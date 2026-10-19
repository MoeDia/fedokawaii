#!/usr/bin/env python3
"""tests/static/deps.py — every program the desktop runs, and where each one comes from.

    python3 deps.py calls REPO            SOURCE<TAB>WHERE<TAB>PROGRAM[<TAB>guarded]
    python3 deps.py check REPO FIXTURES MANIFEST_PKGS
                                          what cannot be found, one line each; exit 1 if any

Programs are read from: the scripts in bin/ and system/, the session's autostart.sh and the
shell's ~/.bashrc.d, waybar's exec / on-click, mako's on-button actions, the launcher
entries' Exec=, yazi's keymaps and plugins (the desktop's and the file dialog's), dwl's
config.h (its spawn arrays and SHCMD), the systemd user units, the portals' configs, foot,
fuzzel, satty, lazygit, herdr, yt-dlp and udiskie — and yazi 26.9.1's own preset (what its
openers and previewers run: FIXTURES/yazi-builtin.txt).

Each must be one of: bin/ or system/ (the desktop's own), lib/upstream.sh's table, built by
setup.sh (dwl, the C helpers, torrra), or in FIXTURES/programs.txt — a package lib/manifest.sh
installs (MANIFEST_PKGS lists them) or a package of a Fedora 44 Minimal Install.
"""
import json
import pathlib
import re
import sys

sys.dont_write_bytecode = True          # (no __pycache__ left in the repository)
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import shcmds  # noqa: E402


def shell_files(repo):
    out = []
    for d in ("bin", "system"):
        for f in sorted((repo / d).iterdir()):
            if not f.is_file():
                continue
            head = f.read_text(errors="replace")[:200]
            if head.startswith("#!") and re.match(r"#!\S*(/env )?\S*(ba|da)?sh\b", head) \
                    or "shellcheck shell=" in head.splitlines()[0]:
                out.append(f)
    out += [repo / "configs/home/.config/dwl/autostart.sh"]
    out += sorted((repo / "configs/home/.bashrc.d").glob("*.sh"))
    out += [repo / "configs/home/.config/blesh/init.sh"]      # (ble.sh's settings: the shell too)
    return out


def helper_funcs(repo):
    """functions the scripts source from elsewhere (width.sh's cols and heading, files.sh's free_name, lib/common.sh's …)."""
    names = set()
    for f in [repo / "configs/home/.config/fedokawaii/icons.sh", repo / "configs/home/.config/fedokawaii/width.sh", repo / "configs/home/.config/fedokawaii/files.sh",
              repo / "bin/kawa-bar",   # (bar_lit: sourced by the bar's long-running modules)
              *sorted((repo / "lib").glob("*.sh"))]:
        names |= shcmds.funcs_of(f.read_text())
    return names


def sh(text, line=1, funcs=()):
    return shcmds.programs(text, line, funcs)


def strip_jsonc(text):
    """JSONC → JSON: // comments outside strings, trailing commas."""
    out, i, n, q = [], 0, len(text), False
    while i < n:
        c = text[i]
        if q:
            out.append(c)
            if c == "\\":
                out.append(text[i + 1]); i += 2; continue
            if c == '"':
                q = False
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
    return re.sub(r",(\s*[}\]])", r"\1", "".join(out))


def lua_strings(expr):
    """a Lua table or concatenation → shell words: literals kept, anything else a stand-in."""
    words = []
    for part in re.split(r",(?![^{]*})", expr):
        part = part.strip()
        if not part or "=" in part.split('"')[0]:
            continue
        lits = re.findall(r'"((?:[^"\\]|\\.)*)"', part)
        whole = re.fullmatch(r'"((?:[^"\\]|\\.)*)"', part)
        words.append(shquote(whole.group(1)) if whole else ("".join(lits) + "X" if lits else "X"))
    return words


def shquote(s):
    return "'" + s.replace("'", "'\\''") + "'"


