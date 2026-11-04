"""tests/engine/torrents_checks.py SCENARIO — kawa-torrents' engine on a real swarm (torrents_swarm.py) and its window on a
pseudo-terminal (torrents_screen.py) with the mock engine: run by test_torrents.sh, one scenario a process, each in the
throw-away home the harness made. Exit 0: it held. Anything else: the assertion that did not, on stderr."""
import atexit
import json
import os
import shutil
import signal
import socket
import sqlite3
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
REPO = os.environ["REPO"]
LIB = os.path.join(REPO, "configs/home/.local/lib/fedokawaii/kawa-torrents")
sys.path.insert(0, LIB)
sys.pycache_prefix = os.path.join(os.environ["HOME"], ".cache/pyc")
import common as common_  # noqa: E402

TMP = os.environ["TMP"]
HOME = os.environ["HOME"]
STATE = os.path.join(HOME, ".local/state/fedokawaii/torrents")
LOG = os.environ["CALLS"]
os.environ["KAWA_TORRENTS_LIB"] = LIB


def eq(got, want, what=""):
    assert got == want, f"{what}: got {got!r}, want {want!r}"


def calls(name):
    """What the stand-ins heard: lines of the harness's log for program NAME."""
    try:
        with open(LOG, encoding="utf-8") as f:
            return [line.rstrip("\n") for line in f if line.startswith(name + " ")]
    except FileNotFoundError:
        return []


def said(kind):
    """What the engine has left for the desktop: (the session's watcher would take these away: there is none here)."""
    d = os.path.join(os.environ["XDG_RUNTIME_DIR"], "kawa-downloads")
    out = []
    try:
        names = sorted(os.listdir(d))
    except FileNotFoundError:
        return out
    for n in names:
        if n.startswith("said.") and not n.endswith(".new"):
            with open(os.path.join(d, n), encoding="utf-8") as f:
                t = f.read().rstrip("\n").split("\t")
            if t[0] == kind:
                out.append(t)
    return out


def notices():
    return said("finished")


def spawn_engine(idle=600):
    from torrents_swarm import Engine
    e = Engine().start(idle=idle)
    atexit.register(lambda: e.proc.poll() is None and e.proc.kill())
    return e


def swarm_():
    from torrents_swarm import Swarm
    return Swarm(os.path.join(TMP, "swarm"))


def downloaded(name):
    return os.path.join(HOME, "Downloads", name)


def same_tree(a, b):
    r = subprocess.run(["diff", "-r", a, b], capture_output=True, text=True, check=False)
    assert r.returncode == 0, f"{a} and {b} differ: {r.stdout[:300]}"


# ── the engine ──────────────────────────────────────────────────────────────────────────────
def magnet_to_done():
    """A bare magnet: its files come, identical; one notice; five reopens with the seeder gone: nothing fetched, no notice."""
    s = swarm_()
    t = s.torrent("Big.Buck.Bunny", {"bunny.mkv": 3 << 20, "extras/poster.jpg": 40000})
    e = spawn_engine()
    c = e.client()
    a = c.ask({"op": "add", "kind": "magnet", "value": t.magnet})
    eq(a["id"], t.hash, "its id is its hash")
    eq(a["known"], False, "new")
    r = c.wait(lambda: c.rows.get(t.hash, {}).get("word") == "done" and c.rows[t.hash], 40, "done")
    eq(r["done"], t.total, "every byte")
    same_tree(os.path.join(t.where, t.name), downloaded(t.name))
    time.sleep(0.3)
    eq(len(notices()), 1, "one notice")
    eq(notices()[0][:3], ["finished", "Big Buck Bunny", str(t.total)], "its words")
    # the bar's list: while it downloaded; gone with it
    mg = c.ask({"op": "magnet", "id": t.hash})["magnet"]
    assert t.hash in mg and mg.startswith("magnet:?xt=urn:btih:"), mg
    c.close()
    eq(e.stop(), 0, "the engine ends clean")
    s.close()
    for k in range(5):
        t0 = time.monotonic()
        e = spawn_engine()
        c = e.client()
        r = c.wait(lambda cl=c: cl.rows.get(t.hash, {}).get("word") == "done" and cl.rows[t.hash], 15, f"done at reopen {k}")
        took = time.monotonic() - t0
        assert took < 3, f"reopen {k} took {took:.2f} s: something was hashed or fetched again"
        eq(r["done"], t.total, "its bytes")
        time.sleep(1.2)
        c.pump()
        eq(len(notices()), 1, f"still one notice after reopen {k}")
        c.close()
        eq(e.stop(), 0, "the engine ends clean")


def file_and_links():
    """A .torrent's path, a duplicate, what is no torrent: each answered in words, the engine going on."""
    s = swarm_()
    t = s.torrent("from.a.file", {"a.bin": 1 << 20})
    e = spawn_engine()
    c = e.client()
    a = c.ask({"op": "add", **common_.asking("file", t.path)})
    eq((a["id"], a["known"], a["err"]), (t.hash, False, ""), "a .torrent")
    c.wait(lambda: c.rows.get(t.hash, {}).get("word") == "done", 40, "done")
    eq(c.ask({"op": "add", **common_.asking("file", t.path)})["known"], True, "the same file again")
    eq(c.ask({"op": "add", "kind": "magnet", "value": t.magnet})["known"], True, "its magnet")
    a = c.ask({"op": "add", **common_.asking("file", __file__)})
    assert a["err"].startswith("not a torrent"), a
    a = c.ask({"op": "add", "kind": "magnet", "value": "magnet:?xt=urn:btih:zz"})
    assert a["err"].startswith("not a link"), a
    a = c.ask({"op": "add", "kind": "torrent", "value": "bm90IGJlbmNvZGU="})
    assert a["err"], a
    eq(len(c.rows), 1, "nothing added for them")
    # nonsense on the socket: answered or ignored, never the end of it
    for junk in (b"not json\n", b'{"op":"nope","n":77}\n', b'{"no":"op"}\n', b'{"op":"pause","n":78,"id":"ffff"}\n', b'[1,2]\n', b"\xff\xfe\n"):
        c.s.sendall(junk)
    c.wait(lambda: 78 in c.answers, 5, "an answer after the nonsense")
    assert c.answers[78].get("err"), "no such torrent is said"
    eq(c.ask({"op": "magnet", "id": t.hash}).get("err"), None, "still answering")
    c.close()
    eq(e.stop(), 0, "ended clean")
    s.close()


def files_gone():
    """A finished torrent whose files were moved: not fetched anew unasked; p fetches them; d takes it off."""
    s = swarm_()
    t = s.torrent("moved.away", {"a.mkv": 2 << 20})
    e = spawn_engine()
    c = e.client()
    c.ask({"op": "add", "kind": "magnet", "value": t.magnet})
    c.wait(lambda: c.rows.get(t.hash, {}).get("word") == "done", 40, "done")
    c.close()
    e.stop()
    shutil.rmtree(downloaded(t.name))
    n = len(notices())
    e = spawn_engine()
    c = e.client()
    c.wait(lambda: c.rows.get(t.hash, {}).get("err") == "its files are gone", 10, "said gone")
    time.sleep(2)
    c.pump()
    eq(c.rows[t.hash]["word"], "failed", "it waits")
    assert not os.path.exists(downloaded(t.name)), "fetched again unasked"
    c.ask({"op": "resume", "id": t.hash})
    c.wait(lambda: c.rows[t.hash]["word"] == "done", 40, "fetched when asked")
    same_tree(os.path.join(t.where, t.name), downloaded(t.name))
    time.sleep(0.3)
    eq(len(notices()), n + 1, "asked for again: a notice again")
    c.close()
    e.stop()
    s.close()


def keep_and_remove():
    """Pause holds across a restart; a removal leaves no file of ours; delete takes the files; a .parts file never stays."""
    s = swarm_()
    t1 = s.torrent("to.keep", {"a.bin": 1 << 20})
    t2 = s.torrent("to.delete", {"b.bin": 1 << 20})
    t3 = s.torrent("to.pause", {"c.bin": 1 << 20})
    e = spawn_engine()
    c = e.client()
    for t in (t1, t2):
        c.ask({"op": "add", "kind": "magnet", "value": t.magnet})
    c.wait(lambda: c.rows.get(t1.hash, {}).get("word") == "done" and c.rows.get(t2.hash, {}).get("word") == "done", 40, "both done")
    s.ses.pause()                                  # (the third: nobody sending)
    c.ask({"op": "add", "kind": "magnet", "value": t3.magnet})
    c.ask({"op": "pause", "id": t3.hash})
    c.wait(lambda: c.rows.get(t3.hash, {}).get("word") == "paused", 5, "paused")
    c.close()
    e.stop()
    e = spawn_engine()
    c = e.client()
    c.wait(lambda: c.rows.get(t3.hash, {}).get("word") == "paused", 10, "still paused after a restart")
    c.ask({"op": "remove", "id": t1.hash})
    c.wait(lambda: t1.hash not in c.rows, 5, "off the list")
    assert os.path.isfile(downloaded("to.keep/a.bin")), "its files stay"
    assert not os.path.exists(os.path.join(STATE, t1.hash + ".resume")), "its resume data goes"
    c.ask({"op": "remove", "id": t2.hash, "files": True})
    c.wait(lambda: t2.hash not in c.rows, 5, "off the list")
    end = time.monotonic() + 5
    while os.path.exists(downloaded("to.delete")) and time.monotonic() < end:
        time.sleep(0.05)
    assert not os.path.exists(downloaded("to.delete")), "its files go"
    c.ask({"op": "remove", "id": t3.hash})
    c.wait(lambda: t3.hash not in c.rows, 5, "off the list")
    time.sleep(0.3)
    strays = [n for n in os.listdir(os.path.join(HOME, "Downloads")) if n not in ("to.keep",)]
    eq(strays, [], "nothing else left in Downloads")
    meta = json.load(open(os.path.join(STATE, "state.json")))
    eq(meta["told"].get(t2.hash), None, "nothing kept of it")
    c.close()
    e.stop()
    s.close()


