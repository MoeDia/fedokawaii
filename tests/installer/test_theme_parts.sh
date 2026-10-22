#!/usr/bin/env bash
# tests/installer/test_theme_parts.sh — theme.sh's parts beyond the files: the C helpers
# kawa-clipkeep and kawa-saver (built like dwl: one that does not build stops the run), and the
# boot menu and console, the one part that runs contained — when it cannot be made the run goes
# on and says so, and --check counts it as optional (exit 4) until what it failed on changes
# (exit 3); once made, the mark goes. Then mpv's scaling on an APU and Steam's overlay with STEAM=no.
. "$(dirname "$0")/lib.sh"
H=/home/fkuser
TK=/usr/local/lib/fedokawaii
theme() { fkrun bash "$TK/theme.sh" --user fkuser "$@"; }
tconf() { sed -i "$@" "$W$TK/fedokawaii.conf"; }   # the toolkit's settings, changed

world built
tconf 's/^WALLPAPER_PACK=.*/WALLPAPER_PACK="no"/'
keep plain

case_ "kawa-clipkeep does not build: the theme run stops and says so (a part of the desktop, as dwl)"
fkh rc-make-kawa-clipkeep 2
theme; [[ $RC != 0 ]] && _ok || _no "exit 0 with kawa-clipkeep not built"
has "$OUT" "kawa-clipkeep failed to build from src/kawa-clipkeep"
[[ ! -e $W$H/.local/state/fedokawaii/kawa-clipkeep.failed ]] && _ok || _no "a mark that would pass it as optional"
case_ "--check after it: drift, exit 3 — never in sync"
theme --check; eq "$RC" 3; has "$OUT" "kawa-clipkeep (not built from src/kawa-clipkeep)"
rm -f "$FKH/rc-make-kawa-clipkeep"

case_ "the boot menu not made (grub2-mkconfig fails): the rest is themed, exit 0, said"
fkh rc-grub2-mkconfig 1
theme; eq "$RC" 0
has "$OUT" "the boot menu and console were not themed"
[[ -s $W/var/lib/fedokawaii/boot.failed ]] && _ok || _no "no boot.failed mark"
[[ -f $W$H/.config/foot/foot.ini && -x $W$H/.local/bin/kawa-clipkeep ]] && _ok || _no "the rest of the theme was not applied"
[[ -x $W$H/.local/bin/kawa-saver && -f $W$H/.local/lib/fedokawaii/kawa-lockmod.so ]] && _ok || _no "the screensaver and the lock screen's module were not built"
eq "$(fk stat -c %U /var/lib/fedokawaii/boot.failed)" root "the boot mark is root's (nothing of yours decides it)"

case_ "--check while nothing it depends on changed: exit 4 — in sync, it listed as not made here"
theme --check; eq "$RC" 4
has "$OUT" "✔ theme in sync"; has "$OUT" "! not made here"; has "$OUT" "grub.cfg"
lacks "$OUT" "kawa-clipkeep" "the helpers are never optional"
case_ "verify takes exit 4 as passed, with a warning (it must not stop setup's gate for ever)"
fkrun bash "$TK/verify.sh" --pre-finalize
has "$OUT" "✔  every file in sync with the repo"; has "$OUT" "! "
lacks "$OUT" "✘  every file in sync"; lacks "$OUT" "boot menu theme installed" "the boot checks skipped"
has "$OUT" "boot menu: not themed here"; lacks "$OUT" "GRUB menu shown for"
has "$OUT" "✔  file dialogs → yazi (FileChooser: termfilechooser, the only one)" "verify reads portals.conf as the theme writes it"

case_ "once what it failed on changes (BOOT_MENU_SECONDS): drift, exit 3"
tconf 's/^BOOT_MENU_SECONDS=.*/BOOT_MENU_SECONDS="5"/'
theme --check; eq "$RC" 3; has "$OUT" "grub"
tconf 's/^BOOT_MENU_SECONDS=.*/BOOT_MENU_SECONDS="2"/'

