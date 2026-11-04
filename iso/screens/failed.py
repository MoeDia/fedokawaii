"""iso/screens/failed.py — the kickstart's %onerror, and what runs in place of Anaconda's second copy
(--if-unfinished: nothing, when %post has finished and the reboot is on its way): what failed, in our
screen, its own words."""
import os
import re
import signal
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


def stop_progress():
    """The progress page's own process (stage 2 has no pkill)."""
    for pid in os.listdir("/proc"):
        if pid.isdigit():
            try:
                with open(f"/proc/{pid}/cmdline", "rb") as f:
                    if b"progress.py" in f.read():
                        os.kill(int(pid), signal.SIGTERM)
            except OSError:
                pass


def main():
    if "--if-unfinished" in sys.argv and os.path.exists("/tmp/fk-post-done"):
        return
    stop_progress()
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