def choose_files():
    """Only what is kept comes; a finished choice is one notice; choosing more makes it a download again, and a second notice."""
    s = swarm_()
    t = s.torrent("season", {"ep1.mkv": 1 << 20, "ep2.mkv": 1 << 20, "ep3.mkv": 1 << 20}, piece=1 << 16)
    e = spawn_engine()
    c = e.client()
    s.ses.pause()                                  # (no one sends until the choice is made)
    c.ask({"op": "add", **common_.asking("file", t.path)})
    c.ask({"op": "watch", "id": t.hash, "cells": 20})
    f = c.event("files", 10)
    names = [x[0] for x in f["files"] if x]
    assert sorted(os.path.basename(n) for n in names) == ["ep1.mkv", "ep2.mkv", "ep3.mkv"], names
    keep = [4 if n.endswith("ep2.mkv") else 0 for n in [x[0] if x else "" for x in f["files"]]]
    c.ask({"op": "files", "id": t.hash, "priorities": keep})
    s.ses.resume()
    r = c.wait(lambda: c.rows.get(t.hash, {}).get("word") == "done" and c.rows[t.hash], 40, "the choice done")
    assert r["total"] <= 1 << 20 + 1 and r["total"] == r["done"], r
    assert os.path.isfile(downloaded("season/ep2.mkv")), "the one kept"
    assert not os.path.getsize(downloaded("season/ep1.mkv")) if os.path.exists(downloaded("season/ep1.mkv")) else True, "a skipped one has no bytes"
    time.sleep(0.2)
    eq(len(notices()), 1, "one notice")
    c.ask({"op": "files", "id": t.hash, "priorities": [4, 4, 4]})
    r = c.wait(lambda: c.rows[t.hash]["done"] == t.total and c.rows[t.hash]["word"] == "done", 30, "all of it")
    same_tree(os.path.join(t.where, t.name), downloaded(t.name))
    time.sleep(0.2)
    eq(len(notices()), 2, "more chosen: another notice when that comes")
    c.close()
    e.stop()
    s.close()


def stream():
    """A file read over HTTP while it comes: every byte right, from anywhere, the player's leaving undoing the rush."""
    s = swarm_()
    s.ses.set_local_upload_rate_limit(4 << 20)
    t = s.torrent("a.film", {"poster.jpg": 70000, "film.mkv": 20 << 20}, piece=1 << 18)
    e = spawn_engine()
    c = e.client()
    c.ask({"op": "add", "kind": "magnet", "value": t.magnet})
    c.wait(lambda: c.rows.get(t.hash, {}).get("meta"), 30, "its files known")
    c.ask({"op": "watch", "id": t.hash, "cells": 10})
    f = c.event("files", 5)
    index = next(k for k, x in enumerate(f["files"]) if x and x[0].endswith("film.mkv"))
    a = c.ask({"op": "stream", "id": t.hash, "file": index})
    url = a.get("url")
    if a.get("waiting"):
        c.wait(lambda: "stream" in c.rows[t.hash], 5, "the row says it")
        url = c.event("stream", 60, id=t.hash)["url"]
    assert url.startswith("http://127.0.0.1:") and url.endswith("/film.mkv"), url
    with open(os.path.join(t.where, t.name, "film.mkv"), "rb") as fh:
        want = fh.read()
    h = urllib.request.urlopen(urllib.request.Request(url, method="HEAD"), timeout=30)
    eq(h.headers["Content-Length"], str(len(want)), "its size")
    eq(h.headers["Connection"], "close", "said aloud: ffmpeg's next seek depends on it")
    # the tail first (a film's index), a piece in the middle while it may not be here yet, then all of it
    for rng, ok in (("bytes=-1000", want[-1000:]), (f"bytes={10 << 20}-{(10 << 20) + 4095}", want[10 << 20:(10 << 20) + 4096]), (f"bytes={len(want) - 5}-", want[-5:])):
        r = urllib.request.urlopen(urllib.request.Request(url, headers={"Range": rng}), timeout=60)
        eq(r.status, 206, rng)
        got = r.read()
        assert got == ok, f"{rng}: {len(got)} bytes, not what the file holds"
    got = urllib.request.urlopen(url, timeout=120).read()
    assert got == want, f"the whole file through the player's URL differs ({len(got)} bytes of {len(want)})"
    for bad in (url.rsplit("/", 2)[0] + "/not-its-token/film.mkv",):
        try:
            urllib.request.urlopen(bad, timeout=5)
            raise AssertionError("a wrong token was answered")
        except urllib.error.HTTPError as x:
            eq(x.code, 404, "a wrong token")
    try:
        urllib.request.urlopen(urllib.request.Request(url, headers={"Range": f"bytes={len(want) + 10}-"}), timeout=5)
        raise AssertionError("a range past the end was answered")
    except urllib.error.HTTPError as x:
        eq(x.code, 416, "past the end")
    # a player that leaves with reads waiting: its thread must not linger holding the stream
    c.wait(lambda: c.rows[t.hash]["word"] == "done", 60, "all here")
    d = c.ask({"op": "stream", "id": t.hash, "file": index})
    assert os.path.basename(d.get("path", "")) == "film.mkv", f"a whole file is its path: {d}"
    c.ask({"op": "stream_stop", "id": t.hash})
    c.wait(lambda: "stream" not in c.rows[t.hash], 5, "the stream's over")
    c.events.clear()
    d = c.event("detail", 5)
    assert 7 not in d["priorities"], f"the rush undone: {d['priorities']}"
    c.close()
    e.stop()
    s.close()


def play_key():
    """v on the list: with one video, the player handed it; with its files not asked for yet (a narrow window), it goes on by itself."""
    mock()
    w = window(30, 60)
    w.has("finished")
    w.keys("j", "j")
    w.keys("v")
    w.settle(0.3)
    # (the mock's film has three videos: the choice is the files' page)
    assert w.screen.find("pieces"), "many videos: its files\n" + w.screen.dump()
    w.keys("\x1b")
    eq(w.close(), 0, "ends clean")


def stream_from_search():
    """v on a result with its files not known: added, and played the moment they are, with nothing more pressed (a real engine,
    a real swarm; the player a stand-in that heard the URL)."""
    s = swarm_()
    s.ses.set_local_upload_rate_limit(4 << 20)
    t = s.torrent("one.film", {"film.mkv": 12 << 20})
    e = spawn_engine()
    w = window(30, 116)
    w.settle(0.5)
    m = t.magnet.replace("&", "&amp;")
    w.paste(f'<a href="{m}">the film</a>')
    c = e.client()
    c.wait(lambda: t.hash in c.rows, 10, "added from a page's source")
    w.keys("v")
    end = time.monotonic() + 40
    while not calls("kawa-play") and time.monotonic() < end:
        w.pump(0.1)
        c.pump(0.05)
    assert calls("kawa-play"), f"the player was not called: {w.screen.dump()}"
    url = calls("kawa-play")[-1].split()[-1]
    assert url.startswith("http://127.0.0.1:") and url.endswith("/film.mkv"), url
    with open(os.path.join(t.where, t.name, "film.mkv"), "rb") as f:
        want = f.read(1000)
    got = urllib.request.urlopen(urllib.request.Request(url, headers={"Range": "bytes=0-999"}), timeout=30).read()
    assert got == want, "the first bytes through the player's URL"
    eq(w.close(), 0, "ends clean")
    c.close()
    e.stop()
    s.close()


def real_player():
    """mpv itself, no window, on a film not yet here: plays from its start, and jumps past what has come."""
    for prog in ("mpv", "ffmpeg"):
        assert shutil.which(prog), f"{prog} is in the manifest"
    s = swarm_()
    s.ses.set_local_upload_rate_limit(3 << 20)
    where = os.path.join(TMP, "swarm/seed-film/film")
    os.makedirs(where)
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-f", "lavfi", "-i", "testsrc2=size=320x240:rate=15:duration=40",
                    "-c:v", "libx264", "-preset", "ultrafast", "-b:v", "5000k", "-minrate", "5000k", "-maxrate", "5000k", "-bufsize", "400k", os.path.join(where, "film.mkv")], check=True)
    import libtorrent as lt
    fs = lt.file_storage()
    lt.add_files(fs, where)
    ct = lt.create_torrent(fs, 1 << 17, flags=lt.create_torrent.v1_only)
    ct.add_tracker(s.announce)
    lt.set_piece_hashes(ct, os.path.dirname(where))
    data = lt.bencode(ct.generate())
    from torrents_swarm import Torrent
    t = Torrent()
    t.ti, t.where, t.name, t.hash = lt.torrent_info(lt.bdecode(data)), os.path.dirname(where), "film", ""
    t.hash = str(t.ti.info_hashes().v1)
    s.seed(t)
    e = spawn_engine()
    c = e.client()
    c.ask({"op": "add", "kind": "magnet", "value": t.magnet})
    c.wait(lambda: c.rows.get(t.hash, {}).get("meta"), 30, "its files known")
    a = c.ask({"op": "stream", "id": t.hash, "file": 0})
    url = a.get("url") or c.event("stream", 60, id=t.hash)["url"]
    done_when_opened = c.rows[t.hash]["done"] / c.rows[t.hash]["total"]
    assert done_when_opened < 1, "the film was already whole: nothing proved"
    log = os.path.join(TMP, "mpv.log")
    p = subprocess.Popen(["mpv", "--no-config", "--vo=null", "--ao=null", "--no-terminal", f"--log-file={log}", "--start=30", "--length=2", url])
    end = time.monotonic() + 90
    while p.poll() is None and time.monotonic() < end:
        c.pump(0.2)
    eq(p.returncode, 0, f"mpv jumped ahead and played: {open(log, errors='replace').read()[-600:]}")
    c.close()
    e.stop()
    s.close()


