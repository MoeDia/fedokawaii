#!/usr/bin/env bash
# tests/session/test_dwl_anim.sh — dwl's animations (src/dwl/dwl.patch, config.h; docs/design-system.md
# §11): a new window dissolves in — cells of the wallpapers' pixel on the screen's grid, wholly
# there or not, in a 4 × 4 Bayer matrix's order — rising its last anim_rise px; a closed one
# dissolves out sinking as far; a workspace switch dissolves the windows out drifting anim_drift
# px one way (its first anim_tag_each_ms) and the next ones in from the other (its last) — every
# frame the screen shows, drawn for the moment that frame reaches the screen, the movement eased
# out, the cells on a smoothstep, nothing ever cut by a moving edge or half-transparent, never a
# full-screen window, never one not yet drawn at its size; tearing flips only with FreeSync on.
# The dissolve: each frame the picture composed by wlroots' render pass into a buffer of its own,
# the cells not there yet cleared by one quad of a GLES 2 shader in the same pass, the scene
# showing that buffer while the window itself stays where it is at opacity 0 (pointer, keys and
# frame callbacks go on). What a headless dwl showed (frames recorded through an open, a switch
# and a close: every cell 3 × 3 on the screen's grid, rank 0 first at (0,0), rank 1 at (2,2);
# 250 µs a frame at most with two windows dissolving; rounds under ASan clean), kept here as the
# code that does it.
. "$(dirname "$0")/../lib/harness.sh"

P=$REPO/src/dwl/dwl.patch CH=$REPO/src/dwl/config.h
added() { sed -n "/^+$1(/,/^+}/p" "$P"; }

case_ "config.h and config.def.h: on, opening 420 ms, closing 400, a switch 420 (each side 280), the lock leaving 420, a 9 px rise, a 24 px drift"
for c in "$(cat "$CH")" "$(sed -n '/^+++ b\/config.def.h/,/^--- /p' "$P" | sed 's/^+//')"; do
  grep -q '^static const int animations *= 1;' <<<"$c" && grep -q '^static const unsigned int anim_open_ms *= 420;' <<<"$c" \
    && grep -q '^static const unsigned int anim_close_ms *= 400;' <<<"$c" && grep -q '^static const unsigned int anim_tag_ms *= 420;' <<<"$c" \
    && grep -q '^static const unsigned int anim_tag_each_ms *= 280;' <<<"$c" && grep -q '^static const unsigned int anim_unlock_ms *= 420;' <<<"$c" \
    && grep -q '^static const int anim_rise *= 9;' <<<"$c" && grep -q '^static const int anim_drift *= 24;' <<<"$c" \
    && ! grep -q 'anim_steps\|anim_ms \|double anim_drift' <<<"$c" && _ok || _no "animations, anim_*_ms, anim_rise, anim_drift"
done

case_ "driven by the screen's frames: each frame drawn for the moment it reaches the screen (the last one shown + the refresh: presentmon), the next asked only while one runs (no timer)"
grep -q '^+			animframe(m, at, held);' "$P" && grep -q 'm->shown_ms + m->refresh_ms \* ceil(' "$P" \
  && grep -q '^+	LISTEN(&wlr_output->events.present, &m->present, presentmon);' "$P" && grep -q 'm->refresh_ms = ev->refresh / 1e6;' "$P" \
  && grep -q '^+	if (left)$' <(added animframe) && ! grep -q 'animtick\|animtimer' "$P" \
  && grep -q 'return 1.0 - (1.0 - p) \* (1.0 - p) \* (1.0 - p);' <(added animease) \
  && _ok || _no "animations not frame-driven"

case_ "a new window dissolves in only once it has drawn itself at its size (showclient from the commit that acks it)"
grep -q '^+		showclient(c, 1);' "$P" && grep -q '^+	showclient(data, 0);' "$P" \
  && grep -q '^+		animstart(c, AnimOpen, 0);' <(added showclient) && _ok || _no "open animation not tied to the acked first frame"

case_ "opening: the window rises anim_rise px to its place in whole pixels, at its current place (a relayout mid-animation is followed) — no fade left anywhere"
f=$(added applyframe)
grep -q 'dy = (int)lround(anim_rise \* (1.0 - e));' <<<"$f" && ! grep -q 'alpha\|clientfade\|fadeease' <<<"$f" \
  && ! grep -q '^+.*\(clientfade\|fadeease\|c->faded\)' "$P" && ! grep -q 'h \* e' <<<"$f" \
  && grep -q '^+	applyframe(c);$' <(sed -n '/^ resize(Client \*c/,/^ }/p;/^+resize(/,/^+}/p' "$P"; grep -A2 'the scene: the window at its place' "$P") \
  && _ok || _no "applyframe: not a rise, or a fade left"

