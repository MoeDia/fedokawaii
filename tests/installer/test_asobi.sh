#!/usr/bin/env bash
# tests/installer/test_asobi.sh — lib/asobi.sh on the fake Fedora: the play world made from nothing (its user
# locked, its home a subvolume, its units with the real uid, its polkit rule yours, Bottles' unit the mirror of
# Steam's, the Flatpaks per user, clean taken once), made again (nothing doubled), no Btrfs (no world, said), and
# Steam leaving your account: games and saves in the world, nothing played on in there overwritten, your account
# clean, the saves' backup kept. The walls themselves are tried for real by tools/asobi-proof.sh.
. "$(dirname "$0")/lib.sh"
STEP=/home/fkuser/fedokawaii/tools/asobi-step.sh
step() { fkrun bash "$STEP" "$@"; }
reflinkless() {   # (the fake machine's disk may not clone: production's /home is Btrfs, checked first)
  printf '#!/bin/bash\na=(); for x; do [[ $x == --reflink=always ]] || a+=("$x"); done; exec /usr/bin/cp "${a[@]}"\n' >"$W/usr/local/bin/cp"
  chmod 755 "$W/usr/local/bin/cp"
}

world built --themed
case_ "made from nothing: every part, with the real uid, the real desktop user"
step s_asobi; eq "$RC" 0 "$OUT"
grep -q '^asobi:.*:/home/asobi:/usr/sbin/nologin$' "$W/etc/passwd" && _ok || _no "no asobi in passwd: $(grep asobi "$W/etc/passwd")"
for g in wheel sudo; do lacks "$(grep "^$g:" "$W/etc/group")" asobi "asobi in $g"; done
for v in /home/asobi /home/.asobi/drop /home/.asobi/snapshots/clean; do fk grep -qx "$v" /var/lib/fkh/subvolumes && _ok || _no "no subvolume $v"; done
u=$(awk -F: '$1 == "asobi" { print $3 }' "$W/etc/passwd")
for f in kawa-asobi.service kawa-asobi-bottles.service kawa-asobi-watch.service kawa-asobi-op@.service "user@$u.service.d/50-kawa-asobi.conf"; do
  [[ -s $W/etc/systemd/system/$f ]] && _ok || _no "no $f"
  lacks "$(cat "$W/etc/systemd/system/$f" 2>/dev/null)" ASOBI_UID "$f: the uid not filled in"
done
has "$(cat "$W/etc/systemd/system/user@$u.service.d/50-kawa-asobi.conf")" "BindPaths=/run/user/$u"
case_ "the walls on the world's own manager alone: what an early build left on every user@ goes"
[[ ! -e $W/etc/systemd/system/user@.service.d/50-kawa-asobi.conf ]] && _ok || _no "walls on every user's manager"
mkdir -p "$W/etc/systemd/system/user@.service.d"; echo '[Service]' >"$W/etc/systemd/system/user@.service.d/50-kawa-asobi.conf"
step asobi_system; eq "$RC" 0 "$OUT"
[[ ! -e $W/etc/systemd/system/user@.service.d/50-kawa-asobi.conf ]] && _ok || _no "the old drop-in stayed: the desktop's manager would not start"
grep -q 'user@\.service\.d' "$W/etc/systemd/system/kawa-asobi.service" && _no "the session names the template" || _ok
case_ "no number of its own (empty, or the desktop's): nothing written, the walls can never land on your manager"
desk=$(awk -F: '$1 == "fkuser" { print $3 }' "$W/etc/passwd")
for n in "" "$desk"; do
  printf '#!/bin/bash\n[[ $* == "-u asobi" ]] && { echo -n "%s"; exit 0; }\nexec /usr/bin/id "$@"\n' "$n" >"$W/usr/local/bin/id"; chmod 755 "$W/usr/local/bin/id"
  rm -f "$W/etc/systemd/system/kawa-asobi.service"
  step asobi_system; [[ $RC -ne 0 ]] && _ok || _no "went on with the number \"$n\""
  has "$OUT" "its walls would land on your manager"
  [[ ! -e $W/etc/systemd/system/user@.service.d/50-kawa-asobi.conf && ! -e $W/etc/systemd/system/user@$desk.service.d/50-kawa-asobi.conf && ! -e $W/etc/systemd/system/kawa-asobi.service ]] && _ok || _no "written all the same with the number \"$n\""
