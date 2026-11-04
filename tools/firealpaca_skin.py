"""tools/firealpaca_skin.py — FireAlpaca's skin, one per mood, from the design's own tokens: read by
tools/build-themes.py, written into themes/<mode>/ as

    firealpaca.conf     the inks src/kawa-firealpaca reads (its lists, its meters, the grey round
                        the canvas: pixels the program writes itself)
    firealpaca.qss      its Qt style sheet (@THEME@: the mood's folder, filled in by kawa-firealpaca)
    firealpaca-*.png    what a style sheet can only take as pictures: the frame of a menu (§4), the
                        panels' headings, the boxes, arrows and marks

The grammar is docs/design-system.md's: rows of 20 px on the 8 px cell, Sumi UI 14 px in one size,
the frame of §4, heading = icon + name + rule, the lacquer for what is selected, keys 20 high.
"""

# the panels' names as FireAlpaca titles them: (its object name, its title, the heading icon's name)
DOCKS = [("DockColor", "Color", "color"), ("DockColorHistory", "Color History", "history"),
         ("DockPalette", "Palette", "palette"), ("DockBrushPreview", "Brush Preview", "preview"),
         ("DockBrushControl", "Brush Control", "control"), ("DockBrush", "Brush", "brush"),
         ("DockNavi", "Navigator", "navi"), ("DockLayer", "Layer", "layer"),
         ("DockReference", "Reference", "reference"), ("DockBrushSize", "Brush Size", "size")]
LETTER = 7           # Sumi UI: a letter's width
HEADING_W = 272      # a heading's picture: from the panel's left edge to its content's right edge (a panel 280 wide)


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def over(c, ground):
    """(r, g, b, a) laid on an opaque ground: a menu's window has no see-through."""
    a = c[3] / 255
    return tuple(round(c[i] * a + ground[i] * (1 - a)) for i in range(3))


def conf(m, p):
    names = ("ground", "view", "key", "edge", "edge2", "faint", "muted", "text", "strong", "accent",
             "select", "text_on_select", "asagi", "flame")
    return "".join(f"{n} {p[n]}\n" for n in names)


def art(path):
    """{name: rows of '#'/'.'} of an art file: "@name" then the rows."""
    blocks, cur = {}, None
    for line in path.read_text().splitlines():
        if line.startswith("@"):
            cur = line[1:].split()[0]
            blocks[cur] = []
        elif line and cur and set(line) <= {"#", "."}:
            blocks[cur].append(line)
    return blocks


def mask(png, rows, ink):
    """A drawing as a picture in one ink, the rest see-through."""
    w, h = len(rows[0]), len(rows)
    return png(w, h, [[ink + (255,) if c == "#" else ink + (0,) for c in r] for r in rows])


def frame(png, m, p, kami, fill):
    """§4's frame as a 7 × 8 picture (sliced 1 2 3 1): the hairline, its corners left out, the
    shadow under and right, laid on the fill (a menu's window has no see-through)."""
    g = rgb(fill)
    hair = over(kami["hair"], g)
    s1, s2 = over(kami["shadow"][0], g), over(kami["shadow"][1], g)
    rows = [[g, hair, hair, hair, hair, g, g],
            [hair, g, g, g, g, hair, g],
            [hair, g, g, g, g, hair, s2],
            [hair, g, g, g, g, hair, s2],
            [hair, g, g, g, g, hair, s2],
            [g, hair, hair, hair, hair, g, s2],
            [g, s1, s1, s1, s1, s1, s2],
            [g, g, s2, s2, s2, s2, s2]]
    return png(7, 8, rows)


def heading(png, rows, title, p):
    """A panel's heading (§4): one cell in, its 12 px icon in the icon column, room for the name from x 32,
    8 px, then the rule on the row's row 10 to the content's right edge: the words are Qt's, the rest this."""
    h = 20
    icon, rule = rgb(p["accent_text"]), rgb(p["edge2"])
    none = icon + (0,)
    px = [[none for _ in range(HEADING_W)] for _ in range(h)]
    for y, r in enumerate(rows):
        for x, c in enumerate(r):
            if c == "#":
                px[y + 4][x + 10] = icon + (255,)
    for x in range(32 + LETTER * len(title) + 8, HEADING_W):
        px[10][x] = rule + (255,)
    return png(HEADING_W, h, px)


