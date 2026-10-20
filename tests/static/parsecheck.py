#!/usr/bin/env python3
"""tests/static/parsecheck.py — does every config file of the desktop read as its format?

    python3 parsecheck.py shell REPO       the shell files (scripts, libraries, sourced files)
    python3 parsecheck.py data REPO        one line per data file: ok|bad|skip KIND FILE[: why]
    python3 parsecheck.py lua FILE…        Lua 5.4's own parser (liblua through ctypes)
    python3 parsecheck.py waybar FILE      every module the bar lists is configured or built in

The formats: JSON and waybar's JSONC, TOML (tomllib), YAML (PyYAML when it is there), INI
(read strictly: a line is a comment, a [section] or key=value; no key twice in a section,
except where the program means it — systemd's units), desktop entries (the spec's rules, or
desktop-file-validate when installed), XML, Lua, and the key=value / option-list files of
mpv, MangoHud, swaylock, btop, zathura, bat, yt-dlp and fzf.
"""
import ctypes
import ctypes.util
import json
import pathlib
import re
import shlex
import sys
import xml.etree.ElementTree as ET

try:
    import tomllib
except ImportError:                      # (python < 3.11)
    tomllib = None
try:
    import yaml
except ImportError:
    yaml = None

SHEBANG = re.compile(r"#!\S*(/env )?\S*\b(ba|da)?sh\b")


def shell_files(repo):
    """every file that is shell: by its first line, or sourced by the scripts."""
    out = []
    for d in ("bin", "system", "lib"):
        for f in sorted((repo / d).iterdir()):
            if f.is_file():
                first = f.read_text(errors="replace").split("\n", 1)[0]
                if SHEBANG.match(first) or "shellcheck shell=" in first:
                    out.append(f)
    out += sorted(repo.glob("*.sh"))
    for f in sorted((repo / "configs").rglob("*")):
        if f.is_file() and f.suffix not in (".ttf", ".png", ".xpm") and "/cursors/" not in str(f):
            first = f.read_text(errors="replace").split("\n", 1)[0]
            if SHEBANG.match(first) or f.suffix == ".sh":
                out.append(f)
    return [str(f.relative_to(repo)) for f in out]


def sourced_files(repo):
    """shell without a first line of its own, read by the scripts with `.`: bash -n only."""
    h = repo / "configs/home/.config/fedokawaii"
    return [str(f.relative_to(repo)) for f in [h / "env", h / "icons.sh", *sorted((h / "themes").glob("*/colors.sh"))]]


# ── formats ──────────────────────────────────────────────────────────────────────────────
def strip_jsonc(text):
    out, i, n, q = [], 0, len(text), False
    while i < n:
        c = text[i]
        if q:
            out.append(c)
            if c == "\\":
                out.append(text[i + 1]); i += 2; continue
            q = c != '"'
            i += 1
            continue
        if c == '"':
            q = True
        elif text.startswith("//", i):
            j = text.find("\n", i)
            i = n if j < 0 else j
            continue
        elif text.startswith("/*", i):
            i = text.find("*/", i) + 2
            continue
        out.append(c); i += 1
    return "".join(out)


def check_json(text, jsonc=False):
    json.loads(strip_jsonc(text) if jsonc else text)


def check_ini(text, dup_ok=False, top_ok=False, key_re=r"[A-Za-z0-9_.@$/+-][^=]*?"):
    """strict INI: comments, [sections], key=value; returns nothing or raises ValueError."""
    section, keys = None, set()
    for n, raw in enumerate(text.splitlines(), 1):
        ln = raw.strip()
        if not ln or ln[0] in "#;":
            continue
        m = re.fullmatch(r"\[([^\]]+)\]", ln)
        if m:
            section, keys = m.group(1), set()
            continue
        m = re.fullmatch(rf"({key_re})\s*=(.*)", ln)
        if not m:
            raise ValueError(f"line {n}: neither a [section] nor key=value: {raw[:80]}")
        if section is None and not top_ok:
            raise ValueError(f"line {n}: a key before any [section]")
        key = m.group(1).strip()
        if key in keys and not dup_ok:
            raise ValueError(f"line {n}: {key} twice in [{section}]")
        keys.add(key)


DESKTOP_KEYS = set("""Type Version Name GenericName NoDisplay Comment Icon Hidden OnlyShowIn NotShowIn
DBusActivatable TryExec Exec Path Terminal Actions MimeType Categories Implements Keywords
StartupNotify StartupWMClass URL PrefersNonDefaultGPU SingleMainWindow""".split())


