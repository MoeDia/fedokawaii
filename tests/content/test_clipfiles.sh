#!/usr/bin/env bash
# tests/content/test_clipfiles.sh — kawa-clipfiles: files on the clipboard as in Windows
# (yazi's Ctrl+C / Ctrl+X / Ctrl+V). The clipboard is a stand-in (wl-copy and wl-paste keep
# one item: its type in $CB.type, its bytes in $CB.data), the files are real.
. "$(dirname "$0")/../lib/harness.sh"

setup() {
  sandbox
  export CB=$TMP/clipboard
  stub wl-copy 'if [ "$1" = --clear ]; then rm -f "$CB.type" "$CB.data"; exit 0; fi
t=text/plain; [ "$1" = --type ] && t=$2; cat >"$CB.data.w"; mv -f "$CB.data.w" "$CB.data"; printf %s "$t" >"$CB.type.w"; mv -f "$CB.type.w" "$CB.type"'
  stub wl-paste 'case "$1" in
  --list-types) [ -e "$CB.type" ] && cat "$CB.type" && echo ;;
  --no-newline) [ "$3" = "$(cat "$CB.type" 2>/dev/null)" ] && cat "$CB.data" || exit 1 ;;
esac'
  A=$TMP/a B=$TMP/b; mkdir -p "$A" "$B"
}
clip() { cat "$CB.data" 2>/dev/null; }

case_ "copy: the files as file:// links (text/uri-list, CRLF), odd names encoded; a notice says how many"
setup
echo one >"$A/one.txt"; echo two >"$A/my file é 100%.txt"; mkdir "$A/folder"; echo x >"$A/folder/in"
rc 0 kawa-clipfiles copy "$A/one.txt" "$A/my file é 100%.txt" "$A/folder" "$A/one.txt"
eq "$(cat "$CB.type")" text/uri-list
eq "$(clip | tr -d '\r')" "file://$A/one.txt
file://$A/my%20file%20%C3%A9%20100%25.txt
file://$A/folder" "each once, in order"
[[ $(clip) == *$'\r\n'* ]] && _ok || _no "not CRLF"
called '^notify-send -a desktop .*3 files copied'

case_ "copy --quiet: the same on the clipboard, no notice (kawa-shrink says what it did itself)"
reset_calls; rc 0 kawa-clipfiles copy --quiet "$A/one.txt"; eq "$(clip | tr -d '\r')" "file://$A/one.txt"; not_called '^notify-send'
kawa-clipfiles copy "$A/one.txt" "$A/my file é 100%.txt" "$A/folder" "$A/one.txt"
case_ "paste a copy into another folder: copied (folders with what is in them), the originals stay"
rc 0 kawa-clipfiles paste "$B"
eq "$(cat "$B/my file é 100%.txt")" two; eq "$(cat "$B/folder/in")" x; [[ -e $A/one.txt ]] && _ok || _no "the original went"
called 'notify-send .*3 files pasted'
case_ "paste again: nothing overwritten — the new ones get (1), then (2)"
echo changed >"$B/one.txt"
kawa-clipfiles paste "$B"; kawa-clipfiles paste "$B"
eq "$(cat "$B/one.txt")" changed "the one there is untouched"
eq "$(cat "$B/one (1).txt") $(cat "$B/one (2).txt")" "one one"
[[ -d "$B/folder (1)" && -e "$B/my file é 100% (1).txt" ]] && _ok || _no "no numbered copies: $(ls "$B" | tr '\n' '|')"

