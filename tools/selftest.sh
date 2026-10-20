#!/usr/bin/env bash
# tools/selftest.sh — the installer checked on this machine, changing nothing (fedokawaii selftest).
#
#   sudo bash /usr/local/lib/fedokawaii/tools/selftest.sh [--sandbox]
#
#   · the settings: every value of fedokawaii.conf valid
#   · the toolkit: every script parses (bash -n), and ShellCheck has no warning (when installed)
#   · setup's own records: phase, user, GPU, the step markers, no resume unit after the build
#   · the last run's log: no ✘, no retry, no warning since the last setup, update or repair began
#   · packages: nothing dnf could not install, the manifest audit (tools/check-packages), and a
#     second run would change nothing (dnf --assumeno, from the cache: no download)
#   · configs: what theme would replace (theme.sh --check)
#   --sandbox  also the installer's torture suite, in a fake machine of its own (the clone's
#              tests/installer/test_torture.sh, run as you: nothing of this machine is touched)
# Exit: 0 all clean · 3 something needs you (each ✘ and ! says what) · 2 misuse.
set -uo pipefail
export LC_ALL=C.UTF-8
SANDBOX=0
case ${1:-} in "") ;; --sandbox) SANDBOX=1 ;; -h|--help) sed -n '2,/^[^#]/{/^#/p}' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  *) echo "selftest: unknown option $1 — --sandbox or --help" >&2; exit 2 ;; esac
((EUID == 0)) || exec sudo bash "$0" "$@"
TK=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)
STATE_DIR=/var/lib/fedokawaii LOG=/var/log/fedokawaii.log LOG_FILE=/dev/null
# shellcheck source-path=SCRIPTDIR/..
# shellcheck source=lib/common.sh
. "$TK/lib/common.sh"
U=$(head -n1 "$STATE_DIR/user" 2>/dev/null | tr -d '[:space:]') || U=""
T0=$SECONDS
hdr "Fedokawaii selftest — the installer on this machine (nothing is changed)"

section "the settings"
p=$(conf_problems "$TK/fedokawaii.conf")
if [[ -z $p ]]; then pass "fedokawaii.conf: every value valid"; else while IFS= read -r l; do fail "fedokawaii.conf" "$l"; done <<<"$p"; fi
read_conf "$TK/fedokawaii.conf"