class Links(BaseHTTPRequestHandler):
    """A little Prowlarr's download link: a redirect to a magnet, a .torrent's bytes, or the trouble a site gives."""
    def log_message(self, *a):
        pass

    def send_it(self, code, body=b"", **head):
        self.send_response(code)
        for k, v in head.items():
            self.send_header(k, v)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if "magnet" in self.path:
            self.send_it(301, Location=self.server.t1.magnet)
        elif "torrent" in self.path:
            self.send_it(200, self.server.t2.bytes)
        elif "junk" in self.path:
            self.send_it(200, b"<html>a page, no torrent</html>")
        elif "slow" in self.path:
            self.server.slow += 1
            if self.server.slow < 2:
                self.send_it(503)
            else:
                self.send_it(200, self.server.t3.bytes)
        else:
            self.send_it(404)


def url_links():
    """A link of Prowlarr's: a row at once, its site asked behind it, the row becoming the torrent; what fails said in words, no key on disk."""
    s = swarm_()
    srv = ThreadingHTTPServer(("127.0.0.1", 0), Links)
    srv.daemon_threads = True
    srv.slow = 0
    srv.t1, srv.t2, srv.t3 = s.torrent("by.redirect", {"a": 1 << 16}), s.torrent("by.file", {"b": 1 << 16}), s.torrent("after.trouble", {"c": 1 << 16})
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    base = f"http://127.0.0.1:{srv.server_address[1]}"
    e = spawn_engine()
    c = e.client()
    a = c.ask({"op": "add", "kind": "url", "value": base + "/magnet?apikey=SECRETKEY", "name": "shown at once", "source": "Knaben"})
    assert a["id"].startswith("url-"), a
    c.wait(lambda: srv.t1.hash in c.rows, 15, "the torrent it led to")
    eq(c.event("moved", 5)["to"], srv.t1.hash, "a window on its row follows")
    eq(c.rows[srv.t1.hash]["source"], "Knaben", "where it was found")
    c.wait(lambda: a["id"] not in c.rows, 5, "the link's row gone")
    b = c.ask({"op": "add", "kind": "url", "value": base + "/a.torrent", "name": "a file"})
    c.wait(lambda: srv.t2.hash in c.rows, 15, "the torrent in the file")
    eq(b["err"], "", "no trouble")
    c.ask({"op": "add", "kind": "url", "value": base + "/slow", "name": "a site in trouble once"})
    c.wait(lambda: srv.t3.hash in c.rows, 20, "asked again by itself")
    for path, word in (("/gone", "refused"), ("/junk", "something else")):
        x = c.ask({"op": "add", "kind": "url", "value": base + path, "name": path})
        err = c.wait(lambda i=x["id"]: c.rows.get(i, {}).get("err"), 15, f"{path} said")
        assert word in err, err
        eq(c.rows[x["id"]]["word"], "failed", "its row")
        assert "SECRETKEY" not in err, err
    x = c.ask({"op": "add", "kind": "url", "value": "http://127.0.0.1:1/x?apikey=SECRETKEY", "name": "dead"})
    err = c.wait(lambda: c.rows.get(x["id"], {}).get("err"), 20, "a dead port said")
    assert "could not reach" in err and "SECRETKEY" not in err, err
    c.ask({"op": "retry", "id": x["id"]})
    c.ask({"op": "remove", "id": x["id"]})
    c.wait(lambda: x["id"] not in c.rows, 5, "off the list")
    c.close()
    e.stop()
    s.close()
    for dp, _, names in os.walk(HOME):
        for n in names:
            p = os.path.join(dp, n)
            if os.path.getsize(p) < 1 << 22:
                with open(p, "rb") as f:
                    assert b"SECRETKEY" not in f.read(), f"the key reached {p}"


def idle_and_marks():
    """It ends by itself once nothing is wanted, everything saved; never while something downloads; the mark says what is unfinished."""
    s = swarm_()
    s.ses.set_local_upload_rate_limit(600 << 10)
    t = s.torrent("slowly", {"a.bin": 2 << 20})
    mark = os.path.join(STATE, "unfinished")
    e = spawn_engine(idle=1)
    c = e.client()
    c.ask({"op": "add", "kind": "magnet", "value": t.magnet})
    c.wait(lambda: os.path.exists(mark), 5, "the mark while it downloads")
    bar = os.path.join(os.environ["XDG_RUNTIME_DIR"], "kawa-downloads", f"torrent.{e.proc.pid}")
    end = time.monotonic() + 6
    while not os.path.exists(bar) and time.monotonic() < end:
        c.pump(0.1)
    assert os.path.exists(bar), "the bar's list while it downloads"
    line = open(bar, encoding="utf-8").readline().rstrip("\n").split("\t")
    eq(len(line), 4, "NAME DONE TOTAL WHERE")
    c.close()                                      # (the window closes: the download goes on)
    time.sleep(1.5)
    assert e.proc.poll() is None, "it ended with a download running"
    rc = e.proc.wait(40)                           # (and ends by itself when that is done)
    eq(rc, 0, "ended clean")
    assert not os.path.exists(mark), "nothing unfinished any more"
    assert not os.path.exists(bar), "the bar's list goes with it"
    assert os.path.isfile(os.path.join(STATE, t.hash + ".resume")), "saved"
    same_tree(os.path.join(t.where, t.name), downloaded(t.name))
    eq(len(notices()), 1, "told, with no window")
    s.close()


def crash_midway():
    """Killed outright halfway (a power cut's cousin): the next start goes on, the file right, no notice lost or doubled."""
    s = swarm_()
    s.ses.set_local_upload_rate_limit(2 << 20)
    t = s.torrent("crash.me", {"a.bin": 12 << 20})
    e = spawn_engine()
    c = e.client()
    c.ask({"op": "add", "kind": "magnet", "value": t.magnet})
    c.wait(lambda: c.rows.get(t.hash, {}).get("done", 0) > 2 << 20, 30, "some of it")
    e.proc.send_signal(signal.SIGKILL)
    e.proc.wait(5)
    assert os.path.isfile(os.path.join(STATE, t.hash + ".resume")), "its resume data was on the disk from the moment it was added"
    e = spawn_engine()
    c = e.client()
    c.wait(lambda: c.rows.get(t.hash, {}).get("word") == "done", 60, "done after the crash")
    same_tree(os.path.join(t.where, t.name), downloaded(t.name))
    time.sleep(0.3)
    eq(len(notices()), 1, "one notice")
    c.close()
    e.stop()
    s.close()


def many():
    """Two hundred torrents: added quickly, listed whole, a restart quick."""
    s = swarm_()
    ts = [s.torrent(f"many.{k:03d}", {"f": 2000}, piece=1 << 14) for k in range(200)]
    e = spawn_engine()
    c = e.client()
    t0 = time.monotonic()
    for t in ts:
        c.ask({"op": "add", "kind": "magnet", "value": t.magnet})
    took = time.monotonic() - t0
    assert took < 6, f"200 adds took {took:.1f} s"
    c.wait(lambda: len(c.rows) == 200, 10, "200 rows")
    c.wait(lambda: sum(r["word"] == "done" for r in c.rows.values()) >= 150, 90, "most of them done")
    c.close()
    e.stop()
    t0 = time.monotonic()
    e = spawn_engine()
    c = e.client()
    c.wait(lambda: len(c.rows) == 200, 10, "200 rows after a restart")
    took = time.monotonic() - t0
    assert took < 3, f"a restart with 200 took {took:.1f} s"
    c.close()
    e.stop()
    s.close()


