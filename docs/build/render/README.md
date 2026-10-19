# Real renders of the fedokawaii desktop (headless, Fedora 44 versions)

`shoot.sh` starts the real apps — waybar, fuzzel, mako, foot/footclient, gtklock, quick settings' panel — with
the test user's configs (what `theme.sh --user kawau` installed), in a headless sway on a
1920×1080 output at scale 1, and captures them with grim for the dark and the light theme.
The apps, and the libraries that draw their text, are built at the versions Fedora 44
ships (`/opt/f44`, see below). Nothing here is a mock-up: every PNG is a lossless grab
of what the compositor showed.

## Run

```sh
sudo ./shoot.sh                    # both themes (≈2 minutes)
sudo ./shoot.sh light              # one theme
sudo SHOOT_ONLY="bar menus" ./shoot.sh dark   # groups: bar menus notify term lock
```

A full run starts each `shots/<theme>/` and `logs/<theme>/` clean; a partial run
(`SHOOT_ONLY`) replaces only the files of the groups it shoots.

Re-run it after the repo changes: `cd /home/claude/fedokawaii && sudo bash theme.sh --user kawau`,
then `./shoot.sh`. It is idempotent: every run starts from scratch, and each theme runs in
its own PID + mount + UTS namespace, so when a theme is done every process it started is
gone (nothing to clean up, even after a crash or a timeout — each theme is capped at 15 min).
At the end the user's theme link (`~/.config/fedokawaii/current`) is put back as it was.

Debugging: `SHOOT_SWAY_DEBUG=1` (sway -d into the sway log), `SHOOT_FOOT_DEBUG=1`
(WAYLAND_DEBUG for the foot server).

## Output

`shots/<theme>/` — crops are 1:1 (no scaling); `*-full.png` is the whole screen at that moment.

