#!/usr/bin/env bash
# shellcheck disable=SC2154  # (here, log, out: lib.sh's)
# tools/vm-inject/fixer-candidate.sh — the local AI fixer inside the button's real path (T47, row 13 of
# update-design.md §5), in a harness VM from run-all.sh's state "inject": a package whose update makes
# foot refuse a line of our config. A VM has no card, so the model is a stand-in that answers one
# fixed edit: what is proven here is everything around the model — the candidate's real container, its
# copy of the home, the program's own check inside it, the fix kept, the package NOT held, the same
# fix on the running system after the theme — and the second run: the stand-in refusing, the package
# held and told. The real model on the real card: tools/fixer-bench.py.
#   bash tools/vm-inject/fixer-candidate.sh VM TREE
# Out: a line a check, the evidence in /dev/shm/r27/inject/fixer-candidate/. Exit 0 all held · 1 one
# did not · 2 the VM could not run.
set -u
vm=${1:?VM} src=${2:?TREE}
# shellcheck source=tools/vm-inject/lib.sh
. "$(dirname "$0")/lib.sh"
U=/var/lib/fedokawaii/update
inj_init "$vm" "$src" fixer-candidate
inj_from inject
run --repo "$src" >>"$log" 2>&1 && run 'sudo bash ~/fedokawaii/setup.sh --toolkit' >>"$log" 2>&1 || { row BROKEN "the toolkit"; exit 2; }
# shellcheck disable=SC2016  # (each check's words: run by eval, in the VM)
ok() { if eval "$2"; then row held "$1"; else row BROKEN "$1 — failed: $2"; fi; }

# the stand-in model: an answer from a file, over the socket kawa-fixer is told of by its wrapper
# (the wrapper is the program's only change: update_steps installs the real one again, after the candidate)
run 'cat | sudo tee /usr/local/sbin/fk-stub-model >/dev/null; sudo chmod 755 /usr/local/sbin/fk-stub-model' <<'PY'
#!/usr/bin/python3 -I
import http.server, json, os, socketserver, sys
class H(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.0"
    def log_message(self, *a):
        pass
    def address_string(self):
        return "stub"
    def do_GET(self):
        self.send_response(200); self.end_headers(); self.wfile.write(b'{"status":"ok"}')
    def do_POST(self):
        self.rfile.read(int(self.headers["Content-Length"]))
        ans = open("/run/fk-stub-answer").read()
        d = {"choices": [{"delta": {"content": ans}}], "timings": {"prompt_n": 9, "predicted_n": 9, "predicted_per_second": 1.0}}
        self.send_response(200); self.end_headers()
        self.wfile.write(b"data: " + json.dumps(d).encode() + b"\n\ndata: [DONE]\n\n")
class S(socketserver.ThreadingMixIn, socketserver.UnixStreamServer):
    daemon_threads = True
    def get_request(self):
        c, _ = super().get_request()
        return c, ("stub", 0)
if os.path.exists("/run/fk-stub.sock"):
    os.unlink("/run/fk-stub.sock")
S("/run/fk-stub.sock", H).serve_forever()
PY
# the package: its update makes foot refuse selection-target= (a rename, as a real one would): its
# scriptlet puts this wrapper over foot, in the copy and on the system alike
run 'cat | sudo tee /usr/local/sbin/fk-foot-wrap >/dev/null; sudo chmod 755 /usr/local/sbin/fk-foot-wrap' <<'SH'
#!/bin/bash
[ -e /usr/bin/foot.real ] || cp -a /usr/bin/foot /usr/bin/foot.real
cat >/usr/bin/foot <<'WRAP'
#!/bin/bash
case " $* " in
  *" --check-config "*)
    if grep -q "^selection-target=" "$HOME/.config/foot/foot.ini"; then
      echo " err: config.c:1: $HOME/.config/foot/foot.ini:1: [main].selection-target: clipboard: not a valid option: selection-target" >&2
      exit 230
    fi
    exit 0 ;;
esac
exec /usr/bin/foot.real "$@"
WRAP
chmod 755 /usr/bin/foot
SH
setup_run() {   # setup_run ANSWER — this press's stand-in, the wrapper over the program
  printf '%s' "$1" | run 'cat | sudo tee /run/fk-stub-answer >/dev/null'
  run 'sudo setsid -f /usr/local/sbin/fk-stub-model >/dev/null 2>&1 </dev/null
       sudo cp -n /usr/local/sbin/kawa-fixer /usr/local/sbin/kawa-fixer.real
       printf "#!/bin/sh\nKAWA_FIXER_SOCK=/run/fk-stub.sock exec /usr/local/sbin/kawa-fixer.real \"\$@\"\n" | sudo tee /usr/local/sbin/kawa-fixer >/dev/null
       sudo chmod 755 /usr/local/sbin/kawa-fixer; sleep 1' >>"$log" 2>&1
}
run 'sudo fk-inject-pkg fk-inject-a 1.1 post=/usr/local/sbin/fk-foot-wrap' >>"$log" 2>&1
FIX='{"verdict":"fix","reason":"selection-target was renamed","edits":[{"file":"~/.config/foot/foot.ini","search":"selection-target=clipboard","replace":"selection-target=both"}]}'

setup_run "$FIX"; press update; facts >>"$log" 2>&1
ok "the update's run ends well"                       '[[ $INJ_RC == 0 ]]'
ok "the package went in, not held"                    '[[ $(run "rpm -q --qf %{version} fk-inject-a") == 1.1 ]]'
ok "the report says what the fixer did"               'run "sudo grep -q \"fixed foot.ini\" '$U'/report"'
ok "the fix is kept in the updater's memory"          'run "sudo ls '$U'/fixes/ | grep -q json"'
ok "the fix is on the running system"                 'run "grep -q ^selection-target=both ~/.config/foot/foot.ini"'
ok "the program takes it"                             'run "foot --check-config"'
ok "the candidate and the home's copy are gone"       '[[ $(run "sudo btrfs subvolume list / | grep -cE \"root.cand|home.cand\"") == 0 ]]'
run 'sudo bash /usr/local/lib/fedokawaii/fedokawaii.sh theme' >>"$log" 2>&1
ok "a theme run does not undo it"                     'run "grep -q ^selection-target=both ~/.config/foot/foot.ini"'
ok "and still says in sync"                           'run "sudo bash ~/fedokawaii/theme.sh --user dia --check"'

# the second: the same breakage, the stand-in refuses — held and told, nothing kept
inj_from inject
run --repo "$src" >>"$log" 2>&1 && run 'sudo bash ~/fedokawaii/setup.sh --toolkit' >>"$log" 2>&1
run 'sudo fk-inject-pkg fk-inject-a 1.1 post=/usr/local/sbin/fk-foot-wrap' >>"$log" 2>&1
setup_run '{"verdict":"cannot_fix","reason":"the documentation does not show a new name","edits":[]}'; press update; facts >>"$log" 2>&1
ok "no fix: the run ends well"                        '[[ $INJ_RC == 0 ]]'
ok "the package is held"                              '[[ $(run "rpm -q --qf %{version} fk-inject-a") == 1.0 ]] && run "sudo grep -q fk-inject-a '$U'/holds"'
ok "the report says why"                              'run "sudo grep -q \"the fixer: held\" '$U'/report"'
ok "the config untouched"                             'run "grep -q ^selection-target=clipboard ~/.config/foot/foot.ini"'
exit "$INJ_BAD"
