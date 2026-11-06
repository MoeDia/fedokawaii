#!/usr/bin/env bash
# tests/content/test_git.sh — kawa-git, the launcher's Git: the repositories in ~/dojo and the
# home (real git, real fd), the last used first, none from hidden folders; the picker a §7
# screen whose Enter opens lazygit in the chosen one; with none, the screen that says how to
# get one — c clones (a real clone, from a local repository), n starts one (git init) — and
# lazygit then opens in it; a bad name or address is said, never acted on. Typed on a terminal
# of its own (pty_run.py); fzf and lazygit are stand-ins, and the real fzf takes c and n.
. "$(dirname "$0")/lib.sh"
. "$REPO/configs/home/.config/fedokawaii/icons.sh"
FD=$(command -v fd 2>/dev/null) GIT=$(command -v git 2>/dev/null)
[[ -n $FD && -n $GIT ]] || { skip "no fd or git here"; exit 0; }

setup() {   # a fresh home; fzf answers with the line of its input that starts with $FZF_PICK's
  sandbox                       # word (the first call only: later ones are Esc), lazygit says where
  config .config/fedokawaii/fzf.opts
  stub fd "exec '$FD' \"\$@\""
  stub fzf 'n=$(cat "$TMP/fzf.n" 2>/dev/null || echo 0); echo $((n + 1)) >"$TMP/fzf.n"
for a; do printf "%s\n" "$a"; done >"$TMP/fzf.args.$((n + 1))"
kind=$(sed -n "s/.*--rows \([a-z]*\)].*/\1/p" "$TMP/fzf.args.$((n + 1))" | head -n1)
kawa-git --rows "$kind" 76 >"$TMP/fzf.in.$((n + 1))"          # (what its start event loads)
[ "$n" = 0 ] && [ -s "$TMP/fzf.pick" ] || exit 130
grep -m1 "^$(cat "$TMP/fzf.pick")	" "$TMP/fzf.in.1"'
  stub lazygit 'pwd >"$TMP/lazygit.pwd"'
  export GIT_CONFIG_GLOBAL=$TMP/gitconfig GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
  printf '[init]\n\tdefaultBranch = main\n' >"$GIT_CONFIG_GLOBAL"
}
repo() { mkdir -p "$1" && "$GIT" init -q "$1" && touch -d "$2" "$1/.git"; }   # repo DIR WHEN
run() { rm -f "$TMP/fzf.n"; python3 -I "$REPO/tests/lib/pty_run.py" --cols 80 --rows 30 "$@" -- kawa-git; }   # run [pty_run options]
hdr() { kawa-git --heading "$1" 76 | head -n1; }                            # hdr KIND — the heading's line
plain() { sed 's/\x1b\[[0-9;]*m//g'; }

setup
repo "$HOME/dojo/old" '-5 days'
repo "$HOME/dojo/new" '-1 hour'
repo "$HOME/dojo/group/deep" '-2 days'
repo "$HOME/project" '-3 days'
repo "$HOME/.cache/tool/src" '-1 minute'               # (a tool's, in a hidden folder)
repo "$HOME/.local/share/nvim/lazy/plugin" '-1 minute'
mkdir -p "$HOME/dojo/notone/sub"
"$GIT" -C "$HOME/dojo/new" checkout -q -b feature

case_ "--list: every repository in ~/dojo and the home, the last used first; none in hidden folders, each once"
eq "$(kawa-git --list | sed "s|^$HOME|~|" | tr '\n' ' ')" "~/dojo/new ~/dojo/group/deep ~/project ~/dojo/old "

case_ "the picker: a §7 screen — the branch icon, repositories, a row each with its branch — Enter opens lazygit in the one chosen"
echo "$HOME/dojo/new" >"$TMP/fzf.pick"
out=$(run); eq "$(cat "$TMP/lazygit.pwd" 2>/dev/null)" "$HOME/dojo/new"
args=$(cat "$TMP/fzf.args.1")
heading_ok "$(hdr list)" 76
lacks "$args" "enter open"; lacks "$args" "esc close"; lacks "$args" "--footer" "nothing obvious on its last line (§7)"
has "$(hdr list)" "$ICON_BRANCH"; lacks "$(hdr list)" "庫" "no kanji (§13)"; has "$args" "--with-nth=2"
has "$args" "--bind=start,resize:reload-sync["; has "$args" "+transform-header["
first=$(head -n1 "$TMP/fzf.in.1" | plain); has "$first" "~/dojo/new"; has "$first" "feature"
eq "$(cut -f1 "$TMP/fzf.in.1" | sed "s|^$HOME|~|" | tr '\n' ' ')" "~/dojo/new ~/dojo/group/deep ~/project ~/dojo/old "