| file | what |
|---|---|
| `wallpaper.png` | the default wallpaper as `kawa-wallpaper --restore` drew it (swaybg), before the bar |
| `desktop.png` | wallpaper + bar |
| `bar.png`, `bar-left.png`, `bar-center.png`, `bar-right.png` | the bar (1920×27) and its thirds (overlapping) |
| `bar-right-muted.png` | the bar's right end while the sink is muted |
| `menu-quick.png` | quick settings (`kawa-panel`) on a machine with a Bluetooth adapter |
| `menu-quick-nobt.png` | the same without one (this sandbox's real state) |
| `menu-sound.png` `menu-sound-muted.png` | the sound panel (`kawa-panel --sound`, Super+A), and muted |
| `menu-brightness.png` | the brightness slider (`kawa-panel --brightness`, the bar's brightness) |
| `menu-weather.png` | the week (`kawa-weather --menu`, the bar's weather), from `stubs/curl`'s forecast |
| `menu-weather-offline.png` | the same three hours later, offline: its age, quiet, above the days |
| `menu-power.png` `menu-calendar.png` `menu-timer.png` `menu-drives.png` `menu-steam.png` `menu-shrink.png` `menu-share.png` `menu-help.png` `menu-change.png` | the dropdowns and centred menus: `kawa-menu`, drawn by the session's panel (`kawa-panel --menu`, started for them; closed with SIGUSR2 between shots) |
| `menu-calendar-next.png` `menu-timer-running.png` `menu-help-filter.png` `menu-shrink-size.png` | the same after keys (paged to next month), with a timer running, filtered by typing (`volume`), and a size of one's own typed (`750 KB`) — `menu_keys`: wtype's keyboard made before the menu opens (sway sends a leave to the focused surface when a keyboard is added) |
| `launcher.png` | `fuzzel` (Super+Space) with the user's config |
| `notify-normal.png` | `kawa-screenshot`'s notice (`-a desktop`, the picture as icon) |
| `notify-app.png` | an app's notice with a Papirus icon and a wrapped body |
| `notify-critical.png` | a critical notice (autostart's "keeps stopping") |
| `osd-volume.png` `osd-brightness.png` `osd-muted.png` | the level display: `kawa-volume up` (57→62 %), `kawa-brightness +10` (60→70 %), `kawa-volume mute` |
| `terminal.png` (+ `terminal-full.png`) | footclient 1100×700 (foot snaps it to 1100×692: whole cells), typed for real: `sleep 3.2`, `fetch neko`, `ls` in a git repo with changes |
| `colors.png` | footclient showing the 16 colours as swatches, as text colours, and bold/dim/italic/underline/reverse/strike |
| `lock.png`, `lock-center.png`, `lock-typing-center.png` | `kawa-lock` (gtklock with the theme's lock style and module), and its centre while typing (the ◆ dots) |

`logs/<theme>/` — every app's stdout/stderr (`waybar.log`, `mako.log`, `menu-*.log`,
`foot-server.log`, `gtklock.log`, …), `fuzzel --check-config` and `foot --check-config`
results, `libs.txt` (the drawing libraries each running app actually mapped) and
`audio.log` (`wpctl status` and every PipeWire node).
`logs/warnings.txt` — the lines of those logs that look like warnings or errors.

## What is real, what stands in

Real: the five apps and their configs (including whatever theme.sh installs next to them,
e.g. `~/.config/pipewire/pipewire.conf.d/60-share.conf` — the "Share" output in the audio
menu — and `~/.local/share/applications/kawa-*.desktop` — "Files" in the launcher), every
`kawa-*` script and `fetch`, the user's
bash prompt (`~/.bashrc.d/fedokawaii.sh`), fonts (DepartureMono Nerd Font, JetBrainsMono
Nerd Font v3.5.1, PixelMplus12, Sumi Icons, Noto, Amiri, Liberation, Noto Color Emoji),
adw-gtk3 6.4 + Papirus 20250501 (Fedora 44's), dconf defaults, PipeWire + WirePlumber
(the volume module, `wpctl`, `pw-dump`), D-Bus, notify-send, the `kawa-dwlstatus` →
waybar signal path, typing (wtype, a virtual keyboard).

Stand-ins (`stubs/`, first in PATH; `xdg/`; `lib/`):

| what | why / how |
|---|---|
| dwl | sway 1.9 (Ubuntu) is the compositor; dwl's status stream is written to `kawa-dwlstatus` by hand: tags 1 2 4 5 occupied, 1 selected, 5 urgent, layout `[]=`, layout US, title `~/repos/fedokawaii` |
| `playerctl`, `cava` | one player, Playing "Mariya Takeuchi — Plastic Love"; one fixed meter frame (so the cassette's reels are always in the same position) |
| `/proc/stat` (first line) | `lib/fakestat.py`, bind-mounted inside the namespace: a steady synthetic load, so the CPU history does not depend on what else this shared VM is doing |
| `nmcli`, `bluetoothctl` | wired network up; one powered controller. `/sys/class/bluetooth/hci0` exists only for the `menu-quick` process (a private mount) |
| `ddcutil` | one DDC/CI monitor, brightness kept in a state file |
| `curl` (Open-Meteo only) | a week of Sharjah's October in Open-Meteo's JSON (33° and clear now; sun, cloud, fog, rain), its days from today; any other URL goes to the real curl |
| `steam` | installed (kawa-steam --menu asks `command -v steam`); asked anything, nothing |
| `cliphist` | a clipboard history with a URL, an image entry, Japanese and Arabic |
| `gammastep` | a process of that name (night light on, as autostart leaves it) |
| `wlr-randr` | `/tmp/veiltest/fakebin/wlr-randr`: sway's outputs in wlr-randr's format |
| audio devices | PipeWire null sinks/source named like the owner's machine (the Ryzen HD audio controller's ALC1220 analog, the Navi 48's HDMI to an LG ULTRAGEAR); `stubs/pw-dump` adds their cards and active routes (Line Out, Rear Microphone, HDMI / DisplayPort), which null devices lack |
| launcher entries | `xdg/share/applications`: Fedora's `.desktop` names/icons for the GUI apps setup.sh installs, plus foot's own three |
| system identity | inside the namespace: hostname `fedokawaii`, a Fedora 44 Server `/etc/os-release` (what `fetch` prints) |
| `~/repos/fedokawaii` | recreated each run: a copy of the repo as a git repo with +1 staged, ~2 modified, ?1 untracked, ↑1 ahead |
| the screenshot in `notify-normal` | a crop of the wallpaper's Fuji scene |

## Built at Fedora 44's versions (`build.sh` → `/opt/f44`)

Versions from packages.fedoraproject.org (Fedora 44 column; the `fedora-44.html` release
page where the overview showed a later update). Sources: GitHub (git tags) or upstream
release tarballs from Ubuntu's archive pool (Codeberg, freedesktop/GNOME GitLab and
Fedora's own hosts are not reachable from this sandbox).

| package | F44 | built | source |
|---|---|---|---|
| waybar | 0.15.0 | 0.15.0 | github.com/Alexays/Waybar tag (spdlog 1.15.2 / fmt 12.0.0 wraps from GitHub) |
| fuzzel | 1.14.0 | 1.14.0 | tag 1.14.0 from the GitHub fork yangyingchao/fuzzel-x — Daniel Eklöf's PGP-signed tag object, verified with the key Debian ships (B19964FB…C116573F) |
| mako | 1.11.0 | 1.11.0 | github.com/emersion/mako tag v1.11.0 |
| gtklock | 4.0.0 | 4.0.0 | github.com/jovanlanik/gtklock tag v4.0.0, built against the GTK above into `/opt/r18` (`stubs/gtklock` runs it) |
| foot | 1.27.0 | 1.27.0 | foot_1.27.0.orig.tar.xz (Ubuntu pool; sha256 matches the .dsc) |
| fcft | 3.3.3 | 3.3.3 | fcft_3.3.3.orig.tar.xz (Ubuntu pool) |
| tllist | 1.1.0 | 1.1.0 | tllist_1.1.0.orig.tar.gz (Ubuntu pool) |
| gtk-layer-shell | 0.10.0 | 0.10.0 | github.com/wmww/gtk-layer-shell |
| wireplumber | 0.5.18 | 0.5.18 | github.com/PipeWire/wireplumber |
| wayland-protocols | 1.49 | 1.49 | Ubuntu pool |
| pixman | 0.46.2 | 0.46.4 | Ubuntu pool (0.46.2 not reachable) |
| glib2 | 2.88.4 | 2.88.4 | github.com/GNOME/glib (+ gvdb from github.com/GNOME/gvdb) |
| fribidi | 1.0.16 | 1.0.16 | github.com/fribidi/fribidi |
| freetype | 2.14.3 | 2.14.3 | github.com/freetype/freetype VER-2-14-3 (with harfbuzz, as Fedora) |
| harfbuzz | 14.1.0 | 14.1.0 | github.com/harfbuzz/harfbuzz (with graphite2, as Fedora) |
| fontconfig | 2.17.0 | 2.17.0 | github.com/fontconfig/fontconfig (library only; reads the system's /etc/fonts) |
| cairo | 1.18.4 (GA) / 1.18.6 (update) | 1.18.4 | Ubuntu pool (1.18.6 not reachable) |
| pango | 1.57.1 | 1.57.1 | github.com/GNOME/pango |
| gtk3 | 3.24.52 | 3.24.52 | github.com/GNOME/gtk |

Also installed for the renders: adw-gtk3 6.4 (GitHub release) into /usr/share/themes,
Papirus 20250501 (git tag) into /usr/share/icons, apt fonts-noto-core,
fonts-noto-color-emoji, fonts-liberation, fonts-hosny-amiri, wtype, libnotify-bin,
pipewire, dconf-cli; the user's fonts in `~kawau/.local/share/fonts` as setup.sh lays
them out (`DepartureMonoNerd/`, `JetBrainsMonoNerd/`, `PixelMplus/`).

The session uses `LD_LIBRARY_PATH=/opt/f44/lib`, so every app (including waybar's
GTK/gtkmm and mako's pango/cairo) draws with the Fedora 44 stack above; `logs/<theme>/libs.txt`
shows it.

## One-time setup (already done in this sandbox)

```sh
# build deps (Ubuntu 24.04) — see build.sh for what each is for
apt-get install meson ninja-build scdoc pkg-config cmake gperf libwayland-dev libxkbcommon-dev \
  libxkbregistry-dev libfreetype-dev libfontconfig-dev libharfbuzz-dev libutf8proc-dev libpng-dev \
  libcairo2-dev libpango1.0-dev libglib2.0-dev libsystemd-dev libgdk-pixbuf-2.0-dev libpam0g-dev \
  libgtkmm-3.0-dev libgtk-3-dev libjsoncpp-dev libsigc++-2.0-dev libinput-dev libnl-3-dev \
  libnl-genl-3-dev libupower-glib-dev libpipewire-0.3-dev libplayerctl-dev libpulse-dev libudev-dev \
  libevdev-dev libmpdclient-dev libdbusmenu-gtk3-dev liblua5.4-dev libffi-dev libpcre2-dev \
  libmount-dev libexpat1-dev libbrotli-dev libbz2-dev libgraphite2-dev liblzo2-dev libthai-dev \
  libepoxy-dev libxi-dev libxrandr-dev libxcursor-dev libxdamage-dev libxcomposite-dev \
  libxinerama-dev libhowardhinnant-date-dev
# runtime
apt-get install pipewire pipewire-bin dbus-daemon dbus-bin libnotify-bin wtype dconf-cli jq \
  fonts-noto-core fonts-noto-color-emoji fonts-liberation fonts-hosny-amiri
python3 -m venv /opt/f44/meson-venv && /opt/f44/meson-venv/bin/pip install meson==1.9.1
./build.sh                                    # → /opt/f44 (≈35 min on 2 cores)
# themes as Fedora 44 packages them
tar xf adw-gtk3v6.4.tar.xz -C /usr/share/themes          # GitHub release v6.4
cp -a papirus/{Papirus,Papirus-Dark,Papirus-Light} /usr/share/icons/   # git tag 20250501
# the user's fonts, laid out as setup.sh does (owned by kawau), then fc-cache as kawau:
#   ~/.local/share/fonts/DepartureMonoNerd/*.otf   (DepartureMono.tar.xz, Nerd Fonts v3.5.1)
#   ~/.local/share/fonts/JetBrainsMonoNerd/*.ttf   (JetBrainsMono.tar.xz)
#   ~/.local/share/fonts/PixelMplus/PixelMplus12-Regular.ttf
```

Note: earlier test sessions left stand-ins in `/usr/local/bin` (`dconf`, `fc-cache`,
`magick` → `convert`, `dwl`, `grub2-*`, `grubby`). The session's PATH puts `/usr/local/bin`
last, so the real `dconf`/`fc-cache` win and only `magick` (used by kawa-wallpaper) comes
from there; shoot.sh calls `/usr/bin/dconf update` and the real `fc-cache` itself.

## Limitations

- **Compositor**: sway 1.9 (wlroots 0.17), not dwl 0.9. Layer-shell surfaces (bar, menus,
  notices, wallpaper, lock) are placed by the same protocol, so their geometry is what dwl
  gives; dwl's own window frames, gaps and centred-dialog patch are not drawn, and the
  terminal floats at a fixed size instead of tiling.
- Still Ubuntu 24.04's: libwayland 1.22, xkbcommon 1.6, gdk-pixbuf 2.42 (icons/images),
  gtkmm 3.24.9, PipeWire 1.0.5, bash 5.2.21 (Fedora 44: 5.3 — `fetch` prints it), the
  fontconfig *configuration* in /etc/fonts (Ubuntu's conf.d, read by fontconfig 2.17).
- PixelMplus 12 is the Regular face only (no Bold in the provided fonts).
- Time is real (Asia/Dubai): the clock and the prompt's time and its sun/moon follow the
  time of the run, and the week's menu starts on that day.
- kawa-theme runs as the veiled half of a switch (`KAWA_VEILED=1`), so the seigaiha
  transition (kawa-veil) is not part of the shots; the end state is the same.
- The cursor in foot blinks; the shot is taken right after focus, when it is lit.
- The portals are Ubuntu's (xdg-desktop-portal + -gtk + -wlr, D-Bus-activated after
  `dbus-update-activation-environment`, as autostart's `import-environment`): waybar reads
  the colour scheme from them ("Discovered appearance 'dark'"). The document portal cannot
  mount FUSE here (harmless log lines in `dbus.log`).
- foot server: a footclient started from a directory the user cannot enter makes foot
  1.27.0's server fail to create the terminal and then lose its Wayland connection
  (every foot window closes). shoot.sh starts everything from `~` to avoid it.

# The applications (`apps.sh`)

```sh
sudo ./apps.sh                                   # both themes (≈6 minutes)
sudo APPS_ONLY="yazi nvim" ./apps.sh light       # groups: yazi nvim lazygit btop mpv zathura
                                                 #   filechooser share torrra brave books notes
                                                 #   system wiremix bluetui visidata
                                                 #   nvim-whichkey nvim-picker nvim-grep nvim-split
                                                 #   nvim-lsp lazygit-log lazygit-commit lazygit-stage
                                                 #   yazi-preview yazi-drives
```

It reads shoot.sh's functions (without its main part) and uses the same session; then it
opens the apps on top of it and saves `shots/<theme>/app-<group>.png` (the window, 1:1) and
`app-<group>-full.png` (the whole screen, same frame). Logs: `logs/<theme>/apps/`,
`logs/apps-warnings.txt`, `logs/<theme>/apps/versions.txt`. A full shoot.sh run leaves the
`app-*` files alone.

The user's home is **not written**: inside each theme's namespace `/home/kawau` is an
overlay whose writes go to `apps-cache/run/<theme>/` (deleted at the end; `APPS_KEEP=1`
keeps it). Demo files (`~/Documents`, `~/Videos`, `~/Pictures`), `secrets.sh` with the stand-in
Prowlarr key, the demo repository (apps.sh's own `demo_repo`: the repo's files committed in a dozen
steps dated Sep–Oct 2026, a merged `wallpaper` branch and an open `torrra` one, origin one commit
behind; then work in progress like shoot.sh's: +1 staged, ~2 modified, ?1 untracked), a fresh dconf user database, Brave's profile, torrra's config…
all live there. The system dconf defaults are compiled from the repo's `00-fedokawaii` only
and bind-mounted over `/etc/dconf/db/local` (this sandbox's `local.d` still holds an old
`00-scriptorium` that would override `gtk-theme` and `button-layout`).

| shot | how |
|---|---|
| `app-yazi` | `footclient yazi ~/Documents/notes.md` (a folder, a PDF, a PNG, the notes previewed) |
| `app-nvim` | `nvim bin/kawa-theme` in the demo repo, LazyVim starter + the repo's colorscheme spec; second start (the first is a warm-up) |
| `app-lazygit` | lazygit in the demo repo; its one-time intro popup closed with Enter, `setup.sh` selected |
| `app-nvim-whichkey` | `bin/kawa-theme` as in `app-nvim`, Space pressed: which-key's leader menu |
| `app-nvim-picker` | Space Space (Snacks file picker, ripgrep's file list) with `wall` typed, `bin/kawa-wallpaper` previewed |
| `app-nvim-grep` | Space / (live grep, ripgrep) for `gsettings`: 10 matches in 4 files, the preview at the first |
| `app-nvim-split` | `:vsplit bin/kawa-wallpaper` next to `bin/kawa-theme`, then Space e: the explorer on the left |
| `app-nvim-lsp` | `kawa-ipc.lua` with lua_ls (Mason): "Undefined global `mp`" diagnostics and the hover (K) of `os.getenv` |
| `app-lazygit-log` | 4: the Commits panel focused, `kawa-weather: …` selected below the merge, its patch on the right |
| `app-lazygit-commit` | `theme.sh` (staged) selected, c: the commit summary box with a message typed (not committed) |
| `app-lazygit-stage` | `setup.sh`: Enter, `a` (hunk), Space, Esc: one of its three hunks staged (MM), the unstaged and staged diffs |
| `app-yazi-preview` | yazi in `~/Pictures` with `fuji-dawn.png` hovered: the picture previewed (sixel, foot) |
| `app-btop`, `app-btop-themefix` | btop started first on another workspace so its graphs have history; `-themefix` is the same btop with the theme where btop can find it (see below) |
| `app-mpv` | mpv 0.41 (`--gpu-sw`: no GPU here) on a 10 s video of the light wallpaper's Fuji, controller shown (`osc-visibility always`), paused at 0:04 |
| `app-zathura` | the handbook PDF at page 5 |
| `app-filechooser` | `lib/filechooser.c` (GTK 3.24.52 from /opt/f44): GtkFileChooserDialog "Open File", theme from GSettings |
| `app-share` | `kawa-share` fed four xdg-desktop-portal-wlr 0.8.4 lines; `wlr-randr` answers for DP-1 and HDMI-A-1 |
| `app-torrra`, `app-torrra-search` | `kawa-torrra --open` (the launcher's way) with `lib/fakeprowlarr.py` on 127.0.0.1:9696; "ubuntu 24.04" typed |
| `app-brave` | Brave Origin new-tab page, second start, `--no-first-run --no-default-browser-check`, `brave.origin.free_tier_accepted` set (the one-time Origin question answered "Proceed") |
| `app-wiremix` | `kawa-float --once mixer mixer 96x29 -- wiremix` (Super+A → *mixer*) while `mpv --no-video` plays the test video: one stream on the Playback tab |
| `app-bluetui` | `kawa-float --once pair pair 96x29 -- bluetui` (Super+X → *pair a device*) on a private session bus where `lib/fakebluez.py` answers as BlueZ (adapter `fedokawaii`; a game controller and a headset paired, a phone found nearby), after **s** (scan) |
| `app-visidata` | `vd weather.csv` in `~/practice` (a small made-up table), a column made numeric (`#`), sorted (`[`), summed (`+` → sum): the frequency line at the bottom |

Fetched once into `apps-cache/` (kept): yazi (latest release, as lib/upstream.sh),
lazygit, neovim, tree-sitter (GitHub releases, newest tags via `git ls-remote`: the API is
not reachable); LazyVim's plugins, parsers and Mason tools (`apps-cache/nvim/share`, bind-
mounted as `~/.local/share/nvim`). nvim-treesitter's GitHub tarballs and Mason's
"latest registry" API call are refused by this sandbox's proxy, so the one-time install uses
`lib/curl-github-archive` (the same tarball made with `git archive`) and `lib/nvim-mason.lua`
(the registry tag from `git ls-remote`). apt: btop 1.3.0, zathura 0.5.4 +
zathura-pdf-poppler (Fedora: mupdf).

Not packaged for this Ubuntu, kept in `/opt/kit-tools/bin` (and linked into the test user's
`~/.local/bin`): wiremix v0.11.0 (built from its tag with `cargo build --locked`), bluetui
0.8.2 (the upstream static musl release file, the one lib/upstream.sh pins) and gdu v5.32.0,
and VisiData 3.3 with dbus-next 0.2.3 in `/opt/kit-tools/venv` (pip; dbus-next
is what `lib/fakebluez.py` runs on).

Debugging: `APPS_HOLD=1` keeps a theme's session up until `/tmp/shoot-kawa-apps/release`
exists (enter it with `nsenter -t <PID 1 of the namespace> -m -p`).
