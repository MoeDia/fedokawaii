#!/usr/bin/env bash
# lib/upstream.sh — tools Fedora does not package, from their official GitHub releases.
# One table drives install (setup.sh), repair, update and the checks (verify.sh).
#
# Every one is PINNED: an exact release, and the SHA-256 of its file (measured 2026-10-15
# from the release itself). The desktop's configs are written for exactly these versions —
# yazi's theme and layout code, the fonts' pixel metrics every alignment is measured with —
# so an update never moves them: what was installed is what stays, file for file, and a
# download that differs by a single byte is refused. Downloads come straight from the
# release page (no GitHub API, so no rate limit to run into). The one exception is
# GE-Proton, which follows its newest release: games are what it is for, and it changes
# nothing else (the newest two are kept, so a game pinned to the older one still starts).

# shellcheck disable=SC2034  # UPSTREAM is iterated by setup.sh and verify.sh
#          name             repo                     tag        file in the release                                   sha-256                                                            binaries → ~/.local/bin
UPSTREAM=(
  "satty|gabm/Satty|v0.22.0|satty-x86_64-unknown-linux-gnu.tar.gz|eb7a028c4a5ce331c2f355add8e2b807a7d697fe4495f7e1965786a4f6bcd5b8|satty"
  "yazi|sxyazi/yazi|v26.9.1|yazi-x86_64-unknown-linux-musl.zip|9b9c39decccf8cb0ff53a7d637d38f8a79d93bbd0099f4ea9c619ef6bb392f5d|yazi ya"
  # (Bluetooth pairing in a terminal; its release file is the binary itself, static — measured 2026-10-16)
  "bluetui|pythops/bluetui|v0.8.2|bluetui-x86_64-linux-musl|b476ee473cb4f7a48cd75d440e991bedc835ff5ac704aac1f1992f8e826222fd|bluetui"
  "lazygit|jesseduffield/lazygit|v0.66.1|lazygit_0.66.1_linux_x86_64.tar.gz|7b3f30c2c06a42cf575280f907e58d7ea08411408b6b62bc926bc91cbc6c3f46|lazygit"
  # (Claude Code sessions side by side, each marked working, blocked or idle: "Agents" in the
  # launcher. Its release file is the binary itself, static — measured 2026-10-19, and the
  # same as the release's own distribution/latest.json)
  "herdr|herdrdev/herdr|v0.9.5|herdr-linux-x86_64|14d9e8bc8b4a9e0118d77c32266f76d461f09b40342eb23752960bd89f59929d|herdr"
)
# the release binaries an earlier version installed and this one no longer has: presenterm
# (slides are LibreOffice Impress's now) and spotify_player (Spotify's own app, built by lpf:
# setup.sh) — taken out of ~/.local/bin, with their records, by update and repair
UPSTREAM_RETIRED=(presenterm spotify_player)
# the apps' monospace font (code, and the Nerd Font symbols programs draw) — Nerd Fonts v3.5.1
NERD_FONTS_TAG=v3.5.1
NERD_FONTS=(
  "JetBrainsMono|04d5e8f903693f9dd13e16f867e994834e681eb3c72c0d337a770dcda09010cf"
)
# Fusion Pixel (SIL OFL): pixel fonts with Latin and Japanese (kana + kanji) in one face —
# the desktop's one type, in two cuts of the same design: the 12 px one for the bar, menus
# and notifications at 1× (12 px), the lock and login screens and the boot menu at 2× and
# 3×; the 10 px one for the terminal at 2× (20 px: a 10 × 24 px cell, the size the terminal
# had before the pixel font, and every pixel still a sharp 2 × 2 square). The monospaced
# cuts, their Japanese glyph forms ("ja"); the terminal draws the 10 px one as Sumi Term, made
# from it here (sumi_term). Installed for every account
# (/usr/local/share/fonts): the login screen runs as its own system user.
FUSION_DIR=/usr/local/share/fonts/fusion-pixel
FUSION_TAG=2026.08.11
# SIZE|SHA-256 of fusion-pixel-font-SIZEpx-monospaced-ttf-vTAG.zip
FUSION_FACES=(
  "12|efbfb4c4cbcd156c8ec2739ff9eaf275490bf5c65279314f28b7a122c2d0d295"
  "10|71676f3c375676dbb363b24a60e8184314d9a2092b8e9a7d660c05ce34575bf3"
)
# (its files were GE-ProtonN-M.tar.gz; since GE-Proton 11 there is one per architecture:
# GE-ProtonN-M-x86_64.tar.gz beside -aarch64 — either form is taken, never the aarch64 one)
GE_PROTON_REPO="GloriousEggroll/proton-ge-custom"; GE_PROTON_ASSET='^GE-Proton[0-9]+-[0-9]+(-x86_64)?\.tar\.gz$'
# torrra (from PyPI, with uv tool) is held at this version: kawa-torrra hands it the Prowlarr
# key by replacing three methods of its settings class, so a newer torrra is taken only
# after that has been checked against it.
TORRRA_VERSION=2.5.1
# Syncplay (watching together: kawa-together starts it) runs from its own source, held at the
# v1.7.6 tag's commit as the file dialog's is: Fedora's package would bring PySide6 and 27 Qt
# modules for a window the terminal way never opens. It is pure Python, so its syncplay/
# folder runs on Fedora's python3 and the libraries the manifest lists (Twisted with TLS,
# pyOpenSSL, certifi, pem) — Syncplay's own Makefile installs it the same way: the folder,
# and a starter that finds it. A newer Python (Fedora 45: 3.15) needs no new copy.
SYNCPLAY_REPO=https://github.com/Syncplay/syncplay.git
SYNCPLAY_TAG=v1.7.6
SYNCPLAY_COMMIT=993232ab095bb810593459bc705b3e6fc64ad161
SYNCPLAY_PYTHON=/usr/bin/python3
# Two fixes of ours to its mpv connection (a start refused now and then; a close that kept it
# open two minutes), applied to the clone before the copy is checked — its header says more
SYNCPLAY_PATCH=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/src/syncplay/syncplay.patch
# ble.sh, the Bash Line Editor (the shell's colours as you type, its suggestions and its
# completion menu: ~/.bashrc.d/fedokawaii.sh loads it), is built from its source at this
# commit (0.4.0-devel4+d81fd54, 2026-09-08). Not a release file: its tagged releases
# (v0.3.4, v0.4.0-devel3, both 2023) know nothing of bash 5.3, which Fedora ships since 43,
# and its nightly file is replaced in place, so no checksum of it could stay pinned. A
# commit fetched by its hash is the pin: git checks every file against it, and the contrib/
# part (a submodule) comes at the commit this one names. Its own build (make install: bash
# and gawk, no compiler) puts it in ~/.local/share/blesh, yours.
# LocalSend — files between this computer and a phone or another computer on the same
# network (Wi-Fi or cable): no account, no cloud. Its Linux release is a folder (the app, its
# libraries, its data), kept whole in ~/.local/share/localsend; ~/.local/bin/localsend points
# into it. Its ports (tcp: the files · udp: devices finding each other) are open in the
# firewall (setup.sh, open_ports)
LOCALSEND_TAG=v1.18.0
LOCALSEND_ASSET=LocalSend-1.18.0-linux-x86-64.tar.gz
LOCALSEND_SHA256=5054f970dda73787a95fcd706dac62cdfb810ff4bde8c5a20f1332ee5d908afb
LOCALSEND_PORT=53317
BLESH_REPO=https://github.com/akinomyoga/ble.sh.git
BLESH_COMMIT=d81fd54feb0d996fdff20dca27eaf0201f7015cc