case_ "the run once it works again: made, the mark gone, --check exit 0"
rm -f "$FKH/rc-grub2-mkconfig"
theme; eq "$RC" 0
[[ ! -e $W/var/lib/fedokawaii/boot.failed ]] && _ok || _no "the mark left behind"
grep -q 'theme=/boot/grub2/themes/sumi/theme.txt\|/boot/grub2/themes/sumi/theme.txt' "$W/boot/grub2/grub.cfg" && _ok || _no "grub.cfg without the theme"
theme --check; eq "$RC" 0

case_ "dracut failing (vi a link to nvim, as an older setup left it: dracut follows it into nvim's Lua libraries): the menu, the console font, the arguments all in place — dracut last, its ✘ said"
keep before-vi
ln -sfn ../../bin/nvim "$W/usr/local/bin/vi"
for f in "$W"/boot/initramfs-*.img; do echo initramfs >"$f"; done              # (the installer's: no splash)
sed -i '/^GRUB_THEME=/d; /^GRUB_TERMINAL_OUTPUT=/d' "$W/etc/default/grub"; rm -f "$W/boot/grub2/grub.cfg"
sed -i 's/^FONT=.*/FONT="eurlatgr"/' "$W/etc/vconsole.conf"
theme; eq "$RC" 0 "the rest of the theme applied"
has "$OUT" "dracut could not remake the boot images with the splash"
has "$(cat "$W/etc/default/grub")" 'GRUB_THEME="/boot/grub2/themes/sumi/theme.txt"'; has "$(cat "$W/etc/default/grub")" 'GRUB_TERMINAL_OUTPUT="gfxterm"'; has "$(cat "$W/etc/default/grub")" 'GRUB_BACKGROUND="/boot/grub2/themes/sumi/background.png"' "no black box once an entry is chosen"
grep -q 'grub2/themes/sumi/theme.txt' "$W/boot/grub2/grub.cfg" && _ok || _no "grub.cfg not made again before dracut"
has "$(cat "$W/etc/vconsole.conf")" 'FONT="ter-v16b"' "the console font set before dracut ran"
has "$(fk lsinitrd)" "themes/bgrt/bgrt.plymouth" "the boot image still without the splash"
case_ "… --check names the images without the splash; verify fails them hard (never a warning): the boot shows text"
theme --check; has "$OUT" "boot images without the splash"
fkrun bash "$TK/verify.sh" --pre-finalize
has "$OUT" "✘  the splash in every boot image (lsinitrd)"; has "$OUT" "✘  vi → nvim (a script"
case_ "… vi a script again (setup's editor_policy): the next run makes the images, verify passes them"
printf '#!/bin/sh\nexec nvim "$@"\n' >"$W/usr/local/bin.vi.tmp"; rm -f "$W/usr/local/bin/vi"; mv "$W/usr/local/bin.vi.tmp" "$W/usr/local/bin/vi"; chmod 755 "$W/usr/local/bin/vi"
theme; eq "$RC" 0; called 'dracut\] -f --regenerate-all'
has "$(fk lsinitrd)" "themes/sumi/sumi.script"
[[ ! -e $W/var/lib/fedokawaii/boot.failed ]] && _ok || _no "the mark left behind"
fkrun bash "$TK/verify.sh" --pre-finalize
has "$OUT" "✔  the splash in every boot image (lsinitrd)"; has "$OUT" "✔  vi → nvim (a script"
reset_calls; theme; not_called 'dracut\]' "images in order: dracut not run again"
back before-vi

case_ "Fedora's plymouthd.conf (comments only): the whole file written — Plymouth itself reads sumi (Theme the first key of [Daemon], ShowDelay=0 after it), the images with it"
printf '# Administrator customizations go in this file\n#[Daemon]\n#Theme=fade-in\n' >"$W/etc/plymouth/plymouthd.conf"
theme; eq "$RC" 0
eq "$(fk plymouth-set-default-theme)" sumi
eq "$(grep -v '^#' "$W/etc/plymouth/plymouthd.conf")" $'[Daemon]\nTheme=sumi\nShowDelay=0'
has "$(fk lsinitrd)" "themes/sumi/sumi.script"
case_ "… a ShowDelay above the theme (as a line-by-line edit left it: Plymouth then reads text): --check drift, the run rewrites it and remakes the images"
printf '[Daemon]\nShowDelay=0\nTheme=sumi\n' >"$W/etc/plymouth/plymouthd.conf"
eq "$(fk plymouth-set-default-theme)" bgrt "Plymouth's reading: hidden"
theme --check; eq "$RC" 3; has "$OUT" "plymouthd.conf: the sumi theme, shown at once"
theme; eq "$RC" 0; called 'dracut\] -f --regenerate-all'
eq "$(fk plymouth-set-default-theme)" sumi; theme --check; eq "$RC" 0

