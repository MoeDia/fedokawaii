#!/usr/bin/env bash
# shellcheck disable=SC2034  # every list here is consumed by setup.sh, verify.sh or theme.sh
# lib/manifest.sh — the single source of truth.
# setup.sh installs exactly these lists; verify.sh proves exactly these lists
# are present, the FORBIDDEN ones are absent, and nothing else was added.
# Every name verified on packages.fedoraproject.org / RPM Fusion / vendor repos
# for Fedora 44 and 45 (2026-10-14; tar, grubby, wiremix, visidata, gdu, rocm-smi,
# Syncplay's Python libraries 2026-10-16; LibreOffice's parts and the hunspell dictionaries
# 2026-10-17). One tool per job — see PACKAGES.md.

# ── phase 1 ─────────────────────────────────────────────────────────────────
PKG_BASE=(
  dnf5-plugins          # dnf copr, dnf config-manager
  git jq gnupg2         # used by the scripts (clone, GitHub API, key check); zips: 7zip (apps)
  python3               # the helpers' small Python parts and the self-tests (tuned brings it
                        #   too: listed, never assumed)
  diffutils man-db      # diff/cmp: the copy against the toolkit, the checks · man: the manuals
                        #   the change menu opens (both usually there; listed, never assumed)
  tar grubby            # tar: the release archives, GE-Proton, the C helpers' builds · grubby:
                        #   kernel arguments (amdgpu, the console palette). Neither is in a
                        #   Minimal Install's @core: tar is @standard's, and the installer
                        #   adds grubby only for a UEFI boot — a BIOS install has none
  NetworkManager sudo   # in @core already: listed so they are marked as yours, and dnf's
                        # clean-up (autoremove) can never take the network or sudo
  NetworkManager-tui    # nmtui
  bash-completion       # tab completion for every CLI below
  neovim                # the only editor
  tuned                 # the performance profile of an always-plugged desktop (system/tuned.conf)
  fwupd                 # firmware inside the devices (SSD, motherboard, dock…) from the LVFS:
                        #   update lists what is new, fwupdmgr update applies it — when you choose
  pciutils usbutils     # lspci · lsusb: which device is which, and which driver holds it
)
PKG_REMOVE=(nano nano-default-editor vim-minimal vim-enhanced vim-default-editor   # one editor: neovim
            dracut-config-rescue                                                   # no rescue boot entry
            systemd-oomd-defaults)                                                 # no whole-session kills (FORBIDDEN_PKGS)

# ── phase 2 ─────────────────────────────────────────────────────────────────
PKG_RELEASE=(rpmfusion-free-release rpmfusion-nonfree-release)
PKG_MEDIA=(
  ffmpeg                # RPM Fusion build, swapped in for ffmpeg-free
  mpv mpv-mpris         # player; mpv-mpris: mpv in the bar and on the media keys (MPRIS)
  yt-dlp                # downloader (mpv plays links through it); ffprobe (ffmpeg) inspects media
  nodejs24 nodejs24-bin nodejs24-npm-bin
                        # YouTube: yt-dlp answers its JavaScript challenges in Node.js (~/.config/yt-dlp/config);
                        # Node 24 by its own name on F44 and F45 ("nodejs" is 22 there); -bin: the plain `node`,
                        # npm-bin: the plain `npm`, which neovim's Mason installs language servers with
  libva-utils           # vainfo — used by verify.sh
  libheif-freeworld     # HEVC for HEIF: iPhone photos (.heic) open in imv, yazi and ImageMagick
  unrar                 # RAR archives and .cbr comics (nonfree): Fedora's 7-Zip reads no RAR (kawa-file, kawa-books)
)
# Vulkan: Fedora's own driver (RADV on AMD, ANV on Intel), 64- and 32-bit. RPM Fusion's
# freeworld build of it adds only Vulkan's own H.264/HEVC video, which nothing here uses (mpv
# and Brave decode through VA-API: mesa-va-drivers-freeworld), and its 64- and 32-bit packages
# have clashed over a shared file (Fedora 44, Mesa 26.1/26.2): installing Steam's 32-bit one
# took the 64-bit one out again
PKG_GPU_COMMON=(mesa-dri-drivers mesa-vulkan-drivers vulkan-loader linux-firmware)
PKG_GPU_amd=(amd-gpu-firmware mesa-va-drivers-freeworld lact
             rocm-smi)   # the ROCm SMI library: btop reads the card through it (load, memory, heat, watts)