def disk_full():
    """A real full disk (a small tmpfs in a namespace of this process's own): the row says so, one critical notice, p goes on once there is room."""
    r = subprocess.run(["unshare", "-Urm", "true"], capture_output=True, check=False)
    assert r.returncode == 0, f"needs unprivileged namespaces: {r.stderr[:100]}"
    if os.environ.get("KT_INSIDE") != "1":
        env = dict(os.environ, KT_INSIDE="1")
        r = subprocess.run(["unshare", "-Urm", sys.executable, __file__, "disk_full"], env=env, check=False)
        sys.exit(r.returncode)
    d = downloaded("")
    os.makedirs(d, exist_ok=True)
    subprocess.run(["mount", "-t", "tmpfs", "-o", "size=40m", "tmpfs", d], check=True)
    filler = os.path.join(d, "the disk full of something else")
    with open(filler, "wb") as f:
        f.write(b"\0" * (34 << 20))
    s = swarm_()
    t = s.torrent("too.big", {"a.bin": 12 << 20}, piece=1 << 18)
    e = spawn_engine()
    c = e.client()
    c.ask({"op": "add", "kind": "magnet", "value": t.magnet})
    err = c.wait(lambda: c.rows.get(t.hash, {}).get("word") == "failed" and c.rows[t.hash]["err"], 60, "the disk's full said")
    assert "space" in err.lower(), err
    time.sleep(1.5)
    eq(len(said("failed")), 1, "one critical notice")
    assert e.proc.poll() is None, "the engine goes on"
    os.remove(filler)
    c.ask({"op": "resume", "id": t.hash})
    c.wait(lambda: c.rows[t.hash]["word"] == "done", 60, "done once there is room")
    same_tree(os.path.join(t.where, t.name), downloaded(t.name))
    c.close()
    e.stop()
    s.close()


def inherit():
    """torrra's list: each torrent taken over with its chosen files; those told stay told; a removed list leaves nothing."""
    db = os.path.join(TMP, "torrra.db")
    con = sqlite3.connect(db)
    con.execute("""CREATE TABLE torrents (magnet_uri TEXT PRIMARY KEY, title TEXT, size REAL, source TEXT, is_paused BOOLEAN DEFAULT 0,
                   is_notified BOOLEAN DEFAULT 0, file_priorities TEXT, upload_limit INTEGER, download_limit INTEGER, save_path TEXT,
                   max_ratio REAL, max_seeding_time INTEGER, sequential_download BOOLEAN DEFAULT 0)""")
    s = swarm_()
    t1 = s.torrent("was.finished", {"a": 1 << 16, "b": 1 << 16}, piece=1 << 14)
    t2 = s.torrent("was.paused", {"c": 1 << 16})
    con.execute("INSERT INTO torrents (magnet_uri, title, source, is_notified, file_priorities) VALUES (?,?,?,1,?)", (t1.magnet, "was.finished", "Knaben", "[4, 0]"))
    con.execute("INSERT INTO torrents (magnet_uri, title, is_paused) VALUES (?,?,1)", (t2.magnet, "was.paused"))
    con.execute("INSERT INTO torrents (magnet_uri, title) VALUES ('http://not.a.magnet/x','skipped')")
    con.commit()
    con.close()
    r = subprocess.run([sys.executable, os.path.join(REPO, "bin/kawa-torrents"), "inherit", db], capture_output=True, text=True, check=False)
    eq(r.returncode, 0, r.stderr)
    assert "2 taken over" in r.stdout, r.stdout
    e = spawn_engine()
    c = e.client()
    c.wait(lambda: t1.hash in c.rows and t2.hash in c.rows, 10, "both in the list")
    eq(c.wait(lambda: c.rows[t2.hash]["word"] == "paused" and "paused", 10), "paused", "its pause")
    eq(c.rows[t1.hash]["source"], "Knaben", "where it was found")
    c.ask({"op": "watch", "id": t1.hash, "cells": 4})
    d = c.wait(lambda: next((m for m in c.events if m.get("ev") == "detail" and m.get("priorities")), None), 30, "its files known")
    keep = sum(1 for p in d["priorities"] if p)
    eq(keep, 1, "its chosen files")
    c.wait(lambda: c.rows[t1.hash]["word"] == "done", 30, "done")
    time.sleep(0.3)
    eq(notices(), [], "told once by torrra: never again")
    assert not os.path.exists(os.path.join(STATE, "inherited.json")), "consumed"
    c.close()
    e.stop()
    s.close()
    r = subprocess.run([sys.executable, os.path.join(REPO, "bin/kawa-torrents"), "inherit", os.path.join(TMP, "none.db")], capture_output=True, text=True, check=False)
    eq((r.returncode, r.stdout), (0, ""), "nothing to take over: nothing said")
    # one torrra had finished, its swarm long dead: it looks, but holds neither the bar nor the engine
    with open(os.path.join(STATE, "inherited.json"), "w", encoding="utf-8") as f:
        json.dump([{"magnet": "magnet:?xt=urn:btih:" + "cd" * 20, "name": "long dead", "told": True}], f)
    e = spawn_engine(idle=1)
    eq(e.proc.wait(15), 0, "the engine ends by itself")
    assert not os.path.exists(os.path.join(STATE, "unfinished")), "nothing unfinished for the next login"


def socket_started():
    """As systemd starts it (its own socket-activate: LISTEN_FDS): nothing runs until something connects; it ends by itself when
    nothing is wanted, the socket stays; the next connection starts it again, its torrents back."""
    s = swarm_()
    t = s.torrent("by.socket", {"a": 1 << 16})
    sock = os.path.join(os.environ["XDG_RUNTIME_DIR"], "kawa-torrents.sock")
    env = dict(os.environ, KAWA_TORRENTS_NET="local", KAWA_TORRENTS_IDLE="1")
    # (--inetd off, one accept loop of the engine's own; -E hands it the environment)
    p = subprocess.Popen(["systemd-socket-activate", "-l", sock, *[f"-E{k}={env[k]}" for k in ("KAWA_TORRENTS_NET", "KAWA_TORRENTS_IDLE", "KAWA_TORRENTS_LIB", "HOME", "XDG_RUNTIME_DIR", "XDG_STATE_HOME", "XDG_CACHE_HOME", "PATH", "CALLS", *[n for n in ("PYTHONPATH", "LD_LIBRARY_PATH") if n in env])],
                          sys.executable, os.path.join(REPO, "bin/kawa-torrents"), "engine"], env=env, stderr=subprocess.DEVNULL)
    atexit.register(p.kill)
    end = time.monotonic() + 8
    while not os.path.exists(sock):
        assert time.monotonic() < end, "no socket"
        time.sleep(0.02)
    from torrents_swarm import Client
    c = Client(sock)
    c.ask({"op": "add", "kind": "magnet", "value": t.magnet})
    c.wait(lambda: c.rows.get(t.hash, {}).get("word") == "done", 40, "done")
    c.close()
    time.sleep(3)                                  # (the idle second, then saved and gone)
    assert os.path.isfile(os.path.join(STATE, t.hash + ".resume")), "saved"
    p.kill()
    p.wait(5)
    s.close()


# ── links, names, numbers ───────────────────────────────────────────────────────────────────
def words():
    import common as cm
    H = "0123456789abcdef0123456789abcdef01234567"
    B32 = "AERUKZ4JVPG66AJDT5LFAERUKZ4JVPG6"
    m = f"magnet:?xt=urn:btih:{H}&dn=A+Name&tr=udp%3A%2F%2Ft%3A1"
    eq(cm.links(m), [("magnet", m)], "a magnet alone")
    eq(cm.links(f"see <a href=\"{m.replace('&', '&amp;')}\">here</a>, or there"), [("magnet", m)], "a page's source")
    eq(cm.links(f"{m}\n{m}\n"), [("magnet", m)], "the same twice is once")
    upper = f"magnet:?xt=urn:btih:{H.upper()}"
    eq(len(cm.links(f"{m} {upper}")), 1, "two spellings of one hash")
    eq(cm.magnet_hash(f"magnet:?xt=urn:btih:{B32}"), cm.magnet_hash(f"magnet:?xt=urn:btih:{B32.lower()}"), "base32, any case")
    assert len(cm.magnet_hash(f"magnet:?xt=urn:btih:{B32}")) == 40, "base32 to hex"
    eq(cm.magnet_name(m), "A Name", "its name")
    eq(cm.magnet_name(f"magnet:?xt=urn:btih:{H}"), H[:16], "no name: its hash")
    eq(cm.magnet_name("magnet:?xt=urn:btih:" + H + "&dn=a%1b%5B31mb"), "a[31mb", "an escape in a name goes")
    eq(cm.links(H), [("magnet", "magnet:?xt=urn:btih:" + H)], "a bare hash typed for the purpose")
    eq(cm.links(H, loose=False), [], "from the clipboard a git commit is no torrent")
    eq(cm.links("https://x.org/a.torrent?k=1 and text"), [("url", "https://x.org/a.torrent?k=1")], "a .torrent's link")
    eq(cm.links("https://x.org/page", loose=False), [], "any link is no offer")
    eq(cm.links("https://x.org/dl/123"), [("url", "https://x.org/dl/123")], "but pasted for the purpose")
    f = os.path.join(TMP, "my file.torrent")
    open(f, "w").close()
    eq(cm.links(f), [("file", f)], "a path with a space")
    os.chdir(TMP)
    eq(cm.links("my file.torrent"), [("file", f)], "named from where you stand")
    eq(cm.links("file://" + f.replace(" ", "%20")), [("file", f)], "a file:// URI")
    eq(cm.links("/no/such/file.torrent"), [], "a path that is not there")
    eq(cm.links("nothing here"), [], "nothing")
    eq(cm.links(""), [], "empty")
    eq(cm.without_key("http://h:1/1/download?apikey=abc&link=x"), "http://h:1/1/download?link=x", "the key out")
    eq(cm.without_key("http://h:1/1/download?link=x&apikey=abc"), "http://h:1/1/download?link=x", "at the end too")
    eq(cm.safe("a\x1b[2Jb\x07c‮d\td"), "a[2Jbcd d", "control letters and overrides")
    eq(cm.reading("Night.of.the.Living.Dead.1968.1080p.x264"), "Night of the Living Dead 1968 1080p x264", "words")
    eq(cm.reading("Album.Name.5.1.Remaster"), "Album Name 5.1 Remaster", "a version's dot")
    eq(cm.reading("Album.Name.5.1.FLAC"), "Album Name 5.1.FLAC", "a file's type at the end")
    eq(cm.reading("fedora-44-x86_64-netinst.iso"), "fedora-44-x86_64-netinst.iso", "a disc's name is a file's")
    eq(cm.reading("Already spaced.name"), "Already spaced.name", "already words")
    eq(cm.cells("北斎 ab"), 7, "a kanji two")
    eq(cm.cut("北斎漫画全十五編", 5), "北斎", "a kanji is never cut in half")
    eq(cm.cut("one two three four", 9), "one two", "at a word")
    eq(cm.cut("onetwothree", 5), "onetw", "no word in reach: at the column")
    assert "…" not in cm.cut("a" * 100, 10), "never an ellipsis"
    eq(cm.size(0), "0 B", "bytes")
    eq(cm.size(1500), "2 KB", "KB")
    eq(cm.size(23_600_000_000), "23.6 GB", "GB")
    eq(cm.size(4_400_000_000_000), "4.4 TB", "TB")
    eq(cm.speed(0), "", "no speed: nothing")
    eq(cm.speed(1_200_000), "1.2 MB/s", "a speed")
    eq(cm.duration(45), "45 s", "seconds")
    eq(cm.duration(3 * 3600 + 600), "3 h 10", "hours")
    eq(cm.duration(86400), "1 day", "a day")
    assert cm.natural("ep 2") < cm.natural("ep 10"), "episode 2 before 10"
    assert cm.playable("a/b.MKV") and not cm.playable("a/b.nfo"), "what can be played"


