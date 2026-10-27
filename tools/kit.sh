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
#     --themes   a trial palette's files (tools/build-themes.py --palette P --out DIR) in place
#                of the installed ones: the theme folders, foot's colours, GTK, nvim's colours
#     --tui      "COLSxROWS:FILE" — the tui scene: a floating terminal that size running the
#                script FILE (a mock screen, a screen under work), shot when it has drawn
#     --play     FILE — the play scene: FILE run inside, in the words of tools/kit-play.sh (the
#                pointer, the keys, shots by name): a menu opened by a click, hovered, used
#     --time     the longest the whole run may take, seconds (default 120: a long play needs more)
#     --bin      DIR first on the kit's PATH (the repository's bin/: its scripts tried before
#                they are applied; everything else stays the installed state)
#     --dwl      the dwl binary (default the edited tree's, ~/.local/src/dwl/dwl; the session's
#                own: /usr/local/bin/dwl)
#     --repo-art the repository's drawn files in place of the installed ones: icons.sh, the icon
#                fonts, the theme folders (what build-icons.py and build-themes.py just wrote)
#     SCENE      bar · notice · launcher · term · quick (Super+X) · system (Super+U; system:N its
#                tab N after the first, shot as system-N.png) · tui (--tui) · play (--play) · full (default: bar notice term full)
# Shots → OUT (default /dev/shm/r27/kit/THEME)/SCENE.png. Exit 0 · 1 a scene failed · 2 misuse.
set -u
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/.." && pwd)
theme=dark out="" fontdir="" fonts=() edits=() scenes=() themes="" tui="" play="" limit=120 bin="" dwl_bin=$HOME/.local/src/dwl/dwl repo_art=0
while (($#)); do
  case $1 in
    --theme) theme=$2; shift 2 ;;
    --fontdir) fontdir=$(realpath "$2"); shift 2 ;;
    --font) fonts+=("$2"); shift 2 ;;
    --edit) edits+=("$2"); shift 2 ;;
    --themes) themes=$(realpath "$2"); shift 2 ;;
    --out) out=$2; shift 2 ;;
    --tui) tui=$2; shift 2 ;;
    --play) play=$(realpath "$2"); shift 2 ;;
    --time) limit=$2; shift 2 ;;
    --bin) bin=$(realpath "$2"); shift 2 ;;
    --dwl) dwl_bin=$(realpath "$2"); shift 2 ;;
    --repo-art) repo_art=1; shift ;;
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
if ((repo_art)); then
  # (the installed fonts but the icons, which are the repository's; its icons.sh and themes)
  mkdir -p "$h/.local/share/fonts"
  for f in "$HOME/.local/share/fonts"/*; do [[ ${f##*/} == SumiIcons* ]] || ln -s "$f" "$h/.local/share/fonts/"; done
  cp "$repo"/configs/home/.local/share/fonts/SumiIcons*.ttf "$h/.local/share/fonts/"
  cp "$repo/configs/home/.config/fedokawaii/icons.sh" "$h/.config/fedokawaii/icons.sh"
  cp -a "$repo/configs/home/.config/fedokawaii/themes/." "$h/.config/fedokawaii/themes/"
else
  ln -s "$HOME/.local/share/fonts" "$h/.local/share/fonts"
fi
if [[ -n $themes ]]; then
  [[ -d $themes/.config/fedokawaii/themes ]] || { echo "kit: --themes: no build-themes tree at $themes" >&2; exit 2; }
  cp -a "$themes/.config/fedokawaii/themes/." "$h/.config/fedokawaii/themes/"
  cp -a "$themes/.config/gtk-4.0/gtk.css" "$h/.config/gtk-4.0/gtk.css"
  cp -a "$themes/.config/nvim/lua/plugins/colorscheme.lua" "$h/.config/nvim/lua/plugins/colorscheme.lua"
  mkdir -p "$h/.local/share/themes" && cp -a "$themes/.local/share/themes/." "$h/.local/share/themes/"
  # (foot's colours: the trial's block in place of the installed one)
  python3 -I -c 'import re, sys