case_ "an install made over a serial console (GRUB_TERMINAL=\"serial console\" wins over the output): it goes, grub.cfg names the theme, --check in sync"
printf 'GRUB_TERMINAL="serial console"\nGRUB_SERIAL_COMMAND="serial"\n' >>"$W/etc/default/grub"
theme --check; eq "$RC" 3; has "$OUT" "GRUB_TERMINAL (it keeps the menu in text)"
theme; eq "$RC" 0
lacks "$(cat "$W/etc/default/grub")" "GRUB_TERMINAL=" "removed"
grep -q 'grub2/themes/sumi/theme.txt' "$W/boot/grub2/grub.cfg" && _ok || _no "grub.cfg without the theme"
theme --check; eq "$RC" 0
fkh grub-no-theme 1
sed -i '/^GRUB_THEME=/d' "$W/etc/default/grub"
theme; eq "$RC" 0 "the rest of the theme applied"
has "$OUT" "grub2-mkconfig made /boot/grub2/grub.cfg without the theme"
[[ -s $W/var/lib/fedokawaii/boot.failed ]] && _ok || _no "no boot.failed mark"
rm -f "$FKH/grub-no-theme"; theme; eq "$RC" 0
[[ ! -e $W/var/lib/fedokawaii/boot.failed ]] && _ok || _no "the mark left behind"

case_ "/boot a partition of its own (the installer's Btrfs layout): grub.cfg names the theme from /boot's root — in sync, and verify sees it"
touch "$FKH/boot-separate"; rm -f "$W/boot/grub2/grub.cfg"
theme; eq "$RC" 0
grep -qxF 'set theme=($root)/grub2/themes/sumi/theme.txt' "$W/boot/grub2/grub.cfg" && _ok || _no "grub.cfg: $(cat "$W/boot/grub2/grub.cfg")"
theme --check; eq "$RC" 0 "$(grep -i grub <<<"$OUT" | head -n2 | tr '\n' '|')"
reset_calls; theme; not_called grub2-mkconfig
fkrun bash "$TK/verify.sh" --pre-finalize
has "$OUT" "✔  boot menu theme installed"; lacks "$OUT" "✘ every file in sync"
rm -f "$FKH/boot-separate"; rm -f "$W/boot/grub2/grub.cfg"; theme; eq "$RC" 0

case_ "the boot menu: the console palette on every boot entry, BOOT_MENU_SECONDS shown, Fedora's auto-hide off"
has "$(cat "$FKH/grub-args")" "vt.default_red="; eq "$(grep -c 'vt.default_red=' "$FKH/grub-args")" 2 "both entries"
has "$(cat "$W/etc/default/grub")" "GRUB_TIMEOUT=2"; has "$(cat "$W/etc/default/grub")" 'GRUB_GFXMODE="2560x1440,auto"'
lacks "$(cat "$FKH/grubenv")" "menu_auto_hide=2"
has "$(cat "$W/etc/vconsole.conf")" 'FONT="ter-v16b"' "1440p: Fedora's own console size (8×16)"
case_ "files an earlier theme put in the boot menu's folder (select_n.png: a pixmap GRUB would still draw): --check names them, the run removes them"
G=$W/boot/grub2/themes/sumi
fk cp /boot/grub2/themes/sumi/select_c.png /boot/grub2/themes/sumi/select_n.png; fk touch /boot/grub2/themes/sumi/departure.pf2
theme --check; eq "$RC" 3; has "$OUT" "select_n.png: left over"; has "$OUT" "departure.pf2: left over"
theme; eq "$RC" 0
[[ ! -e $G/select_n.png && ! -e $G/departure.pf2 && -s $G/select_c.png && -s $G/select_w.png && -s $G/theme.txt ]] && _ok || _no "in the folder: $(ls "$G" | tr '\n' ' ')"
theme --check; eq "$RC" 0
case_ "BOOT_MENU_SECONDS=0 beside Windows: the menu stays shown (the other system must stay reachable)"
echo "Windows Boot Manager" >"$W/var/lib/fedokawaii/other-os"
tconf 's/^BOOT_MENU_SECONDS=.*/BOOT_MENU_SECONDS="0"/'; theme
lacks "$(cat "$FKH/grubenv")" "menu_auto_hide=2"
rm -f "$W/var/lib/fedokawaii/other-os"
case_ "BOOT_MENU_SECONDS=0: Fedora's hidden menu back"
theme
has "$(cat "$FKH/grubenv")" "menu_auto_hide=2"

