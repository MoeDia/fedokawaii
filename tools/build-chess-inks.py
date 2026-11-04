#!/usr/bin/env python3
"""tools/build-chess-inks.py — the inks of the chess board and its men, for both moods: each a token of
the palette, a Wada colour, or a stated mix of two in OKLab (tools/wada-palette.py's own mix, as every
colour of the desktop; docs/design-system.md §1). Writes
configs/home/.local/share/fedokawaii/chess/inks.txt: NAME DARK LIGHT, a line each (hex).

  python3 -I tools/build-chess-inks.py [OUT]
"""
import importlib.util
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("wada", HERE / "wada-palette.py")
wada = importlib.util.module_from_spec(spec)
sys.dont_write_bytecode = True
spec.loader.exec_module(wada)
mix, W = wada.mix, wada.W


def over(top, under, a):
    """top at alpha a over under, as the frame's hairline and shadow lie on the panel's ground."""
    t = [int(top[i:i + 2], 16) for i in (0, 2, 4)]
    u = [int(under[i:i + 2], 16) for i in (0, 2, 4)]
    return "".join(f"{round(x * a + y * (1 - a)):02x}" for x, y in zip(t, u, strict=True))


def inks(p, mood):
    """p: the mood's palette (tools/wada-palette.py dark() or light())."""
    o = {}
    dark = mood == "dark"
    # the board: old kaya wood — ink-stained in the dungeon, honey by daylight
    if dark:
        o["sq_l"] = mix("Ecru", "Light Brownish Olive", 0.35)
        o["sq_d"] = mix("Pale Raw Umber", "Black", 0.22)
    else:
        o["sq_l"] = mix("Ivory Buff", "Sulpher Yellow", 0.45)
        o["sq_d"] = mix("Maple", "Pale Raw Umber", 0.38)
    o["sq_l2"] = mix(o["sq_l"], "Pale Raw Umber", 0.14)      # the grain
    o["sq_d2"] = mix(o["sq_d"], "Black", 0.2)
    o["sq_l3"] = mix(o["sq_l"], "Sulpher Yellow", 0.22)      # the tile's lit edge
    o["sq_d3"] = mix(o["sq_d"], "Isabella Color", 0.16)
    # the last move: the torch (dark), the gold leaf (light) laid on the wood
    leaf = "Apricot Orange" if dark else "Yellow Ocher"
    o["ls_l"] = mix(o["sq_l"], leaf, 0.42)
    o["ls_d"] = mix(o["sq_d"], leaf, 0.42)
    o["ls_l2"] = mix(o["ls_l"], "Pale Raw Umber", 0.14)
    o["ls_d2"] = mix(o["ls_d"], "Black", 0.2)
    # a square in check: the seal's red
    o["ck_l"] = mix(o["sq_l"], "Jasper Red", 0.72)
    o["ck_d"] = mix(o["sq_d"], "Jasper Red", 0.72)
    # marks on the wood: a dot's ink, a coordinate's
    o["dot_l"] = mix(o["sq_l"], "Black", 0.42)
    o["dot_d"] = mix(o["sq_d"], "Black", 0.55)
    o["co_l"] = mix(o["sq_l"], "Black", 0.55)
    o["co_d"] = mix(o["sq_d"], "Sulpher Yellow", 0.55)
    o["accent"] = p["accent"]
    o["accent_hi"] = p["accent_hi"]
    o["select"] = p["select"]
    o["on_select"] = p["text_on_select"]
    o["asagi"] = p["asagi"]
    o["flame"] = p["flame"]
    o["gold"] = W["Isabella Color"] if dark else W["Yellow Ocher"]
    o["strong"] = p["strong"]
    o["muted"] = p["muted"]
    o["faint"] = p["faint"]
    o["edge2"] = p["edge2"]
    o["edge"] = p["edge"]
    # the frame (§4), over the ground it floats on
    if dark:
        o["hair"] = over(p["text"], p["ground"], 0.50)
        o["sh1"] = over(W["Black"], p["ground"], 0.67)
        o["sh2"] = over(W["Black"], p["ground"], 0.31)
    else:
        o["hair"] = over(p["strong"], p["ground"], 0.84)
        o["sh1"] = over(W["Pale Raw Umber"], p["ground"], 0.43)
        o["sh2"] = over(W["Pale Raw Umber"], p["ground"], 0.19)
    # the men: bone and vermilion against black lacquer and gold (dark); porcelain and its blue
    # against black lacquer and gold leaf (light) — maki-e, sometsuke
    if dark:
        o["w_o"] = mix("Black", "Vandyke Brown", 0.1)
        o["w_f"] = mix("Sulpher Yellow", "Isabella Color", 0.14)
        o["w_l"] = mix("Sulpher Yellow", "White", 0.5)
        o["w_d"] = mix("Isabella Color", "Sulpher Yellow", 0.32)
        o["w_t"] = W["Jasper Red"]
        o["b_o"] = mix("Black", "White", 0.0)
        o["b_f"] = mix("Black", "Pale Raw Umber", 0.24)
        o["b_l"] = mix("Pale Raw Umber", "Isabella Color", 0.22)
        o["b_d"] = mix("Black", "Vandyke Brown", 0.1)
        o["b_t"] = W["Isabella Color"]
    else:
        o["w_o"] = mix("Deep Slate Green", "Black", 0.5)
        o["w_f"] = mix("Sulpher Yellow", "White", 0.72)
        o["w_l"] = W["White"]
        o["w_d"] = mix("Sulpher Yellow", "Neutral Gray", 0.5)
        o["w_t"] = mix("Light Porcelain Green", "Dusky Green", 0.45)
        o["b_o"] = mix("Black", "White", 0.0)
        o["b_f"] = mix("Black", "Deep Slate Green", 0.72)
        o["b_l"] = mix("Deep Grayish Olive", "Isabella Color", 0.22)
        o["b_d"] = mix("Black", "Deep Slate Green", 0.2)
        o["b_t"] = W["Yellow Ocher"]
    return o


def main(argv):
    root = HERE.parent
    out = pathlib.Path(argv[1]) if len(argv) > 1 else root / "configs/home/.local/share/fedokawaii/chess/inks.txt"
    a, b = inks(wada.dark(), "dark"), inks(wada.light(), "light")
    lines = ["# the chess board's and men's inks, dark and light: tools/build-chess-inks.py writes this"]
    lines += [f"{k} {a[k]} {b[k]}" for k in a]
    out.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
