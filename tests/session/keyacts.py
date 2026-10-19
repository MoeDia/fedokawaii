#!/usr/bin/env python3
"""tests/session/keyacts.py REPO — does each line of the help sheet (Super+/, keybinds.txt) say
what its keys really do in dwl's config.h? One line per mismatch; exit 1 if any.

tests/static/keybinds.py checks that the sheet and config.h name the same keys. This one
checks the meaning: Super+J is "focus next" only if config.h binds it to focusstack +1, the
"terminal" row spawns foot's client, Super+S / T / Y / M are the layouts the words name (and
layouts[] really holds spiral, columns, floating and monocle in that order)… ROWS below is the meaning of
each row of the sheet's dwl sections; a row this check does not know is reported, so a new or
reworded row is looked at here too. Also: no key bound twice (the second binding would be
dead), every kawa-* a key runs exists and takes the word it is given.
"""
import pathlib
import re
import sys

MODS = {"MODKEY": "Super", "SHIFT": "Shift", "CTRL": "Ctrl", "WLR_MODIFIER_ALT": "Alt",
        "WLR_MODIFIER_LOGO": "Super", "WLR_MODIFIER_SHIFT": "Shift", "WLR_MODIFIER_CTRL": "Ctrl"}

# row of the sheet (its keys, exactly as written) → (words its description must hold,
# [the action of each key the row names, in the row's order])
# an action: "spawn:COMMAND" (the words dwl runs), or "FUNCTION:ARGUMENT" (dwl's own)
TAGS = [f"{1 << i}" for i in range(9)]
ROWS = {
    "Super+Return":            ("terminal (foot)", ["spawn:footclient"]),
    "Super+Space":             ("launcher", ["spawn:fuzzel"]),
    "Super+B":                 ("browser (Brave Origin)", ["spawn:brave-origin"]),
    "Super+E":                 ("files (yazi)", ["spawn:footclient yazi"]),
    "Super+X":                 ("quick settings", ["spawn:kawa-quick"]),
    "Super+A":                 ("sound: volume, output, input", ["spawn:kawa-audio"]),
    "Super+C":                 ("calendar", ["spawn:kawa-calendar"]),
    "Super+/":                 ("this help", ["spawn:kawa-help"]),
    "Super+W":                 ("wallpaper picker", ["spawn:kawa-wallpaper"]),
    "Super+Shift+W":           ("dark / light theme", ["spawn:kawa-theme"]),
    "Super+V":                 ("clipboard history", ["spawn:kawa-clip"]),
    "Super+Z":                 ("shrink or convert", ["spawn:kawa-shrink"]),
    "Super+R":                 ("books", ["spawn:kawa-books"]),
    "Super+N":                 ("notes", ["spawn:kawa-notes"]),
    "Super+Shift+N":           ("dismiss notifications", ["spawn:makoctl dismiss -a"]),
    "Super+U":                 ("the system: update, new Fedora, repair", ["spawn:fedokawaii --window"]),
    "Super+Shift+U":           ("change the desktop", ["spawn:kawa-config"]),
    "Super+Escape":            ("lock screen (then sleep after 90 s)", ["spawn:kawa-lock --sleep"]),
    "Super+Shift+E":           ("power menu", ["spawn:kawa-power"]),
    "Print":                   ("region", ["spawn:kawa-screenshot region"]),
    "Shift+Print":             ("full screen", ["spawn:kawa-screenshot full"]),
    "Super+Print":             ("region → annotate", ["spawn:kawa-screenshot edit"]),
    "Super+Q":                 ("close window", ["killclient:0"]),
    "Super+J / K":             ("focus next / previous", ["focusstack:+1", "focusstack:-1"]),
    "Super+H / L":             ("spiral: the first window narrower / wider", ["setmfact:-0.05f", "setmfact:+0.05f"]),
    "Super+Shift+Return":      ("move window to the first (largest) place", ["zoom:0"]),
    "Super+F":                 ("fullscreen", ["togglefullscreen:0"]),
    "Super+Shift+Space":       ("float / unfloat", ["togglefloating:0"]),
    "Super+middle-click":      ("float / unfloat", ["togglefloating:0"]),
    "Super+drag / right-drag": ("move / resize", ["moveresize:CurMove", "moveresize:CurResize"]),
    "Super+S":                 ("layout: golden spiral (the default)", ["setlayout:&layouts[0]"]),
    "Super+T":                 ("layout: columns, left to right", ["setlayout:&layouts[1]"]),
    "Super+Y / M":             ("layout: floating · one at a time", ["setlayout:&layouts[2]", "setlayout:&layouts[3]"]),
    "Super+Shift+T":           ("the tiling layout used before", ["setlayout:0"]),
    "Super+1…9":               ("go to workspace", [f"view:{t}" for t in TAGS]),
    "Super+Shift+1…9":         ("send window to workspace", [f"tag:{t}" for t in TAGS]),
    "Super+Ctrl+1…9":          ("also show workspace", [f"toggleview:{t}" for t in TAGS]),
    "Super+Ctrl+Shift+1…9":    ("also show the window on workspace", [f"toggletag:{t}" for t in TAGS]),
    "Super+Tab":               ("previous workspace", ["view:0"]),
    "Super+0":                 ("all workspaces at once", ["view:~0"]),
    "Super+Shift+0":           ("the window on every workspace", ["tag:~0"]),
    "Super+, / .":             ("focus monitor left / right", ["focusmon:WLR_DIRECTION_LEFT", "focusmon:WLR_DIRECTION_RIGHT"]),
    "Super+Shift+, / .":       ("send window to monitor", ["tagmon:WLR_DIRECTION_LEFT", "tagmon:WLR_DIRECTION_RIGHT"]),
    "Volume · Mute · Mic":     ("media keys, with a level display",
                                ["spawn:kawa-volume up", "spawn:kawa-volume down", "spawn:kawa-volume mute", "spawn:kawa-volume mic"]),
    "Play · Next · Previous":  ("media keys",
                                ["spawn:kawa-nowplaying play-pause", "spawn:kawa-nowplaying next", "spawn:kawa-nowplaying previous"]),
    "Super+scroll":            ("volume ±2 %", ["spawn:kawa-volume up 2", "spawn:kawa-volume down 2"]),
    "Super+] / Super+[":       ("monitor brightness up / down", ["spawn:kawa-brightness +10", "spawn:kawa-brightness -10"]),
    "Brightness keys":         ("the same", ["spawn:kawa-brightness +10", "spawn:kawa-brightness -10"]),
    "Sleep key":               ("locked first, then asleep", ["spawn:kawa-power sleep", "spawn:kawa-power sleep"]),
    "Super+Ctrl+Shift+Q":      ("log out (quit dwl)", ["quit:0"]),
    "Ctrl+Alt+F2…F6":          ("text consoles", [f"chvt:({n})" for n in range(2, 7)]),
    "Ctrl+Alt+F1":             ("back here", ["chvt:(1)"]),
}
NOT_DWL = {"Alt+Shift", "Right Shift+F12"}     # XKB's and MangoHud's own (tests/static checks where)
KEYS = {"Return": "Return", "Space": "space", "/": "slash", "Escape": "Escape", "Print": "Print",
        "Tab": "Tab", ",": "comma", ".": "period", "]": "bracketright", "[": "bracketleft"}
