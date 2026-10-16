#!/usr/bin/env python3
"""tests/yazi/syncplay_pair.py — two friends watching together, for real: a syncplay-server on
127.0.0.1 (with a password), and alice and bob each starting kawa-together in a home of their
own that holds the desktop's mpv config and scripts (TEMPLATE: a home test_syncplay.sh made with
the harness). Their players (real mpv, no picture, no sound) are driven over Syncplay's own
sockets, the way a person would press keys; what Syncplay says is read from its terminal.

    python3 syncplay_pair.py TEMPLATE MEDIA SYNCPLAY_DIR MPV KAWA_TOGETHER

MEDIA holds film.mkv and other.mkv. Prints "case TEXT", then "ok" or "no WHY" per check (the
test file turns them into its report); anything else is commentary.
"""
import glob, json, os, re, shutil, signal, socket, subprocess, sys, tempfile, time

TEMPLATE, MEDIA, SPDIR, MPV, TOGETHER = sys.argv[1:6]
FILM, OTHER = MEDIA + "/film.mkv", MEDIA + "/other.mkv"
ROOT = os.path.dirname(TEMPLATE)
RUN = os.environ["XDG_RUNTIME_DIR"]
PW = "pa55 word"
procs = []


def case(text):
    print("case " + text, flush=True)


def check(ok, why=""):
    print("ok" if ok else "no " + str(why)[:400], flush=True)


def ipc(path, cmd, timeout=3.0):
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.settimeout(timeout)
    s.connect(path)
    s.sendall((json.dumps({"command": cmd, "request_id": 5}) + "\n").encode())
    buf, end = b"", time.time() + timeout
    while time.time() < end:
        buf += s.recv(65536)
        for ln in buf.split(b"\n"):
            if ln.strip() and json.loads(ln).get("request_id") == 5:
                s.close()
                return json.loads(ln)
    s.close()
    raise TimeoutError(cmd)


def get(path, prop):
    return ipc(path, ["get_property", prop]).get("data")


def until(fn, timeout=10):
    end = time.time() + timeout
    while time.time() < end:
        try:
            v = fn()
            if v:
                return v
        except (OSError, TimeoutError, ValueError, KeyError, TypeError):
            pass
        time.sleep(0.1)
    return None


def free_port():
    s = socket.socket()
    s.bind(("127.0.0.1", 0))
    p = s.getsockname()[1]
    s.close()
    return p


PORT = free_port()


def env(home):
    e = dict(os.environ, HOME=home, XDG_CONFIG_HOME=home + "/.config", XDG_STATE_HOME=home + "/.local/state",
             XDG_CACHE_HOME=home + "/.cache", XDG_DATA_HOME=home + "/.local/share")
    e["PATH"] = SPDIR + ":" + os.path.dirname(MPV) + ":" + e["PATH"]
    return e


def home_for(name, media=True):
    h = os.path.join(ROOT, name)
    shutil.copytree(TEMPLATE, h, symlinks=True)
    dirs = repr([MEDIA]) if media else "{}"
    # as theme.sh starts it, pointed at the test's server and player (no picture, no sound:
    # Syncplay's own per-player arguments, so mpv.conf stays the desktop's)
    args = repr({MPV: ["--vo=null", "--ao=null"]})
    with open(h + "/.config/syncplay.ini", "w") as f:
        f.write(f"[server_data]\nhost = 127.0.0.1\nport = {PORT}\npassword = {PW}\n\n"
                f"[client_settings]\nname = {name}\nroom = film\nplayerpath = {MPV}\n"
                f"perplayerarguments = {args}\nmediasearchdirectories = {dirs}\n\n"
                f"[general]\ncheckforupdatesautomatically = False\n")
    return h


def spots(h):   # the spots mpv keeps in this home: {start seconds}
    out = set()
    for f in glob.glob(h + "/.local/state/mpv/watch_later/*"):
        for ln in open(f):
            if ln.startswith("start="):
                out.add(round(float(ln[6:])))
    return out


