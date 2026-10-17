#!/bin/bash
# apps.sh — the desktop's applications, for real, in the dark and the light theme: shoot.sh's
# companion for the handbook. It reuses shoot.sh's session (its functions are read from
# shoot.sh: D-Bus, PipeWire, headless sway, kawa-theme, mako, the foot server, waybar) and
# adds the apps on top of it.
#
#   sudo ./apps.sh                     both themes
#   sudo ./apps.sh light               one theme
#   sudo APPS_ONLY="yazi nvim" ./apps.sh dark     only some groups:
#        yazi nvim lazygit btop mpv zathura filechooser share torrra brave (default: all)
#        books notes system wiremix bluetui visidata
#        nvim-whichkey nvim-picker nvim-grep nvim-split nvim-lsp lazygit-log
#        lazygit-commit lazygit-stage yazi-preview yazi-drives
#
# Shots → shots/<theme>/app-<group>.png (the window 1:1) and app-<group>-full.png (the whole
# screen in that same frame). Logs → logs/<theme>/apps/, summary → logs/apps-warnings.txt.
#
# The user's home is not written: inside each theme's namespace /home/$K is an overlay whose
# writes land in apps-cache/run/<theme> (deleted afterwards; APPS_KEEP=1 keeps it). So the
# demo files, the Prowlarr key in secrets.sh, the theme switch, dconf, Brave's profile,
# torrra's config, lazygit's state … all stay in there.
#
# Fetched once into apps-cache/ (GitHub releases / git; kept between runs):
#   opt/     yazi + ya (latest release, as lib/upstream.sh), lazygit, neovim, tree-sitter
#   nvim/    LazyVim's plugins, tree-sitter parsers and Mason tools (~/.local/share/nvim)
#   media/   the test video (ffmpeg) and the demo files
# Also used: btop and zathura from apt, mpv 0.41 (../media/mpv041/AppDir), torrra 2.5.1
# (../media/venv313), Brave Origin (../brave/root/opt/brave.com/brave-origin).
set -uo pipefail
APPS_SELF=$(readlink -f "$0")
# shoot.sh, without its main part (the last if … fi): every function and setting it has
# shellcheck source=shoot.sh
source <(sed '/^if \[\[ \${1:-} == --inner \]\]; then$/,$d' "${APPS_SELF%/*}/shoot.sh")
SELF=$APPS_SELF
SH=/tmp/shoot-kawa-apps            # staged helpers (readable by $K); shoot.sh's is /tmp/shoot-kawa
X=/tmp/xdg-kawa-apps               # the session's XDG_RUNTIME_DIR
C=$R/apps-cache
REPO=${FEDOKAWAII_REPO:-/home/claude/fedokawaii}
ALL_GROUPS="yazi nvim lazygit btop mpv zathura filechooser share torrra brave books notes system
  nvim-whichkey nvim-picker nvim-grep nvim-split nvim-lsp lazygit-log lazygit-commit lazygit-stage yazi-preview
  yazi-drives wiremix bluetui visidata"
ALL_GROUPS=$(echo $ALL_GROUPS)
ONLY=${APPS_ONLY:-$ALL_GROUPS}
KEY=0123456789abcdef0123456789abcdef       # the stand-in Prowlarr's API key
MPV_APPDIR=${APPS_MPV_APPDIR:-$(readlink -f "$R/../media/mpv041/AppDir")}
TORRRA_VENV=${APPS_TORRRA_VENV:-$(readlink -f "$R/../media/venv313")}
BRAVE_DIR=${APPS_BRAVE_DIR:-$(readlink -f "$R/../brave/root/opt/brave.com/brave-origin")}
CA=/tmp/ca-bundle.crt                      # a CA bundle $K can read (the agent proxy's)
NETENV=(HTTPS_PROXY="${HTTPS_PROXY:-}" https_proxy="${HTTPS_PROXY:-}" NO_PROXY="${NO_PROXY:-}"
        no_proxy="${NO_PROXY:-}" CURL_CA_BUNDLE=$CA GIT_SSL_CAINFO=$CA SSL_CERT_FILE=$CA)

# ──────────────────────────────────────────────────────────────────────────────────────
# outer: checks, downloads, staging, LazyVim's install, one namespace per theme, summary
# ──────────────────────────────────────────────────────────────────────────────────────
latest_tag() {   # latest_tag OWNER/REPO — the newest vX.Y.Z tag (git: the API is not reachable here)
  git ls-remote --tags --refs "https://github.com/$1.git" 2>/dev/null | awk '{print $2}' \
    | sed 's|^refs/tags/||' | grep -E '^v?[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -1
}

gh_get() {   # gh_get OWNER/REPO TAG ASSET OUT
  [[ -s $4 ]] && return 0
  curl -fsSL --retry 3 -o "$4.part" "https://github.com/$1/releases/download/$2/$3" && mv "$4.part" "$4"
}

fetch_tools() {   # → $C/opt/bin: yazi ya lazygit nvim tree-sitter, and $C/opt/versions
  local o=$C/opt d=$C/dl t
  [[ -x $o/bin/yazi && -x $o/bin/lazygit && -x $o/bin/nvim && -x $o/bin/tree-sitter && -s $o/versions ]] && return 0
  say "fetching yazi, lazygit, neovim, tree-sitter (GitHub releases)"
  mkdir -p "$d"; rm -rf "$o"; mkdir -p "$o/bin" "$o/x"
  local ty tl tn tt
  ty=$(latest_tag sxyazi/yazi) tl=$(latest_tag jesseduffield/lazygit) tn=$(latest_tag neovim/neovim) \
    tt=$(latest_tag tree-sitter/tree-sitter)
  [[ -n $ty && -n $tl && -n $tn && -n $tt ]] || { warn "could not list the release tags"; return 1; }
  gh_get sxyazi/yazi "$ty" yazi-x86_64-unknown-linux-musl.zip "$d/yazi-$ty-x86_64-unknown-linux-musl.zip" &&
  gh_get jesseduffield/lazygit "$tl" "lazygit_${tl#v}_linux_x86_64.tar.gz" "$d/lazygit_${tl#v}_linux_x86_64.tar.gz" &&
  gh_get neovim/neovim "$tn" nvim-linux-x86_64.tar.gz "$d/nvim-$tn-linux-x86_64.tar.gz" &&
  gh_get tree-sitter/tree-sitter "$tt" tree-sitter-linux-x64.gz "$d/tree-sitter-$tt-linux-x64.gz" \
    || { warn "a download failed"; return 1; }
  unzip -q "$d/yazi-$ty-x86_64-unknown-linux-musl.zip" -d "$o/x/yazi" &&
  install -m 755 "$o"/x/yazi/*/yazi "$o"/x/yazi/*/ya "$o/bin/" &&
  tar -xzf "$d/lazygit_${tl#v}_linux_x86_64.tar.gz" -C "$o/x" lazygit && install -m 755 "$o/x/lazygit" "$o/bin/" &&
  tar -xzf "$d/nvim-$tn-linux-x86_64.tar.gz" -C "$o" && ln -sfn ../nvim-linux-x86_64/bin/nvim "$o/bin/nvim" &&
  gunzip -c "$d/tree-sitter-$tt-linux-x64.gz" >"$o/bin/tree-sitter" && chmod 755 "$o/bin/tree-sitter" \
    || { warn "unpacking failed"; return 1; }
  rm -rf "$o/x"; chmod -R a+rX "$o"
  printf 'yazi %s\nlazygit %s\nneovim %s\ntree-sitter %s\n' "$ty" "$tl" "$tn" "$tt" >"$o/versions"
}

