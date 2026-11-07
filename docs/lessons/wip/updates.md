---
id: updates
title: How an update runs, A to Z
part: 1
minutes: 13
---
## idea
Nothing changes under you between seasons: an update runs only when you start it. You start it from Super+U, update. It checks the free space first, then takes a snapshot named before update and the date, and stops if it cannot. Then it upgrades every package in one run that closing the window cannot cut off, installs what the manifest gained, brings the pinned tools and neovim's plugins to their versions, and finishes with verify. It ends with a word: complete, partial, checks or stopped. After checks, run repair. If a new kernel came, restart; the old one stays as the way back.

## exercise
Press Super+U. Look at the update line: its mark reads due once the season has come round, and the menu shows the last outcome. Do not run it now unless the notice has come. Read what each word of the outcome means above, and say aloud which one tells you to run repair.

## check
```check
ask: Which outcome of an update tells you to run repair?
answer: checks
proof: grep -q '\*checks\* (verify found something' docs/fedokawaii-guide.md
```