def save_spot(h, f, at):   # watched alone first, up to AT seconds (mpv keeps the spot on quit)
    sock = RUN + "/solo.sock"
    before = spots(h)
    for _ in range(3):         # (a slow machine: the seek not there yet when it quit — again)
        p = subprocess.Popen([MPV, "--vo=null", "--ao=null", "--pause", "--input-ipc-server=" + sock, f], env=env(h),
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        until(lambda: get(sock, "duration"), 20)
        ipc(sock, ["seek", at, "absolute"])
        until(lambda: abs(get(sock, "time-pos") - at) < 0.5, 20)
        ipc(sock, ["quit"])
        p.wait(10)
        if spots(h) == before | {at}:
            return
    raise RuntimeError(f"mpv kept no spot at {at} s for {os.path.basename(f)} (it has {sorted(spots(h))})")


class Friend:
    def __init__(self, name, media=True):
        self.name, self.home = name, home_for(name, media)
        self.logpath = os.path.join(ROOT, name + ".log")

    def start(self, file):
        # (Syncplay 1.7.6 connects to mpv's socket the moment the file appears, and now and
        # then before mpv listens: "Could not load mpv". A person starts it again; so does this)
        for _ in range(2):
            self.p = subprocess.Popen([TOGETHER, file], stdin=subprocess.PIPE, stdout=open(self.logpath, "a"),
                                      stderr=subprocess.STDOUT, env=env(self.home), start_new_session=True, text=True)
            procs.append(self.p)
            self.sock = until(lambda: "Could not load mpv" not in self.log() and self.find_sock(), 25)
            if self.sock and "Could not load mpv" not in self.log():
                return self.sock
            print(self.name + ": Syncplay could not reach its mpv — started again")
            self.stop()
            open(self.logpath, "w").close()
        return None

    def find_sock(self):
        todo = [self.p.pid]
        while todo:
            pid = todo.pop()
            for d in os.listdir("/proc"):
                if not d.isdigit():
                    continue
                try:
                    if int(open(f"/proc/{d}/stat").read().rsplit(")", 1)[1].split()[1]) != pid:
                        continue
                    args = open(f"/proc/{d}/cmdline").read().split("\0")
                except (OSError, ValueError, IndexError):
                    continue
                todo.append(int(d))
                for a in args:
                    if a.startswith("--input-ipc-server="):
                        get(a.split("=", 1)[1], "pid")
                        return a.split("=", 1)[1]
        return None

    def log(self):
        try:
            return open(self.logpath, errors="replace").read()
        except FileNotFoundError:
            return ""

    def mark(self):
        self.at = len(self.log())

    def said(self, pattern, timeout=10):
        return until(lambda: re.search(pattern, self.log()[self.at:]), timeout)

    def say(self, line):
        self.p.stdin.write(line + "\n")
        self.p.stdin.flush()

    def pos(self):             # (none while a file loads: asked again for a few seconds)
        v = until(lambda: (lambda t: None if t is None else [t])(get(self.sock, "time-pos")), 5)
        return v[0] if v else None

    def stop(self):
        try:
            os.killpg(self.p.pid, signal.SIGHUP)    # (as closing its terminal window does)
            self.p.wait(10)
        except (OSError, subprocess.TimeoutExpired):
            os.killpg(self.p.pid, signal.SIGKILL)


server = None


def start_server():
    global server
    server = subprocess.Popen([SPDIR + "/syncplay-server", "--port", str(PORT), "--password", PW, "--ipv4-only",
                               "--interface-ipv4", "127.0.0.1"], stdout=open(ROOT + "/server.log", "a"),
                              stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL, env=env(ROOT), start_new_session=True)
    return until(lambda: socket.create_connection(("127.0.0.1", PORT), 0.5).close() or True, 15)


def stop_server():
    os.killpg(server.pid, signal.SIGTERM)
    server.wait(10)


try:
    alice, bob, carol = Friend("alice"), Friend("bob"), Friend("carol", media=False)
    save_spot(alice.home, FILM, 40)
    save_spot(alice.home, OTHER, 30)
    print("alice's own spots before:", sorted(spots(alice.home)))
    start_server()

    case("alice and bob start kawa-together: both in room 'film' (password taken), the same film, paused")
    alice.mark(); bob.mark()
    sa = alice.start(FILM)
    check(alice.said(r"Successfully connected to server", 15), alice.log()[-300:])
    check(sa, "alice's mpv never answered")
    alice.said(r"alice is playing 'film.mkv'", 15)
    sb = bob.start(FILM)
    check(alice.said(r"bob has joined the room: 'film'", 15), alice.log()[alice.at:][-300:])
    check(bob.said(r"<alice> is playing:\s+File: 'film.mkv'|alice is playing 'film.mkv'", 15), bob.log()[-300:])
    check(until(lambda: get(sa, "filename") == get(sb, "filename") == "film.mkv"))
    # (kawa-ipc.lua steps aside for Syncplay's own socket: no second one of ours)
    check(sa.startswith(RUN + "/syncplay-") and not glob.glob(RUN + "/mpv-*.sock"), (sa, glob.glob(RUN + "/mpv-*.sock")))
    # (as bob comes in Syncplay settles the room's state — now and then playing: paused here,
    # as a person would)
    ipc(sa, ["set_property", "pause", True])
    check(until(lambda: get(sa, "pause") is True and get(sb, "pause") is True, 8), (get(sa, "pause"), get(sb, "pause")))

    case("the desktop's mpv in Syncplay: alice's own spot (40 s) is not opened, and the room hears no jump")
    time.sleep(2)
    check(alice.pos() < 15, alice.pos())
    check(bob.pos() < 15, bob.pos())
    check(not re.search(r"alice jumped from [\d:]+ to 00:(3[5-9]|4[0-5])", bob.log()), re.findall(r"alice jumped[^\n]*", bob.log()))

    case("ready: alice unpauses while bob is not ready — she is set ready, both stay paused")
    alice.mark()
    ipc(sa, ["set_property", "pause", False])
    check(alice.said(r"You are now set as ready"), alice.log()[alice.at:][-300:])
    time.sleep(1.5)
    check(get(sa, "pause") is True and get(sb, "pause") is True, (get(sa, "pause"), get(sb, "pause")))
    case("bob unpauses: both play, in step (within Syncplay's own 1.5 s)")
    ipc(sb, ["set_property", "pause", False])
    check(until(lambda: get(sa, "pause") is False and get(sb, "pause") is False, 8), (get(sa, "pause"), get(sb, "pause")))
    time.sleep(2)
    check(abs(alice.pos() - bob.pos()) < 1.5, (alice.pos(), bob.pos()))

    case("a pause in one player pauses the other, at the same spot")
    ipc(sa, ["set_property", "pause", True])
    check(until(lambda: get(sb, "pause") is True, 5))
    time.sleep(0.8)
    check(abs(alice.pos() - bob.pos()) < 1.5, (alice.pos(), bob.pos()))

    case("a seek in one player moves the other, and Syncplay says who jumped")
    alice.mark()
    ipc(sb, ["seek", 25, "absolute"])
    check(until(lambda: abs(alice.pos() - 25) < 1, 6), alice.pos())
    check(alice.said(r"bob jumped from .* to 00:25", 5))

    case("chat: from bob's terminal (ch), and typed in alice's mpv window (Enter, the words, Enter)")
    alice.mark(); bob.mark()
    bob.say("ch hello from bob")
    check(alice.said(r"<bob> hello from bob", 6), alice.log()[alice.at:][-300:])
    for k in ["ENTER", "h", "i", "SPACE", "b", "o", "b", "ENTER"]:
        ipc(sa, ["keypress", k])
        time.sleep(0.08)
    check(bob.said(r"<alice> hi bob", 6), bob.log()[bob.at:][-300:])
    check(get(sa, "pause") is True, "the keys typed into the chat moved the film instead")

    case("carol joins with another file: alice is told it differs")
    alice.mark()
    carol.start(OTHER)
    check(alice.said(r"File you are playing appears to be different from carol's|Your file differs", 15),
          alice.log()[alice.at:][-400:])
    carol.stop()
    alice.said(r"carol has left", 10)

    case("the room's next file (alice: qas other.mkv), one alice half-watched alone (30 s): nobody is moved there")
    ipc(sa, ["set_property", "pause", True])         # (carol's visit set the room playing)
    until(lambda: get(sb, "pause") is True, 5)
    bob.mark()
    alice.say("qas " + OTHER)
    check(until(lambda: get(sa, "filename") == get(sb, "filename") == "other.mkv", 15), (get(sa, "filename"), get(sb, "filename")))
    seen = []
    t0 = time.time()
    while time.time() - t0 < 4:
        try:
            seen.append((alice.pos(), bob.pos()))
        except (OSError, TimeoutError):
            pass
        time.sleep(0.2)
    top = max((max(a or 0, b or 0) for a, b in seen), default=-1)
    check(0 <= top < 5, f"furthest: {top} s")
    jumps = re.findall(r"alice jumped from [\d:]+ to 00:(\d\d)", bob.log()[bob.at:])
    check(not [j for j in jumps if 25 <= int(j) <= 35], re.findall(r"alice jumped[^\n]*", bob.log()[bob.at:]))

    case("the server restarts: both reconnect, and a seek still travels")
    alice.mark(); bob.mark()
    stop_server()
    check(alice.said(r"Connection with server lost", 15))
    time.sleep(1)
    start_server()
    check(alice.said(r"Successfully connected to server", 30), alice.log()[alice.at:][-300:])
    check(bob.said(r"Successfully connected to server", 30), bob.log()[bob.at:][-300:])
    # (back in, Syncplay reloads the room's file and, for 1.5 s, puts a stray position back
    # to the start: the seek waits till that is over, as a person would not notice)
    alice.said(r"alice is playing 'other.mkv'", 20)
    time.sleep(3)
    ipc(sa, ["seek", 12, "absolute"])
    check(until(lambda: abs(bob.pos() - 12) < 1, 8), bob.pos())

    case("alice closes her player: her own spots (40 s, 30 s) are as she left them")
    ipc(sa, ["quit"])
    until(lambda: alice.p.poll() is not None, 5)
    check(spots(alice.home) == {40, 30}, sorted(spots(alice.home)))
except Exception as e:                       # (a step that broke: the case it was in fails)
    check(False, f"the run stopped: {type(e).__name__}: {e}")
finally:
    for p in procs:
        try:
            os.killpg(p.pid, signal.SIGHUP)
        except OSError:
            pass
    for p in procs:
        try:
            p.wait(10)
        except subprocess.TimeoutExpired:
            os.killpg(p.pid, signal.SIGKILL)
    if server:
        try:
            os.killpg(server.pid, signal.SIGKILL)
        except OSError:
            pass
