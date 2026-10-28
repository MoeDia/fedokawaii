# Highlight contrast (T19k-2) — measurements, 2026-10-28

WCAG 2.x contrast ratio, (L1 + 0.05) / (L2 + 0.05), sRGB → linear. Palette from
tools/build-themes.py (P[mode]); surfaces rendered headless with tools/gallery.sh
(--only quick,system,launcher,clipboard → /dev/shm/r27t/gal, not kept).

## The selected row today (fzf's bg+ 16 = accent, fg+ 17 = text_on_accent, `:strip`)
| theme | fill | words | ratio |
|---|---|---|---|
| dark  | accent #eb5324 | text_on_accent #111314 | **5.14** (AA, not AAA; pure black would be 5.80 at most) |
| light | accent #a84222 | text_on_accent #f8f3d8 | 5.42 |

Looked at (gallery, 1×): in dark the bright vermilion bar with near-black words reads heavy and
the words dim — what the owner describes; in light the cream words on the deep red read clearly.
The two themes use opposite grammars for "selected" (dark words on bright red / light words on
deep red): one of the things to unify.

## Other pairs on the dark ground (#181715) and the soft fill (edge #2d251e)
text 10.00 / muted 5.15 / faint 2.58 / accent_text 4.94 on ground; on edge: text 8.40, muted
4.33, faint 2.17, accent 4.15 — faint is below 3:1 everywhere (quick settings' "off" labels and
values, e.g. "night light / off"); muted on the soft fill is just under 4.5. Light: muted on
edge 3.92, faint 2.05–2.51.

## Candidates for dark's selected row (fill → words, and the fill against the ground)
| fill | black | #111314 | cream #f8f3d8 | strong #f1e1b4 | fill vs ground |
|---|---|---|---|---|---|
| #eb5324 (today) | 5.80 | 5.14 | 3.24 | 2.79 | 4.94 |
| #a84222 (light's accent) | 3.47 | 3.08 | 5.42 | 4.66 | 2.96 |
| #9a3a1c | 3.00 | 2.66 | 6.28 | 5.40 | 2.56 |
| #8f3318 | 2.65 | 2.36 | **7.08** | 6.09 | 2.26 |
Direction to render and grill next: one grammar for both themes — cream words on a deep
lacquer red (dark ≈ #8f3318–#9a3a1c, light's #a84222 deepened toward 6.5+) — weighed against
the bright vermilion's 4.94 separation from the ground (a deep fill needs its 1 px frame or
the stitch to stand off a dark ground: WCAG 1.4.11 wants 3:1 for a component's edge).
Threshold for tools/contrast.py: 4.5 text/icons (7 for the selected row's words, the owner's
complaint), 3 for frames and large glyphs; faint is "not there yet" — decide per use whether it
is text (then ≥ 4.5) or decoration.
