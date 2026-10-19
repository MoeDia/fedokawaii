#!/usr/bin/env bash
# tests/installer/test_report_rows.sh — rows of fedokawaii-report's tables, each run on its own
# against what the owner's machine showed on 19 Oct (its journal lines, its processes, its
# firewall, its sockets…), with stand-ins for the programs they ask: what is normal there
# passes — a mode set's REG_WAIT, glycin's loader under the bar, a USB controller set up again
# after a sleep, the report's own shell — and what is wrong still fails. The rows' own command
# lines, read from system/fedokawaii-report as its checks() reads them; no fake machine.
FK_PURE=1
. "$(dirname "$0")/../lib/harness.sh"
sandbox
RPT=$REPO/system/fedokawaii-report
# row NAME — the row's COMMAND (the fields as checks() splits them)
row() {
  local line rest
  line=$(awk -v n="$1 | " 'index($0, n) == 1 { print; exit }' "$RPT")
  [[ -n $line ]] || { echo "false # no row $1"; return; }
  rest=${line#* | }; rest=${rest#* | }; rest=${rest#* | }; rest=${rest#* | }
  rest=${rest% | *}; printf '%s' "${rest% | *}"
}
# run NAME — the row run as the report runs it (its variables), its output in OUT, status in RC
mkdir -p "$TMP/tk" "$TMP/state"; cp "$REPO/fedokawaii.conf" "$TMP/tk/"
run() {
  OUT=$(TK=$TMP/tk STATE=$TMP/state U=$USER UH=$HOME UIDN=$UID DWL=${DWL:-} WB=${WB:-} QUICK=0 RT=$XDG_RUNTIME_DIR \
        timeout 20 bash -c "$(row "$1")" 2>&1 </dev/null); RC=$?
}
J=$TMP/journal; : >"$J"
stub journalctl "cat '$J'"

case_ "GPU-05: a mode set's REG_WAIT and the VM notes at a logout are amdgpu's routine; a ring timeout is not"
printf '%s\n' 'Oct 19 14:09:28 fedora kernel: amdgpu 0000:03:00.0: [drm] REG_WAIT timeout 1us * 150000 tries - optc401_disable_crtc line:235' \
  'Oct 19 14:12:11 fedokawaii kernel: amdgpu 0000:03:00.0: VM memory stats for proc dwl(1363) task dwl:cs0(1362) is non-zero when fini' >"$J"
run "GPU-05 the kernel on the card"; eq "$RC" 0 "$OUT"
echo 'Oct 19 15:00:00 fedokawaii kernel: amdgpu 0000:03:00.0: [drm:amdgpu_job_timedout] *ERROR* ring gfx_0.0.0 timeout' >>"$J"
run "GPU-05 the kernel on the card"; eq "$RC" 1

case_ "SLP-08: a USB controller set up again at a resume (Reinit) is no failure; a device that failed is"
printf '%s\n' 'Oct 19 14:11:10 fedokawaii kernel: PM: suspend entry (deep)' \
  'Oct 19 14:11:25 fedokawaii kernel: xhci_hcd 0000:13:00.0: xHC error in resume, USBSTS 0x401, Reinit' \
  'Oct 19 14:11:25 fedokawaii kernel: PM: suspend exit' >"$J"
run "SLP-08 resume errors and wake sources"; eq "$RC" 0 "$OUT"
echo 'Oct 19 14:11:25 fedokawaii kernel: PM: Some devices failed to suspend, or early wake event detected' >>"$J"
run "SLP-08 resume errors and wake sources"; eq "$RC" 1

case_ "BOOT-23, SYS-13: the watchdog chip's notice and systemd's skipped sysfail unit are no hang, no missing firmware"
printf '%s\n' 'Oct 19 14:09:10 fedokawaii kernel: watchdog: watchdog0: watchdog did not stop!' \
  'Oct 19 14:09:31 fedokawaii systemd[1]: systemd-boot-clear-sysfail.service - Clear SysFail Entry If The Boot Is Successful skipped, unmet condition check ConditionPathExists=/sys/firmware/efi/efivars/LoaderEntrySysFail-4a67b082' >"$J"
run "BOOT-23 shutdown was quick"; eq "$RC" 0 "$OUT"
run "SYS-13 firmware the kernel could not load"; eq "$RC" 0 "$OUT"
echo 'Oct 19 14:09:30 fedokawaii kernel: amdgpu 0000:03:00.0: Direct firmware load for amdgpu/x.bin failed with error -2' >>"$J"
run "SYS-13 firmware the kernel could not load"; eq "$RC" 1

case_ "RES-03: GTK's image loader (glycin, in bwrap) under the bar is no stray child"
WB=4242
stub ps "cat <<'EOF'
   5336      14 S    bash $HOME/.local/bin/kawa-nowplaying
   5350      14 S    bash $HOME/.local/bin/kawa-mem
   5403      14 S    bwrap --unshare-all --die-with-parent --seccomp 35 /usr/libexec/glycin-loaders/2+/glycin-image-rs --dbus-fd 32
EOF"
run "RES-03 waybar's children"; eq "$RC" 0 "$OUT"
stub ps "echo '   6000      60 S    sleep 1000'"
run "RES-03 waybar's children"; eq "$RC" 1

case_ "BRV-02: Steam's own GPU process (--disable-gpu) is not Brave's"
stub ps "cat <<'EOF'
/home/u/.local/share/Steam/ubuntu12_64/steamwebhelper --type=gpu-process --disable-gpu --use-gl=disabled
/opt/brave.com/brave-origin/brave --type=gpu-process --ozone-platform=wayland --use-angle=vulkan
EOF"
run "BRV-02 Brave draws with the GPU"; eq "$RC" 0 "$OUT"

case_ "NET-07: the ports as firewalld lists them (the first one too); NET-09: LLMNR and mDNS are no strangers"
stub firewall-cmd 'case "$*" in --state) echo running ;; --get-default-zone) echo public ;; *--list-ports*) echo "6881/tcp 6881/udp 53317/tcp 53317/udp" ;; *--list-services*) echo "dhcpv6-client mdns" ;; esac'
run "NET-07 the firewall"; eq "$RC" 0 "$OUT"
stub firewall-cmd 'case "$*" in --state) echo running ;; --get-default-zone) echo public ;; *--list-ports*) echo "6881/udp 53317/tcp 53317/udp" ;; *--list-services*) echo "ssh mdns" ;; esac'
run "NET-07 the firewall"; eq "$RC" 1; has "$OUT" "closed: 6881/tcp"; has "$OUT" "ssh or cockpit open"
stub ss "cat <<'EOF'
tcp LISTEN 0 4096 0.0.0.0:5355 0.0.0.0:* users:((\"systemd-resolve\",pid=666,fd=13))
tcp LISTEN 0 4096 127.0.0.53%lo:53 0.0.0.0:* users:((\"systemd-resolve\",pid=666,fd=19))
udp UNCONN 0 0 0.0.0.0:5353 0.0.0.0:* users:((\"avahi-daemon\",pid=880,fd=12))
udp UNCONN 0 0 [::]:5355 [::]:* users:((\"systemd-resolve\",pid=666,fd=14))
EOF"
run "NET-09 what listens"; eq "$RC" 0 "$OUT"

case_ "SLP-10: the check's own shell (its command line names the keeper) is no keeper"
run "SLP-10 the lock's keeper"; eq "$RC" 0 "$OUT"; has "$OUT" "keepers 0"

case_ "UI-07: one level display (its several lines in makoctl's list) is one"
stub wpctl 'echo "Volume: 0.30"'; stub kawa-volume
stub makoctl "cat <<'EOF'
Notification 41: 音  sound
  App name: osd
  Category: osd
  Urgency: low
EOF"
run "UI-07 a held volume key updates in place"; eq "$RC" 0 "$OUT"

case_ "UI-08: a set that writes to the monitor itself (one DDC/CI write, ~0.4 s) is in time; the level is read at once"
stub kawa-brightness '[ "$1" = --level ] && { echo 85; exit 0; }; sleep 0.4'
run "UI-08 brightness: never slow"; eq "$RC" 0 "$OUT"

case_ "DWL-05: none of dwl's status lines in its log — the owner's (16, before the bar's pipe) fail"
mkdir -p "$HOME/.cache"; printf '%s\n' "start-dwl: 2 graphics cards: drawing on card1" "vrr: HDMI-A-1 off" >"$HOME/.cache/dwl.log"
run "DWL-05 status lines stay out of dwl.log"; eq "$RC" 0 "$OUT"
for i in 1 2; do printf 'HDMI-A-1 %s\n' "title " "appid " "fullscreen " "floating " "selmon $((i - 1))" "tags 0 1 0 0" "layout (@)" "kblayout 0"; done >>"$HOME/.cache/dwl.log"
run "DWL-05 status lines stay out of dwl.log"; eq "$RC" 1; has "$OUT" "16 status lines"

case_ "FONT-04b: fuzzel shapes through fcft (HarfBuzz and utf8proc) — its version line never names it"
stub fuzzel 'echo "fuzzel version: 1.14.0 +cairo +png +svg(nanosvg) -assertions"'
stub ldd 'case $1 in *fcft*) printf "\tlibharfbuzz.so.0 => /lib64/libharfbuzz.so.0 (0x1)\n\tlibutf8proc.so.3 => /lib64/libutf8proc.so.3 (0x2)\n" ;;
  *) printf "\tlibfcft.so.4 => /lib64/libfcft.so.4 (0x3)\n" ;; esac'
run "FONT-04b Arabic shapes in the menus (fuzzel)"; eq "$RC" 0 "$OUT"
stub ldd 'case $1 in *fcft*) printf "\tlibpixman-1.so.0 => /lib64/libpixman-1.so.0 (0x1)\n" ;; *) printf "\tlibfcft.so.4 => /lib64/libfcft.so.4 (0x3)\n" ;; esac'
run "FONT-04b Arabic shapes in the menus (fuzzel)"; eq "$RC" 1
rm -f "$STUBS/ldd"

case_ "UNIT-09: the first-start report not run yet, but enabled for the next start, is no warning; neither run nor enabled is"
stub systemctl '[ "$1" = is-enabled ] && exit 0; echo Result=success'
run "UNIT-09 the report ran once"; eq "$RC" 0 "$OUT"; has "$OUT" "it runs at the next start"
stub systemctl '[ "$1" = is-enabled ] && exit 1; echo Result=success'
run "UNIT-09 the report ran once"; eq "$RC" 1

case_ "SHARE-10: a portal at rest (inactive, success, never restarted) is fine — it starts on demand"
stub systemctl 'case "$*" in *ActiveState*) echo inactive ;; *Result*) echo success ;; *NRestarts*) echo 0 ;; esac'
run "SHARE-10 the portal services do not crash"; eq "$RC" 0 "$OUT"

case_ "SEC-04: ble.sh's sticky shared folders are not world-writable files"
mkdir -p "$HOME/.local/share/blesh/run" "$HOME/.local/share/blesh/cache.d"; chmod 1777 "$HOME/.local/share/blesh/run" "$HOME/.local/share/blesh/cache.d"
run "SEC-04 world-writable files in your home"; eq "$RC" 0 "$OUT"
touch "$HOME/open"; chmod 666 "$HOME/open"
run "SEC-04 world-writable files in your home"; eq "$RC" 1; rm -f "$HOME/open"

case_ "FETCH-01: the shell asked on a terminal of its own (python's pty: no util-linux-script on a Server install) — never stopped, never without a terminal"
mkdir -p "$HOME/.local/share/blesh"
printf '[[ -t 0 && -t 1 ]] && BLE_VERSION=0.4.0\n' >"$HOME/.bashrc"
run "FETCH-01 the prompt (ble.sh)"; eq "$RC" 0 "$OUT"; has "$OUT" "BLE=0.4.0"
lacks "$(row "FETCH-01 the prompt (ble.sh)")" "script -" "util-linux-script is no package of the desktop's"
printf 'echo "ble.sh: syntax error near x"\nBLE_VERSION=0.4.0\n' >"$HOME/.bashrc"
run "FETCH-01 the prompt (ble.sh)"; eq "$RC" 1
rm -f "$HOME/.bashrc"

case_ "the bar as the toolkit writes it: BAR-10 (one click per item), BAR-11 (no hover box, no bottom line), NOTE-07 (every mako section names a sender)"
rm -f "$STUBS/systemctl"
config .config/waybar .config/mako
mkdir -p "$HOME/.local/bin"; cp "$REPO"/bin/kawa-* "$HOME/.local/bin/"
run "BAR-10 the clock group"; eq "$RC" 0 "$OUT"
run "BAR-11 no hover boxes, no bottom line"; eq "$RC" 0 "$OUT"
run "NOTE-07 the notices' sections match their senders"; eq "$RC" 0 "$OUT"; has "$OUT" "sections for no sender: none · categories with no section: none"
printf '[app-name=drive]\ndefault-timeout=1\n' >>"$HOME/.config/mako/config"   # (a sender's name misspelt)
run "NOTE-07 the notices' sections match their senders"; eq "$RC" 1; has "$OUT" "sections for no sender: drive "

done_
