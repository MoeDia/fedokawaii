# ~/.config/fedokawaii/files.sh — read by the kawa-* helpers that write a file beside others
# (kawa-pick: the save dialog, kawa-clipfiles: a paste, kawa-shrink: a smaller copy).
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
