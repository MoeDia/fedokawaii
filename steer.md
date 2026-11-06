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