new = re.search(r"# >>> colours.*?# <<< colours", open(sys.argv[1]).read(), re.S).group(0)
t = open(sys.argv[2]).read()
open(sys.argv[2], "w").write(re.sub(r"# >>> colours.*?# <<< colours", lambda _: new, t, flags=re.S))' \
    "$themes/.config/foot/foot.ini" "$h/.config/foot/foot.ini" || exit 2
fi
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

# Super+U's window: the size kawa-warm opens it at (the installed one: what the desktop runs)
sys_size=$(sed -n 's/^ *system) .*size=\([0-9]*x[0-9]*\) .*/\1/p' "$(command -v kawa-warm)")
[[ $sys_size =~ ^[0-9]+x[0-9]+$ ]] || { echo "kit: no size for the system window in kawa-warm" >&2; exit 1; }

# inside the headless dwl: the kit's environment, then each scene and its shot
cat >"$K/inside.sh" <<EOF
export HOME=$h XDG_CONFIG_HOME=$h/.config XDG_CACHE_HOME=$h/.cache XDG_STATE_HOME=$h/.local/state
export XDG_DATA_HOME=$h/.local/share FONTCONFIG_FILE=$K/fonts.conf PATH=${bin:+$bin:}$h/.local/bin:/usr/local/bin:/usr/bin:/bin
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
    quick)    # quick settings (Super+X: kawa-quick → kawa-panel), its whole window
      kawa-quick >/dev/null 2>&1 & sleep 2; grim "$out/quick.png"; wtype -k Escape; sleep 0.5 ;;
    tui)      # --tui's script in a floating terminal of its size
      footclient -a float -T tui -W "${tui%%:*}" -- bash "${tui#*:}" >/dev/null 2>&1 &
      sleep 3; grim "$out/tui.png"; wtype -k Escape; sleep 0.5 ;;
    play)     # --play's FILE, in kit-play.sh's words
      export KIT_OUT="$out"; : >"$out/play.log"
      ( . "$here/kit-play.sh"; . "$play" ) || fail=1 ;;
    system|system:[0-9])   # Super+U: its foot window as kawa-warm sizes it (app-id float: dwl puts
      # no warm window away); system:N — Tab pressed N times first (the Nth tab after the first)
      footclient -a float -T system -W $sys_size -- fedokawaii --popup >/dev/null 2>&1 &
      sleep 3; n=\${s#system}; n=\${n#:}
      for ((i = 0; i < \${n:-0}; i++)); do wtype -k Tab; sleep 0.4; done
      grim "$out/\${s/:/-}.png"; wtype -k Escape; sleep 0.5 ;;
    full) grim "$out/full.png" ;;
    *) echo "kit: no scene \$s" >&2; fail=1 ;;
  esac || fail=1
done
exit \$fail
EOF
# (dwl itself in the kit's home and PATH: what it starts — a key's program, a warm window — is
# the kit's too, never the real home's)
HOME=$h XDG_CONFIG_HOME=$h/.config XDG_CACHE_HOME=$h/.cache XDG_STATE_HOME=$h/.local/state \
  XDG_DATA_HOME=$h/.local/share FONTCONFIG_FILE=$K/fonts.conf \
  PATH=${bin:+$bin:}$h/.local/bin:/usr/local/bin:/usr/bin:/bin \
  bash "$here/hl-dwl.sh" "$K/inside.sh" --dwl "$dwl_bin" --time "$limit" --keep "$K/logs"
rc=$?
for s in "${scenes[@]}"; do [[ -f $out/$s.png ]] && echo "$out/$s.png"; done
((rc == 0)) || { echo "kit: a scene failed (exit $rc) — waybar: $(tail -n 3 "$K/waybar.log" 2>/dev/null)" >&2; exit 1; }
