"""iso/screens/progress.py — what the screen shows while Anaconda installs the base system.

The one owner of tty1 from %pre to the reboot; Anaconda's own words go to tty2 (console=tty2,
inst.notmux). Read from its logs: /tmp/packaging.log and /tmp/anaconda.log.
"""
import os
import re
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from console import ACCENT_TEXT, FAINT, MUTED, STRONG, TEXT, WIDTH, G, Screen, wrap  # noqa: E402

PROGRESS = "/tmp/anaconda.log"
PACKAGING = "/tmp/packaging.log"
STEPS = (("Configuring storage", "the disk"), ("Running pre-installation", "the disk"),
         ("Starting package installation", "the packages"), ("Downloading", "the packages"),
         ("Preparing transaction", "the packages"), ("Performing post-installation", "the system"),
         ("Configuring installed system", "the system"), ("Writing network", "the system"),
         ("Creating users", "the system"), ("Installing boot loader", "the boot menu"),
         ("Generating initramfs", "the boot menu"), ("Running post-installation", "our toolkit"))
FRAMES = ("hg-0", "hg-1", "hg-2", "hg-3", "hg-4")


def tail_new(path, pos):
    try:
        with open(path, "rb") as f:
            f.seek(pos)
            data = f.read()
            return data.decode("utf-8", "replace"), f.tell()
    except OSError:
        return "", pos


def main():
    s = Screen(keys=False)
    top = max(1, (s.rows - 11) // 2)
    s.clear()
    s.torii(top)
    s.heading(top + 7, "download", "installing the base system")
    word, done, total = "the disk", 0, 0
    positions = {PROGRESS: 0, PACKAGING: 0}
    frame = 0
    drawn = None
    while True:
        for path in positions:
            text, positions[path] = tail_new(path, positions[path])
            for line in text.splitlines():
                for key, w in STEPS:
                    if key in line:
                        word = w
                m = re.search(r"Installing .*\((\d+)/(\d+)\)", line) or re.search(r"\[\s*(\d+)/(\d+)\]", line)
                if m:
                    done, total = int(m.group(1)), int(m.group(2))
                    word = "the packages"
        state = (word, done, total)
        if state != drawn:
            drawn = state
            s.clear_row(top + 9, s.left - 1, WIDTH + 2)
            s.at(top + 9, s.left + 1, word, TEXT)
            if total:
                count = f"{done} of {total}"
                s.at(top + 9, s.left + WIDTH - len(count), count, MUTED)
                s.meter(top + 11, s.left, done, total)
        s.at(top + 7, s.left, G[FRAMES[frame % len(FRAMES)]], ACCENT_TEXT)
        frame += 1
        time.sleep(0.6)


if __name__ == "__main__":
    _ = (FAINT, STRONG, wrap)
    main()
