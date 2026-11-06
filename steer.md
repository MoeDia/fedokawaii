# Steering for the round-28 run, written by Claude while monitoring it for the owner.
# r28-pulse (on the PC, every 30 min) brings each "## S<n>" block below into the run's inbox, once.

## S1 2026-11-06 14:45
The owner (14:31) saw the 11 option sheets and wants to pick from a page of his own, every option shown on its own in high resolution and every motion as a video. Make this "picker pack" NEXT, before other plan rows (a plan row f16b), re-rendering what exists, no new design work. Target: in the pulse within 2 to 3 hours.
- Folder: ~/.local/share/r28/img/hi/ (r28-pulse pushes all of img/ to branch pulse; the old 300 KB and 16-file limits do not apply to hi/). Claude builds his picker page from it.
- One file per option and mood, never a sheet. Name: <set>-<n>-<mood>.<ext>, sets a b c d e f g h1 h2 i as on the sheets, n 0 = today's look, 1..3 = the options, mood dark or light.
- Stills (d e f g h1 h2 i): 1:1 real pixels with enough context to judge (the bar: the full 1920 wide strip plus some wallpaper; the lock: the full 1920x1080; prompt, menus, power, Helium: the element on a crop of the desktop). PNG for UI (crisp text), JPEG q95 only for full paintings. 3 MB each at most.
- Motions (a b c): MP4, H.264, yuv420p, +faststart, 60 fps, 1:1 pixels (a 1280x720 or tighter crop around the motion), 3 to 5 s, the motion played twice with a short rest, looping cleanly. Dark only, unless an option's motion differs by mood. 3 MB each at most. Also a still of the key frame per option as <set>-<n>-dark.png.
- picker.json in hi/: [{"set":"a","title":"Window open and close","kind":"motion","provisional":2,"options":[{"n":0,"name":"today: the hop","text":"450/400 ms"},{"n":1,"name":"seal","text":"a stamp, 150/110 ms"}, ...]}, ...] covering every set, texts short and plain. For e, two entries: "e" (dark lock) and "e2" (light lock), or one entry with both moods; say which.
- The whole hi/ at most 90 MB. When it is pushed, note it in the plan row, then back to the plan. His picks will come as S2.

