#!/usr/bin/env bash
# tools/build-iso.sh — the fedokawaii installer: one bootable ISO, reproducible, as a normal user.
#   bash tools/build-iso.sh [--ref REF] [--out DIR] [--dev]
#     --ref REF   the commit whose toolkit goes in (default HEAD; its time is the ISO's: SOURCE_DATE_EPOCH)
#     --out DIR   where the ISO goes (default ~/VM/iso/out)
#     --dev       an installer you can enter over ssh (inst.sshd): for working on it, never to publish
# Fedora's netinst, its signed shim, GRUB and kernel untouched (Secure Boot stays on), replayed by
# xorriso with only what nobody signs changed: the menu's grub.cfg, a kickstart, our screens as
# images/product.img (Anaconda overlays it on its stage 2), the boot splash as a second initrd, the
# toolkit as a tarball in the first. Same inputs (iso/inputs.sh) and same commit = the same bytes.
# Written up in .claude/notes/iso-design.md. Needs: xorriso, mtools, cpio, xz, git, curl, python3-pillow.
# Exit: 0 built (fedokawaii-DATE-COMMIT.iso + .sha256) · 1 failed (the line above says why) · 2 misuse.
set -Eeuo pipefail
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/.." && pwd)
ref=HEAD out=$HOME/VM/iso/out dev=0
while (($#)); do
  case $1 in
    --ref) ref=$2; shift 2 ;;
    --out) out=$2; shift 2 ;;
    --dev) dev=1; shift ;;
    -h|--help) sed -n '2,/^set -E/{/^set -E/d;s/^# \{0,1\}//;p}' "$0"; exit 0 ;;
    *) echo "build-iso: unknown option $1" >&2; exit 2 ;;
  esac
done
for t in xorriso mcopy mdir cpio xz git curl rpm2cpio python3 sha256sum; do
  command -v "$t" >/dev/null || { echo "build-iso: $t is missing" >&2; exit 1; }
done
# shellcheck source=iso/inputs.sh
source "$repo/iso/inputs.sh"
cache=$HOME/VM/iso/in
mkdir -p "$cache/rpm" "$out"
commit=$(git -C "$repo" rev-parse --verify "$ref^{commit}")
export SOURCE_DATE_EPOCH
SOURCE_DATE_EPOCH=$(git -C "$repo" log -1 --format=%ct "$commit")
stamp=$(date -u -d "@$SOURCE_DATE_EPOCH" +%Y%m%d)
work=$(mktemp -d "$HOME/VM/iso/build.XXXXXX")
trap 'rm -rf "$work"' EXIT
trap 'echo "build-iso: stopped at line $LINENO: $BASH_COMMAND (status ${PIPESTATUS[*]})" >&2' ERR
say() { printf '%s %s\n' "$(date +%T)" "$*"; }

# ── the inputs, each by its checksum ─────────────────────────────────────────
fetch() {   # fetch URL FILE SHA256 — from the cache, or the network; never a file that does not match
  local url=$1 f=$2 sum=$3
  if [[ ! -s $f ]]; then curl -sSfL --retry 3 --max-time 3600 -o "$f.part" "$url"; mv "$f.part" "$f"; fi
  [[ $(sha256sum "$f" | cut -d' ' -f1) == "$sum" ]] || { echo "build-iso: $f is not the pinned file (sha256)" >&2; exit 1; }
}
# (the release must be the newest stable: a newer one is a new pin, after its VM pre-flight)
newest=$(curl -sSf --max-time 30 https://fedoraproject.org/releases.json \
  | python3 -Ic 'import json, sys; print(max(int(r["version"]) for r in json.load(sys.stdin) if r["version"].isdigit()))')
[[ $newest == "$ISO_RELEASE" ]] || { echo "build-iso: Fedora $newest is the newest stable, the pin says $ISO_RELEASE (iso/inputs.sh)" >&2; exit 1; }
say "inputs: $ISO_NETINST, commit ${commit:0:12}"
netinst=$cache/$ISO_NETINST
fetch "$ISO_NETINST_URL" "$netinst" "$ISO_NETINST_SHA256"
mkdir "$work/rpm"
for r in "${ISO_RPMS[@]}"; do
  n=${r% *}
  sub=$(printf '%.1s' "$n")
  fetch "$ISO_RPM_URL/$sub/$n" "$cache/rpm/$n" "${r#* }"
  rpm2cpio "$cache/rpm/$n" | (cd "$work/rpm" && cpio -idm --quiet)
