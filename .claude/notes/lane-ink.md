# lane-ink — the demon and the angel, epic ink illustrations (owner 18:32)

Branch lane-ink, worktree ~/repos/fk-ink. Scratch: ~/.cache/r27-ink (candidates, sources, lab scripts),
/dev/shm/ink (working renders). Runtime: stable-diffusion.cpp master-1047-984eb06 Vulkan (official
release zip, ggml MIT) in ~/.local/share/fk-ink-sd/bin; models in ~/.local/share/fk-ink-sd/models:
FLUX.2-klein-4B Q8 (leejet GGUF, Apache-2.0), Qwen3-4B Q4_K_M (unsloth GGUF, Apache-2.0), flux2 VAE
(Comfy-Org/flux2-klein-4B, Apache-2.0), Z-Image-Turbo Q6 as a second opinion (Apache-2.0). GPU at nice
15 + ionice idle, weights mapped from disk (0.4 GB of anonymous RAM), a guard kills the job under memory
pressure. All of this is a tool of the lane, not of the product: nothing of it ships; delete when done.

## Status (newest first)
- 19:10 first candidates in: the generated route is very strong; masters route built (Hannya mask +
  engraver's filter, Schongauer's Gabriel + Hokusai's wave + Durer's clouds). Sheet next.

## What main must do to merge and apply
(filled in as it is built)

## Open questions
none yet

## OWNER 19:11 — THE LOCK: DROP THE PIXEL ART COMPLETELY
His words: "still not serious enough. DROP this whole pixelated act. Focus on the images I showed you, the torch idea, the style, the open and closed mouth, and the wall carvings. Super serious, super detailed, ancient, proper."
- The lock and its twin the greeter become a full-resolution 1920x1080 PAINTING, not pixel art, never upscaled pixels. Style = his two references: engraved ink / irezumi, fine hatching and cross-hatching, sculpted shading, aged paper, Renaissance depth with Japanese line.
- DARK: a Hannya at the centre, facing him, in engraved ink (horns, scrollwork on brow and cheeks, wild hair, staring eyes). Mouth states painted from the SAME face (inpaint only the mouth, so the identity never shifts): closed → open after the secret key → the bite on Enter (it eats the password) → in.
- LIGHT: a Renaissance winged angel in Japanese tattoo ink among Hokusai waves and sakura, indigo wash. Her states: scroll closed → unrolled after the secret key, each typed character a brush mark → rolled and sealed with a hanko on Enter → in.
- WALLS: ancient carved stone reliefs of demons and angels at war, in the same engraved technique, weathered and cracked, deep relief that reads at 1x.
- TORCHES: kept and painted, giving real light on stone, carvings and face; live in the lock: flame flicker, light that moves with it, rising embers, all as light layers over the painting.
- Serious and ancient: nothing cute, flat or empty; detail everywhere.
- Ownership: lane-ink paints the WHOLE lock artwork for both moods (figures, walls, carvings, torches, light layers) from public-domain masters and local generation as in its task, cleaned by hand into one style. lane-art stops lock work, hands over anything useful through its notes, and keeps the wallpapers. Main: the lock engine and the greeter show full-res painted layers (smooth scaling, never pixel scaling), the state images, and the animated light layers within the frame budget. lane-saver builds the saver from the same painting.
- Candidates on his page (.claude/review/next/) before finishing: both moods, every state.

## OWNER 19:12 — THE DEMON AND ANGEL ICONS: NO PIXEL ART EITHER
His words: "same for the icons: drop this pixelated act for the demon/angel icons — keep pixel art for everything else — just for the lockscreen, the bar and the terminal icons, keep it super serious."
- ONE character everywhere: every demon/angel icon is derived from lane-ink's lock painting (the same Hannya face, the same angel), never a separate drawing.
- fetch (~300 px sixel): the full engraved ink portrait.
- quick settings and menus (48-56 px): the same face, smooth anti-aliased reduction (no pixel snapping), hand-sharpened and retouched at that size.
- the bar (21 px PNG): a tight face crop, smooth and high-contrast, retouched by hand to read like a tiny engraved coin or seal; state images (demon roar / angel eyes open) from the painting's own states.
- the terminal prompt (a font glyph, one cell line high, one colour only): a hand-drawn two-ink woodcut reduction of the same face (the only size without shading, because a glyph is one colour), in the shu (demon) / sumi (angel) ink; the failed-command state too.
- Everything else in the UI stays pixel art. Render every size side by side at 1x and 4x into .claude/review/next/ for his verdict, then wire them in (bar, prompt font, fetch, quick settings, menus).
- Ownership: lane-ink makes all sizes; lane-pixels uses the 48-56 px one in quick settings; main wires the bar, the prompt font and fetch.

