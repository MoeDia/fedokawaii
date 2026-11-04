#!/usr/bin/env bash
# tests/engine/test_prowlarr.sh — Prowlarr on demand, from the two places that start it and
# then go on without it: setup.sh's prowlarr_up (setup, update, repair, the Fedora move) and
# the `prowlarr` shell command (its web page). A start that fails is stopped again: left
# alone, the unit's Restart=on-failure would try it every 10 s until the next boot.
# (the window's own: tests/engine/test_torrents.sh; verify's: tests/installer.)
# Then setup.sh's other torrent steps, as functions: torrents_up (the program whole on Fedora's
# Python, and all an older setup's torrra left taken out, its list handed over first).
. "$(dirname "$0")/lib.sh"
KEY=a1b2c3d4e5f60718293a4b5c6d7e8f90

# systemd --user: $TMP/active while Prowlarr runs; $TMP/start-fails makes every start fail
user_systemd() {
  stub systemctl 'case "$*" in
  *is-active*) [ -e "'"$TMP"'/active" ]; exit $? ;;
  *" start "*|*" restart "*) [ -e "'"$TMP"'/start-fails" ] && { echo "Job for prowlarr.service failed." >&2; exit 1; }; : >"'"$TMP"'/active" ;;
  *" stop "*) rm -f "'"$TMP"'/active" ;;
esac'
}

# ── setup.sh's prowlarr_up ───────────────────────────────────────────────────
# its own functions, as setup.sh has them, run as setup runs a step (errexit); the user's
# commands run as you here; podman knows the key and has the image; curl is Prowlarr's API
up_world() {
  sandbox; user_systemd; stub sleep
  { sed -n '/^prowlarr_image() {/p' "$REPO/setup.sh"
    for f in prowlarr_key prowlarr_accepts prowlarr_up; do sed -n "/^$f() {/,/^}/p" "$REPO/setup.sh"; done; } >"$TMP/fns.sh"
  [[ $(grep -c '() {' "$TMP/fns.sh") == 4 ]] || { echo "fixture: setup.sh's Prowlarr functions not found" >&2; exit 1; }
  stub podman 'case "$*" in *"secret inspect"*) printf %s '"$KEY"' ;; esac'
  stub curl 'cat >/dev/null; [ -e "'"$TMP"'/key-refused" ] && exit 22; exit 0'
  mkdir -p "$HOME/.config/fedokawaii"
  printf 'PROWLARR_API_KEY=%s\n' "$KEY" >"$HOME/.config/fedokawaii/secrets.sh"; chmod 600 "$HOME/.config/fedokawaii/secrets.sh"
}
up() {   # → $OUT, $RC
  OUT=$(LOG_FILE=$TMP/fk.log STATE_DIR=$TMP/state REPO_DIR=$REPO TARGET_HOME=$HOME TARGET_USER=$(id -un) \
        TARGET_UID=$(id -u) TARGET_GID=$(id -g) bash -c 'set -Eeuo pipefail
    . "$1/lib/common.sh"; . "$2"; as_user() { "$@"; }
    prowlarr_up' _ "$REPO" "$TMP/fns.sh" 2>&1); RC=$?
}
stops_after() {   # a stop of prowlarr.service comes after the last (re)start
  awk '/^systemctl .*(start|restart) prowlarr.service/ { s = NR } /^systemctl .*stop .*prowlarr.service/ { t = NR }
       END { exit !(s && t > s) }' "$CALLS"
}

case_ "prowlarr_up: a working Prowlarr is started, checked, and put back to sleep"
up_world; up; eq "$RC" 0 "$OUT"
called '^systemctl --user restart prowlarr.service'; stops_after && _ok || _no "not stopped again"
case_ "prowlarr_up: one that does not start — said, and stopped again (never left retrying every 10 s)"
up_world; : >"$TMP/start-fails"; up; eq "$RC" 1
has "$OUT" "Prowlarr did not start"; stops_after && _ok || _no "left starting: $(tail -n3 "$CALLS" | tr '\n' '|')"
case_ "prowlarr_up: one that does not take the key — said, and stopped again too"
up_world; : >"$TMP/key-refused"; up; eq "$RC" 1
has "$OUT" "does not take the key"; stops_after && _ok || _no "left running"
case_ "…but one you had running already (its page open) is left running"
up_world; : >"$TMP/active"                                  # (its unit current: no restart)
mkdir -p "$HOME/.config/containers/systemd"; cp "$REPO/system/prowlarr.container" "$HOME/.config/containers/systemd/"
: >"$TMP/key-refused"; up; eq "$RC" 1; not_called 'stop'; [[ -e $TMP/active ]] && _ok || _no "your Prowlarr was stopped"

# ── kawa-prowlarr: its page (`prowlarr`, the launcher), and its sleep ─────────────
sh_world() {
  sandbox; user_systemd; stub xdg-open; stub systemd-run
  # (the stand-in's stop of anything but prowlarr.service — the planned sleep — leaves it running)
  stub systemctl 'case "$*" in
  *is-active*) [ -e "'"$TMP"'/active" ] && { echo active; exit 0; }; echo inactive; exit 3 ;;
  *" start "*|*" restart "*) [ -e "'"$TMP"'/start-fails" ] && { echo "Job for prowlarr.service failed." >&2; exit 1; }; : >"'"$TMP"'/active" ;;
  *" stop "*prowlarr.service*) rm -f "'"$TMP"'/active" ;;
