#!/usr/bin/env python3
"""Builds Fedokawaii-Guide.pdf from docs/fedokawaii-guide.md and REAL renders
(scratchpad/real/shots/{dark,light}: the real apps at Fedora 44's versions)."""
import re, os, sys, glob, math
import markdown, numpy as np
from PIL import Image, ImageDraw, ImageFont
S = os.environ.get("FEDOKAWAII_SCRATCH", "/tmp/claude-0/-home-claude/6d31fcd7-1ae3-5468-8ff5-715a71fb37a1/scratchpad")
REPO = os.environ.get("FEDOKAWAII_REPO", "/home/claude/fedokawaii")
CHROME = os.environ.get("FEDOKAWAII_CHROME", "/opt/pw-browsers/chromium-1194/chrome-linux/chrome")
OUT = f"{S}/guide"
IMG = f"{OUT}/img2"
R = f"{S}/real/shots"
NM = f"{S}/mock/node_modules/@fontsource"
GAP = (90, 90, 90)
os.makedirs(IMG, exist_ok=True)
DM = ImageFont.truetype(f"{S}/mock/fonts/DepartureMonoNerdFont-Regular.otf", 22)

def im(p): return Image.open(p).convert("RGB")

def scale(img, k): return img.resize((img.width * k, img.height * k), Image.NEAREST) if k != 1 else img

INK, PAPER = (15, 14, 12), (233, 225, 203)
def grid(rows, out, gap=16, bg=GAP, align="center", row_bg=None, pad=0):
    """rows: list of lists of images → one picture, rows stacked, images side by side and
    top-aligned; row_bg gives each row its own ground (the theme it shows), with pad around"""
    keep = [(i, [x for x in r if x is not None]) for i, r in enumerate(rows)]
    keep = [(i, r) for i, r in keep if r]
    W = max(sum(x.width for x in r) + gap * (len(r) - 1) for _, r in keep) + 2 * pad
    H = sum(max(x.height for x in r) + 2 * pad for _, r in keep) + gap * (len(keep) - 1)
    canvas = Image.new("RGB", (W, H), bg)
    d = ImageDraw.Draw(canvas)
    y = 0
    for i, r in keep:
        h = max(x.height for x in r) + 2 * pad
        if row_bg: d.rectangle([0, y, W - 1, y + h - 1], fill=row_bg[i])
        w = sum(x.width for x in r) + gap * (len(r) - 1)
        x0 = (W - w) // 2 if align == "center" else pad
        for x in r:
            canvas.paste(x, (x0, y + pad)); x0 += x.width + gap
        y += h + gap
    canvas.save(out); return out

def both(name, k=1):
    d, l = f"{R}/dark/{name}.png", f"{R}/light/{name}.png"
    if not (os.path.exists(d) and os.path.exists(l)): return None
    return scale(im(d), k), scale(im(l), k)

def pair(name, out, k=1, vertical=False):
    b = both(name, k)
    if not b: return None
    return grid([[b[0]], [b[1]]] if vertical else [[b[0], b[1]]], out)

def shrink(src, out, w):
    i = im(src)
    if i.width > w: i = i.resize((w, round(i.height * w / i.width)), Image.LANCZOS)
    i.save(out); return out

FIG, FIGW, FIGH = {}, {}, {}
def add(name, path):   # a figure at its natural size (1 px = 1 CSS px); sized in fig()
    if not (path and os.path.exists(path)): return
    i = Image.open(path)
    FIG[name], FIGW[name], FIGH[name] = path, i.width, i.height

# Every figure is laid out at an exact size that keeps its proportions — its natural size
# when it fits the text column, smaller when it does not (width and height from one factor:
# never stretched), a whole multiple for the pixel-art strips that fill the column. The
# picture itself is only ever enlarged by a whole number (each source pixel an exact block,
# no colour invented) until there are at least 2.5 of its pixels to a CSS pixel (≥ 240 dpi);
# the PDF places it at the exact size and the reader's own scaling does the rest — nothing
# is resampled twice, no row or column doubled or dropped unevenly.
MM = 96 / 25.4                       # CSS px per mm
TEXT_W = 180 * MM                    # the text column (A4 less 2 × 15 mm)
FULL = {"bar", "fetch", "pointers", "icons"}          # strips that fill the column
MAXH = {"desktop-dark": 236, "desktop-light": 236, "transition": 236, "packsheet": 236, "lock": 84,
        "menus": 180, "osd": 150, "drives": 110}
