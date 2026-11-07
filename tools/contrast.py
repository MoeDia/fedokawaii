#!/usr/bin/env python3
"""tools/contrast.py — every selected and highlighted state of the desktop, its ink against its
fill, in both themes: the WCAG 2.x contrast ratio, measured from the files the desktop ships
(the generated theme files and each surface's own config), never from what they should say.

  python3 tools/contrast.py          the table; exit 1 if a pair is under its threshold
  python3 tools/contrast.py --quiet  only the pairs under it
  python3 tools/contrast.py --apca   the same pairs and every role's words on the grounds, by APCA
                                     too (WCAG 3's draft, APCA-W3 0.0.98G-4g: Lc, the lightness
                                     contrast as read; exit 1 if one is under): Lc 75 for words
                                     read at length, 60 for a label, 45 for an icon, a mark or a
                                     large glyph, 30 for words only spotted (APCA's bronze levels)

Thresholds (docs/design-system.md §1): the words on what is selected ≥ 7 : 1 (the owner,
2026-10-27 19:19: a highlighted row's words did not stand out — the vermilion held black at
5.1 only); an icon or a mark on it, the letters a search matched, a marked row ≥ 4.5; a large
glyph on a seal ≥ 3 (WCAG's large-text and component rule). tests/static/test_contrast.sh runs it.
"""
import importlib.util
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
HOME = ROOT / "configs/home"
THEMES = HOME / ".config/fedokawaii/themes"
WORDS, ICON, LARGE, SHAPE = 7.0, 4.5, 3.0, 3.01    # (SHAPE: no letter at all — a cursor's edge, a seal's mass: WCAG 1.4.11's 3 : 1)

_spec = importlib.util.spec_from_file_location("wada_palette", ROOT / "tools/wada-palette.py")
_wada = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_wada)
P = _wada.palette()[0]
contrast = _wada.contrast


def apca(fg, bg):
    """APCA-W3 0.0.98G-4g: the lightness contrast Lc of fg read on bg, as a magnitude (dark on light
    and light on dark alike; the polarity is in the exponents)."""
    def y(h):
        r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
        v = 0.2126729 * r ** 2.4 + 0.7151522 * g ** 2.4 + 0.0721750 * b ** 2.4
        return v + (0.022 - v) ** 1.414 if v < 0.022 else v       # (the soft clamp of near-black)
    yt, yb = y(fg), y(bg)
    if abs(yb - yt) < 0.0005:
        return 0.0
    if yb > yt:                                                   # (dark words on a light ground)
        s = (yb ** 0.56 - yt ** 0.57) * 1.14
        return 0.0 if s < 0.1 else (s - 0.027) * 100
    s = (yb ** 0.65 - yt ** 0.62) * 1.14                          # (light words on a dark ground)
    return 0.0 if s > -0.1 else -(s + 0.027) * 100


APCA_NEED = {WORDS: 60.0, ICON: 45.0, LARGE: 45.0, SHAPE: 30.0}      # (what each WCAG class asks, read by APCA)
STEP = 15.0                                              # (Lc between neighbouring word inks: §1)


# what each role carries, as APCA's levels: words read at length, a label, an icon or a mark (the
# vermilion: no red on sumi reaches 60 — words to be read are never accent_text), words spotted
ROLE_LC = {"strong": 75.0, "text": 75.0, "muted": 60.0, "accent_text": 45.0, "faint": 30.0}
# kept by the owner's word, measured and shown, not counted: the seal's numeral is black (r27)
APCA_KEPT = ("the workspace seal's numeral (Wada's Black, the owner's choice)",
             "the calendar's today: its digit on the seal (the workspace seal's own pair)")


def role_pairs(m):
    """Every role's words on the grounds they stand on: the panels' and the terminal's, a solid
    surface, a key's fill, the bar's tile — and a selected line's band (the terminal's black, ansi0),
    which carries a row's own words (text, strong), never muted or faint ones."""
    p = P[m]
    grounds = dict(ground=p["ground"], surface=p["surface"], key=p["key"], tile=_wada.palette()[2][m])
    return ([(f"the roles ({m})", f"{r} on {g}", p[r], bg, ROLE_LC[r]) for g, bg in grounds.items() for r in ROLE_LC]
            # the band behind a selected line (the terminal's black): a selected row's words only
            + [(f"the roles ({m})", f"{r} on the band (ansi0)", p[r], p["ansi0"], ROLE_LC[r]) for r in ("strong", "text")])