make_media() {   # the test video, the demo PDF/picture/notes (→ $C/media, copied to $SH/media)
  local m=$C/media wp=$OUT/light/wallpaper.png
  mkdir -p "$m"
  if [[ ! -s $m/fuji-dawn.mkv ]]; then
    say "making the test video (ffmpeg)"
    if [[ -s $wp ]]; then    # the light wallpaper's pixel-art Fuji, panned slowly (whole pixels)
      ffmpeg -nostdin -loglevel error -y -loop 1 -framerate 30 -i "$wp" \
        -f lavfi -i "sine=frequency=220:sample_rate=48000:duration=10" \
        -filter_complex "[0:v]crop=1280:720:'240+trunc(t*16)':360,format=yuv420p[v];[1:a]volume=0.1[a]" \
        -map '[v]' -map '[a]' -t 10 -c:v libx264 -preset veryfast -crf 16 -c:a aac -b:a 96k \
        -metadata title="Fuji at dawn" "$m/fuji-dawn.mkv"
    else                     # colour bars
      ffmpeg -nostdin -loglevel error -y -f lavfi -i "smptehdbars=size=1280x720:rate=30:duration=10" \
        -f lavfi -i "sine=frequency=220:sample_rate=48000:duration=10" -c:v libx264 -pix_fmt yuv420p \
        -c:a aac -metadata title="Colour bars" "$m/fuji-dawn.mkv"
    fi || warn "ffmpeg failed"
  fi
  if [[ ! -s $m/fuji-dawn.png && -s $wp ]]; then
    python3 -I -c 'import sys; from PIL import Image; Image.open(sys.argv[1]).crop((480, 720, 1440, 1080)).save(sys.argv[2])' \
      "$wp" "$m/fuji-dawn.png"
  fi
  cat >"$m/notes.md" <<'EOF'
# Weekend

## Sat — Kawaguchiko
- 07:10 bus from Shinjuku (seat 4A)
- walk the north shore to Oishi Park
- **onsen** at Fuji-yurari before dinner

## Sun — back to town
1. coffee at the station
2. pick up the prints (¥2,400)
3. `kawa-wallpaper --pack` — new pictures

> 富士山 at dawn: best light at 05:40.

| what   | cost    |
|--------|---------|
| bus    | ¥2,200  |
| ryokan | ¥18,000 |
EOF
  printf 'Receipt 2026-09-12\nKonbini, Kawaguchiko\nonigiri ×2   ¥340\ntea          ¥160\ntotal        ¥500\n' >"$m/receipt-0912.txt"
  rm -rf "${SH:?}/media"; mkdir -p "$SH/media"; cp -a "$m/." "$SH/media/"
  cp "$REPO/docs/Fedokawaii-Guide.pdf" "$SH/media/fedokawaii-guide.pdf"
  chmod -R a+rX "$SH/media"
}

build_filechooser() {   # lib/filechooser.c against /opt/f44's GTK 3 → $SH/bin/kawa-filechooser
  install -d -m 755 "$SH/bin"
  PKG_CONFIG_PATH=$F44/lib/pkgconfig gcc -O2 -Wall -o "$SH/bin/kawa-filechooser" "$R/lib/filechooser.c" \
    $(PKG_CONFIG_PATH=$F44/lib/pkgconfig pkg-config --cflags --libs gtk+-3.0) -Wl,-rpath,$F44/lib \
    2>"$LOG/filechooser-build.log" || warn "filechooser.c did not build (see $LOG/filechooser-build.log)"
}

stage() {
  say "staging stubs and helpers in $SH"
  rm -rf "$SH"; install -d -m 755 "$SH"
  cp -a "$R/stubs" "$R/lib" "$R/xdg" "$R/books" "$R/sway.conf" "$SH/"
  cat >>"$SH/sway.conf" <<'EOF'

# apps.sh: the applications at the sizes of the handbook's shots (dwl would tile them; the
# file chooser it floats and centres, as here)
for_window [app_id="^app-"] floating enable, resize set 1104 704, move position center
for_window [app_id="^mpv$"] floating enable, move position center
for_window [app_id="^org.pwmt.zathura$"] floating enable, resize set 1104 764, move position center
for_window [app_id="^kawa-filechooser$"] floating enable, move position center
for_window [app_id="^xdg-desktop-portal-gtk$"] floating enable, move position center
for_window [app_id="^brave"] floating enable, resize set 1284 804, move position center
EOF
  install -d -m 755 "$SH/opt" "$SH/mpv" "$SH/torrra-venv" "$SH/brave" "$SH/bin" "$SH/share-bin"
  # torrra's wrapper, as setup.sh installs it (/usr/local/bin/kawa-torrra)
  install -m 755 "$REPO/system/kawa-torrra" "$SH/bin/kawa-torrra"
  # the screen-share menu's two monitors (the input names DP-1 and HDMI-A-1): wlr-randr
  # answering for them, as on a two-monitor machine
  cat >"$SH/share-bin/wlr-randr" <<'EOF'
#!/bin/sh
cat <<'OUT'
DP-1 "Dell Inc. DELL U2723QE 7X2Y1T3 (DP-1)"
  Make: Dell Inc.
  Model: DELL U2723QE
  Enabled: yes
  Modes:
    3840x2160 px, 59.997002 Hz (preferred, current)
  Position: 0,0
  Transform: normal
  Scale: 1.500000
HDMI-A-1 "LG Electronics LG HDR 4K 0x0007D5A1 (HDMI-A-1)"
  Make: LG Electronics
  Model: LG HDR 4K
  Enabled: yes
  Modes:
    3840x2160 px, 60.000000 Hz (preferred, current)
  Position: 2560,0
  Transform: normal
  Scale: 1.500000
OUT
EOF
  chmod 755 "$SH/share-bin/wlr-randr"
  chmod -R a+rX "$SH"
  install -d -m 755 -o "$K" -g "$K" "$SH/state"
  cat >"$SH/state/os-release" <<'EOF'
NAME="Fedora Linux"
VERSION="44 (Server Edition)"
RELEASE_TYPE=stable
ID=fedora
VERSION_ID=44
PLATFORM_ID="platform:f44"
PRETTY_NAME="Fedora Linux 44 (Server Edition)"
ANSI_COLOR="0;38;2;60;110;180"
CPE_NAME="cpe:/o:fedoraproject:fedora:44"
HOME_URL="https://fedoraproject.org/"
VARIANT="Server Edition"
VARIANT_ID=server
SUPPORT_END=2027-06-02
EOF
  # the system dconf defaults exactly as the repo installs them (only 00-fedokawaii: this
  # sandbox's /etc/dconf/db/local.d still holds an older test's 00-scriptorium, which
  # overrides gtk-theme and button-layout ':close'); bind-mounted inside the namespace
  install -d -m 755 "$SH/dconf.d"
  cp "$REPO/configs/system/etc/dconf/db/local.d/00-fedokawaii" "$SH/dconf.d/"
  /usr/bin/dconf compile "$SH/dconf-local" "$SH/dconf.d" || warn "dconf compile failed"
  chmod 644 "$SH/dconf-local"
}