done

# ── the pictures ─────────────────────────────────────────────────────────────
# (from the commit, not the working tree: the same bytes whatever lies around)
mkdir "$work/src"
git -C "$repo" archive "$commit" -- art system tools iso lib configs/home/.local/share/fedokawaii/dark/lock-scene.png | tar -xf - -C "$work/src"
python3 -B "$work/src/tools/build-iso-art.py" "$work/art" "fedokawaii $(date -u -d "@$SOURCE_DATE_EPOCH" +%Y.%m.%d) · ${commit:0:7} · Fedora $ISO_RELEASE"

# reproducible <dir> <out>: a directory as a newc cpio, sorted, its times the commit's, root's
reproducible() {
  find "$1" -exec touch -h -d "@$SOURCE_DATE_EPOCH" {} +
  (cd "$1" && find . -print0 | LC_ALL=C sort -z | cpio --null --quiet -o -H newc -R 0:0 --reproducible) >"$2"
}

# ── the toolkit ──────────────────────────────────────────────────────────────
say "the toolkit"
# (what the system needs, not the round's own notes and tooling)
git -C "$repo" archive --format=tar "$commit" -- . ':(exclude).claude' ':(exclude)CLAUDE.md' \
  ':(exclude)tools/claude-loop.sh' ':(exclude)tools/start.sh' | xz -T1 -6 --check=crc32 >"$work/toolkit.tar.xz"

# ── stage 2's files: images/product.img ─────────────────────────────────────
say "images/product.img"
p=$work/product/usr/share/fedokawaii-iso
mkdir -p "$p" "$work/product/etc/systemd/system"
# (Anaconda ends without a reboot, an early crash: its second copy, under tmux, would run %pre again and
# ask everything again. It cannot be masked, anaconda-direct requires it: in its place, the failure's page)
mkdir -p "$work/product/etc/systemd/system/anaconda.service.d"
printf '%s\n' '[Service]' 'Type=oneshot' 'ExecStart=' 'ExecStart=/usr/bin/python3 /usr/share/fedokawaii-iso/failed.py --if-unfinished' \
  >"$work/product/etc/systemd/system/anaconda.service.d/fedokawaii.conf"
# (the console's font is ours from the first screen: Anaconda's keyboard step reloads it through localed)
ln -s /dev/null "$work/product/etc/systemd/system/systemd-vconsole-setup.service"
cp "$work/src/iso/screens/"* "$p/"
cp "$work/art/console/sumi-console.psf" "$work/art/console/glyphs.py" "$p/"
cp "$work/toolkit.tar.xz" "$p/"
(cd "$work" && sha256sum toolkit.tar.xz) >"$p/toolkit.sha256"
# (anaconda.target wants plymouth-quit: the picture must stay until our first page is ready behind it)
ln -s /dev/null "$work/product/etc/systemd/system/plymouth-quit.service"
ln -s /dev/null "$work/product/etc/systemd/system/plymouth-quit-wait.service"
# the answers file's kernel arguments (the palette from the dark theme, the boot's own from lib/common.sh)
eval "$(sed -n '/^BOOT_ARGS=(/,/)$/p' "$work/src/lib/common.sh")"
pal=$(python3 -B - "$work/src" <<'PY'
import importlib.util
import pathlib
import sys
sys.dont_write_bytecode = True
s = importlib.util.spec_from_file_location("themes", pathlib.Path(sys.argv[1]) / "tools/build-themes.py")
m = importlib.util.module_from_spec(s)
s.loader.exec_module(m)
p = m.P["dark"]
inks = [p["ground"]] + [p[k] for k in ("red", "green", "yellow", "blue", "purple", "teal", "ansi7", "ansi8",
                                       "bred", "bgreen", "byellow", "bblue", "bpurple", "bteal", "ansi15")]
print(" ".join("vt.default_%s=%s" % (n, ",".join(str(int(c[o:o + 2], 16)) for c in inks))
               for n, o in (("red", 0), ("grn", 2), ("blu", 4))))
PY
)
sed -i "s|@APPEND@|${BOOT_ARGS[*]} $pal|" "$p/questions.py"
# (a release of fedokawaii: the update button knows which one this is, and takes the next)
git -C "$repo" describe --tags --exact-match --match 'v*' "$commit" 2>/dev/null >"$p/toolkit-release" || : >"$p/toolkit-release"
reproducible "$work/product" "$work/product.cpio"
gzip -n -9 <"$work/product.cpio" >"$work/product.img"