def printable(src, scale, out):
    i = Image.open(src).convert("RGB")
    k = max(1, math.ceil(2.5 * scale - 1e-9))
    if k > 1: i = i.resize((i.width * k, i.height * k), Image.NEAREST)
    i.save(out, optimize=True)
    return out
def layout(name):
    nw, nh = FIGW[name], FIGH[name]
    maxw = TEXT_W * (0.8 if name == "icons" else 1.0)
    maxh = MAXH.get(name, 120) * MM
    fit = min(maxw / nw, maxh / nh)
    s = (math.floor(fit) if name in FULL else 1) if fit >= 1 else fit
    return printable(FIG[name], s, f"{IMG}/{name}.print.png"), nw * s, nh * s

add("desktop-dark", shrink(f"{R}/dark/clipboard-full.png" if os.path.exists(f"{R}/dark/desktop-tour.png") is False else f"{R}/dark/desktop-tour.png", f"{IMG}/desktop-dark.png", 1920))
add("desktop-light", shrink(f"{R}/light/clipboard-full.png" if os.path.exists(f"{R}/light/desktop-tour.png") is False else f"{R}/light/desktop-tour.png", f"{IMG}/desktop-light.png", 1920))
if os.path.exists(f"{R}/dark/terminal-full.png"):
    add("desktop-dark", shrink(f"{R}/dark/terminal-full.png", f"{IMG}/desktop-dark.png", 1920))
    add("desktop-light", shrink(f"{R}/light/terminal-full.png", f"{IMG}/desktop-light.png", 1920))

# the bar: each end at 2×, dark above light
bars = []
for t in ("dark", "light"):
    for part in ("bar-left", "bar-center", "bar-right"):
        p = f"{R}/{t}/{part}.png"
        if os.path.exists(p): bars.append([scale(im(p), 2)])
if bars: add("bar", grid(bars, f"{IMG}/bar.png", gap=10))

def menus_fig():
    names = ["menu-quick", "menu-power", "menu-calendar", "menu-audio"]
    rows = []
    for t in ("dark", "light"):
        rows.append([im(f"{R}/{t}/{n}.png") for n in names if os.path.exists(f"{R}/{t}/{n}.png")])
    return grid(rows, f"{IMG}/menus.png", gap=24, pad=24, bg=INK, row_bg=[INK, PAPER])
add("menus", menus_fig())

def osd_fig():
    rows = []
    for t in ("dark", "light"):
        rows.append([im(f"{R}/{t}/{n}.png") for n in ("osd-volume", "notify-app", "notify-critical") if os.path.exists(f"{R}/{t}/{n}.png")])
    return grid(rows, f"{IMG}/osd.png", gap=24, pad=24, bg=INK, row_bg=[INK, PAPER])
add("osd", osd_fig())

add("terminal", pair("terminal", f"{IMG}/terminal.png", vertical=True))
add("colors", pair("colors", f"{IMG}/colors.png"))
add("clipboard", grid([[im(f"{R}/dark/clipboard-picture.png"), im(f"{R}/light/clipboard.png")]], f"{IMG}/clipboard.png")
    if os.path.exists(f"{R}/dark/clipboard-picture.png") else None)
add("launcher", pair("launcher", f"{IMG}/launcher.png"))
add("menu-change", pair("menu-change", f"{IMG}/menu-change.png"))
add("menu-drives", pair("menu-drives", f"{IMG}/menu-drives.png"))
def drives_fig():   # a stick that opened, then eject's "safe to unplug": dark above light
    rows = []
    for t in ("dark", "light"):
        rows.append([im(f"{R}/{t}/{n}.png") for n in ("notify-drive", "notify-eject") if os.path.exists(f"{R}/{t}/{n}.png")])
    if not any(rows): return None
    return grid(rows, f"{IMG}/drives.png", gap=24, pad=24, bg=INK, row_bg=[INK, PAPER])
add("drives", drives_fig())
if os.path.exists(f"{R}/dark/wallpaper-picker.png") and os.path.exists(f"{R}/light/wallpaper-picker.png"):
    add("wallpaper-picker", grid([[im(f"{R}/dark/wallpaper-picker.png"), im(f"{R}/light/wallpaper-picker.png")]], f"{IMG}/wallpaper-picker.png"))
