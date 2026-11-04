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
> - update the whole system in one step
> - check its health, and repair what is wrong
> - go back in time with snapshots

**Super+U** opens the system's own control: one window for everything that keeps the machine
healthy, in five tabs across its top — *system*, *update*, *snapshots*, *backups*, *learning*.
**Tab** or **→** shows the next, **Shift+Tab** or **←** the one before, and a click on a tab shows
it. Each entry shows its state beside it — when the update is due, whether verify passed — and
the pane on the right tells more about the one under the cursor. What is still being built says
*soon*.

<!-- fig:system | Super+U: the status on the dark theme, the move to the next Fedora on the light. -->

## 8.1 the entries you will use

| Tab | Entry | Does | How often |
|---|---|---|---|
| system | status | how things stand, on one page | when curious |
| system | verify | every check; changes nothing | after something odd |
| system | repair | verify, then put right what it found | when verify fails |
| update | update | everything up to date: Fedora, Brave, Claude Code, the desktop's tools, neovim's plugins — with a snapshot first | each season, when it says *due* |
| update | fedokawaii | the desktop itself, newest from GitHub | when you hear of a change |
| update | Fedora N | the move to the next release | once it says *ready* |
| snapshots | go back | the list of snapshots of the system, and one brought back | before and after a risky change |
| backups | back up now | your home to the backup drive | weekly |
| backups | restore | your files as a backup holds them: pick a file, a folder or several — a copy lands in `~/Restored`, never over what is there | when something is lost |
| backups | the drive | which drive your backups go to, whether it is plugged in, how full, and the last backup; Enter picks another | once, then when it changes |
| learning | lessons | this book | |

From a terminal: `update`, `verify`, `repair`, `snaps`, and `fedokawaii report` (below).
