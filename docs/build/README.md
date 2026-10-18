# docs/build — how the handbook PDF is made

`Fedokawaii-Guide.pdf` is `fedokawaii-guide.md` typeset with **real screenshots**: the desktop's
own programs (waybar, fuzzel, mako, foot, gtklock, yazi, neovim, mpv, Brave …) started with
this repository's configs, as `theme.sh` installs them, and captured to the pixel. Nothing in
the book is a mock-up. This folder keeps everything that made it, as it was run.

| File | What it does |
|---|---|
| `handbook.py` | the book: the Markdown → HTML (pixel fonts, the figures framed, every picture enlarged by a whole number only) → PDF in headless Chromium, then `pdfpack.py` |
| `pdfpack.py` | re-compresses the PDF's pictures losslessly (PNG row predictors), so the book stays small — every pixel the same |
| `render/shoot.sh` | the desktop: bar, menus and quick settings, notices, level display, terminal, lock — both themes (`SHOOT_ONLY="menus …"` for some; `switch` times a theme switch) |
| `render/apps.sh` | the applications and windows: yazi, neovim, lazygit, btop, mpv, zathura, the file dialog, books, notes, Super+U, torrra, Brave, the mixer (wiremix), pairing (bluetui), VisiData |
| `render/grub.sh` | the boot menu, drawn by GRUB 2.12 itself: the installed theme on a rescue CD booted in QEMU with UEFI firmware, with Fedora's entries → `shots/grub.png` |
| `render/build.sh` | builds the drawing stack (Pango, fcft, foot, fuzzel, mako, gtklock, waybar …) at Fedora 44's versions into `/opt/f44` |
| `render/sway.conf` | the headless compositor that stands in for dwl, drawing dwl's 2 px frame |
| `render/README.md` | the render kit in detail: what is real, what stands in, every output file |
| `render/lib/`, `render/stubs/` | small helpers and stand-ins for hardware the sandbox lacks (Bluetooth, DDC/CI, a player, a monitor list; `lib/fakebluez.py` answers as BlueZ for bluetui) |

## Where it ran

The kit was written for the sandbox the book was made in (Ubuntu, no GPU, no monitor) and
is kept exactly as it ran there: paths at the top of each script point into that sandbox's
scratch folder (`S=…`; `handbook.py` takes `FEDOKAWAII_REPO` — by default the repository it
sits in —, `FEDOKAWAII_SCRATCH` and `FEDOKAWAII_CHROME` from the environment, and
`handbook.py --help` lists them), and `render/stubs/` expects an fzf 0.74 binary
beside the scripts (not kept here: 5 MB). To rebuild elsewhere, set those paths, build the
stack once (`sudo render/build.sh`), then:

```sh
cd /path/to/fedokawaii && sudo bash theme.sh --user TESTUSER   # the configs the pictures show
sudo render/shoot.sh && sudo render/apps.sh                     # both themes (a few minutes)
FEDOKAWAII_REPO=/path/to/fedokawaii FEDOKAWAII_SCRATCH=/path/to/work \
  FEDOKAWAII_CHROME=/usr/bin/chromium-browser python3 handbook.py # needs: markdown, pillow, numpy,
                                                                  # pikepdf, playwright
```

`FEDOKAWAII_GUIDE` and `FEDOKAWAII_OUT` point it at another Markdown file and output folder (a
preview). The book is set in the desktop's own faces: Fusion Pixel as setup installs it
(`FEDOKAWAII_PIXEL_FONT`) for headings and labels, the toolkit's Sumi Icons, JetBrains Mono for
code, Noto Serif and Sans from `@fontsource` for the text; from the system it takes Noto
Serif/Sans CJK JP for kanji and kana, and DejaVu Sans for arrows and symbols. The cover is the
dark theme's default wallpaper, dawn-mart, as the theme fetched it (`FEDOKAWAII_COVER`); a
missing font or cover stops the build. It prints twice: the second pass writes the contents' page
numbers, read from the first.

On the Fedokawaii desktop itself the programs are real already, so the pictures can also be
taken there with `grim` — the book only needs the PNG names `handbook.py` reads.
