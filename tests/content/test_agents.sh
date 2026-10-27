#!/usr/bin/env bash
# tests/content/test_agents.sh — Agents in the launcher: herdr 0.9.5 (lib/upstream.sh) in a
# terminal window of its own. Its launcher entry (footclient with its own app-id and title,
# starting in ~/repos), its config read as herdr 0.9.5 reads it (only keys it knows, only
# colour names it knows — an unknown one is no error to herdr, just its cyan — and what it
# draws readable in foot's dark and light palettes), and, when this machine has the pinned
# herdr, the real one started as the entry starts it: on a terminal of its own, from ~/repos,
# with this config (its server up there, the window's side attached, Ctrl+B a starting
# Claude Code in the pane's folder, every word it draws 4.5:1 or more in both palettes).
. "$(dirname "$0")/lib.sh"
# the real herdr, as the caller's PATH has it (before the sandbox narrows PATH): the pinned one only
REAL_HERDR=$(command -v herdr 2>/dev/null)
[[ -n $REAL_HERDR && $("$REAL_HERDR" --version 2>/dev/null) == "herdr 0.9.5" ]] || REAL_HERDR=""
sandbox
FOOT=$REPO/configs/home/.config/foot/foot.ini
config .config/herdr/config.toml .local/share/applications/kawa-agents.desktop
CFG=$HOME/.config/herdr/config.toml
ENTRY=$HOME/.local/share/applications/kawa-agents.desktop

# ── the launcher entry ───────────────────────────────────────────────────────
case_ "kawa-agents.desktop: herdr in a footclient window of its own (app-id kawa-agents, titled Agents), started in ~/repos"
eq "$(sed -n 's/^Exec=//p' "$ENTRY")" "footclient -N -a kawa-agents -T Agents -D $HOME/repos -- herdr"
eq "$(sed -n 's/^Terminal=//p' "$ENTRY")" false "it opens its own window: no second terminal around it"
eq "$(sed -n 's/^Name=//p' "$ENTRY")" Agents
case_ "kawa-agents.desktop: ~/repos, where it starts, is a folder the Theme run makes"
has "$(cat "$REPO/theme.sh")" '"$TARGET_HOME/repos"'

# ── the config, as herdr 0.9.5 reads it ──────────────────────────────────────
# every key herdr 0.9.5 knows that this config may set (its config reference,
# docs/next/website/src/data/config-reference.json at v0.9.5; [[keys.command]]'s own keys:
# configuration.mdx, "Custom command keybindings")
KNOWN="onboarding update.version_check update.manifest_check update.channel theme.name
theme.auto_switch theme.dark_name theme.light_name theme.custom.accent theme.custom.panel_bg
theme.custom.sidebar_bg theme.custom.active_row_bg theme.custom.selection_bg theme.custom.surface0
theme.custom.surface1 theme.custom.surface_dim theme.custom.overlay0 theme.custom.overlay1
theme.custom.text theme.custom.subtext0 theme.custom.mauve theme.custom.green theme.custom.yellow
theme.custom.red theme.custom.blue theme.custom.teal theme.custom.peach ui.window_title
ui.sound.enabled ui.toast.delivery ui.toast.delay_seconds ui.hide_tab_bar_when_single_tab
ui.accent ui.sidebar_width ui.mouse_capture ui.pane_borders terminal.new_cwd
terminal.default_shell worktrees.directory keys.command.key keys.command.type
keys.command.command keys.command.description keys.command.width keys.command.height"
case_ "config.toml: TOML; every key one herdr 0.9.5 knows, each of its kind"
out=$(python3 -I - "$CFG" "$KNOWN" <<'EOF' 2>&1
import sys, tomllib
cfg = tomllib.load(open(sys.argv[1], "rb")); known = set(sys.argv[2].split())
def walk(d, pre=""):
    for k, v in d.items():
        p = pre + k
        if isinstance(v, dict): yield from walk(v, p + ".")
        elif isinstance(v, list) and v and all(isinstance(x, dict) for x in v):
            for x in v: yield from walk(x, p + ".")
        else: yield p, v
bad = [f"unknown key {k}" for k, _ in walk(cfg) if k not in known]
kinds = {"onboarding": bool, "update.version_check": bool, "update.manifest_check": bool,
         "ui.sound.enabled": bool, "ui.hide_tab_bar_when_single_tab": bool}
bad += [f"{k} is not a {t.__name__}" for k, v in walk(cfg) for kk, t in kinds.items() if k == kk and type(v) is not t]
d = cfg.get("ui", {}).get("toast", {}).get("delivery")
if d not in ("off", "herdr", "terminal", "system"): bad.append(f"ui.toast.delivery {d!r}")
for c in cfg.get("keys", {}).get("command", []):
    if c.get("type") not in ("shell", "pane", "popup", "plugin_action"): bad.append(f"keys.command type {c.get('type')!r}")
print("\n".join(bad))
EOF
)
eq "$out" ""
case_ "config.toml: pinned — herdr never asks herdr.dev for a newer herdr or newer agent rules; no first-run tour; no sound"
eq "$(python3 -I -c 'import sys, tomllib; c = tomllib.load(open(sys.argv[1], "rb")); print(c["update"]["version_check"], c["update"]["manifest_check"], c["onboarding"], c["ui"]["sound"]["enabled"])' "$CFG")" "False False False False"
case_ "config.toml: Ctrl+B a opens Claude Code in a pane; worktrees beside the projects (~/repos/worktrees)"
eq "$(python3 -I -c 'import sys, tomllib; c = tomllib.load(open(sys.argv[1], "rb")); k = c["keys"]["command"][0]; print(k["key"], k["type"], k["command"], c["worktrees"]["directory"])' "$CFG")" \
   "prefix+a pane claude ~/repos/worktrees"

