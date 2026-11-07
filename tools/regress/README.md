# Never again — every item the owner ever reported, and what guards it

"Not one issue he ever reported may come back" (owner, 26 Oct 01:48). This file is the list: every
item of the ledger (`.claude/notes/02-LEDGER.md`, r24 → r28) and every row of the master's trace
(`.claude/notes/master-trace.md`) has a row here, and each row names what holds it.

How it stays true: `tests/regress/test_list.sh` (`tools/regress/items.py check`) fails when an item
has no row, when a row names a test file or a case that is not there, word for word, when a check
here is no row's, or when an `open` row's task is marked done. A new ledger line with a behaviour
adds its row here with the line.

**A row:** `| ITEMS | what must hold | CHECK · CHECK |`. A CHECK is one of:

| check | what it says |
|---|---|
| `tests/AREA/test_x.sh "words"` | a stand-in test, the case with those words (run by `tests/run.sh`) |
| `tools/regress/x.sh` | a headless check on the real GPU, nothing of the session touched (run by `tools/regress/run.sh`) |
| `tools/x.sh` | a proof kept as a tool: root or a VM, run when its part changes |
| `gone T..: why` | it was replaced or taken out; nothing of it is left to break (its successor has a row) |
| `record: why` | no behaviour of its own: a decision, a standing rule, research, a piece of work |
| `open T..: why` | its task is still running; the row must name a check when the task is marked done |
| `manual: step` | cannot be automated: the step, five at the most |

**Records by their name** need no row, because `items.py` knows them: a master's verdict (`*-master*`, `*-R3`:
what it found has its own `-fix` line), a run of the suite, a push, an apply, an event of the PC's
(`r27-suite*`, `r27-push*`, `r27-apply*`, `r27-event`, `r27-boot*`, `r27-tidy*`), a note of round 28 (`r28-note-*`), research and
baselines (`*-digest`, `*-research`, `*-baseline`, `*-facts`, `*-hunt`), an ASan run (`*-asan`).

**Run them:** `bash tests/run.sh regress` · `bash tools/regress/run.sh --bin bin --repo-art` ·
`bash tools/prepush.sh` (all of it, before a push to main) · `fedokawaii selftest --sandbox` (on the
installed system). `python3 tools/regress/items.py blame LOG` turns a run's ✘ lines into the items
they break.

