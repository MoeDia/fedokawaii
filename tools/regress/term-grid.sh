#!/usr/bin/env bash
# tools/regress/term-grid.sh — never again text out of its grid (owner inbox 2 Nov 18:22: "make sure terminal
# text alignment and spacing and everything is tested in an insane wide range of situations"): the desktop's
# text screens and the programs he uses in a real foot, on the real GPU, both themes, at the sizes the
# layouts give (halves, thirds, quarters, master and stack) and from 20 × 5 to the whole screen, odd counts
# too; zoomed in and out; after a theme switch; with long and wide names. Each screen's words as foot
# holds them (its own pipe-visible) and its picture:
#   · no line wider than the window (foot joins a wrapped line back: a wrap is a line too long)
#   · no "…", no shell or Python error on the screen, not blank
#   · the window its size, the text on its grid: its pad's 8 px whole, nothing drawn into them
# Findings known and not yet fixed are in term-grid-known.txt, each with its reason: they are said, a new one fails.
#   bash tools/regress/term-grid.sh [KIT OPTION…]
#   SIZES="80x24 20x5" PROGRAMS="yazi git" THEMES=dark   a part of it; KEEP=1 keeps the shots
# Exit 0 held · 1 broken (each said) · 2 the kit could not run
set -u
here=$(cd "$(dirname "$0")" && pwd)
out=$(mktemp -d /dev/shm/regress-grid.XXXXXX)
[[ ${KEEP:-} == 1 ]] || trap 'rm -rf "$out"' EXIT
[[ ${KEEP:-} == 1 ]] && echo "term-grid: shots in $out" >&2
sizes=${SIZES:-20x5 24x7 33x9 41x17 47x11 58x24 69x17 72x25 76x51 80x24 83x25 88x51 101x31 116x25 116x51 144x40 159x51 235x51}
programs=${PROGRAMS:-prompt git calc clip books wallpaper system yazi lazygit btop nvim wiremix}
themes=${THEMES:-dark light}

cat >"$out/play.sh" <<PLAY_END
SIZES="$sizes"
PROGRAMS="$programs"
PLAY_END
cat >>"$out/play.sh" <<'PLAY_END'
cat >"$HOME/dump" <<'DUMP_END'
#!/bin/sh
cat >"$KIT_OUT/dump.txt"
DUMP_END
chmod +x "$HOME/dump"
panel; nap 1; at 1900 1070
mkdir -p "$HOME/repos/demo" "$HOME/Wide/日本語のフォルダ" "$HOME/Wide/مجلد عربي" "$HOME/Wide/🎉 emoji" "$HOME/Wide/combining é ñ ü" "$HOME/Wide/a very long folder name that goes on and on and on and on and on and on and on"
(cd "$HOME/repos/demo" && git init -q && echo x >a && git add a && git -c user.name=t -c user.email=t@t commit -qm first)
: >"$HOME/pick"
cmd() {
  case $1 in
    prompt)    set -- bash -i ;;
    git)       set -- kawa-git ;;
    calc)      set -- kawa-calc ;;
    clip)      set -- kawa-clip --tui ;;
    books)     set -- kawa-books --tui ;;
    wallpaper) set -- kawa-wallpaper --tui "$HOME/pick" ;;
    system)    set -- fedokawaii --popup ;;
    yazi)      set -- yazi "$HOME" ;;
    wide)      set -- yazi "$HOME/Wide" ;;
    lazygit)   set -- sh -c "cd $HOME/repos/demo && exec lazygit" ;;
    btop)      set -- btop ;;
    nvim)      set -- nvim "$HOME/repos/demo/a" ;;
    wiremix)   set -- wiremix ;;
    *)         set -- sh -c "echo no program $1; exec sleep 60" ;;
  esac
  printf '%s\0' "$@"
}
grab() {   # grab NAME — the screen's words and its picture
  rm -f "$KIT_OUT/dump.txt"; wtype -s 150 -M ctrl -M shift -k F9 -m shift -m ctrl; nap 0.25
  [ -f "$KIT_OUT/dump.txt" ] && mv "$KIT_OUT/dump.txt" "$KIT_OUT/$1.txt"
  shot "$1"
}
open() {   # open PROGRAM SIZE — a floating terminal that size running it; w its pid
  local c=() a
  while IFS= read -r -d '' a; do c+=("$a"); done < <(cmd "$1")
  foot -a float -T grid -W "$2" -o "key-bindings.pipe-visible=[$HOME/dump] Control+Shift+F9" "${c[@]}" >/dev/null 2>&1 & w=$!
}
shut() { kill "$w" 2>/dev/null; wait "$w" 2>/dev/null; nap 0.25; }
shot base
for p in $PROGRAMS; do for s in $SIZES; do
  open "$p" "$s"; nap 1.5; grab "$p-$s"; shut
done; done
# zoomed: the same window, foot's font a step or two up and down (Ctrl+plus, Ctrl+minus): the program
# follows; the name says the steps
for p in yazi prompt git; do
  open "$p" 80x24; nap 1.5
  wtype -s 150 -M ctrl -k equal -k equal -m ctrl; nap 0.8; grab "zoom+2:$p"
  wtype -s 150 -M ctrl -k minus -k minus -k minus -k minus -m ctrl; nap 0.8; grab "zoom-2:$p"
  shut
done
# long and wide names: Japanese, Arabic, emoji, combining marks, a name longer than any window
for s in 47x11 80x24 116x25; do
  open wide "$s"; nap 1.5; grab "wide-$s"; shut
done
# a theme switch with it open
open yazi 80x24; nap 1.5; grab "before-switch"; kawa-theme toggle >/dev/null 2>&1; nap 2.2; grab "after-switch"; kawa-theme toggle >/dev/null 2>&1; nap 1.5; shut
# a live resize while output streams: two tiled, the split moved under it; still running, the grid whole
foot -T stream sh -c 'i=0; while :; do i=$((i + 1)); printf "line %d — the quick brown fox\n" "$i"; done' >/dev/null 2>&1 & s1=$!
nap 0.8
foot -T other sh -c 'exec sleep 120' >/dev/null 2>&1 & s2=$!
nap 0.8
for _ in 1 2 3 4 5 6 7 8; do wtype -s 60 -M logo -k h -m logo; done
for _ in 1 2 3 4 5 6 7 8; do wtype -s 60 -M logo -k l -m logo; done
nap 0.5; shot stream
kill -0 "$s1" 2>/dev/null && say "stream alive" || say "stream dead"
kill "$s1" "$s2" 2>/dev/null
PLAY_END
rc=0
for th in $themes; do
  bash "$here/../kit.sh" --theme "$th" "$@" --time 1200 --out "$out/$th" --play "$out/play.sh" play >"$out/kit-$th.log" 2>&1 \
    || { echo "term-grid: the kit failed: $(tail -n 2 "$out/kit-$th.log")" >&2; exit 2; }
done
python3 -I -B "$here/term-grid.py" "$here/term-grid-known.txt" "$here/../../tests/menus" "$out" $themes || rc=$?
exit "$rc"
