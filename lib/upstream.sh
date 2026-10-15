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
  "presenterm|mfontanini/presenterm|v0.16.1|presenterm-0.16.1-x86_64-unknown-linux-musl.tar.gz|87512d7c88c3d961c7687aca3519f83c2b7611a550cf769c67c6f7948e8b8f54|presenterm"
  "spotify_player|aome510/spotify-player|v0.25.1|spotify_player-x86_64-unknown-linux-gnu.tar.gz|e68dce205e995f80107149c55ace7b93125dbf73805363b7b0f9bfe8475c50ba|spotify_player"
)
# the fonts: terminal + code · bar, menus, notifications, lock — Nerd Fonts v3.5.1
NERD_FONTS_TAG=v3.5.1
NERD_FONTS=(
  "JetBrainsMono|04d5e8f903693f9dd13e16f867e994834e681eb3c72c0d337a770dcda09010cf"
  "DepartureMono|7d2d86db20730e26ee4fc926e3c64429d6f9da6fce91e74c325fe1c5ee74d9ee"
)
# PixelMplus 12: a 12 px pixel font with Japanese (kana + kanji), for the small Japanese
# touches in the bar and menus. Its only release is from 2013.
PIXELMPLUS_URL="https://github.com/itouhiro/PixelMplus/releases/download/v1.0.0/PixelMplus-20130602.zip"
PIXELMPLUS_SHA256="ca4b5eecc9cf869e85d480000084ecc0fb24c16fc8b37b4046145ecd642fae11"
# (its files were GE-ProtonN-M.tar.gz; since GE-Proton 11 there is one per architecture:
# GE-ProtonN-M-x86_64.tar.gz beside -aarch64 — either form is taken, never the aarch64 one)
GE_PROTON_REPO="GloriousEggroll/proton-ge-custom"; GE_PROTON_ASSET='^GE-Proton[0-9]+-[0-9]+(-x86_64)?\.tar\.gz$'
# torrra (from PyPI, with pipx) is held at this version: kawa-torrra hands it the Prowlarr
# key by replacing three methods of its settings class, so a newer torrra is taken only
# after that has been checked against it.
TORRRA_VERSION=2.5.1

up_state_dir() { echo "$TARGET_HOME/.local/share/fedokawaii/upstream"; }
up_tag()       { as_user cat -- "$(up_state_dir)/$1" 2>/dev/null | head -c 200 || true; }   # (yours: read as you)
font_dir()     { echo "$TARGET_HOME/.local/share/fonts/${1}Nerd"; }
proton_dir()   { echo "$TARGET_HOME/.local/share/Steam/compatibilitytools.d"; }

record_tag() {   # (every write into the home is the user's own: user_put)
  as_user mkdir -p "$(up_state_dir)"
  printf '%s\n' "$2" | user_put 0644 "$(up_state_dir)/$1"
}

# fetch_pinned URL SHA256 → downloaded, checked, unpacked into a fresh dir; sets REL_DIR.
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
  fetch_pinned "https://github.com/$repo/releases/download/$tag/$asset" "$sum" || return 1
  for b in "${list[@]}"; do
    src=$(find "$REL_DIR/x" -type f -name "$b" -print -quit)
    [[ -n $src ]] || { log "$b not found inside the $name $tag archive"; return 1; }
    libs_for "$src" || return 1
  done
  as_user mkdir -p "$TARGET_HOME/.local/bin"
  for b in "${list[@]}"; do
    user_put 0755 "$TARGET_HOME/.local/bin/$b" <"$(find "$REL_DIR/x" -type f -name "$b" -print -quit)"
  done
  record_tag "$name" "$tag"; rm -rf "$REL_DIR"
  ok "$name $tag → ~/.local/bin ($(IFS=' '; echo "${list[*]}"))"
}