done
rm -f "$W/usr/local/bin/id"; step asobi_system; eq "$RC" 0 "$OUT"
has "$(cat "$W/etc/polkit-1/rules.d/60-kawa-asobi.rules")" 'subject.user == "fkuser"'
for f in rules/kawa-asobi symbols/kawa-asobi types/kawa-asobi; do [[ -s $W/etc/xkb/$f ]] && _ok || _no "no xkb $f"; done
[[ -s $W/etc/systemd/user/kawa-asobi-world.service && -s $W/etc/pam.d/kawa-asobi && -s $W/etc/gamemode.ini ]] && _ok || _no "a file missing"
[[ -x $W/usr/local/sbin/kawa-asobi-root && -x $W/usr/local/bin/kawa-asobi-session && -x $W/usr/local/bin/kawa-asobi-world && -x $W/usr/local/bin/kawa-asobi-splash ]] && _ok || _no "a program missing"
case_ "Bottles' unit is Steam's, mirrored: each conflicts with the other, the stop going first"
b=$(cat "$W/etc/systemd/system/kawa-asobi-bottles.service"); s=$(cat "$W/etc/systemd/system/kawa-asobi.service")
has "$b" 'KAWA_ASOBI_FACE=bottles'; has "$s" 'KAWA_ASOBI_FACE=steam'
has "$b" 'Conflicts=getty@tty8.service kawa-asobi.service'; has "$s" 'Conflicts=getty@tty8.service kawa-asobi-bottles.service'
grep -q '^After=.*kawa-asobi-bottles\.service' <<<"$s" && _ok || _no "the faces in no order: one would start before the other stopped"
grep -q '^After=.*kawa-asobi\.service' <<<"$b" && _no "the faces ordered both ways: stopping the two is a cycle" || _ok
case_ "the Flatpaks: per user, from Flathub, both, kept off what is not theirs; no system-wide remote"
called '^asobi\[flatpak\] --user remote-add --if-not-exists flathub https://dl.flathub.org/'
called '^asobi\[flatpak\] --user install .*com.valvesoftware.Steam com.usebottles.bottles'
called '^asobi\[flatpak\] --user override com.valvesoftware.Steam .*--nofilesystem=/mnt .*--filesystem=/home/.asobi/drop'
called 'systemctl\] mask .*flatpak-add-fedora-repos.service'
case_ "the drop folder: a group of two, set-group-id; the snapshots root's; your link to it"
eq "$(fk stat -c %a:%G /home/.asobi/drop)" 2770:asobi-drop
eq "$(fk stat -c %a:%U /home/.asobi/snapshots)" 700:root
has "$(grep '^asobi-drop:' "$W/etc/group")" fkuser
eq "$(fk readlink /home/fkuser/Drop)" /home/.asobi/drop

case_ "made again: nothing doubled, clean kept as it was"
reset_calls; step s_asobi; eq "$RC" 0 "$OUT"
not_called '\[useradd\]'; not_called '\[groupadd\]'; not_called '\[btrfs\] subvolume (create|snapshot)'
eq "$(grep -c '^asobi:' "$W/etc/passwd")" 1

world built --themed
case_ "no Btrfs under /home: no world, and it says why"
fkh fstype-_home xfs
sed -i '/^asobi:/d' "$W/etc/passwd"; fk sed -i '/^asobi:/d' /etc/shadow
step asobi_account; eq "$RC" 1 "$OUT"; has "$OUT" "/home on Btrfs"
grep -q '^asobi:' "$W/etc/passwd" && _no "the user was made" || _ok

world built --themed
reflinkless
case_ "Steam leaves your account: games and saves in the world, your account clean, the saves' backup kept"
step asobi_account asobi_drop asobi_system; eq "$RC" 0 "$OUT"
S=$W/home/fkuser/.local/share/Steam Wd=$W/home/asobi/.var/app/com.valvesoftware.Steam/.local/share/Steam
mkdir -p "$S/steamapps/common/Game" "$S/steamapps/compatdata/7/pfx" "$S/userdata/1" "$S/config" "$W/home/fkuser/.steam" "$W/home/fkuser/blasphemous-save-backup-20261022"
echo game >"$S/steamapps/common/Game/g"; echo old-save >"$S/steamapps/compatdata/7/pfx/save"; echo vdf >"$S/config/config.vdf"; echo keep >"$W/home/fkuser/blasphemous-save-backup-20261022/s"
fk chown -R fkuser:fkuser /home/fkuser/.local /home/fkuser/.steam /home/fkuser/blasphemous-save-backup-20261022
# (played on in the world already: that save is newer than the one here; played here after an earlier copy: this one newer than the world's)
mkdir -p "$Wd/steamapps/compatdata/7/pfx" "$Wd/steamapps/compatdata/8/pfx" "$S/steamapps/compatdata/8/pfx"
echo new-save >"$Wd/steamapps/compatdata/7/pfx/save"; touch -d '+1 hour' "$Wd/steamapps/compatdata/7/pfx/save"
echo earlier-copy >"$Wd/steamapps/compatdata/8/pfx/save"; touch -d '-1 hour' "$Wd/steamapps/compatdata/8/pfx/save"
echo played-here >"$S/steamapps/compatdata/8/pfx/save"; fk chown -R fkuser:fkuser /home/fkuser/.local
step asobi_host_out; eq "$RC" 0 "$OUT"
eq "$(cat "$Wd/steamapps/common/Game/g")" game "the game did not move"
eq "$(cat "$Wd/steamapps/compatdata/7/pfx/save")" new-save "a save played on in the world was overwritten"
eq "$(cat "$Wd/steamapps/compatdata/8/pfx/save")" played-here "a save played here after an earlier copy was lost"
eq "$(cat "$Wd/config/config.vdf")" vdf
[[ ! -e $S && ! -e $W/home/fkuser/.steam ]] && _ok || _no "Steam still in the account"
eq "$(cat "$W/home/fkuser/blasphemous-save-backup-20261022/s")" keep
eq "$(fk stat -c %U /home/asobi/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps/common/Game/g)" asobi
case_ "signed in there already: Steam's settings in the world stay"
mkdir -p "$S/config"; echo host >"$S/config/config.vdf"; echo world >"$Wd/config/config.vdf"; : >"$Wd/config/loginusers.vdf"; fk chown -R fkuser:fkuser /home/fkuser/.local
step asobi_host_out; eq "$RC" 0 "$OUT"; eq "$(cat "$Wd/config/config.vdf")" world
done_
