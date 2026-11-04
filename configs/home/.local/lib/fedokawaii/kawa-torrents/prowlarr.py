#!/usr/bin/python3 -I
"""Prowlarr, as this program asks it: a search site by site, so what a quick site finds shows at once and
a slow one holds up nothing (measured 4 Nov: Knaben 0.6 s, YTS 39.6 s — one whole search waits for the slowest);
the usual sites added (setup.sh: `prowlarr.py add`, key on stdin); and those that fail rested, so that Prowlarr's
page says nothing is wrong and no search waits for them (`prowlarr.py tend`, kawa-torrents after a first search,
kawa-prowlarr before the page opens).

The usual sites (public, none behind Cloudflare's challenge — those need FlareSolverr, which this desktop
does not run; researched 2026-10-17 against Prowlarr's and Jackett's indexer definitions, measured here
2026-11-04):
   nyaasi            Nyaa — anime first, the largest anime tracker
   SubsPlease        the season's anime, as it airs (built into Prowlarr)
   thepiratebay      The Pirate Bay (its JSON API) — films and series
   yts               YTS — films, small encodes
   Knaben            Knaben — a search across many trackers (built into Prowlarr)
   limetorrents      LimeTorrents — films and series
   torrentdownloads  Torrent Downloads — films and series
Left out on purpose: EZTV, 1337x, KickassTorrents, dmhy (Cloudflare: FlareSolverr only); AniDex (unreliable
since its 2025 server move); TorrentGalaxy, RARBG copies, BitSearch (gone from Prowlarr); TorrentProject2 and
TorrentsCSV (no film/series categories). Taken out where an older setup added it: Tokyo Toshokan ("Cloudflare
protection detected" at search after search, though Prowlarr's own test of it passes).

A site is rested when it has a failure on record and Prowlarr's own test of it fails too: switched off, noted in
~/.local/state/fedokawaii/torrents/rested. Each tend tries the rested again, and those that answer are switched
on. One you switched off yourself is never touched. When every site with a failure fails its test and none has
just answered, it is this computer's network, and nothing is rested.

Exit (add): 0 every one present · 1 one or more could not be added (said, one line each) · 2 Prowlarr did
not answer, or refused the key. Exit (tend): 0 · 2 the same.
"""
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

URL = os.environ.get("KAWA_PROWLARR_URL", "http://127.0.0.1:9696")
INDEXERS = [("nyaasi", 1), ("SubsPlease", 5), ("thepiratebay", 10),
            ("yts", 10), ("Knaben", 15), ("limetorrents", 20), ("torrentdownloads", 25)]
RETIRED = ("tokyotosho",)
SEARCH_WAIT = 60
HOME = os.path.expanduser("~")
RESTED = os.path.join(os.environ.get("XDG_STATE_HOME") or os.path.join(HOME, ".local/state"), "fedokawaii/torrents/rested")


class Refused(Exception):
    """Prowlarr did not answer, or would not."""


