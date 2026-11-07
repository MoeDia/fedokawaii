# docs/build — the render kit

The Learn book (PDF) is retired: its source, `docs/fedokawaii-learn.md`, lives on as the text of Super+U's
daily lessons (`docs/learn/syllabus.txt`, cut by `tools/learn-pieces.py`). What stays here is the kit
that photographs the desktop's own programs, started with this repository's configs as `theme.sh`
installs them and captured to the pixel — nothing is a mock-up.

| File | What it does |
|---|---|
| `render/shoot.sh` | the desktop: bar, menus and quick settings, notices, level display, terminal, lock — both themes (`SHOOT_ONLY="menus …"` for some; `switch` times a theme switch) |
| `render/apps.sh` | the applications and windows: yazi, neovim, lazygit, btop, mpv, zathura, the file dialog, books, notes, Super+U, torrra, Helium, the mixer (wiremix), pairing (bluetui), VisiData |
| `render/grub.sh` | the boot menu, drawn by GRUB 2.12 itself: the installed theme on a rescue CD booted in QEMU with UEFI firmware, with Fedora's entries → `shots/grub.png` |
| `render/build.sh` | builds the drawing stack (Pango, fcft, foot, mako, gtklock, waybar …) at Fedora's versions into `/opt/fk-stack` |
| `render/sway.conf` | the headless compositor that stands in for dwl, drawing dwl's 2 px frame |
| `render/README.md` | the render kit in detail: what is real, what stands in, every output file |
| `render/lib/`, `render/stubs/` | small helpers and stand-ins for hardware the sandbox lacks (Bluetooth, DDC/CI, a player, a monitor list; `lib/fakebluez.py` answers as BlueZ for bluetui) |

## Where it ran

The kit was written for the sandbox it was made in (Ubuntu, no GPU, no monitor) and is kept as it ran
there: paths at the top of each script point into that sandbox's scratch folder (`S=…`), and
`render/stubs/` expects an fzf 0.74 binary beside the scripts (not kept here: 5 MB). To run elsewhere,
set those paths, build the stack once (`sudo render/build.sh`), then:

```sh
cd /path/to/fedokawaii && sudo bash theme.sh --user TESTUSER   # the configs the pictures show
sudo render/shoot.sh && sudo render/apps.sh                     # both themes (a few minutes)
```

On the Fedokawaii desktop itself the programs are real already, so the pictures can also be taken
there with `grim`.