MEDIA = {"Volume": ["XF86AudioRaiseVolume", "XF86AudioLowerVolume"], "Mute": ["XF86AudioMute"],
         "Mic": ["XF86AudioMicMute"], "Play": ["XF86AudioPlay"], "Next": ["XF86AudioNext"],
         "Previous": ["XF86AudioPrev"], "Brightness keys": ["XF86MonBrightnessUp", "XF86MonBrightnessDown"],
         "Sleep key": ["XF86Sleep", "XF86Suspend"]}
POINTER = {"drag": "BTN_LEFT", "right-drag": "BTN_RIGHT", "middle-click": "BTN_MIDDLE", "scroll": None}


def keys_of(spec):
    """'Super+J / K' → [(mods, key)…] in the row's order."""
    if spec in MEDIA:
        return [(frozenset(), k) for k in MEDIA[spec]]
    if " · " in spec:
        return [k for part in spec.split(" · ") for k in keys_of(part)]
    out, prev = [], frozenset()
    for alt in spec.split(" / "):
        parts = alt.split("+")
        mods = frozenset(parts[:-1]) if len(parts) > 1 else prev
        key = parts[-1]
        prev = mods
        if key in POINTER:
            out += [(mods, "AxisUp"), (mods, "AxisDown")] if key == "scroll" else [(mods, POINTER[key])]
        elif m := re.fullmatch(r"(F?)(\d+)…\1(\d+)", key):
            out += [(mods, f"{m.group(1)}{i}") for i in range(int(m.group(2)), int(m.group(3)) + 1)]
        else:
            out.append((mods, KEYS.get(key, key.lower() if len(key) == 1 else key)))
    return out


