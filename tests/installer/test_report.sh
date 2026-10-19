#!/usr/bin/env bash
# tests/installer/test_report.sh — fedokawaii-report on a finished install (the fake machine, as
# root, no systemd and no desktop running): it writes ~/fedokawaii-report.txt, yours, with the
# verdict on top, the findings by area, each area's table of checks, the logs and captures,
# and a machine-readable summary; no secret is copied; the commands meant for you run as you;
# a broken program is a FAIL with its output, a missing optional one a WARN, the checks that
# need the desktop are skipped (and said); crashes are grouped by program with their package
# and dnf's transaction; the files of root's in your home are found, podman's are not; an old
# toolkit's missing pieces are findings, never a crash. (Two runs: about five minutes.)
. "$(dirname "$0")/lib.sh"
TK=/usr/local/lib/fedokawaii
R=/home/fkuser/fedokawaii-report.txt
report() { fkrun bash /usr/local/bin/fedokawaii-report "$@"; REP=$(cat "$W$R" 2>/dev/null); }
area() { awk -v a="$1" '$0 == a { on = 1; next } /^[0-9]+\. / || /^── / { on = 0 } on' <<<"$REP"; }

world built
# the machine as the owner's was found (19 Oct): a secret in the settings and in the install's
# log; a program installed but broken; Steam (optional) not here; lpf's folder left; crashes — 26 of a
# package's helper while dnf ran, one of the bar, one before setup finished; files of root's
# in the home, and podman's storage (the containers' own ids); a ✘ in the log with what led to it
printf 'GH_TOKEN="ghp_never-copied-1"\n' >>"$W$TK/fedokawaii.conf"
printf '  ✘ 3.04 tools: password: hunter2-never-copied\n' >>"$W/var/log/fedokawaii.log"
printf '#!/bin/sh\necho "foot: error while loading shared libraries: libfcft.so.4" >&2\nexit 3\n' >"$W/usr/local/bin/foot"
chmod 755 "$W/usr/local/bin/foot"
mkdir -p "$W/var/lib/lpf/packages"   # (lpf's folder, left behind when Spotify became its web player)
mkdir -p "$W/home/fkuser/.local/share/applications"   # (Spotify's entry: its web player)
sed 's|@HOME@|/home/fkuser|g' "$REPO/configs/home/.local/share/applications/spotify.desktop" >"$W/home/fkuser/.local/share/applications/spotify.desktop"
fk date -d '2026-10-19 04:00:00' +%s >"$W/var/lib/fedokawaii/setup-done"   # (the fake machine's own time zone)
mkdir -p "$W/usr/local/sbin"
{ printf '#!/bin/sh\n[ "$1" = list ] || exit 0\n'
  printf 'cat <<EOF\n'
  printf 'Mon 2026-10-19 03:00:00 +04 100 0 0 SIGSEGV present  /usr/bin/fooinstall 1K\n'
  for i in $(seq 26); do printf 'Mon 2026-10-19 04:05:%02d +04 %d 0 0 SIGTRAP present  /usr/lib64/qt6/libexec/qwebengine_convert_dict 250.2K\n' $((49 + i / 13)) $((3200 + i)); done
  printf 'Mon 2026-10-19 05:01:02 +04 9100 1000 1000 SIGSEGV present  /usr/bin/waybar 1.2M\n'
  printf 'Mon 2026-10-19 14:10:54 +04 3626 1000 1000 SIGSYS present  /usr/bin/bwrap 120K\n'
  printf 'EOF\n'; } >"$W/usr/local/sbin/coredumpctl"
printf '%s\n' '#!/bin/bash' 'case "$1 $2" in' \
  '"history list") printf "%s\n" "ID Command line                    Date and time       Action(s) Altered" "  8 dnf upgrade -y                  2026-10-19 04:40:00               3" "  7 dnf install -y libreoffice-writer hunspell-ar 2026-10-19 04:03:12               412" "  6 dnf install -y git             2026-10-19 03:50:01               9" ;;' \
  '"history info") echo "Transaction ID : $3"; echo "Packages altered: hunspell-ar qt6-qtwebengine" ;;' \
  '*) exec /usr/local/bin/dnf "$@" ;;' 'esac' >"$W/usr/local/sbin/dnf"