def c_unescape(s):
    return re.sub(r"\\(.)", lambda m: {"n": "\n", "t": "\t"}.get(m.group(1), m.group(1)), s)


def home_bin(text):
    """@HOME@/.local/bin/X, %h/.local/bin/X → X (the desktop's own helpers by full path)."""
    return re.sub(r"(@HOME@|%h|\$HOME|~)/\.local/bin/", "", text)


def snippets(repo):
    """(source, where, text, line): every piece of shell the configs hand to sh (or run as a
    command line): waybar's exec / on-click, mako's exec, Exec=, yazi's shell and Command(…),
    dwl's spawn arrays and SHCMD, systemd's Exec*=, the portals', foot's and fuzzel's commands."""
    out = []

    def add(source, where, text, line=1):
        out.append((source, where, text, line))

    # waybar: every exec, exec-if and on-* runs through sh -c
    wb = repo / "configs/home/.config/waybar/config.jsonc"
    for mod, conf in json.loads(strip_jsonc(wb.read_text())).items():
        if isinstance(conf, dict):
            for k, v in conf.items():
                if isinstance(v, str) and (k in ("exec", "exec-if", "on-update") or k.startswith(("on-click", "on-scroll"))):
                    add("waybar", f"waybar {mod}.{k}", home_bin(v))

    # mako: an action is "exec CMD" (or a built-in: dismiss, invoke-default-action, none…)
    for f in [repo / "configs/home/.config/mako/config",
              *sorted((repo / "configs/home/.config/fedokawaii/themes").glob("*/mako"))]:
        for n, ln in enumerate(f.read_text().splitlines(), 1):
            m = re.match(r"\s*(on-[a-z-]+)\s*=\s*(.*)", ln)
            if m and m.group(2).startswith("exec "):
                add("mako", f"{f.relative_to(repo)}:{n}", home_bin(m.group(2)[5:]), n)

    # launcher entries: Exec= and TryExec= (field codes are the file or link handed over). An
    # entry that only hides a package's own (NoDisplay, no file types) starts nothing: skipped
    for f in sorted((repo / "configs/home/.local/share/applications").glob("*.desktop")):
        lines = f.read_text().splitlines()
        if "NoDisplay=true" in lines and not any(x.startswith("MimeType=") for x in lines):
            continue
        for n, ln in enumerate(lines, 1):
            m = re.match(r"(Try)?Exec=(.*)", ln)
            if m:
                add("desktop", f"{f.relative_to(repo)}:{n}", home_bin(re.sub(r"%[fFuUick]", "FILE", m.group(2))), n)

    # yazi: keymaps (shell commands; plugins are checked on their own) and the plugins' Lua
    for f in [repo / "configs/home/.config/yazi/keymap.toml",
              repo / "configs/home/.config/fedokawaii/yazi-pick/keymap.toml"]:
        for n, ln in enumerate(f.read_text().splitlines(), 1):
            for run in re.findall(r'run\s*=\s*"((?:[^"\\]|\\.)*)"', ln) + re.findall(r"run\s*=\s*'([^']*)'", ln):
                m = re.match(r"shell\s+(?:--\s+(.*)|'([^']*)'|\"((?:[^\"\\]|\\.)*)\")", run)
                if m:
                    add("yazi", f"{f.relative_to(repo)}:{n}", m.group(1) or m.group(2) or c_unescape(m.group(3)), n)
    lua = sorted((repo / "configs/home/.config/yazi").rglob("*.lua")) + \
        sorted((repo / "configs/home/.config/fedokawaii/yazi-pick").rglob("*.lua"))
    for f in lua:
        text = f.read_text()
        for m in re.finditer(r'Command\(\s*"([^"]+)"\s*\)((?:\s*:\s*args?\((?:\{[^}]*\}|[^)]*)\))*)', text):
            words = [shquote(m.group(1))]
            for a in re.findall(r":\s*args?\((\{[^}]*\}|[^)]*)\)", m.group(2)):
                words += lua_strings(a.strip("{} "))
            n = text.count("\n", 0, m.start()) + 1
            add("yazi", f"{f.relative_to(repo)}:{n}", " ".join(words), n)
        for m in re.finditer(r'emit\(\s*"shell"\s*,\s*\{([^}]*)\}', text):
            first = lua_strings(m.group(1))[:1]
            if first:
                n = text.count("\n", 0, m.start()) + 1
                add("yazi", f"{f.relative_to(repo)}:{n}", first[0].strip("'"), n)

    # dwl: the spawn arrays and SHCMD strings of config.h
    ch = (repo / "src/dwl/config.h").read_text()
    for m in re.finditer(r'static const char \*\w+\[\]\s*=\s*\{([^}]*)\}', ch):
        words = [shquote(c_unescape(w)) for w in re.findall(r'"((?:[^"\\]|\\.)*)"', m.group(1))]
        n = ch.count("\n", 0, m.start()) + 1
        add("dwl", f"src/dwl/config.h:{n}", " ".join(words), n)
    for m in re.finditer(r'SHCMD\("((?:[^"\\]|\\.)*)"\)', ch):
        n = ch.count("\n", 0, m.start()) + 1
        add("dwl", f"src/dwl/config.h:{n}", c_unescape(m.group(1)), n)

    # systemd user units: Exec*= (a leading -, @, :, +, ! is systemd's, %h the home)
    for f in sorted((repo / "configs/home/.config/systemd/user").rglob("*")):
        if f.is_file():
            for n, ln in enumerate(f.read_text().splitlines(), 1):
                m = re.match(r"Exec\w*=\s*[-@:+!]*(.*)", ln)
                if m and m.group(1).strip():
                    add("systemd", f"{f.relative_to(repo)}:{n}", home_bin(m.group(1)), n)

    # other configs naming a program
    simple = {
        ".config/xdg-desktop-portal-termfilechooser/config": r"cmd=(.*)",
        ".config/xdg-desktop-portal-wlr/config": r"(?:chooser_cmd|exec_before|exec_after)=(.*)",
        ".config/foot/foot.ini": r"launch=(.*)",
        ".config/fuzzel/fuzzel.ini": r"terminal=(.*)",
        ".config/satty/config.toml": r'copy-command\s*=\s*"(.*)"',
        ".config/lazygit/config.yml": r"\s*editPreset:\s*(\S+)",
        ".config/herdr/config.toml": r'\s*command\s*=\s*"(.*)"',
    }
    for rel, rx in simple.items():
        f = repo / "configs/home" / rel
        for n, ln in enumerate(f.read_text().splitlines(), 1):
            m = re.match(rx, ln)
            if m:
                add("config", f"{f.relative_to(repo)}:{n}", home_bin(m.group(1)).replace("${url}", "URL"), n)
    foot = repo / "configs/home/.config/foot/foot.ini"
    for n, ln in enumerate(foot.read_text().splitlines(), 1):
        m = re.match(r"pipe-[\w-]+=\[(.*)\]", ln)
        if m:
            add("config", f"{foot.relative_to(repo)}:{n}", m.group(1), n)
    return out


