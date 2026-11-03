VERDICT: FAIL

# T20 review 1 — the lock as a scene, the login its twin, the fast wrong password, screens off after 5 s
Branch t20 @ 5cea79b (7 commits, 46 files over main). Reviewed 2026-11-03 04:45–05:30 by the master; nothing of the
owner's session touched; both repositories read-only. Scratch and evidence: /dev/shm/r27/master/T20/own/.

## What I checked, and how
- Code read in full: src/kawa-lockmod/kawa-lockmod.c, bin/kawa-lock, lock.ui, both gtklock.css, tools/build-lock.py,
  system/kawa-greet, system/gtklock.pam, the setup.sh/lib/guard.sh/verify.sh/report/theme.sh/kawa-wallpaper/build-art.py
  diffs, tests/look/test_lock.sh, tests/engine/test_greeter.sh, tools/regress/lock-start.sh, tests/installer/{lib,test_theme}.sh,
  design-system §0/§9/§11 — against gtklock v4.0.0's own window.c/auth.c/gtklock.c/module.c (fetched; Fedora's
  gtklock-4.0.0-3 carries no patch: `rpm -q --changelog` = initial inclusion), Linux-PAM v1.7.0 libpam/pam_delay.c, and
  the PC's PAM stack (`authselect current` = local; /etc/pam.d/gtklock = `auth include login`; system-auth = pam_env,
  pam_faildelay 2 s, pam_unix nullok, pam_deny).
