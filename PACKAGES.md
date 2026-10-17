# Fedokawaii — software list

One tool per job. The authoritative list is `lib/manifest.sh` (packages) and `lib/upstream.sh`
(release binaries); `verify.sh` proves the machine matches them exactly. Every name was checked
for **Fedora 44 and 45** on 15 Oct 2026. No Flatpak, no Snap, no fallbacks.

Source: **F** Fedora · **RF** RPM Fusion · **V** vendor repo (signed) · **C** COPR · **GH** GitHub release (pinned: an exact version and its SHA-256, measured here) · **pipx** · **podman**

## By job

| Job | Tool | Source | Notes |
|---|---|---|---|
| Compositor | dwl 0.9 | git (Codeberg) | built with XWayland on; a small patch (`src/dwl/dwl.patch`): gaps, retro window frames on one window at a time, centred floating windows, keybindings that work in the Arabic layout, menus that close on a click outside, monitors plugged in later set up again (`kawa-display --hotplug`), the keyboard layout reported to the bar (and said again if the bar fell behind) |
| Transitions | `kawa-veil` | this repository (`src/kawa-veil`, C) | the theme and wallpaper changes; built by theme.sh with dwl's build tools — nothing extra installed |
| Clipboard keeper | `kawa-clipkeep` | this repository (`src/kawa-clipkeep`, C) | a copy stays after its program closes; the usual tool for this (wl-clip-persist) is not packaged for Fedora |
| Login | greetd (agreety) + greetd-selinux | F | plain text login: user name, password; SELinux policy is a separate package on Fedora |
| Terminal | foot (server + footclient) | F | |
| Shell | bash + bash-completion | F | native prompt, OSC 7 / 133 for foot |
| Shell helpers | fzf · zoxide · eza · tldr | F | Ctrl+R / Ctrl+T / Alt+C · a `cd` that learns your folders · `ls` with git status and trees · `tldr` examples |
| Editor | neovim + LazyVim + tree-sitter-cli | F + git | nano / vim-minimal are **removed** |
| Browser | Brave Origin | V | free on Linux; Shields only; in GTK mode, so it wears the palette |
| AI | Claude Code | V (`downloads.claude.ai`, key fingerprint checked) | |
| Launcher + all menus | fuzzel | F | `--dmenu` for quick settings, power, audio, calendar, brightness, screen-share picker, help (the wallpaper and clipboard windows are fzf) |
| Bar | waybar | F | dwl tags via `kawa-dwlstatus`; its own clock module (seconds, no script) |
| Notifications | mako + libnotify | F | |
| Lock / idle | swaylock · swayidle | F | the power menu is a fuzzel menu (`kawa-power`); away, nothing locks or sleeps (the screens go dark after an hour); a lock you ask for (Super+Escape) sleeps 90 s later; sleep is suspend only — hibernation off (`/etc/systemd/sleep.conf.d/90-fedokawaii.conf`) |
| Level display | mako (category `osd`) | F | `kawa-osd`: volume, microphone, brightness — no separate OSD program |
| Wallpaper | swaybg | F | |
| Outputs | wlr-randr · wlopm | F | `kawa-display` picks the best refresh rate ≤ `MONITOR_HZ` · `wlopm` powers screens off when idle without moving windows |
| Clipboard | wl-clipboard + cliphist + fzf | F | Super+V: the history in a small window (fzf), pictures previewed in the terminal (ImageMagick draws them as sixels) |
| Screenshots | grim + slurp + satty | F + GH | satty needs gtk4 + libadwaita (listed) |
| Night light | gammastep | F | |
| Audio | PipeWire + WirePlumber (+ pulse/alsa shims) + pipewire-utils | F | wiremix (the mixer: a terminal program, in a floating window, in the theme's colours), EasyEffects, playerctl; `pw-dump` feeds the audio menu |
| Music meter | cava | F | the bar's spectrum meter, only while sound plays (sleeps through silence) |
| Monitor brightness | ddcutil | F | DDC/CI, like Twinkle Tray on Windows |
| Bar clicks | wtype | F | clicking a workspace presses its key (Super+1…9) |
| Portals | xdg-desktop-portal-wlr + -gtk | F | screen share (with the `kawa-share` picker) / file dialogs / dark mode |
| File dialogs | xdg-desktop-portal-termfilechooser 1.4.3 + yazi (`kawa-pick`) | git (GitHub, pinned commit) | not packaged for Fedora: built by setup.sh like dwl (meson + inih-devel + systemd-devel, kept); Brave's and GTK programs' Open/Save dialogs are yazi in a floating terminal; the GTK dialog stays as the fallback |
| Terminal for apps | xdg-terminal-exec | F | programs that ask for a terminal get foot |
| Auth dialogs | lxqt-policykit | F | |
| USB drives | udiskie + udisks2 + `kawa-drives` · exfatprogs · dosfstools · ntfs-3g | F | sticks, disks and SD cards open by themselves under `/run/media/$USER`; `kawa-drives` gives the notices, the bar's drive mark, yazi's **M** and the eject that says "safe to unplug"; exFAT and FAT tools check, repair and name the usual sticks; ntfs-3g opens NTFS whether or not the kernel has its own NTFS driver (Fedora's kernels have changed which one they build) |
| Bluetooth | bluez + bluetui | F + GH (musl, SHA-256 pinned) | controller dongle; pairing in a floating terminal window (quick settings → *pair a device*) |
| Files | yazi + 7zip + file | GH (musl) + F | 7-Zip: archive previews and extraction; `file`: types |
| Office | AbiWord + Gnumeric | F | |
| Reading | zathura (+ mupdf, cb) · bsdtar | F | PDF, EPUB, CBZ; bsdtar opens comics for the books window's covers and page counts |
| PDF tools | qpdf · poppler-utils · ghostscript · xournalpp | F | merge, split, rotate, password · images and text out · compress · annotate and sign |
| Text from pictures (OCR) | tesseract (+ English, Arabic) | F | scans and screenshots to text, and searchable PDFs |
| Slides | presenterm | GH (musl, SHA-256 pinned) | |
| Images | imv + ImageMagick (+ -heic) + libheif-freeworld | F + RF | convert, resize, compress — phone (HEIC) photos too; ImageMagick also draws the pixel art, the wallpapers and the boot menu background |
| QR codes | qrencode | F | a link or Wi-Fi details as a QR code, in the terminal or as a PNG |
| Screen recording | wf-recorder | F | the whole screen or a region (slurp) to MP4, with or without sound |
| Calculator | qalc (`qalculate`) | F | |
| Video | mpv + mpv-mpris + yt-dlp + nodejs24 (+ -bin, -npm-bin) | F | mpv-mpris: mpv in the bar and on the media keys; Node.js: yt-dlp's JavaScript runtime for YouTube, and npm for Mason's language servers |
| Watching together | Syncplay 1.7.6 (no window) | git (GitHub, pinned commit) + F | its source at the v1.7.6 tag's commit with two fixes of ours (src/syncplay/syncplay.patch: mpv waited for at the start, the window closed with mpv), run by Fedora's python3 with python3-twisted (+tls) · python3-pyOpenSSL · python3-certifi · python3-pem (lib/upstream.sh); Fedora's syncplay package is left out: it brings PySide6 and 27 Qt modules for a window never used. `kawa-together`: the room, then Syncplay beside mpv; pause, seek, ready and chat reach friends through a public server (syncplay.pl) |
| Codecs | ffmpeg (full) | RF | replaces ffmpeg-free |
| Music | spotify_player | GH (sha256) | Premium |
| Torrents | torrra (on Python 3.13) + Prowlarr | pipx + podman | libtorrent has no Python 3.14 wheel yet; its libraries pinned to torrra 2.5.1's own lock (`system/torrra-constraints.txt`; libtorrent and certifi left free); `kawa-torrra` hands torrra the key from `secrets.sh` |
| Git | git + lazygit | F + GH | lazygit from its own release, pinned like yazi (its COPR is no longer kept) |
| Script checking | ShellCheck | F | `fedokawaii apply` reads the scripts you changed with it; every finding has a page (SC number) that explains it |
| System monitor | btop (+ rocm-smi on AMD) | F | rocm-smi is the ROCm SMI library btop opens to read the card: load, memory, heat and watts in the CPU box, and a GPU box on **5** |
| Tables in the terminal | visidata (`vd`) · sc-im | F | `vd file.csv`: CSV, TSV, JSON and SQLite — sort, sum, filter, group, save; the default for CSV and TSV files (a `.xlsx` needs python3-openpyxl, which is not installed: Excel files stay with Gnumeric) · sc-im: a vi-like spreadsheet for `.sc` files and quick sums |
| Disk usage | gdu | F | `gdu ~`: what fills a folder, largest first; **d** deletes |
| Search / view | ripgrep · fd-find · bat | F | rg and fd also power LazyVim's pickers |
| Performance | tuned | F | the `fedokawaii` profile: throughput-performance for an always-plugged desktop |
| Fetch | `fetch` (own, pure bash) | repo | ten pixel pictures; replaces fastfetch |
| Snapshots | snapper | F | Timeshift can't use Fedora's subvolume names |
| Backups | restic | F | your home to a USB drive, an external disk or a restic address, deduplicated and encrypted; `kawa-backup` runs it (quick settings → backup) — nothing on a timer, the drive may not be plugged in |
| Containers | podman | F | for Prowlarr |
| GPU | Mesa freeworld VA-API · LACT · rocm-smi | RF + C + F | amdgpu feature mask for LACT; rocm-smi: the library btop reads the card through (AMD only); while RPM Fusion is behind this Fedora's Mesa, or the COPR has no build for it, they wait (recorded, Fedora's drivers standing in) and update or repair adds them |
| Peripherals | OpenRGB | F | RGB lighting on the motherboard's headers; fan speeds are the motherboard firmware's (§21.2) |
| Gaming | Steam · gamescope · gamemode · MangoHud · GE-Proton · ntsync-autoload · steam-devices | RF + F + GH | GE-Proton keeps the newest two; ntsync: Proton's faster synchronisation |
| Fonts | JetBrainsMono Nerd · DepartureMono Nerd · PixelMplus 12 · Sumi Icons · Terminus (console) · Noto Sans · Noto Sans CJK · Noto Naskh Arabic · Noto Kufi Arabic · Amiri · Noto Color Emoji · Liberation | GH + F + repo | Departure = the pixel UI font; PixelMplus = Japanese in the pixel UI and the terminal; Noto Sans CJK = Japanese, Chinese, Korean in programs and subtitles; Sumi Icons = this desktop's icons; Kufi = Arabic in the pixel UI (bar, menus, notices); Liberation = metric-compatible fonts for office files |
| Look | adw-gtk3 · qt6ct · Papirus · dconf · pointers drawn here (Adwaita beneath for rare shapes) | F + repo | dark/light switched live by `kawa-theme`; the pixel pointers come from `art/cursors.txt` |
| Build (kept) | gcc · make · pkgconf · wayland/wlroots/xcb devel | F | theme.sh rebuilds dwl when you change a keybind, and builds kawa-veil and kawa-clipkeep |
| Script plumbing | dnf5-plugins · git · jq · gnupg2 · tar · grubby · diffutils · man-db · libva-utils · libdnf5-plugin-actions | F | used by setup.sh / verify.sh; tar unpacks the release archives and GE-Proton, grubby sets the kernel arguments (neither is in a Minimal Install's `@core`; the installer adds grubby only on a UEFI machine); diff / cmp compare the copy and the toolkit, man opens the manuals the change menu lists (both usually present: listed, never assumed); actions = a snapshot pair around every dnf run |
| Drivers and firmware | fwupd · pciutils · usbutils, and what this machine needs (`lib/hardware.sh`): microcode_ctl or amd-ucode-firmware, NetworkManager-wifi + wireless-regdb, alsa-sof-firmware, the firmware the kernel asked for (iwlwifi-…-firmware and the like), intel-media-driver beside an AMD card | F + RF | fwupd: device firmware from the LVFS, applied only by you · lspci / lsusb: which device, which driver · the per-machine packages are found from the hardware at setup, update and repair, and recorded in `/var/lib/fedokawaii/hardware-pkgs` (part of the manifest from then on) |
| Base | NetworkManager · sudo | F | already in @core — listed so they are marked as yours and dnf's clean-up never takes them |
| Base | NetworkManager-tui · xorg-x11-server-Xwayland · xdg-utils · xdg-user-dirs | F | nmtui (quick settings → network) · X11 programs · `xdg-open` · `~/Pictures`… |
| GPU base | mesa-dri-drivers · mesa-vulkan-drivers · vulkan-loader · linux-firmware · amd-gpu-firmware (AMD) · intel-media-driver (Intel) | F + RF | Vulkan: Fedora's own on both (RPM Fusion's freeworld Vulkan build adds only Vulkan's H.264/HEVC video, unused here, and its 64- and 32-bit packages have clashed); VA-API: the freeworld build on AMD, Intel's driver from RPM Fusion |
| Repositories | rpmfusion-free-release · rpmfusion-nonfree-release | RF | |

## Never present (verify.sh fails if any appear)

Editors other than neovim (nano, nano-default-editor, vim-minimal, vim-enhanced, vim-default-editor, emacs) · the rescue kernel (dracut-config-rescue) · browsers other than Brave
Origin (firefox, chromium, brave-browser) · other terminals and launchers (alacritty, kitty, xterm,
konsole, gnome-terminal, rofi, wofi, wmenu, bemenu) · second polkit agents and tray NM
(polkit-gnome, hyprpolkitagent, network-manager-applet) · flatpak, snapd, PackageKit,
gnome-software · ffmpeg-free · tuigreet, wlogout, fastfetch, neofetch (replaced by agreety,
fuzzel menus and the own `fetch`) · pavucontrol, blueman (replaced by wiremix and bluetui, in
terminal windows) · second notification daemons (dunst, SwayNotificationCenter: swaync) ·
power-profiles-daemon (tuned only) · other login managers (gdm, sddm, lightdm, lxdm) ·
systemd-oomd-defaults (systemd-oomd's rules: its out-of-memory killer acts on whole cgroups, so
under memory pressure it can end the whole desktop session, where every program runs; the
kernel's own OOM killer stays) · mesa-vulkan-drivers-freeworld (Vulkan: Fedora's own) · on AMD, the non-freeworld mesa-va-drivers.
PackageKit is also kept from arriving as a weak dependency (dnf's `exclude_from_weak`: PackageKit-Qt6 recommends it).

On top of that list, verify.sh compares everything *user-installed* against a snapshot taken
before setup started plus the manifest — anything else is reported by name.

## Removed since the previous version, and why

| Removed | Why |
|---|---|
| a separate clock script | waybar's own clock module shows seconds and wakes on the second by itself |
| tuigreet, wlogout, fastfetch | agreety (part of greetd), a fuzzel power menu, the own `fetch` |
| npm for Claude Code | Claude Code now ships an official signed dnf repo (Node.js and npm are back, for yt-dlp and Mason — see below) |
| Rust + cargo (+ openssl/alsa/dbus devel, cmake) | yazi, presenterm, spotify_player, bluetui come as release binaries — 15 min faster setup |
| GStreamer plugins + `@multimedia` group | nothing installed uses GStreamer (mpv = ffmpeg; Brave and Steam bundle their own) |
| x264, x265, svt-av1, libaom, dav1d, opus, lame, flac, … CLI/lib packages | pulled in by ffmpeg where needed; the CLI encoders duplicated ffmpeg |
| google-noto-sans-arabic-fonts | fontconfig sends Arabic to Noto Naskh; Sans Arabic was never used |
| starship (COPR) | native bash prompt, no process per prompt |
| bluez-tools, polkit/xdg-desktop-portal listed explicitly | unused, or already dependencies (udisks2 is listed again: nothing but a weak dependency brings it) |
| `settings.ini` for GTK | GTK reads GSettings (dconf) on Wayland — single source |
| unzip | 7zip opens zip files too (`7z x`) |
| mediainfo | ffprobe (part of ffmpeg) tells the same about a video or song |
| pavucontrol, blueman | terminal programs first: wiremix (Fedora's package) is the mixer, bluetui (GitHub release, pinned) pairs devices — both open in a floating foot window and wear the theme; no GTK window, nothing to start at login |
| Brave flags file | Chromium ≥ 140 picks Wayland automatically |
| `keepcache`, `skip_if_unavailable`, `clean_requirements_on_remove` in dnf config | already Fedora's defaults |
| lazygit's COPR (dejan/lazygit) | its description says it is no longer maintained; lazygit now comes from its GitHub release, pinned (SHA-256) |
| solaar, liquidctl | nothing to drive on this machine: the mouse (on a USB receiver) needs no app, and the cooler is an air cooler — liquidctl is for liquid coolers and fan hubs |

## Added since the previous version, and why

| Added | Why |
|---|---|
| cava | the bar's music meter (one small process, asleep whenever nothing plays) |
| terminus-fonts-console | a crisp, larger font on the text console (login, Ctrl+Alt+F2…) |
| greetd-selinux | without it SELinux can block the login on Fedora |
| tree-sitter-cli | required by LazyVim's nvim-treesitter (`main` branch) |
| ShellCheck | changing the desktop's scripts yourself (chapter 42 of the handbook): it catches the mistakes bash lets through |
| python3.13 | torrra's libtorrent has wheels only up to 3.13 |
| libnotify | `notify-send`, used by the helpers |
| gtk4, libadwaita | runtime libraries of the satty binary |
| dconf, adwaita-cursor-theme, gnupg2 | dark-mode settings · cursor · key fingerprint check |
| diffutils, man-db | `diff` / `cmp`: the working copy against the toolkit, the checks · `man`: the manuals the change menu opens (both usually on the minimal install; listed so they are never assumed) |
| wlopm | screens off when idle without moving windows |
| tuned | the always-plugged performance profile |
| xdg-terminal-exec | programs that ask for a terminal get foot |
| mpv-mpris | mpv in the bar's *now playing* and on the media keys |
| nodejs24, nodejs24-bin, nodejs24-npm-bin | yt-dlp solves YouTube's JavaScript challenges with it (Node.js 24; -bin gives the plain `node` command); `npm` installs Mason's language servers in neovim |
| fzf | the clipboard and wallpaper windows; the shell's Ctrl+R, Ctrl+T and Alt+C; yazi's fuzzy jump |
| zoxide | `cd` learns the folders you use: `cd proj` jumps to ~/repos/project from anywhere; yazi's `Z` uses the same list |
| eza | `ls` / `ll` / `lt`: folders first, git status per file, trees |
| tldr | `tldr tar`: the five commands you actually wanted, instead of the whole man page (Fedora's own client: tealdeer leaves Fedora with release 45) |
| ghostscript | shrink a PDF (what the "compress PDF" websites do) |
| tesseract, -langpack-eng, -langpack-ara | text out of scans, photos and screenshots, English and Arabic |
| ImageMagick-heic | opens and converts phone photos (HEIC) |
| libheif-freeworld (RPM Fusion) | the HEVC decoder iPhone photos need — Fedora's own libheif cannot read them |
| qrencode | QR codes without a website |
| wf-recorder | screen recordings (the screenshot tools do stills only) |
| 7zip, file | yazi's archive previews and extraction; file types for the clipboard window |
| google-noto-sans-cjk-vf-fonts | Japanese, Chinese and Korean in programs, web pages and subtitles |
| ntsync-autoload | Proton's faster synchronisation (with Steam) |
| steam-devices | the rules that let Steam open a game controller (Bluetooth or USB); Steam brings it today — listed so dnf's clean-up can never take it |
| fwupd, pciutils, usbutils | firmware inside the devices (SSD, motherboard, dock), offered by update and applied by you · which device is which, and which driver holds it |
| exfatprogs, dosfstools, ntfs-3g | the USB drives: check, repair and name exFAT and FAT sticks; NTFS opens whatever NTFS driver the kernel has |
| python3, glib2, fontconfig | already there as other packages' dependencies; listed so they are never assumed: the helpers' Python parts and the self-tests · `gsettings`, `gio` · `fc-match`, `fc-cache` |
| tar, grubby | not on a Minimal Install (grubby only on UEFI machines): unpacking the toolkit and the kernel's boot options |
| visidata, sc-im | tables in the terminal: `vd` opens a CSV at once (sort, sum, filter, group — like ORDER BY, SUM, WHERE, GROUP BY), sc-im is a spreadsheet with vi keys; Gnumeric stays for Excel files |
| gdu | what fills the disk, folder by folder, with a delete key — the question `space` (handbook §25.6) cannot answer |
| rocm-smi (AMD) | the ROCm SMI library btop opens to show the graphics card; without it btop finds no GPU |
