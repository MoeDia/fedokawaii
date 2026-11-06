#!/usr/bin/env python3
"""tools/helium-options.py — the options for Helium's theme (r28 f15): what tools/helium-options.sh shows the
real browser. `prep` writes, for each mood, a new tab page in the text screens' grammar (design system §7) and
noren's theme extension (a wave tile, the palette's colours); `sheet` lays the real shots out; nothing built in.

    python3 tools/helium-options.py prep DIR
    python3 tools/helium-options.py sheet DIR OUT.jpg
"""
import importlib.util
import json
import pathlib
import re
import shutil
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("build_themes", ROOT / "tools/build-themes.py")
BT = importlib.util.module_from_spec(spec)
spec.loader.exec_module(BT)

OPTIONS = [("now", "today: compact, the address at the left"),
           ("tsuitate", "1 tsuitate, a folding screen: address above, tabs below, 2 keys + 2 keys"),
           ("mokuroku", "2 mokuroku, an index: tabs a list at the left, 3 keys + 3 keys"),
           ("noren", "3 noren, a shop curtain: tabs hang from a band of waves, 3 keys + 3 keys")]
THEMES = ROOT / "configs/home/.config/fedokawaii/themes"
ICONS = ROOT / "configs/home/.config/fedokawaii/icons.sh"
FONT = ImageFont.truetype("/usr/local/share/fonts/fedokawaii/SumiUI.ttf", 14)
ROWS = [("ICON_BOOK", "the learn book", "chapter 7"), ("ICON_CODE", "repositories", "12"),
        ("ICON_MUSIC", "spotify", "playing"), ("ICON_FOLDER", "downloads", "2 new")]


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def icon(name):
    m = re.search(rf"^{name}=\$'((?:\\x[0-9a-f]{{2}})+)'", ICONS.read_text(), re.M)
    return bytes.fromhex(m[1].replace("\\x", "")).decode()


def ntp(d, mood):
    p = BT.P[mood]
    rows = "".join(f'<div class="row"><i>{icon(i)}</i><b>{n}</b><u>{v}</u></div>' for i, n, v in ROWS)
    (d / "ntp.html").write_text(f"""<!doctype html><meta charset="utf-8"><title>new tab</title><style>
html,body{{height:100%;margin:0;background:#{p["ground"]};color:#{p["text"]};font:16px/20px "Sumi Term";-webkit-font-smoothing:none}}
main{{position:absolute;left:50%;top:50%;width:448px;margin:-136px 0 0 -224px}}
img{{display:block;width:56px;height:56px;margin:0 0 20px;image-rendering:pixelated}}
i{{font:normal 16px/20px "Sumi Icons Term"}}
.head{{display:flex;color:#{p["strong"]};margin-bottom:20px}} .head i{{color:#{p["accent_text"]};width:24px}}
.head s{{flex:1;text-decoration:none;height:1px;background:#{p["edge2"]};margin:10px 0 0 8px}}
.find{{display:flex;margin-bottom:20px;color:#{p["faint"]}}} .find em{{font-style:normal;color:#{p["accent_text"]};width:32px;padding-left:8px;box-sizing:border-box}}
.find u{{margin-left:auto;text-decoration:none;color:#{p["muted"]}}}
.row{{display:flex;padding:0 8px}} .row i{{color:#{p["muted"]};width:24px}} .row b{{font-weight:normal}}
.row u{{margin-left:auto;text-decoration:none;color:#{p["muted"]}}}
.head+.row{{background:#{p["select"]};color:#{p["text_on_select"]};box-shadow:inset 2px 0 #{p["select_edge"]}}}
</style><main><img src="head.png"><div class="find"><em>&gt;</em>search or a place<u>/</u></div>
<div class="head"><i>{icon("ICON_BRANCH")}</i>today<s></s></div>{rows}</main>""")
    shutil.copy(THEMES / mood / "head-48.png", d / "head.png")
    (d / "manifest.json").write_text(json.dumps({"manifest_version": 3, "name": "fedokawaii new tab", "version": "1",
                                                 "chrome_url_overrides": {"newtab": "ntp.html"}}))


def waves(path, ground, line):
    """Seigaiha on the pixel: three rings a scale, no blending, tiles at 32 by 16."""
    im = Image.new("RGB", (32, 16), rgb(ground))
    px = im.load()
    for row, x0 in ((0, 0), (1, 16), (2, 0)):          # (later rows lie over earlier ones, as scales do)
        cy = 8 * row
        for sx in (-32, 0, 32):
            cx = sx + x0
            for y in range(16):
                for x in range(32):
                    for yy in (y, y + 16):
                        d2 = (x - cx) ** 2 + (yy - cy - 8) ** 2
                        if yy <= cy + 8 and d2 <= 15.5 ** 2:
                            r = d2 ** 0.5
                            px[x, y] = rgb(line) if 14.5 <= r or 9.5 <= r < 10.5 or 4.5 <= r < 5.5 else rgb(ground)
    im.save(path)


def noren(d, mood):
    p = BT.P[mood]
    waves(d / "frame.png", p["lo"] if mood == "dark" else p["edge"], p["edge2"] if mood == "dark" else p["edge2"])
    c = {"frame": p["ground"], "frame_inactive": p["ground"], "toolbar": p["key"], "tab_text": p["strong"], "tab_background_text": p["text"],
         "tab_background_text_inactive": p["muted"], "bookmark_text": p["text"], "ntp_background": p["ground"], "ntp_text": p["text"],
         "toolbar_button_icon": p["text"], "omnibox_background": p["ground"], "omnibox_text": p["text"], "toolbar_text": p["text"]}
    (d / "manifest.json").write_text(json.dumps({"manifest_version": 3, "name": "fedokawaii noren", "version": "1", "theme": {
        "images": {"theme_frame": "frame.png"},
        "colors": {k: list(rgb(v)) for k, v in c.items()},
        "properties": {"ntp_background_alignment": "center"}}}))


def prep(out):
    for mood in ("dark", "light"):
        for name, make in (("ntp", ntp), ("noren", noren)):
            d = out / mood / name
            d.mkdir(parents=True, exist_ok=True)
            make(d, mood)


def sheet(out, jpg):
    w, h = Image.open(out / "dark/noren.png").size
    now = 84                                             # (today's: its top rows and its page, enough to compare)
    gap, lab = 10, 22
    im = Image.new("RGB", (w * 2 + gap * 3, gap + lab + now + (lab + h + gap) * 3), rgb(BT.P["dark"]["lo"]))
    draw = ImageDraw.Draw(im)
    y = gap
    for name, label in OPTIONS:
        draw.text((gap, y + 15), label, font=FONT, fill=rgb(BT.P["dark"]["text"]), anchor="ls")
        y += lab
        for col, mood in enumerate(("dark", "light")):
            s = Image.open(out / mood / f"{name}.png").convert("RGB")
            if name == "now":
                s = s.crop((0, 0, w, now))
            im.paste(s, (gap + col * (w + gap), y))
        y += (now if name == "now" else h) + gap
    im.save(jpg, quality=80, optimize=True, progressive=True)
    print(jpg, pathlib.Path(jpg).stat().st_size, im.size)


if __name__ == "__main__":
    if sys.argv[1] == "prep":
        prep(pathlib.Path(sys.argv[2]))
    else:
        sheet(pathlib.Path(sys.argv[2]), sys.argv[3])
