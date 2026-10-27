#!/usr/bin/env bash
# tests/session/test_hotplug.sh — a monitor dropping off the cable and coming back
# (src/dwl/dwl.patch): switched off at its button, or asleep long enough, the LG drops off
# HDMI and comes back as a new output. dwl crashed on that on 26 Oct 12:22 (configurex11
# read c->mon with no monitor there: the session ended, "a random restart"), and every time
# the monitor came back on tag 1. Kept here as the code that fixes it; the real thing — a test
# dwl on the other graphics card, its socket forced on and off by the kernel's own hotplug —
# is tools/hotplug-test.sh (root), which the old dwl fails at its first check.
. "$(dirname "$0")/../lib/harness.sh"

P=$REPO/src/dwl/dwl.patch
added() { sed -n "/^+$1(/,/^+}/p" "$P"; }

case_ "an X11 window asking for a size while no monitor is there: configured as it asks (no c->mon read)"
grep -Pzq '\+			\|\| client_is_unmanaged\(c\) \|\| !c->mon\) \{\n[ +]		wlr_xwayland_surface_configure' "$P" \
  && _ok || _no "configurex11 guard"

case_ "the other paths that run with no monitor: focusmon/dirtomon, the move's snap, an animation's start"
grep -Pzq '\+	if \(!selmon\)\n\+		return NULL;' "$P" && grep -Pzq '\+	if \(!selmon\)    /\* \(every monitor off or gone\) \*/\n\+		return;' "$P" \
  && grep -q '^+		if (selmon) {   /\* (the edges it snaps to' "$P" \
  && grep -Pzq '\+animstart\(Client \*c, int kind, int dir\)\n\+\{\n\+	int o = c->bw \? 1 : 0;\n\+	if \(!c->mon\)\n\+		return;' "$P" \
  && _ok || _no "NULL monitor guards"

case_ "kept under its name as it goes (cleanupmon → monkeep): tags, layouts, sizes, mode, focus, off"
f=$(added monkeep)
grep -q 'snprintf(k->name, sizeof(k->name), "%s", m->wlr_output->name);' <<<"$f" \
  && grep -q 'k->tagset\[0\] = m->tagset\[0\];' <<<"$f" && grep -q 'k->sellt = m->sellt;' <<<"$f" \
  && grep -q 'k->mfact = m->mfact;' <<<"$f" && grep -q 'k->refresh = m->wlr_output->current_mode->refresh;' <<<"$f" \
  && grep -q 'k->wassel = m == selmon;' <<<"$f" && grep -q 'k->off = m->asleep || !m->wlr_output->enabled;' <<<"$f" \
  && grep -Pzq '\+	monkeep\(m\);\n\+	wl_list_for_each_safe\(g, gtmp, &ghosts, link\)' "$P" && _ok || _no "monkeep"

case_ "back as it was (createmon): its tags and layout, the mode it had, the focus; one turned off stays off, asleep"
grep -q '^+		if (monkept\[i\].name\[0\] && !strcmp(monkept\[i\].name, wlr_output->name))' "$P" \
  && grep -q '^+		m->tagset\[0\] = k->tagset\[0\];' "$P" && grep -q '^+				m->wakemode = mode;' "$P" \
  && grep -Pzq '\+	if \(k && k->off\) \{\n\+		m->asleep = m->fresh = 1;' "$P" \
  && grep -Pzq '\+		if \(k->wassel && wlr_output->enabled\) \{\n\+			selmon = m;' "$P" \
  && grep -q '^+	if (child_pid > 0 && !m->fresh)' "$P" && _ok || _no "createmon restore"

case_ "lit by a key pressed, a button, a move — never by a key let go; at its mode, kawa-display as it lights"
f=$(added monpower)
grep -q 'if (on && !m->wlr_output->current_mode)' <<<"$f" && grep -q 'wlr_output_state_set_mode(&state, m->wakemode ? m->wakemode' <<<"$f" \
  && grep -q '"kawa-display", "--hotplug"' <<<"$f" && grep -Pzq '\+		if \(press\)\n\+			saverwake\(\);' "$P" \
  && grep -q '^+	saverinput(event->state == WL_KEYBOARD_KEY_STATE_PRESSED);' "$P" \
  && grep -q '^+	saverinput(event->state == WL_POINTER_BUTTON_STATE_PRESSED);' "$P" && _ok || _no "wake on press"

case_ "windows moved between monitors in a batch keep the focus order (monbatch): the focused one is focused again"
grep -Pzq '\+	if \(!monbatch\)\n\+		focusclient\(focustop\(selmon\), 1\);' "$P" \
  && (($(grep -c '^+[[:space:]]*monbatch = 1;' "$P") == 2)) && (($(grep -c '^+[[:space:]]*monbatch = 0;' "$P") == 2)) \
  && _ok || _no "monbatch"

case_ "the runtime check exists and fails the old way: tools/hotplug-test.sh (root, a free card)"
t=$REPO/tools/hotplug-test.sh
[[ -f $t && -f $REPO/tools/xconf.c ]] && grep -q 'kill -USR1' "$t" && grep -q 'echo 1 >"$dbg/trigger_hotplug"' "$t" && grep -q 'focus $want_title · C at $want_c' "$t" \
  && bash -n "$t" && _ok || _no "tools/hotplug-test.sh"
done_
