"""The engine: libtorrent's session, kept apart from the window so a download goes on when the window
closes, and a window, a magnet link or the bar can all talk to the one session.

systemd starts it on the first connection to its socket (kawa-torrents.socket; autostart.sh too, at
login, while downloads are unfinished) and it ends by itself, its state saved, 30 s after there is no
window and nothing left to download: nothing runs and no memory is held while nothing is wanted.

It speaks JSON lines on the socket. A client sends {"op": …, "n": 1, …} and gets {"re": 1, "ok": true, …}
back; it is told {"ev": "rows", "rows": […], "gone": […]} with what changed, once a second, and about
the torrent it watches {"ev": "detail", …}. Every torrent is in STATE as ID.resume, libtorrent's own
resume data (the .torrent inside once known): nothing is fetched or hashed again at a start, and the
other small things in state.json. A link of Prowlarr's holds its API key: kept in memory only, never
written. Each finished torrent says so once (kawa-downloads notice), remembered in state.json: never
again at a start, and never for bytes that were already on the disk.
"""
import base64
import fcntl
import json
import mimetypes
import os
import secrets
import selectors
import signal
import socket
import sys
import threading
import time
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import libtorrent as lt

import common
from common import STATE, SOCK, RUN, DOWNLOADS

LOCAL = os.environ.get("KAWA_TORRENTS_NET") == "local"     # (the tests' swarm: this computer alone)
IDLE = float(os.environ.get("KAWA_TORRENTS_IDLE", 30))     # seconds with nothing to do before it ends
TICK = 1.0                                                 # seconds between looks at the torrents
PORT = 6881                                                # the firewall's (setup.sh open_ports)
STATUS_EVERY = 2.0                                         # the bar's list ($RUN/kawa-downloads/torrent.PID)
SAVE_EVERY = 300                                           # a power cut costs at most this much hashing
FETCH_TRIES = 3                                            # a link of Prowlarr's: its site may be slow
FETCH_WAIT = 60
STREAM_HEAD = 8 << 20                                      # what must be there before the player opens
STREAM_TAIL = 2 << 20                                      # (a file's index often lies at its end)
STREAM_WINDOW = 32 << 20                                   # how far ahead of the player pieces are rushed
STREAM_LINGER = 20                                         # seconds after the player leaves

# answering from here on 4 Nov 2026 (a BEP 15 connect to each of 30 public trackers; the list torrra
# added to every link had half of it dead). A magnet with no trackers of its own still has the DHT
TRACKERS = ["udp://open.stealth.si:80/announce", "udp://tracker.torrent.eu.org:451/announce",
            "udp://exodus.desync.com:6969/announce", "udp://open.demonii.com:1337/announce",
            "udp://tracker.dler.org:6969/announce", "udp://tracker-udp.gbitt.info:80/announce",
            "udp://tracker.peerfect.org:6969/announce", "udp://ipv4announce.sktorrent.eu:6969/announce",
            "udp://tracker.opentrackr.org:1337/announce"]
ROUTERS = "dht.libtorrent.org:25401,router.bittorrent.com:6881,router.utorrent.com:6881,dht.transmissionbt.com:6881"
PAUSED, AUTO, SEQUENTIAL = lt.torrent_flags.paused, lt.torrent_flags.auto_managed, lt.torrent_flags.sequential_download
UPLOAD_ONLY = lt.torrent_flags.upload_mode        # (where libtorrent puts a torrent that met a full disk: no error on it, 20 minutes)
PAD = lt.file_storage.flag_pad_file
ST = lt.torrent_status
SAVE_FLAGS = lt.torrent_handle.save_info_dict | lt.torrent_handle.flush_disk_cache
# (status_flags_t's query_name and query_save_path: bits 6 and 7 of torrent_handle.hpp, not named by the binding)
QUERY_NAME, QUERY_FOLDER = 1 << 6, 1 << 7
QUERY = QUERY_NAME | QUERY_FOLDER


def say(*words):
    print("kawa-torrents:", *words, file=sys.stderr, flush=True)


def write_file(path, data):
    """Whole or not at all: a power cut leaves the old file or the new one."""
    new = f"{path}.new"
    with open(new, "wb") as f:
        f.write(data)
        f.flush()
        os.fsync(f.fileno())
    os.replace(new, path)


def tid(h_or_status):
    """A torrent's id: its info hash in hex (the v1 one if it has one: as a magnet link names it)."""
    hashes = h_or_status.info_hashes
    hashes = hashes() if callable(hashes) else hashes
    return str(hashes.v1 if hashes.has_v1() else hashes.v2)


class Pending:
    """A torrent known only by a link still to be asked (Prowlarr's, a site's .torrent): a row until
    the answer comes. Memory only: the link holds the key."""
    __slots__ = ("id", "url", "name", "source", "err", "added", "tries", "stream")

    def __init__(self, url, name, source):
        self.id = "url-" + secrets.token_hex(6)
        self.url, self.name, self.source = url, name, source
        self.err, self.added, self.tries, self.stream = "", int(time.time()), 0, None


