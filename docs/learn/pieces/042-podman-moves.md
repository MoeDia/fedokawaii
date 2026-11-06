---
id: podman-moves
title: containers
part: programs
chapter: 22
minutes: 7
needs: [time-savers]
optional: no
---

> **Word — container.** A program packed with everything it needs, run apart from the rest of
> the system. Removing it leaves nothing behind.

**Best at:** trying software without installing it, and running services (Prowlarr runs in one
here). podman runs containers as you, never as root.

| Command | Does |
|---|---|
| `podman run --rm -it fedora:45 bash` | a throw-away Fedora, gone when you `exit` |
| `podman run --rm -it python:3.14 python` | a Python of another version, for a minute |
| `podman ps -a` · `podman images` | running and stopped containers · the images kept |
| `podman run --rm -v ~/dojo/practice:/w:Z -w /w python:3.14 python script.py` | run a script of yours inside |
| `podman image prune` | delete images no container uses |

### exercises

**22.1 ★ A throw-away system.** Start the Fedora container, `dnf install -y cowsay`, run it,
`exit`.

*Expected:* `cowsay` exists only inside; on your desktop, `command not found`.

**22.2 ★★ Your script inside.** Run `~/dojo/practice/oops.py` (fixed) in the `python:3.14` container
with `-v`.