def api(key, method, path, body=None, wait=60):
    req = urllib.request.Request(URL.rstrip("/") + "/api/v1" + path, method=method,
                                 data=None if body is None else json.dumps(body).encode(),
                                 headers={"X-Api-Key": key, "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=wait) as r:
        data = r.read()
    return json.loads(data) if data else None


def secret():
    """The key, from secrets.sh alone (yours, mode 600) — read the way the shell would, in a shell of its own."""
    import subprocess
    path = os.path.join(HOME, ".config/fedokawaii/secrets.sh")
    try:
        st = os.stat(path)
    except OSError:
        return ""
    if st.st_mode & 0o077 or st.st_uid != os.getuid():
        return ""
    out = subprocess.run(["bash", "-c", 'set +u; . "$1" >/dev/null 2>&1; printf %s "${PROWLARR_API_KEY:-}"', "_", path],
                         capture_output=True, text=True, check=False).stdout
    return out if len(out) == 32 else ""


# ── a search ────────────────────────────────────────────────────────────────────────────────
def sites(key):
    """The sites switched on: (id, name)."""
    return [(i["id"], i.get("name") or i.get("definitionName") or "") for i in api(key, "GET", "/indexer", wait=10) if i.get("enable")]


def search(key, site, query):
    """What one site found; [] from a site Prowlarr is letting rest after a failure (it answers 400)."""
    q = urllib.parse.urlencode({"query": query, "type": "search", "indexerIds": site, "limit": 100})
    try:
        return api(key, "GET", "/search?" + q, wait=SEARCH_WAIT) or []
    except urllib.error.HTTPError as e:
        if e.code == 400:
            return []
        raise


# ── the usual sites ─────────────────────────────────────────────────────────────────────────
def add_usual(key):
    try:
        indexers = api(key, "GET", "/indexer")
        for i in indexers:
            if (i.get("definitionName") or "").lower() in RETIRED:
                api(key, "DELETE", f"/indexer/{i['id']}")
                print(f"{i.get('name')}: taken out (Cloudflare: it fails at search after search)")
        have = {(i.get("definitionName") or "").lower() for i in indexers}
        missing = [(d, p) for d, p in INDEXERS if d.lower() not in have]
        if not missing:
            print(f"Prowlarr's indexers: all {len(INDEXERS)} in place")
            return 0

        def known():
            return {(s.get("definitionName") or "").lower(): s for s in api(key, "GET", "/indexer/schema")}
        schema = known()
        if any(d.lower() not in schema for d, _ in missing):
            # its list of sites not fetched yet (a first start): fetched now, and waited for
            cmd = api(key, "POST", "/command", {"name": "IndexerDefinitionUpdate"})
            for _ in range(60):
                if api(key, "GET", f"/command/{cmd['id']}").get("status") not in ("queued", "started"):
                    break
                time.sleep(2)
            schema = known()
        profile = api(key, "GET", "/appprofile")[0]["id"]
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
            api(key, "POST", "/indexer", body)
            print(f"{name}: added")
        except urllib.error.HTTPError:
            # Prowlarr tests a site before it saves it: one it cannot reach from here is saved switched off,
            # and rested as tend's own: the next tend switches it on the day it answers
            try:
                made = api(key, "POST", "/indexer?forceSave=true", dict(body, enable=False))
                note_rested(rested() | {made["id"]})
                print(f"{name}: added, rested (it does not answer from here)")
            except (urllib.error.URLError, OSError, ValueError, KeyError, TypeError) as e:
                print(f"{name}: could not be added ({e})", file=sys.stderr)
                failed += 1
        except (urllib.error.URLError, OSError, ValueError) as e:
            print(f"{name}: could not be added ({e})", file=sys.stderr)
            failed += 1
    return 1 if failed else 0


# ── the sites that fail for good ────────────────────────────────────────────────────────────
def rested():
    try:
        with open(RESTED, encoding="utf-8") as f:
            return {int(x) for x in f.read().split()}
    except (OSError, ValueError):
        return set()


def note_rested(ids):
    os.makedirs(os.path.dirname(RESTED), mode=0o700, exist_ok=True)
    with open(RESTED + ".new", "w", encoding="utf-8") as f:
        f.write("".join(f"{i}\n" for i in sorted(ids)))
    os.replace(RESTED + ".new", RESTED)


def answers(key, indexer):
    """Prowlarr's own test of a site."""
    try:
        api(key, "POST", "/indexer/test", indexer, wait=30)
        return True
    except urllib.error.HTTPError:
        return False
    except (urllib.error.URLError, OSError, ValueError):
        return False


def tend(key):
    """Prowlarr's page without its warning, for good: what fails is rested, what is back switched on."""
    try:
        indexers = {i["id"]: i for i in api(key, "GET", "/indexer")}
        failing = [st.get("indexerId") for st in api(key, "GET", "/indexerstatus") or []]
    except (urllib.error.URLError, OSError, ValueError, KeyError, TypeError) as e:
        print(f"Prowlarr did not answer as it should ({e})", file=sys.stderr)
        return 2
    before = rested()
    mine = {i for i in before if i in indexers}
    for i in sorted(mine):
        it = indexers[i]
        if it.get("enable"):                       # (you switched it on yourself: yours again)
            mine.discard(i)
        elif answers(key, dict(it, enable=True)):
            try:
                api(key, "PUT", f"/indexer/{i}?forceSave=true", dict(it, enable=True))
                mine.discard(i)
                print(f"{it.get('name')}: answers again, switched on")
            except (urllib.error.URLError, OSError, ValueError) as e:
                print(f"{it.get('name')}: could not be switched on ({e})", file=sys.stderr)
    sick = [i for i in failing if i in indexers and indexers[i].get("enable")]
    dead = [i for i in sick if not answers(key, indexers[i])]
    alive_elsewhere = len(dead) < len([i for i in indexers.values() if i.get("enable")])
    if dead and alive_elsewhere:
        for i in dead:
            it = indexers[i]
            try:
                api(key, "PUT", f"/indexer/{i}?forceSave=true", dict(it, enable=False))
                mine.add(i)
                print(f"{it.get('name')}: rested (it does not answer from here)")
            except (urllib.error.URLError, OSError, ValueError) as e:
                print(f"{it.get('name')}: could not be rested ({e})", file=sys.stderr)
    if mine != before:
        note_rested(mine)
        try:                                       # (its page says so at once, not at its next look)
            api(key, "POST", "/command", {"name": "CheckHealth"})
        except (urllib.error.URLError, OSError, ValueError):
            pass
    return 0


def main(argv):
    if len(argv) != 2 or argv[1] not in ("add", "tend"):
        print("usage: prowlarr.py add|tend   (the key on stdin)", file=sys.stderr)
        return 2
    key = sys.stdin.read().strip()
    return add_usual(key) if argv[1] == "add" else tend(key)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
