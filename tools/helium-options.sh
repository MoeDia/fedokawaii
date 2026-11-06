#!/usr/bin/env bash
# tools/helium-options.sh — Helium's theme options (r28 f15), shot from the real browser: a headless dwl
# (tools/hl-dwl.sh: its own runtime dir, D-Bus and PID namespace), a throw-away home and profiles; nothing
# of the session or of the real home is written (its fonts are read). The window is 960 by 600, half
# the monitor, so that the sheet can show it 1:1.
#   bash tools/helium-options.sh OUT.jpg
# Exit 0 · 1 a shot missing
set -u
here=$(cd "$(dirname "$0")" && pwd)
jpg=$1
export REPO=${here%/*} OUT=/dev/shm/r28/f15/run
rm -rf -- "$OUT"; mkdir -p "$OUT"
python3 -B "$here/helium-options.py" prep "$OUT" || exit 1
cat >"$OUT/inside.sh" <<'INSIDE'
export HOME=$OUT/home-$MOOD XDG_CONFIG_HOME=$OUT/home-$MOOD/.config XDG_CACHE_HOME=$OUT/home-$MOOD/.cache XDG_DATA_HOME=$OUT/home-$MOOD/.local/share
gtk=Fedokawaii; [ "$MOOD" = dark ] && gtk=Fedokawaii-dark
export GTK_THEME=$gtk BROWSER=true
mkdir -p "$XDG_DATA_HOME/themes" "$XDG_CONFIG_HOME/gtk-3.0" "$XDG_CONFIG_HOME/gtk-4.0" "$XDG_CACHE_HOME"
ln -sfn "$REPO/configs/home/.local/share/themes/$gtk" "$XDG_DATA_HOME/themes/$gtk"
ln -sfn "$REAL_HOME/.local/share/fonts" "$XDG_DATA_HOME/fonts"
for v in 3 4; do printf '[Settings]\ngtk-theme-name=%s\ngtk-font-name=Sumi UI 10.5\n' "$gtk" >"$XDG_CONFIG_HOME/gtk-$v.0/settings.ini"; done
for v in 3 4; do printf 'window, widget, * { font-family: "Sumi UI"; font-size: 14px; }\n' >"$XDG_CONFIG_HOME/gtk-$v.0/gtk.css"; done
# (GTK on Wayland takes its font from GSettings, which the system's dconf answers: a keyfile of this home's instead)
export GSETTINGS_BACKEND=keyfile
mkdir -p "$XDG_CONFIG_HOME/glib-2.0/settings"
printf "[org/gnome/desktop/interface]\nfont-name='Sumi UI 10.5'\ngtk-theme='%s'\n" "$gtk" >"$XDG_CONFIG_HOME/glib-2.0/settings/keyfile"
cat >"$OUT/a.html" <<'PAGE'
<!doctype html><title>the book of five rings</title>
PAGE
cat >"$OUT/b.html" <<'PAGE'
<!doctype html><title>wlroots release notes</title>
PAGE
# start: Helium on this profile, its pages, then a new tab by its own key (a command line's chrome://newtab is dropped)
start() {
  /usr/bin/helium --user-data-dir="$1" --ozone-platform=wayland --no-first-run --password-store=basic --hide-crash-restore-bubble \
    --load-extension="$2" "file://$OUT/a.html" "file://$OUT/b.html" >>"$OUT/$MOOD/${1##*/}.log" 2>&1 &
  pid=$!
  sleep 5
}
# one NAME JQ EXT: Helium with these settings on top of what all share, a shot of it (a theme's "installed" bar only comes on its first start: a second)
one() {
  p=$HOME/$1; mkdir -p "$p/Default"
  jq -n "$2 | .helium.completed_onboarding = true | .helium.services.user_consented = false | .helium.services.schema_version = 1
    | .helium.browser.rounded_frame = false | .browser.theme.user_color2 = -3719651 | .browser.theme.is_grayscale2 = false | .helium.browser.show_avatar_button = false | .session.restore_on_startup = 5" >"$p/Default/Preferences"
  start "$p" "$3"
  case $3 in *,*) kill "$pid"; sleep 1.5; start "$p" "$3" ;; esac
  grep -m1 -o '[^ ]*libgtk[^ ]*' "/proc/$pid/maps" >"$OUT/$MOOD/$1.gtk"
  wtype -s 1000 -M ctrl t -m ctrl
  sleep 1
  wtype -s 500 -k F6       # (the page's, not the address's: the field at rest)
  sleep 1.5
  grim "$OUT/$MOOD/$1.png"
  kill "$pid"; sleep 1.5
}
ntp=$OUT/$MOOD/ntp
gtkmode='.extensions.theme.system_theme = 1'
centre='.helium.browser.centered_location_bar = true'
two="$centre | .browser.show_forward_button = false"
case $OPTION in
  now) one now "$gtkmode | .helium.browser.layout = 1 | .helium.browser.show_extensions_button = false" "$ntp" ;;
  tsuitate) one tsuitate "$gtkmode | $two | .helium.browser.layout = 3 | .helium.browser.show_extensions_button = false" "$ntp" ;;
  mokuroku) one mokuroku "$gtkmode | $centre | .helium.browser.layout = 2 | .helium.browser.show_vertical_tabs_collapse_button = false | .helium.browser.show_extensions_button = true" "$ntp" ;;
  noren) one noren "$centre | .helium.browser.layout = 0 | .helium.browser.show_extensions_button = true" "$ntp,$OUT/$MOOD/noren" ;;
esac
INSIDE
export REAL_HOME=$HOME
# (one dwl a shot: a clean start for each)
for MOOD in ${MOODS:-dark light}; do
  for OPTION in ${OPTIONS:-now tsuitate mokuroku noren}; do
    export MOOD OPTION
    bash "$here/hl-dwl.sh" "$OUT/inside.sh" --time 40 --size 960x600@60Hz || exit 1
  done
done
[[ -n ${OPTIONS:-} ]] || python3 -B "$here/helium-options.py" sheet "$OUT" "$jpg"
