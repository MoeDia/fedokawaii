---
id: helium-search-tabs
title: Finding things fast
part: 1
minutes: 12
---
## idea
The address bar is also the search: Ctrl+L, type words, Enter. Ctrl+F finds a word inside the page you are reading, and Enter jumps to the next match. Ctrl+H is your history and Ctrl+J your downloads, both one key away, so you never need to remember where something came from. A tab you will not need again is closed with Ctrl+W; fewer open tabs use less memory, which matters on a machine kept lean.

## exercise
In Helium press Ctrl+L, type fedora release schedule and press Enter. Open a result, press Ctrl+F, type beta and press Enter twice to see the next match. Then press Ctrl+H to see the page in your history and Ctrl+J for downloads. Esc leaves each. Close the extra tabs with Ctrl+W.

## check
```check
ask: Which key chord finds a word inside the page?
answer: Ctrl+F
proof: grep -q 'Ctrl+J · Ctrl+H · Ctrl+F' docs/fedokawaii-guide.md
```