esac'
}
pw() { OUT=$(kawa-prowlarr "$@" 2>&1); RC=$?; }
SLEEP='^systemd-run --user --quiet --unit=prowlarr-idle --on-active=30min --timer-property=AccuracySec=30s systemctl --user stop prowlarr.service$'

case_ "prowlarr (the page): started (the wait said), the page opened, asleep again 30 minutes later"
sh_world; pw; eq "$RC" 0; has "$OUT" "starting Prowlarr"
called '^systemctl --user start prowlarr.service'; for _ in {1..50}; do grep -q '^xdg-open' "$CALLS" && break; /bin/sleep 0.05; done
called '^xdg-open http://localhost:9696$'; called "$SLEEP"; not_called '^systemctl --user stop prowlarr.service'
case_ "…already running: the page only, no wait to announce; a sleep already planned, planned anew"
sh_world; : >"$TMP/active"; pw; eq "$RC" 0; lacks "$OUT" "starting"; called '^systemctl --user stop prowlarr-idle.timer'; called "$SLEEP"
case_ "…a start that fails: said (a notice too), stopped again (never left retrying), no page, no sleep planned"
sh_world; : >"$TMP/start-fails"; pw; eq "$RC" 1
has "$OUT" "Prowlarr did not start"; has "$OUT" "journalctl --user -u prowlarr"
called '^systemctl --user stop --no-block prowlarr.service'; not_called xdg-open; not_called systemd-run
called '^notify-send -a torrents -u critical -- .*  Prowlarr did not start'
case_ "prowlarr stop: asleep now, its planned sleep called off"
sh_world; : >"$TMP/active"; pw stop; eq "$RC" 0; called '^systemctl --user stop prowlarr.service'; [[ ! -e $TMP/active ]] && _ok || _no "still running"
called '^systemctl --user stop prowlarr-idle.timer'
case_ "--busy (a search starts): started, the planned sleep called off, none planned"
sh_world; pw --busy; eq "$RC" 0; called '^systemctl --user start prowlarr.service'; called 'stop prowlarr-idle.timer'; not_called systemd-run
case_ "--idle (the search window closed): the sleep planned; nothing planned for one already asleep"
sh_world; : >"$TMP/active"; pw --idle; called "$SLEEP"
sh_world; pw --idle; eq "$RC" 0; not_called systemd-run
case_ "KAWA_PROWLARR_IDLE_MIN sets another wait (the tests' own knob); a wrong word says how it is used"
sh_world; : >"$TMP/active"; KAWA_PROWLARR_IDLE_MIN=5 kawa-prowlarr --idle; called 'on-active=5min'
pw bogus; eq "$RC" 2; has "$OUT" "usage: kawa-prowlarr"
case_ "the shell's prowlarr and the launcher entry both go through kawa-prowlarr"
grep -q 'Exec=@HOME@/.local/bin/kawa-prowlarr$' "$REPO/configs/home/.local/share/applications/kawa-prowlarr.desktop" && _ok || _no "the launcher entry"

