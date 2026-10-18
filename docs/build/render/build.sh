#!/bin/bash
# Build the fedokawaii apps — and the text/toolkit stack they draw with — at Fedora 44's
# versions into /opt/f44 (run as root). Nothing is installed outside /opt/f44.
# Sources are expected under /opt/f44/src (README.md says where each came from).
#
#   build.sh [step...]   default: every step, in order; finished steps are skipped
#                        unless FORCE=1 (e.g. FORCE=1 build.sh fcft foot fuzzel)
set -euo pipefail
P=/opt/f44
S=$P/src
LOG=$P/build-logs
mkdir -p "$LOG"
export PKG_CONFIG_PATH=$P/lib/pkgconfig:$P/share/pkgconfig
export LDFLAGS="-Wl,-rpath,$P/lib"
export PATH=$P/meson-venv/bin:$P/bin:$PATH     # meson 1.9.1 (glib needs >= 1.4; Ubuntu has 1.3.2)
common=(--prefix=$P --libdir=lib --buildtype=release)

mb() {  # mb <name> <srcdir> [meson options...]
  local name=$1 dir=$2; shift 2
  if [[ -e $LOG/$name.done && ${FORCE:-0} != 1 ]]; then echo "skip $name"; return; fi
  echo ">>> $name ($(date +%T))"
  rm -rf "$dir/_b"
  { meson setup "$dir/_b" "$dir" "${common[@]}" --wrap-mode="${WRAP:-nofallback}" "$@" &&
    ninja -C "$dir/_b" &&
    if [[ -n ${STAGE:-} ]]; then         # install into a stage, keep only what lands in $P
      rm -rf "$STAGE" && DESTDIR="$STAGE" meson install -C "$dir/_b" &&
        cp -a "$STAGE$P/." "$P/" && rm -rf "$STAGE"
    else ninja -C "$dir/_b" install; fi
  } >"$LOG/$name.log" 2>&1 || { echo "FAILED $name — see $LOG/$name.log"; tail -30 "$LOG/$name.log"; exit 1; }
  touch "$LOG/$name.done"
}

