#!/usr/bin/env bash
# tests/session/test_clicks.sh — every click and scroll of waybar's config starts at once: run
# against stand-ins as slow as a real machine at its worst (the network, NetworkManager,
# bluetoothd, udisks and PipeWire each a whole second behind; the monitor's DDC/CI 100 ms a
# call), the first thing you see or hear (a menu or window, the panel, a key pressed, a level
# set, a notice) comes within 900 ms — nothing slow is waited for before it. A timing test:
# under heavy load run it alone.
. "$(dirname "$0")/../lib/harness.sh"

sandbox
config .config/fedokawaii/env
# a stand-in that is something you see: its start is stamped in $TMP/acts
seen() { stub "$1" "echo \"$1 \$(date +%s%N)\" >>\"\$TMP/acts\"${2:+; $2}"; }
slow() { stub "$1" "sleep $2${3:+; $3}"; }   # a stand-in that only takes its time
for p in fuzzel footclient kawa-panel wtype kawa-osd steam notify-send; do seen "$p"; done
seen playerctl; seen wpctl 'echo "Volume: 0.50"'
slow nmcli 1; slow bluetoothctl 1; slow curl 3; slow busctl 1; slow pw-dump 1 'echo "[]"'; slow udisksctl 1
slow makoctl 0.01
stub lsblk 'echo "{\"blockdevices\":[{\"name\":\"/dev/sdb\",\"type\":\"disk\",\"rm\":true,\"tran\":\"usb\",\"label\":null,\"size\":\"28.9G\",\"fstype\":\"vfat\",\"mountpoints\":[null],\"vendor\":\"Kingston\",\"model\":\"DT\"},{\"name\":\"/dev/loop0\",\"type\":\"loop\",\"rm\":false,\"tran\":null,\"label\":\"IMG\",\"size\":\"2G\",\"fstype\":\"iso9660\",\"mountpoints\":[null],\"vendor\":null,\"model\":null}]}"'
stub losetup 'echo "{\"loopdevices\":[]}"'
stub ddcutil 'exec bash "'"$REPO"'/tests/status/fake_ddcutil" "$@"'
export DDC=$TMP/ddc DDC_BUSES=5 DDC_DELAY=0.1 KAWA_SYSFS=$TMP/sys WAYLAND_DISPLAY=wayland-clicks
mkdir -p "$DDC" "$TMP/sys/class/backlight"
kawa-brightness --level >/dev/null 2>&1        # (a session under way: the monitor found)

# (module, event, command), as waybar's config has them
python3 -B -c 'import json, sys; sys.path.insert(0, sys.argv[1]); import parsecheck as p
c = json.loads(p.strip_jsonc(open(sys.argv[2]).read()))
for m, v in c.items():
    if isinstance(v, dict):
        for k in ("on-click", "on-click-right", "on-click-middle", "on-scroll-up", "on-scroll-down"):
            if k in v: print(f"{m}\t{k}\t{v[k]}")' "$REPO/tests/static" "$REPO/configs/home/.config/waybar/config.jsonc" >"$TMP/clicks"

case_ "the bar has its clicks (the list is read, not empty)"
(( $(wc -l <"$TMP/clicks") >= 30 )) && _ok || _no "only $(wc -l <"$TMP/clicks") clicks found in config.jsonc"
# dwl's fifo (the keyboard tile's click, kawa-tag kb next): a line read from it is what happens
mkfifo "$XDG_RUNTIME_DIR/dwl-warm"
( exec 3<>"$XDG_RUNTIME_DIR/dwl-warm"; while IFS= read -r l <&3; do echo "dwl-${l// /-} $(date +%s%N)" >>"$TMP/acts"; done ) & BG_PIDS+=($!)
case_ "each click and scroll: something happens within 900 ms, with every slow service a second behind"
while IFS=$'\t' read -r mod ev cmd; do
  : >"$TMP/acts"; rm -f "$XDG_RUNTIME_DIR"/kawa-menu-* "$XDG_RUNTIME_DIR"/kawa-term-* 2>/dev/null
  t0=$(date +%s%N)
  timeout 8 sh -c "$cmd" >/dev/null 2>&1 </dev/null
  # (what it started apart from the bar — setsid -f, as every opener — stamps when it comes:
  # looked for until 900 ms after the click)
  what="" at=""
  while [[ -z $what ]] && (( ($(date +%s%N) - t0) / 1000000 < 1500 )); do
    read -r what at <"$TMP/acts" 2>/dev/null || { what="" at=""; sleep 0.02; }
  done
  if [[ -z $what ]]; then _no "$mod $ev ($cmd): nothing happened at all"; continue; fi
  ms=$(( (at - t0) / 1000000 ))
  ((ms <= 900)) && _ok || _no "$mod $ev ($cmd): $what only after $ms ms"
done <"$TMP/clicks"
done_