# ── setup's indexers (kawa-torrents' prowlarr.py add), against a stand-in Prowlarr ─────
# a small HTTP server speaking Prowlarr's API: the indexers it has ($TMP/have.json), the
# schema of every known one, POST (which fails its connection test for names in $TMP/unreachable)
# and PUT ?forceSave; every request logged to $TMP/api.log with the key it carried
api_world() {
  sandbox
  cat >"$TMP/fake.py" <<'PY'
import json, os, sys
from http.server import BaseHTTPRequestHandler, HTTPServer
T = sys.argv[1]
KNOWN = ["nyaasi", "SubsPlease", "tokyotosho", "thepiratebay", "yts", "Knaben", "limetorrents", "torrentdownloads", "eztv"]
def have():
    try: return json.load(open(f"{T}/have.json"))
    except FileNotFoundError: return []
class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def send(self, code, obj=None):
        self.send_response(code); self.end_headers()
        if obj is not None: self.wfile.write(json.dumps(obj).encode())
    def note(self, body=""):
        with open(f"{T}/api.log", "a") as f: f.write(f"{self.command} {self.path} key={self.headers.get('X-Api-Key')} {body}\n")
    def do_GET(self):
        self.note()
        if self.headers.get("X-Api-Key") != "k3y": return self.send(401)
        if self.path == "/api/v1/indexer": return self.send(200, have())
        if self.path == "/api/v1/indexer/schema":
            # (a first start: $T/no-defs — only the sites built into Prowlarr, until it has
            # fetched its list: the IndexerDefinitionUpdate command)
            known = ["SubsPlease", "Knaben"] if os.path.exists(f"{T}/no-defs") else KNOWN
            return self.send(200, [{"definitionName": d, "name": d.title(), "implementation": "Cardigann", "fields": [{"name": "baseUrl"}], "presets": [], "enable": False, "priority": 25} for d in known])
        if self.path == "/api/v1/command/31": return self.send(200, {"id": 31, "name": "IndexerDefinitionUpdate", "status": "completed"})
        if self.path == "/api/v1/appprofile": return self.send(200, [{"id": 7, "name": "Standard"}])
        self.send(404)
    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        if self.path == "/api/v1/command":
            self.note(json.dumps(body))
            if body.get("name") == "IndexerDefinitionUpdate" and os.path.exists(f"{T}/no-defs"): os.remove(f"{T}/no-defs")
            return self.send(201, {"id": 31, "name": body.get("name"), "status": "queued"})
        self.note(json.dumps({k: body.get(k) for k in ("definitionName", "enable", "priority", "appProfileId", "tags")} | {"presets": "presets" in body}))
        unreachable = open(f"{T}/unreachable").read().split() if os.path.exists(f"{T}/unreachable") else []
        if body["enable"] and body["definitionName"] in unreachable:
            return self.send(400, [{"errorMessage": "Unable to connect to indexer"}])
        h = have(); body["id"] = len(h) + 1; h.append(body); json.dump(h, open(f"{T}/have.json", "w"))
        self.send(201, body)
    def do_PUT(self):
        body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        self.note(json.dumps({"id": body.get("id"), "enable": body.get("enable")}))
        h = [body if i["id"] == body["id"] else i for i in have()]; json.dump(h, open(f"{T}/have.json", "w"))
        self.send(202, body)
    def do_DELETE(self):
        self.note()
        i = int(self.path.rsplit("/", 1)[1])
        json.dump([x for x in have() if x["id"] != i], open(f"{T}/have.json", "w"))
        self.send(200, {})
s = HTTPServer(("127.0.0.1", 0), H)
open(f"{T}/port", "w").write(str(s.server_address[1]))
s.serve_forever()
PY
  python3 -I "$TMP/fake.py" "$TMP" & FAKE_PID=$!
  on_exit "kill $FAKE_PID 2>/dev/null"
  for _ in {1..100}; do [[ -s $TMP/port ]] && break; /bin/sleep 0.05; done
  URL=http://127.0.0.1:$(cat "$TMP/port")
}
ix() { OUT=$(printf %s "${1:-k3y}" | KAWA_PROWLARR_URL=$URL python3 -I "$REPO/configs/home/.local/lib/fedokawaii/kawa-torrents/prowlarr.py" add 2>&1); RC=$?; }
log_of() { grep "^$1" "$TMP/api.log"; }

