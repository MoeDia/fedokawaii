#!/usr/bin/env bash
# tools/container-trial.sh — Fedokawaii's package steps, for real, in a throw-away Fedora 44
# container, attacked in the ways a real install meets: the results in ONE file to hand on.
#
#   bash tools/container-trial.sh            (from a clone of the repository, as yourself — no sudo)
#   fedokawaii trial                         (the same, on a finished Fedokawaii desktop)
#   options: --image REF (default registry.fedoraproject.org/fedora:44) · --keep (leave the
#            container for a look: podman exec -it fedokawaii-trial bash) · --help
#
# Needs: podman (rootless), the network, ~10 GB free where podman keeps its containers, 20–40
# minutes. Touches nothing of this machine but podman's own storage and one file in the home:
#   ~/fedokawaii-trial.txt    the results: PASS/FAIL per scenario, every ✘ and warning with
#                             the lines around it, then every log in full (packages.evidence
#                             as dnf answered it too) — the one file to hand on
# Its lock and its working folder (the logs one by one) are under $XDG_RUNTIME_DIR (else
# ~/.cache/fedokawaii), and go when it ends: nothing of it is left to show in a file dialog.
# The stages (a progress line each, with its time):
#   1 podman and space · 2 the image · 3 the container: a Server-like base (the tools a Minimal
#   Install has), the repository copied in, a desktop user · 4 tools/check-packages (static) ·
#   5 setup.sh --trial: every package step for real (repositories, RPM Fusion, Brave, Claude
#   Code, COPRs, every list, the release downloads, checksummed) — boot, GPU, login and
#   display steps skipped and named · 6 tools/check-packages --live: every name, repository,
#   version, conflict, duplicate, obsolete, signature, against dnf itself · 7 the same run
#   again: idempotent — no package changes, no warnings · 8 killed mid-transaction (a power
#   cut), then resumed: it must converge · 9 a repository pointed at a 404 mirror: a clear
#   failure, then converges once it is gone · 10 stale metadata (a month-old cache) · 11 the
#   package database held by another dnf · 12 a release download refused (checksum mismatch)
#   and GitHub unreachable: refused clearly, nothing half-installed, then converges
# Exit: 0 every scenario passed · 1 one or more failed (the file says which) · 2 misuse.
# (the stages run through stage(); single-quoted code runs inside the container)
# shellcheck disable=SC2329,SC2016
set -uo pipefail
export LC_ALL=C.UTF-8
REPO=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)
IMAGE=registry.fedoraproject.org/fedora:44 KEEP=0
while (($#)); do
  case $1 in
    --image) [[ -n ${2:-} ]] || { echo "container-trial: --image REF" >&2; exit 2; }; IMAGE=$2; shift ;;
    --keep) KEEP=1 ;;
    -h|--help) sed -n '2,/^[^#]/{/^#/p}' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "container-trial: unknown option $1 — bash tools/container-trial.sh --help" >&2; exit 2 ;;
  esac; shift
