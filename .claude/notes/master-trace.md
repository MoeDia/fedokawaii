# Master trace: every request the owner has made, and where it stands

Written 2026-11-01 for the independent reviewer (plan T19n). It lists every distinct request the owner has made, from the r24 list (21 Oct) to the inbox entry of 2026-11-01 00:11, one row each, so a reviewer can check that nothing was missed. It is conservative: a request is `done` only where the ledger says so and records how it was verified.

Snapshot: repo HEAD e1481c5 (1 Nov 00:47), ledger 1461 lines, plan 768 lines (tasks T01 to T63), inbox 5 entries. The main agent keeps working, so later ledger lines are not in it.

## Sources (read in full)

1. `.claude/notes/02-LEDGER.md`: r24 list and verify pass, r25, r26 and its follow-ups, the r27 lines.
2. `CLAUDE.md` from "Round 27, the owner's notes of 2026-10-25" to the end: his decisions, bugs 1 to 17, the bar redesign, every later block (18:48, installer, update, ISO, fonts, RGB, monitor, never again, network, lock, 14:07, 26/27 Oct, gaming VM, one design, also, 14:27, 19:19, the INBOX FILE rule and the remote-page rule).
3. `.claude/notes/round27-owner-notes.md`: his raw words of 25 Oct (cross-checked line by line in Appendix B).
4. `.claude/inbox.md`: his newest raw requests (23:47, 23:52, 23:55, 23:56, 00:11).
5. `.claude/plan.md`: tasks `### T..` with the status in brackets, used to map each request to its task.

Also read for the wording of the r24 and r25 requests, which the ledger only abbreviates: `.claude/notes/src-r24-owner-requests.md`, `.claude/notes/src-r25-plan.md`. Not traced: the standing rules at the top of CLAUDE.md (lines 1 to 106) and the operating steps of START (0 to 6), except where they hold a deliverable (rows `r27-run-*`). The owner's r24 list has no items 28, 30 to 32 and 39.

## Legend

- **Status.** `done`: the ledger records the work finished and how it was verified (a measurement, shot, frame log or test run on this PC or its render kit); where the ledger says his eye is still pending, the proof says so. `wip`: partly built, built with only part of the proof, reopened by a later note, or a standing rule kept in force. `todo`: not started (plan task marked [todo]) or the ledger says "?" with no later line. `dropped`: superseded or withdrawn; the reason is in the proof cell (gaming VM decision, new font set, new bar, new lock, new prompt, new motion).
- **Proof.** What the ledger says was measured, shot or tested; "none recorded" when it says nothing. `kit` is a headless render of the real scripts (r24 to r26: the cloud sandbox's kit, not the PC; r27: tools/kit.sh on this PC's GPU). `live` is his running session on this PC (grim or a measurement). `r27-NN` points at a ledger line.
- **Task.** Plan task id. `T52` alone on an r24 to r26 row means done before round 27 and only its regression check is planned. `conv` is the plan's Conventions section. `plan` is plan.md itself.
- **Flag.** `UNPLANNED`: no plan task answers it (the generic catch-alls T51, T52, T59 to T61 do not count). `UNPROVEN`: marked done but the ledger records no verification. `STALE`: a done or VERIFIED mark (in the plan or the ledger) that a later ledger line or owner note reopens; the row's status shows the corrected state.
- `(= id)` in a request marks a row that repeats another row's request (each ledger-numbered line keeps its own row). The ids of round 27 follow CLAUDE.md's order: `dec` his decisions, `bug`, `bar`, `1848`, `inst`, `upd`, `iso`, `fonts`, `rgb`, `mon`, `never`, `net`, `lock5`, `rep` (14:07), `more`, `vm`, `one`, `also`, `run`, `1427`, `1919`, `rule`, `led` (a note recorded only in the ledger), `inbox`.

## r24: the "final round" list of 21 Oct (ledger numbers; src-r24-owner-requests.md)

| id | request | task | status | proof | flag |
|---|---|---|---|---|---|
| r24-rep | Fix every report FAIL and WARN (mako double start, BAR, RES, PERF, UI, THEME-22) | T53 | wip | none recorded; verify 257/258 on 31 Oct (one: his qbittorrent) | |
| r24-1 | `update` got stuck; had to run it again | T45, T49 | todo | none recorded ("?" in ledger) | |
| r24-2 | Black box still shows after choosing the kernel in the boot menu | T41, T59 | done | journal: splash on amdgpu only; owner to confirm visually | |
| r24-3 | Calculator and notes footer hints glitch while typing | T52 | done | typing at 15 ms/key: footer whole, answer live | |
| r24-4 | Bar tooltips: minimal words (volume, brightness, RAM) | T15 | done | live tooltips read; reframed r27-15d, measured both themes | |
| r24-5 | Custom pixel icons instead of the duck and sheep launcher icons | T16 | done | seals checked r24; r27-16 pixel icons, 22 entries, test_launcher | |
| r24-6 | Clipboard: gap between input line and first entry | T52 | done | blank row between input and first entry, checked live | |
| r24-7 | Dark/light switch transition better, matching the wallpaper transition | T19 | done | wash.sh 199 frames over 1204.6 ms; anim-check wash 1200.0 | |
| r24-8a | Opening many terminals fast: no mis-laid text or duplicate headings | T24, T52 | done | 8-window bursts 0/17 duplicates (was 40%); test_tiles 142/0 | |
| r24-8b | Restyle the prompt to the newest design system | T24 | dropped | superseded by the r27 pastel-powerline prompt (r27-dec-6a) | |
| r24-8c | Proper space between cursor line and first item in every TUI | T16 | done | six TUIs: heading, blank, input, blank, list; r27-16 grammar | |
| r24-9 | Super+N rapid toggle faster | T52 | done | 3 presses in 163 ms toggled 3 times | |
| r24-10 | Screen recording entry in quick settings | T19k-7 | done | record tile checked r24; now one hour of the dial | |
| r24-11 | Calendar previous, next, today glitchy or unresponsive | T52 | done | 5 Enters in a burst reached Mar 2027, none lost | |
| r24-12 | btop better spaced, consistent, minimal | T52 | done | looked at: block graphs, square corners; accepted, no measurement | |
| r24-13 | Bar dropdowns recolour on hover only after a first click | T13 | done | reopened 25 Oct; root cause fixed r27-13a, menu-first-click.sh | |
| r24-14 | Volume mixer: more space after the diamond marker | T52 | done | wiremix shows air before "HD-Audio Generic" | |
| r24-15 | Torrents not working; a pip error notice keeps appearing | T29 | done | VERIFIED r25-9 both themes; r27 overhaul is separate (T29) | |
| r24-16 | Steam tooltip said "starting" while Steam was running | T35 | dropped | superseded: Steam leaves the host (gaming VM decision) | |
| r24-17 | Launcher calculations and currency conversion work | T52 | done | "100 eur in usd" gives $112.15; "5 km to miles" correct | |
| r24-18 | Windows open, close, resize perfectly smooth, no wrong-size frame | T19 | done | anim-check open 420.0, close 400.0 shipped dwl; live shots | |
| r24-19 | Learn guide much longer: Python and Rust levels, exercises | T63 | done | 90k words, Python levels 1 to 4+, Rust, 71 exercise headings | |
| r24-20 | Wallpapers rotate every 4 h, 100 total, nice transition | T16, T19 | done | 111 in the picker, rotate row first; wash verified | |
| r24-21 | Blasphemous does not work: diagnose, pick the best Proton | T35 | dropped | superseded: games leave the host; game ran after owner's save choice | |
| r24-22 | Yazi file picker jumbled and overlapping; yazi disappointing overall | T22 | wip | portal save picker clean (r24); whole-UI rebuild still T22 | |
| r24-23 | Font slightly thicker for readability in UI and terminal | T07 | dropped | superseded by the r27 font selection (r27-fonts-1) | |
| r24-24a | Screensaver wake slow, black screen before the lock | T20 | wip | VERIFIED r26-10 headless; owner still sees it (r27-bug-1) | STALE |
| r24-24b | Lock screen looks too thin | T20 | dropped | superseded by the r27 lock redesign (r27-dec-4a) | |
| r24-25 | PDF size reduction, Super+Z rules, stale image, 52 KB size bug | T16, T52 | wip | text clipboard gives "nothing to shrink"; PDF shrink not recorded | |
| r24-26 | Alt+F menu and share picker: first option highlighted | T52 | done | launcher, timer, calendar open on first choice; Alt+F, picker unnamed | |
| r24-27 | Window screen-share rock solid, better viewer quality | UNPLANNED | todo | none recorded ("?" in ledger) | UNPLANNED |
| r24-29 | Sleep and wake with Enter | T52 | done | owner said it works | |
| r24-33 | Clean mic: verify it is really active | T17b | dropped | superseded: clean mic removed entirely (r27-1427-2) | |
| r24-34 | Blasphemous 60 fps cap; black game after workspace switch | T35 | dropped | superseded: games leave host; dwl fix r26-26 stays in dwl | |
| r24-35 | Downloads icon shows percent; zip and PDF progress; all sources | T14, T31 | done | job file gives "50%" on the bar; Brave % still open | |
| r24-36 | Recording: pause/resume with 3-2-1 countdown; fullscreen performance | T52 | done | pause, countdown, resume, mp4 written; fullscreen performance not recorded | |
| r24-37 | OCR and screenshot keys reachable on a 61-key board | T23 | done | bound in config.h (Super+Shift+X, S, A); no run recorded | UNPROVEN |
| r24-38 | Fast clicking better, system-wide | T52 | done | 7, 6, 5 clicks at 50-60 ms: every click counted | |
| r24-40a | Boot menu still shows an orange progress bar | UNPLANNED | todo | none recorded; waits for the owner's boot video | UNPLANNED |
| r24-40b | Black blink twice before the lock screen after boot (= r24-2) | T41, T59 | done | journal: splash on amdgpu only; owner to confirm | |
| r24-41a | Every Super+U option works; custom menus aligned to the pixel | T12, T45, T48 | wip | T12 entries open or say "not yet"; update, held, restore pending | |
| r24-41b | Super+U update pulls from the public GitHub repository | UNPLANNED | todo | none recorded ("?" in ledger) | UNPLANNED |
| r24-42 | Rethink kanji/launcher colour change and workspace borders | T14 | done | owner picked kami (r26-20); re-measured at 27 rows r27-14a | |
| r24-43 | Treat every warning, failure and comment seriously | conv | wip | standing rule; verify 257/258 live (one: his own qbittorrent) | |
| r24-44 | Token-efficient, sequential, careful, deterministic work | conv | wip | standing rule; none recorded | |
| r24-45 | Screensaver follows the current theme | T52 | done | light saver shot: indigo on kinari | |