case_ "a new Prowlarr: the seven added, each with its priority, the profile, no tags, the schema's settings (its presets left out)"
api_world; ix; eq "$RC" 0 "$OUT"
eq "$(log_of POST | wc -l)" 7
for e in nyaasi:1 SubsPlease:5 thepiratebay:10 yts:10 Knaben:15 limetorrents:20 torrentdownloads:25; do
  has "$(log_of POST)" "\"definitionName\": \"${e%:*}\", \"enable\": true, \"priority\": ${e#*:}, \"appProfileId\": 7, \"tags\": [], \"presets\": false}"
done
lacks "$(cat "$TMP/api.log")" eztv "a Cloudflare site added"
lacks "$(cat "$TMP/api.log")" tokyotosho "Tokyo Toshokan: Cloudflare since"
eq "$(grep -c 'key=k3y' "$TMP/api.log")" "$(wc -l <"$TMP/api.log")" "every request carried the key"
case_ "run again (every update): nothing added, said so"
ix; eq "$RC" 0; has "$OUT" "all 7 in place"; eq "$(log_of POST | wc -l)" 7 "no second POST"
case_ "one you have (renamed, switched off): left as it is — matched by its kind, any letter case"
api_world; echo '[{"id": 1, "name": "My Nyaa", "definitionName": "NyaaSi", "enable": false}]' >"$TMP/have.json"
ix; eq "$RC" 0; lacks "$(log_of POST)" '"nyaasi"'; eq "$(log_of POST | wc -l)" 6
has "$(cat "$TMP/have.json")" '"name": "My Nyaa", "definitionName": "NyaaSi", "enable": false'
case_ "Tokyo Toshokan, where an older setup added it: taken out (its searches fail on Cloudflare's challenge, its page warns)"
api_world; echo '[{"id": 9, "name": "Tokyo Toshokan", "definitionName": "tokyotosho", "enable": true}]' >"$TMP/have.json"
ix; eq "$RC" 0 "$OUT"; has "$OUT" "Tokyo Toshokan: taken out"; has "$(log_of DELETE)" "/api/v1/indexer/9"; lacks "$(cat "$TMP/have.json")" tokyotosho
case_ "a site Prowlarr cannot reach from here: saved rested, the rest go on — no warning on its page, tried again at each tend"
api_world; echo "yts limetorrents" >"$TMP/unreachable"
ix; eq "$RC" 0 "$OUT"; has "$OUT" "yts: added, rested"
eq "$(python3 -c 'import json,sys; print(sum(1 for i in json.load(open(sys.argv[1])) if i["enable"]))' "$TMP/have.json")" 5 "five switched on"
eq "$(wc -l <"$HOME/.local/state/fedokawaii/torrents/rested")" 2 "both noted"
case_ "a first start, Prowlarr's list of sites not fetched yet: fetched there and then (its IndexerDefinitionUpdate, waited for), then all added"
api_world; : >"$TMP/no-defs"
ix; eq "$RC" 0 "$OUT"; has "$(log_of POST)" '"name": "IndexerDefinitionUpdate"'
has "$(cat "$TMP/api.log")" "GET /api/v1/command/31"; eq "$(log_of 'POST /api/v1/indexer' | wc -l)" 7
case_ "…its list complete already: not asked again"
api_world; ix; lacks "$(cat "$TMP/api.log")" "IndexerDefinitionUpdate"
case_ "a wrong key: refused, said, exit 2, nothing added"
api_world; ix wrong; eq "$RC" 2; has "$OUT" "refused (401)"; not_called POST; [[ ! -e $TMP/have.json ]] && _ok || _no "added with a wrong key"
case_ "Prowlarr not answering: said, exit 2"
api_world; kill "$FAKE_PID"; wait "$FAKE_PID" 2>/dev/null; ix; eq "$RC" 2; has "$OUT" "did not answer"
case_ "setup runs it with the key on stdin (never on a command line), and goes on whatever it says"
grep -q 'printf %s "$key" | as_user python3 -I "$REPO_DIR/configs/home/.local/lib/fedokawaii/kawa-torrents/prowlarr.py" add' "$REPO/setup.sh" && _ok || _no "setup's line changed"
case_ "verify knows the same seven"
has "$(sed -n '/^INDEXERS = /,/]$/p' "$REPO/configs/home/.local/lib/fedokawaii/kawa-torrents/prowlarr.py")" '("torrentdownloads", 25)'
case_ "the page: what fails rested before it opens (no warning on it)"
grep -q 'kawa-torrents tend' "$REPO/bin/kawa-prowlarr" && _ok || _no "kawa-prowlarr opens the page without tending"

