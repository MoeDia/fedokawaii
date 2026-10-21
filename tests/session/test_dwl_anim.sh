#!/usr/bin/env bash
# tests/session/test_dwl_anim.sh — dwl's animations (src/dwl/dwl.patch, config.h): a new window
# fades in rising its last anim_rise px, a closed one fades out sinking as far, a workspace
# switch cross-fades as the windows drift anim_drift of the screen aside — every frame the
# screen shows, eased out over anim_ms, nothing ever cut by a moving edge, never a full-screen
# window, never one not yet drawn at its size; tearing flips only with FreeSync on. What a headless dwl showed (frames grabbed through each, and rounds of
# windows opened and closed at once with switches mid-slide under ASan, nothing left on the
# screen), kept here as the code that does it.
. "$(dirname "$0")/../lib/harness.sh"

P=$REPO/src/dwl/dwl.patch CH=$REPO/src/dwl/config.h
added() { sed -n "/^+$1(/,/^+}/p" "$P"; }

case_ "config.h and config.def.h: on, 220 ms, a 24 px rise, a drift of 0.06 of the screen"
for c in "$(cat "$CH")" "$(sed -n '/^+++ b\/config.def.h/,/^--- /p' "$P" | sed 's/^+//')"; do
  grep -q '^static const int animations *= 1;' <<<"$c" && grep -q '^static const unsigned int anim_ms *= 220;' <<<"$c" \
    && grep -q '^static const int anim_rise *= 24;' <<<"$c" && grep -q '^static const double anim_drift *= 0.06;' <<<"$c" \
    && ! grep -q 'anim_steps' <<<"$c" && _ok || _no "animations, anim_ms, anim_rise, anim_drift"
done

case_ "driven by the screen's frames: each frame drawn for its own time, the next asked only while one runs (no timer)"
grep -q '^+		animframe(m, now.tv_sec \* 1000.0 + now.tv_nsec / 1e6, held);' "$P" \
  && grep -q '^+	if (left)$' <(added animframe) && ! grep -q 'animtick\|animtimer' "$P" \
  && grep -q 'return 1.0 - (1.0 - p) \* (1.0 - p) \* (1.0 - p);' <(added animease) \
  && _ok || _no "animations not frame-driven"

case_ "a new window unrolls only once it has drawn itself at its size (showclient from the commit that acks it)"
grep -q '^+		showclient(c, 1);' "$P" && grep -q '^+	showclient(data, 0);' "$P" \
  && grep -q '^+		animstart(c, AnimOpen, 0);' <(added showclient) && _ok || _no "open animation not tied to the acked first frame"

case_ "opening: no cut — the whole window fades in (its picture's opacity, its frame's colours) as it rises anim_rise px to its place, at its current place (a relayout mid-animation is followed)"
f=$(added applyframe)
grep -q 'dy = (int)lround(anim_rise \* (1.0 - e));' <<<"$f" && grep -q 'alpha = (float)e;' <<<"$f" \
  && ! grep -q 'h \* e' <<<"$f" && grep -q 'clientfade(c, alpha);' <<<"$f" \
  && grep -q '^+	applyframe(c);$' <(sed -n '/^ resize(Client \*c/,/^ }/p;/^+resize(/,/^+}/p' "$P"; grep -A2 'the scene: the window at its place' "$P") \
  && _ok || _no "applyframe: not a fade and a rise"
f=$(added clientfade)
grep -q 'wlr_scene_node_for_each_buffer(&c->scene_surface->node, fadebuffer, &a);' <<<"$f" \
  && grep -q 'col\[k\] = c->bcolor\[part\[i\]\]\[k\] \* a;' <<<"$f" && grep -q 'c->faded = a < 1.0f;' <<<"$f" \
  && grep -q 'if (alpha < 1.0f || c->faded)' <(added applyframe) && _ok || _no "clientfade: the picture and the frame (premultiplied), back to whole once done"
case_ "a workspace switch: the old windows fade out drifting one way, the new fade in drifting in from it — anim_drift of the screen, never a full-width slide"
f=$(added applyframe)
grep -q 'dx = c->animdir \* (int)lround(c->mon->w.width \* anim_drift \* (1.0 - e));' <<<"$f" \
  && grep -q 'dx = -c->animdir \* (int)lround(c->mon->w.width \* anim_drift \* e);' <<<"$f" \
  && grep -q 'alpha = (float)(1.0 - e);' <<<"$f" && _ok || _no "the cross-fade and drift"

