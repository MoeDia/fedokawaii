#!/usr/bin/env bash
# tests/look/test_lock.sh — kawa-lock (Super+Escape, before sleep, the power menu) and the
# idle chain autostart.sh sets up: the screens off after an hour, nothing else. swaylock is a
# stand-in that keeps its arguments and stays "running" like swaylock -f; ImageMagick is the
# real one, so the decorated padlock is checked as a picture.
. "$(dirname "$0")/../lib/harness.sh"
. "$(dirname "$0")/lib.sh"
need magick python3 flock
REAL_MAGICK=$(command -v magick)

setup() {
  look
  SHARE=$HOME/.local/share/fedokawaii CONF=$HOME/.config/fedokawaii/current/swaylock
  # swaylock -f: keeps its arguments, locks (stays running) and returns
  argv swaylock '[ -e /proc/$$/fd/9 ] && echo "lock held" >>"$FAKE_TMP/fd9"
bash -c '"'"'exec -a "$0" /bin/sleep 300'"'"' "fake-swaylock-of-$FAKE_TMP" >/dev/null 2>&1 9>&- &
echo "swaylock $!" >>"$FAKE_PROCS"'
  # the real ImageMagick, its arguments kept
  argv magick "exec '$REAL_MAGICK' \"\$@\""
  # fonts: whatever this machine has (the desktop's pixel fonts are not needed to draw)
  FONT=$(fc-match -f '%{file}' monospace 2>/dev/null)
  if [[ -s $FONT ]]; then stub fc-match "printf '%s' '$FONT'"; PIC=$XDG_RUNTIME_DIR/kawa-lock.png
  else stub fc-match 'exit 1'; PIC=$SHARE/dark/lock.png; fi      # (no fonts at all: the bare padlock)
  # shellcheck source=/dev/null
  . "$HOME/.config/fedokawaii/icons.sh"
}
locks() { grep -c '^swaylock' "$CALLS"; }              # (counted safely when two run at once)
after() { args_of magick | grep -A1 -xF -- "$1" | tail -n1; }      # after ARG — the argument after ARG
annotate_text() { after +2+86; }                                       # the date line