## r25: his 14 points of 21 Oct 17:27, plus the 18:34 and 18:59 additions (src-r25-plan.md)

| id | request | task | status | proof | flag |
|---|---|---|---|---|---|
| r25-1 | Font thicker: Sumi UI Bold, Sumi Term Bold | T07 | dropped | superseded by r27 faces; r25 check: declared Bold, no smear | |
| r25-2 | Super+W: current wallpaper highlighted; 4-hour toggle text not cut | T16 | done | verified r25 on PC; toggle now a key line (r27-16) | |
| r25-3 | Bar menus: hover and keys work without a click; static rows unselectable | T13 | done | reopened 25 Oct; root cause fixed r27-13a, menu-first-click.sh | |
| r25-4 | Bar redesign: no boxes or stitches, colour only | T14 | dropped | superseded by r26 v10, then kami, then the r27 bar | |
| r25-5 | Notifications: alignment, spacing, icon against text | T15 | done | r27-15b: notices measured headless and live, 410 wide | |
| r25-6a | Terminal prompt: cursor gap, new prompt, torii not cut | T24 | dropped | superseded by r26-24, then the r27 pastel-powerline prompt | |
| r25-6b | Lock screen redesign: subtle wallpaper, no stretched box | T20 | dropped | superseded by the r27 lock redesign (r27-dec-4a) | |
| r25-7 | Boot black box and two flicks: drop plymouth.use-simpledrm (= r24-2) | T41, T59 | done | journal: splash on amdgpu only; owner to confirm visually | |
| r25-8 | Snapshots boot read-only | T48 | done | verified on PC r25 | |
| r25-9a | Torrra faster and themed exactly | T29 | done | verified on PC, both themes (r27 overhaul is T29) | |
| r25-9b | Neovim fully themed | T30 | done | verified on PC, both themes | |
| r25-10 | Best possible audio quality | T58 | done | none recorded; "verify active" via pw-metadata left open | UNPROVEN |
| r25-11a | Update, repair and install run clean | T54 | done | apply rc=3 only test tools; r27-5 fresh VM verify 251 | |
| r25-11b | Launcher live calculator; notice shows the copied result | T52 | done | kit launcher-calc shot | |
| r25-12 | Launcher icon click toggles; mouse and keyboard unified | T52 | done | verified earlier (ledger, no detail) | |
| r25-13 | Script TUI looks consistent and optimised | T53 | done | lib/common.sh grammar; verify window checked on PC | |
| r25-14 | Full sweep: bugs, performance, research | T59 | wip | open; part of r26-11 | |
| r25-15 | dwl animations; fix rapid open and close artifacts | T19 | dropped | superseded by r26-6, then the r27 dissolve motion | |
| r25-16 | Be the end user: open every app and menu, fix bugs | T59 | todo | none recorded (final phase) | |
| r25-17 | Learn guide: AI and Claude Code part with exercises, fundamentals | T63 | done | Part VI and appendix D merged; PDFs rebuilt r26 | |
| r25-x1 | Bar menus and panels transparent like the terminal | T52 | done | verified on PC r25 | |
| r25-x2 | Docs updated for the bar: design system, README, guide | T09 | done | redone for kami (r26-21); design system rewritten r27-9 | |

## r26: his round of 21 Oct 21:41 to 22 Oct 02:10, and the unnumbered follow-ups of 24 and 25 Oct

