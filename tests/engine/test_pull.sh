#!/usr/bin/env bash
# tests/engine/test_pull.sh — fedokawaii pull: the one clone (~/repos/fedokawaii) brought to
# GitHub's newest (a local bare repository stands in for it), then the update run from it
# through sudo, and repair when verify still finds something; a working copy made by
# `fedokawaii copy` turned into the clone (packed first when it holds anything of yours);
# setup's clone adopted into place; the token kept in secrets.sh, never in .git/config.
. "$(dirname "$0")/lib.sh"

fresh() {
  sandbox; engine_world; stub notify-send
  C=$HOME/repos/fedokawaii
  git config --global user.name "Kawa Tester"; git config --global user.email kawa@example.org
  git config --global init.defaultBranch main
  # GitHub: a bare repository holding the toolkit's files (its front the stand-in)
  O=$TMP/origin.git W=$TMP/upstream
  cp -r "$R/toolkit" "$W" && git -C "$W" init -q -b main && git -C "$W" add -A && git -C "$W" commit -qm first
  git clone -q --bare "$W" "$O"; git -C "$W" remote add origin "$O"
  export FEDOKAWAII_ORIGIN=file://$O
}
upstream_commit() { echo "$1" >>"$W/README.md"; git -C "$W" add -A && git -C "$W" commit -qm "$1" && git -C "$W" push -q origin main; }
rec() { printf '%s\n' "$2" >"$R/state/$1"; }

case_ "pull with no clone yet: GitHub's cloned, the update runs from it (sudo), no repair when verify passed"
fresh; rec last-verify "$(date +%s) 200 0 0"
out=$(fedokawaii pull 2>&1); eq "$?" 0 "$out"
[[ -d $C/.git ]] && _ok || _no "no clone"
eq "$(git -C "$C" remote get-url origin)" "file://$O"
eq "$(front_calls)" "front update"
called "^sudo bash $C/fedokawaii.sh update"
has "$out" "cloned"; has "$(cat "$HOME/.local/state/fedokawaii/pull.log")" "fedokawaii pull"
read -r t res h <"$HOME/.local/state/fedokawaii/last-pull"; eq "$res" ok; eq "$h" "$(git -C "$C" rev-parse --short HEAD)"
called "^notify-send .*fedokawaii pull up to date with GitHub"

case_ "GitHub moved on: fast-forwarded, the new commits listed; your uncommitted change kept"
upstream_commit "a fix"; echo "# mine" >>"$C/setup.sh"; reset_calls; : >"$R/front.log"
out=$(fedokawaii pull 2>&1); eq "$?" 0 "$out"
has "$out" "a fix"; has "$out" "your changes in the clone are kept"
eq "$(tail -n1 "$C/setup.sh")" "# mine"; eq "$(git -C "$C" log -1 --format=%s)" "a fix"

case_ "verify still finds something after the update: repair follows, from the toolkit"
rec last-verify "$(date +%s) 200 2 0"; : >"$R/front.log"
out=$(fedokawaii pull 2>&1); eq "$(front_calls | tr '\n' '|')" "front update|front repair|"
has "$out" "repair follows"; called "^sudo bash $R/toolkit/fedokawaii.sh repair"
case_ "the update failing (1): repair follows too; a repair that fails is the outcome, said in a notice"
rec last-verify "$(date +%s) 200 0 0"; echo 1 >"$R/rc-update"; echo 1 >"$R/rc-repair"; : >"$R/front.log"; reset_calls
fedokawaii pull >/dev/null 2>&1; eq "$?" 1; eq "$(front_calls | tr '\n' '|')" "front update|front repair|"
called "^notify-send -a desktop -u critical"; read -r t res h <"$HOME/.local/state/fedokawaii/last-pull"; eq "$res" failed
rm -f "$R/rc-update" "$R/rc-repair"

case_ "your commits and GitHub's went apart: stopped before anything runs as root, how to go on said"
upstream_commit "theirs"; echo x >>"$C/README.md"; git -C "$C" commit -qam mine; : >"$R/front.log"
out=$(fedokawaii pull 2>&1); eq "$?" 1; has "$out" "went apart"; eq "$(front_calls)" ""