printf '%s\n' '#!/bin/bash' '[ "$1" = -qf ] && { case $2 in *qwebengine*) echo qt6-qtwebengine-6.10.0-1.fc44.x86_64 ;; *) echo waybar-0.14.0-1.fc44.x86_64 ;; esac; exit 0; }' 'exec /usr/local/bin/rpm "$@"' >"$W/usr/local/sbin/rpm"
chmod 755 "$W"/usr/local/sbin/{coredumpctl,dnf,rpm}
fk bash -c 'mkdir -p /home/fkuser/.cache/oops /home/fkuser/.local/share/containers/storage/overlay/x /home/fkuser/Downloads
            touch /home/fkuser/Downloads/rooted; chown 0:0 /home/fkuser/Downloads/rooted
            touch /home/fkuser/.cache/oops/{a,b,c} /home/fkuser/.local/share/containers/storage/overlay/x/{1,2}
            chown -R fkuser:fkuser /home/fkuser/.cache /home/fkuser/.local
            chown 0:0 /home/fkuser/.cache/oops/{a,b,c}
            chown -R 100999:100999 /home/fkuser/.local/share/containers/storage/overlay/x'
printf 'THEME="dark"\n' >"$W/var/lib/fedokawaii/conf-from-copy.conf"
{ for i in 1 2 3 4 5 6 7; do echo "  step context $i"; done; echo "  ✘ 3.06 applications: dnf failed"
  seq 1 500 | sed 's/^/  ✔ step /'; } >>"$W/var/log/fedokawaii.log"
# … and as the owner's report showed it (19 Oct): a repair after the failed runs, without a ✘;
# the greeter's EGL and GL extension lists ("…_no_error"); the journal's errors all known but
# one (a crash's stack trace, the AMD kernel's TDX notice, LACT's OverDrive, foot's broken pipe
# as the session ended); glycin's bwrap ended by its seccomp filter; a sudo of verify's that
# closed at 14:08:39, a restart, and a real logout that showed the login screen 1.2 s later
printf '\n\e[1m── Fedokawaii repair · fkuser \e[0m\n  ✔ repaired\n' >>"$W/var/log/fedokawaii.log"
printf '%s\n' 'Oct 19 14:09:33 fedokawaii kawa-greet[1098]: 00:00:00.053 [INFO] [render/egl.c:205] Supported EGL client extensions: EGL_EXT_device_base EGL_KHR_create_context_no_error' \
  'Oct 19 14:09:33 fedokawaii kawa-greet[1098]: 00:00:00.068 [INFO] [render/gles2/renderer.c:542] Supported GLES2 extensions: GL_KHR_no_error GL_EXT_blend_minmax' >"$FKH/journal-kawa-greet"
printf '%s\n' 'Oct 19 14:09:25 fedora kernel: virt/tdx: TDX not supported by the host platform' \
  'Oct 19 14:09:27 fedora kernel: amdgpu: Overdrive is enabled, please disable it before reporting any bugs unrelated to overdrive.' \
  'Oct 19 14:10:54 fedokawaii systemd-coredump[3637]: Process 3626 (bwrap) of user 1000 dumped core.' \
  '                                                   Module bwrap from rpm bubblewrap-0.12.0-1.fc44.x86_64' \
  '                                                   #0  0x00007f0926263f4b execve (libc.so.6 + 0xc0f4b)' \
  'Oct 19 14:12:11 fedokawaii foot[1486]: wayland: failed to roundtrip Wayland display: Broken pipe' \
  'Oct 19 14:12:11 fedokawaii foot[1486]: wayland: failed to flush wayland socket: Broken pipe' \
  'Oct 19 14:12:30 fedokawaii kernel: nvme0n1: I/O error, dev nvme0n1, sector 4096' >"$FKH/journal-err"
