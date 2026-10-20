#!/usr/bin/env bash
# tests/installer/test_torture.sh — the installer attacked as a fresh Fedora 44 install meets it,
# in the fake machine (tests/installer/lib.sh). Every warning, ✘ or shell error is a failure.
#
#   the parts, no machine: every fedokawaii.conf key fuzzed (empty, spaces, unicode, a command,
#     a number past bash's arithmetic) — refused by name or valid, never a shell error · dnf's
#     failure kinds told apart · tools/check-packages (static, and --live against a stand-in
#     dnf: a missing name, a rename, two packages bringing one command) · the container trial
#     against a stand-in podman: its stages, its one results file, the container removed,
#     nothing of the home touched but ~/fedokawaii-trial*
#   the fake machine:
#     · a fresh phase 1 and 2: rc 0, the summary says 0 ✘ 0 warnings; phase 1 run again from
#       its start: no package changed, no warning
#     · cut off at points spread over phase 1 — SIGKILL (a power cut) and SIGINT — then run
#       again: it converges to the very packages an uncut run has
#     · no network, then the network back; mirrors failing (404, metalink, a partial file, a
#       checksum, the rpm lock held) a few times: retried, converged, the summary counts them
#     · what no retry mends — a renamed package, a clash, a full disk — said with the package,
#       why and the fix; the rest of the batch still in
#     · a bad fedokawaii.conf: refused before anything changes; not root; root with no user
#     · two runs at once: the second refused at once, plainly
#     · --dry-run: what would change, nothing changed; ACTION --help; misuse
#     · hardware: no GPU, NVIDIA, two monitors, a 2160p one — check.sh speaks, no shell error
#     · an Arabic locale around it all
#     · a finished install: a home whose path has spaces, your own dotfiles kept in a backup
#       before theme replaces them; theme twice: the second changes nothing; repair after a
#       partial loss (packages and a release tool gone): back
. "$(dirname "$0")/lib.sh"
CLONE=/home/fkuser/fedokawaii
TK=/usr/local/lib/fedokawaii
setup() { fkrun bash "$CLONE/setup.sh" --no-reboot; }
marks() { compgen -G "$W/var/lib/fedokawaii/done.*" | wc -l; }
# shell_errors TEXT — what bash says when a script is wrong, never what a script says itself
shell_errors() { grep -E 'unbound variable|syntax error|command not found|bad substitution|integer expression expected|No such file or directory$|ambiguous redirect|division by 0|value too great' <<<"$1" | grep -v '^\$ ' || true; }
clean_run() {   # clean_run WHAT — the last fkrun ended 0, with no ✘, no warning, no shell error
  eq "$RC" 0 "$1: exit $RC — $(grep -E '✘' <<<"$OUT" | head -n 3)"
  lacks "$OUT" "✘" "$1: a ✘ line"
  eq "$(shell_errors "$OUT")" "" "$1: a shell error"
  eq "$(grep -E '^ *! ' <<<"$OUT" | head -n 3)" "" "$1: a warning"
}

# ══ the parts, no fake machine ════════════════════════════════════════════════════════
lib() { OUT=$(LOG_FILE=/dev/null STATE_DIR=$TMP/state bash -c '. "$1/lib/common.sh"; eval "$2"' _ "$REPO" "$1" 2>&1); RC=$?; }
sandbox
case_ "every fedokawaii.conf key fuzzed: refused by its name, or valid — never a shell error, never a number that wraps"
mapfile -t KEYS < <(sed -n 's/^\([A-Z_]*\)=.*/\1/p' "$REPO/fedokawaii.conf")
eq "${#KEYS[@]}" 21 "the keys of fedokawaii.conf"
FUZZ=("" " " "a b" "日本語" "مدينة" '$(touch /tmp/fk-pwned)' '`id`' 'x;rm -rf /' "../../etc/passwd" "-1" "0" \
      "18446744073709551760" "99999999999999999999999" "$(printf 'x%.0s' {1..3000})" $'tab\there' "yes " "AMD" "v0.9 " "\\")
