#!/usr/bin/env bash
# shellcheck disable=SC2034  # every list here is consumed by setup.sh, verify.sh or theme.sh
# lib/manifest.sh — the single source of truth.
# setup.sh installs exactly these lists; verify.sh proves exactly these lists
# are present, the FORBIDDEN ones are absent, and nothing else was added.
# Every name verified on packages.fedoraproject.org / RPM Fusion / vendor repos
# for Fedora 44 and 45 (2026-10-14). One tool per job — see PACKAGES.md.

# ── phase 1 ─────────────────────────────────────────────────────────────────
PKG_BASE=(
  dnf5-plugins          # dnf copr, dnf config-manager
  git jq gnupg2         # used by the scripts (clone, GitHub API, key check); zips: 7zip (apps)
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
            dracut-config-rescue)                                                  # no rescue boot entry

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
PKG_GPU_COMMON=(mesa-dri-drivers vulkan-loader linux-firmware)
PKG_GPU_amd=(amd-gpu-firmware mesa-va-drivers-freeworld mesa-vulkan-drivers-freeworld lact)
PKG_GPU_intel=(intel-media-driver mesa-vulkan-drivers)

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
PKG_SESSION=(greetd greetd-selinux xorg-x11-server-Xwayland)   # greetd brings agreety, the text login
PKG_DESKTOP=(
  pipewire wireplumber pipewire-pulseaudio pipewire-alsa  # audio (Pulse API for Brave/Steam, ALSA for spotify_player)
  pipewire-utils                                          # pw-dump: the audio popup lists outputs/inputs from it
  pavucontrol easyeffects playerctl cava                  # per-app mixer, EQ, media keys, the bar's music meter
  waybar mako fuzzel foot                                 # bar, notifications, launcher+menus, terminal
  swaybg swayidle swaylock wlr-randr wlopm                # wallpaper, idle, lock, output modes, screens off
  ddcutil wtype                                           # monitor brightness over DDC/CI · bar clicks → Super+1…9
  wl-clipboard cliphist grim slurp gammastep libnotify    # clipboard, screenshots, night light, notify-send
  xdg-desktop-portal-wlr xdg-desktop-portal-gtk           # screencast/screenshot + file dialogs/settings
  xdg-utils xdg-user-dirs udiskie lxqt-policykit          # xdg-open, ~/Pictures…, USB automount, auth dialogs
  udisks2                                                 # what udiskie asks to mount (only a weak dependency brings it otherwise)
  exfatprogs dosfstools ntfs-3g                           # drives: check, repair and name exFAT and FAT sticks and
                                                          #   SD cards; NTFS opens whatever NTFS driver the kernel has
  xdg-terminal-exec                                       # a terminal (foot) for apps that ask for one
  bluez blueman                                           # Bluetooth controller dongle
  dconf                                                   # persists GTK settings (dark mode for GTK4/libadwaita)
  gtk4 libadwaita                                         # runtime for satty (upstream binary)
)
PKG_LOOK=(
  adw-gtk3-theme qt6ct papirus-icon-theme adwaita-cursor-theme
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
  abiword gnumeric                                  # office
  zathura zathura-pdf-mupdf zathura-cb              # PDF / EPUB / comic book reader
  bsdtar                                            #   comics' covers and pages for the books window
                                                    #   (libarchive, as zathura-cb: CBZ, CBR, CB7)
  qpdf poppler-utils xournalpp                      # PDF tools, annotation and signing
  ghostscript                                       #   PDF compression (`gs`)
  tesseract tesseract-langpack-eng tesseract-langpack-ara   # text from scans and pictures (OCR)
  imv ImageMagick ImageMagick-heic qalculate        # images, conversions (phone HEIC photos too), `qalc`
  qrencode wf-recorder                              # QR codes · screen recordings
  btop bat ripgrep fd-find                          # monitor, pager; rg/fd also power LazyVim pickers
  fzf file 7zip                                     # the clipboard and wallpaper windows' lists, the shell's
                                                    #   Ctrl+R / Ctrl+T / Alt+C, yazi's z; file types; archives
  eza zoxide tldr                                   # the shell: ls with git status and trees · a cd that
                                                    #   learns your folders (yazi's Z too) · tldr examples
  lazygit tree-sitter-cli                           # git TUI; parser builder required by LazyVim's nvim-treesitter
  ShellCheck                                        # explains what is wrong in a shell script: fedokawaii apply
                                                    #   reads the ones you changed (and neovim's bash server, §11.5)
  openrgb solaar liquidctl                          # RGB, Logitech, coolers
  snapper libdnf5-plugin-actions                    # snapshots; actions = pre/post snapshot around every dnf run
  podman python3.13 pipx                            # Prowlarr container; torrra (needs libtorrent wheels ≤ py3.13)
)
PKG_GAMING=(steam gamescope gamemode mangohud
            ntsync-autoload)   # /dev/ntsync at boot: Proton's faster Windows synchronisation

