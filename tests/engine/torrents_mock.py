"""tests/engine/torrents_mock.py — an engine and a Prowlarr that say exactly what they are told, for looking at the
window: every state on one screen, the same numbers on every run. The real engine is tested on a real swarm
(torrents_swarm.py); this one is for the eyes, and for sizes and lists no swarm should be asked for.

    python3 torrents_mock.py [--rows N] [--empty] → serves $XDG_RUNTIME_DIR/kawa-torrents.sock and KAWA_PROWLARR_URL until killed
"""
import json
import os
import selectors
import socket
import sys
import threading
import time
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

NOW = int(time.time())
DAY = 86400
D = os.path.join(os.path.expanduser("~"), "Downloads")


def row(i, name, word, done=0, total=0, down=0, up=0, peers=0, seeds=0, known=0, added=0, at=0, err="", meta=True, source="", stream=None):
    r = {"id": i, "name": name, "word": word, "done": done, "total": total, "down": down, "up": up, "peers": peers,
         "seeds": seeds, "known": known, "added": NOW - added, "at": NOW - at if at else 0, "progress": 0, "folder": D,
         "source": source, "err": err, "meta": meta, "ratio": 0.42 if word == "done" else 0}
    if stream:
        r["stream"] = stream
    return r


GB, MB = 1000 ** 3, 1000 ** 2
ROWS = [
    row("a" * 40, "Night.of.the.Living.Dead.1968.1080p.BluRay.x264", "downloading", int(3.1 * GB), int(7.2 * GB), int(12.4 * MB), 310000, 38, 9, 214, 60, source="Knaben",
        stream={"file": 0, "ready": True, "buffered": 1.0}),
    row("b" * 40, "debian-13.1.0-amd64-DVD-1.iso", "downloading", int(1.9 * GB), int(3.9 * GB), 4210000, 88000, 22, 18, 96, 300, source="thepiratebay"),
    row("c" * 40, "[SubsPlease] Hokusai no Musume - 01-12 (1080p) [Batch]", "downloading", int(0.2 * GB), int(14.3 * GB), 0, 0, 3, 0, 40, 420, source="nyaasi"),
    row("d" * 40, "北斎漫画 全十五編 — 東京国立博物館 高精細スキャン", "downloading", 600 * MB, int(1.3 * GB), 870000, 0, 6, 2, 11, 500, source="Knaben"),
    row("e" * 40, "Sintel.2010.4K.Open.Movie", "finding", meta=False, added=20),
    row("url-ff0011", "Tears of Steel 2012 2160p open movie, Blender Foundation", "asking", meta=False, added=10, source="limetorrents"),
    row("f" * 40, "ubuntu-26.04-desktop-amd64.iso", "checking", int(4.2 * GB), int(6.1 * GB), added=800),
    row("0" * 40, "archlinux-2026.11.01-x86_64.iso", "queued", 0, int(1.4 * GB), added=900),
    row("1" * 40, "The.General.1926.Buster.Keaton.720p.WEBRip", "failed", 300 * MB, int(2.2 * GB), added=1000, err="no space left on device"),
    row("url-ff0022", "Metropolis 1927 restored", "failed", meta=False, added=1100, err="could not reach it: Name or service not known", source="limetorrents"),
    row("2" * 40, "Nosferatu.1922.1080p.Restored", "paused", int(1.4 * GB), int(4.4 * GB), added=2000),
    row("3" * 40, "Big Buck Bunny 2008 1080p open movie", "done", int(1.1 * GB), int(1.1 * GB), 0, 420000, 2, 0, 12, 3000, 20),
    row("4" * 40, "Sita Sings the Blues (2008) 1080p", "done", 640 * MB, 640 * MB, added=DAY, at=DAY // 2),
    row("5" * 40, "Internet.Archive.Prelinger.Collection.Duck.and.Cover.1951.mp4", "done", 88 * MB, 88 * MB, added=2 * DAY, at=2 * DAY),
    row("6" * 40, "fedora-44-x86_64-netinst.iso", "done", int(1.0 * GB), int(1.0 * GB), added=3 * DAY, at=3 * DAY),
]
FILES = [["Night.of.the.Living.Dead.1968/Night.of.the.Living.Dead.1968.1080p.BluRay.x264.mkv", int(7 * GB)],
         ["Night.of.the.Living.Dead.1968/Subs/English.srt", 90000], ["Night.of.the.Living.Dead.1968/Subs/Japanese.srt", 110000],
         ["Night.of.the.Living.Dead.1968/poster.jpg", 2400000], ["Night.of.the.Living.Dead.1968/extras/trailer 1968.mkv", 180 * MB],
         ["Night.of.the.Living.Dead.1968/extras/interview with George Romero, restored.mkv", 420 * MB]]
PIECES = ([8] * 16 + [0, 0, 3, 0, 8, 8, 0, 5, 8, 2, 0, 0, 1, 0, 0, 0] + [0] * 32 + [8] * 6)
TRACKERS = [["udp://open.stealth.si:80/announce", "answers"], ["udp://tracker.torrent.eu.org:451/announce", "answers"],
            ["udp://tracker.opentrackr.org:1337/announce", "failed"], ["udp://exodus.desync.com:6969/announce", "answers"]]


def detail(i, cells):
    files = len(FILES)
    n = max(1, cells)
    return {"ev": "detail", "id": i, "pieces": [PIECES[k * len(PIECES) // n] for k in range(n)], "trackers": TRACKERS,
            "progress": [int(FILES[0][1] * 0.43), 90000, 110000, 0, 0, 0], "priorities": [7, 4, 4, 4, 0, 0][:files]}


RESULTS = [("debian-13.1.0-amd64-netinst.iso", 754 * MB, 1204, "thepiratebay", 900, 4000, "ab" * 20),
           ("Debian 13.1 DVD x86_64 (three discs, official images)", int(11.6 * GB), 312, "Knaben", 1200, 4000, "bc" * 20),
           ("debian live 13 gnome", int(3.3 * GB), 88, "limetorrents", 3000, 4000, ""),
           ("デビアン 13 解説書 日本語 PDF", 41 * MB, 12, "nyaasi", 8000, 7000, "cd" * 20),
           ("Debian Handbook 2024 EPUB", 8 * MB, 5, "Knaben", 24000, 7000, "de" * 20),
           ("Debian GNU/Linux 3.0 woody, very old, seven CDs for historians", int(4.4 * GB), 0, "thepiratebay", 200000, 4000, "ef" * 20),
           ("debian wallpapers", 12 * MB, 0, "limetorrents", 90000, 8000, "")]


class Prowlarr(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def answer(self, data):
        body = json.dumps(data).encode()
        self.send_response(200)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        u = urllib.parse.urlsplit(self.path)
        q = urllib.parse.parse_qs(u.query)
        if u.path.endswith("/indexer"):
            self.answer([{"id": k + 1, "name": n, "definitionName": n, "enable": True} for k, n in enumerate(("Knaben", "limetorrents", "nyaasi", "thepiratebay", "slowsite"))])
        elif u.path.endswith("/search"):
            site = int(q["indexerIds"][0])
            names = {1: "Knaben", 2: "limetorrents", 3: "nyaasi", 4: "thepiratebay", 5: "slowsite"}
            if site == 5:
                time.sleep(float(os.environ.get("MOCK_SLOW", 6)))
                self.answer([])
                return
            self.answer([{"title": t, "size": s, "seeders": sd, "indexer": names[site], "ageHours": a, "categories": [{"id": c}], "infoHash": h,
                          "magnetUrl": "" if h else "", "downloadUrl": "" if h else f"http://127.0.0.1:1/x?apikey=k&id={t}", "guid": t}
                         for t, s, sd, si, a, c, h in RESULTS if si == names[site]])
        elif u.path.endswith("/indexerstatus"):
            self.answer([])
        else:
            self.send_error(404)


def serve():
    rows = ROWS
    if "--empty" in sys.argv:
        rows = []
    if "--rows" in sys.argv:
        n = int(sys.argv[sys.argv.index("--rows") + 1])
        rows = [row(f"{k:040x}", f"Long.List.Of.Things.Volume.{k:04d}.1080p.WEB-DL", "downloading" if k % 3 == 0 else "done", MB * (k % 90), MB * 100, 1000 * (k % 500 + 1) if k % 3 == 0 else 0,
                    added=k * 60, at=k * 60 if k % 3 else 0) for k in range(n)]
    path = os.path.join(os.environ["XDG_RUNTIME_DIR"], "kawa-torrents.sock")
    try:
        os.unlink(path)
    except FileNotFoundError:
        pass
    ls = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    ls.bind(path)
    ls.listen(8)
    sel = selectors.DefaultSelector()
    sel.register(ls, selectors.EVENT_READ, None)
    bufs = {}
    log = os.environ.get("MOCK_LOG")
    while True:
        for key, _ in sel.select():
            if key.data is None:
                c, _ = ls.accept()
                sel.register(c, selectors.EVENT_READ, "c")
                bufs[c] = b""
                continue
            c = key.fileobj
            try:
                data = c.recv(1 << 16)
            except OSError:
                data = b""
            if not data:
                sel.unregister(c)
                c.close()
                continue
            bufs[c] += data
            *lines, bufs[c] = bufs[c].split(b"\n")
            for line in lines:
                q = json.loads(line)
                if log:
                    with open(log, "a", encoding="utf-8") as f:
                        f.write(line.decode() + "\n")
                out = []
                if q["op"] == "hello":
                    out.append({"ev": "rows", "all": True, "rows": rows, "gone": [], "turtle": False})
                elif q["op"] == "watch" and q.get("id"):
                    out.append({"ev": "files", "id": q["id"], "files": FILES})
                    out.append(detail(q["id"], q.get("cells", 40)))
                elif q["op"] == "magnet":
                    out.append({"re": q.get("n"), "magnet": f"magnet:?xt=urn:btih:{q['id']}&dn=mock"})
                elif q["op"] == "add":
                    out.append({"re": q.get("n"), "id": "a" * 40, "known": False, "err": ""})
                elif q["op"] == "stream":
                    out.append({"re": q.get("n"), "url": "http://127.0.0.1:1/stream/file.mkv"})
                elif q.get("n") is not None:
                    out.append({"re": q["n"]})
                for m in out:
                    if m.get("re", 0) is None:
                        continue
                    c.sendall((json.dumps(m, ensure_ascii=False) + "\n").encode())


def main():
    port = int(os.environ.get("KAWA_PROWLARR_URL", "http://127.0.0.1:0").rpartition(":")[2])
    http = ThreadingHTTPServer(("127.0.0.1", port), Prowlarr)
    http.daemon_threads = True
    threading.Thread(target=http.serve_forever, daemon=True).start()
    serve()


if __name__ == "__main__":
    main()