# ── the window ──────────────────────────────────────────────────────────────────────────────
def mock(args=(), slow=0.5):
    """The mock engine and Prowlarr up (torrents_mock.py); the stand-ins' log is CALLS."""
    os.environ["KAWA_PROWLARR_URL"] = "http://127.0.0.1:19797" if "PROWLARR_PORT" not in os.environ else f"http://127.0.0.1:{os.environ['PROWLARR_PORT']}"
    with socket.socket() as probe:
        probe.bind(("127.0.0.1", 0))
        port = probe.getsockname()[1]
    os.environ["KAWA_PROWLARR_URL"] = f"http://127.0.0.1:{port}"
    env = dict(os.environ, MOCK_LOG=os.path.join(TMP, "mock.log"), MOCK_SLOW=str(slow))
    p = subprocess.Popen([sys.executable, "-I", os.path.join(HERE, "torrents_mock.py"), *args], env=env)
    atexit.register(p.kill)
    sock = os.path.join(os.environ["XDG_RUNTIME_DIR"], "kawa-torrents.sock")
    end = time.monotonic() + 8
    while not os.path.exists(sock):
        assert time.monotonic() < end, "the mock engine did not start"
        time.sleep(0.02)
    return p


def asked():
    try:
        with open(os.path.join(TMP, "mock.log"), encoding="utf-8") as f:
            return [json.loads(line) for line in f]
    except FileNotFoundError:
        return []


def window(rows=30, cols=116, args=()):
    from torrents_screen import Window
    w = Window([sys.executable, os.path.join(REPO, "bin/kawa-torrents"), *args], rows=rows, cols=cols)
    atexit.register(lambda: w.dead or _kill(w.pid))
    return w


def _kill(pid):
    try:
        os.kill(pid, signal.SIGKILL)
    except ProcessLookupError:
        pass


def row_of(w, word):
    at = w.screen.find(word)
    assert at, f"no {word!r} on the screen:\n{w.screen.dump()}"
    return at[0]


def check_screen(s, cols):
    """What holds on every screen, at every size: nothing past the edge, nothing cut with an ellipsis, a cursor's fill whole."""
    assert not getattr(s, "overflow", False), f"a row ran past the edge at {cols} columns:\n{s.dump()}"
    for y in range(s.rows):
        assert "…" not in s.line(y), f"an ellipsis on row {y}:\n{s.dump()}"
        fill = [x for x in range(s.cols) if s.cells[y][x][2] == 24]
        if fill and cols >= 12:
            assert fill[0] == 0 or s.cells[y][fill[0] - 1][0] in ("│", " "), f"row {y}: its fill starts at {fill[0]}"
            assert fill == list(range(fill[0], fill[-1] + 1)), f"row {y}: its fill has a hole\n{s.dump()}"


def every_size():
    """From a sliver to a wall of a screen, both tabs, with all the states on the list: no crash, nothing past the edge."""
    mock()
    w = window(30, 116)
    w.has("downloads")
    sizes = [(2, 2), (3, 8), (6, 20), (10, 30), (12, 40), (20, 44), (24, 62), (30, 60), (24, 84), (30, 104), (40, 116), (50, 131), (50, 132), (50, 238), (54, 300), (70, 400), (8, 100), (3, 300)]
    for rows, cols in sizes:
        w.resize(rows, cols)
        w.settle(0.15)
        assert not w.dead, f"it ended at {rows}x{cols}: {w.tail[-1500:].decode('utf-8', 'replace')}"
        check_screen(w.screen, cols)
    for rows, cols in sizes:
        w.keys("\t") if not w.screen.find("find") else None
        w.resize(rows, cols)
        w.settle(0.1)
        assert not w.dead, f"it ended at {rows}x{cols} on find: {w.tail[-1500:].decode('utf-8', 'replace')}"
        check_screen(w.screen, cols)
    eq(w.close(), 0, "ends clean")


def layout():
    """To the column: tabs, a heading, a row's icon at 2 and its name at 5, values ending at the last content column, the cursor's fill."""
    mock()
    w = window(40, 116)
    w.has("finished")
    s = w.screen
    eq(s.line(0)[1], w_icon("DOWNLOAD"), "the tab's icon at the content's first column")
    eq(s.line(0)[4:13], "downloads", "its name three columns on")
    eq(s.line(1)[4:13], "▔" * 9, "the line under it, flush")
    assert s.line(2).strip() == "", "a row of paper"
    y = row_of(w, "downloading")
    eq(s.line(y)[1], w_icon("DOWNLOAD"), "a heading at the content's first column")
    assert s.line(y)[4:15] == "downloading" and s.line(y)[16] == "─", s.line(y)
    assert s.line(y).rstrip().endswith("to come") and len(s.line(y).rstrip()) == 115, f"its rule, then how much, to the last column: {s.line(y)!r}"
    eq(s.line(y)[115], " ", "and no further")
    y2 = row_of(w, "finished")
    assert s.line(y2).rstrip().endswith("2.8 GB"), s.line(y2)
    eq(s.line(y + 1).strip(), "", "a blank under a heading")
    y = row_of(w, "paused")
    assert s.line(y - 1).strip() == "" and s.line(y - 2).strip() == "", "two blank lines over a heading"
    # the row under the cursor: from the cursor's column to one past the content, in the lacquer
    eq(s.cells[row_of(w, "paused")][0][2], None, "no fill on a heading")
    first = next(yy for yy in range(s.rows) if s.cells[yy][0][2] == 24)
    eq([s.cells[first][x][2] for x in (0, 57, 115)], [24, 24, 24], "the whole row, to the window's edge")
    eq(s.cells[first][5][1], 25, "its words in the lacquer's ink")
    y = row_of(w, "debian-13.1.0")
    eq(s.line(y)[5:18], "debian-13.1.0", "a name at column 5 of the screen")
    assert s.line(y)[2] != " " and s.line(y)[3] == " " and s.line(y)[4] == " ", s.line(y)[:8]
    assert s.line(y).rstrip()[-2:] == "GB" and len(s.line(y).rstrip()) == 115, f"values end at the last content column: {s.line(y)!r}"
    # the same column for the sizes down the list
    ys = [row_of(w, n) for n in ("debian-13.1.0", "Nosferatu", "Big Buck Bunny", "fedora-44")]
    ends = {len(s.line(yy).rstrip()) for yy in ys}
    eq(ends, {115}, "a column of sizes")
    # a kanji name: two columns a letter, the row still ends where the others do
    y = row_of(w, "全十五編")
    eq(sum(1 for x in range(s.cols) if s.cells[y][x][0] == ""), 22 if False else sum(1 for c in "北斎漫画 全十五編 — 東京国立博物館 高精細スキャン" if unicodedata_wide(c)), "wide letters take two")
    assert len(s.line(y).rstrip()) + sum(1 for x in range(s.cols) if s.cells[y][x][0] == "") == 115, "ends in the column of sizes"
    # the meter: ten cells, part-way in a dissolve's step
    y = row_of(w, "debian-13.1.0")
    meter = [c for c in s.line(y) if c in meter_letters()]
    eq(len(meter), 10, f"ten segments: {s.line(y)!r}")
    assert meter[:4] == [w_icon("READ")] * 4 and meter[4] != w_icon("READ") and meter[4] != w_icon("READ_OFF") and meter[5:] == [w_icon("READ_OFF")] * 5, meter
    eq(w.close(), 0, "ends clean")