up_state_dir() { echo "$TARGET_HOME/.local/share/fedokawaii/upstream"; }
up_tag()       { as_user cat -- "$(up_state_dir)/$1" 2>/dev/null | head -c 200 || true; }   # (yours: read as you)
font_dir()     { echo "$TARGET_HOME/.local/share/fonts/${1}Nerd"; }
proton_dir()   { echo "$TARGET_HOME/.local/share/Steam/compatibilitytools.d"; }

record_tag() {   # (every write into the home is the user's own: user_put)
  as_user mkdir -p "$(up_state_dir)"
  printf '%s\n' "$2" | user_put 0644 "$(up_state_dir)/$1"
}

# fetch_pinned URL SHA256 [NAME] → downloaded, checked, unpacked into a fresh dir; sets REL_DIR.
# A release file that is no archive (bluetui's is the binary itself) is put there as NAME.
# Returns 1 (nothing installed) when the download fails or its checksum is not the pinned one.
fetch_pinned() {
  local url=$1 want=$2 file
  REL_DIR=$(mktemp -d "$KAWA_TMP/rel.XXXXXX"); file="$REL_DIR/${url##*/}"
  retry 3 10 "${CURL[@]}" -o "$file" "$url" || { log "download failed: $url"; return 1; }
  [[ $(sha256sum "$file" | cut -d' ' -f1) == "$want" ]] \
    || { log "${file##*/}: its SHA-256 is not the pinned one — refused"; return 1; }
  log "verified: ${file##*/}"
  mkdir -p "$REL_DIR/x"
  case $file in
    *.zip)    7z x -y -bso0 -bsp0 -o"$REL_DIR/x" "$file" ;;
    *.tar.gz) tar -xzf "$file" -C "$REL_DIR/x" --no-same-owner ;;
    *.tar.xz) tar -xJf "$file" -C "$REL_DIR/x" --no-same-owner ;;
    *)        cp -- "$file" "$REL_DIR/x/${3:-${file##*/}}" ;;
  esac
}