| id | request | task | status | proof | flag |
|---|---|---|---|---|---|
| r26-1 | Bar: more stitches, stitching exact to the pixel | T14 | dropped | superseded by kami (r26-20); old bar measured on kit and PC | |
| r26-2 | Bar: music visualiser wings either side of the clock | T14 | done | kit; red wings measured r27-14b; live not recorded | |
| r26-3 | Bar: workspaces not the launcher's orange | T14 | done | verified r26; r27-14a stamp measured on the bar | |
| r26-4 | Bar: stitch-separate the right-hand icons | T14 | dropped | superseded by kami tiles (r26-20) | |
| r26-5 | Bar: middle colours (warm grey, date, kanji, strong time) | T14 | dropped | superseded by kami colours (r26-20) and the r27 palette | |
| r26-6 | Animations: frame-driven, eased, 220 ms | T19 | dropped | superseded by the r27 dissolve motion (r27-dec-1a) | |
| r26-7a | Many terminals opened fast: no duplicate headings (= r24-8a) | T24, T52 | done | 0/17 duplicates (was 40%); test_tiles 142/0 (r27) | |
| r26-7b | Prompt: full drastic rework | T24 | dropped | superseded by r26-24, then the r27 pastel-powerline prompt | |
| r26-8 | Busy cursor after unlock | T52 | done | none recorded; needs the owner's unlock to confirm | UNPROVEN |
| r26-9 | Design consistency upgrade across menus, lock, saver | T09, T17 | dropped | superseded by the r27 design system and audit | |
| r26-10 | Screensaver: no delay on key exit; design upgrade (= r24-24a) | T20 | wip | VERIFIED r26 (110 ms lock); owner still sees delay (r27-bug-1) | STALE |
| r26-11 | Full sweep of history, 0% issues, script TUI visuals, guide on GitHub | T52, T59 | wip | open ("WIP: this ledger") | |
| r26-12a | Integrate with the PC: ssh survives update, repair, reboot; keys only | T39 | wip | s_ssh writes keys-only drop-in; PC state not rechecked | |
| r26-12b | Trim leftovers and garbage from the PC | T42, T62 | todo | none recorded; list kept in the ledger | |
| r26-13 | Installer: a fully clean run, no failures or warnings | T54 | done | fresh VM verify 251 + 4 named skips; PC 257/258 | |
| r26-14 | Screen tearing: desktop not vsynced? | T38 | done | diagnosed on PC (vsynced flips); fix built, deployment unverified | UNPROVEN |
| r26-15 | Tearing during open, close and workspace change | T19 | dropped | superseded by r27 dissolve (no hard edge sweeping) | |
| r26-16 | Bar classier, subtler stitching; clock must not look stitched | T14 | dropped | superseded by kami (r26-20) | |
| r26-17 | Three drastic bar variants (tabi, noren, sumi) | T14 | done | mocked; resolved by owner's pick of kami (r26-20) | |
| r26-18 | More retro, old-Japanese bar options (cartouche, senjafuda, chochin) | T14 | done | mocked; resolved by owner's pick of kami (r26-20) | |
| r26-19 | More elegant options surviving any wallpaper (urushi, kami, hinoki) | T14 | done | mocked on 8 wallpapers; owner picked kami | |
| r26-20 | Kami bar: symmetry, spacing, centring, distinct dark and light, flair | T14 | done | kit and PC measured gaps 8/8, 4/10, 6 (r26-22) | |
| r26-21 | Docs for the kami bar: design system, README, guide, Learn | T09 | done | docs updated (ledger line); design system rewritten r27-9 | |
| r26-22 | Bar alignment and contrast; prompt cursor gap | T14 | done | kit and PC measured: 8/8, 4/10, 6 | |
| r26-23 | Lock screen consistent with the bar | T20 | dropped | superseded by the r27 lock redesign (r27-dec-4a) | |
| r26-24 | Prompt: one short line (torii, folder, branch, code, took) | T24 | dropped | superseded by the r27 pastel-powerline prompt (r27-dec-6a) | |
| r26-25 | Bar to the pixel: clean seal ellipse, padded text tiles | T14 | done | kit seal centre 15.5/15, tiles 8/8; re-measured at 27 rows | |
| r26-26 | Fullscreen game black after workspace switch | T35 | dropped | VERIFIED r26 on PC; game leaves host (gaming VM decision) | |
| r26-fu-1 | Letter spacing: every letter, digit, symbol keeps its last column free | T10 | dropped | superseded by r27 faces (r27-fonts-1): 2340 glyphs keep air | |
| r26-fu-2 | Percent sign drawn by hand | T10 | dropped | superseded by the r27 face's hand-drawn signs (r27-10a) | |
| r26-fu-3 | Joystick and sun icons better; joystick animated | T35 | dropped | joystick: gaming VM decision; sun and bulb redrawn r27-10b | |
| r26-fu-4 | Bar must not grow with Arabic, emoji or Thai titles | T14, T52 | wip | headless r26: 31 px always; r27 27-row check with Arabic not recorded | |
| r26-fu-5 | Boot splash shown three times (= r24-2) | T41, T59 | done | journal: splash on amdgpu only; owner to confirm visually | |
| r26-fu-6 | Saver to lock after screens dark: frozen, then cut (= r24-24a) | T20 | wip | headless fix verified (wlopm off 20 s); owner still saw it | STALE |
| r26-fu-7 | Layout stalls of 250 ms cut to 60 ms | T52 | done | dwl watchdog: never blocked 20 ms in 1000 random actions | |
| r26-fu-8 | Ink-bleed theme wash, owner wants 1.2 s, was 720 ms (= r24-7) | T19 | done | wash.sh 1204.6 ms over 199 frames | |

## r27, his decisions of 25 Oct (CLAUDE.md "His decisions"; asked 18:30)

| id | request | task | status | proof | flag |
|---|---|---|---|---|---|
| r27-dec-1a | Window open and close in playful pixel style, 400-450 ms | T19 | done | anim-check: open 420.0, close 400.0 on shipped dwl; live shots | |
| r27-dec-1b | Workspace switch in playful pixel style, 400-450 ms | T19 | done | anim-check out 280.0, in 420.0; live burst 362 shots | |
| r27-dec-1c | Menus, Super+N and similar popups animated anew | T19 | done | headless: menus ~200/160 ms, notice ~240/200; warm unroll built; no live look | |
| r27-dec-1d | Lock to desktop animation redone | T19, T20 | wip | built in dwl (lock leaves in 420 ms); no run recorded | |
| r27-dec-1e | First login after boot (greeter to session) gets an animation | T19 | todo | none recorded; handover is T19's next step | |
| r27-dec-1f | Wallpaper and theme ink wash lasts 1.2 s | T19 | done | wash.sh 199 frames over 1204.6 ms; shipped dwl 1200.0 | |
| r27-dec-2a | UI font 16 to 14 px; width tables rebuilt | T10 | done | applied live; 0 ASCII pairs touching; verify 0 problems | |
| r27-dec-2b | Terminal font 20 to 16 px; everything re-aligned | T11 | done | foot cell 8x20, capitals rows 4-15 measured; verify FONT checks | |
| r27-dec-3a | Workspace stamps: black numeral, small, fully inside the red circle, 1-9 | T14 | done | bar-geometry: seal x 60-75, numeral inside, 5 px paper each side | |
| r27-dec-3b | Kanji only on stamps, lock quote, day seal; pixel icons elsewhere | T16 | done | grep-tested; test_notices allows no kanji; shots both themes | |
| r27-dec-4a | Lock screen: new art, no date, time or power buttons | T20 | todo | none recorded | |
| r27-dec-4b | Password typed inside a demon's mouth (dark) or an angel (light) | T20 | todo | none recorded | |
| r27-dec-4c | Two retro torches and a dungeon feel on the lock | T20 | todo | none recorded | |
| r27-dec-4d | One Japanese quote, no translation, display lettering; you pick it | T20 | wip | quotes chosen r27-9, dictionary-checked; not yet on the lock | |
| r27-dec-4e | Art as pixel versions of public-domain old masters (Kuniyoshi, Hokusai, Buddhist angels) | T18 | wip | build-masters.py built; 14 demons and 14 angels sourced, licences checked | |
| r27-dec-4f | About 10 demon wallpapers (dark) and 10 angel wallpapers (light) | T18 | todo | pipeline and sources only; none of the 20 made | |
| r27-dec-4g | Bar's far-right icon: demon (dark) or angel (light) | T18, T19k-4 | done | live grim: hannya 7/8 px across, 1/1 above and below | |
| r27-dec-4h | Fetch art: the mood's demon or angel | T18 | done | test_fetch 98/0; no render recorded | |
| r27-dec-5 | Yazi: keep the engine, rebuild the whole UI, contrast, many sizes | T22 | todo | none recorded | |
| r27-dec-6a | Prompt rebuilt in pastel-powerline style with the terminal icon | T24 | todo | none recorded | |
| r27-dec-6b | Wada palette informs the whole design system | T08 | done | every text role at least 4.5:1; live shots both themes | |
| r27-dec-7 | Theme switch animates the mouse cursor too | T19 | done | wash.sh: cursor loaded once between go and end | |
| r27-dec-8 | Wallpaper 4-hour auto-change toggle key inside Super+W, at the bottom | T16 | done | r toggles, state on last line; shots both themes | |
| r27-dec-9a | Full chess TUI app: board, play, review, lessons, puzzles, progress | T25b | todo | none recorded | |
| r27-dec-9b | Chess takes him from zero to 1800 chess.com rapid in a year | T25a, T25b | todo | none recorded | |
| r27-dec-9c | 730 games (two a day) against built-in Stockfish at lesson-matched levels | T25a, T25b | todo | none recorded | |
| r27-dec-9d | About 10 minutes of puzzles a day | T25b | todo | none recorded | |
| r27-dec-9e | Study chess.com and beginner teaching; argue with yourself, stay minimal | T25a | todo | none recorded | |
| r27-dec-9f | Chess visuals: pixel board, custom pieces, move animation, last move, hints | T25b | todo | none recorded | |
| r27-dec-9g | Chess tested to destruction: screens, keys, sizes, themes, resume after reboot | T25c | todo | none recorded | |
| r27-dec-9h | Chess grounded in cited sources (Steps, Yusupov, Heisman, Silman, Polgar) | T25a | todo | none recorded | |
| r27-dec-10a | Full typing TUI app modelled on EdClub and TypingClub | T26a, T26b | todo | none recorded | |
| r27-dec-10b | Typing: English, 100+ WPM target, proper speed and accuracy measurement | T26a, T26b | todo | none recorded | |
| r27-dec-10c | Typing visuals: on-screen keyboard, finger per next key, hands, errors shown | T26b | todo | none recorded | |
| r27-dec-10d | Typing tested to destruction; research cited (keybr, Ericsson, Monkeytype) | T26a, T26c | todo | none recorded | |
| r27-dec-11a | Learning section in Super+U beside the Learn pieces, chess and typing | T12, T27 | wip | tab built r27-12 (entries "soon"); pieces not cut | |
| r27-dec-11b | Learn book cut into ordered lessons: lesson n of N, done mark | T27 | todo | none recorded | |
| r27-dec-11c | Delete the old Guide PDF, its build, every menu entry and test | T27 | todo | none recorded | |
| r27-dec-12a | FireAlpaca official Linux build: launcher entry, XP-Pen with pressure | T28 | todo | none recorded | |
| r27-dec-12b | Prove FireAlpaca's upsides over Xournal++ first | T28 | todo | none recorded | |
| r27-dec-12c | FireAlpaca guide in the Learn book | T28, T63 | todo | none recorded | |
| r27-dec-12d | FireAlpaca themed to the limit, minimal panels, both themes | T28 | todo | none recorded | |
| r27-dec-13a | RGB software for the darkFlash case fans and hub | T36 | todo | none recorded | |
| r27-dec-13b | RGB software for the Jungle Leopard cooler, including its display | T36, T37 | todo | none recorded | |
| r27-dec-13c | RGB for the Gigabyte 9060 XT logo | T36 | todo | none recorded | |
| r27-dec-14 | Repo cleaned; handoff written | T42, T53 | wip | handoff commit 692d962 (git); cleanup not in ledger | |