## S2 2026-11-06 15:10
The owner's picks and notes, from his picker page (14:49) and his chat (15:05), his words kept where they matter. They override the provisional guesses and anything earlier on these points. Put each into the plan as rows; keep the deadline.
PICKS
- d prompt: 3 rakkan. BUT no demon or angel head anywhere: the head is a Fedora logo, "bloody" in dark mode and "lighty" (bright, gentle) in light mode, and the same Fedora head in the top bar. Drop the angel/demon idea from EVERYWHERE except the wallpapers (keep the wallpapers as they are).
- f bar: 3 jikusaki. The icons very clean, well spaced, drawn super accurately, tight.
- g power menu: 1 jiku, without the reddish area behind restart and shut down.
- h1 Super+U: 1 ichimai; the dense info lines (like "updated ...") better spaced, easier to read and absorb.
- h2 Super+R: 1 hon. The keycap style it uses to show keys (ctrl + a) is "SUPER awesome": use it everywhere it applies (menus, cheat sheets, lessons, the power menu, Helium's new tab, ...).
- i Helium: 2 mokuroku, made far more TUI-feeling: change the lines, the toolbar and the left tab section heavily, break them down, your call. Add Proton Pass to the pre-installed extensions.
- a b c motions: no pick yet; he picks from the videos (S1's pack: the motion videos first; stills of e are no longer needed, the lock is redone below).
LOCK SCREEN (replaces options e and e2 entirely; his earlier "drop the pixel act" is superseded, for the lock only)
- Simple and gamey: a small retro Japanese pixel-art samurai who reacts, super active, while he types the password: when typing starts, on each key, while deleting, on Enter right and on Enter wrong.
- The wallpaper behind it: super pixel-arty, full, very fun, a dense metroidvania-map style.
- 4 distinct variants for dark AND 4 for light. Dark: a male samurai. Light: a gentle female samurai ("super gentle feeling").
- Take your time on it: quality over speed. It must stay a real ext-session-lock lock: unlock never breaks, the password is never shown or logged; prove it in the VM.
- For his pick: the 4 + 4 as stills and short videos of the reactions in ~/.local/share/r28/img/hi/ (set "L"), with picker.json entries.
DROP
- Sketching and drawing: remove FireAlpaca, its shortcut, the tablet-specific support, all of it (packages, configs, menus, keybinds, lessons, tests, the inventory). He sketches on paper.
NEW
- The quick-settings icon on the top bar: a custom Japanese retro-style gear that spins while the quick-settings menu is open and stops when it closes (cheap on the CPU, follows the mood).

## S3 2026-11-06 15:15
The owner (15:09): bring pixel art back into the design SUBTLY, to strengthen the gaming, Japanese-retro feeling and give the menus more flair, especially the separator lines. Accents on top of the current crisp style, not the old pixelated look everywhere. He decides on his picker page, so make OPTIONS first, not a build:
- Five elements, options 1-3 each plus n 0 = today, each shown applied to real screens (Super+U, quick settings, the power menu, a notification, the bar), dark and light, 1:1 PNG, integer scaling only (no blur):
  P1 separators and rules (ideas: a dithered pixel rule, a pixel seigaiha wave band, a stepped rule with pixel end caps, a dotted rule with a tiny crest in the middle)
  P2 the selection marker in lists (ideas: a JRPG-style pixel pointer that bobs, a pixel brush-stroke underline, pixel corner brackets around the row)
  P3 panel corners and frames (ideas: pixel bracket corners, a one-pixel-stepped frame like an old game's dialog box, small pixel ornaments at the corners)
  P4 meters (volume, brightness, battery, downloads) as pixel HP/MP-style bars
  P5 small accents (a tiny pixel crest by a title, a pixel sparkle on focus, a falling pixel petal)
  plus one "all together" sheet per mood with your favourite combination.
- Motions among them (the bobbing pointer, a filling meter) as short MP4s, like S1's.
- picker.json entries (sets P1 to P5, kind still or motion) in ~/.local/share/r28/img/hi/ beside S1's pack. Order: S1's motion videos first, then this, then the lock (S2) when it is ready. Keep it consistent with his picks (rakkan, jikusaki, jiku, ichimai, hon, mokuroku).

## S4 2026-11-06 17:40
The owner's picks from the picker page (17:35) on the pack you pushed, with his notes. Put them into the plan; keep the deadline.
PICKS
- c menus and panels coming and going: 2 omori.
- P2 the selection marker: 1 yubi (the bobbing pointer). AND a rule for everywhere it applies: when something is highlighted or selected, change its COLOUR (text, icon) instead of putting a full highlight band behind it.
- P3 corners and frames: 3 kanagu.
- P4 meters: 1 tairyoku, with a better colour combination (your choice; show the result in the next pack as P4 with n 4, dark and light).
- Not picked: a (window open and close), b (workspace move), P1 (separators), P5 (accents), PA. For P5 he wrote "show me variants of something more game like".
NEW OPTIONS (he wants them to feel more like a game, Japanese retro game in particular)
- For a, b, P1 and P5: 4 NEW variants each, numbered 4 to 7 (keep n 0 = today; drop 1 to 3, he passed on them), in the same form as before: a and b as MP4 from real dwl builds plus a key-frame PNG, P1 and P5 as 1:1 PNG on the real screens, dark and light, plus MP4 for anything that moves.
- Ideas only, your call: a: a JRPG window that grows out of a line from its centre, a mosaic/pixelate dissolve, a scanline wipe, a battle-start flash, a door that opens like a metroidvania door. b: a room-scroll like old adventure games, an iris wipe, a diamond-tile wipe, a fast pixel slide with a dust trail. P1: an 8-bit window-border ornament, a chain of tiny pixel links, a pixel katana as the rule, a HUD segment rule. P5: a spinning pixel coin, a "!" pop, a pixel shuriken, a lantern that flickers, a small level-up sparkle. Keep it crisp (integer scaling), cheap on the CPU, and consistent with his picks.
- Into ~/.local/share/r28/img/hi/ with picker.json updated (sets a, b, P1, P5 with options 0 and 4 to 7; P4 with n 4 added). Order: these before the lock pack; the lock still matters most, take your time on it after.

## S5 2026-11-06 17:45
The owner (17:39): the motion videos must be SLOWER to judge and ACCURATE: "some of the animations looked identical to me, measure them properly". Claude measured the pack's MP4s (frame-to-frame difference at 60 fps, runs of changed frames) and they do not match the designs:
- a: the openings last 3 frames for seal (50 ms, designed 150), 7 for shoji (117 ms, designed 190), broken 1-2 frame blips for kasumi (designed 220), 11 for today (183 ms, designed 450). The closings are missing in a-1 and a-2 (only the two openings show up).
- b: hayate 7 frames (117 ms, designed 220), kakejiku 12 (200 ms, designed 420), fusuma 5-7 (about 100 ms, designed 300), today 12-17 (designed 450).
- c: all four open in 13-17 frames (217-283 ms) although they are designed 300, 380, 460 and 340 ms, which is why they look alike.
So the real-time headless recording drops or compresses frames. For every motion video from now on (the new a and b variants 4-7, and the today references a-0 and b-0):
1. Render frame-exact, not by recording in real time: drive the animation clock deterministically (a test-only hook that steps dwl's animation time by exactly 1/60 s per frame and captures each frame with screencopy), so nothing is dropped.
2. Two files per option: <set>-<n>-<mood>.mp4 at real speed and <set>-<n>-<mood>-slow.mp4 at a quarter of the speed (4 times slower). Open AND close, each twice, with a short rest between.
3. Measure before shipping: per video, the frames that change and the open/close durations; they must match the designed ms within one frame. Write the measured values into picker.json per option ("measured": "open 190 ms / close 150 ms").
4. Check that the options really differ: compare each pair's frame sequences; if two look nearly the same, fix the motion or the recording before shipping, and say so in the plan.
5. Add a one-image frame strip per option (<set>-<n>-<mood>-strip.png, every frame of the opening with its time in ms) so he can see the steps.
c is already picked (omori): re-record omori this way once, as c-2 with the slow version, so he can confirm it.