def action(func, arg, cmds):
    """dwl's (function, argument text) → 'spawn:COMMAND' or 'FUNCTION:ARGUMENT'."""
    arg = arg.strip()
    if func == "spawn":
        if m := re.fullmatch(r'SHCMD\("(.*)"\)', arg):
            return "spawn:" + m.group(1)
        if m := re.fullmatch(r"\{\s*\.v\s*=\s*(\w+)\s*\}", arg):
            return "spawn:" + " ".join(cmds.get(m.group(1), ["?" + m.group(1)]))
    m = re.fullmatch(r"\{\s*(?:\.\w+\s*=\s*)?(.*?)\s*\}", arg)
    a = m.group(1) if m else arg
    a = re.sub(r"^1 << (\d+)$", lambda x: str(1 << int(x.group(1))), a)
    return f"{func}:{a}"


def parse_config(text):
    """{(mods, key): [action…]} (a list: a key bound twice shows twice), and the layouts."""
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    cmds = {m.group(1): re.findall(r'"([^"]*)"', m.group(2))
            for m in re.finditer(r"static const char \*(\w+)\[\]\s*=\s*\{(.*?)\};", text)}
    macros = {}   # the ones that stand for whole entries of keys[] (TAGKEYS, CHVT), not SHCMD
    for m in re.finditer(r"#define (\w+)\((\w+(?:,\w+)*)\)\s*((?:.*\\\n)*.*)", text):
        if m.group(1) not in ("SHCMD", "COLOR"):
            macros[m.group(1)] = (m.group(2).split(","), m.group(3).replace("\\\n", " "))

    def expand(line):
        for name, (params, body) in macros.items():
            for m in re.finditer(rf"\b{name}\(([^()]*)\)", line):
                args = [a.strip() for a in m.group(1).split(",")]
                b = body
                for p, a in zip(params, args):
                    b = re.sub(rf"(\w*)##{p}\b", lambda x: x.group(1) + a, b)
                    b = re.sub(rf"\b{p}\b", a, b)
                line = line.replace(m.group(0), b)
        return line

    binds = {}
    for arr, keyrx in (("Key keys[]", r"XKB_KEY_(\w+)"), ("Button buttons[]", r"(BTN_\w+)"), ("Axis axes[]", r"(Axis\w+)")):
        body = text[text.index("static const " + arr):]
        body = body[body.index("{") + 1:]
        depth, end = 1, 0
        for i, c in enumerate(body):
            depth += c == "{"
            depth -= c == "}"
            if depth == 0:
                end = i
                break
        body = expand("\n".join(ln for ln in body[:end].splitlines() if not ln.lstrip().startswith("#")))
        for m in re.finditer(r"\{\s*([A-Z_|0 ]+?)\s*,\s*" + keyrx + r"\s*,\s*(\w+)\s*,\s*((?:\{[^{}]*\})|SHCMD\(\"(?:[^\"\\]|\\.)*\"\))\s*\}", body):
            mods = frozenset(MODS[x.strip()] for x in m.group(1).split("|") if x.strip() in MODS)
            key = m.group(2)
            binds.setdefault((mods, key), []).append(action(m.group(3), m.group(4), cmds))
    lay = re.search(r"static const Layout layouts\[\]\s*=\s*\{(.*?)\};", text, re.S).group(1)
    layouts = re.findall(r'\{\s*"([^"]*)"\s*,\s*(\w+)\s*\}', lay)
    return binds, layouts