done
((EUID != 0)) || { echo "container-trial: run it as yourself, not root — rootless podman keeps it all in your own storage" >&2; exit 2; }
OUT=$HOME/fedokawaii-trial.txt NAME=fedokawaii-trial
WORK=${XDG_RUNTIME_DIR:-}; [[ -n $WORK && -d $WORK && -w $WORK ]] || WORK=$HOME/.cache/fedokawaii
mkdir -p "$WORK" || exit 1
exec 8>"$WORK/fedokawaii-trial.lock"
flock -n 8 || { echo "container-trial: another trial is running ($WORK/fedokawaii-trial.lock)" >&2; exit 1; }
D=$(mktemp -d "$WORK/fedokawaii-trial.XXXXXX") || exit 1
# (what an older version left in the home: its working folder and lock)
rm -rf -- "$HOME/fedokawaii-trial.d" "$HOME/fedokawaii-trial.lock"
if [[ -t 1 ]]; then G=$'\e[32m' R=$'\e[31m' Y=$'\e[33m' DIM=$'\e[2m' Z=$'\e[0m'; else G="" R="" Y="" DIM="" Z=""; fi
START=$(date +%s) STAGES=12 N=0
RESULTS=()   # "PASS|name|time|note"
secs() { local s=$1; printf '%dm%02ds' $((s / 60)) $((s % 60)); }
# stage NAME FUNCTION — one scenario: its progress line, its time, its outcome (0 PASS · 1 FAIL · 2 SKIP)
stage() {
  local name=$1 fn=$2 t0 rc note
  N=$((N + 1)); t0=$(date +%s)
  printf '%s[%2d/%d]%s %s … ' "$DIM" "$N" "$STAGES" "$Z" "$name"
  NOTE=""; "$fn" >>"$D/trial.log" 2>&1; rc=$?; note=$NOTE
  case $rc in
    0) RESULTS+=("PASS|$name|$(secs $(($(date +%s) - t0)))|$note"); printf '%s✔%s %s%s\n' "$G" "$Z" "$(secs $(($(date +%s) - t0)))" "${note:+ — $note}" ;;
    2) RESULTS+=("SKIP|$name|-|$note"); printf '%s– skipped%s — %s\n' "$Y" "$Z" "$note" ;;
    *) RESULTS+=("FAIL|$name|$(secs $(($(date +%s) - t0)))|$note"); printf '%s✘%s %s — %s\n' "$R" "$Z" "$(secs $(($(date +%s) - t0)))" "$note" ;;
  esac
  return "$rc"
}
pm() { echo "\$ podman $*"; podman "$@"; }
# inside LOG CMD… — CMD as root in the container, its output in ~/fedokawaii-trial.d/LOG.log
inside() { local log=$1; shift; { echo "── $(date '+%H:%M:%S') $*"; } >>"$D/$log.log"; timeout 3600 podman exec -e LC_ALL=C.UTF-8 "$NAME" "$@" >>"$D/$log.log" 2>&1; }
q() { podman exec "$NAME" bash -c "$1" 2>/dev/null; }   # a question asked inside: its answer
# setup's trial run as the desktop user ran sudo: LOG [ENV=VALUE…]
trial_run() { local log=$1; shift; inside "$log" env SUDO_USER=kawa "$@" bash /root/fedokawaii/setup.sh --trial; }
marks_out() { q "rm -f /var/lib/fedokawaii/done.T*"; }   # every trial step runs again
issues() { grep -aE '✘|^ *! |dnf attempt [0-9]|attempt [0-9]+/[0-9]+ failed|warning|Error:' "$D/$1.log" | grep -v '^──' || true; }
cleanup() {
  rm -rf -- "$D"; rm -f -- "$WORK/fedokawaii-trial.lock"   # (the results are in ~/fedokawaii-trial.txt)
  ((KEEP)) && { echo "the container is kept: podman exec -it $NAME bash · podman rm -f $NAME when done"; return; }
  podman rm -f "$NAME" >/dev/null 2>&1 || true
}
trap 'cleanup' EXIT
trap 'echo; write_out; echo "stopped — the container is removed; the results so far: $OUT"; exit 130' INT TERM

