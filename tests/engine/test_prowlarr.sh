#!/usr/bin/env bash
# tests/engine/test_prowlarr.sh — Prowlarr on demand, from the two places that start it and
# then go on without it: setup.sh's prowlarr_up (setup, update, repair, the Fedora move) and
# the `prowlarr` shell command (its web page). A start that fails is stopped again: left
# alone, the unit's Restart=on-failure would try it every 10 s until the next boot.
# (kawa-torrra and verify already stop it: tests/engine/test_torrra.sh, tests/installer.)
# Then setup.sh's other torrent steps, as functions: torrra_up (torrra at its pinned version
# with its libraries at the versions it was released with, uv's own `torrra` kept off your
# PATH, the load probe that verify shares) and torrent_port (the firewall, never reloaded).
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
called '^notify-send -a torrra -u critical -- .*  Prowlarr did not start'
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

# ── setup's indexers (system/prowlarr-indexers.py), against a stand-in Prowlarr ─────
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
s = HTTPServer(("127.0.0.1", 0), H)
open(f"{T}/port", "w").write(str(s.server_address[1]))
s.serve_forever()
PY
  python3 -I "$TMP/fake.py" "$TMP" & FAKE_PID=$!
  on_exit "kill $FAKE_PID 2>/dev/null"
  for _ in {1..100}; do [[ -s $TMP/port ]] && break; /bin/sleep 0.05; done
  URL=http://127.0.0.1:$(cat "$TMP/port")
}
ix() { OUT=$(printf %s "${1:-k3y}" | python3 -I "$REPO/system/prowlarr-indexers.py" "$URL" 2>&1); RC=$?; }
log_of() { grep "^$1" "$TMP/api.log"; }

case_ "a new Prowlarr: the eight added, each with its priority, the profile, no tags, the schema's settings (its presets left out)"
api_world; ix; eq "$RC" 0 "$OUT"
eq "$(log_of POST | wc -l)" 8
for e in nyaasi:1 SubsPlease:5 tokyotosho:10 thepiratebay:10 yts:10 Knaben:15 limetorrents:20 torrentdownloads:25; do
  has "$(log_of POST)" "\"definitionName\": \"${e%:*}\", \"enable\": true, \"priority\": ${e#*:}, \"appProfileId\": 7, \"tags\": [], \"presets\": false}"
done
lacks "$(cat "$TMP/api.log")" eztv "a Cloudflare site added"
eq "$(grep -c 'key=k3y' "$TMP/api.log")" "$(wc -l <"$TMP/api.log")" "every request carried the key"
case_ "run again (every update): nothing added, said so"
ix; eq "$RC" 0; has "$OUT" "all 8 in place"; eq "$(log_of POST | wc -l)" 8 "no second POST"
case_ "one you have (renamed, switched off): left as it is — matched by its kind, any letter case"
api_world; echo '[{"id": 1, "name": "My Nyaa", "definitionName": "NyaaSi", "enable": false}]' >"$TMP/have.json"
ix; eq "$RC" 0; lacks "$(log_of POST)" '"nyaasi"'; eq "$(log_of POST | wc -l)" 7
has "$(cat "$TMP/have.json")" '"name": "My Nyaa", "definitionName": "NyaaSi", "enable": false'
case_ "a site Prowlarr cannot reach now: saved switched off, then switched on without the test — the rest go on"
api_world; echo "yts limetorrents" >"$TMP/unreachable"
ix; eq "$RC" 0 "$OUT"; has "$OUT" "yts: added (not reachable just now"
has "$(log_of PUT)" "forceSave=true"; eq "$(log_of PUT | wc -l)" 2
eq "$(python3 -c 'import json,sys; print(sum(1 for i in json.load(open(sys.argv[1])) if i["enable"]))' "$TMP/have.json")" 8 "all eight switched on"
case_ "a first start, Prowlarr's list of sites not fetched yet: fetched there and then (its IndexerDefinitionUpdate, waited for), then all eight added"
api_world; : >"$TMP/no-defs"
ix; eq "$RC" 0 "$OUT"; has "$(log_of POST)" '"name": "IndexerDefinitionUpdate"'
has "$(cat "$TMP/api.log")" "GET /api/v1/command/31"; eq "$(log_of 'POST /api/v1/indexer' | wc -l)" 8
case_ "…its list complete already: not asked again"
api_world; ix; lacks "$(cat "$TMP/api.log")" "IndexerDefinitionUpdate"
case_ "a wrong key: refused, said, exit 2, nothing added"
api_world; ix wrong; eq "$RC" 2; has "$OUT" "refused (401)"; not_called POST; [[ ! -e $TMP/have.json ]] && _ok || _no "added with a wrong key"
case_ "Prowlarr not answering: said, exit 2"
api_world; kill "$FAKE_PID"; wait "$FAKE_PID" 2>/dev/null; ix; eq "$RC" 2; has "$OUT" "did not answer"
case_ "setup runs it with the key on stdin (never on a command line), and goes on whatever it says"
grep -q 'printf %s "$key" | as_user python3 -I "$REPO_DIR/system/prowlarr-indexers.py"' "$REPO/setup.sh" && _ok || _no "setup's line changed"
case_ "verify knows the same eight"
has "$(sed -n '/^INDEXERS = /,/]$/p' "$REPO/system/prowlarr-indexers.py")" '("torrentdownloads", 25)'