## OWNER ANSWER 2026-11-04 19:16 — to your question «2026-11-04 19:13 — question from lane-ink»
do your rbst super serious try hard

## OWNER VERDICT 2026-11-04 19:19 on your render ink-M1-masters-demon.png: love
this is best for the lockscreen demon

## OWNER VERDICT 2026-11-04 19:19 on your render ink-M2-masters-angel.png: love
solid angel for the lockscrene

## OWNER VERDICT 2026-11-04 19:21 on your render ink-SD902-torchlit.png: love
[Claude, art direction while the owner is away 19:20-21:20; he asked me to keep the design coherent and true to his notes; his own verdicts win] THIS is the dark lock's direction: the torch-lit version (warm sepia glow, falloff into black) beats the flat ones by far. Take SD902-torchlit's face (moustache, scrollwork, samurai menace) as THE demon, with SD901's ferocity in the eyes. Next: (1) push it from "horned man" to HANNYA: horns rising from the forehead, brows knit upward in anguish, gold-ringed metallic eyes, pointed ears, a mouth that can open ear to ear; keep the scrollwork tattoo and the wild hair; (2) the mouth states inpainted on THIS face (closed, open, the bite) so the identity never shifts; (3) crop 1920x1088 to 1080 without cutting the horns; (4) the torches as separate light layers so the lock can flicker them; (5) keep the carved reliefs this dense and torch-lit.

## OWNER VERDICT 2026-11-04 19:21 on your render ink-SD901-torchlit.png: ok
[Claude, art direction while the owner is away 19:20-21:20; he asked me to keep the design coherent and true to his notes; his own verdicts win] Strong, but SD902-torchlit's face wins; keep this one's eye intensity and its wall (the angels-vs-demons reliefs read best here).

## OWNER VERDICT 2026-11-04 19:21 on your render ink-SD901.png: change
[Claude, art direction while the owner is away 19:20-21:20; he asked me to keep the design coherent and true to his notes; his own verdicts win] Without the torch glow it is flat: every dark candidate must be torch-lit.

## OWNER VERDICT 2026-11-04 19:21 on your render ink-LA2.png: love
[Claude, art direction while the owner is away 19:20-21:20; he asked me to keep the design coherent and true to his notes; his own verdicts win] The right base for the LIGHT lock: winged angel, Hokusai waves in indigo, gold halo, sakura, engraved ink. Next: (1) a more beautiful Renaissance face (Botticelli / Raphael grace), a gentle turn of the head instead of the stiff frontal pose; (2) she holds the sutra scroll clearly, for the scroll states (closed, unrolled, sealed) inpainted on THIS figure; (3) the owner keeps the torch idea in both moods: in light, two hanging lanterns or torches with warm light on her and the clouds; (4) carved stone or wood reliefs at the edges (angels vs demons) so both locks share the wall-carving idea; (5) fill the frame edge to edge, no plain sky.

## OWNER VERDICT 2026-11-04 19:21 on your render ink-LD3.png: love
[Claude, art direction while the owner is away 19:20-21:20; he asked me to keep the design coherent and true to his notes; his own verdicts win] The right base for FETCH and the ICONS: a high-contrast demon on paper with flame scrollwork. Derive fetch (~300 px), quick settings (48-56 px), the bar (21 px coin/seal crop) and the prompt woodcut glyph from the CHOSEN lock face (SD902-torchlit pushed to Hannya), in this paper-and-ink treatment, so lock and icons are one character. Do the angel the same way from LA2.

## OWNER VERDICT 2026-11-04 19:25 on your render ink-SD902-torchlit.png: love
OWNER'S CHOICE (he said it to Claude in chat at 19:25, relayed): "for the demon I want THIS". SD902-torchlit is the demon MASTER for the lock and every icon. "Manipulate it properly, make it fit, adjust whatever you need": crop to 1920x1080 keeping the horns, clean artefacts by hand, make the torches separate light layers for the flicker, paint the mouth states (closed, open, the bite) on THIS face by inpainting only the mouth, and derive fetch, quick settings, the bar coin and the prompt woodcut from this face. Keep its look: torch-lit sepia, tattoo scrollwork, wild hair, the carved angels-vs-demons wall.

