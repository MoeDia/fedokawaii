#!/usr/bin/env bash
# tests/installer/test_theme_parts.sh — theme.sh's optional parts: the boot menu and console,
# and the C helpers kawa-veil and kawa-clipkeep. When one cannot be made the run goes on and
# says so, and --check counts it as optional (exit 4) until what it failed on changes (exit 3);
# once made, the marks go. Then mpv's scaling on an APU and Steam's overlay with STEAM=no.
. "$(dirname "$0")/lib.sh"
H=/home/fkuser
TK=/usr/local/lib/fedokawaii
theme() { fkrun bash "$TK/theme.sh" --user fkuser "$@"; }
tconf() { sed -i "$@" "$W$TK/fedokawaii.conf"; }   # the toolkit's settings, changed

world built
tconf 's/^WALLPAPER_PACK=.*/WALLPAPER_PACK="no"/'
keep plain

case_ "neither the boot menu (grub2-mkconfig fails) nor kawa-veil (its build fails) made: the rest is themed, exit 0, both said"
fkh rc-grub2-mkconfig 1; fkh rc-make-kawa-veil 2
theme; eq "$RC" 0
has "$OUT" "the boot menu and console were not themed"; has "$OUT" "kawa-veil did not build"
[[ -s $W/var/lib/fedokawaii/boot.failed ]] && _ok || _no "no boot.failed mark"
[[ -s $W$H/.local/state/fedokawaii/kawa-veil.failed ]] && _ok || _no "no kawa-veil.failed mark"
[[ -f $W$H/.config/foot/foot.ini && -x $W$H/.local/bin/kawa-clipkeep ]] && _ok || _no "the rest of the theme was not applied"
eq "$(fk stat -c %U /var/lib/fedokawaii/boot.failed)" root "the boot mark is root's (nothing of yours decides it)"

case_ "--check while nothing they depend on changed: exit 4 — in sync, both listed as not made here"
theme --check; eq "$RC" 4
has "$OUT" "✔ theme in sync"; has "$OUT" "! not made here"
has "$OUT" "grub.cfg"; has "$OUT" "kawa-veil did not build from src/kawa-veil"
case_ "verify takes exit 4 as passed, with a warning per part (it must not stop setup's gate for ever)"
fkrun bash "$TK/verify.sh" --pre-finalize
has "$OUT" "✔ every file in sync with the repo"; has "$OUT" "! "
lacks "$OUT" "✘ every file in sync"; lacks "$OUT" "boot menu theme installed" "the boot checks skipped"
has "$OUT" "boot menu: not themed here"; lacks "$OUT" "GRUB menu shown for"

case_ "once what they failed on changes (BOOT_MENU_SECONDS, kawa-veil's source): drift, exit 3"
tconf 's/^BOOT_MENU_SECONDS=.*/BOOT_MENU_SECONDS="5"/'
theme --check; eq "$RC" 3; has "$OUT" "grub"
tconf 's/^BOOT_MENU_SECONDS=.*/BOOT_MENU_SECONDS="2"/'
c=$(find "$W$TK/src/kawa-veil" -name '*.c' | head -n1); echo "/* an edit */" >>"$c"
theme --check; eq "$RC" 3; has "$OUT" "kawa-veil (not built from src/kawa-veil)"

case_ "the run once both work again: made, both marks gone, --check exit 0"
rm -f "$FKH/rc-grub2-mkconfig" "$FKH/rc-make-kawa-veil"
theme; eq "$RC" 0
[[ ! -e $W/var/lib/fedokawaii/boot.failed && ! -e $W$H/.local/state/fedokawaii/kawa-veil.failed ]] && _ok || _no "a mark left behind"
[[ -x $W$H/.local/bin/kawa-veil ]] && _ok || _no "kawa-veil not built"
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
[[ ! -e $W$H/.config/MangoHud ]] && _ok || _no "MangoHud config installed with STEAM=no"
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
