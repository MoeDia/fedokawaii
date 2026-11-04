"""What the chess tests share: a throw-away home with the app's files, kawa-chess in a pty, a player that reads the
position from the app's own files and answers through the keyboard."""
import json
import os
import pathlib
import shutil
import sys

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parent.parent
LIB = REPO / "configs/home/.local/lib/fedokawaii/kawa-chess"
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(LIB))
sys.dont_write_bytecode = True
import board as B  # noqa: E402
from chess_pty import Tty  # noqa: E402


def make_home(root, mood="dark", real_engine=None, fake=True, extra=None):
    """A home in root with what theme.sh would install, and `stockfish` on PATH: a real one, or the stand-in."""
    root = pathlib.Path(root)
    home = root / "home"
    (home / ".config/fedokawaii/themes").mkdir(parents=True, exist_ok=True)
    (home / ".local/lib/fedokawaii").mkdir(parents=True, exist_ok=True)
    (home / ".local/share/fedokawaii").mkdir(parents=True, exist_ok=True)
    shutil.copytree(LIB, home / ".local/lib/fedokawaii/kawa-chess", dirs_exist_ok=True, ignore=shutil.ignore_patterns("__pycache__"))
    shutil.copytree(REPO / "configs/home/.local/share/fedokawaii/chess", home / ".local/share/fedokawaii/chess", dirs_exist_ok=True)
    shutil.copy(REPO / "configs/home/.config/fedokawaii/icons.sh", home / ".config/fedokawaii/icons.sh")
    for m in ("dark", "light"):
        shutil.copytree(REPO / "configs/home/.config/fedokawaii/themes" / m, home / ".config/fedokawaii/themes" / m, dirs_exist_ok=True)
    cur = home / ".config/fedokawaii/current"
    if cur.is_symlink():
        cur.unlink()
    cur.symlink_to(f"themes/{mood}")
    bindir = root / "bin"
    bindir.mkdir(exist_ok=True)
    sf = bindir / "stockfish"
    if sf.exists() or sf.is_symlink():
        sf.unlink()
    if real_engine:
        sf.symlink_to(real_engine)
    elif fake:
        sf.write_text(f'#!/bin/sh\nexec python3 -I -B {HERE}/fake_stockfish.py "$@"\n')
        sf.chmod(0o755)
    env = {"HOME": str(home), "PATH": f"{bindir}:/usr/bin:/bin", "TERM": "foot", "LANG": "C.UTF-8",
           "XDG_RUNTIME_DIR": str(root), "DBUS_SESSION_BUS_ADDRESS": f"unix:path={root}/nobus",
           "KAWA_CHESS_LIB": str(LIB), "KAWA_CHESS_TRACE": str(root / "trace"), "PYTHONDONTWRITEBYTECODE": "1"}
    env.update(extra or {})
    return home, env


def open_app(env, cols=126, rows=33, mood="dark"):
    t = Tty(["python3", "-I", "-B", str(REPO / "bin/kawa-chess")], cols=cols, rows=rows, env=env, mood=mood)
    t.pump(0.6)
    return t


def state(home):
    return pathlib.Path(home) / ".local/state/fedokawaii/chess"


def crash_text(home):
    p = state(home) / "crash.log"
    return p.read_text() if p.exists() else ""


def current(home):
    try:
        return json.loads((state(home) / "current.json").read_text())
    except (OSError, ValueError):
        return None


def position_of(saved):
    """The position of a saved game."""
    pos = B.Position(saved["spec"]["fen"])
    for u in saved["moves"]:
        pos.push(B.from_uci(u))
    return pos


def go_to_tab(t, name, order=("today", "lessons", "puzzles", "games", "progress")):
    """From the first tab."""
    for _ in range(order.index(name)):
        t.send("\t")
        t.pump(0.08)


def start_free_game(t, colour=0, level_steps=0):
    """A free game from the games tab: its level moved by steps, the colour by turns."""
    go_to_tab(t, "games")
    t.send("\r")
    t.pump(0.15)
    for _ in range(colour):
        t.send("\x1b[C")
        t.pump(0.03)
    t.send("\x1b[B")
    t.pump(0.03)
    arrow = "\x1b[C" if level_steps > 0 else "\x1b[D"
    for _ in range(abs(level_steps)):
        t.send(arrow)
        t.pump(0.03)
    t.send("\x1b[B")
    t.pump(0.03)
    t.send("\r")
    t.pump(0.3)