s_podman() {
  command -v podman >/dev/null || { NOTE="podman is not installed — sudo dnf install podman"; return 1; }
  pm info >/dev/null || { NOTE="podman does not answer (podman info says why)"; return 1; }
  local root free
  root=$(podman info --format '{{.Store.GraphRoot}}' 2>/dev/null) || root=$HOME
  free=$(df -Pk "$root" 2>/dev/null | awk 'NR == 2 { print int($4 / 1048576) }')
  NOTE="podman $(podman --version | awk '{ print $NF }'), ${free:-?} GB free in $root"
  ((${free:-0} >= 10)) || { NOTE="$NOTE — 10 GB needed"; return 1; }
  podman container exists "$NAME" && pm rm -f "$NAME"
  return 0
}
s_image() {
  local i
  for i in 1 2 3; do pm pull "$IMAGE" && { NOTE=$(podman image inspect --format '{{.Created}}' "$IMAGE" 2>/dev/null | cut -c1-10); NOTE="image of ${NOTE:-?}"; return 0; }; sleep $((20 * i)); done
  NOTE="could not pull $IMAGE (3 tries) — the network, or the registry"; return 1
}
s_container() {
  pm run -d --name "$NAME" --hostname fedokawaii-trial -e container=podman "$IMAGE" sleep infinity || { NOTE="podman run failed"; return 1; }
  # what Fedora Server's Minimal Install has and the container image leaves out (and jq:
  # check-packages --live reads dnf's JSON with it, even when setup stopped before its base step)
  inside base dnf -y install --setopt=install_weak_deps=False shadow-utils util-linux sudo procps-ng findutils tar gzip \
    which curl gnupg2 systemd passwd hostname diffutils file jq || { NOTE="the Server-like base did not install (base.log)"; return 1; }
  pm cp "$REPO/." "$NAME:/root/fedokawaii" || { NOTE="could not copy the repository in"; return 1; }
  inside base bash -c 'rm -rf /root/fedokawaii/.git; chown -R root:root /root/fedokawaii; useradd -m -G wheel kawa' || { NOTE="no desktop user"; return 1; }
  NOTE="Fedora $(q '. /etc/os-release; echo $VERSION_ID'), $(q 'rpm -qa | wc -l') packages, user kawa"
  return 0
}
s_static() { inside static bash /root/fedokawaii/tools/check-packages; local r=$?; NOTE=$(tail -n1 "$D/static.log"); return $((r != 0)); }
s_setup() {
  trial_run setup; local r=$?
  NOTE="$(q 'rpm -qa | wc -l') packages after"
  ((r == 0)) || { NOTE="setup --trial stopped (exit $r): $(grep -a '✘' "$D/setup.log" | tail -n1)"; return 1; }
  ! grep -qa '✘' "$D/setup.log" || { NOTE="ended, but with ✘ lines (setup.log)"; return 1; }
  return 0
}
s_live() {
  inside live bash /root/fedokawaii/tools/check-packages --live --write-evidence; local r=$?
  podman cp "$NAME:/root/fedokawaii/tools/packages.evidence" "$D/packages.evidence" >/dev/null 2>&1
  NOTE=$(tail -n1 "$D/live.log"); return $((r != 0))
}
s_again() {
  local before after
  before=$(q 'rpm -qa | sort'); marks_out
  trial_run again; local r=$?
  after=$(q 'rpm -qa | sort')
  ((r == 0)) || { NOTE="the second run stopped (exit $r)"; return 1; }
  [[ $before == "$after" ]] || { NOTE="the second run changed packages: $(diff <(echo "$before") <(echo "$after") | grep '^[<>]' | head -n5 | tr '\n' ' ')"; return 1; }
  [[ -z $(issues again) ]] || { NOTE="no package changed, but warnings: $(issues again | head -n2 | tr '\n' ' ')"; return 1; }
  NOTE="zero package changes, zero warnings"
  return 0
}
# a set of applications taken out, so a run has something to install again
APPS_OUT="libreoffice-impress xournalpp openrgb qrencode"
s_killed() {
  q "dnf -y remove $APPS_OUT >/dev/null 2>&1"; marks_out
  # (in the background inside the container; killed as soon as dnf is in its transaction)
  podman exec -d -e SUDO_USER=kawa "$NAME" bash -c 'bash /root/fedokawaii/setup.sh --trial >/root/killed.log 2>&1'
  local i
  for ((i = 0; i < 600; i++)); do q 'pgrep -f "dnf -y install" >/dev/null' && q 'grep -qaE "Running transaction|Installing|\[[0-9]+/[0-9]+\]" /root/killed.log' && break; sleep 1; done
  sleep 3
  q 'pkill -KILL -f "setup.sh --trial"; pkill -KILL -x dnf5; pkill -KILL -x dnf; pkill -KILL -x rpm'
  q 'cat /root/killed.log' >>"$D/killed.log"
  echo "── killed at $(date '+%H:%M:%S') (SIGKILL: a power cut)" >>"$D/killed.log"
  trial_run killed; local r=$?
  ((r == 0)) || { NOTE="did not converge after the kill (exit $r)"; return 1; }
  local p; for p in $APPS_OUT; do q "rpm -q $p >/dev/null" || { NOTE="$p is not back"; return 1; }; done
  [[ -z $(q 'dnf -q repoquery --duplicates') ]] || { NOTE="packages installed twice after the kill: $(q 'dnf -q repoquery --duplicates' | head -n3 | tr '\n' ' ')"; return 1; }
  q 'dnf -q check >/dev/null 2>&1' || { NOTE="dnf check finds problems after the kill"; return 1; }
  NOTE="converged: every package back, no duplicates, dnf check clean"
  return 0
}
s_badmirror() {
  q "dnf -y remove qrencode >/dev/null 2>&1"; marks_out
  q 'printf "%s\n" "[zz-trial-404]" "name=a mirror that answers 404" "baseurl=https://dl.fedoraproject.org/pub/fedora/linux/no-such-tree/\$releasever/" "enabled=1" "gpgcheck=1" "skip_if_unavailable=False" >/etc/yum.repos.d/zz-trial-404.repo'
  trial_run badmirror; local r=$?
  q 'rm -f /etc/yum.repos.d/zz-trial-404.repo'
  ((r != 0)) || { NOTE="a repository that answers 404 went unnoticed"; return 1; }
  grep -qa "dnf could not install" "$D/badmirror.log" || { NOTE="it failed, but without the summary naming the package, why and the fix"; return 1; }
  trial_run badmirror; r=$?
  ((r == 0)) || { NOTE="did not converge once the bad repository was gone (exit $r)"; return 1; }
  NOTE="refused clearly ($(sed -n '/ — \(net\|other\|missing\): /{s/^ *//;p;q}' "$D/badmirror.log" | cut -c1-80)…), then converged"
  return 0
}
s_stale() {
  q "dnf -y remove qrencode >/dev/null 2>&1"; marks_out
  q 'find /var/cache/libdnf5 -type f -exec touch -d "45 days ago" {} + 2>/dev/null'
  trial_run stale; local r=$?
  ((r == 0)) || { NOTE="stopped on a month-old cache (exit $r)"; return 1; }
  NOTE="a month-old cache refreshed and used"
  return 0
}
s_locked() {
  q "dnf -y remove qrencode libreoffice-impress >/dev/null 2>&1"; marks_out
  podman exec -d "$NAME" bash -c 'dnf -y install libreoffice-impress >/root/holder.log 2>&1'
  sleep 2
  trial_run locked; local r=$?
  q 'cat /root/holder.log' >>"$D/locked.log"
  ((r == 0)) || { NOTE="did not wait out the other dnf (exit $r)"; return 1; }
  NOTE="waited for the other dnf$(grep -qa '(lock)' "$D/locked.log" && echo ', retried on the lock'), then went on"
  return 0
}
s_downloads() {
  local u=/root/fedokawaii/lib/upstream.sh r
  local sha zeros; zeros=$(printf '0%.0s' {1..64})
  sha=$(q ". $u; printf '%s\\n' \"\${UPSTREAM[@]}\" | awk -F'|' '\$1 == \"satty\" { print \$5 }'")
  [[ $sha =~ ^[0-9a-f]{64}$ ]] || { NOTE="satty's pin not found in lib/upstream.sh"; return 1; }
  q "rm -f /home/kawa/.local/bin/satty /home/kawa/.local/share/fedokawaii/upstream/satty; cp $u $u.orig; sed -i 's/$sha/$zeros/' $u"
  marks_out; trial_run downloads; r=$?
  ((r != 0)) || { NOTE="a download that does not match its pinned checksum was accepted"; q "mv $u.orig $u"; return 1; }
  q '[ ! -e /home/kawa/.local/bin/satty ]' || { NOTE="a refused download was installed anyway"; q "mv $u.orig $u"; return 1; }
  q "mv $u.orig $u"
  q 'cp /etc/hosts /root/hosts.orig; echo "0.0.0.0 github.com objects.githubusercontent.com release-assets.githubusercontent.com" >>/etc/hosts'
  marks_out; trial_run downloads; r=$?
  q 'cp /root/hosts.orig /etc/hosts'
  ((r != 0)) || { NOTE="GitHub unreachable went unnoticed"; return 1; }
  marks_out; trial_run downloads; r=$?
  ((r == 0)) || { NOTE="did not converge once the downloads worked again (exit $r)"; return 1; }
  q '[ -x /home/kawa/.local/bin/satty ]' || { NOTE="satty is not installed in the end"; return 1; }
  NOTE="a checksum mismatch and GitHub unreachable refused clearly, nothing half-installed, then converged"
  return 0
}