case_ "the cells: a smoothstep (gentle at both ends, every one of the sixteen steps seen), shown = 16 × s(p) in, 16 − that out"
grep -q 'return p \* p \* (3 - 2 \* p);' <(added cellease) \
  && grep -q 'double shown = 16.0 \* cellease(c->animp);' <(added clientdissolve) && grep -q 'shown = 16.0 - shown;' <(added clientdissolve) \
  && grep -q 'moncell(g->mon), 16.0 \* (1.0 - cellease(t)));' <(added ghostapply) && _ok || _no "the curve"

case_ "the punch: one quad of a GLES 2 shader inside the pass — a cell's rank 4·m(low bits) + m(next bits), m = [[0 2] [3 1]] (build-masters.py's Bayer matrix), cells of moncell px on the screen's grid (origin = the buffer's corner on the screen), cleared to nothing where the rank is not yet reached"
f=$(sed -n '/^+punchinit(void)$/,/^+}/p' "$P")
grep -q 'float m(vec2 a) { return mod(2.0 \* a.x + 3.0 \* a.y, 4.0); }' <<<"$f" \
  && grep -q 'vec2 c = floor((gl_FragCoord.xy + origin) / cell);' <<<"$f" \
  && grep -q 'float rank = 4.0 \* m(mod(c, 2.0)) + m(mod(floor(c / 2.0), 2.0));' <<<"$f" \
  && grep -q 'if (rank < shown) discard;' <<<"$f" && grep -q 'gl_FragColor = vec4(0.0);' <<<"$f" \
  && grep -q 'glDisable(GL_BLEND);' <(added dissolveshow) && grep -q 'glDisableVertexAttribArray(punchpos);' <(added dissolveshow) \
  && grep -q 'wlr_render_pass_submit(pass);' <(added dissolveshow) \
  && grep -q 'wlr_scene_buffer_set_buffer_with_damage(d->node, d->buf, NULL);' <(added dissolveshow) \
  && grep -q 'while (m && (640 \* k < m->m.width || 360 \* k < m->m.height))' <(added moncell) \
  && _ok || _no "the punch"
