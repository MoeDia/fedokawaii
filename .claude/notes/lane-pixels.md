# lane-pixels — menus and panels to the pixel (owner 18:03; feedback.md)
Started 18:12, 4 Nov. Done by 21:30.

## Plan
1. Foundation: select = 12 % tint + 2 px edge (RIGHT); row grammar; keycaps; seals; panel-art pictures
2. Quick settings, power dialog
3. Calendar, timer, sound, downloads, help
4. Critical notice, Super+U (value insets, 16 px tabs, footer, fit)
5. Tests, design-system.md, renders 1x + 4x into .claude/review/next/, three critique passes

## Status
(see below, updated as each part lands)

## OWNER 18:45 — RGB: SOLID, NOT BREATHING
The GPU's RGB cannot stay in sync, so no breathing or any animation across devices. Instead:
- ONE steady red on every device (fans, hub, cooler, GPU logo, K617), calibrated per device so they LOOK identical (each brand renders red differently; the GPU drifts orange or pink): a per-device colour value, then one question on his page to confirm the match by eye.
- Event-driven instead of animated: lock screen → fade to about 30 %; screens off or sleep → off; unlock or wake → full.
- The quick-settings switch (rgb on/off for everything, remembered across reboots) as asked at 18:39.

## OWNER 18:49 — MORE LOVE FOR QUICK SETTINGS (Super+X)
He wants quick settings to be a small masterpiece, not a plain list. Keep it a menu (no circle), but:
- a header with character: the mood's head (lane-ink's ink version at menu size) beside "quick settings", drawn into a little title plate
- the two meters as real instruments at the top, with numbers: brightness as the lantern's glow filling, volume as segments; the same ramp as every meter
- on/off drawn as small hanko seals (inked = on, blank = off) instead of the words
- small section labels in muted ink (screen · sound · connect · capture · power) with even rhythm between sections
- the new rows: RGB (all lights on/off, from lane-hardware) and share sound (from lane-browser)
- every action row shows its key at the right as a keycap; the selected row uses the highlight RIGHT (2 px edge + tint)
- hover/selected/pressed states drawn, the unroll motion kept, both moods, every gap measured; render it at 1x and 4x into .claude/review/next/ for his verdict

## OWNER 19:12 — THE DEMON AND ANGEL ICONS: NO PIXEL ART EITHER
His words: "same for the icons: drop this pixelated act for the demon/angel icons — keep pixel art for everything else — just for the lockscreen, the bar and the terminal icons, keep it super serious."
- ONE character everywhere: every demon/angel icon is derived from lane-ink's lock painting (the same Hannya face, the same angel), never a separate drawing.
- fetch (~300 px sixel): the full engraved ink portrait.
- quick settings and menus (48-56 px): the same face, smooth anti-aliased reduction (no pixel snapping), hand-sharpened and retouched at that size.
- the bar (21 px PNG): a tight face crop, smooth and high-contrast, retouched by hand to read like a tiny engraved coin or seal; state images (demon roar / angel eyes open) from the painting's own states.
- the terminal prompt (a font glyph, one cell line high, one colour only): a hand-drawn two-ink woodcut reduction of the same face (the only size without shading, because a glyph is one colour), in the shu (demon) / sumi (angel) ink; the failed-command state too.
- Everything else in the UI stays pixel art. Render every size side by side at 1x and 4x into .claude/review/next/ for his verdict, then wire them in (bar, prompt font, fetch, quick settings, menus).
- Ownership: lane-ink makes all sizes; lane-pixels uses the 48-56 px one in quick settings; main wires the bar, the prompt font and fetch.