steps=("$@")
[[ ${#steps[@]} -eq 0 ]] && steps=(pixman protocols glib fribidi freetype0 harfbuzz freetype fontconfig cairo pango gtk3
                                   tllist fcft foot fuzzel mako swaylock gls wireplumber waybar)
for s in "${steps[@]}"; do case $s in
  # ── the drawing stack ──────────────────────────────────────────────────────────────
  pixman)    mb pixman $S/pixman-0.46.4 -Dtests=disabled -Ddemos=disabled -Dgtk=disabled ;;
  protocols) mb protocols $S/wayland-protocols-1.49 -Dtests=false ;;
  glib)      mb glib $S/glib -Dselinux=disabled -Dman-pages=disabled -Ddocumentation=false -Dtests=false \
               -Dintrospection=disabled -Dsysprof=disabled -Dglib_debug=disabled ;;
  fribidi)   mb fribidi $S/fribidi -Ddocs=false -Dtests=false -Dbin=false ;;
  # freetype and harfbuzz need each other (Fedora's freetype uses harfbuzz in the
  # autohinter): freetype without it first, then harfbuzz, then freetype again
  freetype0) mb freetype0 $S/freetype -Dharfbuzz=disabled -Dbrotli=enabled -Dbzip2=enabled -Dpng=enabled \
               -Dzlib=system -Dtests=disabled ;;
  harfbuzz)  mb harfbuzz $S/harfbuzz -Dfreetype=enabled -Dglib=enabled -Dgobject=disabled -Dgraphite2=enabled \
               -Dcairo=disabled -Dchafa=disabled -Dicu=disabled -Dtests=disabled -Ddocs=disabled \
               -Dutilities=disabled -Dintrospection=disabled -Dbenchmark=disabled \
               -Draster=disabled -Dvector=disabled -Dgpu=disabled ;;
  freetype)  mb freetype $S/freetype -Dharfbuzz=enabled -Dbrotli=enabled -Dbzip2=enabled -Dpng=enabled \
               -Dzlib=system -Dtests=disabled ;;
  # fontconfig 2.17 reads the system's configuration (/etc/fonts, Ubuntu's conf.d) and
  # caches; only its library and tools go to $P
  fontconfig) STAGE=$S/fontconfig/_stage mb fontconfig $S/fontconfig -Ddoc=disabled -Dtests=disabled \
               -Dtools=enabled -Dcache-build=disabled -Dnls=disabled \
               -Dbaseconfig-dir=/etc/fonts -Dconfig-dir=/etc/fonts/conf.d -Dtemplate-dir=/usr/share/fontconfig/conf.avail \
               -Dxml-dir=/usr/share/xml/fontconfig -Dcache-dir=/var/cache/fontconfig ;;
  cairo)     mb cairo $S/cairo-1.18.4 -Dxlib=enabled -Dxcb=enabled -Dlzo=enabled -Dglib=enabled \
               -Dfreetype=enabled -Dfontconfig=enabled -Dpng=enabled -Dzlib=enabled \
               -Dtests=disabled -Dspectre=disabled -Dsymbol-lookup=disabled -Dgtk_doc=false ;;
  pango)     mb pango $S/pango -Dintrospection=disabled -Ddocumentation=false -Dman-pages=false \
               -Dbuild-testsuite=false -Dbuild-examples=false -Dlibthai=enabled -Dsysprof=disabled ;;
  gtk3)      mb gtk3 $S/gtk3 -Dx11_backend=true -Dwayland_backend=true -Dbroadway_backend=false \
               -Dcloudproviders=false -Dtracker3=false -Dcolord=no -Dprint_backends=file \
               -Dgtk_doc=false -Dman=false -Dintrospection=false -Ddemos=false -Dexamples=false \
               -Dtests=false -Dinstalled_tests=false ;;
  # ── the apps ───────────────────────────────────────────────────────────────────────
  tllist)    mb tllist $S/tllist-1.1.0 ;;
  fcft)      mb fcft $S/fcft-3.3.3 -Dgrapheme-shaping=enabled -Drun-shaping=enabled -Dtest-text-shaping=false -Ddocs=disabled ;;
  foot)      mb foot $S/foot-1.27.0 -Dgrapheme-clustering=enabled -Dterminfo=enabled -Ddocs=disabled -Dtests=false ;;
  fuzzel)    mb fuzzel $S/fuzzel -Denable-cairo=enabled -Dpng-backend=libpng -Dsvg-backend=nanosvg ;;
  mako)      mb mako $S/mako -Dicons=enabled -Dman-pages=disabled -Dsd-bus-provider=libsystemd ;;
  swaylock)  mb swaylock $S/swaylock -Dgdk-pixbuf=enabled -Dpam=enabled -Dman-pages=disabled ;;
  gls)       mb gtk-layer-shell $S/gtk-layer-shell -Dintrospection=false -Dvapi=false -Dtests=false -Ddocs=false -Dexamples=false ;;
  wireplumber) mb wireplumber $S/wireplumber -Dintrospection=disabled -Ddoc=disabled -Dsystem-lua=true \
                 -Dtests=false -Ddbus-tests=false -Dsystemd=disabled -Delogind=disabled \
                 -Dsystemd-user-service=false -Dsystemd-system-service=false ;;
  # spdlog/fmt come from waybar's own wraps (sources pre-seeded from GitHub: see README)
  waybar)    WRAP=default mb waybar $S/waybar --force-fallback-for=spdlog -Dcava=disabled -Dman-pages=disabled -Dtests=disabled \
                 -Dwireplumber=enabled -Dmpris=enabled -Dpulseaudio=enabled -Dlibnl=enabled -Dupower_glib=enabled \
                 -Ddbusmenu-gtk=enabled -Dlibinput=enabled -Dlibudev=enabled -Dlibevdev=enabled -Dmpd=enabled \
                 -Dsystemd=enabled -Djack=disabled -Dgps=disabled -Dsndio=disabled -Dexperimental=true ;;
  *) echo "unknown step $s"; exit 2 ;;
esac; done
echo "all done ($(date +%T))"
