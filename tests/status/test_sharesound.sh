#!/usr/bin/env bash
# tests/status/test_sharesound.sh — kawa-sharesound: what one look at PipeWire does, on a made-up
# graph (pw-dump a stand-in; pw-link, pw-metadata and pw-cli only recorded): the browser's recording
# of a monitor moved to the mix, every stream linked to the mix but a browser's live ones and those
# of who records it; the share microphone; nothing left when nothing is shared. The real thing,
# real PipeWire and a real browser: tools/share-sound-proof.sh.
. "$(dirname "$0")/lib.sh"

setup() {
  box; . "$HOME/.config/fedokawaii/icons.sh"
  G=$TMP/graph.json; NODES=() PORTS=() LINKS=() NEXT=1000 DEFAULT=alsa_mic
  stub pw-dump 'cat "'"$G"'"'
  stub pw-link '[ "$1" = -m ] && exit 0; exit 0'       # (its monitor ends at once: the watcher takes one look)
  stub pw-metadata; stub pw-cli; stub kawa-quick
  export XDG_RUNTIME_DIR; S=$XDG_RUNTIME_DIR/kawa-sharesound
  rm -rf "$S"
  node 40 alsa_out "Audio/Sink" '' playback_FL playback_FR monitor_FL monitor_FR
  node 60 alsa_mic "Audio/Source" '' capture_MONO
}
node() {   # node ID NAME CLASS PROPS-JSON PORT… — a node; a port named playback_/input_ is an input, id ID*10+n
  local id=$1 name=$2 cls=$3 extra=$4 i=0 p; shift 4
  NODES+=("{\"id\":$id,\"type\":\"PipeWire:Interface:Node\",\"info\":{\"props\":{\"node.name\":\"$name\",\"media.class\":\"$cls\"${extra:+,$extra}}}}")
  for p; do i=$((i + 1)); local d=output; [[ $p == playback_* || $p == input_* ]] && d=input
    PORTS+=("{\"id\":$((id * 10 + i)),\"type\":\"PipeWire:Interface:Port\",\"info\":{\"direction\":\"$d\",\"props\":{\"node.id\":$id,\"port.name\":\"$p\"}}}")
  done
}
link() {   # link OUTNODE INNODE OUTPORT INPORT
  LINKS+=("{\"type\":\"PipeWire:Interface:Link\",\"info\":{\"output-node-id\":$1,\"input-node-id\":$2,\"output-port-id\":$3,\"input-port-id\":$4}}")
}
write() {
  local IFS=,
  printf '[%s,{"type":"PipeWire:Interface:Metadata","props":{"metadata.name":"default"},"metadata":[{"key":"default.audio.source","value":{"name":"%s"}}]}]\n' \
    "${NODES[*]}${PORTS:+,${PORTS[*]}}${LINKS:+,${LINKS[*]}}" "$DEFAULT" >"$G"
}
look() { write; : >"$CALLS"; kawa-sharesound watch; }
PULSE='"application.process.binary":"helium","application.process.id":77'
mpv()    { node 100 mpv Stream/Output/Audio '"application.name":"mpv","application.process.id":50' output_FL output_FR; }
film()   { node 110 Helium Stream/Output/Audio "$PULSE,\"application.name\":\"Helium\",\"node.latency\":\"1024/48000\"" output_FL output_FR; }
callsd() { node 120 Helium Stream/Output/Audio "$PULSE,\"application.name\":\"Helium\",\"node.latency\":\"512/48000\"" output_FL output_FR; }
rec()    { node 130 'Helium input' Stream/Input/Audio "$PULSE,\"stream.capture.sink\":true,\"target.object\":\"alsa_out\"" input_FL input_FR; }
mix()    { node 70 kawa_share_mix Audio/Sink '' playback_FL playback_FR monitor_FL monitor_FR; }
mic()    { node 80 kawa_share_mic Audio/Source/Virtual '' input_FL input_FR capture_FL capture_FR; }

case_ "nothing shared, nothing on: one look does nothing at all"
setup; look; eq "$(cat "$CALLS" | grep -vE '^pw-(dump|link -m)')" ""
case_ "the browser records a monitor, no mix yet: the mix made (an output nothing plays, never chosen by itself)"
setup; mpv; rec; look
called '^pw-cli create-node adapter .*node.name=kawa_share_mix media.class=Audio/Sink .*object.linger=true priority.session=0'
not_called '^pw-link [0-9]'
case_ "…with the mix: its recording moved there, as the sound panel moves a stream; what plays linked to it too; a browser's film in, its call out"
setup; mpv; film; callsd; rec; mix; look
called '^pw-metadata 130 target.object kawa_share_mix$'
called '^pw-link 1001 701$'; called '^pw-link 1002 702$'
called '^pw-link 1101 701$'; called '^pw-link 1102 702$'
not_called '^pw-link 1201'; not_called '^pw-link 1202'
case_ "…already moved and linked: nothing more (a look changes nothing twice)"
setup; mpv; rec; mix; link 70 130 703 1301; link 100 70 1001 701; link 100 70 1002 702; look
eq "$(grep -cE '^pw-(link (-d |[0-9])|metadata|cli)' "$CALLS")" 0 "$(cat "$CALLS")"
case_ "…a link no longer wanted (a stream that is the call now): taken away"
setup; callsd; rec; mix; link 70 130 703 1301; link 120 70 1201 701; look
called '^pw-link -d 1201 701$'
case_ "…a stream with no latency of its own is no call: linked"
setup; node 140 Other Stream/Output/Audio '"application.process.binary":"helium"' output_FL output_FR; rec; mix; look
called '^pw-link 1401 701$'
case_ "…a stream wired by hand, half of a loopback: none of a program's sound, not linked"
setup; node 141 byhand Stream/Output/Audio '"node.autoconnect":false' output_FL; node 142 loop Stream/Output/Audio '"node.link-group":"g1"' output_FL; rec; mix; look
not_called '^pw-link 1411'; not_called '^pw-link 1421'
case_ "another program recording a monitor (a meter, OBS) is left alone"
setup; node 150 cava Stream/Input/Audio '"application.process.binary":"cava","stream.capture.sink":true' input_FL; mix; look
not_called '^pw-metadata'; called '^pw-cli destroy 70$'
case_ "the browser stopped recording: the mix goes"
setup; mpv; mix; look; called '^pw-cli destroy 70$'