STRICT=" GPU STEAM SSH_SERVER THEME WALLPAPER_PACK BOOT_MENU_SECONDS MONITOR_HZ DNF_PARALLEL TIMEZONE NIGHT_LIGHT KB_LAYOUTS KB_TOGGLE BACKUP_REMIND_DAYS DWL_TAG DWL_COMMIT DWL_WLROOTS TFC_TAG TFC_COMMIT "
n=0 bad=0
for k in "${KEYS[@]}"; do
  for v in "${FUZZ[@]}"; do
    n=$((n + 1)); f=$TMP/fuzz.conf
    grep -v "^$k=" "$REPO/fedokawaii.conf" >"$f"; printf '%s="%s"\n' "$k" "${v//\"/}" >>"$f"
    lib "conf_problems '$f'"
    [[ -e /tmp/fk-pwned ]] && { _no "$k='$v' ran a command"; rm -f /tmp/fk-pwned; bad=1; }
    [[ -z $(shell_errors "$OUT") ]] || { _no "$k='${v:0:20}': $(shell_errors "$OUT" | head -n1)"; bad=1; }
    if [[ -n $OUT ]]; then grep -q "$k" <<<"$OUT" || { _no "$k='${v:0:20}' refused without naming $k: ${OUT:0:120}"; bad=1; }
    elif [[ $STRICT == *" $k "* && $v != "0" && $v != "-1" ]] || [[ $v =~ ^[0-9]{18,}$ && $k == @(MONITOR_HZ|DNF_PARALLEL|BACKUP_REMIND_DAYS|BOOT_MENU_SECONDS) ]]; then
      _no "$k='${v:0:24}' accepted"; bad=1
    fi
  done
done
((bad)) || _ok
case_ "…the strict keys take the edge values they should: 0 days, the 0 boot-menu seconds"
grep -v '^BOOT_MENU_SECONDS=' "$REPO/fedokawaii.conf" >"$TMP/e.conf"; echo 'BOOT_MENU_SECONDS="0"' >>"$TMP/e.conf"
lib "conf_problems '$TMP/e.conf'"; eq "$OUT" ""
grep -v '^MONITOR_HZ=' "$REPO/fedokawaii.conf" >"$TMP/e.conf"; echo 'MONITOR_HZ="540"' >>"$TMP/e.conf"
lib "conf_problems '$TMP/e.conf'"; eq "$OUT" ""
grep -v '^MONITOR_HZ=' "$REPO/fedokawaii.conf" >"$TMP/e.conf"; echo 'MONITOR_HZ="541"' >>"$TMP/e.conf"
lib "conf_problems '$TMP/e.conf'"; has "$OUT" "MONITOR_HZ must be a number 30–540"

case_ "dnf's words → the kind of failure (dnf5's own messages)"
for m in "No match for argument: foo|missing" "Error: Unable to find a match: foo|missing" \
         "Librepo error: Status code: 404 for https://x/y.rpm|net" "Curl error (28): Timeout was reached|net" \
         "Failed to download metadata (metalink: \"https://mirrors\") for repository \"fedora\"|net" \
         "Interrupted by header callback: Downloading successful, but checksum doesn't match|checksum" \
         "Failed to obtain rpm transaction lock. Another transaction is in progress.|lock" \
         "Transaction failed: Signature verification failed. OpenPGP check for package x has failed|gpg" \
         "Error: not enough free space: 512 MB more space needed on /|disk" \
         " Problem: file /usr/bin/x from install of a-1 conflicts with file from package b-1|conflict" \
         "something else entirely|other"; do
  OUT=$(LOG_FILE=/dev/null bash -c '. "$1/lib/common.sh"; dnf_why "$2"' _ "$REPO" "${m%|*}" 2>&1); eq "$OUT" "${m#*|}" "${m%|*}"
done

