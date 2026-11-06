---
id: snapshots-report
title: snapshots and the health report
part: desktop
chapter: 8
minutes: 3
needs: [super-u]
optional: no
---

## 8.2 snapshots: an undo for the whole system

> **Word — snapshot.** A frozen picture of every file at one moment. It costs almost no space
> (it shares unchanged data with the live files) and lets you copy any file back as it was.

Snapshots are taken by themselves: of your files (/home) every hour; of the system before every
update. Old ones go by their own rules, and the one an update may need stays until a start has
proven that update. To see them:

```text
$ snaps
 # │ Type   │ Pre # │ Date                     │ Description
───┼────────┼───────┼──────────────────────────┼────────────────────────
57 │ single │       │ Mon 20 Oct 2026 10:00:01 │ before update 2026-10-20
58 │ single │       │ Tue 21 Oct 2026 19:12:40 │ before my experiment
```

*(for example; shortened)*

| You want | Do |
|---|---|
| a file of yours as it was an hour ago | Super+U → snapshots → **a file, back**: pick the hour, then the file or folder (Space marks several, q takes the folder you are in) — a copy lands in `~/Restored`, beside what you have now; no password |
| a mark before a risky change | `sudo snapper -c root create -p -d "before my experiment"` (prints its number) |
| the whole system back to a snapshot | Super+U → snapshots → **go back**, its number: it becomes the system at the next start; your files stay as they are |
| the system you went back from | the same list, **old**: going back can itself be undone |

> **Careful.** `~/downloads` is not in the snapshots: move what you keep out of it.

## 8.3 the health report

When something is wrong and you want help, `fedokawaii report` writes
`~/fedokawaii-report.txt`: hundreds of checks, each with an ID and a verdict. Search it for
`FAIL` (in neovim: `/FAIL`). Give that file to whoever helps you — or to Claude Code.