# the matrix the shader computes is build-masters.py's, cell for cell
python3 - "$REPO/tools/build-masters.py" <<'EOF' && _ok || _no "the shader's ranks are not the wallpapers' Bayer matrix"
import re, sys
src = open(sys.argv[1]).read()
B = eval(re.search(r"BAYER = np\.array\((\[\[.*?\]\])\)", src).group(1))
m = lambda x, y: (2 * x + 3 * y) % 4
for y in range(4):
    for x in range(4):
        assert 4 * m(x % 2, y % 2) + m((x // 2) % 2, (y // 2) % 2) == B[y][x], (x, y)
EOF

case_ "the picture composed as the scene draws it: each surface from its own texture (the client buffer's), its part, size and turn, at its own opacity (the alpha-modifier's, never the hiding 0); the frame's pieces in their colours"
f=$(added dissolvepart)
grep -q 'wlr_client_buffer_get(b->buffer)' <<<"$f" && grep -q '.src_box = b->src_box, .dst_box = { x, y, w, h },' <<<"$f" \
  && grep -q '.transform = b->transform, .filter_mode = b->filter_mode,' <<<"$f" && grep -q 'WLR_RENDER_BLEND_MODE_PREMULTIPLIED' <<<"$f" \
  && grep -q 'wlr_alpha_modifier_v1_get_surface_state(ss->surface)' <(sed -n '/^+bufalpha(/,/^+}/p' "$P") \
  && grep -q 'wlr_scene_node_for_each_buffer(&c->scene_surface->node, dissolvesurface, pass);' <(added clientdissolve) \
  && grep -q 'c->border\[j\]->color);' <(added clientdissolve) && _ok || _no "the composition"

case_ "the window itself stays where it is, out of sight: its surfaces at opacity 0 (hidden again every frame: its own commits set them back), its frame's pieces off; back as they were when the dissolve ends"
f=$(added clienthide)
grep -q 'wlr_scene_node_for_each_buffer(&c->scene_surface->node, fadebuffer, &a);' <<<"$f" \
  && grep -q 'wlr_scene_node_set_enabled(&c->border\[i\]->node, !hide);' <<<"$f" \
  && grep -q 'clienthide(c, 1);' <(added clientdissolve) && grep -q 'clienthide(c, 0);' <(added animdrop) \
  && grep -q 'animdrop(c);' <(added animstop) && _ok || _no "clienthide"

case_ "the dissolve's buffer: ARGB8888, linear, from dwl's own allocator, made anew when the window changes size, dropped at the end (and with the renderer on a GPU reset); GLES 2 only (dissolveok), dwl linked with glesv2"
f=$(added dissolvebegin)
grep -q 'uint64_t linear = DRM_FORMAT_MOD_LINEAR;' <<<"$f" && grep -q '.format = DRM_FORMAT_ARGB8888' <<<"$f" \
  && grep -q 'wlr_allocator_create_buffer(alloc, w, h, &fmt)' <<<"$f" && grep -q 'd->node->point_accepts_input = ghostinput;' <<<"$f" \
  && grep -q 'wlr_buffer_drop(d->buf);' <(added dissolveend) && grep -q 'return drw && wlr_renderer_is_gles2(drw);' <(added dissolveok) \
  && grep -q 'animations && dissolveok() && !locked' <(added animok) \
  && grep -A24 '^@@ .* gpureset(struct wl_listener' "$P" | grep -q '^+	punchprog = 0;$' \
  && grep -q '"XLIBS=xcb xcb-icccm pixman-1 glesv2"' "$REPO/lib/manifest.sh" && grep -q 'XLIBS="xcb xcb-icccm pixman-1 glesv2"' "$REPO/tools/hl-dwl.sh" \
  && _ok || _no "the buffer's life"

case_ "a workspace switch: the old windows dissolve out drifting anim_drift px one way (0 – anim_tag_each_ms), the new ones in from the other side (from anim_tag_ms − anim_tag_each_ms to the end) — never a full-width slide"
f=$(added applyframe)
grep -q 'dx = c->animdir \* (int)lround(anim_drift \* (1.0 - e));' <<<"$f" \
  && grep -q 'dx = -c->animdir \* (int)lround(anim_drift \* e);' <<<"$f" \
  && grep -q 'double p = kind == AnimIn ? (t - (anim_tag_ms - anim_tag_each_ms)) / anim_tag_each_ms' "$P" \
  && grep -q 'return kind == AnimOpen ? anim_open_ms : kind == AnimIn ? anim_tag_ms' "$P" \
  && grep -q ': kind == AnimUnroll ? anim_unroll_ms : anim_tag_each_ms;' "$P" \
  && _ok || _no "the switch's drift and timing"

case_ "layer surfaces by namespace (config.h layeranims): the panels' menus in 200 ms dropping 4 px and out 160, a notice 240 · 200, the level display at once and out 300, the saver out 180; any other at once"
for c in "$(cat "$CH")" "$(sed -n '/^+++ b\/config.def.h/,/^--- /p' "$P" | sed 's/^+//')"; do
  grep -Eq '^	\{ "kawa-panel", +200, +160, +4 \},' <<<"$c" && grep -Eq '^	\{ "notifications", +240, +200, +0 \},' <<<"$c" \
    && grep -Eq '^	\{ "kawa-level", +0, +300, +0 \},' <<<"$c" && grep -Eq '^	\{ "kawa-saver", +0, +180, +0 \},' <<<"$c" \
    && _ok || _no "layeranims"
done
case_ "a layer surface dissolves in from the frame after it maps (its picture reaches the scene after dwl's listener), dropping la->drop px into place, the surface itself there at opacity 0; on unmap its last picture dissolves away — from as far as it had come in — over what it covered (ghosttree, above it in its own layer); the saver even over the lock"
f=$(sed -n '/^ commitlayersurfacenotify(/,/^ }/p;/^+commitlayersurfacenotify(/,/^+}/p' "$P")
grep -q 'if (!l->mapped && layer_surface->surface->mapped && l->la && l->la->in_ms && layerok(l)) {' "$P" \
  && grep -q 'dy = -(int)lround(l->la->drop \* (1.0 - animease(p)));' <(added layerdissolve) \
  && grep -q 'wlr_scene_node_for_each_buffer(&l->scene->node, fadebuffer, &zero);' <(added layerdissolve) \
  && grep -q 'ghosttree(l->mon, l->scene, l->scene->node.parent, l->la->out_ms, from < 0 ? 0 : from);' "$P" \
  && grep -q 'return animations && dissolveok() && (l->saver || !locked) && l->mon;' <(added layerok) \
  && grep -A4 '^@@ .* destroylayersurfacenotify(' "$P" | grep -q '^+	dissolveend(&l->dis);$' \
  && grep -q 'ghosttree(m, m->lock_surface->surface->data, layers\[LyrBlock\],' "$P" \
  && _ok || _no "the layer surfaces' dissolves"

case_ "tearing (async) flips only while FreeSync is on for the screen (vrr 1)"
grep -q '^+	if (m->vrr == 1 && (c = focustop(m)) && c->isfullscreen && client_surface(c)$' "$P" && _ok || _no "async flips without FreeSync"
case_ "an empty cut hides the picture (wlroots takes an empty clip for none)"
grep -q 'wlr_scene_node_set_enabled(&c->scene_surface->node, 0);' <(added applyframe) && _ok || _no "empty clip not handled"

case_ "a closed window's ghost dissolves out and sinks anim_rise px (its own rise and time: anim_close_ms), from as many cells as it showed (one closed while it dissolved in), its parts kept out of sight in a box of their own"
f=$(added ghostapply)
grep -q 'wlr_scene_node_set_position(&g->tree->node, g->x, g->y + (int)lround(g->rise \* animease(t)));' <<<"$f" \
  && grep -q 'dissolvepart(pass, g->parts\[i\].node, g->parts\[i\].node->x - g->box.x,' <<<"$f" \
  && grep -q '^+	g->ms = anim_close_ms, g->rise = anim_rise;' "$P" && grep -q '^+		if ((now - g->t0) >= g->ms) {' "$P" \
  && grep -q 'g->t0 = g->last = nowms() - (1.0 - p) \* g->ms;' <(added ghostclient) \
  && grep -q 'wlr_scene_node_set_enabled(node, 0);' <(sed -n '/^+ghostadd(/,/^+}/p' "$P") \
  && grep -q '^+	float color\[4\];' "$P" && grep -q '^+	int x, y; ' "$P" && _ok || _no "ghostapply / GhostPart / Ghost"
case_ "a closed window leaves a ghost of its own buffers that never takes the pointer, freed (its dissolve with it) with its monitor and at exit"
grep -q 'wlr_scene_buffer_create(g->tree, b->buffer)' "$P" && grep -q 'n->point_accepts_input = ghostinput;' "$P" \
  && grep -q '^+		if (g->mon == m)$' "$P" && grep -A1 '^+	wl_list_for_each_safe(g, gtmp, &ghosts, link)$' "$P" | grep -q 'ghostfree(g);' \
  && grep -q 'dissolveend(&g->dis);' <(added ghostfree) && _ok || _no "ghost lifecycle"

case_ "the ghost stays above the window that takes the focus after it"
grep -q '^+		wl_list_for_each_reverse(g, &ghosts, link)' "$P" && _ok || _no "a focused neighbour is raised over the ghost"

case_ "the switch: out to one side and in from the other, focus and layout at once; a window drifting out is not under the pointer"
v=$(sed -n '/^[ +]view(const Arg \*arg)$/,/^[ +]}$/p' "$P")
grep -q 'animstart(c, AnimOut, dir);' <<<"$v" && grep -q 'animstart(c, AnimIn, dir);' <<<"$v" \
  && grep -q '__builtin_ctz(now) > __builtin_ctz(was)' <<<"$v" && grep -q '(\*pc)->anim == AnimOut' "$P" \
  && _ok || _no "view() slide"

case_ "never a full-screen window, a warm one, an unmanaged one, or under the lock"
grep -q '!locked && c && c->mon && !c->isfullscreen' <(added animok) && grep -q '!iswarm(c) && !client_is_unmanaged(c)' <(added animok) \
  && grep -q 'if (c->mon == m && c->isfullscreen && (c->tags & (was | now)))' "$P" && _ok || _no "an exclusion is missing"

case_ "an animation waits while its monitor is held for a window to draw its new size (its clock moved on: nothing lost to an unshown frame)"
grep -q '^+		held = pending && m->holding && !m->holdover;' "$P" && [[ $(grep -c 't0 += now - .*last;' <(added animframe)) == 3 ]] \
  && ! sed -n '/if (held)/,/continue;/p' <(added animframe) | grep -q 'left = 1' \
  && _ok || _no "animframe ignores holdmon, or asks for frames while held (a held screen answering its own frames: dwl ran out of memory)"

case_ "after the unlock the pointer's surface and image are found once the lock has left the scene (no busy cursor left behind)"
d=$(grep -A9 '^ 	wlr_scene_node_destroy(&lock->scene->node);$' "$P")
grep -q '^-	motionnotify(0, NULL, 0, 0, 0, 0);$' <(grep -B12 '^ 	wlr_scene_node_destroy(&lock->scene->node);$' "$P") \
  && grep -q '^+	if (unlock)$' <<<"$d" && grep -q '^+		motionnotify(0, NULL, 0, 0, 0, 0);$' <<<"$d" \
  && _ok || _no "destroylock asks for the pointer before the lock is gone"

# ── beside the animations, in the same patch: full screen and X11 windows ──
case_ "focustop: a visible full-screen window first (a window it hides never takes the keys on a return to its workspace), else the latest focused one shown"
f=$(sed -n '/^ focustop(Monitor \*m)$/,/^ }$/p' "$P")
grep -q '^+		if (c->isfullscreen)$' <<<"$f" && grep -q '^+		if (!top)$' <<<"$f" && grep -q '^+			continue;$' <<<"$f" \
  && _ok || _no "focustop does not prefer the full-screen window"
case_ "arrange: an X11 window shown again is told it is not minimised (a Wine game black on returning to its workspace)"
grep -q '^+			if (VISIBLEON(c, m) && client_is_x11(c) && !client_is_unmanaged(c)$' "$P" \
  && grep -q '^+				wlr_xwayland_surface_set_minimized(c->surface.xwayland, 0);$' "$P" && _ok || _no "arrange leaves it minimised"

case_ "Super+Q on a warm window (notes, the clipboard, the system menu) puts it away, its page saved — never ends it mid-line"
k=$(sed -n '/^[ +]killclient(const Arg \*arg)$/,/^[ +]}$/p' "$P")
grep -q 'if (sel && iswarm(sel))' <<<"$k" && grep -q 'warmhide(sel, 1);' <<<"$k" && _ok || _no "killclient closes a warm window"
case_ "windows 8 px from the screen's edges and from the bar's lower hairline (outergappx: their edges on the bar's outer tiles' hairlines, x 8 and 1911; their tops on y 33), 8 apart (gappx)"
grep -q '^static const unsigned int outergappx *= 8;' "$CH" && grep -q '^static const unsigned int gappx *= 8;' "$CH" \
  && grep -q 'int n = 0, gap = (int)outergappx;' "$P" && _ok || _no "the edge gap"

case_ "unlocked: the lock screen dissolves off the desktop (anim_unlock_ms, a ghost of each screen's lock over it all, no sinking); locking: at once"
grep -q '^static const unsigned int anim_unlock_ms   = 420;' "$REPO/src/dwl/config.h" && grep -q '^+	if (animations && dissolveok()) {$' "$P" \
  && _ok || _no "anim_unlock_ms"
f=$(added ghosttree)
grep -q 'g->tree = wlr_scene_tree_create(parent);' <<<"$f" && grep -q 'g->ms = ms, g->rise = 0;' <<<"$f" \
  && grep -q '^+				ghosttree(m, m->lock_surface->surface->data, layers\[LyrBlock\],$' "$P" \
  && grep -q '^+						anim_unlock_ms, 0);$' "$P" && _ok || _no "ghosttree for the lock"
case_ "the screensaver over the lock: its own scene layer above the lock's, for the user's own kawa-saver alone (/proc/PID/exe); the lock holds no frame under it; a saver that does not go is taken off within SAVER_GUARD_MS"
grep -q '^+	LyrIMPopup, LyrBlock, LyrSaver, NUM_LAYERS }; /\* scene layers \*/' "$P" && _ok || _no "LyrSaver above LyrBlock"
f=$(added issaver)
grep -q 'strcmp(ls->namespace, "kawa-saver")' <<<"$f" && grep -q 'snprintf(link, sizeof(link), "/proc/%d/exe", (int)pid);' <<<"$f" \
  && grep -q 'return b && !strcmp(b + 1, "kawa-saver");' <<<"$f" && grep -q 'if (uid != getuid())' <<<"$f" && _ok || _no "issaver"
grep -q '^+		if (saverup(m))$' "$P" && grep -q '^+#define SAVER_GUARD_MS 1500$' "$P" && (($(grep -c '^+[[:space:]]*saverinput(.*);' "$P") == 4)) && _ok || _no "lockhold, guard, input"
case_ "after a long time away (the screens dark): the first input lights them at once, gives the keyboard back to the saver before the key is sent (lighting them sent it to the lock), and the guard waits for the screen to come back"
grep -q '^+	woke = saverwake();$' "$P" && grep -Pzq '\+	if \(woke\)\n\+		saverkeys\(\);' "$P" && grep -q '^+#define SAVER_WAKE_MS 4000$' "$P" \
  && grep -q 'SAVER_GUARD_MS + (woke ? SAVER_WAKE_MS : 0)' "$P" && _ok || _no "wake, keys back, longer guard"
case_ "a warm window (Super+U, N, V) shown unrolls from its top edge over anim_unroll_ms — its rod (the frame's foot: bottom hairline and shadow) travelling down, the picture cut above it (drawnheight, framelayout) — and one its key started unrolls as it maps"
grep -q '^static const unsigned int anim_unroll_ms   = 300;' "$CH" && grep -q '^static const unsigned int anim_rollup_ms   = 240;' "$CH" \
  && grep -q 'return (int)lround(c->geom.height \* e);' <(added drawnheight) \
  && grep -q 'int w = c->geom.width, h = drawnheight(c), o = c->bw ? 1 : 0, j, dx = 0, dy = 0;' <(added applyframe) \
  && grep -q 'framelayout(w, h, o, r);' <(added applyframe) \
  && grep -q 'animstart(c, AnimUnroll, 0);' <(sed -n '/^+warmshow(Client \*c)$/,/^+}/p;/^ warmshow(Client \*c)$/,/^ }/p' "$P") \
  && grep -q 'animstart(c, AnimUnroll, 0);   /\* (a warm window its key started: it unrolls) \*/' <(added showclient) \
  && grep -q 'return animations && !locked && c && c->mon;' <(added warmanimok) && _ok || _no "the unroll"
case_ "put away: a ghost of it rolls up into its top edge over anim_rollup_ms — its picture frozen as it stood (composed once: whatever the window draws once away is never seen), its frame laid out where the scroll ends; from as far as it had unrolled; shown again meanwhile: it unrolls from there"
f=$(added warmhide)
grep -q 'ghostscroll(c, f);' <<<"$f" && grep -q 'wlr_scene_node_set_enabled(&c->scene->node, 0);' <<<"$f" && grep -q 'animdrop(c);' <<<"$f" \
  && grep -q 'dissolveshow(&g->dis, pass, 0, 0, 1, 16.0);' <(added ghostscroll) && grep -q 'g->ms = anim_rollup_ms, g->rise = 0;' <(added ghostscroll) \
  && grep -q 'g->t0 = g->last = nowms() - (1.0 - cbrt(f < 0 ? 0 : f > 1 ? 1 : f)) \* g->ms;' <(added ghostscroll) \
  && grep -q 'int hv = (int)lround(g->h \* (1.0 - animease(t))), ih = MAX(hv - 2 \* g->o, 0);' <(added ghostapply) \
  && grep -q 'wlr_scene_buffer_set_source_box(g->dis.node, &(struct wlr_fbox){ 0, 0,' <(added ghostapply) \
  && grep -q 'f = c->rolling ? ghostopen(c->rolling) : 0;' "$P" && grep -q 'g->of->rolling = NULL;' <(added ghostfree) \
  && _ok || _no "the roll-up"
lacks "$(sed -n '/^+warmshow(Client \*c)$/,/^+}/p;/^ warmshow(Client \*c)$/,/^ }/p' "$P")" "ghostclient" "shown: never a ghost"
case_ "popups (warm windows, \"float\" ones) in their own scene layer above any full-screen window — Super+V over a film (bug 9); a floating layout leaves them there"
grep -q '^+enum { LyrBg, LyrBottom, LyrTile, LyrFloat, LyrTop, LyrFS, LyrPopup, LyrUnmanaged, LyrOverlay,$' "$P" \
  && grep -q 'return c->isfullscreen ? LyrFS : ispopup(c) ? LyrPopup : c->isfloating ? LyrFloat : LyrTile;' <(added clientlayer) \
  && grep -q '|| c->scene->node.parent == layers\[LyrPopup\])' "$P" \
  && grep -q 'wlr_scene_node_reparent(&c->scene->node, layers\[clientlayer(c)\]);' "$P" && _ok || _no "the popup layer"
done_