lk = both("lock-center", 2)
if lk: add("lock", grid([[lk[0], lk[1]]], f"{IMG}/lock.png"))
for app in ("app-yazi", "app-nvim", "app-lazygit", "app-btop", "app-mpv", "app-zathura", "app-filechooser",
            "app-share", "app-torrra", "app-brave"):
    b = both(app)
    if b:
        vertical = b[0].width > 900
        add(app, grid([[b[0]], [b[1]]] if vertical else [[b[0], b[1]]], f"{IMG}/{app}.png"))
    elif app == "app-brave" and os.path.exists(f"{IMG}/{app}.png"):
        add(app, f"{IMG}/{app}.png")    # (Brave would not start in this sandbox: its last real render)
# the two small windows: books (the list on ink, adding on paper) and notes (both themes)
if os.path.exists(f"{R}/dark/app-books.png") and os.path.exists(f"{R}/light/app-books-add.png"):
    add("books", grid([[im(f"{R}/dark/app-books.png"), im(f"{R}/light/app-books-add.png")]], f"{IMG}/books.png"))
nb = both("app-notes")
if nb: add("notes", grid([[nb[0], nb[1]]], f"{IMG}/notes.png"))
# the system's control (Super+U): the status on ink, the move to the next Fedora on paper
if os.path.exists(f"{R}/dark/app-system.png") and os.path.exists(f"{R}/light/app-system-upgrade.png"):
    add("system", grid([[im(f"{R}/dark/app-system.png"), im(f"{R}/light/app-system-upgrade.png")]], f"{IMG}/system.png"))
# the pointers, from their drawings (tools/build-cursors.py --preview)
import subprocess
if subprocess.run(["python3", f"{REPO}/tools/build-cursors.py", "--preview", f"{IMG}/pointers.png"], capture_output=True).returncode == 0:
    add("pointers", f"{IMG}/pointers.png")
# the walkthrough shots (nvim, lazygit, yazi): marker "nvim-picker" ← render "app-nvim-picker"
for name in ("nvim-whichkey", "nvim-picker", "nvim-grep", "nvim-split", "nvim-lsp",
             "lazygit-stage", "lazygit-commit", "lazygit-log", "yazi-preview", "yazi-drives"):
    # one theme each, alternating, full width: a walkthrough reads better large than twice
    t = ("dark", "light")[len([k for k in FIG if k.startswith(("nvim-", "lazygit-", "yazi-"))]) % 2]
    src = f"{R}/{t}/app-{name}.png"
    if os.path.exists(src): add(name, src)            # (sized, never resampled twice: layout())

# the transition, from two real screens (the formula of src/kawa-veil/kawa-veil.c plan())
BAYER = np.array([[0,32,8,40,2,34,10,42],[48,16,56,24,50,18,58,26],[12,44,4,36,14,46,6,38],[60,28,52,20,62,30,54,22],
                  [3,35,11,43,1,33,9,41],[51,19,59,27,49,17,57,25],[15,47,7,39,13,45,5,37],[63,31,55,23,61,29,53,21]])