def sheet_rows(text):
    sections = ("launch", "screenshots", "windows", "workspaces", "sound", "session")
    rows, section = [], None
    for n, ln in enumerate(text.splitlines(), 1):
        if m := re.match(r"── (\w+)", ln):
            section = m.group(1)
            continue
        if section in sections and ln.strip():
            spec, desc = ln[:24].strip(), ln[24:].strip()
            rows.append((n, spec, desc))
            for extra in re.findall(r"\((?:or |Ctrl\+Alt\+F1: )?((?:Super|Ctrl)\+[\w+-]+)(?::[^)]*)?\)", desc):
                rows.append((n, extra, desc))
    return rows


def check(repo):
    binds, layouts = parse_config((repo / "src/dwl/config.h").read_text())
    sheet = (repo / "configs/home/.config/fedokawaii/keybinds.txt").read_text()
    out, told = [], set()
    for (mods, key), acts in binds.items():
        if len(acts) > 1:
            out.append(f"config.h binds {'+'.join(sorted(mods) + [key])} {len(acts)} times: only the first works")
    for n, spec, desc in sheet_rows(sheet):
        if spec in NOT_DWL:
            continue
        if spec not in ROWS:
            out.append(f"keybinds.txt:{n}: {spec!r} — a row this check does not know: add its meaning to ROWS")
            continue
        words, acts = ROWS[spec]
        if words not in desc:
            out.append(f"keybinds.txt:{n}: {spec} says {desc!r}, not {words!r}")
        ks = keys_of(spec)
        if len(ks) != len(acts):
            out.append(f"keybinds.txt:{n}: {spec} names {len(ks)} keys, the check knows {len(acts)} actions")
            continue
        for k, want in zip(ks, acts):
            told.add(k)
            got = binds.get(k, ["(nothing)"])[0]
            if want != got:
                out.append(f"keybinds.txt:{n}: {spec} ({'+'.join(sorted(k[0]) + [k[1]])}) is {desc!r}, but config.h does {got}")
    for k in sorted(set(binds) - told, key=lambda k: (sorted(k[0]), k[1])):
        if k[0] == frozenset({"Ctrl", "Alt"}) and re.fullmatch(r"F\d+", k[1]):
            continue                                   # the other text consoles: the sheet names 1–6
        out.append(f"config.h binds {'+'.join(sorted(k[0]) + [k[1]])} ({binds[k][0]}), the help sheet never says so")
    want_layouts = [("(@)", "spiral"), ("|||", "tile"), ("><>", "NULL"), ("[M]", "monocle")]
    if layouts[:4] != want_layouts:
        out.append(f"layouts[] is {layouts[:4]}: Super+S / T / Y / M say spiral · columns · float · one at a time ({want_layouts})")
    # every helper a key runs: there, and it takes the word it is given
    for acts in binds.values():
        a = acts[0]
        if not a.startswith("spawn:"):
            continue
        words = a[6:].split()
        name = words[0]
        if name.startswith("kawa-") or name == "fedokawaii":
            f = repo / ("system" if name == "fedokawaii" else "bin") / name
            if not f.is_file():
                out.append(f"config.h runs {name}, which is not in the repository")
                continue
            src = f.read_text()
            for w in words[1:]:               # (named in its usage or one of its cases)
                if not re.search(rf"(?<![\w+-]){re.escape(w)}(?![\w-])", src):
                    out.append(f"config.h runs {' '.join(words)}, but {name} never mentions {w!r}")
    return out


if __name__ == "__main__":
    p = check(pathlib.Path(sys.argv[1]))
    print("\n".join(p))
    sys.exit(1 if p else 0)
