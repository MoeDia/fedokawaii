#!/usr/bin/env bash
# tests/installer/test_clean.sh — a run with nothing wrong says nothing wrong: no ✘, no !, no
# "attempt" line. RPM Fusion's release packages from RPM Fusion's own server or, when that does
# not answer, its mirror list — each checked against RPM Fusion's pinned key before dnf installs
# it (and refused when it is not RPM Fusion's); waits (the network, your own systemd) said
# quietly; the readiness check's clock still synchronising said as information.
. "$(dirname "$0")/lib.sh"
CLONE=/home/fkuser/fedokawaii
TK=/usr/local/lib/fedokawaii
setup() { fkrun bash "$CLONE/setup.sh"; }
resume() { fkrun bash "$TK/setup.sh" --resume "$@"; }

# ── the helpers, alone ───────────────────────────────────────────────────────
case_ "wait_until: quiet while it waits, 0 once the thing comes, 1 when it never does — and no attempt lines"
o=$(LOG_FILE=/dev/null bash -c '. "$1/lib/common.sh"; sleep() { :; }; k=0; up() { k=$((k + 1)); ((k >= 3)); }; wait_until 20 up; echo "rc=$? n=$k"; wait_until 4 false; echo "rc=$?"' _ "$REPO" 2>&1)
has "$o" "rc=0 n=3"; has "$o" "rc=1"; lacks "$o" "attempt"
case_ "dnf_why: COPR's \"Chroot not found\" is a name no repository has (no new try mends it)"
eq "$(LOG_FILE=/dev/null bash -c '. "$1/lib/common.sh"; dnf_why "Chroot not found in the given Copr project (fedora-47-x86_64)."' _ "$REPO")" missing

world fresh; releases
keep fresh

# ── phase 1, then phase 2 ────────────────────────────────────────────────────
case_ "phase 1 on a sound machine: its summary counts nothing retried, nothing warned, nothing failed"
setup; eq "$RC" 0 "$(grep -E '✘' <<<"$OUT" | head -n3 | tr '\n' '|')"
has "$OUT" "0 retried · 0 warning(s) · 0 failed"; lacks "$OUT" "attempt 1/"
not_called 'grubby\] .*--remove-args' "no argument to take off: grubby is not run for nothing"
case_ "…an entry with an argument gone since (plymouth.use-simpledrm: a black flick before the login): taken off every entry"
back fresh; reset_calls
printf '%s\n' "ro rootflags=subvol=root rhgb quiet plymouth.use-simpledrm" "ro rootflags=subvol=root rhgb quiet plymouth.use-simpledrm" >"$FKH/grub-args"; chmod 666 "$FKH/grub-args"
# (and what an older container trial left in the home: its lock and its logs; its results stay)
H=$W/home/fkuser; mkdir -p "$H/fedokawaii-trial.d"; : >"$H/fedokawaii-trial.d/base.log"; : >"$H/fedokawaii-trial.lock"; echo results >"$H/fedokawaii-trial.txt"
chown -R 31000:31000 "$H/fedokawaii-trial.d" "$H/fedokawaii-trial.lock" "$H/fedokawaii-trial.txt"
setup; eq "$RC" 0 "$(grep -E '✘' <<<"$OUT" | head -n3 | tr '\n' '|')"
called 'grubby\] --update-kernel=ALL --remove-args=plymouth.use-simpledrm'
lacks "$(cat "$FKH/grub-args")" "plymouth.use-simpledrm"; has "$(head -n1 "$FKH/grub-args")" "systemd.tty.term.console=dumb"
[[ ! -e $H/fedokawaii-trial.d && ! -e $H/fedokawaii-trial.lock && -f $H/fedokawaii-trial.txt ]] && _ok || _no "the trial's old lock or logs still in the home (or its results gone)"
has "$OUT" "the container trial's old leftovers removed"
reboot_world; keep phase2

