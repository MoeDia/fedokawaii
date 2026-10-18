#!/usr/bin/env bash
# tests/engine/test_hygiene.sh — lib/hygiene.sh, the scan verify shows and repair acts on:
# each function on a made-up machine (its /etc, /usr/local/lib and /var/tmp in the test's
# folder, dnf and systemctl as stand-ins). Every function must answer, never fail: setup.sh
# reads them under errexit, so one that failed would end an update or a repair.
. "$(dirname "$0")/lib.sh"

fresh() {
  sandbox
  FS=$TMP/fs; mkdir -p "$FS/etc/systemd/system" "$FS/usr/local/lib" "$FS/var/tmp" "$FS/usr/lib/systemd/system"
  local me=() ; [[ $(id -un) == root ]] || me=("s|-user root |-user $(id -un) |")   # (root's leftovers: yours, here)
  pointed "$REPO/lib/hygiene.sh" "$TMP/hygiene.sh" \
    "s|find /etc |find $FS/etc |" "s|/etc/systemd/system/display-manager.service|$FS/etc/systemd/system/display-manager.service|" \
    "s|/usr/local/lib/fedokawaii|$FS/usr/local/lib/fedokawaii|g" \
    "s|find /var/tmp |find $FS/var/tmp |" "${me[@]}"
  # shellcheck source=/dev/null
  . "$TMP/hygiene.sh"
  # systemctl: the states in $TMP/units ("UNIT STATE ACTIVE", user units in $TMP/user-units)
  : >"$TMP/units"; : >"$TMP/user-units"
  stub systemctl 'f="'"$TMP"'/units"; [ "$1" = --user ] && { f="'"$TMP"'/user-units"; shift; }
verb=$1; shift; [ "$1" = --quiet ] && { q=1; shift; }; u=$1
line=$(grep "^$u " "$f"); st=$(echo "$line" | cut -d" " -f2); act=$(echo "$line" | cut -d" " -f3)
case $verb in
  is-enabled) [ -n "$st" ] || { [ -n "$q" ] || echo not-found; exit 4; }
              [ -n "$q" ] || echo "$st"
              case $st in enabled|enabled-runtime|static|alias|indirect|generated|transient) exit 0 ;; *) exit 1 ;; esac ;;
  is-active)  [ "$act" = active ] && exit 0; exit 3 ;;
esac'
  stub dnf
}
as_user() { "$@"; }                                   # (setup.sh's: here, the same user)
unit() { echo "$1 $2 ${3:-inactive}" >>"$TMP/units"; }
user_unit() { echo "$1 $2 ${3:-inactive}" >>"$TMP/user-units"; }
strict() { ( set -Eeuo pipefail; IFS=$'\n\t'; "$@" ); }   # (as setup.sh calls them)

# ── packages ─────────────────────────────────────────────────────────────────
case_ "hy_duplicates: what dnf lists twice, by name-version.arch"
fresh; stub dnf 'printf "%s\n" bash-5.2.37-1.fc44.x86_64 bash-5.3.0-1.fc44.x86_64'
eq "$(hy_duplicates)" $'bash-5.2.37-1.fc44.x86_64\nbash-5.3.0-1.fc44.x86_64'
called '^dnf -q repoquery --duplicates --qf %\{name\}-%\{evr\}\.%\{arch\}'
case_ "hy_duplicates: dnf failing or missing — nothing, and no failure"
stub dnf 'echo "Error: Failed to obtain rpm transaction lock" >&2; exit 1'
eq "$(strict hy_duplicates)" ""; eq "$?" 0
eq "$(without dnf -- bash -c '. "$1"; set -e; hy_duplicates; echo ok' _ "$TMP/hygiene.sh" 2>&1)" ok
case_ "hy_dnf_problems: dnf check's lines (blank ones dropped), its errors too"
fresh; stub dnf 'printf "%s\n\n  %s\n" "Problem: package foo-1-1.fc44.x86_64 requires libbar.so.1" "broken dependency"; echo "warning: rpmdb" >&2; exit 1'
out=$(strict hy_dnf_problems); eq "$?" 0
eq "$out" $'Problem: package foo-1-1.fc44.x86_64 requires libbar.so.1\n  broken dependency\nwarning: rpmdb'
called '^dnf -q check'
case_ "hy_dnf_problems: all in order — nothing"
stub dnf 'exit 0'; eq "$(hy_dnf_problems)" ""
case_ "hy_unneeded: names once each, sorted; offline (dnf failing) — nothing"
fresh; stub dnf 'printf "%s\n" zlib-ng libfoo zlib-ng abc'
eq "$(hy_unneeded)" $'abc\nlibfoo\nzlib-ng'; called '^dnf -q repoquery --unneeded'
stub dnf 'echo "Failed to download metadata" >&2; exit 1'; eq "$(strict hy_unneeded)" ""; eq "$?" 0

