#!/usr/bin/env python3
"""tools/prompt-options.py — the options for the prompt with the head inside its ribbon (r28 f10):
rendered by real foot in the kit, from a throw-away font of the options' edge glyphs.

    python3 tools/prompt-options.py gen DIR       # DIR/font/KawaPromptTry.ttf, DIR/mock-{dark,light}.sh
    python3 tools/prompt-options.py sheet DIR OUT # DIR/{dark,light}/tui.png → the sheet, a JPEG
"""
import importlib.util
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
W, H = 8, 20                       # the terminal's cell
COLS, ROWS, PAD = 66, 20, 8         # the mock's window, foot's padding
OPTIONS = ("now", "tanzaku", "obi", "rakkan")
TRY = 0xFD000                      # a range of the options' own, clear of Sumi Icons Term's


def cell(fn):
    """A 20-row glyph: fn(x, y) says which pixels are the foreground's."""
    return ["".join("#" if fn(x, y) else "." for x in range(W)) for y in range(H)]


def vee(y, depth):                 # how far a swallowtail's notch reaches at row y
    return round(depth * (1 - abs(y - 9.5) / 9.5))


BITES = (0, 0, 1, 0, 0, 0, 0, 2, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0)  # a carved seal's edge, by hand

GLYPHS = {
    # 1 tanzaku: a poem slip's straight cuts, the corners eased, a hairline between papers
    "try-t-start": cell(lambda x, y: x >= (2 if y in (0, 19) else 1 if y in (1, 18) else 0)),
    "try-t-end": cell(lambda x, y: x <= 7 - (2 if y in (0, 19) else 1 if y in (1, 18) else 0)),
    "try-t-join": cell(lambda x, y: x == 7),
    # 2 obi: a silk band, swallowtail ends, each paper folded over the next on a slant
    "try-o-start": cell(lambda x, y: x >= vee(y, 7)),
    "try-o-end": cell(lambda x, y: x <= 7 - vee(y, 7)),
    "try-o-fold": cell(lambda x, y: x <= round(7 * (19 - y) / 19)),
    # 3 rakkan: the head a red seal set in the band, its edge carved; the papers meet plainly (no glyph)
    "try-r-start": cell(lambda x, y: x >= (1 if y in (0, 19) else 0) + BITES[19 - y]),
    "try-r-end": cell(lambda x, y: x <= 7 - BITES[y] - (1 if y in (0, 19) else 0)),
}


def build_icons():
    spec = importlib.util.spec_from_file_location("build_icons", ROOT / "tools/build-icons.py")
    mod = importlib.util.module_from_spec(spec)
    sys.dont_write_bytecode = True
    spec.loader.exec_module(mod)
    return mod


def gen(out):
    mod = build_icons()
    (out / "font").mkdir(parents=True, exist_ok=True)
    text = "".join(f"@{n} adv=8 x=0\n" + "\n".join(r) + "\n\n" for n, r in GLYPHS.items())
    icons = mod.parse(text)
    for i, ic in enumerate(icons):
        ic["code"] = TRY + i
    mod.build(icons, out / "font/KawaPromptTry.ttf", "Kawa Prompt Try", mod.TERM_RAISE, mod.TERM_CELL,
              mod.TERM_UPM, mod.TERM_ASC, mod.TERM_DESC)
    # The mock draws one codepoint per glyph; a shell variable for each
    defs = "".join(f"{ic['name'][4:].replace('-', '_')}=$'\\U{ic['code']:08x}'\n" for ic in icons)
    for mood in ("dark", "light"):
        (out / f"mock-{mood}.sh").write_text(f"#!/usr/bin/env bash\nMOOD={mood}\n" + defs
                                             + (ROOT / "tools/prompt-options.mock").read_text())


def sheet(src, jpg):
    from PIL import Image, ImageChops
    crops = []
    for mood in ("dark", "light"):
        im = Image.open(src / mood / "tui.png").convert("RGB")
        ground = im.getpixel((4, im.height - 4))
        diff = ImageChops.difference(im, Image.new("RGB", im.size, ground))
        x0, y0, _, _ = diff.crop((0, 40, *im.size)).getbbox()    # the window's frame, under the bar
        y0 += 40
        crops.append(im.crop((x0 + 1, y0 + 1, x0 + 1 + PAD * 2 + COLS * W, y0 + 1 + PAD * 2 + ROWS * H)))
    w, h = crops[0].size
    zoom_w = w // 2                                              # the band's start, twice over
    out = Image.new("RGB", (w * 2 + 4, h + 4 + len(OPTIONS) * (3 * H * 2 + 4)), (0, 0, 0))
    for i, c in enumerate(crops):
        out.paste(c, (i * (w + 4), 0))
        for k in range(len(OPTIONS)):
            top = PAD + (k * 5 + 1) * H
            strip = c.crop((0, top, zoom_w, top + 3 * H)).resize((w, 6 * H), Image.NEAREST)
            out.paste(strip, (i * (w + 4), h + 4 + k * (6 * H + 4)))
    out.save(jpg, quality=88, subsampling=0, optimize=True)
    print(jpg, out.size, pathlib.Path(jpg).stat().st_size)


if __name__ == "__main__":
    if sys.argv[1] == "gen":
        gen(pathlib.Path(sys.argv[2]))
    else:
        sheet(pathlib.Path(sys.argv[2]), sys.argv[3])