def calls(repo):
    """(source, where, program, guarded) for everything the desktop runs."""
    funcs = helper_funcs(repo)
    rows = []
    for f in shell_files(repo):
        for ln, prog, g in sh(f.read_text(), 1, funcs):
            rows.append(("script", f"{f.relative_to(repo)}:{ln}", prog, g))
    for source, where, text, line in snippets(repo):
        for _, prog, g in sh(text, line, funcs):
            rows.append((source, where, prog, g))
    # a program named outright, not as shell: yt-dlp's JavaScript runtime, udiskie's hooks
    yt = repo / "configs/home/.config/yt-dlp/config"
    for n, ln in enumerate(yt.read_text().splitlines(), 1):
        m = re.match(r"--js-runtimes\s+(\w+)", ln)
        if m:
            rows.append(("config", f"{yt.relative_to(repo)}:{n}", m.group(1), False))
    ud = repo / "configs/home/.config/udiskie/config.yml"
    for n, ln in enumerate(ud.read_text().splitlines(), 1):
        m = re.match(r'\s*(?:password_prompt|event_hook)\s*:\s*\[\s*"([^"]+)"', ln)
        if m:
            rows.append(("config", f"{ud.relative_to(repo)}:{n}", m.group(1), False))
    return rows


# ── where programs come from ─────────────────────────────────────────────────────────────
def load_fixture(path):
    table = {}
    for n, ln in enumerate(path.read_text().splitlines(), 1):
        ln = ln.split("#", 1)[0].strip()
        if ln:
            prog, kind, *what = ln.split()
            table[prog] = (kind, " ".join(what), n)
    return table