def check_desktop(text):
    """the Desktop Entry spec's rules that matter to a launcher and to xdg-open."""
    lines = [ln for ln in text.splitlines() if ln.strip() and not ln.lstrip().startswith("#")]
    if not lines or lines[0].strip() != "[Desktop Entry]":
        raise ValueError("the first group must be [Desktop Entry]")
    check_ini(text)
    kv = dict(re.match(r"([^=]+?)\s*=\s*(.*)", ln).groups() for ln in lines[1:] if not ln.startswith("["))
    for k in kv:
        base = re.sub(r"\[[^\]]+\]$", "", k)
        if base not in DESKTOP_KEYS and not base.startswith("X-"):
            raise ValueError(f"unknown key {k}")
    for need in ("Type", "Name"):
        if need not in kv:
            raise ValueError(f"no {need}=")
    if kv["Type"] == "Application" and "Exec" not in kv and kv.get("DBusActivatable") != "true":
        raise ValueError("an Application needs Exec=")
    for b in ("NoDisplay", "Hidden", "Terminal", "StartupNotify", "DBusActivatable"):
        if b in kv and kv[b] not in ("true", "false"):
            raise ValueError(f"{b}={kv[b]}: true or false")
    for lst in ("MimeType", "Categories", "Keywords", "OnlyShowIn", "NotShowIn", "Actions"):
        if lst in kv and not kv[lst].endswith(";"):
            raise ValueError(f"{lst}= must end with ;")
    if "MimeType" in kv:
        for t in kv["MimeType"].rstrip(";").split(";"):
            if not re.fullmatch(r"[a-z0-9-]+/[A-Za-z0-9.+_-]+", t):
                raise ValueError(f"MimeType {t!r} is not type/subtype")
    if "Exec" in kv:
        codes = re.findall(r"%(.)", kv["Exec"])
        if any(c not in "fFuUick%" for c in codes):
            raise ValueError(f"Exec= has an unknown field code: {kv['Exec']}")
        if sum(c in "fFuU" for c in codes) > 1:
            raise ValueError("Exec= may hold one of %f %F %u %U")


def check_mimeapps(text):
    check_ini(text)
    for n, ln in enumerate(text.splitlines(), 1):
        m = re.match(r"([^#\[][^=]*)=(.*)", ln)
        if m:
            if not re.fullmatch(r"[a-z0-9-]+/[A-Za-z0-9.+_-]+", m.group(1)):
                raise ValueError(f"line {n}: {m.group(1)!r} is not a MIME type")
            for d in filter(None, m.group(2).split(";")):
                if not d.endswith(".desktop"):
                    raise ValueError(f"line {n}: {d!r} is not a .desktop name")


def check_keyvalue(text, sections=False, sep="="):
    """key=value lines and bare flags (mpv, MangoHud, swaylock): nothing else."""
    for n, raw in enumerate(text.splitlines(), 1):
        ln = raw.split("#", 1)[0].strip() if not re.search(r'"[^"]*#', raw) else raw.strip()
        if not ln or ln.startswith("#"):
            continue
        if sections and re.fullmatch(r"\[[^\]]+\]", ln):
            continue
        if not re.fullmatch(rf"[A-Za-z0-9_.-]+(\s*{sep}.*)?", ln):
            raise ValueError(f"line {n}: not key{sep}value: {raw[:80]}")


def check_mpv(text):
    for n, raw in enumerate(text.splitlines(), 1):
        ln = raw.strip()
        if not ln or ln.startswith("#") or re.fullmatch(r"\[[^\]]+\]", ln):
            continue
        if ln.startswith("@"):                  # a token theme.sh fills (@MPV_SCALING@)
            continue
        m = re.fullmatch(r"([A-Za-z0-9_-]+)(?:=(.*))?", ln)
        if not m:
            raise ValueError(f"line {n}: not option=value: {raw[:80]}")
        v = (m.group(2) or "").strip()
        if v.startswith('"'):                   # a quoted value: one closing quote, then a comment at most
            if not re.fullmatch(r'"[^"]*"\s*(#.*)?', v):
                raise ValueError(f"line {n}: the quoted value is not closed, or text follows it")
        elif "#" in v and not re.search(r"\s#", v):
            raise ValueError(f"line {n}: an unquoted # starts a comment here: quote the value")


