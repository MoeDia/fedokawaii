# Fedokawaii — Fedora Server → dwl, scripted

*Fedora + kawaii (かわいい, "cute").* A reproducible dwl desktop on Fedora 44/45 from a
minimal Server install: dark and retro, a little Japanese, drawn pixel by pixel. One tool
per job, no Flatpak, every package verified, and a verifier that proves it. The helpers are
the `kawa-*` commands (川, *kawa*, river).

```
fedokawaii.sh      the install menu: Check · Setup · Theme · Both · Verify · Update · Drift · Status · Repair
check.sh           is this machine ready for setup? read-only (setup runs it first)
setup.sh           software: repos, drivers, dwl, apps (3 phases, resumes itself after reboots)
theme.sh           every config, colour, keybinding, the boot menu (re-run any time; --check finds drift)
verify.sh          proves the machine matches the manifest: nothing missing, nothing extra
fedokawaii.conf    your settings (GPU, Steam, refresh rate, keyboard, city, theme…); anything
                   else you change in a working copy and apply — see "Changing it" below

lib/               shared shell: common.sh (output, steps, locks) · manifest.sh (every package,
                   the forbidden list, services) · upstream.sh (GitHub-release tools, checksummed)
                   · hardware.sh (this machine's firmware, microcode, Wi-Fi and sound parts) ·
                   hygiene.sh (nothing doubled or fighting: packages, services, leftovers)
system/            what setup installs: `fedokawaii` (the system's control and its menu, Super+U),
                   the session launcher (with its rescue screen), greeter, snapshots around dnf,
                   the performance profile, torrra's key wrapper, and the Prowlarr container
                   (→ ~/.config/containers/systemd)
src/               what is compiled here: dwl/ (config.h — keys, colours — and dwl.patch: gaps,
                   full window borders, centred dialogs, Arabic-proof keys, the layout for the bar) ·
                   kawa-veil/ (the theme and wallpaper transitions, C) · kawa-clipkeep/
                   (copies outlive the program they came from, C)
bin/               the kawa-* helpers (→ ~/.local/bin): menus, bar modules, theme, wallpaper
                   picker, level display, lock, clipboard history, books, notes, the file dialog,
                   the drives (kawa-drives: notices, the bar's mark, eject),
                   screen-share picker, fetch, the popup window (kawa-float) and its pictures
                   (kawa-sixel), brave-origin (Brave with screen-share sound)
configs/           what theme installs: home/ mirrors $HOME (foot, waybar, fuzzel, mako, gtk,
                   qt, bash, nvim, both themes, the pixel art, the icon font) · system/ mirrors /etc
art/               source art: icons.txt (every icon, drawn as text) · cursors.txt (the pointers,
                   drawn as text) · grub/ (torii, Departure Mono)
tools/             generators: build-icons.py (Sumi Icons, and its terminal cut) · build-themes.py
                   (one palette → every app) · build-cursors.py (the pointers)
docs/              the handbook: fedokawaii-guide.md and its illustrated PDF, Fedokawaii-Guide.pdf ·
                   build/ (how the PDF and its real screenshots were made: docs/build/README.md)
PACKAGES.md        what is installed, from where, and why
```

## The look

- **Two themes**, switched with **Super+Shift+W** or quick settings → *theme*: **dark** (sumi
  ink: ink-black ground, unbleached-paper text) and **light** (washi paper: warm paper ground,
  ink text). The screen holds still while everything changes underneath, then the new theme
  arrives as a row of seigaiha wave crests with a dithered fringe — rising like dawn, or
  falling like nightfall. Terminals and everything in them, neovim, the bar, menus,
  notifications, GTK, Qt, Brave (in its GTK mode), mpv, btop, zathura, the lock screen and the
  wallpaper all follow, live. Every colour used for reading reaches 4.5 : 1; only decoration
  meant to recede sits lower.
- **Pixel fonts and pixel icons**: Departure Mono on its 11 px grid, and *Sumi Icons* —
  icons drawn for this desktop (`art/icons.txt`), no icon packs in the bar or menus.
- **Full borders**: every window has a plain 2-pixel border — vermilion for the focused one,
  warm grey for the others; menus and notices are solid cards with the same warm-grey border.
- **The bar**: a vermilion torii key (launcher), workspaces as keyboard keys (1–3 always,
  more as you use them), the layout as an icon, the window title; in the middle, what is
  playing between the two halves of a fluorescent-display spectrum meter, with a cassette
  whose reels turn; on the right a seal while do-not-disturb (静) or screen sharing (共有)
  is on, the tray, a drive mark while a USB drive is plugged in, the keyboard layout
  (US / AR), CPU history and load, volume, date, the weekday as a kanji seal, time to the
  second, and the quick-settings key.
- **Level display**: the volume, microphone and brightness keys show a hi-fi level wedge of
  pixel columns at the bottom centre, updating in place while a key is held.
