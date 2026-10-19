# ~/.config/fedokawaii/files.sh — read by the kawa-* helpers that write a file beside others
# (kawa-pick: the save dialog, kawa-clipfiles: a paste, kawa-shrink: a smaller copy), and
# by those that put something on the clipboard (clip_put).
# shellcheck shell=bash

# free_name PATH — PATH while nothing is there, else the next free "name (1).ext", "name (2).ext"…
# beside it, as Brave names a second download: nothing is ever written over
free_name() {
  local dir=${1%/*} stem=${1##*/} ext="" n=1
  [[ -e $1 || -L $1 ]] || { printf '%s' "$1"; return; }
  [[ $stem == ?*.* ]] && ext=.${stem##*.} stem=${stem%.*}
  while [[ -e "$dir/$stem ($n)$ext" || -L "$dir/$stem ($n)$ext" ]]; do n=$((n + 1)); done
  printf '%s' "$dir/$stem ($n)$ext"
}

# clip_put TYPE — stdin onto the clipboard as TYPE, by a wl-copy in a session of its own (the
# terminal or the menu it was started from may close at once: the copy stays), then checked:
# 0 once the clipboard offers TYPE (within 2 s), 1 if it never does. Each copy is logged in
# ~/.cache/kawa-clip.log (what, and whether it took) — fedokawaii report reads it.
clip_put() {
  local t=$1 i ok=1 log=$HOME/.cache/kawa-clip.log
  setsid -f wl-copy --type "$t" || ok=0
  for ((i = 0; ok && i < 40; i++)); do
    wl-paste --list-types 2>/dev/null | grep -qxF -- "$t" && break
    sleep 0.05
  done
  ((ok && i < 40)) || ok=0
  mkdir -p "${log%/*}"
  printf '%(%F %T)T %s: %s %s\n' -1 "${0##*/}" "$t" "$( ((ok)) && echo "on the clipboard" || echo "NOT on the clipboard")" >>"$log"
  ((ok))
}