case_ "tools/check-packages: the manifest clean as it is; a name twice, wanted and forbidden, with no evidence — each said"
o=$(bash "$REPO/tools/check-packages" 2>&1); eq "$?" 0 "$o"; has "$o" "✔ clean"
mkdir -p "$TMP/cp/lib" "$TMP/cp/tools"; cp "$REPO/lib/manifest.sh" "$REPO/lib/upstream.sh" "$TMP/cp/lib/"; cp "$REPO/tools/check-packages" "$REPO/tools/packages.evidence" "$TMP/cp/tools/"
sed -i 's/^  gh  /  gh firefox kitty-nonexistent btop /' "$TMP/cp/lib/manifest.sh"
o=$(bash "$TMP/cp/tools/check-packages" 2>&1); eq "$?" 1
has "$o" "btop is in two lists"; has "$o" "firefox is wanted and forbidden at once"; has "$o" "no evidence for"; has "$o" "kitty-nonexistent"
case_ "tools/check-packages --live against dnf: a name gone, a rename, a command from two packages, a repository unsigned"
cp "$REPO/lib/manifest.sh" "$TMP/cp/lib/"
stub rpm 'exit 1'
cat >"$STUBS/dnf" <<'EOF'
#!/bin/bash
a=" $* "
case $a in
  *" repo list "*) printf 'repo id repo name\nfedora Fedora\nupdates Updates\nrpmfusion-free x\nrpmfusion-nonfree x\nbrave-browser x\nclaude-code x\ncopr:copr.fedorainfracloud.org:ilyaz:LACT x\ncopr:copr.fedorainfracloud.org:zzahkaboom24:grub-btrfs x\n' ;;
  *" repo info "*) [[ $a == *brave-browser* ]] && echo "PGP check : no" || echo "PGP check : yes" ;;
  *" --whatprovides "*) [[ ${*: -1} == wiremix ]] && echo wiremix-ng ;;
  *" --whatobsoletes "*) ;;
  *" --files "*) case ${*: -1} in fd-find) echo /usr/bin/fd ;; fzf) printf '/usr/bin/fzf\n/usr/bin/fd\n' ;; esac ;;
  *" repoquery "*) for n; do [[ $n == -* || $n == repoquery || $n == *%* ]] && continue
                    case $n in wiremix|gdu) ;; ffmpeg|mesa-va-drivers-freeworld|libheif-freeworld) echo "$n|1.0-1|rpmfusion-free|$n" ;;
                      steam) echo "$n|1.0-1|rpmfusion-nonfree|$n" ;; brave-origin) echo "$n|1.0-1|brave-browser|$n" ;; claude-code) echo "$n|1.0-1|claude-code|$n" ;;
                      lact) echo "lact|0.10.1-1|copr:copr.fedorainfracloud.org:ilyaz:LACT|lact" ;; grub-btrfs) echo "grub-btrfs|4.14-1|copr:copr.fedorainfracloud.org:zzahkaboom24:grub-btrfs|grub-btrfs" ;;
                      *) echo "$n|1.0-1.fc44|fedora|$n" ;; esac; done ;;
esac
exit 0
EOF
chmod 755 "$STUBS/dnf"
o=$(bash "$TMP/cp/tools/check-packages" --live 2>&1); eq "$?" 1
has "$o" "not in any enabled repository: gdu (fedora)"; has "$o" "renamed?): wiremix → wiremix-ng"
has "$o" "the same command from two packages: /usr/bin/fd: fd-find and fzf"
has "$o" "brave-browser: enabled without a signature check"; has "$o" "rpmfusion-free: enabled, packages signature-checked"
if ((EUID == 0)); then has "$o" "all of them resolve together in one transaction"; else has "$o" "one-transaction check skipped: it needs root" "as a user: said, not faked"; fi
rm -f "$STUBS/dnf" "$STUBS/rpm"

case_ "the container trial (tools/container-trial.sh) against a stand-in podman: every stage, one results file, the container gone, nothing else in the home"
# (as a user, as it is meant to run — rootless podman; root is refused)
CT=$TMP/ct; mkdir -p "$CT/home"; chmod 755 "$TMP" "$STUBS"; chmod 666 "$CALLS"
cat >"$STUBS/podman" <<'EOF'
#!/bin/bash
echo "podman $*" >>"$CT/podman.log"
case $1 in
  --version) echo "podman version 5.6.0" ;;
  info) [[ ${2:-} == --format ]] && echo "$CT" || echo "host: ok" ;;
  container) exit 1 ;;   # (exists: no)
  pull|run|cp|rm) ;;
  image) echo 2026-10-01T00:00:00 ;;
  exec)
    shift; while [[ $1 == -* ]]; do [[ $1 == -e ]] && shift; shift; done; shift   # (its options, then the container's name)
    c="$*"
    case $c in
      *"rpm -qa | sort"*) printf 'bash\nqrencode\n' ;;
      *"rpm -qa | wc -l"*) echo 812 ;;
      *os-release*) echo 44 ;;
      *"bash /root/fedokawaii/setup.sh --trial"*)
        n=$(cat "$CT/trialruns" 2>/dev/null || echo 0); echo $((n + 1)) >"$CT/trialruns"
        echo "── Fedokawaii container trial · Fedora 44 · kawa"; echo "✔ T1 dnf5 tuning · 2s"
        case $((n + 1)) in
          # (1 setup · 2 again · 3 the one killed · 4 after it · 5 the 404 mirror · 6 without it · 7 stale ·
          #  8 locked · 9 a checksum refused · 10 GitHub unreachable · 11 the downloads again)
          5) echo "✘ dnf could not install 1 of 1 package(s):"; echo "    qrencode — net: the network or the mirrors failed every try"; exit 1 ;;
          9) echo "✘ satty: checksum mismatch"; exit 1 ;; 10) echo "✘ could not fetch satty"; exit 1 ;;
        esac
        echo "── container trial: every package step done · 9m" ;;
      *check-packages*--live*) echo "✔ clean — 9 passed, 0 warning(s)" ;;
      *check-packages*) echo "✔ clean — 4 passed, 0 warning(s)" ;;
      *"printf '%s\\n'"*UPSTREAM*|*'${UPSTREAM[@]}'*) printf '%064d\n' 7 | tr 0 a ;;
      *pgrep*|*grep\ -qaE*) exit 0 ;;
      *"rpm -q "*) exit 0 ;;
      *"[ ! -e "*) exit 0 ;;
      *"[ -x "*) exit 0 ;;
      *repoquery\ --duplicates*) ;;
      *) ;;
    esac ;;
