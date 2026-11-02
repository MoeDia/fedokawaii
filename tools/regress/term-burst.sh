#!/usr/bin/env bash
# tools/regress/term-burst.sh — never again an abort when a second SIGTERM reaches dwl while it ends (a
# logout's TERM, then its session scope's; 2 Nov 17:04: wl_display_terminate aborted inside quit(),
# called by the late signal on a display on its way out): N headless runs (GLES on the render node,
# like the desktop's), each sent TERMs 1 ms apart until it is gone.
#   bash tools/regress/term-burst.sh [DWL] [N]   (default the installed /usr/local/bin/dwl, 10 runs)
# Exit 0 every run ended cleanly · 1 an abort or a crash (counted) · 2 the check could not run
set -u
bin=${1:-/usr/local/bin/dwl} n=${2:-10}
[[ -x $bin ]] || { echo "term-burst: no dwl at $bin" >&2; exit 2; }
gpu=(WLR_RENDERER=pixman)
for node in /dev/dri/renderD*; do [[ -e $node ]] && { gpu=(WLR_RENDERER=gles2 "WLR_RENDER_DRM_DEVICE=$node"); break; }; done
bad=0
for ((i = 1; i <= n; i++)); do
  rt=$(mktemp -d /tmp/regress-tb.XXXXXX) || exit 2
  chmod 700 "$rt"
  env -u WAYLAND_DISPLAY -u DISPLAY -u DBUS_SESSION_BUS_ADDRESS XDG_RUNTIME_DIR="$rt" WLR_BACKENDS=headless "${gpu[@]}" \
    WLR_LIBINPUT_NO_DEVICES=1 WLR_HEADLESS_OUTPUTS=1 "$bin" -s 'sleep 30' >"$rt/log" 2>&1 &
  pid=$!
  for _ in $(seq 100); do [[ -S $rt/wayland-0 ]] && break; sleep 0.05; done
  [[ -S $rt/wayland-0 ]] || { kill -KILL "$pid" 2>/dev/null; wait "$pid" 2>/dev/null; rm -rf "$rt"; echo "term-burst: dwl did not start" >&2; exit 2; }
  sleep 0.3
  for _ in $(seq 400); do kill -TERM "$pid" 2>/dev/null || break; sleep 0.001; done
  wait "$pid"; rc=$?
  ((rc == 0 || rc == 143)) || { bad=$((bad + 1)); echo "term-burst: run $i ended with status $rc$( ((rc > 128)) && echo " (signal $((rc - 128)))")"; }
  rm -rf "$rt"
done
((bad == 0)) && { echo "term-burst: $n runs, each ended cleanly"; exit 0; }
echo "term-burst: $bad of $n runs did not end cleanly"
exit 1