## r27, bugs to fix (CLAUDE.md 1 to 17; verify each on the PC)

| id | request | task | status | proof | flag |
|---|---|---|---|---|---|
| r27-bug-1 | Saver to lock after long absence: frozen picture, then a sudden cut | T20 | wip | headless fix verified; real long-absence reproduction not done | |
| r27-bug-2a | Notes: black areas around the text while typing | T21 | todo | none recorded | |
| r27-bug-2b | Notes: flicker on save | T21 | todo | none recorded | |
| r27-bug-2c | Notes: spacing between header and first line | T21 | todo | none recorded | |
| r27-bug-2d | Notes redesigned as a vertical lined notebook | T21 | todo | none recorded | |
| r27-bug-2e | Notes: margins constant while scrolling | T21 | todo | none recorded | |
| r27-bug-3 | Bar dropdown rows inactive until first click, fixed for good | T13 | done | kit: row lit at open, first click pages; menu-first-click.sh | |
| r27-bug-4a | Lock: blinking cursor sometimes missing | T20 | todo | none recorded | |
| r27-bug-4b | Lock: wrong password takes long to report; make it fast | T20 | todo | none recorded | |
| r27-bug-5 | Wallpaper change: a black box flashes first | T19 | done | wash.sh both themes: only old, new, rim ink; picker keeps page | |
| r27-bug-6a | Flicker on notes save (= r27-bug-2b) | T21 | todo | none recorded | |
| r27-bug-6b | Flicker when typing launcher calculations or conversions | T16 | done | answer row stays in place; shots 36 to 408; test_calc 29/0 | |
| r27-bug-6c | Clipboard exit flashes "terminated" in white text | T16 | done | warm-exit.sh holds, installed build fails; shots of Esc and Enter | |
| r27-bug-7 | Super+C calendar opens centred under the date | T13 | done | calendar-middle.sh: frame centre x 959.5 = bar middle | |
| r27-bug-8 | Only one menu or popup open at a time, every combination | T13 | done | one-popup.sh: 90 ordered pairs, one popup each | |
| r27-bug-9 | Popups such as Super+V visible over fullscreen windows | T19 | done | headless: Super+V over fullscreen terminal shows; Esc returns | |
| r27-bug-10 | Locked PDFs: password prompt; wrong password says so in place | T22 | todo | none recorded | |
| r27-bug-11 | .rar files in yazi error; use unrar | T22 | todo | none recorded | |
| r27-bug-12a | Torrents slow; "failed to resolve" when starting a download | T29 | todo | causes found (Prowlarr DNS/IPv6, Cloudflare); no fix recorded | |
| r27-bug-12b | Notice every time torrents opens for finished downloads | T29 | todo | none recorded | |
| r27-bug-12c | Stress and measure the torrents app | T29 | todo | none recorded | |
| r27-bug-13a | Brave download shows no percent progress | T31 | todo | none recorded | |
| r27-bug-13b | Odd link icon in the download notice | T31 | todo | none recorded | |
| r27-bug-14 | Steam may think it is a Steam Deck | T35 | dropped | superseded: Steam leaves the host (gaming VM decision) | |
| r27-bug-15 | Super+U headings too close to their first item | T12 | done | kit shots both themes; blank row under heading; test_menu 555/0 | |
| r27-bug-16 | Super+R books: tear down and redo alignment and spacing | T16 | done | six books shot both themes; test_books; meter in pixels | |
| r27-bug-17 | Dashed separator lines in TUIs removed; spacing refined | T16 | done | grep-tested, no dashed rule left; shots both themes | |

## r27, bar redesign (CLAUDE.md "Bar redesign")

| id | request | task | status | proof | flag |
|---|---|---|---|---|---|
| r27-bar-1 | Bar height 27 px | T14 | done | bar-geometry.sh rows 0+3, 3+1, 4+20, 24+1, 25+1, 26+1; live border rows 33-34 | |
| r27-bar-2 | No inner cream second frame on any cell, red end buttons included | T14 | done | one frame per tile; gaps 8/8 measured both themes | |
| r27-bar-3 | Active window title lighter in weight | T14 | done | Sumi UI is one weight of 1 px strokes; checked in shots | |
| r27-bar-4 | Date DD/MM/YYYY with a custom red pixel slash | T14 | done | clock measured 15,14,14,8 px; slash a new sign, red | |
| r27-bar-5 | US in red, AR in blue, clickable | T14 | done | live: click gives AR blue, again US; test_tag 78/0 | |
| r27-bar-6 | Red separator between video title and channel or episode | T14 | done | test_nowplaying 204/0 rewritten for the label; rule not itemised | |
| r27-bar-7 | Audio visualizer in our red | T14 | done | wings fed through fifos, gaps 15,14,14,14,15,8; test_configs | |
| r27-bar-8 | DND bar icon opens a small DND-only menu | T13 | done | live: timed quiet ended by its timer; test_quick 361/0 | |
| r27-bar-9 | Steam tooltip show or hide; click brings it to this workspace | T35 | dropped | superseded: gaming VM decision | |
| r27-bar-10 | Retro antenna TV icon animates while a video plays | T14 | done | test_nowplaying 204/0; frame timing not recorded | |
| r27-bar-11 | Joystick icon moves while Steam runs | T35 | dropped | superseded: gaming VM decision | |
| r27-bar-12 | Downloads icon animates while downloading | T14 | done | six frames in order, 125.0 ms apart; test_downloads 52/0 | |
| r27-bar-13 | Weather sunny icon different from the brightness icon | T14, T19k-4 | done | nine skies kit; live moon 8,14,8,8 px; test_weather 229/0 | |
| r27-bar-14 | Window borders get the bar's 3D shadow look | T15 | done | window-frame.sh both themes; live frame colour 362/362 | |
| r27-bar-15 | Volume and brightness sliders alive, turning red when high | T13, T15 | done | segments read back at 42/50/85/100%; level-display.sh | |
| r27-bar-16 | Re-measure spacing, alignment, fit: every icon, section, window gap | T14, T19m | done | every tile 8/8 px paper to ink; audit pass is T19m | |

## r27, added 18:48

| id | request | task | status | proof | flag |
|---|---|---|---|---|---|
| r27-1848-1 | To-do list beside the notes and in Super+U: boxes, done struck through | T21 | done | test_notes 115/0, test_menu 589/0; kit both moods; not live yet | |
| r27-1848-2 | Design coherence pass: one colour use, frame and spacing grammar | T17 | done | gallery: 27 surfaces both themes, same box; --check held twice | |
| r27-1848-3 | Performance baseline: numbers before, measured inside dwl | T04 | done | perf-before.md: 0 dropped in 65 streaks; boot 20.4 s | |
| r27-1848-4 | End-of-round performance test, numbers before and after | T60 | todo | none recorded | |

## r27, everything trickles into the installer (19:45)