printf '%s\n' '1792404519.000000 fedokawaii sudo[7001]: pam_unix(sudo:session): session closed for user fkuser' \
  '1792404519.100000 fedokawaii runuser[7002]: pam_unix(runuser:session): session closed for user fkuser' >"$FKH/journal-unix.prev"
printf '%s\n' '1792404573.000000 fedokawaii greetd[1049]: pam_unix(greetd-greeter:session): session opened for user greetd(uid=989) by (uid=0)' \
  '1792404730.000000 fedokawaii greetd[4952]: pam_unix(greetd:session): session closed for user fkuser' \
  '1792404731.200000 fedokawaii greetd[4776]: pam_unix(greetd-greeter:session): session opened for user greetd(uid=989) by (uid=0)' >"$FKH/journal-unix"
# (the report's own two switches as kawa-theme timed them: the first to light cold — its
# wallpaper decoded for the first time — the last warm)
printf '%s\n' '2026-10-19 14:13:44 kawa-theme: switched to light in 568 ms (under the veil)' \
  '2026-10-19 14:13:51 kawa-theme: switched to dark in 49 ms (under the veil)' >"$W/home/fkuser/.cache/kawa-theme.log"
fk chown fkuser: /home/fkuser/.cache/kawa-theme.log
keep ready

report --quick

case_ "the report is written, yours alone: the verdict, the findings by area, the tables, the logs, the summary"
eq "$RC" 0 "exit"
has "$OUT" "fedokawaii-report: $R ("
has "$OUT" "checks and the machine's logs — this takes a few minutes"
[[ -s $W$R ]] && _ok || _no "no report written"
eq "$(fk stat -c '%U %a' "$R")" "fkuser 600"
[[ $(sed -n 1p <<<"$REP") == "fedokawaii health report — "*" — for fkuser" ]] && _ok || _no "first line: $(sed -n 1p <<<"$REP")"
grep -qE '^made by fedokawaii-report in [0-9]+ s: [0-9]{3} checks in tables, and the logs \(--quick' <<<"$REP" && _ok || _no "second line: $(sed -n 2p <<<"$REP")"
grep -qE '^VERDICT: (BROKEN|WORKS, WITH WARNINGS|HEALTHY) — ' <<<"$REP" && _ok || _no "no verdict line"
eq "$(grep -n '^VERDICT' <<<"$REP" | cut -d: -f1)" 4 "the verdict on the fourth line"
v=$(grep -n '^VERDICT' <<<"$REP" | cut -d: -f1); f=$(grep -n '^── findings by area' <<<"$REP" | cut -d: -f1)
t=$(grep -n '^── by area: each check' <<<"$REP" | cut -d: -f1); b=$(grep -n '^══════ 1. the system and the toolkit' <<<"$REP" | cut -d: -f1)
c=$(grep -n '^══════ the checks: what each one printed' <<<"$REP" | cut -d: -f1); m=$(grep -n '^══════ machine-readable' <<<"$REP" | cut -d: -f1)
((v < f && f < t && t < b && b < c && c < m)) && _ok || _no "not verdict, findings, tables, logs, captures, summary: $v $f $t $b $c $m"
has "$REP" "          → " "a finding says what to do"
for s in "1. the system and the toolkit" "2. the boot and the console" "3. the install's log" "4. verify" "5. login and the session" "6. dwl and the keys" "7. the theme" "10. the journal and the system's health" "13. sleep and the lock" "17. the clipboard" "19. fonts" "20. the launcher and what opens what" "24. disks and snapshots"; do
  has "$REP" "══════ $s " "no section $s"
done
a=$(grep -n '^══════ 2\. ' <<<"$REP" | cut -d: -f1); z=$(grep -n '^══════ 24\. ' <<<"$REP" | cut -d: -f1)
((a < z)) && _ok || _no "the sections are not in their areas' order"
lacks "$REP" "row '" "a row of the report's own tables is malformed"