case_ "tearing (async) flips only while FreeSync is on for the screen (vrr 1)"
grep -q '^+	if (m->vrr == 1 && (c = focustop(m)) && c->isfullscreen && client_surface(c)$' "$P" && _ok || _no "async flips without FreeSync"
case_ "an empty cut hides the picture (wlroots takes an empty clip for none)"
grep -q 'wlr_scene_node_set_enabled(&c->scene_surface->node, 0);' <(added applyframe) && _ok || _no "empty clip not handled"

case_ "a closed window's ghost fades out and sinks anim_rise px: each part its own colour or opacity, the tree where the window stood"
f=$(added ghostapply)
grep -q 'wlr_scene_node_set_position(&g->tree->node, g->x, g->y + (int)lround(anim_rise \* e));' <<<"$f" \
  && grep -q 'col\[k\] = p->color\[k\] \* a;' <<<"$f" && grep -q 'wlr_scene_buffer_set_opacity(wlr_scene_buffer_from_node(p->node), p->color\[0\] \* a);' <<<"$f" \
  && grep -q '^+	float color\[4\];' "$P" && grep -q '^+	int x, y; ' "$P" && _ok || _no "ghostapply / GhostPart / Ghost"
case_ "a closed window leaves a ghost of its own buffers that never takes the pointer, freed with its monitor and at exit"
grep -q 'wlr_scene_buffer_create(g->tree, b->buffer)' "$P" && grep -q 'n->point_accepts_input = ghostinput;' "$P" \
  && grep -q '^+		if (g->mon == m)$' "$P" && grep -A1 '^+	wl_list_for_each_safe(g, gtmp, &ghosts, link)$' "$P" | grep -q 'ghostfree(g);' \
  && _ok || _no "ghost lifecycle"

case_ "the ghost stays above the window that takes the focus after it"
grep -q '^+		wl_list_for_each_reverse(g, &ghosts, link)' "$P" && _ok || _no "a focused neighbour is raised over the ghost"

case_ "the switch: out to one side and in from the other, focus and layout at once; a window sliding out is not under the pointer"
v=$(sed -n '/^[ +]view(const Arg \*arg)$/,/^[ +]}$/p' "$P")
grep -q 'animstart(c, AnimOut, dir);' <<<"$v" && grep -q 'animstart(c, AnimIn, dir);' <<<"$v" \
  && grep -q '__builtin_ctz(now) > __builtin_ctz(was)' <<<"$v" && grep -q '(\*pc)->anim == AnimOut' "$P" \
  && _ok || _no "view() slide"

case_ "never a full-screen window, a warm one, an unmanaged one, or under the lock"
grep -q '!locked && c && c->mon && !c->isfullscreen' <(added animok) && grep -q '!iswarm(c) && !client_is_unmanaged(c)' <(added animok) \
  && grep -q 'if (c->mon == m && c->isfullscreen && (c->tags & (was | now)))' "$P" && _ok || _no "an exclusion is missing"

case_ "an animation waits while its monitor is held for a window to draw its new size (its clock moved on: nothing lost to an unshown frame)"
grep -q '^+		held = pending && m->holding && !m->holdover;' "$P" && [[ $(grep -c 't0 += now - .*last;' <(added animframe)) == 2 ]] \
  && ! sed -n '/if (held)/,/continue;/p' <(added animframe) | grep -q 'left = 1' \
  && _ok || _no "animframe ignores holdmon, or asks for frames while held (a held screen answering its own frames: dwl ran out of memory)"

case_ "after the unlock the pointer's surface and image are found once the lock has left the scene (no busy cursor left behind)"
d=$(grep -A9 '^ 	wlr_scene_node_destroy(&lock->scene->node);$' "$P")
grep -q '^-	motionnotify(0, NULL, 0, 0, 0, 0);$' <(grep -B12 '^ 	wlr_scene_node_destroy(&lock->scene->node);$' "$P") \
  && grep -q '^+	if (unlock)$' <<<"$d" && grep -q '^+		motionnotify(0, NULL, 0, 0, 0, 0);$' <<<"$d" \
  && _ok || _no "destroylock asks for the pointer before the lock is gone"

done_