# libs_for FILE — every shared library FILE needs is present; one Fedora no longer pulls in
# by itself (libssl.so.3 once Fedora 45 moved to OpenSSL 4, say) is installed by its soname,
# whichever package provides it now. Returns 1 when one still cannot be found. (ldd runs as
# you: it must never run as root on a file you could have shaped — your tools, or dwl, built
# from your folder. Only a fresh download in root's own private folder, already checked
# against its pinned SHA-256, is looked at by root, which alone can read it there.)
# What gets installed is chosen only by files root can vouch for: that fresh download, or
# root's copy of Fedora's own wlroots. A file in your home is only checked — whatever it
# names never decides what root installs (the tool is fetched again instead).
missing_libs() {   # (a file ldd cannot read, or a static one, needs nothing it can name)
  { if [[ -n ${KAWA_TMP:-} && $1 == "$KAWA_TMP"/* ]]; then ldd "$1"; else as_user ldd "$1"; fi || true; } 2>/dev/null \
    | awk '/=> not found/ { print $1 }' | sort -u
}
libs_for() {
  local miss
  case $1 in
    "${KAWA_TMP:-//}"/* | "$(wlr_home)"/lib/*) ;;
    *) miss=$(missing_libs "$1")
       [[ -z $miss ]] || { log "${1##*/} is missing: $(tr '\n' ' ' <<<"$miss")"; return 1; }
       return 0 ;;
  esac
  # (a soname and nothing else: lib….so with its version, one per line)
  miss=$(missing_libs "$1" | grep -E '^lib[A-Za-z0-9._+-]+\.so(\.[0-9]+)*$' | sed 's/$/()(64bit)/') || true
  [[ -z $miss ]] && return 0
  log "${1##*/} needs $(tr '\n' ' ' <<<"$miss")— installing what provides it"
  # shellcheck disable=SC2086  # one soname per word
  dnf -y -q install $miss >>"$LOG_FILE" 2>&1 || true
  # the packages that gave them belong to the desktop from now on: the manifest lists them
  # (lib/manifest.sh, manifest_all), so verify never takes them for something you added
  # shellcheck disable=SC2086
  { cat "$STATE_DIR/upstream-libs" 2>/dev/null; rpm -q --qf '%{name}\n' --whatprovides $miss 2>/dev/null | grep -v ' '; } \
    | sort -u | grep . | write_file "$STATE_DIR/upstream-libs" 0644 || true
  miss=$(missing_libs "$1")
  [[ -z $miss ]] || { log "${1##*/} is still missing: $(tr '\n' ' ' <<<"$miss")"; return 1; }
}

# install_upstream_bin "name|repo|tag|file|sha256|bin1 bin2" — a no-op when that tag is in
# place and runs. Returns 1, having changed nothing, when it cannot be installed.
install_upstream_bin() {
  local name repo tag asset sum bins b have=1 list src
  IFS='|' read -r name repo tag asset sum bins <<<"$1"
  IFS=' ' read -r -a list <<<"$bins"
  for b in "${list[@]}"; do [[ -x $TARGET_HOME/.local/bin/$b ]] || have=0; done
  if ((have)) && [[ $(up_tag "$name") == "$tag" ]]; then
    # it still finds every library? Else fetched again: the checked copy says what it needs
    for b in "${list[@]}"; do [[ -z $(missing_libs "$TARGET_HOME/.local/bin/$b") ]] || have=0; done
    if ((have)); then log "$name $tag — in place"; return 0; fi
    log "$name $tag lacks a library — fetching it again"
  fi
  fetch_pinned "https://github.com/$repo/releases/download/$tag/$asset" "$sum" "${list[0]}" || return 1
  for b in "${list[@]}"; do
    src=$(find "$REL_DIR/x" -type f -name "$b" -print -quit)
    [[ -n $src ]] || { log "$b not found inside the $name $tag archive"; return 1; }
    libs_for "$src" || return 1
  done
  as_user mkdir -p "$TARGET_HOME/.local/bin"
  # (each write checked, the tag recorded only after all of them: repair calls this where
  # errexit is off)
  for b in "${list[@]}"; do
    user_put 0755 "$TARGET_HOME/.local/bin/$b" <"$(find "$REL_DIR/x" -type f -name "$b" -print -quit)" \
      || { log "could not write ~/.local/bin/$b (is the disk full?)"; return 1; }
  done
  record_tag "$name" "$tag"; rm -rf "$REL_DIR"
  ok "$name $tag → ~/.local/bin ($(IFS=' '; echo "${list[*]}"))"
}

localsend_dir() { echo "$TARGET_HOME/.local/share/localsend"; }
install_localsend() {   # the pinned release, whole, into ~/.local/share/localsend (yours)
  local dir; dir=$(localsend_dir)
  if [[ $(up_tag localsend) == "$LOCALSEND_TAG" && -x $dir/localsend_app && -L $TARGET_HOME/.local/bin/localsend ]] \
     && [[ -z $(missing_libs "$dir/localsend_app") ]]; then
    log "LocalSend $LOCALSEND_TAG — in place"; return 0
  fi
  fetch_pinned "https://github.com/localsend/localsend/releases/download/$LOCALSEND_TAG/$LOCALSEND_ASSET" "$LOCALSEND_SHA256" || return 1
  [[ -f $REL_DIR/x/localsend_app ]] || { log "localsend_app not found inside the LocalSend $LOCALSEND_TAG archive"; return 1; }
  libs_for "$REL_DIR/x/localsend_app" || return 1      # (its tray: libayatana-appindicator)
  # the new folder made beside the old one, then put in its place: never half of each
  as_user rm -rf -- "$dir.new" && as_user mkdir -p -- "$dir.new" || return 1
  (cd "$REL_DIR/x" && tar -cf - .) | as_user tar -xf - -C "$dir.new" --no-same-owner \
    || { as_user rm -rf -- "$dir.new"; log "could not write ${dir/#$TARGET_HOME/\~} (is the disk full?)"; return 1; }
  as_user rm -rf -- "$dir" && as_user mv -T -- "$dir.new" "$dir" || return 1
  as_user mkdir -p "$TARGET_HOME/.local/bin"
  as_user ln -sfn ../share/localsend/localsend_app "$TARGET_HOME/.local/bin/localsend" || return 1
  record_tag localsend "$LOCALSEND_TAG"; rm -rf "$REL_DIR"
  ok "LocalSend $LOCALSEND_TAG → ~/.local/share/localsend (localsend)"
}
localsend_current() { [[ $(up_tag localsend) == "$LOCALSEND_TAG" && -x $(localsend_dir)/localsend_app ]]; }

retire_upstream() {   # UPSTREAM_RETIRED out: each binary (only one its record says we put there) and its record
  local n
  for n in "${UPSTREAM_RETIRED[@]}"; do
    [[ -n $(up_tag "$n") ]] || continue
    as_user rm -f -- "$TARGET_HOME/.local/bin/$n" "$(up_state_dir)/$n" || return 1
    log "$n — no longer part of the desktop: taken out of ~/.local/bin"
  done
}

install_nerd_fonts() {    # each family from its own release file, checksum-pinned
  local e name sum dir f failed=0 bad
  for e in "${NERD_FONTS[@]}"; do
    IFS='|' read -r name sum <<<"$e"; dir=$(font_dir "$name")
    if [[ $(up_tag "nerd-$name") == "$NERD_FONTS_TAG" ]] && compgen -G "$dir/*.[ot]tf" >/dev/null; then
      log "$name Nerd Font $NERD_FONTS_TAG — in place"; continue
    fi
    fetch_pinned "https://github.com/ryanoasis/nerd-fonts/releases/download/$NERD_FONTS_TAG/$name.tar.xz" "$sum" \
      || { failed=1; continue; }
    compgen -G "$REL_DIR/x/*.[ot]tf" >/dev/null || { log "the $name archive held no font files"; failed=1; continue; }
    as_user rm -rf "$dir"; as_user mkdir -p "$dir"; bad=0
    while IFS= read -r -d '' f; do user_put 0644 "$dir/${f##*/}" <"$f" || bad=1; done \
      < <(find "$REL_DIR/x" \( -name '*.ttf' -o -name '*.otf' \) -print0)
    rm -rf "$REL_DIR"
    if ((bad)); then log "could not write the $name fonts into $dir (is the disk full?)"; failed=1; continue; fi
    record_tag "nerd-$name" "$NERD_FONTS_TAG"
    ok "$name Nerd Font $NERD_FONTS_TAG"
  done
  as_user fc-cache -f >/dev/null
  return "$failed"
}

install_fusion() {   # pinned archives → /usr/local/share/fonts/fusion-pixel (the faces, the licence,
  # and the terminal's face made from the 10 px one: Sumi Term, tools/build-term-font.py)
  local e px f have=1 rels=() faces=() lic=""
  for e in "${FUSION_FACES[@]}"; do [[ -s $FUSION_DIR/fusion-pixel-${e%%|*}px-monospaced-ja.ttf ]] || have=0; done
  if ((have)) && [[ $(cat "$FUSION_DIR/.version" 2>/dev/null) == "$FUSION_TAG" ]]; then
    log "Fusion Pixel 12 and 10 $FUSION_TAG — in place"; sumi_term; sumi_ui; return
  fi
  # every archive fetched and checked before anything is installed: one refused, none is
  for e in "${FUSION_FACES[@]}"; do
    px=${e%%|*}
    fetch_pinned "https://github.com/TakWolf/fusion-pixel-font/releases/download/$FUSION_TAG/fusion-pixel-font-${px}px-monospaced-ttf-v$FUSION_TAG.zip" "${e#*|}" \
      || { rm -rf "${rels[@]}" "$REL_DIR"; return 1; }
    rels+=("$REL_DIR")
    f=$(find "$REL_DIR/x" -name "fusion-pixel-${px}px-monospaced-ja.ttf" -print -quit)
    [[ -s $f ]] || { rm -rf "${rels[@]}"; log "the Fusion Pixel $px archive held no Japanese $px px face"; return 1; }
    faces+=("$f"); [[ -n $lic ]] || lic=$(find "$REL_DIR/x" -name OFL.txt -print -quit)
  done
  install -d -m 0755 "$FUSION_DIR" && install -m 0644 "${faces[@]}" "$lic" "$FUSION_DIR/" \
    || { rm -rf "${rels[@]}"; log "could not write $FUSION_DIR (is the disk full?)"; return 1; }
  rm -rf "${rels[@]}"
  printf '%s\n' "$FUSION_TAG" >"$FUSION_DIR/.version"
  # the pixel fonts before it, in the home: Fusion Pixel draws all they did
  as_user rm -rf "$TARGET_HOME/.local/share/fonts/PixelMplus" "$TARGET_HOME/.local/share/fonts/DepartureMonoNerd" \
    "$TARGET_HOME/.local/share/fonts/FusionPixel"
  as_user rm -f "$(up_state_dir)/nerd-DepartureMono"
  fc-cache -f "$FUSION_DIR" >/dev/null; as_user fc-cache -f >/dev/null
  ok "Fusion Pixel 12 and 10 $FUSION_TAG (the desktop's font, Latin and Japanese)"
  sumi_term; sumi_ui
}
# sumi_term — the terminal's face, Sumi Term, made from the 10 px one (tools/build-term-font.py)
# whenever it is missing or older than the face or the tool that makes it
sumi_term() {
  local f=$FUSION_DIR/sumi-term.ttf src=$FUSION_DIR/fusion-pixel-10px-monospaced-ja.ttf
  [[ -s $f && ! $f -ot $src && ! $f -ot $REPO_DIR/tools/build-term-font.py ]] && return 0
  python3 -I "$REPO_DIR/tools/build-term-font.py" "$src" "$f.new" && chmod 0644 "$f.new" && mv -f "$f.new" "$f" \
    || { rm -f "$f.new"; log "could not make the terminal's face, Sumi Term (python3-fonttools)"; return 1; }
  fc-cache -f "$FUSION_DIR" >/dev/null; as_user fc-cache -f >/dev/null
  ok "Sumi Term (the terminal's face: Fusion Pixel 10, its upright strokes a screen pixel heavier)"
}
# sumi_ui — the UI's face, Sumi UI, made from the 12 px one (tools/build-ui-font.py), the same way
sumi_ui() {
  local f=$FUSION_DIR/sumi-ui.ttf src=$FUSION_DIR/fusion-pixel-12px-monospaced-ja.ttf
  [[ -s $f && ! $f -ot $src && ! $f -ot $REPO_DIR/tools/build-ui-font.py ]] && return 0
  python3 -I "$REPO_DIR/tools/build-ui-font.py" "$src" "$f.new" && chmod 0644 "$f.new" && mv -f "$f.new" "$f" \
    || { rm -f "$f.new"; log "could not make the UI's face, Sumi UI (python3-fonttools)"; return 1; }
  fc-cache -f "$FUSION_DIR" >/dev/null; as_user fc-cache -f >/dev/null
  ok "Sumi UI (the UI's face: Fusion Pixel 12, its upright strokes doubled)"
}

# swap_in NEW DIR NAME — the folder NEW (built, and found to work) in DIR's place, the old one
# kept aside until it is: a move that fails puts the old one back (returns 1, said)
swap_in() {
  local new=$1 d=$2
  as_user mkdir -p "$(dirname "$d")"
  as_user rm -rf "$d.old"; if [[ -d $d ]]; then as_user mv -T "$d" "$d.old"; fi
  if ! as_user mv -T "$new" "$d"; then
    [[ -d $d.old ]] && as_user mv -T "$d.old" "$d"
    log "could not put $3 in $d"; return 1
  fi
  as_user rm -rf "$d.old"
}

# ── Syncplay ──────────────────────────────────────────────────────────────────
# (kawa-together reads Syncplay's public servers and its port from this folder: keep the two
# in step)
syncplay_dir() { echo "$TARGET_HOME/.local/share/fedokawaii/syncplay"; }

# syncplay_starter NAME MODULE DIR [ARG…] — the small script ~/.local/bin/NAME: Syncplay's
# MODULE from DIR, run by Fedora's python3, isolated (-I: nothing of yours on its path) and
# unbuffered (-u: its lines reach a pipe or a log as they happen, as they reach a terminal)
syncplay_starter() {
  local name=$1 module=$2 dir=$3; shift 3
  printf '#!/bin/sh\n# %s — Syncplay %s without its window, from its folder; lib/upstream.sh writes it\n' "$name" "$SYNCPLAY_TAG"
  printf '# (setup, update and repair keep it)\npy=%q dir=%q\n' "$SYNCPLAY_PYTHON" "$dir"
  printf 'exec "$py" -I -u -c '"'"'import sys; sys.argv[0] = "%s"; sys.path.insert(0, sys.argv.pop(1)); from syncplay.%s import main; main()'"'"' "$dir"%s "$@"\n' \
    "$name" "$module" "${*:+ $*}"
}

# syncplay_runs [DIR] — that folder loads with Fedora's python3: the client and server and,
# for the secure connection, Twisted's TLS, certifi and pem (a missing one would turn TLS off
# without a word); its version is the pinned one
syncplay_runs() {
  as_user "$SYNCPLAY_PYTHON" -I -c 'import sys; sys.path.insert(0, sys.argv[1])
import syncplay, syncplay.client, syncplay.server, certifi, pem
from twisted.internet.ssl import optionsForClientTLS
sys.exit(syncplay.version != sys.argv[2])' "${1:-$(syncplay_dir)}" "${SYNCPLAY_TAG#v}" >/dev/null 2>&1
}
# syncplay_starters [--check] — the two starters as this toolkit writes them (written again
# when they differ: a newer toolkit's, or one gone); --check only says whether they do
syncplay_starters() {
  local e name module want f
  for e in "syncplay ep_client --no-gui" "syncplay-server ep_server"; do
    IFS=' ' read -r name module want <<<"$e"
    want=$(syncplay_starter "$name" "$module" "$(syncplay_dir)" ${want:+"$want"}); f=$TARGET_HOME/.local/bin/$name
    [[ -x $f && $(as_user cat -- "$f" 2>/dev/null) == "$want" ]] && continue
    [[ ${1:-} == --check ]] && return 1
    as_user mkdir -p "$TARGET_HOME/.local/bin"
    printf '%s\n' "$want" | user_put 0755 "$f" || return 1
  done
}
# syncplay_pin — what the record holds: the pinned commit, and which patch of ours it carries
# (a changed patch is a new pin: update puts in a copy with it)
syncplay_pin() {
  local s; s=$(sha256sum <"$SYNCPLAY_PATCH" 2>/dev/null) || s=missing
  printf '%s+%.12s\n' "$SYNCPLAY_COMMIT" "$s"
}
syncplay_current() {
  [[ $(up_tag syncplay) == "$(syncplay_pin)" ]] && syncplay_starters --check && syncplay_runs
}

# install_syncplay — a no-op when the pinned commit is in place, with our patch, and loads.
# Else its tag is fetched (as you, into a folder of yours that goes again), must be the pinned
# commit, takes the patch, and the new folder must load before it replaces the old one; then
# the two starters. Returns 1, having changed nothing, when any of that fails.
install_syncplay() {
  local d src
  d=$(syncplay_dir)
  if [[ $(up_tag syncplay) == "$(syncplay_pin)" ]] && syncplay_runs; then
    syncplay_starters || return 1
    log "Syncplay $SYNCPLAY_TAG — in place"; return 0
  fi
  src=$(as_user mktemp -d) || return 1
  if ! retry 3 10 as_user git -c advice.detachedHead=false clone --quiet --depth 1 --branch "$SYNCPLAY_TAG" "$SYNCPLAY_REPO" "$src/s"; then
    log "could not fetch Syncplay $SYNCPLAY_TAG ($SYNCPLAY_REPO)"; as_user rm -rf "$src"; return 1
  fi
  if [[ $(as_user git -C "$src/s" rev-parse "$SYNCPLAY_TAG^{commit}") != "$SYNCPLAY_COMMIT" ]]; then
    log "Syncplay's tag $SYNCPLAY_TAG is not the pinned commit $SYNCPLAY_COMMIT — refused"; as_user rm -rf "$src"; return 1
  fi
  if ! as_user git -C "$src/s" apply - <"$SYNCPLAY_PATCH"; then
    log "src/syncplay/syncplay.patch does not apply to Syncplay $SYNCPLAY_TAG — refused"; as_user rm -rf "$src"; return 1
  fi
  as_user mkdir -p "$src/new" && as_user cp -R "$src/s/syncplay" "$src/new/" || { as_user rm -rf "$src"; return 1; }
  if ! syncplay_runs "$src/new"; then
    log "Syncplay $SYNCPLAY_TAG does not load with $SYNCPLAY_PYTHON — are the manifest's python3-twisted+tls, python3-certifi and python3-pem installed?"
    as_user rm -rf "$src"; return 1
  fi
  swap_in "$src/new" "$d" Syncplay || { as_user rm -rf "$src"; return 1; }
  as_user rm -rf "$src"
  syncplay_starters || return 1
  record_tag syncplay "$(syncplay_pin)"
  syncplay_current || { log "Syncplay $SYNCPLAY_TAG was put in place but does not start"; return 1; }
  ok "Syncplay $SYNCPLAY_TAG (no window) → ~/.local/bin (syncplay, syncplay-server)"
}

# ── ble.sh ────────────────────────────────────────────────────────────────────
blesh_dir() { echo "$TARGET_HOME/.local/share/blesh"; }
# blesh_runs [DIR] — that copy loads and is the pinned commit (its version names it)
blesh_runs() {
  [[ $(as_user bash "${1:-$(blesh_dir)}/ble.sh" --version 2>/dev/null) == *"+${BLESH_COMMIT:0:7}" ]]
}
blesh_current() { [[ $(up_tag blesh) == "$BLESH_COMMIT" ]] && blesh_runs; }

# install_blesh — a no-op when the pinned commit is in place and loads. Else that commit is
# fetched by its hash (as you, into a folder of yours that goes again) with its contrib/
# part, built into a new folder, and that folder must load before it replaces the old one.
# Returns 1, having changed nothing, when any of that fails.
install_blesh() {
  local d src
  d=$(blesh_dir)
  if blesh_current; then log "ble.sh ${BLESH_COMMIT:0:7} — in place"; return 0; fi
  src=$(as_user mktemp -d) || return 1
  as_user git init -q "$src/s" && as_user git -C "$src/s" remote add origin "$BLESH_REPO" \
    || { as_user rm -rf "$src"; return 1; }
  if ! retry 3 10 as_user git -C "$src/s" fetch -q --depth 1 origin "$BLESH_COMMIT" \
     || ! as_user git -C "$src/s" -c advice.detachedHead=false checkout -q FETCH_HEAD \
     || ! retry 3 10 as_user git -C "$src/s" submodule update -q --init --depth 1; then
    log "could not fetch ble.sh ${BLESH_COMMIT:0:7} ($BLESH_REPO)"; as_user rm -rf "$src"; return 1
  fi
  if ! as_user make -C "$src/s" install INSDIR="$src/new" >>"$LOG_FILE" 2>&1; then
    log "ble.sh ${BLESH_COMMIT:0:7} did not build ($LOG_FILE says why)"; as_user rm -rf "$src"; return 1
  fi
  if ! blesh_runs "$src/new"; then
    log "the ble.sh just built does not load as ${BLESH_COMMIT:0:7} — refused"; as_user rm -rf "$src"; return 1
  fi
  swap_in "$src/new" "$d" ble.sh || { as_user rm -rf "$src"; return 1; }
  as_user rm -rf "$src"
  record_tag blesh "$BLESH_COMMIT"
  ok "ble.sh ${BLESH_COMMIT:0:7} (the shell's colours, suggestions and menus) → ~/.local/share/blesh"
}

# GE-Proton: its newest release (the GitHub API names it; its own .sha512sum file — the one
# for that very file — checks it). The newest two are kept, so a game pinned to the
# previous one still starts. Returns 1, having changed nothing, when GitHub cannot be
# reached or the file does not check out. Its folder is named as the archive names it.
install_ge_proton() {
  local json tag url sumurl dir want got file name top part
  dir=$(proton_dir)
  json=$("${CURL[@]}" -H 'Accept: application/vnd.github+json' \
         "https://api.github.com/repos/$GE_PROTON_REPO/releases/latest") || { log "GitHub not reachable for GE-Proton"; return 1; }
  # the checksum file is the one named like the archive (…-x86_64.sha512sum); a release with
  # a single checksum file of another name is taken only when it is the only one there
  IFS=$'\t' read -r tag url sumurl < <(jq -r --arg re "$GE_PROTON_ASSET" '
    .tag_name as $t | (.assets | map(select(.name | test($re))) | first) as $a
    | ($a.name // "" | sub("\\.tar\\.gz$"; ".sha512sum")) as $sn
    | (.assets | map(select(.name | test("\\.sha512sum$")))) as $sums
    | ($sums | map(select(.name == $sn)) | first // (if ($sums | length) == 1 then $sums[0] else null end)) as $s
    | [$t, ($a.browser_download_url // ""), ($s.browser_download_url // "")] | @tsv' <<<"$json") || true
  # (an answer that is not JSON — a Wi-Fi sign-in page — reads as no release: said below)
  [[ -n ${tag:-} && -n ${url:-} && -n ${sumurl:-} ]] || { log "no GE-Proton release file for x86_64 found"; return 1; }
  file=${url##*/}; name=${file%.tar.gz}
  if [[ -d $dir/$name || -d $dir/$tag ]]; then   # (put there before, or by another tool: recorded)
    if [[ -d $dir/$name ]]; then record_tag ge-proton "$name"; else record_tag ge-proton "$tag"; fi
    log "$name — in place"; return 0
  fi
  # the line for this file, or the file's only hash
  want=$("${CURL[@]}" "$sumurl") || { log "GE-Proton's checksum file not reachable"; return 1; }
  want=$({ grep -F -- "$file" <<<"$want" || printf '%s\n' "$want"; } | grep -oE '\b[0-9a-f]{128}\b' | sed -n 1p; exit "${PIPESTATUS[1]}") \
    || { log "GE-Proton's checksum file holds no SHA-512 for $file"; return 1; }
  REL_DIR=$(mktemp -d "$KAWA_TMP/rel.XXXXXX")
  retry 3 10 "${CURL[@]}" -o "$REL_DIR/ge.tar.gz" "$url" || { log "GE-Proton download failed"; return 1; }
  got=$(sha512sum "$REL_DIR/ge.tar.gz" | cut -d' ' -f1)
  [[ $got == "$want" ]] || { log "GE-Proton $file: checksum mismatch — refused"; return 1; }
  mkdir -p "$REL_DIR/x"; tar -xzf "$REL_DIR/ge.tar.gz" -C "$REL_DIR/x" --no-same-owner
  # its one top folder (GE-Proton11-9-x86_64/, or GE-Proton10-25/ before), with Steam's file in it
  top=$(find "$REL_DIR/x" -mindepth 1 -maxdepth 1 -type d -name 'GE-Proton*' -printf '%f\n')
  [[ -n $top && $top != *$'\n'* && -f $REL_DIR/x/$top/compatibilitytool.vdf ]] \
    || { log "the GE-Proton archive did not hold one GE-Proton folder with compatibilitytool.vdf"; return 1; }
  # unpacked by you into a folder of its own, then moved into place in one step: a power cut or
  # a full disk half-way leaves nothing half-made that a later run would take for installed
  # (each step checked: repair calls this where errexit is off)
  part=$dir/.fedokawaii-unpack
  if ! { as_user mkdir -p "$dir" && as_user rm -rf -- "$part" && as_user mkdir -- "$part" \
         && tar -C "$REL_DIR/x" -cf - "$top" | as_user tar -C "$part" -xf - --no-same-owner \
         && as_user mv -T -- "$part/$top" "$dir/$top"; }; then
    as_user rm -rf -- "$part"; log "GE-Proton could not be unpacked into $dir (is the disk full?)"; return 1
  fi
  as_user rm -rf -- "$part"
  as_user find "$dir" -mindepth 1 -maxdepth 1 -type d -name 'GE-Proton*' -printf '%f\n' | sort -V | head -n -2 \
    | while read -r old; do as_user rm -rf "${dir:?}/$old"; log "removed old $old"; done
  record_tag ge-proton "$top"; rm -rf "$REL_DIR"
  ok "$top → Steam compatibilitytools.d"
}
