#!/usr/bin/env bash
# tools/vm-inject/run-all.sh — every failure of update-design.md §5 injected in a harness VM (T49): a
# row starts the VM from the state "inject" (below), breaks one thing, presses the button as Super+U
# presses it, restores nothing by hand, and holds only if the machine ends working and says what
# happened. The rows' words are the system's own: the report's line, the notice kept for login.
#   bash tools/vm-inject/run-all.sh VM TREE base        once: the state "inject" from "pressed" (an
#        up-to-date system with this desktop, the desktop at every start): the signing key of the
#        test packages, fk-inject-a and -b 1.0 from a local repository, every other repository
#        showing nothing newer (the network still used: includepkgs), the next Fedora far off
#   bash tools/vm-inject/run-all.sh VM TREE [ROW…]      those rows (all, without any)
# Out: a line a row, the same in /dev/shm/r27/inject/table.txt, each row's evidence (its press, its
# facts) in /dev/shm/r27/inject/ROW/. The toolkit comes from TREE (frozen: a proof reads it through).
# Exit 0 every row held · 1 one did not · 2 the VM could not run.
# Rows proven by their own scripts: restore-cut.sh (41), split-cut.sh (43), overlay-restore.sh (the
# boot menu's read-only start), probation.sh (15: a kernel that does not start), update-button.sh (29),
# release-move.sh (32: the move cut and red). The fixer's own (21, 22): the fixer's bench. Stubs, a
# VM adds nothing there: eol, remind (tests/engine/test_status.sh), space (test_upkeep).
set -u
vm=${1:?VM} src=${2:?TREE}; shift 2
# shellcheck source=tools/vm-inject/lib.sh
. "$(dirname "$0")/lib.sh"
# shellcheck disable=SC2154  # (here, log, out: lib.sh's)
U=/var/lib/fedokawaii/update
TABLE=/dev/shm/r27/inject/table.txt
mkdir -p "${TABLE%/*}"