| item | what must hold | check |
|---|---|---|
| r24-2 r24-40b r25-7 r26-fu-5 | boot: the splash once, no black box, no blink: no simpledrm, no plymouth.use-simpledrm on any entry | tests/regress/test_boot.sh "the boot's arguments" · tests/installer/test_setup.sh "phase 1: a quiet boot" · tests/installer/test_clean.sh "an entry with an argument gone since" |
| r24-40a | the boot menu shows no orange progress bar: our own theme, no bar | tests/regress/test_boot.sh "the boot menu" · tests/installer/test_theme_parts.sh "the boot menu not made" |
| r27-19m-boot | the black rectangle left at the hand-over (seen in the VM, 3 Nov) | open T19m: its finer capture is pass 2 of the audit |
| r27-kanji-words | the boot splash in words, no kanji; kanji only where he allows it | tests/regress/test_gone.sh "kanji only where he allows" |
| r25-8 | a snapshot boots read-only | tests/installer/test_upkeep.sh "the start-up run in a snapshot started from the boot menu" · tests/engine/test_snap.sh "from a snapshot started from the boot menu" |
| r26-fu-4 | the bar never grows, whatever the title: Arabic, emoji, Thai | tools/regress/bar-titles.sh · tests/regress/test_bar.sh "a title of any script" |
| r27-bar-1 r27-14a r27-10c | 27 rows; every tile on the grid | tools/regress/bar-geometry.sh · tests/static/test_bargaps.sh "the tiles, from the style and the drawings" |
| r27-bar-2 r26-20 r26-22 r26-25 r24-42 r26-3 r26-1 r26-4 r26-5 r26-16 | no inner frame on any cell; one frame per tile, 8 px paper to ink, stamps and seal to the pixel | tools/regress/bar-geometry.sh · tests/session/test_bar.sh "the style" |
| r27-bar-3 | the active title in the lighter face: one weight of 1 px strokes | tests/session/test_dwlstatus.sh "titles: JSON and markup breakers" · tests/regress/test_fonts.sh "the UI face is one weight" |
| r27-bar-4 | date DD/MM/YYYY, our red slash | tests/session/test_bar.sh "the items at rest" |
| r27-bar-5 | US red, AR blue, clickable | tools/regress/bar-layout.sh · tests/session/test_tag.sh "kb next" · tests/session/test_dwlstatus.sh "us,ara: us then ar" |
| r27-1427-8 | us/ar in capitals while Caps Lock is on, small when off, live | tests/session/test_dwlstatus.sh "Caps Lock (owner, 14:27)" |
| r27-bar-6 | a red rule between the video's title and its channel | tests/status/test_nowplaying.sh "a song plays: the cassette, the title, a red rule" |
| r27-bar-7 r26-2 | the visualizer in our red, wings either side of the clock | tests/status/test_nowplaying.sh "the wings: a module of their own each" · tests/status/test_nowplaying.sh "in the light theme: the wings in its own ten reds" |
| r27-bar-8 | the DND icon opens a small DND-only menu | tests/menus/test_quick.sh "the dropdown, nothing set" |
| r27-bar-10 r27-14b | the retro TV moves while a video plays: frames 0–3 in order, 6 a second, no stray pixel | tools/regress/tv-frames.sh · tests/regress/test_bar.sh "the television's four frames" · tests/status/test_nowplaying.sh "a video: the television's picture moves" |
| r27-bar-12 r27-31a r27-inbox-0011 r24-35 | downloads: the arrow moves while downloading, the percent inside the mark, any source | tests/status/test_downloads.sh "the percent inside the mark" · tests/status/test_downloads.sh "bar --follow" · tests/content/test_file.sh "packing: its progress a row" |
| r27-19m-dl | names in the downloads' list as he reads them | tests/status/test_downloads.sh "a name in the menu" |
| r27-bar-13 | the weather's sun is not the brightness icon | tests/regress/test_bar.sh "the weather's sun is not the brightness" · tests/status/test_weather.sh "the bar's picture for every code" |
| r27-bar-14 r27-15a | window borders with the bar's 3D shadow | tools/regress/window-frame.sh |
| r27-bar-15 r27-15c | volume and brightness: a level display, alive, red when high | tools/regress/level-display.sh · tests/menus/test_panel.sh "the level display: one row on the grid" · tests/status/test_osd.sh "70 %: one line" |
| r27-bar-16 | every section re-measured | tools/regress/bar-geometry.sh · tests/static/test_bargaps.sh "ICON_BAR_*: each icon's ink from the pen" |
| r27-bar-9 r27-bar-11 r24-16 r27-vm-1 | no Steam on the bar: its tile, joystick and tooltip gone | tests/regress/test_bar.sh "no Steam on the bar" |
| r24-4 r27-15d | tooltips: minimal words, in the frame | tests/session/test_bar.sh "tooltips: a module either says" |
| r27-19k r27-19k-1 r27-1919-3 | the bar through rapid workspace switches: no frame wrong, no pop | tools/regress/bar-burst.sh |
| r26-17 r26-18 r26-19 | the bar's variants he chose from | record: mock-ups, settled by his pick of kami (r26-20) |
| r27-found-1 | no waybar zombies: nothing sends SIGUSR2 | tests/static/test_barreload.sh "no program, config, installer step" |
| r27-53-timer | the bar's idle cost: the clock's loop starts no process | tests/menus/test_timer.sh "the bar's loop starts no process" |
| r27-19k-4 | the weather and the sections drawn anew; the head's picture on the bar | tests/status/test_weather.sh "every sky the bar can show has its picture" · tests/session/test_bar.sh "the mood's head: the Fedora logo" · tools/regress/bar-geometry.sh |
| r27-1919-1 r27-dec-4g | the bar's far right: was the demon and angel, now the Fedora head (r28-d1) | tests/static/test_heads.sh "no old head on the head's surfaces" · tests/session/test_bar.sh "the mood's head: the Fedora logo (tools/build-head.py, 32 × 30, the disc 26 across) for both themes" |
| r27-1919-2 | every custom icon alive, unique | open T19q: his design review; the drawn icons' checks are tests/static/test_generated.sh |
| r27-1919-4 r27-19k-5 | the to-do's own icon | tests/content/test_notes.sh "its heading (the tanzaku, to-do, the rule)" |
| r24-13 r25-3 r27-bug-3 r27-13a | dropdown rows answer the pointer from the first frame, no click first; static rows never selectable | tools/regress/menu-first-click.sh · tests/menus/test_panel.sh "it opens under the pointer" · tests/menus/test_panel.sh "one light in every panel and menu" |
| r27-bug-7 | Super+C opens centred under the date | tools/regress/calendar-middle.sh · tests/menus/test_panel.sh "--middle (the calendar, the timer)" |
| r27-bug-8 | one popup at a time, every combination | tools/regress/one-popup.sh · tests/session/test_popups.sh "a popup raised over a menu" · tests/menus/test_panel.sh "opening one closes the one open" |
| r27-bug-9 | popups show over a fullscreen window | tools/regress/popup-fullscreen.sh · tests/session/test_dwl_anim.sh "popups (warm windows" |
| r27-13b r27-1848-2 r27-one-2 r27-one-5 r27-17 r26-9 | one grammar: every surface the same box in both moods | tools/regress/gallery.sh · tests/static/test_design_doc.sh "the sections, numbered" |
| r27-13c | the timed quiet ends by its timer | tests/menus/test_quick.sh "dnd: the timer that ends it" |
| r24-26 | Alt+F and the share picker: the first option highlighted | tests/menus/test_panel.sh "a menu opens keyboard-first" · tests/menus/test_share.sh "two screens: the link icon" |
| r24-38 r25-12 | fast clicking counts every click; a launcher click toggles, mouse and keys one | tests/menus/test_panel.sh "a fast clicker: 40 clicks" · tests/menus/test_panel.sh "a click is never a held key" · tests/menus/test_menu.sh "its key pressed fast" |
| r24-9 | Super+N rapid: every press toggles | tools/regress/warm-rapid.sh · tests/menus/test_hotkeys.sh "pressed fast, every press counts" · tests/menus/test_hotkeys.sh "the warm keys (Super+N, Super+V, Super+U)" |
| r24-10 | screen recording in quick settings | tests/menus/test_quick.sh "record: on while kawa-record" |
| r24-11 | calendar previous, next, today: every press, no glitch | tests/menus/test_calendar.sh "December → next → January" · tests/menus/test_calendar.sh "the cursor stays on the key that paged" · tests/menus/test_panel.sh "--stay (the calendar's months)" |
| r24-3 r27-21-bug6b r27-bug-6b | the calculator's and the launcher's answers: no flicker, the footer whole | tools/regress/launcher-calc.sh · tests/look/test_calc.sh "bug 6, the rest (seen frame" · tests/look/test_calc.sh "bug 6 (the answer's row flickered" · tests/content/test_notes.sh "nothing written over the footer while typing" |
| r24-17 r25-11b | live calculator and currency in the launcher; the notice shows the copied result | tests/look/test_calc.sh "the launcher: a sum typed is worked out" · tests/look/test_calc.sh "the launcher: a sum typed" · tests/regress/test_keys.sh "a currency conversion" |
| r24-5 | no duck or sheep: every launcher entry a custom pixel icon | tests/look/test_launcher.sh "every listed entry: a window program's own icon" |
| r24-6 r24-8c r27-bug-15 r27-bug-17 r27-16 | text screens: a blank row after the heading and input; no dashed rule anywhere; one grammar | tests/content/test_configs.sh "fzf.opts: one blank line" · tests/engine/test_menu.sh "the tab bar, a heading over the list" · tests/regress/test_gone.sh "no dashed rule" |
| r27-bug-6c | the clipboard's exit never flashes "terminated" | tools/regress/warm-exit.sh · tests/content/test_clip.sh "in the warm window (KAWA_WARM=clip)" |
| r27-bug-16 | Super+R aligned and spaced | tests/content/test_books.sh "every row is exactly the list's width" · tests/content/test_books.sh "the pane: the cover centred" |
| r25-2 r27-dec-8 | Super+W: the current one marked, the 4-hour toggle a key at the bottom, whole | tests/look/test_wallpaper.sh "the cursor starts on the current choice" · tests/look/test_wallpaper.sh "--next (its timer, every hour)" |
| r24-20 | wallpapers rotate every 4 h, 100 at least | tests/look/test_wallpaper.sh "--next (its timer, every hour): n" · tests/regress/test_counts.sh "a hundred wallpapers" |
| r25-x1 | menus see-through like the terminal | tests/menus/test_panel.sh "the ground as see-through as the terminal's" |
| r25-5 r27-15b | notices: alignment, spacing, icon and text; our mako pinned | tests/static/test_notices.sh "every notify-send" · tests/static/test_syntax.sh "the desktop's mako" · tests/static/test_design_doc.sh "§14" |
| r27-1427-4 | a key to switch the monitor off, in quick settings | tests/menus/test_quick.sh "screenoff: every screen dark" |
| r27-1427-9 r27-more-4 r27-1919-5 | quick settings: a proper menu, every row its own picture, on the grid to the pixel | tests/menus/test_panel.sh "the items, in order: the two levels" · tests/menus/test_panel.sh "every picture a row or a level can wear i" · tests/menus/test_panel.sh "the grid (docs/design-system.md §3–" · open T19q: his verdict on the plain menu |
| r27-led-2323 r27-19k-3 r27-19k-7 | the mon sheet, then the dial | gone T19q: Super+X from nothing, his note of 4 Nov 17:00 |
| r27-17b | the desktop items of 14:27: the clean mic out, the screen-off key, the small us/ar | tests/static/test_syntax.sh "the clean mic is gone" · tests/menus/test_quick.sh "screenoff: every screen dark" · tests/session/test_dwlstatus.sh "Caps Lock (owner, 14:27)" |
| r27-1919-6 r27-19k-2 | what is highlighted has contrast: WCAG measured, both moods | tests/static/test_contrast.sh "tools/contrast.py: every pair" · tests/static/test_contrast.sh "every menu's selected row is a colour change on the ground (select is the ground: no band)" · tools/regress/menu-cursor.sh |
| r27-19m r27-19m-b1 r27-19m-p1 r27-19m-p1-tui r27-19m-gtk-default r27-inbox-2347 r27-1919-7 r27-inbox-2352b | the words by APCA; every surface measured | tests/static/test_contrast.sh "tools/contrast.py --apca" · tools/regress/gallery.sh |
| r27-inbox-2352a | 100+ sources for the design | record: .claude/notes/design-research.md |
| r27-also-2 r27-23-help r27-23-sheets r27-23-own r27-23-fix1 r27-23-fix2 | Super+/ comprehensive, fuzzy, the active program's keys first | tests/menus/test_help.sh "a program the shell named in the title" · tests/menus/test_help.sh "one of ours by its app id" · tests/menus/test_panel.sh "--fuzzy (Super+/)" · tests/content/test_shell.sh "a program with a key sheet names its window" |
| r27-23-scroll r27-23-fix3 r27-23-wheelcheck r27-23-live | a long list moves by whole lines; one mouse notch, one move | tools/regress/wheel-notch.sh · tests/menus/test_panel.sh "no line is cut at either edge" · tests/menus/test_panel.sh "one mouse notch, one move" |
| r27-23-live-2 | the same, live | record: a live check of the row above |
| r27-53-panel-start | the panel's start | record: a measurement, 6 ms, nothing to cut (tools/perf.sh keeps the protocol) |
| r24-24a r26-10 r26-fu-6 r27-bug-1 | saver → lock after a long absence: no frozen picture, no cut | tools/regress/saver-lock.sh · tests/session/test_dwl_anim.sh "after a long time away (the screens dark)" · tests/look/test_saver.sh "--idle: the lock started once the painting" |
| r24-24b r25-6b r26-23 | the old thin lock | gone T20: the lock was redrawn (r27-20-*) |
| r24-45 | the saver follows the theme | tests/look/test_saver.sh "its colours: the theme's saver.conf" |
| r27-19m-saver | no kanji seals on the saver but the day's | gone T19q: the saver redone from the lock's painting; tests/regress/test_gone.sh holds the kanji |
| r27-one-3 | lock, greeter and saver in one grammar | tests/engine/test_greeter.sh "the lock's twin" · tests/look/test_lock.sh "the scene (build-ink.py → lo" |
| r27-bug-4a r27-dec-4a r27-dec-4b r27-dec-4c r27-dec-4d r27-20-dark r27-20-light r27-20-light-built r27-20-wire r27-20-wire-3 r27-20-nit5 r27-20-nits r27-20-fix-1 r27-20-fix-2 r27-20-proto r27-20-live | the lock's scene: no date, time or buttons; the mouth, the torches, one quote; its own caret, blinking | tools/regress/lock-screens.sh · tools/regress/lock-start.sh · tests/look/test_lock.sh "the scene (build-ink.py → lo" · tests/look/test_lock.sh "the layout: every id gtklock reads" |
| r27-bug-4b r27-20-wire-2 | a wrong password reports fast | tests/regress/test_lock.sh "a wrong password reports fast" · tests/engine/test_greeter.sh "a wrong password: the session cancelled" |
| r27-lock5-1 | lock: screens off after 5 s, any key lights them onto the lock | tools/regress/lock-screens.sh · tests/look/test_lock.sh "the screens (kawa-lockmod)" |
| r26-fu-9 | a lock that fails never kills another gtklock: only its keeper's child | tests/regress/test_lock.sh "only its keeper's own gtklock" |
| r26-8 | no busy cursor after an unlock | tests/session/test_dwl_anim.sh "after the unlock the pointer's surface" |
| r24-29 | sleep and wake with Enter: the wake is no try | tests/look/test_lock.sh "kawa-lockmod: an empty Enter is no try" · tests/engine/test_greeter.sh "the wake guard" · tests/menus/test_power.sh "kawa-power sleep (the Sleep key)" |
| r27-dec-1d r27-dec-1e | lock → desktop dissolve; greeter → session | tests/session/test_dwl_anim.sh "unlocked: the lock screen dissolves off" · open T19q: the lock's frames are being redone |
| r27-02b-found | the screens' dark state read right | tests/look/test_lock.sh "--screens on when wlopm fails" |
| r24-18 r25-15 r26-6 r26-15 r27-dec-1a r27-dec-1b r27-19 | windows open, close, switch: every step a frame, as long as config.h says, no wrong-size frame | tools/regress/anim.sh · tests/session/test_dwl_anim.sh "a new window hops in only once it has drawn itself" · tests/session/test_dwl_anim.sh "driven by the screen's frames" |
| r27-dec-1c | menus, Super+N and the rest unroll | tests/session/test_dwl_anim.sh "layer surfaces by namespace" · tests/session/test_dwl_anim.sh "a warm window (Super+U, N, V) shown unrolls" |
| r24-7 r26-fu-8 r27-dec-1f r27-bug-5 r27-dec-7 | theme and wallpaper: the ink wash, 1.2 s, no black box, the pointer with it | tools/regress/wash.sh · tests/session/test_dwl_anim.sh "the wash (a theme switch" · tests/session/test_dwl_anim.sh "the pointer takes a theme switch's new pointer" |
| r26-14 | no tearing on the desktop: async flips only under FreeSync | tests/session/test_dwl_anim.sh "tearing (async) flips only while FreeSync" |
| r26-fu-7 | layout holds: 60 ms at the most, dwl never blocked | tests/regress/test_dwl.sh "the layout's holds" |
| r24-34 r26-26 | a game shown again after a switch: told it is not minimised | tests/session/test_dwl_anim.sh "arrange: an X11 window shown again" |
| r27-1 r27-rep-1 r27-rep-2 r27-rep-3b | the random restart: dwl with no monitor, NULL-safe | tests/session/test_hotplug.sh "an X11 window asking for a size while no monitor" · tests/session/test_hotplug.sh "the other paths that run with no monitor" · tools/hotplug-test.sh |
| r27-rep-3a r27-crashnote-pid | a crash says so once, only his session's | tests/session/test_crashnote.sh "his session's dwl crashed" · tests/session/test_crashnote.sh "a dwl of his own under another pid crashed" |
| r27-2 r27-rep-4a r27-rep-4b r27-02b r27-02b-fixes r27-02b-sf6 | monitor on: back on the workspace it was, by name, with its layout and focus | tools/regress/monitor-state.sh · tests/session/test_hotplug.sh "kept under its name as it goes" · tests/session/test_hotplug.sh "back as it was (createmon)" · tests/session/test_hotplug.sh "back after it dropped off" · tools/hotplug-test.sh |
| r27-stuck-notice r27-stuck-notice-fix | no picture outlives its surface | tools/regress/notice-unplug.sh · tests/session/test_hotplug.sh "its ghosts go with it, last" |
| r27-dwl-noxwayland | dwl with no XWayland: exits clean | tools/regress/no-xwayland-exit.sh |
| r27-dwl-termburst | a burst of new terminals never crashes dwl | tools/regress/term-burst.sh |
| r27-21-cold | a cold Super+N: the press is never lost | tests/session/test_warm.sh "its key's press taken as it MAPS" · tools/regress/notes-page.sh |
| r27-bug-2a r27-21-bug2 | notes: no black areas around the text, nor in any program under the glass | tools/regress/glass-cells.sh · tests/look/test_units.sh "foot.ini: the see-through ground on every cell" |
| r27-bug-2b r27-bug-6a r27-21-bug6 | notes: no flicker on save | tests/content/test_notes.sh "notes.lua: neovim's ui2 on" |
| r27-bug-2c r27-bug-2d r27-bug-2e r27-21-nb r27-21-nb2 | notes: a lined notebook, the heading's blank row, margins that never move | tools/regress/notes-page.sh · tests/content/test_notes.sh "notes.lua: the heading in the tabline" |
| r27-21-master-fix | the page: no conceal, the pen in the page on a cold start | tests/content/test_notes.sh "notes.lua: a start on a day already written" |
| r27-21-sf | the page opens on a day's line | tests/content/test_notes.sh "notes.lua: the page opens on a day's line" |
| r27-21-master-2-fix | o, yy p, :put never jump the page | tests/content/test_notes.sh "notes.lua: lines typed with Returns each keep their rule" · tests/content/test_notes.sh "notes.lua: a to-do longer than the page" |
| r27-21-master-3-fix | the page moves by lines: no smooth scroll over the margin | tests/content/test_notes.sh "notes.lua: the page moves by lines" |
| r27-21-master-4-fix | a scroll he makes is his | tests/content/test_notes.sh "notes.lua: a scroll he makes is his" |
| r27-21-master-5-fix r27-21-master-5-left r27-21-master-6-fix r27-21-master-7-fix | a wheel while typing: a look; the pen stays with the text | tests/content/test_notes.sh "typing at the foot, a wheel up, Esc" · tests/content/test_notes.sh "a line typed in long notes, then tab into that to-do" · tests/content/test_notes.sh "a wheel up while typing in a window that has been through normal mode" |
| r27-21-master-8-fix | the program placing the pen ends a look | tests/content/test_notes.sh "a look, then a click: the pen goes where the pointer is" |
| r27-21-master-9-fix r27-21-master-10-fix | a click on the head or the foot places no pen; double and triple clicks swallowed | tests/content/test_notes.sh "a look, then a click that places no pen" · tests/content/test_notes.sh "a double and a triple click on the foot" |
| r27-1848-1 r27-21a | the to-do: a box, done struck through, nothing else | tests/content/test_notes.sh "space ticks: the box filled and muted" |
| r27-21t r27-inbox-2227 | the to-do only through Super+N's tab, never in Super+U | tests/content/test_notes.sh "kawa-notes --todo is gone" · tests/engine/test_menu.sh "nor a way in by name" |
| r27-17c r27-1427-7 | copy and paste everywhere: foot, the primary, a closed window's copy, a picture, 6 MB, neovim, the history | tools/regress/clipboard.sh · tests/content/test_notes.sh "the clipboard (owner 14:27, copy/paste)" · tests/content/test_clip.sh "a picture over cliphist's 5,000,000 bytes" · tests/content/test_clip.sh "a copy kawa-clipkeep offers again" |
| r24-22 r27-dec-5 r27-22-grid r27-22-nits | yazi on §7's grid, the file picker never jumbled | tests/yazi/test_yazi.sh "init.lua's frame" · tests/menus/test_pick.sh "the dialog's keymap parses" · tests/yazi/test_yazi.sh "yazi follows its window as it is resized" |
| r27-more-5 r27-22-hidden r27-22-sf7 | hidden files always shown, file manager and picker | tests/yazi/test_yazi.sh "hidden files shown, dotfiles too" · tests/menus/test_pick.sh "the dialog's yazi: your theme" |
| r27-22-kinds | file kinds readable on the ground | tests/static/test_contrast.sh "tools/contrast.py: every pair" |
| r27-22-empty r27-22-seen | what is not there yet, said quietly | tests/yazi/test_yazi.sh "what is not there yet, said quietly" |
| r27-22-tabs | yazi's tabs in our grammar | tests/yazi/test_yazi.sh "two tabs (t t)" |
| r27-22-mf3-found | yazi's modals | open T22: must-fix 3 of the master's review |
| r27-22-zathura | zathura's bars in our font | tests/content/test_configs.sh "zathurarc: r reloads" |
| r27-bug-10 r27-22-b10 r27-22-b10-built r27-22-b10-rec r27-22-failed r27-22-sf3 r27-22-sf2a | locked PDFs: a password asked; a wrong one says so in place | tests/menus/test_panel.sh "a password asked with --stay" · tests/content/test_file.sh "lock: AES-256" · tests/menus/test_config.sh "yazi: a PDF previewed through kawa-pdf" |
| r27-22-b10-cheap | a locked archive's check is cheap | tests/content/test_file.sh "a locked zip: the menu says so" |
| r27-bug-11 r27-22-sf2b | .rar opens: unrar | tests/yazi/test_yazi.sh "a .rar: its entries in the preview" · tests/content/test_file.sh "a RAR unpacked by the real unrar" |
| r24-25 | Super+Z: PDF and picture shrink, never a stale image | tests/content/test_shrink.sh "Super+V open, the cursor on text: nothing to shrink" · tests/content/test_shrink.sh "a PDF full of pictures" · tests/content/test_shrink.sh "a size of your own: typed (150 KB)" |
| r27-52-R5-sf2 | the picker's q with marks takes the marked | tests/menus/test_pick.sh "q with marks takes the marked" |
| r24-8a r26-7a | many terminals fast: no duplicate heading, nothing mis-laid | tools/regress/prompt-burst.sh · tests/content/test_tiles.sh "a window nothing has run in yet" |
| r24-8b r25-6a r26-7b r26-24 | the older prompts | gone T24: the pastel-powerline prompt replaced them |
| r27-dec-6a r27-24 r27-24-direction r27-24-fix1 r27-24-burst | our prompt: pastel powerline, one short line, contrast measured | tests/content/test_shell.sh "foot: a new window's prompt" · tests/content/test_shell.sh "foot: one short line" · tests/static/test_contrast.sh "it fails the prompt's ink moved off its papers" · tools/regress/prompt-burst.sh |
| r27-24-fix2 | the prompt's pairs in the contrast table | tests/static/test_design_doc.sh "the contrast table" |
| r27-24-fix3 | its tiles measured, not copied; ble.sh's first load silent | tools/regress/tile-widths.sh · tests/content/test_tools.sh "the second start says nothing at all" |
| r24-12 | btop spaced and consistent | tests/content/test_configs.sh "btop.conf: every name btop's" · tests/content/test_tiles.sh "btop's start: all five boxes" |
| r24-14 | the mixer's mark has air | tests/static/test_syntax.sh "the mixer's marks" |
| r27-dec-2b r27-fonts-2 r27-fonts-3 r27-11 | the terminal's face: UDEV Gothic NF, 16 px, 8 × 20 | tests/installer/test_upstream.sh "the terminal's face (UDEV Gothic NF)" · tests/static/test_syntax.sh "Sumi Term (UDEV Gothic NF" |
| r27-dec-3b | kanji only on stamps, the lock's quote and the day's seal | tests/regress/test_gone.sh "kanji only where he allows" · tests/static/test_notices.sh "every notify-send" |
| r27-inbox-1822b | terminal text aligned in an insane range of situations | tools/regress/term-grid.sh |
| r27-9b | the suite never runs less than it says | tests/regress/test_suite.sh "every test file is run, once" · tests/regress/test_suite.sh "no test leans on a tool" · tests/installer/test_common.sh "the harness's guard" |
| r26-fu-1 r27-fonts-1 r27-dec-2a r27-10a | the UI face: every letter, digit and sign keeps its air, no pair touches | tests/regress/test_fonts.sh "no two letters touch" · tests/static/test_generated.sh "width.sh's cols counts as the faces draw" |
| r26-fu-2 | the % drawn by hand | tests/regress/test_fonts.sh "the percent sign is ours" |
| r27-fonts-4 r27-10b r27-10d r27-fix | icons on the new cells; an icon appended moves no other; a session on an old font draws none wrong | tests/static/test_bargaps.sh "an icon appended moves no other icon" · tests/static/test_generated.sh "build-icons.py on a copy" · tests/static/test_generated.sh "an icon written as its raw character" |
| r27-7 r27-1427-1 r25-1 r24-23 | fonts chosen; thicker once, replaced since | tests/installer/test_upstream.sh "the face, Sumi UI" · tests/static/test_generated.sh "build-fonts.py on a copy" |
| r26-fu-3 | the sun and bulb redrawn; the joystick gone | tests/status/test_brightness.sh "the bulb of its fifth" · tests/regress/test_bar.sh "no Steam on the bar" |
| r27-9 r27-one-4 r26-21 r25-x r25-x2 | docs/design-system.md the single truth: what it names exists, its numbers are the code's | tests/static/test_design_doc.sh "every file it names is in the repository" · tests/static/test_design_doc.sh "the palette (§1)" |
| r27-8 r27-dec-6b | the Wada palette: every token from its source, every pair measured | tests/static/test_design_doc.sh "the palette (§1)" · tests/static/test_generated.sh "build-themes.py on a copy" |
| r26-11 r25-14 r25-16 r27-also-3 r27-run-3 | the full sweep, the end user's walk | open T59: maniac testing |
| r27-12 r27-one-1 r24-41a r27-42-strays-a | Super+U: tabs, states, every entry answers, its tab record tidied | tests/engine/test_menu.sh "the tab bar, a heading over the list" · tests/engine/test_menu.sh "the tab's record: one per menu" · tests/engine/test_menu.sh "help names every command the engine answers" |
| r24-41b | update pulls from the public repository | tests/engine/test_pull.sh "pull with no clone yet" |
| r27-6 r27-vm-14 | one early notice of what he must do | tests/content/test_foryou.sh "show: a critical notice per thing" |
| r24-rep | the report's findings: mako once, no double start, XCURSOR | tests/installer/test_report_rows.sh "UI-07: one level display" · tests/session/test_autostart.sh "logged out, in again: one of each helper" · tests/look/test_theme.sh "dwl told at every switch" |
| r27-3 | the toolbox: frame log, kit, px | tests/session/test_framelog.sh "dwl writes those lines" · tests/static/test_tools.sh "hl-dwl.sh and shot.sh" |
| r27-4 r27-1848-3 | the performance baseline | record: .claude/notes/perf-before.md (tools/perf.sh is the protocol) |
| r27-1848-4 r27-run-4 | the performance test, before and after | open T60: tools/perf.sh |
| r27-18 r27-18-walls r27-18-mf1 r27-18-mf3 r27-18-mf4a r27-18-mf4b r27-18-sf69 r27-18-sf8 r27-18-fix-1 r27-dec-4e r27-dec-4f | the old masters: committed, by checksum, indexed, no print margin; ten and more of each | tests/static/test_masters.sh "every picture the list takes from the toolkit" · tests/static/test_masters.sh "no paper at any picture's edges" · tests/regress/test_counts.sh "ten demons and ten angels" |
| r27-dec-4h | fetch: the mood's face | tests/content/test_fetch.sh "no name: the mood's own face" |
| r27-found-lockpng | the lock's pictures rebuild as committed | tests/static/test_generated.sh "build-art.py on a copy" |
| r25-10 | the best sound: 48 kHz and the music's own rate, the resampler at 14, the best codecs | tests/status/test_configs.sh "50-quality.conf" · tests/status/test_configs.sh "the resampler at quality 14" · tests/status/test_configs.sh "50-bluetooth-quality.conf" |
| r24-33 r27-1427-2 | no clean mic: nothing left of it | tests/static/test_syntax.sh "the clean mic is gone" · tests/status/test_configs.sh "the clean mic is taken out" · tests/session/test_state.sh "a setting the desktop no longer has" |
| r24-36 | recording: pause, 3-2-1, resume, one file | tests/look/test_record.sh "pause again: 3, 2, 1" · tests/look/test_record.sh "stopped after a pause" |
| r24-37 | the capture and read-text keys on a 61-key board | tests/regress/test_keys.sh "the capture keys" · tests/look/test_screenshot.sh "text: the region read" |
| r24-27 | a window share is solid: one question, one menu for Brave's two requests | tests/menus/test_share.sh "Helium's two requests for one window shar" · tests/look/test_units.sh "one question per share" |
| r24-15 r25-9a | torrents: no pip error, torrra at its pins, themed | tests/engine/test_prowlarr.sh "an earlier setup's pipx install" · gone T29: torra left, kawa-torrents is the desktop's own |
| r25-9b | neovim themed | tests/content/test_tools.sh "neovim: :checkhealth" |
| r27-33 r27-bug-12a r27-bug-12b r27-bug-12c r27-more-1 r27-more-2 r27-more-3 r27-more-6 r27-1427-5 r27-1427-6 | torrents overhauled, "failed to resolve", the notice once, Prowlarr's warning | open T29: lane-torrents |
| r27-29s r27-29s-fix1 r27-inbox-1822a r27-53-mpvdumps | Syncplay and its mpv as one: closing either closes both, no core dumps | tests/yazi/test_syncplay.sh "the launcher's Syncplay" · tests/yazi/test_syncplay.sh "the syncplay installed runs on a Python without PySide6" |
| r27-bug-13a r27-bug-13b | Brave's download: the percent, no odd icon | tests/status/test_downloads.sh "the browser: a .crdownload —" · tests/status/test_downloads.sh "a finished download's notice" |
| r27-53-brave | one check whether Brave is open | gone T31a: Brave left, kawa-browser is one file |
| r27-1427-3a r27-1427-3b r27-1427-3c r27-1427-3d | a better browser, trial and migration | open T31a: lane-research2's notes, the trial is main's |
| r24-1 r27-49-hang r27-49-E1 r27-49-E2 r27-49-E3 r27-49-E4 r27-49-B1 r27-49-B2 | the update never sticks: dnf's end read by polling, a stop from outside said | tests/installer/test_update_flow.sh "stopped from outside while it fetches" · tests/installer/test_update_flow.sh "stopped from outside before its transaction began" · tools/vm-inject/update-green.sh · tools/vm-inject/update-button.sh |
| r27-upd-1 r27-upd-7 r27-upd-10 r27-49a r27-49c r27-49-merge r27-45-merge | one press: snapshot, update, verify, keep or roll back, a short report | tests/installer/test_update_flow.sh "a green update: stored once" · tests/engine/test_status.sh "a kept update whose desktop items were red before it" |
| r27-upd-2 r27-upd-5 r27-49-18 r27-49-11 r27-49-sf2-5 | the culprit held: a whole family, none written twice | tests/installer/test_update_flow.sh "a family red (one source package)" · tests/installer/test_update_flow.sh "the next press: the holds in force again" · tests/installer/test_update_flow.sh "two sources whose names begin alike" |
| r27-49-14 r27-49-R4-sf1 r27-49-R4-sf3 r27-49-R4-sf4 | a run cut short ends well | tests/installer/test_update_flow.sh "a run cut before its transaction" · tests/installer/test_update_flow.sh "a start after a run cut before its transaction began" |
| r27-49-8 | a new kernel's first start is on trial, and only when the boot can come back | tests/installer/test_update_flow.sh "a green update that brought a kernel" · tests/installer/test_update_flow.sh "a kernel with a third entry in the boot menu" |
| r27-49-sf1 r27-49-master-2-fixes r27-49-master-3-fixes r27-49-R5-sf r27-49-R4b-green3 | what a red run offers stays, and a red before never hides a new one | tests/installer/test_update_flow.sh "the next press keeps that offered snapshot pinned" · tests/installer/test_update_flow.sh "a red before (the bar's clock) never hides another" |
| r27-49-halt r27-49-pid1 r27-49-storm3 r27-49-R4b-sf | systemd crashing in a transaction: seen, said, the machine put right | tests/installer/test_update_flow.sh "systemd itself crashed in the transaction" · tests/installer/test_upkeep.sh "systemd crashed BEFORE a transaction" |
| r27-49e r27-49f r27-49h r27-49-apply6 r27-49-exp1 r27-49-exp2 | the update's checks after: the desktop's start, the probation, a press follows a running one | tests/engine/test_menu.sh "an update running as a unit of its own" · tests/engine/test_front.sh "update: a unit of the system's own" · tools/regress/session-start.sh |
| r27-upd-3 | his settings kept apart from what the theme owns: byte for byte through a theme run | tests/regress/test_kept.sh "secrets, his own autostart and his settings" · tests/regress/test_kept.sh "the settings file" · tests/engine/test_copy.sh "diff: the settings you saved from the menu" · tests/session/test_state.sh "the theme ships no file where your settings live" |
| r27-upd-4 r27-upd-6 r27-upd-11 r27-upd-12 r27-50 r27-50b r27-50b-checks r27-inbox-1710 r27-inbox-2355b r27-inbox-2355c r27-one-6 | release upgrades through the same button, pre-flighted | open T46: lane-updates, main does the PC's upgrade |
| r27-upd-8 r27-upd-9 | the local fixer | open T47: lane-fixer |
| r27-upd-13 r27-upd-14 r27-upd-15 r27-upd-16 | snapshots, backups, rollback: one model, from Super+U and the boot menu | open T48: lane-updates |
| r27-upd-17 r27-upd-18 r27-47/48 r27-47 | the update's research and design | record: .claude/notes/update-research.md, update-design.md |
| r27-upd-19 r27-52a-vm2 r27-52b-vm | every failure injected in the VM | open T49: tools/vm-inject |
| r27-52a r27-52a-restore r27-52a-fix | a whole-system restore cut at any step ends whole | tests/engine/test_snap.sh "finish: a restore cut after its exchange" · tests/installer/test_upkeep.sh "the start-up run: kernels a restore left in /boot" · tools/vm-inject/restore-cut.sh |
| r27-52b r27-52b-fix r27-52b-fstab r27-52b-pc | the flat layout: a split cut at any step ends whole | tests/engine/test_split.sh "a file a process holds open" · tests/engine/test_snap.sh "the flat layout (fedokawaii-split)" · tools/vm-inject/split-cut.sh |
| r28-f06f | a read-only subvolume in /home (the world's clean snapshot) never stops the split, and stays read-only; a smoke verifies after setup's last reboot | tests/engine/test_split.sh "a read-only subvolume inside /home" |
| r27-52-file r27-52-restore r27-52-restore-sf r27-52-R4-sf1 r27-52-pc | a file back, a backup back, the drive | tests/engine/test_menu.sh "the drive: its row's value" · tests/content/test_backup.sh "mount DIR: the backups opened read-only" |
| r27-found-2 r27-tools | tests leave no core dump, no shell probe left behind | tests/installer/test_report.sh "as you: the commands meant for your session" · tests/run.sh |
| r27-found-3 | a Fedora "out" only when it is out | tests/installer/test_upgrade.sh "Fedora 46 not out (its relea" |
| r27-found-4 r25-11a r26-13 r27-inst-1 r26-fu-10 r27-5 | a clean install really works | tests/installer/test_torture.sh "fedokawaii selftest on the finished install" · tools/vm-smoke.sh |
| r27-pkg-evidence | every package's evidence | tests/installer/test_torture.sh "tools/check-packages: the manifest clean" |
| r27-verify-dark | verify with the screens dark: no false alarm | tests/installer/test_verify.sh "every screen dark" |
| r25-13 | the scripts' look, one grammar | tests/installer/test_report.sh "the report is written, yours alone" · tests/installer/test_common.sh "retry" |
| r27-inst-4 r27-53-sc-tools r27-53-sc-style r27-53-ruff r27-53-ruff-done r27-inbox-2355a | the code to its standards: ShellCheck -S style, ruff | tests/static/test_syntax.sh "every shell file is clean for shellcheck -S style" · tests/static/test_syntax.sh "every Python file is clean for ruff" |
| r27-53-deadcode | no function left uncalled | tests/static/test_tools.sh "tools/deadcode.sh" |
| r27-53-rest | no early-stopping reader under pipefail | tests/static/test_pipefail.sh "no early-stopping reader" |
| r27-53-selftest r27-never-3 | selftest clean, and it runs these checks | tests/regress/test_wiring.sh "selftest runs the checks" |
| r27-never-1 r27-never-2 | every item here; all of it before a push | tests/regress/test_list.sh "the list is whole" · tests/regress/test_wiring.sh "prepush runs everything" |
| r27-leak r27-leak-2 r27-53-harness | no test or probe reaches his session | tests/regress/test_isolation.sh "a test cannot reach his session" · tests/installer/test_common.sh "the harness's guard" |
| r27-incident-kill | a scratch run can kill only its own | tests/regress/test_isolation.sh "a headless run is fenced" |
| r27-test-leftovers | the suite leaves nothing in /tmp | tests/regress/test_isolation.sh "a test leaves nothing behind" |
| r27-stray-scopes r27-53-scope | apply's live step leaves no stray scope | tests/installer/test_theme.sh "a live session: the running desktop reloads" |
| r27-rep-5a r27-rep-5b r27-rep-5c r26-12b r27-dec-14 | a perfectly clean system, one layout; a verify check finds strays | open T42: not begun |
| r26-12a r27-net-2 | ssh keys-only, on through a restart | tests/installer/test_setup.sh "phase 1: a quiet boot" · open T39: lane-network |
| r27-39-audit r27-net-1 r27-net-3 r27-net-4 r27-net-5 | network: default deny, every service bound, a port scan | open T39: lane-network |
| r27-away | heavy work waits until he is away | record: tools/away.sh, a tool of the round's own |
| r27-keep r27-vm-4 | ~/blasphemous-save-backup-20261022 kept | open T35: lane-asobi moves it into ASOBI's import folder |
| r24-19 r25-17 | the Learn book: long, Python and Rust by levels, exercises, the part on AI | tests/regress/test_counts.sh "the Learn book" |
| r27-dec-3a | the workspace stamps: a black numeral, fully inside the red circle, 1–9 | tools/regress/bar-geometry.sh · tests/session/test_dwlstatus.sh "1–3 always; 4–9 only while they hold" |
| r24-21 r27-bug-14 r27-vm-5a r27-vm-5b r27-vm-6 r27-vm-7 r27-vm-8 r27-vm-9 r27-vm-10 r27-vm-11 r27-vm-12 r27-vm-13 | Blasphemous, the Steam Deck question, the gaming VM | gone T32: the owner dropped the VM (4 Nov 17:38), ASOBI replaces it |
| r27-vm-2 r27-vm-3 | no gaming on his own account | open T35: lane-asobi removes it, tests/menus/test_steam.sh and test_game.sh go with it |
| r25-4 | the bar without boxes | gone T14: kami, then the r27 bar |
| r24-43 r24-44 r27-0 r27-loop r27-19n r27-19p r27-master-5-done r27-flaky-1 r27-53-flake-panel r27-53-flake-theme r27-rule-1 r27-inbox-2356 r27-run-1 r27-run-8 r27-run-9 r27-run-10 r27-run-11 | how the round is run | record: a standing rule or a piece of the round's work, no behaviour of its own |
| r27-also-1 | RAM preload | open T40: not begun |
| r27-dec-9a r27-dec-9b r27-dec-9c r27-dec-9d r27-dec-9e r27-dec-9f r27-dec-9g r27-dec-9h | the chess app | open T25c: lane-chess, its tests come with it |
| r27-dec-10a r27-dec-10b r27-dec-10c r27-dec-10d | the typing app | open T26c: lane-typing, its tests come with it |
| r27-dec-11a r27-dec-11b r27-dec-11c | the Learning section, the Guide PDF gone | open T27: lane-learning |
| r27-dec-12a r27-dec-12b r27-dec-12c r27-dec-12d | FireAlpaca | gone d2: the owner sketches on paper (S2, 6 Nov) |
| r27-dec-13a r27-dec-13b r27-dec-13c r27-rgb-1 r27-rgb-2 r27-rgb-3 | RGB, all in our red | open T36: lane-hardware |
| r27-mon-1 r27-mon-2 r27-mon-3 r27-mon-4 r27-mon-5 | the monitor | open T38: lane-hardware |
| r27-inbox-1826 | the refresh key | open T20r: not begun |
| r27-inst-2 | kernel and Fedora tuning, each measured | open T41: not begun |
| r27-inst-3 | neovim faster | open T30: lane-nvim |
| r27-iso-1 | ISO research | record: lane-research's digest |
| r27-iso-2 r27-iso-3 r27-iso-4 r27-iso-5 r27-iso-7 r27-iso-9 r27-iso-10 | the installer ISO | open T56: lane-iso |
| r27-iso-6 r27-iso-8 | the ISO proven and released | open T57: lane-iso |
| r27-rule-2 | his remote page keeps working through every change | manual: after an apply, open http://THE-PC:8737 with his token (fk-remote.service is his own, outside the repo) |
| r27-19q | his first design review: the prompt's head, the lantern, the plain Super+X, the hop, the strip, the lock's gate | tools/regress/lock-gate.sh · tests/content/test_shell.sh "foot: a new window's prompt" · tests/menus/test_panel.sh "the items, in order: the two levels" · open T19q: pack 2 with him |
| r27-19q-6-rail | the workspace move's rail, and rapid switching clean | tools/regress/rail.sh · tools/regress/bar-burst.sh |
| r27-19q-6-lacquer | the rail and the rod in lacquer; a switch takes each window's place at that moment | tools/regress/rail.sh |
| r27-kernel-oops | a kernel oops on the PC, its cause not established | record: an event of the PC's, RAM or memory pressure under the lanes' load |
| r27-19r | the clock to the minute; the band behind the bar gone again ("fully floating, no band, ever") | tests/session/test_glass.sh "on: " · tools/regress/bar-geometry.sh |
| r27-19r-2 | terminal words through the glass over the worst wallpaper pixel | tests/static/test_contrast.sh "tools/contrast.py: every pair" |
| r27-found-menu-cursor | a row's cursor whole, nothing left on the row it left | tools/regress/menu-cursor.sh |
| r27-found-open | Super+/ after any popup: its height follows the app, its middle stays | tools/regress/one-popup.sh |
| r27-found-start-dwl | a test's dwl beside the session stops no login | tests/session/test_startdwl.sh "a test's dwl beside it" |
| r27-found-vt-bar | the bar back after a VT switch | open T32: lane-asobi reproduces it, the cause not known yet |
| r27-manifest-flatpak | Flatpak only inside ASOBI, never removed by a repair | open T35: lane-asobi's branch has it |
| r27-regress-bugs | what the new checks found: the bar 1 px taller under a fallback face, a popup taking a window out of fullscreen | tools/regress/bar-titles.sh · tools/regress/popup-fullscreen.sh |
| r27-session-weight r27-vt-notes | tonight's session weight; wlroots' VT switch read | record: for tonight only (no lanes on the product); notes from the source |
| r27-run-2 | the research round | open T58: not begun |
| r27-run-5 | the whole suite, verify, the regression set, push | open T61: tools/prepush.sh is it |
| r27-run-6 | the round's finish | open T62: not begun |
| r27-run-7 r27-run-12 | the Learn book correct after every change | open T63: at his word |
| r27-20r | Super+Ctrl+R redraws the desktop from scratch, nothing of his lost, a hung bar or panel made new | tools/regress/refresh.sh |
| r27-flood | Helium's login: one hidden window, one starter, each press of its key one window | tools/regress/browser-login.sh |
| r27-sprint-1 | the clock keeps its seconds; a double switch leaves no window behind; floats roll up with their words | tests/session/test_bar.sh "the time: the clock and its menu's light" · tools/regress/float-exit.sh · tools/regress/rail.sh |
| r27-flips r27-freeze r27-session-cut r27-wedge | the night of 4 Nov: the wrong bits, the freeze, the session cut, PID 1 stuck | record: events and their findings; the RAM check itself is T59's (tools/ram-check.c) |
| r27-note-train | what the lanes brought keeps holding: the bar after the play world, the downloads' fill, the lessons' grid and cover, the editor's start, the power dialog, the saver's ways out, Torrents' and typing's windows at every size | tools/regress/bar-cycles.sh · tools/regress/downloads-fill.sh · tools/regress/downloads-tools.sh · tools/regress/learn-grid.sh · tools/regress/nvim-start.sh · tools/regress/power-dialog.sh · tools/regress/saver-dark.sh · tools/regress/saver-keys.sh · tools/regress/torrents.sh · tools/regress/typing.sh |
| r28-f06c | snapper's configs made and set without D-Bus: no SELinux denial at setup's end, the running daemon restarted | tests/installer/test_upkeep.sh "repair before setup's own end made the snapshot configs" · tools/vm-smoke.sh |
| r28-f06h | the first report waits for the first login however long, never holds the start, and is marked done only when it ended | tests/installer/test_report.sh "the first start: waits" · tests/installer/test_setup.sh · tools/vm-smoke.sh |
| r28-f06d | setup's lock lives in a small process: no child carries fd 9 (no SELinux denial on a domain change, no daemon keeps the lock), held through the run, free soon after | tests/installer/test_common.sh "take_lock: the lock lives in a small process" · tools/vm-smoke.sh |
| r28-f06i | a fresh install gets /home's snapper config before the first report; what the report starts in the session outlives it; --help answers in kawa-browser and kawa-stick; the report's rows follow the desktop | tests/installer/test_upkeep.sh "the first start on the flat layout" · tests/installer/test_setup.sh · tests/installer/test_report_rows.sh "DWL-08" · tests/content/test_stick.sh · tests/content/test_browser.sh |
| r28-f15b | a virtual keyboard gone (wtype: a click on a workspace in the bar) gives the seat the real keyboards' group back: a browser started by mouse right after does not segfault | tests/regress/test_dwl.sh "a virtual keyboard gone" |
| r28-f06j | the first report shows nothing on the first login (as --quick); BOOT-22 knows the split's start and a shutdown ending at the disks; RES-04 skips the report's own pipes; PERF-01 looks again while the machine settles | tests/installer/test_report.sh "the first start: waits" · tests/installer/test_report_rows.sh "BOOT-22" · tests/installer/test_report_rows.sh "RES-04" |
| r28-f19 | an old home's folders move to ~/downloads ~/captures ~/notes ~/books ~/dojo, nothing overwritten, what remembers a path follows; xdg-user-dirs set, no other folder made | tests/content/test_tidy.sh "your home's old folders" · tests/installer/test_verify.sh |
| r28-f20 | no script or config the desktop ships names an old home folder; only kawa-tidy and its table in lib/common.sh do | tests/static/test_home.sh |
| r28-d1 | the head is the Fedora logo, bloody in dark, lighty in light, in the bar, the prompt, fetch and the masthead; no old head on those surfaces | tests/static/test_heads.sh |
| r28-c1 | with the lights off the cooler's display is told it is out once a second, not every ten: left alone its firmware blinks a 99 | tests/status/test_rgb.sh |
| r28-d1c | no demon or angel in the typing hands, the boot splash or the ISO's crest and boot menu: a ronin's and a priest's hands; the head's own pixels on the splash (×8) and crest (×5); shiro behind the boot menu | tests/static/test_heads.sh · tests/content/test_typing.sh |
| r28-d2 | sketching gone: no FireAlpaca, no Sketch, no tablet in the desktop, dwl or the lessons | tests/regress/test_gone.sh "sketching stays gone" |
| r28-d2b | the to-do's heading wears its own tanzaku after d1's new icon numbers; the saver's scene built on the lock's art as it is | tests/content/test_notes.sh · tests/look/test_saver.sh |
| r28-f20b | xdg-user-dirs' Projects is the dojo, an old ~/Projects moves there | tests/static/test_home.sh "Projects is the dojo" |
| r28-f23 | his own neovim config: the lock is the handful and no more, every spec pinned, no word of LazyVim; start, Python servers, folds, first frame as before | tests/content/test_configs.sh "his own config, minimal" · tools/regress/nvim-start.sh |
| r28-f24b | neovim's font 2 px bigger while it runs, this window's alone, back on leave and suspend; the notes page not; refused sizes change nothing | tests/content/test_configs.sh "its font 2 px bigger" |
| r28-f24 | neovim's ground solid while it runs, see-through back on leave and suspend, both moods, after a theme switch; the notes page stays see-through; a transparency toggle leaves it solid, and it ends on the choice | tests/content/test_configs.sh "its ground solid while it runs" |
| r28-f25 | a daily lesson is one idea, one exercise, one check; a day one of each part, 25 to 30 minutes; anything else refused with its place; an answer's steps make its check pass; the record dated, today's pair waits, a missed day costs nothing | tests/content/test_lessons.sh "a lesson that is not one idea" · tests/content/test_lessons.sh "the days are held" · tests/content/test_lessons.sh "an answer's steps make its check pass" · tests/content/test_lessons.sh "today's pair" |
| r28-f26 | the Learning window is the day: today's pair, next told and not offered, how far; a check passed stamps, nothing else does; both moods, a single cell to the whole screen | tests/content/test_learn.sh "the day: today's pair" · tests/content/test_learn.sh "a run check" · tools/regress/learn-grid.sh |
| r28-sa13 | Super+U is ichimai: 88 × 15 cells (723 × 320 px), a two-line tab bar, no footer, the list 36 and its rows 33, the pane 13 rows; the status in three groups with paper between them where all fit, the routine lines making way first; a pane of several items shows two | tests/session/test_warm.sh "--renew clip system" · tests/engine/test_menu.sh "the tab bar, a heading over the list" · tests/engine/test_menu.sh "status, routine" · tests/engine/test_menu.sh "status at its fullest" · tests/engine/test_menu.sh "rows: the mark at the right edge" |
| r28-sa04 | the Part 1 lessons (days 29-33, 45, 46: ASOBI, Helium) are the pieces the book and the syllabus make; one id each, the front matter whole | tests/content/test_learn.sh "the pieces are what the book and the syllabus make, byte for byte" · tests/content/test_learn.sh "at least 120 lessons; every id once; each with its front matter; a name that fits the pane's heading" |
| r28-sa14 | Super+V's clipboard window is 88 columns, the menus' grid; bin/kawa-warm and bin/kawa-clip hold the same size | tests/session/test_warm.sh "--renew clip system (theme.sh, after an apply): one put away — its loop and its run ended, opened again put away at its size; one showing left as it is; the notes never" |
| r28-tr1 | the glass alpha is 0.99 with the glass on, both palettes, saved where foot.ini reads it | tests/session/test_glass.sh "on: 0.99 for both palettes, saved where foot.ini reads it" |
| r28-sa20 | Helium is mokuroku (his pick): tabs a list at the left, no collapse button, the address centred, the extensions' key shown; its new tab is the desktop extension's text screen, both moods in one page | tests/installer/test_theme_parts.sh "the browser's first start answered before it runs: GTK colours, mokuroku (tabs a list at the left, the address centred), square, its first-start page done, once; your choice afterwards stays" · tests/content/test_browser.sh "the desktop's small extension loaded, and the program it tells named in the profile, this home's path; none there: neither" |
| r28-sa20b | Helium's chrome in Sumi UI: a label with no parent is Sumi UI 14 px, labels in windows inherit (GTK apps keep their font) | tests/look/test_launcher.sh "Helium's chrome in Sumi UI (r28 sa20b)" |
| r28-sa15d2b | mako notices carry kanagu brass corners in both moods (kanagu-color in each theme's mako, drawn by src/mako/mako.patch) | tests/static/test_design_doc.sh "the contrast table (§1) is the measured one: APCA Lc" |
| r28-s12a | a heading's rule is waku (P1 4): the 1 px edge2 rail, brass stops and studs every 17 px in the kanagu inks, centred, at most 3 rows; section labels plain; none in the bar, notices, power menu | tests/menus/test_panel.sh "a heading's pixels: its icon (accent_text) in the icon column, its name (strong) from cell 3, the rule — waku (P1 4, S12): the 1 px edge2 rail on the row's row 10, a brass stop at each end, a stud every 17 px, centred — to the content's edge (8 px before a value, muted, at its end)" |
| r28-s12c | quick settings' gear on the bar: still at rest, four stepped poses while quick settings are open, the click its own; the head no click | tests/session/test_bar.sh "quick settings' gear (d4, tools/build-gear.py): still at rest, four poses 40 rows apart while open, stepped (no frame between), both moods" |
| r28-s12c2 | quick settings' row pictures: art pieces, `#` the state ink plus one second ink each (red only on) | manual: tools/panel-review.sh --only quick, both moods, looked at 4× (pixels by hand: no test reads art) |
| r28-s12d | a panel menu (kawa-panel) stays a scroll while open under a real scroll motion: dwl's two rods and silk round its frame, full from the unroll's last frame to the roll-up's (layermount, mounted in layeranims); a dialog (kawa-dialog) unrolls the same, no mount (its own rods) | tests/session/test_popups.sh "s12d: a menu stays a scroll while open (its rods and silk round it, mounted), a dialog draws its own" |
| r28-d5 | a status line in parts (Super+U): its lead text, what follows muted (asks stay text), the dots faint, two columns of air each side where it fits | tests/engine/test_menu.sh "status at its fullest: the routine lines make way (kernel, disk, release, support — in that order), never one asking for you" |
| r28-sa14b | Super+R's window is 88 × 29 (list 45 rows, add-picker rule 84, pane 36 kept) | tests/content/test_books.sh "Super+R: the floating window, once" |
| r28-sa15 | the panel dropdowns' highlights measured: 88 pairs, none under its threshold, both moods, 32 panels | tests/static/test_contrast.sh "tools/contrast.py: every pair at or over its threshold, both themes" |
| r28-sa15b2 | GTK 3/4 selected rows change colour on a transparent ground; words selected in a field keep the lacquer | tests/static/test_contrast.sh "every menu's selected row is a colour change on the ground" |
| r28-sa15d2a | kanagu brass corners on dwl windows: four scene buffers per window, art composed once per theme, brass from dwl.colors | tests/session/test_dwl_anim.sh "the picture composed as the scene draws it" |
| r28-sa20c | the noellipsis test skips the yubi pointer's pixel rows; a quoted row is never text | tests/static/test_noellipsis.sh "nothing asks a toolkit to ellipsize" |
| r28-sa25b4 | the bar's layout mark and the bare download mark drawn by their bar twins (20 px, Sumi Icons Bar); a 20 px spiral | tests/session/test_dwlstatus.sh "each of dwl's layout symbols as its pixel icon" · tests/status/test_downloads.sh "the mark: the percent of all" |
| r28-sa27-omori | his pick c-2 omori is dwl's scroll motion: a menu, panel, dialog and warm window unroll as a weight falling and bouncing (460 ms), pulled up gathering speed (240); config.def.h keeps the rod | tests/session/test_dwl_anim.sh "a scroll's motion is one switch: omori (his pick c-2), the rod, kakejiku and makimono a word away, all four sites by one ease; a scroll put away mid-way goes from where it is" |
| r28-sa28-mozaiku | his pick a-5 mozaiku is dwl's window motion: a window opens as a Super Famicom mosaic refining (300 ms) and closes the reverse (220); config.def.h keeps the hop | tests/session/test_dwl_anim.sh "a window's motion is one switch: mozaiku (his pick a-5), the hop, seal, shoji, kasumi and the others a word away; shoji cuts whole pixels, kasumi uses the dissolve's cells" |
| r28-sa29-heya | his pick b-4 heya is dwl's workspace move: the next room slides in wall to wall, one speed, no rail (360 ms, no wave); config.def.h keeps the strip | tests/session/test_dwl_anim.sh "a workspace's motion is one switch: heya (his pick b-4), the strip, hayate, the scroll, the doors and the others a word away; the doors part over the next room, nothing crossing" |
| r28-sb01 | the dojo: a rootless podman box that sees only ~/dojo (no caps, capped, localhost ports), run/shell/db/doctor/reset/wipe; reset and wipe never delete without cause | tests/content/test_dojo.sh "the box: one bind mount (~/dojo, relabelled), no caps, no new privileges, caps, localhost ports" · tests/content/test_dojo.sh "wipe: asks; anything but wipe deletes nothing; reset leaves the files" |
| r28-sb02 | the lesson standard 2: every section in its order, two hints, three levels, three questions, terms one meaning, keys as keycaps, reading a third of the minutes | tests/content/test_lessons.sh "standard 2: a lesson of every part is read, its parts come through, its terms make the glossary" · tests/content/test_lessons.sh "standard 2: what breaks the standard is refused, with why" |
| r28-sb03 | the spaced daily review core: cards due 1, 3, 7, 14 days after the last right answer, a wrong one back next day, learned after 3 right answers on different days, 5 cards interleaved, streak, quiet rank, week look back | tests/content/test_review.sh |
| r28-sb03b | kawa-learn review screens: r review (y/n into the record), m concept map, a week + rank, e explain-it-back note, corner line, nothing over the edge when resized | tests/content/test_learn_review.sh |
| r28-sb02b | the calm lesson page: one offline file, the standard's order, keycaps, step pictures on a click or key, reduced motion, both moods WCAG AA measured by the build; kawa-learn --page opens it in Helium | tests/content/test_lessons.sh "standard 2's page (sb02b): one offline file, every section in order, keycaps, step pictures, both moods measured" · tests/content/test_learn.sh "as a page (sb02b): a standard-2 lesson written offline with the theme's sheet and given to Helium; a standard-1 one said" |
| r28-sb04 | lessons days 1-3 on standard 2; every standard-2 lesson's example runs and prints exactly its ```output | tests/content/test_lessons_course.sh "every lesson's check, in the syllabus order" · tests/content/test_lessons_course.sh "a broken lesson is caught: a check that already passes, a need not taught yet, a day too long, an example that prints otherwise" |
| r28-sa20d | the regress list kept whole: a row for every r28 id | record: housekeeping of this file (tools/regress/items.py check) |