PKG_GPU_intel=(intel-media-driver)

# ── phase 3 ─────────────────────────────────────────────────────────────────
PKG_BUILD=(             # kept installed: theme.sh rebuilds dwl (config.h, patch) and builds
                        # kawa-clipkeep, kawa-saver and kawa-lockmod; update rebuilds the yazi file
                        # dialog (termfilechooser)
  gcc make pkgconf-pkg-config
  libasan               # AddressSanitizer's runtime: dwl built once more with it for the checks
                        #   (tools/hl-dwl.sh --asan: the selftest's crash and leak runs)
  gtk3-devel            # GTK 3's headers: kawa-lockmod, the lock screen's gtklock module
  wayland-devel wayland-protocols-devel libinput-devel libxkbcommon-devel
  pixman-devel libdrm-devel libxcb-devel xcb-util-wm-devel wlroots-devel
  meson inih-devel systemd-devel   # setup.sh builds xdg-desktop-portal-termfilechooser (the yazi
                                   #   file dialog; not packaged): meson (+ ninja-build), its INI
                                   #   parser (inih), sd-bus (libsystemd); no man page, so no scdoc
)
# dwl's config.mk ships XWayland commented out; Steam and other X11 apps need it on
# (and pixman: dwl.patch damages a window capture's output itself — capturesession)
DWL_MAKE=(XWAYLAND=-DXWAYLAND "XLIBS=xcb xcb-icccm pixman-1")
PKG_SESSION=(greetd greetd-selinux xorg-x11-server-Xwayland    # the login manager, X11 apps
  cage python3-gobject gtk3                                     # the login screen: kawa-greet (GTK) in cage, a kiosk compositor
  plymouth-plugin-script)                                       # the boot splash (the "sumi" Plymouth theme is a script)
