#!/usr/bin/env bash
# tests/installer/test_conf_scripts.sh — what setup.sh, theme.sh, check.sh and verify.sh do with a
# fedokawaii.conf a person got wrong (or saved on Windows), in the fake machine: each stops
# before it changes anything, naming the line; the Windows file runs as from Linux; --help
# needs neither root nor a valid file. (The reading itself: test_conf.sh)
. "$(dirname "$0")/lib.sh"
CONF=$REPO/fedokawaii.conf
# ── what the scripts do with such a file, in the fake machine ─────────────────
world fresh
cf=$W/home/fkuser/fedokawaii/fedokawaii.conf
case_ "setup: a bad file stops it before anything is done, naming the line (exit 1)"
sed -i 's/^GPU=.*/GPU = "amd"/' "$cf"
fkrun bash /home/fkuser/fedokawaii/setup.sh --no-reboot
eq "$RC" 1; has "$OUT" "fedokawaii.conf:"; has "$OUT" 'GPU has spaces around'
eq "$(state phase)" "" "no phase recorded"; not_called 'dnf'

case_ "setup: the same file saved on Windows (CRLF + BOM) runs as from Linux"
{ printf '\xef\xbb\xbf'; sed 's/$/\r/' "$CONF"; } >"$cf"
fkrun bash /home/fkuser/fedokawaii/setup.sh --status
eq "$RC" 0; has "$OUT" "phase 1"

case_ "setup --help: works without a valid file, and without sudo rights in the way"
sed -i 's/^GPU=.*/GPU="nvidia"/' "$cf"
fkrun bash /home/fkuser/fedokawaii/setup.sh --help
eq "$RC" 0; has "$OUT" "sudo bash setup.sh --update"
fkrun runuser -u fkuser -- bash /home/fkuser/fedokawaii/setup.sh --help
eq "$RC" 0 "--help as the user, before sudo"; has "$OUT" "sudo bash setup.sh --update"

case_ "check: a bad file is a ✘ line (not ready), the rest of the check still runs"
fkrun bash /home/fkuser/fedokawaii/check.sh
eq "$RC" 1; has "$OUT" "✘  GPU must be auto, amd or intel (is 'nvidia')"; has "$OUT" "memory"

case_ "check: the file missing is one ✘ line"
rm -f "$cf"; fkrun bash /home/fkuser/fedokawaii/check.sh
eq "$RC" 1; has "$OUT" "✘  cannot read /home/fkuser/fedokawaii/fedokawaii.conf"
lacks "$OUT" "STEAM must be"

world built
tcf=$W/usr/local/lib/fedokawaii/fedokawaii.conf
case_ "theme: a bad file stops it before any file is touched (exit 1)"
sed -i 's/^THEME=.*/THEME="pink"/' "$tcf"
fkrun bash /usr/local/lib/fedokawaii/theme.sh --user fkuser
eq "$RC" 1; has "$OUT" "THEME must be dark or light (is 'pink')"
[[ ! -e $W/home/fkuser/.config/foot ]] && _ok || _no "theme wrote configs with a bad fedokawaii.conf"

case_ "verify: a bad file in the toolkit is a failed check of its own, named"
fkrun bash /usr/local/lib/fedokawaii/verify.sh
eq "$RC" 3; has "$OUT" "✘  fedokawaii.conf"; has "$OUT" "THEME must be dark or light"

done_
