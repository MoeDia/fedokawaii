#!/bin/bash
# render/grub.sh OUT.png — the boot menu, drawn by GRUB itself: the theme theme.sh installed
# (/boot/grub2/themes/sumi, for a 1920x1080 screen) on a GRUB 2.12 rescue CD booted in QEMU
# with UEFI firmware (OVMF), and the screen taken from QEMU's monitor while the countdown runs.
# The entries are the ones Fedora 44's grub.cfg lists on this desktop right after an update:
# the new kernel, the one before it (kept until the new one has started once; setup keeps no
# rescue entry), and the firmware settings.
# Needs: grub-mkrescue with the x86_64-efi modules, xorriso, mtools, qemu-system-x86_64, OVMF,
# python3 with Pillow (Ubuntu: grub-efi-amd64-bin grub-common xorriso mtools qemu-system-x86 ovmf).
set -euo pipefail
OUT=${1:?usage: render/grub.sh OUT.png}
THEME=${GRUB_THEME_DIR:-/boot/grub2/themes/sumi}
CODE=${OVMF_CODE:-/usr/share/OVMF/OVMF_CODE_4M.fd} VARS=${OVMF_VARS:-/usr/share/OVMF/OVMF_VARS_4M.fd}
W=$(mktemp -d); trap 'kill "$(cat "$W/qemu.pid" 2>/dev/null)" 2>/dev/null; rm -rf "$W"' EXIT
mkdir -p "$W/iso/boot/grub/themes"
cp -r "$THEME" "$W/iso/boot/grub/themes/sumi"
cat >"$W/iso/boot/grub/grub.cfg" <<'EOF'
# the screen as Fedora's grub.cfg sets it up (00_header), with theme.sh's settings
set gfxmode=1920x1080,auto
insmod all_video
insmod gfxterm
insmod png
loadfont ($root)/boot/grub/themes/sumi/fusion.pf2
terminal_output gfxterm
set theme=($root)/boot/grub/themes/sumi/theme.txt
export theme
set timeout_style=menu
set timeout=300
menuentry 'Fedora Linux (7.0.12-201.fc44.x86_64) 44 (Forty Four)' { true }
menuentry 'Fedora Linux (7.0.10-200.fc44.x86_64) 44 (Forty Four)' { true }
menuentry 'UEFI Firmware Settings' { fwsetup }
EOF
grub-mkrescue -o "$W/grub.iso" "$W/iso" >/dev/null 2>&1
cp "$VARS" "$W/vars.fd"
qemu-system-x86_64 -machine q35 -m 512 -display none -vga std \
  -drive "if=pflash,format=raw,readonly=on,file=$CODE" -drive "if=pflash,format=raw,file=$W/vars.fd" \
  -cdrom "$W/grub.iso" -monitor "unix:$W/mon.sock,server,nowait" -daemonize -pidfile "$W/qemu.pid"
# the menu is up once the screen is 1920 wide and nothing but the countdown's bar (a strip of
# GRUB's redrawing, under 32 px tall) changes between two frames: that frame is kept
python3 -I - "$W" "$OUT" <<'EOF'
import socket, sys, time
from PIL import Image, ImageChops
w, out = sys.argv[1], sys.argv[2]
def grab(p):
    s = socket.socket(socket.AF_UNIX); s.connect(f"{w}/mon.sock"); s.settimeout(3)
    try: s.recv(4096)
    except OSError: pass
    s.send(f"screendump {p}\n".encode()); time.sleep(1.0); s.close()
    return Image.open(p).convert("RGB")
last = None
for i in range(90):
    time.sleep(2)
    try: im = grab(f"{w}/f.ppm")
    except OSError: continue
    if im.size == (1920, 1080) and last is not None and last.size == im.size:
        box = ImageChops.difference(im, last).getbbox()
        if box is None or box[3] - box[1] <= 32:
            im.save(out); sys.exit(0)
    last = im
sys.exit("render/grub.sh: GRUB's menu never settled on a 1920x1080 screen")
EOF
