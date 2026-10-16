#!/usr/bin/env python3
"""tests/static/keybinds.py — does the help sheet (Super+/) say what dwl's config.h binds?

    python3 keybinds.py REPO      one line per mismatch; exit 1 if any

config.h: keys[] (with TAGKEYS and CHVT expanded), buttons[], axes[]. keybinds.txt: the
sections of dwl's keys (launch, screenshots, windows, workspaces, sound/music/monitor, session);
the terminal's and the drives' sections are other programs' keys and are left out. A help line
names its keys as "Super+J / K", "Super+1…9", "Super+] / Super+[", "Volume · Mute · Mic"…
Two keys of the sheet are not dwl's own: Alt+Shift (the keyboard layout: XKB's option, from
fedokawaii.conf) and Right Shift+F12 (MangoHud's toggle_hud) — each checked where it is set.
"""
import pathlib
import re
import sys

MODS = {"MODKEY": "Super", "SHIFT": "Shift", "CTRL": "Ctrl", "WLR_MODIFIER_ALT": "Alt",
        "WLR_MODIFIER_LOGO": "Super", "WLR_MODIFIER_SHIFT": "Shift", "WLR_MODIFIER_CTRL": "Ctrl", "0": None}
NAMES = {"/": "slash", ",": "comma", ".": "period", "]": "bracketright", "[": "bracketleft",
         "space": "space", "return": "Return", "escape": "Escape", "tab": "Tab", "print": "Print"}
MEDIA = {"volume": ["XF86AudioRaiseVolume", "XF86AudioLowerVolume"], "mute": ["XF86AudioMute"],
         "mic": ["XF86AudioMicMute"], "play": ["XF86AudioPlay"], "next": ["XF86AudioNext"],
         "previous": ["XF86AudioPrev"], "brightness keys": ["XF86MonBrightnessUp", "XF86MonBrightnessDown"]}


def norm_key(k):
    """a keysym name as the sheet and config.h can both be compared by."""
    k = k.strip()
    if k.lower() in NAMES:
        return NAMES[k.lower()]
    return k.lower() if len(k) == 1 else k


def config_keys(text):
    """{(frozenset(mods), key)} from config.h; buttons as BTN_*, axes as Axis*."""
    out = set()

    def mods(expr):
        ms = set()
        for m in expr.split("|"):
            m = m.strip()
            if MODS.get(m):
                ms.add(MODS[m])
        return frozenset(ms)

    body = text[text.index("static const Key keys[]"):]
    body = body[:body.index("};")]
    for m in re.finditer(r"\{\s*([A-Z_|0 ]+?)\s*,\s*XKB_KEY_(\w+)\s*,\s*(\w+)", body):
        out.add((mods(m.group(1)), norm_key(m.group(2))))
    for m in re.finditer(r"TAGKEYS\(\s*XKB_KEY_(\w+)", body):
        k = norm_key(m.group(1))
        for ms in ({"Super"}, {"Super", "Ctrl"}, {"Super", "Shift"}, {"Super", "Ctrl", "Shift"}):
            out.add((frozenset(ms), k))
    for m in re.finditer(r"CHVT\((\d+)\)", body):
        out.add((frozenset({"Ctrl", "Alt"}), f"F{m.group(1)}"))
    for arr, rx in (("Button buttons[]", r"\{\s*([A-Z_|0 ]+?)\s*,\s*(BTN_\w+)"),
                    ("Axis axes[]", r"\{\s*([A-Z_|0 ]+?)\s*,\s*(Axis\w+)")):
        if arr in text:
            b = text[text.index(arr):]
            b = b[:b.index("};")]
            for m in re.finditer(rx, b):
                out.add((mods(m.group(1)), m.group(2)))
    return out


