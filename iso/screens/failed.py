"""iso/screens/failed.py — the kickstart's %onerror: what failed, in our screen, its own words."""
import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from console import Screen, message_page, power_off, wrap  # noqa: E402

LOGS = ("/tmp/anaconda.log", "/tmp/packaging.log", "/tmp/storage.log", "/tmp/program.log")


def reason():
    """The last errors the installer logged, without their prefixes: the words someone can search for."""
    found = []
    for path in LOGS:
        try:
            with open(path, encoding="utf-8", errors="replace") as f:
                for line in f:
                    if re.search(r"\b(ERR|ERROR|CRIT|CRITICAL)\b", line):
                        found.append(re.sub(r"^[0-9:,]+ \w+ [\w.]+: ?", "", line.strip()))
        except OSError:
            pass
    return found[-3:]


def main():
    subprocess.run(["pkill", "-f", "progress.py"], check=False)
    s = Screen()
    lines = wrap("the installation stopped. the disk may hold a part of it; nothing else on this PC was changed.")
    why = []
    for r in reason():
        why += wrap(r)
    if why:
        lines += [""] + why[:8]
    message_page(s, "cross", "the install failed", lines + ["", "any key turns the PC off"])
    while s.key(None) is None:
        pass
    power_off()


if __name__ == "__main__":
    main()
