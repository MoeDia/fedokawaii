#!/usr/bin/env bash
# tools/vm-create.sh — a test VM, installed unattended from Fedora's own install tree with a
# kickstart that reproduces the README's install (Minimal Install, US keyboard, Asia/Dubai, root
# disabled, an administrator) on THIS PC's disk layout: UEFI, GPT, /boot/efi vfat 600 M, /boot
# XFS 2 G (outside Btrfs), one Btrfs subvolume "root" for / with /home inside it — what setup.sh,
# snapper and the rollback really meet. A session VM (qemu:///session: yours, no root), passt
# networking with the guest's ssh on a local port, a virtio GPU (dwl draws there), the serial
# console logged. Its files live in ~/VM/harness/NAME/; the finished install becomes
# base.qcow2 (never written again) and every run uses an overlay over it (tools/vm-snap.sh).
#   bash tools/vm-create.sh NAME [--release 44] [--port 2222] [--ram 8192] [--cpus 6] [--disk 60]
# The guest: user dia with no password at all (locked: the harness key, ~/VM/harness/id_ed25519,
# and sudo without one); nothing of the owner's (his password, keys) ever goes in.
# Exit 0 ready (ssh answers) · 1 the install failed (the serial log says why) · 2 misuse.
set -u
name="" release=44 port=2222 ram=8192 cpus=6 disk=60
while (($#)); do
  case $1 in
    --release) release=$2; shift 2 ;;
    --port) port=$2; shift 2 ;;
    --ram) ram=$2; shift 2 ;;
    --cpus) cpus=$2; shift 2 ;;
    --disk) disk=$2; shift 2 ;;
    -h|--help) sed -n '2,/^set -u/{/^set -u/d;s/^# \{0,1\}//;p}' "$0"; exit 0 ;;
    -*) echo "vm-create: unknown option $1" >&2; exit 2 ;;
    *) name=$1; shift ;;
  esac
done
[[ $name =~ ^[a-z0-9-]+$ ]] || { echo "usage: bash tools/vm-create.sh NAME [--release 44] [--port 2222]" >&2; exit 2; }
H=$HOME/VM/harness
D=$H/$name
[[ -e $D ]] && { echo "vm-create: $D exists — tools/vm-snap.sh $name destroy first" >&2; exit 2; }
for t in virt-install virsh qemu-img ssh-keygen; do
  command -v "$t" >/dev/null || { echo "vm-create: $t is missing (fedokawaii repair installs PKG_VIRT)" >&2; exit 2; }
done
# ~/VM: a Btrfs subvolume of its own, so the system's snapshots never carry VM disks
if [[ ! -d $HOME/VM ]]; then
  if [[ $(stat -f -c %T "$HOME") == btrfs ]]; then btrfs subvolume create "$HOME/VM" >/dev/null || exit 2
  else mkdir -p "$HOME/VM"; fi
fi
mkdir -p "$D" && chmod 700 "$H"
[[ -f $H/id_ed25519 ]] || ssh-keygen -q -t ed25519 -N "" -C "fedokawaii-harness" -f "$H/id_ed25519" || exit 2
# Fedora's master server itself (dl.fedoraproject.org): the mirror redirector handed a mirror
# that refused the installer's initrd (403) — the master is fast here (27 MB/s) and never stale
fp=https://dl.fedoraproject.org/pub/fedora/linux
case $release in
  rawhide) tree=$fp/development/rawhide/Everything/x86_64/os/ updates="" ;;
  *) tree=$fp/releases/$release/Everything/x86_64/os/ updates=$fp/updates/$release/Everything/x86_64/ ;;
esac
curl -sfL --max-time 60 -o /dev/null "$tree.treeinfo" || { echo "vm-create: no install tree at $tree" >&2; exit 1; }
cat >"$D/ks.cfg" <<EOF
# the harness's kickstart (tools/vm-create.sh): the README's install, this PC's layout
text
lang en_US.UTF-8
keyboard us
timezone Asia/Dubai --utc
network --bootproto=dhcp --hostname=fk-$name --activate
rootpw --lock
user --name=dia --groups=wheel --lock
sshkey --username=dia "$(cat "$H/id_ed25519.pub")"
url --url=$tree
${updates:+repo --name=updates --baseurl=$updates}
firstboot --disable
selinux --enforcing
bootloader --timeout=1
zerombr
clearpart --all --initlabel --disklabel=gpt
part /boot/efi --fstype=efi --size=600
part /boot --fstype=xfs --size=2048
part btrfs.01 --fstype=btrfs --grow
btrfs none --label=fedora btrfs.01
btrfs / --subvol --name=root fedora
services --enabled=sshd
%packages
@^custom-environment
openssh-server
%end
%post
echo 'dia ALL=(ALL) NOPASSWD: ALL' >/etc/sudoers.d/90-harness
chmod 440 /etc/sudoers.d/90-harness
%end
poweroff
EOF
echo "vm-create: $name — Fedora $release from $tree (serial log: $D/serial.log)"
virt-install --connect qemu:///session --name "fk-$name" --osinfo detect=on,require=off \
  --memory "$ram" --vcpus "$cpus" --cpu host-passthrough --boot uefi \
  --disk "path=$D/disk.qcow2,size=$disk,format=qcow2,bus=virtio" \
  --location "$tree" --initrd-inject "$D/ks.cfg" \
  --extra-args "inst.ks=file:/ks.cfg inst.text console=ttyS0,115200" \
  --network "passt,portForward=127.0.0.1:$port:22" --video virtio --graphics none \
  --serial "file,path=$D/serial.log" --noautoconsole --noreboot --wait -1 >"$D/virt-install.log" 2>&1
rc=$?
state=$(virsh -c qemu:///session domstate "fk-$name" 2>/dev/null)
if ((rc != 0)) || [[ $state != "shut off" ]]; then
  echo "vm-create: the install did not end cleanly (virt-install $rc, the VM $state) — $D/virt-install.log, $D/serial.log" >&2
  exit 1
fi
# the finished install is the base: read-only from now on, every run an overlay over it
mv "$D/disk.qcow2" "$D/base.qcow2" && chmod a-w "$D/base.qcow2"
qemu-img create -q -f qcow2 -b "$D/base.qcow2" -F qcow2 "$D/disk.qcow2" || exit 1
nv=$(virsh -c qemu:///session dumpxml "fk-$name" | sed -n 's|.*<nvram[^>]*>\(.*\)</nvram>.*|\1|p')
[[ -n $nv && -f $nv ]] && cp --reflink=auto "$nv" "$D/nvram.base.fd"
echo "$port" >"$D/port"
virsh -c qemu:///session start "fk-$name" >/dev/null || exit 1
for _ in $(seq 120); do
  ssh -q -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=3 \
    -i "$H/id_ed25519" -p "$port" dia@127.0.0.1 true 2>/dev/null && { echo "vm-create: fk-$name ready (ssh -p $port)"; exit 0; }
  sleep 5
done
echo "vm-create: fk-$name booted but ssh never answered — $D/serial.log" >&2
exit 1
