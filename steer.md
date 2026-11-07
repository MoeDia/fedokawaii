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

## S6 2026-11-06 17:50
The owner (17:43): with the PC dark, the CPU cooler's display blinks "99" about once a second. It must be dark too, whenever ~/.config/fedokawaii/dark exists and whenever the RGB is switched off. A small task: do it next.
- Find what makes the blink (kawa-rgb's cooler feeder stopped, so the display shows its own no-signal blink? a stale or malformed frame? the "off" frame read as 99?) from kawa-rgb's code and the protocol notes (lane-hardware's section 9, src/kawa-rgb).
- Make "kawa-rgb off" blank the display for good: the protocol's blank/off frame if it has one, or a blank frame sent at whatever rate keeps it blank. Remember Report 5 and the ISP bootloader: only the known selectors, from the allow-list.
- If the display cannot be blanked, say so in the plan (blocked, with the evidence) and make it show the real temperature steadily, never blinking.
- Prove it with nothing else lit, and keep it dark across reboots (r28-dark calls "kawa-rgb off" every 30 minutes).

## S7 2026-11-06 17:55
The owner (17:51): "reduce the transparency effect a little". Everywhere translucency is used (terminals, menus, panels, quick settings, notifications, the launcher; nvim already has none), make it a little more opaque: roughly 6 to 8 points more alpha (for example 0.85 becomes 0.92), one shared value per mood from the theme, not per app. Show it in the next pack as set T ("Transparency", still, dark and light): n 0 today and n 1 the new value on the same real screen, so he can confirm.

## S8 2026-11-06 18:00
The owner (17:59): he is very picky about the design and will go several rounds, so the design work must NOT slow the rest. Run it as a separate, bounded track:
- Alternate: after each design task (options, renders, videos), do two non-design tasks (learning system, nvim, apps, Stoat, Syncplay, inventory, repo clean-up, the Fedora 45 ISO and its installer, tests). The ISO and installer track must start on schedule (Sunday) whatever the design rounds do.
- Never wait for his picks: when a design needs a pick, park it and move to other work; his picks arrive through these steering notes.
- Make options only good enough to judge, never polished twice; build the picked designs through the theme's shared tokens and small swappable parts, so a late change of mind is a quick swap, not a rebuild.
- The S6 cooler fix and the S5 frame-exact recording hook count as engineering, not design rounds.
- Keep the plan's day order; if the design track falls behind, it is the design track that waits, not the rest.

## S9 2026-11-06 22:40
The owner picked a (window open and close): 5 mozaiku, from the frame-exact videos. Build it as the default (behind the same switch, the others stay one switch away). b's new 4-7 (heya, hitomi, hishi, suna) are on his page now; no pick yet.

## S10 2026-11-07 00:40
- The owner picked b (workspace move): 4 heya. Build it as the default, the others one switch away.
- P1's new separators (waku, kusari, ken, kizami) are on his page; no pick yet.
- Check the home folders against his words: exactly ~/downloads, ~/captures, ~/notes, ~/books and ~/dojo, all lowercase, nothing else (no Desktop, Documents, Projects...). f20b's commit says "~/Projects is the dojo": if ~/Projects exists or is used anywhere, it must be ~/dojo (rename, no symlink named Projects). Fix it if needed, in the VM and the docs.

## S11 2026-11-07 00:55
The owner (00:49): speed things up a little while spending FEWER tokens. Be smart about models and overhead:
1. A model per task, from the plan row (add a column "model" to r28-plan.tsv: opus, sonnet or haiku; default sonnet):
   - opus only for: design work he will judge, the dwl/C patches, the lock, the ISO and its installer, anything about security, and any task that already failed once on a cheaper model;
   - sonnet for ordinary coding, configs, apps, tests and docs that need judgment;
   - haiku for mechanical work: renames, sweeps, doc updates that follow a decided change, regenerated lists, running checks and summing them up.
   r27-lane-loop passes --model (alias opus, sonnet or haiku) from the "now" row; effort medium (low for haiku rows). Change the loop carefully: keep the old line commented beside it, test it on one pass, and if a pass on a cheaper model fails, the row goes back to opus.
2. Less overhead per pass: a short pass brief (.claude/notes/r28-brief.md, under 150 lines: the rules, the current task, where things are) read at the start instead of the long notes; big files by grep and line ranges only.
3. Two or three tiny related rows may share one pass (fewer start-ups); never a big one.
4. Tests: per task, only the checks for what changed; the full suite and a full VM install once a day and before the ISO is cut, not after every task.
5. Let Claude see the mix: extend ~/.local/bin/r28-track so pulse.md's tokens line also splits output tokens by model (message.model in the transcripts), last 6 hours and since the start (keep its CLI and page working; restart r28-track).
Everything else stays: S8's balance, commit and push per task, nothing may break.

## S12 2026-11-07 02:45
The owner's picks and notes from his page (00:47), his words kept:
- P1 separators: 4 waku. BUT "top bar, notifications, power menu: these places don't need a separator line; use it smartly and avoid it to keep things nicer and more tidy, and be very careful about its thickness, don't make it too thick."
- Highlights, everywhere: no red background band behind the selected option, and no underline like the one under "status" in Super+U. A selected or highlighted item changes its colour only (as S4 said). "Be careful."
- The quick-settings menu: "don't forget to give it some love like we discussed before" (round 27's ask), together with the spinning gear (S2).
- c menus (omori): "the menu and all other similar menus should keep the scroll design even after the open, not switch back to the normal border; it needs to look consistent and legit." The scroll's rods and edges stay for as long as the menu is open, in every menu of that kind.
- P5's new accents (zeni, bikkuri, shuriken, chochin) are on his page; no pick yet.
- The lock (l4) is his top design item and has been blocked since Friday evening: retry it with a fresh approach, on opus, before Sunday's ISO work.

## S13 2026-11-07 04:15
Claude, watching the pulse (Sat 03:44):
- All four daily rows (dsat, dsun, dmon, dtue) ran back to back on Saturday morning, about two hours each; the ETA slipped from Sun 11:47 to about Sun 22:30. Let dtue finish (do not kill a VM mid-install). Then add one new daily row for each remaining calendar day (Sun 8, Mon 9, Tue 10), each run only on its own day, Dubai time, and never one straight after another; the loop must not pick a daily row before its day. Go on with the plan.
- S11's model mix is not biting yet: in the last 6 hours opus wrote 275k output tokens, haiku 11k, sonnet 8k. Check that the open rows really carry sonnet or haiku where S11's rules say (most coding, configs, apps, tests and docs are sonnet; sweeps, checks and runs like the daily suite are haiku), and that the loop really passes --model (look at message.model in the latest transcript). Opus stays for design he judges, dwl/C, the lock, the ISO/installer and security.

## S14 2026-11-07 09:35
The owner (09:25): make up for the hours lost (the four daily suites back to back, and steering that waited for his Mac). Boost the pace a little more, still one agent at a time, still cheap:
1. Long machine jobs (a VM install, the full suite, the ISO build, renders) run in the background as their own systemd user units (still one VM at a time). The pass starts the job, marks it "running" in the plan, and goes on with the next row that does not touch the same files or the VM; a later pass reads the result. No pass sits waiting on a VM.
2. No idle time between passes: check the loop's sleep or back-off and the conductor's interval, and start the next pass as soon as one ends (keep the wait for a usage-limit reset).
3. Daily rows run only on their own day (S13), and a daily run is skipped when the previous one passed less than 12 hours earlier with no system-level change since.
4. Sonnet for every row S11 allows; by tonight the pulse's model split should show sonnet doing most of the rows.
5. Target: the ETA back to Sunday noon or earlier. Nothing may break; S8's balance stays.

## S15 2026-11-07 09:45
The owner (09:40): his Mac will sleep, so Claude's notes can arrive hours late, and he will change nothing on GitHub. Steer yourself:
1. Order the work so nothing ever waits on him or on Claude. Rows that need a pick or a note are parked; there is always a next row that needs nobody (engineering, apps, learning, nvim, repo, ISO and installer, tests). A design row waiting for a pick: build the strongest option behind a switch (S8) and move on; swap when the pick comes.
2. A self-audit every 6 passes (cheap, on haiku), the checks Claude would otherwise send by hand: (a) pace against the plan and the ETA trend; (b) no daily row before its day, no long job repeated; (c) the model mix (sonnet should carry most rows); (d) any pass over 90 minutes, any idle gap between passes; (e) a blocked row older than 6 hours gets one fresh attempt with a different approach; (f) the design track not crowding out the rest. Fix what it finds and note it in the plan.
3. Claude's notes still arrive through steer.md whenever his Mac is awake. Treat them as his voice, never wait for them.

## S16 2026-11-07 12:55
The owner (12:43), in order of size:
1. Packages: add smartmontools and LocalSend only (he declined Syncthing and Tailscale).
   - smartmontools: smartd watches the disks; a warning becomes a notification and a line in Super+U's inventory/health; part of the self-maintenance.
   - LocalSend: from its official release (RPM or AppImage, self-updating like the other release apps; NOT Flatpak, Flatpak stays inside ASOBI); its port (53317, TCP and UDP) open in the home/LAN zone only; in the launcher and Super+U's inventory.
2. Neovim colours: no third-party colorscheme. Generate our own colorscheme ("kawa") straight from the theme tokens in tools/build-themes.py, for both moods, following the mood switch live as now; drop the gruvbox plugin (one plugin fewer).
3. Rust in Neovim: keep what is there (rust-analyzer with clippy on save, rustfmt, taplo, Space r keys, codelldb), and add inlay hints for Rust (types shown in the code, a key to toggle them), which help a learner most. crates.nvim only if it stays tiny.
4. The daily lessons, Part 2: make him a well-rounded programmer, still about 30 minutes a day, tiny steps:
   - Bash scripting as its own track, early: his desktop is built of shell scripts.
   - Python stays the main language. Connect it to the SQL he already uses at work (SQLite from Python).
   - Simple, solid frontends: HTML and CSS, a little JavaScript, and HTMX with a small Python backend (FastAPI); and terminal UIs with Textual (Python), later ratatui (Rust), matching his desktop's look.
   - Rust after the Python basics, with Rustlings-style tiny exercises.
   - Short units on the basics underneath: the command line, regex, HTTP and networking, data structures; git, testing, debugging and security as planned.
   - Order: Python and Bash first, then web and TUI frontends, then Rust. Write the track list into the lessons' table of contents.
