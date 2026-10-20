#!/usr/bin/env bash
# tests/menus/test_config.sh — kawa-config (Super+Shift+U, "change"): the parts of the desktop
# opened in the working copy, then applied now, later, or looked at ("what changed"); the
# files that are yours alone; where to learn each language. Against a made-up toolkit
# (/usr/local/lib/fedokawaii, a folder of the test in a namespace of its own) and a working
# copy in the test's home: none yet, the same as the toolkit, many files changed, something
# else in its place, git missing. The editor (footclient → nvim), the engine (fedokawaii),
# the floating windows and the browser are stand-ins.
. "$(dirname "$0")/../lib/harness.sh"
. "$(dirname "$0")/lib.sh"
((NS)) || { echo "  (skipped: kawa-config reads /usr/local/lib/fedokawaii — no user namespaces here to stand in for it)"; echo "test_config: 0 passed, 0 failed"; exit 0; }

# the files every part opens, in a toolkit of a few lines each
PARTS=(src/dwl/config.h configs/home/.config/fedokawaii/keybinds.txt configs/home/.config/waybar/config.jsonc
  configs/home/.config/waybar/style.css tools/build-themes.py configs/home/.config/foot/foot.ini
  configs/home/.bashrc.d/fedokawaii.sh configs/home/.config/fuzzel/fuzzel.ini configs/home/.config/mako/config
  configs/home/.config/yazi/init.lua configs/home/.config/yazi/theme.toml configs/home/.config/yazi/keymap.toml
  configs/home/.config/fedokawaii/yazi-pick/keymap.toml configs/home/.config/udiskie/config.yml bin/kawa-drives
  configs/home/.config/yazi/plugins/drives.yazi/main.lua configs/home/.config/dwl/autostart.sh art/icons.txt
  tools/build-icons.py lib/manifest.sh PACKAGES.md fedokawaii.conf setup.sh fedokawaii.sh)
setup() {
  menus_sandbox
  W=$TMP/world TK=$TMP/toolkit VL=$TMP/varlib COPY=$HOME/repos/fedokawaii; export W TK COPY
  mkdir -p "$W" "$VL"
  local f; for f in "${PARTS[@]}"; do mkdir -p "$(dirname "$TK/$f")"; printf '# %s\n' "$f" >"$TK/$f"; done
  printf 'print("drawn")\n' >"$TK/tools/build-themes.py"; cp "$TK/tools/build-themes.py" "$TK/tools/build-icons.py"
  : >"$W/edit"; echo 0 >"$W/editrc"
  # the engine: copy as fedokawaii copy makes it (with git's record of the settings), else logged
  stub fedokawaii 'case $1 in
  copy) [ -e "$W/no-git" ] && { echo "git: command not found" >&2; exit 1; }
        mkdir -p "${COPY%/*}" && cp -r /usr/local/lib/fedokawaii "$COPY" && mkdir -p "$COPY/.git" &&
        cp "$COPY/fedokawaii.conf" "$COPY/.git/fedokawaii-conf-base" ;;
esac'
  # the editor: footclient running nvim on the files after "--"; $W/edit says what you do in it
  edit='case " $* " in *" -N "*|*" yazi "*|*" lazygit"*) exit 0 ;; esac
while [ "$1" != "--" ]; do [ "$1" = -D ] && cd "$2"; shift; done; shift 4
for f; do case $(cat "$W/edit") in change) echo "# yours" >>"$f" ;; esac; done'
  stub footclient '[ "$(cat "$W/rc.footclient" 2>/dev/null)" = 220 ] && exit 220
'"$edit"'
exit "$(cat "$W/editrc")"'
  stub foot "$edit"
  stub setsid; stub kawa-term; stub kawa-help
  # python3: fontTools there or not ($W/no-fonttools), pip offline or not ($W/offline)
  stub python3 'case "$*" in
  "-c import fontTools") [ -e "$W/no-fonttools" ] && exit 1; exit 0 ;;
  "-m venv "*) mkdir -p "$3/bin"; printf "#!/bin/sh\n[ -e \"%s/offline\" ] && exit 1; exit 0\n" "$W" >"$3/bin/pip"
               printf "#!/bin/sh\necho \"venv python \$*\" >>\"%s\"\n" "$CALLS" >"$3/bin/python3"; chmod +x "$3/bin/pip" "$3/bin/python3"; exit 0 ;;
