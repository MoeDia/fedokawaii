#!/usr/bin/env bash
# tests/session/test_warm.sh — the warm windows (notes, the clipboard, the system menu): dwl's
# hidden tag and toggle (src/dwl/dwl.patch: warm), and kawa-warm, which starts them, runs what
# is in them and answers each show and hide. A press is dwl's alone — no process started —
# so a window shows or goes within the frame. dwl's part is read from the patch (its
# behaviour on a real dwl: the latency harness); kawa-warm's is run, footclient a stand-in.
. "$(dirname "$0")/../lib/harness.sh"
P=$REPO/src/dwl/dwl.patch CH=$REPO/src/dwl/config.h
sandbox

# ── dwl.patch ────────────────────────────────────────────────────────────────────────────
fn() { sed -n "/^+$1(/,/^+}/p" "$P"; }   # fn NAME — that function as the patch adds it
case_ "WARMTAG: the tag bit above TAGMASK — in no view (view() and the tag keys mask with TAGMASK)"
grep -q '^+#define WARMTAG *(1u << TAGCOUNT)' "$P" && _ok || _no "no WARMTAG = 1u << TAGCOUNT"
grep -q '^ #define TAGMASK *((1u << TAGCOUNT) - 1)' "$P" && _ok || _no "TAGMASK is not upstream's"
case_ "the bar never counts a parked window: printstatus masks occupied and urgent with TAGMASK"
grep -q '^+			occ |= c->tags & TAGMASK;' "$P" && _ok || _no "occ unmasked"
grep -q '^+				urg |= c->tags & TAGMASK;' "$P" && _ok || _no "urg unmasked"
case_ "a warm window maps floating and parked — shown at once only when its key started it"
f=$(sed -n '/^ 	c->isfloating |= client_is_float_type(c);/,/^ 	setmon(c, mon, newtags);/p' "$P")   # (applyrules' end)
has "$f" '+	if (iswarm(c)) {'; has "$f" '+		newtags = WARMTAG;'; has "$f" '+			if (warmpend.want)'
case_ "a warm window is a popup: another window taking the focus parks it, never closes it"
f=$(fn closepopups); has "$f" '+			if (iswarm(c))'; has "$f" '+				warmhide(c, !keep);'
has "$(fn ispopup)" '|| iswarm(c)'
has "$(fn iswarm)" '!strncmp(client_get_appid(c), "warm-", 5)'
case_ "the key: shown on this monitor's view (centred, focused) or parked; none running — started, shown as it maps"
f=$(fn warm); has "$f" 'warmhide(c, 1);'; has "$f" 'warmshow(c);'
has "$f" 'warmpend.want = !warmpend.want;' "(a press while it starts undoes the last: an even number leaves it away)"
has "$f" '"kawa-warm", "--open"'
f=$(sed -n '/^+warmshow(/,/^+}/p' "$P")
has "$f" 'c->tags = m->tagset[m->seltags];'; has "$f" 'focusclient(c, 1);'; has "$f" 'warmhook(c, "--shown");'
f=$(fn warmhide); has "$f" 'c->tags = WARMTAG;'; has "$f" 'wlr_scene_node_set_enabled(&c->scene->node, 0);'
has "$f" 'focusclient(focustop(selmon), 1);' "(its focus handed on)"; has "$f" 'warmhook(c, "--hidden");'
case_ "dwl's fifo: \$XDG_RUNTIME_DIR/dwl-warm, held open both ways, two commands, names checked"
grep -q '"%s/dwl-warm"' "$P" && _ok || _no "no dwl-warm fifo"
grep -q 'O_RDWR | O_NONBLOCK | O_CLOEXEC' "$P" && _ok || _no "not held open read-write"
f=$(sed -n '/^+warmcmd(/,/^+}/p' "$P"); has "$f" '"toggle "'; has "$f" '"hide "'
has "$(sed -n '/^+warmname(/,/^+}/p' "$P")" '"abcdefghijklmnopqrstuvwxyz0123456789-"'
case_ "config.h: Super+N, Super+V and Super+U are warm toggles"
for kn in n:notes v:clip u:system; do
  grep -Eq "\{ MODKEY, +XKB_KEY_${kn%%:*}, +warm, +\{\.v = \"${kn#*:}\"\} \}" "$CH" && _ok || _no "Super+${kn%%:*} is not warm ${kn#*:}"
done