# ── a lock ───────────────────────────────────────────────────────────────────
setup
case_ "Super+Escape: the padlock with the day's kanji and the date, through the theme's settings"
rc 0 kawa-lock
eq "$(locks)" 1
args_eq swaylock 1 -f -C "$CONF" -i "$PIC"
if [[ -s $FONT ]]; then
  pad=$(size_of "$SHARE/dark/lock.png"); w=${pad%x*} h=${pad#*x}
  eq "$(size_of "$XDG_RUNTIME_DIR/kawa-lock.png")" "$((w + 480))x$((h + 340))" "grown evenly on every side: the padlock stays centred"
  k=$(after +1+1); [[ ${#k} == 1 && 月火水木金土日 == *"$k"* ]] && _ok || _no "the weekday kanji: [$k]"
  [[ $(annotate_text) =~ ^(MON|TUE|WED|THU|FRI|SAT|SUN)\ [0-9]{2}\ [A-Z]{3}$ ]] && _ok || _no "the date line: $(annotate_text)"
fi
[[ ! -e $XDG_RUNTIME_DIR/kawa-lock.png.tmp ]] && _ok || _no "a half-made picture was left"
[[ ! -e $TMP/fd9 ]] && _ok || _no "swaylock keeps kawa-lock's lock: every later call would wait 5 s"

case_ "before sleep (--now): the bare padlock at once, no drawing"
setup
rc 0 kawa-lock --now
args_eq swaylock 1 -f -C "$CONF" -i "$SHARE/dark/lock.png"
eq "$(ncalls magick)" 0

case_ "the light theme: its own padlock and settings"
setup
ln -sfn themes/light "$HOME/.config/fedokawaii/current"
kawa-lock --now
args_eq swaylock 1 -f -C "$CONF" -i "$SHARE/light/lock.png"

case_ "already locked (a second press, idle while locked): nothing more"
setup
kawa-lock --now
rc 0 kawa-lock; rc 0 kawa-lock --now
eq "$(locks)" 1
eq "$(ncalls magick)" 0 "no picture drawn for nothing"

case_ "two at once (a double press while the first draws its picture): one lock"
setup
stubf magick <<'EOF'
: >"$FAKE_TMP/gate.magick.in"; while [ ! -e "$FAKE_TMP/gate.magick" ]; do /bin/sleep 0.02; done; exit 1
EOF
kawa-lock & a=$!
at_gate magick || _no "the first never reached its picture"
kawa-lock & b=$!
/bin/sleep 0.3
eq "$(locks)" 0 "the second waits for the first"
open_gate magick
wait "$a"; ra=$?; wait "$b"; rb=$?
eq "$ra$rb" 00
eq "$(locks)" 1 "one swaylock"

case_ "before sleep while the idle lock still draws its picture: --now locks at once, alone"
setup
stubf magick <<'EOF'
: >"$FAKE_TMP/gate.magick.in"; while [ ! -e "$FAKE_TMP/gate.magick" ]; do /bin/sleep 0.02; done; exit 1
EOF
kawa-lock & a=$!
at_gate magick || _no "the idle lock never reached its picture"
start=$(date +%s%N)
kawa-lock --now; rn=$?
ms=$(( ($(date +%s%N) - start) / 1000000 ))
eq "$rn" 0
((ms < 2000)) && _ok || _no "--now waited $ms ms for the other one"
eq "$(locks)" 1 "locked before the drawing is done"
open_gate magick; wait "$a"; ra=$?
eq "$ra" 0
eq "$(locks)" 1 "the drawing one stands down: still one swaylock"

case_ "a held key (20 presses in a row): one lock"
setup
for _ in {1..20}; do kawa-lock --now; done
eq "$(locks)" 1

# ── a lock you asked for: sleep 90 s later ─────────────────────────────────────
case_ "Super+Escape (--sleep): locked, and still locked when the time is up — the computer sleeps"
setup; stub systemctl
KAWA_LOCK_SLEEP=1 kawa-lock --sleep; r=$?
eq "$r" 0; eq "$(locks)" 1
for _ in {1..40}; do grep -q '^systemctl suspend' "$CALLS" && break; /bin/sleep 0.1; done
called '^systemctl suspend$'
case_ "--sleep, unlocked before the time is up: it stays awake"
setup; stub systemctl
KAWA_LOCK_SLEEP=2 kawa-lock --sleep
pid=$(awk '$1 == "swaylock" { p = $2 } END { print p }' "$FAKE_PROCS"); kill "$pid" 2>/dev/null
/bin/sleep 3
not_called '^systemctl suspend'
case_ "--sleep: 90 s unless KAWA_LOCK_SLEEP says otherwise (0: never); --now and a plain lock never sleep"
grep -q 'sleep_after=90' "$REPO/bin/kawa-lock" && _ok || _no "the default is not 90 s"
setup; stub systemctl
KAWA_LOCK_SLEEP=0 kawa-lock --sleep; /bin/sleep 1.5; not_called '^systemctl'
setup; stub systemctl
KAWA_LOCK_SLEEP=1 kawa-lock --now; /bin/sleep 1.5; not_called '^systemctl'
setup; stub systemctl
KAWA_LOCK_SLEEP=1 kawa-lock; /bin/sleep 1.5; not_called '^systemctl'
case_ "--sleep when swaylock fails: no sleep (never an unlocked one), the failure returned"
setup; stub systemctl; argv swaylock 'exit 1'
KAWA_LOCK_SLEEP=1 kawa-lock --sleep; r=$?
eq "$r" 1; /bin/sleep 1.5; not_called '^systemctl'
case_ "the key and the power menu's lock ask for it (--sleep); the power menu's sleep does not wait"
grep -q 'XKB_KEY_Escape, *spawn, *SHCMD("kawa-lock --sleep")' "$REPO/src/dwl/config.h" && _ok || _no "Super+Escape"
grep -q '0) exec kawa-lock --sleep ;;' "$REPO/bin/kawa-power" && _ok || _no "power menu lock"
grep -q '1) kawa-lock && act sleep suspend ;;' "$REPO/bin/kawa-power" && _ok || _no "power menu sleep"

# ── when something is missing or broken it still locks ─────────────────────────
case_ "the theme link missing: the plain ground colour, still the padlock"
setup
rm "$HOME/.config/fedokawaii/current"
rc 0 kawa-lock --now
args_eq swaylock 1 -f -i "$SHARE/dark/lock.png" -c 0f0e0c

case_ "the padlock picture missing: still locks, plainly"
setup
rm -f "$SHARE"/dark/lock.png
rc 0 kawa-lock
args_eq swaylock 1 -f -C "$CONF"

case_ "ImageMagick missing, failing or stuck: the bare padlock (stuck: after 3 s at most)"
setup
hide magick
rc 0 kawa-lock
args_eq swaylock 1 -f -C "$CONF" -i "$SHARE/dark/lock.png"
setup
stub magick 'echo "magick: unable to read font" >&2; exit 1'
err=$(kawa-lock 2>&1); r=$?
eq "$r" 0; eq "$err" "" "quiet"
args_eq swaylock 1 -f -C "$CONF" -i "$SHARE/dark/lock.png"
setup
stub magick 'exec /bin/sleep 30'
start=$SECONDS; kawa-lock; took=$((SECONDS - start))
((took <= 5)) && _ok || _no "a stuck ImageMagick held the lock back $took s"
args_eq swaylock 1 -f -C "$CONF" -i "$SHARE/dark/lock.png"

case_ "no runtime folder (XDG_RUNTIME_DIR unset): still locks, without the date"
setup
( unset XDG_RUNTIME_DIR; kawa-lock ); r=$?
eq "$r" 0
args_eq swaylock 1 -f -C "$CONF" -i "$SHARE/dark/lock.png"

case_ "swaylock missing: says so (a notice too) and fails, so the power menu does not suspend"
setup
hide swaylock
out=$(kawa-lock 2>&1); r=$?
eq "$r" 1
has "$out" "swaylock"
lacks "$out" "line "
called "^notify-send -a desktop -u critical $ICON_LOCK  Could not lock the screen"

case_ "swaylock failing or crashing: the failure reaches the caller (no suspend unlocked)"
setup
argv swaylock 'exit 1'
rc 1 kawa-lock
argv swaylock 'kill -SEGV $$'
r=$(bash -c 'kawa-lock >/dev/null 2>&1; echo $?' 2>/dev/null)
((r != 0)) && _ok || _no "a crashed swaylock looked like a lock"
setup
stub swaylock 'exit 1'
out=$( { kawa-lock && echo suspended; } 2>/dev/null)
eq "$out" "" "kawa-power's 'kawa-lock && systemctl suspend' would not suspend"

case_ "a Turkish or Arabic locale: the date still in the pixel font's plain capitals"
if command -v localedef >/dev/null && [[ -e /usr/share/i18n/locales/tr_TR && -s $FONT ]]; then
  setup
  mkdir -p "$TMP/locale"
  localedef -i tr_TR -f UTF-8 "$TMP/locale/tr_TR.UTF-8" 2>/dev/null
  stub date 'exec /bin/date -d "2026-10-16 12:00" "$@"'       # a Friday: "Fri" has an i
  LOCPATH=$TMP/locale LC_ALL=tr_TR.UTF-8 kawa-lock
  eq "$(annotate_text)" "FRI 16 OCT" "not FRİ (Turkish capitals)"
  setup; stub date 'exec /bin/date -d "2026-10-16 12:00" "$@"'
  mkdir -p "$TMP/locale"; localedef -i ar_EG -f UTF-8 "$TMP/locale/ar_EG.UTF-8" 2>/dev/null
  LOCPATH=$TMP/locale LC_ALL=ar_EG.UTF-8 kawa-lock
  eq "$(annotate_text)" "FRI 16 OCT"
else
  echo "  (skipped: no localedef or tr_TR source here)"
fi

case_ "HOME with a space: the settings and picture paths arrive whole"
setup
mkdir -p "$TMP/my home"; cp -a "$HOME/." "$TMP/my home/"; export HOME="$TMP/my home"
kawa-lock --now
args_eq swaylock 1 -f -C "$HOME/.config/fedokawaii/current/swaylock" -i "$HOME/.local/share/fedokawaii/dark/lock.png"

case_ "--help shows how it is used"
setup
out=$(kawa-lock --help 2>&1); r=$?
eq "$r" 0; has "$out" "kawa-lock --now"
eq "$(locks)" 0 "--help does not lock"

# ── the idle chain (autostart.sh's swayidle line) ─────────────────────────────
# swayidle here: runs each timeout's command in order (as sh -c, which is bash on Fedora),
# then the screens' resume, then before-sleep — the order an idle hour and a suspend give
idle() {   # idle — autostart.sh's own swayidle arguments, played through
  local block
  block=$(sed -n '/^keep swayidle/,/<\/dev\/null &$/p' "$REPO/configs/home/.config/dwl/autostart.sh" | sed 's|</dev/null &$||')
  [[ -n $block ]] || { _no "no swayidle line in autostart.sh"; return; }
  keep() { "$@"; }
  swayidle() {
    local t=() c=() r=() bs="" i
    while (($#)); do
      case $1 in
        -w) shift ;;
        timeout) t+=("$2") c+=("$3"); r+=(""); shift 3
                 [[ ${1:-} == resume ]] && { r[${#r[@]} - 1]=$2; shift 2; } ;;
        before-sleep) bs=$2; shift 2 ;;
        *) _no "swayidle: unknown argument $1"; return ;;
      esac
    done
    printf '%s\n' "${t[@]}" >"$TMP/idle.times"
    for i in "${!t[@]}"; do echo "idle ${t[i]}s" >>"$CALLS"; bash -c "${c[i]}"; done
    for i in "${!t[@]}"; do [[ -n ${r[i]} ]] && { echo "resume" >>"$CALLS"; bash -c "${r[i]}"; }; done
    [[ -n $bs ]] && { echo "before-sleep" >>"$CALLS"; bash -c "$bs"; }
  }
  eval "$block"
  unset -f keep swayidle
}
case_ "away: nothing locks or sleeps — only the screens go dark after an hour; back on at a key"
setup
argv wlopm
argv notify-send
idle
eq "$(tr '\n' ' ' <"$TMP/idle.times")" "3600 " "one time: an hour"
eq "$(locks)" 1 "locked only for the sleep (below), never by itself"
not_called '^systemctl'
args_eq wlopm 1 --off '*'
args_eq wlopm 2 --on '*'
eq "$(grep -E '^(idle|resume|before|notify|swaylock|wlopm)' "$CALLS" | cut -d' ' -f1-2 | tr '\n' '|')" \
  "idle 3600s|wlopm --off|resume|wlopm --on|before-sleep|swaylock -f|" \
  "screens off, on again; before a sleep: locked at once"
case_ "a suspend while unlocked: locked at once (the bare padlock) before the machine sleeps"
setup
idle_bs=$(sed -n "s/^  before-sleep '\(.*\)' <\/dev\/null &\$/\1/p" "$REPO/configs/home/.config/dwl/autostart.sh")
eq "$idle_bs" "kawa-lock --now"
bash -c "$idle_bs"
args_eq swaylock 1 -f -C "$CONF" -i "$SHARE/dark/lock.png"

done_
