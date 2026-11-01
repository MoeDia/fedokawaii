# ~/.config/fedokawaii/files.sh — read by the kawa-* helpers that write a file beside others
# (kawa-pick: the save dialog, kawa-clipfiles: a paste, kawa-shrink: a smaller copy), and
# by those that put something on the clipboard (clip_put).
# shellcheck shell=bash

# free_name PATH [dir] — PATH while nothing is there, else the next free "name (1).ext", "name (2).ext"…
# beside it, as Brave names a second download: nothing is ever written over (dir: a folder's
# name, never split at a dot — "v1.2 (1)", not "v1 (1).2")
free_name() {
  local dir=${1%/*} stem=${1##*/} ext="" n=1
  [[ -e $1 || -L $1 ]] || { printf '%s' "$1"; return; }
  [[ ${2:-} != dir && $stem == ?*.* ]] && ext=.${stem##*.} stem=${stem%.*}
  while [[ -e "$dir/$stem ($n)$ext" || -L "$dir/$stem ($n)$ext" ]]; do n=$((n + 1)); done
  printf '%s' "$dir/$stem ($n)$ext"
}

# restored_dir → a folder of its own in ~/Restored for what comes back from a snapshot or a
# backup — DATE-TIME (a second one in the same second: .2, .3 …) — made; its path on stdout
restored_dir() {
  local base dir n=1
  base=$HOME/Restored/$(date '+%Y-%m-%d-%H%M%S'); dir=$base
  while [[ -e $dir ]]; do n=$((n + 1)); dir=$base.$n; done
  mkdir -p -- "$dir" && printf '%s' "$dir"
}
# restore_into DIR ROOT PATH… — each PATH (inside ROOT) copied into DIR, never over anything:
# a line each, its path under ROOT (and the name it got, a second of one name), or why not all
# of it came. Yours, with the labels of where it lands — a reflink where it can (the same disk:
# no space taken until one of them changes)
restore_into() {
  local dir=$1 root=$2 p to f out k; shift 2
  for p; do
    k=""; [[ -d $p && ! -L $p ]] && k=dir
    to=$(free_name "$dir/${p##*/}" "$k")
    f=${p#"$root"/}; [[ ${to##*/} == "${p##*/}" ]] || f+=" — as ${to##*/}"
    if out=$(cp -RP --preserve=mode,timestamps,links --reflink=auto -- "$p" "$to" 2>&1); then printf '   %s\n' "$f"
    else printf '   %s — not all of it: %s\n' "$f" "$(sed -n 1p <<<"$out")"; fi
  done
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

# yazi_focused — the yazi in the focused window, for Super+Z and Super+D (dwl's keys, which
# yazi never sees): its id (YAZI_ID: `ya emit-to ID shell "kawa-shrink %s"` runs on its
# selection, or the file under its cursor) on stdout. Each yazi keeps
# $XDG_RUNTIME_DIR/kawa-yazi.ID — "PID TIME FOLDER", rewritten as it is used (init.lua) —
# and the focused window's title (dwl-bar/title.json: "Yazi: FOLDER") says which: a live one
# whose folder it names, the one used last of those. Fails: the focused window is no yazi
yazi_focused() {
  local run=${XDG_RUNTIME_DIR:-/nonexistent} t f id p tm d best="" bt=0 c
  t=$(jq -r '.text // empty' "$run/dwl-bar/title.json" 2>/dev/null) || return 1
  t=${t//&lt;/<}; t=${t//&gt;/>}; t=${t//&apos;/\'}; t=${t//&quot;/\"}; t=${t//&amp;/&}
  [[ $t == "Yazi: "* ]] || return 1
  t=${t#Yazi: }
  for f in "$run"/kawa-yazi.*; do
    [[ -f $f ]] || continue
    id=${f##*/kawa-yazi.}
    IFS=$'\t' read -r p tm d <"$f" || continue
    read -r c 2>/dev/null </proc/"$p"/comm && [[ $c == yazi ]] || { rm -f -- "$f"; continue; }   # (closed)
    [[ $t == "${d##*/}" || $t == "$d" || $t == "${d/#"$HOME"/\~}" ]] || continue
    [[ ${tm%.*} =~ ^[0-9]+$ ]] && ((${tm//./} > bt)) && { best=$id bt=${tm//./}; }
  done
  [[ -n $best ]] && printf '%s\n' "$best"
}
