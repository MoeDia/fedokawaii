"""The command's words other than the engine: the window, a link added from anywhere, a magnet taken out of a
.torrent file, an older program's list taken over."""
import json
import os
import socket
import sqlite3
import subprocess
import sys
import time

import common


def ask_engine(q, wait=8):
    """One question to the engine (systemd starts it if it sleeps): its answer, or None."""
    end = time.monotonic() + 3
    while True:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.settimeout(wait)
        try:
            s.connect(common.SOCK)
            break
        except OSError:
            s.close()
            if time.monotonic() > end:
                return None
            subprocess.run(["systemctl", "--user", "start", "--no-block", "kawa-torrents.socket"], stdin=subprocess.DEVNULL,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
            time.sleep(0.1)
    try:
        s.sendall((json.dumps({**q, "n": 1}) + "\n").encode())
        buf = b""
        while True:
            data = s.recv(1 << 20)
            if not data:
                return None
            buf += data
            *lines, buf = buf.split(b"\n")
            for line in lines:
                m = json.loads(line)
                if m.get("re") == 1:
                    return m
    except OSError:
        return None
    finally:
        s.close()


def add(args):
    rc = 0
    for arg in args:
        found = common.links(arg)
        if not found:
            print(f"kawa-torrents: not a magnet link, a .torrent file or a link to one: {common.without_key(arg)}", file=sys.stderr)
            rc = 1
            continue
        for kind, value in found:
            a = ask_engine({"op": "add", "kind": kind, "value": value})
            if a is None:
                print("kawa-torrents: the engine does not answer — systemctl --user status kawa-torrents", file=sys.stderr)
                return 1
            if a.get("err"):
                print(f"kawa-torrents: {a['err']}", file=sys.stderr)
                rc = 1
            else:
                print(("already here: " if a.get("known") else "added: ") + a["id"])
    return rc


def notify(words, urgency="normal"):
    icon = ""
    try:
        import app
        icon = app.load_icons().get("DOWNLOAD", "")
    except (ImportError, OSError):
        pass
    subprocess.run(["notify-send", "-a", "torrents", "-u", urgency, "--", f"{icon}  torrents", words], stdin=subprocess.DEVNULL,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)


def window_open():
    import fcntl
    try:
        with open(common.WINDOW, "a") as f:
            fcntl.flock(f, fcntl.LOCK_EX | fcntl.LOCK_NB)
            return False
    except BlockingIOError:
        return True
    except OSError:
        return False


def open_link(args):
    """From the launcher and xdg-open: a window of its own, or, while one is open, the link added to it. The
    window it is added to shows it at once, wherever it stands: a notice says so here too."""
    if window_open():
        if args and args[0]:
            found = common.links(args[0])
            if not found:
                notify("not a magnet link or a .torrent file", "critical")
                return 1
            for kind, value in found:
                a = ask_engine({"op": "add", "kind": kind, "value": value})
                if a is None:
                    notify("the engine does not answer: systemctl --user status kawa-torrents", "critical")
                    return 1
                if a.get("err"):
                    notify(a["err"], "critical")
                    return 1
                name = common.magnet_name(value) if kind == "magnet" else common.reading(os.path.basename(value))
                notify(("already here: " if a.get("known") else "added: ") + name)
        return 0
    cmd = ["kawa-term", "--app", "kawa-torrents", "Torrents", os.path.realpath(sys.argv[0])]
    if args and args[0]:
        cmd.append(args[0])
    os.execvp(cmd[0], cmd)
    return 1


def magnet_of_file(path):
    import libtorrent as lt
    return lt.make_magnet_uri(lt.torrent_info(path))


def magnet(args):
    if len(args) != 1:
        print("usage: kawa-torrents magnet FILE.torrent", file=sys.stderr)
        return 2
    path = common.file_uri_path(args[0]) if args[0].startswith("file://") else args[0]
    try:
        link = magnet_of_file(path)
    except (RuntimeError, OSError, ValueError) as e:
        print(f"kawa-torrents: not a .torrent file that can be read: {path} ({e})", file=sys.stderr)
        return 1
    print(link)
    try:
        subprocess.Popen(["wl-copy", "--", link], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    except OSError:
        pass
    return 0


def inherit(args):
    """torrra's list (~/.local/share/torrra/torrra.db) → inherited.json, which the engine adds at its next start: each
    with its chosen files; those it had told of stay told. Its magnet links know no files: they are fetched once and the
    data on the disk checked once. An old list with nothing in it, or none at all: nothing to do. Exit 1: it could not be read."""
    db = args[0] if args else os.path.join(common.HOME, ".local/share/torrra/torrra.db")
    if not os.path.exists(db):
        return 0
    try:
        con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
        con.row_factory = sqlite3.Row
        rows = con.execute("SELECT * FROM torrents").fetchall()
        con.close()
    except sqlite3.Error as e:
        print(f"kawa-torrents: torrra's list could not be read: {e}", file=sys.stderr)
        return 1
    items = []
    for r in rows:
        r = dict(r)
        link = r.get("magnet_uri") or ""
        if not link.startswith("magnet:"):
            continue
        prios = None
        if r.get("file_priorities"):
            try:
                prios = json.loads(r["file_priorities"])
            except ValueError:
                prios = None
        items.append({"magnet": link, "name": r.get("title") or "", "source": r.get("source") or "", "paused": bool(r.get("is_paused")),
                      "told": bool(r.get("is_notified")), "priorities": prios, "folder": r.get("save_path") or ""})
    if items:
        os.makedirs(common.STATE, mode=0o700, exist_ok=True)
        path = os.path.join(common.STATE, "inherited.json")
        with open(path + ".new", "w", encoding="utf-8") as f:
            json.dump(items, f)
        os.replace(path + ".new", path)
    print(f"torrents: {len(items)} taken over from torrra")
    return 0


def check():
    """What verify asks: this program whole, and libtorrent loading in it."""
    problems = []
    try:
        import libtorrent as lt
        major = int(lt.__version__.split(".")[0])
        if major < 2:
            problems.append(f"libtorrent {lt.__version__}: 2.0 or newer is needed")
    except ImportError as e:
        problems.append(f"libtorrent does not load ({e}): the rb_libtorrent-python3 package, fedokawaii repair puts it back")
    for mod in ("app", "term", "prowlarr"):
        try:
            __import__(mod)
        except ImportError as e:
            problems.append(f"{mod}: {e}")
    if problems:
        for p in problems:
            print(f"kawa-torrents: {p}", file=sys.stderr)
        return 1
    print(f"kawa-torrents: whole, libtorrent {lt.__version__}, Python {sys.version.split()[0]}")
    return 0


def tend():
    import prowlarr
    key = prowlarr.secret()
    if not key:
        print("kawa-torrents: no PROWLARR_API_KEY in secrets.sh", file=sys.stderr)
        return 1
    return prowlarr.tend(key)


def main(args):
    cmd = args[0] if args else ""
    if cmd == "add":
        return add(args[1:])
    if cmd == "magnet":
        return magnet(args[1:])
    if cmd == "inherit":
        return inherit(args[1:])
    if cmd == "tend":
        return tend()
    if cmd == "--check":
        return check()
    if cmd == "--open":
        return open_link(args[1:])
    if cmd.startswith("-") or cmd in ("list",):
        print("usage: kawa-torrents [LINK] | --open [LINK] | add LINK… | magnet FILE | tend | --check  (kawa-torrents --help)", file=sys.stderr)
        return 2
    import app
    rc = app.run_window(args)
    if rc is None:                                 # (open already: this one's link goes there)
        return open_link(args)
    return rc
