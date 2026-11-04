---
id: upkeep-practice
title: practice
part: desktop
chapter: 8
minutes: 12
needs: [the-fixer]
optional: no
---

**8.1 ★ Status.** Open **Super+U**, read *status*.

*Expected:* your Fedora release, until when it is supported, and when the next update is due.

**8.2 ★ Verify.** Run `verify` in a terminal.

*Expected:* a list of checks ending in *passed*, or the few to fix with what to do.

**8.3 ★★ A safe experiment.** Make a mark (`sudo snapper -c root create -p -d "before my test"`), then
leave a trace in the system (`sudo touch /etc/my-test`). Go back to your mark: Super+U → snapshots →
go back, the number the first command printed, then restart.

*Expected:* `ls /etc/my-test` says *No such file*, a file you made in your home meanwhile is still
there, and *old* in the same list would bring the trace back.

**8.4 ★★ A lost file.** Make `~/Documents/test.txt`, wait for the next hourly snapshot (or
`sudo snapper -c home create -p`), delete the file, then copy it back from the snapshot.

*Expected:* `cat ~/Documents/test.txt` shows it again.
