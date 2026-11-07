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

## S17 2026-11-07 12:55
The owner (12:48), correcting S16: he does NOT use SQL at work (that was a mix-up); he learns it from zero. And more love for the web track.
1. SQL with PostgreSQL, a full track like the others, from zero: Fedora's current PostgreSQL server installed, started on demand (not always running), a learning database, psql. Tiny steps: SELECT and WHERE, sorting, JOINs, GROUP BY, then designing tables, keys, indexes, transactions, backups; then Postgres from Python with psycopg 3. Drop "SQLite from Python because he knows SQL" from S16.
2. Nothing outdated, anywhere in the lessons: check every lesson against the current official docs and tools as of November 2026 (current Python and uv, Rust 2024 edition, current PostgreSQL, psycopg 3 not psycopg2, modern CSS, modern JavaScript, HTMX 2), and end each lesson with a "checked against" line naming the doc and its version.
3. The web track, more love: simple, solid websites, modern, minimal and quick. Semantic HTML; modern CSS without frameworks first (custom properties, flexbox, grid, container queries, :has(), nesting, clamp() type); a little modern JavaScript (modules, fetch, no var, no jQuery); HTMX with a small Python backend for interactivity; speed (tiny pages, few requests, optimised images, at most one web font) and accessibility basics; publishing a static site. Project-based: he builds his own personal site step by step across the track.
4. He pointed again to the YouTuber Hayyoth: use your Hayyoth findings (r28-hayyoth.md) for the web track's look and teaching style.

## S18 2026-11-07 12:55
The owner (12:49): the learning in fedokawaii is SUPER important to him. He is a slow learner, learns by examples and practice, and dislikes complex words used without their definitions. Rules for every lesson (Part 1 and Part 2), applied to the lessons already written too:
- Example first, then the idea: show a small working example, then explain it, then let him try a variation.
- Practice is most of the lesson: about 2 parts doing, 1 part reading. Every lesson has a hands-on exercise with an expected result he can check himself, a hint, and the answer hidden until he asks.
- One new idea per lesson; slow, tiny steps; repeat earlier ideas in later exercises so they stick (a short "remember?" warm-up from an earlier lesson).
- Plain words. Any term he may not know gets a friendly one-line definition the first time it appears in that lesson, in a small box like "venv: a private folder of Python packages for one project", plus a glossary page that collects them all.
- Short sentences, no jargon chains, no walls of text; real, relatable examples (his folders, his notes, his books, his desktop).
- End each lesson with a 3-question check and one line on what comes next.
Rewrite the lessons written so far to these rules before writing new ones. This track gets opus (design he will judge) and a final read-through for plain language.

## S19 2026-11-07 13:00
The owner (12:51): go deeper on what happens behind the scenes, and DRILL the critical concepts into him fully. Claude chose the theory below; keep S18's rules (example first, plain words, every term defined, mostly practice).
HOW
- Every lesson gets a "Behind the scenes" part: what really happens underneath, a simple drawing (boxes and arrows in text), and a hands-on peek with a real tool (ps, strace, ss, curl -v, dig, git cat-file, EXPLAIN, the browser's dev tools, rust's borrow checker errors).
- Drilling: a 5-minute daily review at the start of each day (inside the ~30 minutes): flashcards and tiny exercises on earlier concepts, spaced out (again after 1, 3, 7, 14 days); a concept counts as learned after 3 right answers on different days. A "concept map" page shows each concept as new, practising or learned.
- A small project each week that uses the week's concepts together.
THE CONCEPTS TO DRILL (in this order, woven into the tracks where they fit)
1. The machine: CPU, RAM and disk; a program vs a process; what happens when he types a command (the shell, PATH, a new process, the exit code); files, permissions, users and sudo; stdin, stdout, stderr, pipes and redirection; bytes, text and UTF-8; binary and why 0.1 + 0.2 is not 0.3.
2. His system: how Linux boots; systemd services; packages and dependencies, versions; the filesystem layout; how his Wayland desktop draws windows (the compositor, dwl).
3. Programming: values, names and references; mutable vs immutable; functions, scope and the call stack; recursion; errors and how to read a traceback; a debugging method (reproduce, isolate, fix, test).
4. Data structures and cost: list, dict (a hash map, why lookup is fast), set, stack, queue; how work grows with data (big-O in plain words).
5. Memory: stack vs heap; Python's garbage collection vs Rust's ownership, borrowing and lifetimes (drilled hard); static vs dynamic types; Option and Result instead of null and exceptions.
6. Networks: IP addresses, ports, DNS, TCP vs UDP; HTTP request and response, methods and status codes; HTTPS and TLS in plain words; what happens when he opens a website.
7. The web: the browser's path from HTML to the DOM, CSS, layout and paint; the box model; the cascade and specificity; responsive layouts; the JavaScript event loop; client vs server; cookies, sessions and caching.
8. Databases: tables, rows and keys; relations and JOINs; designing tables without repeating data (normalisation in plain words); indexes (why they make lookups fast); transactions (all or nothing); EXPLAIN.
9. Git underneath: snapshots, commits as a chain, branches as pointers, merge and rebase.
10. Security: secrets never in code; input validation; SQL injection and XSS shown and then prevented; hashing vs encryption; least privilege.
11. Later: concurrency (threads vs async) and how tests protect a program (unit vs integration).