def foot_colours(m):
    """foot.ini's [colors-<m>]: the sixteen, the desktop's own past them, its words and ground."""
    block = (HOME / ".config/foot/foot.ini").read_text().split(f"[colors-{m}]")[1].split("\n[")[0]
    kv = dict(re.findall(r"^([a-z0-9]+)=([0-9a-f]{6})$", block, re.M))
    pal = {i: kv[f"regular{i}"] for i in range(8)} | {8 + i: kv[f"bright{i}"] for i in range(8)}
    pal |= {int(k): v for k, v in kv.items() if k.isdigit()}
    return pal, kv["foreground"], kv["background"]


def term_pairs(m):
    """The menus in a terminal: fzf's (fzf.opts) and VisiData's, both in foot's palette slots."""
    pal, fg, bg = foot_colours(m)
    opts = (HOME / ".config/fedokawaii/fzf.opts").read_text()
    col = {}
    for spec in re.findall(r"--color=(\S+)", opts):
        for item in spec.split(","):
            name, _, val = item.partition(":")
            col[name] = val.split(":")[0]
    def ink(name, default):
        v = col.get(name, "-1")
        return default if v == "-1" else pal[int(v)]
    # VisiData (the Tables window) takes the same slots: 'FG on BG', foot's palette numbers
    vd = {k: (pal[int(f)], pal[int(g)]) for k, f, g in
          re.findall(r"^options\.(color_\w+) = '(\d+) on (\d+)'", (HOME / ".config/visidata/config.py").read_text(), re.M)}
    return [("every menu (fzf)", "the row under the cursor: its words", ink("fg+", fg), ink("bg+", bg), WORDS),
            ("Tables (VisiData)", "the row under the cursor", *vd["color_current_row"], WORDS),
            ("Tables (VisiData)", "the cursor's column name", *vd["color_current_hdr"], WORDS),
            ("Tables (VisiData)", "the menu's item under the cursor", *vd["color_menu_active"], WORDS),
            ("every menu (fzf)", "the row under the cursor: the letters matched", ink("hl+", fg), ink("bg+", bg), WORDS),
            ("every menu (fzf)", "a marked row", ink("selected-fg", fg), ink("selected-bg", bg), ICON),
            ("every menu (fzf)", "the letters matched, at rest", ink("hl", fg), bg, ICON)]


def glass_pairs(m):
    """A terminal's words through its glass (kawa-glass: foot's alpha, blended as stored): the ground over
    the worst pixel any wallpaper can hold, white under the dark ground, black under the paper."""
    alpha = float(re.search(r"^ON=([0-9.]+)", (ROOT / "bin/kawa-glass").read_text(), re.M).group(1))
    pal, fg, bg = foot_colours(m)
    worst = 255 if m == "dark" else 0
    over = "".join(f"{round(alpha * int(bg[i:i + 2], 16) + (1 - alpha) * worst):02x}" for i in (0, 2, 4))
    return [("the terminal", f"its words at alpha {alpha:g} over the worst wallpaper pixel", fg, over, WORDS)]


def prompt_pairs(m):
    """The prompt: the mood's head on the ground (bloody in slot 20, lighty in the bright blue, slot 12), its
    ink (30) on each paper (27–29: the folder, git, the time and jobs) and a failure's code, the cream
    (32) on the lacquer (31) — foot's slots."""
    pal, fg, bg = foot_colours(m)
    return [("the prompt", "the mood's head on the ground", pal[20 if m == "dark" else 12], bg, ICON),
            ("the prompt", "the folder's words on their paper", pal[30], pal[27], WORDS),
            ("the prompt", "git's words on their paper", pal[30], pal[28], WORDS),
            ("the prompt", "the time and the jobs on their paper", pal[30], pal[29], WORDS),
            ("the prompt", "a failure's code on the lacquer", pal[32], pal[31], WORDS)]


YAZI_NAMES = ("black", "red", "green", "yellow", "blue", "magenta", "cyan", "gray", "darkgray", "lightred",
              "lightgreen", "lightyellow", "lightblue", "lightmagenta", "lightcyan", "white")


