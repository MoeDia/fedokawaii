#!/usr/bin/env python3
"""tools/wada-palette.py — the two themes' palettes, built from Sanzo Wada's colours (A Dictionary of
Color Combinations, 1933–34): every token a Wada colour, or a stated mix of two in OKLab. Nothing
else: no colour is written here that is not a Wada swatch or a mix of two.

  python3 -I tools/wada-palette.py [--sheet OUT.png] [--palette OUT.py] [--table] [--doc]

--table: each text role's contrast (WCAG) on each ground, both themes; --doc: the token rows of
docs/design-system.md §1 (hex and recipe); --sheet: the swatches with
their names and recipes; --palette: a file for tools/build-themes.py --palette (P, KAMI, TILE).
The colours: the dataset github.com/mattdesl/dictionary-of-colour-combinations (MIT, © 2020 Matt
DesLauriers, after Dain M. Blodorn Kim's) — only the swatches used are copied below.
"""
import sys

W = {   # Wada's swatches used here: name → hex (colors.json, 2026-10-27)
    "Black": "111314", "Vandyke Brown": "4b3317", "Pale Raw Umber": "71502f", "Light Brownish Olive": "806e4b",
    "Deep Grayish Olive": "635a3a", "Ecru": "c2ae93", "Ivory Buff": "ebd3a2", "Sulpher Yellow": "f5ecc2",
    "White": "ffffff", "Red Orange": "dd4027", "Jasper Red": "eb5324", "Vandyke Red": "82241f",
    "Apricot Orange": "f68c50", "Brick Red": "a84222", "Venice Green": "62c6bf", "Benzol Green": "00978d",
    "Light Porcelain Green": "00908a", "Dusky Green": "004f46", "Rainette Green": "8fa071",
    "Yellow Ocher": "e2b540", "Isabella Color": "c5a56e", "Olympic Blue": "5a82b3", "Salvia Blue": "97acc8",
    "Light Mauve": "9a72aa", "Coral Red": "f58e84", "Cobalt Green": "96d1aa", "Naples Yellow": "fbe6a0",
    "Pale King's Blue": "a7d4e4", "Grayish Lavender - A": "b5b1d8", "Deep Slate Green": "112f2c",
    "Cossack Green": "437742", "Orange Citrine": "986f2d", "Blue": "006eb8", "Dark Soft Violet": "66629c",
    "Diamine Green": "1a7444", "Sepia": "644b1e", "Helvetia Blue": "005b8d", "Violet": "4f4086",
    "Vandar Poel's Blue": "064f6e", "Neutral Gray": "b6bfc1", "Khaki": "bc892b", "Maple": "c59f6b",
}


# ── OKLab (Björn Ottosson): mixing where the eye sees it ─────────────────────────────────────
def _lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def _gam(c):
    c = max(0.0, min(1.0, c))
    return 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055


def to_lab(h):
    r, g, b = (_lin(int(h[i:i + 2], 16) / 255) for i in (0, 2, 4))
    l = (0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b) ** (1 / 3)
    m = (0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b) ** (1 / 3)
    s = (0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b) ** (1 / 3)
    return (0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
            1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
            0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)


def from_lab(L, a, b):
    l = (L + 0.3963377774 * a + 0.2158037573 * b) ** 3
    m = (L - 0.1055613458 * a - 0.0638541728 * b) ** 3
    s = (L - 0.0894841775 * a - 1.2914855480 * b) ** 3
    r = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
    g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
    bb = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
    return "".join(f"{round(_gam(c) * 255):02x}" for c in (r, g, bb))


RECIPE = {}


def mix(a, b, t, role=None):
    """a toward b by t (0 = a, 1 = b), in OKLab; a and b are Wada names or earlier mixes."""
    ha, hb = W.get(a, a), W.get(b, b)
    la, lb = to_lab(ha), to_lab(hb)
    out = from_lab(*(x + (y - x) * t for x, y in zip(la, lb)))
    if role:
        RECIPE[role] = f"{a} → {b} {t:g}"
    return out


def w(name, role=None):
    if role:
        RECIPE[role] = name
    return W[name]


