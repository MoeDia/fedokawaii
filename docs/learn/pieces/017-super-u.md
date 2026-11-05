---
id: super-u
title: the entries you will use
part: desktop
chapter: 8
minutes: 3
needs: [desks-session]
optional: no
---

> **In this chapter**
>
> - update the whole system in one step, a new Fedora too
> - check its health, and repair what is wrong
> - go back in time with snapshots, keep a copy with backups

**Super+U** opens the system's own control: one window for everything that keeps the machine
healthy, in five tabs across its top — *system*, *update*, *snapshots*, *backups*, *learning*.
**Tab** or **→** shows the next, **Shift+Tab** or **←** the one before, and a click on a tab shows
it. Each entry shows its state beside it — when the update is due, whether verify passed — and
the pane on the right tells more about the one under the cursor. What is still being built says
*soon*.

<!-- fig:system | Super+U: the status on the dark theme, the update on the light. -->

## 8.1 the entries you will use

| Tab | Entry | Does | How often |
|---|---|---|---|
| system | status | how things stand, on one page | when curious |
| system | verify | every check; changes nothing | after something odd |
| system | repair | verify, then put right what it found | when verify fails |
| update | update | everything up to date, from A to Z: section 8.4 | when it says *due* |
| update | held | what the update holds back, and why | when its report names one |
| snapshots | go back | the list of snapshots of the system, and one brought back: it becomes the system at the next start, your files stay | when something broke |
| snapshots | a file, back | a file or folder of yours as it was: a copy lands in `~/Restored` | when something is lost |
| backups | back up now | your home to the backup drive | weekly |
| backups | restore | your files as a backup holds them: pick a file, a folder or several — a copy lands in `~/Restored`, never over what is there | when something is lost |
| backups | the drive | which drive your backups go to, whether it is plugged in, how full, and the last backup; Enter picks another | once, then when it changes |
| learning | lessons | what you are reading: the book, in pieces | every day |

From a terminal: `update`, `verify`, `repair`, `snaps`, and `fedokawaii report` (below).
