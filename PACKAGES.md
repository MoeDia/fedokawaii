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
| Lock / idle | swaylock · swayidle | F | the power menu is a fuzzel menu (`kawa-power`) |
| Level display | mako (category `osd`) | F | `kawa-osd`: volume, microphone, brightness — no separate OSD program |
| Wallpaper | swaybg | F | |
| Outputs | wlr-randr · wlopm | F | `kawa-display` picks the best refresh rate ≤ `MONITOR_HZ` · `wlopm` powers screens off when idle without moving windows |
| Clipboard | wl-clipboard + cliphist + fzf | F | Super+V: the history in a small window (fzf), pictures previewed in the terminal (ImageMagick draws them as sixels) |
| Screenshots | grim + slurp + satty | F + GH | satty needs gtk4 + libadwaita (listed) |
| Night light | gammastep | F | |
| Audio | PipeWire + WirePlumber (+ pulse/alsa shims) + pipewire-utils | F | pavucontrol, EasyEffects, playerctl; `pw-dump` feeds the audio menu |
| Music meter | cava | F | the bar's spectrum meter, only while sound plays (sleeps through silence) |
| Monitor brightness | ddcutil | F | DDC/CI, like Twinkle Tray on Windows |
| Bar clicks | wtype | F | clicking a workspace presses its key (Super+1…9) |
| Portals | xdg-desktop-portal-wlr + -gtk | F | screen share (with the `kawa-share` picker) / file dialogs / dark mode |
| File dialogs | xdg-desktop-portal-termfilechooser 1.4.3 + yazi (`kawa-pick`) | git (GitHub, pinned commit) | not packaged for Fedora: built by setup.sh like dwl (meson + inih-devel + systemd-devel, kept); Brave's and GTK programs' Open/Save dialogs are yazi in a floating terminal; the GTK dialog stays as the fallback |
| Terminal for apps | xdg-terminal-exec | F | programs that ask for a terminal get foot |
| Auth dialogs | lxqt-policykit | F | |
| USB drives | udiskie + udisks2 + `kawa-drives` · exfatprogs · dosfstools · ntfs-3g | F | sticks, disks and SD cards open by themselves under `/run/media/$USER`; `kawa-drives` gives the notices, the bar's drive mark, yazi's **M** and the eject that says "safe to unplug"; exFAT and FAT tools check, repair and name the usual sticks; ntfs-3g opens NTFS whether or not the kernel has its own NTFS driver (Fedora's kernels have changed which one they build) |
| Bluetooth | bluez + blueman | F | controller dongle |
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
| Codecs | ffmpeg (full) | RF | replaces ffmpeg-free |
| Music | spotify_player | GH (sha256) | Premium |
| Torrents | torrra (on Python 3.13) + Prowlarr | pipx + podman | libtorrent has no Python 3.14 wheel yet; `kawa-torrra` hands torrra the key from `secrets.sh` |
| Git | git + lazygit | F + C | |
| Script checking | ShellCheck | F | `fedokawaii apply` reads the scripts you changed with it; every finding has a page (SC number) that explains it |
| System monitor | btop | F | |
| Search / view | ripgrep · fd-find · bat | F | rg and fd also power LazyVim's pickers |
| Performance | tuned | F | the `fedokawaii` profile: throughput-performance for an always-plugged desktop |
| Fetch | `fetch` (own, pure bash) | repo | ten pixel pictures; replaces fastfetch |
| Snapshots | snapper | F | Timeshift can't use Fedora's subvolume names |
| Containers | podman | F | for Prowlarr |
| GPU | Mesa freeworld (VA-API + Vulkan) · LACT | RF + C | amdgpu feature mask for LACT |
| Peripherals | OpenRGB · Solaar · liquidctl | F | |
| Gaming | Steam · gamescope · gamemode · MangoHud · GE-Proton · ntsync-autoload | RF + F + GH | GE-Proton keeps the newest two; ntsync: Proton's faster synchronisation |
| Fonts | JetBrainsMono Nerd · DepartureMono Nerd · PixelMplus 12 · Sumi Icons · Terminus (console) · Noto Sans · Noto Sans CJK · Noto Naskh Arabic · Noto Kufi Arabic · Amiri · Noto Color Emoji · Liberation | GH + F + repo | Departure = the pixel UI font; PixelMplus = Japanese in the pixel UI and the terminal; Noto Sans CJK = Japanese, Chinese, Korean in programs and subtitles; Sumi Icons = this desktop's icons; Kufi = Arabic in the pixel UI (bar, menus, notices); Liberation = metric-compatible fonts for office files |
| Look | adw-gtk3 · qt6ct · Papirus · dconf · pointers drawn here (Adwaita beneath for rare shapes) | F + repo | dark/light switched live by `kawa-theme`; the pixel pointers come from `art/cursors.txt` |
| Build (kept) | gcc · make · pkgconf · wayland/wlroots/xcb devel | F | theme.sh rebuilds dwl when you change a keybind, and builds kawa-veil and kawa-clipkeep |
| Script plumbing | dnf5-plugins · git · jq · gnupg2 · tar · grubby · diffutils · man-db · libva-utils · libdnf5-plugin-actions | F | used by setup.sh / verify.sh; tar unpacks the release archives and GE-Proton, grubby sets the kernel arguments (neither is in a Minimal Install's `@core`; the installer adds grubby only on a UEFI machine); diff / cmp compare the copy and the toolkit, man opens the manuals the change menu lists (both usually present: listed, never assumed); actions = a snapshot pair around every dnf run |
| Drivers and firmware | fwupd · pciutils · usbutils, and what this machine needs (`lib/hardware.sh`): microcode_ctl or amd-ucode-firmware, NetworkManager-wifi + wireless-regdb, alsa-sof-firmware, the firmware the kernel asked for (iwlwifi-…-firmware and the like), intel-media-driver beside an AMD card | F + RF | fwupd: device firmware from the LVFS, applied only by you · lspci / lsusb: which device, which driver · the per-machine packages are found from the hardware at setup, update and repair, and recorded in `/var/lib/fedokawaii/hardware-pkgs` (part of the manifest from then on) |
| Base | NetworkManager · sudo | F | already in @core — listed so they are marked as yours and dnf's clean-up never takes them |
| Base | NetworkManager-tui · xorg-x11-server-Xwayland · xdg-utils · xdg-user-dirs | F | nmtui (quick settings → network) · X11 programs · `xdg-open` · `~/Pictures`… |
| GPU base | mesa-dri-drivers · vulkan-loader · linux-firmware · amd-gpu-firmware (AMD) · intel-media-driver + mesa-vulkan-drivers (Intel) | F + RF | the freeworld Mesa builds on AMD; Intel's VA-API driver from RPM Fusion, Fedora's Vulkan |
| Repositories | rpmfusion-free-release · rpmfusion-nonfree-release | RF | |

## Never present (verify.sh fails if any appear)

Editors other than neovim (nano, nano-default-editor, vim-minimal, vim-enhanced, vim-default-editor, emacs) · the rescue kernel (dracut-config-rescue) · browsers other than Brave
Origin (firefox, chromium, brave-browser) · other terminals and launchers (alacritty, kitty, xterm,
konsole, gnome-terminal, rofi, wofi, wmenu, bemenu) · second polkit agents and tray NM
(polkit-gnome, hyprpolkitagent, network-manager-applet) · flatpak, snapd, PackageKit,
gnome-software · ffmpeg-free · tuigreet, wlogout, fastfetch, neofetch (replaced by agreety,
fuzzel menus and the own `fetch`) · second notification daemons (dunst, swaync) ·
power-profiles-daemon (tuned only) · other login managers (gdm, sddm, lightdm, lxdm) · on AMD,
the non-freeworld mesa-va-drivers / mesa-vulkan-drivers.

On top of that list, verify.sh compares everything *user-installed* against a snapshot taken
before setup started plus the manifest — anything else is reported by name.

## Removed since the previous version, and why

| Removed | Why |
|---|---|
| a separate clock script | waybar's own clock module shows seconds and wakes on the second by itself |
| tuigreet, wlogout, fastfetch | agreety (part of greetd), a fuzzel power menu, the own `fetch` |
| npm for Claude Code | Claude Code now ships an official signed dnf repo (Node.js and npm are back, for yt-dlp and Mason — see below) |
| Rust + cargo (+ openssl/alsa/dbus devel, cmake) | yazi, presenterm, spotify_player come as release binaries — 15 min faster setup |
| GStreamer plugins + `@multimedia` group | nothing installed uses GStreamer (mpv = ffmpeg; Brave and Steam bundle their own) |
| x264, x265, svt-av1, libaom, dav1d, opus, lame, flac, … CLI/lib packages | pulled in by ffmpeg where needed; the CLI encoders duplicated ffmpeg |
| google-noto-sans-arabic-fonts | fontconfig sends Arabic to Noto Naskh; Sans Arabic was never used |
| starship (COPR) | native bash prompt, no process per prompt |
| bluez-tools, polkit/xdg-desktop-portal listed explicitly | unused, or already dependencies (udisks2 is listed again: nothing but a weak dependency brings it) |
| `settings.ini` for GTK | GTK reads GSettings (dconf) on Wayland — single source |
| unzip | 7zip opens zip files too (`7z x`) |
| mediainfo | ffprobe (part of ffmpeg) tells the same about a video or song |
| Brave flags file | Chromium ≥ 140 picks Wayland automatically |
| `keepcache`, `skip_if_unavailable`, `clean_requirements_on_remove` in dnf config | already Fedora's defaults |

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
| fwupd, pciutils, usbutils | firmware inside the devices (SSD, motherboard, dock), offered by update and applied by you · which device is which, and which driver holds it |
| exfatprogs, dosfstools, ntfs-3g | the USB drives: check, repair and name exFAT and FAT sticks; NTFS opens whatever NTFS driver the kernel has |
| python3, glib2, fontconfig | already there as other packages' dependencies; listed so they are never assumed: the helpers' Python parts and the self-tests · `gsettings`, `gio` · `fc-match`, `fc-cache` |
| tar, grubby | not on a Minimal Install (grubby only on UEFI machines): unpacking the toolkit and the kernel's boot options |