PKG_DESKTOP=(
  pipewire wireplumber pipewire-pulseaudio pipewire-alsa  # audio (Pulse API for Brave and Steam; ALSA for
                                                          #   programs that open it directly: games)
  pipewire-utils                                          # pw-dump: the audio popup lists outputs/inputs from it
  wiremix playerctl cava                                  # per-app mixer (a terminal window), media keys, the bar's music meter
                                                          #   (the clean mic and an equaliser: PipeWire's own modules — no package)
  waybar mako foot                                        # bar, notifications, terminal (the launcher and menus: kawa-panel)
  gtk-layer-shell                                         # quick settings: kawa-panel (GTK 3 and Python's
                                                          #   GObject with cairo come with the login screen)
  swaybg swayidle gtklock wlr-randr wlopm                 # wallpaper, idle, lock, output modes, screens off
  wayland-utils                                           # wayland-info: what the compositor offers (the health report)
  ddcutil wtype                                           # monitor brightness over DDC/CI · bar clicks → Super+1…9
  wl-clipboard cliphist grim slurp gammastep libnotify    # clipboard, screenshots, night light, notify-send
  xdg-desktop-portal-wlr xdg-desktop-portal-gtk           # screencast/screenshot + settings (dark/light), print, open with
  xdg-utils xdg-user-dirs udiskie lxqt-policykit          # xdg-open, ~/Pictures…, USB automount, auth dialogs
  udisks2                                                 # what udiskie asks to mount (only a weak dependency brings it otherwise)
  exfatprogs dosfstools ntfs-3g                           # drives: check, repair and name exFAT and FAT sticks and
                                                          #   SD cards; NTFS opens whatever NTFS driver the kernel has
  xdg-terminal-exec                                       # a terminal (foot) for apps that ask for one
  bluez                                                   # Bluetooth controller dongle (pairing: bluetui, lib/upstream.sh)
  dconf                                                   # persists GTK settings (dark mode for GTK4/libadwaita)
  glib2 fontconfig                                        # gsettings, gio · fc-cache, fc-match: the helpers call them
                                                          #   (NetworkManager and foot bring them too: listed, never assumed)
  gtk4 libadwaita                                         # runtime for satty (upstream binary)
)
PKG_LOOK=(
  adw-gtk3-theme qt6ct            # (icons: each app's own, under GTK's Adwaita — no icon pack)
  liberation-fonts-all            # metric-compatible Arial/Times/Courier for office documents
  google-noto-sans-fonts          # UI sans
  google-noto-naskh-arabic-fonts amiri-fonts   # Arabic sans / serif
  google-noto-kufi-arabic-fonts                # Arabic in the pixel UI (bar, menus, notices): square, even strokes
  google-noto-color-emoji-fonts   # emoji
  google-noto-sans-cjk-vf-fonts   # Japanese, Chinese, Korean in apps, web pages and subtitles
  terminus-fonts-console          # the text console's font (Terminus bold, theme.sh)
)
PKG_APPS=(
  brave-origin claude-code                          # browser, AI (vendor repos)
  gh                                                # GitHub from the terminal: sign in once (gh auth login),
                                                    #   then clone, pull requests, issues, releases
  libreoffice-writer libreoffice-calc libreoffice-impress
                                                    # office: Word, Excel and PowerPoint files (and
                                                    #   OpenDocument), opened and edited — only these three
  libreoffice-gtk3                                  #   LibreOffice drawn by GTK 3: it follows the desktop's
                                                    #   GTK theme, dark and light (its other toolkits: not here)
  hunspell-en hunspell-ar                           # spelling dictionaries, English and Arabic (LibreOffice;
                                                    #   Arabic is its language for right-to-left text: theme.sh)
  zathura zathura-pdf-mupdf zathura-cb              # PDF / EPUB / comic book reader (the books window's
                                                    #   covers and page counts: 7z, below)
  qpdf poppler-utils xournalpp                      # PDF tools, annotation and signing
  ghostscript                                       #   PDF compression (`gs`)
  tesseract tesseract-langpack-eng tesseract-langpack-ara   # text from scans and pictures (OCR)
  imv ImageMagick ImageMagick-heic qalculate        # images, conversions (phone HEIC photos too), `qalc`
  python3-twisted python3-twisted+tls python3-pyOpenSSL python3-certifi python3-pem
                                                    # what Syncplay needs (watching together, kawa-together): lib/upstream.sh
                                                    #   runs its pinned source on Fedora's python3 — Twisted with its TLS
                                                    #   extra (+tls brings service-identity, idna), certifi (Fedora's CA
                                                    #   list), pem. Not the syncplay package: PySide6 and 27 Qt modules with it
  qrencode wf-recorder                              # QR codes · screen recordings
  btop bat ripgrep fd-find                          # monitor, pager; rg/fd also power LazyVim pickers
  git-delta                                         # lazygit's diffs: syntax-coloured, line-numbered (delta)
  visidata                                          # tables in the terminal: vd opens CSV, TSV, JSON and
                                                    #   SQLite (sort, sum, filter, group — Excel files are
                                                    #   LibreOffice Calc's)
  gdu                                               # what fills the disk (gdu ~), folder by folder
  fzf file 7zip                                    # the clipboard and wallpaper windows' lists, the shell's
                                                    #   Ctrl+R / Ctrl+T / Alt+C, yazi's z; file types; archives
  zstd                                              # .tar.zst archives (kawa-file, through tar -I)
  eza zoxide tldr                                   # the shell: ls with git status and trees · a cd that
                                                    #   learns your folders (yazi's Z too) · tldr examples
  tree-sitter-cli                                   # parser builder required by LazyVim's nvim-treesitter
                                                    #   (lazygit, the git TUI: lib/upstream.sh)
  ShellCheck                                        # explains what is wrong in a shell script: fedokawaii apply
                                                    #   reads the ones you changed (and neovim's bash server, §17.15)
  openrgb                                           # RGB lighting (fan speeds: the motherboard's firmware)
  snapper libdnf5-plugin-actions                    # snapshots; actions = pre/post snapshot around every dnf run
  grub-btrfs                                        # the snapshots in the boot menu (its COPR: no Fedora package)
  restic                                            # backups to another disk (kawa-backup)
  uv rustup                                         # Python and Rust to learn with: uv installs a current
                                                    #   CPython and its packages, rustup-init the stable Rust
                                                    #   (+ rust-analyzer, clippy, rustfmt) — both in your home (setup.sh: s_dev)
  podman                                            # Prowlarr container (torrra: uv tool, on uv's own Python 3.13 —
                                                    #   libtorrent has wheels only up to 3.13: setup.sh torrra_up)
)
PKG_GAMING=(steam gamescope mangohud
            ntsync-autoload    # /dev/ntsync at boot: Proton's faster Windows synchronisation
            steam-devices)     # the rules that let Steam (and Proton's games) open a controller:
                               #   Steam brings it today — listed, never assumed

