---
id: upkeep-practice
title: practice
part: desktop
chapter: 8
minutes: 12
needs: [snapshots-report]
optional: no
---

**8.1 ★ Status.** Open **Super+U**, read *status*.

*Expected:* your Fedora release, until when it is supported, and when the next update is due.

**8.2 ★ Verify.** Run `verify` in a terminal.

*Expected:* a list of checks ending in *passed*, or the few to fix with what to do.

**8.3 ★★ A safe experiment.** Make a mark (`sudo snapper -c root create -p -d "before cowsay"`),
install a toy (`sudo dnf install cowsay`), run `cowsay hi`, then put everything back to your mark
(`sudo snapper -c root undochange NUMBER..0`, with the number the first command printed) and
reboot.

*Expected:* after the reboot, `cowsay` answers `command not found`, and `verify` passes.

**8.4 ★★ A lost file.** Make `~/Documents/test.txt`, wait for the next hourly snapshot (or
`sudo snapper -c home create -p`), delete the file, then copy it back from the snapshot.

*Expected:* `cat ~/Documents/test.txt` shows it again.