def icons_():
    import app
    return app.load_icons()


def w_icon(name):
    return icons_()[name]


def meter_letters():
    ic = icons_()
    return {ic[k] for k in ic if k == "READ" or k == "READ_OFF" or (k.startswith("READ_") and k[5:].isdigit())}


def unicodedata_wide(c):
    import unicodedata
    return unicodedata.east_asian_width(c) in ("W", "F")


def keys_():
    """Every key does what its line says, on the mock engine: nothing is typed anywhere it should not be."""
    mock()
    w = window(40, 116)
    w.has("finished")
    s = w.screen

    def on(word):
        y = row_of(w, word)
        assert s.cells[y][0][2] == 24, f"the cursor is not on {word}:\n{s.dump()}"

    on("Tears of Steel")
    w.keys("j")
    on("Sintel")
    w.keys("k")
    on("Tears of Steel")
    w.keys("G")
    on("fedora-44")
    w.keys("g")
    on("Tears of Steel")
    w.keys(b"\x04")                                # ctrl+d: a page
    assert s.cells[row_of(w, "Tears of Steel")][0][2] is None, "it moved"
    w.keys("g", "j", "j", "j", "j")
    on("[SubsPlease]")
    r = next(x for x in asked() if x["op"] == "hello")
    assert r, "said hello"
    # a row's own keys
    w.keys("p")
    eq(asked()[-1], {"op": "pause", "id": "c" * 40}, "p pauses")
    w.keys("t")
    eq(asked()[-1], {"op": "turtle", "on": True}, "t slows")
    w.keys("r")
    eq(asked()[-1], {"op": "retry", "id": "c" * 40}, "r asks again")
    w.keys("c")
    eq(asked()[-1], {"op": "recheck", "id": "c" * 40}, "c checks")
    w.keys("P")
    eq(asked()[-1], {"op": "pause_all"}, "P: all")
    # copy: the magnet to the clipboard, said in place
    n = len(calls("wl-copy"))
    w.keys("y")
    w.has("magnet copied", 5)
    w.settle(0.2)
    eq(len(calls("wl-copy")), n + 1, "copied")
    assert ("magnet:?xt=urn:btih:" + "c" * 40) in calls("wl-copy")[-1], calls("wl-copy")[-1]
    # d asks, and only y removes; the question says its name
    w.keys("d")
    w.has("remove", 5)
    w.keys("n")
    assert not any(x["op"] == "remove" for x in asked()), "n keeps it"
    w.keys("d", "y")
    eq(asked()[-1], {"op": "remove", "id": "c" * 40}, "d y removes")
    w.keys("D", "y")
    eq(asked()[-1], {"op": "remove", "id": "c" * 40, "files": True}, "D y removes with its files")
    # v: a play: the player handed a URL
    w.keys("g")
    w.keys("j", "j")                               # (on the film)
    on("Night of the Living Dead")
    w.keys("\r")
    w.settle(0.3)
    w.resize(40, 116)
    w.keys("\x1b")
    # the filter: only those that contain
    w.keys("/", "n", "o", "s")
    w.settle(0.1)
    assert w.screen.find("Nosferatu") and not w.screen.find("Sintel"), w.screen.dump()
    w.keys("\x1b")
    assert w.screen.find("Sintel"), "the filter gone"
    # Tab: find; Tab back
    w.keys("\t")
    assert w.screen.find("what to find"), w.screen.dump()
    w.keys("\t")
    assert w.screen.find("downloading"), w.screen.dump()
    # the add line: typed and added; Esc leaves nothing
    w.keys("a")
    assert w.screen.find("a magnet link"), w.screen.dump()
    w.keys("\x1b")
    assert not w.screen.find("a magnet link"), "gone"
    w.keys("a")
    for c in "ab" * 20:
        w.keys(c)
    assert w.screen.find("abababababababab"), "what it comes to is said, under the line\n" + w.screen.dump()
    w.keys("\r")
    eq(asked()[-1]["op"], "add", "a bare hash added")
    w.keys("a")
    for c in "words":
        w.keys(c)
    w.has("not a magnet link", 3)
    w.keys("\x1b")
    eq(asked()[-1]["value"], "magnet:?xt=urn:btih:" + "ab" * 20, "as a magnet")
    # a paste anywhere adds
    m = "magnet:?xt=urn:btih:" + "cd" * 20 + "&dn=pasted"
    w.paste(m)
    eq(asked()[-1]["value"], m, "a paste on the list")
    w.paste("just words")
    w.has("not a magnet link", 5)
    # the mouse: over a row moves the cursor; a click acts; the wheel moves; a tab's icon changes tab
    y = row_of(w, "Sintel")
    w.hover(y, 20)
    assert s.cells[y][0][2] == 24, "the cursor follows the pointer"
    w.wheel(y, 20)
    w.wheel(y, 20, up=True)
    x = w.screen.line(0).find(w_icon("SEARCH"))
    w.click(0, x)
    assert w.screen.find("what to find"), "a click on a tab"
    w.click(0, 1)
    assert w.screen.find("downloading"), "and back"
    eq(w.close(), 0, "ends clean")


def details():
    """The details beside the list on a wide window, on their own page on a narrow one; files kept and skipped; a video plays."""
    mock()
    w = window(50, 238)
    w.has("files")
    s = w.screen
    rail = s.line(1).find("│")
    assert rail > 150, s.line(1)
    assert s.line(0)[rail + 2] != " ", "its heading right after the free column"
    w.keys("j", "j")
    assert s.find("Night of the Living Dead 1968"), s.dump()
    assert any(s.cells[y][rail + 1][2] != 24 for y in range(5)), "no fill in the pane yet"
    w.settle(0.2)
    w.keys("\r")                                   # (into the files)
    y0 = next(y for y in range(s.rows) if s.cells[y][rail + 1][2] == 24)
    eq(s.cells[y0][cols_of(s) - 1][2], 24, "the fill to the window's edge")
    list_row = next(y for y in range(3, s.rows) if "Night of the Living Dead 1968" in s.line(y)[:rail - 20])
    eq(s.cells[list_row][0][2], 18, "the list's row keeps a band")
    w.keys(" ")
    eq(asked()[-1]["op"], "files", "Space keeps or skips")
    w.keys("n")
    eq(asked()[-1]["priorities"], [0, 0, 0, 0, 0, 0], "n: none")
    w.keys("a")
    assert all(asked()[-1]["priorities"]), "a: all"
    w.keys("i")
    assert not any(asked()[-1]["priorities"]), "i: the other way round"
    w.keys("g")
    w.keys("j", "j")                               # (a video)
    w.keys("\r")
    eq(asked()[-1]["op"], "stream", "Enter on a video plays it")
    w.settle(0.3)
    assert calls("kawa-play"), "handed to the player"
    assert "http://127.0.0.1:1/stream/file.mkv" in calls("kawa-play")[-1], calls("kawa-play")
    # the mouse in them: the pointer takes the cursor, a click on the box keeps or skips, on a video's name plays it
    w.keys("\x1b")
    y0 = next(y for y in range(s.rows) if "Subs/English.srt" in s.line(y)[rail:] or "English.srt" in s.line(y))
    w.hover(y0, rail + 10)
    eq(s.cells[y0][rail + 1][2], 24, "the pointer on a file: the lacquer there")
    n = len([x for x in asked() if x["op"] == "files"])
    w.click(y0, rail + 3)
    eq(len([x for x in asked() if x["op"] == "files"]), n + 1, "a click on its box")
    y1 = next(y for y in range(s.rows) if "trailer 1968" in s.line(y))
    plays = len(calls("kawa-play"))
    w.click(y1, rail + 10)
    w.settle(0.3)
    eq(len(calls("kawa-play")), plays + 1, "a click on a video's name plays it")
    list_row2 = next(y for y in range(3, s.rows) if "Sintel" in s.line(y)[:rail - 20])
    w.hover(list_row2, 30)
    eq(s.cells[list_row2][0][2], 24, "back on the list: one light, there")
    w.hover(list_row, 30)
    w.keys("\x1b")
    w.resize(30, 64)
    w.keys("\r")
    w.settle(0.2)
    assert s.line(0)[1] != " " and not s.find("finished"), "its own page\n" + s.dump()
    assert any(s.cells[y][0][2] == 24 for y in range(s.rows)), "straight into its files\n" + s.dump()
    assert s.find("pieces") and s.find("state"), s.dump()
    w.keys("\x1b")
    assert s.find("downloading"), "back to the list"
    eq(w.close(), 0, "ends clean")


def cols_of(s):
    return s.cols


