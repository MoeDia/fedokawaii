#!/usr/bin/env bash
# tools/regress/session-start.sh — never again "the desktop does not come up" (and the update's
# smoke test, .claude/notes/update-design.md §4.2): the kit's headless dwl on the real GPU with
# the installed configs, the session's pieces started as autostart starts them — the bar, the
# notices and the terminal server (the kit's own start), quick settings' panel, the three warm
# windows — and after their time: each one still running in this session, and the bar drawn.
# In the theme the desktop has now; the bar itself is measured by bar-geometry.sh.
#   bash tools/regress/session-start.sh [KIT OPTION…]   (the update: --dwl /usr/local/bin/dwl)
# Exit 0 held · 1 broken (said) · 2 the kit could not run
set -u
here=$(cd "$(dirname "$0")" && pwd)
out=$(mktemp -d /dev/shm/regress-session.XXXXXX)
[[ ${KEEP:-} == 1 ]] || trap 'rm -rf "$out"' EXIT
th=$(readlink "$HOME/.config/fedokawaii/current"); th=${th##*/}
[[ $th == @(dark|light) ]] || { echo "session-start: no theme in ~/.config/fedokawaii/current" >&2; exit 2; }
cat >"$out/play.sh" <<'PLAY'
panel
warm
nap 4
# (this session's own: a process whose environment names this run's runtime folder)
mine() {
  local p
  for p in $(pgrep "$@"); do grep -qz "^XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR\$" "/proc/$p/environ" 2>/dev/null && return 0; done
  return 1
}
for n in waybar mako foot kawa-panel; do mine -x "$n" || say "not running: $n"; done
for n in notes clip system; do mine -f "kawa-warm --inside $n\$" || say "not running: the warm window $n"; done
shot screen
PLAY
bash "$here/../kit.sh" --theme "$th" "$@" --out "$out/kit" --play "$out/play.sh" play >"$out/kit.log" 2>&1 \
  || { echo "session-start: the kit failed: $(tail -n 2 "$out/kit.log")" >&2; exit 2; }
# (dwl drew: the bar's rows hold its many colours, not the ground's one)
n=$(python3 -I -c 'import sys; from PIL import Image
im = Image.open(sys.argv[1]).convert("RGB").crop((0, 0, 1920, 27)); print(len(im.getcolors(im.width * im.height)))' \
  "$out/kit/screen.png" 2>/dev/null) || n=0
((n > 16)) || echo "nothing drawn: the bar's rows hold $n colour$( ((n == 1)) || echo s)" >>"$out/kit/play.log"
if [[ -s $out/kit/play.log ]]; then
  echo "session-start ($th): $(paste -sd ';' "$out/kit/play.log" | sed 's/;/ · /g')" >&2; exit 1
fi
echo "session-start ($th): the bar, the notices, the terminals, quick settings and the warm windows up; dwl drawing"
