"""iso/screens/failed.py — the kickstart's %onerror: what failed, where its log is, in our screen."""
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from console import Screen, message_page, power_off, wrap  # noqa: E402


def main():
    subprocess.run(["pkill", "-f", "progress.py"], check=False)
    s = Screen()
    lines = wrap("the installation stopped. the disk may hold a part of it; nothing else on this PC was "
                 "changed. the log is /tmp/anaconda.log on this screen's system (ctrl+alt+f2).")
    message_page(s, "cross", "the install failed", lines + ["", "any key turns the PC off"])
    while s.key(None) is None:
        pass
    power_off()


if __name__ == "__main__":
    main()
