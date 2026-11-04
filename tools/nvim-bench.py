#!/usr/bin/env python3
"""tools/nvim-bench.py — Neovim as the desktop runs it, timed in a pseudo-terminal that answers as
foot does: to first output, to LazyVim's VeryLazy, to the last draw of the first full screen, to
its exit; each plugin's own load time; and each key's time to its redraw.

A pty that answers nothing is not a terminal: nvim waits 100 ms for the answer to its colour query
(DSR, vim/_core/defaults.lua: E1568), and 1 s at its exit for DA1, so a silent one measures its
own silence. `--silent` shows how much.

  python3 -B tools/nvim-bench.py sandbox DIR --config NAME=PATH… [--data PATH] [--link]
  python3 -B tools/nvim-bench.py start DIR --variants V… [--scenarios S,…] [--runs N] [--json F]
  python3 -B tools/nvim-bench.py keys  DIR --variants V… [--scenarios S,…] [--runs N] [--json F]
  python3 -B tools/nvim-bench.py first DIR --variants V… [--runs N] [--json F]
  python3 -B tools/nvim-bench.py check DIR --variants V     never again: what must hold, said line
                                                           by line (tools/regress/nvim-start.sh)

A sandbox holds a whole home: DIR/data is a reflink copy of nvim's data (the plugins, Mason's
tools, the parsers: read, and maybe written, by what runs here; never the real one), each config
under DIR/configs/NAME with its state and cache beside it. Everything runs in a PID namespace of
its own with no display, no D-Bus and no real home in its environment: no clipboard, no notice,
no journal line of the owner's is reachable, and nothing outlives the run.

A variant is NAME or NAME-off:PART+PART…: that config with those parts off, through the sandbox's
lua/plugins/zz_bench.lua — a plugin (its name as lazy.nvim knows it), snacks:scroll, ts:folds,
lsp:inlay_hints, g:trouble_lualine, o:cursorline. Runs are interleaved, variant by variant in a new
random order each round, so a busy moment hits them all alike.

Scenarios — start: dash (nvim alone) · py · md · sh · lua · rs · commit (git's message) ·
txt; keys: py (with its server) · md · big (20,000 lines of Python, no server waited for).
Exit 0 · 1 a run timed out · 2 misuse.
"""
import fcntl
import json
import os
import pty
import random
import re
import select
import shutil
import signal
import statistics
import struct
import subprocess
import sys
import tempfile
import termios
import time

REAL_HOME = os.path.expanduser("~")
SIZE = (180, 50)  # a whole screen's window: cols, rows (byte counts and redraw cost scale with it)

# ── a terminal that answers as foot 1.27 does ────────────────────────────────────────────────
BG = b"rgb:1818/1717/1515"  # the dark ground of the desktop's foot
FG = b"rgb:e8e8/e0e0/d0d0"
FIXED = (
    (b"\x1b[5n", b"\x1b[0n"),                     # DSR: nvim's colour query waits on this
    (b"\x1b[c", b"\x1b[?62;22c"),                 # DA1 (nvim waits at its exit)
    (b"\x1b[0c", b"\x1b[?62;22c"),
    (b"\x1b[>c", b"\x1b[>1;12700;0c"),            # DA2
    (b"\x1b[>0q", b"\x1bP>|foot(1.27.0)\x1b\\"),  # XTVERSION
    (b"\x1b[>q", b"\x1bP>|foot(1.27.0)\x1b\\"),
    (b"\x1b[?u", b"\x1b[?0u"),                    # the kitty keyboard's flags
    (b"\x1b[6n", b"\x1b[1;1R"),                   # CPR
    (b"\x1b]11;?\x07", b"\x1b]11;" + BG + b"\x07"),
    (b"\x1b]11;?\x1b\\", b"\x1b]11;" + BG + b"\x1b\\"),
    (b"\x1b]10;?\x07", b"\x1b]10;" + FG + b"\x07"),
    (b"\x1b]10;?\x1b\\", b"\x1b]10;" + FG + b"\x1b\\"),
)
DECRQM = re.compile(rb"\x1b\[\?(\d+)\$p")
XTGETTCAP = re.compile(rb"\x1bP\+q([0-9a-fA-F;]+)\x1b\\")
TCAP_YES = {b"Tc": b"", b"RGB": b"8", b"setrgbf": b"\x1b[38:2::%p1%d:%p2%d:%p3%dm",
            b"setrgbb": b"\x1b[48:2::%p1%d:%p2%d:%p3%dm"}
SYNC_END = b"\x1b[?2026l"
# what is not drawing: the terminal's own sequences, spaces (a query or a mode set is no redraw)
CONTROL = re.compile(rb"\x1b\[[0-9;:?<>= $]*[a-zA-Z~]|\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)|\x1bP[^\x1b]*\x1b\\|\x1b[=>()][0-9A-Z]?|[\s\x08]+")


