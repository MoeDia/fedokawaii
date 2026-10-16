#!/usr/bin/env bash
# tests/engine/test_copy.sh — changing the desktop itself (handbook, chapter 42): `fedokawaii
# copy` makes the working copy once, `keep` brings a config changed in place into it, `diff`
# shows what apply would change, `apply` checks the scripts and hands the copy to root. What
# is yours is never overwritten, and every refusal names the place the change belongs.
. "$(dirname "$0")/lib.sh"

fresh() {
  sandbox; engine_world
  # the toolkit as the copy will see it: a helper, a config, one with theme.sh's tokens
  printf '#!/usr/bin/env bash\necho helper\n' >"$R/toolkit/bin/kawa-x"; chmod 755 "$R/toolkit/bin/kawa-x"
  mkdir -p "$R/toolkit/configs/home/.config/waybar"
  printf '{ "home": "@HOME@/x" }\n' >"$R/toolkit/configs/home/.config/waybar/config"
  printf '# hello\n' >"$R/toolkit/configs/home/.config/foot/notes and todo.sh"
  C=$HOME/repos/fedokawaii
}
ident() { git config --global user.name "Kawa Tester"; git config --global user.email kawa@example.org; }

# ── copy ─────────────────────────────────────────────────────────────────────
case_ "copy with no toolkit: said, nothing made"
fresh; rm -rf "$R/toolkit"
out=$(fedokawaii copy 2>&1); eq "$?" 1; has "$out" "the toolkit is missing"; [[ ! -e $C ]] && _ok || _no "a copy was made"

case_ "copy, the first time, git not knowing your name: made, how to commit it said"
fresh
out=$(fedokawaii copy 2>&1); eq "$?" 0
[[ -f $C/setup.sh && -f $C/fedokawaii.sh && -f $C/bin/kawa-x ]] && _ok || _no "files missing from the copy"
eq "$(git -C "$C" symbolic-ref --short HEAD 2>/dev/null)" main
cmp -s "$C/.git/fedokawaii-conf-base" "$R/toolkit/fedokawaii.conf" && _ok || _no "the settings' base was not kept"
has "$out" "git does not know your name yet"; has "$out" "lazygit in $C"
case_ "…then again: nothing committed yet, said (and nothing overwritten)"
echo mine >>"$C/bin/kawa-x"
out=$(fedokawaii copy 2>&1); eq "$?" 0; has "$out" "nothing committed yet"; has "$(cat "$C/bin/kawa-x")" mine

case_ "copy with git knowing your name: committed as installed; files yours to change"
fresh; ident
out=$(fedokawaii copy 2>&1); eq "$?" 0
has "$(git -C "$C" log --oneline 2>/dev/null)" "fedokawaii as installed ($(date +%F))"
[[ -w $C/bin/kawa-x ]] && _ok || _no "not writable"
eq "$(git -C "$C" status --porcelain | wc -l)" 0 "the copy is clean"
case_ "…then again: the copy named, with what changed since its last commit"
eq "$(fedokawaii copy)" "  your working copy: $C"
echo x >>"$C/bin/kawa-x"; echo y >"$C/new.txt"
has "$(fedokawaii copy)" "2 file(s) changed since its last commit"

case_ "copy where something else already is: refused, how to go on said"
fresh; mkdir -p "$C"; echo "my notes" >"$C/notes.txt"
out=$(fedokawaii copy 2>&1); eq "$?" 1; has "$out" "no working copy at $C"; has "$out" "FEDOKAWAII_COPY"
eq "$(ls "$C")" "notes.txt" "nothing added to your folder"
case_ "copy at a path with spaces and Japanese (FEDOKAWAII_COPY)"
fresh; ident; export FEDOKAWAII_COPY="$HOME/my repos/設定 copy"
out=$(fedokawaii copy 2>&1); eq "$?" 0; [[ -f "$FEDOKAWAII_COPY/setup.sh" ]] && _ok || _no "not made"
has "$(git -C "$FEDOKAWAII_COPY" log --oneline)" "as installed"
unset FEDOKAWAII_COPY
case_ "copy into a folder you cannot write: it fails (exit 1), no half copy is called done"
if ((EUID)); then
  fresh; mkdir -p "$HOME/repos"; chmod 555 "$HOME/repos"
  out=$(fedokawaii copy 2>&1); eq "$?" 1; lacks "$out" "your working copy: $C — change it there"
  chmod 755 "$HOME/repos"
else _ok; fi

