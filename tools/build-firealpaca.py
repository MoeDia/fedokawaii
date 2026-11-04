#!/usr/bin/env python3
"""tools/build-firealpaca.py — our pictures and defaults for FireAlpaca:

    python3 tools/build-firealpaca.py           the masks of art/firealpaca-icons.txt →
                                                configs/home/.local/share/fedokawaii/firealpaca/icons/;
                                                what it starts from (theme.sh puts it there once) →
                                                configs/firealpaca/: Palette.ini (Wada's 159, art/wada-159.tsv),
                                                BrushNew.xml, EraserNew.xml
    python3 tools/build-firealpaca.py --sheet OUT.png [ZOOM]   every drawing at its size and ZOOM (default 3) on
                                                paper, for looking at, nothing written else

Every block's name is a file of the program's own resources: the same name, the same size (a sizes
table below names them, a wrong size stops the run: a mask scaled by Qt would smear). The masks are
black with their shape in alpha: src/kawa-firealpaca paints an icon in its state's ink; a list's
picture is black on its row and goes through the row's own ramp.
"""
import pathlib
import struct
import sys
import zlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
ART = ROOT / "art/firealpaca-icons.txt"
OUT = ROOT / "configs/home/.local/share/fedokawaii/firealpaca/icons"
# the sizes of the program's own files of these names (measured from its resources), by prefix or name
SIZES = {"tool_camera": (20, 20), "tool_": (24, 24), "snap_": (18, 18), "icon_": (20, 20), "grad_": (20, 20),
         "ref_random": (20, 20), "curve_": (20, 20), "select_": (16, 16), "move": (16, 16), "gear_12": (12, 12),
         "gear_18": (18, 18), "gear_10": (10, 10), "plus_18": (18, 18), "minus_18": (18, 18), "layer_clip": (9, 10),
         "layer_draft": (10, 10), "layer_lock": (10, 14), "layer_link": (16, 40), "folder_41": (41, 41),
         "firealpaca24": (24, 24)}


def blocks():
    out, cur = {}, None
    for n, line in enumerate(ART.read_text().splitlines(), 1):
        if line.startswith("@"):
            cur = line[1:].strip()
            if cur in out:
                raise SystemExit(f"{ART.name}:{n}: {cur} twice")
            out[cur] = []
        elif line and not set(line) - {"#", "."} and cur:      # (a row may start with "#": a comment has words)
            out[cur].append(line)
        elif line and not line.startswith("#"):
            raise SystemExit(f"{ART.name}:{n}: not a row of a drawing: {line!r}")
    return out


def size_of(name):
    for key, s in SIZES.items():
        if name.startswith(key):
            return s
    raise SystemExit(f"{ART.name}: {name}: no size known")


def checked():
    bad, art = [], blocks()
    for name, rows in art.items():
        w, h = size_of(name)
        if len(rows) != h or any(len(r) != w for r in rows):
            got = sorted({len(r) for r in rows})
            bad.append(f"{name}: {len(rows)} rows of {got}, not {h} of {w}")
    if bad:
        raise SystemExit(f"{ART.name}: wrong sizes:\n  " + "\n  ".join(bad))
    return art