section "the toolkit's scripts"
bad=()
for f in "$TK"/setup.sh "$TK"/theme.sh "$TK"/verify.sh "$TK"/check.sh "$TK"/fedokawaii.sh "$TK"/lib/*.sh "$TK"/system/fedokawaii "$TK"/system/fedokawaii-report "$TK"/tools/*.sh "$TK"/tools/check-packages; do
  [[ -f $f ]] || continue; bash -n "$f" 2>/dev/null || bad+=("${f#"$TK/"}")
done
if ((${#bad[@]})); then fail "scripts that do not parse" "${bad[*]} — fedokawaii repair puts the toolkit back"; else pass "every script parses"; fi
if command -v shellcheck >/dev/null; then
  n=$(cd "$TK" && shellcheck -S warning -x -f gcc setup.sh theme.sh verify.sh check.sh fedokawaii.sh lib/*.sh tools/*.sh 2>/dev/null | grep -c ':' || true)
  ((n == 0)) && pass "ShellCheck: no warning" || warn "ShellCheck: $n warning(s)" "cd $TK && shellcheck -S warning -x setup.sh lib/*.sh — send them"
else info "ShellCheck is not installed (dnf install ShellCheck): its look at the scripts skipped"; fi

section "setup's own records"
ph=$(cat "$STATE_DIR/phase" 2>/dev/null) || ph=""
case $ph in done) pass "the build is done" ;; 1|2|3) warn "the build is at phase $ph" "setup carries on: sudo bash $TK/setup.sh" ;; *) fail "phase record '$ph'" "sudo bash $TK/setup.sh --status" ;; esac
if [[ -n $U ]] && getent passwd "$U" >/dev/null; then pass "the desktop user: $U"; else fail "the user record names '$U'" "no such user — write the desktop user's name in $STATE_DIR/user"; fi
g=$(cat "$STATE_DIR/gpu" 2>/dev/null) || g=""
[[ $g == @(amd|intel) ]] && pass "built for the $g GPU" || fail "GPU record '$g'" "fedokawaii repair"
compgen -G "$STATE_DIR/done.T*" >/dev/null && fail "the container trial's records are here" "rm $STATE_DIR/done.T* — they belong in a container"
[[ $ph == "done" && -e /etc/systemd/system/fedokawaii-resume.service ]] && fail "the resume unit is still installed after the build" "fedokawaii repair"
if [[ $ph == "done" ]]; then
  miss=()
  while IFS='|' read -r name _; do compgen -G "$STATE_DIR/done.${name%% *} *" >/dev/null || miss+=("$name"); done \
    < <(grep -E '^ *step "[0-9]' "$TK/setup.sh" | sed -E 's/^ *step "([^"]*)" +([a-z_0-9]+).*/\1|\2/')
  ((${#miss[@]} == 0)) && pass "every setup step has its marker" || warn "steps with no marker: ${miss[*]}" "steps a later version added: update and repair do their work"
fi

section "the last run"
if [[ -r $LOG ]]; then
  n=$(grep -anE '── Fedokawaii (setup|update|repair|theme|apply)' "$LOG" | tail -n1 | cut -d: -f1)
  if [[ -n $n ]]; then
    o=$(tail -n +"$n" "$LOG" | sed 's/\x1b\[[0-9;]*m//g')
    info "$(head -n1 <<<"$o" | sed 's/^── //')"
    b=$(grep -aE '✘|dnf attempt [0-9]|attempt [0-9]+/[0-9]+ failed|^ *! ' <<<"$o" | tail -n 8)
    if [[ -z $b ]]; then pass "no ✘, no retry, no warning in it"; else warn "the last run logged:" "fedokawaii log shows it whole"; while IFS= read -r l; do info "  $l"; done <<<"$b"; fi
  else info "no run in the log yet"; fi
else fail "no log at $LOG"; fi

section "packages"
if [[ -s $STATE_DIR/dnf-failed ]]; then while IFS='|' read -r pk why; do fail "$pk did not install ($why)" "$(dnf_fix "$why" "$pk")"; done <"$STATE_DIR/dnf-failed"
else pass "nothing dnf could not install"; fi
if o=$(bash "$TK/tools/check-packages" 2>&1); then pass "the manifest audit (tools/check-packages)"; else fail "the manifest audit" "$(grep '✘' <<<"$o" | head -n 3 | tr '\n' ' ')"; fi
if [[ $ph == "done" && $g == @(amd|intel) ]]; then
  # shellcheck source=lib/manifest.sh
  . "$TK/lib/manifest.sh"
  mapfile -t m < <(manifest_all "$g")
  o=$(dnf -q install --assumeno --cacheonly "${m[@]}" 2>&1)
  if grep -qiE '^ *(Installing|Upgrading|Downgrading|Replacing)|No match|Problem' <<<"$o"; then
    warn "a second run would change packages" "fedokawaii repair"; grep -iE '^ *(Installing|Upgrading|Downgrading|Replacing)|No match|Problem' <<<"$o" | head -n 6 | while IFS= read -r l; do info "  $l"; done
  else pass "a second run would change no package (${#m[@]} in the manifest)"; fi
fi

section "configs"
if [[ -n $U && $ph == "done" ]]; then
  o=$(bash "$TK/theme.sh" --user "$U" --check 2>&1); r=$?
  case $r in 0) pass "every config is the toolkit's" ;; 4) pass "every config is the toolkit's (but for an optional part)" ;;
    *) warn "configs differ from the toolkit's" "fedokawaii drift lists them; fedokawaii theme puts them back (each kept in a backup)" ;; esac
fi

if ((SANDBOX)); then
  section "the torture suite (a fake machine; nothing of this one is touched)"
  h=$(getent passwd "$U" | cut -d: -f6)
  t=$h/repos/fedokawaii/tests/installer/test_torture.sh
  if [[ -f $t ]]; then
    o=$(runuser -u "$U" -- bash "$t" 2>&1); r=$?
    tail -n 3 <<<"$o" | while IFS= read -r l; do info "$l"; done
    ((r == 0)) && pass "the torture suite passed" || fail "the torture suite" "its lines above; the whole: bash $t"
  else warn "no clone with the tests at ~/repos/fedokawaii" "fedokawaii copy makes one"; fi
fi

section "result · $(took "$T0")"
summary "selftest" || exit 3