| id | request | task | status | proof | flag |
|---|---|---|---|---|---|
| r27-inst-1 | Every change made by setup/theme/apply from clean Fedora, VM-proven | T54 | wip | fresh VM run verify 251 + 4 skips (r27-5); rerun owed | |
| r27-inst-2 | Use kernel 7.2 and Fedora 44 features, each change measured | T41 | todo | none recorded | |
| r27-inst-3 | Neovim faster start-up and editing; cut costly plugins | T30 | todo | baseline only: nvim to VeryLazy 148 ms (r27-4) | |
| r27-inst-4 | Harden the repo: dead code, lib/ folding, ShellCheck, selftest clean | T53 | todo | none recorded | |

## r27, update system (19:51 update-proof, 19:56 self-maintaining, 20:00 AI fixer, 20:05 FINAL, 20:11 bulletproof)

| id | request | task | status | proof | flag |
|---|---|---|---|---|---|
| r27-upd-1 | Snapshot, update, verify, automatic rollback with a clear notice | T45 | todo | none recorded | |
| r27-upd-2 | Pin or validate what breaks between versions (yazi, waybar, foot, mako, gtklock) | T45, T30 | wip | mako pinned by tag and commit (r27-15b); rest not yet | |
| r27-upd-3 | Theme-owned configs kept apart from his settings (conf, secrets, local) | T54 | todo | none recorded | |
| r27-upd-4 | Prove in the VM: pending updates and next release; repeatable tools/ test | T46, T49 | todo | none recorded | |
| r27-upd-5 | Hold the culprit: bisect, versionlock, weekly retry, security notice | T45 | todo | none recorded | |
| r27-upd-6 | Release upgrades pre-flighted in a VM; red VM stays; EOL warning | T46 | todo | none recorded | |
| r27-upd-7 | Short report after each update run; he never has to step in | T45 | todo | none recorded | |
| r27-upd-8 | Local AI fixer on the 16 GB RX 9060 XT: required, offline | T47 | todo | none recorded | |
| r27-upd-9 | Fixer proven in the VM with graded breakages; unfixable ends held and told | T47, T49 | todo | none recorded | |
| r27-upd-10 | One Super+U update item does everything A to Z; he never runs dnf | T45 | todo | entry exists as "soon" (r27-12) | |
| r27-upd-11 | Release upgrades run through the same update button | T46 | todo | none recorded | |
| r27-upd-12 | No background auto-updates; quiet notice after 2 weeks or near EOL | T45, T46 | todo | none recorded | |
| r27-upd-13 | Snapshots, backups, rollback, Btrfs: one clear model, from Super+U | T48 | todo | none recorded | |
| r27-upd-14 | Whole-system rollback from the boot menu even if the desktop will not start | T48 | todo | none recorded | |
| r27-upd-15 | Restore single files; backup-drive flow; scrub and space checks | T48 | todo | none recorded | |
| r27-upd-16 | Learning piece: update steps, fixer limits, snapshots against backups, rollback | T50 | todo | none recorded | |
| r27-upd-17 | Update research: 300+ sources logged in update-research.md | T43 | todo | none recorded | |
| r27-upd-18 | Written update design: every failure mode, skeptic pass, /boot outside Btrfs | T44 | todo | none recorded | |
| r27-upd-19 | Inject every failure in the VM (power cut, disk full, bad boot) | T49 | todo | none recorded | |

## r27, the installer ISO (20:17)

| id | request | task | status | proof | flag |
|---|---|---|---|---|---|
| r27-iso-1 | Research Omarchy's ISO, Kickstart, mkksiso, lorax, Anaconda text mode, Secure Boot | T55 | todo | none recorded | |
| r27-iso-2 | One bootable ISO installs the newest stable Fedora and the whole system | T56 | todo | none recorded | |
| r27-iso-3 | Bare-minimum questions on our themed first screen; nothing asked twice | T56 | todo | none recorded | |
| r27-iso-4 | Kickstart base install (UEFI, GPT, Btrfs); setup runs unattended through reboots | T56 | todo | none recorded | |
| r27-iso-5 | Refuse a too-small disk or no network with a clear message | T56, T57 | todo | none recorded | |
| r27-iso-6 | ISO proven end to end in the VM: wiped disks, slow network, pulled reboot | T57 | todo | none recorded | |
| r27-iso-7 | ISO build reproducible through tools/build-iso.sh | T56 | todo | none recorded | |
| r27-iso-8 | ISO and checksum published in a GitHub release | T57 | todo | none recorded | |
| r27-iso-9 | Never run the ISO on his real disk | T57 | wip | standing rule; no ISO exists yet | |
| r27-iso-10 | ISO fully themed: boot menu, splash, questions, progress, every message | T56 | todo | none recorded | |

## r27, fonts (26 Oct 00:46; replaces the Sumi faces)

| id | request | task | status | proof | flag |
|---|---|---|---|---|---|
| r27-fonts-1 | UI face: Japanese-retro, readable, no letter-spacing problem at all | T07, T10 | done | 33 families measured; 0 ASCII pairs touching; owner likes it (14:27) | |
| r27-fonts-2 | Terminal font: coding grade, Nerd glyphs, Japanese, tuned for 1080p | T07, T11 | done | UDEV Gothic NF 16 px, cell 8x20 measured; font pins in verify | |
| r27-fonts-3 | Sizes a little smaller than today, more on screen | T10, T11 | done | cell 8x20 measured; design: 51 rows full height (was 43) | |
| r27-fonts-4 | Rework width tables, icon sizes and layouts; icon font keeps working | T10, T11 | done | air tables regenerated; icons redrawn pixel-exact; verify 0 problems | |

## r27, RGB (00:46)

| id | request | task | status | proof | flag |
|---|---|---|---|---|---|
| r27-rgb-1 | Every light in our red palette with one slow, synced motion | T36 | todo | none recorded | |
| r27-rgb-2 | RGB follows dark and light if it looks good | T36 | todo | none recorded | |
| r27-rgb-3 | Redragon K617 Fizz: OpenRGB or own driver, restored at boot and resume | T36 | todo | none recorded | |

## r27, monitor LG 24G411A-B (00:46)

| id | request | task | status | proof | flag |
|---|---|---|---|---|---|
| r27-mon-1 | Prove FreeSync/VRR really works (EDID range, vrr_capable, refresh varies) | T38 | todo | none recorded | |
| r27-mon-2 | Optimised colour profile from research on this exact panel | T38 | todo | none recorded | |
| r27-mon-3 | Set the monitor's own menu over DDC/CI; re-apply at boot and wake | T38 | todo | none recorded | |
| r27-mon-4 | Correct LUT through dwl's gamma path if measured to help | T38 | todo | none recorded | |
| r27-mon-5 | Learn piece explains what was set and why | T38 | todo | none recorded | |

## r27, never again (01:48), network security (01:48), lock screens off (01:48)

| id | request | task | status | proof | flag |
|---|---|---|---|---|---|
| r27-never-1 | Every ledger item r24 to r27 becomes an automated regression check | T52 | wip | nine tools/regress scripts exist; the item list is not built | |
| r27-never-2 | Run all regression checks before every push and at the end | T52, T61 | todo | none recorded | |
| r27-never-3 | Keep the checks in the installer's selftest | T52 | todo | none recorded | |
| r27-net-1 | firewalld default-deny inbound; only needed services, LAN-only | T39 | todo | none recorded | |
| r27-net-2 | sshd keys-only or off | T39 | wip | keys-only drop-in written by setup (r26-12); PC state not rechecked | |
| r27-net-3 | Every local service bound to localhost or LAN only | T39 | todo | none recorded | |
| r27-net-4 | Network sysctls, IPv6 parity, no UPnP, DNS privacy if free | T39 | todo | none recorded | |
| r27-net-5 | Verify by port scan from another machine; add checks to verify | T39 | todo | none recorded | |
| r27-lock5-1 | Lock idle 5 s turns the monitors off; any key lights them onto the lock | T20 | todo | none recorded | |

## r27, reported 26 Oct 14:07 (fix first)