case_ "a mono stream feeds both sides; a surround one by its side"
setup; node 160 voice Stream/Output/Audio '"application.name":"voice"' output_MONO; node 170 film51 Stream/Output/Audio '"application.name":"film51"' output_RL output_RR output_LFE; rec; mix; look
called '^pw-link 1601 701$'; called '^pw-link 1601 702$'
called '^pw-link 1701 701$'; not_called '^pw-link 1701 702$'; called '^pw-link 1702 702$'; called '^pw-link 1703 701$'; called '^pw-link 1703 702$'

case_ "on: your microphone remembered, the share microphone made, then the default input (kawa-quick moves what records)"
setup; write; stub pw-cli 'cp "'"$TMP"'/withmic.json" "'"$G"'"'; DEFAULT=alsa_mic; mic; write; cp "$G" "$TMP/withmic.json"
kawa-sharesound on; eq "$?" 0
eq "$(cat "$S/mode")" desktop; eq "$(cat "$S/before")" alsa_mic
called '^kawa-quick --do input 80$'
eq "$(kawa-sharesound state)" desktop
case_ "…one look: the mix made, then your microphone and the mix into the share microphone (a mono microphone on both sides)"
setup; mkdir -p "$S"; echo desktop >"$S/mode"; echo alsa_mic >"$S/before"; mpv; mix; mic; look
called '^pw-link 1001 701$'
called '^pw-link 703 801$'; called '^pw-link 704 802$'
called '^pw-link 601 801$'; called '^pw-link 601 802$'
case_ "…who records the share microphone is the call: its own sound stays out, the others' stays in"
setup; mkdir -p "$S"; echo desktop >"$S/mode"; echo alsa_mic >"$S/before"; mpv; mix; mic
node 200 discord Stream/Output/Audio '"application.name":"discord","application.process.id":90' output_FL output_FR
node 210 'discord in' Stream/Input/Audio '"application.name":"discord","application.process.id":90' input_FL
link 80 210 803 2101; look
not_called '^pw-link 2001'; called '^pw-link 1001 701$'
case_ "…one program chosen: its sound alone"
setup; mkdir -p "$S"; echo mpv >"$S/mode"; echo alsa_mic >"$S/before"; mpv; film; mix; mic; look
called '^pw-link 1001 701$'; not_called '^pw-link 1101'; called '^pw-link 601 801$'
case_ "off: your microphone the default again, the nodes gone"
setup; mkdir -p "$S"; echo desktop >"$S/mode"; echo alsa_mic >"$S/before"; mix; mic; write; : >"$CALLS"
kawa-sharesound off; eq "$?" 0
called '^kawa-quick --do input 60$'; called '^pw-cli destroy 70$'; called '^pw-cli destroy 80$'
[[ ! -e $S/mode ]] && _ok || _no "the mode stayed"; eq "$(kawa-sharesound state)" off

case_ "the row's menu: off, the desktop's sound, each program (once); the one in use marked; a choice done"
setup; mpv; film; callsd; write
stub kawa-menu 'cat >"$TMP/menu.in"'; kawa-sharesound menu
eq "$(cut -f1,3,5 "$TMP/menu.in")" "$(printf 'part\tshare sound\nrow\toff\ton\nrow\tthe desktop'"'"'s sound\t\nrow\tmpv\t\nrow\tHelium\t')"
stub kawa-menu 'cat >/dev/null; echo 3'; stub pw-cli; mic; write; kawa-sharesound menu; eq "$(cat "$S/mode")" mpv "row 3: mpv"
case_ "…dismissed: nothing changes"
stub kawa-menu 'cat >/dev/null'; kawa-sharesound menu; eq "$(cat "$S/mode")" mpv
case_ "the panel's state: read from its record, no process started"
has "$(kawa-quick --state 2>/dev/null | grep -c . || true)" ""
has "$(sed -n '/^state_sharesound/p' "$REPO/bin/kawa-quick")" 'kawa-sharesound/mode'
case_ "PipeWire not running: a command says so by its status, a watcher ends"
setup; stub pw-dump 'exit 1'; kawa-sharesound on; eq "$?" 1; kawa-sharesound watch; eq "$?" 0
case_ "--help, and wrong use: 2"
setup; kawa-sharesound --help | grep -q 'kawa-sharesound portal' && _ok || _no "no help"
kawa-sharesound nonsense 2>/dev/null; eq "$?" 2
done_
