#!/usr/bin/env bash
# shellcheck disable=SC2034  # every list here is consumed by setup.sh, verify.sh or theme.sh
# lib/manifest.sh — the single source of truth.
# setup.sh installs exactly these lists; verify.sh proves exactly these lists
# are present, the FORBIDDEN ones are absent, and nothing else was added.
# Every name verified on packages.fedoraproject.org / RPM Fusion / vendor repos
# for Fedora 44 and 45 (2026-10-14; tar, grubby, wiremix, visidata, gdu, rocm-smi,
# Syncplay's Python libraries 2026-10-16; LibreOffice's parts, the hunspell dictionaries and
# lpf-spotify-client 2026-10-17). One tool per job — see PACKAGES.md.

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
PKG_BUILD=(             # kept installed: theme.sh rebuilds dwl (config.h, patch) and builds kawa-veil and
                        # kawa-clipkeep; update rebuilds the yazi file dialog (termfilechooser)
  gcc make pkgconf-pkg-config
  wayland-devel wayland-protocols-devel libinput-devel libxkbcommon-devel
  pixman-devel libdrm-devel libxcb-devel xcb-util-wm-devel wlroots-devel
  meson inih-devel systemd-devel   # setup.sh builds xdg-desktop-portal-termfilechooser (the yazi
                                   #   file dialog; not packaged): meson (+ ninja-build), its INI
                                   #   parser (inih), sd-bus (libsystemd); no man page, so no scdoc
)
# dwl's config.mk ships XWayland commented out; Steam and other X11 apps need it on
DWL_MAKE=(XWAYLAND=-DXWAYLAND "XLIBS=xcb xcb-icccm")
PKG_SESSION=(greetd greetd-selinux xorg-x11-server-Xwayland    # the login manager, X11 apps
  cage python3-gobject gtk3                                     # the login screen: kawa-greet (GTK) in cage, a kiosk compositor
  plymouth-plugin-script)                                       # the boot splash (the "sumi" Plymouth theme is a script)
PKG_DESKTOP=(
  pipewire wireplumber pipewire-pulseaudio pipewire-alsa  # audio (Pulse API for Brave/Steam/Spotify; ALSA for
                                                          #   programs that open it directly: games)
  pipewire-utils                                          # pw-dump: the audio popup lists outputs/inputs from it
  wiremix easyeffects playerctl cava                      # per-app mixer (a terminal window), EQ, media keys, the bar's music meter
  waybar mako fuzzel foot                                 # bar, notifications, launcher+menus, terminal
  gtk-layer-shell                                         # quick settings: kawa-panel (GTK 3 and Python's
                                                          #   GObject with cairo come with the login screen)
  swaybg swayidle gtklock wlr-randr wlopm                 # wallpaper, idle, lock, output modes, screens off
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
  zathura zathura-pdf-mupdf zathura-cb              # PDF / EPUB / comic book reader
  bsdtar                                            #   comics' covers and pages for the books window
                                                    #   (libarchive, as zathura-cb: CBZ, CBR, CB7)
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
  visidata                                          # tables in the terminal: vd opens CSV, TSV, JSON and
                                                    #   SQLite (sort, sum, filter, group — Excel files are
                                                    #   LibreOffice Calc's)
  gdu                                               # what fills the disk (gdu ~), folder by folder
  fzf file 7zip                                    # the clipboard and wallpaper windows' lists, the shell's
                                                    #   Ctrl+R / Ctrl+T / Alt+C, yazi's z; file types; archives
  eza zoxide tldr                                   # the shell: ls with git status and trees · a cd that
                                                    #   learns your folders (yazi's Z too) · tldr examples
  tree-sitter-cli                                   # parser builder required by LazyVim's nvim-treesitter
                                                    #   (lazygit, the git TUI: lib/upstream.sh)
  ShellCheck                                        # explains what is wrong in a shell script: fedokawaii apply
                                                    #   reads the ones you changed (and neovim's bash server, §17.15)
  openrgb                                           # RGB lighting (fan speeds: the motherboard's firmware)
  snapper libdnf5-plugin-actions                    # snapshots; actions = pre/post snapshot around every dnf run
  restic                                            # backups to another disk (kawa-backup)
  podman python3.13 pipx                            # Prowlarr container; torrra (needs libtorrent wheels ≤ py3.13)
)
PKG_GAMING=(steam gamescope gamemode mangohud
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
              papirus-icon-theme)      # every app shows its own icon now (hicolor), not an icon pack's

# ── never present after setup (removed, replaced, or out of scope) ─────────
FORBIDDEN_PKGS=(
  nano nano-default-editor vim-minimal vim-enhanced vim-default-editor emacs   # editors: neovim only
  firefox chromium brave-browser                                               # browsers: Brave Origin only
  alacritty kitty xterm konsole gnome-terminal                                 # terminals: foot only
  rofi wofi wmenu bemenu                                                       # launchers: fuzzel only
  tuigreet gtkgreet wlogout fastfetch neofetch                                 # replaced: kawa-greet, fuzzel menus, own fetch
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
COPRS=(ilyaz/LACT)
copr_pkgs() { case $1 in ilyaz/LACT) echo lact ;; esac; }   # what each COPR brings

# ── built on this machine: lpf makes these packages from a manifest package's recipe
#    (setup.sh, spotify_client). No repository has them, so they are not in manifest_all
#    (update would look for them there); verify counts them as the desktop's own ─────────
LPF_BUILT=(spotify-client)
# Spotify (SPOTIFY=yes, your acceptance of its terms): RPM Fusion's recipe, which lpf builds
# into the spotify-client package on this machine (setup.sh)
PKG_SPOTIFY=(lpf-spotify-client)

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
  [[ $SPOTIFY == yes ]] && printf '%s\n' "${PKG_SPOTIFY[@]}"
  # libraries a release binary needed that Fedora stopped pulling in by itself (say
  # openssl3-libs, once Fedora 45 moved to OpenSSL 4): installed and recorded by lib/upstream.sh
  cat "${STATE_DIR:-/var/lib/fedokawaii}/upstream-libs" 2>/dev/null || true
  # what this machine's own hardware needs — its firmware, the CPU's microcode, the Wi-Fi's
  # plumbing (lib/hardware.sh): found and recorded by setup, update and repair
  cat "${STATE_DIR:-/var/lib/fedokawaii}/hardware-pkgs" 2>/dev/null || true
  return 0
}