class Stream:
    """A file played while it comes: its pieces rushed from where the player reads, in order after that."""

    def __init__(self, h, index):
        self.h, self.index = h, index
        ti = h.torrent_file()
        fs = ti.files()
        self.token = secrets.token_urlsafe(16)
        self.name = fs.file_name(index)
        self.path = os.path.join(h.status(QUERY_FOLDER).save_path, fs.file_path(index))
        self.size = fs.file_size(index)
        self.start = fs.file_offset(index)
        self.plen = ti.piece_length()
        self.first = self.piece_at(0)
        self.last = self.piece_at(max(0, self.size - 1))
        self.readers = 0
        self.left_at = time.monotonic()
        self.ready = False
        self.head = -1
        self.gone = False
        # what must be there before the player opens: its first pieces and its last
        head = range(self.first, min(self.last, self.piece_at(min(STREAM_HEAD, self.size - 1))) + 1)
        tail = range(max(self.first, self.piece_at(max(0, self.size - STREAM_TAIL))), self.last + 1)
        self.need = sorted(set(head) | set(tail))
        self.rush()

    def rush(self):
        h = self.h
        h.unset_flags(AUTO)
        h.resume()
        h.set_flags(SEQUENTIAL)
        h.file_priority(self.index, 7)
        for k, p in enumerate(self.need):
            h.set_piece_deadline(p, 400 + 150 * k)

    def piece_at(self, offset):
        return (self.start + offset) // self.plen

    def piece_end(self, piece):
        return (piece + 1) * self.plen - self.start

    def buffered(self):
        return sum(1 for p in self.need if self.h.have_piece(p)) / max(1, len(self.need))

    def want(self, piece):
        """The player reads PIECE now: the ones ahead of it rushed; a jump drops the old rush."""
        if piece == self.head:
            return
        window = max(4, STREAM_WINDOW // self.plen)
        near = self.head <= piece <= self.head + window // 2
        # (reading on: only the pieces new to the window; small pieces mean thousands in it, at every step)
        start = self.head + window + 1 if near and self.head >= 0 else piece
        if not near:
            self.h.clear_piece_deadlines()
        self.head = piece
        for p in range(start, min(self.last, piece + window) + 1):
            if not self.h.have_piece(p):
                self.h.set_piece_deadline(p, 300 + 120 * (p - piece))

    def wait(self, piece, alive):
        """True once PIECE is on the disk; False if the stream ended or the player left meanwhile."""
        while not self.h.have_piece(piece):
            if self.gone or not alive():
                return False
            time.sleep(0.05)
        return not self.gone

    def finish(self):
        self.gone = True
        h = self.h
        if not h.is_valid():
            return
        h.clear_piece_deadlines()
        h.unset_flags(SEQUENTIAL)
        if h.file_priority(self.index) == 7:
            h.file_priority(self.index, 4)
        s = h.status(0)
        if not s.flags & PAUSED:
            h.set_flags(AUTO)


class Player(BaseHTTPRequestHandler):
    """The file, by byte ranges, over this computer's own loopback: reads wait for their pieces."""
    protocol_version = "HTTP/1.1"
    engine = None

    def log_message(self, *a):
        pass

    def do_HEAD(self):
        self.serve(False)

    def do_GET(self):
        self.serve(True)

    def serve(self, body):
        token = self.path.lstrip("/").partition("/")[0]
        st = self.engine.stream_by_token(token)
        if st is None:
            self.send_error(404)
            return
        pos, end = 0, st.size - 1
        rng = self.headers.get("Range", "")
        ranged = rng.startswith("bytes=") and "," not in rng
        if ranged:
            a, _, b = rng[6:].partition("-")
            try:
                if a:
                    pos, end = int(a), int(b) if b else st.size - 1
                else:
                    pos, end = max(0, st.size - int(b)), st.size - 1
            except ValueError:
                ranged = False
        end = min(end, st.size - 1)
        if pos > end or pos < 0:
            self.send_response(416)
            self.send_header("Connection", "close")
            self.close_connection = True
            self.send_header("Content-Range", f"bytes */{st.size}")
            self.send_header("Content-Length", "0")
            self.end_headers()
            return
        self.send_response(206 if ranged else 200)
        # (said aloud: ffmpeg asks to close, and takes a server's silence for keeping the connection — its
        # next seek, on a socket closed under it, ended the film with "End of file")
        self.send_header("Connection", "close")
        self.close_connection = True
        self.send_header("Accept-Ranges", "bytes")
        self.send_header("Content-Type", mimetypes.guess_type(st.name)[0] or "application/octet-stream")
        self.send_header("Content-Length", str(end - pos + 1))
        if ranged:
            self.send_header("Content-Range", f"bytes {pos}-{end}/{st.size}")
        self.end_headers()
        if not body:
            return
        st.readers += 1
        fd = -1
        try:
            alive = self.connection_alive
            while pos <= end:
                piece = st.piece_at(pos)
                st.want(piece)
                if not st.wait(piece, alive):
                    return
                if fd < 0:
                    fd = os.open(st.path, os.O_RDONLY | os.O_CLOEXEC)
                n = min(end + 1, st.piece_end(piece), pos + (1 << 18)) - pos
                data = os.pread(fd, n, pos)
                if not data:
                    return
                self.wfile.write(data)
                pos += len(data)
        except (OSError, RuntimeError):            # (the player left: mpv seeks by closing; the torrent removed under it)
            self.close_connection = True
        finally:
            if fd >= 0:
                os.close(fd)
            st.readers -= 1
            st.left_at = time.monotonic()

    def connection_alive(self):
        """Still there? A closed socket reads as ready with nothing in it."""
        try:
            self.connection.setblocking(False)
            try:
                return self.connection.recv(1, socket.MSG_PEEK) != b""
            finally:
                self.connection.setblocking(True)
        except BlockingIOError:
            return True
        except OSError:
            return False


class Client:
    __slots__ = ("sock", "buf", "out", "watch", "sent_files", "cells", "trackers_at")

    def __init__(self, sock):
        self.sock, self.buf, self.out = sock, b"", bytearray()
        self.watch, self.sent_files, self.cells, self.trackers_at = None, None, 40, 0.0


class Engine:
    def __init__(self, listener):
        os.makedirs(STATE, mode=0o700, exist_ok=True)
        self.lock = open(os.path.join(STATE, "lock"), "w")
        try:
            fcntl.flock(self.lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            say("another engine has these torrents")
            sys.exit(0)
        self.listener = listener
        self.sel = selectors.DefaultSelector()
        self.clients = []
        self.handles = {}                          # id → torrent_handle
        self.rows = {}                             # id → what clients were last told
        self.pend = {}                             # id → Pending
        self.streams = {}                          # id → Stream
        self.saving = 0
        self.said = 0
        self.woken = {}                            # id → its files' choice: added anew once its resume data is written
        self.dirty = False
        self.stopping = False
        self.last_status = self.last_save = self.last_update = 0.0
        self.idle_since = time.monotonic()
        self.wanting_mark = None
        self.http = None
        self.results = []                          # what the fetching threads have found
        self.results_lock = threading.Lock()
        self.meta = self.read_state()
        self.ses = self.make_session()
        self.wake_r, self.wake_w = os.pipe2(os.O_NONBLOCK | os.O_CLOEXEC)
        self.alert_r, self.alert_w = os.pipe2(os.O_NONBLOCK | os.O_CLOEXEC)
        self.ses.set_alert_fd(self.alert_w)
        self.status_path = os.path.join(RUN, "kawa-downloads", f"torrent.{os.getpid()}")
        self.load_torrents()

    # ── what is kept ────────────────────────────────────────────────────────────────────────
    def read_state(self):
        try:
            with open(os.path.join(STATE, "state.json"), encoding="utf-8") as f:
                meta = json.load(f)
        except FileNotFoundError:
            meta = {}
        except (OSError, ValueError) as e:
            say(f"state.json could not be read ({e}): starting from its defaults")
            meta = {}
        meta.setdefault("told", {})
        meta.setdefault("source", {})
        meta.setdefault("turtle", False)
        return meta

    def save_state(self):
        if self.dirty:
            self.dirty = False
            try:
                write_file(os.path.join(STATE, "state.json"), json.dumps(self.meta).encode())
            except OSError as e:
                say(f"state.json could not be saved: {e}")

    def make_session(self):
        settings = {
            "alert_mask": lt.alert_category.status | lt.alert_category.storage | lt.alert_category.error,
            "alert_queue_size": 4000,
            "listen_interfaces": "127.0.0.1:0" if LOCAL else f"0.0.0.0:{PORT},[::]:{PORT}",
            "enable_dht": not LOCAL, "dht_bootstrap_nodes": ROUTERS,
            # nothing announced on the LAN, no port opened on the router behind your back
            "enable_lsd": False, "enable_upnp": False, "enable_natpmp": False,
            "announce_to_all_trackers": True, "announce_to_all_tiers": True,
            # many at once, a slow one never holding up the rest
            "active_downloads": 8, "active_seeds": 16, "active_limit": 200, "active_checking": 2,
            "dont_count_slow_torrents": True,
            "allow_multiple_connections_per_ip": LOCAL,
            "aio_threads": 4, "hashing_threads": 2,
        }
        ses = lt.session(settings)
        if not LOCAL:
            try:                                   # the DHT's nodes of last time: first peers in seconds, not a minute
                with open(os.path.join(STATE, "dht"), "rb") as f:
                    ses.load_state(lt.bdecode(f.read()))
            except FileNotFoundError:
                pass
            except (OSError, RuntimeError, ValueError, TypeError, AttributeError) as e:
                say(f"the DHT's nodes of last time could not be read: {e}")
        self.apply_turtle(ses)
        return ses

    def apply_turtle(self, ses=None):
        on = self.meta["turtle"]
        (ses or self.ses).apply_settings({"download_rate_limit": (1 << 20) if on else 0,
                                          "upload_rate_limit": (200 << 10) if on else 0})

    def load_torrents(self):
        for name in sorted(os.listdir(STATE)):
            if not name.endswith(".resume"):
                continue
            path = os.path.join(STATE, name)
            try:
                with open(path, "rb") as f:
                    atp = lt.read_resume_data(f.read())
                self.remember(self.ses.add_torrent(atp))
            except (OSError, RuntimeError, ValueError) as e:
                say(f"{name} could not be read ({e}): set aside as {name}.bad")
                self.try_rename(path, path + ".bad")
        self.load_inherited()

    def try_rename(self, a, b):
        try:
            os.replace(a, b)
        except OSError as e:
            say(f"could not rename {a}: {e}")

    def load_inherited(self):
        """inherited.json — what `kawa-torrents inherit` read from an older program's list."""
        path = os.path.join(STATE, "inherited.json")
        try:
            with open(path, encoding="utf-8") as f:
                items = json.load(f)
        except FileNotFoundError:
            return
        except (OSError, ValueError) as e:
            say(f"inherited.json could not be read: {e}")
            return
        for it in items:
            try:
                atp = lt.parse_magnet_uri(it["magnet"])
                atp.save_path = it.get("folder") or DOWNLOADS
                atp.flags = (atp.flags & ~lt.torrent_flags.duplicate_is_error) | AUTO
                if it.get("paused"):
                    atp.flags = (atp.flags | PAUSED) & ~AUTO
                if it.get("priorities"):
                    atp.file_priorities = [int(p) for p in it["priorities"]]
                if it.get("name"):
                    atp.name = it["name"]
                self.give_trackers(atp)
                h = self.ses.add_torrent(atp)
                i = self.remember(h)
                if it.get("told"):
                    self.meta["told"][i] = 1
                if it.get("source"):
                    self.meta["source"][i] = it["source"]
                self.dirty = True
                h.save_resume_data(SAVE_FLAGS)
                self.saving += 1
            except (RuntimeError, ValueError, KeyError, TypeError) as e:
                say(f"an inherited torrent could not be added: {e}")
        self.save_state()
        os.remove(path)

    def remember(self, h):
        i = tid(h)
        self.handles[i] = h
        return i

    def give_trackers(self, atp):
        if not LOCAL:
            have = set(atp.trackers)
            atp.trackers = list(atp.trackers) + [t for t in TRACKERS if t not in have]

    # ── adding ──────────────────────────────────────────────────────────────────────────────
    def add(self, kind, value, name="", source="", also="", paused=False):
        """A magnet, a .torrent's contents or a link → (id, already there?, what went wrong). ALSO: a link that
        may know the torrent's own trackers (Prowlarr's), asked in the background."""
        try:
            if kind == "url":
                return self.add_url(value, name, source)
            atp = lt.parse_magnet_uri(value) if kind == "magnet" else lt.add_torrent_params()
            if kind == "bytes":
                atp.ti = lt.torrent_info(lt.bdecode(value))
            return self.add_params(atp, name, source, also, paused)
        except (RuntimeError, ValueError, OSError) as e:
            what = "not a torrent" if kind == "bytes" else "not a link that can be read"
            return None, False, f"{what} ({e})"

    def add_params(self, atp, name="", source="", also="", paused=False):
        hashes = atp.ti.info_hashes() if atp.ti else atp.info_hashes
        i = str(hashes.v1 if hashes.has_v1() else hashes.v2)
        if i in self.handles and self.handles[i].is_valid():
            h = self.handles[i]
            if atp.ti is not None and not h.status(0).has_metadata:
                h.set_metadata(atp.ti.info_section())
            for t in atp.trackers:
                h.add_tracker({"url": t})
            if also:
                self.fetch_for_trackers(also, i)
            return i, True, ""
        atp.save_path = DOWNLOADS
        os.makedirs(DOWNLOADS, exist_ok=True)
        atp.flags = (atp.flags & ~lt.torrent_flags.duplicate_is_error) | AUTO
        if paused:
            atp.flags = (atp.flags | PAUSED) & ~AUTO
        if name and not atp.name:
            atp.name = name
        private = atp.ti is not None and atp.ti.priv()
        if not private:
            self.give_trackers(atp)
        h = self.ses.add_torrent(atp)
        i = self.remember(h)
        if source:
            self.meta["source"][i] = source
            self.dirty = True
        self.save_resume(h)
        if also:
            self.fetch_for_trackers(also, i)
        self.idle_since = time.monotonic()
        self.update_now()
        return i, False, ""

    def add_url(self, url, name, source):
        for p in self.pend.values():
            if p.url == url:
                return p.id, True, ""
        p = Pending(url, name or common.without_key(url).rpartition("/")[2] or "a link", source)
        self.pend[p.id] = p
        self.fetch(p)
        self.push_rows()
        return p.id, False, ""

    def fetch(self, p):
        p.err, p.tries = "", p.tries + 1
        threading.Thread(target=self.fetch_thread, args=(p,), daemon=True).start()

    def fetch_for_trackers(self, url, i):
        threading.Thread(target=self.fetch_trackers_thread, args=(url, i), daemon=True).start()

    def fetch_trackers_thread(self, url, i):
        try:
            kind, value = common.fetch_link(url, 15)
        except common.FetchFailed:
            return                                 # (the hash was enough to start: only a few more sources lost)
        self.post(("trackers", i, common.magnet_trackers(value) if kind == "magnet" else []))

    def fetch_thread(self, p):
        """Prowlarr asks the site for it: seconds as a rule, up to a minute for a slow one. Asked again
        twice when the site is the trouble; what it says at last stands on the row, in words."""
        err = ""
        for attempt in range(FETCH_TRIES):
            try:
                kind, value = common.fetch_link(p.url, FETCH_WAIT)
                self.post(("fetched", p.id, kind, value))
                return
            except common.FetchFailed as e:
                err = str(e)
                if e.final:
                    break
                time.sleep(1.5 * (attempt + 1))
        self.post(("failed", p.id, err))

    def post(self, item):
        with self.results_lock:
            self.results.append(item)
        try:
            os.write(self.wake_w, b".")
        except BlockingIOError:
            pass

    def take_results(self):
        with self.results_lock:
            items, self.results = self.results, []
        for it in items:
            if it[0] == "trackers":
                h = self.handles.get(it[1])
                if h is not None and h.is_valid():
                    for t in it[2]:
                        h.add_tracker({"url": t})
            elif it[0] == "fetched":
                p = self.pend.pop(it[1], None)
                if p is None:
                    continue
                i, _, err = self.add(it[2], it[3], p.name, p.source)
                if err:
                    p.err = err
                    self.pend[p.id] = p
                else:
                    self.moved(p.id, i)
                self.push_rows()
            elif it[0] == "failed":
                p = self.pend.get(it[1])
                if p is not None:
                    p.err = it[2]
                    self.push_rows()

    def moved(self, old, new):
        """A link's row became a torrent: a window with its cursor there follows."""
        self.tell({"ev": "moved", "from": old, "to": new})

    def remove(self, i, files):
        if i in self.pend:
            del self.pend[i]
            self.push_rows()
            return
        h = self.handles.pop(i, None)
        if h is None:
            return
        self.woken.pop(i, None)
        st = self.streams.pop(i, None)
        if st is not None:
            st.gone = True
        if h.is_valid():
            self.ses.remove_torrent(h, lt.session.delete_files if files else lt.session.delete_partfile)
        for tail in (".resume", ".resume.new"):
            try:
                os.remove(os.path.join(STATE, i + tail))
            except FileNotFoundError:
                pass
            except OSError as e:
                say(f"could not remove {i}{tail}: {e}")
        for kept in ("told", "source", "errors", "gone"):
            self.meta.get(kept, {}).pop(i, None)
        self.dirty = True
        self.save_state()
        self.push_rows()

    def save_resume(self, h):
        if h.is_valid():
            try:
                h.save_resume_data(SAVE_FLAGS)
                self.saving += 1
            except RuntimeError as e:
                say(f"resume data not asked: {e}")

    # ── what libtorrent says ────────────────────────────────────────────────────────────────
    def on_alerts(self):
        try:
            os.read(self.alert_r, 65536)
        except BlockingIOError:
            pass
        self.drain()

    def drain(self):
        for a in self.ses.pop_alerts():
            if isinstance(a, lt.state_update_alert):
                self.on_status(a.status)
            elif isinstance(a, lt.save_resume_data_alert):
                self.saving -= 1
                self.on_resume(a)
            elif isinstance(a, lt.save_resume_data_failed_alert):
                self.saving -= 1
            elif isinstance(a, lt.torrent_finished_alert):
                self.on_finished(a.handle)
            elif isinstance(a, lt.metadata_received_alert):
                self.save_resume(a.handle)
            elif isinstance(a, lt.fastresume_rejected_alert):
                self.on_files_gone(a)
            elif isinstance(a, lt.file_error_alert):
                self.on_file_error(a)
            elif isinstance(a, lt.torrent_error_alert):
                say(f"torrent error: {a.message()}")
            elif isinstance(a, lt.listen_failed_alert):
                self.on_listen_failed(a)

    def on_listen_failed(self, a):
        # (another program on the port. No socket at all would mean no DHT and no uTP: any port then)
        say(f"port not free: {a.message()}")
        if not LOCAL and self.ses.listen_port() == 0:
            self.ses.apply_settings({"listen_interfaces": "0.0.0.0:0,[::]:0"})

    def on_files_gone(self, a):
        """Its files moved or deleted since (yazi, by hand): libtorrent would quietly start over, tens of gigabytes
        unasked. It stops; the row says so, and p fetches them again, or d takes it off the list."""
        i = tid(a.handle)
        say(f"{i}: resume data rejected: {a.message()}")
        if self.meta["told"].get(i) or a.handle.status(0).total_wanted_done:
            a.handle.unset_flags(AUTO)
            a.handle.pause()
            self.meta.setdefault("gone", {})[i] = 1
            self.dirty = True

    def on_resume(self, a):
        try:
            i = tid(a.handle)
            if i in self.handles:
                write_file(os.path.join(STATE, i + ".resume"), lt.write_resume_data_buf(a.params))
            if i in self.woken:                    # (below)
                prios = self.woken.pop(i)
                self.ses.remove_torrent(a.handle)
                a.params.flags |= lt.torrent_flags.update_subscribe   # (a live torrent's flags leave out this default)
                h = self.handles[i] = self.ses.add_torrent(a.params)
                if prios:                          # (this alert may be of a save asked before the choice was made)
                    h.prioritize_files(prios)
                st = self.streams.get(i)
                if st is not None:
                    st.h = h
                    st.rush()
                self.save_resume(h)
        except (OSError, RuntimeError) as e:
            say(f"resume data could not be written: {e}")

    def wake(self, h, i, prios=None):
        """A finished torrent wanted again (more of its files chosen, one played): libtorrent 2.0.11 lets its seeds go when
        it finishes and never again counts them as worth connecting to, not when asked, not at a tracker's word (measured:
        none in 130 s). Added anew from its resume data, nothing is lost and it connects at once (0.1 s)."""
        self.woken[i] = prios
        self.save_resume(h)

    def on_file_error(self, a):
        i, what = tid(a.handle), a.error.message().lower()
        told = self.meta.setdefault("errors", {})
        if told.get(i) != what:                    # (once for each thing that went wrong)
            say(f"{i}: {what}")
            told[i] = what
            self.dirty = True
            self.say_to_desktop("failed", common.reading(a.handle.status(QUERY_NAME).name), what)

    def on_finished(self, h):
        """Once for each torrent, and only for bytes that came over the network: never for a check that
        found everything already there, as at every start of the program before this one."""
        s = h.status(QUERY)
        i = tid(h)
        self.save_resume(h)
        if self.meta["told"].get(i):
            return
        self.meta["told"][i] = 1
        self.dirty = True
        self.save_state()
        if s.total_payload_download > 0 and s.total_wanted > 0:
            where = os.path.join(s.save_path, s.name) if s.name else s.save_path
            self.say_to_desktop("finished", common.reading(s.name) or "a torrent", str(s.total_wanted), where)

    def say_to_desktop(self, *fields):
        """A word for the session's watcher (kawa-downloads watch), a file of tab-separated fields it reads and takes away: the
        engine, walled in, starts no program and has no way to the screen. A session not there yet: it waits for it."""
        self.said += 1
        path = os.path.join(RUN, "kawa-downloads", f"said.{os.getpid()}.{self.said}")
        try:
            os.makedirs(os.path.dirname(path), mode=0o700, exist_ok=True)
            with open(path + ".new", "w", encoding="utf-8") as f:
                f.write("\t".join(x.replace("\t", " ").replace("\n", " ") for x in fields) + "\n")
            os.replace(path + ".new", path)
        except OSError as e:
            say(f"a word for the desktop could not be written: {e}")

    # ── rows ────────────────────────────────────────────────────────────────────────────────
    def trouble(self, s, i):
        """What stopped it, in words: libtorrent's own error; a full disk (it only stops writing); its files gone."""
        if s.errc.value():
            return s.errc.message().lower()
        if s.flags & UPLOAD_ONLY and i in self.meta.get("errors", ()):
            return self.meta["errors"][i]
        if i in self.meta.get("gone", ()):
            return "its files are gone"
        return ""

    def word(self, s, i):
        if self.trouble(s, i):
            return "failed"
        st = s.state
        if st == ST.checking_files:
            return "checking"
        if s.moving_storage:
            return "moving"
        if s.flags & PAUSED and not s.flags & AUTO:
            return "paused"
        if st == ST.downloading_metadata:
            return "finding"
        # (checking_resume_data, a moment at each start, says nothing: a finished one is finished all through it)
        if st in (ST.finished, ST.seeding) or (st == ST.checking_resume_data and s.total_wanted and s.total_wanted_done == s.total_wanted):
            return "done"
        if s.flags & PAUSED:
            return "queued"
        return "downloading"

    def row(self, s):
        i = tid(s)
        out = {"id": i, "name": common.safe(s.name) or i[:16], "word": self.word(s, i),
               "done": s.total_wanted_done, "total": s.total_wanted,
               "down": s.download_payload_rate, "up": s.upload_payload_rate,
               "peers": s.num_peers, "seeds": s.num_seeds, "known": max(s.list_peers, s.num_incomplete + s.num_complete, 0),
               "added": s.added_time, "at": s.completed_time, "progress": s.progress_ppm,
               "folder": s.save_path, "source": self.meta["source"].get(i, ""),
               "err": self.trouble(s, i), "meta": s.has_metadata,
               "ratio": round(s.all_time_upload / s.all_time_download, 2) if s.all_time_download else 0}
        st = self.streams.get(i)
        if st is not None:
            out["stream"] = {"file": st.index, "ready": st.ready, "buffered": round(st.buffered(), 3)}
        return out

    def pending_row(self, p):
        return {"id": p.id, "name": p.name, "word": "failed" if p.err else "asking", "done": 0, "total": 0,
                "down": 0, "up": 0, "peers": 0, "seeds": 0, "known": 0, "added": p.added, "at": 0, "progress": 0,
                "folder": DOWNLOADS, "source": p.source, "err": p.err, "meta": False, "ratio": 0}

    def on_status(self, statuses):
        changed = []
        for s in statuses:
            r = self.row(s)
            if self.rows.get(r["id"]) != r:
                self.rows[r["id"]] = r
                changed.append(r)
        self.push_changes(changed)

    def push_rows(self):
        """Everything that is not libtorrent's (a link's row, a torrent gone): told at once."""
        changed = []
        for p in self.pend.values():
            r = self.pending_row(p)
            if self.rows.get(p.id) != r:
                self.rows[p.id] = r
                changed.append(r)
        self.push_changes(changed)

    def push_changes(self, changed):
        gone = [i for i in self.rows if i not in self.handles and i not in self.pend]
        for i in gone:
            del self.rows[i]
        if changed or gone:
            self.tell({"ev": "rows", "rows": changed, "gone": gone})

    def update_now(self):
        self.ses.post_torrent_updates(QUERY)
        self.last_update = time.monotonic()

    def tell(self, msg):
        data = (json.dumps(msg, ensure_ascii=False, separators=(",", ":")) + "\n").encode()
        for c in list(self.clients):
            self.send(c, data)

    def send(self, c, data):
        c.out += data
        if len(c.out) > 16 << 20:                  # (a window that stopped reading: it can come back)
            self.drop(c)
            return
        self.flush(c)

    def flush(self, c):
        try:
            n = c.sock.send(c.out)
            del c.out[:n]
        except BlockingIOError:
            pass
        except OSError:
            self.drop(c)
            return
        self.sel.modify(c.sock, selectors.EVENT_READ | (selectors.EVENT_WRITE if c.out else 0), c)

    def drop(self, c):
        if c in self.clients:
            self.clients.remove(c)
            self.sel.unregister(c.sock)
            c.sock.close()
            self.idle_since = time.monotonic()

    # ── a torrent looked at ─────────────────────────────────────────────────────────────────
    def send_files(self, c, h, i):
        ti = h.torrent_file()
        fs = ti.files()
        files = []
        for k in range(fs.num_files()):
            if fs.file_flags(k) & PAD:
                files.append(None)
            else:
                files.append([common.safe(fs.file_path(k)), fs.file_size(k)])
        c.sent_files = i
        self.send(c, (json.dumps({"ev": "files", "id": i, "files": files}, ensure_ascii=False,
                                 separators=(",", ":")) + "\n").encode())

    def send_detail(self, c):
        i = c.watch
        h = self.handles.get(i)
        if h is None or not h.is_valid():
            return
        s = h.status(lt.torrent_handle.query_pieces)
        d = {"ev": "detail", "id": i, "pieces": cells_of(s.pieces, c.cells)}
        if time.monotonic() - c.trackers_at >= 5:  # (a nested list of every address of this computer: every 5 s is plenty)
            c.trackers_at = time.monotonic()
            d["trackers"] = trackers_of(h)
        if s.has_metadata:
            if c.sent_files != i:
                self.send_files(c, h, i)
            d["progress"] = h.file_progress(lt.torrent_handle.piece_granularity)
            d["priorities"] = [int(p) for p in h.get_file_priorities()]
        self.send(c, (json.dumps(d, separators=(",", ":")) + "\n").encode())

    # ── what a client asks ──────────────────────────────────────────────────────────────────
    def on_client(self, c, mask):
        if mask & selectors.EVENT_WRITE:
            self.flush(c)
            if c not in self.clients:
                return
        if not mask & selectors.EVENT_READ:
            return
        try:
            data = c.sock.recv(1 << 20)
        except BlockingIOError:
            return
        except OSError:
            self.drop(c)
            return
        if not data:
            self.drop(c)
            return
        c.buf += data
        *lines, c.buf = c.buf.split(b"\n")
        for line in lines:
            if c not in self.clients:
                return
            self.on_line(c, line)

    def on_line(self, c, line):
        n = None
        try:
            q = json.loads(line)
            n = q.get("n")
            answer = getattr(self, "op_" + q["op"])(c, q) or {}
        except (ValueError, KeyError, AttributeError, TypeError) as e:
            say(f"a request that made no sense: {e!r}")
            answer = {"err": "not understood"}
        except RuntimeError as e:                  # (libtorrent: a torrent removed under the request)
            answer = {"err": str(e)}
        if n is not None:
            self.send(c, (json.dumps({"re": n, **answer}, ensure_ascii=False, separators=(",", ":")) + "\n").encode())

    def handle(self, q):
        h = self.handles.get(q["id"])
        if h is None or not h.is_valid():
            raise RuntimeError("no such torrent")
        return h

    def op_hello(self, c, q):
        self.update_now()
        self.send(c, (json.dumps({"ev": "rows", "all": True, "rows": list(self.rows.values()), "gone": [],
                                  "turtle": self.meta["turtle"]}, ensure_ascii=False, separators=(",", ":")) + "\n").encode())

    def op_add(self, c, q):
        kind, value = q["kind"], q["value"]
        if kind == "torrent":
            kind, value = "bytes", base64.b64decode(value)
        i, known, err = self.add(kind, value, q.get("name", ""), q.get("source", ""), q.get("also", ""))
        return {"id": i, "known": known, "err": err}

    def clear_trouble(self, h, i):
        if h.status(0).errc.value():
            h.clear_error()
        h.unset_flags(UPLOAD_ONLY)
        if self.meta.get("errors", {}).pop(i, None):
            self.dirty = True

    def op_pause(self, c, q):
        h = self.handle(q)
        h.unset_flags(AUTO)
        h.pause()
        self.save_resume(h)
        self.update_now()

    def op_resume(self, c, q):
        h = self.handle(q)
        self.clear_trouble(h, q["id"])
        if self.meta.get("gone", {}).pop(q["id"], None):
            self.meta["told"].pop(q["id"], None)
            self.dirty = True
        h.set_flags(AUTO)
        h.resume()
        self.idle_since = time.monotonic()
        self.update_now()

    def op_pause_all(self, c, q):
        """All paused, or, when all are, all going on."""
        hs = [h for h in self.handles.values() if h.is_valid() and not h.status(0).is_finished]
        down = [h for h in hs if not h.status(0).flags & PAUSED or h.status(0).flags & AUTO]
        for h in down:
            h.unset_flags(AUTO)
            h.pause()
        if not down:
            for h in hs:
                h.set_flags(AUTO)
                h.resume()
        self.update_now()

    def op_retry(self, c, q):
        p = self.pend.get(q["id"])
        if p is not None:
            self.fetch(p)
            self.push_rows()
            return None
        h = self.handle(q)
        self.clear_trouble(h, q["id"])
        h.force_reannounce()
        h.force_dht_announce()
        self.update_now()
        return None

    def op_recheck(self, c, q):
        self.handle(q).force_recheck()
        self.update_now()

    def op_remove(self, c, q):
        self.remove(q["id"], bool(q.get("files")))

    def op_magnet(self, c, q):
        return {"magnet": lt.make_magnet_uri(self.handle(q))}

    def op_watch(self, c, q):
        c.watch, c.sent_files, c.trackers_at = q.get("id"), None, 0.0
        c.cells = max(1, min(int(q.get("cells", 40)), 400))
        if c.watch:
            self.send_detail(c)

    def op_files(self, c, q):
        """Which files are wanted: choosing more of a finished torrent makes it a download again."""
        h = self.handle(q)
        i = q["id"]
        prios = [int(p) for p in q["priorities"]]
        st = self.streams.get(i)
        if st is not None and prios[st.index] != 0:
            prios[st.index] = 7
        finished = h.status(0).is_finished
        h.prioritize_files(prios)
        if self.meta["told"].pop(i, None):
            self.dirty = True
            self.save_state()
        if finished:
            self.wake(h, i, prios)
        else:
            self.save_resume(h)
        self.idle_since = time.monotonic()
        self.update_now()

    def op_attention(self, c, q):
        """Someone opened Torrents, or a link, with its window elsewhere: the window is told to ask for you."""
        self.tell({"ev": "attention"})

    def op_turtle(self, c, q):
        self.meta["turtle"] = bool(q["on"])
        self.dirty = True
        self.save_state()
        self.apply_turtle()
        self.tell({"ev": "turtle", "on": self.meta["turtle"]})

    def op_stream(self, c, q):
        """Play a file while it comes: its URL once its head and tail are here. One already whole is its path."""
        h = self.handle(q)
        i = q["id"]
        if not h.status(0).has_metadata:
            return {"err": "its files are not known yet"}
        fs = h.torrent_file().files()
        index = int(q["file"])
        if not 0 <= index < fs.num_files() or fs.file_flags(index) & PAD:
            return {"err": "no such file"}
        if h.file_progress(lt.torrent_handle.piece_granularity)[index] >= fs.file_size(index):
            return {"path": os.path.join(h.status(QUERY_FOLDER).save_path, fs.file_path(index))}
        old = self.streams.pop(i, None)
        if old is not None and old.index != index:
            old.finish()
        elif old is not None:
            self.streams[i] = old
            if old.ready:
                return {"url": self.stream_url(old)}
            return {"waiting": True}
        finished = h.status(0).is_finished
        st = self.streams[i] = Stream(h, index)
        if finished:
            self.wake(h, i)
        self.start_http()
        self.update_now()
        self.check_streams()
        return {"url": self.stream_url(st)} if st.ready else {"waiting": True}

    def op_stream_stop(self, c, q):
        st = self.streams.pop(q["id"], None)
        if st is not None:
            st.finish()
        self.update_now()

    def stream_by_token(self, token):
        for st in list(self.streams.values()):
            if secrets.compare_digest(st.token, token):
                return st
        return None

    def stream_url(self, st):
        return f"http://127.0.0.1:{self.http.server_address[1]}/{st.token}/{urllib.parse.quote(st.name)}"

    def start_http(self):
        if self.http is None:
            handler = type("BoundPlayer", (Player,), {"engine": self})
            self.http = ThreadingHTTPServer(("127.0.0.1", 0), handler)
            self.http.daemon_threads = True
            threading.Thread(target=self.http.serve_forever, kwargs={"poll_interval": 1}, daemon=True).start()

    def check_streams(self):
        now = time.monotonic()
        for i, st in list(self.streams.items()):
            if not st.h.is_valid():
                del self.streams[i]
            elif not st.ready:
                if all(st.h.have_piece(p) for p in st.need):
                    st.ready = True
                    st.left_at = now
                    self.tell({"ev": "stream", "id": i, "url": self.stream_url(st), "name": st.name})
            elif st.readers <= 0 and now - st.left_at > STREAM_LINGER:
                del self.streams[i]
                st.finish()

    # ── the loop ────────────────────────────────────────────────────────────────────────────
    def coming(self, r):
        """Is this row something still to download? Not one told of already: a finished torrent taken over from torrra,
        looking for its files' list in a swarm that may be long dead, holds neither the bar nor this process."""
        return r["word"] in ("downloading", "finding", "checking", "queued", "moving") and not self.meta["told"].get(r["id"])

    def wanting(self):
        """Anything that needs this process alive: something to download, a player, a link being asked."""
        return bool(self.streams or self.pend) or any(self.coming(r) for r in self.rows.values())

    def mark_unfinished(self):
        """A file that says downloads are unfinished: the next login's autostart looks at it."""
        now = any(self.coming(r) for r in self.rows.values())
        if now != self.wanting_mark:
            self.wanting_mark = now
            path = os.path.join(STATE, "unfinished")
            try:
                if now:
                    open(path, "w").close()
                elif os.path.exists(path):
                    os.remove(path)
            except OSError as e:
                say(f"could not mark what is unfinished: {e}")

    def write_status(self):
        """What the bar shows (kawa-downloads' torrent.PID): the name, bytes done, bytes wanted, where."""
        lines = []
        for r in self.rows.values():
            if r["word"] == "asking" or (self.coming(r) and r["word"] != "queued"):
                where = os.path.join(r["folder"], r["name"]) if r["meta"] else r["folder"]
                lines.append("\t".join((r["name"].replace("\t", " "), str(r["done"]), str(r["total"]), where.replace("\t", " "))) + "\n")
        try:
            if lines:
                os.makedirs(os.path.dirname(self.status_path), mode=0o700, exist_ok=True)
                with open(self.status_path + ".new", "w", encoding="utf-8") as f:
                    f.writelines(lines)
                os.replace(self.status_path + ".new", self.status_path)
            elif os.path.exists(self.status_path):
                os.remove(self.status_path)
        except OSError as e:
            say(f"the bar's list could not be written: {e}")

    def tick(self):
        now = time.monotonic()
        self.drain()                               # (the alert pipe's word can be missed by a hair: never left for long)
        if now - self.last_update >= TICK:
            self.update_now()
        self.check_streams()
        self.mark_unfinished()
        for c in list(self.clients):
            if c.watch:
                self.send_detail(c)
        if now - self.last_status >= STATUS_EVERY:
            self.last_status = now
            self.write_status()
        if now - self.last_save >= SAVE_EVERY:
            self.last_save = now
            for h in self.handles.values():
                if h.is_valid() and h.need_save_resume_data():
                    self.save_resume(h)
        self.save_state()

    def on_wake(self):
        try:
            os.read(self.wake_r, 4096)
        except BlockingIOError:
            pass
        self.take_results()

    def on_accept(self):
        try:
            sock, _ = self.listener.accept()
        except OSError:
            return
        sock.setblocking(False)
        c = Client(sock)
        self.clients.append(c)
        self.sel.register(sock, selectors.EVENT_READ, c)
        self.idle_since = time.monotonic()

    def stop(self, *_):
        self.stopping = True
        try:
            os.write(self.wake_w, b".")
        except OSError:
            pass

    def run(self):
        signal.signal(signal.SIGTERM, self.stop)
        signal.signal(signal.SIGINT, self.stop)
        signal.signal(signal.SIGHUP, signal.SIG_IGN)
        self.listener.setblocking(False)
        self.sel.register(self.listener, selectors.EVENT_READ, "accept")
        self.sel.register(self.alert_r, selectors.EVENT_READ, "alerts")
        self.sel.register(self.wake_r, selectors.EVENT_READ, "wake")
        self.update_now()
        last = time.monotonic()
        self.last_save = last
        while not self.stopping:
            for key, mask in self.sel.select(max(0.0, TICK - (time.monotonic() - last))):
                if key.data == "accept":
                    self.on_accept()
                elif key.data == "alerts":
                    self.on_alerts()
                elif key.data == "wake":
                    self.on_wake()
                else:
                    self.on_client(key.data, mask)
            now = time.monotonic()
            if now - last >= TICK:
                last = now
                self.tick()
                if not self.clients and not self.wanting() and now - self.idle_since >= IDLE:
                    break
                if self.clients or self.wanting():
                    self.idle_since = now
        self.close()

    def close(self):
        """Everything saved: resume data for what changed, the DHT's nodes, the state. systemd gives 10 s."""
        for c in list(self.clients):
            self.drop(c)
        for st in self.streams.values():
            st.finish()
        self.ses.pause()
        for h in self.handles.values():
            if h.is_valid() and h.need_save_resume_data():
                self.save_resume(h)
        limit = time.monotonic() + 8
        while self.saving > 0 and time.monotonic() < limit:
            self.ses.wait_for_alert(200)
            self.drain()
        if not LOCAL:
            try:
                write_file(os.path.join(STATE, "dht"), lt.bencode(self.ses.save_state(lt.save_state_flags_t.save_dht_state)))
            except (OSError, RuntimeError, AttributeError) as e:
                say(f"the DHT's nodes could not be saved: {e}")
        self.save_state()
        self.mark_unfinished()
        try:
            os.remove(self.status_path)
        except OSError:
            pass


def cells_of(pieces, n):
    """The pieces drawn in N cells: for each, how much of it is here, 0 … 8."""
    total = len(pieces)
    if not total:
        return []
    if total <= n:
        return [8 if pieces[int(k * total / n)] else 0 for k in range(n)]
    out = []
    for k in range(n):
        a, b = k * total // n, (k + 1) * total // n
        have = sum(pieces[a:b])
        out.append((have * 8 + (b - a) // 2) // max(1, b - a) if have not in (0, b - a) else (8 if have else 0))
    return out


def trackers_of(h):
    """Each tracker: its address, and whether it answers, for the details. (An answer on one of the computer's
    addresses is an answer: loopback and link-local ones never reach a tracker, and always fail.)"""
    out = []
    for t in h.trackers():
        ends = t.get("endpoints") or ()
        state = ""
        if t.get("verified") or any(e.get("start_sent") for e in ends):
            state = "answers"
        elif any(e.get("updating") for e in ends):
            state = "asking"
        elif any(e.get("fails") for e in ends):
            state = "failed"
        out.append([common.safe(t.get("url", "")), state])
    return out


def main():
    fds = int(os.environ.get("LISTEN_FDS", "0"))
    if fds >= 1 and int(os.environ.get("LISTEN_PID", "0")) == os.getpid():
        listener = socket.socket(fileno=3)
    else:                                          # (no systemd in front of it: the tests)
        listener = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        try:
            os.unlink(SOCK)
        except FileNotFoundError:
            pass
        listener.bind(SOCK)
        listener.listen(16)
    os.set_inheritable(listener.fileno(), False)
    Engine(listener).run()
    return 0