case_ "an APU (512 MB of shared memory) and STEAM=no: mpv's own scaling, no game overlay config"
back plain; hw_apu; tconf 's/^STEAM=.*/STEAM="no"/'
theme; eq "$RC" 0
lacks "$(grep '^profile=' "$W$H/.config/mpv/mpv.conf")" "high-quality"
has "$(cat "$W$H/.config/mpv/mpv.conf")" "# scaling: mpv's own defaults"
[[ ! -e $W$H/.config/MangoHud && ! -e $W$H/.local/share/applications/steam.desktop ]] && _ok || _no "MangoHud config or Steam's entry installed with STEAM=no"
has "$(cat "$W/etc/vconsole.conf")" 'FONT="ter-v16b"'


case_ "Spotify and WhatsApp: their web apps in Brave app windows (their seals); the older entry for Spotify's app and lpf's hidden ones replaced or retired"
back plain; a=$W$H/.local/share/applications; mkdir -p "$a"
printf '[Desktop Entry]\n# Spotify (lpf)\nName=Spotify\nExec=spotify --ozone-platform=wayland %%U\n' >"$a/spotify.desktop"
for e in lpf lpf-gui lpf-notify lpf-spotify-client; do printf '[Desktop Entry]\n# with lpf-spotify-client\nName=%s\nNoDisplay=true\n' "$e" >"$a/$e.desktop"; done
printf '[Desktop Entry]\n# mine\nName=lpf\n' >"$a/lpf-mine.desktop"
fk_perms; theme; eq "$RC" 0
eq "$(sed -n 's/^Exec=//p' "$a/spotify.desktop")" "$H/.local/bin/brave-origin --app=https://open.spotify.com"
eq "$(sed -n 's/^X-Fedokawaii-Kanji=//p' "$a/spotify.desktop")" "曲" "our seal (曲), the launcher draws it"
lacks "$(cat "$a/spotify.desktop")" "Icon=" "no picture of its own"
lacks "$(cat "$a/spotify.desktop")" "MimeType" "no spotify: links (nothing here opens them)"
eq "$(sed -n 's/^Exec=//p' "$a/whatsapp.desktop")" "$H/.local/bin/brave-origin --app=https://web.whatsapp.com" "WhatsApp: WhatsApp Web in a Brave app window"
eq "$(sed -n 's/^X-Fedokawaii-Kanji=//p' "$a/whatsapp.desktop")" "話" "WhatsApp: our seal (話), the launcher draws it"
lacks "$(cat "$a/whatsapp.desktop")" "Icon=" "WhatsApp: no picture of its own"
for e in lpf lpf-gui lpf-notify lpf-spotify-client; do [[ ! -e $a/$e.desktop ]] && _ok || _no "$e.desktop left"; done
has "$OUT" "lpf-spotify-client.desktop (retired)"; [[ -e $a/lpf-mine.desktop ]] && _ok || _no "an entry of yours taken"
theme --check; lacks "$OUT" "lpf" "in sync without lpf's entries"
grep -qx 'NoDisplay=true' "$a/qt6ct.desktop" && _ok || _no "qt6ct.desktop not hidden in the home"
case_ "Brave: Widevine switched on once (Spotify's web player needs it) while Brave is closed; switched off in Brave later, it stays off"
back plain; ls="$W$H/.config/BraveSoftware/Brave-Origin/Local State"
mkdir -p "${ls%/*}"; echo '{"brave":{"origin":{"free_tier_accepted":true}}}' >"$ls"; fk_perms
theme; eq "$(jq -c .brave "$ls")" '{"origin":{"free_tier_accepted":true},"widevine_opted_in":true}' "on, the rest as it was"
has "$OUT" "Widevine on"
jq '.brave.widevine_opted_in = false' "$ls" >"$ls.n" && cat "$ls.n" >"$ls" && rm "$ls.n"
theme; eq "$(jq .brave.widevine_opted_in "$ls")" false "your choice kept"
theme --check; lacks "$OUT" "Widevine"
back plain; rm -rf "$W$H/.config/BraveSoftware"; theme
eq "$(jq -c . "$W$H/.config/BraveSoftware/Brave-Origin/Local State")" '{"brave":{"widevine_opted_in":true}}' "before Brave's first start"