case_ "the tables: every area's checks with a summary line; the desktop's skipped, and said"
t=$(sed -n '/^── by area: each check/,/^── fine/p' <<<"$REP")
for a in "2. the boot and the console" "18. screen sharing and the file dialog" "22. packages and updates" "27. applications" "28. backups"; do
  grep -qE "^${a//./\\.} — [0-9]+ checks: [0-9]+ ok, [0-9]+ FAIL, [0-9]+ WARN, [0-9]+ INFO, [0-9]+ SKIP" <<<"$t" && _ok || _no "no summary line for $a"
done
n=$(grep -cE '^  (ok  |FAIL|WARN|INFO|SKIP)  ' <<<"$t"); ((n > 400)) && _ok || _no "only $n checks in the tables"
grep -qE '^  SKIP  mako ' <<<"$t" && _ok || _no "a check that needs the desktop ran without one"
has "$(area "0. the report itself")" "checks of the live desktop were skipped: no desktop session runs for fkuser"
grep -qE '^  SKIP  BOOT-05 ' <<<"$t" && _ok || _no "a full-run check (the trial boot image) ran with --quick"

case_ "no secret is copied: passwords, tokens and keys show as ●●●; secrets.sh is never read"
lacks "$REP" "ghp_never-copied-1"; lacks "$REP" "hunter2-never-copied"; lacks "$REP" "a1b2c3d4e5f60718293a4b5c6d7e8f90"
has "$REP" 'GH_TOKEN=●●●'; has "$REP" 'password: ●●●'
has "$REP" "secrets.sh (mode only — never read)"

case_ "as you: the commands meant for your session run as you, in your home (never root's)"
lacks "$REP" "failed to run command ‘runuser’"; lacks "$REP" "failed to run command ‘asu’"
has "$(grep -A3 '^── the fonts the desktop uses (as fkuser)' <<<"$REP")" "Fusion Pixel 12px Mono ja"
grep -qP '^INFO\t18\. screen sharing and the file dialog\tSHARE-05 the share log\t\(no screen shared yet: /home/fkuser/\.cache/kawa-share\.log\)$' <<<"$REP" && _ok || _no "a row as you did not see your home: $(grep -P '\tSHARE-05 the share log\t' <<<"$REP")"
l=$(grep -P '^(ok|FAIL)\t27\. applications\tFETCH-01 the prompt \(ble\.sh\)\t' <<<"$REP"); [[ -n $l && $l != *"not installed"* ]] && _ok || _no "ble.sh (a file in your home, not a program) not found: $l"
lacks "$(sed -n '/^── 9\. the session.s programs · RES-04/,/^── /p' <<<"$REP" | grep -E '^T')" "bash" "the shell probe left a stopped bash behind"   # (zombies: the test machine's own, its PID 1 reaps none)

case_ "every program, run: a broken one FAILs with its output, a missing optional one WARNs"
a=$(area "27. applications")
has "$a" "FAIL  foot: installed but broken (exit 3) — expected: prints its version"
has "$a" "| foot: error while loading shared libraries: libfcft.so.4" "the broken one's output, in the findings"
has "$a" "WARN  SPOT-05 lpf's leftovers are gone (exit 1)" "lpf's folder left behind: a WARN"; has "$a" "WARN  steam: not installed (optional)"
lacks "$a" "SPOT-04"; lacks "$a" "SPOT-06"; lacks "$a" "FAIL  steam"
t=$(sed -n '/^── by area: each check/,/^── fine/p' <<<"$REP")
grep -qE '^  ok    SPOT-06 Spotify opens its web player ' <<<"$t" && _ok || _no "the web player's entry not ok: $(grep ' SPOT-06 ' <<<"$t")"
grep -qE '^  ok    fuzzel ' <<<"$t" && _ok || _no "fuzzel (a working stand-in) not ok: $(grep ' fuzzel ' <<<"$t")"
grep -qE '^  FAIL  foot +[0-9]+ ms  prints its version' <<<"$t" && _ok || _no "foot not FAIL in the table"
grep -qE '^  (ok  |FAIL)  kawa-drives ' <<<"$t" && _ok || _no "the kawa-* helpers are not in the table"
grep -qE '^  (ok  |FAIL)  yazi ' <<<"$t" && grep -qE '^  (ok  |FAIL)  herdr ' <<<"$t" && _ok || _no "the upstream tools are not in the table"
eq "$(grep -cE '^  (ok  |FAIL)  yazi ' <<<"$t")" 1 "yazi checked once"
has "$REP" "── 27. applications · foot (FAIL)"$'\n'"\$ foot --version" "the command that failed, in the captures"
has "$REP" "── PKG-01 the packages lib/manifest.sh installs"
has "$REP" "no desktop session is running (dwl not found for fkuser)"

