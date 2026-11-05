#!/usr/bin/python3
"""tools/torrent-stress.py — how Torrents holds up, measured, in a throw-away home (nothing of the real one is read or written,
nothing reaches the session). The numbers T29 is judged by:

    python3 tools/torrent-stress.py                the local swarm: 50 torrents on the loopback; the window at 500 rows
    python3 tools/torrent-stress.py --real HASH …  also the real network, at the turtle's speed: add → first peer, → metadata,
                                                   for each info hash given (a distribution's ISO: nothing is kept)
    python3 tools/torrent-stress.py --torrra       also the program before it, torrra, if it is still installed (its window)

Prints a table; exit 0 when redraw at 500 rows stays under 50 ms (p95) and every torrent came through; 1 otherwise.
"""
import argparse
import atexit
import os
import shutil
import signal
import subprocess
import sys
import tempfile
import time

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.environ["REPO"] = REPO
sys.path.insert(0, os.path.join(REPO, "tests/engine"))
LIB = os.path.join(REPO, "configs/home/.local/lib/fedokawaii/kawa-torrents")
sys.path.insert(0, LIB)


def sandbox():
    tmp = tempfile.mkdtemp(prefix="torrent-stress.", dir="/dev/shm" if os.path.isdir("/dev/shm") else None)
    atexit.register(shutil.rmtree, tmp, True)
    home, run = os.path.join(tmp, "home"), os.path.join(tmp, "run")
    os.makedirs(os.path.join(home, ".config/fedokawaii"))
    os.makedirs(run, mode=0o700)
    shutil.copy(os.path.join(REPO, "configs/home/.config/fedokawaii/icons.sh"), os.path.join(home, ".config/fedokawaii/icons.sh"))
    stubs = os.path.join(tmp, "stubs")
    os.makedirs(stubs)
    for name in ("kawa-downloads", "kawa-prowlarr", "kawa-play", "wl-copy", "wl-paste", "systemctl", "notify-send"):
        p = os.path.join(stubs, name)
        with open(p, "w", encoding="utf-8") as f:
            f.write("#!/bin/sh\nexit 0\n")
        os.chmod(p, 0o755)
    os.environ.update(HOME=home, XDG_RUNTIME_DIR=run, XDG_STATE_HOME=os.path.join(home, ".local/state"), XDG_CACHE_HOME=os.path.join(home, ".cache"),
                      XDG_CONFIG_HOME=os.path.join(home, ".config"), DBUS_SESSION_BUS_ADDRESS=f"unix:path={run}/bus", WAYLAND_DISPLAY="wayland-none",
                      KAWA_TORRENTS_LIB=LIB, PATH=stubs + ":" + os.environ["PATH"])
    os.environ.pop("DISPLAY", None)
    return tmp


def memory(pid):
    """RSS in MB, and what of it is the process's own (RssAnon): the rest is shared libraries and the files it maps."""
    vals = {}
    with open(f"/proc/{pid}/status", encoding="utf-8") as f:
        for line in f:
            if line.startswith(("VmRSS:", "RssAnon:")):
                k, v = line.split()[:2]
                vals[k] = int(v) / 1024
    return f"{vals['VmRSS:']:.1f} MB ({vals['RssAnon:']:.1f} own)"


def cpu_seconds(pid):
    with open(f"/proc/{pid}/stat", encoding="utf-8") as f:
        p = f.read().rsplit(")", 1)[1].split()
    return (int(p[11]) + int(p[12])) / os.sysconf("SC_CLK_TCK")


def pct(xs, p):
    xs = sorted(xs)
    return xs[min(len(xs) - 1, int(len(xs) * p / 100))]


def say(what, value):
    print(f"{what:<54} {value}", flush=True)


def swarm_test():
    from torrents_swarm import Engine, Swarm
    s = Swarm(os.path.join(os.environ["HOME"], "..", "swarm"))
    ts = [s.torrent(f"stress.{k:03d}", {"file.bin": 2 << 20}, piece=1 << 16) for k in range(50)]
    t0 = time.monotonic()
    e = Engine().start()
    atexit.register(lambda: e.proc.poll() is None and e.proc.kill())
    c = e.client()
    say("the engine: start to its socket", f"{1000 * (time.monotonic() - t0):.0f} ms")
    added, first, done = {}, {}, {}
    t1 = time.monotonic()
    for t in ts:
        added[t.hash] = time.monotonic()
        a = c.ask({"op": "add", "kind": "magnet", "value": t.magnet})
        assert not a["err"], a
    say("50 magnets added", f"{1000 * (time.monotonic() - t1):.0f} ms")
    end = time.monotonic() + 240
    while len(done) < len(ts) and time.monotonic() < end:
        c.pump(0.05)
        now = time.monotonic()
        for t in ts:
            r = c.rows.get(t.hash)
            if not r:
                continue
            if t.hash not in first and (r["peers"] or r["done"]):
                first[t.hash] = now - added[t.hash]
            if t.hash not in done and r["word"] == "done":
                done[t.hash] = now - added[t.hash]
    ok = len(done) == len(ts)
    say("came through", f"{len(done)} of {len(ts)}")
    if first:
        say("add → first peer, p50 · p95", f"{pct(list(first.values()), 50):.2f} s · {pct(list(first.values()), 95):.2f} s")
    if done:
        say("add → whole, p50 · p95 (100 MB, one seeder)", f"{pct(list(done.values()), 50):.2f} s · {pct(list(done.values()), 95):.2f} s")
    say("the engine's memory, 50 torrents", memory(e.proc.pid))
    idle0, at0 = cpu_seconds(e.proc.pid), time.monotonic()
    time.sleep(5)
    say("the engine's CPU, nothing moving", f"{100 * (cpu_seconds(e.proc.pid) - idle0) / (time.monotonic() - at0):.2f} %")
    c.close()
    e.stop()
    t2 = time.monotonic()
    e = Engine().start()
    c = e.client()
    c.wait(lambda: len(c.rows) == len(ts), 15, "the list")
    say("back up with 50, nothing hashed", f"{1000 * (time.monotonic() - t2):.0f} ms")
    c.close()
    e.stop()
    s.close()
    return ok


