#!/usr/bin/env python3
"""Builds Fedokawaii-Guide.pdf from docs/fedokawaii-guide.md and REAL renders
($FEDOKAWAII_SCRATCH/real/shots/{dark,light}: the real apps at Fedora 44's versions)."""
import re, os, sys, math, html as H
from pathlib import Path
USAGE = """usage: python3 docs/build/handbook.py        builds docs/Fedokawaii-Guide.pdf (a few minutes)
       python3 docs/build/handbook.py --help  this text
The repository is the one this script sits in (FEDOKAWAII_REPO overrides it); the renders and
the scratch folder come from FEDOKAWAII_SCRATCH, the output folder from FEDOKAWAII_OUT."""
# (anything but no argument at all is not a build: a stray --help must never start one)
if len(sys.argv) > 1:
    print(USAGE, file=sys.stdout if sys.argv[1] in ("-h", "--help") else sys.stderr)
    sys.exit(0 if sys.argv[1] in ("-h", "--help") else 2)
import markdown, numpy as np
from PIL import Image, ImageDraw, ImageFont
S = os.environ.get("FEDOKAWAII_SCRATCH") or sys.exit("handbook.py: FEDOKAWAII_SCRATCH names the folder with the renders (real/shots)")
# the repository this script belongs to (docs/build/ → its root), never a fixed path: run from a
# copy, it builds that copy
REPO = os.environ.get("FEDOKAWAII_REPO", str(Path(__file__).resolve().parents[2]))
CHROME = os.environ.get("FEDOKAWAII_CHROME", "/opt/pw-browsers/chromium-1194/chrome-linux/chrome")
OUT = os.environ.get("FEDOKAWAII_OUT", f"{S}/guide")   # (test copy: configurable)
IMG = f"{OUT}/img2"
R = f"{S}/real/shots"
NM = f"{S}/mock/node_modules/@fontsource"
GAP = (90, 90, 90)
os.makedirs(IMG, exist_ok=True)
# the desktop's own faces: Fusion Pixel (as setup installs it) for headings and labels, the
# toolkit's Sumi Icons; the cover is the dark theme's default wallpaper, ink-ridges-night
PIXEL = os.environ.get("FEDOKAWAII_PIXEL_FONT", "/usr/local/share/fonts/fusion-pixel/fusion-pixel-12px-monospaced-ja.ttf")
SUMI = f"{REPO}/configs/home/.local/share/fonts/SumiIcons.ttf"
COVER = os.environ.get("FEDOKAWAII_COVER", "/home/kawau/.local/share/fedokawaii/wallpapers/dark/ink-ridges-night.src")
for need in (PIXEL, SUMI, COVER):
    if not os.path.exists(need): sys.exit(f"handbook.py: {need} is missing")