def yazi_pairs(m):
    """The files (yazi, theme.toml): its colours are foot's slots, by name or number — the row under
    the cursor, and a place in another folder (the parent's, the preview's) under a folder's name."""
    pal, fg, bg = foot_colours(m)
    def slot(v):
        return pal[int(v)] if v.isdigit() else pal[YAZI_NAMES.index(v)]
    ind = dict(re.findall(r'^(\w+)\s*=\s*\{([^}]*)\}', (HOME / ".config/yazi/theme.toml").read_text().split("[indicator]")[1].split("\n[")[0], re.M))
    def ink(name, key, default):
        v = re.search(key + r'\s*=\s*"(\w+)"', ind[name])
        return slot(v.group(1)) if v else default
    folder = slot(re.search(r'\{ url = "\*/", fg = "(\w+)"', (HOME / ".config/yazi/theme.toml").read_text()).group(1))
    return [("files (yazi)", "the row under the cursor: its words", ink("current", "fg", fg), ink("current", "bg", bg), WORDS),
            ("files (yazi)", "the folder you are in (the parent's place): its name", ink("parent", "fg", folder), ink("parent", "bg", bg), WORDS),
            ("files (yazi)", "where you would land (the preview's place): its name", ink("preview", "fg", folder), ink("preview", "bg", bg), WORDS)]


def panel_pairs(m):
    """quick settings: kawa-panel draws with panel.conf's colours by name — the names its look()
    gives the item under the cursor (tests/static/test_contrast.sh holds kawa-panel to them)."""
    c = dict(re.findall(r"^([a-z_]+)=([0-9a-f]{6})$", (THEMES / m / "panel.conf").read_text(), re.M))
    # (the cursor: a 12 % tint and a 2 px edge of the seal's red; every ink keeps its own on it, so each is measured)
    return [("the panels", "the item under the cursor: its words", c["text_on_select"], c["select"], WORDS),
            ("the panels", "the item under the cursor: its picture", c["text_on_select"], c["select"], ICON),
            ("the panels", "an item held down by the pointer: its words", c["strong"], c["select"], WORDS),
            ("the panels", "the item under the cursor: its value", c["text"], c["select"], WORDS),
            ("the panels", "the item under the cursor: its key's label on its cap", c["muted"], c["key"], ICON),
            ("the panels", "the item under the cursor: the cursor's edge", c["select_edge"], c["select"], SHAPE),
            ("the panels", "the item under the cursor: a seal inked, a chosen dot", c["accent"], c["select"], SHAPE),
            ("the panels", "a meter under the cursor: a lit segment on the tint", c["asagi"], c["select"], LARGE),
            ("the panels", "a meter: lit against unlit (the level)", c["asagi"], c["edge"], LARGE),
            ("the panels", "a seal inked: its paper's ring", c["ground"], c["accent"], SHAPE),
            ("the panels", "a seal tile inked: its carved picture", c["text_on_accent"], c["accent"], SHAPE),
            ("the panels", "a seal tile blank: its picture", c["muted"], c["key"], ICON),
            ("the panels", "the calendar's today: its digit on the seal (the workspace seal's own pair)", c["text_on_accent"], c["accent"], ICON),
            ("the panels", "the calendar's Saturday", c["ai"], c["ground"], ICON),
            ("the panels", "the calendar's Sunday", c["accent_text"], c["ground"], ICON),
            ("the panels", "a timer's sand on the ground", c["sand"], c["ground"], SHAPE)]


def css_pairs(m):
    gtk3 = (HOME / f".local/share/themes/{'Fedokawaii-dark' if m == 'dark' else 'Fedokawaii'}/gtk-3.0/gtk.css").read_text()
    d3 = dict(re.findall(r"@define-color (\w+)\s+#([0-9a-f]{6});", gtk3))
    gtk4 = (HOME / ".config/gtk-4.0/gtk.css").read_text()
    block = gtk4.split("@media (prefers-color-scheme: dark)")[1 if m == "dark" else 0]
    d4 = dict(re.findall(r"--([\w-]+): #([0-9a-f]{6});", block))
    lock = (THEMES / m / "gtklock.css").read_text()
    sel = re.search(r"#input-field selection \{ background-color: #([0-9a-f]{6}); color: #([0-9a-f]{6}); \}", lock)
    return [("GTK 3 apps", "a selected row, a default button", d3["accent_fg_color"], d3["accent_bg_color"], WORDS),
            ("GTK 4 apps", "a selected row, a default button", d4["accent-fg-color"], d4["accent-bg-color"], WORDS),
            ("GTK 3 apps", "a button under the pointer: its words", d3["accent_color"], d3["kawa_key"], ICON),
            ("the lock, the login", "the words selected in the field", sel.group(2), sel.group(1), WORDS)]


