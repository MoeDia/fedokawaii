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
sys.dont_write_bytecode = True                 # (no __pycache__ left in the repository)
import markdown, numpy as np, importlib.util
from PIL import Image, ImageDraw, ImageFont
S = os.environ.get("FEDOKAWAII_SCRATCH") or sys.exit("handbook.py: FEDOKAWAII_SCRATCH names the folder with the renders (real/shots)")
# the repository this script belongs to (docs/build/ → its root), never a fixed path: run from a
# copy, it builds that copy
REPO = os.environ.get("FEDOKAWAII_REPO", str(Path(__file__).resolve().parents[2]))
# the palette: the desktop's own (tools/build-themes.py, the only place a colour is written
# down) — the light theme's tokens are the book's ink and paper, the dark theme's the cover's
_spec = importlib.util.spec_from_file_location("build_themes", f"{REPO}/tools/build-themes.py")
_bt = importlib.util.module_from_spec(_spec); _spec.loader.exec_module(_bt)
LT, DK = _bt.P["light"], _bt.P["dark"]
def rgb(h): return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))
def stitch(col, on, per, h, k=4):
    """the stitched rule's tile as a PNG data URL: ON px of COL then transparent to PER, H tall,
    drawn K times larger (sharp when the page is zoomed). An image, never a CSS gradient:
    Chromium prints a repeating gradient as a picture of its whole clip — on a table row, a
    page-sized one per row (18 000 of them: a 135 MB PDF that took most of an hour)."""
    import base64, io
    t = Image.new("RGBA", (per * k, h * k), (0, 0, 0, 0))
    t.paste(rgb(col) + (255,), (0, 0, on * k, h * k))
    b = io.BytesIO(); t.save(b, "PNG")
    return "url(data:image/png;base64," + base64.b64encode(b.getvalue()).decode() + ")"
CHROME = os.environ.get("FEDOKAWAII_CHROME", "/opt/pw-browsers/chromium-1194/chrome-linux/chrome")
OUT = os.environ.get("FEDOKAWAII_OUT", f"{S}/guide")   # (test copy: configurable)
# the book's file name: the handbook's by default; learn.py (beside this script) prints the
# learning guide through the same machinery under its own
PDF = os.environ.get("FEDOKAWAII_PDF", "Fedokawaii-Guide.pdf")
IMG = f"{OUT}/img2"
R = f"{S}/real/shots"
NM = f"{S}/mock/node_modules/@fontsource"
GAP = rgb(LT["muted"])                     # between the two themes' pictures: the panels' frame grey
os.makedirs(IMG, exist_ok=True)
# the desktop's own faces: Sumi UI (the toolkit's, system/fonts) for headings and labels —
# in print at 12 px, three quarters of its grid: its letters 6 px a column, the panels' units
# below unchanged; its pixels are squares of the outline, sharp at any zoom — and the
# toolkit's Sumi Icons; the cover is the dark theme's default wallpaper, ink-ridges-night
PIXEL = os.environ.get("FEDOKAWAII_PIXEL_FONT", f"{REPO}/system/fonts/SumiUI.ttf")
SUMI = f"{REPO}/configs/home/.local/share/fonts/SumiIcons.ttf"
COVER = os.environ.get("FEDOKAWAII_COVER", "/home/kawau/.local/share/fedokawaii/wallpapers/dark/ink-ridges-night.src")
for need in (PIXEL, SUMI, COVER):
    if not os.path.exists(need): sys.exit(f"handbook.py: {need} is missing")
DM = ImageFont.truetype(PIXEL, 32)                      # (32 px: the face's grid × 2)

def im(p): return Image.open(p).convert("RGB")

def scale(img, k): return img.resize((img.width * k, img.height * k), Image.NEAREST) if k != 1 else img

