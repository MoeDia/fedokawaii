---
id: helium-reading-mode
title: Long reading, calm
part: 1
minutes: 11
---
## idea
For a long page, take away what is not the page. F11 (or Super+F) makes Helium fullscreen: no tabs, no toolbar, only the text. Press it again to leave. Ctrl+Plus and Ctrl+Minus change the size of the text and Ctrl+0 puts it back. Many sites follow the desktop's dark or light mood, and the colours of the browser itself change with it, so reading at night is already gentle. Ctrl+F finds your place again if you lose it.

## exercise
Open a long page, for example the Fedora documentation. Press F11 and scroll with the arrows or Space. Press Ctrl+Plus twice, then Ctrl+0. Leave fullscreen with F11.

## check
```check
ask: Which key makes Helium fullscreen, and leaves it again?
answer: F11
proof: grep -q 'F11 or Super+F' docs/fedokawaii-guide.md
```