# ── kawa-warm ────────────────────────────────────────────────────────────────────────────
setup() {
  sandbox
  export WAYLAND_DISPLAY=wayland-test FIFO=$XDG_RUNTIME_DIR/dwl-warm
  stub footclient
  stub nvim; stub kawa-clip; stub curl
}
fifo() {   # fifo — dwl's fifo, what is written to it kept in $TMP/fifo.log
  mkfifo "$FIFO"
  ( exec 3<>"$FIFO"; while IFS= read -r l <&3; do printf '%s\n' "$l" >>"$TMP/fifo.log"; done ) & FR=$!
  on_exit "kill $FR 2>/dev/null"
}
got() { sleep "${1:-0.3}"; cat "$TMP/fifo.log" 2>/dev/null; }

case_ "kawa-warm NAME: dwl's toggle through its fifo; an unknown name, or no dwl, says so"
setup; fifo
rc 0 kawa-warm notes; eq "$(got)" "toggle notes"
rc 2 kawa-warm music; eq "$(got 0.1)" "toggle notes"
rm -f "$FIFO"; out=$(kawa-warm clip 2>&1); eq "$?" 1; has "$out" "dwl is not running"
case_ "--start (login): the three windows, app-ids warm-NAME, their titles and sizes, parked"
setup; python3 -I -c 'import socket, sys; socket.socket(socket.AF_UNIX).bind(sys.argv[1])' "$XDG_RUNTIME_DIR/foot-wayland-test.sock"
rc 0 kawa-warm --start
for w in "warm-notes -T notes -W 80x25 -- $REPO/bin/kawa-warm --inside notes" \
         "warm-clip -T clipboard -W 80x27 -- $REPO/bin/kawa-warm --inside clip" \
         "warm-system -T system -W 100x18 -- $REPO/bin/kawa-warm --inside system"; do
  called "^footclient -a $w\$"
done
case_ "--open NAME (its key, none running): the window, shown as it starts"
setup; rc 0 kawa-warm --open notes; called "^footclient -a warm-notes .* --inside notes show\$"
rc 2 kawa-warm --open music

case_ "--inside: what ends by itself (a choice made, Esc) puts the window away and starts again, put away"
setup; fifo; stub kawa-clip 'echo run >>"$TMP/runs"; sleep 1.1'
kawa-warm --inside clip & L=$!
sleep 2.5; kill "$L"; wait "$L" 2>/dev/null
eq "$(got 0)" $'hide clip\nhide clip'; eq "$(wc -l <"$TMP/runs")" 3
case_ "...what runs in it knows it is warm (KAWA_WARM: its name), to put the window away first as it ends"
setup; fifo; stub kawa-clip 'printf "%s\n" "${KAWA_WARM:-none}" >>"$TMP/runs"; sleep 1.1'
kawa-warm --inside clip & L=$!; sleep 0.4; kill "$L"; wait "$L" 2>/dev/null
eq "$(head -n1 "$TMP/runs")" clip
case_ "--away NAME (what runs in it, as it ends — Esc, a copy): dwl told to put it away while its page is still drawn; no dwl: nothing, at once, no file made"
setup; fifo
rc 0 kawa-warm --away clip; eq "$(got)" "hide clip"
rc 2 kawa-warm --away music
rm -f "$FIFO"; rc 0 timeout 5 kawa-warm --away clip; [[ ! -e $FIFO ]] && _ok || _no "a plain file made where dwl's fifo goes"
mkfifo "$FIFO"; rc 0 timeout 5 kawa-warm --away system "(a fifo nobody reads — dwl gone: never a wait)"
case_ "...one that cannot start: five tries in a row, then the window closes"
setup; fifo; stub kawa-clip 'echo run >>"$TMP/runs"; exit 1'
rc 1 kawa-warm --inside clip; eq "$(wc -l <"$TMP/runs")" 5
case_ "...ended by --hidden (.reset): started again, no second hide"
setup; fifo; stub kawa-clip 'echo run >>"$TMP/runs"; sleep 1.1'; : >"$XDG_RUNTIME_DIR/kawa-warm-clip.reset"
kawa-warm --inside clip & L=$!; sleep 0.3; : >"$XDG_RUNTIME_DIR/kawa-warm-clip.reset"
sleep 1.2; kill "$L"; wait "$L" 2>/dev/null
eq "$(got 0)" ""; [[ ! -e $XDG_RUNTIME_DIR/kawa-warm-clip.reset ]] && _ok || _no "the mark stayed"
case_ "...notes shown as it starts: the page told (kawa-notes --inside --shown), once"
setup; stub kawa-notes 'echo "$*" >>"$TMP/runs"; sleep 1.1'
kawa-warm --inside notes show & L=$!; sleep 1.6; kill "$L"; wait "$L" 2>/dev/null
eq "$(cat "$TMP/runs")" $'--inside --shown\n--inside'