# ── setup.sh's torrra_up ─────────────────────────────────────────────────────
# a venv of the real python3 with the stand-in torrra (fixtures/torrra: its screens fail to
# load while $FAKE_TEXTUAL_BROKEN exists); the two system files it installs pointed into
# the test's folder; uv a stand-in that records where it would put its `torrra`
D=$(cd "$(dirname "$0")" && pwd)
TV=$(sed -n 's/^TORRRA_VERSION=//p' "$REPO/lib/upstream.sh")
tu_world() {
  sandbox; stub sleep; stub restorecon
  V=$HOME/.local/share/uv/tools/torrra SYS=$TMP/sys
  local pyv; pyv=$(python3 -c 'import sys; print(f"python{sys.version_info[0]}.{sys.version_info[1]}")')
  mkdir -p "$V/bin" "$V/lib/$pyv/site-packages" "$SYS/usr/local/bin" "$SYS/etc/profile.d" "$HOME/.local/bin"
  ln -s "$(command -v python3)" "$V/bin/python"; : >"$V/bin/torrra"
  printf 'home = %s\ninclude-system-site-packages = false\n' "$(dirname "$(command -v python3)")" >"$V/pyvenv.cfg"
  cp -r "$D/fixtures/torrra/." "$V/lib/$pyv/site-packages/"
  printf 'Metadata-Version: 2.1\nName: torrra\nVersion: %s\n' "$TV" >"$V/lib/$pyv/site-packages/torrra-2.5.1.dist-info/METADATA"
  python3 -I "$D/fixtures/pins.py" "$REPO/system/torrra-constraints.txt" "$V/lib/$pyv/site-packages"   # (each library at its pin)
  sed -n '/^torrra_from_pipx() {/,/^}/p; /^torrra_up() {/,/^}/p' "$REPO/setup.sh" >"$TMP/tu.sh"
  sed -i -e "s|/usr/local/bin/kawa-torrra|$SYS/usr/local/bin/kawa-torrra|g" \
         -e "s|/etc/profile.d/kawa-torrra.sh|$SYS/etc/profile.d/kawa-torrra.sh|g" "$TMP/tu.sh"
  # (both rewrites made, and no path of this machine's own left in it)
  { grep -q "$SYS/usr/local/bin/kawa-torrra" "$TMP/tu.sh" && grep -q "$SYS/etc/profile.d/kawa-torrra.sh" "$TMP/tu.sh" \
      && ! grep -Eq '(^|[ "=])/(usr|etc)/' "$TMP/tu.sh"; } || { echo "fixture: torrra_up's system paths not pointed into the test" >&2; exit 1; }
  stub uv 'printf %s "${UV_TOOL_BIN_DIR:-}" >"'"$TMP"'/uv-bin-dir"
case " $* " in *" tool install "*) rm -f "${FAKE_TEXTUAL_BROKEN:-/nonexistent}"; python3 -I "'"$D/fixtures/pins.py"'" "'"$REPO/system/torrra-constraints.txt"'" "'"$V/lib/$pyv/site-packages"'"
  b=${UV_TOOL_BIN_DIR:-$HOME/.local/bin}; mkdir -p "$b"; ln -sfn "'"$V"'/bin/torrra" "$b/torrra" ;; esac'
  unset FAKE_TEXTUAL_BROKEN
}
tu() {   # → $OUT, $RC
  OUT=$(LOG_FILE=$TMP/fk.log STATE_DIR=$TMP/state REPO_DIR=$REPO TARGET_HOME=$HOME TARGET_USER=$(id -un) \
        TARGET_UID=$(id -u) TARGET_GID=$(id -g) TORRRA_VENV=.local/share/uv/tools/torrra TORRRA_BIN=.local/share/uv/tool-bin TORRRA_VERSION=$TV \
        bash -c 'set -Eeuo pipefail; . "$1/lib/common.sh"; . "$2"; as_user() { "$@"; }; torrra_up' _ "$REPO" "$TMP/tu.sh" 2>&1); RC=$?
}
C=$REPO/system/torrra-constraints.txt

