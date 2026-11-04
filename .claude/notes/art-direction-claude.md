# Art direction — Claude (chat), at the owner's request 4 Nov 17:18
Owner said: "be a masterful artist, go DEEP". This is an outside critique of review pack 1, seen at 1x.
The owner's own verdicts on his page ALWAYS override this. It does not replace his answers to T19p.

## 0. The law: one world
One ink set per mood (dark: sumi, bone, shu/vermilion, gold; light: kinari paper, sumi, gold, shu).
One key line (1 px sumi), one character sheet, one ground, one gap scale. Ukiyo-e logic: a key block + few colour blocks.
Kamon logic for every crest/icon: one grid, one stroke weight, symmetric where possible, never touching its frame (ma).

## 1. The two heads: ONE character sheet (lane-art)
Today: 3 different oni (bar crest 00b, fetch 00a/01, quick-settings Hannya 05) and 2 different Kannon. Pick the quick-settings pair as the master design (most refined).
Hand-pixel (never downscale) every size from it: prompt (line height), bar tile, 32, 48 (quick settings), fetch (~96-128), lock references.
Oni: Hannya/Kyosai references — brows, cheek folds, nostrils, tusks, gold horns, bone teeth, 3-value shu ramp; the current fetch oni (square jaw, block eyes) reads as a jack-o-lantern: replace.
Kannon: gofun face, sumi hair with ushnisha, red urna and lips, half-closed eyes, gold nimbus as a ring (not stepped blocks).
Bar crest: horns clipped at the top, nimbus clipped at the bottom, head edge-to-edge in the tile → keep >= 2 px of ma inside the tile at 1x.
States drawn at EVERY size: oni calm/roar, Kannon closed/open eyes. Doc: docs/art/heads.md with all sizes side by side at 1x and 4x.

## 2. The bar needs a ground (main)
The tiles float on the wallpaper: on busy art (02, the live strip; 01, the flames behind the workspace tiles) it is chaos.
Give it a band: the mood's paper/sumi, opaque or >= 90%, 1 px hairline below; the tiles become insets in it.
One gap inside a group (4 px), one between groups (12 px), written in the design system; today the head's gap differs from the rest.
The date: drop the seconds (a ticking digit pulls the eye all day); one format, one clock style everywhere.
Workspaces (torii, red disc, 二, 三): write down the rule (active = hinomaru stamp?) or make them 一 二 三 consistently.

## 3. Windows over the wallpaper (main)
Translucent terminals let high-contrast art run behind text (01: the figure behind the left terminal; light: line work behind yazi).
Make windows opaque (or >= 0.96) and let the art live in gaps, empty workspaces and the lock.
Measure body-text contrast against the WORST composited pixel, target >= 7:1.

## 4. Wallpapers (lane-art)
The sepia + vermilion three-tone dark set is the strongest thing in the pack: keep the grain. Make the light set obey the same three-ink rule.
Remove what is left of cartouches, seals and poem cards (third row: the first and last pictures still carry text columns).
Remove triptych seams (vertical lines in row 1 #1, row 2 #2 and #3).
Top 40 px of every picture calm (it sits under the bar); the subject in the centre for an empty workspace; no face cut by an edge.

## 5. Quick settings (main)
Geometry mixes a square (4 corner icons) and a circle (12 on a ring): choose one — all on one circle at equal angles, or a ring plus 4 fixed corners drawn as a deliberate frame.
The dotted arc is open at top and bottom and its meaning is not shown.
A caption line under the head names the focused crest and its state (e.g. Bluetooth · off): today nothing is labelled.
Icons: one grid, one stroke, one optical size (camera outline vs picture filled vs monitor busy today). Active = shu fill, idle = sumi line.

## 6. Super+U (main)
The bottom third of tab 1 is empty: fit the height or use it. The left list has no heading rule while the right column has one: mirror them.
Four tabs are icon-only: show the word on focus. Check that the one update item is where the owner decided it is.

## 7. The highlight band (owner decides, T19p q3)
Offer him two drawn options side by side: a full shu band, or a 2 px shu edge + a 12 % shu tint. Measure both for contrast.

## 8. Lock (lane-art)
Dark is the best piece. The wall is western bricks fading as a soft blob: make it ishigaki (irregular castle stones) or carved temple wood (owner's "carved dungeon"), lit by the torches in 3 stepped pools of light, not a vignette.
Light: the roundel's figure is washed watercolour with yellow blotches, another technique than the dark roundel's clean print: redo it from a cleaner source in the three-ink rule.
Clouds: true suyari-gasumi (gold mist bands, rounded ends, an inner line, sparing kirikane dots), not flat bars.

## 9. Method
Every surface: render at 1x, inspect at 1x and 3-4x, beside its reference plate; a measurements table per surface; three looks before showing him.
