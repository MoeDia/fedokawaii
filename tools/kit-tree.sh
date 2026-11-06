#!/usr/bin/env bash
# tools/kit-tree.sh — what tools/kit.sh --tree renders with: the tree as it is, nothing applied.
# dwl, mako, foot and yazi built at their pins with the repository's patches into a scratch prefix, a
# home from theme.sh (tools/kit-tree-home.sh). Each is made again only when what it was made from
# changed. Nothing installed is written; wlroots is the one the PC keeps, read only.
#   bash tools/kit-tree.sh [--prefix DIR]     (default ~/.cache/r28/kit-tree) → DIR/bin, DIR/home
# Exit 0 · 1 a build failed (DIR/log/NAME.log says why).
set -u
repo=$(cd "$(dirname "$0")/.." && pwd)
prefix=$HOME/.cache/r28/kit-tree
[[ ${1:-} == --prefix ]] && prefix=$2
mkdir -p "$prefix"/{bin,log,src}
pin() { sed -n "s/^$1=\"\\([^\"]*\\)\".*/\\1/p" "$repo/fedokawaii.conf"; }
. "$repo/lib/manifest.sh"
wlr=/usr/local/lib/fedokawaii-wlroots-$(pin DWL_WLROOTS)
# fresh NAME SUM — already made from this? (else the build runs, and stamp NAME SUM records it)
fresh() { [[ -x $prefix/bin/$1 && $(cat "$prefix/bin/$1.built" 2>/dev/null) == "$2" ]]; }
stamp() { printf '%s\n' "$2" >"$prefix/bin/$1.built"; echo "kit-tree: $1 built"; }
fail() { echo "kit-tree: $1 failed: $prefix/log/$1.log" >&2; tail -n 5 "$prefix/log/$1.log" >&2; exit 1; }
# checkout NAME ORIGIN COMMIT PATCH — a clean tree at the pin, the patch applied
checkout() {
  local s=$prefix/src/$1
  rm -rf "$s"
  git clone --quiet --no-checkout "$2" "$s" && git -C "$s" -c advice.detachedHead=false checkout --quiet "$3" \
    && [[ $(git -C "$s" rev-parse HEAD) == "$3" ]] && git -C "$s" apply - <"$4"
}

c=$(pin DWL_COMMIT)
sum=$({ cat "$repo/src/dwl/config.h" "$repo/src/dwl/dwl.patch"; echo "$c"; } | sha256sum)
if ! fresh dwl "$sum"; then
  {
    checkout dwl "$HOME/.local/src/dwl" "$c" "$repo/src/dwl/dwl.patch" \
      && cp "$repo/src/dwl/config.h" "$prefix/src/dwl/config.h" \
      && make -C "$prefix/src/dwl" -j"$(nproc)" "${DWL_MAKE[@]}" "WLR_INCS=$(<"$wlr/cflags")" \
        "WLR_LIBS=-L$wlr/lib -lwlroots-$(pin DWL_WLROOTS) -Wl,--disable-new-dtags,-rpath,$wlr/lib" \
      && cp "$prefix/src/dwl/dwl" "$prefix/bin/dwl"
  } >"$prefix/log/dwl.log" 2>&1 || fail dwl
  stamp dwl "$sum"
fi

c=$(pin MAKO_COMMIT)
sum=$({ cat "$repo/src/mako/mako.patch"; echo "$c"; } | sha256sum)
if ! fresh mako "$sum"; then
  {
    checkout mako "$HOME/.local/src/mako" "$c" "$repo/src/mako/mako.patch" \
      && meson setup "$prefix/src/mako/build" "$prefix/src/mako" --buildtype=release -Dwerror=false \
        -Dman-pages=disabled -Dsd-bus-provider=libsystemd \
      && meson compile -C "$prefix/src/mako/build" \
      && cp "$prefix/src/mako/build/mako" "$prefix/bin/mako"
  } >"$prefix/log/mako.log" 2>&1 || fail mako
  stamp mako "$sum"
fi

# foot's -devel packages unpacked here, not installed: this PC stays as it is (their libraries it has)
foot_devel() {
  local d=$prefix/devel r l
  [[ -d $d/usr/lib64/pkgconfig ]] && return 0
  mkdir -p "$d" && dnf -q download --arch=x86_64 --destdir "$d/rpms" fcft-devel tllist-devel utf8proc-devel || return 1
  for r in "$d"/rpms/*.rpm; do rpm2cpio "$r" | (cd "$d" && cpio -idm --quiet) || return 1; done
  for l in "$d"/usr/lib64/lib*.so; do ln -sf "/usr/lib64/$(readlink "$l")" "$l"; done
  sed -i "s|^prefix=.*|prefix=$d/usr|; s|^libdir=/usr|libdir=$d/usr|; s|^includedir=/usr|includedir=$d/usr|" "$d"/usr/lib64/pkgconfig/*.pc
}
c=$(pin FOOT_COMMIT)
sum=$({ cat "$repo/src/foot/foot.patch"; echo "$c"; } | sha256sum)
if ! fresh foot "$sum"; then
  {
    foot_devel && checkout foot https://codeberg.org/dnkl/foot.git "$c" "$repo/src/foot/foot.patch" \
      && PKG_CONFIG_PATH=$prefix/devel/usr/lib64/pkgconfig meson setup "$prefix/src/foot/build" "$prefix/src/foot" \
        --buildtype=release -Db_lto=true -Dwerror=false -Ddocs=disabled -Dthemes=false -Dtests=false -Dterminfo=disabled \
        -Dgrapheme-clustering=enabled \
      && meson compile -C "$prefix/src/foot/build" \
      && cp "$prefix/src/foot/build/foot" "$prefix/src/foot/build/footclient" "$prefix/bin/"
  } >"$prefix/log/foot.log" 2>&1 || fail foot
  stamp foot "$sum"
fi

c=$(pin YAZI_COMMIT)
sum=$({ cat "$repo/src/yazi/yazi.patch"; echo "$c"; } | sha256sum)
if ! fresh yazi "$sum"; then
  {
    checkout yazi https://github.com/sxyazi/yazi.git "$c" "$repo/src/yazi/yazi.patch" \
      && CARGO_HOME=$prefix/cargo CARGO_PROFILE_RELEASE_LTO=thin CARGO_PROFILE_RELEASE_CODEGEN_UNITS=16 \
        bash -c 'cd "$1" && cargo build --release --locked -p yazi-fm' _ "$prefix/src/yazi" \
      && cp "$prefix/src/yazi/target/release/yazi" "$prefix/bin/yazi"
  } >"$prefix/log/yazi.log" 2>&1 || fail yazi
  rm -rf "$prefix/src/yazi"                 # (its target: up to 2 GB)
  stamp yazi "$sum"
fi

bash "$repo/tools/kit-tree-home.sh" "$prefix/home" >"$prefix/log/home.log" 2>&1 || fail home
echo "kit-tree: $prefix: $(git -C "$repo" rev-parse --short HEAD)"
