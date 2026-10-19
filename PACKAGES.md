# Fedokawaii — software list

One tool per job. The authoritative list is `lib/manifest.sh` (packages) and `lib/upstream.sh`
(release binaries); `verify.sh` proves the machine matches them exactly. Every name was checked
for **Fedora 44 and 45** on 15 Oct 2026 (LibreOffice's parts and the dictionaries on 17 Oct). No Flatpak, no Snap, no fallbacks.

Source: **F** Fedora · **RF** RPM Fusion · **V** vendor repo (signed) · **C** COPR · **GH** GitHub release (pinned: an exact version and its SHA-256, measured here) · **pipx** · **podman**

## By job

| Job | Tool | Source | Notes |
|---|---|---|---|
| Compositor | dwl 0.9 | git (Codeberg) | built with XWayland on; a small patch (`src/dwl/dwl.patch`): gaps, retro window frames on one window at a time, centred floating windows, keybindings that work in the Arabic layout, menus that close on a click outside, monitors plugged in later set up again (`kawa-display --hotplug`), the keyboard layout reported to the bar (and said again if the bar fell behind) |
| Transitions | `kawa-veil` | this repository (`src/kawa-veil`, C) | the theme and wallpaper changes; built by theme.sh with dwl's build tools — nothing extra installed |
| Clipboard keeper | `kawa-clipkeep` | this repository (`src/kawa-clipkeep`, C) | a copy stays after its program closes; the usual tool for this (wl-clip-persist) is not packaged for Fedora |
| Login | greetd + greetd-selinux · `kawa-greet` in cage | F + this repository (`system/kawa-greet`, Python + GTK 3) | the lock screen's twin: the day's seal, the padlock, the time, one box for your password (your user name is set by setup); cage, a kiosk compositor, shows it; SELinux policy is a separate package on Fedora |
| Boot splash | Plymouth (script plugin) | F + this repository (`system/plymouth/sumi`) | the sumi splash while the disk unlocks and the system starts |
| Terminal | foot (server + footclient) | F | |
| Shell | bash + bash-completion · ble.sh | F + git (pinned commit) | native prompt, OSC 7 / 133 for foot; ble.sh (the Bash Line Editor) types for it: the line coloured as you type, a grey suggestion from your history, a completion menu — in the terminal's 16 colours, so it follows the theme |
| Shell helpers | fzf · zoxide · eza · bat · tldr | F | Ctrl+R / Ctrl+T / Alt+C · a `cd` that learns your folders · `ls` with git status and trees · `cat` in syntax colours · `tldr` examples |
| Editor | neovim + LazyVim + tree-sitter-cli | F + git | nano / vim-minimal are **removed** |
| Browser | Brave Origin | V | free on Linux; Shields only; in GTK mode, so it wears the palette |
| AI | Claude Code | V (`downloads.claude.ai`, key fingerprint checked) | |
| AI agents side by side | herdr | GH (static, SHA-256 pinned) | several Claude Code sessions in panes of one terminal window (launcher → *Agents*), each marked working, blocked or idle in a sidebar; a git worktree per task on one key; a notice (mako) when one finishes or asks. Its own multiplexer and server, so no tmux; Claude Squad (needs tmux, AGPL, last release August 2026) was the other candidate. Its update and rule-download checks are off: it stays the pinned release |
| Launcher + all menus | fuzzel | F | through `kawa-menu`: power, audio, calendar, drives, help, change, shrink, screen-share picker (the wallpaper and clipboard windows are fzf) |
| Quick settings | `kawa-panel` + gtk-layer-shell | this repository (Python + GTK 3) + F | the panel under the bar's cat (Super+X): brightness, sound, the tiles; GTK 3 and Python's GObject come with the login screen |
| Bar | waybar | F | dwl tags via `kawa-dwlstatus`; its own clock module (seconds, no script) |
| Notifications | mako + libnotify | F | |
| Lock / idle | gtklock · swayidle | F | the power menu is a fuzzel menu (`kawa-power`); away, nothing locks or sleeps (the screens go dark after an hour); a lock you ask for (Super+Escape) sleeps 90 s later; sleep is suspend only — hibernation off (`/etc/systemd/sleep.conf.d/90-fedokawaii.conf`) |
| Level display | mako (category `osd`) | F | `kawa-osd`: volume, microphone, brightness — no separate OSD program |
| Wallpaper | swaybg | F | |
| Outputs | wlr-randr · wlopm · wayland-utils | F | `kawa-display` picks the best refresh rate ≤ `MONITOR_HZ` · `wlopm` powers screens off when idle without moving windows · `wayland-info` lists what the compositor offers (the health report) |
| Clipboard | wl-clipboard + cliphist + fzf | F | Super+V: the history in a small window (fzf) — text and pictures (screenshots, Brave's *Copy image*), the last 100, none over 20 MiB (`kawa-clip --store` behind `wl-paste --watch`); pictures previewed in the terminal (ImageMagick draws them as sixels) and copied back as pictures |
| Screenshots | grim + slurp + satty | F + GH | satty needs gtk4 + libadwaita (listed) |
| Night light | gammastep | F | |
| Audio | PipeWire + WirePlumber (+ pulse/alsa shims) + pipewire-utils | F | wiremix (the mixer: a terminal program, in a floating window, in the theme's colours), EasyEffects, playerctl; `pw-dump` feeds the audio menu, `pw-play` sounds the timer's chime |
| Music meter | cava | F | the bar's spectrum meter, only while sound plays (sleeps through silence) |
| Monitor brightness | ddcutil | F | DDC/CI, like Twinkle Tray on Windows |
| Bar clicks | wtype | F | clicking a workspace presses its key (Super+1…9) |
| Portals | xdg-desktop-portal-wlr + -gtk | F | screen share (with the `kawa-share` picker; one question per share: transient restore tokens for screens, `XDPW_PERSIST_MODE`, 0.7+; a window's choice remembered 10 s by `kawa-share`) / file dialogs / dark mode |
| File dialogs | xdg-desktop-portal-termfilechooser 1.4.3 + yazi (`kawa-pick`) | git (GitHub, pinned commit) | not packaged for Fedora: built by setup.sh like dwl (meson + inih-devel + systemd-devel, kept); Brave's and GTK programs' Open/Save dialogs are yazi in a floating terminal; the GTK dialog stays as the fallback — and is LibreOffice's: it builds GTK's dialog itself, never asking the portal |
| Terminal for apps | xdg-terminal-exec | F | programs that ask for a terminal get foot |
| Auth dialogs | lxqt-policykit | F | |
| USB drives | udiskie + udisks2 + `kawa-drives` · exfatprogs · dosfstools · ntfs-3g | F | sticks, disks and SD cards open by themselves under `/run/media/$USER`; `kawa-drives` gives the notices, the bar's drive mark, yazi's **M** and the eject that says "safe to unplug"; exFAT and FAT tools check, repair and name the usual sticks; ntfs-3g opens NTFS whether or not the kernel has its own NTFS driver (Fedora's kernels have changed which one they build) |
| Bluetooth | bluez + bluetui | F + GH (musl, SHA-256 pinned) | controller dongle; pairing in a floating terminal window (quick settings → *pair a device*) |
| Files | yazi + 7zip + file | GH (musl) + F | 7-Zip: archive previews and extraction; `file`: types |
| Office | LibreOffice Writer · Calc · Impress + libreoffice-gtk3 · hunspell-en · hunspell-ar | F | open and edit Word, Excel and PowerPoint files (and OpenDocument), the defaults for them (a `.csv` stays VisiData's); drawn by GTK 3, so it follows the theme; English and Arabic spelling — Arabic is its right-to-left language here (`/etc/dconf`, Theme). Only these three: no Base, Draw or Math; Java and the offline help are never taken as weak dependencies |
| Reading | zathura (+ mupdf, cb) · bsdtar | F | PDF, EPUB, CBZ; bsdtar opens comics for the books window's covers and page counts |
| PDF tools | qpdf · poppler-utils · ghostscript · xournalpp | F | merge, split, rotate, password · images and text out · compress · annotate and sign |
| Text from pictures (OCR) | tesseract (+ English, Arabic) | F | scans and screenshots to text, and searchable PDFs |
| Images | imv + ImageMagick (+ -heic) + libheif-freeworld | F + RF | convert, resize, compress — phone (HEIC) photos too; ImageMagick also draws the pixel art, the wallpapers and the boot menu background |
| QR codes | qrencode | F | a link or Wi-Fi details as a QR code, in the terminal or as a PNG |
| Screen recording | wf-recorder | F | the whole screen or a region (slurp) to MP4, with or without sound |
| Calculator | qalc (`qalculate`) | F | |
| Video | mpv + mpv-mpris + yt-dlp + nodejs24 (+ -bin, -npm-bin) | F | mpv-mpris: mpv in the bar and on the media keys; Node.js: yt-dlp's JavaScript runtime for YouTube, and npm for Mason's language servers |
| Watching together | Syncplay 1.7.6 (no window) | git (GitHub, pinned commit) + F | its source at the v1.7.6 tag's commit with two fixes of ours (src/syncplay/syncplay.patch: mpv waited for at the start, the window closed with mpv), run by Fedora's python3 with python3-twisted (+tls) · python3-pyOpenSSL · python3-certifi · python3-pem (lib/upstream.sh); Fedora's syncplay package is left out: it brings PySide6 and 27 Qt modules for a window never used. `kawa-together`: a small form (server, room, name, password, film; your last choice ready, Enter rejoins it), then Syncplay beside mpv; pause, seek, ready and chat reach friends through a public server (syncplay.pl) |
| Codecs | ffmpeg (full) | RF | replaces ffmpeg-free |
| Music | Spotify's web player | — (Brave Origin) | open.spotify.com in a Brave app window (`spotify.desktop`), free or Premium; Widevine switched on once in Brave (Theme); Brave's MPRIS: the bar's now-playing and meter, the media keys |
| Torrents | torrra (on Python 3.13) + Prowlarr | pipx + podman | libtorrent has no Python 3.14 wheel yet; its libraries pinned to torrra 2.5.1's own lock (`system/torrra-constraints.txt`; libtorrent and certifi left free); `kawa-torrra` hands torrra the key from `secrets.sh` |
| Git | git + lazygit | F + GH | lazygit from its own release, pinned like yazi (its COPR is no longer kept) |
| Script checking | ShellCheck | F | `fedokawaii apply` reads the scripts you changed with it; every finding has a page (SC number) that explains it |
| System monitor | btop (+ rocm-smi on AMD) | F | rocm-smi is the ROCm SMI library btop opens to read the card: load, memory, heat and watts in the CPU box, and a GPU box on **5** |
| Tables in the terminal | visidata (`vd`) | F | `vd file.csv`: CSV, TSV, JSON and SQLite — sort, sum, filter, group, save; the default for CSV and TSV files (a `.xlsx` needs python3-openpyxl, which is not installed: Excel files are LibreOffice Calc's) |
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
| Fonts | Fusion Pixel 12 · JetBrainsMono Nerd · Sumi Icons · Terminus (console) · Noto Sans · Noto Sans CJK · Noto Naskh Arabic · Noto Kufi Arabic · Amiri · Noto Color Emoji · Liberation | GH + F + repo | Fusion Pixel = the one pixel font: Latin, kana and kanji in one face — the terminal at 24 px (on 26 px lines), the bar, menus and notices at 12 px, the lock and login screens, the boot menu; JetBrainsMono Nerd = the apps' monospace and the Nerd Font symbols programs draw; Noto Sans CJK = Japanese, Chinese, Korean in programs and subtitles; Sumi Icons = this desktop's icons; Kufi = Arabic in the pixel UI (bar, menus, notices); Liberation = metric-compatible fonts for office files |
| Look | adw-gtk3 · qt6ct · dconf · pointers drawn here (Adwaita beneath for rare shapes) | F + repo | dark/light switched live by `kawa-theme`; the pixel pointers come from `art/cursors.txt`; icons: each program's own (hicolor), under GTK's Adwaita — no icon pack; windows, dialogs, buttons square (the GTK themes) |
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
gnome-software · ffmpeg-free · tuigreet, gtkgreet, wlogout, fastfetch, neofetch (replaced by
kawa-greet, fuzzel menus and the own `fetch`) · swaylock (the lock: gtklock only) · pavucontrol, blueman (replaced by wiremix and bluetui, in
terminal windows) · second notification daemons (dunst, SwayNotificationCenter: swaync) ·
power-profiles-daemon (tuned only) · other login managers (gdm, sddm, lightdm, lxdm) ·
AbiWord, Gnumeric, sc-im (replaced by LibreOffice) · systemd-oomd-defaults (systemd-oomd's rules: its out-of-memory killer acts on whole cgroups, so
under memory pressure it can end the whole desktop session, where every program runs; the
kernel's own OOM killer stays) · mesa-vulkan-drivers-freeworld (Vulkan: Fedora's own) · on AMD, the non-freeworld mesa-va-drivers.
PackageKit is also kept from arriving as a weak dependency (dnf's `exclude_from_weak`: PackageKit-Qt6 recommends it), and so are Java and LibreOffice's offline help (LibreOffice recommends them; Writer, Calc and Impress need neither).

On top of that list, verify.sh compares everything *user-installed* against a snapshot taken
before setup started plus the manifest — anything else is reported by name.

## Removed since the previous version, and why

| Removed | Why |
|---|---|
| a separate clock script | waybar's own clock module shows seconds and wakes on the second by itself |
| tuigreet, wlogout, fastfetch | kawa-greet (the login screen), a fuzzel power menu, the own `fetch` |
| npm for Claude Code | Claude Code now ships an official signed dnf repo (Node.js and npm are back, for yt-dlp and Mason — see below) |
| Rust + cargo (+ openssl/alsa/dbus devel, cmake) | yazi and bluetui come as release binaries — 15 min faster setup |
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
| AbiWord, Gnumeric | LibreOffice Writer and Calc open *and edit* Word and Excel files, tracked changes and complex layouts included; update removes them |
| sc-im | one spreadsheet is enough: Calc for formulas, VisiData for looking at data |
| presenterm (release binary) | slides are Impress's, which opens and shows PowerPoint files; update takes the binary and its theme link out |
| spotify_player (release binary) | Spotify's web player instead (a free account works too); update takes the binary and its settings out |
| lpf, lpf-spotify-client, spotify-client | Spotify's own app, built here by lpf from RPM Fusion's recipe — until the recipe pointed at a download Spotify had taken down (Oct 2026); its web player in a Brave app window does the same. Update hands the three back to dnf, and repair removes lpf's account (pkg-build) and /var/lib/lpf |
| papirus-icon-theme | every program shows its own icon, as its package ships it (the launcher, GTK, Qt, the notices): no icon pack over them; update hands it back to dnf |

## Added since the previous version, and why

| Added | Why |
|---|---|
| cava | the bar's music meter (one small process, asleep whenever nothing plays) |
| libreoffice-writer, -calc, -impress, -gtk3 | open and edit Word, Excel and PowerPoint files; the GTK 3 part draws it in the desktop's theme |
| hunspell-en, hunspell-ar | spelling in English and Arabic, as you type in LibreOffice |
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
| visidata | tables in the terminal: `vd` opens a CSV at once (sort, sum, filter, group — like ORDER BY, SUM, WHERE, GROUP BY); Excel files are LibreOffice Calc's |
| gdu | what fills the disk, folder by folder, with a delete key — the question `space` (handbook §25.6) cannot answer |
| ble.sh (from its source, a pinned commit) | fish's comforts in bash: the line coloured as you type (an unknown command in vermilion before it runs), a suggestion from your history to take with →, a completion menu. Not packaged by Fedora; its tagged releases (2023) predate bash 5.3, so it is built from a pinned commit, as Syncplay is (make and gawk, no compiler) |
| rocm-smi (AMD) | the ROCm SMI library btop opens to show the graphics card; without it btop finds no GPU |
