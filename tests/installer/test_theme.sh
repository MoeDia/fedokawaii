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
left=$(grep -rlE '@(HOME|UID|MONITOR_HZ|WEATHER_CITY|NIGHT_LIGHT|ICON_CHEVRON_RIGHT|MPV_SCALING)@' "$W$H" 2>/dev/null | grep -v "^$W$H/fedokawaii/" || true)
eq "$left" "" "tokens left in: $left"
env=$(cat "$W$H/.config/fedokawaii/env")
has "$env" 'MONITOR_HZ=144'; has "$env" 'WEATHER_CITY="Sharjah"'; has "$env" 'NIGHT_LIGHT="25.35:55.40"'
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
for l in .config/qt6ct/qt6ct.conf .config/imv/config .config/presenterm/config.yaml .config/btop/themes/fedokawaii.theme; do
  [[ -L $W$H/$l && -e $W$H/$l ]] && _ok || _no "$l is not a working link into the current theme"
done
[[ -s $W$H/.local/share/fedokawaii/dark/pattern.png && -s $W$H/.local/share/fedokawaii/light/lock.png ]] && _ok || _no "pixel art not drawn"

# ── the second run, and --check ──────────────────────────────────────────────
case_ "a second run: nothing changes, it says so, no new backup folder — and your theme switch stays"
ln -sfn themes/dark "$W$H/.config/fedokawaii/current"        # (kawa-theme: you switched to dark)
first=$(backups)
theme; eq "$RC" 0
has "$OUT" "files already in sync"; lacks "$OUT" "files updated"
total=$(sed -n 's/.*all \([0-9]*\) files already in sync.*/\1/p' <<<"$OUT")
eq "$(backups)" "$first" "no backup folder for a run that replaced nothing"
eq "$(readlink "$W$H/.config/fedokawaii/current")" themes/dark "your switch stays"

case_ "--check in sync: exit 0, the same count as the run, nothing written"
reset_calls; theme --check; eq "$RC" 0; has "$OUT" "✔ theme in sync — $total files match the repo"
not_called 'grubby .*--update|grub2-mkconfig|grub2-editenv - (set|unset)|\[make\]|dconf'

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

done_