def check_options(text):
    """bat, yt-dlp, fzf: command-line options, as the shell would split them."""
    for n, raw in enumerate(text.splitlines(), 1):
        ln = raw.strip()
        if not ln or ln.startswith("#"):
            continue
        for w in shlex.split(ln):
            if not w.startswith("-") and not re.match(r"[\w.:/~@-]", w):
                raise ValueError(f"line {n}: {w!r}")


def check_zathurarc(text):
    for n, raw in enumerate(text.splitlines(), 1):
        ln = raw.strip()
        if not ln or ln.startswith("#"):
            continue
        w = shlex.split(ln, comments=True)
        if not w or w[0] not in ("set", "map", "unmap", "include"):
            raise ValueError(f"line {n}: not set/map/unmap/include: {raw[:80]}")
        if w[0] == "set" and len(w) != 3 and not (len(w) == 2):
            raise ValueError(f"line {n}: set takes a name and one value")


def check_btop_theme(text):
    for n, raw in enumerate(text.splitlines(), 1):
        ln = raw.strip()
        if ln and not ln.startswith("#") and not re.fullmatch(r'theme\[[a-z_]+\]\s*=\s*"[^"]*"', ln):
            raise ValueError(f"line {n}: not theme[name]=\"value\"")


def check_xml(text):
    ET.fromstring(text.encode())


def kind_of(rel):
    name = rel.rsplit("/", 1)[-1]
    if name.endswith(".json"):
        return "json"
    if name.endswith(".jsonc"):
        return "jsonc"
    if name.endswith(".toml"):
        return "toml"
    if name.endswith((".yml", ".yaml")):
        return "yaml"
    if name.endswith(".desktop"):
        return "desktop"
    if name.endswith(".lua"):
        return "lua"
    if name.endswith(".xml") or name == "fonts.conf":
        return "xml"
    if name == "mimeapps.list":
        return "mimeapps"
    if "/systemd/" in rel or name.endswith((".service", ".timer", ".target", ".socket", ".container")):
        return "systemd"
    if name in ("foot.ini", "fuzzel.ini"):
        return "ini-top"
    if name.endswith((".ini", ".theme")) and name != "btop.theme" or name in (
            "cava.conf", "qt6ct.conf", "qt6ct-colors.conf", "tuned.conf", "wlroots-portals.conf", "imv") \
            or "/dconf/" in rel or "xdg-desktop-portal" in rel:
        return "ini"
    if name == "mpv.conf":
        return "mpv"
    if name in ("MangoHud.conf", "swaylock"):
        return "keyvalue"
    if name == "btop.conf":
        return "btop"
    if name == "btop.theme":
        return "btop-theme"
    if name == "zathurarc":
        return "zathura"
    if name == "fzf.opts" or rel.endswith((".config/bat/config", ".config/yt-dlp/config")):
        return "options"
    if name == "mako" or rel.endswith(".config/mako/config"):
        return "mako"
    if rel.endswith(".config/visidata/config.py"):   # VisiData's options file is Python
        return "python"
    return None


def data_files(repo):
    out = []
    for top in ("configs", "system", "src", "tests/static/fixtures", "tests/yazi"):
        d = repo / top
        if d.is_dir():
            for f in sorted(d.rglob("*")):
                if f.is_file():
                    rel = str(f.relative_to(repo))
                    k = kind_of(rel)
                    if k:
                        out.append((k, rel))
    return out


def lua_check(paths):
    """[(path, None | error)] — Lua 5.4's parser (the yazi plugins' own Lua); None when no
    Lua library is on this machine."""
    lib = None
    for name in ("liblua-5.4.so", "liblua5.4.so.0", "liblua5.4.so", "liblua.so.5.4",
                 ctypes.util.find_library("lua5.4") or "", ctypes.util.find_library("lua") or ""):
        if not name:
            continue
        try:
            lib = ctypes.CDLL(name)
            lib.luaL_loadfilex
            break
        except (OSError, AttributeError):
            lib = None
    if lib is None:
        return None
    lib.luaL_newstate.restype = ctypes.c_void_p
    lib.luaL_loadfilex.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_char_p]
    lib.lua_tolstring.restype = ctypes.c_char_p
    lib.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_void_p]
    lib.lua_close.argtypes = [ctypes.c_void_p]
    out = []
    for p in paths:
        L = lib.luaL_newstate()
        rc = lib.luaL_loadfilex(L, str(p).encode(), b"t")
        out.append((p, None if rc == 0 else lib.lua_tolstring(L, -1, None).decode(errors="replace")))
        lib.lua_close(L)
    return out


