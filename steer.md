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