esac
exit 0
EOF
chmod 755 "$STUBS/podman"; stub sleep; stub flock
stub df 'echo "Filesystem 1024-blocks Used Available Capacity Mounted"; echo "x 1 1 99999999 1% /"'
mkdir -p "$CT/repo/tools"; cp "$REPO/tools/container-trial.sh" "$CT/repo/tools/"   # (where a user can read it)
chown -R 31000:31000 "$CT"
asme() { setpriv --reuid=31000 --regid=31000 --clear-groups env HOME="$CT/home" CT="$CT" PATH="$PATH" TMP="$TMP" "$@"; }
o=$(asme bash "$CT/repo/tools/container-trial.sh" 2>&1); r=$?
o2=$(HOME=$CT/home bash "$REPO/tools/container-trial.sh" 2>&1); eq "$?" 2 "root refused"; has "$o2" "run it as yourself, not root"
eq "$r" 0 "$o"
for s in "podman and space" "the Fedora 44 image" "the container (Server-like base" "check-packages: the manifest" "setup --trial: every package step" \
         "check-packages --live" "run again: idempotent" "killed mid-transaction" "a repository answering 404" "stale metadata" "held by another dnf" "release downloads"; do
  has "$o" "$s"
done
has "$o" "✔ every scenario passed"
R=$CT/home/fedokawaii-trial.txt
[[ -f $R ]] && _ok || _no "no results file"
has "$(head -n 20 "$R")" "SUMMARY"; has "$(cat "$R")" "PASS  podman and space"; has "$(cat "$R")" "EVERY ✘ AND WARNING"; has "$(cat "$R")" "FULL LOGS"
has "$(cat "$R")" "qrencode — net" "the 404 run's ✘, with its context, in the file"
grep -q 'podman rm -f fedokawaii-trial' "$CT/podman.log" && _ok || _no "the container was not removed"
eq "$(ls -A "$CT/home" | tr '\n' ' ')" "fedokawaii-trial.d fedokawaii-trial.lock fedokawaii-trial.txt " "only ~/fedokawaii-trial* in the home"
o=$(asme bash "$CT/repo/tools/container-trial.sh" --bogus 2>&1); eq "$?" 2; has "$o" "unknown option --bogus"
rm -f "$STUBS/podman" "$STUBS/sleep" "$STUBS/flock" "$STUBS/df"

# ══ the fake machine ═════════════════════════════════════════════════════════════════
world fresh; releases
keep fresh
installed_now() { sort "$FKH/installed"; }
FRESH=$(installed_now)