WAYBAR_BUILTIN = re.compile(r"(backlight|battery|bluetooth|clock|cpu|disk|group|idle_inhibitor|image|"
                            r"keyboard-state|memory|mpd|mpris|network|power-profiles-daemon|privacy|"
                            r"pulseaudio|sndio|systemd-failed-units|temperature|tray|upower|user|"
                            r"wireplumber|cava|cffi|load|gamemode|jack|custom/[\w-]+|group/[\w-]+)(#[\w-]+)?$")


def waybar_check(path):
    conf = json.loads(strip_jsonc(pathlib.Path(path).read_text()))
    bars = conf if isinstance(conf, list) else [conf]
    bad = []
    for bar in bars:
        # a group (group/NAME) is listed on a side and lists modules of its own
        groups = {k: bar[k].get("modules", []) for k in bar if k.startswith("group/")}
        for g, mods in groups.items():
            if not mods:
                bad.append(f"{g}: a group with no modules")
        for side in ("modules-left", "modules-center", "modules-right"):
            for m in bar.get(side, []) + [x for g in bar.get(side, []) for x in groups.get(g, [])]:
                if not WAYBAR_BUILTIN.match(m):
                    bad.append(f"{m}: not a waybar module")
                elif (m.startswith("custom/") or m.startswith("group/")) and m not in bar:
                    bad.append(f"{m}: listed, never configured")
                elif m.startswith("custom/") and not ({"exec", "format"} & set(bar[m])):
                    bad.append(f"{m}: neither exec nor format")
        listed = {m for s in ("modules-left", "modules-center", "modules-right") for m in bar.get(s, [])}
        listed |= {x for g in listed for x in groups.get(g, [])}
        for k in bar:
            if WAYBAR_BUILTIN.match(k) and k not in listed:
                bad.append(f"{k}: configured, but no side lists it")
    return bad


def main(argv):
    cmd, rest = argv[0], argv[1:]
    if cmd == "shell":
        repo = pathlib.Path(rest[0])
        for f in shell_files(repo):
            print(f)
    elif cmd == "sourced":
        for f in sourced_files(pathlib.Path(rest[0])):
            print(f)
    elif cmd == "lua":
        res = lua_check(rest)
        if res is None:
            print("skip no Lua 5.4 library here")
            return
        for p, err in res:
            print(f"ok lua {p}" if err is None else f"bad lua {p}: {err}")
    elif cmd == "waybar":
        for b in waybar_check(rest[0]):
            print(b)
    elif cmd == "data":
        repo = pathlib.Path(rest[0])
        home = pathlib.Path(rest[1]) if len(rest) > 1 else None   # the configs as installed (rendered)
        checks = {
            "json": check_json, "jsonc": lambda t: check_json(t, True),
            "toml": lambda t: tomllib.loads(t), "yaml": lambda t: yaml.safe_load(t),
            "desktop": check_desktop, "xml": check_xml, "mimeapps": check_mimeapps,
            "systemd": lambda t: check_ini(t, dup_ok=True), "ini": check_ini,
            "ini-top": lambda t: check_ini(t, top_ok=True), "mpv": check_mpv,
            "keyvalue": check_keyvalue, "btop": lambda t: check_keyvalue(t),
            "btop-theme": check_btop_theme, "zathura": check_zathurarc, "options": check_options,
            "mako": lambda t: check_ini(t, dup_ok=False, top_ok=True, key_re=r"[a-z-]+"),
            "python": lambda t: compile(t, "visidatarc", "exec"),
        }
        for kind, rel in data_files(repo):
            if kind == "lua":
                continue
            if kind == "toml" and tomllib is None or kind == "yaml" and yaml is None:
                print(f"skip {kind} {rel}: no {kind} reader in this python")
                continue
            try:
                src = home / rel[len("configs/home/"):] if home and rel.startswith("configs/home/") else repo / rel
                checks[kind](src.read_text())
                print(f"ok {kind} {rel}")
            except Exception as e:  # noqa: BLE001 — every reader's own error is the message
                print(f"bad {kind} {rel}: {type(e).__name__}: {e}".replace("\n", " "))


if __name__ == "__main__":
    main(sys.argv[1:])
