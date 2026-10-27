#!/usr/bin/env bash
# tests/installer/test_report_rows.sh — rows of fedokawaii-report's tables, each run on its own
# against what the owner's machine showed on 19 Oct (its journal lines, its processes, its
# firewall, its sockets…), with stand-ins for the programs they ask: what is normal there
# passes — a mode set's REG_WAIT, glycin's loader under the bar, a USB controller set up again
# after a sleep, the report's own shell — and what is wrong still fails. The rows' own command
# lines, read from system/fedokawaii-report as its checks() reads them; no fake machine.
# shellcheck disable=SC2034  # (the harness reads it: this file needs no fake machine)
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

case_ "NET-07: the ports as firewalld lists them (the first one too); NET-09: mDNS and Steam's Remote Play are no strangers, LLMNR is (it is off)"
stub firewall-cmd 'case "$*" in --state) echo running ;; --get-default-zone) echo public ;; *--list-ports*) echo "6881/tcp 6881/udp 53317/tcp 53317/udp" ;; *--list-services*) echo "dhcpv6-client mdns ssh" ;; esac'
run "NET-07 the firewall"; eq "$RC" 0 "$OUT"
stub firewall-cmd 'case "$*" in --state) echo running ;; --get-default-zone) echo public ;; *--list-ports*) echo "6881/udp 53317/tcp 53317/udp" ;; *--list-services*) echo "ssh mdns cockpit" ;; esac'
run "NET-07 the firewall"; eq "$RC" 1; has "$OUT" "closed: 6881/tcp"; has "$OUT" "cockpit open"
stub ss "cat <<'EOF'
tcp LISTEN 0 4096 0.0.0.0:5355 0.0.0.0:* users:((\"systemd-resolve\",pid=666,fd=13))
tcp LISTEN 0 4096 127.0.0.53%lo:53 0.0.0.0:* users:((\"systemd-resolve\",pid=666,fd=19))
udp UNCONN 0 0 0.0.0.0:5353 0.0.0.0:* users:((\"avahi-daemon\",pid=880,fd=12))
udp UNCONN 0 0 [::]:5355 [::]:* users:((\"systemd-resolve\",pid=666,fd=14))
EOF"
run "NET-09 what listens"; eq "$RC" 1 "LLMNR is off on this desktop: 5355 on every address is a finding"
stub ss "cat <<'EOF'
tcp LISTEN 0 4096 127.0.0.53%lo:53 0.0.0.0:* users:((\"systemd-resolve\",pid=666,fd=19))
tcp LISTEN 0 128 0.0.0.0:27036 0.0.0.0:* users:((\"steam\",pid=2370,fd=134))
udp UNCONN 0 0 *:27036 *:* users:((\"steam\",pid=2370,fd=132))
udp UNCONN 0 0 0.0.0.0:5353 0.0.0.0:* users:((\"avahi-daemon\",pid=880,fd=12))
EOF"
run "NET-09 what listens"; eq "$RC" 0 "$OUT"
stub ss "echo 'tcp LISTEN 0 128 0.0.0.0:27036 0.0.0.0:* users:((\"nc\",pid=9,fd=3))'"
run "NET-09 what listens"; eq "$RC" 1 "27036 is Steam's alone"
run "NET-20 no LLMNR"; eq "$RC" 0 "$OUT"
stub ss "echo 'udp UNCONN 0 0 0.0.0.0:5355 0.0.0.0:* users:((\"systemd-resolve\",pid=666,fd=12))'"
run "NET-20 no LLMNR"; eq "$RC" 1
case_ "NET-21: Steam's 27036 opened in the firewall is a finding"
stub firewall-cmd 'case "$*" in --state|-q\ --state) exit 0 ;; --get-default-zone) echo public ;; *--list-ports*) echo "6881/tcp 27036/udp" ;; *--list-services*) echo "mdns" ;; esac'
run "NET-21 Steam's 27036 stays closed"; eq "$RC" 1 "$OUT"
stub firewall-cmd 'case "$*" in --state|-q\ --state) exit 0 ;; --get-default-zone) echo public ;; *--list-ports*) echo "6881/tcp" ;; *--list-services*) echo "mdns" ;; esac'
run "NET-21 Steam's 27036 stays closed"; eq "$RC" 0 "$OUT"

case_ "RES-03: the volume module follows PipeWire (long-running, as nowplaying, mem and timer)"
WB=4242
stub ps "cat <<'EOF'
   1855     407 S    bash $HOME/.local/bin/kawa-volume bar
   1874     407 S    bash $HOME/.local/bin/kawa-timer bar
EOF"
run "RES-03 waybar's children"; eq "$RC" 0 "$OUT"
unstub ps 2>/dev/null || rm -f "$STUBS/ps"; WB=""

case_ "SYNC-01: the patch checked with git apply (the tool that applied it; no patch program on the desktop)"
lacks "$(row "SYNC-01 Syncplay runs, patched")" "patch -R" "patch is no package of the desktop's"
mkdir -p "$TMP/tk/src/syncplay" "$HOME/.local/share/fedokawaii/syncplay/syncplay" "$HOME/.local/bin"
printf 'a = 1\n' >"$HOME/.local/share/fedokawaii/syncplay/syncplay/x.py"
printf -- '--- a/syncplay/x.py\n+++ b/syncplay/x.py\n@@ -1 +1 @@\n-a = 0\n+a = 1\n' >"$TMP/tk/src/syncplay/syncplay.patch"
printf '#!/bin/sh\necho "Syncplay 1.7.6"\n' >"$HOME/.local/bin/syncplay"; chmod 755 "$HOME/.local/bin/syncplay"
run "SYNC-01 Syncplay runs, patched"; eq "$RC" 0 "$OUT"; has "$OUT" "applied: syncplay.patch"
printf 'a = 0\n' >"$HOME/.local/share/fedokawaii/syncplay/syncplay/x.py"
run "SYNC-01 Syncplay runs, patched"; eq "$RC" 1; has "$OUT" "NOT applied"
lacks "$(row "SYNC-03 the Syncplay server answers" | head -c0)$(awk -F' [|] ' '$1 == "SYNC-03 the Syncplay server answers" { print $3 }' "$RPT")" warn "someone else's server: no verdict"

case_ "WALL-01: the pack counted where it lives (wallpapers/THEME/*.src); WALL-02: the drawn cache, an empty one passing"
for t in dark light; do mkdir -p "$HOME/.local/share/fedokawaii/wallpapers/$t"; for i in $(seq 30); do : >"$HOME/.local/share/fedokawaii/wallpapers/$t/p$i.src"; done; done
run "WALL-01 the wallpapers"; eq "$RC" 0 "$OUT"; has "$OUT" "60 pictures"
rm -f "$HOME"/.local/share/fedokawaii/wallpapers/light/*; run "WALL-01 the wallpapers"; eq "$RC" 1 "30 of the pack is too few"
run "WALL-02 the scaled cache"; eq "$RC" 0 "$OUT"
mkdir -p "$HOME/.cache/fedokawaii/wallpaper-screens"; head -c 2000000 /dev/zero >"$HOME/.cache/fedokawaii/wallpaper-screens/a.png"
run "WALL-02 the scaled cache"; eq "$RC" 0 "$OUT"
case_ "WALL-03: each theme's last picture still there"
mkdir -p "$HOME/.local/state/fedokawaii"; echo "pack:p1" >"$HOME/.local/state/fedokawaii/wallpaper-dark"
run "WALL-03 the wallpaper of each theme exists"; eq "$RC" 0 "$OUT"
echo "pack:gone" >"$HOME/.local/state/fedokawaii/wallpaper-light"; run "WALL-03 the wallpaper of each theme exists"; eq "$RC" 1
case_ "WALL-04: the list's pictures counted, not its comments (the whole pack fetched passes)"
{ echo "# the pack"; echo "# ── dark"; for i in $(seq 30); do echo "dark  p$i  -  center  0  https://x/p$i.jpg  T (CC0)"; done; } >"$HOME/.local/share/fedokawaii/wallpapers.list"
grep -q '^WALLPAPER_PACK=' "$TMP/tk/fedokawaii.conf" 2>/dev/null || echo 'WALLPAPER_PACK=yes' >>"$TMP/tk/fedokawaii.conf"
run "WALL-04 the pack against its list"; eq "$RC" 0 "$OUT"; has "$OUT" "30 of 30 listed"

case_ "UPK-03: the records with a word after the date (last-update: \"EPOCH ok\") read as dates"
printf '1792454291 checks\n' >"$TMP/state/last-update"; printf '1792454291\n' >"$TMP/state/last-update-done"
run "UPK-03 the toolkit and the install"; lacks "$OUT" "invalid date"; has "$OUT" "last-update: 2026-"; has "$OUT" " checks"

case_ "UPK-05, SEC-10: a token written into the clone's address is a finding (and never printed)"
mkdir -p "$HOME/repos"; git init -q "$HOME/repos/fedokawaii"
git -C "$HOME/repos/fedokawaii" remote add origin "https://ghp_secretvalue123456789@github.com/MoeDia/fedokawaii.git"
run "UPK-05 the clone (~/repos/fedokawaii)"; lacks "$OUT" "ghp_secret"
run "SEC-10 no token in a git address"; eq "$RC" 1
git -C "$HOME/repos/fedokawaii" remote set-url origin https://github.com/MoeDia/fedokawaii.git
run "UPK-05 the clone (~/repos/fedokawaii)"; eq "$RC" 0 "$OUT"; run "SEC-10 no token in a git address"; eq "$RC" 0 "$OUT"
case_ "UPK-09: the last pull's record"
printf '%s ok abc1234\n' "$(date +%s)" >"$HOME/.local/state/fedokawaii/last-pull"; run "UPK-09 the last pull"; eq "$RC" 0 "$OUT"
printf '%s failed abc1234\n' "$(date +%s)" >"$HOME/.local/state/fedokawaii/last-pull"; run "UPK-09 the last pull"; eq "$RC" 1

case_ "NIGHT-01/02: the night light's record, and gammastep running exactly when it says on"
mkdir -p "$TMP/nb"; printf '#!/bin/sh\nexit 0\n' >"$TMP/nb/kawa-night"; chmod 755 "$TMP/nb/kawa-night"; PATH=$TMP/nb:$PATH
echo "on 3500" >"$HOME/.local/state/fedokawaii/night"; run "NIGHT-01 the night light remembered"; eq "$RC" 0 "$OUT"
echo "on 3600" >"$HOME/.local/state/fedokawaii/night"; run "NIGHT-01 the night light remembered"; eq "$RC" 1 "a warmth off the steps"
echo "on 3500" >"$HOME/.local/state/fedokawaii/night"; stub pgrep 'exit 1'
run "NIGHT-02 the night light as you left it"; eq "$RC" 1 "on, no gammastep"
echo "off 3500" >"$HOME/.local/state/fedokawaii/night"; run "NIGHT-02 the night light as you left it"; eq "$RC" 0 "$OUT"
rm -f "$STUBS/pgrep"

case_ "SYS-16: a server's extras enabled are findings"
mkdir -p "$TMP/tk/lib"; cp "$REPO/lib/hygiene.sh" "$TMP/tk/lib/"
stub systemctl 'case "$*" in "is-enabled ModemManager.service") echo enabled ;; *) echo disabled ;; esac'
run "SYS-16 services a desktop does not need"; eq "$RC" 1; has "$OUT" ModemManager.service
stub systemctl 'echo disabled'; run "SYS-16 services a desktop does not need"; eq "$RC" 0 "$OUT"
rm -f "$STUBS/systemctl"

case_ "THEME-21: both themes hold the same files"
for t in dark light; do mkdir -p "$HOME/.config/fedokawaii/themes/$t"; : >"$HOME/.config/fedokawaii/themes/$t/colors.sh"; done
run "THEME-21 both themes have the same files"; eq "$RC" 0 "$OUT"
: >"$HOME/.config/fedokawaii/themes/dark/only-dark.conf"; run "THEME-21 both themes have the same files"; eq "$RC" 1 "$OUT"

case_ "BAK-06: the exclude list leaves out the cache, Downloads and Steam"
mkdir -p "$HOME/.config/fedokawaii"; printf '%s\n' "$HOME/.cache" "$HOME/Downloads" "$HOME/.local/share/Steam" >"$HOME/.config/fedokawaii/backup-exclude"
run "BAK-06 the backup leaves out what comes again"; eq "$RC" 0 "$OUT"
printf '%s\n' "$HOME/.cache" >"$HOME/.config/fedokawaii/backup-exclude"; run "BAK-06 the backup leaves out what comes again"; eq "$RC" 1

case_ "PERF-02, PERF-08: the sample PERF-01 leaves — the desktop's wake-ups and the bar's CPU judged, apps listed only"
WB=4242; printf '%s\n' "4242	0.30	4.0	60000	waybar" "5350	0.01	0.3	3500	bash /home/u/.local/bin/kawa-mem" \
  "5351	0.02	1.0	3500	bash /home/u/.local/bin/kawa-timer bar" "7000	9.00	900.0	900000	/opt/brave.com/brave-origin/brave --type=renderer" >"/tmp/fk-perf-sample.$UID"
run "PERF-02 the desktop's wake-ups"; eq "$RC" 0 "$OUT"; has "$OUT" "app    /opt/brave.com"
run "PERF-08 the bar at rest"; eq "$RC" 0 "$OUT"; has "$OUT" "0.33 % in all"
printf '%s\n' "4242	2.50	40.0	60000	waybar" >"/tmp/fk-perf-sample.$UID"
run "PERF-02 the desktop's wake-ups"; eq "$RC" 1 "40 a second is too many"; has "$OUT" "TOO MANY"
run "PERF-08 the bar at rest"; eq "$RC" 1 "2.5 % of a core"
rm -f "/tmp/fk-perf-sample.$UID"; run "PERF-02 the desktop's wake-ups"; eq "$RC" 1 "no sample: a finding, never a pass"; WB=""
case_ "PERF-03: each helper under its limit; an app is listed, never judged"
stub ps "printf '%s\n' ' 90000 waybar' ' 3000 bash /h/.local/bin/kawa-mem' ' 2500000 /opt/brave.com/brave-origin/brave'"
run "PERF-03 every session process's memory (RSS)"; eq "$RC" 0 "$OUT"; has "$OUT" "app"
stub ps "printf '%s\n' ' 300000 waybar'"; run "PERF-03 every session process's memory (RSS)"; eq "$RC" 1; has "$OUT" "OVER"
rm -f "$STUBS/ps"
case_ "PERF-07: a module polling under 10 s fails (one every 3 s), signals and long intervals pass"
mkdir -p "$HOME/.config/waybar"
printf '%s\n' '{ "custom/date": { "exec": "x", "interval": 60 }, "custom/mem": { "exec": "kawa-mem", "restart-interval": 5 },' '  // a comment' '  "custom/tag1": { "exec": "y", "signal": 8 }, }' >"$HOME/.config/waybar/config.jsonc"
run "PERF-07 the bar's polling"; eq "$RC" 0 "$OUT"; has "$OUT" "60 timed runs an hour"
printf '%s\n' '{ "custom/poll": { "exec": "kawa-poll", "interval": 3 } }' >"$HOME/.config/waybar/config.jsonc"
run "PERF-07 the bar's polling"; eq "$RC" 1; has "$OUT" "make it a signal"
case_ "fedokawaii-latency (PERF-09): repeated, judged on p95 and the spread, worst first; nothing it lacks is guessed"
L=$REPO/system/fedokawaii-latency
out=$(env -u WAYLAND_DISPLAY python3 -I "$L" 2>&1); eq "$?" 2 "no session: nothing timed"; has "$out" "no desktop session"
mkdir -p "$TMP/lh/.cache/fedokawaii"
for v in 400 420 410 430 405 415; do echo "kawa-theme: switched to dark in $v ms"; done >"$TMP/lh/.cache/kawa-theme.log"
for v in 100 900 120 950 110 100; do echo "2026-10-20 05:00:00 kawa-wallpaper: set pack:a on screen in $v ms"; done >"$TMP/lh/.cache/fedokawaii/wallpaper.log"
out=$(HOME=$TMP/lh WAYLAND_DISPLAY=wayland-9 XDG_RUNTIME_DIR=$TMP/lh PATH=/usr/bin:/bin python3 -I "$L" 2>&1); rc=$?
eq "$rc" 1 "a wallpaper change uneven and slow at p95: a FAIL"
eq "$(grep -m1 -E '^  (FAIL|ok)' <<<"$out" | awk '{ print $1 }')" FAIL "the worst first"
has "$out" "a wallpaper on screen (the last 6, as logged)"; has "$out" "spread"
grep -qE '^  ok +the theme switch \(the last 6, as logged\) +p50 +412' <<<"$out" && _ok || _no "the theme switch line: $(grep 'theme switch' <<<"$out")"
has "$out" "not measured — needs dwl's frame callbacks"; has "$out" "fedokawaii report --perf"
lacks "$(row "PERF-09 every interaction, again and again (p95, spread)")" "--full --full"
has "$(row "PERF-09 every interaction, again and again (p95, spread)")" '[ "$PERFM" = 1 ] && m=--full'

case_ "PERF-05: the bar's process tree counted"
WB=$$; run "PERF-05 the bar's processes"; eq "$RC" 0 "$OUT"; has "$OUT" "processes under waybar"; WB=""

case_ "the last rows of the round: XDG-02, STATE-05, HUSH-01/02, FONT-16, GAME-21, UPK-22, BOOT-46"
for d in bash less python node sqlite; do mkdir -p "$HOME/.local/state/$d"; done
run "XDG-02 the history folders are there, yours"; eq "$RC" 0 "$OUT"; rmdir "$HOME/.local/state/node"
run "XDG-02 the history folders are there, yours"; eq "$RC" 1
mkdir -p "$TMP/sb"; printf '#!/bin/sh\n[ "$1" = list ] && cat "$TMP/state-list"\n' >"$TMP/sb/kawa-state"; chmod 755 "$TMP/sb/kawa-state"
printf 'dnd=on\nbrightness=40\ncleanmic=off\nvrr=x\n' >"$TMP/state-list"
PATH=$TMP/sb:$PATH run "STATE-05 every kept setting valid"; eq "$RC" 0 "$OUT"; has "$OUT" "(a helper's own)"
printf 'brightness=140\n' >"$TMP/state-list"; PATH=$TMP/sb:$PATH run "STATE-05 every kept setting valid"; eq "$RC" 1
mkdir -p "$HOME/.config/xdg-desktop-portal-wlr" "$HOME/.config/mako"
printf '[screencast]\nexec_before=/h/kawa-hush on sharing; x\nexec_after=/h/kawa-hush off sharing; x\n' >"$HOME/.config/xdg-desktop-portal-wlr/config"
printf '#!/bin/sh\n' >"$TMP/sb/kawa-hush"; chmod 755 "$TMP/sb/kawa-hush"
PATH=$TMP/sb:$PATH run "HUSH-01 notices held while a screen is shared"; eq "$RC" 0 "$OUT"
sed -i '/exec_after/d' "$HOME/.config/xdg-desktop-portal-wlr/config"; PATH=$TMP/sb:$PATH run "HUSH-01 notices held while a screen is shared"; eq "$RC" 1
printf '[mode=do-not-disturb]\n[mode=sharing]\n[mode=game]\n' >"$HOME/.config/mako/config"; run "HUSH-02 mako's hush modes"; eq "$RC" 0 "$OUT"
printf '[mode=do-not-disturb]\n' >"$HOME/.config/mako/config"; run "HUSH-02 mako's hush modes"; eq "$RC" 1
mkdir -p "$TMP/tk/lib" "$TMP/tk/system"; cp "$REPO/lib/upstream.sh" "$TMP/tk/lib/"; cp "$REPO/system/fedokawaii-latency" "$TMP/tk/system/"
mkdir -p "$HOME/.local/share/fedokawaii/upstream"
# (the terminal's face: four stand-ins in a folder of their own, the toolkit's copy pinned to them)
F=$TMP/faces; mkdir -p "$F"; sed -i "s|^FACES_DIR=.*|FACES_DIR=$F|" "$TMP/tk/lib/upstream.sh"
while IFS='|' read -r f sum; do printf 'face %s\n' "$f" >"$F/$f"; sed -i "s/$sum/$(sha256sum "$F/$f" | cut -d' ' -f1)/" "$TMP/tk/lib/upstream.sh"
done < <(. "$REPO/lib/upstream.sh"; printf '%s\n' "${TERM_FACE_FILES[@]}")
run "FONT-17 the terminal's face at its pin"; eq "$RC" 0 "$OUT"
printf x >>"$F/UDEVGothicNF-Bold.ttf"; run "FONT-17 the terminal's face at its pin"; eq "$RC" 1 "a file changed"
printf 'face %s\n' UDEVGothicNF-Bold.ttf >"$F/UDEVGothicNF-Bold.ttf"; mkdir -p "$HOME/.local/share/fonts/JetBrainsMonoNerd"
run "FONT-17 the terminal's face at its pin"; eq "$RC" 1 "the Nerd Font before it still there"; rm -rf "$HOME/.local/share/fonts/JetBrainsMonoNerd"
d=$HOME/.local/share/Steam/compatibilitytools.d; mkdir -p "$d/GE-Proton11-11" "$d/GE-Proton11-10"; echo GE-Proton11-11 >"$HOME/.local/share/fedokawaii/upstream/ge-proton"
run "GAME-21 GE-Proton: the recorded one there, two kept at most"; eq "$RC" 0 "$OUT"; mkdir -p "$d/GE-Proton11-9"
run "GAME-21 GE-Proton: the recorded one there, two kept at most"; eq "$RC" 1 "three kept"
run "UPK-22 the timing harness is the toolkit's and runs"; eq "$RC" 0 "$OUT"

case_ "every row the report adds this round parses as checks() splits it (mode, level, seven fields)"
for n in $(grep -oE '^(UPK-(09|1[0-9]|20)|BOOT-3[1-5]|LOGIN-1[678]|DWL-(18|19)|KEY-1[12]|THEME-(19|20|21)|GPU-(09|1[01])|RES-1[2368]|SYS-1[4-9]|PERF-0[1-9]|NET-2[0-5]|AUD-15|SLP-1[2-6]|UI-1[45]|BAR-2[2-7]|CLIP-12|FONT-15|MIME-0[89]|PKG-1[56]|UNIT-11|DISK-1[67]|SEC-1[012]|X11-04|NIGHT-0[123]|WALL-0[34]|SPOT-08|BAK-06|LOGIN-19|SLP-2[01]|XDG-0[1-3]|UPK-2[12]|BOOT-46|AUD-2[01]|GAME-(19|2[01])|FONT-1[67]|GIT-01|CALC-01|HUSH-0[1-3]|DL-03|STATE-05|REC-04|OCR-02|BAR-28|PANEL-01|FETCH-03|UI-16|THEME-22|UPK-20|APP-09|REC-01|DISK-18|DEV-01|NVIM-02|PKG-1[78]|MON-08) ' "$RPT" | sort -u); do
  l=$(grep -E "^$n " "$RPT"); f=${l#* | }; m=${f%% | *}; f=${f#* | }; v=${f%% | *}
  [[ $m =~ ^(user|ses|root)(\+full)?(\+solo)?(/[0-9]+)?$ && $v =~ ^(fail|warn|info)$ ]] && _ok || _no "$n: mode [$m] level [$v]"
done
eq "$(grep -cE '^(UPK-(09|1[0-9]|20)|BOOT-3[1-5]|LOGIN-1[678]|DWL-(18|19)|KEY-1[12]|THEME-(19|20|21)|GPU-(09|1[01])|RES-1[2368]|SYS-1[4-9]|PERF-0[1-9]|NET-2[0-5]|AUD-15|SLP-1[2-6]|UI-1[45]|BAR-2[2-7]|CLIP-12|FONT-15|MIME-0[89]|PKG-1[56]|UNIT-11|DISK-1[67]|SEC-1[012]|X11-04|NIGHT-0[123]|WALL-0[34]|SPOT-08|BAK-06|LOGIN-19|SLP-2[01]|XDG-0[1-3]|UPK-2[12]|BOOT-46|AUD-2[01]|GAME-(19|2[01])|FONT-1[67]|GIT-01|CALC-01|HUSH-0[1-3]|DL-03|STATE-05|REC-04|OCR-02|BAR-28|PANEL-01|FETCH-03|UI-16|THEME-22|UPK-20|APP-09|REC-01|DISK-18|DEV-01|NVIM-02|PKG-1[78]|MON-08) ' "$RPT")" 125 "125 rows added this round"
eq "$(grep -oE '^[A-Z0-9]+-[0-9]+[a-z]? ' "$RPT" | sort | uniq -d)" "" "no ID twice"

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

case_ "CALC-01 and UI-16: the launcher is the panel's — the torii and the menu helper ask it, a sum is worked out by qalc; either not asking it fails"
mkdir -p "$TMP/lb" "$HOME/.local/share/applications" "$HOME/.config/waybar"
printf '#!/bin/sh\n# kawa-menu (a stand-in): the launcher the panel'"'"'s own: printf "toggle launcher"\n' >"$TMP/lb/kawa-menu"
printf '#!/bin/sh\n' >"$TMP/lb/kawa-calc"; printf '#!/bin/sh\n' >"$TMP/lb/qalc"; chmod 755 "$TMP/lb"/*
printf '[Desktop Entry]\nName=Calculator\nExec=kawa-calc\n' >"$HOME/.local/share/applications/kawa-calc.desktop"
printf '{\n  "custom/torii": { "exec": "kawa-bar torii", "on-click": "setsid -f kawa-menu --launcher" }\n}\n' >"$HOME/.config/waybar/config.jsonc"
PATH=$TMP/lb:$PATH run "CALC-01 the calculator in the launcher"; eq "$RC" 0 "$OUT"
PATH=$TMP/lb:$PATH run "UI-16 the launcher is the panel's"; eq "$RC" 0 "$OUT"
printf '#!/bin/sh\n' >"$TMP/lb/kawa-menu"; PATH=$TMP/lb:$PATH run "CALC-01 the calculator in the launcher"; eq "$RC" 1 "a kawa-menu that does not ask the panel"
sed -i 's/kawa-menu --launcher/fuzzel/' "$HOME/.config/waybar/config.jsonc"
printf '#!/bin/sh\n# printf "toggle launcher"\n' >"$TMP/lb/kawa-menu"; PATH=$TMP/lb:$PATH run "UI-16 the launcher is the panel's"; eq "$RC" 1 "the torii opens something else"
rm -rf "$TMP/lb" "$HOME/.config/waybar" "$HOME/.local/share/applications/kawa-calc.desktop"

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

case_ "INS-02: setup's records agree — a finished build passes; a phase, user or GPU that is none, or a trial's records, fail"
printf 'done\n' >"$TMP/state/phase"; id -un >"$TMP/state/user"; echo amd >"$TMP/state/gpu"; rm -f "$TMP"/state/done.*
run "INS-02 setup's own records agree"; eq "$RC" 0 "$OUT"
echo 7 >"$TMP/state/phase"; run "INS-02 setup's own records agree"; eq "$RC" 1; has "$OUT" "'7' is no phase"
echo "done" >"$TMP/state/phase"; echo nobody-here-xyz >"$TMP/state/user"; run "INS-02 setup's own records agree"; eq "$RC" 1; has "$OUT" "names 'nobody-here-xyz', no user here"
id -un >"$TMP/state/user"; : >"$TMP/state/done.T5 repositories"; run "INS-02 setup's own records agree"; eq "$RC" 1; has "$OUT" "the container trial's records, on a real machine"
rm -f "$TMP"/state/done.T*
case_ "INS-03: nothing dnf could not install — each left-out package said with why"
rm -f "$TMP/state/dnf-failed"; run "INS-03 nothing dnf could not install"; eq "$RC" 0; has "$OUT" "nothing left out"
printf 'wiremix|missing\n' >"$TMP/state/dnf-failed"; run "INS-03 nothing dnf could not install"; eq "$RC" 1; has "$OUT" "wiremix — missing"
rm -f "$TMP/state/dnf-failed"
case_ "PKG-19: the package audit runs from the toolkit and passes on this repository"
mkdir -p "$TMP/tk/tools" "$TMP/tk/lib"; cp "$REPO/tools/check-packages" "$REPO/tools/packages.evidence" "$TMP/tk/tools/"; cp "$REPO/lib/manifest.sh" "$REPO/lib/upstream.sh" "$TMP/tk/lib/"
run "PKG-19 the package audit"; eq "$RC" 0 "$OUT"; has "$OUT" "clean"

done_