def pictures(png, root, m, p, kami):
    """Every picture of the skin: name → bytes."""
    parts = art(root / "art/firealpaca-parts.txt")
    text, on_sel, faint = rgb(p["text"]), rgb(p["text_on_select"]), rgb(p["faint"])
    out = {
        "firealpaca-frame.png": frame(png, m, p, kami, p["ground"]),
        "firealpaca-check.png": mask(png, parts["check"], rgb(p["accent_text"])),
        "firealpaca-check-off.png": mask(png, parts["check"], faint),
        "firealpaca-menu-check.png": mask(png, parts["check"], text),
        "firealpaca-menu-check-sel.png": mask(png, parts["check"], on_sel),
        "firealpaca-dot.png": mask(png, parts["dot"], rgb(p["accent_text"])),
        "firealpaca-down.png": mask(png, parts["down"], rgb(p["muted"])),
        "firealpaca-down-off.png": mask(png, parts["down"], faint),
        "firealpaca-up.png": mask(png, parts["up"], rgb(p["muted"])),
        "firealpaca-up-off.png": mask(png, parts["up"], faint),
        "firealpaca-right.png": mask(png, parts["right"], text),
        "firealpaca-right-off.png": mask(png, parts["right"], faint),
        "firealpaca-right-sel.png": mask(png, parts["right"], on_sel),
    }
    for _, title, icon in DOCKS:
        out[f"firealpaca-head-{icon}.png"] = heading(png, parts["head-" + icon], title, p)
    return out