case_ "--hidden clip in a real terminal: what runs ends whole (its process group), starts again; the window stays"
setup; fifo
stub kawa-clip 'echo $$ >>"$TMP/runs"; exec sleep 30'
( for _ in {1..100}; do [[ -s $TMP/runs ]] && break; sleep 0.05; done
  : >"$XDG_RUNTIME_DIR/kawa-warm-clip.shown"; kawa-warm --hidden clip ) & H=$!
python3 -I "$REPO/tests/lib/pty_run.py" --timeout 3 -- kawa-warm --inside clip >/dev/null 2>&1
wait "$H"
eq "$(wc -l <"$TMP/runs")" 2 "(ended once, started again)"
first=$(head -n1 "$TMP/runs"); ! kill -0 "$first" 2>/dev/null && _ok || _no "the first run is still there"
eq "$(got 0)" "" "(no hide: it was away already)"
[[ ! -e $XDG_RUNTIME_DIR/kawa-warm-clip.shown ]] && _ok || _no "the clipboard still marked shown (Super+Z would act on it)"
for p in $(cat "$TMP/runs"); do kill "$p" 2>/dev/null; done

case_ "--renew clip system (theme.sh, after an apply): one put away — its loop and its run ended, opened again put away at its size; one showing left as it is; the notes never"
setup
stub kawa-clip 'echo $$ >>"$TMP/runs"; exec sleep 30'
python3 -I "$REPO/tests/lib/pty_run.py" --timeout 5 -- kawa-warm --inside clip >/dev/null 2>&1 & W=$!
for _ in {1..100}; do [[ -s $TMP/runs ]] && break; sleep 0.05; done
loop=$(cat "$XDG_RUNTIME_DIR/kawa-warm-clip.pid"); run=$(head -n1 "$TMP/runs")
: >"$XDG_RUNTIME_DIR/kawa-warm-system.shown"
rc 0 kawa-warm --renew system clip
! kill -0 "$loop" 2>/dev/null && _ok || _no "the clipboard's loop still runs"
! kill -0 "$run" 2>/dev/null && _ok || _no "what ran in it still runs"
called "^footclient --no-wait -a warm-clip -T clipboard -W 80x27 -- $REPO/bin/kawa-warm --inside clip\$"
not_called "^footclient --no-wait -a warm-system" "the system menu, showing: left as it is"
wait "$W" 2>/dev/null
setup; out=$(kawa-warm --renew clip notes 2>&1); eq "$?" 2; has "$out" "the notes hold your page"; not_called '^footclient'
setup; rc 0 kawa-warm --renew system
called "^footclient --no-wait -a warm-system -T system -W 100x18 -- $REPO/bin/kawa-warm --inside system\$" "none running: opened, put away"

case_ "--shown/--hidden: the clipboard marked shown and its list read again; the menu's list read again; the notes page told through its socket"
setup; rc 0 kawa-warm --shown clip; called '^kawa-clip --poke$'
[[ -e $XDG_RUNTIME_DIR/kawa-warm-clip.shown ]] && _ok || _no "no shown mark"
rc 0 kawa-warm --shown system; called "^curl .*--unix-socket $XDG_RUNTIME_DIR/fedokawaii-menu.sock --data-binary reload-sync\(fedokawaii --items\)"
rc 0 kawa-warm --shown notes; called "^nvim --server $XDG_RUNTIME_DIR/kawa-notes.nvim --remote-expr v:lua.kawa_notes_shown\(\)\$"
rc 0 kawa-warm --hidden notes; called "^nvim --server $XDG_RUNTIME_DIR/kawa-notes.nvim --remote-expr v:lua.kawa_notes_hidden\(\)\$"
rc 0 kawa-warm --hidden clip   # (none running: nothing to end)
rc 2 kawa-warm --shown music

case_ "autostart starts them at login; help"
grep -q '^kawa-warm --start ' "$REPO/configs/home/.config/dwl/autostart.sh" && _ok || _no "not in autostart.sh"
has "$(kawa-warm --help)" "Super+N"

done_
