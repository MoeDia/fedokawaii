#!/usr/bin/env bash
# tests/regress/test_kept.sh — never again an apply or an update that touches what is his (r27-upd-3,
# the owner's "update-proof" of 25 Oct: "configs owned by theme.sh, his own settings kept apart"):
# secrets.sh, his autostart.local.sh, the state of his settings and the settings chosen in the menu,
# byte for byte through a theme run on the finished install, in the fake machine.
. "$(dirname "$0")/../installer/lib.sh"
TK=/usr/local/lib/fedokawaii
echo_item() { printf '  %s · %s\n' "$1" "$2"; }

world built --themed
H=$W/home/fkuser
cfg=$H/.config/fedokawaii
state=$H/.local/state/fedokawaii

case_ "secrets, his own autostart and his settings: byte for byte through a theme run"
mkdir -p "$cfg" "$H/.config/dwl" "$state"
printf 'export PROWLARR_API_KEY=0123456789abcdef0123456789abcdef\nexport OWN_KEY=mine\n' >"$cfg/secrets.sh"; chmod 600 "$cfg/secrets.sh"
printf '#!/bin/sh\necho his own\n' >"$H/.config/dwl/autostart.local.sh"
printf 'dnd=on\nbrightness=40\n' >"$state/settings"
printf 'light\n' >"$state/wallpaper"
fk chown -R fkuser:fkuser "$cfg/secrets.sh" "$H/.config/dwl/autostart.local.sh" "$state"
before=$(cd "$H" && sha256sum .config/fedokawaii/secrets.sh .config/dwl/autostart.local.sh .local/state/fedokawaii/settings .local/state/fedokawaii/wallpaper)
fkrun bash "$TK/theme.sh" --user fkuser
[[ $RC == [04] || $RC == 0 ]] && _ok || _no "theme ended $RC: $(tail -n 3 <<<"$OUT")"
after=$(cd "$H" && sha256sum .config/fedokawaii/secrets.sh .config/dwl/autostart.local.sh .local/state/fedokawaii/settings .local/state/fedokawaii/wallpaper 2>&1)
eq "$after" "$before" "changed by the theme run: $(diff <(printf '%s\n' "$before") <(printf '%s\n' "$after") | head -n 4)"
eq "$(stat -c %a "$cfg/secrets.sh")" 600 "secrets.sh's mode"
has "$(cat "$cfg/secrets.sh")" "OWN_KEY=mine"
echo_item r27-upd-3 "secrets.sh, autostart.local.sh, his settings: the same bytes after a theme run"

case_ "the settings file: what he saved in the menu stays when the toolkit is made again"
fk bash -c "sed -i 's/^THEME=.*/THEME=\"light\"/' $TK/fedokawaii.conf"
fkrun bash "$TK/theme.sh" --user fkuser
has "$(fk cat "$TK/fedokawaii.conf")" 'THEME="light"' "the theme run put his setting back"
case_ "the theme ships nothing where his own files live"
for p in .config/fedokawaii/secrets.sh .config/dwl/autostart.local.sh .local/state; do
  [[ -e $REPO/configs/home/$p ]] && _no "configs/home/$p would be written over his" || _ok
done
done_
