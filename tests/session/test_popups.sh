#!/usr/bin/env bash
# tests/session/test_popups.sh — one popup at a time, whatever kind, and the pointer's surface
# always the one under it: dwl.patch read (its behaviour on a real dwl: tools/kit.sh plays —
# every ordered pair of ten popups, a menu opened by its key under a resting pointer).
#   · a popup raised (a warm window's key, a float window new, a click) while a menu of the
#     panel's holds the keyboard: the menu dropped first (as Esc), never for the pointer
#     merely passing over a popup (focusclient's lift)
#   · a panel menu taking the keyboard closes every popup — the lock's surface never does
#   · a layer surface mapped, gone or moved under a resting pointer: the pointer re-checked
#     once its commit is done (the scene has the buffer then); a button's release re-checks it
#     too (a menu that opened while the button was down)
. "$(dirname "$0")/../lib/harness.sh"
P=$REPO/src/dwl/dwl.patch
sandbox
fn() { sed -n "/^+$1(/,/^+}/p" "$P"; }   # fn NAME — that function as the patch adds it
# hunks NAME — the patch's changes inside upstream's function NAME (git names it in each hunk's head)
hunks() { awk -v f="$1(" '/^@@/ { on = index($0, "@@ " f) > 0 } /^diff / { on = 0 } on' "$P"; }

case_ "a popup raised over a menu: the menu dropped first — on a raise (lift), never on the pointer passing"
f=$(sed -n '/^ focusclient(Client \*c, int lift)/,/^ }/p' "$P")   # (its head is context in a hunk git files under dirtomon)
has "$f" '+	if (c && lift && ispopup(c))'; has "$f" '+		dropmenu();'
# (the keyboard's surface read after the drop: the menu's no longer counts as the one focused)
awk '/^\+		dropmenu\(\);/ { d = NR } /^\+	old = seat->keyboard_state.focused_surface;/ { o = NR } END { exit !(d && o && d < o) }' \
  <<<"$f" && _ok || _no "the focused surface read before the menu was dropped"
has "$f" '-	struct wlr_surface *old = seat->keyboard_state.focused_surface;' "(no longer read at its declaration)"

case_ "a menu of the panel's taking the keyboard: every popup closed — only the panel's (kawa-panel), not the lock's"
f=$(hunks arrangelayers)
has "$f" '+			if (l != exclusive_focus && ispanel(l))'; has "$f" '+				closepopups(NULL);'
has "$(fn ispanel)" '!strcmp(l->layer_surface->namespace, "kawa-panel")' '!strcmp(l->layer_surface->namespace, "kawa-dialog")'
has "$(cat "$REPO/bin/kawa-panel")" 'def build_window(name="kawa-panel"):' 'GtkLayerShell.set_namespace(win, name)' 'win, area = build_window("kawa-dialog")' "(the names dwl knows the panel by: a menu, a dialog)"

case_ "s12d: a menu stays a scroll while open (its rods and silk round it, mounted), a dialog draws its own"
has "$(cat "$REPO/src/dwl/config.h")" '{ "kawa-panel",     300,   240,    1,     1 },' '{ "kawa-dialog",    300,   240,    1,     0 },'
f=$(fn layermount)
has "$f" 'anim_scroll_motion == ScrollRod' 'dissolveend(&l->mount);' 'k.box.width - 1, k.box.height - 2, 1.0, 1.0);'
has "$(fn layerstop)" 'layermount(l);'
has "$(hunks commitlayersurfacenotify)" "+	layermount(l);"
has "$(cat "$P")" '+	dissolveend(&l->mount);           /* (the ghost rolling up draws its rods from here) */' '+					scrollopen(1.0 - (from < 0 ? 0 : from)), l->la->mount);'
has "$(hunks destroylayersurfacenotify)" 'dissolveend(&l->mount);'
has "$(fn layerdissolve)" 'scrollopen(p), l->la->mount ? 1.0 : smooth((1.0 - p) / 0.22));'
has "$(fn ghostapply)" 'scrollshut(t), g->rollup == 2 ? 1.0 : smooth(t / 0.22));'

case_ "a layer surface's commit (mapped, gone, moved): the pointer re-checked once the commit is done"
f=$(hunks commitlayersurfacenotify)
has "$f" '+	pointerlater();'
has "$(fn pointerlater)" 'wl_event_loop_add_idle(event_loop, pointerrefresh, NULL)'
has "$(fn pointerlater)" 'if (!pointer_idle)' "(one pending at most, however many commits)"
f=$(fn pointerrefresh); has "$f" 'pointer_idle = NULL;'; has "$f" 'motionnotify(0, NULL, 0, 0, 0, 0);'

case_ "a button let go: the pointer re-checked (a menu that opened while the button was down answers at once)"
f=$(hunks buttonpress)
has "$f" '+	if (event->state == WL_POINTER_BUTTON_STATE_RELEASED && !locked)'
has "$f" '+		motionnotify(0, NULL, 0, 0, 0, 0);'

done_