def answers(data):
    out = b""
    for q, a in FIXED:
        if q in data:
            out += a * data.count(q)
    for m in DECRQM.finditer(data):
        out += b"\x1b[?" + m.group(1) + b";2$y"
    for m in XTGETTCAP.finditer(data):
        for cap in m.group(1).split(b";"):
            name = bytes.fromhex(cap.decode())
            if name in TCAP_YES:
                out += b"\x1bP1+r" + cap + b"=" + TCAP_YES[name].hex().encode() + b"\x1b\\"
            else:
                out += b"\x1bP0+r" + cap + b"\x1b\\"
    return out


class Term:
    """One program in a pty: every read timestamped, its queries answered."""

    def __init__(self, argv, env, size=SIZE, silent=False, raw=None, cwd=None, marker=None):
        self.silent, self.raw, self.marker = silent, raw, marker
        self.painted = None  # ns of the first read showing the marker: the text on the screen
        self.t0 = time.monotonic_ns()
        self.pid, self.fd = pty.fork()
        if self.pid == 0:
            try:
                if cwd:
                    os.chdir(cwd)
                os.execvpe(argv[0], argv, env)
            except OSError:
                os._exit(127)
        fcntl.ioctl(self.fd, termios.TIOCSWINSZ, struct.pack("HHHH", size[1], size[0], 0, 0))
        self.reads = []  # (ns since t0, bytes)
        self.draws = []  # ns since t0 of the reads that put text on the screen
        self.frames = 0  # flushes that drew text: nvim wraps each in a synchronized update, one frame on foot
        self.eof = False
        self.cpu_ms = None

    def pump(self, wait_s):
        """One read, waiting at most wait_s. True if something came."""
        if self.eof:
            return False
        r, _, _ = select.select([self.fd], [], [], max(0.0, wait_s))
        if not r:
            return False
        try:
            data = os.read(self.fd, 1 << 16)
        except OSError:
            data = b""
        if not data:
            self.eof = True
            return False
        now = time.monotonic_ns() - self.t0
        self.reads.append((now, len(data)))
        for flush in data.split(SYNC_END)[:-1]:   # (a flush with text in it: one that only set the cursor's shape draws nothing)
            if CONTROL.sub(b"", flush):
                self.frames += 1
        if CONTROL.sub(b"", data):
            self.draws.append(now)
        if self.marker and self.painted is None and self.marker in data:
            self.painted = now
        if self.raw is not None:
            self.raw.append((now, data))
        if not self.silent:
            a = answers(data)
            if a:
                os.write(self.fd, a)
        return True

    def send(self, keys):
        os.write(self.fd, keys)
        return time.monotonic_ns() - self.t0

    def now(self):
        return time.monotonic_ns() - self.t0

    def pss_kb(self):
        """Proportional memory of the TUI and its --embed server together."""
        total = 0
        pids = [self.pid]
        try:
            with open(f"/proc/{self.pid}/task/{self.pid}/children") as f:
                pids += [int(p) for p in f.read().split()]
        except OSError:
            pass
        for p in pids:
            try:
                with open(f"/proc/{p}/smaps_rollup") as f:
                    for line in f:
                        if line.startswith("Pss:"):
                            total += int(line.split()[1])
                            break
            except OSError:
                pass
        return total

    def close(self):
        """Ends this program's whole session (its own pid and group: nothing computed)."""
        if self.pid:
            try:
                os.killpg(self.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            try:
                ru = os.wait4(self.pid, 0)[2]
                self.cpu_ms = (ru.ru_utime + ru.ru_stime) * 1000  # (with what it waited for: the server)
            except ChildProcessError:
                pass
            self.pid = None
        try:
            os.close(self.fd)
        except OSError:
            pass


# ── the sandbox ───────────────────────────────────────────────────────────────────────────────
ZZ_BENCH = """-- tools/nvim-bench.py: its variants' parts off (never shipped)
local spec = {}
for name in (os.getenv("KAWA_BENCH_OFF") or ""):gmatch("[^+]+") do
  local kind, what = name:match("^(%w+):(.+)$")
  if kind == "snacks" then         -- a part of snacks.nvim
    spec[#spec + 1] = { "folke/snacks.nvim", opts = { [what] = { enabled = false } } }
  elseif kind == "ts" then         -- a part of the treesitter setup: folds, indent
    spec[#spec + 1] = { "nvim-treesitter/nvim-treesitter", opts = { [what] = { enable = false } } }
  elseif kind == "lsp" then        -- a part of the LSP setup: folds, inlay_hints
    spec[#spec + 1] = { "neovim/nvim-lspconfig", opts = { [what] = { enabled = false } } }
  elseif kind == "g" then          -- a global off: trouble_lualine, snacks_animate
    vim.g[what] = false
  elseif kind == "o" then          -- an option off: cursorline, relativenumber
    vim.api.nvim_create_autocmd("User", { pattern = "VeryLazy", once = true, callback = function() vim.o[what] = false end })
  else
    spec[#spec + 1] = { name, enabled = false }
  end
end
return spec
"""

HOOK = r"""-- tools/nvim-bench.py: the marks, in CLOCK_MONOTONIC (Python's monotonic_ns; hrtime's own)
local marks = { cmd = vim.uv.hrtime() }
local function mark(n) marks[n] = marks[n] or vim.uv.hrtime() end
for _, ev in ipairs({ "VimEnter", "UIEnter" }) do
  vim.api.nvim_create_autocmd(ev, { once = true, callback = function() mark(ev) end })
end
vim.api.nvim_create_autocmd("User", { pattern = "LazyDone", once = true, callback = function() mark("LazyDone") end })
vim.api.nvim_create_autocmd("LspAttach", { once = true, callback = function() mark("LspAttach") end })
vim.api.nvim_create_autocmd("DiagnosticChanged", { once = true, callback = function() mark("Diagnostic") end })
local function dump()
  local out = { marks = marks, plugins = {}, loaded_modules = 0, errors = {} }
  local ok, cfg = pcall(require, "lazy.core.config")
  if ok then
    for name, p in pairs(cfg.plugins) do
      local l = p._ and p._.loaded
      out.plugins[name] = l and { ms = (l.time or 0) / 1e6, by = l.start or l.event or l.ft or l.keys or l.cmd or l.plugin or l.require or l.import or "?" } or false
    end
    out.stats = require("lazy").stats()
    out.stats.times = nil
  end
  for _ in pairs(package.loaded) do out.loaded_modules = out.loaded_modules + 1 end
  out.messages = vim.api.nvim_exec2("messages", { output = true }).output
  out.clients = vim.tbl_map(function(c) return c.name end, vim.lsp.get_clients())
  out.ft = vim.bo.filetype
  local f = io.open(os.getenv("KAWA_BENCH_OUT"), "w")
  if f then f:write(vim.json.encode(out)); f:close() end
  if os.getenv("KAWA_BENCH_QUIT") then vim.cmd("qa!") end  -- (a real foot in the kit: no keys there)
end
local function very_lazy()
  mark("VeryLazy")
  vim.schedule(function() mark("VeryLazyDone"); vim.defer_fn(dump, tonumber(os.getenv("KAWA_BENCH_DUMP_MS") or 250)) end)
end
vim.api.nvim_create_autocmd("User", { pattern = "VeryLazy", once = true, callback = very_lazy })
"""

SAMPLE_PY_HEAD = '''"""Orders: a small shop's arithmetic, long enough to look like work."""
from __future__ import annotations

import dataclasses
import json
import math
from pathlib import Path


@dataclasses.dataclass
class Item:
    name: str
    price: float
    count: int = 1

    def total(self) -> float:
        return round(self.price * self.count, 2)

'''
SAMPLE_PY_UNIT = '''
def compute_{n}(items: list[Item], rate: float = 0.{d}) -> float:
    """The total of {n}: items, a discount over a hundred, the tax."""
    subtotal = sum(item.total() for item in items)
    discount = 0.1 if subtotal > 100 else 0.0
    # TODO: a real discount table for {n}
    for item in items:
        if item.count > 10 and item.price < math.pi * {d}:
            subtotal -= item.price * 0.5
    return round(subtotal * (1 - discount) * (1 + rate), 2)


class Report{n}:
    """Prints order {n} as a table and as JSON."""

    def __init__(self, items: list[Item], path: Path | None = None) -> None:
        self.items = items
        self.path = path or Path("report-{n}.json")

    def rows(self) -> list[str]:
        return [f"{{i.name:<20}} {{i.count:>4}} {{i.total():>9.2f}}" for i in self.items]

    def save(self) -> None:
        data = [dataclasses.asdict(i) for i in self.items]
        self.path.write_text(json.dumps(data, indent=2))

'''
SAMPLE_MD = """# The notebook

Some prose, as a person writes it: a paragraph that runs on for a while, with a [link](https://example.org)
and a little `code` in it, then **bold** words. Lines this long are the ones soft wrapping changes.

## A list

- first, with a few words
- second, with a few more words than the first one has
- third

```python
def f(x):
    return x * 2
```

"""
SAMPLE_RS = """fn total(items: &[(f64, u32)]) -> f64 {
    items.iter().map(|(p, c)| p * f64::from(*c)).sum()
}

fn main() {
    let items = vec![(1.5, 2), (2.25, 4)];
    println!("{}", total(&items));
}
"""
SAMPLE_LUA = """local M = {}

function M.total(items)
  local sum = 0
  for _, item in ipairs(items) do
    sum = sum + item.price * item.count
  end
  return sum
end

return M
"""
SAMPLE_SH = """#!/bin/bash
set -euo pipefail
for f in "$@"; do
  [[ -f $f ]] || continue
  wc -l -- "$f"
done
"""
SAMPLE_COMMIT = """

# Please enter the commit message for your changes. Lines starting
# with '#' will be ignored, and an empty message aborts the commit.
#
# On branch main
# Changes to be committed:
#	modified:   setup.sh
#
"""


def build_samples(root):
    w = os.path.join(root, "work")
    os.makedirs(w, exist_ok=True)
    py = SAMPLE_PY_HEAD + "".join(SAMPLE_PY_UNIT.format(n=n, d=(n % 9) + 1) for n in range(60))
    big = SAMPLE_PY_HEAD + "".join(SAMPLE_PY_UNIT.format(n=n, d=(n % 9) + 1) for n in range(800))
    files = {"sample.py": py, "big.py": big, "sample.md": SAMPLE_MD * 20, "notes.txt": SAMPLE_MD * 5,
             "sample.lua": SAMPLE_LUA, "sample.sh": SAMPLE_SH, "COMMIT_EDITMSG": SAMPLE_COMMIT,
             "pyproject.toml": '[project]\nname = "orders"\nversion = "0.1.0"\nrequires-python = ">=3.12"\n'}
    for name, text in files.items():
        with open(os.path.join(w, name), "w") as f:
            f.write(text)
    rs = os.path.join(root, "work-rs")
    os.makedirs(rs + "/src", exist_ok=True)
    with open(rs + "/Cargo.toml", "w") as f:
        f.write('[package]\nname = "orders"\nversion = "0.1.0"\nedition = "2021"\n')
    with open(rs + "/src/main.rs", "w") as f:
        f.write(SAMPLE_RS)
    for d in (w, rs):
        if not os.path.isdir(d + "/.git"):
            subprocess.run(["git", "init", "-q", d], check=True,
                           env={"PATH": "/usr/bin", "GIT_CONFIG_GLOBAL": "/dev/null", "GIT_CONFIG_SYSTEM": "/dev/null"})
            git = ["git", "-c", "user.name=bench", "-c", "user.email=bench@localhost", "-C", d]
            subprocess.run(git + ["add", "-A"], check=True, env={"PATH": "/usr/bin", "GIT_CONFIG_GLOBAL": "/dev/null"})
            subprocess.run(git + ["commit", "-qm", "base"], check=True, env={"PATH": "/usr/bin", "GIT_CONFIG_GLOBAL": "/dev/null"})


def add_config(root, name, path):
    """A config under test: copied whole, the bench's plugin file and init beside it."""
    d = os.path.join(root, "configs", name, "nvim")
    if os.path.isdir(d):
        shutil.rmtree(d)
    shutil.copytree(path, d)
    with open(d + "/lua/plugins/zz_bench.lua", "w") as f:
        f.write(ZZ_BENCH)


def cmd_sandbox(args):
    root = args["dir"]
    os.makedirs(root + "/run", mode=0o700, exist_ok=True)
    data = root + "/data/nvim"
    if not os.path.isdir(data):
        os.makedirs(root + "/data", exist_ok=True)
        src = args.get("data") or REAL_HOME + "/.local/share/nvim"
        if "link" in args:   # (the never-again check: read, never written — a config at the lock's commits installs nothing)
            os.symlink(src, data)
        else:
            subprocess.run(["cp", "-a", "--reflink=always", src, data], check=True)
    with open(root + "/hook.lua", "w") as f:
        f.write(HOOK)
    build_samples(root)
    for spec in args.get("config", []):
        name, _, path = spec.partition("=")
        add_config(root, name, path)
    return 0


def environ(root, config, off):
    home = f"{root}/configs/{config}/home"
    for d in ("", "/state", "/cache"):
        os.makedirs(home + d, exist_ok=True)
    return {
        "HOME": home, "XDG_CONFIG_HOME": f"{root}/configs/{config}", "XDG_DATA_HOME": f"{root}/data",
        "XDG_STATE_HOME": home + "/state", "XDG_CACHE_HOME": home + "/cache", "XDG_RUNTIME_DIR": f"{root}/run",
        "PATH": f"{REAL_HOME}/.local/bin:{REAL_HOME}/.local/share/cargo/bin:/usr/local/bin:/usr/bin",
        "CARGO_HOME": f"{REAL_HOME}/.local/share/cargo", "RUSTUP_HOME": f"{REAL_HOME}/.local/share/rustup",
        "TERM": "foot", "COLORTERM": "truecolor", "LANG": os.environ.get("LANG", "C.UTF-8"),
        "KAWA_BENCH_OFF": off, "KAWA_BENCH_OUT": f"{root}/run/out-{os.getppid()}-{os.getpid()}.json",
    }


def parse_variant(v):
    name, _, off = v.partition("-off:")
    return name, off


def nvim_argv(root, files):
    return ["nvim", "--cmd", f"luafile {root}/hook.lua"] + files


def scenario(root, s):
    """(files, cwd, a word only its first paint shows) of a start scenario."""
    w = root + "/work"
    return {
        "dash": ([], w, b"editor"), "py": (["sample.py"], w, b"arithmetic"), "md": (["sample.md"], w, b"prose"),
        "txt": (["notes.txt"], w, b"prose"), "sh": (["sample.sh"], w, b"pipefail"), "lua": (["sample.lua"], w, b"ipairs"),
        "commit": (["COMMIT_EDITMSG"], w, b"ignored"), "rs": (["src/main.rs"], root + "/work-rs", b"total"),
        "big": (["big.py"], w, b"arithmetic"),
    }[s]


# ── start ─────────────────────────────────────────────────────────────────────────────────────
def one_start(root, variant, s, silent=False, timeout=15.0, raw=None, dump_ms=250):
    config, off = parse_variant(variant)
    env = environ(root, config, off)
    env["KAWA_BENCH_DUMP_MS"] = str(dump_ms)
    out = env["KAWA_BENCH_OUT"]
    if os.path.exists(out):
        os.remove(out)
    files, cwd, marker = scenario(root, s)
    t = Term(nvim_argv(root, files), env, silent=silent, raw=raw, cwd=cwd, marker=marker)
    deadline = time.monotonic() + timeout
    res = {"timed_out": False}
    # until the bench's dump exists and the screen has been quiet a while
    while True:
        came = t.pump(0.01)
        now = t.now()
        if t.eof:
            break
        if time.monotonic() > deadline:
            res["timed_out"] = True
            break
        if not came and os.path.exists(out) and t.reads and now - t.reads[-1][0] > 150e6:
            break
    res["pss_kb"] = t.pss_kb()
    dump = {}
    try:
        with open(out) as f:
            dump = json.load(f)
    except (OSError, ValueError):
        pass
    marks = {k: (v - t.t0) / 1e6 for k, v in dump.get("marks", {}).items()}
    res["marks"] = marks
    res["first_ms"] = t.reads[0][0] / 1e6 if t.reads else None
    res["paint_ms"] = t.painted / 1e6 if t.painted else None
    done = marks.get("VeryLazyDone")
    if done is not None:
        # the first full screen: the last draw before the first quiet 60 ms after VeryLazy's work
        last = done
        for at in t.draws:
            ms = at / 1e6
            if ms < done:
                continue
            if ms - last > 60:
                break
            last = ms
        res["ready_ms"] = last
    res["bytes"] = sum(n for _, n in t.reads)
    res["plugins"] = dump.get("plugins", {})
    res["modules"] = dump.get("loaded_modules")
    res["messages"] = dump.get("messages", "")
    res["clients"] = dump.get("clients", [])
    res["ft"] = dump.get("ft")
    # its exit: Esc, :qa!, to the pty's end
    if not t.eof:
        at = t.send(b"\x1b:qa!\r")
        q_deadline = time.monotonic() + 5
        while not t.eof and time.monotonic() < q_deadline:
            t.pump(0.05)
        res["quit_ms"] = (t.now() - at) / 1e6 if t.eof else None
    t.close()
    res["cpu_ms"] = t.cpu_ms
    return res


def med(values):
    v = [x for x in values if x is not None]
    return round(statistics.median(v), 1) if v else None


def pct(values, q):
    v = sorted(values)
    if not v:
        return None
    return round(v[min(len(v) - 1, int(q * len(v)))], 2)


def cmd_start(args):
    root = args["dir"]
    variants, scenarios, runs = args["variants"], args.get("scenarios", ["dash"]), int(args.get("runs", 10))
    res = {v: {s: [] for s in scenarios} for v in variants}
    rc = 0
    for v in variants:      # one run each first: the bytecode cache and the state files settled
        for s in scenarios:
            one_start(root, v, s)
    order = [(v, s) for v in variants for s in scenarios]
    for _ in range(runs):
        random.shuffle(order)
        for v, s in order:
            r = one_start(root, v, s, silent="silent" in args)
            rc |= 1 if r["timed_out"] else 0
            res[v][s].append(r)
    table = {}
    for v in variants:
        for s in scenarios:
            rs = res[v][s]
            table[f"{v}|{s}"] = {
                "first": med(r["first_ms"] for r in rs), "ui": med(r["marks"].get("UIEnter") for r in rs),
                "paint": med(r.get("paint_ms") for r in rs), "cpu": med(r.get("cpu_ms") for r in rs),
                "vl": med(r["marks"].get("VeryLazy") for r in rs), "vl_done": med(r["marks"].get("VeryLazyDone") for r in rs),
                "ready": med(r.get("ready_ms") for r in rs), "quit": med(r.get("quit_ms") for r in rs),
                "pss_mb": round((med(r["pss_kb"] for r in rs) or 0) / 1024, 1), "modules": med(r["modules"] for r in rs),
            }
    if "json" in args:
        with open(args["json"], "w") as f:
            json.dump({"table": table, "runs": res}, f)
    for k, row in table.items():
        print(f"{k:<28} paint {row['paint']!s:>6} · UIEnter {row['ui']!s:>6} · VeryLazy {row['vl']!s:>6} · done {row['vl_done']!s:>6} · ready {row['ready']!s:>6} · quit {row['quit']!s:>6} · CPU {row['cpu']!s:>6} · PSS {row['pss_mb']!s:>6} MB · mods {row['modules']}")
    return rc


# ── keys ──────────────────────────────────────────────────────────────────────────────────────
TYPED = (
    "def price_after_tax(items, tax_rate=0.2):\n"
    "subtotal = sum(item.total() for item in items)\n"
    "discount = 0.1 if subtotal > 100 else 0\n"
    "return round(subtotal * (1 - discount) * (1 + tax_rate), 2)\n\n"
    "class Basket:\n"
    "def __init__(self, items):\n"
    "self.items = items\n"
)
PROSE = (
    "Some more words typed the way a person types them, one after the other, with commas, "
    "and a sentence that goes on until the line is long enough to wrap at the window's edge. "
)


def press(t, keys, quiet_ms, gap_ms, cap_ms=500):
    """One key: the times to its first byte and to the last before quiet_ms of silence."""
    at = t.send(keys)
    first = last = None
    n = 0
    frames = t.frames
    while True:
        now = t.now()
        wait = cap_ms / 1000 - (now - at) / 1e9
        if wait <= 0:
            break
        if last is not None:
            wait = min(wait, quiet_ms / 1000 - (now - last) / 1e9)
            if wait <= 0:
                break
        before = len(t.reads)
        t.pump(wait)
        for got, b in t.reads[before:]:
            first = got if first is None else first
            last = got
            n += b
        if t.eof:
            break
    # the keys' pace: the next key when a person's would come
    rest = gap_ms / 1000 - (t.now() - at) / 1e9
    last_any = None
    if rest > 0:
        end = time.monotonic() + rest
        before = len(t.reads)
        while time.monotonic() < end:
            t.pump(end - time.monotonic())
        for got, b in t.reads[before:]:    # (a late second draw: a statusline on its own timer)
            last_any = got
            n += b
    return {"first": None if first is None else (first - at) / 1e6,
            "last": None if last is None else (last - at) / 1e6,
            "tail": None if last_any is None else (last_any - at) / 1e6, "bytes": n, "frames": t.frames - frames}


def wait_ready(t, env, timeout=20.0, extra_ms=0):
    deadline = time.monotonic() + timeout
    out = env["KAWA_BENCH_OUT"]
    while time.monotonic() < deadline:
        came = t.pump(0.01)
        if not came and os.path.exists(out) and t.reads and t.now() - t.reads[-1][0] > 150e6:
            break
    end = time.monotonic() + extra_ms / 1000
    while time.monotonic() < end:
        t.pump(end - time.monotonic())


ESC = b"\x1b[27u"  # (the kitty keyboard's: foot's answer to nvim's CSI > 1 u, no wait for a sequence)
CTRL_D, CTRL_U = b"\x1b[100;5u", b"\x1b[117;5u"


def keys_script(s):
    """What a person does, key by key: (label or None, keys, quiet ms, gap ms). A label's keys are
    counted together; None sets the next phase up."""
    out = []
    for _ in range(50):
        out.append(("j", b"j", 6, 33))
    for _ in range(50):
        out.append(("k", b"k", 6, 33))
    for _ in range(10):
        out += [("i (insert)", b"i", 8, 150), ("Esc from insert", ESC, 8, 150)]
    out += [(None, b"G", 10, 60), (None, b"o", 10, 60)]
    text = PROSE if s == "md" else TYPED
    what = "type prose" if s == "md" else "type code"
    out += [(what, (b"\r" if c == "\n" else c.encode()), 6, 90) for c in text]
    out += [(None, ESC, 8, 200), (None, b"gg", 10, 60)]
    for _ in range(10):
        out += [(": opens", b":", 8, 120), ("Esc from :", ESC, 8, 120)]
    if s != "md":
        for _ in range(5):
            out += [("/ opens", b"/", 8, 120), ("Esc from /", ESC, 8, 120)]
    for _ in range(6):
        out += [("Ctrl+D", CTRL_D, 50, 600), ("Ctrl+U", CTRL_U, 50, 600)]
    return out


def one_keys(root, variant, s):
    config, off = parse_variant(variant)
    env = environ(root, config, off)
    if os.path.exists(env["KAWA_BENCH_OUT"]):
        os.remove(env["KAWA_BENCH_OUT"])
    files = {"py": ["sample.py"], "md": ["sample.md"], "big": ["big.py"]}[s]
    t = Term(nvim_argv(root, files), env, cwd=root + "/work")
    wait_ready(t, env, extra_ms=4000 if s == "py" else 500)  # (its server up and through the file)
    res = {}
    for label, keys, quiet, gap in keys_script(s):
        r = press(t, keys, quiet, gap)
        if label:
            res.setdefault(label, []).append(r)
    t.close()
    return res


def cmd_keys(args):
    root = args["dir"]
    variants, scenarios, runs = args["variants"], args.get("scenarios", ["py"]), int(args.get("runs", 3))
    res = {v: {s: [] for s in scenarios} for v in variants}
    order = [(v, s) for v in variants for s in scenarios]
    for _ in range(runs):
        random.shuffle(order)
        for v, s in order:
            res[v][s].append(one_keys(root, v, s))
    table = {}
    for v in variants:
        for s in scenarios:
            labels = res[v][s][0].keys()
            for label in labels:
                ps = [p for r in res[v][s] for p in r[label]]
                first = [p["first"] for p in ps if p["first"] is not None]
                last = [p["last"] for p in ps if p["last"] is not None]
                table[f"{v}|{s}|{label}"] = {
                    "first_p50": pct(first, 0.5), "first_p95": pct(first, 0.95), "last_p50": pct(last, 0.5),
                    "last_p95": pct(last, 0.95), "last_max": max(last) if last else None,
                    "tail_share": round(sum(1 for p in ps if p["tail"] is not None) / len(ps), 2),
                    "tail_p50": pct([p["tail"] for p in ps if p["tail"] is not None], 0.5),
                    "bytes_p50": pct([p["bytes"] for p in ps], 0.5), "frames_p50": pct([p["frames"] for p in ps], 0.5),
                    "frames_max": max(p["frames"] for p in ps), "n": len(ps), "drawn": len(last),
                }
    for k, row in table.items():
        print(f"{k:<46} first p50 {row['first_p50']:>7} p95 {row['first_p95']:>7} · last p50 {row['last_p50']:>7} p95 {row['last_p95']:>7} max {round(row['last_max'] or 0, 1):>7} · late {row['tail_share']:>4} at {row['tail_p50']} · bytes {row['bytes_p50']:>7} · frames {row['frames_p50']} (max {row['frames_max']})")
    if "json" in args:
        with open(args["json"], "w") as f:
            json.dump({"table": table}, f)
    return 0


# ── first use: what a lazy load makes the first press pay ─────────────────────────────────────
FIRST = (
    ("Space Space (files)", [], b"  "),
    ("Space / (grep)", [], b" /"),
    ("Space e (tree)", [], b" e"),
    ("s (flash)", ["sample.py"], b"sco"),
    ("Space, its menu (which-key)", ["sample.py"], b" "),
    (": (cmdline)", ["sample.py"], b":"),
    ("i, then a letter (completion)", ["sample.py"], b"Gosu"),
    ("g c c (comment)", ["sample.py"], b"ggjgcc"),
    ("L (the next file)", ["sample.py", "sample.md"], b"L"),
    ("] f (next function)", ["sample.py"], b"]f"),
    ("( (the closing one)", ["sample.py"], b"Go("),
)


def cmd_first(args):
    root = args["dir"]
    variants, runs = args["variants"], int(args.get("runs", 5))
    res = {}
    for _ in range(runs):
        for v in random.sample(variants, len(variants)):
            for label, files, keys in FIRST:
                config, off = parse_variant(v)
                env = environ(root, config, off)
                if os.path.exists(env["KAWA_BENCH_OUT"]):
                    os.remove(env["KAWA_BENCH_OUT"])
                t = Term(nvim_argv(root, files), env, cwd=root + "/work")
                wait_ready(t, env, extra_ms=1200)   # (a person's first key, not one racing the start)
                r = press(t, keys, 300, 0, cap_ms=1500)
                res.setdefault(f"{v}|{label}", []).append(r)
                t.close()
    table = {}
    for k, rs in res.items():
        table[k] = {"first": med(r["first"] for r in rs), "last": med(r["last"] for r in rs)}
        print(f"{k:<52} first {table[k]['first']:>7} · last {table[k]['last']:>7}")
    if "json" in args:
        with open(args["json"], "w") as f:
            json.dump(table, f)
    return 0


# ── never again ───────────────────────────────────────────────────────────────────────────────
def frames_of(raw):
    """What each flush drew: the output cut at the synchronized updates' ends."""
    return b"".join(d for _, d in raw).split(SYNC_END)


def cmd_check(args):
    root, variant = args["dir"], args["variants"][0]
    bad = []

    def say(ok, words):
        print(("✔ " if ok else "✘ ") + words)
        if not ok:
            bad.append(words)

    one_start(root, variant, "dash")   # (the bytecode cache and the state settled)
    raw = []
    r = one_start(root, variant, "dash", raw=raw)
    n = sum(1 for f in frames_of(raw) if b"editor" in f)
    say(n == 1, f"the first screen is drawn once, not again when the plugins come ({n})")
    say(r["messages"] == "", f"a start says nothing: {r['messages'][:60]!r}")
    say(not any(r["plugins"].get(p) for p in ("nvim-lspconfig", "mason.nvim", "gitsigns.nvim")),
        "the first screen loads no server, no Mason, no git")
    raw = []
    r = one_start(root, variant, "txt", raw=raw)
    fr = frames_of(raw)
    text = next((i for i, f in enumerate(fr) if b"prose" in f), -1)
    line = next((i for i, f in enumerate(fr) if b"NORMAL" in f), -2)
    say(text == line, f"a file's first frame has its status line ({text}, {line})")
    say(not any(r["plugins"].get(p) for p in ("nvim-lspconfig", "mason.nvim")),
        "a text file loads no server and no Mason")
    r = one_start(root, variant, "py", dump_ms=4000)
    say(sorted(r["clients"]) == ["basedpyright", "ruff"], f"a Python file has its servers ({r['clients']})")
    # the keys
    config, off = parse_variant(variant)
    env = environ(root, config, off)
    if os.path.exists(env["KAWA_BENCH_OUT"]):
        os.remove(env["KAWA_BENCH_OUT"])
    t = Term(nvim_argv(root, ["sample.py"]), env, cwd=root + "/work")
    wait_ready(t, env, extra_ms=1500)
    moves = [press(t, b"j", 6, 60) for _ in range(30)]
    late = sum(1 for m in moves if m["frames"] > 1)
    say(late <= 10, f"a key's frame is its only one: no second draw on a timer ({late} of 30 keys had one, crossing into a block)")
    p = press(t, CTRL_D, 50, 600)
    say(p["frames"] <= 4 and (p["last"] or 0) < 150, f"Ctrl+D lands at once: {p['frames']} frames, {round(p['last'] or 0)} ms")
    p = press(t, b":", 8, 200)
    say(p["bytes"] < 2000, f"the command line opens on its row, the text above not drawn again ({p['bytes']} bytes)")
    press(t, ESC, 8, 200)
    t.close()
    # the Learn book's first exercise
    env = environ(root, config, off)
    if os.path.exists(env["KAWA_BENCH_OUT"]):
        os.remove(env["KAWA_BENCH_OUT"])
    t = Term(nvim_argv(root, ["+Tutor"]), env, cwd=root + "/work")
    wait_ready(t, env, extra_ms=100)
    t.close()
    try:
        with open(env["KAWA_BENCH_OUT"]) as f:
            ft = json.load(f).get("ft")
    except (OSError, ValueError):
        ft = None
    say(ft == "tutor", f"nvim +Tutor opens the tutor ({ft})")
    print(f"nvim: {'all held' if not bad else str(len(bad)) + ' broken'}")
    return 1 if bad else 0


def main(argv):
    if len(argv) < 3 or argv[1] not in ("sandbox", "start", "keys", "first", "check"):
        print(__doc__.strip())
        return 0 if len(argv) > 1 and argv[1] in ("-h", "--help") else 2
    if not os.environ.get("NVIM_BENCH_FENCED"):
        # a PID namespace of its own: nothing outlives the run, and nothing else can be signalled
        os.environ["NVIM_BENCH_FENCED"] = "1"
        for var in ("WAYLAND_DISPLAY", "DISPLAY", "DBUS_SESSION_BUS_ADDRESS"):
            os.environ.pop(var, None)
        os.execvp("unshare", ["unshare", "--user", "--map-current-user", "--pid", "--fork", "--mount-proc",
                              "--kill-child", sys.executable, "-B", *argv])
    args = {"dir": os.path.abspath(argv[2])}
    multi = {"--config": "config", "--variants": "variants"}
    i = 3
    while i < len(argv):
        a = argv[i]
        if a in multi:
            args[multi[a]] = []
            i += 1
            while i < len(argv) and not argv[i].startswith("--"):
                args[multi[a]].append(argv[i])
                i += 1
        elif a in ("--silent", "--link"):
            args[a[2:]] = True
            i += 1
        elif a == "--scenarios":
            args["scenarios"] = argv[i + 1].split(",")
            i += 2
        elif a in ("--runs", "--json", "--data"):
            args[a[2:]] = argv[i + 1]
            i += 2
        else:
            print(f"unknown: {a}", file=sys.stderr)
            return 2
    return {"sandbox": cmd_sandbox, "start": cmd_start, "keys": cmd_keys, "first": cmd_first, "check": cmd_check}[argv[1]](args)


if __name__ == "__main__":
    tempfile.tempdir = None
    sys.exit(main(sys.argv))