# ── the first stage's splash: a second initrd ───────────────────────────────
say "the boot splash"
b=$work/boot
mkdir -p "$b/usr/lib64/plymouth/renderers" "$b/usr/share/plymouth/themes/sumi" "$b/etc/plymouth"
cp -a "$work/rpm/usr/lib64/plymouth/script.so" "$b/usr/lib64/plymouth/"
cp -a "$work/rpm/usr/lib64/plymouth/renderers/"*.so "$b/usr/lib64/plymouth/renderers/"
cp -a "$work/rpm/usr/lib64/plymouth/label-freetype.so" "$b/usr/lib64/plymouth/"
for l in libply-splash-graphics libpng16 libdrm libfreetype libharfbuzz libgraphite2; do cp -a "$work/rpm/usr/lib64/$l".so* "$b/usr/lib64/"; done
# (where the freetype label looks for its font: no text is ever drawn with it, the viewer just has to exist)
mkdir -p "$b/usr/share/fonts"
cp "$work/src/system/fonts/SumiUI.ttf" "$b/usr/share/fonts/Plymouth.ttf"
cp "$work/src/system/fonts/SumiUI.ttf" "$b/usr/share/fonts/Plymouth-monospace.ttf"
cp "$work/art/plymouth/"* "$b/usr/share/plymouth/themes/sumi/"
printf '%s\n' '[Daemon]' 'Theme=sumi' 'ShowDelay=0' 'DeviceTimeout=8' >"$b/etc/plymouth/plymouthd.conf"
ln -s sumi/sumi.plymouth "$b/usr/share/plymouth/themes/default.plymouth"
# (a module Anaconda's first stage asks for by name, whose absence it writes across the first seconds)
mkdir -p "$b/etc/modprobe.d"
printf 'install edd :\n' >"$b/etc/modprobe.d/fedokawaii.conf"
reproducible "$b" "$work/boot.cpio"
xz -T1 --check=crc32 -6 <"$work/boot.cpio" >"$work/fedokawaii-boot.img"

# ── the menu and the kickstart ──────────────────────────────────────────────
say "the menu and the kickstart"
args="inst.stage2=hd:LABEL=$ISO_VOLID inst.ks=hd:LABEL=$ISO_VOLID:/ks.cfg inst.text inst.notmux inst.noshell inst.geoloc=0 inst.nosave=input_ks,output_ks console=tty1 rhgb quiet loglevel=3 rd.udev.log_level=3 systemd.show_status=false vt.global_cursor_default=0 $pal"
if ((dev)); then args+=" inst.sshd plymouth.debug"; fi
sed -e "s|@VOLID@|$ISO_VOLID|g" -e "s|@ARGS@|$args|g" -e "s|@GROUND@|$(cat "$work/art/ground")|g" "$work/src/iso/grub.cfg" >"$work/grub.cfg"
sed -e "s|@RELEASE@|$ISO_RELEASE|g" "$work/src/iso/ks.cfg" >"$work/ks.cfg"
if ((dev)); then sed -i '1i sshpw --username=root --plaintext fk' "$work/ks.cfg"; fi
touch -d "@$SOURCE_DATE_EPOCH" "$work/grub.cfg"

# ── the EFI partition: only its grub.cfg changes (nothing signed) ───────────
# (where the netinst keeps it: GPT partition 2, read from the image itself)
read -r esp_lba esp_n < <(xorriso -indev "$netinst" -report_system_area plain 2>/dev/null \
  | awk '$1 == "GPT" && $2 == "start" && $6 == "2" { print $7, $8 }')
