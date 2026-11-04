---
id: snapshots-report
title: snapshots and the health report
part: desktop
chapter: 8
minutes: 2
needs: [super-u]
optional: no
---

## 8.2 snapshots: an undo for the whole system

> **Word — snapshot.** A frozen picture of every file at one moment. It costs almost no space
> (it shares unchanged data with the live files) and lets you copy any file back as it was.

Snapshots are taken by themselves: of your files (/home) every hour; of the system around every
package install and before every update. Two everyday uses:

```text
$ snaps
 # │ Type   │ Pre # │ Date                     │ Description
───┼────────┼───────┼──────────────────────────┼────────────────────────
57 │ single │       │ Mon 20 Oct 2026 10:00:01 │ before update 2026-10-20
58 │ pre    │       │ Mon 20 Oct 2026 10:12:40 │ dnf install htop
59 │ post   │    58 │ Mon 20 Oct 2026 10:12:52 │ dnf install htop
```

*(for example; shortened)*

| You want | Do |
|---|---|
| undo one package install | `sudo snapper -c root undochange 58..59`, then reboot and `verify` |
| a file of yours as it was an hour ago | Super+U → snapshots → **a file, back**: pick the hour, then the file or folder (Space marks several, q takes the folder you are in) — a copy lands in `~/Restored`, beside what you have now; no password |
| a mark before a risky change | `sudo snapper -c root create -p -d "before my experiment"` (prints its number) |
| everything back to that mark | `sudo snapper -c root undochange NUMBER..0`, then reboot |

> **Careful.** `~/Downloads` is not in the snapshots: move what you keep out of it.

## 8.3 the health report

When something is wrong and you want help, `fedokawaii report` writes
`~/fedokawaii-report.txt`: hundreds of checks, each with an ID and a verdict. Search it for
`FAIL` (in neovim: `/FAIL`). Give that file to whoever helps you — or to Claude Code.