def png(w, h, rows):
    raw = b"".join(b"\x00" + b"".join(bytes(px) for px in row) for row in rows)

    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def sheet(art, path, zoom):
    cols, cell = 14, 44 * zoom
    n = len(art)
    h = ((n + cols - 1) // cols) * (cell + 4)
    w = cols * (cell + 4)
    paper = (0xe8, 0xe3, 0xc2, 255)
    img = [[paper for _ in range(w)] for _ in range(h)]
    for i, (_, rows) in enumerate(sorted(art.items())):
        ox, oy = (i % cols) * (cell + 4) + 2, (i // cols) * (cell + 4) + 2
        for y, r in enumerate(rows):
            for x, c in enumerate(r):
                if c == "#":
                    for yy in range(zoom):
                        for xx in range(zoom):
                            img[oy + y * zoom + yy][ox + x * zoom + xx] = (0x12, 0x26, 0x25, 255)
    pathlib.Path(path).write_bytes(png(w, h, img))
    print(f"{n} drawings → {path}: order " + " ".join(sorted(art)))


def palette_ini():
    """FireAlpaca's palette file: one section a swatch, its name shown beside the palette when picked;
    QSettings' QVariant of an unsigned char, written as the program writes it."""
    rows = [ln.split("\t") for ln in (ROOT / "art/wada-159.tsv").read_text().splitlines() if not ln.startswith("#")]

    def byte(v):
        return f"@Variant(\\0\\0\\0\\x86\\x{v:02x})"
    out = []
    for i, (name, hexa) in sorted(enumerate(rows), key=lambda e: str(e[0])):     # (QSettings' order: as text)
        r, g, b = (int(hexa[j:j + 2], 16) for j in (0, 2, 4))
        out.append(f"[{i}]\nb={byte(b)}\ng={byte(g)}\nname={name}\nr={byte(r)}\n")
    return "\n".join(out)


# The brushes he starts with: few, each its own use (the program's own, unchanged, and our sumi brush); the
# rest of its set stays one click away in its Brush Store (Brush menu), its files untouched.
BRUSHES = [
    '<Brush type="pen" name="Fude" R="24" minR="0.04" alpha="1" pressWidth="true" pressTrans="false" iriNuki="true" pp="true" '
    'ppStylusMul="1" ppFingerMul="1" ppFadeInLen="0.25" ppFadeOutLen="0.6" ppFadeFunc="smooth" ppInkPoolInLen="0.15" '
    'ppInkPoolOutLen="0" ppInkPoolInAdd="0.25" ppInkPoolOutAdd="0" ppInkFunc="drop" />',
    '<Brush type="pen" name="Pen" R="8" alpha="1" pressWidth="true" pressTrans="false" />',
    '<Brush type="pen" name="Pencil" R="10" minR="0.3" alpha="1" pressWidth="true" pressTrans="true" />',
    '<Brush type="air" name="Sketchbook" R="12" minR="0.1" alpha="0.75" pressWidth="true" pressTrans="true" '
    'texFile="preset_sketch.mdp" texOp="sub" texEffect="0.25" />',
    '<Brush type="air" name="AirBrush" R="60" minR="0.8" alpha="0.2" pressWidth="true" pressTrans="true" />',
    '<Brush type="wc" name="Watercolor" R="80" minR="0.5" alpha="0.7" pressWidth="true" pressTrans="true" softEdge="true" '
    'option0="70" option1="30" />',
    '<Brush type="wc" name="Bleeding" R="80" minR="0.5" alpha="0.75" pressWidth="true" pressTrans="true" '
    'texFile="preset_noise.mdp" texOp="sub" texEffect="0.25" softEdge="true" option0="70" option1="30" />',
    '<Brush type="bitmapwc" name="Flat" R="80" minR="0.8" alpha="1" pressWidth="true" pressTrans="true" '
    'file="bb_hirafude_rnd.png" option0="10" option1="1" option2="50" option3="0" option4="70" option5="30" option6="0" option7="0" />',
    '<Brush type="finger" name="Smudge" R="50" minR="0.6" alpha="1" pressWidth="true" pressTrans="false" option0="50" />',
    '<Brush type="mix" name="Mix" R="70" minR="0.7" alpha="0.2" pressWidth="true" pressTrans="true" softEdge="false" />',
    '<Brush type="blur" name="Blur" R="80" minR="0.8" alpha="1" pressWidth="true" pressTrans="true" option0="40" />',
    '<Brush type="program" name="Symmetry" R="10" alpha="1" pressWidth="true" pressTrans="true" file="symm_x.bs" '
    'option0="0" option1="0" />',
]
ERASERS = [
    '<Brush type="erase" name="Eraser" R="12" alpha="1" pressWidth="true" pressTrans="false" softEdge="false" option0="0" />',
    '<Brush type="erase" name="Eraser, wide" R="40" alpha="1" pressWidth="true" pressTrans="false" softEdge="false" option0="0" />',
    '<Brush type="erase" name="Eraser, soft" R="50" minR="0.6" alpha="1" pressWidth="true" pressTrans="true" softEdge="true" option0="0" />',
]


def brush_xml(rows):
    body = "".join(f"        {r}\n" for r in rows)
    return ('<?xml version="1.0" encoding="UTF-8" ?>\n<Root>\n    <Brushes>\n' + body + "    </Brushes>\n    <Groups />\n"
            '    <Active index="0" scrollPos="0" />\n    <Version ver="1" />\n</Root>\n')


def seeds():
    d = ROOT / "configs/firealpaca"
    d.mkdir(parents=True, exist_ok=True)
    (d / "Palette.ini").write_text(palette_ini())
    (d / "BrushNew.xml").write_text(brush_xml(BRUSHES))
    (d / "EraserNew.xml").write_text(brush_xml(ERASERS))
    print(f"Palette.ini, BrushNew.xml, EraserNew.xml → {d.relative_to(ROOT)}")


def main():
    art = checked()
    if "--sheet" in sys.argv:
        i = sys.argv.index("--sheet")
        zoom = int(sys.argv[i + 2]) if len(sys.argv) > i + 2 else 3
        sheet(art, sys.argv[i + 1], zoom)
        return
    OUT.mkdir(parents=True, exist_ok=True)
    for old in OUT.glob("*.png"):
        if old.stem not in art:
            old.unlink()
    for name, rows in art.items():
        w, h = len(rows[0]), len(rows)
        (OUT / f"{name}.png").write_bytes(png(w, h, [[(0, 0, 0, 255 if c == "#" else 0) for c in r] for r in rows]))
    print(f"{len(art)} masks → {OUT.relative_to(ROOT)}")
    seeds()


if __name__ == "__main__":
    main()
