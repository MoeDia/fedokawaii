#!/usr/bin/python3 -I
"""system/prowlarr-indexers.py — Prowlarr's indexers: the best public torrent sites for anime,
films and series, added once, so torrra's first search finds something. setup.sh runs it (as
you) at setup, every update and repair, with Prowlarr up; the API key comes on stdin (never
on a command line). Usage: printf %s "$KEY" | prowlarr-indexers.py [URL]

Prowlarr fetches its list of sites (the indexer definitions) in the background once it has
started: right after a first start the list can still lack them. A site it does not know yet
is asked for at once (its "Indexer Definition Update" task, waited for up to two minutes)
before anything is said missing.

Each is added only when Prowlarr has none of its kind yet (matched by its definition, so
one you renamed, set up differently or switched off is left exactly as you have it), with
the settings Prowlarr's own form starts with, and a priority (1 is asked first, 50 last;
Prowlarr's default is 25). An indexer Prowlarr cannot reach right now (offline, a site
down for a while) is added all the same: Prowlarr checks it on every search and pauses one
that keeps failing, rather than losing it.

The list (public sites, none behind Cloudflare's challenge — those need FlareSolverr, which
this desktop does not run; researched 2026-10-17 against Prowlarr's and Jackett's indexer
definitions and their histories):
   nyaasi            Nyaa — anime first, the largest anime tracker
   SubsPlease        the season's anime, as it airs (built into Prowlarr)
   tokyotosho        Tokyo Toshokan — anime, a long-running index
   thepiratebay      The Pirate Bay (its JSON API) — films and series
   yts               YTS — films, small encodes
   Knaben            Knaben — a search across many trackers (built into Prowlarr)
   limetorrents      LimeTorrents — films and series
   torrentdownloads  Torrent Downloads — films and series
Left out on purpose: EZTV, 1337x, KickassTorrents, dmhy (Cloudflare: FlareSolverr only);
AniDex (unreliable since its 2025 server move); TorrentGalaxy, RARBG copies, BitSearch
(gone from Prowlarr); TorrentProject2 and TorrentsCSV (no film/series categories).

Exit: 0 every one present · 1 one or more could not be added (said, one line each) ·
2 Prowlarr did not answer, or refused the key.
"""
import json
import sys
import time
import urllib.error
import urllib.request

INDEXERS = [("nyaasi", 1), ("SubsPlease", 5), ("tokyotosho", 10), ("thepiratebay", 10),
            ("yts", 10), ("Knaben", 15), ("limetorrents", 20), ("torrentdownloads", 25)]


def main():
    base = (sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:9696").rstrip("/") + "/api/v1"
    key = sys.stdin.read().strip()

    def api(method, path, body=None):
        req = urllib.request.Request(base + path, method=method,
                                     data=None if body is None else json.dumps(body).encode(),
                                     headers={"X-Api-Key": key, "Content-Type": "application/json"})
        with urllib.request.urlopen(req, timeout=60) as r:
            data = r.read()
        return json.loads(data) if data else None

    try:
        have = {(i.get("definitionName") or "").lower() for i in api("GET", "/indexer")}
        missing = [(d, p) for d, p in INDEXERS if d.lower() not in have]
        if not missing:
            print(f"Prowlarr's indexers: all {len(INDEXERS)} in place")
            return 0
        def sites():
            return {(s.get("definitionName") or "").lower(): s for s in api("GET", "/indexer/schema")}
        schema = sites()
        if any(d.lower() not in schema for d, _ in missing):
            # its list of sites not fetched yet (a first start): fetched now, and waited for
            cmd = api("POST", "/command", {"name": "IndexerDefinitionUpdate"})
            for _ in range(60):
                if api("GET", f"/command/{cmd['id']}").get("status") not in ("queued", "started"):
                    break
                time.sleep(2)
            schema = sites()
        profile = api("GET", "/appprofile")[0]["id"]
    except urllib.error.HTTPError as e:
        print(f"Prowlarr refused ({e.code}) — is the key in secrets.sh the one it was given?", file=sys.stderr)
        return 2
    except (urllib.error.URLError, OSError, ValueError, IndexError, KeyError) as e:
        print(f"Prowlarr did not answer as it should ({e})", file=sys.stderr)
        return 2

    failed = 0
    for name, priority in missing:
        s = schema.get(name.lower())
        if s is None:
            print(f"{name}: Prowlarr does not know it (its list of sites could not be fetched?)", file=sys.stderr)
            failed += 1
            continue
        body = {k: v for k, v in s.items() if k != "presets"}
        body.update(enable=True, appProfileId=profile, priority=priority, tags=[])
        try:
            api("POST", "/indexer", body)
            print(f"{name}: added")
        except urllib.error.HTTPError:
            # Prowlarr tests a site before it saves it: one it cannot reach now is saved switched
            # off, then switched on without the test (forceSave) — it is tried at each search
            try:
                made = api("POST", "/indexer", dict(body, enable=False))
                api("PUT", f"/indexer/{made['id']}?forceSave=true", dict(body, id=made["id"], enable=True))
                print(f"{name}: added (not reachable just now: Prowlarr tries it at each search)")
            except (urllib.error.URLError, OSError, ValueError, KeyError, TypeError) as e:
                print(f"{name}: could not be added ({e})", file=sys.stderr)
                failed += 1
        except (urllib.error.URLError, OSError, ValueError) as e:
            print(f"{name}: could not be added ({e})", file=sys.stderr)
            failed += 1
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