case_ "crashes, grouped by program: the desktop's a FAIL, before setup finished only listed, qwebengine's dictionary conversion during dnf known — each with its package and dnf's transaction"
a=$(area "10. the journal and the system's health")
lacks "$a" "qwebengine_convert_dict" "the dictionaries' conversion as dnf installed hunspell: known, no finding"
has "$REP" "26 × SIGTRAP  /usr/lib64/qt6/libexec/qwebengine_convert_dict  (uid 0, qt6-qtwebengine-6.10.0-1.fc44.x86_64)"
has "$REP" "  known and harmless: the dictionaries' conversion as dnf installed hunspell or qtwebengine ("
has "$REP" "  the dnf transaction last begun before it: 7: dnf install -y libreoffice-writer hunspell-ar 2026-10-19 04:03:12 · 412"
has "$a" "FAIL  SYS-02 /usr/bin/waybar crashed 1 times (SIGSEGV, 2026-10-19 05:01:02)"
has "$a" "| the dnf transaction last begun before it: 8: dnf upgrade -y · 2026-10-19 04:40:00 · 3"
lacks "$a" "fooinstall" "a crash before setup finished is no finding"
has "$REP" "/usr/bin/fooinstall  (uid 0," "… but it is listed"
has "$REP" "Packages altered: hunspell-ar qt6-qtwebengine" "dnf's own account of that transaction"

case_ "as the owner's report found them, now judged right: a logout timed within its boot (never a sudo before a restart); the greeter's extension lists no errors; the journal's known errors aside; glycin's bwrap known; the install's log by its last run"
a=$(sed -n '/^── findings by area/,/^── by area: each check/p' <<<"$REP")
lacks "$a" "LOGIN-06"; has "$REP" "logout at "; has "$REP" "→ login screen 1.2 s later"; lacks "$REP" "54.0 s later"
grep -qP '^ok\t2\. the boot and the console\tLOGIN-06 logout → login screen within 1\.2 s' <<<"$REP" && _ok || _no "LOGIN-06 not ok: $(grep 'LOGIN-06' <<<"$REP" | head -n 3)"
lacks "$a" "the login screen logged"
has "$a" "WARN  SYS-01 the journal has 1 error entries this boot (the known and harmless aside)"; has "$a" "nvme0n1: I/O error"
lacks "$a" "TDX"; lacks "$a" "Broken pipe"
has "$REP" "this boot: 1 error entries (and 5 known and harmless)"
lacks "$a" "bwrap"; has "$REP" "known, upstream: glycin's sandboxed image loader"
lacks "$a" "by its own count"; grep -qP '^ok\t7\. the theme\tthe theme switches in time by its own count \(the last: 49 ms \(to dark\)\)' <<<"$REP" && _ok || _no "the theme's own count: $(grep 'own count' <<<"$REP" | head -n 2)"
v=$(sed -n '/^  FAIL  verify: /,/^  [A-Z]/p' <<<"$REP"); n=$(grep -c '^          | ' <<<"$v")
has "$v" "FAIL  verify: $n checks failed" "verify's count is its ✘ lines"; lacks "$v" "checks failed:" "verify's closing count is no failed check"
lacks "$a" "UPK-06"; grep -qP "^ok\t3\. the install's log\tUPK-06 the install's last run has no ✘ \([0-9]+ in earlier runs" <<<"$REP" && _ok || _no "UPK-06: $(grep 'UPK-06' <<<"$REP" | head -n 2)"