# ── keep ─────────────────────────────────────────────────────────────────────
fresh; ident; fedokawaii copy >/dev/null
config .config/foot/foot.ini 2>/dev/null || { mkdir -p "$HOME/.config/foot"; cp "$R/toolkit/configs/home/.config/foot/foot.ini" "$HOME/.config/foot/"; }
cp "$R/toolkit/configs/home/.config/foot/foot.ini" "$HOME/.config/foot/foot.ini"
case_ "keep a config you did not change: already the same"
out=$(fedokawaii keep "$HOME/.config/foot/foot.ini" 2>&1); eq "$?" 0; has "$out" "already the same in the copy"
case_ "keep a config you changed: copied to its place in the copy, apply named"
echo "font=Other:size=13" >>"$HOME/.config/foot/foot.ini"
out=$(fedokawaii keep "$HOME/.config/foot/foot.ini" 2>&1); eq "$?" 0
has "$out" "kept: configs/home/.config/foot/foot.ini — fedokawaii apply makes it the desktop's"
cmp -s "$HOME/.config/foot/foot.ini" "$C/configs/home/.config/foot/foot.ini" && _ok || _no "not copied"
case_ "keep by a relative path, from inside the folder"
echo "# more" >>"$HOME/.config/foot/foot.ini"
out=$(cd "$HOME/.config/foot" && fedokawaii keep foot.ini 2>&1); has "$out" "kept: configs/home/.config/foot/foot.ini"
case_ "keep a helper of ~/.local/bin: it goes to bin/"
mkdir -p "$HOME/.local/bin"; printf '#!/usr/bin/env bash\necho changed\n' >"$HOME/.local/bin/kawa-x"
out=$(fedokawaii keep "$HOME/.local/bin/kawa-x" 2>&1); has "$out" "kept: bin/kawa-x"
case_ "keep a name with spaces"
cp "$R/toolkit/configs/home/.config/foot/notes and todo.sh" "$HOME/.config/foot/"; echo "# mine" >>"$HOME/.config/foot/notes and todo.sh"
out=$(fedokawaii keep "$HOME/.config/foot/notes and todo.sh" 2>&1); has "$out" "kept: configs/home/.config/foot/notes and todo.sh"
case_ "keep what is drawn or filled in: never copied, its source named"
mkdir -p "$HOME/.local/share/themes/Fedokawaii" "$HOME/.local/share/icons/Fedokawaii"
for f in .config/fedokawaii/themes/dark/colors.sh .local/share/themes/Fedokawaii/x.css .config/fedokawaii/icons.sh .local/share/icons/Fedokawaii/cursor .config/fedokawaii/env; do
  mkdir -p "$(dirname "$HOME/$f")"; [[ -e $HOME/$f ]] || echo x >"$HOME/$f"
done
out=$(fedokawaii keep "$HOME/.config/fedokawaii/themes/dark/colors.sh" 2>&1); has "$out" "tools/build-themes.py"
out=$(fedokawaii keep "$HOME/.config/fedokawaii/icons.sh" 2>&1); has "$out" "art/icons.txt"
out=$(fedokawaii keep "$HOME/.local/share/icons/Fedokawaii/cursor" 2>&1); has "$out" "art/cursors.txt"
out=$(fedokawaii keep "$HOME/.config/fedokawaii/env" 2>&1); has "$out" "fedokawaii settings"
case_ "keep a config with theme.sh's tokens: the change made by hand in the copy"
mkdir -p "$HOME/.config/waybar"; echo '{ "home": "/home/me/x", "more": 1 }' >"$HOME/.config/waybar/config"
out=$(fedokawaii keep "$HOME/.config/waybar/config" 2>&1); has "$out" "make the same change in $C/configs/home/.config/waybar/config by hand"
has "$(cat "$C/configs/home/.config/waybar/config")" "@HOME@" "the copy keeps its token"
case_ "keep what is not the toolkit's, what is outside your home, what does not exist"
echo x >"$HOME/.config/mine.conf"
out=$(fedokawaii keep "$HOME/.config/mine.conf" 2>&1); has "$out" "not one of the toolkit's files"
out=$(fedokawaii keep /etc/hostname 2>&1); has "$out" "not in your home"
out=$(fedokawaii keep "$HOME/.config/nope" 2>&1); has "$out" "no such file"
case_ "keep: exit 1 when a file could not be kept (0 only when every one was)"
rc 1 fedokawaii keep "$HOME/.config/nope"
rc 1 fedokawaii keep "$HOME/.config/foot/foot.ini" "$HOME/.config/nope"
rc 0 fedokawaii keep "$HOME/.config/foot/foot.ini"
case_ "keep a link that leads outside your home: refused"
ln -s /etc/hostname "$HOME/.config/foot/linked.ini"
out=$(fedokawaii keep "$HOME/.config/foot/linked.ini" 2>&1); has "$out" "not in your home"
case_ "keep when your home is reached through a link (HOME=/home → /var/home)"
ln -s "$HOME" "$TMP/linkhome"
out=$(HOME=$TMP/linkhome FEDOKAWAII_COPY=$C fedokawaii keep "$TMP/linkhome/.config/foot/foot.ini" 2>&1)
lacks "$out" "not in your home"
case_ "keep with no working copy: how to make one"
out=$(FEDOKAWAII_COPY=$TMP/none fedokawaii keep "$HOME/.config/foot/foot.ini" 2>&1); eq "$?" 1; has "$out" "fedokawaii copy makes one"