def expand(spec):
    """'Super+J / K' → [(mods, key)…]; None when the sheet's words are not a key."""
    spec = spec.strip()
    low = spec.lower()
    if " · " in spec or low in MEDIA:
        keys = []
        for part in spec.split(" · "):
            if part.lower() not in MEDIA:
                return None
            keys += [(frozenset(), k) for k in MEDIA[part.lower()]]
        return keys
    out, prev_mods = [], None
    for alt in spec.split(" / "):
        alt = alt.strip()
        parts = alt.split("+") if alt not in ("+",) else ["+"]
        # a lone key after " / " shares the modifiers of the one before it
        if len(parts) == 1 and prev_mods is not None:
            ms, key = prev_mods, parts[0]
        else:
            ms, key = frozenset(p for p in parts[:-1]), parts[-1]
        if not key:                                     # "Super++"
            key = "+"
        prev_mods = ms
        if key in ("drag", "right-drag", "middle-click"):
            key = {"drag": "BTN_LEFT", "right-drag": "BTN_RIGHT", "middle-click": "BTN_MIDDLE"}[key]
            out.append((ms, key))
        elif key == "scroll":
            out += [(ms, "AxisUp"), (ms, "AxisDown")]
        elif m := re.fullmatch(r"(F?)(\d+)…\1?(\d+)", key):
            out += [(ms, f"{m.group(1)}{i}") for i in range(int(m.group(2)), int(m.group(3)) + 1)]
        else:
            out.append((ms, norm_key(key)))
    return out


DWL_SECTIONS = ("launch", "screenshots", "windows", "workspaces", "sound", "session")


def sheet_keys(text):
    """[(line, spec, keys)] of the dwl sections; and the non-dwl specs met there."""
    rows, section = [], None
    for n, ln in enumerate(text.splitlines(), 1):
        m = re.match(r"── (\w+)", ln)
        if m:
            section = m.group(1)
            continue
        if section not in DWL_SECTIONS or not ln.strip():
            continue
        # the keys fill a column 24 wide (one may touch the words: "Super+drag / right-drag move")
        spec, desc = ln[:24].strip(), ln[24:].strip()
        rows.append((n, spec, desc))
        # "(or Super+middle-click)" in the words: a second key for the same thing
        for extra in re.findall(r"\(or (Super\+[\w-]+)\)", desc):
            rows.append((n, extra, desc))
    return rows


def check(repo):
    ch = (repo / "src/dwl/config.h").read_text()
    sheet = (repo / "configs/home/.config/fedokawaii/keybinds.txt").read_text()
    have = config_keys(ch)
    told = set()
    problems = []
    for n, spec, desc in sheet_keys(sheet):
        if spec == "Alt+Shift":
            conf = (repo / "fedokawaii.conf").read_text()
            if not re.search(r"^KB_TOGGLE=.*alt_shift_toggle", conf, re.M):
                problems.append(f"keybinds.txt:{n}: Alt+Shift — fedokawaii.conf's KB_TOGGLE is not grp:alt_shift_toggle")
            continue
        if spec == "Right Shift+F12":
            mh = (repo / "configs/home/.config/MangoHud/MangoHud.conf").read_text()
            if not re.search(r"^toggle_hud=Shift_R\+F12\s*$", mh, re.M):
                problems.append(f"keybinds.txt:{n}: Right Shift+F12 — MangoHud.conf's toggle_hud is not Shift_R+F12")
            continue
        keys = expand(spec)
        if keys is None:
            problems.append(f"keybinds.txt:{n}: {spec!r} — not a key this check can read")
            continue
        for k in keys:
            told.add(k)
            if k not in have:
                problems.append(f"keybinds.txt:{n}: {spec} ({'+'.join(sorted(k[0]))}+{k[1]}) — config.h does not bind it")
    for k in sorted(have - told, key=lambda k: (sorted(k[0]), k[1])):
        if k[0] == frozenset({"Ctrl", "Alt"}) and re.fullmatch(r"F\d+", k[1]):
            continue                                    # the text consoles: the sheet names the common ones
        problems.append(f"config.h binds {'+'.join(sorted(k[0]) + [k[1]])}, the help sheet never says so")
    return problems


if __name__ == "__main__":
    p = check(pathlib.Path(sys.argv[1]))
    for x in p:
        print(x)
    sys.exit(1 if p else 0)
