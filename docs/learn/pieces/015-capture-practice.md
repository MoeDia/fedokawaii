---
id: capture-practice
title: practice
part: desktop
chapter: 6
minutes: 23
needs: [shrink-archives]
optional: no
---

**6.1 ★ Annotate.** **Super+Print**, drag over this window, put an arrow (**z**) and a number
marker (**m**), **Enter**. Paste it into a note (**Super+N** cannot hold pictures — paste it into
a Brave chat or email instead).

*Expected:* the marked-up picture appears where you paste.

**6.2 ★ The history.** Copy three different words, one after another. Open **Super+V** and paste
the first.

*Expected:* the first word, though you copied two others since.

**6.3 ★★ Under 500 KB.** Take a full screenshot (**Shift+Print**), then **Super+Z** → *chat*.
Check both sizes: `ls -lh ~/Pictures/Screenshots | tail -2`.

*Expected:* the shrunk copy is under 500 KB.

**6.4 ★★ A 20-second demo.** Record yourself (**Super+Shift+R**, whole screen, no sound) opening
the launcher, starting btop and closing it; stop, and click the notice.

*Expected:* the recording plays in mpv; it is in `~/Videos/Recordings`.

**6.5 ★ Read the screen.** Open any picture with text in it (a screenshot of this page will do),
press **Super+Shift+Print** (or **Super+Shift+X**), drag over a line of text, and paste it into a
note.

*Expected:* the line arrives as text you can edit; nothing was saved in `~/Pictures`.

**6.6 ★★ A pause in the middle.** Record a region, pause it with **Super+Shift+P** for ten
seconds while you open something private, resume, and stop.

*Expected:* the bar shows the pause mark while paused, then the dot and 3 · 2 · 1; the file plays straight through,
without the private part.

**6.7 ★★ One PDF from three.** Copy three PDFs (or pictures) in yazi, **Super+D** → *pages* →
*merge into one PDF*, in the order you chose them. Then take pages `1-2` out of the result.

*Expected:* `…-merged.pdf` next to the first file, then `…-merged.pages-1-2.pdf`; each path was on
the clipboard in turn.
