#!/usr/bin/env bash
# tests/installer/test_theme.sh — theme.sh in a fake finished install: every config rendered
# into the home (render: fedokawaii.conf's values in, binaries byte for byte; place: the mode
# from the content, a backup of what it replaces, written by the user), a second run that
# changes nothing and says so, --check in sync (0) and with drift (3), and the run that puts
# the drift back. (The optional parts: test_theme_parts.sh · safety and users: test_theme_users.sh)
. "$(dirname "$0")/lib.sh"
H=/home/fkuser
TK=/usr/local/lib/fedokawaii
theme() { fkrun bash "$TK/theme.sh" --user fkuser "$@"; }
tconf() { sed -i "$@" "$W$TK/fedokawaii.conf"; }   # the toolkit's settings, changed
backups() { find "$W$H/.local/state/fedokawaii/backup" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort; }

world built
tconf -e 's/^WALLPAPER_PACK=.*/WALLPAPER_PACK="no"/' -e 's/^THEME=.*/THEME="light"/'   # (the pack is the network's)
# a copy uploaded through a web page: the x bits gone from scripts, set on a plain file
chmod 644 "$W$TK/configs/home/.config/dwl/autostart.sh" "$W$TK/bin/kawa-theme"
chmod 755 "$W$TK/configs/home/.config/fedokawaii/env"

# what an earlier version left for programs the desktop no longer has (presenterm's link into
# the theme, sc-im's and spotify_player's settings) — and a file of yours beside one of them
mkdir -p "$W$H/.config/presenterm" "$W$H/.config/sc-im" "$W$H/.config/spotify-player"
ln -s ../../fedokawaii/current/presenterm.yaml "$W$H/.config/presenterm/config.yaml"
echo '# ~/.config/sc-im/scimrc — sc-im, the terminal spreadsheet' >"$W$H/.config/sc-im/scimrc"
echo '# ~/.config/spotify-player/app.toml — spotify_player (Premium)' >"$W$H/.config/spotify-player/app.toml"
echo '# ~/.config/spotify-player/theme.toml — spotify_player uses the terminal' >"$W$H/.config/spotify-player/theme.toml"
echo 'my own notes' >"$W$H/.config/sc-im/mine.sc"
fk chown -hR fkuser:fkuser "$H/.config/presenterm" "$H/.config/sc-im" "$H/.config/spotify-player"

# ── the first run ────────────────────────────────────────────────────────────
case_ "first run: every file of configs/home, bin/ and configs/system in place (exit 0)"
theme; eq "$RC" 0 "exit"; has "$OUT" "files updated"
miss=""
while IFS= read -r -d '' f; do
  rel=${f#"$REPO/configs/home/"}; [[ -f $W$H/$rel ]] || miss+=" $rel"
done < <(find "$REPO/configs/home" -type f -print0)
eq "$miss" "" "every configs/home file installed"
for f in "$REPO"/bin/*; do [[ -x $W$H/.local/bin/${f##*/} ]] || miss+=" ${f##*/}"; done
eq "$miss" "" "every helper in ~/.local/bin, executable"
[[ -f $W/etc/dconf/db/local.d/00-fedokawaii ]] && _ok || _no "configs/system → /etc"
eq "$(fk stat -c %U "/etc/dconf/db/local.d/00-fedokawaii")" root "the system files are root's"
eq "$(fk stat -c %U:%G "$H/.config/fedokawaii/env")" fkuser:fkuser "the home's files are the user's"
called 'dconf\] update'

