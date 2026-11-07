---
id: when-a-notice-asks
title: A notice that needs you
part: 1
minutes: 12
---
## idea
Most notices only tell you something and go. A few ask for you. The upkeep notice says the update season is here and names the days since the last update; the answer is Super+U, update. The backup notice says the last backup is old; the answer is quick settings, backup, with the drive plugged in. A notice that says a part is missing means fedokawaii repair. These notices are the only reminders: the desktop never acts on them by itself, and a click closes one without doing anything. You pick the moment.

## exercise
Pretend each notice has just come. For upkeep, press Super+U and find update. For backup, press Super+X and find backup. For a missing part, open a terminal and find repair in the Super+U menu. Close any notice with a click, or all with Super+Shift+N; they come back when due, not before.

## check
```check
ask: What is the title of the notice that says the update season is here?
answer: upkeep
proof: grep -q '^\*upkeep\* says it is time' docs/fedokawaii-guide.md
```