case_ "files in your home: root's found and grouped by folder, ~/Downloads too; podman's storage counted apart, by design"
a=$(area "24. disks and snapshots")
has "$a" "WARN  SEC-03 4 files in your home belong to root"
lacks "$a" "another user"
b=$(sed -n '/^── files in your home not yours/,/^── /p' <<<"$REP")
grep -qP '^ +3  root\t~/\.cache/oops$' <<<"$b" && _ok || _no "root's files not grouped by folder: $b"
grep -qP '^ +1  root\t~/Downloads$' <<<"$b" && _ok || _no "your Downloads folder not searched: $b"
has "$b" "podman's storage (~/.local/share/containers/storage): 3 files of podman's containers' own (subordinate) ids — by design"
lacks "$(grep -P '^ +[0-9]+  ' <<<"$b")" "containers"

case_ "the install's log: each ✘ with the 6 lines before it; a long log cut, the rest counted"
l=$(sed -n '/^── every ✘ line, with the 6 lines before it/,/^── /p' <<<"$REP")
has "$l" "step context 2"; lacks "$l" "step context 1"; has "$l" "✘ 3.06 applications: dnf failed"
grep -qE '^… [0-9]+ earlier lines$' <<<"$REP" && _ok || _no "the install's log uncut"
lacks "$(sed -n '/^── setup.s state/,/^── /p' <<<"$REP")" "conf-from-copy" "the settings files are not setup's state"
(($(wc -c <"$W$R") < 4000000)) && _ok || _no "the file is $(wc -c <"$W$R") bytes"

case_ "the machine-readable summary: one line per check and finding, STATUS<tab>area<tab>check<tab>detail"
m=$(sed -n '/^══════ machine-readable/,$p' <<<"$REP" | tail -n +2)
(($(grep -c . <<<"$m") > 450)) && _ok || _no "only $(grep -c . <<<"$m") lines"
lacks "$(grep -vP '^(ok|FAIL|WARN|INFO|SKIP)\t[0-9]+\. [^\t]+\t[^\t]+\t' <<<"$m")" $'\t' "a line not of the form"
grep -qP '^FAIL\t27\. applications\tfoot\tfoot: error while loading' <<<"$m" && _ok || _no "foot's line"
grep -qP '^ok\t1\. the system and the toolkit\tsetup finished' <<<"$m" && _ok || _no "the section findings are not in it"
grep -qP '^SKIP\t9\. the session.s programs\tRES-01 ' <<<"$m" && _ok || _no "a skipped check is not in it"

case_ "an old toolkit (no lib/upstream.sh, no lib/manifest.sh, no bin/): findings, never a crash"
back ready
fk_plain rm -rf "$W$TK/lib/upstream.sh" "$W$TK/lib/manifest.sh" "$W$TK/bin"
report --quick; eq "$RC" 0 "exit"
has "$REP" "FAIL  lib/upstream.sh is missing from the toolkit"
has "$REP" "FAIL  lib/manifest.sh is missing from the toolkit: the packages are not checked"
has "$REP" "FAIL  the toolkit has no bin/"
grep -q '^VERDICT: BROKEN' <<<"$REP" && _ok || _no "not BROKEN"

case_ "misuse: exit 2; --help: the header"
report --nonsense; eq "$RC" 2; has "$OUT" "usage: fedokawaii-report [--quick]"
report --help; eq "$RC" 0; has "$OUT" "sudo fedokawaii-report --quick"

case_ "shellcheck: clean"
if command -v shellcheck >/dev/null; then
  out=$(shellcheck -S warning "$REPO/system/fedokawaii-report" 2>&1) && _ok || _no "${out:0:400}"
else printf '  – skipped: shellcheck is not installed\n'; fi

done_