# write_out — the one file, from what has run so far (at the end, or when the trial is stopped)
write_out() {
pass=0 fail=0
{
  echo "FEDOKAWAII CONTAINER TRIAL — $(date '+%F %H:%M') — $(secs $(($(date +%s) - START))) — $IMAGE"
  echo "host: $(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-?}") · podman $(podman --version 2>/dev/null | awk '{ print $NF }') · repository $(git -C "$REPO" log -1 --format='%h %cs' 2>/dev/null || echo '(no git)')"
  echo
  echo "SUMMARY"
  for r in "${RESULTS[@]}"; do
    IFS='|' read -r s n t note <<<"$r"
    [[ $s == PASS ]] && pass=$((pass + 1)); [[ $s == FAIL ]] && fail=$((fail + 1))
    printf '  %-4s  %-60s %8s  %s\n' "$s" "$n" "$t" "$note"
  done
  echo "  → $pass passed, $fail failed"
  echo
  echo "EVERY ✘ AND WARNING (with the lines around it)"
  for f in "$D"/*.log; do
    [[ -f $f && ${f##*/} != trial.log ]] || continue
    m=$(grep -naE '✘|^ *! |dnf attempt [0-9]|attempt [0-9]+/[0-9]+ failed|[Ww]arning|Error:' "$f" | cut -d: -f1)
    [[ -n $m ]] || continue
    echo "── ${f##*/}"
    while IFS= read -r l; do sed -n "$((l > 3 ? l - 3 : 1)),$((l + 2))p" "$f" | sed 's/^/    /'; echo "    ·"; done <<<"$m"
  done
  echo
  echo "FULL LOGS"
  for f in "$D"/*.log; do [[ -f $f ]] || continue; echo; echo "════ ${f##*/}"; cat "$f"; done
  [[ -f $D/packages.evidence ]] && { echo; echo "════ packages.evidence (dnf's answer)"; cat "$D/packages.evidence"; }
} >"$OUT" 2>&1
}