def window_test():
    from torrents_screen import Window
    mock = subprocess.Popen([sys.executable, "-I", os.path.join(REPO, "tests/engine/torrents_mock.py"), "--rows", "500"], env=dict(os.environ, KAWA_PROWLARR_URL="http://127.0.0.1:0"))
    atexit.register(mock.kill)
    sock = os.path.join(os.environ["XDG_RUNTIME_DIR"], "kawa-torrents.sock")
    while not os.path.exists(sock):
        time.sleep(0.01)
    me = [sys.executable, os.path.join(REPO, "bin/kawa-torrents")]
    t0 = time.monotonic()
    w = Window(me, rows=52, cols=236)
    w.until(lambda s: s.find("downloading"), 15, "the first frame")
    say("the window: start to its first frame", f"{1000 * (time.monotonic() - t0):.0f} ms")
    w.settle(0.3)
    say("the window's memory, 500 rows", memory(w.pid))
    # a key to its frame: the frame's bytes back on the pty, 300 moves
    times = []
    for k in [b"j"] * 150 + [b"k"] * 150:
        t = time.monotonic()
        os.write(w.fd, k)
        before = w.screen.updates
        while time.monotonic() - t < 1 and not (w.screen.updates > before and 2026 not in w.screen.modes):
            w.pump(0.2)
        times.append(time.monotonic() - t)
    say("a key to its frame, 500 rows, p50 · p95 · worst", f"{1000 * pct(times, 50):.1f} ms · {1000 * pct(times, 95):.1f} ms · {1000 * max(times):.1f} ms")
    c0, at0 = cpu_seconds(w.pid), time.monotonic()
    end = at0 + 5
    while time.monotonic() < end:
        w.pump(0.05)
    say("the window's CPU, its icons moving", f"{100 * (cpu_seconds(w.pid) - c0) / (time.monotonic() - at0):.2f} %")
    w.close()
    mock.kill()
    mock.wait()
    os.unlink(sock)
    return pct(times, 95) < 0.05


def seconds(x):
    return f"{x:.2f} s" if x is not None else "none in 90 s"


def real_test(hashes):
    from torrents_swarm import Client
    os.environ.pop("KAWA_TORRENTS_NET", None)
    sock = os.path.join(os.environ["XDG_RUNTIME_DIR"], "kawa-torrents.sock")
    if os.path.exists(sock):
        os.unlink(sock)
    env = dict(os.environ, KAWA_TORRENTS_IDLE="600")
    p = subprocess.Popen([sys.executable, os.path.join(REPO, "bin/kawa-torrents"), "engine"], env=env)
    atexit.register(lambda: p.poll() is None and p.kill())
    while not os.path.exists(sock):
        time.sleep(0.01)
    c = Client(sock)
    c.ask({"op": "turtle", "on": True})
    for h in hashes:
        i = h.lower()
        t0 = time.monotonic()
        c.ask({"op": "add", "kind": "magnet", "value": f"magnet:?xt=urn:btih:{h}"})
        peer = meta = None
        end = t0 + 90
        while time.monotonic() < end and (peer is None or meta is None):
            c.pump(0.1)
            r = c.rows.get(i)
            if r:
                if peer is None and r["peers"]:
                    peer = time.monotonic() - t0
                if meta is None and r["meta"]:
                    meta = time.monotonic() - t0
        say(f"the real network, {i[:12]}: first peer · its files known", f"{seconds(peer)} · {seconds(meta)}")
        c.ask({"op": "remove", "id": i, "files": True})
    say("the engine's memory after them", memory(p.pid))
    c.close()
    p.send_signal(signal.SIGTERM)
    p.wait(15)


def torrra_test():
    """The window it replaced, opened on its downloads, for the before column."""
    from torrents_screen import Window
    py = os.path.join(REAL_HOME, ".local/share/uv/tools/torrra/bin/python")
    if not os.path.exists(py):
        say("torrra", "not installed: nothing to compare")
        return
    t0 = time.monotonic()
    w = Window([py, "-I", "-c", "from torrra.__main__ import cli; cli()", "downloads"], rows=52, cols=236)
    try:
        w.until(lambda s: any(x.strip() for x in s.lines()), 20, "torrra's first frame")
        say("torrra: start to its first frame", f"{1000 * (time.monotonic() - t0):.0f} ms")
        w.settle(1.0)
        time.sleep(2)
        say("torrra: memory, its window open, nothing in it", memory(w.pid))
    finally:
        w.close()


REAL_HOME = os.path.expanduser("~")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--real", nargs="*", default=[], metavar="HASH")
    ap.add_argument("--torrra", action="store_true")
    args = ap.parse_args()
    sandbox()
    os.environ["KAWA_TORRENTS_NET"] = "local"
    ok = swarm_test()
    state = os.path.join(os.environ["XDG_STATE_HOME"], "fedokawaii/torrents")
    shutil.rmtree(state, True)
    ok = window_test() and ok
    shutil.rmtree(state, True)
    if args.torrra:
        torrra_test()
    if args.real:
        real_test(args.real)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
