"""iso/screens/progress.py — what the screen shows while Anaconda installs the base system.

The one owner of the screen from %pre to the reboot (its VT, console.py); Anaconda's own words stay on
tty1 (console=tty1, inst.notmux). It reads what Anaconda says, as the journal hands it to /tmp/syslog
("INFO anaconda:").
"""
import os
import re
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from console import ACCENT_TEXT, MUTED, TEXT, WIDTH, G, Screen  # noqa: E402

SYSLOG = "/tmp/syslog"
FRAMES = ("hg-0", "hg-1", "hg-2", "hg-3", "hg-4")
# how the meter is shared out: a slow disk and a fast line, or the other way round, come out about right
DOWNLOAD, INSTALL = 40, 90       # the meter's percent when each has finished
# what the installer is at, in our words: the first that fits a line of its own
WORDS = (("Creating ", "the disk"), ("Running pre-installation", "the disk"),
         ("Downloading packages", "the packages"), ("Configuring installed system", "the system"),
         ("Writing network", "the system"), ("Creating users", "the system"),
         ("Installing boot loader", "the boot menu"), ("Performing post-installation", "the boot menu"),
         ("Generating initramfs", "the boot menu"), ("Running post-installation", "the toolkit"),
         ("Storing configuration", "the toolkit"))
DOWN_RE = re.compile(r"Downloading \d+ RPMs?, ([\d.]+) (\w+) / ([\d.]+) (\w+) \((\d+)%\)")
UNIT = {"B": 1, "KiB": 1024, "MiB": 1024 ** 2, "GiB": 1024 ** 3}
PACK_RE = re.compile(r"(?:Installing|Configuring|Verifying) .*\((\d+)/(\d+)\)")


def lines_since(pos):
    try:
        with open(SYSLOG, "rb") as f:
            f.seek(pos)
            data = f.read()
            return data.decode("utf-8", "replace"), f.tell()
    except OSError:
        return "", pos


def human(n):
    return f"{n / 1024 ** 3:.1f} GB" if n >= 1024 ** 3 else f"{round(n / 1024 ** 2)} MB"


class State:
    def __init__(self):
        self.word, self.count, self.percent = "the disk", "", 0

    def read(self, line):
        said = line.split("INFO anaconda:", 1)
        if len(said) != 2:
            return
        said = said[1].strip()
        m = DOWN_RE.search(said)
        if m:
            got = float(m.group(1)) * UNIT.get(m.group(2), 1)
            total = float(m.group(3)) * UNIT.get(m.group(4), 1)
            self.word = "the packages"
            self.count = f"{human(got)} of {human(total)}"
            self.percent = DOWNLOAD * got / max(total, 1)
            return
        m = PACK_RE.search(said)
        if m:
            self.word = "the packages"
            self.count = f"{m.group(1)} of {m.group(2)}"
            self.percent = DOWNLOAD + (INSTALL - DOWNLOAD) * int(m.group(1)) / max(int(m.group(2)), 1)
            return
        for key, words in WORDS:
            if key in said:
                self.word, self.count = words, ""
                if words in ("the system", "the boot menu", "the toolkit"):
                    step = ("the system", "the boot menu", "the toolkit").index(words)
                    self.percent = max(self.percent, INSTALL + 3 * step)
                return


def main():
    s = Screen(keys=False)
    top = max(1, (s.rows - 12) // 2)
    state = State()
    pos = 0
    drawn = None
    frame = 0

    def page():
        s.clear()
        s.torii(top)
        s.heading(top + 6, "download", "installing the base system")

    page()
    while True:
        if s.undressed():
            page()
            drawn = None
        text, pos = lines_since(pos)
        for line in text.splitlines():
            state.read(line)
        now = (state.word, state.count, int(state.percent))
        if now != drawn:
            drawn = now
            s.clear_row(top + 8, s.left - 1, WIDTH + 2)
            s.at(top + 8, s.left, state.word, TEXT)
            if state.count:
                s.at(top + 8, s.left + WIDTH - len(state.count), state.count, MUTED)
            s.meter(top + 10, s.left, int(state.percent), 100)
        s.at(top + 6, s.left, G[FRAMES[frame % len(FRAMES)]], ACCENT_TEXT)
        frame += 1
        time.sleep(0.6)


if __name__ == "__main__":
    main()