esac
[ -e "$W/draw-fails" ] && exit 1
exec /usr/bin/python3 "$@"'
}
# config_ — kawa-config with the toolkit (and /var/lib/fedokawaii) where the engine keeps them
# shellcheck disable=SC2120  # (no arguments: kawa-config takes none)
config_() {
  ns "mount -t tmpfs none /usr/local/lib && mkdir /usr/local/lib/fedokawaii && mount --bind '$TK' /usr/local/lib/fedokawaii
mount -t tmpfs none /var/lib && mkdir /var/lib/fedokawaii && mount --bind '$VL' /var/lib/fedokawaii" kawa-config "$@"
}
copy_made() { mkdir -p "${COPY%/*}"; cp -r "$TK" "$COPY"; mkdir -p "$COPY/.git"; cp "$COPY/fedokawaii.conf" "$COPY/.git/fedokawaii-conf-base"; }
title() { fz_arg title "${1:-}"; }
. "$REPO/configs/home/.config/fedokawaii/icons.sh"

# ── the menu, and the copy's state in its title ──────────────────────────────────────
case_ "no working copy yet: every part in five, each under its kanji, sized to its content, the title says it is made on first use"
setup; answer esc; rc 0 config_
eq "$(fz_rows | grep '^row' | cut -f3 | tr '\n' ',')" "colours,bar,bar look,icons,notifications,launcher,transparency,keys,terminal,shell,files,drives,autostart,settings,packages,yours alone,what changed,history,apply,update fedokawaii,learn,"
eq "$(fz_rows | grep '^part' | cut -f2,3 | tr '\t\n' ' ,')" "見 look,手 use,系 system,史 history,案 help," "the headings: a kanji, the name"
eq "$(fz_rows | grep -vc -e '^part	' -e '^row	')" 0 "nothing but parts and rows (the panel spaces its parts)"
eq "$(fz_rows | grep '^row' | awk -F'\t' 'NF != 4' )" "" "every row: its icon, its name, its note"
eq "$(fz_rows | grep -F "	launcher	" | cut -f4)" "the launcher's look"
eq "$(fz_arg select)" 1 "the cursor's first key on the first entry, not its heading"
eq "$(title)" "change · ~/repos/fedokawaii · made on first use"
eq "$(fz_arg width)" ""; eq "$(fz_arg lines)" ""; fits
not_called '^fedokawaii copy' "nothing made by just looking"
case_ "a copy the same as the toolkit: nothing to apply"
setup; copy_made; answer esc; config_; eq "$(title)" "change · ~/repos/fedokawaii"
case_ "a copy with 21 files changed and 3 new: 24 not applied, and the title still one line"
setup; copy_made
for i in {1..30}; do echo "edit $i" >>"$COPY/${PARTS[i % 21]}"; echo "x" >"$COPY/new$i.txt"; done
rm "$COPY"/new{4..30}.txt
answer esc; config_; eq "$(title)" "change · ~/repos/fedokawaii · 24 not applied"; fits
case_ "the settings file: as made (or as last applied) it is no change; edited it is one"
setup; copy_made; echo 'WEATHER_CITY="Tokyo"' >>"$TK/fedokawaii.conf"
answer esc; config_; eq "$(title)" "change · ~/repos/fedokawaii" "the menu changed the toolkit's: the copy's untouched one is not counted"
echo 'NIGHT_LIGHT="1:2"' >>"$COPY/fedokawaii.conf"
answer esc; config_; eq "$(title)" "change · ~/repos/fedokawaii · 1 not applied"
case_ "a copy elsewhere (FEDOKAWAII_COPY), with spaces and Japanese in its path"
setup; COPY="$HOME/my work/設定 copy"; copy_made; answer esc; FEDOKAWAII_COPY=$COPY config_
eq "$(title)" "change · ~/my work/設定 copy"