def lum(h):
    r, g, b = (_lin(int(h[i:i + 2], 16) / 255) for i in (0, 2, 4))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a, b):
    la, lb = sorted((lum(a), lum(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


# ── the dark theme: 鬼 the demon's — sumi ink, a torchlit dungeon's stone, the vermilion seal ──
def dark():
    p = {}
    p["lo"] = w("Black", "dark.lo")
    p["ground"] = mix("Black", "Vandyke Brown", 0.13, "dark.ground")
    p["surface"] = mix("Black", "Vandyke Brown", 0.20, "dark.surface")
    p["view"] = p["surface"]
    p["key"] = mix("Black", "Pale Raw Umber", 0.20, "dark.key")
    p["edge"] = mix("Black", "Pale Raw Umber", 0.32, "dark.edge")
    p["edge2"] = mix("Black", "Pale Raw Umber", 0.48, "dark.edge2")
    p["hi"] = mix("Black", "Pale Raw Umber", 0.62, "dark.hi")
    p["faint"] = mix("Light Brownish Olive", "Black", 0.22, "dark.faint")
    p["muted"] = mix("Light Brownish Olive", "Ecru", 0.40, "dark.muted")
    p["text"] = mix("Ecru", "Ivory Buff", 0.45, "dark.text")
    p["strong"] = mix("Ivory Buff", "Sulpher Yellow", 0.55, "dark.strong")
    p["accent"] = w("Jasper Red", "dark.accent")        # (Red Orange's fill held ink at 4.3 : 1 only)
    p["accent_hi"] = mix("Jasper Red", "Apricot Orange", 0.5, "dark.accent_hi")
    p["accent_lo"] = w("Vandyke Red", "dark.accent_lo")
    p["accent_text"] = w("Jasper Red", "dark.accent_text")
    p["text_on_accent"] = p["lo"]                 # (Wada's Black on the vermilion: 4.5 : 1 and over)
    # what is selected — a menu's row under the cursor, quick settings' item, GTK's and Qt's
    # selection: the same deep lacquer in both themes (漆, one grammar), the strongest cream on it
    # (7.3 : 1; the vermilion held black words at 5.1 only — the owner's 19:19 complaint)
    p["select"] = w("Vandyke Red", "dark.select")
    p["text_on_select"] = p["strong"]
    p["select_lo"] = mix("Vandyke Red", p["text_on_select"], 0.3, "dark.select_lo")   # (unlit: 3.7 : 1 under the lit)
    p["lit"], p["lit_text"], p["lit_hi"], p["lit_lo"] = p["text"], p["ground"], p["strong"], p["muted"]
    p["urgent_text"] = p["lo"]
    p["asagi"] = mix("Venice Green", "Ecru", 0.25, "dark.asagi")
    p["flame"] = w("Apricot Orange", "dark.flame")
    p["gold"] = w("Isabella Color", "dark.gold")
    p["red"], p["green"], p["yellow"] = w("Jasper Red"), w("Rainette Green"), w("Yellow Ocher")
    p["blue"], p["purple"], p["teal"] = w("Salvia Blue"), w("Light Mauve"), w("Benzol Green")
    p["bred"], p["bgreen"], p["byellow"] = w("Coral Red"), w("Cobalt Green"), w("Naples Yellow")
    p["bblue"], p["bpurple"], p["bteal"] = w("Pale King's Blue"), w("Grayish Lavender - A"), w("Venice Green")
    p["ansi0"], p["ansi7"], p["ansi8"], p["ansi15"] = p["edge"], p["text"], p["muted"], p["strong"]
    p.update(gtk="Fedokawaii-dark", base="adw-gtk3-dark", scheme="prefer-dark")
    return p


# ── the light theme: 天 the angel's — gold leaf on paper, a deep green ink, a softer seal ──────
def light():
    p = {}
    p["ground"] = mix("Sulpher Yellow", "Neutral Gray", 0.20, "light.ground")
    p["surface"] = mix("Sulpher Yellow", "Isabella Color", 0.18, "light.surface")
    p["view"] = mix("Sulpher Yellow", "White", 0.25, "light.view")
    p["key"] = mix("Sulpher Yellow", "White", 0.35, "light.key")
    p["hi"] = w("White", "light.hi")
    p["edge"] = mix("Sulpher Yellow", "Isabella Color", 0.45, "light.edge")
    p["edge2"] = mix("Sulpher Yellow", "Maple", 0.62, "light.edge2")
    p["lo"] = mix("Isabella Color", "Deep Slate Green", 0.25, "light.lo")
    p["text"] = mix("Deep Slate Green", "Black", 0.30, "light.text")
    p["strong"] = mix("Deep Slate Green", "Black", 0.70, "light.strong")
    p["faint"] = mix(p["text"], p["ground"], 0.60, "light.faint")
    p["muted"] = mix(p["text"], p["ground"], 0.36, "light.muted")
    p["accent"] = w("Brick Red", "light.accent")
    p["accent_hi"] = mix("Brick Red", "Apricot Orange", 0.45, "light.accent_hi")
    p["accent_lo"] = mix("Brick Red", "Vandyke Red", 0.5, "light.accent_lo")
    p["accent_text"] = w("Brick Red", "light.accent_text")
    p["text_on_accent"] = p["key"]
    p["select"] = w("Vandyke Red", "light.select")   # (the dark theme's lacquer: 8.5 : 1 under the key's cream)
    p["text_on_select"] = p["key"]
    p["select_lo"] = mix("Vandyke Red", p["text_on_select"], 0.3, "light.select_lo")
    p["lit"], p["lit_text"], p["lit_hi"], p["lit_lo"] = p["text"], p["key"], p["muted"], p["strong"]
    p["urgent_text"] = p["key"]
    p["asagi"] = mix("Light Porcelain Green", "Dusky Green", 0.45, "light.asagi")
    p["flame"] = w("Brick Red", "light.flame")
    p["gold"] = w("Yellow Ocher", "light.gold")
    p["red"], p["green"], p["yellow"] = w("Brick Red"), w("Cossack Green"), w("Orange Citrine")
    p["blue"], p["purple"], p["teal"] = w("Blue"), w("Dark Soft Violet"), w("Dusky Green")
    p["bred"], p["bgreen"], p["byellow"] = w("Vandyke Red"), w("Diamine Green"), w("Sepia")
    p["bblue"], p["bpurple"], p["bteal"] = w("Helvetia Blue"), w("Violet"), w("Vandar Poel's Blue")
    p["ansi0"], p["ansi7"], p["ansi8"], p["ansi15"] = p["edge"], p["text"], p["muted"], p["strong"]
    p.update(gtk="Fedokawaii", base="adw-gtk3", scheme="prefer-light")
    return p


def table(P):
    roles = [("faint", 0), ("muted", 3), ("text", 4.5), ("strong", 4.5), ("accent_text", 4.5), ("asagi", 3)]
    for m, p in P.items():
        print(f"== {m}")
        for g in ("ground", "surface", "key"):
            cells = []
            for r, need in roles:
                c = contrast(p[r], p[g])
                cells.append(f"{r} {c:4.1f}{' ✘' if c < need else ''}")
            print(f"  on {g:8}: " + " · ".join(cells))
        print(f"  text_on_accent on accent {contrast(p['text_on_accent'], p['accent']):.1f}"
              f" · text_on_select on select {contrast(p['text_on_select'], p['select']):.1f}"
              f" · lit_text on lit {contrast(p['lit_text'], p['lit']):.1f}")


def sheet(P, out):
    from PIL import Image, ImageDraw
    rows = [k for k in P["dark"] if isinstance(P["dark"][k], str) and len(P["dark"][k]) == 6
            and all(c in "0123456789abcdef" for c in P["dark"][k])]
    im = Image.new("RGB", (1000, 22 * len(rows) + 30), (90, 90, 90))
    d = ImageDraw.Draw(im)
    for col, m in enumerate(("dark", "light")):
        x = 10 + col * 495
        d.text((x, 6), m, fill=(255, 255, 255))
        for i, k in enumerate(rows):
            h = P[m].get(k)
            if not h:
                continue
            y = 26 + i * 22
            d.rectangle((x, y, x + 60, y + 18), fill="#" + h)
            d.text((x + 68, y + 3), f"{k:15} #{h}  {RECIPE.get(m + '.' + k, '')}", fill=(240, 240, 240))
    im.save(out)


DOC_TOKENS = ("ground", "surface", "view", "key", "edge", "edge2", "hi", "lo", "faint", "muted", "text", "strong",
              "accent", "accent_hi", "accent_lo", "accent_text", "text_on_accent", "select", "text_on_select", "select_lo", "asagi",
              "flame",
              "gold", "lit", "lit_text")
DOC_TERM = ("red", "green", "yellow", "blue", "purple", "teal", "bred", "bgreen", "byellow", "bblue", "bpurple", "bteal")


def doc(P, tile):
    """The tokens as docs/design-system.md §1 lays them out (its first three columns: the role is
    the doc's own) — tests/static/test_design_doc.sh reads the doc's hex codes back against these."""
    def cell(m, k, h):
        r = RECIPE.get(f"{m}.{k}", "")
        r = r if r and r != h else ""
        return f"`{h}`" + (f" {r}" if r else "")
    for k in DOC_TOKENS:
        print(f"| `{k}` | {cell('dark', k, P['dark'][k])} | {cell('light', k, P['light'][k])} |")
    print(f"| `tile` | `{tile['dark']}` | `{tile['light']}` |")
    for k in DOC_TERM:
        print(f"| `{k}` | `{P['dark'][k]}` | `{P['light'][k]}` |")


def palette():
    """P (both themes' tokens), KAMI (the bar's washi ornaments), TILE (its paper), EDITOR (nvim's
    extra inks) — what tools/build-themes.py writes every colour file from."""
    P = {"dark": dark(), "light": light()}
    def rgba(h, a):
        return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (a,)
    ink, umber = W["Black"], mix("Vandyke Brown", "Black", 0.45)
    kami = {
        "dark": dict(hair=rgba(P["dark"]["text"], 128), shadow=(rgba(ink, 170), rgba(ink, 80)), rule=P["dark"]["edge"],
                     red=P["dark"]["accent"], gold=P["dark"]["gold"], rod=mix("Vandyke Brown", "Black", 0.1),
                     rod_hi=mix("Pale Raw Umber", "Isabella Color", 0.3), rod_dk=mix("Black", "Vandyke Brown", 0.2),
                     fibre_t=0.06, fibre_to="ffffff"),
        "light": dict(hair=rgba(P["light"]["strong"], 215), shadow=(rgba(umber, 110), rgba(umber, 48)), rule=P["light"]["edge"],
                      red=P["light"]["accent"], gold=P["light"]["gold"], rod=mix("Vandyke Brown", "Pale Raw Umber", 0.2),
                      rod_hi=mix("Pale Raw Umber", "Isabella Color", 0.45), rod_dk=mix("Vandyke Brown", "Black", 0.4),
                      fibre_t=0.6, fibre_to="ffffff"),
    }
    tile = {"dark": mix(P["dark"]["ground"], "Pale Raw Umber", 0.16), "light": mix("Sulpher Yellow", "White", 0.45)}
    editor = dict(comment=mix("Light Brownish Olive", "Ecru", 0.15), paper2=mix("Ecru", "Isabella Color", 0.3),
                  paper3=mix("Isabella Color", "Light Brownish Olive", 0.35), orange=w("Apricot Orange"),
                  orange_deep=mix("Brick Red", "Apricot Orange", 0.25))
    return P, kami, tile, editor


def main(argv):
    P, kami, tile, editor = palette()
    if "--table" in argv:
        table(P)
    if "--doc" in argv:
        doc(P, tile)
    if "--sheet" in argv:
        sheet(P, argv[argv.index("--sheet") + 1])
    if "--palette" in argv:
        out = argv[argv.index("--palette") + 1]
        with open(out, "w") as f:
            f.write("# generated by tools/wada-palette.py — every colour a Wada swatch or a mix of two\n")
            f.write(f"P = {P!r}\nKAMI = {kami!r}\nTILE = {tile!r}\nEDITOR = {editor!r}\n")
        print(f"palette → {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