def sheet(m, p):
    """The whole style sheet (Qt's QSS: no comments of ours inside it, each rule costs a parse)."""
    g, view, key, edge, edge2 = p["ground"], p["view"], p["key"], p["edge"], p["edge2"]
    faint, muted, text, strong = p["faint"], p["muted"], p["text"], p["strong"]
    sel, on_sel, accent, asagi = p["select"], p["text_on_select"], p["accent"], p["asagi"]
    surface = p["surface"]
    heads = "\n".join(f'QDockWidget#{obj}::title {{ background-image: url(@THEME@/firealpaca-head-{icon}.png); }}'
                      for obj, _, icon in DOCKS)
    return f"""\
* {{ font-family: "Sumi UI"; font-size: 14px; font-weight: normal; outline: 0; }}
QWidget {{ background-color: #{g}; color: #{text}; selection-background-color: #{sel}; selection-color: #{on_sel}; }}
QMainWindow::separator {{ background: #{g}; width: 8px; height: 8px; }}
QMainWindow::separator:hover {{ background: #{edge2}; }}
QLabel, QCheckBox, QRadioButton {{ background: transparent; }}
QLabel:disabled, QCheckBox:disabled, QRadioButton:disabled {{ color: #{faint}; }}
QToolTip {{ background-color: #{surface}; color: #{text}; border: 1px solid #{edge2}; padding: 2px 8px; }}

QMenuBar {{ background: #{g}; padding: 0; spacing: 0; border: none; }}
QMenuBar::item {{ background: transparent; padding: 3px 8px; }}
QMenuBar::item:selected, QMenuBar::item:pressed {{ background: #{sel}; color: #{on_sel}; }}
QMenu {{ background: #{g}; border-image: url(@THEME@/firealpaca-frame.png) 1 2 3 1 stretch stretch; border-width: 1px 2px 3px 1px; padding: 8px 0; }}
QMenu::item {{ background: transparent; padding: 3px 16px 3px 32px; }}
QMenu::item:selected {{ background: #{sel}; color: #{on_sel}; }}
QMenu::item:disabled {{ color: #{faint}; }}
QMenu::item:disabled:selected {{ background: transparent; color: #{faint}; }}
QMenu::separator {{ height: 1px; background: #{edge2}; margin: 9px 8px 10px 8px; }}
QMenu::indicator {{ width: 12px; height: 12px; left: 10px; background: transparent; }}
QMenu::indicator:checked {{ image: url(@THEME@/firealpaca-menu-check.png); }}
QMenu::indicator:checked:selected {{ image: url(@THEME@/firealpaca-menu-check-sel.png); }}
QMenu::indicator:checked:disabled {{ image: url(@THEME@/firealpaca-check-off.png); }}
QMenu::right-arrow {{ image: url(@THEME@/firealpaca-right.png); width: 12px; height: 12px; right: 4px; }}
QMenu::right-arrow:selected {{ image: url(@THEME@/firealpaca-right-sel.png); }}
QMenu::right-arrow:disabled {{ image: url(@THEME@/firealpaca-right-off.png); }}

QToolBar {{ background: #{g}; border: none; spacing: 0; padding: 0; }}
QToolBar::handle {{ image: none; width: 0; height: 0; }}
QToolBar::separator:horizontal {{ background: #{edge2}; width: 1px; margin: 6px 8px; }}
QToolBar::separator:vertical {{ background: #{edge2}; height: 1px; margin: 8px 6px; }}
QToolButton {{ background: transparent; border: none; padding: 2px; }}
QToolButton:hover {{ background: #{key}; }}
QToolButton:checked, QToolButton:pressed {{ background: #{sel}; color: #{on_sel}; }}
QToolButton::menu-indicator {{ image: none; }}

QDockWidget {{ color: #{strong}; titlebar-close-icon: none; titlebar-normal-icon: none; }}
QDockWidget::title {{ background-color: #{g}; background-repeat: no-repeat; background-position: left center; text-align: left; padding: 3px 0 3px 32px; }}
{heads}
QDockWidget::close-button, QDockWidget::float-button {{ width: 0; height: 0; border: none; background: transparent; image: none; }}

QPushButton {{ background: #{key}; color: #{text}; border: 1px solid #{edge}; padding: 0 8px; min-height: 18px; dialogbuttonbox-buttons-have-icons: 0; }}
QPushButton:hover {{ background: #{sel}; border-color: #{sel}; color: #{on_sel}; }}
QPushButton:pressed {{ background: #{sel}; border-color: #{sel}; color: #{on_sel}; }}
QPushButton:default {{ border-color: #{sel}; }}
QPushButton:disabled {{ color: #{faint}; }}
QDialogButtonBox {{ button-layout: 0; dialogbuttonbox-buttons-have-icons: 0; }}

QLineEdit, QSpinBox, QDoubleSpinBox, QComboBox, QAbstractSpinBox {{ background: #{key}; color: #{text}; border: 1px solid #{edge}; padding: 0 3px; min-height: 18px; }}
QLineEdit:focus, QSpinBox:focus, QDoubleSpinBox:focus, QComboBox:focus {{ border-color: #{muted}; }}
QLineEdit:disabled, QSpinBox:disabled, QDoubleSpinBox:disabled, QComboBox:disabled {{ color: #{faint}; }}
QComboBox::drop-down {{ background: transparent; border: none; width: 16px; }}
QComboBox::down-arrow {{ image: url(@THEME@/firealpaca-down.png); width: 12px; height: 12px; }}
QComboBox::down-arrow:disabled {{ image: url(@THEME@/firealpaca-down-off.png); }}
QComboBox QAbstractItemView {{ background: #{g}; color: #{text}; border: 1px solid #{edge2}; selection-background-color: #{sel}; selection-color: #{on_sel}; }}
QAbstractSpinBox::up-button, QAbstractSpinBox::down-button {{ background: transparent; border: none; width: 16px; }}
QAbstractSpinBox::up-arrow {{ image: url(@THEME@/firealpaca-up.png); width: 12px; height: 6px; }}
QAbstractSpinBox::down-arrow {{ image: url(@THEME@/firealpaca-down.png); width: 12px; height: 6px; }}

QCheckBox {{ spacing: 8px; }}
QCheckBox::indicator {{ width: 12px; height: 12px; background: #{key}; border: 1px solid #{edge2}; }}
QCheckBox::indicator:checked {{ image: url(@THEME@/firealpaca-check.png); }}
QCheckBox::indicator:checked:disabled {{ image: url(@THEME@/firealpaca-check-off.png); }}
QCheckBox::indicator:disabled {{ border-color: #{edge}; }}
QRadioButton {{ spacing: 8px; }}
QRadioButton::indicator {{ width: 12px; height: 12px; background: #{key}; border: 1px solid #{edge2}; }}
QRadioButton::indicator:checked {{ image: url(@THEME@/firealpaca-dot.png); }}

QSlider {{ background: transparent; }}
QSlider::groove:horizontal {{ background: #{edge}; height: 2px; }}
QSlider::sub-page:horizontal {{ background: #{asagi}; }}
QSlider::handle:horizontal {{ background: #{accent}; width: 6px; margin: -6px 0; }}
QSlider::groove:vertical {{ background: #{edge}; width: 2px; }}
QSlider::handle:vertical {{ background: #{accent}; height: 6px; margin: 0 -6px; }}

QTabWidget::pane {{ background: #{g}; border: none; border-top: 1px solid #{edge2}; }}
QTabBar {{ background: #{g}; }}
QTabBar::tab {{ background: #{g}; color: #{muted}; border: none; padding: 3px 16px; min-height: 14px; }}
QTabBar::tab:selected {{ background: #{sel}; color: #{on_sel}; }}
QTabBar::tab:hover:!selected {{ color: #{text}; background: #{key}; }}
QTabBar::close-button {{ image: none; width: 0; }}

QMdiArea {{ background: #{g}; border: none; qproperty-background: #{g}; }}
QMdiSubWindow {{ background: #{g}; border: none; }}
QMdiArea QTabBar::tab, QMdiArea QTabBar::tab:selected, QMdiArea QTabBar::tab:hover {{ background: #{g}; color: #{muted}; padding: 3px 8px; }}
QMdiArea QTabBar::tab:selected {{ color: #{strong}; }}
QAbstractScrollArea {{ background: #{g}; border: none; }}
QScrollBar:vertical {{ background: #{g}; width: 8px; margin: 0; }}
QScrollBar:horizontal {{ background: #{g}; height: 8px; margin: 0; }}
QScrollBar::handle {{ background: #{edge2}; }}
QScrollBar::handle:hover {{ background: #{muted}; }}
QScrollBar::handle:vertical {{ min-height: 20px; margin: 0 0 0 16px; }}
QScrollBar::handle:horizontal {{ min-width: 20px; margin: 16px 0 0 0; }}
QScrollBar::add-line, QScrollBar::sub-line {{ background: transparent; height: 0; width: 0; }}
QScrollBar::add-page, QScrollBar::sub-page {{ background: transparent; }}

QListView, QTreeView, QTableView, QListWidget, QTreeWidget, QTableWidget, QTextEdit, QPlainTextEdit {{ background: #{view}; color: #{text}; border: none; alternate-background-color: #{view}; }}
QListView::item, QTreeView::item {{ padding: 3px 8px; }}
QListView::item:selected, QTreeView::item:selected, QTableView::item:selected {{ background: #{sel}; color: #{on_sel}; }}
QHeaderView::section {{ background: #{g}; color: #{muted}; border: none; padding: 3px 8px; }}
QTableCornerButton::section {{ background: #{g}; border: none; }}

QGroupBox {{ background: transparent; border: none; margin-top: 28px; }}
QGroupBox::title {{ subcontrol-origin: margin; subcontrol-position: top left; color: #{strong}; padding: 3px 0; }}
QProgressBar {{ background: #{edge}; color: #{strong}; border: none; text-align: center; }}
QProgressBar::chunk {{ background: #{asagi}; }}
QSplitter::handle {{ background: #{g}; }}
QStatusBar {{ background: #{g}; color: #{muted}; }}
QStatusBar::item {{ border: none; }}
QStatusBar QLabel {{ color: #{muted}; }}
"""
