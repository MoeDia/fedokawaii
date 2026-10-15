#!/usr/bin/env python3
"""A stand-in for Prowlarr on 127.0.0.1:9696, enough for torrra (and kawa-torrra's checks):

  /api/v1/indexer   two enabled torrent indexers
  /api/v1/health    no problems
  /api/v1/search    ?query=…  releases shaped like Prowlarr's (title, size, seeders,
                    leechers, indexer, magnetUrl, downloadUrl, infoHash, publishDate, …);
                    a query about Ubuntu 24.04 gets a page of plausible ISO releases

The API key is checked like Prowlarr does: header X-Api-Key or query apikey; else 401.
  fakeprowlarr.py [KEY] [PORT]
"""
import hashlib
import http.server
import json
import sys
import urllib.parse

KEY = sys.argv[1] if len(sys.argv) > 1 else "0123456789abcdef0123456789abcdef"
PORT = int(sys.argv[2]) if len(sys.argv) > 2 else 9696
GB = 1024 ** 3

INDEXERS = [
    {"id": 1, "name": "LinuxTracker", "enable": True, "protocol": "torrent", "privacy": "public",
     "priority": 25, "appProfileId": 1, "added": "2026-09-30T18:12:44Z"},
    {"id": 2, "name": "Internet Archive", "enable": True, "protocol": "torrent", "privacy": "public",
     "priority": 25, "appProfileId": 1, "added": "2026-09-30T18:13:02Z"},
]

#        title                                          size (GiB)  seeders leechers indexer  published
UBUNTU = [
    ("ubuntu-24.04.3-desktop-amd64.iso",                 5.91, 1843, 112, 1, "2025-08-07T16:44:00Z"),
    ("ubuntu-24.04.3-live-server-amd64.iso",             3.08, 1210,  41, 1, "2025-08-07T16:51:00Z"),
    ("kubuntu-24.04.3-desktop-amd64.iso",                4.37,  402,  19, 1, "2025-08-07T18:02:00Z"),
    ("xubuntu-24.04.3-desktop-amd64.iso",                3.94,  288,  12, 1, "2025-08-07T18:10:00Z"),
    ("ubuntu-24.04.3-desktop-arm64.iso",                 5.62,  176,   9, 1, "2025-08-07T17:20:00Z"),
    ("lubuntu-24.04.3-desktop-amd64.iso",                3.21,  141,   6, 1, "2025-08-07T18:25:00Z"),
    ("ubuntu-mate-24.04.3-desktop-amd64.iso",            4.12,  117,   4, 1, "2025-08-07T18:31:00Z"),
    ("ubuntu-24.04.2-desktop-amd64.iso",                 5.88,   96,   2, 2, "2025-02-20T12:05:00Z"),
    ("Ubuntu 24.04 LTS Noble Numbat (desktop, amd64)",   5.68,   74,   3, 2, "2024-04-25T15:40:00Z"),
    ("ubuntu-24.04.3-live-server-arm64.iso",             2.73,   63,   1, 1, "2025-08-07T17:02:00Z"),
    ("ubuntustudio-24.04.3-dvd-amd64.iso",               5.49,   38,   2, 2, "2025-08-08T09:15:00Z"),
    ("ubuntu-24.04-netboot-amd64.tar.gz",                0.08,   21,   0, 2, "2024-04-25T16:02:00Z"),
]


def releases(query):
    q = query.lower()
    if "ubuntu" not in q:
        return []
    out = []
    for i, (title, gib, se, le, ix, pub) in enumerate(UBUNTU):
        h = hashlib.sha1(title.encode()).hexdigest()
        name = INDEXERS[ix - 1]["name"]
        magnet = ("magnet:?xt=urn:btih:" + h + "&dn=" + urllib.parse.quote(title)
                  + "&tr=" + urllib.parse.quote("https://torrent.ubuntu.com/announce"))
        out.append({
            "guid": f"https://linuxtracker.org/index.php?page=torrent-details&id={h}",
            "age": 0, "ageHours": 0.0, "ageMinutes": 0.0,
            "size": int(gib * GB), "files": 1, "grabs": se * 7 + 13,
            "indexerId": ix, "indexer": name, "title": title, "sortTitle": title.lower(),
            "imdbId": 0, "tmdbId": 0, "tvdbId": 0, "tvMazeId": 0,
            "publishDate": pub,
            "downloadUrl": f"http://127.0.0.1:{PORT}/{ix}/api?t=get&id={h}",
            "infoUrl": f"https://linuxtracker.org/index.php?page=torrent-details&id={h}",
            "magnetUrl": magnet, "infoHash": h.upper(),
            "seeders": se, "leechers": le, "protocol": "torrent",
            "fileName": title + ".torrent",
            "categories": [{"id": 4000, "name": "PC", "subCategories": []}],
        })
    return out


class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        u = urllib.parse.urlparse(self.path)
        q = urllib.parse.parse_qs(u.query)
        if self.headers.get("X-Api-Key") != KEY and q.get("apikey", [""])[0] != KEY:
            self.send_response(401)
            self.end_headers()
            return
        if u.path == "/api/v1/indexer":
            body = INDEXERS
        elif u.path == "/api/v1/health":
            body = []
        elif u.path == "/api/v1/search":
            body = releases(q.get("query", [""])[0])
        else:
            self.send_response(404)
            self.end_headers()
            return
        data = json.dumps(body).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, fmt, *a):
        sys.stderr.write("fakeprowlarr: " + (fmt % a) + "\n")


http.server.ThreadingHTTPServer(("127.0.0.1", PORT), H).serve_forever()