- **Clipboard**: Super+V opens a small window with the clipboard history — searchable, with
  the full text or the picture itself as a preview; a copy stays on the clipboard after the
  program it came from is closed.
- **No window buttons**: dwl tiles and Super+Q closes, so no app (GTK or Brave) draws any.
- **Books and notes**: Super+R lists every book in `~/Books` (PDF, EPUB, comics) with the
  page you stopped on, a reading bar and the cover — Enter reads it in zathura, Ctrl+A adds
  books from Downloads, Ctrl+D removes. Super+N opens `~/Notes/notes.md`, a dated diary of
  quick notes, and puts it away again; it saves as you type.
- **File dialogs**: every Open, Upload and Save as — Brave's too — is yazi in a floating
  terminal, with its previews and keys (GTK's dialog stays as the fallback).
- **USB drives**: sticks, disks and SD cards open by themselves with a notice (click it for
  the files); the bar's drive mark and **M** in yazi or any file dialog open or eject them,
  and eject says *safe to unplug*. Encrypted drives ask for their passphrase; exFAT, FAT,
  NTFS, ext4 and Btrfs all open.
- **The terminal**: fzf on Ctrl+R / Ctrl+T / Alt+C, a `cd` that learns your folders (zoxide),
  `ls` as eza, `tldr` examples, hints to copy hashes and paths (Ctrl+Shift+Y), and a notice
  when a long command finishes in a window you are not looking at — all cached, so a new
  shell starts no extra process.
- **Wallpapers**: the default is a retro railway town — a konbini by a level crossing at night,
  the same kind of crossing under cherry blossom by day — from a curated pack of 70
  (`WALLPAPER_PACK="yes"`), fetched from GitHub and redrawn as 640×360 pixel art: all
  Japanese and retro, all in the themes' colours, no two alike — Hiroshige and Hokusai, ink
  and brush, Shōwa streets and stations in pixel art, shrines in rain and snow, anime
  (credits and licences in `configs/home/.local/share/fedokawaii/wallpapers.list`). Mt Fuji
  over the seigaiha waves, drawn here, stays one choice away (and is the default without the pack).
  Each theme keeps its own; day/night pairs switch together; a new one dissolves in.
- **Prompt**: a ledger line — torii, path, git, a dotted rule, time taken, a vermilion seal
  with the exit code when a command fails, sun or moon, the time to the second.
- **fetch**: one of ten pixel pictures (beckoning cat, daruma, torii at sunset, a beige
  computer showing Fuji, Fuji at dawn, onigiri, a paper lantern, a cassette, a fox mask,
  ramen), coloured only from the desktop's palette, beside the system facts.
- **Pointers**: a pixel mouse pointer drawn for the desktop — the classic arrow and hand in
  ink and paper, thin shapes with a paper rim, vermilion accents — crisp at 1× and 2×.
- **Lock, boot, console**: the lock screen is the plain ground with a pixel padlock whose
  keyhole lights as you type, the day as a vermilion kanji seal above it and the date below;
  the GRUB menu is sumi ink with a hem of seigaiha waves fading upwards in a dither, at your
  monitor's native resolution; Terminus and the dark theme's 16 colours on the login console.

## 1 · Fedora Server installer — the settings that matter

Boot the Fedora 44 Server USB → **Install Fedora 44**:

| Screen | Set |
|---|---|
| Keyboard | English (US) — Arabic is added by the session |
| Time & Date | Asia/Dubai, Network Time **on** |
| Software Selection | **Minimal Install** (if the image lists only *Fedora Server Edition* / *Fedora Custom Operating System*, pick **Custom Operating System**). Nothing ticked on the right |
| Installation Destination | disk → Storage Configuration **Custom** → Done → scheme dropdown **Btrfs** → *Click here to create them automatically* → Done → Accept. **Do not skip:** Server's *Automatic* is LVM + XFS and snapper needs Btrfs |
| KDUMP | off |
| Network & Host Name | ethernet **on**, hostname `fedokawaii` |
| Root Account | leave it **disabled** (no root password) — everything runs through your administrator user with `sudo` |
| User Creation | your user, **Make this user administrator** |

## 2 · Run

The project is yours alone and private: bring it on a USB stick as
`fedokawaii.tar.gz` (tar keeps every file's permissions; the minimal install has `tar`).

```sh
lsblk -o NAME,SIZE,LABEL,FSTYPE           # find the stick, say sdb1
sudo mount /dev/sdb1 /mnt
tar -xzf /mnt/fedokawaii.tar.gz -C ~      # → ~/fedokawaii
sudo umount /mnt
cd ~/fedokawaii
sudo bash fedokawaii.sh
```

The menu offers **Setup** (the software) and **Theme** (the look) separately; neither forces
the other. Setup walks itself through three phases with a reboot between each, resumed
automatically on tty1, and
refuses to enable the login until `verify.sh` passes, then takes a baseline snapshot.
If anything fails it prints the line and the log (`/var/log/fedokawaii.log`, root's: `sudo
less` it); fix it and run it again — finished steps are skipped. At the first reboot setup
installs the project for good as `/usr/local/lib/fedokawaii` (root's own; everything runs from
there from then on), so the folder you installed from can go once setup is done.

**Coming from Scriptorium** (this project's old name): Setup and `update` take its system
files out by themselves (its timers, dnf hooks, dconf defaults, greeter), and Theme moves
its `~/.bashrc.d/scriptorium.sh` to the backup. The rest it left in your home is yours to
delete once you have logged in to the new desktop:

```sh
rm -rf ~/.config/scriptorium ~/.local/share/scriptorium ~/.local/state/scriptorium
rm -f ~/.local/bin/scrip-* ~/.cache/scriptorium-theme.log ~/.cache/scrip-lock-*
sudo rm -rf /var/lib/scriptorium /var/log/scriptorium*.log
```

## 3 · Looking after it — Super+U

**Super+U** opens the system's own control (`fedokawaii` in a terminal; a numbered menu on a
text console): how it stands, and every piece of upkeep, each with what is due beside it.
It reminds you — from what it already knows, never from the network — when the update season
comes round (every 90 days), when a new Fedora has settled (60 days after its release), and
a month before yours ends.

| Command | Does |
|---|---|
| `fedokawaii update` (or `update`) | the season's update: snapshot → `dnf upgrade` (detached, so nothing can cut it off) → the manifest, this machine's drivers and firmware, nothing doubled or fighting, the desktop's pinned tools, GE-Proton, torrra, Prowlarr, neovim's plugins → verify; a part that fails is reported and the rest goes on |
| `fedokawaii upgrade` | move to the next Fedora once it has settled: checks RPM Fusion, the COPRs, room and every library dwl needs first; snapshot; `dnf system-upgrade`; the rest by itself after the restart |
| `fedokawaii verify` (or `verify`) | full check, including your running session |
| `fedokawaii repair` (or `repair`) | verify, then fix what can be fixed by itself — packages, drivers and firmware, anything doubled or fighting, services, your session, release tools, torrra, Prowlarr, drifted configs — and verify again; offline, what needs no network |
| `fedokawaii theme` · `fedokawaii drift` | apply the configs again (dwl rebuilt only if needed) · list files that differ |
| `fedokawaii status` · `snapshots` · `log` · `settings` · `remind` | how it stands · the snapshots · the last log · `fedokawaii.conf` · the season |
| `kawa-theme` | switch dark ⇄ light (`kawa-theme dark`, `light`, `get`) |
| `Super+/` | every keybinding, searchable |

### Changing it — Super+Shift+U

The desktop is changed in a **working copy** (`~/repos/fedokawaii`, a git repository of the
toolkit), never in the toolkit itself, so every update keeps the change (handbook, chapter 15):

| Command | Does |
|---|---|
| `fedokawaii copy` | makes the working copy, once |
| **Super+Shift+U** · `fedokawaii change` | every part by name — keys, bar, bar look, colours, terminal, shell, launcher, notifications, files, drives, autostart, icons, packages, settings — opened in neovim in the copy; *apply now* when you close it |
| `fedokawaii keep FILE` | a config you tried in place (`~/.config/…`), taken into the copy |
| `fedokawaii diff` | what the copy would change |
| `fedokawaii apply` | ShellCheck's advice, every script parsed, the copy made the toolkit (your saved settings merged in), then the theme — or repair, when packages or system parts changed |

Files the theme never writes are yours to edit in place: `~/.bashrc.d/local.sh`,
`~/.config/dwl/autostart.local.sh`, `~/.config/nvim/lua/plugins/local.lua`. Chapter 16 of the
handbook is about learning: which languages to learn and why, the ideas behind them with an
example each, where the reliable documentation is, and where the industry stands now.
Chapter 17 explains Linux itself from the ground up, on this machine: the boot, files,
users, processes and services, packages and how this desktop's pieces connect, the graphics
and sound stacks, D-Bus and the portals, security, the commands by job, and a glossary.

## 4 · First login, once

- **Prowlarr** is already wired to torrra (its key's master copy is `~/.config/fedokawaii/secrets.sh`; Prowlarr gets it as a podman secret);
  type `prowlarr` (it starts on demand and opens <http://localhost:9696>), create its login, and add your indexers (handbook §12.1).
- **spotify_player**: run it once and log in (Premium).
- **Claude Code**: `claude` → log in. `/theme` → the *ANSI colours only* variant to use the palette.
- **Brave Origin**: nothing to set — Theme put it in GTK mode, so it wears the palette and follows
  the dark/light switch, and starts it so a screen share can carry the computer's sound.

## 5 · Kernels and the boot menu

Two kernels: the newest, and the one before it as the way back. The themed boot menu shows for
`BOOT_MENU_SECONDS` (2 by default); set it to 0 for Fedora's hidden menu, which appears
only after a failed boot, or with **Shift** held (or **Esc** or **F8** pressed) as it starts. Re-run Theme after changing monitors so the
boot menu matches the new resolution.
