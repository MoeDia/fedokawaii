"""The window: the desktop's text-screen grammar (docs/design-system.md §7), drawn from what the engine says.

Two tabs: downloads and find. It holds nothing of its own but a search's results: closing it stops no
download. The layout is a set of columns per width band, from a narrow tile to the whole screen; nothing is
ever cut with "…", a name ends at a word. Column 0 of the screen is the cursor's, column 1 the content's first.
"""
import fcntl
import json
import os
import re
import selectors
import signal
import socket
import subprocess
import threading
import time

import common
from common import cells, cut, pad, reading, size, speed, duration
from term import ACCENT, ACCENT_TEXT, EDGE, EDGE2, FAINT, MUTED, ON_SELECT, SELECT, STRONG, Term

ANIM = 0.125                                       # 8 a second: the moving icons (design-system §13)
PANE_MIN = 132                                     # columns from which the details stand beside the list
PANE_W = 60
OFFER_FILE_AGE = 86400                             # a .torrent that came in the last day is offered
_ICON = re.compile(r"^ICON_([A-Z0-9_]+)=\$'((?:\\x[0-9a-f]{2})+)'", re.M)
CATEGORY = ((2000, "TV_0"), (5000, "TV_0"), (3000, "MUSIC"), (7000, "BOOK"), (1000, "GAMEPAD"), (4000, "CODE"))
SORTS = ("seeds", "size", "newest", "name")
SPARK = 16                                         # columns of the speed's picture


def load_icons():
    path = os.path.join(common.HOME, ".config/fedokawaii/icons.sh")
    try:
        with open(path, encoding="utf-8") as f:
            text = f.read()
    except OSError:
        return {}
    return {n: bytes(int(h, 16) for h in e.split("\\x")[1:]).decode("utf-8") for n, e in _ICON.findall(text)}


class Chosen(list):
    """A row the cursor stands on: whoever lays it down gives it the lacquer."""


class Line:
    """A line of text typed on: the search line, the add line, a filter."""

    def __init__(self, text=""):
        self.text, self.at = text, len(text)

    def key(self, name):
        t, a = self.text, self.at
        if name == "left":
            self.at = max(0, a - 1)
        elif name == "right":
            self.at = min(len(t), a + 1)
        elif name in ("home", "ctrl-a"):
            self.at = 0
        elif name in ("end", "ctrl-e"):
            self.at = len(t)
        elif name == "backspace" and a:
            self.text, self.at = t[:a - 1] + t[a:], a - 1
        elif name == "delete":
            self.text = t[:a] + t[a + 1:]
        elif name == "ctrl-u":
            self.text, self.at = t[a:], 0
        elif name == "ctrl-k":
            self.text = t[:a]
        elif name == "ctrl-w":
            b = t[:a].rstrip()
            b = b[:b.rfind(" ") + 1]
            self.text, self.at = b + t[a:], len(b)
        elif name == "space":
            self.put(" ")
        else:
            return False
        return True

    def put(self, s):
        s = common.safe(s)
        self.text = self.text[:self.at] + s + self.text[self.at:]
        self.at += len(s)

    def view(self, w):
        """What fits in W columns around the cursor, and the cursor's column in it."""
        t, a = self.text, self.at
        if cells(t) < w:
            return t, cells(t[:a])
        start = 0
        while cells(t[start:a]) >= w:
            start += 1
        return cut_plain(t[start:], w), cells(t[start:a])


def cut_plain(s, n):
    used, out = 0, []
    for c in s:
        w = common.width_of(c)
        if used + w > n:
            break
        out.append(c)
        used += w
    return "".join(out)


