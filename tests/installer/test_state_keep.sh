#!/usr/bin/env bash
# tests/installer/test_state_keep.sh — what you set on the desktop outlives the toolkit's own
# runs (the fake machine): every setting's record put in the home as its helper writes it — the
# store (kawa-state: do not disturb, Bluetooth, brightness, another helper's key), the night
# light, the screensaver, the terminal's glass, each theme's wallpaper, the light theme's link,
# FreeSync, Steam's start with the desktop, WirePlumber's volumes and defaults — then the theme
# run (what fedokawaii apply ends in), a repair and an update: each record byte for byte as it
# was, and the theme link still on light.
. "$(dirname "$0")/lib.sh"
H=/home/fkuser
TK=/usr/local/lib/fedokawaii
world built; releases

# yours: each record as its helper writes it (owned by you, as there)
put() { mkdir -p "$(dirname "$W$H/$1")"; printf '%s\n' "${@:2}" >"$W$H/$1"; }
put .local/state/fedokawaii/settings '# ~/.local/state/fedokawaii/settings — what you set on the desktop (kawa-state; kawa-state --help)' \
  dnd=on bluetooth=off brightness=40 gamemode=on
put .local/state/fedokawaii/night 'on 3500'
put .local/state/fedokawaii/saver off
put .local/state/fedokawaii/foot-glass.ini '[colors-dark]' alpha=1 '[colors-light]' alpha=1
put .local/state/fedokawaii/wallpaper-dark pack:yoru-03
put .local/state/fedokawaii/wallpaper-light "$H/Pictures/Wallpapers/mine.png"
put .config/fedokawaii/vrr always
put .config/fedokawaii/steam-warm no
put .local/state/wireplumber/default-nodes '[default-nodes]' 'default.configured.audio.sink=alsa_output.usb-DAC' 'default.configured.audio.source=alsa_input.usb-Mic'
put .local/state/wireplumber/stream-properties '[stream-properties]' 'Output/Audio:media.role:Music={"volume":0.42,"mute":false}'
mkdir -p "$W$H/.config/fedokawaii/themes/light"; ln -sfn themes/light "$W$H/.config/fedokawaii/current"
fk chown -R fkuser:fkuser "$H/.local/state" "$H/.config/fedokawaii"
FILES=(.local/state/fedokawaii/settings .local/state/fedokawaii/night .local/state/fedokawaii/saver
       .local/state/fedokawaii/foot-glass.ini .local/state/fedokawaii/wallpaper-dark .local/state/fedokawaii/wallpaper-light
       .config/fedokawaii/vrr .config/fedokawaii/steam-warm
       .local/state/wireplumber/default-nodes .local/state/wireplumber/stream-properties)
sums() { (cd "$W$H" && sha256sum "${FILES[@]}" 2>&1; readlink .config/fedokawaii/current); }
WANT=$(sums)

for run in "theme (fedokawaii apply)" "repair" "update"; do
  case_ "$run: every setting of yours as you left it"
  case $run in
    theme*) fkrun bash "$TK/theme.sh" --user fkuser ;;
    repair) fkrun bash "$TK/setup.sh" --repair ;;
    update) fkrun bash "$TK/setup.sh" --update ;;
  esac
  # (repair's exit says what it found on the fake machine; that it reached the theme is what counts)
  if [[ $run == repair ]]; then has "$OUT" "the theme (configs, dwl, helpers, wallpapers)"; else eq "$RC" 0 "$run ran: $(tail -n 3 <<<"$OUT")"; fi
  eq "$(sums)" "$WANT"
done
done_
