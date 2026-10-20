"""tests/menus/headless_panel.py — the real kawa-panel's decisions without a screen, as the
session runs it: its fifo ($XDG_RUNTIME_DIR/kawa-panel.in) read line by line exactly as the
panel's main loop does (toggle MODE · menu PID · close), every request handed to the real
Panel (bin/kawa-panel, loaded as a module with a stand-in for gi), and kawa-menu's callers
answered through their own fifos. After every line, $XDG_RUNTIME_DIR/panel.state holds
"1 WHAT" while a panel or menu is on screen, "0 -" when none is.

    python3 -I headless_panel.py REPO/bin/kawa-panel GI_STUB_DIR

Its command line names kawa-panel, so kawa-quick and kawa-menu take it for the session's.
"""
import importlib.machinery
import importlib.util
import os
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, sys.argv[2])
loader = importlib.machinery.SourceFileLoader("kawa_panel", sys.argv[1])
spec = importlib.util.spec_from_loader("kawa_panel", loader)
kp = importlib.util.module_from_spec(spec)
loader.exec_module(kp)

STATE = ("theme\tdark\nbrightness\t70%\nnight\ton\nvrr\tin games\nwallpaper\tmishima-mist\nsound\t62%\n"
         "nettype\twifi\nnetwork\tHome Net\nbluetooth\ton\ndevices\tnone\ndrives\tnone\n"
         "backup\t3 days ago\ndnd\toff\n")
SOUND = "sound\t62%\nmuted\toff\nmic\ton\n"


class UI:
    """the screen, stood in for: nothing drawn, every state read answered at once"""
    def clicked(self): return None
    def click(self): return None             # (no bar here: every request is a key's)
    def run(self, argv, done): done(0, SOUND if "sound" in argv else STATE)
    def trim(self, size): return 0, size[1], size[0]
    def __getattr__(self, name): return lambda *a, **k: None


panel = kp.Panel(UI())
RUN = kp.RUN
STATEF = os.path.join(RUN, "panel.state")


def note():
    with open(STATEF + ".new", "w") as f:
        f.write(f"{int(panel.visible)} {panel.what if panel.visible else '-'}\n")
    os.replace(STATEF + ".new", STATEF)


def menu_from(pid):
    req = os.path.join(RUN, f"kawa-menu.{pid}.req")
    out = os.path.join(RUN, f"kawa-menu.{pid}.out")
    try:
        with open(req) as f:
            got = kp.menu_request(f.read())
        os.unlink(req)
    except (OSError, UnicodeDecodeError):
        got = None

    def reply(rc, text):
        try:
            fd = os.open(out, os.O_WRONLY | os.O_NONBLOCK)
            os.write(fd, f"{rc} {text}\n".encode())
            os.close(fd)
        except OSError:
            pass
    if got is None:
        reply(2, "")
        return
    caller, menu = got
    panel.request("menu " + caller, menu, reply)


note()
os.mkfifo(kp.FIFO)
fifo = os.open(kp.FIFO, os.O_RDWR)
with open(kp.PIDFILE, "w") as f:
    f.write(f"{os.getpid()}\n")
pending = b""
while True:
    data = os.read(fifo, 65536)
    lines = (pending + data).split(b"\n")
    pending = lines.pop()
    for line in lines:
        f = line.decode(errors="replace").split()
        if len(f) == 2 and f[0] == "toggle" and f[1] in kp.MODES:
            panel.request(f[1])
        elif len(f) == 2 and f[0] == "menu" and f[1].isdigit():
            menu_from(int(f[1]))
        elif f == ["close"]:
            panel.close("chosen")
        note()