case_ "laid out at the width fzf asks for (a tiled window resized): the heading and each row's branch at the last column"
for w in 40 120; do
  heading_ok "$(kawa-git --heading list "$w" | head -n1)" "$w"
  eq "$(kawa-git --rows list "$w" | head -n1 | cut -f2 | plain | python3 -I -c 'import sys,unicodedata; t=sys.stdin.read().rstrip("\n"); print(sum(2 if unicodedata.east_asian_width(c) in "WF" else 1 for c in t))')" "$((w - 1))" "[$w] the row's width: the value a column inside the band, as the icon is"
done

case_ "Esc: closed, nothing opened (exit 0)"
rm -f "$TMP/fzf.pick" "$TMP/fzf.n" "$TMP/lazygit.pwd"
run >/dev/null; eq "$?" 0; [[ ! -e $TMP/lazygit.pwd ]] && _ok || _no "lazygit opened on Esc"

setup
case_ "none: the screen says there are none and how to get one, with c and n as its keys"
run >/dev/null
args=$(cat "$TMP/fzf.args.1")
heading_ok "$(hdr none)" 76
has "$(kawa-git --heading none 76)" "no repositories yet"
tile() { bash -c 'INK_MUTED=$'"'"'\e[38;5;21m'"'"' INK_OFF=$'"'"'\e[0m'"'"'; . "$1"; screen_tile "$2"' _ "$REPO/configs/home/.config/fedokawaii/screen.sh" "$1"; }
has "$args" "--footer="$'\n'"$(tile c) "$'\e[38;5;21mclone\e[0m   '"$(tile n) "$'\e[38;5;21mnew\e[0m' "its two keys (§7: the key a tile, what it does muted, three columns apart)"
has "$args" "--bind=c:pos(1)+accept,n:pos(2)+accept"
has "$(plain <"$TMP/fzf.in.1")" "clone one"; has "$(plain <"$TMP/fzf.in.1")" "start a new one"

case_ "n: a new repository, its name typed, made in ~/dojo (git init) — and lazygit opens in it"
echo init >"$TMP/fzf.pick"
run --send 1 'my-project\r' >/dev/null
[[ -d $HOME/dojo/my-project/.git ]] && _ok || _no "no ~/dojo/my-project/.git"
eq "$(cat "$TMP/lazygit.pwd" 2>/dev/null)" "$HOME/dojo/my-project"

case_ "n with a name that is no folder name, or one there already: said, nothing made, nothing opened"
for bad in 'a b' '../up' '.hidden' 'taken'; do
  setup; mkdir -p "$HOME/dojo/taken"; echo init >"$TMP/fzf.pick"   # (a folder, no repository)
  out=$(run --send 1 "$bad\\r" --send 2 'x' | plain)
  [[ $bad == taken ]] && has "$out" "is there already" || has "$out" "a name of letters"
  [[ ! -e $TMP/lazygit.pwd ]] && _ok || _no "[$bad] opened"
done
[[ ! -e $HOME/up && ! -e $HOME/dojo/.hidden ]] && _ok || _no "a bad name made a folder"

setup
"$GIT" init -q --bare "$TMP/src/proj.git"
case_ "c: a clone from its address into ~/dojo/NAME — and lazygit opens in it"
echo clone >"$TMP/fzf.pick"
run --send 1 "file://$TMP/src/proj.git\\r" >/dev/null
[[ -d $HOME/dojo/proj/.git ]] && _ok || _no "no ~/dojo/proj"
eq "$(cat "$TMP/lazygit.pwd" 2>/dev/null)" "$HOME/dojo/proj"
case_ "c with an address git cannot clone: said, nothing opened"
setup; echo clone >"$TMP/fzf.pick"
out=$(run --send 1 "file://$TMP/src/nothere.git\\r" --send 3 'x' | plain)
has "$out" "git could not clone it"; [[ ! -e $TMP/lazygit.pwd && ! -e $HOME/dojo/nothere ]] && _ok || _no "opened, or a folder left"

if [[ -n $REAL_FZF ]]; then
  case_ "the real fzf ($("$REAL_FZF" --version | cut -d' ' -f1)): n and c pick their rows on the empty screen"
  setup; stub fzf "exec '$REAL_FZF' \"\$@\""
  run --send 1 'n' --send 2 'from-key\r' >/dev/null
  eq "$(cat "$TMP/lazygit.pwd" 2>/dev/null)" "$HOME/dojo/from-key"
  setup; stub fzf "exec '$REAL_FZF' \"\$@\""; "$GIT" init -q --bare "$TMP/src/k.git"
  run --send 1 'c' --send 2 "file://$TMP/src/k.git\\r" >/dev/null
  eq "$(cat "$TMP/lazygit.pwd" 2>/dev/null)" "$HOME/dojo/k"
else
  skip "no fzf here: the keys c and n not tried in the real one"
fi

case_ "misuse: 2; lazygit missing: said, 1"
setup; rc 2 kawa-git --frob
rm -f "$STUBS/lazygit"; out=$(PATH=$(without lazygit) run | plain); has "$out" "lazygit is missing"

done_
