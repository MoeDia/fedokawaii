#!/usr/bin/env bash
# tests/engine/test_front.sh — fedokawaii.sh, root's front: every action and menu entry runs
# the right script with the right words, its outcome comes back, the desktop user is the right
# one whatever their name looks like, and `apply` makes a working copy the toolkit only when
# every script in it parses. setup.sh, theme.sh, check.sh and verify.sh are stand-ins that
# say what they were asked (lib.sh); "root" is a variable here, so this runs as anyone.
. "$(dirname "$0")/lib.sh"

fresh() {
  sandbox; engine_world; front_world
  export FK_EUID=0 SUDO_USER=kawa
  echo kawa >"$R/state/user"
  # the desktop user's home, as getent tells it
  stub getent 'case "$2" in kawa|mo.eldoush|2fast|Ali-Baba) printf "%s:x:1000:1000::%s:/bin/bash\n" "$2" "$HOME" ;; *) exit 2 ;; esac'
  F=$R/toolkit/fedokawaii.sh
}
front() { bash "$F" "$@"; }

# ── as a user, and misuse ────────────────────────────────────────────────────
fresh
case_ "run as a user: it says sudo is needed (exit 2), and touches nothing"
out=$(FK_EUID=1000 bash "$F" update 2>&1); eq "$?" 2
eq "$out" "run with sudo: sudo bash fedokawaii.sh"
[[ ! -e $R/fedokawaii.log ]] && _ok || _no "the log was touched"; eq "$(front_calls)" ""
case_ "help: the actions, exit 0 (as root or not)"
out=$(front --help 2>&1); eq "$?" 0; has "$out" "check    is this machine ready?"; has "$out" "apply"; lacks "$out" "#"
out=$(FK_EUID=1000 bash "$F" -h 2>&1); eq "$?" 0; has "$out" "sudo bash fedokawaii.sh ACTION"
case_ "an unknown action: exit 2, the actions named"
out=$(front frobnicate 2>&1); eq "$?" 2; has "$out" "unknown action: frobnicate"; has "$out" "check setup theme"
rc 2 front ""; rc 2 front upgrade --later; rc 2 front update now
eq "$(front_calls)" "" "nothing ran"

# ── the actions ──────────────────────────────────────────────────────────────
case_ "each action runs its script, with its words"
fresh
for a in check setup all verify update upgrade repair status drift theme; do rc 0 front "$a"; done
rc 0 front upgrade --now
exp="check.sh  (from $R/toolkit)
setup.sh  (from $R/toolkit)
setup.sh  (from $R/toolkit)
verify.sh  (from $R/toolkit)
setup.sh --update (from $R/toolkit)
setup.sh --upgrade (from $R/toolkit)
setup.sh --repair (from $R/toolkit)
setup.sh --status (from $R/toolkit)
theme.sh --user kawa --check (from $R/toolkit)
theme.sh --user kawa (from $R/toolkit)
setup.sh --upgrade --now (from $R/toolkit)"
eq "$(front_calls | sed 's/^\([a-z]*\) /\1.sh /')" "$exp"
case_ "setup alone forgets 'with theme'; both remembers it"
: >"$R/state/with-theme"; front setup >/dev/null; [[ ! -e $R/state/with-theme ]] && _ok || _no "with-theme kept"
front all >/dev/null; [[ -e $R/state/with-theme ]] && _ok || _no "with-theme not made"
case_ "outcomes come back: verify 3, drift 3 and 4, repair 3, update 1, a stopped update 130"
echo 3 >"$R/rc-verify"; rc 3 front verify
echo 3 >"$R/rc-theme"; rc 3 front drift; echo 4 >"$R/rc-theme"; rc 4 front drift
echo 3 >"$R/rc-setup"; rc 3 front repair; echo 1 >"$R/rc-setup"; rc 1 front update
echo 130 >"$R/rc-setup"; rc 130 front update

# ── who the desktop user is ──────────────────────────────────────────────────
case_ "the user setup recorded is the one themed (whoever ran sudo)"
fresh; export SUDO_USER=someoneelse; front theme >/dev/null; has "$(front_calls)" "theme --user kawa"
case_ "before setup recorded one: USERNAME from fedokawaii.conf — dots, digits, capitals, a dash"
for u in mo.eldoush 2fast Ali-Baba; do
  fresh; rm -f "$R/state/user"; sed -i "s/^USERNAME=\"\"/USERNAME=\"$u\"/" "$R/toolkit/fedokawaii.conf"
  front theme >/dev/null; has "$(front_calls)" "theme --user $u " "USERNAME=$u"