DM = ImageFont.truetype(PIXEL, 24)                      # (24 px: the pixel font's grid × 2)

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
            "app-share", "app-torrra", "app-brave", "app-wiremix", "app-bluetui", "app-visidata"):
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
# (each kept as fetched: NAME.src, any size, a painting rather than pixel art — scaled smoothly)
def wall(mode, name, w, h): return im(f"{W}/{mode}/{name}.src").resize((w, h), Image.LANCZOS)
add("pack", grid([[wall("dark", "ink-ridges-night", 960, 540), wall("light", "ink-ridges", 960, 540)]], f"{IMG}/pack.png"))
tw, th, cols = 320, 180, 6
rows = -(-len(entries) // cols)
sheet = Image.new("RGB", (cols * (tw + 12) + 12, rows * (th + 40) + 12), (15, 14, 12)); d = ImageDraw.Draw(sheet)
for i, (mode, name) in enumerate(entries):
    x = 12 + (i % cols) * (tw + 12); y = 12 + (i // cols) * (th + 40)
    sheet.paste(wall(mode, name, tw, th), (x, y))
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

add("grub", f"{R}/grub.png")                            # (render/grub.sh: GRUB itself, in QEMU)
subprocess.run(["python3", f"{REPO}/tools/build-icons.py", "--preview", f"{IMG}/icons.png"], check=True, capture_output=True)
add("icons", f"{IMG}/icons.png")

# ── the document ───────────────────────────────────────────────────────────────
src = open(os.environ.get("FEDOKAWAII_GUIDE", f"{REPO}/docs/fedokawaii-guide.md"), encoding="utf-8").read()
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
html = re.sub(r"<code>(#[0-9a-f]{6})</code>", r"<span class='swc'><span class='sw' style='background:\1'></span><code>\1</code></span>", html)   # (swatch and value: one unit)
html = re.sub(r"<h1>((?:Part [IVXLC]+|Appendices)\b.*?)</h1>", r"<h1 class='part'>\1</h1>", html)   # book: Part title pages
html = re.sub(r"(<h1 class='part'>.*?)(?=<h1)", r"<section class='partpage'>\1</section>", html, flags=re.S)
_n = iter(range(1, 10**6))                            # every contents heading a link target (its page number)
html = re.sub(r"<h([12])( class='part')?>", lambda m: f"<h{m[1]}{m[2] or ''} id='t{next(_n)}'>", html)
def code_breaks(c):   # inline code breaks after a / of a path, never inside an --option
    return re.sub(r"(?<![^\s(])(--?[\w.=:,+-]+)", r"<span class='nw'>\1</span>", c.replace("/", "/<wbr>"))
html = re.sub(r"(?<!<pre>)<code>([^<]*)</code>", lambda m: "<code>" + code_breaks(m[1]) + "</code>", html)
html = re.sub(r"<p><strong>What you learnt</strong></p>\s*<ul>.*?</ul>\s*<p><strong>Check yourself</strong></p>\s*<ol>.*?</ol>",
              lambda m: "<div class='recap'>" + re.sub(r"<p><strong>(What you learnt|Check yourself)</strong></p>", r"<p class='lbl'>\1</p>", m[0]) + "</div>",
              html, flags=re.S)
html = re.sub(r"(<pre>(?:(?!<pre>).)*?</pre>)\s*<p>((?:<em>)?\(.*?)</p>",   # a block and its "(for example)" note: one unit
              lambda m: f"<div class='grp{' cont' if m[2].endswith(':') else ''}'>{m[1]}<p class='note'>{m[2]}</p></div>", html, flags=re.S)
html = re.sub(r"<(p|li)>((?:(?!</?\1>).)*?)</\1>(?=\s*(?:</[ou]l>\s*)?<(?:pre|div class='(?:grp|tw)|ul|ol))",   # a lead-in: "…:",
              lambda m: f"<{m[1]} class='lead-in'>{m[2]}</{m[1]}>"                                     # a step "**2.** …",
              if m[2].endswith(":") or re.match(r"<strong>(\d+\.|Try this)", m[2]) or len(re.sub(r"<[^>]+>", "", m[2])) <= 100
              else m[0], html, flags=re.S)                                                          # "Try this", a label
html = re.sub(r"<p><strong>([^<]{1,60})</strong></p>", r"<p class='lead'><strong>\1</strong></p>", html)   # a label ("Terms.", "Pitfalls.")
def short_cols(m):   # a column whose every cell is short (a key, a name) never wraps; nor does a short header or code
    t = m[0]
    rows = re.findall(r"<tr>(.*?)</tr>", t, re.S)
    cells = [re.findall(r"<t[hd][^>]*>(.*?)</t[hd]>", r, re.S) for r in rows]
    n = min(len(c) for c in cells)
    vis = lambda x: H.unescape(re.sub(r"<[^>]+>", "", x)).strip()
    narrow = {i for i in range(n) if max(len(vis(c[i])) for c in cells) <= 20}
    for r in rows:
        cs = re.findall(r"<t[hd][^>]*>.*?</t[hd]>", r, re.S)
        new = "".join(re.sub(r"^<(t[hd])", r"<\1 class='nw'", c) if i in narrow or (c.startswith("<th") and len(vis(c)) <= 16)
                      else c for i, c in enumerate(cs))
        t = t.replace(r, "\n" + new + "\n", 1)
    return re.sub(r"<code>((?:[^<]|<wbr>|</?span[^>]*>){1,120}?)</code>", lambda c: f"<code class='nw'>{re.sub(r'<[^>]+>', '', c[1])}</code>"
                  if len(re.sub(r"<[^>]+>", "", c[1])) <= 26 else c[0], t)
html = re.sub(r"<table>.*?</table>", short_cols, html, flags=re.S)

def ff(name, path, w="400", s="normal"):
    return f"@font-face{{font-family:'{name}';src:url('file://{path}');font-weight:{w};font-style:{s}}}"
CSS = "\n".join([
    ff("DM", PIXEL),
    ff("SUMI", SUMI),
    # (not "Serif": unquoted, that is the generic keyword, and the body fell back to the system serif)
    ff("NotoSerif", f"{NM}/noto-serif/files/noto-serif-latin-400-normal.woff2"),
    ff("NotoSerif", f"{NM}/noto-serif/files/noto-serif-latin-700-normal.woff2", "700"),
    ff("NotoSerif", f"{NM}/noto-serif/files/noto-serif-latin-400-italic.woff2", "400", "italic"),
    ff("NotoSerif", f"{NM}/noto-serif/files/noto-serif-latin-700-italic.woff2", "700", "italic"),
    ff("Sans", f"{NM}/noto-sans/files/noto-sans-latin-400-normal.woff2"),
    ff("Sans", f"{NM}/noto-sans/files/noto-sans-latin-700-normal.woff2", "700"),
    ff("Sans", f"{NM}/noto-sans/files/noto-sans-latin-400-italic.woff2", "400", "italic"),
    # arrows, ≥ ≈, ⌄, ✔ ✘: not in Noto's latin files; one face for them everywhere
    ff("Sym", "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf")[:-1] + ";unicode-range:U+2190-23FF,U+25A0-27BF}",
    ff("Sym", "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", "700")[:-1] + ";unicode-range:U+2190-23FF,U+25A0-27BF}",
    ff("JBM", f"{S}/mock/fonts/jbm/JetBrainsMonoNerdFont-Regular.ttf"),
]) + """
@page { size: A4; margin: 16mm 0 18mm; background: #efe8d5;
  @bottom-center { content: counter(page); font-family: DM; font-size: 12px; color: #776f60; } }
@page :first { margin: 0; background: #0f0e0c; @bottom-center { content: none; } }
html { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
body { font-family: NotoSerif, Sym, 'Noto Serif CJK JP', serif; font-size: 9.6pt; line-height: 1.5; color: #2b2721; margin: 0; }
/* every page the same width (the cover's, A4's): the text column is the padding, so no page
   is wider than another and nothing is ever shrunk to fit */
main { padding: 0 15mm; }
.cover { height: 297mm; width: 210mm; background: #0f0e0c; color: #cfc3a6; position: relative; overflow: hidden; break-after: page; }
.cover img.bg { position: absolute; left: 0; top: 0; width: 100%; height: 100%; }
.cover .shade { position: absolute; left: 0; bottom: 0; width: 100%; height: 55%; background: linear-gradient(#0f0e0c00 0, #0f0e0c99 50%, #0f0e0ce6 100%); }
.cover .t { position: absolute; left: 18mm; right: 18mm; bottom: 30mm; }
.cover h1 { break-before: auto; font-family: DM; font-weight: 400; font-size: 48px; line-height: 1.1; color: #ece3cc; margin: 0 0 10px; border: 0; letter-spacing: 1px; }
.cover .torii { font-family: SUMI; font-size: 44px; color: #d0583a; display: block; margin-bottom: 18px; }
.cover p.sub { font-family: NotoSerif; font-style: italic; font-size: 13pt; color: #cfc3a6; max-width: 140mm; margin: 0 0 8px; }
.cover p.date { font-family: DM; font-size: 12px; color: #b9ad92; margin: 0; }
.cover .rule { height: 2px; background: #d0583a; width: 40mm; margin: 14px 0 16px; }
.toc { break-after: page; }
.toc h1 { break-before: auto; }
.toc ol { list-style: none; padding: 0; margin: 6px 0; columns: 2; column-gap: 10mm; font-family: Sans, Sym, 'Noto Sans CJK JP', sans-serif; font-size: 7.9pt; }
.toc li { margin: 1px 0; break-inside: avoid; }
.toc li.l0 { font-family: DM; font-size: 12px; color: #c0462a; margin-top: 10px; }
.toc li.l1 { font-family: DM; font-size: 12px; color: #0f0e0c; margin-top: 5px; }
.toc li.l2 { padding-left: 4mm; color: #4a443a; }
.toc li.l3 { padding-left: 8mm; color: #776f60; font-size: 7.2pt; margin: 0; }
.toc li.l0, .toc li.l1 { break-after: avoid; }
/* title, dotted leader after its last line, page number at the right; a long title hangs */
.toc a { display: block; position: relative; padding-right: 2.4em; color: inherit; }
.toc .tt { position: relative; z-index: 1; background: #efe8d5; padding-right: 5px; }
.toc .ld { position: absolute; left: 0; right: 2.3em; bottom: 0.3em; border-bottom: 1px dotted #b3a88c; }
.toc .pn { position: absolute; right: 0; bottom: 0; text-indent: 0; font-variant-numeric: tabular-nums; }
.toc li.l1 a { padding-left: 4ch; text-indent: -4ch; } .toc li.l1 .ld { left: 4ch; }
.toc li.l2 a { padding-left: 2.3em; text-indent: -2.3em; } .toc li.l2 .ld { left: 2.3em; }
h1 { font-family: DM; font-weight: 400; font-size: 24px; color: #0f0e0c; margin: 0 0 10px; padding: 0 0 6px;
     border-bottom: 2px solid #d0583a; break-after: avoid; break-before: page; }
h2 { font-family: DM; font-weight: 400; font-size: 18px; color: #2b2721; margin: 18px 0 6px; break-after: avoid; }
h3 { font-family: DM; font-weight: 400; font-size: 12px; color: #2b2721; margin: 14px 0 4px; break-after: avoid; }
h1 + p, h2 + p { margin-top: 4px; }
p { margin: 6px 0; } ul, ol { padding-left: 16px; margin: 6px 0; } li { margin: 3px 0; }
strong { color: #0f0e0c; }
a { color: #9c3922; text-decoration: none; }
code { font-family: JBM, monospace; font-size: 8.2pt; background: #e2d9c2; padding: 0 3px; border-radius: 2px; overflow-wrap: anywhere;
       font-variant-ligatures: none; }   /* -->, !=, >= print as typed, never as one ligature glyph */
pre { background: #161411; color: #cfc3a6; padding: 9px 11px; font-size: 8pt; line-height: 1.45; border-left: 3px solid #d0583a; break-inside: avoid; white-space: pre-wrap; }
pre code { background: none; color: inherit; padding: 0; font-size: 8pt; }
.tw { break-inside: auto; margin: 8px 0 12px; }
table { border-collapse: collapse; width: 100%; font-family: Sans, Sym, 'Noto Sans CJK JP', sans-serif; font-size: 8.1pt; line-height: 1.4; }
th { font-family: DM; font-weight: 400; font-size: 12px; background: #2b2721; color: #ece3cc; text-align: left; padding: 5px 7px; }
td { border-bottom: 1px solid #c2b79b; padding: 4px 7px; vertical-align: top; }
tr { break-inside: avoid; }
td code { font-size: 7.6pt; overflow-wrap: break-word; }   /* a column never narrower than its longest name */
th code { background: #4a443a; color: #ece3cc; } th strong, th em { color: inherit; }
.nw { white-space: nowrap; }
tbody tr:first-child { break-after: avoid; } tbody tr:last-child { break-before: avoid; }   /* no lone row */
p.lead, p:has(+ p.lead) { break-after: avoid; }
.grp { break-inside: avoid; } .grp.cont { break-after: avoid; }   /* (cont: its note ends in a lead-in, "…:") */
.tw.keep { break-inside: avoid; }                     /* a short table whole, on one page (marked when printed) */
/* a lead-in ("…, type:") stays with the block it introduces (a figure may go to the next page: it is referred to) */
p.lead-in, :is(ul, ol):has(> li:last-child.lead-in) { break-after: avoid; }
figure { margin: 10px 0 14px; break-inside: avoid; text-align: center; }
figure img { display: block; margin: 0 auto; box-sizing: content-box; outline: 1px solid #2b2721; }
.swc { white-space: nowrap; }
.sw { display:inline-block; width:9px; height:9px; border:1px solid #2b2721; margin-right:3px; vertical-align:-1px; }
/* a Part: its own page, the title and opening centred on it (a little above the middle) */
.partpage { break-before: page; break-after: page; height: 262mm; display: flex; flex-direction: column;
            justify-content: center; padding-bottom: 24mm; box-sizing: border-box; }
h1.part { font-size: 30px; border: 0; text-align: center; margin: 0; padding: 0; break-before: auto; }
.partpage > p { text-align: center; font-style: italic; max-width: 125mm; margin: 4mm auto 0; color: #4a443a; }
h1.part + p { margin-top: 6mm; }
.recap { break-inside: avoid; margin-top: 16px; border-top: 1px solid #c2b79b; }
.recap .lbl { font-family: DM; font-size: 12px; color: #c0462a; margin: 10px 0 4px; }
blockquote { margin: 9px 0 11px; padding: 6px 11px; background: #e6dec6; border-left: 3px solid #5f7fa0; break-inside: avoid; }
blockquote p { margin: 3px 0; } blockquote ul, blockquote ol { margin: 3px 0; }
figcaption { font-family: Sans, Sym, 'Noto Sans CJK JP', sans-serif; font-size: 7.8pt; color: #776f60; margin: 4px auto 0; text-align: left; max-width: 100%; }
"""
# a table of contents from the headings
nocode = re.sub(r"^```.*?^```", "", body, flags=re.M | re.S)   # (a "# comment" in a code block is no heading)
heads = re.findall(r"^(#{1,%d}) (.+)$" % int(os.environ.get("BOOK_TOC_LEVELS", "2")), nocode, re.M)
assert len(heads) == len(re.findall(r"<h[12][ >]", html)), "contents and headings differ"
toc = "<section class='toc'><h1>Contents</h1><ol>" + "".join(   # (page numbers: 000 until the first print says where)
    f"<li class='{'l0' if re.match(r'(Part [IVXLC]+|Appendices)\b', t) else 'l' + str(len(h))}'><a href='#t{i}'>"
    f"<span class='tt'>{markdown.markdown(re.sub(r'^(\d+)\. ', r'\1\\. ', t))[3:-4]}</span><span class='ld'></span><span class='pn'>000</span></a></li>"
    for i, (h, t) in enumerate(heads, 1)) + "</ol></section>"
# ink-ridges-night, cut to the page (210 × 297): the moon and the ridges under it, from the
# right of the picture, the moon high in the sky; the title on the dark ridges, shaded under the words
_c = Image.open(COVER).convert("RGB")
_h = _c.height; _w = round(_h * 210 / 297); _x = round(_c.width * 0.473)
cover_bg = f"{IMG}/cover.jpg"; _c.crop((_x, 0, _x + _w, _h)).save(cover_bg, quality=92)
torii = chr(0xFE000)
doc = (f"<!doctype html><html><head><meta charset='utf-8'><title>Fedokawaii — the handbook</title><style>{CSS}</style></head><body>"
       f"<section class='cover'><img class='bg' src='file://{cover_bg}'><div class='shade'></div><div class='t'>"
       f"<span class='torii'>{torii}</span><h1>{'\u00a0'.join(meta['title'].rsplit(' ', 1))}</h1><div class='rule'></div>"
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
    pg.evaluate("""() => {   // tables in a row with the same header (Keys | Does …) get the same column widths
        const tws = [...document.querySelectorAll('.tw')], sig = t => [...t.querySelectorAll('th')].map(x => x.textContent).join('|');
        let run = [];
        const flush = () => { if (run.length > 1) { const ths = run.map(t => [...t.querySelectorAll('th')]);
            const w = ths[0].map((_, i) => Math.max(...ths.map(r => r[i].getBoundingClientRect().width)));
            ths.forEach(r => r.slice(0, -1).forEach((th, i) => th.style.width = w[i] + 'px')); } run = []; };
        tws.forEach(t => { const prev = run[run.length - 1];
            let near = prev && sig(prev) === sig(t);
            for (let e = prev && prev.nextElementSibling; near && e && e !== t; e = e.nextElementSibling)
                if (!['P', 'H3'].includes(e.tagName)) near = false;
            if (!near) flush(); run.push(t); });
        flush();
        document.querySelectorAll('.tw').forEach(t => t.offsetHeight <= 240 && t.classList.add('keep'));   // ≤ ¼ page
        // a paragraph of three lines or fewer is never split: Chromium keeps 2 lines (orphans) and lets one
        // line (a widow) start the next page when it cannot keep both
        document.querySelectorAll('main p, main li').forEach(e => {
            if (e.offsetHeight < parseFloat(getComputedStyle(e).lineHeight) * 3.5) e.style.breakInside = 'avoid'; });
    }""")
    def pages():   # the page each contents heading landed on: its link's named destination
        import pikepdf
        with pikepdf.open(f"{OUT}/Fedokawaii-Guide.pdf") as pdf:
            at = {page.objgen: i + 1 for i, page in enumerate(pdf.pages)}
            dests = {str(k).lstrip("/"): v for k, v in pdf.Root.Dests.items()}
            return [str(at[dests[f"t{i}"][0].objgen]) for i in range(1, len(heads) + 1)]
    for _ in range(3):   # print, write the numbers in (same width: nothing moves), print again
        pg.pdf(path=f"{OUT}/Fedokawaii-Guide.pdf", format="A4", print_background=True, prefer_css_page_size=True)
        nums = pages()
        if nums == pg.evaluate("() => [...document.querySelectorAll('.toc .pn')].map(e => e.textContent)"): break
        pg.evaluate("ns => document.querySelectorAll('.toc .pn').forEach((e, i) => e.textContent = ns[i])", nums)
    else: print("contents: page numbers still moving")
    b.close()
print("pdf", os.path.getsize(f"{OUT}/Fedokawaii-Guide.pdf") // 1024, "KiB")
# the pictures re-compressed losslessly (pdfpack.py, beside this script): every pixel the same, a tenth smaller
sys.dont_write_bytecode = True                 # (no __pycache__ left in the repository)
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pdfpack
pdfpack.main(f"{OUT}/Fedokawaii-Guide.pdf", f"{OUT}/Fedokawaii-Guide.packed.pdf")
os.replace(f"{OUT}/Fedokawaii-Guide.packed.pdf", f"{OUT}/Fedokawaii-Guide.pdf")
print("packed", os.path.getsize(f"{OUT}/Fedokawaii-Guide.pdf") // 1024, "KiB")