# ── a part: opened in the copy, then applied now / later / looked at ───────────────────
case_ "a part, no copy yet: the copy is made first (a notice says where), then the file opened in it"
setup; answer "pick launcher"; config_
called '^fedokawaii copy'
called 'notify-send -a desktop -- .*  change your working copy: ~/repos/fedokawaii — made from the toolkit'
called "^footclient -T change · launcher -D $COPY -- nvim -O -- configs/home/.config/fuzzel/fuzzel.ini$"
eq "$(fz_n)" 1 "closed unchanged: nothing to apply, no second menu"
case_ "the copy cannot be made (git missing, so the engine fails): a notice, no editor"
setup; : >"$W/no-git"; answer "pick bar"; config_
called 'notify-send -a desktop -- .*  change could not make the working copy in'
not_called '^footclient'
case_ "something else where the copy goes: a notice, nothing overwritten"
setup; mkdir -p "$COPY"; echo mine >"$COPY/notes.txt"; answer "pick bar"; config_
called "notify-send -a desktop -- .*  change $COPY is something else — move it, or set FEDOKAWAII_COPY"
not_called '^fedokawaii copy'; eq "$(cat "$COPY/notes.txt")" mine
case_ "a part changed: apply now runs fedokawaii apply in a window that waits for a key"
setup; copy_made; echo change >"$W/edit"; answer "pick terminal" "pick apply now"; config_
eq "$(fz_n)" 2; eq "$(title 2)" "the terminal server reads it at your next login"
eq "$(fz_rows 2 | cut -f1-3 | tr '\t\n' ' ,')" "part 適 apply,row $ICON_DOWNLOAD apply now,row $ICON_HOURGLASS later,row $ICON_BRANCH what changed," "the apply question: 適 apply, three rows"
FITS_WRAP=1 fits 2 "(the when-text wraps at its spaces)"
called '^kawa-term --float --once apply --dialog apply 100x33 -- bash -c .* _ fedokawaii apply$'
case_ "… later: nothing runs now"
setup; copy_made; echo change >"$W/edit"; answer "pick terminal" "pick later"; config_
not_called '^kawa-term --float'
case_ "… what changed: fedokawaii diff in a window"
setup; copy_made; echo change >"$W/edit"; answer "pick terminal" "pick what changed"; config_
called '^kawa-term --float --once diff --dialog what changed 120x41 -- bash -c .* _ fedokawaii diff$'
case_ "… Esc: nothing runs"
setup; copy_made; echo change >"$W/edit"; answer "pick terminal" esc; config_; not_called '^kawa-term --float'
case_ "two files in one part (keys: dwl's config.h and the help sheet), side by side"
setup; copy_made; answer "pick keys"; config_
called '^footclient -T change · keys -D .* -- nvim -O -- src/dwl/config.h configs/home/.config/fedokawaii/keybinds.txt$'
case_ "every part opens its own files in the copy"
for p in "bar:waybar/config.jsonc" "bar look:waybar/style.css" "colours:tools/build-themes.py" "shell:fedokawaii.sh" \
         "notifications:mako/config" "files:yazi-pick/keymap.toml" "drives:drives.yazi/main.lua" "autostart:dwl/autostart.sh" \
         "icons:art/icons.txt" "packages:PACKAGES.md" "settings:-- fedokawaii.conf"; do
  setup; copy_made; answer "pick ${p%%:*}"; config_; called "^footclient -T change · ${p%%:*} .*${p#*:}"
done

case_ "the editor quit with an error (nvim :cq): no second editor window opens"
setup; copy_made; echo 1 >"$W/editrc"; answer "pick bar"; config_
eq "$(grep -c '^foot ' "$CALLS")" 0 "foot not started after footclient's editor closed"
case_ "the terminal server is down (footclient 220): said in a notice — never a foot of its own"
setup; copy_made; echo 220 >"$W/rc.footclient"; echo change >"$W/edit"; answer "pick bar" esc; config_
not_called '^foot '; called '^notify-send -a desktop -- .*  change the terminal server is not running — fedokawaii repair puts it back$'
eq "$(fz_n)" 1 "no apply question after it"
case_ "the terminal server is down: your scripts (yazi) and the history (lazygit) say so too"
setup; echo 220 >"$W/rc.footclient"; answer "pick yours alone" "pick your scripts"; config_
not_called '^foot '; called '^notify-send -a desktop -- .*  change the terminal server is not running'
setup; copy_made; echo 220 >"$W/rc.footclient"; answer "pick 	history	"; config_
not_called '^foot '; called '^notify-send -a desktop -- .*  change the terminal server is not running'

