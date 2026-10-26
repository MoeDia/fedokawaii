#!/usr/bin/env bash
# tools/vm-smoke.sh — the whole install proven in a test VM (tools/vm-create.sh), from the
# fresh Fedora to a running desktop, the way the owner installs (README §2): this repository's
# tracked files (as in the working tree) copied in, `sudo bash fedokawaii.sh all` — setup with the
# theme, through its own reboots (it resumes on tty1) — then verify, then the desktop started
# (greetd's initial session: no password anywhere) and looked at: dwl, the bar and the notices
# running, a screenshot that is not black and has the bar on it.
#   bash tools/vm-smoke.sh NAME [--keep] [--timeout MIN]
#     --keep     start from the VM as it is (default: revert to the fresh install first)
#     --timeout  the longest the install may take (default 240 min)
# Everything lands in ~/VM/harness/NAME/smoke-DATE/: the log, verify's output, the shot, a
# summary line (also printed). Exit 0 green · 1 a stage failed (the summary says which) · 2 misuse.
set -u
here=$(cd "$(dirname "$0")" && pwd)
name="" keep=0 limit=240
while (($#)); do
  case $1 in
    --keep) keep=1; shift ;;
    --timeout) limit=$2; shift 2 ;;
    -h|--help) sed -n '2,/^set -u/{/^set -u/d;s/^# \{0,1\}//;p}' "$0"; exit 0 ;;
    -*) echo "vm-smoke: unknown option $1" >&2; exit 2 ;;
    *) name=$1; shift ;;
  esac
done
H=$HOME/VM/harness
[[ $name =~ ^[a-z0-9-]+$ && -d $H/$name ]] || { echo "usage: bash tools/vm-smoke.sh NAME [--keep] [--timeout MIN]" >&2; exit 2; }
out=$H/$name/smoke-$(date +%Y%m%d-%H%M%S)
mkdir -p "$out"
run() { bash "$here/vm-run.sh" "$name" "$@"; }
note() { printf '%s %s\n' "$(date +%T)" "$*" | tee -a "$out/smoke.log"; }
finish() {   # finish RESULT WHAT
  printf '%s · %s · %s · %s\n' "$(date '+%F %T')" "$name" "$1" "$2" | tee "$out/summary"
  [[ $1 == green ]] && exit 0 || exit 1
}
t0=$SECONDS
if ((!keep)); then bash "$here/vm-snap.sh" "$name" revert fresh || finish red "revert to fresh failed"; fi
bash "$here/vm-snap.sh" "$name" start >/dev/null || finish red "the VM did not start (no ssh)"
note "repo → ~/fedokawaii ($(git -C "$here/.." rev-parse --short HEAD), the working tree)"
run --repo || finish red "copying the repository in failed"
note "sudo bash fedokawaii.sh all — setup with the theme, through its reboots"
run 'cd ~/fedokawaii && sudo setsid -f bash -c "bash fedokawaii.sh all </dev/null >/tmp/fk-all.out 2>&1"' \
  || finish red "setup did not start"
# (followed by the phase file; each reboot cuts ssh — waited for; the log's last line kept)
last="" deadline=$((SECONDS + limit * 60))
while :; do
  ((SECONDS > deadline)) && finish red "setup not done after $limit min (phase: ${last:-?})"
  sleep 30
  ph=$(run 'sudo head -n1 /var/lib/fedokawaii/phase 2>/dev/null' 2>/dev/null) || continue
  [[ $ph != "$last" ]] && { note "phase: ${ph:-(none yet)}"; last=$ph; }
  [[ $ph == "done" ]] && break
  # (a run that stopped: the toolkit says ✘ and no process of it is left)
  # (the brackets: the pattern must not match the remote shell that carries it)
  if run 'pgrep -f "[f]edokawaii.sh|[s]etup.sh" >/dev/null' 2>/dev/null; then continue; fi
  if run 'sudo grep -q "✘" /var/log/fedokawaii.log 2>/dev/null && ! systemctl is-active -q fedokawaii-resume.service 2>/dev/null' 2>/dev/null; then
    run 'sudo tail -n 40 /var/log/fedokawaii.log' >"$out/setup-tail.log" 2>&1
    finish red "setup stopped in phase ${ph:-?} — $out/setup-tail.log"
  fi
done
note "setup done in $(( (SECONDS - t0) / 60 )) min"
run 'sudo cat /var/log/fedokawaii.log' >"$out/setup.log" 2>&1
run 'sudo fedokawaii verify' >"$out/verify.log" 2>&1
vrc=$?
counts=$(grep -oE '[0-9]+/[0-9]+' "$out/verify.log" | tail -n 1)
note "verify: exit $vrc ${counts:+· $counts} (the failing lines: grep ✘ $out/verify.log)"
# the desktop: greetd's initial session, as on the PC (CLAUDE.md START §4), never a password
run 'f=/etc/greetd/fedokawaii.toml; sudo cp -a $f /root/fk.bak && printf "\n[initial_session]\ncommand = \"/usr/local/bin/start-dwl\"\nuser = \"dia\"\n" | sudo tee -a $f >/dev/null && sudo rm -f /run/greetd.run && sudo systemctl restart greetd; sleep 20; sudo cp -a /root/fk.bak $f' \
  || finish red "the session could not be started"
procs=$(run 'for p in dwl waybar mako; do pgrep -u dia -x $p >/dev/null && printf "%s " $p; done')
note "running: ${procs:-nothing}"
run 'eval "$(tr "\0" "\n" </proc/$(pgrep -u dia -xo waybar)/environ | grep -E "^(WAYLAND_DISPLAY|XDG_RUNTIME_DIR)=" | sed "s/^/export /")"; grim /tmp/smoke.png' \
  && run --get /tmp/smoke.png "$out/desktop.png"
shot=bad
if [[ -s $out/desktop.png ]]; then
  # (not black: more than 2 colours make up at least half of it; the bar: its top 40 rows hold
  # more than 8 colours)
  python3 -I - "$out/desktop.png" <<'PY' && shot=ok
import sys
from PIL import Image
im = Image.open(sys.argv[1]).convert("RGB")
w, h = im.size
cols = im.getcolors(1 << 24) or []
big = sorted(cols, reverse=True)
top = im.crop((0, 0, w, min(40, h))).getcolors(1 << 24) or []
sys.exit(0 if (sum(c for c, _ in big[:2]) < 0.9 * w * h and len(top) > 8) else 1)
PY
fi
note "screenshot: $shot ($out/desktop.png)"
[[ $vrc -eq 0 && $procs == "dwl waybar mako " && $shot == ok ]] \
  && finish green "verify ${counts:-ok}, desktop up in $(( (SECONDS - t0) / 60 )) min" \
  || finish red "verify exit $vrc ${counts}, running: ${procs:-none}, shot $shot"