done
case_ "…written with single quotes, or bare, it is the same user"
fresh; rm -f "$R/state/user"; sed -i "s/^USERNAME=\"\"/USERNAME='mo.eldoush'   # me/" "$R/toolkit/fedokawaii.conf"
front theme >/dev/null; has "$(front_calls)" "theme --user mo.eldoush "
fresh; rm -f "$R/state/user"; sed -i "s/^USERNAME=\"\"/USERNAME=mo.eldoush/" "$R/toolkit/fedokawaii.conf"
front theme >/dev/null; has "$(front_calls)" "theme --user mo.eldoush "
case_ "…empty: whoever ran sudo; and root itself is never the desktop user"
fresh; rm -f "$R/state/user"; export SUDO_USER=kawa; front theme >/dev/null; has "$(front_calls)" "theme --user kawa"
fresh; rm -f "$R/state/user"; export SUDO_USER=root
out=$(front theme 2>&1); eq "$?" 1; has "$out" "unknown desktop user — run setup first"; eq "$(front_calls)" ""
out=$(front drift 2>&1); eq "$?" 1; has "$out" "unknown desktop user"
unset SUDO_USER; out=$(front theme 2>&1); eq "$?" 1

# ── the menu (for the install) ───────────────────────────────────────────────
case_ "the menu: where setup stands, nine entries"
fresh; rm -f "$R/state/phase"
out=$(printf 'q\n' | front 2>&1); eq "$?" 0
has "$out" "F E D O K A W A I I"; has "$out" "setup: not started · theme: not applied"; has "$out" "9  Repair"
echo 2 >"$R/state/phase"; has "$(printf 'q\n' | front 2>&1)" "setup: phase 2 of 3"
echo 'done' >"$R/state/phase"; mkdir -p "$HOME/.local/state/fedokawaii"; : >"$HOME/.local/state/fedokawaii/theme-applied"
has "$(printf 'q\n' | front 2>&1)" "setup: complete · theme: applied"
case_ "the menu: every number runs its action, then the menu again"
fresh
printf '1\n2\n3\n4\n5\n6\n7\n8\n9\nq\n' | front >/dev/null 2>&1
eq "$(front_calls | awk '{ print $1 ($2 ~ /^--/ ? " " $2 : "") }' | tr '\n' '|')" "check|setup|theme --user|setup|verify|setup --update|theme --user|setup --status|setup --repair|"
case_ "the menu: a failing action keeps the menu; a wrong key says what is wanted; q, Q, Enter, end of input leave"
fresh; echo 1 >"$R/rc-verify"
out=$(printf '5\nx\n10\nq\n' | front 2>&1); eq "$?" 0; has "$out" "1–9 or q"; eq "$(grep -c 'F E D O' <<<"$out")" 4
for k in q Q ""; do printf '%s\n' "$k" | front >/dev/null 2>&1; eq "$?" 0 "[$k]"; done
front </dev/null >/dev/null 2>&1; eq "$?" 0 "end of input"

# ── conf: the settings, checked before they are saved ────────────────────────
case_ "conf FILE (the menu's edited copy): checked, then made the toolkit's settings"
fresh; cp "$R/toolkit/fedokawaii.conf" "$TMP/edit.conf"; sed -i 's/^STEAM="yes"/STEAM="no"/' "$TMP/edit.conf"
out=$(front conf "$TMP/edit.conf" 2>&1); eq "$?" 0; has "$out" "every value is valid"
has "$out" "BACKUP_TARGET and BACKUP_REMIND_DAYS count at once" "the backup's two need no update: said"
has "$(cat "$R/toolkit/fedokawaii.conf")" 'STEAM="no"'
called "^runuser -u kawa -- cat -- $TMP/edit.conf" "read as whoever ran sudo, never as root"
case_ "conf with a slip: not saved, every problem listed, the settings as they were"
sed -e 's/^MONITOR_HZ="144"/MONITOR_HZ="9000"/' "$R/toolkit/fedokawaii.conf" >"$TMP/bad.conf"; printf 'FOO=1\n' >>"$TMP/bad.conf"
before=$(cat "$R/toolkit/fedokawaii.conf")
out=$(front conf "$TMP/bad.conf" 2>&1); eq "$?" 1
has "$out" "not saved"; has "$out" "MONITOR_HZ must be"; has "$out" "FOO is not a setting"
eq "$(cat "$R/toolkit/fedokawaii.conf")" "$before"
case_ "conf of a file that cannot be read: said"
out=$(front conf "$TMP/none.conf" 2>&1); eq "$?" 1; has "$out" "cannot read $TMP/none.conf"
case_ "conf alone: the toolkit's own file checked"
fresh; out=$(front conf 2>&1); eq "$?" 0; has "$out" "every value is valid"