echo "Fedokawaii container trial — $(date '+%F %H:%M') · $IMAGE · the results: $OUT"
: >"$D/trial.log"
ok=1
stage "podman and space"            s_podman  || ok=0
((ok)) && { stage "the Fedora 44 image" s_image || ok=0; }
((ok)) && { stage "the container (Server-like base, the repository, a user)" s_container || ok=0; }
if ((ok)); then
  stage "check-packages: the manifest (static)" s_static
  if stage "setup --trial: every package step, for real" s_setup; then
    stage "check-packages --live: dnf's own answer" s_live
    stage "run again: idempotent (no changes, no warnings)" s_again
    stage "killed mid-transaction (power cut), resumed"   s_killed
    stage "a repository answering 404, then gone"          s_badmirror
    stage "stale metadata (a month-old cache)"             s_stale
    stage "the package database held by another dnf"       s_locked
    stage "release downloads: checksum mismatch, GitHub unreachable" s_downloads
  else
    stage "check-packages --live: dnf's own answer" s_live
  fi
fi
# ── the one file ──────────────────────────────────────────────────────────────
write_out
echo
if ((fail == 0 && pass > 0)); then printf '%s✔ every scenario passed%s — %s (send it as it is)\n' "$G" "$Z" "$OUT"; exit 0; fi
printf '%s✘ %d scenario(s) failed%s — everything is in %s (send it as it is)\n' "$R" "$fail" "$Z" "$OUT"; exit 1