case_ "render: no @TOKEN@ left anywhere in the home; each filled from fedokawaii.conf"
left=$(grep -rlE '@(HOME|UID|MONITOR_HZ|WEATHER_CITY|NIGHT_LIGHT|ICON_CHEVRON_RIGHT|MPV_SCALING|BRAVE_ICON)@' "$W$H" 2>/dev/null | grep -v "^$W$H/fedokawaii/" || true)
eq "$left" "" "tokens left in: $left"
env=$(cat "$W$H/.config/fedokawaii/env")
has "$env" 'MONITOR_HZ=144'; has "$env" 'WEATHER_CITY="Sharjah"'; has "$env" 'NIGHT_LIGHT="25.35:55.40"'
lacks "$env" 'BACKUP_' "no copy of the backup settings: kawa-backup reads them from fedokawaii.conf, their one place"
has "$(cat "$W$H/.config/fedokawaii/backup-exclude")" "$H/.cache" "@HOME@ in the backup's exclude list"
has "$(cat "$W$H/.config/xdg-desktop-portal-termfilechooser/config")" "cmd=$H/.local/bin/kawa-pick" "@HOME@: the user's home"
has "$(cat "$W$H/.config/udiskie/config.yml")" "setup_by_uid: !!int \"$FK_UID\"" "@UID@: the user's id"
has "$(cat "$W$H/.config/fedokawaii/fzf.opts")" "$(. "$REPO/configs/home/.config/fedokawaii/icons.sh"; printf '%s' "$ICON_CHEVRON_RIGHT")" "@ICON_CHEVRON_RIGHT@"
has "$(grep '^profile=' "$W$H/.config/mpv/mpv.conf")" "profile=high-quality" "@MPV_SCALING@: a discrete AMD card (12 GB)"

case_ "render: binaries byte for byte (fonts, pictures, pointers) — never through sed"
bad=""
while IFS= read -r -d '' f; do
  cmp -s "$f" "$W$H/${f#"$REPO/configs/home/"}" || bad+=" ${f##*/}"
done < <(find "$REPO/configs/home" -type f \( -name '*.ttf' -o -name '*.otf' -o -name '*.png' -o -path '*/cursors/*' \) -print0)
eq "$bad" "" "binaries changed on the way:$bad"

case_ "place: the mode from the content (#! → 0755, else 0644), whatever the copy's bits say"
eq "$(stat -c %a "$W$H/.config/dwl/autostart.sh")" 755 "a script that lost its x bit"
eq "$(stat -c %a "$W$H/.local/bin/kawa-theme")" 755 "a helper that lost its x bit"
eq "$(stat -c %a "$W$H/.config/fedokawaii/env")" 644 "a plain file marked executable"

case_ "the theme link starts as THEME says; the configs that are links point into it"
eq "$(readlink "$W$H/.config/fedokawaii/current")" themes/light
for l in .config/qt6ct/qt6ct.conf .config/imv/config .config/wiremix/wiremix.toml .config/btop/themes/fedokawaii.theme; do
  [[ -L $W$H/$l && -e $W$H/$l ]] && _ok || _no "$l is not a working link into the current theme"
done
[[ -s $W$H/.local/share/fedokawaii/dark/padlock.png && -s $W$H/.local/share/fedokawaii/light/padlock.png && -s $W$H/.local/share/fedokawaii/light/seal-7.png ]] && _ok || _no "the lock's pictures not copied"

case_ "the programs the desktop no longer has: their files of ours into the backup, folders left empty gone, yours kept"
[[ ! -e $W$H/.config/presenterm && ! -e $W$H/.config/spotify-player && ! -e $W$H/.config/sc-im/scimrc ]] && _ok \
  || _no "left: $(ls -d "$W$H"/.config/{presenterm,spotify-player,sc-im/scimrc} 2>/dev/null | tr '\n' ' ')"
eq "$(cat "$W$H/.config/sc-im/mine.sc")" "my own notes" "a file of yours in the same folder"
b=$(backups | tail -n1)
[[ -L $b/.config/presenterm/config.yaml && -f $b/.config/sc-im/scimrc && -f $b/.config/spotify-player/app.toml ]] && _ok \
  || _no "not in the backup ($b)"
has "$OUT" "spotify-player/theme.toml (retired)"