case_ "phase 2: RPM Fusion's release packages from RPM Fusion's own server, checked against its pinned keys, installed by dnf checking them again"
resume --no-reboot; eq "$RC" 0 "$(grep -E '✘' <<<"$OUT" | head -n3 | tr '\n' '|')"
pkg_has rpmfusion-free-release && pkg_has rpmfusion-nonfree-release && _ok || _no "the release packages are not installed"
called 'curl\] .*https://download1\.rpmfusion\.org/free/fedora/rpmfusion-free-release-44\.noarch\.rpm'
not_called 'mirrors\.rpmfusion\.org' "the mirror list is never asked while RPM Fusion's own server answers"
called 'rpmkeys\] -K .*rpmfusion-free-release-44\.noarch\.rpm'; called 'rpmkeys\] -K .*rpmfusion-nonfree-release-44\.noarch\.rpm'
called 'rpm\] --import .*RPM-GPG-KEY-rpmfusion-free-fedora-2020'
called 'dnf\] -y install --setopt=localpkg_gpgcheck=1 /.*rpmfusion-free-release-44\.noarch\.rpm /.*rpmfusion-nonfree-release-44\.noarch\.rpm'
not_called 'dnf\] -y install https://' "dnf never fetches them itself (one dead mirror once stopped setup there)"
has "$OUT" "0 retried · 0 warning(s) · 0 failed"

case_ "…RPM Fusion's own server not answering: its mirror list instead, said in one line — still checked"
back phase2; reset_calls; fkh unreachable download1.rpmfusion.org
resume --no-reboot; eq "$RC" 0 "$(grep -E '✘' <<<"$OUT" | head -n3 | tr '\n' '|')"
called 'curl\] .*https://mirrors\.rpmfusion\.org/free/fedora/rpmfusion-free-release-44\.noarch\.rpm'
has "$OUT" "did not come from download1.rpmfusion.org — the next source"
called 'rpmkeys\] -K'; pkg_has rpmfusion-free-release && _ok || _no "not installed from the mirror list"
lacks "$OUT" "attempt 1/"

case_ "…a release package not signed by RPM Fusion (a mirror's own file): refused from every source, nothing installed, exit 1 naming why"
back phase2; reset_calls; fkh rpm-badsig
resume --no-reboot; eq "$RC" 1
has "$OUT" "does not carry RPM Fusion's signature"; has "$OUT" "RPM Fusion's release packages for Fedora 44 could not be fetched"
pkg_has rpmfusion-free-release && _no "an unsigned release package was installed" || _ok
not_called 'dnf\] -y install --setopt=localpkg_gpgcheck=1'

case_ "…a key RPM Fusion has not used so far: taken from RPM Fusion's own server, and said — never from a mirror"
back phase2; reset_calls; fkh rpmfusion-key-other
resume --no-reboot; eq "$RC" 0 "$(grep -E '✘' <<<"$OUT" | head -n3 | tr '\n' '|')"
has "$OUT" "signed with a key this toolkit does not pin yet"; pkg_has rpmfusion-free-release && _ok || _no "not installed"
back phase2; reset_calls; fkh rpmfusion-key-other; fkh unreachable download1.rpmfusion.org
resume --no-reboot; eq "$RC" 1 "a new key from a mirror is refused"
has "$OUT" "carries no key of RPM Fusion's that could check it"
pkg_has rpmfusion-free-release && _no "a mirror's file with an unknown key was installed" || _ok

# ── the readiness check ──────────────────────────────────────────────────────
case_ "check: the clock still synchronising with NTP on — information, not a warning (a wrong clock shows in the downloads)"
back fresh; printf '%s\n' no >"$FKH/ntp"; chmod 666 "$FKH/ntp"
fkh ntp-on yes
fkrun bash "$CLONE/check.sh"; eq "$RC" 0
has "$OUT" "the clock is still synchronising (NTP is on)"; lacks "$OUT" "!  clock"

done_
