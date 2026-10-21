#!/usr/bin/env python3
"""tools/build-appicons.py — the launcher's own icons, one set per theme.

    python3 tools/build-appicons.py

Every launcher entry whose program works in a terminal, or has no icon of its own that fits,
shows a seal of ours (docs/design-system.md §4, "Launcher icons"): an 18 × 18 square — the
launcher's icon size — its 1 px frame in edge2, the entry's kanji in accent_text, Fusion
Pixel 12 drawn pixel by pixel, its ink centred; the ground key, as a tile's (a clear ground
would lose the kanji on the chosen row, whose fill is accent: fuzzel cannot swap the icon). Each picture is exactly 18 × 18, shown 1:1 (dwl's monitors are at scale 1): fuzzel
filters any picture it resizes, so a 2× copy halved would blur every edge (measured: a 36 px
seal drawn at 18 mixed the frame into the ground), and an icon named by its path has no
second size to offer. Writes (committed):

    configs/home/.config/fedokawaii/themes/<theme>/apps/<name>.png

and the entries name them through the theme link (Icon=@HOME@/.config/fedokawaii/current/
apps/<name>.png), so switching the theme switches them. The colours are build-themes.py's.
Needs: Pillow, and Fusion Pixel 12 installed (fc-match finds it).
"""
import importlib.util
import pathlib
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("themes", ROOT / "tools/build-themes.py")
themes = importlib.util.module_from_spec(spec)
spec.loader.exec_module(themes)
P = themes.P

SIZE = 18          # fuzzel's icon: the 20 px row less the font's descent (fuzzel.ini)

# name (the picture, as the entry's Icon= names it) → its kanji, one character, meaning it
ICONS = {
    "terminal": "端",    # Terminal (foot)          the end of the line: a terminal
    "editor": "編",      # Editor (Neovim)          to edit
    "files": "箱",       # Files (yazi)             a box: what holds things
    "agents": "代",      # Agents (herdr, Claude)   one acting for you
    "git": "枝",         # Git (lazygit)            a branch
    "notes": "記",       # Notes                    to note down
    "clipboard": "写",   # Clipboard                a copy
    "books": "本",       # Books (zathura)          a book
    "wallpaper": "壁",   # Wallpaper                a wall
    "backup": "蔵",      # Backup (restic)          a storehouse
    "calc": "算",        # Calculator (qalc)        to reckon
    "disk": "量",        # Disk usage (gdu)         an amount
    "tables": "表",      # Tables (VisiData)        a table
    "monitor": "視",     # System monitor (btop)    to watch
    "mixer": "混",       # Volume mixer (wiremix)   to mix
    "network": "網",     # Network (nmtui)          a net
    "bluetooth": "青",   # Bluetooth (bluetui)      blue
    "file": "具",        # File tools               a tool
    "torrents": "種",    # Torrents (torrra)        a seed
    "prowlarr": "索",    # Prowlarr                 to search
    "spotify": "曲",     # Spotify (in Brave)       a tune
    "whatsapp": "話",    # WhatsApp (in Brave)      to talk
}


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def icon(p, ch, font):
    im = Image.new("RGBA", (SIZE, SIZE), rgb(p["key"]))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, SIZE - 1, SIZE - 1], outline=rgb(p["edge2"]))
    # the ink measured on its own (the font's box holds the side bearings), then centred
    ink = Image.new("1", (SIZE * 2, SIZE * 2), 0)
    dk = ImageDraw.Draw(ink)
    dk.fontmode = "1"
    dk.text((SIZE // 2, SIZE // 2), ch, font=font, fill=1)
    l, t, r, b = ink.getbbox()
    x = (SIZE - (r - l)) // 2 - l + SIZE // 2
    y = (SIZE - (b - t)) // 2 - t + SIZE // 2
    d.fontmode = "1"
    d.text((x, y), ch, font=font, fill=rgb(p["accent_text"]))
    return im


def main():
    path = subprocess.run(["fc-match", "-f", "%{file}", "Fusion Pixel 12px Mono ja"],
                          capture_output=True, text=True, check=True).stdout
    if "fusion-pixel-12px" not in path:
        sys.exit(f"Fusion Pixel 12 is not installed (fc-match gives {path})")
    font = ImageFont.truetype(path, 12)
    n = 0
    for theme in ("dark", "light"):
        d = ROOT / "configs/home/.config/fedokawaii/themes" / theme / "apps"
        d.mkdir(parents=True, exist_ok=True)
        for old in d.glob("*.png"):
            if old.stem not in ICONS:
                old.unlink()
        for name, ch in ICONS.items():
            icon(P[theme], ch, font).save(d / f"{name}.png", optimize=True)
            n += 1
    print(f"{n} launcher icons written")


if __name__ == "__main__":
    main()
