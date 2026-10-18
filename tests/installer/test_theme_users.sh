#!/usr/bin/env bash
# tests/installer/test_theme_users.sh — theme.sh's safety and whom it runs for: links planted
# in the home (a config, a config folder, the state folder) never steer a write of root's; the
# newest 20 backups kept; misuse (exit 2); USERNAME and --user; user names with a dot,
# capitals, digits or a dash; a user that does not exist; the software not installed yet.
. "$(dirname "$0")/lib.sh"
H=/home/fkuser
TK=/usr/local/lib/fedokawaii
theme() { fkrun bash "$TK/theme.sh" --user fkuser "$@"; }
tconf() { sed -i "$@" "$W$TK/fedokawaii.conf"; }   # the toolkit's settings, changed
backups() { find "$W$H/.local/state/fedokawaii/backup" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort; }

world built
tconf 's/^WALLPAPER_PACK=.*/WALLPAPER_PACK="no"/'
keep plain
theme; keep themed

# ── links planted in the home ────────────────────────────────────────────────
case_ "a config replaced by a link to a file of root's: the link is replaced, root's file untouched"
printf 'root secret\n' >"$W/etc/fk-secret"; chmod 600 "$W/etc/fk-secret"
# (every planted link is relative: it leads to the fake machine's file in there and out here alike)
ln -sfn ../../../../etc/fk-secret "$W$H/.config/foot/foot.ini"; fk chown -h fkuser:fkuser "$H/.config/foot/foot.ini"
for i in $(seq -w 1 25); do mkdir -p "$W$H/.local/state/fedokawaii/backup/20250101-0000$i"; done   # (and 25 old backups)
fk chown -R fkuser:fkuser "$H/.local/state/fedokawaii/backup"
theme; eq "$RC" 0
eq "$(cat "$W/etc/fk-secret")" "root secret" "root's file"
[[ -f $W$H/.config/foot/foot.ini && ! -L $W$H/.config/foot/foot.ini ]] && _ok || _no "the link is still there"
nb=$(backups | tail -n1)
[[ -L $nb/.config/foot/foot.ini ]] && _ok || _no "the backup should hold the link itself"
lacks "$(cat "$W/home/fkuser/.config/foot/foot.ini")" "root secret" "the secret never copied into the home"
case_ "the newest 20 runs' backups kept, older ones removed"
eq "$(backups | wc -l)" 20
lacks "$(backups)" "20250101-000001" "the oldest gone"; lacks "$(backups | tail -n1)" "20250101-" "this run's own is the newest"

case_ "a config folder replaced by a link to a folder of root's: nothing written there; the run stops and names it"
back themed
mkdir -p "$W/etc/fk-dir"; echo keep >"$W/etc/fk-dir/foot.ini"
rm -rf "$W$H/.config/foot"; ln -s ../../../etc/fk-dir "$W$H/.config/foot"; fk chown -h fkuser:fkuser "$H/.config/foot"
theme
eq "$(cat "$W/etc/fk-dir/foot.ini")" keep "root's folder untouched"; eq "$(ls "$W/etc/fk-dir")" foot.ini "nothing added there"
[[ $RC != 0 ]] && _ok || _no "a run that could not write a config ended 0"
has "$OUT" ".config/foot"
case_ "the state folder a link: the run refuses before anything"
back themed; rm -rf "$W$H/.local/state/fedokawaii"; ln -s ../../../../etc "$W$H/.local/state/fedokawaii"
theme; eq "$RC" 1; has "$OUT" "is not a folder"