def upstream_bins(repo):
    text = (repo / "lib/upstream.sh").read_text()
    bins = set()
    for m in re.finditer(r'^\s*"([^"|]+)\|[^"]*\|([^"|]*)"\s*$', text, re.M):
        bins.update(m.group(2).split())
    return bins


def own_programs(repo):
    names = {f.name for f in (repo / "bin").iterdir() if f.is_file()}
    names |= {f.name for f in (repo / "system").iterdir() if f.is_file() and "." not in f.name}
    return names


def check(repo, fixdir, manifest_file):
    """the problems, one string each (empty: every program has a home)."""
    progs = load_fixture(fixdir / "programs.txt")
    pkgs = set(manifest_file.read_text().split())
    up, own = upstream_bins(repo), own_programs(repo)
    setup = (repo / "setup.sh").read_text() + (repo / "theme.sh").read_text()
    problems = []
    # the fixture itself must be true to the repository
    for prog, (kind, what, n) in sorted(progs.items()):
        if kind == "manifest" and what not in pkgs:
            problems.append(f"fixture line {n}: {prog} — package {what} is not in lib/manifest.sh")
        elif kind == "minimal" and what in pkgs:
            problems.append(f"fixture line {n}: {prog} — {what} is in lib/manifest.sh: say manifest")
        elif kind == "dep" and (len(what.split()) != 2 or what.split()[1] not in pkgs):
            problems.append(f"fixture line {n}: {prog} — dep needs PACKAGE BY, BY a manifest package: {what}")
        elif kind == "upstream" and prog not in up:
            problems.append(f"fixture line {n}: {prog} — not a binary of lib/upstream.sh's table")
        elif kind == "built" and what not in setup:
            problems.append(f"fixture line {n}: {prog} — setup.sh / theme.sh never mention {what}")
        elif kind not in ("manifest", "minimal", "dep", "upstream", "built", "optional"):
            problems.append(f"fixture line {n}: {prog} — unknown kind {kind}")
    rows = calls(repo)
    rows += [("yazi", f"yazi 26.9.1 preset: {why}", prog, g)
             for prog, why, g in yazi_builtin(fixdir)]
    seen = {}
    for source, where, prog, guarded in rows:
        if prog in own or prog in up:
            continue
        kind = progs.get(prog, (None,))[0]
        if kind in ("manifest", "minimal", "dep", "built"):
            continue
        if kind == "optional" and guarded:
            continue
        key = (prog, kind)
        seen.setdefault(key, []).append(f"{where}" + (" (guarded)" if guarded else ""))
    for (prog, kind), wheres in sorted(seen.items()):
        why = "optional, but called unguarded" if kind == "optional" else "installed by nothing"
        problems.append(f"{prog}: {why} — {'; '.join(wheres[:4])}{' …' if len(wheres) > 4 else ''}")
    return problems