case_ "torrra_up, torrra working: nothing installed — an old \`torrra\` link in ~/.local/bin taken out"
tu_world; ln -s "$V/bin/torrra" "$HOME/.local/bin/torrra"
tu; eq "$RC" 0 "$OUT"; not_called '^uv'
[[ ! -e $HOME/.local/bin/torrra && ! -L $HOME/.local/bin/torrra ]] && _ok || _no "the raw torrra is still on your PATH"
[[ -x $SYS/usr/local/bin/kawa-torrra ]] && _ok || _no "kawa-torrra not installed"
case_ "…a torrra of your own there (a script, a link elsewhere) is left alone"
tu_world; printf '#!/bin/sh\n' >"$HOME/.local/bin/torrra"; tu; eq "$RC" 0; [[ -f $HOME/.local/bin/torrra ]] && _ok || _no "your script went"
tu_world; ln -s /bin/true "$HOME/.local/bin/torrra"; tu; [[ -L $HOME/.local/bin/torrra ]] && _ok || _no "your link went"
case_ "torrra_up, Textual broken under torrra: the load probe sees it — installed again, with the pinned libraries"
tu_world; export FAKE_TEXTUAL_BROKEN=$TMP/textual-broken; : >"$FAKE_TEXTUAL_BROKEN"
tu; eq "$RC" 0 "$OUT"
called "^uv tool install --force --python 3.13 --constraints $C torrra==$TV$"
case_ "…and uv's own \`torrra\` kept in uv's folder, never on your PATH"
eq "$(cat "$TMP/uv-bin-dir" 2>/dev/null)" "$HOME/.local/share/uv/tool-bin"
[[ ! -e $HOME/.local/bin/torrra && ! -L $HOME/.local/bin/torrra ]] && _ok || _no "uv linked torrra into ~/.local/bin"
case_ "an earlier setup's pipx install: taken out, then installed by uv"
tu_world; P=$HOME/.local/share/pipx; mkdir -p "$P/venvs/torrra/bin" "$P/bin"; ln -s "$P/venvs/torrra/bin/torrra" "$P/bin/torrra"
mv "$V" "$TMP/uvgone"; stub uv 'mkdir -p "'"$V"'"; cp -a "'"$TMP/uvgone"'/." "'"$V"'/"'
tu; eq "$RC" 0 "$OUT"; [[ ! -e $P ]] && _ok || _no "pipx's folder left"; called "^uv tool install --force --python 3.13 --constraints $C torrra==$TV$"
unset FAKE_TEXTUAL_BROKEN
case_ "torrra_up, a library not at its pin (Textual 8.0.1, before ansi-dark): installed again, at the pins"
tu_world; s=$(ls -d "$V"/lib/python*/site-packages); rm -rf "$s"/textual-*.dist-info; mkdir -p "$s/textual-8.0.1.dist-info"
printf 'Metadata-Version: 2.1\nName: textual\nVersion: 8.0.1\n' >"$s/textual-8.0.1.dist-info/METADATA"
tu; eq "$RC" 0 "$OUT"; called "^uv tool install --force --python 3.13 --constraints $C torrra==$TV$"
[[ -d $s/textual-8.2.8.dist-info && ! -d $s/textual-8.0.1.dist-info ]] && _ok || _no "Textual not at its pin after the install"
case_ "torrra_up, broken and not mended by the install: said, not passed over"
tu_world; stub uv; export FAKE_TEXTUAL_BROKEN=$TMP/textual-broken; : >"$FAKE_TEXTUAL_BROKEN"
tu; eq "$RC" 1; has "$OUT" "is installed but does not load"; unset FAKE_TEXTUAL_BROKEN