# ── from a working copy on a finished install ────────────────────────────────
copy_world() {   # $W: a working copy, made from the toolkit (its front is the same one, pointed at $R)
  W=$TMP/home/repos/fedokawaii; mkdir -p "$W"
  cp -a "$R/toolkit/." "$W/"
  mkdir -p "$W/.git"; cp "$R/toolkit/fedokawaii.conf" "$W/.git/fedokawaii-conf-base"
  F=$W/fedokawaii.sh
}
case_ "theme from a copy: the copy becomes the toolkit first, then the toolkit's theme"
fresh; copy_world
front theme >/dev/null; eq "$(front_calls | cut -d' ' -f1-3 | tr '\n' '|')" "setup --toolkit (from|theme --user kawa|"
has "$(front_calls | tail -n1)" "(from $R/toolkit)"
case_ "…and when the copy is refused (setup --toolkit fails): no theme from the old toolkit"
: >"$R/front.log"; echo 1 >"$R/rc-setup"
out=$(front theme 2>&1); eq "$?" 1; eq "$(front_calls | cut -d' ' -f1-2)" "setup --toolkit"
case_ "…the same from the menu (where a failing action keeps the menu): no theme after a refused copy"
: >"$R/front.log"; printf '3\nq\n' | front >/dev/null 2>&1
eq "$(front_calls | cut -d' ' -f1-2)" "setup --toolkit"
case_ "theme from a copy before setup has finished: the copy's own theme.sh"
fresh; copy_world; echo 3 >"$R/state/phase"
front theme >/dev/null; eq "$(front_calls)" "theme --user kawa (from $W)"

case_ "apply from the toolkit itself: refused, the theme named instead"
fresh; out=$(front apply 2>&1); eq "$?" 1; has "$out" "apply runs from your working copy"; has "$out" "fedokawaii theme"
case_ "apply of a copy that is the same: nothing to apply"
fresh; copy_world; out=$(front apply 2>&1); eq "$?" 0; has "$out" "the copy and the toolkit are the same"; eq "$(front_calls)" ""
case_ "apply of a config change: the copy made the toolkit, then the theme"
echo "font=Changed" >>"$W/configs/home/.config/foot/foot.ini"
out=$(front apply 2>&1); eq "$?" 0
has "$out" "1 file(s) differ from the toolkit"; has "$out" "configs/home/.config/foot/foot.ini"
eq "$(front_calls | cut -d' ' -f1-3 | tr '\n' '|')" "setup --toolkit (from|theme --user kawa|"
has "$out" "applied — keep the change in your copy's history"
case_ "apply of a system part (a new helper of the system): repair, which applies the theme too"
fresh; copy_world; mkdir -p "$W/system"; printf '#!/usr/bin/env bash\necho x\n' >"$W/system/kawa-new"
out=$(front apply 2>&1); eq "$?" 0; has "$out" "system/kawa-new (new)"
eq "$(front_calls | cut -d' ' -f1-2 | tr '\n' '|')" "setup --toolkit|setup --repair|"
case_ "…repair that leaves something for you: applied, exit 3"
: >"$R/front.log"; echo 3 >"$R/rc-setup"
# (--toolkit must pass: a stand-in answering 3 to it would stop apply — give it its own 0)
printf '#!/usr/bin/env bash\necho "setup $* (from ${0%%/*})" >>"%s/front.log"\n[[ $1 == --toolkit ]] && exit 0\nexit 3\n' "$R" >"$W/setup.sh"
cp "$W/setup.sh" "$R/toolkit/setup.sh"
out=$(front apply 2>&1); eq "$?" 3; has "$out" "repair ran; what still needs you is listed above"
case_ "apply of the handbook alone: the toolkit has it, nothing else runs"
fresh; copy_world; echo "more" >>"$W/docs/notes.md"
out=$(front apply 2>&1); eq "$?" 0; has "$out" "nothing here changes the desktop itself"
eq "$(front_calls | cut -d' ' -f1-2)" "setup --toolkit"
case_ "apply of a script that does not parse: nothing applied, the script named"
fresh; copy_world; printf '#!/usr/bin/env bash\nif then fi\n' >"$W/bin/kawa-broken"; echo "x" >>"$W/configs/home/.config/foot/foot.ini"
out=$(front apply 2>&1); eq "$?" 1; has "$out" "these do not parse — nothing was applied"; has "$out" "bin/kawa-broken"
eq "$(front_calls)" "" "nothing ran"
case_ "apply: a name holding \" and \" is still one file"
fresh; copy_world; printf '# a\n' >"$R/toolkit/configs/home/.config/foot/notes and todo.sh"; printf '# b\n' >"$W/configs/home/.config/foot/notes and todo.sh"
out=$(front apply 2>&1); has "$out" "configs/home/.config/foot/notes and todo.sh"; lacks "$out" "    configs/home/.config/foot/notes"$'\n'
case_ "apply: settings saved from the menu since the copy was made are no change of the copy's"
fresh; copy_world; sed -i 's/^STEAM="yes"/STEAM="no"/' "$R/toolkit/fedokawaii.conf"
out=$(front apply 2>&1); has "$out" "nothing to apply"
case_ "apply of very many files: forty named, the rest counted"
fresh; copy_world; for i in $(seq 1 45); do echo "$i" >"$W/configs/home/.config/foot/f$i.ini"; done
out=$(front apply 2>&1); has "$out" "45 file(s) differ"; has "$out" "… and 5 more (fedokawaii diff shows them all)"
case_ "apply with no desktop user known: refused"
fresh; copy_world; echo x >>"$W/configs/home/.config/foot/foot.ini"; rm -f "$R/state/user"; export SUDO_USER=root
out=$(front apply 2>&1); eq "$?" 1; has "$out" "unknown desktop user"

done_