def check_desktop_refs(repo, fixdir, pkgs):
    """every launcher entry mimeapps.list and xdg-terminals.list name exists: the desktop's
    own, or one a manifest package ships (FIXTURES/desktop-files.txt); no type twice."""
    own = {f.name for f in (repo / "configs/home/.local/share/applications").glob("*.desktop")}
    shipped = {}
    for ln in (fixdir / "desktop-files.txt").read_text().splitlines():
        ln = ln.split("#", 1)[0].split()
        if ln:
            shipped[ln[0]] = ln[1]
    problems = [f"desktop-files.txt: {d} — package {p} is not in lib/manifest.sh"
                for d, p in sorted(shipped.items()) if p not in pkgs]
    ma = repo / "configs/home/.config/mimeapps.list"
    section, seen = None, {}
    for n, ln in enumerate(ma.read_text().splitlines(), 1):
        ln = ln.strip()
        if not ln or ln.startswith("#"):
            continue
        if ln.startswith("["):
            section = ln
            continue
        mime, _, apps = ln.partition("=")
        if (section, mime) in seen:
            problems.append(f"mimeapps.list:{n}: {mime} again in {section} (line {seen[section, mime]})")
        seen[section, mime] = n
        for d in filter(None, apps.split(";")):
            if d not in own and d not in shipped:
                problems.append(f"mimeapps.list:{n}: {mime} → {d}: no such launcher entry")
    for n, ln in enumerate((repo / "configs/home/.config/xdg-terminals.list").read_text().splitlines(), 1):
        ln = ln.strip()
        if ln and not ln.startswith("#") and ln not in own and ln not in shipped:
            problems.append(f"xdg-terminals.list:{n}: {ln}: no such launcher entry")
    return problems


def check_plugins(repo, fixdir):
    """every `plugin NAME` a yazi keymap runs is there: the desktop's, the dialog's or yazi's own."""
    preset = {w for ln in (fixdir / "yazi-plugins.txt").read_text().splitlines()
              if not ln.startswith("#") for w in ln.split()}
    mine = {p.name[:-5] for p in (repo / "configs/home/.config/yazi/plugins").glob("*.yazi")
            if (p / "main.lua").is_file()}
    pick = {p.name[:-5] for p in (repo / "configs/home/.config/fedokawaii/yazi-pick").glob("*.yazi")
            if (p / "main.lua").is_file()}
    problems = []
    for f, have in ((repo / "configs/home/.config/yazi/keymap.toml", mine),
                    (repo / "configs/home/.config/fedokawaii/yazi-pick/keymap.toml", mine | pick)):
        for n, ln in enumerate(f.read_text().splitlines(), 1):
            for name in re.findall(r'run\s*=\s*"plugin\s+([\w.-]+)', ln):
                if name not in have and name not in preset:
                    problems.append(f"{f.relative_to(repo)}:{n}: plugin {name} is nowhere")
    return problems


def yazi_builtin(fixdir):
    out = []
    for ln in (fixdir / "yazi-builtin.txt").read_text().splitlines():
        ln = ln.strip()
        if ln and not ln.startswith("#"):
            prog, rest = ln.split(None, 1)
            out.append((prog, rest.strip(), rest.rstrip().endswith("optional")))
    return out


def main(argv):
    if argv[0] == "calls":
        for row in calls(pathlib.Path(argv[1])):
            print("\t".join(row[:3]) + ("\tguarded" if row[3] else ""))
    elif argv[0] == "snippets":                  # NUL-separated: WHERE, TEXT, WHERE, TEXT…
        for _, where, text, _ in snippets(pathlib.Path(argv[1])):
            sys.stdout.write(f"{where}\0{text}\0")
    elif argv[0] in ("desktop", "plugins"):
        repo, fixdir = pathlib.Path(argv[1]), pathlib.Path(argv[2])
        problems = check_desktop_refs(repo, fixdir, set(pathlib.Path(argv[3]).read_text().split())) \
            if argv[0] == "desktop" else check_plugins(repo, fixdir)
        for p in problems:
            print(p)
        sys.exit(1 if problems else 0)
    elif argv[0] == "check":
        problems = check(pathlib.Path(argv[1]), pathlib.Path(argv[2]), pathlib.Path(argv[3]))
        for p in problems:
            print(p)
        sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main(sys.argv[1:])