case_ "the pointers: both Sumi themes, their other names made as links, the default one the theme's"
miss="" n=0
while read -r name p; do
  [[ -z $name || $name == \#* ]] && continue
  for v in dark light; do
    n=$((n + 1)); [[ $(readlink "$W/usrshare/icons/Sumi-$v/cursors/$name") == "$p" ]] || miss+=" Sumi-$v/$name"   # (the fake /usr/share)
  done
done <"$REPO/art/cursor-names.txt"
((n > 150)) && _ok || _no "only $n other names (art/cursor-names.txt)"
eq "$miss" "" "links not made"
eq "$(readlink "$W$H/.local/share/icons/default")" /usr/share/icons/Sumi-light "THEME=light: the light pointers are the default"
[[ -s $W/usrshare/icons/Sumi-light/cursors/left_ptr && -s $W/usrshare/icons/Sumi-dark/cursors/default ]] && _ok || _no "left_ptr does not lead to a pointer"
eq "$(stat -c %U "$W/usrshare/icons/Sumi-dark/cursors/default" 2>/dev/null)" "$(id -un)" "(root's, as the system's files: the fake machine's root is this user)"

case_ "Syncplay's settings started: its public server, your name, a room of your own, mpv (yours, 600)"
ini=$W$H/.config/syncplay.ini
s=$(cat "$ini" 2>/dev/null)
has "$s" "host = syncplay.pl"; has "$s" "port = 8999"; has "$s" "name = fkuser"
grep -qE '^room = fkuser-[0-9a-f]{4}$' "$ini" && _ok || _no "no room of your own: $(grep '^room' "$ini")"
has "$s" "playerpath = /usr/bin/mpv"; has "$s" "mediasearchdirectories = ['$H/Videos', '$H/Downloads']"
has "$s" "checkforupdatesautomatically = False"
has "$s" "chatinputfontfamily = JetBrainsMono Nerd Font"; has "$s" "chatoutputfontfamily = JetBrainsMono Nerd Font"
eq "$(sed -n 's/^chat\(In\|Out\)\(put\)FontFamily=//p' "$W$H/.config/mpv/script-opts/syncplayintf.conf" | sort -u)" "JetBrainsMono Nerd Font" \
  "its words on the film in that font from mpv's first frame (Syncplay's script in mpv)"
has "$(grep '^osd-font=' "$W$H/.config/mpv/mpv.conf")" '"JetBrainsMono Nerd Font"' "the same as mpv's own"
eq "$(fk stat -c '%U %a' "$H/.config/syncplay.ini")" "fkuser 600"

case_ "Xournal++ (Sketch): the pen's lower button the eraser, its upper one the hand"
xpp=$W$H/.config/xournalpp/settings.xml
grep -q 'name="stylus"><attribute name="tool" type="string" value="eraser"' "$xpp" && _ok || _no "button 1: $(cat "$xpp" 2>/dev/null)"
grep -q 'name="stylus2"><attribute name="tool" type="string" value="hand"' "$xpp" && _ok || _no "button 2: $(cat "$xpp" 2>/dev/null)"
eq "$(fk stat -c %U "$H/.config/xournalpp/settings.xml")" fkuser

# ── the second run, and --check ──────────────────────────────────────────────
case_ "a second run: nothing changes, it says so, no new backup folder — and your theme switch stays"
ln -sfn themes/dark "$W$H/.config/fedokawaii/current"        # (kawa-theme: you switched to dark,
ln -sfn /usr/share/icons/Sumi-dark "$W$H/.local/share/icons/default"           #  the pointers with it)
first=$(backups)
theme; eq "$RC" 0
has "$OUT" "files already in sync"; lacks "$OUT" "files updated"
total=$(sed -n 's/.*all \([0-9]*\) files already in sync.*/\1/p' <<<"$OUT")
eq "$(backups)" "$first" "no backup folder for a run that replaced nothing"
eq "$(readlink "$W$H/.config/fedokawaii/current")" themes/dark "your switch stays"
eq "$(readlink "$W$H/.local/share/icons/default")" /usr/share/icons/Sumi-dark "the pointers stay with it"

case_ "--check in sync: exit 0, the same count as the run, nothing written"
reset_calls; theme --check; eq "$RC" 0; has "$OUT" "✔ theme in sync — $total files match the repo"
not_called 'grubby .*--update|grub2-mkconfig|grub2-editenv - (set|unset)|\[make\]|dconf|dracut|plymouth-set-default-theme [a-z]'

case_ "--check after changes: exit 3, each named (an edit, a deletion, a link replaced, dwl's config)"
echo "# mine" >>"$W$H/.config/foot/foot.ini"
rm -f "$W$H/.config/waybar/style.css"
rm -f "$W$H/.config/imv/config"; echo "x" >"$W$H/.config/imv/config"
echo "// mine" >>"$W$TK/src/dwl/config.h"
theme --check; eq "$RC" 3
has "$OUT" "files differ from the repo:"
has "$OUT" "$H/.config/foot/foot.ini"; has "$OUT" "$H/.config/waybar/style.css"
has "$OUT" ".config/imv/config (not a link to"; has "$OUT" "/usr/local/bin/dwl (not built from src/dwl as it is now)"
has "$(tail -n1 "$W$H/.config/foot/foot.ini")" "# mine" "--check writes nothing"

case_ "the run after: everything put back, your versions in a new backup folder, dwl rebuilt"
theme; eq "$RC" 0
has "$OUT" "dwl rebuilt"; has "$OUT" "previous versions: ~/.local/state/fedokawaii/backup/"
lacks "$(cat "$W$H/.config/foot/foot.ini")" "# mine"
[[ -s $W$H/.config/waybar/style.css && -L $W$H/.config/imv/config ]] && _ok || _no "not all put back"
nb=$(backups | tail -n1)
[[ -n $nb && $nb != "$(tail -n1 <<<"$first")" ]] && _ok || _no "no new backup folder"
has "$(cat "$nb/.config/foot/foot.ini" 2>/dev/null)" "# mine" "your foot.ini kept"
eq "$(cat "$nb/.config/imv/config" 2>/dev/null)" "x" "your imv config kept"
theme --check; eq "$RC" 0 "in sync after the run"

case_ "Syncplay's settings stay yours (it rewrites them itself): only what is empty is filled again"
sed -i -e 's/^host = .*/host = films.example.org/' -e 's/^name = .*/name = Mo/' \
  -e 's/^room = .*/room = Friday%%night/' -e 's/^playerpath = .*/playerpath = None/' \
  -e 's/^chatoutputfontfamily = .*/chatoutputfontfamily = sans-serif/' "$ini"
theme --check; eq "$RC" 3; has "$OUT" "syncplay.ini (Syncplay: playerpath, chatoutputfontfamily not set)"
theme; eq "$RC" 0; has "$OUT" "syncplay.ini (Syncplay: playerpath, chatoutputfontfamily)"
has "$(cat "$ini")" "chatoutputfontfamily = JetBrainsMono Nerd Font" "Syncplay's own default (sans-serif) is not a choice of yours: mpv's font again"
s=$(cat "$ini")
has "$s" "host = films.example.org"; has "$s" "name = Mo"; has "$s" "room = Friday%%night"
has "$s" "playerpath = /usr/bin/mpv"
theme --check; eq "$RC" 0

case_ "Xournal++'s settings, once set, are yours (it rewrites them itself): a tool you choose — nothing too — stays"
[[ -e $W$H/.local/state/fedokawaii/xournalpp-pen ]] && _ok || _no "not recorded as done"
sed -i -e 's/value="eraser"/value="pen"/' -e 's/value="hand"/value="none"/' "$xpp"
theme --check; eq "$RC" 0 "no drift: yours"
theme; eq "$RC" 0
grep -q 'name="stylus"><attribute name="tool" type="string" value="pen"' "$xpp" && _ok || _no "your choice was overwritten"
grep -q 'name="stylus2"><attribute name="tool" type="string" value="none"' "$xpp" && _ok || _no "your 'nothing' was overwritten"

case_ "the pointers before Sumi: Fedokawaii removed, its default kept in the backup, default a link again"
o=$W$H/.local/share/icons
rm "$o/default"; mkdir -p "$o/default" "$o/Fedokawaii/cursors"
printf '[Icon Theme]\nInherits=Fedokawaii\n' >"$o/default/index.theme"
printf '[Icon Theme]\nName=Fedokawaii\n' >"$o/Fedokawaii/index.theme"
echo x >"$o/Fedokawaii/cursors/default"; ln -s default "$o/Fedokawaii/cursors/left_ptr"
chown -R "$FK_UID:$FK_UID" "$o/default" "$o/Fedokawaii"
theme --check; eq "$RC" 3
has "$OUT" "$H/.local/share/icons/Fedokawaii (the pointers before Sumi)"
has "$OUT" "$H/.local/share/icons/default (not a link to /usr/share/icons/Sumi-dark)"
theme; eq "$RC" 0
[[ ! -e $o/Fedokawaii ]] && _ok || _no "the old pointers are still there"
eq "$(readlink "$o/default")" /usr/share/icons/Sumi-dark "the default: the theme in use's (dark, switched above)"
has "$(cat "$(backups | tail -n1)/.local/share/icons/default/index.theme" 2>/dev/null)" "Inherits=Fedokawaii" \
  "the old default/index.theme kept in the backup"
theme --check; eq "$RC" 0 "in sync after the run"

done_