# ── dropped from the manifest: Update hands them back to dnf as dependencies, so they
#    are no longer "yours" and dnf autoremove clears them when nothing needs them. Move a
#    package here when you take it out of the lists above ───────────────────────────────
RETIRED_PKGS=(unzip mediainfo)   # unzip: 7zip opens zips too · mediainfo: ffprobe does its job

# ── never present after setup (removed, replaced, or out of scope) ─────────
FORBIDDEN_PKGS=(
  nano nano-default-editor vim-minimal vim-enhanced vim-default-editor emacs   # editors: neovim only
  firefox chromium brave-browser                                               # browsers: Brave Origin only
  alacritty kitty xterm konsole gnome-terminal                                 # terminals: foot only
  rofi wofi wmenu bemenu                                                       # launchers: fuzzel only
  tuigreet wlogout fastfetch neofetch                                          # replaced: agreety, fuzzel menus, own fetch
  polkit-gnome hyprpolkitagent network-manager-applet                          # one polkit agent, no tray NM
  dunst swaync                                                                 # notifications: mako only
  power-profiles-daemon                                                        # power: tuned only (both would set the CPU)
  gdm sddm lightdm lxdm                                                        # logins: greetd only
  flatpak snapd PackageKit gnome-software                                      # dnf only
  dracut-config-rescue                                                         # no rescue image
  ffmpeg-free                                                                  # RPM Fusion ffmpeg only
)
FORBIDDEN_amd=(mesa-va-drivers mesa-vulkan-drivers)                             # freeworld builds only (mesa-va-drivers: before F44)

# ── services ────────────────────────────────────────────────────────────────
SVC_SYSTEM=(greetd.service bluetooth.service snapper-timeline.timer snapper-cleanup.timer fstrim.timer)
SVC_SYSTEM_amd=(lactd.service)
SVC_USER_GLOBAL=(pipewire.socket wireplumber.service)

# ── vendor repositories ────────────────────────────────────────────────────
BRAVE_REPO_URL="https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo"
CLAUDE_REPO_BASEURL="https://downloads.claude.ai/claude-code/rpm/stable"
CLAUDE_KEY_URL="https://downloads.claude.ai/keys/claude-code.asc"
CLAUDE_KEY_FPR="31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE"
COPRS=(ilyaz/LACT dejan/lazygit)

# manifest_all GPU → every package setup.sh installs on purpose, one per line
manifest_all() {
  local gpu_pkgs="PKG_GPU_$1[@]"
  printf '%s\n' "${PKG_BASE[@]}" "${PKG_RELEASE[@]}" "${PKG_MEDIA[@]}" \
    "${PKG_GPU_COMMON[@]}" "${!gpu_pkgs}" "${PKG_BUILD[@]}" "${PKG_SESSION[@]}" \
    "${PKG_DESKTOP[@]}" "${PKG_LOOK[@]}" "${PKG_APPS[@]}"
  [[ ${STEAM:-yes} == yes ]] && printf '%s\n' "${PKG_GAMING[@]}"
  # libraries a release binary needed that Fedora stopped pulling in by itself (say
  # openssl3-libs for spotify_player on Fedora 45): installed and recorded by lib/upstream.sh
  cat "${STATE_DIR:-/var/lib/fedokawaii}/upstream-libs" 2>/dev/null || true
  # what this machine's own hardware needs — its firmware, the CPU's microcode, the Wi-Fi's
  # plumbing (lib/hardware.sh): found and recorded by setup, update and repair
  cat "${STATE_DIR:-/var/lib/fedokawaii}/hardware-pkgs" 2>/dev/null || true
  return 0
}