case_ "a fresh phase 1, then phase 2: clean, each step timed, a summary with no ✘ and no warning"
setup; clean_run "phase 1"
has "$OUT" "── phase 1 of 3 done · "; has "$OUT" "step(s) done · 0 retried · 0 warning(s) · 0 failed · log: /var/log/fedokawaii.log"
grep -qE '✔ 1\.5 base packages · [0-9]+s' <<<"$OUT" && _ok || _no "no time on a step's line"
eq "$(state phase)" 2
P1=$(installed_now); keep p1
setup; clean_run "phase 2"; eq "$(state phase)" 3; has "$OUT" "── phase 2 of 3 done · "
case_ "phase 1 run again from its start (its markers gone): no package changes, no warning"
back p1; rm -f "$W"/var/lib/fedokawaii/done.1.*; echo 1 >"$W/var/lib/fedokawaii/phase"
: >"$CALLS"; setup; clean_run "phase 1 again"
eq "$(installed_now)" "$P1" "the second run changed packages"
case_ "…and a phase whose steps are all done: every step skipped, dnf never asked to install"
back p1; setup >/dev/null; echo 2 >"$W/var/lib/fedokawaii/phase"; : >"$CALLS"
setup; eq "$RC" 0; eq "$(grep -c 'skip (done): 2\.' <<<"$OUT")" 4; not_called 'dnf\] .*install'

case_ "cut off anywhere in phase 1 — a power cut (SIGKILL) or Ctrl+C (SIGINT) — then run again: the same packages as an uncut run"
back fresh; : >"$CALLS"; setup >/dev/null; total=$(grep -c . "$CALLS")
((total > 20)) && _ok || _no "phase 1 made only $total stub calls"
for sig in KILL INT; do
  for at in 3 $((total / 2)) $((total - 4)); do
    back fresh; rm -f "$FKH/cut-count"; echo "$at" >"$FKH/cut-at"; echo "$sig" >"$FKH/cut-sig"; chmod 666 "$FKH"/cut-*
    setup; first=$RC
    ((first != 0)) || [[ -f $FKH/cut-at ]] || _no "SIG$sig at call $at: the run was not stopped"
    [[ $sig == INT ]] && ((first == 130)) && has "$OUT" "interrupted — run the same command again to continue"
    rm -f "$FKH/cut-at"; setup
    eq "$RC" 0 "SIG$sig at call $at ($(cat "$FKH/cut.log" 2>/dev/null | tail -n1)): the run after it — $(grep '✘' <<<"$OUT" | head -n2)"
    eq "$(state phase)" 2 "SIG$sig at call $at: phase 1 not finished"
    eq "$(installed_now)" "$P1" "SIG$sig at call $at: other packages than an uncut run"
    eq "$(shell_errors "$OUT")" "" "SIG$sig at call $at: a shell error on the way back"
  done
done
rm -f "$FKH"/cut-*

case_ "no network: said plainly before anything is installed; the network back: it goes on"
back fresh; fkh net off; setup; eq "$RC" 1; has "$OUT" "this machine is not ready"; has "$(sed -n '/^network/,/^$/p' <<<"$OUT")" "✘" "the readiness check names the network"
eq "$(installed_now)" "$FRESH" "packages changed without a network"
back fresh; fkh net off; setup >/dev/null; fkh net on; setup; clean_run "after the network came back"
case_ "mirrors failing in a row (a 404, a damaged download, the rpm lock held; metalink and a partial file: test_common): retried with fresh metadata, converged, counted"
back fresh; fkh fail-dnf-404 1; fkh fail-dnf-checksum 1; fkh fail-dnf-lock 1   # (three in a row: the fourth try gets through)
setup; eq "$RC" 0 "$(grep '✘' <<<"$OUT" | head -n2)"; eq "$(state phase)" 2
for k in net checksum lock; do has "$OUT" "failed ($k) — again in"; done
called 'dnf\] -y install .* --refresh$'
eq "$(installed_now)" "$P1" "other packages than a clean run"
has "$OUT" "── phase 1 of 3 done"; has "$OUT" " retried · 0 warning(s) · 0 failed"; lacks "$OUT" "· 0 retried" "the retries not counted"