case_ "the constraints: torrra's libraries at the versions it was released with; libtorrent and certifi free"
[[ -f $C ]] && _ok || _no "no $C"
bad=$(grep -Ev '^(#|$)' "$C" 2>/dev/null | grep -Ev '^[a-z0-9][a-z0-9._-]*==[0-9][0-9A-Za-z.+-]*$'); eq "$bad" "" "not NAME==VERSION: $bad"
for p in textual==8.2.8 rich==14.2.0 httpx==0.28.1 click==8.3.1; do grep -qx "$p" "$C" 2>/dev/null && _ok || _no "$p not pinned"; done
for p in libtorrent certifi torrra; do grep -Eq "^$p==" "$C" 2>/dev/null && _no "$p pinned" || _ok; done
case_ "the update moves libtorrent (uv tool upgrade: the install's own pins kept)"
grep -q 'uv tool upgrade torrra' "$REPO/setup.sh" && _ok || _no "the update's libtorrent step changed"

case_ "verify's load check sees a broken Textual too (it loads torrra's screens)"
tu_world
vp=$(sed -n "s|.*uv/tools/torrra/bin/python\" -I -c '\\([^']*\\)' \"\$TORRRA_VERSION\".*|\\1|p" "$REPO/verify.sh")
[[ -n $vp ]] && _ok || _no "verify's torrra check not found"
if python3 -c 'import sys; sys.exit(sys.version_info[:2] != (3, 13))'; then
  "$V/bin/python" -I -c "$vp" "$TV" 2>/dev/null && _ok || _no "a working torrra fails verify's check"
else _ok; fi
: >"$TMP/textual-broken"
FAKE_TEXTUAL_BROKEN=$TMP/textual-broken "$V/bin/python" -I -c "$vp" "$TV" 2>/dev/null && _no "a broken Textual passes verify's check" || _ok

# ── setup.sh's open_ports (torrra's 6881, LocalSend's 53317) ──────────────────────────────────────────────────
# firewalld: its saved ports in $TMP/fw-perm, its running ones in $TMP/fw-run; a reload
# makes the running ones the saved ones (dropping what was added only while it runs)
tp_world() {
  sandbox
  { grep '^OPEN_PORTS=' "$REPO/setup.sh"; sed -n '/^open_ports() {/,/^}/p' "$REPO/setup.sh"; } >"$TMP/tp.sh"
  : >"$TMP/fw-perm"; : >"$TMP/fw-run"
  stub firewall-cmd 'f="$TMP/fw-run"; for a in "$@"; do [ "$a" = --permanent ] && f="$TMP/fw-perm"; done
for a in "$@"; do case $a in
  --state) [ -e "$TMP/fw-down" ] && exit 252; exit 0 ;;
  --query-port=*) grep -qx "${a#--query-port=}" "$f"; exit $? ;;
  --add-port=*) echo "${a#--add-port=}" >>"$f" ;;
  --reload) cp "$TMP/fw-perm" "$TMP/fw-run" ;;
esac; done'
}
tp() { OUT=$(LOG_FILE=$TMP/fk.log bash -c 'set -Eeuo pipefail; . "$1/lib/common.sh"; LOCALSEND_PORT=53317; . "$2"; open_ports' _ "$REPO" "$TMP/tp.sh" 2>&1); RC=$?; }
both() { printf '%s\n' 6881/tcp 6881/udp 53317/tcp 53317/udp; }

case_ "open_ports, 6881 open already (saved and running): nothing changed, firewalld not reloaded"
tp_world; both >"$TMP/fw-perm"; both >"$TMP/fw-run"; tp; eq "$RC" 0 "$OUT"
not_called 'add-port'; not_called 'reload'
case_ "open_ports, closed: opened, saved and running, without a reload"
tp_world; tp; eq "$RC" 0 "$OUT"
eq "$(sort "$TMP/fw-perm" | tr '\n' ' ')" "53317/tcp 53317/udp 6881/tcp 6881/udp "; eq "$(sort "$TMP/fw-run" | tr '\n' ' ')" "53317/tcp 53317/udp 6881/tcp 6881/udp "
not_called 'reload'
case_ "open_ports, saved but not running (another rule added at run time stays): opened while it runs"
tp_world; both >"$TMP/fw-perm"; echo 8080/tcp >"$TMP/fw-run"; tp; eq "$RC" 0
has "$(cat "$TMP/fw-run")" "8080/tcp" "a rule added while firewalld runs was dropped"; has "$(cat "$TMP/fw-run")" "6881/udp"
not_called '\-\-permanent \-\-add-port'
case_ "open_ports, firewalld not running: said, nothing done"
tp_world; : >"$TMP/fw-down"; tp; eq "$RC" 0; has "$OUT" "firewalld is not running"; not_called 'port'

done_