case_ "the working copy fedokawaii copy made (no GitHub, the toolkit's files): turned into the clone, nothing packed"
fresh; rec last-verify "$(date +%s) 200 0 0"; echo old >"$R/toolkit/left-over"   # (a file the toolkit still has, GitHub no longer)
fedokawaii copy >/dev/null 2>&1; [[ -d $C/.git ]] && ! git -C "$C" remote get-url origin >/dev/null 2>&1 && _ok || _no "copy not made as before"
git -C "$C" rev-parse -q --verify HEAD >/dev/null && git -C "$C" update-ref -d HEAD   # (git knew the name: committed — this test is the uncommitted copy)
out=$(fedokawaii pull 2>&1); eq "$?" 0 "$out"
eq "$(git -C "$C" remote get-url origin)" "file://$O"; [[ ! -e $C/left-over ]] && _ok || _no "a file GitHub lacks stayed"
lacks "$out" "packed"; [[ ! -e $C/.git/fedokawaii-conf-base ]] && _ok || _no "the old copy's settings record stayed"
case_ "…one with a file you changed: packed first, then the clone"
fresh; fedokawaii copy >/dev/null 2>&1; echo "# changed" >>"$C/setup.sh"
out=$(fedokawaii pull 2>&1); eq "$?" 0 "$out"; has "$out" "packed"
p=$(ls "$HOME"/.local/state/fedokawaii/clone-before-*.tar.gz); [[ -s $p ]] && _ok || _no "no pack"
tar -xzOf "$p" fedokawaii/setup.sh | grep -q '# changed' && _ok || _no "the change is not in the pack"
lacks "$(cat "$C/setup.sh")" "# changed"
case_ "the copy's place holding something else: refused, how to go on said"
fresh; mkdir -p "$C"; echo x >"$C/notes"
out=$(fedokawaii pull 2>&1); eq "$?" 1; has "$out" "something else"; eq "$(front_calls)" ""

case_ "setup's clone adopted (--adopt): moved to ~/repos/fedokawaii, its origin the public address — a token in it and an old one in secrets.sh dropped"
fresh; D=$HOME/fedokawaii; git clone -q "$O" "$D"
git -C "$D" remote set-url origin "https://x-access-token:ghp_abcdefghijklmnopqrstuvwxyz0123@github.com/MoeDia/fedokawaii.git"
S=$HOME/.config/fedokawaii/secrets.sh; mkdir -p "${S%/*}"
printf "PROWLARR_API_KEY=abc\nFEDOKAWAII_GITHUB_TOKEN='ghp_old'\n" >"$S"; chmod 600 "$S"
out=$(fedokawaii --adopt "$D" </dev/null 2>&1); eq "$?" 0 "$out"
[[ -d $C/.git && ! -e $D ]] && _ok || _no "not moved"
eq "$(git -C "$C" remote get-url origin)" "file://$O"
lacks "$(cat "$C/.git/config")" "ghp_" "no token in .git/config"
lacks "$(cat "$S")" "FEDOKAWAII_GITHUB_TOKEN"; has "$(cat "$S")" "PROWLARR_API_KEY=abc"; eq "$(stat -c %a "$S")" 600
case_ "adopt declines when ~/repos/fedokawaii is a clone already (setup then tidies its folder as before)"
D3=$HOME/third; git clone -q "$O" "$D3"
fedokawaii --adopt "$D3" </dev/null >/dev/null 2>&1; eq "$?" 1; [[ -d $D3 ]] && _ok || _no "moved anyway"
case_ "adopt over an uncommitted copy of the toolkit's files: replaced, nothing packed; over a changed one: packed"
fresh; fedokawaii copy >/dev/null 2>&1; git -C "$C" update-ref -d HEAD 2>/dev/null
D=$HOME/fk; git clone -q "$O" "$D"; out=$(fedokawaii --adopt "$D" </dev/null 2>&1); eq "$?" 0; lacks "$out" packed
fresh; fedokawaii copy >/dev/null 2>&1; echo "# mine" >>"$C/setup.sh"
D=$HOME/fk; git clone -q "$O" "$D"; out=$(fedokawaii --adopt "$D" </dev/null 2>&1); eq "$?" 0; has "$out" packed

case_ "pull reads the public repository: no credential helper, git never prompts"
fresh; stub git 'case "$*" in *"credential.helper= "*) echo "plain" >>"$TMP/git-auth" ;; esac; [ "$GIT_TERMINAL_PROMPT" = 0 ] || echo prompt >>"$TMP/git-prompt"; exec /usr/bin/git "$@"'
fedokawaii pull >/dev/null 2>&1; [[ -s $TMP/git-auth ]] && _ok || _no "a credential helper left in"; [[ ! -e $TMP/git-prompt ]] && _ok || _no "git could prompt"
case_ "GitHub not answering: said, nothing runs as root"
fresh; export FEDOKAWAII_ORIGIN=https://example.invalid/fedokawaii.git
out=$(timeout 60 fedokawaii pull 2>&1 </dev/null); eq "$?" 1; has "$out" "GitHub does not answer"; eq "$(front_calls)" ""

case_ "pull is a job: in Super+U's popup it goes to a window of its own"
fresh; stub setsid; FEDOKAWAII_POPUP=yes fedokawaii --run pull </dev/null; called "^setsid -f .*--job pull"
case_ "an update or repair running (root's lock): said at once, git untouched"
fresh; ( exec 9>"$R/state/lock"; flock 9; exec sleep 30 ) >/dev/null 2>&1 & holder=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do flock -n "$R/state/lock" true || break; sleep 0.1; done
out=$(fedokawaii pull 2>&1); eq "$?" 1; has "$out" "running now"; [[ ! -e $C ]] && _ok || _no "cloned anyway"
kill "$holder" 2>/dev/null; wait "$holder" 2>/dev/null

done_