# ── setup.sh's torrents_up ───────────────────────────────────────────────────
# the program checked as it stands in the repository; an older setup's torrra taken out, with its list handed
# over first; the system files pointed into the test's folder
tu_world() {
  sandbox; stub sleep; stub restorecon
  stub uv 'case "$*" in "tool uninstall torrra") rm -rf "$HOME/.local/share/uv/tools/torrra" ;; esac'
  SYS=$TMP/sys; mkdir -p "$SYS/usr/local/bin" "$SYS/etc/profile.d" "$HOME/.local/bin"
  sed -n '/^torrents_cmd() {/p; /^torrra_out() {/,/^}/p; /^torrents_up() {/,/^}/p' "$REPO/setup.sh" >"$TMP/tu.sh"
  sed -i -e "s|/usr/local/bin/kawa-torrra|$SYS/usr/local/bin/kawa-torrra|g" -e "s|/etc/profile.d/kawa-torrra.sh|$SYS/etc/profile.d/kawa-torrra.sh|g" "$TMP/tu.sh"
  { grep -q "$SYS/usr/local/bin/kawa-torrra" "$TMP/tu.sh" && ! grep -Eq '(^|[ "=])/(usr|etc)/' "$TMP/tu.sh"; } || { echo "fixture: torrents_up's system paths not pointed into the test" >&2; exit 1; }
}
tu() {   # → $OUT, $RC
  OUT=$(LOG_FILE=$TMP/fk.log STATE_DIR=$TMP/state REPO_DIR=$REPO TARGET_HOME=$HOME TARGET_USER=$(id -un) \
        TARGET_UID=$(id -u) TARGET_GID=$(id -g) bash -c 'set -Eeuo pipefail; shopt -s extglob; . "$1/lib/common.sh"; . "$2"; as_user() { "$@"; }; torrents_up' _ "$REPO" "$TMP/tu.sh" 2>&1); RC=$?
}
old_torrra() {   # what an older setup left: uv's tool, its settings, its cache, its list, its wrapper and hook
  V=$HOME/.local/share/uv/tools/torrra
  mkdir -p "$V/bin" "$HOME/.local/share/uv/tool-bin" "$HOME/.config/torrra" "$HOME/.cache/torrra" "$HOME/.local/share/torrra"
  : >"$HOME/.local/share/uv/tool-bin/torrra"; : >"$HOME/.config/torrra/config.toml"; : >"$HOME/.cache/torrra/cache.db"
  : >"$SYS/usr/local/bin/kawa-torrra"; : >"$SYS/etc/profile.d/kawa-torrra.sh"
  python3 -I -c 'import sqlite3, sys
c = sqlite3.connect(sys.argv[1])
c.execute("CREATE TABLE torrents (magnet_uri TEXT PRIMARY KEY, title TEXT, source TEXT, is_paused BOOLEAN DEFAULT 0, is_notified BOOLEAN DEFAULT 0, file_priorities TEXT, save_path TEXT)")
c.execute("INSERT INTO torrents VALUES (?,?,?,0,1,?,NULL)", ("magnet:?xt=urn:btih:" + "ab" * 20, "A Film", "Knaben", "[4, 0]"))
c.commit()' "$HOME/.local/share/torrra/torrra.db"
}

