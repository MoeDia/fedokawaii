---
id: update-button
title: the update button, from A to Z
part: desktop
chapter: 8
minutes: 5
needs: [snapshots-report]
optional: no
---

## 8.4 the update button, from A to Z

**Super+U → update → update** is the one way anything on this machine gets updated. You never run
dnf. Nothing updates by itself: a quiet notice comes when updates have waited two weeks, when a new
Fedora has settled, and 90, 30 and 7 days before your Fedora's support ends. Press it and go on
working; the window only shows the run, so closing it stops nothing.

| Step | What happens | If it goes wrong |
|---|---|---|
| fedokawaii itself | its newest release from GitHub, checked in a fake machine first | that release stays out; the update goes on with the one you have |
| may it start | no other package manager at work, room on the disk, rpm's own database whole; every check run, so that what is red already is not blamed on the update | it says why and stops: nothing has changed |
| fetch | every package downloaded and resolved once | the network went: nothing has changed; press it again |
| a copy first | a copy of the system receives those packages, and is checked | the package that broke it is found by trying halves of the set, and held back; the rest goes on, and your system never saw it |
| snapshot | the system as it is now, kept until a start has proven the update | it stops: no change without a way back |
| the transaction | that same set, on the running system; the power button waits | a power cut: at the next start it is finished if every package went in, else the system before it comes back |
| the desktop | the desktop's own tools, neovim's plugins, the theme | each part on its own: the report names what failed, the next press tries again |
| the checks | every check again, and the desktop started out of sight: the bar measured, the lock up | the set is held back, and the system before it comes back at the next start |
| the report | one line in a notice; the whole in the update's pane and its log | |

A held package is tried again at every press, and let go when a newer version passes. When a local
model can mend what stopped it (a config option a new version renamed), it tries that in a copy
first; what it cannot mend stays held, and said: section 8.7.

The desktop's own steps are the one part the copy does not try: its new packages, firmware, the
pinned tools and the theme go in after the transaction, on the running system. The checks after them
judge them all the same, and a red undoes them with the update.

An update you stop by hand leaves its unit *failed* in `systemctl --failed` until the next press
clears it: expected, nothing to do.

**A new kernel** is on trial at the next start: three starts to reach the desktop, and if it cannot,
the kernel before it comes back by itself, and the new one is held until a newer one comes.

**A new Fedora comes through the same button.** A press that ends with this Fedora up to date looks
at the next one, seven days after its release. It is tried in a test VM first: a fresh Fedora with
this whole desktop installed on it, about an hour in the background, your system untouched. Then the
report says *press update again*, and never restarts without that. The next press tries the whole
move in a copy of your system, takes a snapshot, downloads, tells you, and restarts into Fedora's own
installation: 20 to 40 minutes on a text screen, leave it on. The start after that judges it before
the login: the release, every package, the desktop rebuilt and started. Anything red and the system
before it comes back, with one more restart, and *Fedora N waits* says why; it is tried again after
a month, or with a newer fedokawaii.

> **Honestly.** A new Fedora that changes something big (a new wlroots under dwl, say) may be beyond
> what the test VM and the local model can get through. Then this machine stays on the Fedora that
> works, and says so well before its support ends: time to have it ported.
