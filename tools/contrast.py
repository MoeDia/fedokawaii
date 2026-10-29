#!/usr/bin/env python3
"""tools/contrast.py — every selected and highlighted state of the desktop, its ink against its
fill, in both themes: the WCAG 2.x contrast ratio, measured from the files the desktop ships
(the generated theme files and each surface's own config), never from what they should say.

  python3 tools/contrast.py          the table; exit 1 if a pair is under its threshold
  python3 tools/contrast.py --quiet  only the pairs under it

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
WORDS, ICON, LARGE = 7.0, 4.5, 3.0

_spec = importlib.util.spec_from_file_location("wada_palette", ROOT / "tools/wada-palette.py")
_wada = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_wada)
P = _wada.palette()[0]
contrast = _wada.contrast


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


def panel_pairs(m):
    """quick settings: kawa-panel draws with panel.conf's colours by name — the names its look()
    gives the item under the cursor (tests/static/test_contrast.sh holds kawa-panel to them)."""
    c = dict(re.findall(r"^([a-z_]+)=([0-9a-f]{6})$", (THEMES / m / "panel.conf").read_text(), re.M))
    return [("quick settings", "the item under the cursor: its words", c["text_on_select"], c["select"], WORDS),
            ("quick settings", "the item under the cursor: its icon, its dot", c["text_on_select"], c["select"], ICON),
            ("quick settings", "a tile under the cursor, on: the picture in its seal", c["select"], c["text_on_select"], ICON),
            ("quick settings", "a meter under the cursor: a lit segment", c["text_on_select"], c["select"], ICON),
            ("quick settings", "a meter under the cursor: lit against unlit (the level)", c["text_on_select"], c["select_lo"], LARGE)]


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
        for surface, state, fg, bg, need in (term_pairs(m) + panel_pairs(m) + css_pairs(m) + qt_pairs(m) + app_pairs(m)):
            out.append((m, surface, state, fg, bg, contrast(fg, bg), need))
    return out


def main():
    quiet = "--quiet" in sys.argv
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