# in the VM: a test package, built, signed (unless "unsigned"), published
#   fk-inject-pkg NAME VER [pre=SH] [post=SH] [posttrans=SH] [req=CAP] [conf=CAP] [unsigned]
PKGTOOL=$(cat <<'TOOL'
#!/bin/bash
set -eu
name=$1 ver=$2; shift 2
pre="" post="" posttrans="" req="" conf="" sign=1
for a; do case $a in pre=*) pre=${a#*=} ;; post=*) post=${a#*=} ;; posttrans=*) posttrans=${a#*=} ;; req=*) req=${a#*=} ;; conf=*) conf=${a#*=} ;; unsigned) sign=0 ;; esac; done
d=$(mktemp -d); r=/var/lib/fk-inject/repo
{ printf '%s\n' "Name: $name" "Version: $ver" "Release: 1" "Summary: an injection" "License: MIT" "BuildArch: noarch"
  [[ -z $req ]] || echo "Requires: $req"; [[ -z $conf ]] || echo "Conflicts: $conf"
  printf '%s\n' '%description' 'an injection' '%install' 'mkdir -p %{buildroot}/usr/share/fk-inject' "echo $ver >%{buildroot}/usr/share/fk-inject/$name" '%files' "/usr/share/fk-inject/$name"
  [[ -z $pre ]] || printf '%%pre\n%s\n' "$pre"; [[ -z $post ]] || printf '%%post\n%s\n' "$post"; [[ -z $posttrans ]] || printf '%%posttrans\n%s\n' "$posttrans"
} >"$d/p.spec"
rpmbuild -bb --quiet --define "_topdir $d" --define "_rpmdir $d/out" "$d/p.spec" >/dev/null 2>&1
f=$(find "$d/out" -name '*.rpm')
((sign == 0)) || GNUPGHOME=/var/lib/fk-inject/gpg rpmsign --addsign --define '_gpg_name fk inject' "$f" >/dev/null 2>&1
mv "$f" "$r/"; createrepo_c --quiet --update "$r" >/dev/null; rm -rf "$d"
TOOL
)
base() {
  inj_init "$vm" "$src" base
  inj_from pressed
  run --apply "$src" >>"$log" 2>&1 || { row BROKEN "the toolkit could not go in"; return 1; }
  run 'sudo dnf install -y -q rpm-build rpm-sign createrepo_c' >>"$log" 2>&1 || { row BROKEN "the build tools"; return 1; }
  printf '%s\n' "$PKGTOOL" | run 'sudo tee /usr/local/sbin/fk-inject-pkg >/dev/null; sudo chmod 755 /usr/local/sbin/fk-inject-pkg'
  # shellcheck disable=SC2016
  run 'set -e; sudo mkdir -p /var/lib/fk-inject/repo; sudo install -d -m 700 /var/lib/fk-inject/gpg
    sudo GNUPGHOME=/var/lib/fk-inject/gpg gpg --batch --quiet --passphrase "" --quick-gen-key "fk inject" rsa2048 sign never
    sudo GNUPGHOME=/var/lib/fk-inject/gpg gpg --batch --quiet --armor --export "fk inject" | sudo tee /var/lib/fk-inject/key >/dev/null
    sudo rpm --import /var/lib/fk-inject/key
    printf "[fk-inject]\nname=fk-inject\nbaseurl=file:///var/lib/fk-inject/repo\ngpgcheck=1\ngpgkey=file:///var/lib/fk-inject/key\nmetadata_expire=1\n" | sudo tee /etc/yum.repos.d/fk-inject.repo >/dev/null
    sudo fk-inject-pkg fk-inject-a 1.0; sudo fk-inject-pkg fk-inject-b 1.0 req="fk-inject-a"
    sudo dnf install -y -q fk-inject-a fk-inject-b
    sudo dnf -q config-manager setopt "*.includepkgs=fk-inject*"
    mkdir -p ~/.config/fedokawaii; printf "WAIT=180\n" >~/.config/fedokawaii/upkeep.conf' >>"$log" 2>&1 || { row BROKEN "the test repository"; return 1; }
  # (one press with nothing to do: what its steps fetch the first time is then in the state, and every row's press is quick)
  press update
  [[ $INJ_RC == 0 ]] || { row BROKEN "the press with nothing to do: $(tail -n1 <<<"$INJ_OUT")"; return 1; }
  run 'sudo rm -f /tmp/press.rc /tmp/press.out' >>"$log" 2>&1
  bash "$here/vm-snap.sh" "$vm" save inject >>"$log" 2>&1 || { row BROKEN "the state"; return 1; }
  row held "the state inject"
}
# ── what the rows share ──────────────────────────────────────────────────────────────────────
from() {   # from ROW — the VM from "inject", this tree's toolkit in (the theme's files are the state's)
  inj_init "$vm" "$src" "$1"
  inj_from inject
  run --repo "$src" >>"$log" 2>&1 && run 'sudo bash ~/fedokawaii/setup.sh --toolkit' >>"$log" 2>&1 || { row BROKEN "the toolkit"; return 1; }
  run 'sudo rm -f /var/lib/fedokawaii/update/why' >>"$log" 2>&1
}
pk() { run "sudo fk-inject-pkg $*" >>"$log" 2>&1; }
v() { run "rpm -q --qf '%{version}' $1"; }
report() { run "sudo sed -n ${1:-2}p $U/report"; }
said() { [[ $INJ_OUT == *"$1"* ]]; }
desktop() { run 'pgrep -x dwl >/dev/null && pgrep -x waybar >/dev/null'; }
wait_desktop() { local _i; for _i in $(seq 40); do desktop && return 0; sleep 3; done; return 1; }
restart() { run 'sudo systemctl reboot' >>"$log" 2>&1; sleep 25; run --wait 900 >>"$log" 2>&1 && bash "$here/vm-snap.sh" "$vm" nice 10 >>"$log" 2>&1; }
again() { cut_power; sleep 1; restart_vm; }
theiface() { virsh -q -c qemu:///session domiflist "fk-$vm" | awk 'NF { print $1; exit }'; }
link() { virsh -q -c qemu:///session domif-setlink "fk-$vm" "$(theiface)" "$1" >>"$log" 2>&1; }
end_row() {   # end_row held|BROKEN WHAT — the evidence, the row's line, the table
  facts >/dev/null 2>&1
  row "$1" "$2"
  cat "$out/row" >>"$TABLE"
  bash "$here/vm-snap.sh" "$vm" stop >>"$log" 2>&1
  [[ $1 == held ]]
}
ok_if() { if eval "$1"; then end_row held "$2"; else end_row BROKEN "$2 — failed: $1"; fi; }

# ── power cuts (rows 1, 2, 3, 4, 39) ─────────────────────────────────────────────────────────
cut_download() {
  from power-cut-download || return 1; pk fk-inject-a 1.1
  press_bg; phase_is fetch 300 || { end_row BROKEN "never fetched"; return 1; }
  again
  local was; was=$(v fk-inject-a); press
  ok_if '[[ $was == 1.0 && $(v fk-inject-a) == 1.1 && $(report 1) == *" ok" ]] && wait_desktop' "cut while fetching: nothing changed ($was), the next press whole: $(report)"
}
cut_candidate() {
  from power-cut-candidate || return 1; pk fk-inject-a 1.1 post='sleep 30'
  press_bg; phase_is candidate 900 || { end_row BROKEN "never reached the copy"; return 1; }
  sleep 8; again
  local was left; was=$(v fk-inject-a); left=$(run 'sudo btrfs subvolume list / | grep -c root.cand'); press
  ok_if '[[ $was == 1.0 && $(v fk-inject-a) == 1.1 && $(report 1) == *" ok" && $(run "sudo btrfs subvolume list / | grep -c root.cand") == 0 ]]' "cut in the copy: running system untouched, its copy (left: $left) dropped by the next press: $(report)"
}
cut_transaction() {
  from power-cut-transaction || return 1; pk fk-inject-a 1.1 post='sleep 40'; pk fk-inject-b 1.1 req='fk-inject-a = 1.1-1'
  press_bg; phase_is replay 1200 || { end_row BROKEN "never reached the transaction"; return 1; }
  sleep 15; again
  # (the start itself judges it, before the login: not whole → the snapshot back, one restart)
  local _i; for _i in $(seq 60); do [[ $(run "sudo sed -n 1p $U/report 2>/dev/null | cut -d' ' -f2") == restored && $(v fk-inject-a) == 1.0 ]] && break; sleep 5; run --wait 300 >>"$log" 2>&1; done
  ok_if '[[ $(v fk-inject-a) == 1.0 && $(v fk-inject-b) == 1.0 ]] && wait_desktop && run "sudo test -e $U/restored-once"' "cut in the transaction: the system before it back, one restart: $(run 'tail -n1 ~/.local/state/fedokawaii/for-you/update-cut 2>/dev/null')"
}
cut_post() {
  from power-cut-post || return 1; pk fk-inject-a 1.1
  press_bg; phase_is steps 1500 || { end_row BROKEN "never reached the steps"; return 1; }
  sleep 5; again
  local was; was=$(v fk-inject-a); press
  ok_if '[[ $was == 1.1 ]] && [[ $(report 1) == *" ok" ]] && said "its steps and checks again"' "cut in the steps: the next press finishes them, nothing replayed: $(report)"
}
# ── the network, the repositories (rows 5, 19, 36) ───────────────────────────────────────────
network_kill() {
  from network-kill || return 1; pk fk-inject-a 1.1
  press_bg; phase_is fetch 400 || { end_row BROKEN "never fetched"; return 1; }
  link down; press_wait 1800; link up
  local r=$INJ_RC was; was=$(v fk-inject-a)
  ok_if '[[ $r != 0 && $was == 1.0 ]] && [[ $(report) == stopped* ]] && wait_desktop' "the network gone while fetching: exit $r, nothing changed: $(report)"
}
thirdparty_lag() {
  from thirdparty-lag || return 1; pk fk-inject-a 1.1
  run 'printf "[fk-lag]\nname=a lagging one\nbaseurl=http://127.0.0.1:9/nothing\nenabled=1\ngpgcheck=0\n" | sudo tee /etc/yum.repos.d/fk-lag.repo >/dev/null' >>"$log" 2>&1
  press
  ok_if '[[ $INJ_RC == 0 && $(v fk-inject-a) == 1.1 ]] && [[ $(report 1) == *" ok" ]]' "a repository that does not answer left out, the rest in: $(report)"
}
clock() {
  from clock || return 1; pk fk-inject-a 1.1
  run 'sudo timedatectl set-ntp false; sudo date -s "2020-01-02 03:04:05"' >>"$log" 2>&1
  press
  local r=$INJ_RC was; was=$(v fk-inject-a); run 'sudo timedatectl set-ntp true' >>"$log" 2>&1
  ok_if '[[ $(run "date +%Y") != 2020 ]] || said "the clock"' "the clock in 2020: exit $r, $was: $(grep -m1 'clock' <<<"$INJ_OUT")"
}
# ── bad packages (rows 6, 11, 20, 42) ────────────────────────────────────────────────────────
pkg_unsigned() {
  from broken-pkg-unsigned || return 1; pk fk-inject-a 1.1 unsigned
  press
  ok_if '[[ $(v fk-inject-a) == 1.0 ]] && wait_desktop' "an unsigned package: refused (exit $INJ_RC), nothing changed: $(report)"
}
pkg_scriptlet() {
  from broken-pkg-scriptlet || return 1; pk fk-inject-a 1.1 pre='exit 1'; pk fk-inject-b 1.1 req='fk-inject-a >= 1.0'
  press
  local held; held=$(run "sudo cut -d' ' -f1 $U/holds 2>/dev/null | tr '\n' ' '")
  ok_if '[[ $(v fk-inject-a) == 1.0 && $held == *fk-inject-a* && $(run "sudo btrfs subvolume list / | grep -c root.cand") == 0 ]] && wait_desktop' "a failing scriptlet: red in the copy, the running system never saw it, held: $held; $(report)"
}
pkg_conflict() {
  from broken-pkg-conflict || return 1; pk fk-inject-a 1.1 conf='bash'
  press
  ok_if '[[ $(v fk-inject-a) == 1.0 ]] && rpm -q bash >/dev/null && wait_desktop' "a package that conflicts with bash: not in, bash kept (exit $INJ_RC): $(report)"
}
pkg_tampered() {
  from broken-pkg-tampered || return 1; pk fk-inject-a 1.1
  press_bg; phase_is candidate 900 || { end_row BROKEN "never reached the copy"; return 1; }
  run "sudo sh -c 'for f in $U/tx/packages/*.rpm; do printf x | dd of=\"\$f\" bs=1 seek=2000 conv=notrunc 2>/dev/null; done'" >>"$log" 2>&1
  press_wait 1800
  ok_if '[[ $(v fk-inject-a) == 1.0 ]] && wait_desktop' "a stored package changed after its download: never in (exit $INJ_RC): $(report)"
}
# ── no room (rows 7, 8, 9, 37) ───────────────────────────────────────────────────────────────
disk_full() {
  from disk-full || return 1; pk fk-inject-a 1.1
  run 'f=$(($(df --output=avail -B1 / | tail -n1) - 10 * 1024 ** 3)); sudo fallocate -l "$f" /var/tmp/fill' >>"$log" 2>&1
  press
  ok_if 'said "free on /" && [[ $INJ_RC != 0 && $(v fk-inject-a) == 1.0 ]] && wait_desktop' "ten gigabytes left: refused, nothing changed: $(report)"
}
disk_unalloc() {
  from disk-full-metadata || return 1; pk fk-inject-a 1.1
  # (chunks allocated, the space then freed: free is plenty, nothing unallocated — Btrfs's own trap)
  run 'f=$(($(sudo btrfs filesystem usage -b / | awk "/Device unallocated:/ { print \$3 }") - 2 * 1024 ** 3)); sudo dd if=/dev/zero of=/var/tmp/fill bs=64M count=$((f / (64 * 1024 ** 2))) status=none; sync; sudo rm /var/tmp/fill; sync; sudo btrfs filesystem usage -b / | grep -E "unallocated|Free .estimated"' >>"$log" 2>&1
  press
  ok_if 'said "unallocated" && [[ $(v fk-inject-a) == 1.0 ]]' "free space but nothing unallocated: refused (exit $INJ_RC): $(grep -m1 unallocated <<<"$INJ_OUT")"
}
boot_full() {
  from boot-full || return 1; pk fk-inject-a 1.1
  run 'f=$(($(df --output=avail -B1 /boot | tail -n1) - 200 * 1024 ** 2)); sudo fallocate -l "$f" /boot/fill' >>"$log" 2>&1
  press
  ok_if 'said "free on /boot" && [[ $INJ_RC != 0 && $(v fk-inject-a) == 1.0 ]]' "/boot nearly full: refused, nothing changed: $(report)"
}
snapper_broken() {
  from snapper-broken || return 1; pk fk-inject-a 1.1
  run 'sudo mv /usr/bin/snapper /usr/bin/snapper.off' >>"$log" 2>&1
  press
  local was; was=$(v fk-inject-a); run 'sudo mv /usr/bin/snapper.off /usr/bin/snapper' >>"$log" 2>&1
  ok_if 'said "could not be taken" && [[ $INJ_RC != 0 && $was == 1.0 ]]' "no snapshot to be had: stopped before any change: $(report)"
}
rpmdb_damage() {
  from rpmdb-damage || return 1; pk fk-inject-a 1.1
  # (a page of rpm's database overwritten, as a bad sector or a crash in the wrong place leaves it)
  run 'sudo sh -c "dd if=/dev/urandom of=/var/lib/rpm/rpmdb.sqlite bs=4096 seek=200 count=8 conv=notrunc 2>/dev/null; rm -f /var/lib/rpm/rpmdb.sqlite-wal /var/lib/rpm/rpmdb.sqlite-shm"; sync' >>"$log" 2>&1
  press
  ok_if 'said "rpm" && rpm -qa >/dev/null' "rpm's database damaged: exit $INJ_RC: $(grep -m1 "rpm's database" <<<"$INJ_OUT"): $(report)"
}
# ── red in the copy, red on the running system (rows 12, 14, 17, 31, 40) ─────────────────────
broken_lib() {
  from broken-lib || return 1
  pk fk-inject-a 1.1 posttrans='rm -f /usr/lib64/libxkbcommon.so.0 /usr/lib64/libxkbcommon.so.0.*'
  press
  local held; held=$(run "sudo cut -d' ' -f1 $U/holds 2>/dev/null | tr '\n' ' '")
  ok_if '[[ $(v fk-inject-a) == 1.0 && $held == *fk-inject-a* ]] && run "ls /usr/lib64/libxkbcommon.so.0 >/dev/null" && wait_desktop' "a library our builds link gone in the copy: held: $held; the running system untouched; $(report)"
}
broken_session() {   # (the copy cannot start a desktop: the live check after the transaction sees it)
  from broken-session || return 1
  pk fk-inject-a 1.1 posttrans='test -d /run/fedokawaii/top && chmod 000 /usr/bin/waybar || :'
  press
  local end line; end=$(report 1); line=$(report)
  restart; wait_desktop
  ok_if '[[ $end == *" restored" && $(v fk-inject-a) == 1.0 ]] && run "test -x /usr/bin/waybar" && desktop' "the bar does not start on the running system: $line; at the restart the system before it, the desktop up"
}
broken_mesa() {
  from broken-mesa || return 1
  pk fk-inject-a 1.1 posttrans='test -d /run/fedokawaii/top && { for f in /usr/lib64/libEGL.so.1*; do [ -f "$f" ] && : >"$f"; done; } || :'
  press
  local end line; end=$(report 1); line=$(report)
  restart; wait_desktop
  ok_if '[[ $end == *" restored" && $(v fk-inject-a) == 1.0 ]] && desktop' "Mesa's libEGL empty on the running system: $line; at the restart the system before it, the desktop up"
}
bls_broken() {
  from bls-broken || return 1
  pk fk-inject-a 1.1 posttrans='test -d /run/fedokawaii/top && sed -i "s/ root=[^ ]*//" /boot/loader/entries/*.conf || :'
  press
  local end line; end=$(report 1); line=$(report)
  restart
  ok_if '[[ $end == *" restored" && $(v fk-inject-a) == 1.0 ]] && run "sudo grep -q root= /boot/loader/entries/*.conf" && wait_desktop' "a boot entry without root=: $line; it started, the entries whole again"
}
verify_broken() {
  from verify-broken || return 1; pk fk-inject-a 1.1
  press_bg; phase_is steps 1500 || { end_row BROKEN "never reached the steps"; return 1; }
  run 'sudo sh -c "printf \"exit 1\n\" >/usr/local/lib/fedokawaii/verify.sh"' >>"$log" 2>&1
  press_wait 1800
  local end line; end=$(report 1); line=$(report); restart
  ok_if '[[ $end == *" restored" && $(v fk-inject-a) == 1.0 ]] && wait_desktop' "verify itself broken: red, never green: $line"
}
# ── the system before it, and back (rows 18, 23, 24, 25) ─────────────────────────────────────
roundtrip() {
  from rollback || return 1; pk fk-inject-a 1.1; pk fk-inject-b 1.1 pre='exit 1' req='fk-inject-a'
  press    # (a in, b held)
  local n held; n=$(run "sudo cat $U/snap"); held=$(run "sudo cut -d' ' -f1 $U/holds | tr '\n' ' '")
  [[ $(v fk-inject-a) == 1.1 && $held == *fk-inject-b* ]] || { end_row BROKEN "the press before it: a $(v fk-inject-a), held: $held"; return 1; }
  run 'echo mine >~/after-the-update' >>"$log" 2>&1
  run "sudo /usr/local/sbin/kawa-snap restore $n" >>"$log" 2>&1 || { end_row BROKEN "kawa-snap restore $n"; return 1; }
  restart; wait_desktop
  local a1 home rel auto; a1=$(v fk-inject-a); home=$(run 'cat ~/after-the-update')
  rel=$(run 'sudo restorecon -R -n -v /etc /usr/local /var/lib/fedokawaii 2>/dev/null | wc -l'); auto=$(run 'test -e /.autorelabel && echo yes || echo no')
  # (the next press finds the holds again: fk, not the restored /etc)
  press; local h2; h2=$(run "sudo cat /etc/dnf/versionlock.toml 2>/dev/null | grep -c fk-inject-b"); local a2; a2=$(v fk-inject-a)
  run 'sudo /usr/local/sbin/kawa-snap restore old' >>"$log" 2>&1 || { end_row BROKEN "kawa-snap restore old"; return 1; }
  restart; wait_desktop
  local a3; a3=$(v fk-inject-a)
  ok_if '[[ $a1 == 1.0 && $home == mine && $auto == no && $h2 -ge 1 ]] && desktop' "restored: a $a1, his file kept ($home), labels off: $rel, autorelabel: $auto, holds back: $h2, press then a $a2; restore old: a $a3"
}
# ── the run itself (rows 26, 27, 28, 29, 30) ─────────────────────────────────────────────────
lock_held() {
  from lock-held || return 1; pk fk-inject-a 1.1
  run 'cp /usr/bin/sleep /tmp/dnf5; setsid -f /tmp/dnf5 600 </dev/null >/dev/null 2>&1' >>"$log" 2>&1
  press
  ok_if 'said "another package manager is running (dnf5)" && [[ $INJ_RC != 0 && $(v fk-inject-a) == 1.0 ]]' "another package manager at work: said: $(report)"
}
stale_offline() {
  from stale-offline || return 1; pk fk-inject-a 1.1
  run 'sudo ln -sfn /var/lib/dnf/offline /system-update' >>"$log" 2>&1
  press; local r=$INJ_RC w; w=$(report)
  restart; press
  ok_if '[[ $r != 0 && $(v fk-inject-a) == 1.1 ]] && wait_desktop' "a stale offline mark: \"$w\"; restarted: $(report)"
}
close_window() {
  from close-window || return 1; pk fk-inject-a 1.1
  press_bg; phase_is candidate 900 || { end_row BROKEN "never reached the copy"; return 1; }
  run 'sudo pkill -f "fedokawaii.sh update"; sudo pkill -x tail' >>"$log" 2>&1
  local _i; for _i in $(seq 360); do run 'systemctl is-active --quiet fedokawaii-update.service' || break; sleep 5; done
  ok_if '[[ $(v fk-inject-a) == 1.1 && $(report 1) == *" ok" ]]' "the window closed mid-run: the unit went on: $(report)"
}
inhibit() {
  from inhibit || return 1; pk fk-inject-a 1.1 post='sleep 25'; pk fk-inject-b 1.1 req='fk-inject-a = 1.1-1'
  press_bg; phase_is replay 1200 || { end_row BROKEN "never reached the transaction"; return 1; }
  sleep 6
  local list off; list=$(run 'systemd-inhibit --list --no-pager 2>/dev/null | grep -iE "dnf|rpm|fedokawaii" | head -n 3'); off=$(run 'systemctl poweroff 2>&1 | head -n 2; true')
  printf '%s\n' "$list" "$off" >"$out/inhibit.txt"
  press_wait 1800
  ok_if '[[ -n $list && $(v fk-inject-a) == 1.1 ]]' "the power button in the transaction: blocked: $(tr -s ' ' <<<"$list" | head -n1): as you: $(head -n1 <<<"$off")"
}
toolkit_bad() {
  from toolkit-bad || return 1; pk fk-inject-a 1.1
  # a GitHub of its own: a bare repository with a tag whose update.sh does not parse
  run 'set -e; rm -f /tmp/fk-origin; sudo rm -f /var/lib/fedokawaii/toolkit-from-copy; cd ~/fedokawaii; git init -q -b main . 2>/dev/null; git add -A >/dev/null; git -c user.name=t -c user.email=t@t commit -q -m t >/dev/null
    git clone -q --bare . /tmp/fk-origin.git; printf "if\n" >>lib/update.sh; git -c user.name=t -c user.email=t@t commit -qam bad; git tag v2099.1.1; git push -q /tmp/fk-origin.git HEAD:refs/heads/main v2099.1.1; chmod -R a+rX /tmp/fk-origin.git' >>"$log" 2>&1 || { end_row BROKEN "the fake GitHub"; return 1; }
  local a=(systemd-run --quiet --wait --collect --unit=fk-inject-press -p SELinuxContext=system_u:system_r:unconfined_service_t:s0 --setenv=FEDOKAWAII_ORIGIN=file:///tmp/fk-origin.git --setenv=FK_TERM=dumb /usr/bin/bash /usr/local/lib/fedokawaii/setup.sh --update)
  run "sudo ${a[*]} >/tmp/press.out 2>&1; echo \$? >/tmp/press.rc" >>"$log" 2>&1
  press_words; run "sudo cat $U/toolkit-red" >"$out/toolkit-red" 2>&1
  ok_if '[[ $(cat "$out/toolkit-red") == v2099.1.1 ]] && [[ $(v fk-inject-a) == 1.1 ]] && run "bash -n /usr/local/lib/fedokawaii/lib/update.sh"' "a release that does not parse: refused, the update went on with the toolkit it had: $(report)"
}
toolkit_good() {   # (its real torture suite in the VM's fake machine; the run then from the new toolkit)
  from toolkit-good || return 1; pk fk-inject-a 1.1
  run 'set -e; sudo rm -f /var/lib/fedokawaii/toolkit-from-copy; cd ~/fedokawaii; git init -q -b main . 2>/dev/null; echo mark >RELEASE-MARK; git add -A >/dev/null; git -c user.name=t -c user.email=t@t commit -q -m t >/dev/null
    git tag v2099.1.2; git clone -q --bare . /tmp/fk-origin.git; chmod -R a+rX /tmp/fk-origin.git' >>"$log" 2>&1 || { end_row BROKEN "the fake GitHub"; return 1; }
  local a=(systemd-run --quiet --wait --collect --unit=fk-inject-press -p SELinuxContext=system_u:system_r:unconfined_service_t:s0 --setenv=FEDOKAWAII_ORIGIN=file:///tmp/fk-origin.git --setenv=FK_TERM=dumb /usr/bin/bash /usr/local/lib/fedokawaii/setup.sh --update)
  local s=$SECONDS; run "sudo ${a[*]} >/tmp/press.out 2>&1; echo \$? >/tmp/press.rc" >>"$log" 2>&1
  press_words
  ok_if 'run "test -e /usr/local/lib/fedokawaii/RELEASE-MARK" && [[ $(run "sudo cat /var/lib/fedokawaii/toolkit-release") == v2099.1.2 && $(v fk-inject-a) == 1.1 && $(report) == *"fedokawaii v2099.1.2"* ]]' "a good release: checked, installed, the run from it in $((SECONDS - s)) s: $(report)"
}
# ── a held package with a security advisory (row 34) ─────────────────────────────────────────
advisory() {
  from advisory || return 1; pk fk-inject-a 1.1 pre='exit 1'
  # shellcheck disable=SC2016
  run 'cat >/tmp/updateinfo.xml <<X
<updates><update from="fk" status="stable" type="security" version="1"><id>FK-2026-1</id><title>a test</title><issued date="2026-11-01 00:00:00"/><severity>Important</severity><description>a test</description><pkglist><collection short="fk"><name>fk</name><package name="fk-inject-a" version="1.1" release="1" epoch="0" arch="noarch"><filename>fk-inject-a-1.1-1.noarch.rpm</filename></package></collection></pkglist></update></updates>
X
sudo modifyrepo_c --mdtype=updateinfo /tmp/updateinfo.xml /var/lib/fk-inject/repo/repodata' >>"$log" 2>&1
  press
  ok_if '[[ $(report) == *"a security fix waits among the held: 1"* ]]' "a held package with a security fix: said: $(report)"
}
# ── backups: a drive plugged in, a backup, a file lost, the file back (T48) ──────────────────
backup_drive() {
  from backup-drive || return 1
  local img=$out/usb.img; qemu-img create -q -f raw "$img" 2G
  virsh -q -c qemu:///session attach-disk "fk-$vm" "$img" sdz --targetbus usb --driver qemu --subdriver raw --live >>"$log" 2>&1 \
    || { end_row BROKEN "the drive could not be plugged in"; return 1; }
  sleep 5
  # shellcheck disable=SC2016
  run 'd=$(lsblk -dpno NAME,TRAN | awk "\$2 == \"usb\" { print \$1; exit }"); [ -n "$d" ] && sudo mkfs.ext4 -q -L FKTEST "$d"; sudo udevadm settle
    sudo sed -i "s/^BACKUP_TARGET=[^ ]*/BACKUP_TARGET=\"FKTEST\"/" /usr/local/lib/fedokawaii/fedokawaii.conf; grep -n "^BACKUP_TARGET" /usr/local/lib/fedokawaii/fedokawaii.conf
    install -m 600 /dev/null ~/.config/fedokawaii/secrets.sh; echo "RESTIC_PASSWORD=\"a test only\"" >~/.config/fedokawaii/secrets.sh
    mkdir -p ~/Notes; echo "the first words" >~/Notes/lost.md' >>"$log" 2>&1
  # shellcheck disable=SC2016
  local e='export XDG_RUNTIME_DIR=/run/user/$(id -u) DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus PATH=$HOME/.local/bin:$PATH; '
  run "$e kawa-backup" >"$out/backup.out" 2>&1; local r1=$?
  local list; list=$(run "$e kawa-backup list" 2>&1)
  run 'rm ~/Notes/lost.md' >>"$log" 2>&1
  run "$e kawa-backup restore \$HOME/Notes/lost.md" >"$out/restore.out" 2>&1; local r2=$?
  local back; back=$(run 'cat ~/Restored/*/Notes/lost.md 2>/dev/null || find ~/Restored -name lost.md -exec cat {} +')
  # (the plug pulled while open: nothing hangs, the next backup says it is not there)
  virsh -q -c qemu:///session detach-disk "fk-$vm" sdz --live >>"$log" 2>&1; sleep 5
  local gone; gone=$(run "$e timeout 60 kawa-backup where" 2>&1)
  rm -f "$img"
  ok_if '[[ $r1 == 0 && $r2 == 0 && $back == "the first words" ]]' "a backup to a USB drive (exit $r1), $(wc -l <<<"$list") listed, the file back in ~/Restored (exit $r2: $back); plug pulled: $gone"
}
ALL=(cut_download cut_candidate cut_transaction cut_post network_kill thirdparty_lag clock pkg_unsigned pkg_scriptlet pkg_conflict pkg_tampered
     disk_full disk_unalloc boot_full snapper_broken rpmdb_damage broken_lib broken_session broken_mesa bls_broken verify_broken roundtrip
     lock_held stale_offline close_window inhibit toolkit_bad toolkit_good advisory backup_drive)
if [[ ${1:-} == base ]]; then base; exit $?; fi
rows=("$@"); ((${#rows[@]})) || rows=("${ALL[@]}")
bad=0
for r in "${rows[@]}"; do
  declare -F "$r" >/dev/null || { echo "run-all: no row $r (${ALL[*]})" >&2; exit 2; }
  "$r" || bad=1
done
exit "$bad"