dd if="$netinst" of="$work/esp.img" bs=512 skip="$esp_lba" count="$esp_n" status=none
mcopy -o -m -i "$work/esp.img" "$work/grub.cfg" ::/EFI/BOOT/grub.cfg
mcopy -o -m -i "$work/esp.img" "$work/grub.cfg" ::/EFI/BOOT/BOOT.conf

# ── the stick's check: a sum for every file of the ISO's own tree ───────────
# (not Fedora's checkisomd5: it sums sectors, and firmware or an automount rewrites a few on a good
# stick, Fedora's own "media check fails at 4.8 %", bug 2420697. Read per file, %pre's meter on it)
sums=$cache/$ISO_NETINST.sums
if [[ ! -s $sums ]]; then
  say "the sums of the netinst's files, once"
  xorriso -no_rc -osirrox on -indev "$netinst" -extract / "$work/tree" >/dev/null 2>&1
  (cd "$work/tree" && find . -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum) >"$sums"
  chmod -R u+w "$work/tree"; rm -rf "$work/tree"
fi
mine=$work/mine
mkdir -p "$mine/EFI/BOOT" "$mine/boot/grub2/x86_64-efi" "$mine/boot/grub2/themes" "$mine/images/pxeboot"
cp "$work/ks.cfg" "$mine/ks.cfg"
cp "$work/product.img" "$mine/images/product.img"
cp "$work/fedokawaii-boot.img" "$mine/images/pxeboot/fedokawaii-boot.img"
cp "$work/grub.cfg" "$mine/EFI/BOOT/grub.cfg"
cp "$work/grub.cfg" "$mine/EFI/BOOT/BOOT.conf"
cp "$work/grub.cfg" "$mine/boot/grub2/grub.cfg"
cp "$work/rpm/usr/lib/grub/x86_64-efi/gfxterm_background.mod" "$mine/boot/grub2/x86_64-efi/"
cp -r "$work/art/grub" "$mine/boot/grub2/themes/fedokawaii"
# (not the three files we replace, nor the BIOS boot image: xorriso writes its boot table into that one)
{ grep -vE '  \./(EFI/BOOT/(grub\.cfg|BOOT\.conf)|boot/grub2/grub\.cfg|images/eltorito\.img)$' "$sums"
  (cd "$mine" && find . -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum); } | LC_ALL=C sort -k2 >"$work/fk-sums"

# ── the ISO ─────────────────────────────────────────────────────────────────
iso=$out/fedokawaii-$stamp-${commit:0:7}.iso
say "the ISO: $iso"
rm -f "$iso"
xorriso -no_rc -indev "$netinst" -outdev "$iso" -boot_image any replay \
  -append_partition 2 C12A7328-F81F-11D2-BA4B-00A0C93EC93B "$work/esp.img" \
  -update "$work/grub.cfg" /EFI/BOOT/grub.cfg \
  -update "$work/grub.cfg" /EFI/BOOT/BOOT.conf \
  -update "$work/grub.cfg" /boot/grub2/grub.cfg \
  -map "$work/fk-sums" /fk-sums \
  -map "$work/ks.cfg" /ks.cfg \
  -map "$work/product.img" /images/product.img \
  -map "$work/fedokawaii-boot.img" /images/pxeboot/fedokawaii-boot.img \
  -map "$work/art/grub" /boot/grub2/themes/fedokawaii \
  -map "$work/rpm/usr/lib/grub/x86_64-efi/gfxterm_background.mod" /boot/grub2/x86_64-efi/gfxterm_background.mod \
  -alter_date_r b "=$SOURCE_DATE_EPOCH" / -- \
  >"$work/xorriso.log" 2>&1 || { tail -n 20 "$work/xorriso.log" >&2; exit 1; }
# (what the drive gives back is what was meant to go in: the check a stick gets, here first)
xorriso -no_rc -osirrox on -indev "$iso" -extract / "$work/back" >/dev/null 2>&1
(cd "$work/back" && sha256sum --quiet --strict -c "$work/fk-sums") >&2 \
  || { echo "build-iso: the ISO does not read back as written" >&2; rm -f "$iso"; exit 1; }
chmod -R u+w "$work/back"; rm -rf "$work/back"
(cd "$out" && sha256sum "${iso##*/}") >"$iso.sha256"
say "built: $(cut -c1-16 "$iso.sha256") $(stat -c %s "$iso") bytes"