class App:
    def __init__(self, first_links=()):
        self.t = Term()
        self.ic = load_icons()
        self.quit = False
        self.tab = "downloads"
        self.first_view = False
        self.sock = None
        self.inbuf = b""
        self.n = 0
        self.waiting = {}                          # n → what to do with the answer
        self.rows = {}
        self.turtle = False
        self.connected = False
        self.tried = 0.0
        self.first_links = list(first_links)
        self.focused = True
        self.cursor_id = None                      # the row the cursor is on, whatever moves around it
        self.coming = None                         # a row added a moment ago, not told of yet
        self.find_moved = False
        self.top = 0
        self.items = []                            # the list shown: dicts, with "id" when it can be chosen
        self.items_key = None
        self.version = 0                           # one more with every change to the rows or the offers
        self.pane_focus = False                    # the keyboard in the details' files
        self.page = False                          # a narrow window: the details fill it
        self.filter = None                         # the list's filter line
        self.adding = None                         # the add line
        self.ask = None                            # a question on the last line: (words, action)
        self.say_until = 0.0
        self.saying = ""
        self.watched = None
        self.files = {}                            # id → the paths and sizes the engine sent
        self.detail = {}
        self.file_cursor = 0
        self.file_top = 0
        self.speeds = []                           # what came in, a second each: the columns at the tabs' right end
        self.speed_at = 0.0
        self.wants_play = None                     # a stream asked for, waiting for its head
        self.wants_files = None                    # v on a row whose files have not come yet
        self.into_files = None                     # Enter on a row whose files have not come yet
        self.play_added = False                    # v on a result: play what is being added
        self.synced = False                        # the engine has said what it has
        self.offers = []                           # what could be added: the clipboard's, the Downloads folder's
        self.declined = set()
        self.frame_n = 0
        self.last_anim = 0.0
        self.mouse_map = {}                        # screen row → what is there
        self.tab_hits = []
        # find
        self.query = Line()
        self.line_focus = True
        self.results = {}
        self.pending_sites = 0
        self.total_sites = 0
        self.search_id = 0
        self.search_err = ""
        self.key = None
        self.prowlarr_woken = False
        self.tended = False
        self.sort = 0
        self.cache = {}
        self.queue = []
        self.q_lock = threading.Lock()
        self.wake_r, self.wake_w = os.pipe2(os.O_NONBLOCK | os.O_CLOEXEC)
        self.sel = selectors.DefaultSelector()

    # ── the engine ──────────────────────────────────────────────────────────────────────────
    def connect(self):
        self.tried = time.monotonic()
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM | socket.SOCK_CLOEXEC)
        try:
            s.connect(common.SOCK)
        except OSError:
            s.close()
            # (systemd's socket not up: the session before this program was installed)
            subprocess.run(["systemctl", "--user", "start", "--no-block", "kawa-torrents.socket"], stdin=subprocess.DEVNULL,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
            return False
        s.setblocking(False)
        self.sock, self.inbuf, self.connected = s, b"", True
        self.sel.register(s, selectors.EVENT_READ, "engine")
        self.send({"op": "hello"})
        self.watched = None
        for link in self.first_links:
            self.add_link(link)
        self.first_links = []
        return True

    def lost(self):
        if self.sock is not None:
            self.sel.unregister(self.sock)
            self.sock.close()
        self.sock, self.connected = None, False

    def send(self, q, then=None):
        if self.sock is None:
            return
        if then is not None:
            self.n += 1
            q = {**q, "n": self.n}
            self.waiting[self.n] = then
        try:
            self.sock.setblocking(True)
            self.sock.settimeout(2)
            self.sock.sendall((json.dumps(q) + "\n").encode())
            self.sock.setblocking(False)
        except OSError:
            self.lost()

    def on_engine(self):
        try:
            data = self.sock.recv(1 << 20)
        except BlockingIOError:
            return
        except OSError:
            data = b""
        if not data:
            self.lost()
            return
        self.inbuf += data
        *lines, self.inbuf = self.inbuf.split(b"\n")
        for line in lines:
            self.on_message(json.loads(line))

    def on_message(self, m):
        if "re" in m:
            then = self.waiting.pop(m["re"], None)
            if then:
                then(m)
            return
        ev = m.get("ev")
        if ev == "rows":
            self.version += 1
            if m.get("all"):
                self.rows = {}
                self.synced = True
                self.turtle = m.get("turtle", False)
                if self.first_view and not m["rows"] and self.tab == "downloads":
                    self.switch_tab()              # (nothing here yet: what you came for is the search)
                self.first_view = False
            for r in m["rows"]:
                self.rows[r["id"]] = r
            for i in m["gone"]:
                self.rows.pop(i, None)
        elif ev == "turtle":
            self.turtle = m["on"]
        elif ev == "moved":
            if self.cursor_id == m["from"]:
                self.cursor_id = m["to"]
        elif ev == "files":
            self.files[m["id"]] = m["files"]
            if self.into_files == m["id"]:         # (Enter on a row whose files were on their way)
                self.into_files = None
                if self.cursor_id == m["id"] and (self.page or self.pane_shown(self.t.cols)):
                    self.pane_focus = True
            if self.wants_files == m["id"]:        # (v, its files asked for: they are here)
                self.wants_files = None
                if self.rows.get(m["id"]):
                    self.play_row(self.rows[m["id"]])
        elif ev == "detail":
            old = self.detail.get(m["id"])
            if old and "trackers" not in m and "trackers" in old:
                m["trackers"] = old["trackers"]
            self.detail[m["id"]] = m
        elif ev == "stream":
            if self.wants_play == m["id"]:
                self.wants_play = None
                self.play(m["url"])

    # ── links ───────────────────────────────────────────────────────────────────────────────
    def add_link(self, link, name="", source="", also=""):
        kinds = common.links(link)
        if not kinds:
            self.tell("not a magnet link, a .torrent file or a link to one")
            return
        for kind, value in kinds:
            try:
                self.send({"op": "add", **common.asking(kind, value), "name": name, "source": source, "also": also}, self.added)
            except OSError as e:
                self.tell(f"{os.path.basename(value)}: {e.strerror}")
        self.go_downloads()

    def added(self, m):
        if m.get("err"):
            self.tell(m["err"])
        elif m.get("id"):
            self.cursor_id, self.coming, self.pane_focus, self.page = m["id"], m["id"], False, False
            if m.get("known"):
                self.tell("already here")
            if self.play_added:                    # (v on a search's result)
                self.play_added = False
                self.play_row(self.rows.get(m["id"]) or {"id": m["id"], "meta": False})

    def go_downloads(self):
        self.tab = "downloads"
        self.line_focus = False

    def tell(self, words):
        self.saying, self.say_until = words, time.monotonic() + 3

    def clip_get(self):
        """The clipboard's words (never waited for on the drawing's thread: an owner that hangs cannot hold up the window)."""
        def run():
            text = ""
            try:
                r = subprocess.run(["wl-paste", "--no-newline", "--type", "text"], capture_output=True, timeout=2, check=False)
                if r.returncode == 0:
                    text = r.stdout[:1 << 20].decode("utf-8", "replace")
            except (OSError, subprocess.TimeoutExpired):
                pass
            self.post(("clipboard", text))
        threading.Thread(target=run, daemon=True).start()

    def copy(self, text, word):
        try:
            subprocess.Popen(["wl-copy", "--", text], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                             stderr=subprocess.DEVNULL, start_new_session=True)
            self.tell(word)
        except OSError as e:
            self.tell(f"the clipboard: {e.strerror}")

    def look_for_offers(self):
        self.clip_get()
        offers = [o for o in self.offers if o["from"] == "clipboard"]
        try:
            now = time.time()
            for e in os.scandir(common.DOWNLOADS):
                if e.name.endswith(".torrent") and e.is_file() and now - e.stat().st_mtime < OFFER_FILE_AGE:
                    if e.path not in self.declined and not any(o["value"] == e.path for o in offers):
                        offers.append({"from": "folder", "kind": "file", "value": e.path, "name": reading(e.name[:-8]), "hash": None})
        except OSError:
            pass
        self.offers = offers
        self.version += 1

    def on_clipboard(self, text):
        self.version += 1
        self.offers = [o for o in self.offers if o["from"] != "clipboard"]
        found = [(k, v) for k, v in common.links(text, loose=False)]
        if self.adding is not None and not self.adding.text and found:
            self.adding = Line(found[0][1])
        for kind, value in found[:1] if len(found) == 1 else []:
            if value in self.declined:
                continue
            name = reading(common.magnet_name(value) if kind == "magnet" else os.path.basename(value))
            self.offers.insert(0, {"from": "clipboard", "kind": kind, "value": value, "name": name,
                                   "hash": common.magnet_hash(value) if kind == "magnet" else None})
        if len(found) > 1:
            many = "\n".join(v for _, v in found)
            if many not in self.declined:
                self.offers.insert(0, {"from": "clipboard", "kind": "many", "value": many, "name": f"{len(found)} links", "hash": None})

    def offers_now(self):
        return [o for o in self.offers if not o["hash"] or o["hash"] not in self.rows]

    def take_offer(self, o):
        self.version += 1
        self.offers.remove(o)
        self.declined.add(o["value"])
        self.add_link(o["value"], o["name"] if o["kind"] != "many" else "")

    def on_paste(self, text):
        if self.adding is not None:
            self.adding.put(" ".join(text.split()))
        elif self.tab == "find" and self.line_focus:
            found = common.links(text, loose=False)
            if found:
                self.add_link(text)
            else:
                self.query.put(" ".join(text.split()))
        elif self.filter is not None:
            self.filter.put(" ".join(text.split()))
        else:
            self.add_link(text)

    # ── find ────────────────────────────────────────────────────────────────────────────────
    def post(self, item):
        with self.q_lock:
            self.queue.append(item)
        try:
            os.write(self.wake_w, b".")
        except BlockingIOError:
            pass

    def wake_prowlarr(self):
        if not self.prowlarr_woken:
            self.prowlarr_woken = True
            threading.Thread(target=self.wake_thread, daemon=True).start()

    def wake_thread(self):
        try:
            r = subprocess.run(["kawa-prowlarr", "--busy"], stdin=subprocess.DEVNULL, capture_output=True, check=False)
            self.post(("prowlarr-up", r.returncode == 0))
        except OSError:
            self.post(("prowlarr-up", False))

    def start_search(self):
        q = " ".join(self.query.text.split())
        if not q:
            return
        self.search_id += 1
        self.results, self.search_err = {}, ""
        self.top, self.find_moved = 0, False
        if q in self.cache and time.monotonic() - self.cache[q][0] < 300:
            self.results = dict(self.cache[q][1])
            self.pending_sites = self.total_sites = 0
            self.line_focus = False
            return
        self.pending_sites = self.total_sites = 1          # (until the sites are known)
        self.wake_prowlarr()
        threading.Thread(target=self.search_thread, args=(self.search_id, q), daemon=True).start()
        self.line_focus = False

    def search_thread(self, sid, q):
        """Prowlarr woken first if asleep (a few seconds), then each site asked on its own thread."""
        import prowlarr                            # (only now: urllib and all it brings, half the window's memory)
        if not self.key:
            self.key = prowlarr.secret()
        if not self.key:
            self.post(("search-failed", sid, "no Prowlarr key in secrets.sh: fedokawaii repair makes one"))
            return
        sites, err, end = None, "", time.monotonic() + 90
        while time.monotonic() < end:
            try:
                sites = prowlarr.sites(self.key)
                break
            except prowlarr.urllib.error.HTTPError as e:
                err = "Prowlarr refused the key in secrets.sh: fedokawaii repair hands it over again" if e.code == 401 else f"Prowlarr answered HTTP {e.code}"
                break
            except OSError:
                err = "Prowlarr did not start: journalctl --user -u prowlarr -e says why"
                time.sleep(0.5)
            except ValueError:
                err = "Prowlarr's answer could not be read"
                break
        if sites is None:
            self.post(("search-failed", sid, err))
            return
        if not sites:
            self.post(("search-failed", sid, "Prowlarr has no sites switched on: fedokawaii repair adds the usual ones"))
            return
        self.post(("search-sites", sid, len(sites)))
        for site, _ in sites:
            threading.Thread(target=self.site_thread, args=(sid, q, site), daemon=True).start()

    def site_thread(self, sid, q, site):
        import prowlarr
        rows = []
        try:
            rows = prowlarr.search(self.key, site, q)
        except (OSError, ValueError):
            pass                                   # (one site's trouble: the others' results stand)
        self.post(("search-site", sid, q, rows))

    def on_queue(self):
        try:
            os.read(self.wake_r, 4096)
        except BlockingIOError:
            pass
        with self.q_lock:
            items, self.queue = self.queue, []
        for it in items:
            kind = it[0]
            if kind == "clipboard":
                self.on_clipboard(it[1])
            elif kind == "copy":
                self.copy(it[1], "magnet copied")
            elif kind == "say":
                self.tell(it[1])
            elif kind == "prowlarr-up":
                pass
            elif kind == "search-failed" and it[1] == self.search_id:
                self.search_err = it[2]
                self.pending_sites = 0
            elif kind == "search-sites" and it[1] == self.search_id:
                self.pending_sites = self.total_sites = it[2]
            elif kind == "search-site" and it[1] == self.search_id:
                self.pending_sites -= 1
                self.merge(it[3])
                if self.pending_sites == 0:
                    self.cache[it[2]] = (time.monotonic(), dict(self.results))
                    if not self.tended:
                        self.tended = True
                        threading.Thread(target=self.tend_thread, daemon=True).start()

    def tend_thread(self):
        import prowlarr
        try:
            with open(os.devnull, "w") as quiet:
                import contextlib
                with contextlib.redirect_stdout(quiet), contextlib.redirect_stderr(quiet):
                    prowlarr.tend(self.key)
        except OSError:
            pass

    def merge(self, found):
        """One torrent on three sites is one row: its best-seeded telling, the sites beside it."""
        for r in found:
            h = (r.get("infoHash") or "").lower()
            k = h or r.get("guid") or r.get("title")
            if not k:
                continue
            old = self.results.get(k)
            seeds = r.get("seeders") or 0
            row = {"id": "r:" + k, "key": k, "name": reading(r.get("title") or "?"), "size": r.get("size") or 0, "seeds": seeds,
                   "site": common.safe(r.get("indexer") or ""), "hash": h, "guid": r.get("guid") or "",
                   "magnet": r.get("magnetUrl") or "", "download": r.get("downloadUrl") or "",
                   "age": r.get("ageHours") or 0, "cat": cat_icon(r.get("categories"))}
            if old is None or seeds > old["seeds"]:
                self.results[k] = row

    def sorted_results(self):
        rows = list(self.results.values())
        how = SORTS[self.sort]
        if how == "seeds":
            rows.sort(key=lambda r: (-r["seeds"], r["name"]))
        elif how == "size":
            rows.sort(key=lambda r: -r["size"])
        elif how == "newest":
            rows.sort(key=lambda r: r["age"])
        else:
            rows.sort(key=lambda r: common.natural(r["name"]))
        return rows

    def result_link(self, r):
        """A magnet to start from at once: no site, no Prowlarr, no waiting — the hash is enough."""
        if r["guid"].lower().startswith("magnet:"):
            return r["guid"]
        if r["hash"]:
            return common.make_magnet(r["hash"], r["name"])
        return ""

    def add_result(self, r, play=False):
        self.play_added = play
        link = self.result_link(r)
        also = r["magnet"] if r["magnet"].lower().startswith("http") else ""
        if link:
            self.send({"op": "add", "kind": "magnet", "value": link, "name": r["name"], "source": r["site"], "also": also}, self.added)
        else:
            self.send({"op": "add", "kind": "url", "value": r["magnet"] or r["download"], "name": r["name"], "source": r["site"]}, self.added)
        self.go_downloads()

    def copy_result(self, r):
        """Prowlarr's own link leads to the whole magnet, trackers and all; the hash alone if it does not answer quickly."""
        url = r["magnet"] if r["magnet"].lower().startswith("http") else r["download"]
        fallback = self.result_link(r)

        def run():
            found = ""
            if url:
                try:
                    kind, value = common.fetch_link(url, 8)
                    if kind == "magnet":
                        found = value
                    else:                          # (the site hands out .torrent files: its magnet read from one)
                        import libtorrent as lt
                        found = lt.make_magnet_uri(lt.torrent_info(lt.bdecode(value)))
                except (common.FetchFailed, ImportError, RuntimeError, ValueError):
                    pass
            if found or fallback:
                self.post(("copy", found or fallback))
            else:
                self.post(("say", "this site gives no magnet link"))
        threading.Thread(target=run, daemon=True).start()

    # ── downloads: the rows ─────────────────────────────────────────────────────────────────
    def order(self):
        """In parts: what comes in, newest first; what rests; what is here, last finished first."""
        coming, resting, here = [], [], []
        for r in self.rows.values():
            w = r["word"]
            if self.filter is not None and self.filter.text.casefold() not in r["name"].casefold().replace(".", " "):
                continue
            (here if w == "done" else resting if w == "paused" else coming).append(r)
        coming.sort(key=lambda r: (-r["added"], r["id"]))
        resting.sort(key=lambda r: (-r["added"], r["id"]))
        here.sort(key=lambda r: (-r["at"], -r["added"], r["id"]))
        return coming, resting, here

    def list_items(self):
        items = []
        if self.filter is None:
            for o in self.offers_now():
                items.append({"kind": "offer", "id": "o:" + o["value"], "offer": o})
        coming, resting, here = self.order()
        first = not items
        for icon, word, rows in (("DOWNLOAD", "downloading", coming), ("PAUSE", "paused", resting), ("CHECK", "finished", here)):
            if not rows:
                continue
            if not first:
                items += [{"kind": "gap"}, {"kind": "gap"}]
            first = False
            items += [{"kind": "head", "icon": icon, "word": word, "right": self.part_sum(rows, word)}, {"kind": "gap"}]
            items += [{"kind": "row", "id": r["id"], "row": r} for r in rows]
        if self.synced and not any(i["kind"] == "row" for i in items) and not any(i["kind"] == "offer" for i in items):
            items.append({"kind": "note", "word": "nothing matches" if self.filter is not None else "nothing yet"})
        return items

    def part_sum(self, rows, word):
        """At a part's rule, how many and how much: what is left to come, or what is here."""
        n = len(rows)
        if word == "finished":
            return f"{n} · {size(sum(r['total'] for r in rows))}"
        left = sum(r["total"] - r["done"] for r in rows)
        return f"{n} · {size(left)} to come" if left > 0 else str(n)

    def find_items(self):
        items = [{"kind": "result", "id": r["id"], "row": r} for r in self.sorted_results()]
        if items:
            return items
        if self.search_err:
            return [{"kind": "failure", "word": self.search_err}]
        if self.pending_sites:
            return []
        return [{"kind": "note", "word": "nothing found" if self.search_id else ""}] if self.search_id else []

    # ── drawing ─────────────────────────────────────────────────────────────────────────────
    def icon(self, name):
        return self.ic.get(name, " ")

    def heading(self, icon, name, w, right=""):
        """Its icon at column 0, its name from column 3, a space, the rule to the last column."""
        name = cut(name, max(0, w - 5))
        used = 3 + cells(name)
        spans = [(self.icon(icon), ACCENT_TEXT), "  ", (name, STRONG)]
        room = w - used
        if right and room >= cells(right) + 4:
            spans += [" ", ("─" * (room - cells(right) - 2), EDGE2), " ", (right, MUTED)]
        elif room >= 2:
            spans += [" ", ("─" * (room - 1), EDGE2)]
        return spans

    def segment(self, level):
        """A meter's square by how much of it is here, 0 … 8: read-off, read-1 … read-7, read."""
        return self.icon("READ_OFF" if level <= 0 else "READ" if level >= 8 else f"READ_{level}")

    def meter(self, fraction, inks):
        """Ten segments: those done solid, the next part-way (its inside coming in as a dissolve does), the rest hollow."""
        tenths = max(0.0, min(1.0, fraction)) * 10
        done = int(tenths)
        spans = [(self.segment(8) * done, inks[0])]
        if done < 10:
            part = int((tenths - done) * 8)
            spans.append((self.segment(part), inks[0] if part else inks[1]))
            spans.append((self.segment(0) * (9 - done), inks[1]))
        return spans

    def state_icon(self, r):
        """A row's picture says its state; the ones that move while something happens (§5, §13)."""
        w, f = r["word"], self.frame_n
        if "stream" in r:
            return f"TV_{f // 2 % 4}", ACCENT_TEXT
        if w == "downloading":
            if r["down"] == 0:
                return "DL_0", MUTED
            return f"DL_{f % 6}", ACCENT_TEXT
        if w in ("finding", "asking", "checking", "moving"):
            return f"HG_{f // 2 % 5}", MUTED
        if w == "failed":
            return "CROSS", ACCENT_TEXT
        if w == "paused":
            return "PAUSE", MUTED
        if w == "queued":
            return "HOURGLASS", FAINT
        if time.time() - r["at"] < 60:             # (just finished: the check in the seal's ink a moment)
            return "CHECK", ACCENT_TEXT
        return "CHECK", MUTED

    def row_words(self, r):
        """What stands instead of numbers while there are none."""
        w = r["word"]
        if w == "failed":                          # (its first clause: the whole of it stands in its details)
            return (r["err"] or "failed").partition(":")[0]
        if w == "finding":
            return "looking for it"
        if w == "asking":
            return "asking the site"
        if w == "checking":
            return "checking"
        if w == "moving":
            return "moving"
        if w == "queued":
            return "queued"
        if w == "downloading" and r["down"] == 0:
            return "no one sending" if r["peers"] else "looking for peers"
        return ""

    def band(self, w):
        """The columns a row in motion keeps at this width, right to left: the size last on every row, so it
        stands in one column down the whole list."""
        if w >= 104:
            return ("meter", "pct", "speed", "eta", "size")
        if w >= 84:
            return ("meter", "pct", "speed", "eta")
        if w >= 62:
            return ("meter", "pct", "speed")
        if w >= 44:
            return ("pct", "speed")
        return ("pct",)

    def value_cols(self, r, w):
        """The row's values, each right-aligned in its column, two columns apart. A finished row has no meter: what
        it still says is what it sends, if it does, and how big it is."""
        b = self.band(w)
        if r["word"] == "done":
            out = []
            if r["up"] >= 1000 and w >= 62:
                out.append((f"{'↑ ' + speed(r['up']):>11}", MUTED))
            out.append((f"{size(r['total']):>8}", MUTED))
            return out
        frac = (r["done"] / r["total"]) if r["total"] else 0
        words = self.row_words(r)
        if "stream" in r and not r["stream"]["ready"]:
            words = f"buffering {int(r['stream']['buffered'] * 100)}%"
        out = []
        if words:
            if "meter" in b and r["total"] and r["word"] != "failed":
                out.append(("METER", frac))
            out.append((cut(words, max(10, w // 2 if r["word"] == "failed" else w // 3)), None if r["word"] == "failed" else MUTED))
            if "size" in b and r["total"]:
                out.append((f"{size(r['total']):>8}", MUTED))
            return out
        if "meter" in b:
            out.append(("METER", frac))
        if "pct" in b:
            out.append((f"{int(frac * 100):>3}%" if r["total"] else "    ", MUTED))
        if "speed" in b:
            out.append((f"{speed(r['down']):>9}", MUTED))
        if "eta" in b:
            left = (r["total"] - r["done"]) / r["down"] if r["down"] else None
            out.append((f"{duration(left) if left is not None else '':>7}", MUTED))
        if "size" in b:
            out.append((f"{size(r['total']):>8}" if r["total"] else " " * 8, MUTED))
        return out

    def draw_row(self, item, w, selected):
        """A row: its icon at column 1, its name from column 4, the values right-aligned to the last."""
        r = item["row"]
        icon, inkname = self.state_icon(r)
        vals = self.value_cols(r, w)
        vw = sum((10 if v[0] == "METER" else cells(v[0])) + 2 for v in vals)
        name = cut(reading(r["name"]), w - 4 - vw)
        filler = w - 4 - cells(name) - vw
        if selected:
            spans = [(" " + self.icon(icon) + "  " + name + " " * filler, ON_SELECT, SELECT)]
        else:
            spans = [" ", (self.icon(icon), inkname), "  ", (name, FAINT if r["word"] == "queued" else None), " " * filler]
        for v in vals:
            if selected:
                spans.append(("  ", ON_SELECT, SELECT))
                if v[0] == "METER":
                    spans += [(t, ON_SELECT, SELECT) for t, _ in self.meter(v[1], (0, 0))]
                else:
                    spans.append((v[0], ON_SELECT, SELECT))
            else:
                spans.append("  ")
                if v[0] == "METER":
                    spans += self.meter(v[1], (MUTED, EDGE2) if r["word"] == "paused" else (ACCENT_TEXT, EDGE2))
                else:
                    spans.append(v)
        return spans

    def draw_result(self, item, w, selected):
        """A result: its kind's icon, its name; then the site, its age and its size where they fit, and last the
        seedling and how many share it: what says most about how fast it will come."""
        r = item["row"]
        vals = []
        if w >= 104:
            vals.append((pad(cut(r["site"], 17), 17), MUTED))
        if w >= 76:
            vals.append((f"{age_words(r['age']):>9}", MUTED))
        if w >= 40:
            vals.append((f"{size(r['size']):>8}", MUTED))
        vw = sum(cells(v[0]) + 2 for v in vals) + 2 + 3 + 5
        name = cut(r["name"], w - 4 - vw)
        filler = w - 4 - cells(name) - vw
        seeds = f"{r['seeds']:>5}"
        sprout = self.icon("SPROUT")
        if selected:
            spans = [(" " + self.icon(r["cat"]) + "  " + name + " " * filler, ON_SELECT, SELECT)]
            for v in vals:
                spans.append(("  " + v[0], ON_SELECT, SELECT))
            spans.append(("  " + sprout + "  " + seeds, ON_SELECT, SELECT))
            return spans
        dead = not r["seeds"]
        spans = [" ", (self.icon(r["cat"]), FAINT if dead else MUTED), "  ", (name, FAINT if dead else None), " " * filler]
        for v in vals:
            spans += ["  ", v]
        spans += ["  ", (sprout, FAINT if dead else MUTED), "  ", (seeds, FAINT if dead else None)]
        return spans

    def draw_offer(self, item, w, selected):
        o = item["offer"]
        where = "in the clipboard" if o["from"] == "clipboard" else "in Downloads"
        value = "enter adds  x not now"
        if w < 60:
            value = "enter adds"
        if w < 40:
            value = ""
        name_w = w - 4 - (cells(value) + 2 if value else 0) - cells(where) - 2
        name = cut(o["name"], name_w)
        filler = w - 4 - cells(where) - 2 - cells(name) - (cells(value) + 2 if value else 0)
        if selected:
            return [(" " + self.icon("MAGNET") + "  " + where + "  " + name + " " * filler + ("  " + value if value else ""), ON_SELECT, SELECT)]
        return [" ", (self.icon("MAGNET"), ACCENT_TEXT), "  ", (where, MUTED), "  ", (name, STRONG), " " * filler,
                *(["  ", (value, MUTED)] if value else [])]

    def tabs(self, w):
        """Three lines over the list: the tab shown with its name, the other its icon alone."""
        names = (("downloads", "DOWNLOAD"), ("find", "SEARCH"))
        top, under, x = [], [], 1
        self.tab_hits = []
        for k, (name, icon) in enumerate(names):
            if k:
                top.append("   ")
                under.append("   ")
                x += 3
            if name == self.tab:
                top += [(self.icon(icon), ACCENT_TEXT), "  ", (name, STRONG)]
                under += ["   ", ("▔" * len(name), ACCENT)]
                self.tab_hits.append((x, x + 3 + len(name), name))
                x += 3 + len(name)
            else:
                top += [(self.icon(icon), MUTED), " "]
                under.append("  ")
                self.tab_hits.append((x, x + 2, name))
                x += 2
        right = self.totals(w - (x - 1) - 3)
        used = sum(cells(s if isinstance(s, str) else s[0]) for s in top)
        if right:
            rw = sum(cells(s if isinstance(s, str) else s[0]) for s in right)
            top.append(" " * max(1, w - used - rw))
            top += right
        return top, under

    def totals(self, room):
        """What comes and goes, at the tabs' right end: only while it does."""
        if not self.rows or room < 12:
            return []
        down = sum(r["down"] for r in self.rows.values() if r["word"] != "done")
        up = sum(r["up"] for r in self.rows.values())
        self.remember_speed(down)
        parts = []
        if self.turtle:
            parts.append(("slow", STRONG))
        if down >= 1000 and room >= 26 + SPARK and max(self.speeds, default=0):
            parts.append(self.spark())
        if down >= 1000:
            parts.append(("↓ " + speed(down), MUTED))
        if up >= 1000 and room >= 26:
            parts.append(("↑ " + speed(up), MUTED))
        out = []
        for k, p in enumerate(parts):
            if k:
                out.append("   ")
            out.append(p)
        return out

    def remember_speed(self, down):
        now = time.monotonic()
        if now - self.speed_at >= 1:
            self.speed_at = now
            self.speeds = (self.speeds + [down])[-SPARK:]

    def spark(self):
        """The last seconds of what came in, the music's wings' columns (design-system §8): the newest at the right, the tallest the most seen."""
        top = max(self.speeds)
        cols = [self.icon(f"EQ_{int(9 * v / top)}") for v in self.speeds]
        return ("".join([self.icon("EQ_0")] * (SPARK - len(cols)) + cols), ACCENT)

    def draw(self):
        t = self.t
        cols, rows = t.cols, t.rows
        self.mouse_map = {}
        t.cursor = None
        if cols < 8 or rows < 3:
            t.draw([])
            return
        w = cols - 2                               # the content, from screen column 1 (the cursor's fill is 0 … cols-1)
        frame = [[] for _ in range(max(rows, 8))]  # (a window of a few rows: what does not fit is not sent)
        pane = self.pane_shown(cols)
        if self.page and self.tab == "downloads" and not pane and self.page_row():
            self.draw_page(frame, cols, rows, w)
        else:
            list_w = w - PANE_W - 3 if pane else w
            top, under = self.tabs(list_w)
            frame[0] = [" "] + top
            frame[1] = [" "] + under
            body_top = 3
            if self.tab == "find":
                body_top = self.draw_find_line(frame, list_w)
            elif self.adding is not None:
                body_top = self.draw_add_line(frame, list_w)
            elif self.filter is not None:
                body_top = self.draw_filter_line(frame, list_w)
            body_h = rows - body_top - 1
            key = (self.tab, self.version, self.filter.text if self.filter else None, len(self.results), self.sort, self.search_err, bool(self.pending_sites), self.search_id)
            if key != self.items_key:              # (an icon's next frame needs no new list: a thousand rows cost nothing)
                self.items_key = key
                self.items = self.find_items() if self.tab == "find" else self.list_items()
            self.place_cursor(body_h)
            if pane:
                self.draw_list(frame, body_top, body_h, list_w)
                self.draw_pane(frame, cols, rows, w, list_w)
            else:
                self.draw_list(frame, body_top, body_h, list_w)
        self.last_line(frame, rows, w, cols)
        t.draw(frame)

    def pane_shown(self, cols):
        return self.tab == "downloads" and cols >= PANE_MIN

    def page_row(self):
        return self.rows.get(self.cursor_id)

    def place_cursor(self, h):
        """The cursor on a row that exists; the view where it can be seen."""
        ids = [k for k, it in enumerate(self.items) if "id" in it]
        if self.tab == "find" and not self.find_moved and ids:
            self.cursor_id = self.items[ids[0]]["id"]
        at = next((k for k in ids if self.items[k]["id"] == self.cursor_id), None)
        if at is None and self.coming and self.coming == self.cursor_id and self.tab == "downloads":
            return                                 # (added a moment ago: its row is on its way)
        if at is None:
            if not ids:
                self.cursor_id = None
                self.top = 0
                return
            at = ids[0] if not getattr(self, "last_at", None) else min(ids, key=lambda k: abs(k - self.last_at))
            self.cursor_id = self.items[at]["id"]
        self.last_at = at
        if h > 0:
            if at < self.top:
                self.top = at
            elif at >= self.top + h:
                self.top = at - h + 1
            if at - (self.top) < 3 and self.top > 0:   # (a heading stays with its first row)
                k = at
                while k > 0 and "id" not in self.items[k - 1]:
                    k -= 1
                self.top = min(self.top, k)
        self.top = max(0, min(self.top, max(0, len(self.items) - max(1, h))))

    def draw_list(self, frame, top, h, w):
        for k in range(h):
            at = self.top + k
            if at >= len(self.items):
                break
            it = self.items[at]
            y = top + k
            here = "id" in it and it["id"] == self.cursor_id
            selected = here and not self.pane_focus and self.adding is None
            kind = it["kind"]
            if kind == "head":
                frame[y] = [" "] + self.heading(it["icon"], it["word"], w, it["right"])
            elif kind == "note":
                frame[y] = ["     ", (it["word"], FAINT)]
            elif kind == "failure":
                frame[y] = ["  ", (self.icon("CROSS"), ACCENT_TEXT), "  ", cut(it["word"], w - 4)]
            elif kind == "row":
                frame[y] = self.lacquer(self.draw_row(it, w, selected or here), selected or here)
                if here and not selected:          # (the keyboard is in its files: its place kept in a band)
                    frame[y] = [(s[0], STRONG, EDGE) if isinstance(s, tuple) else s for s in frame[y]]
            elif kind == "result":
                frame[y] = self.lacquer(self.draw_result(it, w, selected), selected)
            elif kind == "offer":
                frame[y] = self.lacquer(self.draw_offer(it, w, selected), selected)
            if "id" in it:
                self.mouse_map[y] = it

    def lacquer(self, spans, selected):
        """The cursor's fill: from the cursor's column to the one beyond the content."""
        if selected:
            return [(" ", ON_SELECT, SELECT), *spans, (" ", ON_SELECT, SELECT)]
        return [" ", *spans]

    def draw_find_line(self, frame, w):
        """The search line: the chevron at the rows' icon column, the words at their names', the count at the end."""
        y = 3
        count = ""
        if self.pending_sites:
            done = self.total_sites - self.pending_sites
            count = f"{len(self.results)} · {done} of {self.total_sites} sites" if self.total_sites > 1 else "asking Prowlarr"
        elif self.search_id and self.results:
            count = f"{len(self.results)} found"
        room = w - 4 - (cells(count) + 2 if count else 0)
        mark = self.icon(f"HG_{self.frame_n // 2 % 5}") if self.pending_sites else self.icon("CHEVRON_RIGHT")
        spans = [" ", " ", (mark, ACCENT_TEXT), "  "]
        if self.query.text or self.line_focus:
            text, at = self.query.view(room)
            if not self.query.text:
                spans.append(("what to find", FAINT))
                filler = room - cells("what to find")
            else:
                spans.append(text)
                filler = room - cells(text)
            if self.line_focus:
                self.t.cursor = (y, 1 + 4 + at)
        else:
            spans.append(("what to find", FAINT))
            filler = room - cells("what to find")
        spans.append(" " * filler)
        if count:
            spans += ["  ", (count, MUTED)]
        frame[y] = spans
        return y + 2

    def draw_add_line(self, frame, w):
        y = 3
        room = w - 4
        text, at = self.adding.view(room)
        magnet = self.icon("MAGNET")
        spans = ["  ", (magnet, ACCENT_TEXT), "  "]
        if self.adding.text:
            spans.append(text)
        else:
            spans.append((cut("a magnet link, a link to a .torrent, its path or a hash", room), FAINT))
        frame[y] = spans
        self.t.cursor = (y, 1 + 4 + at)
        said = self.understood(self.adding.text)
        if said:
            frame[y + 1] = ["     ", (cut(said[0], room), said[1])]
        return y + 3

    def understood(self, text):
        """What a line typed or pasted comes to, before Enter: its name, how many, or that it is none."""
        if not text.strip():
            return None
        found = common.links(text)
        if not found:
            return "not a magnet link, a .torrent file or a link to one", FAINT
        if len(found) > 1:
            return f"{len(found)} links", STRONG
        kind, value = found[0]
        if kind == "magnet":
            return reading(common.magnet_name(value)), STRONG
        if kind == "file":
            return reading(os.path.basename(value)[:-8]), STRONG
        return "a link: asked when added", MUTED

    def draw_filter_line(self, frame, w):
        y = 3
        room = w - 4
        text, at = self.filter.view(room)
        spans = ["  ", (self.icon("CHEVRON_RIGHT"), ACCENT_TEXT), "  "]
        spans.append(text if self.filter.text else ("only those that contain", FAINT))
        frame[y] = spans
        self.t.cursor = (y, 1 + 4 + at)
        return y + 2

    def draw_pane(self, frame, cols, rows, w, list_w):
        """The details beside the list: the rail past the list's cursor fill, a free column (the pane's own cursor
        fill), its heading level with the tabs."""
        rail = list_w + 2
        x = rail + 2
        for y in range(rows - 1):
            frame[y] = pad_to(frame[y], rail) + [("│", EDGE2)]
        r = self.rows.get(self.cursor_id)
        lines = self.detail_lines(r, cols - x - 1, rows - 1)
        for y, spans in enumerate(lines[:rows - 1]):
            frame[y] = frame[y] + self.lacquer(spans, isinstance(spans, Chosen))
        self.pane_x = x

    def draw_page(self, frame, cols, rows, w):
        """A narrow window: the details fill it; Esc goes back to the list."""
        r = self.page_row()
        lines = self.detail_lines(r, w, rows - 1)
        for y, spans in enumerate(lines[:rows - 1]):
            frame[y] = self.lacquer(spans, isinstance(spans, Chosen))
        self.pane_x = 1

    def detail_lines(self, r, w, h):
        """A torrent looked at: its facts, its pieces, its files. Empty lines where the grid wants air."""
        if r is None:
            return []
        self.want_watch(r["id"], w)
        name = reading(r["name"])
        lines = [self.heading(self.state_icon(r)[0], cut(name, max(0, w - 8)), w), []]
        facts = self.facts(r, w)
        kw = max(cells(k) for k, _ in facts)
        for k, v in facts:
            lines.append(["   ", (pad(k, kw), MUTED), "  ", cut(v, w - 3 - kw - 2)])
        det = self.detail.get(r["id"])
        if det and det.get("pieces"):
            lines += [[], [], self.heading("PIECES", "pieces", w), []]
            lines += self.piece_lines(det["pieces"], w)
        files = self.files.get(r["id"])
        if files:
            lines += [[], [], self.heading("FILE", "files", w), []]
            top = len(lines)
            self.file_rows = [k for k, f in enumerate(files) if f]
            order = sorted(self.file_rows, key=lambda k: common.natural(files[k][0]))
            self.file_order = order
            room = max(1, h - top)
            if self.file_cursor >= len(order):
                self.file_cursor = max(0, len(order) - 1)
            if self.file_cursor < self.file_top:
                self.file_top = self.file_cursor
            elif self.file_cursor >= self.file_top + room:
                self.file_top = self.file_cursor - room + 1
            self.file_top = max(0, min(self.file_top, max(0, len(order) - room)))
            common_prefix = shared_folder([files[k][0] for k in order])
            self.file_y = top
            for row, k in enumerate(order[self.file_top:self.file_top + room]):
                sel = self.pane_focus and self.file_top + row == self.file_cursor
                lines.append(self.file_line(r, files, k, common_prefix, w, sel, det))
        elif r["word"] in ("finding", "asking") and not files:
            lines += [[], [], self.heading("FILE", "files", w), []]
            lines.append(["    ", ("not known yet", FAINT)])
        return lines

    def facts(self, r, w):
        out = []
        word = {"downloading": "downloading", "finding": "looking for it", "asking": "asking the site", "checking": "checking its files",
                "queued": "queued", "paused": "paused", "failed": "failed", "done": "finished", "moving": "moving"}[r["word"]]
        out.append(("state", r["err"] if r["word"] == "failed" and r["err"] else word))
        if r["total"]:
            out.append(("size", f"{size(r['done'])} of {size(r['total'])}" if r["done"] < r["total"] else size(r["total"])))
        if r["down"] >= 1000 and r["word"] != "done":
            left = (r["total"] - r["done"]) / r["down"]
            out.append(("speed", speed(r["down"]) + f", {duration(left)} left"))
        if r["up"] >= 1000:
            out.append(("sends", speed(r["up"])))
        if r["peers"] or r["known"]:
            out.append(("peers", f"{r['peers']} of {max(r['known'], r['peers'])}" + (f", {r['seeds']} seeds" if r["seeds"] else "")))
        if r["ratio"]:
            out.append(("ratio", f"{r['ratio']:.2f}"))
        if r["source"]:
            out.append(("from", r["source"]))
        out.append(("folder", home_short(r["folder"])))
        det = self.detail.get(r["id"])
        if det and det.get("trackers"):
            tr = det["trackers"]
            ok = sum(1 for _, s in tr if s == "answers")
            out.append(("trackers", f"{ok} of {len(tr)} answer"))
        return out

    def piece_lines(self, levels, w):
        """A torrent's pieces: a cloth woven as they come, a segment a cell, each by how much of it is here (0 … 8), left to right, line by line."""
        across = max(1, w - 3)
        out = []
        for at in range(0, len(levels), across):
            spans, run, now = [], [], None
            for level in levels[at:at + across]:
                ink_ = EDGE2 if level == 0 else ACCENT_TEXT
                if ink_ != now and run:
                    spans.append(("".join(run), now))
                    run = []
                run.append(self.segment(level))
                now = ink_
            spans.append(("".join(run), now))
            out.append(["   ", *spans])
        return out

    def file_line(self, r, files, k, prefix, w, selected, det):
        path, sz = files[k]
        name = path[len(prefix):]
        prios = det.get("priorities") if det else None
        on = not prios or (k < len(prios) and prios[k] > 0)
        progress = det.get("progress") if det else None
        got = progress[k] if progress and k < len(progress) else 0
        icon = "BOX_ON" if on else "BOX_OFF"
        pct = f"{int(100 * got / sz):>3}%" if sz else "100%"
        value = f"{size(sz):>8}  {pct}" if w >= 44 else pct
        room = w - 4 - cells(value) - 2
        n = cut_file(name, room)
        filler = room - cells(n)
        if selected:
            return Chosen([(" " + self.icon(icon) + "  " + n + " " * filler + "  " + value, ON_SELECT, SELECT)])
        ink_ = None if on else FAINT
        return [" ", (self.icon(icon), MUTED if on else FAINT), "  ", (n, ink_), " " * filler, "  ", (value, MUTED if on else FAINT)]

    def want_watch(self, i, w):
        """The engine tells of one torrent: the pieces in as many cells as the cloth here holds (three lines on a tall window, one on a small)."""
        lines = 3 if self.t.rows >= 30 else 1
        want = (i, max(1, w - 3) * lines)
        if want != self.watched:
            self.watched = want
            self.send({"op": "watch", "id": i, "cells": want[1]})

    def last_line(self, frame, rows, w, cols):
        """A screen's own keys, on its last line: the key in text, what it does muted, its state strong. A word
        said a moment replaces them; a question waits for its answer."""
        y = max(0, rows - 1)
        if self.ask:
            words = cut(self.ask[0], w - 2)
            frame[y] = [" ", (words, STRONG)]
            return
        if time.monotonic() < self.say_until:
            frame[y] = [" ", (cut(self.saying, w - 2), STRONG)]
            return
        if not self.connected:
            frame[y] = [" ", (self.icon("CROSS"), ACCENT_TEXT), "  ", cut("the engine does not answer: trying again (systemctl --user status kawa-torrents)", w - 3)]
            return
        if self.adding is not None:
            frame[y] = [" "] + keys_spans((("ctrl+o", "pick a file", ""),), w)
            return
        if self.tab == "find":
            keys = (("v", "play", ""), ("y", "copy magnet", ""), ("s", "sort", SORTS[self.sort])) if not self.line_focus else ()
        elif self.pane_focus:
            keys = (("space", "keep or skip", ""), ("a", "all", ""), ("n", "none", ""), ("enter", "play", ""))
        else:
            r = self.selected_row()
            word = r["word"] if r else ""
            p = ("r", "try again", "") if word == "failed" else ("p", "go on", "") if word == "paused" else ("p", "pause", "")
            keys = (("a", "add", ""), ("y", "copy magnet", ""), ("v", "play", ""), p, ("d", "remove", ""), ("t", "slow", "on" if self.turtle else "off"))
        frame[y] = [" "] + keys_spans(keys, w)

    # ── input ───────────────────────────────────────────────────────────────────────────────
    def on_tty(self):
        events = self.t.read()
        if events is None:
            self.quit = True
            return
        for e in events:
            kind = e[0]
            if kind == "key":
                self.on_key(e[1])
            elif kind == "text":
                for c in e[1]:
                    self.on_key(c)
            elif kind == "paste":
                self.on_paste(e[1])
            elif kind == "mouse":
                self.on_mouse(e[1], e[2], e[3])
            elif kind == "focus":
                self.focused = e[1]
                if e[1]:
                    self.look_for_offers()

    def on_key(self, k):
        self.say_until = 0.0
        if self.ask:
            action, self.ask = self.ask[1], None
            if k == "y":
                action()
            return
        if k == "ctrl-q":
            self.quit = True
            return
        if k == "ctrl-v":
            self.paste_clipboard()
            return
        if self.adding is not None:
            self.key_adding(k)
        elif self.tab == "find":
            self.key_find(k)
        elif self.filter is not None and self.key_filter(k):
            pass
        elif self.pane_focus:
            self.key_files(k)
        else:
            self.key_list(k)

    def paste_clipboard(self):
        def run():
            try:
                r = subprocess.run(["wl-paste", "--no-newline", "--type", "text"], capture_output=True, timeout=2, check=False)
                self.post(("pasted", r.stdout.decode("utf-8", "replace") if r.returncode == 0 else ""))
            except (OSError, subprocess.TimeoutExpired):
                self.post(("pasted", ""))
        run_it = threading.Thread(target=run, daemon=True)
        run_it.start()
        run_it.join(2.2)
        with self.q_lock:
            pasted = [i for i in self.queue if i[0] == "pasted"]
            self.queue = [i for i in self.queue if i[0] != "pasted"]
        if pasted and pasted[0][1]:
            self.on_paste(pasted[0][1])
        else:
            self.tell("the clipboard is empty")

    def move(self, step):
        ids = [k for k, it in enumerate(self.items) if "id" in it]
        if not ids:
            return
        self.find_moved = self.tab == "find"
        at = next((p for p, k in enumerate(ids) if self.items[k]["id"] == self.cursor_id), 0)
        at = max(0, min(len(ids) - 1, at + step))
        self.cursor_id = self.items[ids[at]]["id"]

    def jump(self, end):
        ids = [k for k, it in enumerate(self.items) if "id" in it]
        self.find_moved = self.tab == "find"
        if ids:
            self.cursor_id = self.items[ids[-1 if end else 0]]["id"]

    def page_size(self):
        return max(1, self.t.rows - 6)

    def key_common(self, k):
        """The keys of any list."""
        if k in ("j", "down"):
            self.move(1)
        elif k in ("k", "up"):
            self.move(-1)
        elif k in ("pagedown", "ctrl-d"):
            self.move(self.page_size())
        elif k in ("pageup", "ctrl-u"):
            self.move(-self.page_size())
        elif k in ("g", "home"):
            self.jump(False)
        elif k in ("G", "end"):
            self.jump(True)
        elif k in ("tab", "shift-tab", "left", "right"):
            self.switch_tab()
        else:
            return False
        return True

    def switch_tab(self):
        self.pane_focus, self.page, self.filter, self.adding = False, False, None, None
        self.cursor_id, self.top = None, 0
        self.last_at = 0
        if self.tab == "downloads":
            self.tab = "find"
            self.line_focus = not self.results
            self.wake_prowlarr()
        else:
            self.tab = "downloads"

    def selected_row(self):
        return self.rows.get(self.cursor_id)

    def selected_offer(self):
        for it in self.items:
            if it.get("id") == self.cursor_id and it["kind"] == "offer":
                return it["offer"]
        return None

    def key_list(self, k):
        if self.page:
            if k in ("esc", "h", "left", "backspace", "q"):
                self.page = False
                return
            if k in ("enter", "l"):
                self.pane_focus = bool(self.selected_row() and self.files.get(self.cursor_id))
                return
        o = self.selected_offer()
        if o:
            if k == "enter":
                self.take_offer(o)
                return
            if k in ("x", "delete", "backspace"):
                self.version += 1
                self.offers.remove(o)
                self.declined.add(o["value"])
                return
        if self.key_common(k):
            return
        r = self.selected_row()
        if k == "q":
            self.quit = True
        elif k == "esc":
            if self.filter is not None:
                self.filter = None
        elif k == "a":
            self.adding = Line()
            self.clip_get()
        elif k == "/":
            self.filter = Line()
        elif k == "t":
            self.send({"op": "turtle", "on": not self.turtle})
        elif k == "P":
            self.send({"op": "pause_all"})
        elif not r:
            return
        elif k in ("enter", "l", "space"):
            self.open_row(r)
        elif k == "p":
            if r["id"].startswith("url-"):
                return
            self.send({"op": "resume" if r["word"] in ("paused", "failed") else "pause", "id": r["id"]})
        elif k == "y":
            self.copy_row(r)
        elif k == "v":
            self.play_row(r)
        elif k == "o":
            self.open_folder(r)
        elif k == "r":
            self.send({"op": "retry", "id": r["id"]})
            self.tell("asked again")
        elif k == "c":
            self.send({"op": "recheck", "id": r["id"]})
        elif k == "d":
            self.ask = (cut(f"remove {reading(r['name'])}? y removes it, the files stay", self.t.cols - 4), lambda: self.send({"op": "remove", "id": r["id"]}))
        elif k == "D":
            self.ask = (cut(f"delete {reading(r['name'])} and its files? y deletes them", self.t.cols - 4), lambda: self.send({"op": "remove", "id": r["id"], "files": True}))

    def open_row(self, r):
        self.file_cursor = self.file_top = 0
        self.page = not self.pane_shown(self.t.cols)
        self.pane_focus = bool(self.files.get(r["id"]))
        self.into_files = None if self.pane_focus else r["id"]

    def copy_row(self, r):
        if r["id"].startswith("url-"):
            self.tell("its magnet is not known yet")
            return
        self.send({"op": "magnet", "id": r["id"]}, lambda m: self.copy(m["magnet"], "magnet copied") if m.get("magnet") else self.tell("its magnet is not known yet"))

    def play_row(self, r):
        """The one video, or the biggest not yet watched; with many, the choice is the files' list."""
        files = self.files.get(r["id"])
        if files is None:
            if r["id"].startswith("url-"):
                self.tell("its site is still being asked")
                return
            self.wants_files = r["id"]             # (it plays the moment its files are known)
            self.want_watch(r["id"], 40)
            if not r["meta"]:
                self.tell("it plays as soon as its files are known")
            return
        can = [k for k, f in enumerate(files) if f and common.playable(f[0])]
        if not can:
            self.tell("nothing in it to play")
            return
        videos = [k for k in can if files[k][0].rpartition(".")[2].lower() in common.VIDEO]
        if len(videos) > 1:
            self.open_row(r)
            self.pane_focus = True
            return
        self.play_file(r, max(videos or can, key=lambda k: files[k][1]))

    def play_file(self, r, index):
        def answer(m):
            if m.get("err"):
                self.tell(m["err"])
            elif m.get("path"):
                self.play(m["path"])
            elif m.get("url"):
                self.play(m["url"])
            elif m.get("waiting"):
                self.wants_play = r["id"]
        self.send({"op": "stream", "id": r["id"], "file": index}, answer)

    def play(self, what):
        try:
            subprocess.Popen(["kawa-play", what], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        except OSError as e:
            self.tell(f"the player: {e.strerror}")

    def open_folder(self, r):
        files = self.files.get(r["id"]) or []
        first = next((f[0] for f in files if f), "")
        where = os.path.join(r["folder"], first.partition("/")[0]) if first else r["folder"]
        subprocess.Popen(["kawa-downloads", "open", "torrent", where], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)

    def key_files(self, k):
        r = self.selected_row()
        files = (self.files.get(r["id"]) if r else None) or []
        order = getattr(self, "file_order", [])
        if not r or not order:
            self.pane_focus = False
            return
        if k in ("esc", "h", "left", "q", "backspace", "tab", "shift-tab"):
            self.pane_focus = self.page = False
        elif k in ("j", "down"):
            self.file_cursor = min(len(order) - 1, self.file_cursor + 1)
        elif k in ("k", "up"):
            self.file_cursor = max(0, self.file_cursor - 1)
        elif k in ("pagedown", "ctrl-d"):
            self.file_cursor = min(len(order) - 1, self.file_cursor + self.page_size())
        elif k in ("pageup", "ctrl-u"):
            self.file_cursor = max(0, self.file_cursor - self.page_size())
        elif k in ("g", "home"):
            self.file_cursor = 0
        elif k in ("G", "end"):
            self.file_cursor = len(order) - 1
        elif k in ("space", "a", "n", "i"):
            self.choose_files(r, files, order, k)
        elif k == "enter":
            f = order[self.file_cursor]
            if common.playable(files[f][0]):
                self.play_file(r, f)
            else:
                self.choose_files(r, files, order, "space")
        else:
            self.key_list(k)

    def choose_files(self, r, files, order, k):
        det = self.detail.get(r["id"]) or {}
        prios = list(det.get("priorities") or [4] * len(files))
        at = order[self.file_cursor]
        for f in order:
            if k == "a":
                prios[f] = prios[f] or 4
            elif k == "n":
                prios[f] = 0
            elif k == "i":
                prios[f] = 0 if prios[f] else 4
        if k == "space":
            prios[at] = 0 if prios[at] else 4
        det["priorities"] = prios                  # (shown at once; the engine's next word confirms it)
        self.detail[r["id"]] = det
        self.send({"op": "files", "id": r["id"], "priorities": prios})

    def key_filter(self, k):
        if k == "esc":
            self.filter = None
            return True
        if k == "enter":
            r = self.selected_row()
            if r:
                self.open_row(r)
            return True
        if k in ("up", "down", "pageup", "pagedown"):
            return False
        if len(k) == 1:
            self.filter.put(k)
            return True
        return self.filter.key(k)

    def key_adding(self, k):
        if k == "esc":
            self.adding = None
        elif k == "enter":
            text = self.adding.text
            self.adding = None
            if text.strip():
                self.add_link(text)
        elif k == "ctrl-o":
            self.pick_file()
        elif len(k) == 1:
            self.adding.put(k)
        else:
            self.adding.key(k)

    def pick_file(self):
        """The file dialog's own yazi, in this terminal: back here with what was chosen."""
        import tempfile
        with tempfile.NamedTemporaryFile("r", prefix="kawa-torrents.", dir=common.RUN, delete=True) as f:
            self.t.leave()
            try:
                subprocess.run(["yazi", "--chooser-file", f.name, common.DOWNLOADS], check=False)
            except OSError as e:
                self.tell(f"yazi: {e.strerror}")
            self.t.enter()
            f.seek(0)
            chosen = f.read().strip().split("\n")[0]
        if chosen:
            self.adding = None
            self.add_link(chosen)

    def key_find(self, k):
        if self.line_focus:
            if k == "enter":
                self.start_search()
            elif k == "esc":
                if self.query.text:
                    self.query = Line()
                elif self.results:
                    self.line_focus = False
                else:
                    self.switch_tab()
            elif k in ("tab", "shift-tab"):
                self.switch_tab()
            elif k == "down":
                if self.results:
                    self.line_focus = False
            elif k == "up":
                pass
            elif len(k) == 1:
                self.query.put(k)
            else:
                self.query.key(k)
            return
        if k in ("/", "esc"):
            self.line_focus = True
            self.query.at = len(self.query.text)
            return
        if k == "up" and self.items and self.items[0].get("id") == self.cursor_id:
            self.line_focus = True
            return
        if self.key_common(k):
            return
        r = next((it["row"] for it in self.items if it.get("id") == self.cursor_id and it["kind"] == "result"), None)
        if k == "q":
            self.quit = True
        elif k == "s":
            self.sort = (self.sort + 1) % len(SORTS)
        elif not r:
            return
        elif k in ("enter", "space"):
            self.add_result(r)
        elif k == "v":
            self.add_result(r, play=True)
        elif k == "y":
            self.copy_result(r)

    def on_mouse(self, kind, x, y):
        if self.ask:
            return
        if kind == "release":
            return
        if kind in ("wheel-up", "wheel-down"):
            self.on_wheel(-3 if kind == "wheel-up" else 3, x)
            return
        if y <= 1 and kind == "press":
            for a, b, name in self.tab_hits:
                if a <= x < b and name != self.tab:
                    self.switch_tab()
                    return
        pane_x = getattr(self, "pane_x", None)
        if pane_x is not None and self.pane_shown(self.t.cols) and x >= pane_x - 1:
            if kind == "press":
                self.click_file(y)
            return
        it = self.mouse_map.get(y)
        if it is None:
            return
        self.find_moved = self.tab == "find"
        if kind == "move":
            if not self.pane_focus and self.adding is None:
                self.cursor_id = it["id"]
        elif kind == "press":
            self.cursor_id = it["id"]
            self.pane_focus = False
            self.on_key("enter")
        elif kind == "press-right" and it["kind"] == "row":
            self.cursor_id = it["id"]
            self.copy_row(it["row"])

    def click_file(self, y):
        order = getattr(self, "file_order", [])
        at = self.file_top + y - getattr(self, "file_y", 0)
        if 0 <= at < len(order) and y >= getattr(self, "file_y", 0):
            self.pane_focus = True
            self.file_cursor = at
            self.key_files("space")

    def on_wheel(self, step, x):
        if self.pane_focus or (self.pane_shown(self.t.cols) and x >= getattr(self, "pane_x", 10 ** 6)):
            self.file_top = max(0, self.file_top + step)
            if self.pane_focus:
                self.file_cursor = max(0, self.file_cursor + step)
            return
        self.move(step)

    # ── the loop ────────────────────────────────────────────────────────────────────────────
    def run(self):
        signal.signal(signal.SIGWINCH, lambda *_: self.wake())
        signal.signal(signal.SIGTERM, self.on_signal)
        signal.signal(signal.SIGHUP, self.on_signal)
        self.t.enter()
        self.sel.register(self.t.fd_in, selectors.EVENT_READ, "tty")
        self.sel.register(self.wake_r, selectors.EVENT_READ, "queue")
        self.connect()
        self.look_for_offers()
        self.first_view = not self.first_links
        while not self.quit:
            if self.t.measure():
                self.watched = None
            self.tick()
            self.draw()
            wait = self.next_wait()
            for key, _ in self.sel.select(wait):
                if key.data == "tty":
                    self.on_tty()
                elif key.data == "queue":
                    self.on_queue()
                elif key.data == "engine":
                    if self.sock is not None:
                        self.on_engine()

    def wake(self):
        try:
            os.write(self.wake_w, b".")
        except OSError:
            pass

    def on_signal(self, *_):
        self.quit = True
        self.wake()

    def moving(self):
        """Is anything on the screen moving? Then the next frame comes on the beat; else nothing is drawn at all."""
        if not self.focused:
            return False
        if self.tab == "find":
            return self.pending_sites > 0
        return any(("stream" in r or r["word"] in ("finding", "asking", "checking", "moving")
                    or (r["word"] == "downloading" and r["down"] > 0)) for r in self.rows.values())

    def tick(self):
        now = time.monotonic()
        if now - self.last_anim >= ANIM:
            self.last_anim = now
            self.frame_n += 1
        if not self.connected and now - self.tried >= 1:
            self.connect()

    def next_wait(self):
        waits = []
        now = time.monotonic()
        if self.moving():
            waits.append(max(0.0, self.last_anim + ANIM - now))
        if now < self.say_until:
            waits.append(self.say_until - now)
        if not self.connected:
            waits.append(1.0)
        return min(waits) if waits else None


def cut_file(name, n):
    """A file's name in N columns: cut at a word, its type kept (a video stays a video)."""
    if cells(name) <= n:
        return name
    stem, dot, end = name.rpartition(".")
    if not dot or len(end) > 5 or n <= len(end) + 4:
        return cut(name, n)
    return cut(stem, n - len(end) - 1) + "." + end


def keys_spans(keys, w):
    """As many of KEYS as fit in W, whole; four columns between two."""
    out, used = [], 0
    for key, what, state in keys:
        n = cells(key) + 2 + cells(what) + (2 + cells(state) if state else 0)
        if used + (4 if used else 0) + n > w:
            break
        if used:
            out.append("    ")
            used += 4
        out += [key, "  ", (what, MUTED)]
        if state:
            out += ["  ", (state, STRONG)]
        used += n
    return out


def pad_to(spans, n):
    used = sum(cells(s if isinstance(s, str) else s[0]) for s in spans)
    return spans + [" " * max(0, n - used)]


def age_words(hours):
    h = int(hours or 0)
    if h < 24:
        return f"{h} h" if h else ""               # (a site that gives no date says "now": nothing is said)
    d = h // 24
    if d < 60:
        return f"{d} days" if d > 1 else "1 day"
    if d < 730:
        return f"{d // 30} months"
    return f"{d // 365} years"


def cat_icon(categories):
    for c in categories or ():
        i = c.get("id", 0) if isinstance(c, dict) else 0
        for base, name in CATEGORY:
            if base <= i < base + 1000:
                return name
    return "FILE"


def home_short(path):
    return "~" + path[len(common.HOME):] if path.startswith(common.HOME) else path


def shared_folder(paths):
    """What every path starts with, whole folders: the torrent's own name, said once in its heading."""
    if not paths:
        return ""
    first = paths[0]
    cut_at = first.rfind("/") + 1
    while cut_at and not all(p.startswith(first[:cut_at]) for p in paths):
        cut_at = first.rfind("/", 0, cut_at - 1) + 1
    return first[:cut_at]


def hold_window():
    """The lock that says a window is open (kawa-downloads' menu, a link opened elsewhere): gone with this process."""
    f = open(common.WINDOW, "a")
    try:
        fcntl.flock(f, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        f.close()
        return None
    return f


def run_window(first_links=()):
    lock = hold_window()
    if lock is None:
        return None
    app = App(first_links)
    try:
        app.run()
    finally:
        app.t.leave()
    if app.prowlarr_woken:
        subprocess.Popen(["kawa-prowlarr", "--idle"], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    return 0