case_ "torrents_up, nothing old: the program checked, nothing else"
tu_world; tu; eq "$RC" 0 "$OUT"; not_called '^uv'
case_ "an older setup's torrra: its list handed over first, then all of it gone — its Python 3.13 too"
tu_world; old_torrra; tu; eq "$RC" 0 "$OUT"
has "$OUT" "taken out"
got=$(python3 -I -c 'import json, sys; d = json.load(open(sys.argv[1])); print(len(d), d[0]["name"], d[0]["told"], d[0]["priorities"])' "$HOME/.local/state/fedokawaii/torrents/inherited.json" 2>&1)
eq "$got" "1 A Film True [4, 0]" "the engine's to add at its next start"
called '^uv tool uninstall torrra$'; called '^uv python uninstall 3.13$'
for f in "$HOME/.config/torrra" "$HOME/.cache/torrra" "$HOME/.local/share/torrra" "$HOME/.local/share/uv/tool-bin/torrra" "$SYS/usr/local/bin/kawa-torrra" "$SYS/etc/profile.d/kawa-torrra.sh"; do
  [[ ! -e $f ]] && _ok || _no "$f is left"
done
case_ "run again (every update): nothing to do, the list not read twice"
rm -f "$HOME/.local/state/fedokawaii/torrents/inherited.json"; : >"$CALLS"; tu; eq "$RC" 0 "$OUT"; not_called '^uv'
[[ ! -e $HOME/.local/state/fedokawaii/torrents/inherited.json ]] && _ok || _no "taken over a second time"
case_ "an earlier setup's pipx install and a link of it in ~/.local/bin: gone; a torrra of your own there left alone"
tu_world; P=$HOME/.local/share/pipx; mkdir -p "$P/venvs/torrra/bin" "$P/bin"; ln -s "$P/venvs/torrra/bin/torrra" "$P/bin/torrra"; ln -s "$P/venvs/torrra/bin/torrra" "$HOME/.local/bin/torrra"
tu; eq "$RC" 0 "$OUT"; [[ ! -e $P ]] && _ok || _no "pipx's folder left"; [[ ! -e $HOME/.local/bin/torrra && ! -L $HOME/.local/bin/torrra ]] && _ok || _no "the link stays"
tu_world; printf '#!/bin/sh\n' >"$HOME/.local/bin/torrra"; tu; eq "$RC" 0 "$OUT"; [[ -f $HOME/.local/bin/torrra ]] && _ok || _no "your script went"
case_ "torrra's list unreadable: said, and nothing taken out"
tu_world; old_torrra; printf 'not a database, not at all, long enough to be read as one and fail\n%.0s' 1 2 3 >"$HOME/.local/share/torrra/torrra.db"
tu; eq "$RC" 1; has "$OUT" "could not be read"; [[ -d $HOME/.local/share/uv/tools/torrra && -e $HOME/.local/share/torrra/torrra.db ]] && _ok || _no "removed all the same"
case_ "the program does not load (Fedora's libtorrent gone): said, not passed over"
tu_world; mkdir -p "$TMP/broken"; printf 'raise ImportError("no libtorrent here")\n' >"$TMP/broken/libtorrent.py"
PYTHONPATH=$TMP/broken tu; eq "$RC" 1; has "$OUT" "does not load"


done_