outer_apps() {
  [[ $EUID -eq 0 ]] || die "run as root (it starts the session as $K inside namespaces)"
  [[ -n $KH && -d $KH ]] || die "no user $K"
  local themes=("$@") t b miss=()
  ((${#themes[@]})) || themes=(dark light)
  for t in "${themes[@]}"; do
    [[ $t == dark || $t == light ]] || die "unknown theme '$t' (dark|light)"
    [[ -d $KH/.config/fedokawaii/themes/$t ]] || die "$KH/.config/fedokawaii/themes/$t missing — run theme.sh --user $K"
  done
  for b in $F44/bin/{waybar,fuzzel,mako,makoctl,foot,footclient,wireplumber,wpctl} sway swaymsg grim swaybg \
           wtype pipewire pw-cli pw-dump dbus-daemon notify-send jq setpriv unshare git curl unzip gcc pkg-config \
           ffmpeg btop zathura python3.13; do
    command -v "$b" >/dev/null || miss+=("$b")
  done
  [[ -x $MPV_APPDIR/bin/mpv ]] || miss+=("mpv 0.41 AppDir ($MPV_APPDIR)")
  [[ -x $TORRRA_VENV/bin/python ]] || miss+=("torrra venv ($TORRRA_VENV)")
  [[ -x $BRAVE_DIR/brave ]] || warn "no Brave Origin at $BRAVE_DIR: the brave group is skipped"
  ((${#miss[@]} == 0)) || die "missing: ${miss[*]} (see README.md)"
  python3 -c 'import PIL' 2>/dev/null || die "python3-PIL missing"
  # another session of the user's (outside apps.sh) is no obstacle: everything here runs in
  # its own PID + mount namespace, with its own runtime dir, bus and compositor, and the home
  # it sees is an overlay — the two cannot see or signal each other
  for b in waybar mako fuzzel foot swaylock wireplumber sway pipewire; do
    pgrep -u "$K" -x "$b" >/dev/null && { warn "$K also runs $b outside apps.sh (left alone)"; break; }
  done
  if want torrra && [[ -n $(awk 'NR > 1 && $4 == "0A" && $2 ~ /:25D0$/' /proc/net/tcp) ]]; then
    die "something already listens on 127.0.0.1:9696 (the stand-in Prowlarr needs it)"
  fi
  mkdir -p "$OUT" "$LOG" "$C"
  fetch_tools || die "the tools could not be fetched"
  stage
  make_media
  want filechooser && build_filechooser
  if want nvim; then
    say "LazyVim: plugins, parsers, tools (as $K, in a scratch home)"
    timeout -k 10 1500 unshare --pid --fork --kill-child --mount --mount-proc --propagation private \
      -- "$SELF" --prep-nvim || warn "the LazyVim install ended with status $?"
  fi
  local rc=0
  for t in "${themes[@]}"; do
    say "── $t theme (apps) ─────────────────────"
    timeout -k 10 1200 unshare --pid --fork --kill-child --mount --uts --mount-proc --propagation private \
      -- "$SELF" --inner-apps "$t" || { rc=$?; warn "$t: the session ended with status $rc"; }
  done
  [[ ${APPS_KEEP:-0} == 1 ]] || rm -rf "$C/run"
  rm -rf "${X:?}"/* 2>/dev/null
  summary_apps "${themes[@]}"
  return $rc
}

summary_apps() {
  local f t
  {
    echo "# What the apps printed (apps.sh $(date '+%F %T'))"
    for t in "$@"; do
      echo; echo "## $t"
      for f in "$LOG/$t/apps"/*.log; do
        [[ -s $f ]] || continue
        grep -aE -i 'warn|error|fail|invalid|unknown|not found|deprecat|could not|cannot|unable|missing|critical' "$f" \
          | grep -avE 'rtkit|RealtimeKit|mod\.rt|libcamera|bluez|logind|modem-manager|portal|reserve-device|v4l2|module-dbus|system bus|dbus-daemon\[|Activating service' \
          | sed "s|^|${f##*/}: |" | head -40
      done
    done
  } >"$LOG/apps-warnings.txt"
  say "warnings → $LOG/apps-warnings.txt"
  for t in "$@"; do say "$(find "$OUT/$t" -name 'app-*.png' 2>/dev/null | wc -l) app PNGs in $OUT/$t"; done
}

# ──────────────────────────────────────────────────────────────────────────────────────
# inside a namespace: the user's home as an overlay, the tools bind-mounted
# ──────────────────────────────────────────────────────────────────────────────────────
mount_home() {   # mount_home TAG — /home/$K becomes a copy-on-write view (writes → $C/run/TAG)
  local u=$C/run/$1 d
  rm -rf "$u"; mkdir -p "$u/upper" "$u/work"
  chown --reference="$KH" "$u/upper"; chmod --reference="$KH" "$u/upper"
  mount -t overlay overlay -o "lowerdir=$KH,upperdir=$u/upper,workdir=$u/work" "$KH" || die "overlay on $KH failed"
  mount --bind "$C/opt" "$SH/opt" || die "bind $C/opt failed"
  # LazyVim's plugins, parsers and Mason's tools, kept between runs (~/.local/share/nvim)
  install -d -o "$K" -g "$K" "$C/nvim" "$C/nvim/share" "$C/nvim/config"
  for d in "$KH/.local" "$KH/.local/share" "$KH/.local/share/nvim"; do
    [[ -d $d ]] || install -d -o "$K" -g "$K" "$d"
  done
  mount --bind "$C/nvim/share" "$KH/.local/share/nvim" || die "bind nvim data failed"
  # LazyVim's starter, as setup.sh's s_lazyvim lays it out (cp -rn: the repo's files stay)
  if [[ ! -f $KH/.config/nvim/init.lua ]]; then
    cp -r --update=none "$C/lazyvim-starter/." "$KH/.config/nvim/" && rm -rf "$KH/.config/nvim/.git"
    cp --update=none "$C/nvim/config"/*.json "$KH/.config/nvim/" 2>/dev/null
    chown -R "$K:$K" "$KH/.config/nvim"
  fi
}

ku() {   # ku CMD… — as the user, without the session (for the LazyVim install)
  setpriv --reuid="$KUID" --regid="$KGID" --init-groups -- env -i HOME="$KH" USER="$K" LOGNAME="$K" \
    SHELL=/bin/bash LANG=C.UTF-8 TERM=xterm-256color XDG_RUNTIME_DIR="$SH/prep-run" \
    PATH="$SH/prep-bin:$SH/opt/bin:$KH/.local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/bin" "${NETENV[@]}" "$@"
}

prep_nvim() {   # LazyVim + plugins, as setup.sh does it (`nvim --headless '+Lazy! sync' +qa`), and
  local L=$LOG/nvim-prep.log    # what its first interactive start would then fetch: parsers, Mason tools
  [[ -d $C/lazyvim-starter/lua ]] || git clone -q --depth 1 https://github.com/LazyVim/starter "$C/lazyvim-starter" \
    || die "could not clone LazyVim/starter"
  mount_home prep
  install -d -m 700 -o "$K" -g "$K" "$SH/prep-run"
  install -d -m 755 "$SH/prep-bin"      # nvim-treesitter's tarballs through git (lib/curl-github-archive)
  install -m 755 "$SH/lib/curl-github-archive" "$SH/prep-bin/curl"
  : >"$L"
  {
    echo "== nvim --headless '+Lazy! sync' +qa"
    ku timeout 900 nvim --headless '+Lazy! sync' +qa 2>&1
    echo "exit $?"
    # the parsers LazyVim asks nvim-treesitter for (its first start would build them), and the
    # Mason tools its config installs (stylua, shfmt) plus lua_ls — with every job awaited
    echo "== tree-sitter parsers"
    ku timeout 900 nvim --headless -c "luafile $SH/lib/nvim-prep.lua" 2>&1
    echo "exit $?"
    echo "== Mason"
    ku env APPS_MASON_REGISTRY_TAG="$(git ls-remote --tags --refs https://github.com/mason-org/mason-registry.git \
      | sed 's|.*refs/tags/||' | grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}-' | sort | tail -1)" \
      timeout 900 nvim --headless -c "luafile $SH/lib/nvim-mason.lua" 2>&1
    echo "exit $?"
  } >>"$L"
  cp -f "$KH/.config/nvim/lazy-lock.json" "$KH/.config/nvim/lazyvim.json" "$C/nvim/config/" 2>/dev/null
  chown -R "$K:$K" "$C/nvim/config"
  du -sh "$C/nvim/share" >>"$L" 2>&1
}

# ──────────────────────────────────────────────────────────────────────────────────────
# inner: one theme, PID 1 of its own namespace
# ──────────────────────────────────────────────────────────────────────────────────────
home_setup() {   # what the user's home holds for the shots (all inside the overlay)
  local u=(setpriv --reuid="$KUID" --regid="$KGID" --init-groups -- env -i HOME="$KH" PATH=/usr/bin:/bin)
  # dconf: only what kawa-theme writes (a fresh user database, as on a new account)
  rm -f "$KH/.config/dconf/user"
  # the fetched tools on the user's PATH: yazi and ya where setup.sh puts them (~/.local/bin);
  # lazygit, nvim and tree-sitter (Fedora's are in /usr/bin) linked next to them
  local b
  for b in yazi ya lazygit nvim tree-sitter fd; do
    "${u[@]}" ln -sfn "$SH/opt/bin/$b" "$KH/.local/bin/$b"
  done
  # the yazi demo folder, the video, the PDF
  "${u[@]}" mkdir -p "$KH/Documents/Receipts" "$KH/Videos" "$KH/Downloads"
  "${u[@]}" cp "$SH/media/notes.md" "$SH/media/fedokawaii-guide.pdf" "$KH/Documents/"
  [[ -s $SH/media/fuji-dawn.png ]] && "${u[@]}" cp "$SH/media/fuji-dawn.png" "$KH/Documents/"
  "${u[@]}" cp "$SH/media/receipt-0912.txt" "$KH/Documents/Receipts/2026-09-12-konbini.txt"
  "${u[@]}" sh -c 'cd "$1" && printf "Receipt 2026-09-20\nBookshop, Jimbocho\n" >2026-09-20-books.txt' sh "$KH/Documents/Receipts"
  "${u[@]}" cp "$SH/media/fuji-dawn.mkv" "$KH/Videos/"
  # the Prowlarr key as setup.sh stores it (secrets.sh, mode 600, the user's)
  "${u[@]}" sh -c 'umask 077; printf "export PROWLARR_API_KEY=%s\n" "$1" >"$2"; chmod 600 "$2"' sh "$KEY" \
    "$KH/.config/fedokawaii/secrets.sh"
  # the demo repository (shoot.sh's: staged, modified, untracked, ahead), now in the overlay
  demo_repo >/dev/null 2>&1
  # the user's font cache, current (written into the overlay)
  setpriv --reuid="$KUID" --regid="$KGID" --init-groups env HOME="$KH" LD_LIBRARY_PATH="$F44/lib" \
    "$F44/bin/fc-cache" "$KH/.local/share/fonts" >/dev/null 2>&1
}

demo_repo() {   # (replaces shoot.sh's) ~/repos/fedokawaii with a history: the repo's files committed
  # in steps over a few weeks, a merged branch (wallpaper) and an open one (torrra), a remote
  # one commit behind; then shoot.sh's work in progress (+1 staged, ~2 modified, ?1 untracked)
  local d=$KH/repos/fedokawaii n=0
  rm -rf "$d" "$KH/repos/.remote"
  install -d -o "$K" -g "$K" "$KH/repos"
  g() { setpriv --reuid="$KUID" --regid="$KGID" --init-groups env -i HOME="$KH" PATH=/usr/bin:/bin \
          GIT_AUTHOR_NAME=kawau GIT_AUTHOR_EMAIL=kawau@fedokawaii GIT_COMMITTER_NAME=kawau \
          GIT_COMMITTER_EMAIL=kawau@fedokawaii GIT_CONFIG_NOSYSTEM=1 \
          GIT_AUTHOR_DATE="$gd" GIT_COMMITTER_DATE="$gd" git -C "$d" "$@" >/dev/null 2>&1; }
  ci() {   # ci DATE MESSAGE PATH… — add those paths (what is left of them) and commit
    local gd=$1 m=$2; shift 2
    g add -A -- "$@" && g commit -q -m "$m"
  }
  local gd="2026-09-01T21:14:00+04:00"
  cp -a "$REPO" "$d" 2>/dev/null || { warn "repo copy failed"; return; }
  rm -rf "$d/.git"; chown -R "$K:$K" "$d"
  g init -q -b main
  ci "2026-09-01T21:14:00+04:00" "fedokawaii: setup.sh, the package list, the menu" \
     setup.sh fedokawaii.sh fedokawaii.conf PACKAGES.md README.md lib check.sh
  ci "2026-09-03T22:40:00+04:00" "dwl: config.h, the patch and start-dwl" src/dwl system/start-dwl system/tuned.conf
  ci "2026-09-06T10:05:00+04:00" "theme.sh: configs, palettes, dark and light" theme.sh tools art configs
  ci "2026-09-09T19:31:00+04:00" "bin: the kawa-* menus and bar helpers" bin/kawa-{menu,quick,power,audio,volume,brightness,calendar,help,osd,cpu,cell,tag,dwlstatus,nowplaying,display,clip,lock,term} bin/fetch
  g checkout -q -b wallpaper
  ci "2026-09-11T20:12:00+04:00" "kawa-wallpaper: packs, pixel-art redraw, the picker" bin/kawa-wallpaper
  ci "2026-09-12T23:48:00+04:00" "kawa-veil: the seigaiha transition between themes" src/kawa-veil bin/kawa-theme
  g checkout -q main
  ci "2026-09-13T09:20:00+04:00" "kawa-weather: wttr.in in the bar" bin/kawa-weather
  gd="2026-09-14T11:02:00+04:00" g merge -q --no-ff -m "Merge branch 'wallpaper'" wallpaper
  ci "2026-09-18T18:44:00+04:00" "kawa-share, kawa-screenshot: screen sharing and grabs" bin/kawa-share bin/kawa-screenshot src/kawa-clipkeep
  ci "2026-09-22T21:07:00+04:00" "system: the greeter, snapshots around dnf" system/kawa-greeter system/kawa-snap
  ci "2026-10-02T20:30:00+04:00" "verify.sh: check every phase and the theme" verify.sh
  ci "2026-10-08T22:15:00+04:00" "docs: the handbook (markdown + PDF)" docs bin/brave-origin
  g checkout -q -b torrra
  ci "2026-10-10T19:55:00+04:00" "torrra: kawa-torrra and a Prowlarr container" system/kawa-torrra system/kawa-torrra.profile.sh system/prowlarr.container
  g checkout -q main
  # whatever the steps above did not name (helpers added since: books, notes, …), so the
  # work in progress below is all the Files panel shows
  ci "2026-10-11T07:40:00+04:00" "bin, system: books, notes, the clipboard and the rest" .
  gd="2026-10-11T08:00:00+04:00"
  g clone -q --bare "$d" "$KH/repos/.remote/fedokawaii.git" \
    && g remote add origin "$KH/repos/.remote/fedokawaii.git" && g fetch -q origin \
    && g branch -q -u origin/main
  printf '\n<!-- draft -->\n' >>"$d/docs/fedokawaii-guide.md"
  gd="2026-10-14T22:41:00+04:00" g commit -q -am "guide: draft of the apps chapter"   # ↑1
  sed -i '/^#    bash theme\.sh --check/a #    bash theme.sh --diff             the same, as a diff against the installed files' \
    "$d/theme.sh"; g add theme.sh                                                     # +1
  # setup.sh: a --dry-run option in the making (three hunks); verify.sh touched   ~2
  sed -i -e '/^#    sudo bash setup.sh --no-reboot/a #    sudo bash setup.sh --dry-run    what the current phase would install; nothing changes' \
         -e 's/^MODE=build NO_REBOOT=0 /MODE=build NO_REBOOT=0 DRY_RUN=0 /' \
         -e '/^    --no-reboot) NO_REBOOT=1 ;;$/a \    --dry-run) DRY_RUN=1 ;;' "$d/setup.sh"
  printf '\n' >>"$d/verify.sh"
  printf 'notes\n' >"$d/TODO.txt"                                                   # ?1
  chown -R "$K:$K" "$d" "$KH/repos"
}

status_title() {   # status_title TITLE APPID [FLOATING] — what dwl would print for the focused window
  printf '%s\n' "DP-1 title $1" "DP-1 appid $2" "DP-1 floating ${3:-0}" >&7
}

win_geom() {   # win_geom APPID → "x,y wxh" of the newest window with that app_id (or name)
  swaymsg -t get_tree | jq -r --arg a "$1" \
    '[recurse(.nodes[]?, .floating_nodes[]?) | select(.app_id == $a or (.app_id == null and .name == $a))] | last
     | .rect | "\(.x),\(.y) \(.width)x\(.height)"' 2>/dev/null | grep -v null
}
win_title() {
  swaymsg -t get_tree | jq -r --arg a "$1" '[recurse(.nodes[]?, .floating_nodes[]?) | select(.app_id == $a)] | last | .name // ""' 2>/dev/null
}

capture() {   # capture NAME APPID [SETTLE] [TIMEOUT] — the window (1:1) and the whole screen, one frame
  local name=$1 app=$2 geom pos size r kb
  geom=$(win_geom "$app") || { warn "$T: no $app window for $name"; return 1; }
  read -r pos size <<<"$geom"
  local sapp=$app; [[ $sapp == app-* ]] && sapp=footclient       # (what dwl would see)
  status_title "$(win_title "$app")" "$sapp" "${FLOAT:-0}"
  # a keyboard plugged in while the frame is taken: the window shows focus as it would
  kb=""
  [[ -z ${NOKBD:-} ]] && { k wtype -s 8000 >/dev/null 2>&1 & kb=$!; sleep 0.4; }
  if r=$(python3 -I "$SH/lib/appshot.py" window "$OT/app-$name-full.png" "$OT/app-$name.png" "$pos" "$size" \
           --settle "${3:-1.0}" --timeout "${4:-15}" 2>>"$LT/$name.log"); then
    say "$T: app-$name.png ($size at $pos)"
  else
    warn "$T: app-$name could not be captured"
  fi
  [[ -n $kb ]] && { kill "$kb" 2>/dev/null; wait "$kb" 2>/dev/null; }
}

term() {   # term NAME DIR CMD… — CMD in a foot window (footclient, the client's environment);
  local name=$1 dir=$2; shift 2   # its app-id app-NAME only tells the windows apart here
  TAPP=app-$name
  k env "${NETENV[@]}" footclient -E -a "$TAPP" -D "$dir" -- "$@" >>"$LT/$name.log" 2>&1 &
  TPID=$!
  waitfor 10 "the $name window" win_geom "$TAPP"
}

term_close() {   # term_close [KEYS…] — send the keys that quit the app, then make sure it is gone
  (($#)) && k wtype -s 300 "$@" >/dev/null 2>&1       # (a new virtual keyboard: wait for its keymap)
  waitpid 6 "$TPID" || { warn "$T: a terminal app had to be killed"; pkill -u "$K" -f -- "-a $TAPP " 2>/dev/null; }
  waitfor 5 "the window to close" bash -c "! swaymsg -t get_tree | grep -q '\"app_id\": \"$TAPP\"'" || true
}

shot_yazi() {   # yazi (Super+E: footclient yazi) in the demo folder, the notes previewed
  term yazi "$KH/Documents" yazi "$KH/Documents/notes.md" || return
  sleep 2.5
  capture yazi "$TAPP" 1.5
  term_close -k q                                  # q quits (no confirmation without tasks)
}

nvim_warm() {   # once per session: a first start (plugins load, Mason and nvim-treesitter look at
  # what they have), quit; every shot is a later start, as on a desktop in use
  [[ -n ${NVIM_WARM:-} ]] && return 0
  NVIM_WARM=1
  term nvim-warmup "$KH/repos/fedokawaii" nvim "$KH/repos/fedokawaii/bin/kawa-theme" || return
  sleep 12
  python3 -I "$SH/lib/appshot.py" window "$W/nvim-warmup-full.png" "$W/nvim-warmup.png" \
    $(win_geom "$TAPP") --settle 1 --timeout 5 >/dev/null 2>&1
  term_close -k Escape -s 100 ":qa" -k Return
}

nvim_open() {   # nvim_open NAME ARGS… — nvim in the demo repository, settled
  local name=$1; shift
  nvim_warm
  term "$name" "$KH/repos/fedokawaii" nvim "$@" || return
  sleep 6
}

nvim_keys() { k wtype -s 300 -d 60 "$@" >/dev/null 2>&1; }   # (a new virtual keyboard: wait for its keymap)

nvim_quit() {   # out of any popup, picker or explorer; nothing is written
  term_close -k Escape -s 150 -k Escape -s 150 -k Escape -s 150 ":qa!" -k Return
}

shot_nvim() {   # Neovim + LazyVim with the repo's gruvbox spec: a script of the repo, no explorer
  nvim_open nvim '+call cursor(44, 1)' '+normal! zt' bin/kawa-theme || return
  capture nvim "$TAPP" 2.0 25
  nvim_quit
}

shot_nvim_whichkey() {   # Space (the leader) pressed: which-key's menu of what follows
  nvim_open nvim-whichkey '+call cursor(44, 1)' '+normal! zt' bin/kawa-theme || return
  nvim_keys -k space
  sleep 2
  capture nvim-whichkey "$TAPP" 1.5 15
  nvim_quit
}

shot_nvim_picker() {   # Space Space: the file picker over the repository, "wall" typed
  nvim_open nvim-picker '+call cursor(44, 1)' '+normal! zt' bin/kawa-theme || return
  nvim_keys -k space -k space
  sleep 1.5
  nvim_keys "wall"
  sleep 2
  capture nvim-picker "$TAPP" 1.5 15
  nvim_quit
}

shot_nvim_grep() {   # Space /: live grep (ripgrep) for "gsettings", the matches and a preview
  nvim_open nvim-grep '+call cursor(44, 1)' '+normal! zt' bin/kawa-theme || return
  nvim_keys -k space "/"
  sleep 1.5
  nvim_keys "gsettings"
  sleep 2.5
  capture nvim-grep "$TAPP" 1.5 15
  nvim_quit
}

shot_nvim_split() {   # two scripts side by side (:vsplit), the explorer (Space e) on the left
  nvim_open nvim-split '+call cursor(44, 1)' '+normal! zt' bin/kawa-theme || return
  nvim_keys ":vsplit bin/kawa-wallpaper" -k Return
  sleep 1.5
  nvim_keys -k space "e"
  sleep 2.5
  capture nvim-split "$TAPP" 1.5 15
  nvim_quit
}

shot_nvim_lsp() {   # lua_ls (Mason) on an mpv script: its diagnostics ("Undefined global `mp`")
  # and the hover documentation of os.getenv (K)
  nvim_open nvim-lsp '+call cursor(8, 17)' configs/home/.config/mpv/scripts/kawa-ipc.lua || return
  sleep 8                                    # (lua_ls starts and reads the workspace)
  nvim_keys "K"
  sleep 2.5
  capture nvim-lsp "$TAPP" 1.5 15
  k pgrep -u "$K" -a lua-language >>"$LT/nvim-lsp.log" 2>&1
  nvim_quit
}

shot_lazygit() {   # lazygit in the demo repository (+1 staged, ~2 modified, ?1 untracked, ↑1)
  # its first start greets with "Thanks for using lazygit!" (Enter closes it, for good);
  # then the second file of the list, the modified setup.sh, with its diff
  lazygit_open lazygit || return
  k wtype -s 300 -k Down -s 150 -k Down >/dev/null 2>&1; sleep 1.5
  capture lazygit "$TAPP" 1.5
  term_close -k q
}

lazygit_open() {   # lazygit_open NAME — lazygit in the demo repository, its intro closed if it shows
  term "$1" "$KH/repos/fedokawaii" lazygit || return
  sleep 3
  # the one-time "Thanks for using lazygit!" (its state file says whether it was seen)
  if ! grep -qs 'startuppopupversion: [1-9]' "$KH/.local/state/lazygit/state.yml" "$KH/.config/lazygit/state.yml"; then
    k wtype -s 300 -k Return >/dev/null 2>&1; sleep 1
  fi
}

shot_lazygit_log() {   # 4: the Commits panel — the graph (a merged branch), a commit's diff beside it
  lazygit_open lazygit-log || return
  k wtype -s 300 "4" -s 400 $(printf -- '-k Down -s 120 %.0s' {1..8}) >/dev/null 2>&1   # "kawa-wallpaper: …",
  # on the merged branch, below the merge: its graph in view
  sleep 1.5
  capture lazygit-log "$TAPP" 1.5
  term_close -k q
}

shot_lazygit_commit() {   # c with theme.sh staged: the commit message box, a summary typed
  lazygit_open lazygit-commit || return
  k wtype -s 300 -k Down -s 150 -k Down -s 150 -k Down >/dev/null 2>&1; sleep 1   # theme.sh (staged)
  k wtype -s 300 "c" >/dev/null 2>&1; sleep 1
  k wtype -s 300 -d 40 "theme.sh: --diff in the usage" >/dev/null 2>&1; sleep 1
  capture lazygit-commit "$TAPP" 1.5
  term_close -k Escape -s 300 -k q                # (Esc closes the box, the message is not committed)
}

shot_lazygit_stage() {   # setup.sh: Enter opens its staging view, a selects a whole hunk, Space
  # stages it: the unstaged hunks on one side, the staged one on the other, the next selected
  lazygit_open lazygit-stage || return
  k wtype -s 300 -k Down -s 150 -k Down >/dev/null 2>&1; sleep 1        # setup.sh (/ · ?? TODO · M setup · M theme · M verify)
  k wtype -s 300 -k Return -s 600 "a" -s 300 -k space >/dev/null 2>&1   # a: select the hunk
  sleep 1.5
  capture lazygit-stage "$TAPP" 1.5
  term_close -k Escape -s 300 -k q
}

shot_yazi_drives() {   # M in yazi: the drives (kawa-drives list; stubs/lsblk: a stick open, a disk closed)
  term yazi-drives "$KH" yazi || return
  sleep 2.5
  k wtype -s 300 M >/dev/null 2>&1; sleep 1.5
  capture yazi-drives "$TAPP" 1.0
  term_close -k Escape -s 300 q
}

shot_yazi_preview() {   # yazi in ~/Pictures, a picture hovered: its preview (sixel, foot)
  local u=(setpriv --reuid="$KUID" --regid="$KGID" --init-groups -- env -i HOME="$KH" PATH=/usr/bin:/bin)
  "${u[@]}" mkdir -p "$KH/Pictures/Wallpapers"
  [[ -s $SH/media/fuji-dawn.png ]] && "${u[@]}" cp "$SH/media/fuji-dawn.png" "$KH/Pictures/"
  "${u[@]}" cp "$KH/.local/share/fedokawaii/dark/scene.png" "$KH/Pictures/scene-night.png"
  "${u[@]}" cp "$KH/.local/share/fedokawaii/light/scene.png" "$KH/Pictures/scene-day.png"
  "${u[@]}" cp "$KH/.cache/kawa-wallpaper/default-dark-1920x1080.png" "$KH/Pictures/Wallpapers/fedokawaii-dark.png"
  "${u[@]}" cp "$KH/.cache/kawa-wallpaper/default-light-1920x1080.png" "$KH/Pictures/Wallpapers/fedokawaii-light.png"
  term yazi-preview "$KH/Pictures" yazi "$KH/Pictures/fuji-dawn.png" || return
  sleep 3.5
  capture yazi-preview "$TAPP" 1.5
  term_close -k q
}

btop_start() {   # btop on a workspace of its own from the start, so its graphs have minutes of history
  # when it is shot last. /proc is remounted hidepid=invisible: the user's btop lists the
  # session's processes, not this harness's (root's) shell loops and screen grabs
  mount -o remount,hidepid=invisible /proc || warn "$T: hidepid remount failed"
  swaymsg -q workspace 2
  term btop "$KH" btop || { swaymsg -q workspace 1; return; }
  BTOP_PID=$TPID BTOP_APP=$TAPP
  # the same btop with the theme where btop can find it (see the report: btop only looks in
  # its theme folders, so color_theme = a full path elsewhere falls back to the Default theme)
  install -d -o "$K" -g "$K" "$KH/.config-btopfix" "$KH/.config-btopfix/btop" "$KH/.config-btopfix/btop/themes"
  sed 's|^color_theme = .*|color_theme = "fedokawaii"|' "$KH/.config/btop/btop.conf" >"$KH/.config-btopfix/btop/btop.conf"
  ln -sfn "$KH/.config/fedokawaii/current/btop.theme" "$KH/.config-btopfix/btop/themes/fedokawaii.theme"
  chown -hR "$K:$K" "$KH/.config-btopfix"
  swaymsg -q workspace 3
  k env XDG_CONFIG_HOME="$KH/.config-btopfix" footclient -E -a app-btopfix -D "$KH" -- btop >>"$LT/btop.log" 2>&1 &
  BTOPFIX_PID=$!
  waitfor 10 "the second btop window" win_geom app-btopfix
  swaymsg -q workspace 1
  sleep 1
}

shot_btop() {
  local left=$((120 - (SECONDS - BTOP_T0)))
  ((left > 0)) && { say "$T: ${left}s more for btop's graphs"; sleep "$left"; }
  swaymsg -q workspace 2; sleep 2.5
  NOKBD=1 capture btop "$BTOP_APP" 0.8 15
  k wtype -s 300 -k q >/dev/null 2>&1; waitpid 6 "$BTOP_PID" || warn "$T: btop had to be killed"
  swaymsg -q workspace 3; sleep 2.5
  NOKBD=1 capture btop-themefix app-btopfix 0.8 15
  k wtype -s 300 -k q >/dev/null 2>&1; waitpid 6 "$BTOPFIX_PID" || warn "$T: btop had to be killed"
  swaymsg -q workspace 1
  mount -o remount,hidepid=off /proc
}

shot_mpv() {   # mpv 0.41 with the user's mpv.conf (theme colours included), the controller shown
  local sock pid
  # (--gpu-sw: this machine has no GPU, only Mesa's llvmpipe, which mpv's gpu-next refuses
  #  unless told; on the real desktop gpu-next runs on the GPU — the same renderer either way)
  k "$SH/mpv/bin/mpv" --gpu-sw "$KH/Videos/fuji-dawn.mkv" >"$LT/mpv.log" 2>&1 &
  pid=$!
  waitfor 15 "the mpv window" win_geom mpv || { kill "$pid" 2>/dev/null; return; }
  # the controller as when the pointer rests on the window (scripts/kawa-ipc.lua's socket)
  waitfor 10 "mpv's socket" compgen -G "$X/mpv-*.sock"
  sock=$(compgen -G "$X/mpv-*.sock" | head -1)
  mpv_ipc "$sock" '["script-message", "osc-visibility", "always", "no-osd"]'
  sleep 2.5                                       # (the picture keeps panning: the whole screen differs)
  mpv_ipc "$sock" '["set_property", "pause", true]'
  mpv_ipc "$sock" '["seek", 4, "absolute+exact"]'
  sleep 1.5
  capture mpv mpv 1.0 10
  mpv_ipc "$sock" '["quit"]'
  waitpid 6 "$pid" || warn "$T: mpv had to be killed"
}

mpv_ipc() {   # mpv_ipc SOCKET JSON-COMMAND
  k python3 -I -c 'import json, socket, sys
c = socket.socket(socket.AF_UNIX); c.settimeout(2); c.connect(sys.argv[1])
c.sendall((json.dumps({"command": json.loads(sys.argv[2])}) + "\n").encode())
try:
    print(c.recv(4096).decode().strip())
except socket.timeout:
    pass' "$1" "$2" >>"$LT/mpv.log" 2>&1
}

shot_zathura() {
  local pid
  k zathura -P 67 "$KH/Documents/fedokawaii-guide.pdf" >"$LT/zathura.log" 2>&1 &   # page 67: chapter 11 opens (the terminal lesson)
  pid=$!
  waitfor 15 "the zathura window" win_geom org.pwmt.zathura || { kill "$pid" 2>/dev/null; return; }
  sleep 2.5
  capture zathura org.pwmt.zathura 1.0
  pkill -u "$K" -x zathura 2>/dev/null; waitpid 5 "$pid" || warn "$T: zathura had to be killed"
}

shot_filechooser() {   # the file dialog: yazi through kawa-pick, started as the portal starts it
  local pid out=$KH/.cache/kawa-pick.out           # ("open file": one file, from ~/Documents)
  k kawa-pick 0 0 0 "$KH/Documents" "$out" >"$LT/filechooser.log" 2>&1 &
  pid=$!
  waitfor 10 "the file dialog" win_geom float || { kill "$pid" 2>/dev/null; return; }
  sleep 2.5
  k wtype -s 300 -k Down >/dev/null 2>&1; sleep 1.5   # (a file under the cursor: its preview)
  FLOAT=1 capture filechooser float 1.0
  k wtype -s 300 q >/dev/null 2>&1                   # q: cancelled
  waitpid 6 "$pid" || { warn "$T: the file dialog had to be killed"; pkill -u "$K" -f kawa-pick 2>/dev/null; }
  waitfor 5 "the file dialog to close" bash -c '! swaymsg -t get_tree | grep -q "\"app_id\": \"float\""' || true
}

shot_books() {   # Super+R: the library — the ones being read first, the cover of the second
  local u=(setpriv --reuid="$KUID" --regid="$KGID" --init-groups -- env -i HOME="$KH" PATH=/usr/bin:/bin) pid
  "${u[@]}" mkdir -p "$KH/Books" "$KH/.local/share/zathura"
  "${u[@]}" cp -r "$SH/books/." "$KH/Books/"; "${u[@]}" rm -f "$KH/Books/notes.md"
  "${u[@]}" python3 -I - "$KH" <<'PY'
import os, sqlite3, sys
h = sys.argv[1]
db = sqlite3.connect(os.path.join(h, ".local/share/zathura/bookmarks.sqlite"))
db.execute("CREATE TABLE IF NOT EXISTS fileinfo (file TEXT PRIMARY KEY, page INTEGER, offset INTEGER, zoom FLOAT, rotation INTEGER, pages_per_row INTEGER, first_page_column TEXT, position_x FLOAT, position_y FLOAT, time TIMESTAMP, page_right_to_left INTEGER, hash BLOB, adjust_mode INTEGER)")
for f, p, ago in (("Japanese/Snow Country.epub", 36, "-1 hours"), ("The Book of Tea.pdf", 86, "-6 hours"),
                  ("The Art of Unix Programming.pdf", 141, "-2 days"), ("Japanese/Kokoro.pdf", 23, "-5 days"),
                  ("Hokusai Manga vol 1.cbz", 5, "-3 weeks")):
    db.execute("REPLACE INTO fileinfo (file, page, time) VALUES (?, ?, DATETIME('now', ?))", (os.path.join(h, "Books", f), p, ago))
db.commit()
PY
  k kawa-books >"$LT/books.log" 2>&1 &
  pid=$!
  waitfor 10 "the books window" win_geom float || return
  sleep 3                                            # the list, the first cover
  k wtype -s 300 -k Down >/dev/null 2>&1; sleep 2.5
  FLOAT=1 capture books float 1.0
  # Ctrl+A: the books elsewhere in the home, two marked with Tab
  "${u[@]}" mkdir -p "$KH/Downloads/papers"
  "${u[@]}" cp "$KH/Books/Japanese/Rashomon.pdf" "$KH/Downloads/In Praise of Shadows.pdf"
  "${u[@]}" cp "$KH/Books/Japanese/Botchan.epub" "$KH/Downloads/papers/The Pillow Book.epub"
  "${u[@]}" cp "$KH/Books/The Book of Tea.pdf" "$KH/Documents/Hojoki.pdf"
  k wtype -s 300 -M ctrl -k a -m ctrl >/dev/null 2>&1; sleep 2
  k wtype -s 300 -k Tab -k Tab >/dev/null 2>&1; sleep 1
  FLOAT=1 capture books-add float 1.0
  k wtype -s 300 -k Escape >/dev/null 2>&1; sleep 1.5      # (back to the list)
  k wtype -s 300 -k Escape >/dev/null 2>&1
  waitpid 5 "$pid" || true
}

shot_notes() {   # Super+N: a few days of notes, open at the end, a line being typed; Super+N again
  local u=(setpriv --reuid="$KUID" --regid="$KGID" --init-groups -- env -i HOME="$KH" PATH=/usr/bin:/bin) pid
  "${u[@]}" mkdir -p "$KH/Notes"; "${u[@]}" cp "$SH/books/notes.md" "$KH/Notes/notes.md"
  declare -F nvim_warm >/dev/null && nvim_warm
  k kawa-notes >"$LT/notes.log" 2>&1 &
  pid=$!
  waitfor 10 "the notes window" win_geom float || return
  sleep 3
  k wtype -s 300 -- "- ask about the snapper cleanup numbers" >/dev/null 2>&1; sleep 1.2
  FLOAT=1 capture notes float 1.0
  k kawa-notes >>"$LT/notes.log" 2>&1                # Super+N again: saved, put away
  waitfor 6 "the notes window to close" bash -c '! swaymsg -t get_tree | grep -q "\"app_id\": \"float\""' \
    || warn "$T: the notes window did not close"
  "${u[@]}" tail -n 5 "$KH/Notes/notes.md" >"$LT/notes-tail.txt"
  waitpid 5 "$pid" || true
}

shot_system() {   # Super+U: the system's control (fedokawaii), from records as setup and an update leave them
  local st=$SH/system-state sb=$SH/system-bin pid d
  rm -rf "$st" "$sb"; mkdir -p "$st" "$sb"
  d=$(date -d '2026-09-02 19:40' +%s)
  printf '%s ok\n' "$d" >"$st/last-update"                  # an update six weeks ago, complete
  printf '%s 179 0 0\n' "$((d + 600))" >"$st/last-verify"     # (verify ran at its end: a finished install's count)
  printf '14\n' >"$st/snapshots"
  : >"$st/lock"
  chmod -R a+rX "$st"
  mkdir -p /var/lib/fedokawaii && mount --bind "$st" /var/lib/fedokawaii || { warn "$T: no stand-in records"; return; }
  # what a Fedora 44 machine answers (only for this window: the stand-ins are on its PATH alone)
  cat >"$sb/uname" <<'EOF'
#!/bin/sh
[ "$1" = -r ] && { echo 6.19.6-200.fc44.x86_64; exit 0; }
exec /usr/bin/uname "$@"
EOF
  cat >"$sb/rpm" <<'EOF'
#!/bin/sh
echo "kernel-core-6.19.6-200.fc44.x86_64            Thu 03 Sep 2026 10:12:41 AM +04"
echo "kernel-core-6.18.12-200.fc44.x86_64           Wed 05 Aug 2026 09:31:07 AM +04"
EOF
  cat >"$sb/df" <<'EOF'
#!/bin/sh
printf '         1B-blocks          Avail\n'
printf '%18s %14s\n' 999658172416 640131457024
EOF
  cat >"$sb/menu" <<EOF
#!/bin/sh
export PATH="$sb:\$PATH"
exec bash "$SH/fedokawaii"
EOF
  install -m 755 "$REPO/system/fedokawaii" "$SH/fedokawaii"
  chmod 755 "$sb"/*; chmod -R a+rX "$sb"
  k kawa-float --once system system 88x17 -- "$sb/menu" >"$LT/system.log" 2>&1 &   # (as fedokawaii --window)
  pid=$!
  waitfor 10 "the system window" win_geom float || { umount /var/lib/fedokawaii; return; }
  sleep 3
  FLOAT=1 capture system float 1.0
  k wtype -s 300 -k Down -k Down >/dev/null 2>&1; sleep 2
  FLOAT=1 capture system-upgrade float 1.0
  k wtype -s 300 -k Escape >/dev/null 2>&1
  waitpid 5 "$pid" || warn "$T: the system window had to be closed"
  umount /var/lib/fedokawaii 2>/dev/null
}

shot_share() {   # the screen-share picker: kawa-share fed what xdg-desktop-portal-wlr 0.8.4 sends
  local lines=$'Monitor: DP-1 Dell U2723QE\nMonitor: HDMI-A-1 LG HDR 4K\nWindow: Brave — Meet (0x1a)\nWindow: foot — ~/repos (0x2b)\n'
  printf '%s' "$lines" >"$W/share-input"; chown "$K:$K" "$W/share-input"
  menu app-share k env PATH="$SH/share-bin:$SH/stubs:$F44/bin:$KH/.local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/bin" \
    sh -c 'bash ${APPS_SHARE_TRACE:+-x} "$(command -v kawa-share)" <"$1"' sh "$W/share-input"
  [[ -f $LT/app-share.log ]] && mv -f "$LT/app-share.log" "$LT/share.log"
}

shot_torrra() {   # torrra 2.5.1 through kawa-torrra, a stand-in Prowlarr, "ubuntu 24.04" searched
  local fp
  python3 -I "$SH/lib/fakeprowlarr.py" "$KEY" 9696 >"$LT/fakeprowlarr.log" 2>&1 &
  fp=$!
  waitfor 10 "the stand-in Prowlarr" python3 -I -c 'import socket; socket.create_connection(("127.0.0.1", 9696), 1)'
  # Prowlarr runs on demand: kawa-torrra asks systemd --user whether it is up and starts it
  # if not. There is no user manager here, and the stand-in is up already: a systemctl that
  # says so (for that one question; everything else goes to the real one)
  install -d -m 755 "$SH/torrra-bin"
  cat >"$SH/torrra-bin/systemctl" <<'EOF'
#!/bin/sh
case "$*" in *is-active*prowlarr*) exit 0 ;; esac
exec /usr/bin/systemctl "$@"
EOF
  chmod 755 "$SH/torrra-bin/systemctl"
  # as the launcher entry starts it (kawa-term kawa-torrra --open): the search screen
  TAPP=app-torrra
  k env PATH="$SH/torrra-bin:$SH/stubs:$F44/bin:$KH/.local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/bin" \
    KAWA_TORRRA_VENV="$SH/torrra-venv" footclient -E -a "$TAPP" -D "$KH" -- "$SH/bin/kawa-torrra" --open >>"$LT/torrra.log" 2>&1 &
  TPID=$!
  waitfor 10 "the torrra window" win_geom "$TAPP" || { kill "$fp"; return; }
  sleep 4
  python3 -I "$SH/lib/appshot.py" window "$OT/app-torrra-search-full.png" "$OT/app-torrra-search.png" \
    $(win_geom "$TAPP") --settle 1 --timeout 8 >/dev/null 2>>"$LT/torrra.log"
  k wtype -s 300 -d 40 "ubuntu 24.04" -k Return >/dev/null 2>&1
  sleep 4
  capture torrra "$TAPP" 1.5 15
  term_close -k Escape -k Escape -M ctrl -k q -m ctrl
  kill "$fp" 2>/dev/null; wait "$fp" 2>/dev/null
}

shot_brave() {   # Brave Origin on its new-tab page: GTK mode (theme.sh's Preferences), Fedokawaii
  # --no-first-run: no one-time welcome tab (brave://welcome, "Set Brave as default browser"),
  # which would otherwise come back on every start until answered; --no-default-browser-check:
  # no "Brave isn't your default browser" bar (on the desktop it is the default, mimeapps.list)
  local pid app try flags=(--password-store=basic --no-default-browser-check --no-first-run)
  [[ -x $SH/brave/brave ]] || { warn "$T: no Brave Origin"; return; }
  # Brave Origin's own first-start question ("Support Brave by purchasing Origin" / "Proceed
  # with Origin for free on Linux") answered as a user answers it once: Proceed, which is
  # brave.origin.free_tier_accepted in Local State. Done before the start, as this seat has
  # no pointer to click it with.
  local ls="$KH/.config/BraveSoftware/Brave-Origin/Local State"
  jq '.brave.origin.free_tier_accepted = true' "$ls" >"$W/local-state" && cat "$W/local-state" >"$ls"
  [[ -n ${APPS_BRAVE_NOSANDBOX:-} ]] && flags+=(--no-sandbox)
  # two starts, as on a desktop in use: the first one sets the new profile up (and is the
  # one that sometimes crashes here: a segfault in the browser process before or just after
  # its window appears — this sandbox has no GPU), the shot is of the second
  local starts=0
  for try in 1 2 3 4 5; do
    k "$SH/brave/brave-origin" "${flags[@]}" >>"$LT/brave.log" 2>&1 &
    pid=$!
    if waitfor 30 "the Brave window" bash -c 'swaymsg -t get_tree | grep -q "\"app_id\": \"brave"' && sleep 6 \
       && swaymsg -t get_tree | grep -q '"app_id": "brave'; then
      starts=$((starts + 1))
      ((starts == 2)) && break
      pkill -TERM -u "$K" -f "$SH/brave/brave" 2>/dev/null       # closed as a window closes
    else
      warn "$T: Brave start $try did not last"
      pkill -u "$K" -f "$SH/brave/brave" 2>/dev/null
    fi
    waitpid 15 "$pid"; pid=""
    waitfor 10 "Brave to be gone" bash -c "! pgrep -u $K -f '$SH/brave/brave'"
  done
  [[ -n $pid ]] || { warn "$T: Brave did not start twice"; return; }
  app=$(swaymsg -t get_tree | jq -r '[recurse(.nodes[]?, .floating_nodes[]?) | select((.app_id // "") | startswith("brave"))] | last | .app_id')
  sleep 3
  capture brave "$app" 1.5 20
  jq -c '{flags: .browser.enabled_labs_experiments, origin: .brave.origin}' "$ls" >>"$LT/brave.log" 2>&1
  pkill -u "$K" -f "$SH/brave/brave" 2>/dev/null
  waitpid 10 "$pid" || warn "$T: Brave had to be killed"
}

shot_wiremix() {   # Super+A → mixer: wiremix (Fedora's 0.11.0) in its floating window, as kawa-audio
                   # opens it, the test film's sound playing (mpv, no picture) on its Playback tab
  local p pid pp
  # (this mpv speaks PulseAudio, not PipeWire's own protocol as Fedora's does: PipeWire's
  # PulseAudio server for the length of the shot)
  k pipewire-pulse >"$LT/wiremix-pulse.log" 2>&1 &
  pp=$!
  waitfor 5 "PipeWire's PulseAudio server" test -S "$X/pulse/native" || { kill "$pp" 2>/dev/null; return; }
  k "$SH/mpv/bin/mpv" --no-video --ao=pulse --loop-file=inf --volume=80 "$KH/Videos/fuji-dawn.mkv" >"$LT/wiremix-mpv.log" 2>&1 &
  p=$!
  sleep 2
  k kawa-float --once mixer mixer 96x29 -- wiremix >"$LT/wiremix.log" 2>&1 &
  pid=$!
  waitfor 10 "the mixer window" win_geom float || { kill "$p" "$pp" 2>/dev/null; return; }
  sleep 3                                         # (the meters settle on the sound)
  FLOAT=1 capture wiremix float 1.0
  k wtype -s 300 -k Escape >/dev/null 2>&1
  waitpid 5 "$pid" || warn "$T: the mixer window had to be closed"
  kill "$p" 2>/dev/null; wait "$p" 2>/dev/null
  kill "$pp" 2>/dev/null; wait "$pp" 2>/dev/null
}

shot_bluetui() {   # quick settings → pair a device: bluetui (v0.8.2) in its floating window, as
                   # kawa-quick opens it, against a stand-in BlueZ on a private bus (lib/fakebluez.py:
                   # a paired controller and headphones; s scans, and a phone nearby shows)
  local d=$W/bt bus db fb pid
  install -d -m 700 -o "$K" -g "$K" "$d"; bus=$d/bus
  k dbus-daemon --session --nofork --address="unix:path=$bus" >"$LT/bluez-bus.log" 2>&1 &
  db=$!
  waitfor 5 "the stand-in bus" test -S "$bus" || { kill "$db" 2>/dev/null; return; }
  k /opt/kit-tools/venv/bin/python -I "$SH/lib/fakebluez.py" "unix:path=$bus" adapter >"$LT/fakebluez.log" 2>&1 &
  fb=$!
  sleep 1.5
  k kawa-float --once pair pair 96x29 -- env DBUS_SYSTEM_BUS_ADDRESS="unix:path=$bus" bluetui >"$LT/bluetui.log" 2>&1 &
  pid=$!
  waitfor 10 "the pairing window" win_geom float || { kill "$fb" "$db" 2>/dev/null; return; }
  sleep 2
  k wtype -s 300 -k s >/dev/null 2>&1; sleep 3   # s: a scan, the phone found
  FLOAT=1 capture bluetui float 1.0
  k wtype -s 300 -k Escape >/dev/null 2>&1
  waitpid 5 "$pid" || warn "$T: the pairing window had to be closed"
  kill "$fb" "$db" 2>/dev/null; wait "$fb" "$db" 2>/dev/null
}

shot_visidata() {   # VisiData (3.3) on the handbook's weather.csv (§16.7): the temp column a number,
                    # sorted, its sum under the table — the Try this, key by key
  local f=$KH/practice/weather.csv
  install -d -m 755 -o "$K" -g "$K" "$KH/practice"
  printf 'city,temp,day\nSharjah,41,Mon\nDubai,40,Tue\nAjman,38,Wed\n' >"$f"; chown "$K:$K" "$f"
  term visidata "$KH/practice" vd weather.csv || return
  sleep 2
  k wtype -s 300 -k l >/dev/null 2>&1; sleep 0.6
  k wtype -s 300 '#' >/dev/null 2>&1; sleep 0.6
  k wtype -s 300 '[' >/dev/null 2>&1; sleep 0.6
  k wtype -s 300 '+' >/dev/null 2>&1; sleep 1
  k wtype -s 300 sum -k Return >/dev/null 2>&1; sleep 1.5
  NOKBD=1 capture visidata "$TAPP" 0.8 15
  term_close -k q -k q
}

inner_apps() {
  local i
  T=$1 OT=$OUT/$1 LT=$LOG/$1/apps W=$SH/work-apps-$1
  mkdir -p "$OT" "$LT"; rm -rf "$W"; mkdir -p "$W"
  # a full run starts clean; a partial one (APPS_ONLY) replaces only what it shoots
  [[ $ONLY == "$ALL_GROUPS" ]] && rm -f "$OT"/app-*.png "$LT"/*.log
  mount_home "$T"
  mount --bind "$SH/dconf-local" /etc/dconf/db/local || warn "$T: dconf defaults bind failed"
  mount --bind "$MPV_APPDIR" "$SH/mpv" || warn "$T: mpv AppDir bind failed"
  mount --bind "$TORRRA_VENV" "$SH/torrra-venv" || warn "$T: torrra venv bind failed"
  [[ -d $BRAVE_DIR ]] && { mount --bind "$BRAVE_DIR" "$SH/brave" || warn "$T: Brave bind failed"; }
  home_setup
  local ot=$OT; OT=$W                    # (session() saves its wallpaper grab into $OT)
  session
  OT=$ot
  # the apps keep their state where they do on the desktop (~/.local/state, in the overlay):
  # shoot.sh points XDG_STATE_HOME at its staging folder, shared by both themes
  for i in "${!KENV[@]}"; do [[ ${KENV[i]} == XDG_STATE_HOME=* ]] && KENV[i]=XDG_STATE_HOME=$KH/.local/state; done
  sleep 1; img grab "$W/desk.ppm"
  read -r _ _ _ BARH <<<"$(img bbox "$W/wallpaper.ppm" "$W/desk.ppm")"
  [[ $BARH =~ ^[0-9]+$ && $BARH -lt 200 ]] || BARH=27
  { echo "versions:"; cat "$SH/opt/versions"; btop --version; zathura --version 2>&1 | head -1
    "$SH/mpv/bin/mpv" --version 2>&1 | head -1; "$SH/torrra-venv/bin/python" -m pip --version 2>/dev/null | head -0
    "$SH/torrra-venv/bin/python" -I -c 'import importlib.metadata as m; print("torrra", m.version("torrra"), "textual", m.version("textual"))'
    [[ -x $SH/brave/brave ]] && "$SH/brave/brave" --version 2>/dev/null; } >"$LT/versions.txt" 2>&1
  # (debugging: APPS_HOLD=1 keeps the session up until $SH/release exists; enter it with
  #  nsenter -t <this PID 1's pid> -m -p, then run as the user with the session's environment)
  if [[ -n ${APPS_HOLD:-} ]]; then
    printf '%s\n' "${KENV[@]}" >"$SH/hold-env"; rm -f "$SH/release"; say "$T: holding (touch $SH/release)"
    for ((i = 0; i < 1800; i++)); do [[ -e $SH/release ]] && break; sleep 1; done
  fi
  want btop        && { btop_start; BTOP_T0=$SECONDS; }
  want yazi        && shot_yazi
  want nvim        && shot_nvim
  want nvim-whichkey && shot_nvim_whichkey
  want nvim-picker  && shot_nvim_picker
  want nvim-grep    && shot_nvim_grep
  want nvim-split   && shot_nvim_split
  want nvim-lsp     && shot_nvim_lsp
  want yazi-preview && shot_yazi_preview
  want yazi-drives && shot_yazi_drives
  want lazygit     && shot_lazygit
  want lazygit-log  && shot_lazygit_log
  want lazygit-commit && shot_lazygit_commit
  want lazygit-stage  && shot_lazygit_stage            # (last: it stages part of setup.sh)
  want mpv         && shot_mpv
  want zathura     && shot_zathura
  want share       && shot_share
  want filechooser && shot_filechooser
  want books       && shot_books
  want notes       && shot_notes
  want system      && shot_system
  want torrra      && shot_torrra
  want wiremix     && shot_wiremix
  want bluetui     && shot_bluetui
  want visidata    && shot_visidata
  want brave       && shot_brave
  want btop        && shot_btop
  exec 7>&-
  pkill -TERM -u "$K" 2>/dev/null; sleep 1
  say "$T: done"
}

case ${1:-} in
  --inner-apps) shift; inner_apps "$@" ;;
  --prep-nvim)  prep_nvim ;;
  --stage)      mkdir -p "$OUT" "$LOG" "$C"; fetch_tools && stage && make_media && build_filechooser ;;   # (debugging)
  *)            outer_apps "$@" ;;
esac
