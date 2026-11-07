#!/usr/bin/env bash
# tests/content/test_learn_review.sh — kawa-learn's review screen (sb03b): r on the day shows a due card, Space
# the answer, y/n keep it in the record; the concept map (m), the week and the rank (a), the quiet line of the
# day, the explain-it-back note (e) written once and never over his words. A standard-2 course from test_lessons.sh.
. "$(dirname "$0")/lib.sh"
sandbox
export PATH=$REPO/bin:$PATH KAWA_TOOLKIT=$REPO
ST=$XDG_STATE_HOME/fedokawaii
L=$TMP/course
pty() { python3 -B -I "$C/learn_pty.py" "$@"; }
screens() { sed -n '/^--- screen/,$p'; }
. <(awk '/^one_(ask|run|std2)\(\)/{p=1} p{print} /^}/{p=0}' "$C/test_lessons.sh")
mkdir -p "$L" "$ST" "$HOME/notes"
one_ask panel 10; one_run first-print 15; one_std2; one_ask panel2 10
printf '1\tpanel\tfirst-print\n2\tpanel2\tstd-two\n' >"$L/days.tsv"
export KAWA_LEARN=$L
EDITOR=true; export EDITOR
yesterday=$(date -d yesterday +%F)

case_ "nothing is done: the review says nothing is due, the day's line says so"
s=$(pty 118x40 '!dump' r '!dump' | screens); has "$s" "nothing due"; has "$s" "Nothing is due"

case_ "a lesson done yesterday: its card is due; Space shows the answer; y writes right into the record"
for i in panel first-print panel2 std-two; do printf '%s\t%s\n' "$yesterday" $i; done >"$ST/days"
s=$(pty 118x40 '!dump' r '!dump' ' ' '!dump' y '!dump' | screens); has "$s" "due"; has "$s" "1 of 4"; has "$s" "Space shows it"; has "$s" "y right"; has "$s" "2 of 4"
has "$(cat "$ST/reviews")" "std-two#1	right"
case_ "a card answered today waits: three are left; a wrong one is written wrong"
s=$(pty 118x40 r '!dump' | screens); has "$s" "1 of 3"
rm "$ST/reviews"; pty 118x40 r ' ' n >/dev/null; has "$(cat "$ST/reviews")" "std-two#1	wrong"

case_ "the map lists every lesson with its state; the week page names the rank and the science"
s=$(pty 118x40 m '!dump' | screens); has "$s" "concept map"; has "$s" "practising"; has "$s" "done"
s=$(pty 118x40 a '!dump' | screens); has "$s" "this week"; has "$s" "yellow belt"; has "$s" "Cepeda"

case_ "the explain-it-back note: made for a lesson done, never over his words, none for one not done"
rm -f "$HOME/notes/"* "$ST/days"; pty 118x40 e >/dev/null; [[ ! -e $HOME/notes/explain-panel2.md ]] && _ok || _no "a note for a lesson not done"
for i in panel first-print panel2 std-two; do printf '%s\t%s\n' "$yesterday" $i; done >"$ST/days"; pty 118x40 e >/dev/null; has "$(cat "$HOME/notes/explain-panel2.md")" "- [ ] I wrote it"
echo mine >>"$HOME/notes/explain-panel2.md"; pty 118x40 e >/dev/null; has "$(cat "$HOME/notes/explain-panel2.md")" "mine"

case_ "small windows: every screen resized to 9x5 and 40x12 puts nothing over the edge and falls over nowhere"
for k in r m a; do
  o=$(pty 118x40 $k =9x5 '!wait 0.1' =40x12 '!wait 0.1' ' ' y 2>&1 >/dev/null); eq "$?" 0 "$k"; eq "$o" "" "$k: $(head -c 200 <<<"$o")"
done
done_