def qt_pairs(m):
    roles = dict(re.findall(r"^(\w+)_colors=(.*)$", (THEMES / m / "qt6ct-colors.conf").read_text(), re.M))
    act = [v.strip()[3:] for v in roles["active"].split(",")]
    return [("Qt apps", "a selected row", act[13], act[12], WORDS)]   # (QPalette: 12 Highlight, 13 HighlightedText)


def app_pairs(m):
    mpv = dict(re.findall(r'script-opt="([\w-]+)=#([0-9a-f]{6})"', (THEMES / m / "mpv.conf").read_text()))
    nv = (HOME / ".config/nvim/lua/plugins/colorscheme.lua").read_text().split("local sel")[1].split("vim.api")[0]
    nvm = re.findall(r'bg = "#([0-9a-f]{6})", fg = "#([0-9a-f]{6})"', nv)[0 if m == "light" else 1]
    btop = dict(re.findall(r'theme\[(\w+)\]="#([0-9a-f]{6})"', (THEMES / m / "btop.theme").read_text()))
    wm = re.search(r'dropdown_selected = \{ fg = "#([0-9a-f]{6})", bg = "#([0-9a-f]{6})" \}',
                   (THEMES / m / "wiremix.toml").read_text())
    p = P[m]
    return [("mpv", "the console's chosen line", mpv["console-focused_color"], mpv["console-focused_back_color"], WORDS),
            ("mpv", "the context menu's chosen row", mpv["context_menu-focused_color"], mpv["context_menu-focused_back_color"], WORDS),
            ("Neovim", "the completion menu's chosen row", nvm[1], nvm[0], WORDS),
            ("btop", "the chosen process", btop["selected_fg"], btop["selected_bg"], WORDS),
            ("the mixer (wiremix)", "a list's chosen line", wm.group(1), wm.group(2), WORDS),
            ("Neovim, TUIs", "an inverted chip: the editor's selection, marked items", p["lit_text"], p["lit"], WORDS),
            ("the bar", "the workspace seal's numeral (Wada's Black, the owner's choice)", P["dark"]["lo"], p["accent"], LARGE)]


def rows():
    out = []
    for m in ("dark", "light"):
        for surface, state, fg, bg, need in (term_pairs(m) + glass_pairs(m) + prompt_pairs(m) + yazi_pairs(m) + panel_pairs(m) + css_pairs(m) + qt_pairs(m) + app_pairs(m)):
            out.append((m, surface, state, fg, bg, contrast(fg, bg), need))
    return out


def main():
    quiet = "--quiet" in sys.argv
    if "--apca" in sys.argv:
        under = 0
        for m in ("dark", "light"):
            for surface, state, fg, bg, need in (role_pairs(m) + term_pairs(m) + prompt_pairs(m) + yazi_pairs(m) + panel_pairs(m) + css_pairs(m) + qt_pairs(m) + app_pairs(m)):
                lc, want = apca(fg, bg), APCA_NEED.get(need, need)
                mark = "◇" if state in APCA_KEPT else "✘" if lc < want else "✔"
                under += mark == "✘"
                if mark != "✔" or not quiet:
                    print(f"{mark} {m:5} Lc {lc:5.1f} (≥ {want:g})  WCAG {contrast(fg, bg):5.2f}  {surface}: {state}  #{fg} on #{bg}")
        # the steps between the word inks (design-system §1): each ≥ 15 Lc below the one above it on
        # the dark ground, so the order reads at a glance (the light mood's strong sits over text by
        # hue and place: both near-black ink — exempt)
        d = P["dark"]
        for hi, lo in (("strong", "text"), ("text", "muted"), ("muted", "faint")):
            step = apca(d[hi], d["ground"]) - apca(d[lo], d["ground"])
            under += step < STEP
            if step < STEP or not quiet:
                print(f"{'✘' if step < STEP else '✔'} dark  step {step:5.1f} (≥ {STEP:g})  the word inks: {hi} over {lo} on the ground")
        print(f"APCA: {under} under their level (◇ kept by the owner's word)")
        return 1 if under else 0
    bad = 0
    for m, surface, state, fg, bg, r, need in rows():
        low = r < need
        bad += low
        if low or not quiet:
            print(f"{'✘' if low else '✔'} {m:5} {r:5.2f} (≥ {need:g})  {surface}: {state}  #{fg} on #{bg}")
    if not quiet:
        print(f"{len(rows())} pairs, {bad} under their threshold")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