case_ "cut, then paste: moved, the clipboard emptied (a cut is used up)"
setup; echo m >"$A/move.me"
kawa-clipfiles cut "$A/move.me"
rc 0 kawa-clipfiles paste "$B"
[[ ! -e $A/move.me && $(cat "$B/move.me") == m ]] && _ok || _no "not moved"
[[ ! -e $CB.type ]] && _ok || _no "the clipboard still holds the cut"
called 'notify-send .*1 file moved'
case_ "a cut, then something else copied elsewhere: the next paste copies (the cut no longer stands)"
setup; echo k >"$A/keep.me"
kawa-clipfiles cut "$A/keep.me"; kawa-clipfiles copy "$A/keep.me"
kawa-clipfiles paste "$B"; [[ -e $A/keep.me && -e $B/keep.me ]] && _ok || _no "moved after a later copy"
case_ "a cut pasted into the folder it is in: nothing moves, nothing doubled"
setup; echo s >"$A/same"; kawa-clipfiles cut "$A/same"; kawa-clipfiles paste "$A"
eq "$(ls "$A")" same
case_ "a folder pasted into itself: refused, said"
setup; mkdir -p "$A/f"; kawa-clipfiles copy "$A/f"; out=$(kawa-clipfiles paste "$A/f" 2>&1); r=$?
eq "$r" 1; [[ ! -e $A/f/f ]] && _ok || _no "copied into itself"

case_ "files copied in another app (its own list: LF, a comment, localhost): pasted"
setup; echo w >"$A/web.pdf"
printf '# copied\nfile://localhost%s/web.pdf\n' "$A" | wl-copy --type text/uri-list
rc 0 kawa-clipfiles paste "$B"; eq "$(cat "$B/web.pdf")" w
case_ "a file on another computer, or gone since it was copied: said, the rest pasted"
setup; echo ok >"$A/ok"
printf 'file://other-host/x\r\nfile://%s/ok\r\nfile://%s/gone\r\n' "$A" "$A" | wl-copy --type text/uri-list
kawa-clipfiles paste "$B"; eq "$?" 1; [[ -e $B/ok ]] && _ok || _no "the good one not pasted"
called 'notify-send .*2 could not be pasted'

case_ "a picture on the clipboard (a screenshot): saved as a dated file; another paste: (1)"
setup; printf '\x89PNG\r\n\x1a\nfake' | wl-copy --type image/png
rc 0 kawa-clipfiles paste "$B"
f=$(ls "$B"); [[ $f =~ ^pasted\ [0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}\.[0-9]{2}\.[0-9]{2}\.png$ ]] && _ok || _no "named [$f]"
cmp -s "$B/$f" <(printf '\x89PNG\r\n\x1a\nfake') && _ok || _no "not the picture's bytes"
printf 'jpg' | wl-copy --type image/jpeg; kawa-clipfiles paste "$B"; ls "$B" | grep -q '\.jpg$' && _ok || _no "a JPEG not saved as .jpg"
case_ "text only, or nothing on the clipboard: nothing pasted, said"
setup; printf 'hello' | wl-copy; out=$(kawa-clipfiles paste "$B"); eq "$?" 1; eq "$(ls -A "$B")" ""
called 'notify-send .*nothing to paste'
setup; kawa-clipfiles paste "$B"; eq "$?" 1
case_ "a folder you cannot write to: said, exit 1"
setup; kawa-clipfiles copy "$TMP/a"; chmod 555 "$B"
if [[ -w $B ]]; then _ok; else out=$(kawa-clipfiles paste "$B"); eq "$?" 1; called 'notify-send .*cannot paste here'; fi
chmod 755 "$B"
case_ "wrong use: exit 2; copy of files that do not exist: 1"
setup; rc 2 kawa-clipfiles; rc 2 kawa-clipfiles paste; rc 2 kawa-clipfiles copy; rc 1 kawa-clipfiles copy "$A/nope"
case_ "yazi's keys run it: Ctrl+C, Ctrl+X on the selection (or the file under the cursor), Ctrl+V here"
k=$REPO/configs/home/.config/yazi/keymap.toml
has "$(cat "$k")" 'on = "<C-c>",      run = "shell -- kawa-clipfiles copy %s"'
has "$(cat "$k")" 'on = "<C-x>",      run = "shell -- kawa-clipfiles cut %s"'
has "$(cat "$k")" 'on = "<C-v>",      run = "shell -- kawa-clipfiles paste ."'

done_