# ── dropped from the manifest: Update hands them back to dnf as dependencies, so they
#    are no longer "yours" and dnf autoremove clears them when nothing needs them. Move a
#    package here when you take it out of the lists above ───────────────────────────────
RETIRED_PKGS=(unzip mediainfo    # unzip: 7zip opens zips too · mediainfo: ffprobe does its job
              pavucontrol blueman   # the mixer and the pairing window are terminal programs now: wiremix, bluetui
              lazygit               # its COPR is no longer kept: lazygit comes from its release (lib/upstream.sh)
              solaar liquidctl      # nothing here to drive: a mouse on a receiver needs no app; no liquid cooler
              abiword gnumeric sc-im   # office is LibreOffice now: Writer, Calc (and VisiData for CSV)
              papirus-icon-theme       # every app shows its own icon now (hicolor), not an icon pack's
              bsdtar                   # the books window's comics: 7z lists and opens them (one archive tool)
              gamemode                 # game mode is kawa-game's (tuned owns the CPU and the card's level)
              easyeffects calf      # one sound-processing stack, PipeWire's own: the clean mic (echo-cancel),
                                    #   an equaliser if you want one (filter-chain's param_eq) — handbook §15.6
              python3-fonttools     # the faces are the repo's own files now (system/fonts): nothing to build
              fuzzel                # the launcher and every menu are kawa-panel's (its sums worked out as you type)
              pipx python3.13       # uv installs torrra now, on a Python 3.13 of its own (one Python tool: uv)
              lpf-spotify-client lpf spotify-client)   # Spotify is its web player in a Brave app window
                                                       #   now; lpf's account and folder: setup.sh, lpf_leftovers_out

# ── never present after setup (removed, replaced, or out of scope) ─────────
FORBIDDEN_PKGS=(
  nano nano-default-editor vim-minimal vim-enhanced vim-default-editor emacs   # editors: neovim only
  firefox chromium brave-browser                                               # browsers: Brave Origin only
  alacritty kitty xterm konsole gnome-terminal                                 # terminals: foot only
  rofi wofi wmenu bemenu                                                       # launchers: kawa-panel's only
  tuigreet gtkgreet wlogout fastfetch neofetch                                 # replaced: kawa-greet, kawa-panel menus, own fetch
  swaylock                                                                     # the lock: gtklock only
  pavucontrol blueman                                                          # replaced: wiremix, bluetui (terminal windows)
  abiword gnumeric sc-im                                                       # replaced: LibreOffice Writer and Calc
  polkit-gnome hyprpolkitagent network-manager-applet                          # one polkit agent, no tray NM
  dunst SwayNotificationCenter                                                 # notifications: mako only (swaync's package)
  power-profiles-daemon                                                        # power: tuned only (both would set the CPU)
  systemd-oomd-defaults                                                        # oomd's rules: under memory pressure it ends a whole cgroup —
                                                                               #   the session's holds every program you run (the kernel's OOM killer stays)
  gdm sddm lightdm lxdm                                                        # logins: greetd only
  flatpak snapd PackageKit gnome-software                                      # dnf only
  dracut-config-rescue                                                         # no rescue image
  ffmpeg-free                                                                  # RPM Fusion ffmpeg only
  mesa-vulkan-drivers-freeworld                                                # Vulkan: Fedora's own (PKG_GPU_COMMON)
)
FORBIDDEN_amd=(mesa-va-drivers)                                                 # VA-API: the freeworld build only (mesa-va-drivers: before F44)