# ── the theme link copied as a folder (a backup or sync tool followed the link) ───────────
# shellcheck disable=SC2088  # (a literal ~ in the name)
case_ "~/.config/fedokawaii/current a real folder, edited inside: kept in the backup, the link put in its place, said"
back themed
rm -f "$W$H/.config/fedokawaii/current"; cp -r "$W$H/.config/fedokawaii/themes/dark" "$W$H/.config/fedokawaii/current"
echo "# my edit" >>"$W$H/.config/fedokawaii/current/colors.sh"; fk chown -R fkuser:fkuser "$H/.config/fedokawaii/current"
theme; eq "$RC" 0
eq "$(readlink "$W$H/.config/fedokawaii/current")" themes/dark "the link again (THEME in fedokawaii.conf)"
has "$OUT" "current was a folder, not a link — kept in the backup"
nb=$(backups | tail -n1)
has "$(cat "$nb/.config/fedokawaii/current/colors.sh" 2>/dev/null)" "# my edit" "the folder, edits and all, in this run's backup"
eq "$(fk stat -c %U "${nb#"$W"}/.config/fedokawaii/current/colors.sh" 2>/dev/null)" fkuser "the backup is yours"

# ── whom it runs for ─────────────────────────────────────────────────────────
case_ "misuse: an unknown option, --user without a name, root with no user to name (exit 2); --help (0)"
back plain
theme --frobnicate; eq "$RC" 2; has "$OUT" "unknown option"
fkrun bash "$TK/theme.sh" --user; eq "$RC" 2; has "$OUT" "--user"
fkrun bash "$TK/theme.sh" --user --check; eq "$RC" 2 "--user followed by an option"
fkrun env -u SUDO_USER bash "$TK/theme.sh"; eq "$RC" 2; has "$OUT" "--user NAME"
fkrun bash "$TK/theme.sh" --help; eq "$RC" 0; has "$OUT" "--check"
case_ "a user that does not exist: said, exit 1"
fkrun bash "$TK/theme.sh" --user nosuchuser; eq "$RC" 1; has "$OUT" "nosuchuser"
case_ "the software not installed yet: told to run setup first (exit 1)"
mv "$W/usr/local/bin/dwl" "$W/usr/local/bin/dwl.away"
theme; eq "$RC" 1; has "$OUT" "run Setup first"
mv "$W/usr/local/bin/dwl.away" "$W/usr/local/bin/dwl"

case_ "user names with a dot and capitals, or digits and a dash: each gets their own home, rendered"
id=32000
for u in Mo.Eldoush kawa-chan42; do
  id=$((id + 1)); echo "$u:x:$id:$id::/home/$u:/bin/bash" >>"$W/etc/passwd"; echo "$u:x:$id:" >>"$W/etc/group"
  mkdir -p "$W/home/$u/.local/src/dwl"; fk chown -R "$u:$u" "/home/$u"
done
fkrun bash "$TK/theme.sh" --user kawa-chan42
eq "$RC" 0 "kawa-chan42: exit"
has "$(cat "$W/home/kawa-chan42/.config/xdg-desktop-portal-termfilechooser/config" 2>/dev/null)" "default_dir=/home/kawa-chan42" "kawa-chan42: @HOME@"
eq "$(fk stat -c %U /home/kawa-chan42/.config/fedokawaii/env 2>/dev/null)" kawa-chan42 "kawa-chan42: owns its files"
case_ "a second person on the machine (no dwl source of their own — dwl is the system's): their home themed, dwl left as it is"
echo "guest:x:32100:32100::/home/guest:/bin/bash" >>"$W/etc/passwd"; echo "guest:x:32100:" >>"$W/etc/group"
mkdir -p "$W/home/guest"; fk chown -R guest:guest /home/guest; reset_calls
fkrun bash "$TK/theme.sh" --user guest; eq "$RC" 0 "$(grep -E '✘' <<<"$OUT" | head -n2 | tr '\n' '|')"
[[ -s $W/home/guest/.config/foot/foot.ini && -s $W/home/guest/.config/dwl/autostart.sh ]] && _ok || _no "the guest's configs not written"
[[ ! -e $W/home/guest/.local/src ]] && _ok || _no "a dwl source made in the guest's home"
not_called 'make\] .*src/dwl'; not_called 'guest\[git\]'
fkrun bash "$TK/theme.sh" --user guest --check; [[ $RC == 0 || $RC == 4 ]] && _ok || _no "the guest's check: exit $RC — $(grep -A3 'differ' <<<"$OUT" | tr '\n' '|')"
case_ "USERNAME with a dot in fedokawaii.conf (no --user, no sudo): that user — not the part before the dot"
tconf 's/^USERNAME=.*/USERNAME="Mo.Eldoush"/'
fkrun env -u SUDO_USER bash "$TK/theme.sh"; eq "$RC" 0; has "$OUT" "theme → Mo.Eldoush"
has "$(cat "$W/home/Mo.Eldoush/.config/xdg-desktop-portal-termfilechooser/config" 2>/dev/null)" "default_dir=/home/Mo.Eldoush"

done_