| id | request | task | status | proof | flag |
|---|---|---|---|---|---|
| r27-rep-1 | Find the cause of the random restart from the evidence | T01 | done | coredump: SIGSEGV in configurex11, NULL mon; hotplug-test reproduces it | |
| r27-rep-2 | Fix the cause of the restart | T01 | done | dwl NULL-safe; hotplug-test 12/12; live unplug, 40 resizes | |
| r27-rep-3a | Catch it next time: pstore, persistent journal, coredumps, crash notice | T01b, T41 | wip | crashnote 11 tests; efi_pstore waits for T41's reboot | STALE |
| r27-rep-3b | Stress test that reproduces the restart | T01 | done | tools/hotplug-test.sh: old dwl segfaults at check 1 | |
| r27-rep-4a | Monitor on lands on workspace 1: keep each output's state | T02 | done | live: workspace 3 kept over real unplug; 5 cycles tags, layout, focus | |
| r27-rep-4b | Test with real monitor power cycle and DPMS; add regression check | T02 | done | DPMS off 90 s, key lit it; test_hotplug.sh; button itself untested | |
| r27-rep-5a | Perfectly clean system: no strays in $HOME, /etc, /usr/local, /opt, /var | T42 | todo | none recorded | |
| r27-rep-5b | One clear layout for what fedokawaii installs, documented in Learning | T42 | todo | none recorded | |
| r27-rep-5c | Installer and update keep it clean; a verify check finds strays | T42 | todo | none recorded | |

## r27, more from 26/27 Oct

| id | request | task | status | proof | flag |
|---|---|---|---|---|---|
| r27-more-1 | Torrents app: full visual overhaul in the new design | T29 | todo | none recorded | |
| r27-more-2 | Torrents: far more robust; huge lists, many torrents, slow indexers | T29 | todo | none recorded | |
| r27-more-3 | Torrents: layouts adapt from narrow tile to fullscreen, nothing cut | T29 | todo | none recorded | |
| r27-more-4 | Quick settings: every item unique, all centred and aligned to the pixel | T13, T17b, T19k-7 | wip | crests, mon sheet, dial (1 Nov) measured; owner verdict pending | STALE |
| r27-more-5 | Yazi: hidden files always shown, file manager and picker | T22 | todo | none recorded | |
| r27-more-6 | Prowlarr: clear the warning shown inside it | T29 | todo | findings only (Cloudflare, Allowed Hosts); no fix recorded | |

## r27, gaming moves into a Windows VM (27 Oct)

| id | request | task | status | proof | flag |
|---|---|---|---|---|---|
| r27-vm-1 | Drop every earlier Steam item (bar icon, joystick, Deck check) | T14, T35 | wip | bar's Steam tile gone (r27-14a); host pieces remain until T35 | |
| r27-vm-2 | Remove Steam, kawa-steam, GE-Proton, gamescope, MangoHud, game mode from the host | T35 | todo | none recorded; kawa-steam --watch kept until T35 | |
| r27-vm-3 | Host becomes a clean non-gaming system: configs, caches, units, repos, docs | T35 | todo | none recorded | |
| r27-vm-4 | Keep ~/blasphemous-save-backup-20261022 (move into the VM import folder later) | T35 | wip | restored from Trash 27 Oct, intact (476 K); move waits for T35 | |
| r27-vm-5a | Windows gaming VM with GPU passthrough: Steam, CS2, qBittorrent inside | T33, T34 | todo | none recorded | |
| r27-vm-5b | His controller passed through to the VM by USB | T33, T34 | todo | none recorded | |
| r27-vm-6 | One self-contained folder holds the whole VM; deleting it leaves no trace | T33 | todo | none recorded | |
| r27-vm-7 | Windows made minimal, fast, light, tuned for gaming latency | T33 | todo | none recorded | |
| r27-vm-8 | Windows set up unattended: autounattend, AMD and virtio drivers, apps | T33 | todo | none recorded | |
| r27-vm-9 | Deep research first: RDNA4 reset, IOMMU, pinning, hugepages, whether CS2 and VAC tolerate a VM | T32 | todo | none recorded | |
| r27-vm-10 | One monitor, one dGPU: host on the iGPU; DDC input switch or Looking Glass | T32, T33, T34 | todo | none recorded | |
| r27-vm-11 | dGPU bound to vfio-pci only while the VM runs, back afterwards if reset allows | T32, T33 | todo | none recorded | |
| r27-vm-12 | TUI app for the VM: start/stop, display switch, controller, state, launcher entry | T34 | todo | none recorded | |
| r27-vm-13 | Test the VM app hard (loops, host suspend, crash, hotplug); optimise VM frame times | T34, T33 | todo | none recorded | |
| r27-vm-14 | Tell him early, once, what he must do physically (BIOS, second cable) | T06 | done | notice shown live (shot), at login and Super+U status; test_foryou 15 | |

## r27, one design, one unit (20:08), and release upgrades

| id | request | task | status | proof | flag |
|---|---|---|---|---|---|
| r27-one-1 | Super+U fully redesigned: structure, sections, states, spacing, art | T12 | done | five tabs; px.py measured both themes; live tab row checked | |
| r27-one-2 | Every menu, popup, notice, OSD and TUI redesigned to match | T13, T15, T16, T17, T21, T22, T23, T29 | wip | gallery 27 surfaces same box; notes, yazi, Super+/, torrents pending | |
| r27-one-3 | Lock, greeter and saver brought to the same grammar | T20 | todo | none recorded | |
| r27-one-4 | design-system.md written first as the single truth | T09 | done | test_design_doc 54/0, mutation-tested | |
| r27-one-5 | Audit surfaces side by side in both themes until indistinguishable (= r27-1848-2) | T17, T19m | done | gallery --check held twice; full audit is T19m | |
| r27-one-6 | Learning piece honest that a big release may exceed the local model | T46, T50 | todo | none recorded | |

## r27, also

| id | request | task | status | proof | flag |
|---|---|---|---|---|---|
| r27-also-1 | RAM caching of apps: preload aggressively, measured | T40 | todo | none recorded | |
| r27-also-2 | Super+/ comprehensive, fuzzy, shows the active TUI app's keys first | T23 | todo | none recorded | |
| r27-also-3 | Performance and visual bug hunt everywhere | T59, T60 | todo | none recorded | |

## r27, how the round is run and finished (deliverables only)

| id | request | task | status | proof | flag |
|---|---|---|---|---|---|
| r27-run-1 | Planner (Fable, max) writes plan.md; critique it hard | plan | done | plan.md written 27 Oct, critiqued and amended (5221118) | |
| r27-run-2 | After the plan: research round of official docs for everything touched | T58 | todo | none recorded | |
| r27-run-3 | Maniac testing: reboots, cold power-off test last (rtcwake) | T59 | todo | none recorded | |
| r27-run-4 | Rigorous performance test; fix everything found (= r27-1848-4) | T60 | todo | none recorded | |
| r27-run-5 | Full test suite and verify, then push | T61 | todo | none recorded | |
| r27-run-6 | Finish: stop inhibitor, remove sudoers rule, summary at ledger top, DONE | T62 | todo | none recorded | |
| r27-run-7 | Learn book: clear code snippets, comprehensive, updated with all changes on his word | T63 | todo | none recorded | |
| r27-run-8 | Idle inhibitor runs for the whole round | conv | wip | r27-inhibit active (ledger r27-event); standing | |
| r27-run-9 | Commit and push after every task; ledger updated after each | conv | wip | pushing works since 27 Oct 18:18 (r27-0) | |
| r27-run-10 | Main agent keeps design work; subagents only for fenced grunt, one at a time | conv | wip | subagent results reviewed here (r27-14b, r27-17b, r27-19k-7) | |
| r27-run-11 | Design as an artwork: render, measure and grill every visual change | T19m | wip | grill-r27.md; frame-by-frame anim-check; both themes | |
| r27-run-12 | Learn book stays correct after every change | conv, T63 | wip | pieces corrected per change (r27-13b, 19, inbox 00:10); no full check | |

## r27, added 26 Oct 27 14:27 and 14:29

