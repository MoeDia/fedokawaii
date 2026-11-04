"""iso/screens/first_boot.py — the installed system's first starts: setup.sh on our screen.

The kickstart's %post puts this and a drop-in on the resume unit (fedokawaii-resume.service): the
same `setup.sh --resume` the harness proves, its words read here, not scrolled on tty1. Setup restarts
the PC between its phases; this starts again with it, and counts from setup's own done.* marks. At
the end it takes itself away: nothing of the installer stays on the system.
"""
import glob
import os
import re
import select
import shutil
import signal
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from console import ACCENT_TEXT, MUTED, TEXT, WIDTH, G, Screen, message_page, restart, run, wrap  # noqa: E402

STATE = "/var/lib/fedokawaii"
TOOLKIT = "/usr/local/lib/fedokawaii"
DROPIN = "/etc/systemd/system/fedokawaii-resume.service.d"
HERE = os.path.dirname(os.path.abspath(__file__))
FRAMES = ("hg-0", "hg-1", "hg-2", "hg-3", "hg-4")


def total_steps():
    """Setup's steps of the three phases, counted from its own lines: one truth."""
    with open(f"{TOOLKIT}/setup.sh", encoding="utf-8") as f:
        text = f.read()
    n = 0
    for fn in ("phase1", "phase2", "phase3"):
        m = re.search(rf"^{fn}\(\) \{{(.*?)^\}}", text, re.S | re.M)
        if m:
            n += len(re.findall(r'^\s*step "', m.group(1), re.M))
    return n or 1


def steps_done():
    return len(glob.glob(f"{STATE}/done.*"))


def phase_done():
    try:
        with open(f"{STATE}/phase", encoding="ascii") as f:
            return f.readline().strip() == "done"
    except OSError:
        return False


def clean_up():
    """Nothing of the installer stays: the drop-in, this folder. (No reload: this run is the unit's,
    and the next start reads the files as they are; what the screen still needs is in memory.)"""
    shutil.rmtree(DROPIN, ignore_errors=True)
    shutil.rmtree(HERE, ignore_errors=True)


def words_of(heading):
    """"3.05 fonts, icons, toolkit themes" → "fonts, icons, toolkit themes"."""
    return re.sub(r"^[0-9T][0-9.]*[a-z0-9]*\s+", "", heading).strip()


def main():
    signal.signal(signal.SIGHUP, signal.SIG_IGN)
    run("plymouth", "quit", "--retain-splash")
    # (nothing else writes on this screen: systemd's status lines, the kernel's below an emergency)
    os.kill(1, signal.SIGRTMIN + 21)
    try:
        with open("/proc/sys/kernel/printk", "w", encoding="ascii") as f:
            f.write("1")
    except OSError:
        pass
    s = Screen(keys=False)
    total = total_steps()
    top = max(1, (s.rows - 12) // 2)

    def page():
        s.clear()
        s.torii(top)
        s.heading(top + 6, "download", "installing the desktop")

    page()
    env = dict(os.environ, TERM="dumb")
    p = subprocess.Popen(["/usr/bin/bash", f"{TOOLKIT}/setup.sh", "--resume"], stdin=subprocess.DEVNULL,  # noqa: S603
                         stdout=subprocess.PIPE, stderr=subprocess.STDOUT, env=env)
    os.set_blocking(p.stdout.fileno(), False)
    buf = b""
    word = "getting ready"
    frame = 0
    tail = []
    drawn = None
    next_frame = 0
    next_page = time.monotonic() + 20
    while True:
        r, _, _ = select.select([p.stdout], [], [], 0.25)
        if r:
            chunk = p.stdout.read()
            if chunk == b"":
                break
            if chunk:
                buf += chunk
                *lines, buf = buf.split(b"\n")
                for raw in lines:
                    line = re.sub(r"\x1b\[[0-9;]*[A-Za-z]", "", raw.decode("utf-8", "replace")).rstrip()
                    if line:
                        tail = (tail + [line])[-40:]
                    m = re.match(r"^── (.+)$", line)
                    if m and not m.group(1).startswith(("Fedokawaii", "phase ")):
                        word = words_of(m.group(1))
                    if "built — rebooting into" in line:
                        word = "ready: the login screen comes next"
                        clean_up()
                    elif "rebooting" in line:
                        word = "restarting; it carries on by itself"
        if s.undressed() or time.monotonic() >= next_page:     # (the page whole again, whatever was written over it)
            next_page = time.monotonic() + 20
            page()
            drawn = None
        done = steps_done()
        state = (word, done)
        if state != drawn:
            drawn = state
            s.clear_row(top + 8, s.left - 1, WIDTH + 2)
            shown = wrap(word, WIDTH - 12)[0] if word else ""
            s.at(top + 8, s.left, shown, TEXT)
            count = f"{done} of {total}"
            s.at(top + 8, s.left + WIDTH - len(count), count, MUTED)
            s.meter(top + 10, s.left, done, total)
        if time.monotonic() >= next_frame:
            next_frame = time.monotonic() + 0.6
            s.at(top + 6, s.left, G[FRAMES[frame % len(FRAMES)]], ACCENT_TEXT)
            frame += 1
    rc = p.wait()
    if rc == 0:
        return
    # setup stopped: its reason, and a restart carries on (setup.sh's own promise)
    s.close()
    s = Screen()
    why = [t for t in tail if "✘" in t or "!" in t[:6]][-4:] or tail[-4:]
    lines = []
    for t in why:
        lines += wrap(re.sub(r"^[0-9:]+\s+", "", t))
    if phase_done():
        clean_up()
        last = "any key restarts the PC into the login screen. Super+U, repair, sets this right."
    else:
        last = "any key restarts the PC; setup carries on from there."
    message_page(s, "cross", "setup stopped", lines[:10] + ["", *wrap(last)])
    while s.key(None) is None:
        pass
    restart()


if __name__ == "__main__":
    main()