# the colours: the terminal theme, and every override a colour name herdr knows (its names,
# and the palette entry each one draws with: what herdr 0.9.5 writes for it, measured)
case_ "config.toml: the terminal theme, every colour a name herdr knows (follows foot's palette; an unknown one would be its cyan)"
out=$(python3 -I - "$CFG" <<'EOF' 2>&1
import sys, tomllib
c = tomllib.load(open(sys.argv[1], "rb"))
NAMES = {"black", "red", "green", "yellow", "blue", "magenta", "cyan", "gray", "grey", "darkgray", "darkgrey",
         "lightred", "lightgreen", "lightyellow", "lightblue", "lightmagenta", "lightcyan", "white"}
bad = [] if c["theme"]["name"] == "terminal" else ["theme.name is not terminal"]
bad += [f"theme.custom.{k} = {v!r}" for k, v in c["theme"].get("custom", {}).items() if v not in NAMES]
print("\n".join(bad))
EOF
)
eq "$out" ""
case_ "config.toml: what herdr draws with these colours readable in foot's dark and light palettes — the mode badge (PREFIX, NAVIGATE) and the tab on the accent, the row you are on, the accent on the background: 4.5:1 or more"
out=$(python3 -I - "$CFG" "$FOOT" <<'EOF' 2>&1
import re, sys, tomllib
c = tomllib.load(open(sys.argv[1], "rb"))["theme"].get("custom", {}); ini = open(sys.argv[2]).read()
IDX = {"black": 0, "red": 1, "green": 2, "yellow": 3, "blue": 4, "magenta": 5, "cyan": 6, "gray": 7, "grey": 7,
       "darkgray": 8, "darkgrey": 8, "lightred": 9, "lightgreen": 10, "lightyellow": 11, "lightblue": 12,
       "lightmagenta": 13, "lightcyan": 14, "white": 15}
# herdr 0.9.5's terminal theme where this config sets nothing (measured: what it writes)
tok = {"accent": "cyan", "surface_dim": "darkgray", "active_row_bg": "darkgray"} | c
def lum(h):
    v = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    v = [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in v]
    return 0.2126 * v[0] + 0.7152 * v[1] + 0.0722 * v[2]
bad = []
for theme in ("dark", "light"):
    sec = re.search(r"^\[colors-%s\]\n(.*?)(?=^\[|\Z)" % theme, ini, re.M | re.S).group(1)
    kv = dict(re.findall(r"^(\w+)=([0-9a-fA-F]{6})", sec, re.M))
    pal = [kv["regular%d" % i] for i in range(8)] + [kv["bright%d" % i] for i in range(8)]
    col = lambda name: kv["foreground"] if name == "fg" else kv["background"] if name == "bg" else pal[IDX[tok[name] if name in tok else name]]
    for what, f, b in (("the mode badge / the tab you are on", "surface_dim", "accent"),
                       ("the accent on the background", "accent", "bg"),
                       ("the row you are on: its name", "fg", "active_row_bg"),
                       ("the row you are on: its mark", "gray", "active_row_bg")):
        lf, lb = lum(col(f)), lum(col(b)); r = (max(lf, lb) + 0.05) / (min(lf, lb) + 0.05)
        if r < 4.5: bad.append(f"{theme}: {what}: {r:.1f}:1")
print("\n".join(bad))
EOF
)
eq "$out" ""

# ── the real herdr, started as the entry starts it ───────────────────────────
if [[ -z $REAL_HERDR ]]; then
  skip "herdr 0.9.5 is not on this machine's PATH (the pinned release: lib/upstream.sh)"