## OWNER VERDICT 2026-11-04 19:25 on your render ink-LA2.png: love
OWNER'S CHOICE (he said it to Claude in chat at 19:25, relayed): "for the angel I want THIS". LA2 is the angel MASTER for the light lock and every light icon. Make it fit and adjust as needed: 1920x1080 edge to edge, clean artefacts, the scroll states (closed, unrolled with brush marks, sealed with a hanko) inpainted on THIS figure, warm lantern or torch light added at both sides to rhyme with the dark lock, and the light icons derived from this face. Keep its look: engraved ink, indigo Hokusai waves, gold halo, sakura.

## OWNER VERDICT 2026-11-04 19:26 on your render ink-M1-masters-demon.png: love
CORRECTION of my 19:25 relay (Claude): the owner's "for the demon I want THIS and for the angel THIS" meant the two images he sent right after, which are YOUR public-domain masters: ink-M1-masters-demon (the engraved Hannya mask with the long ringed horns and wild hair) and ink-M2-masters-angel (the Renaissance engraved angel with the banderole and halo above Hokusai's waves and sakura). THESE are the masters, not SD902/LA2. His words: "manipulate those properly, make them fit, adjust whatever you need, you have the reference."
DEMON (lock, greeter, every icon) from M1: keep the engraved Hannya mask exactly as the character. Build the 1920x1080 lock around it: the torch-lit carved hall of SD902-torchlit (stone reliefs of angels and demons at war, two torches, warm sepia light falling into black) is now only the SETTING and LIGHTING reference: re-render or paint that setting in M1's engraved line so figure and wall are one technique; light the mask from the torches (warm glints on the horns and lacquer). Mouth states on THIS mask: M1's mouth is open, so paint the closed state and the bite by editing only the jaw. Derive fetch, quick settings, the bar coin and the prompt woodcut from M1 (it is already high-contrast ink on paper: ideal for small sizes).

## OWNER VERDICT 2026-11-04 19:26 on your render ink-M2-masters-angel.png: love
CORRECTION of my 19:25 relay (Claude): the owner's "for the demon I want THIS and for the angel THIS" meant the two images he sent right after, which are YOUR public-domain masters: ink-M1-masters-demon (the engraved Hannya mask with the long ringed horns and wild hair) and ink-M2-masters-angel (the Renaissance engraved angel with the banderole and halo above Hokusai's waves and sakura). THESE are the masters, not SD902/LA2. His words: "manipulate those properly, make them fit, adjust whatever you need, you have the reference."
ANGEL (light lock, light icons) from M2: keep the engraved Renaissance angel as the character. Fix the composite: the clouds are cut-out patches and the waves' edges are pasted: redraw them as one continuous scene in the same engraved line with the indigo wash, fill the 1920x1080 frame edge to edge (no empty paper), the banderole she holds IS the scroll: closed → unfurled with each typed character as a brush mark → rolled and sealed with a hanko on Enter; add warm lanterns or torches at both sides to rhyme with the dark lock; derive the light icons from her face.

## OWNER VERDICT 2026-11-04 19:26 on your render ink-SD902-torchlit.png: ok
CORRECTION of my 19:25 relay (Claude): the owner's "for the demon I want THIS and for the angel THIS" meant the two images he sent right after, which are YOUR public-domain masters: ink-M1-masters-demon (the engraved Hannya mask with the long ringed horns and wild hair) and ink-M2-masters-angel (the Renaissance engraved angel with the banderole and halo above Hokusai's waves and sakura). THESE are the masters, not SD902/LA2. His words: "manipulate those properly, make them fit, adjust whatever you need, you have the reference." SD902-torchlit stays only as the setting and lighting reference for M1.

## OWNER VERDICT 2026-11-04 19:26 on your render ink-LA2.png: ok
CORRECTION of my 19:25 relay (Claude): the owner's "for the demon I want THIS and for the angel THIS" meant the two images he sent right after, which are YOUR public-domain masters: ink-M1-masters-demon (the engraved Hannya mask with the long ringed horns and wild hair) and ink-M2-masters-angel (the Renaissance engraved angel with the banderole and halo above Hokusai's waves and sakura). THESE are the masters, not SD902/LA2. His words: "manipulate those properly, make them fit, adjust whatever you need, you have the reference." LA2 stays only as a composition reference (full frame, waves both sides) for M2.
