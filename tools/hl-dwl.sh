#!/usr/bin/env bash
# tools/hl-dwl.sh — a headless dwl on the real GPU (renderD128): nothing on the screen, nothing
# of the session touched (a runtime dir of its own, no input devices: keys go in through wtype's
# virtual keyboard), 1920x1080@144 like the monitor, dwl's frame log on. SCRIPT runs inside it
# (sh, with WAYLAND_DISPLAY and DISPLAY set; `wtype -s 1000 …` lets the virtual keyboard
# register before its first key); dwl ends when SCRIPT ends. Nothing is left behind.
#   bash tools/hl-dwl.sh SCRIPT [--dwl BIN] [--asan] [--time S] [--keep DIR] [--size WxH@HZ]
#     --dwl   the binary (default ~/.local/src/dwl/dwl)
#     --asan  that tree built once more with AddressSanitizer (in /tmp, the tree untouched);
#             its reports end up in DIR/asan.* with --keep
#     --time  the longest it may run, seconds (default 60): then it is stopped (exit 124)
#     --keep  DIR gets frames.log (tools/framestat.py), dwl.log, script.log (and asan.*)
# Exit: SCRIPT's own status · 124 out of time · 2 misuse or no GPU.
set -u
script="" bin=$HOME/.local/src/dwl/dwl asan=0 limit=60 keep="" size=1920x1080@144Hz
while (($#)); do
  case $1 in
    --dwl) bin=$2; shift 2 ;;
    --asan) asan=1; shift ;;
    --time) limit=$2; shift 2 ;;
    --keep) keep=$2; shift 2 ;;
    --size) size=$2; shift 2 ;;
    -h|--help) sed -n '2,/^set -u/{/^set -u/d;s/^# \{0,1\}//;p}' "$0"; exit 0 ;;
    -*) echo "hl-dwl: unknown option $1" >&2; exit 2 ;;
    *) script=$(realpath "$1"); shift ;;
  esac
done
[[ -f $script ]] || { echo "usage: bash tools/hl-dwl.sh SCRIPT [--dwl BIN] [--asan] [--time S] [--keep DIR]" >&2; exit 2; }
[[ -e /dev/dri/renderD128 ]] || { echo "hl-dwl: no GPU render node (renderD128)" >&2; exit 2; }
if ((asan)); then
  tree=$(dirname "$(realpath "$bin")") abuild=/tmp/hl-dwl-asan
  rm -rf "$abuild" && mkdir -p "$abuild" || exit 2
  tar -C "$tree" --exclude=.git --exclude=dwl --exclude='*.o' -cf - . | tar -C "$abuild" -xf - || exit 2
  inc=$(cat /usr/local/lib/fedokawaii-wlroots-0.20/cflags) lib=/usr/local/lib/fedokawaii-wlroots-0.20/lib
  make -s -C "$abuild" CFLAGS="-O1 -fsanitize=address -fno-omit-frame-pointer" LDFLAGS="-fsanitize=address" \
    WLR_INCS="$inc" WLR_LIBS="-Wl,-rpath,$lib -L$lib -lwlroots-0.20 -lpixman-1 -ldrm" \
    XWAYLAND=-DXWAYLAND XLIBS="xcb xcb-icccm" >/dev/null || { echo "hl-dwl: the ASan build failed" >&2; exit 2; }
  bin=$abuild/dwl
fi
[[ -x $bin ]] || { echo "hl-dwl: no dwl at $bin" >&2; exit 2; }
rt=$(mktemp -d /tmp/hl-dwl.XXXXXX)
chmod 700 "$rt"
trap 'rm -rf "$rt"' EXIT
# (inside: the mode first, then the script — its status kept for the caller)
cat >"$rt/inside.sh" <<EOF
#!/bin/sh
wlr-randr --output HEADLESS-1 --custom-mode $size >/dev/null 2>&1
sh "$script" >"$rt/script.log" 2>&1
echo \$? >"$rt/status"
kill \$PPID
EOF
chmod +x "$rt/inside.sh"
env -u WAYLAND_DISPLAY -u DISPLAY XDG_RUNTIME_DIR="$rt" WLR_BACKENDS=headless WLR_RENDERER=gles2 \
  WLR_LIBINPUT_NO_DEVICES=1 WLR_HEADLESS_OUTPUTS=1 WLR_RENDER_DRM_DEVICE=/dev/dri/renderD128 \
  DWL_FRAMELOG="$rt/frames.log" ASAN_OPTIONS="log_path=$rt/asan:detect_leaks=1" \
  timeout "$limit" "$bin" -s "$rt/inside.sh" >"$rt/dwl.log" 2>&1
rc=$?
if [[ -n $keep ]]; then
  mkdir -p "$keep" && cp -a "$rt"/frames.log "$rt"/dwl.log "$rt"/script.log "$keep"/ 2>/dev/null
  cp -a "$rt"/asan.* "$keep"/ 2>/dev/null
fi
((rc == 124)) && { echo "hl-dwl: out of time ($limit s)" >&2; exit 124; }
[[ -f $rt/status ]] && exit "$(cat "$rt/status")"
echo "hl-dwl: dwl ended before the script did (exit $rc) — its log:" >&2; tail -n 12 "$rt/dwl.log" >&2
exit 1