case_ "colours changed: the palettes drawn again in the copy before asking"
setup; copy_made; echo change >"$W/edit"; answer "pick colours" esc; config_
called '^python3 tools/build-themes.py$'; eq "$(fz_n)" 2
case_ "colours, the drawing stops on an error: a notice, no apply question"
setup; copy_made; echo change >"$W/edit"; : >"$W/draw-fails"; answer "pick colours"; config_
called 'notify-send -a desktop -- .*  change tools/build-themes.py stopped'; eq "$(fz_n)" 1
case_ "icons changed, fontTools installed: drawn at once"
setup; copy_made; echo change >"$W/edit"; answer "pick icons" esc; config_
eq "$(fz_n)" 2; not_called 'venv python'
case_ "icons, no fontTools: fetched once into a folder of its own, then drawn with it"
setup; copy_made; echo change >"$W/edit"; : >"$W/no-fonttools"; answer "pick icons" esc; config_
called 'notify-send -a desktop -- .*  change the first time: fetching fontTools'; called '^venv python tools/build-icons.py'
eq "$(fz_n)" 2
case_ "icons, no fontTools and offline: a notice, the half-made folder removed, no apply question"
setup; copy_made; echo change >"$W/edit"; : >"$W/no-fonttools"; : >"$W/offline"; answer "pick icons"; config_
called 'notify-send -a desktop -- .*  change fontTools could not be fetched \(offline\?\)'
[[ ! -e $HOME/.cache/fedokawaii/fonttools ]] && _ok || _no "the venv was left half made"
eq "$(fz_n)" 1

# ── the rest of the menu ──────────────────────────────────────────────────────────────
case_ "what changed (no copy yet: made first), apply, history (lazygit in the copy)"
setup; answer "pick what changed"; config_; called '^fedokawaii copy'; called '^kawa-term --float --once diff --dialog what changed 120x41 '
setup; copy_made; answer "pick apply"; config_; called '^kawa-term --float --once apply --dialog apply 100x33 '
setup; copy_made; answer "pick 	history	"; config_; called "^footclient -N -D $COPY -- lazygit$"
setup; copy_made; answer "pick update fedokawaii"; config_; called '^kawa-term --float --once pull --dialog update fedokawaii 100x33 -- bash -c .* _ fedokawaii pull$'
case_ "yours alone: each file made the first time with a word of what it is for, then opened"
for p in "shell additions:.bashrc.d/local.sh:Fedora's ~/.bashrc reads every" "autostart:.config/dwl/autostart.local.sh:run at every login" \
         "neovim plugins:.config/nvim/lua/plugins/local.lua:LazyVim reads every file"; do
  IFS=: read -r name f words <<<"$p"
  setup; answer "pick yours alone" "pick $name"; config_
  has "$(cat "$HOME/$f" 2>/dev/null)" "$words" "$f"
  called "^footclient -T change · $name -D $HOME/${f%/*} -- nvim -O -- $HOME/$f$"
  called "notify-send -a desktop -- .*  change ~/$f — yours: nothing to apply"
done
fits 2
case_ "yours alone, the file there already: never overwritten"
setup; mkdir -p "$HOME/.bashrc.d"; echo "alias ll='ls -l'" >"$HOME/.bashrc.d/local.sh"
answer "pick yours alone" "pick shell additions"; config_
eq "$(cat "$HOME/.bashrc.d/local.sh")" "alias ll='ls -l'"
case_ "your scripts: yazi in ~/.local/bin"
setup; answer "pick yours alone" "pick your scripts"; config_; called "^footclient -N -- yazi $HOME/.local/bin$"
case_ "learn: the learning guide, the help sheet, a man page, a web page"
setup; answer "pick learn" "pick learning guide"; config_; called '^fedokawaii guide$'; fits 2
setup; answer "pick learn" "pick 	keys	"; config_; called '^kawa-help'
setup; answer "pick learn" "pick man foot.ini"; config_; called '^kawa-term man 5 foot.ini$'
setup; answer "pick learn" "pick ShellCheck"; config_; called '^setsid -f xdg-open https://www.shellcheck.net/wiki/$'
case_ "Esc, a click outside: closes, nothing made or run"
for a in esc lost; do setup; answer "$a"; rc 0 config_; not_called '^(fedokawaii|footclient|kawa-term --float)'; done

case_ "--help: what it is, exit 0; anything else: exit 2, no menu"
setup; has "$(kawa-config --help)" "change the desktop itself"; rc 0 kawa-config --help
rc 2 kawa-config bar; eq "$(fz_n)" 0

done_
