# grill-r27 — the side-by-side audit (T17)

Every surface shot headless on the real GPU in both themes (`bash tools/gallery.sh --bin bin
--repo-art`: 27 surfaces — the bar, the launcher and a sum in it, quick settings, sound,
brightness, do-not-disturb, calendar, timer, drives, downloads, power, Super+/, the level
display, a notice and a critical one, Super+U, the clipboard, Super+W, books, the file
picker, the calculator, git, the terminal, yazi, btop, notes), dark | light sheets, grilled
against docs/design-system.md.

## Measured
- Geometry: every surface the same box in dark and light, 27 of 27 (a theme is inks, never
  geometry) — kept as `tools/regress/gallery-expect.json`; `tools/gallery.sh --check` holds a
  later build to it (the calendar's height and the power menu's width follow the month and the
  uptime: their place only).
- Dropdowns hang from y 33 (the bar's 27 rows and its air), the right-hand ones end at x 1913
  (hairline 1911, shadow 1912) — quick settings, sound, brightness, do-not-disturb, drives,
  downloads, notices alike; the calendar and the timer centred under the clock.
- The headless regress set (bar-geometry, window-frame, level-display, warm-exit, calendar-middle,
  menu-first-click, one-popup) holds on the repository's state.

## Found and fixed
1. Super+/ typed into a field with a bare "> " before it; the launcher's field has none: the
   same bare field now (a prompt only where it carries words of its own — a size, an order, a
   passphrase's lock).
2. The file picker (yazi) still listed Enter and Esc on its last line and stood its heading's
   name a column further than every heading: its own keys only, name on column 3.
3. Super+U's status showed a setting's name — "not set up (BACKUP_TARGET)" — and so did the
   backup pane and the drive picker: "no drive · quick settings → backup", "your home, to the
   drive you chose", "it is remembered".
4. The kit shot the light theme on the dark root: a light surface's dark hairline vanished and
   the sheets misled — each theme's own ground now (swaybg), shots.py reads the ground from
   each shot. nvim had no plugins in the kit (the notes in nvim's default colours): its data
   linked, read only (checked: nothing written).
5. The calendar's middle half a pixel off the clock's: not a placement error but parity — the
   clock's scroll is odd (its kanji's 13 px of ink with equal sides), the calendar even (seven
   40 px days, six 8 px gaps); no layout makes both exact without a 1 px asymmetry elsewhere.
   The check now holds them within half a pixel (a real misplacement is a pixel or more).

## Seen, owned by later tasks (not left undone: each is in its task's approach)
- Notes: "~" end-of-buffer marks down the margin, the day's heading in markdown's green, the
  old footer grammar (path · saved as you go · super+n) → T21 (the lined notebook).
- Yazi's own view: a bare path for a heading, its status line → T22 (the whole UI rebuilt).
- The terminal's prompt → T24.
- Quick settings as a menu he loves, a monitor-off key → T17b (owner, 14:27).
- The lock, the greeter and the saver are not headless-shot here (gtklock and greetd need their
  own stage) → T20 shoots and grills them; the window ghosts and washes → T19.
- In the kit the brightness meter is empty (no DDC/CI monitor there); live it reads 40 %.

Nothing left for T17.
