---
id: health-report
title: Read the health report
part: 1
minutes: 13
---
## idea
When something is wrong, one file says more than any log: the health report, ~/fedokawaii-report.txt. About seven hundred checks, each with an ID such as BOOT-01 or THEME-10, grouped by area: the install, the start, the session, the hardware, the desktop, and every program run once to prove it works. It starts with a verdict, works or fails, and its warnings. Read it from the top: the verdict, then each line marked FAIL or WARN, then the ID, which tells you the area. The command asks for your password because the journal is root's.

## exercise
In a terminal type fedokawaii report and enter your password when it asks; it takes a few minutes. Then open the file in neovim with nvim ~/fedokawaii-report.txt, read the first lines, and search for WARN with a slash and then Enter. Note the ID of the first one and the area it belongs to. Leave the file as it is.

## check
```check
ask: Which command writes the health report?
answer: fedokawaii report
proof: grep -q 'fedokawaii report' docs/fedokawaii-guide.md
```
