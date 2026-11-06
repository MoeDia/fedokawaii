---
id: clipboard-shots
title: clipboard, screenshots, recordings
part: desktop
chapter: 6
minutes: 3
needs: [desks-session]
optional: no
---

> **In this chapter**
>
> - paste anything you copied earlier
> - take, mark up and share a screenshot
> - record the screen
> - shrink a picture or PDF for email

<!-- fig:clipboard | The clipboard history (Super+V): text and pictures, filtered as you type. -->

## 6.1 the clipboard and its history

| Where | Copy | Paste |
|---|---|---|
| every program | **Ctrl+C** | **Ctrl+V** |
| the terminal | **Ctrl+Shift+C**, or just select the text | **Ctrl+Shift+V** |
| anything copied earlier | — | **Super+V**, choose, **Enter**, then paste as usual |

The history (**Super+V**) keeps text *and* pictures. Type to filter, **Ctrl+D** forgets one
entry, **Ctrl+X** forgets them all.

## 6.2 screenshots

| Press | Takes | Then |
|---|---|---|
| **Print** | a region: drag a box (**Esc** gives up) | saved to `~/captures` and copied |
| **Shift+Print** | the whole screen | saved and copied |
| **Super+Print** | a region, opened in satty to mark it up | **Enter** copies, **Ctrl+S** saves |
| **Super+Shift+Print** | a region's **text**, read by tesseract (English and Arabic) | the text copied, nothing saved |

**No Print key?** A small (61-key) keyboard has the same four on letters:

| Keys | Same as |
|---|---|
| **Super+Shift+S** | Print: a region, saved and copied |
| **Super+Shift+F** | Shift+Print: the whole screen |
| **Super+Shift+A** | Super+Print: a region to annotate |
| **Super+Shift+X** | Super+Shift+Print: a region's text |

The text key reads what you cannot select — a picture of a document, a video's subtitle, an
error in a window that will not let you copy it. *no text found* means the region held none.

In satty: **z** an arrow, **r** a rectangle, **t** text, **m** numbered markers, **b** blur
(for a password or a name), **1…5** the colour, **Ctrl+Z** undo.

## 6.3 recording the screen

**Super+Shift+R** opens a small menu: the whole screen or a region, with the desktop's sound or
without. Choose, and it records: a red dot, pulsing once a second, and the time gone by stand in
the bar, in vermilion. **Super+Shift+R** again — or a click on that tile — stops it. A notice
says where the file is (a click plays it), and its path is on the clipboard.

**Super+Shift+P** pauses it: the bar shows the pause mark and the time (**00:12**), muted, and
nothing is recorded — not the screen, not the sound. Press it again and the bar counts **3**,
**2**, **1** beside the dot, a second each, then records on. The pieces become one file when you
stop.

| What | Where |
|---|---|
| the recordings | `~/captures/2026-10-20_14-05-31.mp4` (the date and time it started) |
| the format | MP4, the picture encoded by the graphics card (H.264), the sound AAC |

Use it for a bug report, a short tutorial for a friend, or to watch your own coding session
back.
