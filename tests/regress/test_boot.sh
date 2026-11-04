#!/usr/bin/env bash
# tests/regress/test_boot.sh — never again the boot's black box, its blinks and its splash drawn
# three times (r24-2, r24-40, r25-7, r26-fu-5). The arguments every boot entry gets (lib/common.sh,
# setup.sh writes them): simpledrm would start the splash on the firmware's screen and amdgpu would
# take it away, a mode change each. The menu itself is hidden unless asked for.
. "$(dirname "$0")/lib.sh"

eval "$(sed -n '/^BOOT_ARGS=(/,/)$/p; /^BOOT_ARGS_GONE=/p' "$REPO/lib/common.sh")"
args=" ${BOOT_ARGS[*]} " gone=" ${BOOT_ARGS_GONE[*]} "

case_ "the boot's arguments: quiet, the splash, no simpledrm, no plymouth.use-simpledrm"
has "$args" " rhgb " "no splash asked for"
has "$args" " quiet " "the kernel's words would show"
has "$args" " initcall_blacklist=simpledrm_platform_driver_init " "simpledrm back: the splash three times"
has "$gone" " plymouth.use-simpledrm " "an entry that still has it keeps its black flick"
lacks "$args" "plymouth.use-simpledrm" "it is back on the entries"
item "r24-2 r25-7 r26-fu-5" "${#BOOT_ARGS[@]} arguments, simpledrm off, plymouth.use-simpledrm taken off every entry"

case_ "the boot menu: hidden unless asked for, its countdown in our own ink"
s=$(sed -n 's/^BOOT_MENU_SECONDS="\([0-9]*\)".*/\1/p' "$REPO/fedokawaii.conf")
eq "$s" 0 "the menu shows at every boot"
hl=$(grep -E 'hl_c\.png' "$REPO/theme.sh")
has "$hl" '$INK_ACCENT' "the countdown's fill is not the palette's"
lacks "$(sed -n '/+ progress_bar/,/^    printf .+ label/p' "$REPO/theme.sh")" "orange"
item r24-40a "the menu shown for ${s:-?} s; its countdown the palette's accent"
done_