## S20 2026-11-07 13:05
The owner (12:54): learning is the most important part of fedokawaii, "no joke". Visuals wherever they help, nothing held back, more research, and information accurate to the dot. On top of S18 and S19:
VISUALS
- Wherever a picture explains faster than words, draw one: simple, calm, big labels, one idea per picture, in the desktop's style, crisp in both moods (SVG). Step-by-step pictures for processes (a command becoming a process, an HTTP request travelling, the call stack growing and shrinking, a git history changing, a JOIN matching rows, Rust moving and borrowing a value), animated or as numbered frames he can step through.
- The lessons open as local pages (Helium, offline) when pictures matter, launched by kawa-learn; your call on the exact viewer, as long as pictures, code and exercises sit together.
LEARNING SCIENCE (research it properly and apply it, cite what you used in the lessons' about page)
- Worked examples first, then the help fades step by step until he solves it alone.
- Retrieval practice and spaced review (S19), interleaving older topics into new exercises, words plus pictures together.
- "Explain it back": every few lessons he explains a concept in his own words in ~/notes, with a checklist to compare against.
- Instant feedback: exercises come with a checker (a small script that runs his answer and says what is right and what is not, kindly). A "common mistakes" box in each lesson.
- Motivation in the desktop's game style: a dojo rank that grows with practice, a streak, a weekly look back. Calm, never nagging.
CURRICULA TO ALIGN WITH (use as structure and checking sources, write our own lessons, no copying): MIT's "Missing Semester" (shell, git, tools), MDN's "Learn web development" (HTML, CSS, JS), the Python tutorial and the Rust Book (with Rustlings exercises), the PostgreSQL tutorial, and Julia Evans' style of visual explanations of Linux and networking (inspiration only).
ACCURACY TO THE DOT
- Every code example in every lesson is run by the test suite with its expected output, so no example can be wrong or go stale.
- Every fact is checked against the primary docs (S17's "checked against" line); when unsure, check, never guess.
- Before a lesson is marked done, a separate review pass (fresh context, opus) checks it for accuracy, plain language and S18's rules; fixes go in before it ships.
SCOPE BY THE DEADLINE
- The full syllabus, the concept map and the glossary; the first 14 days of lessons finished to this standard (pictures, checkers, review passed); the rest written ahead of him later, always at least 7 days ahead, through the same gates. Quality over quantity: never ship a lesson that has not passed the checks.

## S21 2026-11-07 13:10
The owner (12:58):
1. The lessons' look must never distract: super minimal, all the care in colours, fonts, spacing and alignment, following the theme in both moods, his eyes comfortable for long reading. Concretely:
   - generous spacing everywhere; text column about 60-70 characters wide; line height about 1.6; a larger body size (around 18-20 px); the chosen programming font for code, a calm reading font for text; everything aligned to one grid;
   - soft contrast from the theme (no pure black on pure white, no glaring accents), comfortable but clearly readable (WCAG AA at least);
   - pictures in the same muted theme colours, only where they teach (S20); nothing moves by itself: step-by-step pictures advance when he clicks; respect reduced motion;
   - the dojo rank and streak stay quiet in a corner or on their own page, never in the lesson's way.
   This replaces anything flashier in S20.
2. Add the C language. Claude's decision on the level and the place:
   - Place: after Python and Bash, SQL and the web, and before Rust. C shows how the machine really handles memory (and how easily it goes wrong); Rust then shows how it prevents those mistakes, so ownership makes sense.
   - Level: solid foundations, not expert: read and write small C programs; types, arrays, strings as bytes, pointers, structs, the stack and the heap, malloc and free; how source becomes a program (preprocess, compile, link) with gcc and make; debugging with gdb; catching memory bugs with AddressSanitizer and valgrind. The goal project: read his own dwl's config.h and a small patch, change it, rebuild and run it in a nested session.
   - Modern C only: C23 as Fedora's current gcc supports it, every example compiled with -std=c23 -Wall -Wextra -Werror and run under AddressSanitizer in the test suite. Check against current, solid sources: Jens Gustedt's "Modern C" (C23 edition), cppreference's C pages, Beej's Guide to C, the gcc manual; not old K&R-style code.
   - Its "behind the scenes" part ties into S19's concepts 1 and 5 (the machine, memory).
The full order of Part 2 is now: Python and Bash, then SQL and the web (with Textual TUIs), then C, then Rust; the basics underneath (S19) woven through. Accuracy gates (S20) apply to all of it.

## S22 2026-11-07 13:10
The owner (13:03):
1. No learning project may affect his PC in any way. Everything a lesson or project runs is contained and sandboxed:
   - One "dojo" sandbox (rootless podman containers, or bubblewrap where a container is too heavy) that sees only ~/dojo, nothing else of his home, no sudo, no system changes; servers bound to localhost only; the checkers run inside it too.
   - PostgreSQL runs in a container inside the dojo, not as a system service (this replaces S17's "Fedora's PostgreSQL server").
   - The C project on dwl works on a copy inside the dojo, built and run as a nested session inside the sandbox; it never touches the real dwl, its config or the system.
   - A reset command puts the dojo back to clean in one step.
2. Projects more fun and interesting, in the desktop's retro game spirit, for example: a samurai text adventure (Bash or Python), a terminal roguelike or a chess-puzzle trainer in Textual, a pixel-art generator, a small HTML canvas game on his site, a Postgres database of his books with a tiny HTMX page, a snake game in C, a terminal Tetris or a fast file finder in Rust. Your call, as long as each one practises that week's concepts.
3. The old learning book is gone for good: the Learn PDF, its sources, the book cover, its build and assets. Harvest the useful knowledge into the new lessons, then remove all of it (f27 started this; finish it, including any cover art, references and menu entries).
4. Plan a purge for the FINAL repo edit: list every leftover that a clean repo does not need (old books and covers, retired scripts, unused assets and renders, round-only tools, stale notes) in .claude/notes/r28-final-purge.md, and remove them in the final edit after the questionnaire. Keep CLAUDE.md working.
5. Make the terminal and Neovim coding experience even better: a minimal but truly effective setup for a human. Start from the twenty things a programmer does every day (open a file by name, search the project, go to a definition, rename, see and fix errors, format, complete code, run, test, debug, git status and commit, switch files, splits, a terminal, undo history, find recent files...) and make sure each has one obvious key in one consistent pattern (Space + a letter per topic: f find, g git, c code, r run, t test, d debug), all shown by which-key and on one cheat-sheet page. Add only what is missing (for example built-in LSP completion if it is not on, a terminal toggle, persistent undo); nothing decorative. It gets lessons of its own (Neovim with his config, S18's rules).

## S23 2026-11-07 13:15
The owner (13:11):
1. Projects: fun, but serious and useful, good enough for a future programming portfolio. Each track ends in one real project he would actually use and could show: a clear README with a screenshot or short demo, tests, a clean git history, a licence, sensible structure. Ideas (your call): a captures organiser CLI in Python (renames by date, finds duplicates); a bookshelf app (PostgreSQL + a fast, minimal HTMX site with search and reading progress); his personal portfolio site itself; a Textual TUI (a habit and lesson tracker, or a chess-puzzle trainer on open puzzle data); a C terminal game plus the sandboxed dwl patch; a Rust duplicate-file finder with a benchmark against his Python version. The fun stays (game touches, his desktop's style); the quality is portfolio-grade.
   Publishing to GitHub happens only when he decides, from outside the dojo, with his own account; the dojo never holds his credentials.
2. The dojo sandbox, made precise:
   - "dojo" (a command, a launcher entry and Super+U) opens a terminal inside the box; Neovim's run, test and debug keys (Space r, Space t, Space d) run inside the box for any file under ~/dojo.
   - Editing happens with his normal Neovim on the host (only text files change); running happens inside the box.
   - Pages served inside open in Helium at localhost.
   - "dojo reset" rebuilds the box (tools, packages, the database) but NEVER deletes his project files; wiping files is a separate command that asks first.

## S24 2026-11-07 13:20
The owner (13:17):
1. The dojo must be super solid and hard to break:
   - a pinned, versioned base image built from Fedora's current release; rebuilt reproducibly; works offline once set up; survives system updates and reboots (proved in the VM);
   - limits so a runaway program can never hurt the PC: memory, CPU, process count and disk caps, and time limits on the checkers;
   - "dojo doctor": checks the box, the database and the mounts, fixes what it can by itself, and says in plain words what it did; run automatically when "dojo" starts if something looks wrong;
   - stale containers and images cleaned automatically; its own tests in the suite (start, run Python, Bash, gcc with AddressSanitizer, cargo, psql, a web page on localhost, reset keeps his files).
2. The top bar's font a little thicker: one weight step heavier, same size, crisp. Show it with the T pack as set "BW" (bar weight): n 0 today, n 1 the new weight, dark and light, so he can confirm.
3. The lessons' steps: spell out every step as if he has never seen it: which window, which key, exactly what to type, and what he should see after each step ("press Space r; a panel opens at the bottom; it shows 'hello'"). Never skip an "obvious" step. But the THINKING must be challenging: easy to follow, hard to answer. Each lesson's exercises go warm-up, then real, then stretch, with puzzles that make him think (predict the output before running it, find the bug, fill in the missing line, choose between two designs and say why); hints come in layers (a nudge, then a bigger hint, then the answer). Drill the ideas until they stick (S19).

## S25 2026-11-07 13:25
The owner (13:20), last for now:
1. The keycap style he loves (h2's "ctrl + a" keys, S2) is used in the lessons too: every key or shortcut in a lesson is drawn as those keycaps, in the theme, both moods.
2. Part 1 (the system) must cover EVERYTHING about his own desktop that he needs to know: go through every feature, menu, keybind, app, tool and maintenance routine in the repo (the inventory, PACKAGES.md, the keys files, the menus, the quick settings, updates and snapshots, backups and restore, the dojo, the lock, Helium, Stoat, Syncplay, LocalSend, the inventory menu, the RGB and cooler, the boot menu rollback, how to recover when something breaks) and make a coverage list in .claude/notes/r28-lesson-coverage.md: each item and the lesson that teaches it. Nothing may be missing; the self-audit (S15) checks this list against the repo each day and adds lessons for anything new.
3. He is leaving the run alone now. Do SOLID work: the learning experience is the most important part. Go.

## S26 2026-11-07 13:45
The owner (13:35): the cooler display no longer blinks, but now shows a STATIC 99. c1's "off" (digits 0x0a, 0x0a, 0x0a every second, kawa-rgb.c disp_out) does not blank it; the firmware shows 99 for digits it does not know. Find a real off:
1. First, USB runtime suspend (the kernel can confirm it, no eyes needed): when the lights go off, kawa-rgb releases the display's hidraw, sets the display's USB device power/control to "auto" with autosuspend_delay_ms 0 (and its interfaces), and checks power/runtime_status says "suspended"; a suspended USB device may draw only 2.5 mA, so a USB-powered display should go dark. Back on: power/control "on", reopen, send digits. If the kernel cannot suspend it (usbhid holding it, no remote-wakeup), try unbinding usbhid from that one interface first, then suspend; rebind on the way back. Only this device (1a2c:4184), never the K617 or any other.
2. Last resorts, in this order: "authorized" 0 on that one USB device (1 on the way back); other values in the report's two ff bytes (a brightness or mode field?) with the digits blank, only with the allow-list care of S6.
3. Only eyes can tell whether the digits are really dark. Build kawa-cooler-test: a guided test he runs once in a terminal; it tries each candidate for 8 seconds and asks "is the cooler display dark now? y/n", logs the answers, and makes the first one that works kawa-rgb's off path. When it is ready, say so on its plan row (Claude will tell him the one command). Make method 1 the default meanwhile if the kernel confirms the suspend.
Restore everything on the way back (lights on, resume from sleep), tested both ways; never leave the device unusable.
