---
id: upkeep-practice
title: practice
part: desktop
chapter: 8
minutes: 17
needs: [doors]
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

**8.4 ★★ A lost file.** Make `~/notes/test.txt`, wait for the next hourly snapshot (or
`sudo snapper -c home create -p`), delete the file, then copy it back from the snapshot.

*Expected:* `cat ~/notes/test.txt` shows it again.

**8.5 ★★ Be a stranger.** Run `sudo bash /usr/local/lib/fedokawaii/tools/portscan.sh` (five minutes).
It scans every port of this machine from the far end of a cable, once as a neighbour and once as a
stranger on the internet.

*Expected:* a table, ending in `✔ exactly the list's doors`.
