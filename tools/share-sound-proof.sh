#!/usr/bin/env bash
# tools/share-sound-proof.sh — sound in a share, proven in the real browser and the real picker, on a
# real PipeWire, cut off from everything of the session: a headless dwl (tools/hl-dwl.sh), a PipeWire,
# WirePlumber, pipewire-pulse and portals of its own with no sound card (fake speakers), Helium in a
# throw-away profile through bin/kawa-browser, the picker clicked by the virtual pointer. A page
# (tools/share-sound/page.html) shares and measures the audio track it gets, in dB, in three bands:
#   other  what another program plays (pw-play)
#   film   a media element in a tab of the same browser
#   call   a real WebRTC connection's sound in that browser
#   screen   the whole screen with kawa-sharesound: other and film in, call out
#   raw      the same without it (--no-fix): how a browser alone does, all three in
#   tab      a tab with its sound: the film in that tab in, nothing else
#   window   the window pane, as the screen: other and film in, call out
#   mic      the row in quick settings, no browser: the share microphone heard by a recorder —
#            your microphone and the desktop's sound; one program's alone; a program recording
#            it that also plays (a call): its own sound kept out
#   bash tools/share-sound-proof.sh [screen|raw|tab|window|mic]…   (default: all)
#   Exit: 0 all as said above · 1 not · 2 misuse. Shots and logs: /dev/shm/share-sound-proof/.
set -u
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/.." && pwd)
out=/dev/shm/share-sound-proof
scenes=("$@"); ((${#scenes[@]})) || scenes=(screen raw tab window mic)
for s in "${scenes[@]}"; do [[ $s == @(screen|raw|tab|window|mic) ]] || { echo "share-sound-proof: unknown scene $s" >&2; exit 2; }; done
rm -rf "$out"; mkdir -p "$out/www" "$out/xdg/pipewire/pipewire.conf.d" "$out/xdg/wireplumber/wireplumber.conf.d" "$out/xdg/xdg-desktop-portal" "$out/xdg/xdg-desktop-portal-wlr"
cp "$here"/share-sound/*.html "$out/www/"
ffmpeg -hide_banner -loglevel error -y -f lavfi -i "anoisesrc=color=white:sample_rate=48000:amplitude=0.9,bandpass=f=650:w=600,volume=6dB" -t 120 -ac 2 "$out/other.wav" || exit 2
ffmpeg -hide_banner -loglevel error -y -f lavfi -i "anoisesrc=color=white:sample_rate=48000:amplitude=0.9,bandpass=f=2700:w=1200,volume=6dB" -t 30 -ac 2 "$out/www/film.wav" || exit 2
# (no sound card can be reached: WirePlumber's monitors off; its and PipeWire's state in the run's own folders)
cat >"$out/xdg/wireplumber/wireplumber.conf.d/50-fence.conf" <<'CONF'
wireplumber.profiles = { main = { monitor.alsa = disabled monitor.alsa-midi = disabled monitor.bluez = disabled monitor.bluez-midi = disabled monitor.v4l2 = disabled monitor.libcamera = disabled } }
CONF
cat >"$out/xdg/pipewire/pipewire.conf.d/50-fence.conf" <<'CONF'
context.objects = [ { factory = adapter args = { factory.name = support.null-audio-sink node.name = fake_speakers node.description = "Fake speakers" media.class = Audio/Sink audio.position = [ FL FR ] object.linger = true priority.session = 1000 } } ]
CONF
cp "$repo/configs/home/.config/xdg-desktop-portal/wlroots-portals.conf" "$out/xdg/xdg-desktop-portal/"
printf '#!/bin/sh\nsed -n 1p\n' >"$out/pick"; chmod +x "$out/pick"
# (the portal as the desktop's, but its chooser, and the fix but in the raw scene: the flag file)
cat >"$out/hook" <<HOOK
#!/bin/sh
[ -e "$out/nofix" ] || exec "$repo/bin/kawa-sharesound" portal
HOOK
chmod +x "$out/hook"
printf '[screencast]\nchooser_type=dmenu\nchooser_cmd=%s/pick\nmax_fps=30\nexec_before=%s/hook\n' "$out" "$out" >"$out/xdg/xdg-desktop-portal-wlr/config"
cat >"$out/clk" <<'CLK'
#!/bin/sh
wlrctl pointer move -8000 -8000; wlrctl pointer move "$1" "$2"; sleep 0.25; wlrctl pointer click left; sleep 0.25
CLK
chmod +x "$out/clk"
# one scene: the run inside the headless dwl
cat >"$out/run.sh" <<EOF2
#!/bin/sh
export XDG_CONFIG_HOME=$out/xdg XDG_STATE_HOME=$out/state XDG_CURRENT_DESKTOP=wlroots XDG_SESSION_TYPE=wayland PATH=$repo/bin:\$PATH
mkdir -p "\$XDG_STATE_HOME"
exec dbus-run-session -- sh "$out/inner.sh"
EOF2
cat >"$out/inner.sh" <<EOF2
#!/bin/sh
O=$out; D="node $here/share-sound/drive.mjs"; S=\$(cat "\$O/scene"); P=\$O/profile; rm -rf "\$P"; mkdir -p "\$P"
pipewire >"\$O/pw.log" 2>&1 & sleep 0.6
wireplumber >"\$O/wp.log" 2>&1 &
pipewire -c pipewire-pulse.conf >"\$O/pwp.log" 2>&1 & sleep 1.5
wtype -s 120000 -k Shift_L >/dev/null 2>&1 &
sleep 0.5
(cd "\$O/www" && exec python3 -I -m http.server 18471 --bind 127.0.0.1 >/dev/null 2>&1) &
mkdir -p "\$P/Default"; printf '{"webrtc":{"ip_handling_policy":"default"}}' >"\$P/Default/Preferences"   # (this page's call is with itself: no server, its own addresses)
kawa-browser --user-data-dir="\$P" --remote-debugging-port=0 --no-first-run --disable-features=WebRtcHideLocalIpsWithMdns about:blank >"\$O/helium-\$S.log" 2>&1 &
H=\$!
i=0; while [ ! -s "\$P/DevToolsActivePort" ] && [ \$i -lt 60 ]; do sleep 0.5; i=\$((i+1)); done
PORT=\$(sed -n 1p "\$P/DevToolsActivePort")
pw-play --target fake_speakers "\$O/other.wav" >/dev/null 2>&1 &
RAW='{echoCancellation:false,noiseSuppression:false,autoGainControl:false}'
START="(window.p=start({video:true,audio:\$RAW,systemAudio:'include'}).catch(e=>'ERR '+e.name+': '+e.message),1)"
WAIT="Promise.race([window.p,new Promise(r=>setTimeout(()=>r('still waiting'),8000))])"
GRAPH="sh:pw-link -l | grep -A4 -E '^kawa_share_mix|^Helium input' | cut -c1-70; true"
case \$S in
  screen|raw)
    \$D "\$PORT" http://127.0.0.1:18471/page.html "\$START" sleep:1500 "sh:\$O/clk 1141 172" sleep:3500 \
      "sh:\$O/clk 825 300" sleep:800 "sh:grim \$O/\$S-picker.png" "sh:\$O/clk 1169 672" sleep:2500 "\$WAIT" sleep:2500 \
      "levels()" "film()" sleep:1500 "levels()" "call()" sleep:3500 "levels()" sleep:4000 "levels()" "pcs.map(p=>p.iceConnectionState).join()+' cand='+window.cands+' el='+(window.callEl?callEl.paused:'none')" "\$GRAPH" \
      "(stream.getTracks().forEach(t=>t.stop()),1)" sleep:2500 "sh:pw-link -l | grep -c kawa_share; true" ;;
  tab)
    \$D "\$PORT" http://127.0.0.1:18471/page.html tab:http://127.0.0.1:18471/film.html "\$START" sleep:1800 "sh:grim \$O/tab-list.png" \
      "sh:\$O/clk 843 224" sleep:800 "sh:grim \$O/tab-picker.png" "sh:\$O/clk 1169 672" sleep:2500 "\$WAIT" sleep:3000 "levels()" sleep:2000 "levels()" ;;
  window)
    \$D "\$PORT" http://127.0.0.1:18471/page.html "\$START" sleep:3000 "sh:\$O/clk 953 172" sleep:3000 "sh:grim \$O/window-picker.png" \
      "sh:\$O/clk 1169 672" sleep:2500 "\$WAIT" sleep:2500 "film()" "call()" sleep:4500 "levels()" sleep:3000 "levels()" ;;
esac
kill \$H; sleep 1
EOF2
cat >"$out/mic.sh" <<EOF2
#!/bin/sh
export XDG_CONFIG_HOME=$out/xdg XDG_STATE_HOME=$out/state XDG_CURRENT_DESKTOP=wlroots PATH=$repo/bin:\$PATH
O=$out
pipewire >"\$O/pw.log" 2>&1 & sleep 0.6
wireplumber >"\$O/wp.log" 2>&1 &
sleep 1.5
pw-cli create-node adapter '{ factory.name=support.null-audio-sink node.name=fake_mic media.class=Audio/Source/Virtual audio.position=[ FL FR ] object.linger=true }' >/dev/null
sleep 0.5; wpctl set-default "\$(pw-dump | jq '.[]|select(.info.props["node.name"]=="fake_mic").id')"
tone() { ffmpeg -hide_banner -loglevel error -y -f lavfi -i "sine=frequency=\$1:sample_rate=48000" -t 60 -ac 2 "\$O/t\$1.wav"; }
tone 1000; tone 2000; tone 3000
PIPEWIRE_PROPS='{ node.autoconnect=false node.name=micplay }' pw-play --target=0 "\$O/t3000.wav" >/dev/null 2>&1 &
sleep 0.6; pw-link micplay:output_FL fake_mic:input_FL; pw-link micplay:output_FR fake_mic:input_FR
pw-play --target fake_speakers --properties='{ application.name=one node.name=one }' "\$O/t1000.wav" >/dev/null 2>&1 &
pw-play --target fake_speakers --properties='{ application.name=two node.name=two }' "\$O/t2000.wav" >/dev/null 2>&1 &
sleep 0.6
rec() { timeout -s INT 2.5 pw-record --target kawa_share_mic --rate 48000 --channels 2 "\$O/\$1.wav" >/dev/null 2>&1; }
pipewire -c pipewire-pulse.conf >"\$O/pwp.log" 2>&1 & sleep 0.4
echo "apps: \$(kawa-sharesound apps | tr '\n' ' ')"
kawa-sharesound on; sleep 1.2
echo "default: \$(pw-metadata -n default 0 default.audio.source 2>/dev/null | grep -o 'kawa_share_mic\|fake_mic' | head -1)"
pw-link -l | grep -A3 -E '^kawa_share_(mix:playback_FL|mic:input_FL)' | cut -c1-60
rec desktop
kawa-sharesound on two; sleep 1.2; rec two
pw-link -l | grep -A3 -E '^kawa_share_mix:playback_FL' | cut -c1-60
# a program that records the share microphone and plays (a call): its playback not linked to the mix
kawa-sharesound on desktop; sleep 1
# (two streams of one process, as a call program has: the process named by hand)
pw-record --target kawa_share_mic --properties='{ application.process.id=4242 node.name=call.in }' "\$O/call-in.wav" >/dev/null 2>&1 &
L1=\$!
pw-play --target fake_speakers --properties='{ application.process.id=4242 node.name=call.out application.name=call }' "\$O/t1000.wav" >/dev/null 2>&1 &
L2=\$!; sleep 1.5
echo "the call's own sound in the mix: \$(pw-link -l | awk '/^kawa_share_mix:playback_/ { f = 1; next } /^[^ ]/ { f = 0 } f && /call.out/' | wc -l) links"
pw-link -l | grep -A6 '^kawa_share_mix:playback_FL' | cut -c1-60
kill \$L1 \$L2; sleep 0.3
kawa-sharesound off; sleep 1.2
echo "after off: \$(pw-dump | jq -r '[.[]|select(.type=="PipeWire:Interface:Node")|.info.props["node.name"]//""|select(startswith("kawa_share"))]|length') nodes, default \$(pw-metadata -n default 0 default.audio.source 2>/dev/null | grep -o 'kawa_share_mic\|fake_mic' | head -1)"
kawa-sharesound state
EOF2
rc=0
for s in "${scenes[@]}"; do
  printf '%s' "$s" >"$out/scene"
  rm -f "$out/nofix"; [[ $s == raw ]] && : >"$out/nofix"
  rm -rf "$out/state"
  r=$out/run.sh; [[ $s == mic ]] && r=$out/mic.sh
  bash "$repo/tools/hl-dwl.sh" "$r" --time 120 --keep "$out/k-$s" >"$out/hl-$s.out" 2>&1
  if [[ $s == mic ]]; then
    grep -vE 'dbus-daemon' "$out/k-mic/script.log" | cut -c1-120
    python3 -I "$here/share-sound/tones.py" "$out/desktop.wav" "$out/two.wav" || rc=1
    continue
  fi
  grep -E '^(JS|kawa_share|Helium input|  \||[0-9]+$)' "$out/k-$s/script.log" | cut -c1-170 >"$out/$s.txt"
  python3 -I - "$s" "$out/$s.txt" <<'PY' || rc=1
import json, re, sys
scene, path = sys.argv[1:3]
rows = [json.loads(l.split("=> ", 1)[1]) for l in open(path, encoding="utf-8") if l.startswith("JS levels()") and "=> {" in l]
started = [l for l in open(path, encoding="utf-8") if l.startswith("JS Promise.race")]
print(f"── {scene}"); [print("  ", r) for r in rows]
HEARD = lambda r, k: r[k] is not None and r[k] > r["floor"] + 20        # (20 dB over the floor)
if not rows:
    print("   ✘ no sound track was measured:", started); sys.exit(1)
last = rows[-1]
want = {"screen": dict(other=True, film=True, call=False), "window": dict(other=True, film=True, call=False), "raw": dict(other=True, film=True, call=True), "tab": dict(other=False, film=True, call=False)}[scene]
bad = [k for k, v in want.items() if HEARD(last, k) != v]
print("   ✘ wrong:", bad) if bad else print("   ✔ as it should be:", want)
sys.exit(1 if bad else 0)
PY
done
exit "$rc"