# ── services ─────────────────────────────────────────────────────────────────
case_ "hy_services: enabled or running — each with what it fights"
fresh; unit power-profiles-daemon.service enabled; unit iwd.service disabled active; unit gdm.service disabled
unit sddm.service masked; unit systemd-networkd.service disabled
out=$(strict hy_services); eq "$?" 0
has "$out" "power-profiles-daemon.service|tuned, the performance profile"
has "$out" "iwd.service|NetworkManager's Wi-Fi"
lacks "$out" gdm; lacks "$out" sddm "masked is off for good"; lacks "$out" networkd
eq "$(wc -l <<<"$out")" 2
case_ "hy_services: a unit with no [Install] (static) counts only while it runs"
fresh; unit lightdm.service static
eq "$(hy_services)" "" "a static unit is not enabled, though is-enabled answers 0 for it"
unit iwd.service static active; has "$(hy_services)" "iwd.service|"
case_ "hy_services: nothing installed — nothing"
fresh; eq "$(strict hy_services)" ""
case_ "hy_user_services: your notification and sound daemons, the same way"
fresh; user_unit dunst.service static; user_unit swaync.service enabled; user_unit pulseaudio.socket enabled-runtime
out=$(hy_user_services)
lacks "$out" dunst "dunst is D-Bus activated (static): only a running one fights mako"
has "$out" "swaync.service|mako"; has "$out" "pulseaudio.socket|PipeWire"
fresh; user_unit dunst.service static active; has "$(hy_user_services)" "dunst.service|mako: only one program can show notifications"
called '^systemctl --user is-active --quiet dunst.service'
case_ "hy_user_services: your systemd not answering — nothing, no failure"
fresh; stub systemctl 'echo "Failed to connect to bus" >&2; exit 1'; eq "$(strict hy_user_services)" ""; eq "$?" 0

# ── the login ────────────────────────────────────────────────────────────────
case_ "hy_display_manager: the unit display-manager.service points at"
fresh; L=$FS/etc/systemd/system/display-manager.service
ln -s /usr/lib/systemd/system/greetd.service "$L"; eq "$(hy_display_manager)" greetd.service
ln -sfn ../../../usr/lib/systemd/system/gdm.service "$L"; eq "$(hy_display_manager)" gdm.service "a relative link"
rm "$L"; eq "$(strict hy_display_manager)" "" "none at all"; eq "$?" 0
: >"$L"; eq "$(strict hy_display_manager)" "" "a plain file, not a link"

# ── files ────────────────────────────────────────────────────────────────────
case_ "hy_rpmnew: every .rpmnew and .rpmsave under /etc, sorted; others left out"
fresh; mkdir -p "$FS/etc/ssh" "$FS/etc/my dir"
: >"$FS/etc/ssh/sshd_config.rpmnew"; : >"$FS/etc/my dir/a b.conf.rpmsave"; : >"$FS/etc/dnf.conf"; : >"$FS/etc/x.rpmnew.bak"
eq "$(hy_rpmnew)" "$FS/etc/my dir/a b.conf.rpmsave"$'\n'"$FS/etc/ssh/sshd_config.rpmnew"
case_ "hy_rpmnew: none — nothing; a folder it may not read — no failure"
fresh; eq "$(strict hy_rpmnew)" ""
mkdir -p "$FS/etc/private"; : >"$FS/etc/private/z.rpmnew"; chmod 000 "$FS/etc/private"
strict hy_rpmnew >/dev/null 2>&1; eq "$?" 0; chmod 755 "$FS/etc/private"
case_ "hy_leftovers: a half-made toolkit, the one before it, temp folders of runs over a day old"
fresh; mkdir -p "$FS/usr/local/lib/fedokawaii" "$FS/usr/local/lib/fedokawaii.new" "$FS/usr/local/lib/fedokawaii.old" "$FS/var/tmp/fedokawaii.old1" "$FS/var/tmp/fedokawaii.live" "$FS/var/tmp/other.x"
touch -d '-2 days' "$FS/var/tmp/fedokawaii.old1" "$FS/var/tmp/other.x"
out=$(strict hy_leftovers); eq "$?" 0
has "$out" "$FS/usr/local/lib/fedokawaii.new"; has "$out" "$FS/usr/local/lib/fedokawaii.old"; has "$out" "$FS/var/tmp/fedokawaii.old1"
lacks "$out" "fedokawaii.live" "a running update's own temp folder"; lacks "$out" other.x
case_ "hy_leftovers: the one before alone (an update cut off as it replaced the toolkit) — not a leftover: it is the toolkit"
fresh; mkdir -p "$FS/usr/local/lib/fedokawaii.old"; lacks "$(strict hy_leftovers)" fedokawaii.old
case_ "hy_leftovers: nothing left — nothing, and no failure"
fresh; eq "$(strict hy_leftovers)" ""; eq "$?" 0

case_ "the conflict lists: each entry UNIT|reason, units that exist in Fedora's naming"
for e in "${CONFLICT_SERVICES[@]}" "${CONFLICT_USER_SERVICES[@]}"; do
  [[ $e =~ ^[a-z0-9-]+\.(service|socket)\|[^|]+$ ]] && _ok || _no "malformed: $e"
done

done_
