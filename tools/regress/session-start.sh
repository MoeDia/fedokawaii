#!/usr/bin/env bash
# tools/regress/session-start.sh — never again "the desktop does not come up" (and the update's
# smoke test, .claude/notes/update-design.md §4.2): the kit's headless dwl on the real GPU with
# the installed configs, the session's pieces started as autostart starts them — the bar, the
# notices and the terminal server (the kit's own start), quick settings' panel, the three warm
# windows — and after their time: each one still running in this session, and the bar drawn.
# In the theme the desktop has now; the bar itself is measured by bar-geometry.sh.
#   bash tools/regress/session-start.sh [KIT OPTION…]   (the update: --dwl /usr/local/bin/dwl)
# Exit 0 held · 1 broken (its verdict line: "session-start (THEME): …") · 2 the check could not run
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
# (exit 1 only with a verdict of its own; whatever keeps the check itself from running is 2)
if ! bash "$here/../kit.sh" --theme "$th" "$@" --out "$out/kit" --play "$out/play.sh" play >"$out/kit.log" 2>&1; then
  if grep -q '^hl-dwl: dwl ended before the script did' "$out/kit.log"; then
    echo "session-start ($th): dwl does not start: $(sed -n '/^hl-dwl: dwl ended/,$p' "$out/kit.log" | sed 1d | grep -v '^$' | tail -n 2 | paste -sd ' ')" >&2; exit 1
  fi
  [[ -s $out/kit/play.log ]] || { echo "session-start: the kit could not run: $(grep -v '^$' "$out/kit.log" | tail -n 1)" >&2; exit 2; }
fi
# (dwl drew: the bar's rows hold its many colours, not the ground's one)
n=$(python3 -I -c 'import sys; from PIL import Image
im = Image.open(sys.argv[1]).convert("RGB").crop((0, 0, 1920, 27)); print(len(im.getcolors(im.width * im.height)))' \
  "$out/kit/screen.png" 2>/dev/null) || { echo "session-start: the shot could not be measured (python3-pillow, the shot)" >&2; exit 2; }
((n > 16)) || echo "nothing drawn: the bar's rows hold $n colour$( ((n == 1)) || echo s)" >>"$out/kit/play.log"
if [[ -s $out/kit/play.log ]]; then
  echo "session-start ($th): $(paste -sd ';' "$out/kit/play.log" | sed 's/;/ · /g')" >&2; exit 1
fi
echo "session-start ($th): the bar, the notices, the terminals, quick settings and the warm windows up; dwl drawing"