| id | request | task | status | proof | flag |
|---|---|---|---|---|---|
| r27-1427-1 | Bar UI font: he likes it now; switch only if clearly better | T58 | wip | owner likes it (14:27); T58 check once, not yet run | |
| r27-1427-2 | Remove "clean mic" (mic noise suppression) completely | T17b | done | subagent work reviewed; report rows removed; no live check recorded | UNPROVEN |
| r27-1427-3a | Replace Brave: survey less common Chromium-based browsers from official sources | T31a | todo | none recorded | |
| r27-1427-3b | Try the top candidates on this PC; pick the best by numbers | T31a | todo | none recorded | |
| r27-1427-3c | Migrate bookmarks, logins, settings, extensions from Brave | T31a | todo | none recorded | |
| r27-1427-3d | Theme the new browser to our design, both themes | T31a | todo | none recorded | |
| r27-1427-4 | Quick-settings button to switch the monitor off | T17b | done | shot both themes only; screen-off run not recorded | UNPROVEN |
| r27-1427-5 | Torrents: copy a torrent's magnet link | T29 | todo | none recorded | |
| r27-1427-6 | Torrents: stream a video immediately while it downloads | T29 | todo | none recorded | |
| r27-1427-7 | Fix copy and paste problems everywhere; find and reproduce first | T17c | wip | two found and fixed (copies over 5 MB, editor); browser waits T31a | |
| r27-1427-8 | Bar US/AR: capitals while Caps Lock is on, lowercase off, live | T17b | done | kit tile measured small letters; Caps Lock toggle not recorded | UNPROVEN |
| r27-1427-9 | Strong design love for quick settings: a proper, beautiful menu | T17b, T19k-7 | wip | crests r27-17b, mon sheet, dial 1 Nov; owner verdict pending | STALE |

## r27, added 27 Oct 19:19 (high priority)

| id | request | task | status | proof | flag |
|---|---|---|---|---|---|
| r27-1919-1 | Demon and angel head icons far too simple: make them serious, detailed | T19k-4 | done | live grim: faces 7/8 px across, 1/1 above, below | |
| r27-1919-2 | Every custom icon more alive, unique, complex | T19k-4 | done | 16 crests, 9 skies, section icons: kit and live measured | |
| r27-1919-3 | Bar flickers on rapid workspace switches: fix, add regression check | T19k-1 | done | live burst 362 shots: 0 pops, 0 colour changes; bar-burst.sh | |
| r27-1919-4 | A proper icon for the to-do list | T19k-5 | done | tanzaku in Super+U, kit both themes 8x crop; test_menu 589/0 | |
| r27-1919-5 | Quick settings still poor: redesign properly (third time) | T19k-3, T19k-7 | wip | mon sheet built r27-19k-3; owner reopened 23:23; dial wip | STALE |
| r27-1919-6 | Highlight contrast: WCAG-measure every selected state, fix low ones | T19k-2, T22 | wip | 48 pairs, 0 under; lazygit 4.15:1 open; yazi row pending | STALE |
| r27-1919-7 | Always measure alignment and spacing precisely, every surface, every change | T19k-6, T19m | wip | standing; px.py used in every ledger line | |

## r27, standing rules of 31 Oct, and a note recorded only in the ledger

| id | request | task | status | proof | flag |
|---|---|---|---|---|---|
| r27-rule-1 | Read inbox.md every pass; rewrite entries into the plan and mark them | T19n | wip | entries 23:47 to 00:11 mapped (r27-inbox, d1688a3) | |
| r27-rule-2 | Keep his remote page (fk-remote, port 8737, LAN only) working through every change | UNPLANNED | wip | none recorded; no plan task or ledger line names it | UNPLANNED |
| r27-led-2323 | Quick settings from scratch: drop the mon sheet, super minimal, super creative | T19k-7 | wip | dial live 1 Nov, measured; test_panel 613/0; verdict pending | |

## The inbox (raw requests of 31 Oct 23:47 to 1 Nov 00:11)

| id | request | task | status | proof | flag |
|---|---|---|---|---|---|
| r27-inbox-2347 | Everything aligned, spaced, proportional, symmetrical, OCD level | T19m | todo | none recorded | |
| r27-inbox-2352a | 100+ sources (Japanese masters, UX books) for alignment, sizes, contrast | T19m | todo | none recorded | |
| r27-inbox-2352b | Look at everything at least three times; grill yourself; really look | T19m | todo | none recorded | |
| r27-inbox-2355a | Avoid over-engineered code: intentional, fast, clean, checked against standards | T53 | todo | none recorded | |
| r27-inbox-2355b | Final ISO on Fedora 45 (out 3 Nov); leverage it fully | T56, T46 | todo | none recorded | |
| r27-inbox-2355c | Optimise and harden the system intensely for Fedora 45 | T41 | todo | none recorded | |
| r27-inbox-2356 | Hire a master: a source of truth that nothing was missed | T19n | wip | this trace written; reviewer gate not yet running | |
| r27-inbox-0011 | Custom beautiful progress bar inside the downloads icon, any source | T31 | wip | kit: fill drawn at 5/25/62/99/100% (r27-31a); sources unproven | |

## Appendix A: open items the ledger itself records (not owner requests; counted apart)

Listed so the reviewer can see none of them is orphaned.

| id | request | task | status | proof | flag |
|---|---|---|---|---|---|
| led-1 | lazygit selected line keeps each file's own colour (red name 4.15:1 on the edge, dark) | UNPLANNED | todo | measured r27-19k-2 part 2; decision left open | UNPLANNED |
| led-2 | Bar brightness reads 0 % in every shot (LG setting or a DDC read) | UNPLANNED | todo | seen r27-14b, "for T38"; T38's text does not name it | UNPLANNED |
| led-3 | verify flags qbittorrent as outside the manifest (his own install of 28 Oct) | UNPLANNED | todo | ledger defers it to the torrents task; plan T29 silent | UNPLANNED |
| led-4 | Unused 14 px tile glyphs and ICON_BOX_ON to remove | T53 | todo | listed in r27-19k-4 (c) and r27-19k-5 | |
| led-5 | LibreOffice first-run dialog and splash on a clean install | T54 | todo | found r27-17c; plan T54 names it | |

## Appendix B: cross-check against his raw words

Each paragraph of `round27-owner-notes.md` (by its line number), the rows that answer it.

| raw line | his words, shortened | rows |
|---|---|---|
| L3 | notes: black area behind the text while typing | r27-bug-2a |
| L5 | bar menus: highlighted rows inactive until a click | r27-bug-3 |
| L7 | first login after boot: no lock-to-desktop animation | r27-dec-1e |
| L9 | lock cursor blink unreliable | r27-bug-4a |
| L11 | performance work, aggressive visual testing everywhere | r27-also-3 |
| L13 | wallpaper change shows a black box first | r27-bug-5 |
| L15 | flicker in terminal apps: notes save, launcher sums | r27-bug-2b, r27-bug-6a, r27-bug-6b |
| L17 | animations boring, replace; wallpaper and theme wash longer | r27-dec-1a, r27-dec-1b, r27-dec-1c, r27-dec-1d, r27-dec-1f |
| L19 | notes: gap between header and first line | r27-bug-2c |
| L21 | chess app, 730 games, Learning section in Super+U | r27-dec-9a, r27-dec-9b, r27-dec-9c, r27-dec-9d, r27-dec-9e, r27-dec-9f, r27-dec-11a |
| L23 | typing app like EdClub | r27-dec-10a, r27-dec-10b |
| L25 | delayed entry to the lock from the saver | r27-bug-1 |
| L27 | DND menu; Steam icon behaviour | r27-bar-8, r27-bar-9 |
| L29 | brightness and weather icons differ | r27-bar-13 |
| L31 | bar smaller; numerals inside the red circle | r27-bar-1, r27-dec-3a |
| L33 | US/AR functional; re-measure bar spacing and border gap | r27-bar-5, r27-bar-16 |
| L35 | no second cream frame; demon head far right and in fetch | r27-bar-2, r27-dec-4g, r27-dec-4h |
| L37 | wallpaper 4-hour toggle as a shortcut | r27-dec-8 |
| L39 | notes as lined notebook; no save refresh; constant margins | r27-bug-2b, r27-bug-2d, r27-bug-2e |
| L42 | lock redesign: demon and angel, torches, one quote, no date | r27-dec-4a, r27-dec-4b, r27-dec-4c, r27-dec-4d, r27-dec-4e, r27-dec-4g |
| L45 | antenna TV icon; joystick icon | r27-bar-10, r27-bar-11 |
| L48 | all fonts a tiny bit smaller, more data | r27-fonts-3, r27-dec-2a, r27-dec-2b |
| L50 | active title too bold | r27-bar-3 |
| L53 | visualizer in our red | r27-bar-7 |
| L56 | date with year, number month, custom red slash | r27-bar-4 |
| L59 | pastel powerline prompt, Wada palette | r27-dec-6a, r27-dec-6b |
| L61 | Super+U headings too close | r27-bug-15 |
| L63 | drop Japanese letters in TUI icons and menus | r27-dec-3b |
| L65 | Super+R books redo | r27-bug-16 |
| L67 | cache apps in RAM | r27-also-1 |
| L69 | FireAlpaca; keep the Learn book solid | r27-dec-12a, r27-dec-12b, r27-dec-12c, r27-dec-12d, r27-run-12 |
| L71 | red separator between video and channel | r27-bar-6 |
| L73 | window borders with the 3D shadow | r27-bar-14 |
| L75 | RGB for fans, cooler display, GPU logo | r27-dec-13a, r27-dec-13b, r27-dec-13c |
| L77 | torrents lag, failed to resolve; harden and test | r27-bug-12a, r27-bug-12c |
| L79 | downloads icon moves while downloading | r27-bar-12 |
| L81 | Brave download: no percent, odd link icon | r27-bug-13a, r27-bug-13b |
| L83 | demonic wallpapers, about 10 per side | r27-dec-4f |
| L85 | .rar in yazi | r27-bug-11 |
| L87 | clipboard exit flashes "terminated" | r27-bug-6c |
| L89 | Learn book: code snippets, comprehensive, update at the end | r27-run-7 |
| L91 | Super+C calendar centred under the date | r27-bug-7 |
| L93 | sliders alive, red when high | r27-bar-15 |
| L97 | yazi UI rebuilt, dark contrast | r27-dec-5 |
| L100 | only one menu open at a time | r27-bug-8 |
| L102 | workspace numeral black inside the circle | r27-dec-3a |
| L104 | notice on every torrents open for finished downloads | r27-bug-12b |
| L106 | locked PDFs: password prompt | r27-bug-10 |
| L108 | lock wrong password slow | r27-bug-4b |
| L110 | dashed lines in terminal apps | r27-bug-17 |
| L112 | popups visible in fullscreen | r27-bug-9 |
| L114 | demon wallpapers dark, angel wallpapers light | r27-dec-4f |
| L116 | Super+/ comprehensive, fuzzy, context-aware | r27-also-2 |
| L118 | Steam may think it is a Steam Deck | r27-bug-14 |

