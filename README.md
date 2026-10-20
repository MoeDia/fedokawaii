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
src/               what is compiled or patched here: dwl/ (config.h — keys, colours — and dwl.patch: gaps,
                   full window borders, centred dialogs, Arabic-proof keys, the layout for the bar,
                   the pointers following the theme) ·
                   kawa-clipkeep/
                   (copies outlive the program they came from, C) · syncplay/ (syncplay.patch:
                   two fixes to Syncplay's mpv connection, applied as it is installed)
bin/               the kawa-* helpers (→ ~/.local/bin): menus, bar modules, theme, wallpaper
                   picker, level display, lock, clipboard history, books, notes, the file dialog,
                   the drives (kawa-drives: notices, the bar's mark, eject),
                   screen-share picker, backups (kawa-backup), watching together (kawa-together),
                   fetch, the popup window (kawa-term --float) and its pictures (kawa-sixel),
                   brave-origin (Brave with screen-share sound)
configs/           what theme installs: home/ mirrors $HOME (foot, waybar, fuzzel, mako, gtk,
                   qt, bash, nvim, both themes, the pixel art, the icon font) · system/ mirrors /etc
art/               source art: icons.txt (every icon, drawn as text) · cursors.txt (the pointers,
                   drawn as text) · grub/ (torii, Fusion Pixel)
tools/             generators: build-icons.py (Sumi Icons, and its terminal cut) · build-themes.py
                   (one palette → every app) · build-cursors.py (the pointers)
tests/             the self-tests: every helper, the engine and the installer, edge case by edge
                   case, against stand-ins for the hardware (bash tests/run.sh — see §6)
docs/              the learning guide Super+U opens: fedokawaii-learn.md and Fedokawaii-Learn.pdf
                   (every key and program, then Python and Rust from zero to AI) · the full
                   handbook, kept here as the reference: fedokawaii-guide.md, Fedokawaii-Guide.pdf ·
                   build/ (how both PDFs and their real screenshots were made: docs/build/README.md)
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
- **One pixel font and pixel icons**: Fusion Pixel 12 (Latin, kana and kanji in one face) —
  the terminal at 24 px on 26 px lines, the bar, menus and notices at 12 px — and *Sumi
  Icons*, icons drawn for this desktop (`art/icons.txt`), no icon packs in the bar or menus.
- **Full borders**: every window has a plain 2-pixel border — vermilion for the focused one,
  warm grey for the others; menus and notices are solid cards with the same warm-grey border.
- **The bar**: a vermilion torii key (launcher), workspaces as kanji numerals (一 二 三
  always, more as you use them), the layout as an icon, the window title; in the middle, what
  is playing between the two halves of a fluorescent-display spectrum meter, with a cassette
  whose reels turn; on the right a seal while do-not-disturb (静) or screen sharing (共有)
  is on, a drive mark while a USB drive is plugged in, Steam's gamepad while it runs, the
  keyboard layout (US / AR), memory, volume, the monitor's brightness (when it answers over
  DDC/CI), the weather, the date (`18 Oct`), the weekday as a kanji seal, the time to the
  second, and the cat — quick settings — centred between the last stitch and the screen's
  edge. No tray.
- **Level display**: the volume, microphone and brightness keys show a hi-fi level wedge of
  pixel columns at the bottom centre, updating in place while a key is held.
- **Clipboard**: Super+V opens a small window with the clipboard history — text and pictures
  (screenshots, Brave's *Copy image*), searchable, with the full text or the picture itself as
  a preview, and Enter puts a picture back as a picture; a copy stays on the clipboard after
  the program it came from is closed.
- **No window buttons**: dwl tiles and Super+Q closes, so no app (GTK or Brave) draws any.
- **Books and notes**: Super+R lists every book in `~/Books` (PDF, EPUB, comics) with the
  page you stopped on, a reading bar and the cover — Enter reads it in zathura, Ctrl+A adds
  books from Downloads, Ctrl+D removes. Super+N opens `~/Notes/notes.md`, a dated diary of
  quick notes, and puts it away again; it saves as you type.
- **Drawing**: *Sketch* in the launcher opens Xournal++ on a blank page the shape of the
  screen, saved as you draw in `~/Pictures/Sketches`. A drawing tablet (an XP-Pen Star G430S
  here) needs no driver: its pen draws with pressure, its lower button erases and its upper
  one drags the page while held, and the pad keeps the screen's proportions.
- **File dialogs**: every Open, Upload and Save as — Brave's too — is yazi in a floating
  terminal, with its previews and keys — the one dialog (LibreOffice alone shows GTK's: it
  builds that dialog itself, without the portal).
- **Office**: LibreOffice Writer, Calc and Impress open and edit Word, Excel and PowerPoint
  files, in the desktop's theme, with English and Arabic spelling.
- **USB drives**: sticks, disks and SD cards open by themselves with a notice (click it for
  the files); the bar's drive mark and **M** in yazi or any file dialog open or eject them,
  and eject writes out what is still on its way, then says *safe to unplug*. Encrypted
  drives ask for their passphrase; exFAT, FAT, NTFS, ext4 and Btrfs all open; disk images
  (`udisksctl loop-setup -f FILE.iso`) open the same way. The machine's own disks never open
  by themselves.
- **The terminal**: fzf on Ctrl+R / Ctrl+T / Alt+C, a `cd` that learns your folders (zoxide),
  `ls` as eza, `tldr` examples, hints to copy hashes and paths (Ctrl+Shift+Y), and a notice
  when a long command finishes in a window you are not looking at — all cached, so a new
  shell starts no extra process.
- **Wallpapers**: the default is one quiet place by night and by day — layers of ink-wash
  ridges under a pale moon on the dark theme, the same ridges on paper under a vermilion sun
  on the light — from a curated pack of 120 (`WALLPAPER_PACK="yes"`), fetched from GitHub at
  pinned commits, checked by SHA-256 and shown at full quality: all Japanese — Hokusai,
  Hiroshige and shin-hanga prints, ink and brush, streets and trains by night and by day,
  anime film (credits and
  licences in `configs/home/.local/share/fedokawaii/wallpapers.list`). Without the pack, the
  theme's plain ground. Each theme keeps its own; day/night pairs switch together; a new one
  dissolves in.
- **Prompt**: a ledger line — torii, path, git, a dotted rule, then after each command a green
  ✓ or a vermilion ✗ with its exit code and the time a slow one took, sun or moon, the time to
  the second. Typing is ble.sh's: the line coloured as you type, a grey suggestion from your
  history (→ takes it), a completion menu — all in the theme's colours.
- **fetch**: one of ten pixel pictures (beckoning cat, daruma, torii at sunset, a beige
  computer showing Fuji, Fuji at dawn, onigiri, a paper lantern, a cassette, a fox mask,
  ramen), coloured only from the desktop's palette, beside the system facts.
- **Pointers**: "Sumi", an ink brush in crisp pixels — the arrow a brush stroke with a dry
  streak, busy an ensō drawn as you wait, "not here" the one vermilion seal — pale ink for the
  dark theme, sumi ink for the light one, switching with it; crisp at 24, 32 and 48 px.
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
| Installation Destination | disk → Storage Configuration **Custom** → Done → **if Windows is on the disk**, delete its parts first: click one under *Unknown*, **−**, tick *Delete all file systems which are only used by Unknown.*, *Delete It* (and the small *EFI System Partition* the same way, if it stays) → scheme dropdown **Btrfs** → *Click here to create them automatically* → Done → Accept (handbook §4.2). **Do not skip:** Server's *Automatic* is LVM + XFS and snapper needs Btrfs |
| KDUMP | off |
| Network & Host Name | ethernet **on**, hostname `fedokawaii`. Setup needs the network from its first minute, and a Minimal Install has **no Wi-Fi** support yet (setup adds it, and the radio's firmware: in phase 2, or at its last check once the radio shows after a restart): a cable, or a phone's USB tethering (it counts as wired), until setup has finished |
| Root Account | leave it **disabled** (no root password) — everything runs through your administrator user with `sudo` |
| User Creation | your user, with **Add administrative privileges to this user account (wheel group membership)** ticked |

## 2 · Run

The project is yours alone and private, on GitHub as `MoeDia/fedokawaii`. A Minimal Install
has neither `tar` nor `git`, so the first command installs one (the network is up already).

**On a USB stick** — on another computer, signed in to GitHub, download
`https://github.com/MoeDia/fedokawaii/archive/refs/heads/main.tar.gz` onto the stick
(it saves as `fedokawaii-main.tar.gz`), then on the new machine:

```sh
sudo dnf install -y tar
lsblk -o NAME,SIZE,LABEL,FSTYPE           # find the stick, say sdb1
sudo mount /dev/sdb1 /mnt
tar -xzf /mnt/fedokawaii-main.tar.gz -C ~ && mv ~/fedokawaii-main ~/fedokawaii
sudo umount /mnt
cd ~/fedokawaii
sudo bash fedokawaii.sh
```

**Or straight from GitHub** (git asks for your GitHub user name, and a *personal access token*
as the password — long to type on a console, so the stick is usually quicker):

```sh
sudo dnf install -y git-core
git clone https://github.com/MoeDia/fedokawaii ~/fedokawaii
cd ~/fedokawaii && sudo bash fedokawaii.sh
```

The menu offers **Setup** (the software) and **Theme** (the look) separately; neither forces
the other. For a first install choose **Both**: Setup removes `~/fedokawaii` at its very end,
so after Setup alone the menu is gone and the first login is plain dwl without the bar — then
press Ctrl+Alt+F2, log in on the text console and run `fedokawaii theme`, then `sudo reboot` and log
in again. Setup walks itself through three phases with a reboot between each, resumed
automatically on tty1, and
refuses to enable the login until `verify.sh` passes — what it finds there it repairs itself
first, the same fixes as `fedokawaii repair`, and checks again — then clears what the build left (dnf's
packages, pip/npm caches, unneeded dependencies, old theme backups),
takes a baseline snapshot and, as its very last step after the final check, removes
`~/fedokawaii` and the download it came from (anything of yours in it packed first into
`~/.local/state/fedokawaii/`). Update and repair run from a fresh clone end the same way. Later changes: `fedokawaii copy` (a working copy in
`~/repos/fedokawaii`), or a fresh clone run once with `sudo bash fedokawaii.sh repair`.
If anything fails it prints the line and the log (`/var/log/fedokawaii.log`, root's: `sudo
less` it); fix it and run it again — finished steps are skipped. At the first reboot setup
installs the project for good as `/usr/local/lib/fedokawaii` (root's own; everything runs from
there from then on), so the folder you installed from can go once setup is done.

**Coming from Scriptorium** (this project's old name): Setup and `update` take its system
files out by themselves (its timers, dnf hooks, dconf defaults, greeter), and Theme moves
its `~/.bashrc.d/scriptorium.sh` to the backup. The rest it left goes by itself too: its
records and logs with setup, update and repair, what it left in your home with the weekly
tidy (`kawa-tidy`) — its settings, `~/.config/scriptorium`, kept in
`~/.local/state/fedokawaii/backup/scriptorium-config` should you want anything from them.

## 3 · Looking after it — Super+U

**Super+U** opens the system's own control (`fedokawaii` in a terminal; a numbered menu on a
text console): how it stands, and every piece of upkeep, each with what is due beside it.
It reminds you — from what it already knows, never from the network — when the update season
comes round (every 90 days), when a new Fedora has settled (60 days after its release), and
a month before yours ends.

| Command | Does |
|---|---|
| `fedokawaii update` (or `update`) | the season's update: snapshot → `dnf upgrade` (detached, so nothing can cut it off) → the manifest, this machine's drivers and firmware, nothing doubled or fighting, the desktop's pinned tools, GE-Proton, torrra, Prowlarr, neovim's plugins → verify; a part that fails is reported and the rest goes on |
| `fedokawaii pull` (Super+U → update fedokawaii) | fedokawaii itself from GitHub: the one clone, `~/repos/fedokawaii`, fast-forwarded, then the update run from it and repair if verify still finds something; the private repository's token asked once and kept in `secrets.sh` (600) |
| `fedokawaii upgrade` | move to the next Fedora once it has settled: checks RPM Fusion, the COPRs, room and every library dwl needs first; snapshot; `dnf system-upgrade`; the rest by itself after the restart |
| `fedokawaii verify` (or `verify`) | full check, including your running session |
| `fedokawaii report [--quick \| --perf]` | the health report: `~/fedokawaii-report.txt`, about 700 checks in 29 areas (29: performance, every threshold a FAIL) — the verdict, the findings (each with what to do), every area's table, the logs, and a line per check to `diff` two runs; every program proved to run, not only installed. Made once by itself after the first start; a few minutes (`--quick`: without the timed tests); send it with any question |
| `fedokawaii repair` (or `repair`) | verify, then fix what can be fixed by itself — packages, drivers and firmware, anything doubled or fighting, services, your session, release tools, torrra, Prowlarr, drifted configs — and verify again; offline, what needs no network |
| `fedokawaii theme` · `fedokawaii drift` | apply the configs again (dwl rebuilt only if needed) · list files that differ |
| `fedokawaii status` · `snapshots` · `log` · `settings` · `remind` | how it stands (the last backup's day among it) · the snapshots · the last log · `fedokawaii.conf` · the season |
| `fedokawaii backup` (or `kawa-backup`; quick settings → backup) | your home — minus `~/Downloads`, caches and what can be downloaded again — to the drive `BACKUP_TARGET` names in `fedokawaii.conf` (it counts as soon as *settings* saves it), with restic; `kawa-backup restore PATH` brings a file or folder back into `~/Restored/`; a notice when the last backup is older than `BACKUP_REMIND_DAYS` (7) |
| `kawa-theme` | switch dark ⇄ light (`kawa-theme dark`, `light`, `get`) |
| `Super+/` | every keybinding, searchable |

### Changing it — Super+Shift+U

The desktop is changed in a **working copy** (`~/repos/fedokawaii`, a git repository of the
toolkit), never in the toolkit itself, so every update keeps the change (handbook, chapter 42):

| Command | Does |
|---|---|
| `fedokawaii copy` | makes the working copy, once |
| **Super+Shift+U** · `fedokawaii change` | every part by name, in five parts — 見 *look* (colours, bar, bar look, icons, notifications, launcher) · 手 *use* (keys, terminal, shell, files, drives, autostart) · 系 *system* (settings, packages, yours alone) · 史 *history* (what changed, history, apply) · 案 *help* (learn) — opened in neovim in the copy; *apply now* when you close it |
| `fedokawaii keep FILE` | a config you tried in place (`~/.config/…`), taken into the copy |
| `fedokawaii diff` | what the copy would change |
| `fedokawaii apply` | ShellCheck's advice, every script parsed, the copy made the toolkit (your saved settings merged in), then the theme — or repair, when packages or system parts changed |

Files the theme never writes are yours to edit in place: `~/.bashrc.d/local.sh`,
`~/.config/dwl/autostart.local.sh`, `~/.config/nvim/lua/plugins/local.lua`. The learning guide
(**Super+U** → *learn*) teaches every program by exercises, then Python and Rust up to a
transformer, fine-tuning and an agent. Chapters 43 and
44 of the handbook are about learning: which languages to learn and why, the ideas behind them
with an example each, where the reliable documentation is, and learning with an AI assistant.
Part IV (chapters 22–34) explains Linux itself from the ground up, on this machine: the boot,
files, users, processes and services, packages and how this desktop's pieces connect, the
graphics and sound stacks, D-Bus and the portals, and security; the commands by job and the
glossary are appendices D and E.

## 4 · First login, once

- **Prowlarr**: nothing to do — it is wired to torrra (its key's master copy is `~/.config/fedokawaii/secrets.sh`; Prowlarr gets
  it as a podman secret), its eight usual sites are in, and its page asks for no login (it answers on this computer only):
  `prowlarr` (or *Prowlarr* in the launcher) starts it on demand and opens <http://localhost:9696> (handbook §20.1).
- **Backups**: name your USB drive or external disk in `fedokawaii.conf` (`BACKUP_TARGET`, Super+U → settings), put a
  password in `~/.config/fedokawaii/secrets.sh` (`RESTIC_PASSWORD="…"` — keep a copy of it elsewhere: without it the backup
  cannot be read), plug the drive in, quick settings → *backup* (handbook §37.6).
- **Spotify**: *Spotify* in the launcher → sign in (free or Premium). It is Spotify's web player in a Brave app window;
  Theme switched on Widevine in Brave for it, and the bar's now-playing and meter follow it (handbook §15.4).
- **Syncplay** (watching a film with friends, in step): nothing to set — Theme started
  `~/.config/syncplay.ini` (the public server syncplay.pl, your name, a room of your own); **W** on a
  film in yazi, or *Syncplay* in the launcher, asks for the room (handbook §15.7).
- **Claude Code**: `claude` → log in. `/theme` → the *ANSI colours only* variant to use the palette.
- **Agents** (herdr): several Claude Code sessions in one window — *Agents* in the launcher, **Ctrl+B a** for
  each new one, **Ctrl+B Shift+G** for a git worktree of its own; the sidebar marks the one that needs you
  (handbook §44.3).
- **Brave Origin**: nothing to set — Theme put it in GTK mode, so it wears the palette and follows
  the dark/light switch, and starts it so a screen share can carry the computer's sound.

## 5 · Kernels and the boot menu

One kernel: the newest. After an update the one before stays as the way back only until the new one has reached the desktop; a quarter of an hour into that start it is removed (`fedokawaii-kernels.timer`, handbook §29.5). The themed boot menu shows for
`BOOT_MENU_SECONDS` (2 by default); set it to 0 for Fedora's hidden menu, which appears
only after a failed boot, or with **Shift** held (or **Esc** or **F8** pressed) as it starts. (Beside Windows, setup leaves the menu shown.) Re-run Theme after changing monitors so the
boot menu matches the new resolution.

## 6 · Self-tests

`bash tests/run.sh` runs every test file; `bash tests/run.sh drives` runs one area. Each file
works in a throw-away home with stand-ins ("stubs") for the hardware and services a helper
talks to — USB drives, monitors, sound, the network, dnf — so nothing on the machine is
touched, and no root, display or network is needed (bash, jq and python3 are). A failed check
prints what was expected and what came instead. The harness is `tests/lib/harness.sh`;
`tests/drives/test_drives.sh` is the worked example to copy. `run.sh` tests a throw-away copy
of the project in which every script (`#!`) is executable: a clone of this repository has no
executable bits (GitHub's upload page commits every file without them), and nothing here
depends on them — setup runs its scripts with `bash`, and the theme sets each file's mode.

## 7 · The first install on the real machine

Everything above was tested without the real hardware. On the PC itself:

| What | How it is checked |
|---|---|
| the graphics card (RX 9060 XT): video decoding, Vulkan, the settings LACT needs | by itself: `verify.sh` at the end of setup — the login is not switched on until it passes; `fedokawaii verify` repeats it any time |
| every device has its driver; Bluetooth's service is on | by itself, the same way |
| the old Windows disk is really cleared | your eyes, in the installer: *SUMMARY OF CHANGES* lists Windows' parts as deleted, and four new ones made — `/boot/efi`, `/boot`, `/`, `/home`. If `/boot/efi` is missing, go back |
| the Bluetooth controller | plug its dongle in **before** setup, so setup sees it; afterwards pair it: **Super+X** → *devices* (it opens *pair a device*, handbook §8.3) |
| the controller does not lag or drop | play a while: setup already keeps the dongle from sleeping (`/etc/modprobe.d/fedokawaii-btusb.conf`). If it still lags, the stronger version keeps every USB device awake: `sudo grubby --update-kernel=ALL --args=usbcore.autosuspend=-1`, then restart |
| btop shows the graphics card | your eyes: open btop (click the bar's memory part) — one line in the CPU box, `GPU`, then the card's load, memory, heat and watts; **5** opens its full box (**Super+F** first: it needs the room). Nothing there: `fedokawaii verify` says whether rocm-smi has the library btop opens |
| how long each phase takes | optional: note the times — the handbook's are estimates |
