#!/usr/bin/env bash
# tools/hl-dwl.sh — a headless dwl on the real GPU (the card the desktop draws on; pixman on a
# machine with none): nothing on the screen, nothing of the session touched (a runtime dir of its
# own, no input devices: keys go in through wtype's virtual keyboard; a D-Bus session of its own:
# a notice, a player, a portal there never reaches the session's), 1920x1080@144 like the
# monitor, dwl's frame log on. SCRIPT runs inside it (sh, with WAYLAND_DISPLAY and DISPLAY set;
# `wtype -s 1000 …` lets the virtual keyboard register before its first key); dwl ends when
# SCRIPT ends. Nothing is left behind.
#   bash tools/hl-dwl.sh SCRIPT [--dwl BIN] [--asan] [--time S] [--keep DIR] [--size WxH@HZ]
#     --dwl   the binary (default ~/.local/src/dwl/dwl)
#     --asan  that tree built once more with AddressSanitizer (in /tmp, the tree untouched);
#             its reports end up in DIR/asan.* with --keep
#     --time  the longest it may run, seconds (default 60): then it is stopped (exit 124)
#     --keep  DIR gets frames.log (tools/framestat.py), dwl.log, script.log (and asan.*)
# Exit: SCRIPT's own status · 124 out of time · 2 misuse.
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
# (the render node of the card the desktop draws on — start-dwl's rule: the most video memory, or
# the only card; never a fixed renderD128: the numbers move with the cards switched on. None — a
# VM's plain virtio screen —: pixman, as the desktop there draws too)
gpu=(WLR_RENDERER=pixman) most=-1
for n in /sys/class/drm/renderD*; do
  [[ -e /dev/dri/${n##*/} ]] || continue
  [[ $(cat "$n/device/vendor" 2>/dev/null) == 0x1af4 ]] && continue   # (a VM's virtio screen, Red Hat's vendor id: no 3D)
  v=$(cat "$n/device/mem_info_vram_total" 2>/dev/null) || v=0
  [[ $v =~ ^[0-9]+$ ]] || v=0
  ((v > most)) && most=$v gpu=(WLR_RENDERER=gles2 "WLR_RENDER_DRM_DEVICE=/dev/dri/${n##*/}")
done
# (KAWA_HL_NODE=/dev/dri/renderD129: another card, when that one is busy: a local model on it starves a
# kit's first frames for a minute, and the bar is not there when a check looks)
[[ -n ${KAWA_HL_NODE:-} ]] && gpu=(WLR_RENDERER=gles2 "WLR_RENDER_DRM_DEVICE=$KAWA_HL_NODE")
if ((asan)); then
  tree=$(dirname "$(realpath "$bin")") abuild=/tmp/hl-dwl-asan
  rm -rf "$abuild" && mkdir -p "$abuild" || exit 2
  tar -C "$tree" --exclude=.git --exclude=dwl --exclude='*.o' -cf - . | tar -C "$abuild" -xf - || exit 2
  inc=$(cat /usr/local/lib/fedokawaii-wlroots-0.20/cflags) lib=/usr/local/lib/fedokawaii-wlroots-0.20/lib
  make -s -C "$abuild" CFLAGS="-O1 -fsanitize=address -fno-omit-frame-pointer" LDFLAGS="-fsanitize=address" \
    WLR_INCS="$inc" WLR_LIBS="-Wl,-rpath,$lib -L$lib -lwlroots-0.20 -lpixman-1 -ldrm" \
    XWAYLAND=-DXWAYLAND XLIBS="xcb xcb-icccm pixman-1 glesv2" >/dev/null || { echo "hl-dwl: the ASan build failed" >&2; exit 2; }
  bin=$abuild/dwl
fi
[[ -x $bin ]] || { echo "hl-dwl: no dwl at $bin" >&2; exit 2; }
# (the run in a PID namespace of its own, the same user inside: ps, pgrep and kill there see only
# this run's processes — a script that kills by a list it worked out can never reach the session;
# 3 Nov one killed ~60 of the session's programs. dwl is the namespace's first process, so all of
# it ends with dwl). Two user namespaces: the outer one's root mounts an X socket folder of the
# run's own (Xwayland refuses the machine's, whose owner it cannot see from inside), the inner
# one is you again
fence=(unshare --map-root-user --pid --fork --mount-proc --kill-child sh -c 'u=$1 g=$2; shift 2
  mount -t tmpfs -o mode=1777 tmpfs /tmp/.X11-unix && exec unshare --user --map-user="$u" --map-group="$g" "$@"' \
  fence "$(id -u)" "$(id -g)")
"${fence[@]}" true 2>/dev/null || { echo "hl-dwl: no PID namespace of its own (unshare --user --pid)" >&2; exit 2; }
rt=$(mktemp -d /tmp/hl-dwl.XXXXXX)
chmod 700 "$rt"
# (on the way out, every process the run left — its environment names this run's own runtime dir,
# which nothing else on the machine has —, a stopped one too: a kit's bar module once lingered
# stopped for hours and failed the report's check of stopped programs)
reap() {
  local p
  for p in /proc/[0-9]*; do
    grep -qz "^XDG_RUNTIME_DIR=$rt\$" "$p/environ" 2>/dev/null && kill -KILL "${p#/proc/}" 2>/dev/null
  done
  return 0
}
trap 'reap; rm -rf "$rt"' EXIT
# (inside: the mode first, then the script — its status kept for the caller)
cat >"$rt/inside.sh" <<EOF
#!/bin/sh
wlr-randr --output HEADLESS-1 --custom-mode $size >/dev/null 2>&1
dbus-run-session -- sh "$script" >"$rt/script.log" 2>&1
echo \$? >"$rt/status"
kill \$PPID
EOF
chmod +x "$rt/inside.sh"
env -u WAYLAND_DISPLAY -u DISPLAY -u DBUS_SESSION_BUS_ADDRESS XDG_RUNTIME_DIR="$rt" WLR_BACKENDS=headless "${gpu[@]}" \
  WLR_LIBINPUT_NO_DEVICES=1 WLR_HEADLESS_OUTPUTS=1 \
  DWL_FRAMELOG="$rt/frames.log" ASAN_OPTIONS="log_path=$rt/asan:detect_leaks=1" \
  timeout "$limit" "${fence[@]}" "$bin" -s "$rt/inside.sh" >"$rt/dwl.log" 2>&1
rc=$?
if [[ -n $keep ]]; then
  mkdir -p "$keep" && cp -a "$rt"/frames.log "$rt"/dwl.log "$rt"/script.log "$keep"/ 2>/dev/null
  cp -a "$rt"/asan.* "$keep"/ 2>/dev/null
fi
((rc == 124)) && { echo "hl-dwl: out of time ($limit s)" >&2; exit 124; }
[[ -f $rt/status ]] && exit "$(cat "$rt/status")"
echo "hl-dwl: dwl ended before the script did (exit $rc) — its log:" >&2; tail -n 12 "$rt/dwl.log" >&2
exit 1