The inbox: 23:47 is r27-inbox-2347; 23:52 is r27-inbox-2352a and r27-inbox-2352b; 23:55 is r27-inbox-2355a, r27-inbox-2355b and r27-inbox-2355c; 23:56 is r27-inbox-2356; 00:11 is r27-inbox-0011.

CLAUDE.md blocks, in order, and where they are traced: His decisions (r27-dec); Bugs 1 to 17 (r27-bug); Bar redesign (r27-bar); Added 18:48 (r27-1848); installer trickle 19:45 (r27-inst); update-proof 19:51, self-maintaining 19:56, AI fixer 20:00, FINAL 20:05, bulletproof 20:11 (r27-upd); ISO 20:17 (r27-iso); Fonts (r27-fonts); RGB (r27-rgb); Monitor (r27-mon); Never again, Network security, Lock screens off (r27-never, r27-net, r27-lock5); Reported 14:07 (r27-rep); More from 26/27 Oct (r27-more); Gaming VM (r27-vm); One design and release upgrades (r27-one); Also (r27-also); How round 27 is run, START 7 and 8, Design: an artwork (r27-run); Added 14:27 and 14:29 (r27-1427); 19:19 (r27-1919); INBOX FILE and the remote page (r27-rule); the ledger-only note of 23:23 (r27-led-2323).

## Counts

Owner-request rows only (r24 to the inbox); Appendix A is counted apart.

- Rows: **332** (r24 46, r25 22, r26 36, r27 228, of which the inbox 8). 10 rows repeat another row's request, so 322 distinct requests.
- Status: done **120**, wip **45**, todo **138**, dropped **29** (dropped: r24 7, r25 5, r26 14, r27 3; the three in r27 are the Steam items, the rest are superseded by the new fonts, bar, lock, prompt and motion).
- Flags: UNPLANNED **4**, UNPROVEN **7**, STALE **8**, none 313.
- Proof "none recorded": 137 rows (todo 133, wip 2, done 2; the done ones are flagged UNPROVEN).

| round | rows | done | wip | todo | dropped |
|---|---|---|---|---|---|
| r24 | 46 | 28 | 7 | 4 | 7 |
| r25 | 22 | 15 | 1 | 1 | 5 |
| r26 | 36 | 16 | 5 | 1 | 14 |
| r27 | 228 | 61 | 32 | 132 | 3 |
| total | 332 | 120 | 45 | 138 | 29 |

Appendix A: 5 items, all todo; UNPLANNED 3.

Plan tasks no row names: T03 (the verification toolbox), T05 (the VM harness) and T51 (re-verifies the 17 bugs); they serve other rows. T19k is traced through its sub-items T19k-1 to T19k-7.

Where the plan heading and the ledger disagree, the row follows the ledger and says so:
- T19k-7, the quick-settings dial: the plan says wip with tests, docs and the live shot left; the ledger records all three done on 1 Nov (test_panel 613/0, live shot 00:05). The rows stay wip: the master's review and his verdict are pending.
- T31, download progress inside the bar's icon: the plan says todo; ledger r27-31a records the fill drawn and verified on the kit (1 Nov 00:58). r27-inbox-0011 stays wip because each source is not yet proven with a real download.
- T20 says to choose the lock quote; ledger r27-9 already chose and dictionary-checked one per mood, so r27-dec-4d is wip, not todo.

### UNPLANNED (7, of which 3 in Appendix A)

- r24-27: the ledger left it "?"; no plan task names screen sharing (T22 mentions the portal only for yazi's picker).
- r24-40a: the ledger says WAIT for his boot video; T41 and T59 cover the black blinks, none covers the orange bar.
- r24-41b: never verified; T45's update flow does not name pulling the public repository.
- r27-rule-2: his fk-remote.service (port 8737) and ~/.local/share/fedokawaii/remote: only CLAUDE.md names them; no task, no ledger line, nothing in the repo.
- led-1: Appendix A: lazygit's selected line (red name 4.15:1 on the edge, dark) was left open by T19k-2; the plan hands only yazi's cursor row to T22.
- led-2: Appendix A: the ledger says "for T38" (bar brightness reads 0 %); T38's text does not mention it.
- led-3: Appendix A: verify flags his own qbittorrent install; the ledger defers the decision to the torrents task; T29 is silent.

### UNPROVEN (7)

- r24-37: bound in config.h (Super+Shift+X, S, A); no key press or OCR run recorded.
- r25-10: DONE(code) only; the ledger's own "verify active (pw-metadata / pactl)" was never recorded.
- r26-8: code deployed; needs his unlock to confirm and was never confirmed.
- r26-14: the diagnosis was checked on the PC, the vsync fix was only built; T38's VRR proof would exercise it.
- r27-1427-2: removal reviewed and tests updated; no grep, pw-dump or live check recorded (the plan's acceptance asks for a grep).
- r27-1427-4: button shot in both themes; the off, key, back-on run (the plan's acceptance) is not recorded.
- r27-1427-8: tile measured with small letters only; the live Caps Lock toggle (the plan's acceptance) is not recorded.

### STALE (8)

- r24-24a: VERIFIED headless in r26, but he still sees the saver-to-lock freeze (r27 bug 1, T20 todo).
- r26-10: VERIFIED r26 (110 ms lock); reopened by his 25 Oct note and r27 bug 1.
- r26-fu-6: DONE(code), headless-verified; his note says the delay persists; open as r27-bug-1.
- r27-rep-3a: the plan marks T01b done; the efi_pstore part waits for T41's reboot.
- r27-more-4: the plan marks T13 and T17b done; he reopened quick settings on 27 Oct 19:19 and 31 Oct 23:23 (T19k-7 wip).
- r27-1427-9: T17b is done in the plan; quick settings was rebuilt twice since (T19k-7 wip).
- r27-1919-5: T19k-3 is done in the plan; his 23:23 note reopened it; the dial (T19k-7) is wip and the T19k heading still says done.
- r27-1919-6: T19k-2 is done in the plan; the ledger leaves lazygit open (4.15:1) and yazi's cursor row for T22.
