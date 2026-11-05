"""iso/screens/failed.py — the kickstart's %onerror, and what runs in place of Anaconda's second copy
(--if-unfinished: nothing, when %post has finished and the reboot is on its way): what failed, in our
screen, its own words."""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from console import Screen, message_page, power_off, stop_progress, wrap  # noqa: E402

LOGS = ("/tmp/fk-pre.log", "/tmp/anaconda.log", "/tmp/packaging.log", "/tmp/storage.log", "/tmp/program.log")
ERASED = "/tmp/fk-disk-erased"     # (questions.py: the disk it erased)


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
    if "--if-unfinished" in sys.argv and os.path.exists("/tmp/fk-post-done"):
        return
    stop_progress()
    s = Screen()
    try:
        with open(ERASED, encoding="ascii") as f:
            what = f"{f.read().strip()} was erased and holds a part of it; nothing else on this PC was changed."
    except OSError:
        what = "no disk was touched."
    lines = wrap(f"the installation stopped. {what} start again from the stick.")
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