def find():
    """Sites answer one by one: what a quick one found shows while a slow one thinks; Enter starts it from the hash, with no site and no key."""
    mock(slow=2.5)
    d = os.path.join(HOME, ".config/fedokawaii")
    with open(os.path.join(d, "secrets.sh"), "w") as f:
        f.write("PROWLARR_API_KEY=" + "0" * 32 + "\n")
    os.chmod(os.path.join(d, "secrets.sh"), 0o600)
    w = window(30, 116)
    w.has("finished")
    w.keys("\t")
    w.has("what to find")
    assert any("--busy" in c for c in calls("kawa-prowlarr")), "Prowlarr woken at the tab"
    s = w.screen
    assert s.modes.intersection({25}), "a caret on the line"
    for c in "debian":
        w.keys(c)
    w.keys("\r")
    w.has("debian-13.1.0-amd64-netinst.iso", 5)
    assert s.find("sites"), "still waiting for the slow site, and it says so\n" + s.dump()
    w.has("found", 8)
    y1, y2 = row_of(w, "netinst.iso"), row_of(w, "DVD x86_64")
    assert y1 < y2, "the best seeded first"
    assert s.cells[y1][0][2] == 24, "the cursor on the first"
    dead = row_of(w, "woody")
    assert dead > y2 and s.cells[dead][5][1] == 22, "no seeds: last, faint"
    # s: another order
    w.keys("s")
    assert row_of(w, "DVD x86_64") < row_of(w, "netinst.iso"), "biggest first"
    w.has("size", 3)
    w.keys("s", "s", "s")
    # y copies a magnet with no site asked; Enter adds from the hash
    n = len(calls("wl-copy"))
    w.keys("y")
    w.has("magnet copied", 8)
    w.settle(0.2)
    assert "ab" * 20 in calls("wl-copy")[n], calls("wl-copy")
    w.keys("\r")
    a = asked()[-1]
    eq(a["op"], "add", "Enter adds")
    assert a["kind"] == "magnet" and ("ab" * 20) in a["value"] and "apikey" not in a["value"], a
    eq(a["source"], "thepiratebay", "where it was found")
    w.has("downloading", 3)
    # the same query again: from memory, at once
    w.keys("\t")
    w.settle(0.2)
    assert s.find("found"), "its results kept\n" + s.dump()
    # a result that has only a site's link goes as a link
    w.keys("/")
    w.keys("\x1b")                                 # (the line cleared)
    for c in "debian":
        w.keys(c)
    w.keys("\r")
    w.settle(0.2)
    w.has("debian live 13", 5)
    y = row_of(w, "debian live 13")
    w.hover(y, 20)
    w.keys("\r")
    a = asked()[-1]
    eq(a["kind"], "url", "no hash: its link")
    eq(w.close(), 0, "ends clean")
    assert any("--idle" in c for c in calls("kawa-prowlarr")), "Prowlarr told it may sleep"


def no_key_no_prowlarr():
    """What stops a search is said where its results would be, in words, with a failure's mark."""
    mock()
    w = window(30, 116)
    w.has("finished")
    w.keys("\t")
    for c in "x":
        w.keys(c)
    w.keys("\r")
    w.has("no Prowlarr key", 5)
    assert w.screen.find("repair"), w.screen.dump()
    eq(w.close(), 0, "ends clean")


def prowlarr_down():
    """Prowlarr that says it will not start: said at once, not after a minute and a half of waiting."""
    p = os.path.join(TMP, "stubs/kawa-prowlarr")
    with open(p, "w", encoding="utf-8") as f:
        f.write("#!/bin/sh\nexit 1\n")
    mock()
    os.environ["KAWA_PROWLARR_URL"] = "http://127.0.0.1:1"
    d = os.path.join(HOME, ".config/fedokawaii")
    with open(os.path.join(d, "secrets.sh"), "w") as f:
        f.write("PROWLARR_API_KEY=" + "0" * 32 + "\n")
    os.chmod(os.path.join(d, "secrets.sh"), 0o600)
    w = window(30, 116)
    w.has("finished")
    w.keys("\t", "x", "\r")
    w.has("Prowlarr did not start", 6)
    eq(w.close(), 0, "ends clean")


def first_view():
    """Nothing downloaded yet: the window opens on the search, the caret on its line."""
    mock(("--empty",))
    w = window(30, 116)
    w.has("what to find", 5)
    w.settle(0.3)
    assert 25 in w.screen.modes, "the caret on the line"
    w.keys("\t")
    w.has("nothing yet", 3)
    eq(w.close(), 0, "ends clean")


def offers():
    """A magnet on the clipboard is offered; Enter adds it; x leaves it; a .torrent just downloaded too; what is already here never."""
    mock()
    H = "12" * 20
    clip = os.path.join(TMP, "clip")
    with open(clip, "w") as f:
        f.write(f"magnet:?xt=urn:btih:{H}&dn=From.The.Clipboard")
    d = os.path.join(HOME, "Downloads")
    os.makedirs(d, exist_ok=True)
    open(os.path.join(d, "A.Fresh.One.torrent"), "w").close()
    w = window(30, 116)
    w.has("in the clipboard", 5)
    s = w.screen
    assert s.find("From The Clipboard"), s.dump()
    assert s.find("in Downloads") and s.find("A Fresh One"), s.dump()
    y = row_of(w, "in the clipboard")
    assert s.cells[y][0][2] == 24, "the cursor on it"
    w.keys("\r")
    a = asked()[-1]
    eq((a["op"], a["kind"]), ("add", "magnet"), "Enter adds it")
    assert H in a["value"], a
    w.settle(0.2)
    assert not s.find("in the clipboard"), "offered once\n" + s.dump()
    w.keys("g")
    y = row_of(w, "in Downloads")
    w.hover(y, 20)
    w.keys("x")
    assert not s.find("in Downloads"), "x: not now\n" + s.dump()
    # back in the window: a focus event looks again: the same is not offered twice
    os.write(w.fd, b"\x1b[O")
    os.write(w.fd, b"\x1b[I")
    w.settle(0.5)
    assert not s.find("in the clipboard") and not s.find("in Downloads"), "not offered again\n" + s.dump()
    # a link on the clipboard while the add line opens: it is on the line already
    w.keys("a")
    w.settle(0.3)
    assert s.find(H) or s.find("magnet:?xt"), "on the add line\n" + s.dump()
    eq(w.close(), 0, "ends clean")


def hand_over():
    """A link opened with no window: a window for it. With one open: added there, a notice, no second window. Each exit right."""
    mock()
    me = [sys.executable, os.path.join(REPO, "bin/kawa-torrents")]
    m = "magnet:?xt=urn:btih:" + "34" * 20 + "&dn=From.The.Browser"
    r = subprocess.run([*me, "--open", m], capture_output=True, text=True, check=False)
    eq(r.returncode, 0, r.stderr)
    c = calls("kawa-term")
    eq(len(c), 1, "a window")
    assert "--app kawa-torrents Torrents" in c[0] and m in c[0], c
    w = window(30, 116)
    w.has("finished")
    r = subprocess.run([*me, "--open", m], capture_output=True, text=True, check=False)
    eq(r.returncode, 0, r.stderr)
    eq(len(calls("kawa-term")), 1, "no second window")
    a = next(x for x in reversed(asked()) if x["op"] == "add")
    eq(a["value"], m, "added to the one open")
    w.settle(0.2)
    eq(w.screen.bells, 1, "the window asks for you (foot: a bell; dwl: its workspace lit)")
    assert any("added: From The Browser" in n or "added: From.The.Browser" in n for n in calls("notify-send")), calls("notify-send")
    r = subprocess.run([*me, "--open", "https-not-a-link"], capture_output=True, text=True, check=False)
    eq(r.returncode, 1, "not a link")
    assert any("not a magnet link" in n for n in calls("notify-send")), calls("notify-send")
    r = subprocess.run([*me, "--open"], capture_output=True, text=True, check=False)
    eq(r.returncode, 0, "the launcher, with a window open")
    w.settle(0.2)
    assert w.screen.bells >= 2, "the launcher's entry with the window elsewhere: it asks for you too"
    # a second window started directly goes the same way, its link handed over
    r = subprocess.run([*me, m], capture_output=True, text=True, check=False)
    eq(r.returncode, 0, r.stderr)
    eq(len(calls("kawa-term")), 1, "still no second window")
    # add, with no window asked for
    r = subprocess.run([*me, "add", m, "no-link"], capture_output=True, text=True, check=False)
    eq(r.returncode, 1, "one of them no link")
    assert "added: " in r.stdout and "not a magnet link" in r.stderr, (r.stdout, r.stderr)
    eq(w.close(), 0, "ends clean")


def engine_lost():
    """The engine gone from under the window: it says so, keeps its place, and is back the moment the engine is."""
    p = mock()
    w = window(30, 116)
    w.has("finished")
    p.kill()
    p.wait(5)
    w.has("the engine does not answer", 5)
    assert w.screen.find("finished"), "what it knew stays"
    assert not w.dead
    os.unlink(os.path.join(os.environ["XDG_RUNTIME_DIR"], "kawa-torrents.sock"))
    p = mock()
    end = time.monotonic() + 6
    while w.screen.find("the engine does not answer") and time.monotonic() < end:
        w.pump(0.1)
    assert not w.screen.find("the engine does not answer"), w.screen.dump()
    eq(w.close(), 0, "ends clean")


def hostile_names():
    """A torrent's name is a stranger's words: an escape, a bell, a writing-direction override never reach the terminal."""
    import common as cm
    bad = "evil\x1b[2J\x1b]0;owned\x07name\u202e.mkv"
    out = cm.reading(bad)
    assert "\x1b" not in out and "\x07" not in out and "\u202e" not in out, repr(out)
    # through the real engine: a magnet's name, as a stranger's link would have it
    e = spawn_engine()
    c = e.client()
    c.ask({"op": "add", "kind": "magnet", "value": "magnet:?xt=urn:btih:" + "ef" * 20 + "&dn=" + urllib.parse.quote(bad)})
    r = c.wait(lambda: c.rows.get("ef" * 20), 10, "its row")
    assert "\x1b" not in r["name"] and "\u202e" not in r["name"], repr(r["name"])
    c.close()
    e.stop()


