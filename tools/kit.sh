#!/usr/bin/env bash
# tools/kit.sh — the desktop's real surfaces rendered off-screen, to be measured (tools/px.py) and
# compared: a headless dwl on the real GPU (tools/hl-dwl.sh) on a flat ground (no wallpaper),
# the real apps with the installed configs — but from a throw-away home: copies of what theme.sh
# installed in ~/.config (and ~/.bashrc), empty caches and state, the scripts and fonts linked.
# Nothing of the session or of the real home is written; the live theme stays as it is.
#   bash tools/kit.sh [--theme dark|light] [--fontdir DIR] [--font "NAME=FAMILY"]…
#                     [--edit "FILE:SED"]… [--out DIR] SCENE…
#     --fontdir  extra fonts (a candidate's files) seen by every app in the kit
#     --font     NAME (as the configs call it: "Sumi UI", "Sumi Term") drawn with FAMILY instead
#     --edit     sed SED applied to the kit's copy of FILE (under ~/.config, or .bashrc): sizes …
#     SCENE      bar · notice · launcher · term · full (default: bar notice term full)
# Shots → OUT (default /dev/shm/r27/kit/THEME)/SCENE.png. Exit 0 · 1 a scene failed · 2 misuse.
set -u
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/.." && pwd)
theme=dark out="" fontdir="" fonts=() edits=() scenes=()
while (($#)); do
  case $1 in
    --theme) theme=$2; shift 2 ;;
    --fontdir) fontdir=$(realpath "$2"); shift 2 ;;
    --font) fonts+=("$2"); shift 2 ;;
    --edit) edits+=("$2"); shift 2 ;;
    --out) out=$2; shift 2 ;;
    -h|--help) sed -n '2,/^set -u/{/^set -u/d;s/^# \{0,1\}//;p}' "$0"; exit 0 ;;
    -*) echo "kit: unknown option $1" >&2; exit 2 ;;
    *) scenes+=("$1"); shift ;;
  esac
done
[[ $theme == @(dark|light) ]] || { echo "kit: --theme dark|light" >&2; exit 2; }
((${#scenes[@]})) || scenes=(bar notice term full)
out=${out:-/dev/shm/r27/kit/$theme}
mkdir -p "$out"
K=$(mktemp -d /tmp/kit.XXXXXX)
trap 'rm -rf "$K"' EXIT
h=$K/home
mkdir -p "$h/.config" "$h/.cache" "$h/.local/state" "$h/.local/share"
# what theme.sh put in ~/.config (the repo names it), and the shell's own files
for f in "$repo"/configs/home/.config/*; do
  f=${f##*/}
  [[ -e $HOME/.config/$f ]] && cp -a "$HOME/.config/$f" "$h/.config/"
done
rm -f "$h/.config/fedokawaii/secrets.sh"     # (keys never leave their file: no render needs one)
cp -a "$HOME/.config/dconf" "$HOME/.config/gtk-3.0" "$h/.config/" 2>/dev/null
# (the session's small settings the configs include or read: foot's glass, night, saver, theme …;
# never the big ones — a backup tarball, logs, for-you's notes)
mkdir -p "$h/.local/state/fedokawaii"
find "$HOME/.local/state/fedokawaii" -maxdepth 1 -type f -size -4k ! -name '*.lock' -exec cp -a {} "$h/.local/state/fedokawaii/" \;
rm -rf "$h/.local/state/fedokawaii/for-you"
cp -a "$HOME/.bashrc" "$h/" 2>/dev/null
[[ -d $HOME/.bashrc.d ]] && cp -a "$HOME/.bashrc.d" "$h/"
ln -s "$HOME/.local/bin" "$h/.local/bin"
ln -s "$HOME/.local/share/fonts" "$h/.local/share/fonts"
ln -sfn "themes/$theme" "$h/.config/fedokawaii/current"
for e in "${edits[@]}"; do
  f=${e%%:*} x=${e#*:}
  t=$h/.config/$f; [[ $f == .bashrc ]] && t=$h/.bashrc
  [[ -f $t ]] || { echo "kit: --edit: no $f in the kit" >&2; exit 2; }
  sed -i -e "$x" "$t" || exit 2
done
{
  echo '<?xml version="1.0"?><!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd"><fontconfig>'
  echo '<include ignore_missing="yes">/etc/fonts/fonts.conf</include>'
  [[ -n $fontdir ]] && echo "<dir>$fontdir</dir>"
  echo "<cachedir>$K/fc-cache</cachedir>"
  for f in "${fonts[@]}"; do
    printf '<match target="pattern"><test name="family"><string>%s</string></test><edit name="family" mode="prepend" binding="strong"><string>%s</string></edit></match>\n' "${f%%=*}" "${f#*=}"
  done
  echo '</fontconfig>'
} >"$K/fonts.conf"

# inside the headless dwl: the kit's environment, then each scene and its shot
cat >"$K/inside.sh" <<EOF
export HOME=$h XDG_CONFIG_HOME=$h/.config XDG_CACHE_HOME=$h/.cache XDG_STATE_HOME=$h/.local/state
export XDG_DATA_HOME=$h/.local/share FONTCONFIG_FILE=$K/fonts.conf PATH=$h/.local/bin:/usr/local/bin:/usr/bin:/bin
export XDG_CURRENT_DESKTOP=wlroots XDG_SESSION_TYPE=wayland
cd "\$HOME"
kawa-dwlstatus <&0 >/dev/null 2>&1 &
mako >/dev/null 2>&1 &
foot --server >/dev/null 2>&1 &
waybar >"$K/waybar.log" 2>&1 &
sleep 3
fail=0
for s in ${scenes[*]}; do
  case \$s in
    bar) grim -g "0,0 1920x40" "$out/bar.png" ;;
    notice)
      notify-send -a desktop -- "a notice" "the words of a notice, on two lines when they are long enough to wrap"
      notify-send -a desktop -u critical -- "a critical one" "it stays until read"
      sleep 1.2; grim -g "1380,30 540x330" "$out/notice.png"; makoctl dismiss -a ;;
    launcher) kawa-menu --launcher >/dev/null 2>&1 & sleep 1.5; grim "$out/launcher.png"; wtype -k Escape; sleep 0.5 ;;
    term)
      footclient -W 100x24 -- bash -i >/dev/null 2>&1 &
      sleep 2; wtype -s 1200 -d 30 "ls --color=always /usr/share | head -5"; wtype -k Return; sleep 1.5
      grim "$out/term.png" ;;
    full) grim "$out/full.png" ;;
    *) echo "kit: no scene \$s" >&2; fail=1 ;;
  esac || fail=1
done
exit \$fail
EOF
bash "$here/hl-dwl.sh" "$K/inside.sh" --time 120 --keep "$K/logs"
rc=$?
for s in "${scenes[@]}"; do [[ -f $out/$s.png ]] && echo "$out/$s.png"; done
((rc == 0)) || { echo "kit: a scene failed (exit $rc) — waybar: $(tail -n 3 "$K/waybar.log" 2>/dev/null)" >&2; exit 1; }
