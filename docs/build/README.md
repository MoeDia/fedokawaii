# docs/build — how the handbook PDF is made

`Fedokawaii-Guide.pdf` is `fedokawaii-guide.md` typeset with **real screenshots**: the desktop's
own programs (waybar, fuzzel, mako, foot, swaylock, yazi, neovim, mpv, Brave …) started with
this repository's configs, as `theme.sh` installs them, and captured to the pixel. Nothing in
the book is a mock-up. This folder keeps everything that made it, as it was run.

| File | What it does |
|---|---|
| `handbook.py` | the book: the Markdown → HTML (pixel fonts, the figures framed, every picture enlarged by a whole number only) → PDF in headless Chromium, then `pdfpack.py` |
| `pdfpack.py` | re-compresses the PDF's pictures losslessly (PNG row predictors), so it stays under 10 MB — every pixel the same |
| `render/shoot.sh` | the desktop: bar, menus, notices, level display, terminal, lock — both themes |
| `render/apps.sh` | the applications and windows: yazi, neovim, lazygit, btop, mpv, zathura, the file dialog, books, notes, Super+U, torrra, Brave |
| `render/build.sh` | builds the drawing stack (Pango, fcft, foot, fuzzel, mako, swaylock, waybar …) at Fedora 44's versions into `/opt/f44` |
| `render/sway.conf` | the headless compositor that stands in for dwl, drawing dwl's 2 px frame |
| `render/README.md` | the render kit in detail: what is real, what stands in, every output file |
| `render/lib/`, `render/stubs/` | small helpers and stand-ins for hardware the sandbox lacks (Bluetooth, DDC/CI, a player, a monitor list) |

## Where it ran

The kit was written for the sandbox the book was made in (Ubuntu, no GPU, no monitor) and
is kept exactly as it ran there: paths at the top of each script point into that sandbox's
scratch folder (`S=…`; `handbook.py` takes `FEDOKAWAII_REPO`, `FEDOKAWAII_SCRATCH` and
`FEDOKAWAII_CHROME` from the environment), and `render/stubs/` expects an fzf 0.74 binary
beside the scripts (not kept here: 5 MB). To rebuild elsewhere, set those paths, build the
stack once (`sudo render/build.sh`), then:

```sh
cd /path/to/fedokawaii && sudo bash theme.sh --user TESTUSER   # the configs the pictures show
sudo render/shoot.sh && sudo render/apps.sh                     # both themes (a few minutes)
FEDOKAWAII_REPO=/path/to/fedokawaii FEDOKAWAII_SCRATCH=/path/to/work \
  FEDOKAWAII_CHROME=/usr/bin/chromium-browser python3 handbook.py # needs: markdown, pillow, numpy,
                                                                  # pikepdf, playwright
```

On the Fedokawaii desktop itself the programs are real already, so the pictures can also be
taken there with `grim` — the book only needs the PNG names `handbook.py` reads.