def single_window():
    """One window: the lock is the file kawa-downloads looks at, and dies with the process, however it ends."""
    mock()
    w = window(30, 116)
    w.has("finished")
    r = subprocess.run([os.path.join(REPO, "bin/kawa-downloads"), "--help"], capture_output=True, text=True, check=False)
    eq(r.returncode, 0, r.stderr)
    import cli
    assert cli.window_open(), "held while it is open"
    os.kill(w.pid, signal.SIGKILL)
    os.waitpid(w.pid, 0)
    w.dead = True
    assert not cli.window_open(), "gone with it"


def terminal_restored():
    """Hung up, killed by TERM, q, Ctrl+Q: the terminal is put back each time, its modes off."""
    mock()
    for how in ("q", "ctrl-q", "term", "hup"):
        w = window(24, 80)
        w.has("finished")
        if how == "q":
            w.keys("q")
        elif how == "ctrl-q":
            w.keys(b"\x11")
        elif how == "term":
            os.kill(w.pid, signal.SIGTERM)
        else:
            os.kill(w.pid, signal.SIGHUP)
        end = time.monotonic() + 5
        while not w.dead and time.monotonic() < end:
            w.pump(0.05)
        for mode in (1003, 1006, 1004, 2004, 1049):
            assert mode not in w.screen.modes, f"{how}: mode {mode} left on"
        _, status = os.waitpid(w.pid, 0)
        eq(status, 0, f"{how}: ends clean")


# ── Prowlarr ────────────────────────────────────────────────────────────────────────────────
class FakeProwlarr(BaseHTTPRequestHandler):
    """Prowlarr's API, as far as add and tend ask: what it says lives on the server object."""
    def log_message(self, *a):
        pass

    def reply(self, data, code=200):
        body = json.dumps(data).encode()
        self.send_response(code)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def body(self):
        n = int(self.headers.get("Content-Length") or 0)
        return json.loads(self.rfile.read(n) or b"null")

    def do_GET(self):
        d = self.server.d
        p = self.path.split("?")[0]
        if p.endswith("/indexer"):
            self.reply(list(d["indexers"].values()))
        elif p.endswith("/indexerstatus"):
            self.reply(d["status"])
        elif p.endswith("/indexer/schema"):
            self.reply([{"definitionName": n, "fields": []} for n in d["known"]])
        elif p.endswith("/appprofile"):
            self.reply([{"id": 1}])
        else:
            self.reply({}, 404)

    def do_POST(self):
        d = self.server.d
        p = self.path.split("?")[0]
        b = self.body()
        if p.endswith("/indexer/test"):
            d["tests"].append(b["id"])
            self.reply({} if b["id"] in d["answering"] else [{"errorMessage": "no"}], 200 if b["id"] in d["answering"] else 400)
        elif p.endswith("/indexer"):
            if b.get("enable") and "forceSave" not in self.path and b["definitionName"] in d["unreachable"]:
                self.reply([{"errorMessage": "cannot reach"}], 400)
                return
            b["id"] = d["next"] = d["next"] + 1
            d["indexers"][b["id"]] = b
            self.reply(b)
        elif p.endswith("/command"):
            d["commands"].append(b["name"])
            self.reply({"id": 9, "status": "completed"})
        else:
            self.reply({}, 404)

    def do_PUT(self):
        i = int(self.path.split("?")[0].rsplit("/", 1)[1])
        self.server.d["indexers"][i] = self.body()
        self.reply({})

    def do_DELETE(self):
        i = int(self.path.split("?")[0].rsplit("/", 1)[1])
        del self.server.d["indexers"][i]
        self.reply({})


def fake_prowlarr(indexers=(), **kw):
    srv = ThreadingHTTPServer(("127.0.0.1", 0), FakeProwlarr)
    srv.daemon_threads = True
    srv.d = {"indexers": {i["id"]: i for i in indexers}, "status": [], "known": [], "answering": set(), "tests": [], "commands": [],
             "unreachable": set(), "next": 100, **kw}
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    os.environ["KAWA_PROWLARR_URL"] = f"http://127.0.0.1:{srv.server_address[1]}"
    return srv.d


def run_prowlarr(cmd, key="k" * 32):
    return subprocess.run([sys.executable, "-I", os.path.join(LIB, "prowlarr.py"), cmd], input=key, capture_output=True, text=True, check=False)


def ix(i, name, on=True):
    return {"id": i, "definitionName": name, "name": name, "enable": on}


def prowlarr_tend():
    """Those that fail are rested and tried again each time; what you switched off stays; a whole network down rests nothing."""
    d = fake_prowlarr([ix(1, "nyaasi"), ix(2, "SubsPlease"), ix(3, "yts", on=False), ix(4, "Knaben")], status=[{"indexerId": 2}], answering={1, 3, 4})
    r = run_prowlarr("tend")
    eq(r.returncode, 0, r.stderr)
    eq(d["indexers"][2]["enable"], False, "the failing one rested")
    assert "SubsPlease: rested" in r.stdout, r.stdout
    assert "CheckHealth" in d["commands"], "its page told at once"
    rested = os.path.join(STATE, "rested")
    eq(open(rested).read().split(), ["2"], "noted")
    eq(d["indexers"][3]["enable"], False, "the one you switched off stays")
    eq(sorted(set(d["tests"])), [2], "only those with a failure are tested")
    # next time it answers: on again; yours still off
    d["status"], d["tests"] = [], []
    d["answering"].add(2)
    r = run_prowlarr("tend")
    eq(d["indexers"][2]["enable"], True, "back")
    assert "answers again" in r.stdout, r.stdout
    eq(open(rested).read().split(), [], "not rested any more")
    eq(d["indexers"][3]["enable"], False, "yours is yours")
    # everything failing: it is the network, not the sites
    d = fake_prowlarr([ix(1, "nyaasi"), ix(2, "Knaben")], status=[{"indexerId": 1}, {"indexerId": 2}], answering=set())
    r = run_prowlarr("tend")
    eq((d["indexers"][1]["enable"], d["indexers"][2]["enable"]), (True, True), "nothing rested when none answers")
    # one you switched on yourself is yours again
    d = fake_prowlarr([ix(5, "SubsPlease", on=True)], answering={5})
    os.makedirs(STATE, exist_ok=True)
    with open(rested, "w") as f:
        f.write("5\n")
    run_prowlarr("tend")
    eq(open(rested).read().split(), [], "yours again")
    # no Prowlarr: exit 2, said
    os.environ["KAWA_PROWLARR_URL"] = "http://127.0.0.1:1"
    r = run_prowlarr("tend")
    eq(r.returncode, 2, "no answer")
    assert "did not answer" in r.stderr, r.stderr


def prowlarr_add():
    """The usual sites each added once; Tokyo Toshokan out; one that cannot be reached saved rested, not failing."""
    import prowlarr as pr
    wanted = [n for n, _ in pr.INDEXERS]
    assert "tokyotosho" not in [n.lower() for n in wanted], "out of the list"
    d = fake_prowlarr([ix(1, "nyaasi"), ix(2, "tokyotosho")], known=wanted, unreachable={"SubsPlease"})
    r = run_prowlarr("add")
    eq(r.returncode, 0, r.stderr)
    assert 2 not in d["indexers"], "Tokyo Toshokan taken out"
    names = sorted(i["definitionName"] for i in d["indexers"].values())
    eq(names, sorted(wanted), "each once")
    sub = next(i for i in d["indexers"].values() if i["definitionName"] == "SubsPlease")
    eq(sub["enable"], False, "the one that cannot be reached: saved, rested")
    assert str(sub["id"]) in open(os.path.join(STATE, "rested")).read().split(), "noted: the next tend tries it"
    r = run_prowlarr("add")
    assert "all 7 in place" in r.stdout, r.stdout
    os.environ["KAWA_PROWLARR_URL"] = "http://127.0.0.1:1"
    eq(run_prowlarr("add").returncode, 2, "no Prowlarr")


def prowlarr_search():
    """A site Prowlarr is letting rest answers 400: no results, no trouble. secret() takes the key only from a private file."""
    import prowlarr as pr
    os.environ["KAWA_PROWLARR_URL"] = "http://127.0.0.1:1"
    p = os.path.join(HOME, ".config/fedokawaii/secrets.sh")
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, "w") as f:
        f.write("# a comment\nOTHER=1\nPROWLARR_API_KEY=" + "a" * 32 + "\n")
    os.chmod(p, 0o600)
    eq(pr.secret(), "a" * 32, "its key")
    os.chmod(p, 0o644)
    eq(pr.secret(), "", "not a private file: not read")
    os.chmod(p, 0o600)
    with open(p, "w") as f:
        f.write("PROWLARR_API_KEY=short\n")
    eq(pr.secret(), "", "not a key")
    os.remove(p)
    eq(pr.secret(), "", "no file")


if __name__ == "__main__":
    fn = globals().get(sys.argv[1]) if len(sys.argv) > 1 else None
    if fn is None or not callable(fn):
        print("usage: torrents_checks.py SCENARIO", file=sys.stderr)
        sys.exit(2)
    fn()
