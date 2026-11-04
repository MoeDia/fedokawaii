---
id: sketch
title: drawing: Sketch
part: programs
chapter: 20
minutes: 4
needs: [notes-pdfs]
optional: no
---

## 20.2 drawing: Sketch

**Sketch** in the launcher (**Super+Space**, type `sketch`) is FireAlpaca, a real painting program, on a new
page the shape of the screen: `~/Pictures/Sketches/sketch DATE.mdp`, ready to draw on.

**Your first drawing, in two minutes.** Put the pen near the pad: the circle on the page is the brush, its size
the line at full pressure. Draw. Press harder for a thicker line, lift off gently for a point. The first brush, *Fude*
(a Japanese writing brush), swells and thins by itself at a stroke's start and end. **Ctrl+Z** takes a stroke back,
**Ctrl+S** keeps the file, and that is all you need for today.

| the pen | on the page | over anything else |
|---|---|---|
| the tip | draws; press harder for a thicker line | a left click |
| the lower button, held, the tip dragged | the hand: moves the page | the right button |
| the upper button, held, the tip touching | the eyedropper: takes the colour under it | the middle button |

| key | does | key | does |
|---|---|---|---|
| **B** · **E** | brush · eraser | **Ctrl+Z** · **Ctrl+Y** | undo · redo |
| **Space**, drag | the hand | **Ctrl+0** | the whole page in the window |
| **Ctrl+Alt**, drag | brush size | **Ctrl++** · **Ctrl+-** | zoom |
| **I** | eyedropper | **G** · **N** | bucket · fill |
| **Tab** | every panel away, and back | **Ctrl+Shift+N** | a new layer |
| **F2** · **F3** · **F4** | the navigator · brush sizes · brush preview | **F5** · **F6** · **F7** | colour history · a reference picture · the status line |

**Colours.** The palette holds all 159 colours of Sanzo Wada's *A Dictionary of Color Combinations*, in the book's
order; pick one and its name shows under the palette. **Layers** are on the right: each is a sheet of glass. Draw
the lines on one and the colour on a layer under it, and you can change one without touching the other.
*Protect Alpha* paints only where the layer already has paint, *Clipping* paints only inside the layer below.

**Keep it, or send it.** **Ctrl+S** keeps the `.mdp`, FireAlpaca's own file with every layer in it (**Enter** on it in
yazi opens it again); *File → Export* makes a PNG to send. Open and Save are the desktop's own dialog, the same yazi
as everywhere. FireAlpaca also saves as you work, into its own backup folder: *File → Open the Auto Backup
Folder*.

**Why this and not Xournal++?** Xournal++ is for writing on pages and PDFs (it still signs your PDFs, **Super+D**). A
drawing wants more: brushes that behave like ink, pencil and watercolour, layers with blend modes and clipping,
rulers that snap (parallel, radial, perspective), symmetry, filters, even frame-by-frame animation.

**When something looks wrong.** The colours and panels follow the desktop, dark or light, even while it is open.
A panel gone? **Tab**, or *Window* in the menu. All of this is in **Super+/** while you draw. The pen draws without pressure? It is the brush: click its small gear, then
tick *Size by Pressure*. Everything in a mess: delete `~/.local/share/FireAlpaca` and `~/.local/state/fedokawaii/firealpaca-seed`,
then run `fedokawaii theme`: you are back at the start, with your drawings untouched.