- Built the module: `make -C src/kawa-lockmod O=…/own/build CFLAGS="-O2 -Wall -Wextra -Wshadow -Wformat=2 -Wconversion"` → clean.
- Memory/paths in the module, traced through gtklock's source: `window_pw_check` sets the error label to "" and
  `window_pw_failure` to "Login failed" every time (so `notify::label` fires on every wrong password, also two in a row);
  `window_pw_failure` re-sensitises, clears, grabs focus, then sets the label (the module's order of changed → focus →
  scatter is right); on a window's destroy GTK clears the focus in `gtk_window_dispose` BEFORE the DESTROY signal, so
  `on_state(l)` runs while `l` is alive, then `window_destroy_notify` → `on_window_destroy` frees `l`, then the children
  (and their handlers, and the area's tick callback) die — no use-after-free found; a check finishing after its screen
  was destroyed is gtklock's own upstream bug (ledger). A module crash would only restart gtklock under the keeper.
- Tests from the worktree: tests/look/test_lock.sh 157/0 · tests/engine/test_greeter.sh 46/0 · tests/installer/test_theme.sh
  141/0 · tests/static/test_syntax.sh 791/0 · tests/static/test_generated.sh 267/0 (outputs in own/tests/).
- The art rebuilt from a scratch copy of tools/build-lock.py (ROOT/OUT redirected, the ~/.cache/r27-art sources read
  only): all six files byte-identical to the committed ones (reproducible). Both scenes use only the mood's palette
  (dark 13 inks, light 17); every mark/caps/caret/ground ink in lock-scene.txt is a palette ink; the strips 144×30 (5
  colours) and 64×12 (4).
- Headless, my own kit runs with MY build of the module, the branch's art, lock.ui and css (LOCK_HOME + `--bin fk-t20/bin`):
  · tools/regress/lock-start.sh dark: held — locked in 103 ms, the scene ×3, 100.00 % of still pixels exact.
  · light play (own/hl/light): 3 typed → 3 marks + caret at place 3; 0.5 s later the caret off; 12 typed → 7 marks + caret
    at place 7 (the 8th); every shot 100.00 % scene-exact outside the flames and the row (gtklock's line draws nothing
    once settled); a key 1.0–1.5 s after the screens went dark was typed (the ≤ 2 s rule).
  · light2 / dark3 (a virtual keyboard held in the seat from the start): the caret is there at 0 s (c0/d0), off at 0.5 s,
    on at 1.0 s — the 1 Hz blink from the first second; the screens went dark 5243 ms after the last key (dark3; ~5.5 s in
    light2); a key after 4.5 s dark lit them and was NOT typed, the next one was (marks 3 → 4): the > 2 s rule holds.
  · greeter: not re-run (the branch's own headless sheet and test_greeter cover the protocol and the scene).
- Against the plan's acceptance: shots both themes ✓ (theirs + mine); caret at 0.0 and 0.5 s ✓ (mine, with a keyboard
  present); wrong password ≤ 400 ms: VM-proven 0.257–0.386 s over SIX tries (the plan asked ten) — see SHOULD-FIX 3;
  5 s → dark, a key lights, consumed only when dark > 2 s ✓ (10 cycles asked, ~5 seen across theirs and mine); greeter
  shot ✓ (headless cage sheet); tests updated ✓; Learn "lock" piece ✗ (not on the branch); bug 1's 35-min saver→lock
  re-verification ✗ (not on the branch, no dwl change here).

## MUST-FIX (before live)
1. **gtklock's own line flashes at the centre of the scene for the first ~140 ms of every lock.** Reproduced 4/4, both
   themes, with the branch's module and css (own/hl/first-{light,dark}/r{1,2}s{0..7}.png; crops own/crops/first-*-r1s0.png):
   at "locked"+0, +38, +73 ms there are 154–172 off-scene pixels — a 1 × 14 px caret column at x = 960 (y 544–557) and a
   141–157 px rule at y = 560/561 (x 882–1038), in BLENDED colours (dark 9d947a / f68c50 / f5b790, light e5dbb3 / dac292 /
   cc9c7c: the non-kawa `#input-field` rule and caret fading), 3 px left at +108 ms, clean from +140 ms. On the dark
   scene it sits on the Hannya's nose; the owner notices one frame. Cause to confirm: the entry's first style is the
   non-kawa one and the change to `window.kawa #input-field` is animated/settled over ~140 ms (adw-gtk3 declares
   200 ms transitions on `entry`). Direction: make the line invisible from its first frame independent of CSS timing —
   `gtk_widget_set_opacity(win->window_box, 0)` in `on_window_create` (keys still arrive; the greeter the same for its
   entry) — and add `transition: none` to every `window.kawa` rule (or `* { transition: none; }` in gtklock.css: nothing
   on the lock should animate through GTK); then prove it: tools/regress/lock-start.sh takes its shot at +0 ms as well
   as at 1 s (both ≥ 99 %), and the same four-shot check for the light mood and once for kawa-greet.

## SHOULD-FIX
2. No visible answer to a keystroke after the 7th: `shown = MIN(len, rn)` saturates and the caret only restarts its blink
   (invisible when it was already on). A 12-character password gives five silent keys — he will think a key was missed.
   Give every key an answer (the newest ember flares a frame, or the row scrolls by one), both module and kawa-greet.
3. The wrong password's time: libpam's `_pam_compute_delay` (v1.7.0) sleeps base × (1 + U) with U the mean of three
   uniforms − 0.5 → 150–450 ms for delay=300000, mostly 250–350; the VM's own samples already include 257, 286 and
   299 ms. So "0.3 s, never below 300 ms" (gtklock.pam's comment, the verify row's name, the ledger) is not true as
   written, and ~2 % of tries exceed 400 ms. Say the real range (and keep 300 ms as the base, or raise it knowingly),
   and time the ten tries the plan asked for.
4. The 5 s rule is 5.0–6.0 s: `g_timeout_add_seconds(1, idle_tick)` is coalesced to second boundaries (measured 5.24,
   ~5.5 and 5.72 s). Tick at 250 ms (or arm one timeout for exactly 5 s − elapsed) so dark comes at 5.0–5.25 s.
5. The Caps Lock ink (asagi arms) is unproven: wtype's virtual keyboard carries no Lock modifier, so neither the ledger
   nor my two tries could show it headless. Verify with a real keymap (a virtual keyboard whose keymap has
   `modifier_map Lock`) or live when the owner next locks; add the shot to the evidence.
6. Art, light mood (own/crops/light-ring.png, light-plaque.png, light-row-typed7.png): the wooden ring is 5 px of
   three-tone Bayer and reads as dither noise at 1× (two flat tones + one crisp highlight line, like the lanterns'
   bronze); the plaque floats in the sky with nothing holding it (the dark's lintel sits in the wall) — a cord to the top
   edge or a beam; the seal is a flat 8 × 8 square (a 5 × 5 negative mark inside makes it a seal); the motes are dark
   9 × 9 dots on paper — fine, but a 1 px `view` halo would let them glow as the embers do. The dark mood stands
   (own/crops/dark-mouth-typed10.png, dark-torch.png, dark-lintel.png).
7. tools/regress/lock-start.sh covers dark only; the light mood is one more kit run (or alternate moods between updates).
8. bin/kawa-lock `screens()` notes "on" even when `wlopm --on` failed: the module then thinks the screens are lit and
   the next key is typed into the dark. Write "on" only on wlopm's success (and say the failure).
9. Follow-ups before T20 may be marked DONE (not blocking live): bug 1 re-verified for real (saver, 35 min dark, a key,
   frames from dwl's log); the Learn "lock" piece (and docs/fedokawaii-guide.md still describes the padlock, seals,
   three keys and fig:lock — lines 1519, 1704–1709, 14160); design-system §11 "the lock goes … 600 ms" names a motion
   that does not exist on this branch — mark it planned (T21) or build it.

## NITS
10. draw(): the shake's `cairo_arc` clip is anti-aliased under `cairo_scale(3)` → blended off-palette pixels along the
    plate's rim for four 48 ms frames; `cairo_set_antialias(cr, CAIRO_ANTIALIAS_NONE)` keeps it pixel art.
11. tests/look/test_lock.sh:222 — the redirection fails before `2>/dev/null` applies and prints "No such file or
    directory" into the run (mkdir first); lines 415–417 reuse `c` (an array in the swayidle stand-in: SC2178/SC2128 under
    -x); tests/engine/test_greeter.sh:154 SC2013.
12. A held wake key: after the first press is swallowed, its repeats (same note, `mt == woken`) are typed.
13. on_window_create connects `on_caps` again whenever `looks` was emptied and a window is created anew (double redraws).
14. kawa-greet: `Gio.bus_get_sync(SYSTEM)` failing at start ends the greeter (pre-existing on main) — a try/except with
    the guard off would keep the login up.
15. The header of kawa-lockmod.c promises "a wrong password … 240 ms, five steps of 48" — measured 3.991→4.184 s in the
    branch's own frames (193 ms + the last step): fine, but say 5 × 48 ms = 192–240 ms.