INK, PAPER = rgb(DK["ground"]), rgb(LT["ground"])
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
MAXH = {"desktop-dark": 236, "desktop-light": 236, "packsheet": 236, "lock": 84,
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

# the pack: two pictures, then the whole sheet
W = "/home/kawau/.local/share/fedokawaii/wallpapers"
entries = [l.split()[:2] for l in open(f"{REPO}/configs/home/.local/share/fedokawaii/wallpapers.list") if l.split()[:1] in (["dark"], ["light"])]
# (each kept as fetched: NAME.src, any size, a painting rather than pixel art — scaled smoothly)
def wall(mode, name, w, h): return im(f"{W}/{mode}/{name}.src").resize((w, h), Image.LANCZOS)
add("pack", grid([[wall("dark", "ink-ridges-night", 960, 540), wall("light", "ink-ridges", 960, 540)]], f"{IMG}/pack.png"))
tw, th, cols = 320, 180, 6
rows = -(-len(entries) // cols)
sheet = Image.new("RGB", (cols * (tw + 12) + 12, rows * (th + 40) + 12), INK); d = ImageDraw.Draw(sheet)
for i, (mode, name) in enumerate(entries):
    x = 12 + (i % cols) * (tw + 12); y = 12 + (i // cols) * (th + 40)
    sheet.paste(wall(mode, name, tw, th), (x, y))
    d.text((x, y + th + 6), name, font=DM, fill=rgb(DK["text"]) if mode == "dark" else rgb(DK["accent_hi"]))
sheet.save(f"{IMG}/packsheet.png"); add("packsheet", f"{IMG}/packsheet.png")

# fetch: the ten pictures, read from bin/fetch, on ink and on paper
src = open(f"{REPO}/bin/fetch").read()
arts = re.findall(r"^ART_(\w+)=\(\n(.*?)\n\)", src, re.M | re.S)
k = 8
fw = len(arts) * (20 * k + 24) + 24
fimg = Image.new("RGB", (fw, 2 * (16 * k + 24) + 24), INK); fd = ImageDraw.Draw(fimg)
fd.rectangle([0, 16 * k + 36, fw, fimg.height], fill=PAPER)
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

# ── the design system in print (docs/design-system.md §8) ──────────────────────
# Every chapter opens as a panel's part does: its seal (one kanji in a 1 px edge2 frame, the
# kanji vermilion), its name, the stitch to the right edge; its sections carry the same seal.
# One kanji per chapter, the desktop's own where the chapter is that part of it (音 the sound
# panel, 盤 drives, 窓 windows, 端 the terminal …, from kawa-panel, kawa-help and kawa-config);
# a Part's seal is the workspace's: the numeral, filled vermilion, as on the bar.
KANJI = {
    "How to read this book": "案",   # a guide (案内; kawa-config's "help")
    "Contents": "目",                # 目次, the contents
    "1": "何",   # what this is
    "2": "語",   # in plain words
    "3": "備",   # preparing (準備)
    "4": "導",   # installing (導入)
    "5": "設",   # the setup (設定)
    "6": "席",   # the first login: the session (kawa-help)
    "7": "窓",   # windows (kawa-help)
    "8": "品",   # menus (お品書き)
    "9": "彩",   # theme and wallpaper: colour
    "10": "書",  # files (kawa-help)
    "11": "端",  # the terminal (kawa-help)
    "12": "写",  # copy and screenshots (kawa-help)
    "13": "盤",  # drives (kawa-panel, kawa-drives)
    "14": "起",  # programs: launch (kawa-help)
    "15": "音",  # sound (the sound panel)
    "16": "読",  # reading
    "17": "筆",  # writing: the brush (kawa-help's drawing)
    "18": "探",  # finding
    "19": "手",  # by your own hand (kawa-config's "use")
    "20": "流",  # torrents: the stream
    "21": "遊",  # games: play
    "22": "図",  # a map (地図)
    "23": "樹",  # the file system: a tree
    "24": "権",  # permissions: rights (権限)
    "25": "言",  # the shell as a language
    "26": "動",  # processes: what moves
    "27": "包",  # packages: wrapped
    "28": "時",  # services and timers (kawa-timer)
    "29": "始",  # how it starts
    "30": "機",  # hardware: the machine
    "31": "画",  # graphics
    "32": "話",  # how programs talk
    "33": "網",  # the network (quick settings)
    "34": "守",  # security: kept safe
    "35": "系",  # the system's control (kawa-config's "system")
    "36": "新",  # updates: new
    "37": "戻",  # snapshots: going back
    "38": "掃",  # keeping it clean: sweeping
    "39": "救",  # when something goes wrong: rescue
    "40": "見",  # how the look is built (kawa-config's "look")
    "41": "史",  # history (kawa-config)
    "42": "改",  # changing it
    "43": "学",  # learning to program
    "44": "問",  # asking an assistant
    "A": "具", "B": "所", "C": "鍵", "D": "令", "E": "辞", "F": "今", "G": "源",
}
# a book's own chapters: its front matter's kanji: "1=始 2=端 …" (the learning guide's)
KANJI.update(k.split("=", 1) for k in meta.get("kanji", "").split())
PART_KANJI = {"I": "一", "II": "二", "III": "三", "IV": "四", "V": "五", "VI": "六", "VII": "七", "Appendices": "付"}
def kanji_of(title):
    t = H.unescape(re.sub(r"<[^>]+>", "", title)).strip()
    m = re.match(r"(\d+|[A-Z])\. ", t)
    k = KANJI.get(m[1] if m else t)
    if not k: print(f"handbook.py: no kanji for the chapter “{t}” (KANJI): 節, a section"); k = "節"
    return k
def seal(k, cls="seal"): return f"<span class='{cls}'>{k}</span>"
def heading(k, inner): return f"{seal(k)}<span class='nm'>{inner}</span><span class='st'></span>"
def seal_heads(html):
    k = KANJI["How to read this book"]
    def one(m):
        nonlocal k
        lvl, part, hid, inner = m[1], m[2], m[3], m[4]
        if part:
            pk = re.match(r"Part ([IVXLC]+)\b", inner)
            return f"<h1 class='part' id='{hid}'>{seal(PART_KANJI.get(pk[1] if pk else 'Appendices', '付'), 'wseal')}<span class='nm'>{inner}</span></h1>"
        if lvl == "1": k = kanji_of(inner)
        return f"<h{lvl} id='{hid}'>{heading(k, inner)}</h{lvl}>"
    return re.sub(r"<h([12])( class='part')? id='(t\d+)'>(.*?)</h\1>", one, html, flags=re.S)
html = seal_heads(html)
# the end of a chapter, as a part of a panel: 習 what you learnt, 試 check yourself
html = re.sub(r"<p class='lbl'>(What you learnt|Check yourself)</p>",
              lambda m: f"<p class='lbl'>{heading('習' if m[1].startswith('What') else '試', m[1])}</p>", html)
# a box's label (In this chapter, On Windows., Careful., Word — …) in the desktop's face
html = re.sub(r"<blockquote>\s*<p><strong>(.*?)</strong>",
              lambda m: f"<blockquote{' class=careful' if m[1].startswith('Careful') else ''}><p><strong class='cl'>{m[1]}</strong>", html, flags=re.S)
# keys as the desktop shows them: a key button (key fill, 1 px edge) round each chord, in its face
KEYNAME = (r"(?:Super|Shift|Ctrl|Alt|AltGr|Win|Windows|Right Shift|Left Shift|Return|Enter|Esc|Escape|Tab|Space|"
           r"Backspace|Delete|Del|Insert|Home|End|PgUp|PgDn|Page Up|Page Down|Up|Down|Left|Right|Print|PrtScn|Menu|Fn|"
           r"F\d{1,2}(?:…(?:F\d{1,2})?)?|\d…\d|[^\s+](?:/[^\s+])?)")
ALONE = re.compile(r"(?:Super|Shift|Ctrl|Alt|Return|Enter|Esc|Escape|Tab|Space|Backspace|Delete|Print|PrtScn|F\d{1,2}(?:…F?\d{0,2})?|[^\s\w]|[a-z0-9])")
CHORD = re.compile(rf"{KEYNAME}(?:\+{KEYNAME})+")
def keys(m):
    t = H.unescape(m[1])
    tok = re.findall(r"(?:Right|Left|Page) (?:Shift|Up|Down)(?:\+\S+)?|\S+", t)
    out = []
    for i, x in enumerate(tok):
        if x == "·" or (x == "/" and 0 < i < len(tok) - 1): out.append(f"<span class='ksep'>{H.escape(x)}</span>")
        elif CHORD.fullmatch(x) or ALONE.fullmatch(x) or (len(tok) > 1 and re.fullmatch(KEYNAME, x)): out.append(f"<kbd>{H.escape(x)}</kbd>")
        else: return m[0]                                  # words: an emphasis, not keys
    return " ".join(out)
html = re.sub(r"<strong>([^<]{1,40})</strong>", keys, html)

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
]) + "\n:root{" + "".join(f"--{k.replace('_', '-')}:#{v};" for k, v in LT.items() if re.fullmatch(r"[0-9a-f]{6}", str(v))) \
   + "".join(f"--d-{k.replace('_', '-')}:#{v};" for k, v in DK.items() if re.fullmatch(r"[0-9a-f]{6}", str(v))) + "}\n" + f"""
@page {{ size: A4; margin: 16mm 0 18mm; background: #{LT['ground']};
  @bottom-center {{ content: counter(page); font-family: DM; font-size: 12px; color: #{LT['muted']}; }} }}
@page :first {{ margin: 0; background: #{DK['ground']}; @bottom-center {{ content: none; }} }}
.cover .shade {{ background: linear-gradient(#{DK['ground']}00 0, #{DK['ground']}99 50%, #{DK['ground']}e6 100%); }}
:root {{ --stitch: {stitch(LT['edge2'], 3, 5, 1)}; --stitch2: {stitch(LT['edge2'], 6, 10, 2)};
  --d-stitch2: {stitch(DK['edge2'], 6, 10, 2)}; }}
""" + """
/* ── the system in print ──────────────────────────────────────────────────────────────────
   The panel's units at 1 px = 1 CSS px (a 12 px line of Sumi UI is 9 pt on paper): gap 6,
   pad and line 12, section 18; a chapter's opening at the terminal's 2× (24 px). Colours only
   from the palette's tokens (:root, from tools/build-themes.py); square corners everywhere. */
:root { --u6: 6px; --u12: 12px; --u18: 18px; }   /* (--stitch, --stitch2: the tiles above, edge2's) */
html { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
* { border-radius: 0 !important; }
body { font-family: NotoSerif, Sym, 'Noto Serif CJK JP', serif; font-size: 9.6pt; line-height: 1.5; color: var(--text); margin: 0; }
/* every page the same width (the cover's, A4's): the text column is the padding, so no page
   is wider than another and nothing is ever shrunk to fit */
main { padding: 0 15mm; }

/* the seal: one kanji in a 1 px edge2 frame, 5 px of air inside it (the 11 px kanji sits a
   pixel below the top of its 12 px cell, as the font draws it); ×2 for a chapter's opening */
.seal { display: inline-block; flex: none; box-sizing: border-box; width: 23px; height: 23px; border: 1px solid var(--edge2);
        padding: 4px 0 0 5px; font: 400 12px/12px DM; color: var(--accent-text); text-align: left; }
/* the workspace seal (a Part): the numeral filled vermilion, as on the bar — the only filled vermilion */
.wseal { display: inline-block; flex: none; box-sizing: border-box; width: 23px; height: 23px; background: var(--accent);
         padding: 5px 0 0 6px; font: 400 12px/12px DM; color: var(--text-on-accent); text-align: left; }
.st { display: block; flex: 1 1 24px; min-width: 24px; height: 1px; background: var(--stitch) 0 0 / 5px 1px repeat-x; }

/* headings: seal, 6, the name, 6, the stitch to the right edge through the seal's middle */
main h1, main h2, .lbl { display: flex; align-items: flex-start; font-weight: 400; break-after: avoid; }
main h2 { font: 400 12px/14px DM; color: var(--text); margin: var(--u18) 0 var(--u6); }
main h2 .nm, .lbl .nm { margin: 4px var(--u6) 0; flex: 0 1 auto; }
main h2 .st, .lbl .st { margin-top: 11px; }
main h1 { font: 400 24px/28px DM; color: var(--strong); margin: 0 0 var(--u18); padding: var(--u6) 0 0; break-before: page; }
main h1 .seal { width: 46px; height: 46px; border-width: 2px; padding: 8px 0 0 10px; font-size: 24px; line-height: 24px; }
main h1 .nm { margin: 9px var(--u12) 0; flex: 0 1 auto; }
main h1 .st { margin-top: 22px; height: 2px; background: var(--stitch2) 0 0 / 10px 2px repeat-x; }
h3 { font: 400 12px/14px DM; color: var(--strong); margin: var(--u12) 0 var(--u6); break-after: avoid; }

p { margin: var(--u6) 0; } ul, ol { padding-left: 16px; margin: var(--u6) 0; } li { margin: 3px 0; }
strong { color: var(--strong); }
a { color: var(--accent-text); text-decoration: none; }
p.lead { margin: var(--u12) 0 var(--u6); }
p.lead strong { font: 400 12px/14px DM; color: var(--strong); }

/* commands and paths: the terminal's face, as typed (no ligature: -->, != print as typed) */
code { font: 400 12px DM, SUMI, JBM, Sym, 'Noto Sans CJK JP', monospace; color: var(--strong); overflow-wrap: anywhere;
       font-variant-ligatures: none; }
/* a block of code: the terminal itself — foot's paper, a window's 2 px frame, two cells of air */
pre { font: 400 12px/15px DM, SUMI, JBM, Sym, 'Noto Sans CJK JP', monospace; background: var(--ground); color: var(--text);
      border: 2px solid var(--muted); padding: var(--u6) var(--u12); margin: var(--u12) 0; break-inside: avoid; white-space: pre-wrap;
      font-variant-ligatures: none; }
pre code { font: inherit; color: inherit; }
/* keys: a key button — key fill, 1 px edge frame, the chord in the desktop's face */
kbd { font: 400 12px/12px DM, Sym; color: var(--strong); background: var(--key); border: 1px solid var(--edge);
      padding: 1px 3px 1px 4px; white-space: nowrap; }
.ksep { color: var(--muted); }

/* tables: the head as labels, every rule the stitch (on the row: one stitch across the cells) */
.tw { break-inside: auto; margin: var(--u12) 0; }
table { border-collapse: collapse; width: 100%; font-family: Sans, Sym, 'Noto Sans CJK JP', sans-serif; font-size: 8.1pt; line-height: 1.4; }
tr { background: var(--stitch) 0 100% / 5px 1px repeat-x; break-inside: avoid; }
th { font: 400 12px/14px DM; color: var(--muted); text-align: left; padding: 0 var(--u6) var(--u6); }
td { padding: 3px var(--u6) 4px; vertical-align: top; }
td code { overflow-wrap: break-word; }   /* a column never narrower than its longest name */
th strong, th em, th code { color: inherit; }
.nw { white-space: nowrap; }
tbody tr:first-child { break-after: avoid; } tbody tr:last-child { break-before: avoid; }   /* no lone row */
p.lead, p:has(+ p.lead) { break-after: avoid; }
.grp { break-inside: avoid; } .grp.cont { break-after: avoid; }   /* (cont: its note ends in a lead-in, "…:") */
.tw.keep { break-inside: avoid; }                     /* a short table whole, on one page (marked when printed) */
/* a lead-in ("…, type:") stays with the block it introduces (a figure may go to the next page: it is referred to) */
p.lead-in, :is(ul, ol):has(> li:last-child.lead-in) { break-after: avoid; }

figure { margin: var(--u12) 0; break-inside: avoid; text-align: center; }
figure img { display: block; margin: 0 auto; box-sizing: content-box; outline: 1px solid var(--muted); }
figcaption { font: 400 12px/15px DM, Sym, 'Noto Sans CJK JP'; color: var(--muted); margin: var(--u6) auto 0; text-align: left; max-width: 100%; }
.swc { white-space: nowrap; }
.sw { display: inline-block; width: 9px; height: 9px; border: 1px solid var(--text); margin-right: 3px; vertical-align: -1px; }

/* boxes: a key — key fill, 1 px edge frame, the pad; the label in the desktop's face */
blockquote { margin: var(--u12) 0; padding: var(--u6) var(--u12); background: var(--key); border: 1px solid var(--edge); break-inside: avoid; }
blockquote p { margin: 3px 0; } blockquote ul, blockquote ol { margin: 3px 0; }
strong.cl { font: 400 12px/14px DM; color: var(--strong); }
blockquote.careful strong.cl { color: var(--accent-text); }
/* the end of a chapter: a part of its own — 習 what you learnt, 試 check yourself */
.recap { break-inside: avoid; margin-top: var(--u18); }
.recap .lbl { font: 400 12px/14px DM; color: var(--text); margin: 0 0 var(--u6); }
.recap .lbl ~ .lbl { margin-top: var(--u12); }

/* a Part: its own page — the workspace seal ×3, the title, a panel's width of stitch, the opening */
.partpage { break-before: page; break-after: page; height: 262mm; display: flex; flex-direction: column;
            justify-content: center; padding-bottom: 24mm; box-sizing: border-box; }
main h1.part { flex-direction: column; align-items: center; font-size: 24px; text-align: center; margin: 0; padding: 0; break-before: auto; }
h1.part .wseal { width: 69px; height: 69px; padding: 15px 0 0 18px; font-size: 36px; line-height: 36px; }
h1.part .nm { margin-top: var(--u18); }
h1.part::after { content: ''; display: block; width: 276px; height: 2px; margin-top: var(--u18); background: var(--stitch2) 0 0 / 10px 2px repeat-x; }
.partpage > p { text-align: center; font-style: italic; max-width: 125mm; margin: 4mm auto 0; color: var(--muted); }
h1.part + p { margin-top: var(--u18); }

/* the contents: rows as the help sheet's — a chapter's kanji, its name, the stitch as the
   leader, the page number right-aligned; a Part opens with its seal */
.toc { break-after: page; }
.toc h1 { break-before: auto; }
.toc ol { list-style: none; padding: 0; margin: var(--u6) 0; columns: 2; column-gap: 10mm; font-family: Sans, Sym, 'Noto Sans CJK JP', sans-serif; font-size: 7.9pt; }
.toc li { margin: 1px 0; break-inside: avoid; }
.toc li.l0 { font: 400 12px/23px DM; color: var(--strong); margin-top: var(--u12); }
.toc li.l1 { font: 400 12px/15px DM; color: var(--strong); margin-top: var(--u6); }
.toc li.l2 { color: var(--text); }
.toc li.l0, .toc li.l1 { break-after: avoid; }
.toc a { display: block; position: relative; padding-right: 2.4em; color: inherit; }
.toc .tt { position: relative; z-index: 1; background: var(--ground); padding-right: var(--u6); }
.toc .ld { position: absolute; left: 0; right: 2.6em; bottom: 0.45em; height: 1px; background: var(--stitch) 0 0 / 5px 1px repeat-x; }
.toc .pn { position: absolute; right: 0; bottom: 0; text-indent: 0; font-variant-numeric: tabular-nums; color: var(--muted); }
.toc li.l0 a { padding-left: 29px; } .toc li.l0 .wseal { position: absolute; left: 0; top: 0; }
.toc li.l0 .ld { left: 29px; bottom: 11px; } .toc li.l0 .pn { color: var(--strong); }
.toc .k { position: absolute; left: 0; top: 0; color: var(--accent-text); }
.toc li.l1 a { padding-left: calc(18px + 4ch); text-indent: -4ch; } .toc li.l1 .ld { left: 18px; bottom: 5px; }
.toc li.l2 a { padding-left: calc(18px + 2.3em); text-indent: -2.3em; } .toc li.l2 .ld { left: 18px; }

/* the cover: the dark theme's ink, the moon left clear above the words */
.cover { height: 297mm; width: 210mm; background: var(--d-ground); color: var(--d-text); position: relative; overflow: hidden; break-after: page; }
.cover img.bg { position: absolute; left: 0; top: 0; width: 100%; height: 100%; }
.cover .shade { position: absolute; left: 0; bottom: 0; width: 100%; height: 55%; }
.cover .t { position: absolute; left: 18mm; right: 18mm; bottom: 30mm; }
.cover .torii { font: 400 48px/48px SUMI; color: var(--d-accent-text); display: block; margin-bottom: var(--u18); }
.cover h1 { font: 400 48px/56px DM; color: var(--d-strong); margin: 0; letter-spacing: 0; }
.cover .cst { height: 2px; margin: var(--u18) 0; background: var(--d-stitch2) 0 0 / 10px 2px repeat-x; }
.cover p.sub { font: 400 24px/30px DM; color: var(--d-text); max-width: 150mm; margin: 0 0 var(--u12); }
.cover p.date { font: 400 12px/12px DM; color: var(--d-muted); margin: 0; }
"""
# a table of contents from the headings
nocode = re.sub(r"^```.*?^```", "", body, flags=re.M | re.S)   # (a "# comment" in a code block is no heading)
heads = re.findall(r"^(#{1,%d}) (.+)$" % int(os.environ.get("BOOK_TOC_LEVELS", "2")), nocode, re.M)
assert len(heads) == len(re.findall(r"<h[12][ >]", html)), "contents and headings differ"
def toc_mark(h, t):   # a Part's filled seal, a chapter's kanji (as the help sheet's rows), a section none
    p = re.match(r"Part ([IVXLC]+)\b|Appendices", t)
    if p: return "l0", seal(PART_KANJI.get(p[1] or "Appendices", "付"), "wseal")
    return "l" + str(len(h)), (f"<span class='k'>{kanji_of(t)}</span>" if len(h) == 1 else "")
toc = f"<section class='toc'><h1>{heading(KANJI['Contents'], 'Contents')}</h1><ol>" + "".join(   # (page numbers: 000 until the first print says where)
    f"<li class='{c}'><a href='#t{i}'>{mk}"
    f"<span class='tt'>{markdown.markdown(re.sub(r'^(\d+)\. ', r'\1\\. ', t))[3:-4]}</span><span class='ld'></span><span class='pn'>000</span></a></li>"
    for i, (h, t) in enumerate(heads, 1) for c, mk in [toc_mark(h, t)]) + "</ol></section>"
# ink-ridges-night, cut to the page (210 × 297): the moon and the ridges under it, from the
# right of the picture, the moon high in the sky; the title on the dark ridges, shaded under the words
_c = Image.open(COVER).convert("RGB")
_h = _c.height; _w = round(_h * 210 / 297); _x = round(_c.width * 0.473)
cover_bg = f"{IMG}/cover.jpg"; _c.crop((_x, 0, _x + _w, _h)).save(cover_bg, quality=92)
torii = chr(0xFE000)
doc = (f"<!doctype html><html><head><meta charset='utf-8'><title>{H.escape(meta['title'])}</title><style>{CSS}</style></head><body>"
       f"<section class='cover'><img class='bg' src='file://{cover_bg}'><div class='shade'></div><div class='t'>"
       f"<span class='torii'>{torii}</span><h1>{'\u00a0'.join(meta['title'].rsplit(' ', 1))}</h1><div class='cst'></div>"
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
    pg.evaluate("""() => {   // every stitch ends on a whole stitch (design-system §4): a rule whose width would end
        // its last one cut is made that much shorter (its stitches start at its left edge; on 3 of 5, on 6 of 10)
        const cut = (w, on, per) => { const r = Math.round(w) % per; return r > 0 && r < on ? r : 0; };
        document.querySelectorAll('.st').forEach(e => {
            const two = !!e.closest('h1'), w = e.getBoundingClientRect().width, r = cut(w, two ? 6 : 3, two ? 10 : 5);
            if (r) { e.style.flex = 'none'; e.style.width = (Math.round(w) - r) + 'px'; } });
        document.querySelectorAll('.toc .ld').forEach(e => {
            const r = cut(e.getBoundingClientRect().width, 3, 5);
            if (r) e.style.right = `calc(2.6em + ${r}px)`; });
        new Set([...document.querySelectorAll('main tr')].map(t => t.closest('table'))).forEach(t => {
            const w = t.getBoundingClientRect().width, r = cut(w, 3, 5);
            if (r) t.style.width = (Math.round(w) - r) + 'px'; });
    }""")
    def pages():   # the page each contents heading landed on: its link's named destination
        import pikepdf
        with pikepdf.open(f"{OUT}/{PDF}") as pdf:
            at = {page.objgen: i + 1 for i, page in enumerate(pdf.pages)}
            dests = {str(k).lstrip("/"): v for k, v in pdf.Root.Dests.items()}
            return [str(at[dests[f"t{i}"][0].objgen]) for i in range(1, len(heads) + 1)]
    for _ in range(3):   # print, write the numbers in (same width: nothing moves), print again
        pg.pdf(path=f"{OUT}/{PDF}", format="A4", print_background=True, prefer_css_page_size=True)
        nums = pages()
        if nums == pg.evaluate("() => [...document.querySelectorAll('.toc .pn')].map(e => e.textContent)"): break
        pg.evaluate("ns => document.querySelectorAll('.toc .pn').forEach((e, i) => e.textContent = ns[i])", nums)
    else: print("contents: page numbers still moving")
    b.close()
print("pdf", os.path.getsize(f"{OUT}/{PDF}") // 1024, "KiB")
# the pictures re-compressed losslessly (pdfpack.py, beside this script): every pixel the same, a tenth smaller
sys.dont_write_bytecode = True                 # (no __pycache__ left in the repository)
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pdfpack
pdfpack.main(f"{OUT}/{PDF}", f"{OUT}/{PDF}.packed")
os.replace(f"{OUT}/{PDF}.packed", f"{OUT}/{PDF}")
print("packed", os.path.getsize(f"{OUT}/{PDF}") // 1024, "KiB")