else
  mkdir -p "$HOME/repos/project" "$TMP/bin"; ln -s "$REAL_HERDR" "$TMP/bin/herdr"
  # Claude Code: a stand-in that says where it was started, and stays (as Claude does)
  stub claude 'pwd >"$TMP/claude.cwd"; echo "stand-in Claude"; sleep 30'
  H_ENV=(env -i HOME="$HOME" PATH="$TMP/bin:$STUBS:/usr/bin:/bin" TMP="$TMP" CALLS="$CALLS" TERM=foot SHELL=/bin/sh LANG=C.UTF-8)
  on_exit '"${H_ENV[@]}" herdr server stop >/dev/null 2>&1'
  case_ "herdr 0.9.5 reads config.toml without a word (herdr config check)"
  out=$("${H_ENV[@]}" herdr config check 2>&1); r=$?
  eq "$r ${out,,}" "0 config: ok"
  case_ "herdr, started on a terminal of its own from ~/repos: its server up there, the window's side attached; Ctrl+B a starts Claude Code in the folder of the pane you are on"
  # (the shell in the first pane goes into a project; then Ctrl+B a; then Ctrl+B alone, so the
  # PREFIX badge is drawn too)
  (cd "$HOME/repos" && "${H_ENV[@]}" python3 -I "$REPO/tests/lib/pty_run.py" --cols 120 --rows 30 --timeout 12 \
     --send 3 'cd project\r' --send 4.5 '\x02' --send 5 'a' --send 7.5 '\x02' --hangup 9 -- herdr) \
    >"$TMP/herdr.out" 2>&1
  L=$HOME/.config/herdr
  has "$(cat "$L/herdr-client.log" 2>/dev/null)" "endpoint handshake succeeded" "the window's side never attached: $(tail -n 3 "$L/herdr-client.log" 2>/dev/null)"
  has "$(cat "$L/herdr-server.log" 2>/dev/null)" "created startup workspace cwd=$HOME/repos"
  eq "$(cat "$TMP/claude.cwd" 2>/dev/null)" "$HOME/repos/project" "Claude Code was not started in the pane's folder"
  case_ "herdr's window title: Agents · the workspace (the bar shows it)"
  has "$(cat "$TMP/herdr.out")" $'\e]0;Agents · repos'
  case_ "herdr, drawn with this config: every word 4.5:1 or more on its background, in foot's dark and light palettes (only its dividing lines are faint)"
  out=$(python3 -I - "$TMP/herdr.out" "$FOOT" <<'EOF' 2>&1
import re, sys
data = open(sys.argv[1], "rb").read().decode("utf-8", "replace"); ini = open(sys.argv[2]).read()
# what each piece of text was drawn with: the SGR state at each printable character
fg = bg = None; rev = False; pairs = {}; i = 0
SEQ = re.compile(r"\x1b(\[[0-?]*[ -/]*[@-~]|\][^\x07\x1b]*(\x07|\x1b\\)|[PX^_][^\x1b]*\x1b\\|[()][0-9A-Za-z]|.)")
while i < len(data):
    m = SEQ.match(data, i) if data[i] == "\x1b" else None
    if m:
        s = m.group(0); i = m.end()
        if s.startswith("\x1b[") and s.endswith("m") and "?" not in s and ">" not in s:
            ps = [int(p) if p else 0 for p in s[2:-1].split(";")] or [0]; j = 0
            while j < len(ps):
                p = ps[j]
                if p == 0: fg = bg = None; rev = False
                elif p == 7: rev = True
                elif p == 27: rev = False
                elif 30 <= p <= 37: fg = p - 30
                elif 90 <= p <= 97: fg = p - 82
                elif p == 39: fg = None
                elif 40 <= p <= 47: bg = p - 40
                elif 100 <= p <= 107: bg = p - 92
                elif p == 49: bg = None
                elif p in (38, 48):
                    if ps[j + 1] == 5: v = ps[j + 2]; j += 2
                    else: v = "#%02x%02x%02x" % tuple(ps[j + 2:j + 5]); j += 4
                    if p == 38: fg = v
                    else: bg = v
                j += 1
        continue
    ch = data[i]; i += 1
    if ch.isalnum():
        f, b = (bg, fg) if rev else (fg, bg)
        pairs.setdefault((f, b), set()).add(ch)
def lum(h):
    v = [int(h[k:k + 2], 16) / 255 for k in (0, 2, 4)]
    v = [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in v]
    return 0.2126 * v[0] + 0.7152 * v[1] + 0.0722 * v[2]
bad = []
for theme in ("dark", "light"):
    sec = re.search(r"^\[colors-%s\]\n(.*?)(?=^\[|\Z)" % theme, ini, re.M | re.S).group(1)
    kv = dict(re.findall(r"^(\w+)=([0-9a-fA-F]{6})", sec, re.M))
    pal = [kv["regular%d" % k] for k in range(8)] + [kv["bright%d" % k] for k in range(8)]
    def col(v, d):
        if v is None: return d
        if isinstance(v, str): return v[1:]
        if v < 16: return pal[v]
        bad.append(f"palette colour {v} (outside the 16: it does not follow the theme)"); return d
    for (f, b), chars in sorted(pairs.items(), key=str):
        if f is not None and f == b: continue        # (a cell drawn in its own background: a blank)
        lf, lb = lum(col(f, kv["foreground"])), lum(col(b, kv["background"]))
        r = (max(lf, lb) + 0.05) / (min(lf, lb) + 0.05)
        if r < 4.5: bad.append(f"{theme}: colour {f} on {b} ({''.join(sorted(chars))[:20]}): {r:.1f}:1")
print("\n".join(sorted(set(bad))) if pairs else "nothing drawn")
EOF
)
  eq "$out" ""
  "${H_ENV[@]}" herdr server stop >/dev/null 2>&1
fi

done_