def values(W, H, style):
    bs = max(-(-W // 640), -(-H // 360), 2); bw, bh = -(-W // bs), -(-H // bs)
    by, bx = np.mgrid[0:bh, 0:bw]; b = (BAYER[by % 8, bx % 8] + 0.5) / 64
    chord = 96.0 * max(H / 1080, 1) / bs; r = chord / 2; band = r * 1.2
    f = np.mod(bx + 0.5, chord) - r; depth = r - np.sqrt(np.maximum(r * r - f * f, 0))
    d = (bh - 1 - by) if style == "rise" else by
    v = (d + depth + band * b) / (bh + r + band)
    return np.kron(v, np.ones((bs, bs)))[:H, :W]
if os.path.exists(f"{R}/dark/terminal-full.png"):
    A = np.array(im(f"{R}/dark/terminal-full.png")); N = np.array(im(f"{R}/light/terminal-full.png"))
    v = values(A.shape[1], A.shape[0], "rise"); ease = lambda t: t * t * (3 - 2 * t)
    frames = [Image.fromarray(np.where((v < ease(t))[..., None], N, A).astype(np.uint8)) for t in (0.3, 0.5, 0.7)]
    row = Image.new("RGB", (3 * 960 + 2 * 16, 540), GAP)
    for i, f in enumerate(frames): row.paste(f.resize((960, 540), Image.LANCZOS), (i * 976, 0))
    detail = frames[1].crop((560, 380, 1360, 680)).resize((1600, 600), Image.NEAREST)
    fig = Image.new("RGB", (row.width, 540 + 16 + 600), GAP); fig.paste(row, (0, 0)); fig.paste(detail, ((row.width - 1600) // 2, 556))
    fig.save(f"{IMG}/transition.png"); add("transition", f"{IMG}/transition.png")

# the pack: two pictures, then the whole sheet
W = "/home/kawau/.local/share/fedokawaii/wallpapers"
entries = [l.split()[:2] for l in open(f"{REPO}/configs/home/.local/share/fedokawaii/wallpapers.list") if l.split()[:1] in (["dark"], ["light"])]
if os.path.exists(f"{W}/dark/dawn-mart.png") and os.path.exists(f"{W}/light/station-street.png"):
    add("pack", grid([[im(f"{W}/dark/dawn-mart.png"), im(f"{W}/light/station-street.png")]], f"{IMG}/pack.png"))
tw, th, cols = 320, 180, 6
rows = -(-len(entries) // cols)
sheet = Image.new("RGB", (cols * (tw + 12) + 12, rows * (th + 40) + 12), (15, 14, 12)); d = ImageDraw.Draw(sheet)
for i, (mode, name) in enumerate(entries):
    p = f"{W}/{mode}/{name}.png"
    if not os.path.exists(p): continue
    x = 12 + (i % cols) * (tw + 12); y = 12 + (i // cols) * (th + 40)
    sheet.paste(im(p).resize((tw, th), Image.NEAREST), (x, y))
    d.text((x, y + th + 6), name, font=DM, fill=(207, 195, 166) if mode == "dark" else (232, 135, 109))
sheet.save(f"{IMG}/packsheet.png"); add("packsheet", f"{IMG}/packsheet.png")

# fetch: the ten pictures, read from bin/fetch, on ink and on paper
src = open(f"{REPO}/bin/fetch").read()
arts = re.findall(r"^ART_(\w+)=\(\n(.*?)\n\)", src, re.M | re.S)
k = 8
fw = len(arts) * (20 * k + 24) + 24
fimg = Image.new("RGB", (fw, 2 * (16 * k + 24) + 24), (15, 14, 12)); fd = ImageDraw.Draw(fimg)
fd.rectangle([0, 16 * k + 36, fw, fimg.height], fill=(233, 225, 203))
for n, (name, body) in enumerate(arts):
    ls = [x.strip().strip('"') for x in body.splitlines()]
    pal = dict(kv.split("=") for kv in ls[0].split())
    for g in range(2):
        ox, oy = 24 + n * (20 * k + 24), 12 + g * (16 * k + 36)
        for y, r in enumerate(ls[1:]):
            for x, ch in enumerate(r):
                if ch != ".": fd.rectangle([ox + x * k, oy + y * k, ox + x * k + k - 1, oy + y * k + k - 1], fill="#" + pal[ch])
fimg.save(f"{IMG}/fetch.png"); add("fetch", f"{IMG}/fetch.png")

add("grub", f"{S}/mock/png2/grub.png")
add("icons", f"{S}/icons-preview.png")

# ── the document ───────────────────────────────────────────────────────────────
src = open(f"{REPO}/docs/fedokawaii-guide.md", encoding="utf-8").read()
fm, body = re.match(r"^---\n(.*?)\n---\n(.*)$", src, re.S).groups()
meta = dict(re.findall(r'^(\w+):\s*"(.*)"$', fm, re.M))
missing = []
def fig(m):
    name, cap = m.group(1).strip(), m.group(2).strip()
    if name not in FIG:
        missing.append(name); return ""
    src, dw, dh = layout(name)
    return (f"<figure class='fig-{name}'><img src='file://{src}' style='width:{dw:.3f}px;height:{dh:.3f}px'>"
            f"<figcaption style='width:{dw:.3f}px'>{cap}</figcaption></figure>")
body = re.sub(r"<!--\s*fig:([\w-]+)\s*\|\s*(.*?)\s*-->", fig, body)
html = markdown.markdown(body, extensions=["tables", "fenced_code"])
html = html.replace("<table>", "<div class='tw'><table>").replace("</table>", "</table></div>")
html = re.sub(r"<code>(#[0-9a-f]{6})</code>", r"<span class='sw' style='background:\1'></span><code>\1</code>", html)

def ff(name, path, w="400", s="normal"):
    return f"@font-face{{font-family:'{name}';src:url('file://{path}');font-weight:{w};font-style:{s}}}"
CSS = "\n".join([
    ff("DM", f"{S}/mock/fonts/DepartureMonoNerdFont-Regular.otf"),
    ff("SUMI", f"{S}/mock/fonts/SumiIcons.ttf"),
    ff("Serif", f"{NM}/noto-serif/files/noto-serif-latin-400-normal.woff2"),
    ff("Serif", f"{NM}/noto-serif/files/noto-serif-latin-700-normal.woff2", "700"),
    ff("Serif", f"{NM}/noto-serif/files/noto-serif-latin-400-italic.woff2", "400", "italic"),
    ff("Sans", f"{NM}/noto-sans/files/noto-sans-latin-400-normal.woff2"),
    ff("Sans", f"{NM}/noto-sans/files/noto-sans-latin-700-normal.woff2", "700"),
    ff("JBM", f"{S}/mock/fonts/jbm/JetBrainsMonoNerdFont-Regular.ttf"),
]) + """
@page { size: A4; margin: 16mm 0 18mm; background: #efe8d5;
  @bottom-center { content: counter(page); font-family: DM; font-size: 11px; color: #776f60; } }
@page :first { margin: 0; background: #0f0e0c; @bottom-center { content: none; } }
html { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
body { font-family: Serif, serif; font-size: 9.6pt; line-height: 1.5; color: #2b2721; margin: 0; }
/* every page the same width (the cover's, A4's): the text column is the padding, so no page
   is wider than another and nothing is ever shrunk to fit */
main { padding: 0 15mm; }
.cover { height: 297mm; width: 210mm; background: #0f0e0c; color: #cfc3a6; position: relative; overflow: hidden; break-after: page; }
.cover img.bg { position: absolute; left: 0; bottom: 0; width: 100%; }
.cover .t { position: absolute; left: 18mm; right: 18mm; top: 34mm; }
.cover h1 { break-before: auto; font-family: DM; font-weight: 400; font-size: 44px; line-height: 1.1; color: #ece3cc; margin: 0 0 10px; border: 0; letter-spacing: 1px; }
.cover .torii { font-family: SUMI; font-size: 44px; color: #d0583a; display: block; margin-bottom: 18px; }
.cover p.sub { font-family: Serif; font-style: italic; font-size: 13pt; color: #cfc3a6; max-width: 140mm; margin: 0 0 8px; }
.cover p.date { font-family: DM; font-size: 11px; color: #7b7365; margin: 0; }
.cover .rule { height: 2px; background: #d0583a; width: 40mm; margin: 14px 0 16px; }
.toc { break-after: page; }
.toc h1 { break-before: auto; }
.toc ol { list-style: none; padding: 0; margin: 6px 0; columns: 2; column-gap: 10mm; font-family: Sans; font-size: 7.9pt; }
.toc li { margin: 1px 0; break-inside: avoid; }
.toc li.l1 { font-family: DM; font-size: 11px; color: #0f0e0c; margin-top: 5px; }
.toc li.l2 { padding-left: 4mm; color: #4a443a; }
.toc li.l3 { padding-left: 8mm; color: #776f60; font-size: 7.2pt; margin: 0; }
h1 { font-family: DM; font-weight: 400; font-size: 22px; color: #0f0e0c; margin: 0 0 10px; padding: 0 0 6px;
     border-bottom: 2px solid #d0583a; break-after: avoid; break-before: page; }
h2 { font-family: DM; font-weight: 400; font-size: 16.5px; color: #2b2721; margin: 18px 0 6px; break-after: avoid; }
h3 { font-family: DM; font-weight: 400; font-size: 13px; color: #2b2721; margin: 14px 0 4px; break-after: avoid; }
h1 + p, h2 + p { margin-top: 4px; }
p { margin: 6px 0; } ul, ol { padding-left: 16px; margin: 6px 0; } li { margin: 3px 0; }
strong { color: #0f0e0c; }
a { color: #9c3922; text-decoration: none; }
code { font-family: JBM, monospace; font-size: 8.2pt; background: #e2d9c2; padding: 0 3px; border-radius: 2px; overflow-wrap: anywhere; }
pre { background: #161411; color: #cfc3a6; padding: 9px 11px; font-size: 8pt; line-height: 1.45; border-left: 3px solid #d0583a; break-inside: avoid; white-space: pre-wrap; }
pre code { background: none; color: inherit; padding: 0; font-size: 8pt; }
.tw { break-inside: auto; margin: 8px 0 12px; }
table { border-collapse: collapse; width: 100%; font-family: Sans, sans-serif; font-size: 8.1pt; line-height: 1.4; }
th { font-family: DM; font-weight: 400; font-size: 11px; background: #2b2721; color: #ece3cc; text-align: left; padding: 5px 7px; }
td { border-bottom: 1px solid #c2b79b; padding: 4px 7px; vertical-align: top; }
tr { break-inside: avoid; }
td code { font-size: 7.6pt; }
figure { margin: 10px 0 14px; break-inside: avoid; text-align: center; }
figure img { display: block; margin: 0 auto; box-sizing: content-box; outline: 1px solid #2b2721; }
.sw { display:inline-block; width:9px; height:9px; border:1px solid #2b2721; margin-right:3px; vertical-align:-1px; }
figcaption { font-family: Sans; font-size: 7.8pt; color: #776f60; margin: 4px auto 0; text-align: left; max-width: 100%; }
"""
# a table of contents from the headings
nocode = re.sub(r"^```.*?^```", "", body, flags=re.M | re.S)   # (a "# comment" in a code block is no heading)
heads = re.findall(r"^(#{1,3}) (.+)$", nocode, re.M)
toc = "<section class='toc'><h1>Contents</h1><ol>" + "".join(
    f"<li class='l{len(h)}'>{markdown.markdown(re.sub(r'^(\d+)\. ', r'\1\\. ', t))[3:-4]}</li>" for h, t in heads) + "</ol></section>"
cover_src = "/home/kawau/.local/share/fedokawaii/dark/scene.png"
cover_raw = cover_src if os.path.exists(cover_src) else f"{S}/mock/wall-dark.png"
_cw = Image.open(cover_raw).width                     # the scene, full-bleed across 210 mm:
cover_bg = printable(cover_raw, 210 * MM / _cw, f"{IMG}/cover.png")   # (each art pixel an exact block)
torii = chr(0xFE000)
doc = (f"<!doctype html><html><head><meta charset='utf-8'><title>Fedokawaii — the handbook</title><style>{CSS}</style></head><body>"
       f"<section class='cover'><img class='bg' src='file://{cover_bg}'><div class='t'>"
       f"<span class='torii'>{torii}</span><h1>{meta['title']}</h1><div class='rule'></div>"
       f"<p class='sub'>{meta['subtitle']}</p><p class='date'>{meta['date']}</p></div></section>"
       f"<main>{toc}{html}</main></body></html>")
open(f"{OUT}/guide2.html", "w", encoding="utf-8").write(doc)
if missing: print("figures missing:", ", ".join(missing))

from playwright.sync_api import sync_playwright
with sync_playwright() as p:
    b = p.chromium.launch(executable_path=CHROME, args=["--no-sandbox"])
    pg = b.new_page()
    pg.goto(f"file://{OUT}/guide2.html"); pg.evaluate("document.fonts.ready"); pg.wait_for_timeout(800)
    # nothing may be wider than the page: Chromium would shrink every page to fit it
    pg.emulate_media(media="print"); pg.set_viewport_size({"width": round(210 * MM), "height": 1123})
    wide = pg.evaluate("""() => [...document.querySelectorAll('main *')].filter(e => {
        const r = e.getBoundingClientRect(); return r.right > document.documentElement.clientWidth - 15 * 96 / 25.4 + 0.5 && r.width > 0;
      }).slice(0, 12).map(e => e.tagName + '.' + (e.className || '') + ' ' + Math.round(e.getBoundingClientRect().right) + ' ' + (e.textContent || '').slice(0, 60))""")
    if wide: print("wider than the text column:", *wide, sep="\n  ")
    pg.pdf(path=f"{OUT}/Fedokawaii-Guide.pdf", format="A4", print_background=True, prefer_css_page_size=True)
    b.close()
print("pdf", os.path.getsize(f"{OUT}/Fedokawaii-Guide.pdf") // 1024, "KiB")
# the pictures re-compressed losslessly (pdfpack.py, beside this script): under 10 MB
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pdfpack
pdfpack.main(f"{OUT}/Fedokawaii-Guide.pdf", f"{OUT}/Fedokawaii-Guide.packed.pdf")
os.replace(f"{OUT}/Fedokawaii-Guide.packed.pdf", f"{OUT}/Fedokawaii-Guide.pdf")
print("packed", os.path.getsize(f"{OUT}/Fedokawaii-Guide.pdf") // 1024, "KiB")