case_ "what no retry mends, said with the package, why and the fix: a renamed package (the rest still in)"
back fresh; fkh_del available bash-completion
setup; eq "$RC" 1; has "$OUT" "✘ dnf could not install 1 of"; has "$OUT" "bash-completion — missing: no enabled repository has 'bash-completion'"
lacks "$OUT" "dnf attempt" "never tried again"
pkg_has neovim && pkg_has tuned && _ok || _no "the rest of the batch was not installed"
has "$(state dnf-failed)" "bash-completion|missing" "kept for the report"
fkh_add available bash-completion; setup; clean_run "once it is there again"; eq "$(state dnf-failed)" "" "the record cleared"
case_ "…a clash between two packages"
back fresh; fkh clash "neovim vim-minimal"
setup; eq "$RC" 1; has "$OUT" "neovim — conflict: it clashes with another package"
case_ "…a full disk: at once, the fix said"
back fresh; fkh disk-full 1
setup; eq "$RC" 1; has "$OUT" "the disk is full — df -h /"; lacks "$OUT" "dnf attempt"
case_ "…a repository's key that does not match, every time: tried with fresh metadata, then named"
back fresh; fkh fail-dnf-gpg 99
setup; eq "$RC" 1; has "$OUT" "dnf attempt 3/4 failed (gpg)"; has "$OUT" "gpg: a repository's signing key does not match its packages"
rm -f "$FKH/fail-dnf-gpg"

case_ "a bad fedokawaii.conf: refused before anything changes, each problem named"
back fresh; sed -i 's/^MONITOR_HZ=.*/MONITOR_HZ="18446744073709551760"/; s/^GPU=.*/GPU="radeon"/' "$W$CLONE/fedokawaii.conf"
: >"$CALLS"; setup; eq "$RC" 1; has "$OUT" "MONITOR_HZ must be a number 30–540"; has "$OUT" "GPU must be auto, amd or intel"
not_called 'dnf\]'; eq "$(marks)" 0 "a step ran"
case_ "not root: refused (2); root with no desktop user to name: refused, said why"
back fresh
fkrun runuser -u fkuser -- bash "$CLONE/setup.sh"; eq "$RC" 2; has "$OUT" "run with sudo"
fkrun env -u SUDO_USER bash "$CLONE/setup.sh" --no-reboot; eq "$RC" 1; has "$OUT" "cannot tell who the desktop user is"
fkrun runuser -u fkuser -- bash "$CLONE/fedokawaii.sh" setup; eq "$RC" 2; has "$OUT" "run with sudo"

case_ "two runs at once: the second refused within seconds, plainly"
back fresh
( fk flock /var/lib/fedokawaii/lock /usr/bin/sleep 25 >/dev/null 2>&1 & ); sleep 3   # (the real sleep: the fake machine's own returns at once)
t=$SECONDS; setup; eq "$RC" 1; has "$OUT" "another Fedokawaii run"; ((SECONDS - t < 20)) && _ok || _no "it waited $((SECONDS - t))s"
sleep 25

case_ "--dry-run setup: the steps and packages still to come — and nothing changed"
back fresh; : >"$CALLS"
fkrun bash "$CLONE/fedokawaii.sh" --dry-run setup; eq "$RC" 0 "$OUT"
has "$OUT" "nothing is changed"; has "$OUT" "would run: 1.5 base packages (s_base)"; has "$OUT" "would install"; has "$OUT" "neovim"
not_called 'dnf\] .*(install|remove|upgrade)'; not_called 'systemctl\] (enable|mask|disable)'
eq "$(marks)" 0 "a step ran"
fkrun bash "$CLONE/fedokawaii.sh" --dry-run bogus; eq "$RC" 2
case_ "each action's help; misuse said with the way out"
fkrun bash "$CLONE/fedokawaii.sh" repair --help; eq "$RC" 0; has "$OUT" "find what broke and fix it"
fkrun bash "$CLONE/fedokawaii.sh" frobnicate; eq "$RC" 2; has "$OUT" "unknown action: frobnicate"
fkrun bash "$CLONE/setup.sh" --bogus; eq "$RC" 2; has "$OUT" "unknown option: --bogus"
fkrun bash "$CLONE/setup.sh" --trial; eq "$RC" 1; has "$OUT" "--trial runs only inside the container trial's container" "never half a setup on a real machine"

case_ "hardware it may meet — no GPU, NVIDIA, two monitors, a 2160p one: check.sh says so, no shell error"
for hw in nogpu nvidia twomon uhd; do
  back fresh
  case $hw in
    nogpu) hw_nogpu ;; nvidia) hw_nvidia ;;
    twomon) mkdir -p "$W/sys/class/drm/card0-HDMI-A-1"; ln -sfn ../card0 "$W/sys/class/drm/card0-HDMI-A-1/device"; echo connected >"$W/sys/class/drm/card0-HDMI-A-1/status"; printf '1920x1080\n' >"$W/sys/class/drm/card0-HDMI-A-1/modes" ;;
    uhd) printf '3840x2160\n2560x1440\n' >"$W/sys/class/drm/card0-DP-1/modes" ;;
  esac
  fkrun bash "$CLONE/check.sh"
  eq "$(shell_errors "$OUT")" "" "$hw: a shell error"
  case $hw in nogpu|nvidia) ((RC != 0)) && _ok || _no "$hw: check.sh passed a machine setup cannot build for" ;; *) eq "$RC" 0 "$hw: $(grep '✘' <<<"$OUT" | head -n2)" ;; esac