case_ "Brave Origin's two launcher entries: its own runs the wrapper; the second (com.brave.Origin) hidden as Brave meant it (brave/brave-browser#52193)"
back plain
printf '[Desktop Entry]\nName=Brave Origin\nIcon=brave-origin\nExec=/usr/bin/brave-origin-stable %%U\n\n[Desktop Action new-window]\nName=New Window\nExec=/usr/bin/brave-origin-stable\n' \
  >"$W/usrshare/applications/brave-origin.desktop"
printf '[Desktop Entry]\nName=Brave Origin\nExec=/usr/bin/brave-origin-stable %%U\n\n[Desktop Action new-private-window]\nName=New Private Window\nExec=/usr/bin/brave-origin-stable --incognito\nNoDisplay=true\n' \
  >"$W/usrshare/applications/com.brave.Origin.desktop"
theme; eq "$RC" 0
u=$W$H/.local/share/applications
has "$(cat "$u/brave-origin.desktop")" "Exec=$H/.local/bin/brave-origin %U"
lacks "$(cat "$u/brave-origin.desktop")" "NoDisplay" "the entry you launch stays listed"
eq "$(sed -n 2p "$u/com.brave.Origin.desktop")" "NoDisplay=true" "hidden in its [Desktop Entry]"
eq "$(grep -c '^NoDisplay=' "$u/com.brave.Origin.desktop")" 1 "the misplaced line gone"
has "$(cat "$u/com.brave.Origin.desktop")" "Exec=$H/.local/bin/brave-origin --incognito"
eq "$(grep '^X-Fedokawaii-Kanji=' "$u/kawa-prowlarr.desktop")" "X-Fedokawaii-Kanji=索" "Prowlarr's page: its seal (索), the launcher draws it"
theme --check; lacks "$OUT" "com.brave.Origin" "in sync once made"
rm -f "$u/com.brave.Origin.desktop"
theme --check; has "$OUT" "com.brave.Origin.desktop" "a missing copy is drift"

case_ "the key that shows the hidden boot menu (and its snapshots): verify fails when 12_menu_auto_hide is gone or GRUB_TIMEOUT_STYLE is set"
fkrun bash "$TK/verify.sh"; has "$OUT" "✔  Shift (Esc/F8) at power-on shows the boot menu"; has "$OUT" "✔  nothing takes that key away"
cp "$W/etc/default/grub" "$TMP/grub.keep"; echo 'GRUB_TIMEOUT_STYLE=hidden' >>"$W/etc/default/grub"
fkrun bash "$TK/verify.sh"; has "$OUT" "✘  nothing takes that key away"; cp "$TMP/grub.keep" "$W/etc/default/grub"
chmod -x "$W/etc/grub.d/12_menu_auto_hide"
fkrun bash "$TK/verify.sh"; has "$OUT" "✘  Shift (Esc/F8) at power-on shows the boot menu"; chmod +x "$W/etc/grub.d/12_menu_auto_hide"

done_