# ── diff ─────────────────────────────────────────────────────────────────────
case_ "diff of a copy as made: the same — nothing to apply"
fresh; ident; fedokawaii copy >/dev/null
out=$(fedokawaii diff 2>&1); eq "$?" 0; has "$out" "the copy and the toolkit are the same"; not_called '^less'
case_ "diff of a change: the diff, in the pager"
echo "font=Changed" >>"$C/configs/home/.config/foot/foot.ini"
fedokawaii diff; called '^less -R'; has "$(plain "$(cat "$R/less.out")")" "+font=Changed"
case_ "diff: the settings you saved from the menu since the copy was made are no change of the copy's"
fresh; ident; fedokawaii copy >/dev/null
sed -i 's/^STEAM="yes"/STEAM="no"/' "$R/toolkit/fedokawaii.conf"     # (the menu's settings, saved as root)
out=$(fedokawaii diff 2>&1); has "$out" "the same — nothing to apply"
case_ "diff: the copy's own change of a setting is"
sed -i 's/^MONITOR_HZ="144"/MONITOR_HZ="60"/' "$C/fedokawaii.conf"
fedokawaii diff >/dev/null; has "$(plain "$(cat "$R/less.out")")" '+MONITOR_HZ="60"'
case_ "diff with no copy, no toolkit: said"
out=$(FEDOKAWAII_COPY=$TMP/none fedokawaii diff 2>&1); eq "$?" 1; has "$out" "no working copy"

# ── apply ────────────────────────────────────────────────────────────────────
fresh; ident; fedokawaii copy >/dev/null
case_ "apply: ShellCheck reads the scripts you changed and added, then root applies the copy"
echo 'echo more' >>"$C/bin/kawa-x"; printf '#!/bin/bash\necho new\n' >"$C/bin/kawa-new"
mkdir -p "$C/bin/extra"; printf '#!/usr/bin/env bash\necho deep\n' >"$C/bin/extra/kawa-deep"; echo "plain text" >"$C/bin/extra/README"
echo "# changed" >>"$C/configs/home/.config/foot/notes and todo.sh"
out=$(fedokawaii apply 2>&1); eq "$?" 0
called '^shellcheck -x -S warning -- '; called 'bin/kawa-x'; called 'bin/kawa-new'; called 'bin/extra/kawa-deep'
called 'configs/home/.config/foot/notes and todo.sh'
not_called 'README'
has "$(front_calls)" "front apply" "root ran the copy's front"
called "^sudo bash $C/fedokawaii.sh apply"
case_ "apply: ShellCheck's notes do not stop it (said, then applied)"
stub shellcheck 'echo "In bin/kawa-x line 3: SC2086"; exit 1'
out=$(fedokawaii apply 2>&1); has "$out" "ShellCheck's notes on the scripts you changed"; has "$out" "apply goes on"
case_ "apply with no ShellCheck installed: applied all the same"
out=$(without shellcheck -- fedokawaii apply 2>&1); eq "$?" 0
case_ "apply's outcome comes back (3: applied, something still needs you)"
echo 3 >"$R/rc-apply"; rc 3 fedokawaii apply
case_ "apply while an update runs: said at once, no password"
: >"$R/state/lock"; ( exec 9>"$R/state/lock"; flock 9; exec sleep 30 ) >/dev/null 2>&1 & holder=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do flock -n "$R/state/lock" true || break; sleep 0.1; done
reset_calls; out=$(fedokawaii apply 2>&1); eq "$?" 1; has "$out" "running now"; not_called '^sudo'
kill "$holder" 2>/dev/null; wait "$holder" 2>/dev/null
case_ "apply with no copy: how to make one"
out=$(FEDOKAWAII_COPY=$TMP/none fedokawaii apply 2>&1); eq "$?" 1; has "$out" "fedokawaii copy makes one"

done_