done

case_ "an Arabic locale around it: the same checks, the same words, no shell error"
back fresh
fkrun env LANG=ar_AE.UTF-8 LC_ALL=ar_AE.UTF-8 LANGUAGE=ar bash "$CLONE/check.sh"; eq "$(shell_errors "$OUT")" ""; has "$OUT" "READY"
fkrun env LANG=ar_AE.UTF-8 LC_ALL=ar_AE.UTF-8 bash "$CLONE/fedokawaii.sh" --dry-run setup; eq "$RC" 0; eq "$(shell_errors "$OUT")" ""
sed -i 's/^WEATHER_CITY=.*/WEATHER_CITY="الشارقة"/' "$W$CLONE/fedokawaii.conf"
fkrun env LANG=C LC_ALL=C bash "$CLONE/fedokawaii.sh" conf; eq "$RC" 0 "an Arabic city in a C locale: $OUT"

# ══ a finished install ════════════════════════════════════════════════════════════════
case_ "a home whose path has spaces, your own dotfiles there before: theme keeps them in a backup, then a second theme changes nothing"
world built
mv "$W/home/fkuser" "$W/home/Fk User"; sed -i 's|^fkuser:\(.*\):/home/fkuser:|fkuser:\1:/home/Fk User:|' "$W/etc/passwd"
H="$W/home/Fk User"; mkdir -p "$H/.config/foot"; printf '# mine\n[main]\nfont=monospace:size=9\n' >"$H/.config/foot/foot.ini"
fk chown -R fkuser:fkuser "/home/Fk User"
fkrun bash "$TK/theme.sh" --user fkuser; clean_run "theme in a home with spaces"
b=$(grep -rl '^# mine' "$H/.local/state/fedokawaii/backup" 2>/dev/null | head -n1)
[[ -n $b ]] && _ok || _no "your foot.ini was not kept in a backup"
lacks "$(cat "$H/.config/foot/foot.ini")" "# mine" "the toolkit's foot.ini is in place"
fkrun bash "$TK/theme.sh" --user fkuser --check; [[ $RC == [04] ]] && _ok || _no "after theme, configs still differ ($RC): $(tail -n 5 <<<"$OUT")"
n=$(ls "$H/.local/state/fedokawaii/backup" | wc -l)
fkrun bash "$TK/theme.sh" --user fkuser; clean_run "theme again"
eq "$(ls "$H/.local/state/fedokawaii/backup" | wc -l)" "$n" "the second theme replaced something (a new backup)"

case_ "repair after a partial loss — packages gone, a release tool gone: back, and the second repair finds nothing"
world built --themed; releases
fkh_del installed btop ripgrep; rm -f "$W/home/fkuser/.local/bin/lazygit"
fkrun bash "$TK/setup.sh" --repair
pkg_has btop && pkg_has ripgrep && _ok || _no "the packages are not back"
[[ -x $W/home/fkuser/.local/bin/lazygit ]] && _ok || _no "lazygit is not back"
eq "$(shell_errors "$OUT")" ""
case_ "fedokawaii selftest on the finished install: it reads, never writes — and names what is off"
: >"$CALLS"; fkrun bash "$TK/tools/selftest.sh"
eq "$(shell_errors "$OUT")" ""; has "$OUT" "fedokawaii.conf: every value valid"; has "$OUT" "every script parses"; has "$OUT" "the desktop user: fkuser"
[[ $RC == [03] ]] && _ok || _no "selftest ended $RC"
not_called 'dnf\] -y '; not_called 'systemctl\] (enable|disable|mask|start|restart)'
echo "wiremix|missing" >"$W/var/lib/fedokawaii/dnf-failed"; : >"$W/var/lib/fedokawaii/done.T5 repositories"
fkrun bash "$TK/tools/selftest.sh"; eq "$RC" 3; has "$OUT" "wiremix did not install (missing)"; has "$OUT" "the container trial's records are here"
done_
