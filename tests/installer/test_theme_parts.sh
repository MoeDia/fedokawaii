#!/usr/bin/env bash
# tests/installer/test_theme_parts.sh — theme.sh's parts beyond the files: the C helpers
# kawa-veil and kawa-clipkeep (built like dwl: one that does not build stops the run), and the
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

case_ "kawa-veil does not build: the theme run stops and says so (a part of the desktop, as dwl)"
fkh rc-make-kawa-veil 2
theme; [[ $RC != 0 ]] && _ok || _no "exit 0 with kawa-veil not built"
has "$OUT" "kawa-veil failed to build from src/kawa-veil"
[[ ! -e $W$H/.local/state/fedokawaii/kawa-veil.failed ]] && _ok || _no "a mark that would pass it as optional"
case_ "--check after it: drift, exit 3 — never in sync"
theme --check; eq "$RC" 3; has "$OUT" "kawa-veil (not built from src/kawa-veil)"
rm -f "$FKH/rc-make-kawa-veil"

case_ "the boot menu not made (grub2-mkconfig fails): the rest is themed, exit 0, said"
fkh rc-grub2-mkconfig 1
theme; eq "$RC" 0
has "$OUT" "the boot menu and console were not themed"
[[ -s $W/var/lib/fedokawaii/boot.failed ]] && _ok || _no "no boot.failed mark"
[[ -f $W$H/.config/foot/foot.ini && -x $W$H/.local/bin/kawa-veil && -x $W$H/.local/bin/kawa-clipkeep ]] && _ok || _no "the rest of the theme was not applied"
eq "$(fk stat -c %U /var/lib/fedokawaii/boot.failed)" root "the boot mark is root's (nothing of yours decides it)"

case_ "--check while nothing it depends on changed: exit 4 — in sync, it listed as not made here"
theme --check; eq "$RC" 4
has "$OUT" "✔ theme in sync"; has "$OUT" "! not made here"; has "$OUT" "grub.cfg"
lacks "$OUT" "kawa-veil" "the helpers are never optional"
case_ "verify takes exit 4 as passed, with a warning (it must not stop setup's gate for ever)"
fkrun bash "$TK/verify.sh" --pre-finalize
has "$OUT" "✔ every file in sync with the repo"; has "$OUT" "! "
lacks "$OUT" "✘ every file in sync"; lacks "$OUT" "boot menu theme installed" "the boot checks skipped"
has "$OUT" "boot menu: not themed here"; lacks "$OUT" "GRUB menu shown for"
has "$OUT" "✔ file dialogs → yazi (FileChooser: termfilechooser, the only one)" "verify reads portals.conf as the theme writes it"

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

case_ "/boot a partition of its own (the installer's Btrfs layout): grub.cfg names the theme from /boot's root — in sync, and verify sees it"
touch "$FKH/boot-separate"; rm -f "$W/boot/grub2/grub.cfg"
theme; eq "$RC" 0
grep -qxF 'set theme=($root)/grub2/themes/sumi/theme.txt' "$W/boot/grub2/grub.cfg" && _ok || _no "grub.cfg: $(cat "$W/boot/grub2/grub.cfg")"
theme --check; eq "$RC" 0 "$(grep -i grub <<<"$OUT" | head -n2 | tr '\n' '|')"
reset_calls; theme; not_called grub2-mkconfig
fkrun bash "$TK/verify.sh" --pre-finalize
has "$OUT" "✔ boot menu theme installed"; lacks "$OUT" "✘ every file in sync"
rm -f "$FKH/boot-separate"; rm -f "$W/boot/grub2/grub.cfg"; theme; eq "$RC" 0

case_ "the boot menu: the console palette on every boot entry, BOOT_MENU_SECONDS shown, Fedora's auto-hide off"
has "$(cat "$FKH/grub-args")" "vt.default_red="; eq "$(grep -c 'vt.default_red=' "$FKH/grub-args")" 2 "both entries"
has "$(cat "$W/etc/default/grub")" "GRUB_TIMEOUT=2"; has "$(cat "$W/etc/default/grub")" 'GRUB_GFXMODE="2560x1440,auto"'
lacks "$(cat "$FKH/grubenv")" "menu_auto_hide=1"
has "$(cat "$W/etc/vconsole.conf")" 'FONT="ter-v32b"' "1440p: the larger console font"
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
lacks "$(cat "$FKH/grubenv")" "menu_auto_hide=1"
rm -f "$W/var/lib/fedokawaii/other-os"
case_ "BOOT_MENU_SECONDS=0: Fedora's hidden menu back"
theme
has "$(cat "$FKH/grubenv")" "menu_auto_hide=1"

case_ "an APU (512 MB of shared memory) and STEAM=no: mpv's own scaling, no game overlay config"
back plain; hw_apu; tconf 's/^STEAM=.*/STEAM="no"/'
theme; eq "$RC" 0
lacks "$(grep '^profile=' "$W$H/.config/mpv/mpv.conf")" "high-quality"
has "$(cat "$W$H/.config/mpv/mpv.conf")" "# scaling: mpv's own defaults"
[[ ! -e $W$H/.config/MangoHud && ! -e $W$H/.local/share/applications/steam.desktop ]] && _ok || _no "MangoHud config or Steam's entry installed with STEAM=no"
has "$(cat "$W/etc/vconsole.conf")" 'FONT="ter-v32b"'


case_ "Brave Origin's two launcher entries: its own runs the wrapper; the second (com.brave.Origin) hidden as Brave meant it (brave/brave-browser#52193)"
back plain
printf '[Desktop Entry]\nName=Brave Origin\nExec=/usr/bin/brave-origin-stable %%U\n\n[Desktop Action new-window]\nName=New Window\nExec=/usr/bin/brave-origin-stable\n' \
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
theme --check; lacks "$OUT" "com.brave.Origin" "in sync once made"
rm -f "$u/com.brave.Origin.desktop"
theme --check; has "$OUT" "com.brave.Origin.desktop" "a missing copy is drift"

done_