install_nerd_fonts() {    # each family from its own release file, checksum-pinned
  local e name sum dir f failed=0
  for e in "${NERD_FONTS[@]}"; do
    IFS='|' read -r name sum <<<"$e"; dir=$(font_dir "$name")
    if [[ $(up_tag "nerd-$name") == "$NERD_FONTS_TAG" ]] && compgen -G "$dir/*.[ot]tf" >/dev/null; then
      log "$name Nerd Font $NERD_FONTS_TAG — in place"; continue
    fi
    fetch_pinned "https://github.com/ryanoasis/nerd-fonts/releases/download/$NERD_FONTS_TAG/$name.tar.xz" "$sum" \
      || { failed=1; continue; }
    compgen -G "$REL_DIR/x/*.[ot]tf" >/dev/null || { log "the $name archive held no font files"; failed=1; continue; }
    as_user rm -rf "$dir"; as_user mkdir -p "$dir"
    while IFS= read -r -d '' f; do user_put 0644 "$dir/${f##*/}" <"$f"; done \
      < <(find "$REL_DIR/x" \( -name '*.ttf' -o -name '*.otf' \) -print0)
    record_tag "nerd-$name" "$NERD_FONTS_TAG"; rm -rf "$REL_DIR"
    ok "$name Nerd Font $NERD_FONTS_TAG"
  done
  as_user fc-cache -f >/dev/null
  return "$failed"
}

install_pixelmplus() {   # pinned archive → ~/.local/share/fonts/PixelMplus (12 px faces only)
  local dir=$TARGET_HOME/.local/share/fonts/PixelMplus f
  if compgen -G "$dir/PixelMplus12-*.ttf" >/dev/null; then log "PixelMplus 12 — in place"; return 0; fi
  fetch_pinned "$PIXELMPLUS_URL" "$PIXELMPLUS_SHA256" || return 1
  as_user mkdir -p "$dir"
  while IFS= read -r -d '' f; do user_put 0644 "$dir/${f##*/}" <"$f"; done \
    < <(find "$REL_DIR/x" \( -name 'PixelMplus12-*.ttf' -o -name 'LICENSE_E' \) -print0)
  rm -rf "$REL_DIR"
  compgen -G "$dir/PixelMplus12-*.ttf" >/dev/null || { log "the PixelMplus archive held no 12 px fonts"; return 1; }
  as_user fc-cache -f >/dev/null
  ok "PixelMplus 12 (Japanese pixel font)"
}

# GE-Proton: its newest release (the GitHub API names it; its own .sha512sum file — the one
# for that very file — checks it). The newest two are kept, so a game pinned to the
# previous one still starts. Returns 1, having changed nothing, when GitHub cannot be
# reached or the file does not check out. Its folder is named as the archive names it.
install_ge_proton() {
  local json tag url sumurl dir want got file name top
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
    | [$t, ($a.browser_download_url // ""), ($s.browser_download_url // "")] | @tsv' <<<"$json")
  [[ -n ${tag:-} && -n ${url:-} && -n ${sumurl:-} ]] || { log "no GE-Proton release file for x86_64 found"; return 1; }
  file=${url##*/}; name=${file%.tar.gz}
  if [[ -d $dir/$name || -d $dir/$tag ]]; then   # (put there before, or by another tool: recorded)
    if [[ -d $dir/$name ]]; then record_tag ge-proton "$name"; else record_tag ge-proton "$tag"; fi
    log "$name — in place"; return 0
  fi
  # the line for this file, or the file's only hash
  want=$("${CURL[@]}" "$sumurl") || { log "GE-Proton's checksum file not reachable"; return 1; }
  want=$({ grep -F -- "$file" <<<"$want" || printf '%s\n' "$want"; } | grep -m1 -oE '\b[0-9a-f]{128}\b') \
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
  as_user mkdir -p "$dir"
  tar -C "$REL_DIR/x" -cf - "$top" | as_user tar -C "$dir" -xf - --no-same-owner   # (unpacked by you)
  as_user find "$dir" -mindepth 1 -maxdepth 1 -type d -name 'GE-Proton*' -printf '%f\n' | sort -V | head -n -2 \
    | while read -r old; do as_user rm -rf "${dir:?}/$old"; log "removed old $old"; done
  record_tag ge-proton "$top"; rm -rf "$REL_DIR"
  ok "$top → Steam compatibilitytools.d"
}