# ── services ────────────────────────────────────────────────────────────────
SVC_SYSTEM=(greetd.service bluetooth.service snapper-timeline.timer snapper-cleanup.timer fstrim.timer)
SVC_SYSTEM_amd=(lactd.service)
SVC_USER_GLOBAL=(pipewire.socket pipewire-pulse.socket wireplumber.service)   # (Fedora's presets enable them; verify checks)

# ── vendor repositories ────────────────────────────────────────────────────
BRAVE_REPO_URL="https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo"
CLAUDE_REPO_BASEURL="https://downloads.claude.ai/claude-code/rpm/stable"
CLAUDE_KEY_URL="https://downloads.claude.ai/keys/claude-code.asc"
CLAUDE_KEY_FPR="31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE"
# RPM Fusion's signing keys, free and nonfree: one each since 2020, for every Fedora from 33 on
# (the release packages of 44 and 45 name the same for 44 to 47 and Rawhide — measured
# 2026-10-21). setup.sh checks the release packages it fetches against them before installing
RPMFUSION_FREE_FPR="E9A491A3DE247814E7E067EAE06F8ECDD651FF2E"
RPMFUSION_NONFREE_FPR="79BDB88F9BBF73910FD4095B6A2AF96194843C65"
# (grub-btrfs: zzahkaboom24's COPR builds 4.14 for Fedora 43 and 44 — kylegospo's stopped at 38)
COPRS=(ilyaz/LACT zzahkaboom24/grub-btrfs)
copr_pkgs() { case $1 in ilyaz/LACT) echo lact ;; zzahkaboom24/grub-btrfs) echo grub-btrfs ;; esac; }   # what each COPR brings

# waiting PART → what waits for a repository to catch up with this Fedora, one name per line
# (setup.sh records it; update and repair try again and clear it): "rpmfusion" — RPM Fusion's
# builds made for another version of the Fedora package they go with (the freeworld drivers,
# libheif-freeworld); "copr" — a COPR with no build for this release yet
waiting() { cat "${STATE_DIR:-/var/lib/fedokawaii}/pending-$1" 2>/dev/null || true; }
waiting_pkgs() {   # → every package left out for now: RPM Fusion's, and the waiting COPRs'
  local c
  waiting rpmfusion
  while IFS= read -r c; do [[ -n $c ]] && copr_pkgs "$c"; done < <(waiting copr)
  return 0
}

# manifest_all GPU → every package setup.sh installs on purpose, one per line
manifest_all() {
  local gpu_pkgs="PKG_GPU_$1[@]"
  printf '%s\n' "${PKG_BASE[@]}" "${PKG_RELEASE[@]}" "${PKG_MEDIA[@]}" \
    "${PKG_GPU_COMMON[@]}" "${!gpu_pkgs}" "${PKG_BUILD[@]}" "${PKG_SESSION[@]}" \
    "${PKG_DESKTOP[@]}" "${PKG_LOOK[@]}" "${PKG_APPS[@]}"
  [[ $STEAM == yes ]] && printf '%s\n' "${PKG_GAMING[@]}"
  # libraries a release binary needed that Fedora stopped pulling in by itself (say
  # openssl3-libs, once Fedora 45 moved to OpenSSL 4): installed and recorded by lib/upstream.sh
  cat "${STATE_DIR:-/var/lib/fedokawaii}/upstream-libs" 2>/dev/null || true
  # what this machine's own hardware needs — its firmware, the CPU's microcode, the Wi-Fi's
  # plumbing (lib/hardware.sh): found and recorded by setup, update and repair
  cat "${STATE_DIR:-/var/lib/fedokawaii}/hardware-pkgs" 2>/dev/null || true
  return 0
}
