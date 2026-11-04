#!/usr/bin/env bash
# tools/vm-iso-test.sh — the installer ISO proven in session VMs of its own, never on a real disk: it
# takes no device argument, it only ever makes a qcow2 under ~/VM/iso/vm/NAME, and it refuses a VM that
# is not its own (r27-iso*). Through the real screens: the firmware, GRUB, our questions typed with
# virsh send-key, the setup, the login. No answer file, nothing of the harness in the ISO: the VM's
# test marker, ssh and sudo reach the installed system through SMBIOS (systemd credentials), which a
# real PC never has.
#   bash tools/vm-iso-test.sh create NAME ISO [--disk GB] [--ram MIB] [--cpus N] [--port P] [--no-sb] [--bios] [--no-net] [--cd-first]
#   bash tools/vm-iso-test.sh start|stop|destroy|state NAME
#   bash tools/vm-iso-test.sh shot NAME OUT.png        the display, as it is
#   bash tools/vm-iso-test.sh keys NAME TEXT…          letters typed; words in <> are keys: <enter> <tab> <down>
#   bash tools/vm-iso-test.sh link NAME up|down        the network cable
#   bash tools/vm-iso-test.sh ssh NAME CMD…            on the installed system (user fk, the test's)
#   bash tools/vm-iso-test.sh install NAME [PASSWORD]  the questions answered through the screens
#   bash tools/vm-iso-test.sh run NAME ISO [--…]       one whole run: create, install, setup, login, verify, timed
# Exit: 0 as asked · 1 failed · 2 misuse.
set -u
here=$(cd "$(dirname "$0")" && pwd)
V=$HOME/VM/iso/vm
VIRSH=(virsh -c qemu:///session)
KEY=$HOME/VM/harness/id_ed25519
TEST_USER=fk
TEST_PASSWORD=${FK_TEST_PASSWORD:-kawaii-test}

die() { echo "vm-iso-test: $*" >&2; exit 1; }
name_ok() { [[ ${1:-} =~ ^r27-iso[a-z0-9-]*$ ]] || { echo "vm-iso-test: only VMs named r27-iso… are mine (got '${1:-}')" >&2; exit 2; }; }

credential() {   # credential NAME TEXT — an SMBIOS type 11 string systemd imports as a credential
  printf 'io.systemd.credential.binary:%s=%s' "$1" "$(printf '%s' "$2" | base64 -w0)"
}

do_create() {
  local name=$1 iso=$2; shift 2
  local disk=80 ram=8192 cpus=6 port="" sb=yes fw=efi link=up cdfirst=0
  while (($#)); do
    case $1 in
      --disk) disk=$2; shift 2 ;;
      --ram) ram=$2; shift 2 ;;
      --cpus) cpus=$2; shift 2 ;;
      --port) port=$2; shift 2 ;;
      --no-sb) sb=no; shift ;;
      --bios) fw=bios; shift ;;
      --no-net) link=down; shift ;;
      --cd-first) cdfirst=1; shift ;;
      *) echo "vm-iso-test: create: unknown option $1" >&2; exit 2 ;;
    esac
  done
  [[ -f $iso ]] || die "no ISO at $iso"
  iso=$(readlink -f "$iso")
  local d=$V/$name
  "${VIRSH[@]}" destroy "$name" >/dev/null 2>&1
  "${VIRSH[@]}" undefine "$name" --nvram >/dev/null 2>&1
  rm -rf "$d"; mkdir -p "$d"
  qemu-img create -q -f qcow2 "$d/disk.qcow2" "${disk}G" || die "qemu-img failed"
  [[ -n $port ]] || port=$((2230 + $(printf '%s' "$name" | cksum | cut -d' ' -f1) % 200))
  echo "$port" >"$d/port"
  local os
  if [[ $fw == efi ]]; then
    os="<os firmware='efi'><type arch='x86_64' machine='q35'>hvm</type>
      <firmware><feature enabled='$sb' name='secure-boot'/><feature enabled='$sb' name='enrolled-keys'/></firmware>
      <smbios mode='sysinfo'/></os>"
  else
    os="<os firmware='bios'><type arch='x86_64' machine='q35'>hvm</type><smbios mode='sysinfo'/></os>"
  fi
  local tmp sudoers pub
  pub=$(cat "$KEY.pub")
  sudoers="$TEST_USER ALL=(ALL) NOPASSWD: ALL"
  # the installed system's test side, by the VM's firmware alone (systemd-tmpfiles' extra lines at
  # each start, sshd wanted by a drop-in from the debug generator): the marker hw_test_vm reads, the
  # harness's key for ssh, sudo without a password. A real PC has none of this
  tmp="f /var/lib/fedokawaii/test-vm 0644 root root - 1
d /home/$TEST_USER/.ssh 0700 $TEST_USER $TEST_USER -
f+ /home/$TEST_USER/.ssh/authorized_keys 0600 $TEST_USER $TEST_USER - $pub
f+ /etc/sudoers.d/90-iso-test 0440 root root - $sudoers"
  local boot=""
  ((cdfirst)) && boot="<boot order='1'/>"
  cat >"$d/domain.xml" <<EOF
<domain type='kvm'>
  <name>$name</name>
  <memory unit='MiB'>$ram</memory>
  <vcpu>$cpus</vcpu>
  <sysinfo type='smbios'><oemStrings>
    <entry>$(credential tmpfiles.extra "$tmp")</entry>
    <entry>$(credential systemd.unit-dropin.multi-user.target "$(printf '[Unit]\nWants=sshd.service\n')")</entry>
  </oemStrings></sysinfo>
  $os
  <features><acpi/><apic/><smm state='on'/></features>
  <cpu mode='host-passthrough'/>
  <on_poweroff>destroy</on_poweroff><on_reboot>restart</on_reboot><on_crash>destroy</on_crash>
  <devices>
    <disk type='file' device='disk'><driver name='qemu' type='qcow2' discard='unmap' cache='unsafe'/>
      <source file='$d/disk.qcow2'/><target dev='vda' bus='virtio'/></disk>
    <disk type='file' device='cdrom'><driver name='qemu' type='raw'/><source file='$iso'/>
      <target dev='sda' bus='sata'/><readonly/>$boot</disk>
    <interface type='user'><backend type='passt'/><model type='virtio'/><link state='$link'/>
      <portForward proto='tcp' address='127.0.0.1'><range start='$port' to='22'/></portForward></interface>
    <video><model type='virtio' heads='1' primary='yes'><resolution x='1920' y='1080'/></model></video>
    <serial type='file'><source path='$d/serial.log'/><target port='0'/></serial>
    <input type='keyboard' bus='usb'/>
    <controller type='usb' model='qemu-xhci'/>
    <memballoon model='none'/>
  </devices>
</domain>
EOF
  "${VIRSH[@]}" define "$d/domain.xml" >/dev/null || die "virsh define failed: $d/domain.xml"
  echo "vm-iso-test: $name defined ($disk G, firmware $fw, Secure Boot $sb, network $link, ssh port $port)"
}

do_shot() {
  local name=$1 out=$2 t
  t=$(mktemp "$V/$name/shot.XXXXXX")
  "${VIRSH[@]}" screenshot "$name" "$t" >/dev/null 2>&1 || { rm -f "$t"; return 1; }
  python3 -I -c 'import sys; from PIL import Image; Image.open(sys.argv[1]).convert("RGB").save(sys.argv[2])' "$t" "$out"
  rm -f "$t"
}

# key names virsh's "linux" codeset takes, for a character of the US layout
send_char() {
  local name=$1 c=$2 k shift=""
  case $c in
    [a-z]) k=KEY_${c^^} ;;
    [A-Z]) k=KEY_$c; shift=KEY_LEFTSHIFT ;;
    [0-9]) k=KEY_$c ;;
    ' ') k=KEY_SPACE ;;
    -) k=KEY_MINUS ;;
    _) k=KEY_MINUS; shift=KEY_LEFTSHIFT ;;
    .) k=KEY_DOT ;;
    /) k=KEY_SLASH ;;
    *) echo "vm-iso-test: no key for '$c'" >&2; return 1 ;;
  esac
  "${VIRSH[@]}" send-key "$name" ${shift:+"$shift"} "$k" >/dev/null
  sleep 0.08
}

do_keys() {
  local name=$1; shift
  local a i
  for a in "$@"; do
    if [[ $a =~ ^\<([a-z0-9]+)\>$ ]]; then
      "${VIRSH[@]}" send-key "$name" "KEY_${BASH_REMATCH[1]^^}" >/dev/null || return 1
      sleep 0.2
    else
      for ((i = 0; i < ${#a}; i++)); do send_char "$name" "${a:i:1}" || return 1; done
    fi
  done
}

vm_ssh() {
  local name=$1; shift
  ssh -q -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 \
    -o ServerAliveInterval=15 -i "$KEY" -p "$(cat "$V/$name/port")" "$TEST_USER@127.0.0.1" "$*"
}

# wait_for NAME PNG-TEST SECONDS — until the display shows what the test says; tools/iso-shot.py knows them
wait_screen() {
  local name=$1 what=$2 secs=$3 end=$((SECONDS + $3)) t
  t=$V/$name/wait.png
  while ((SECONDS < end)); do
    if do_shot "$name" "$t" 2>/dev/null && python3 -I -B "$here/iso-shot.py" "$t" "$what"; then return 0; fi
    sleep 3
  done
  echo "vm-iso-test: $name: no '$what' screen within $secs s (last: $t)" >&2
  return 1
}

do_install() {
  local name=$1 pw=${2:-$TEST_PASSWORD}
  wait_screen "$name" form 600 || return 1
  sleep 1
  do_keys "$name" "$TEST_USER" "<enter>" "$pw" "<enter>" "$pw" "<enter>" "<down>" "<down>" "<down>" "<down>" "<enter>" || return 1
  sleep 1
  do_keys "$name" "<enter>"
}

cmd=${1:-}; [[ -n $cmd ]] && shift
case $cmd in
  create) name_ok "${1:-}"; [[ $# -ge 2 ]] || exit 2; do_create "$@" ;;
  start) name_ok "${1:-}"; "${VIRSH[@]}" start "$1" ;;
  stop) name_ok "${1:-}"; "${VIRSH[@]}" destroy "$1" ;;
  destroy) name_ok "${1:-}"; "${VIRSH[@]}" destroy "$1" >/dev/null 2>&1; "${VIRSH[@]}" undefine "$1" --nvram >/dev/null 2>&1; rm -rf "${V:?}/$1" ;;
  state) name_ok "${1:-}"; "${VIRSH[@]}" domstate "$1" ;;
  shot) name_ok "${1:-}"; do_shot "$1" "$2" ;;
  keys) name_ok "${1:-}"; do_keys "$@" ;;
  link) name_ok "${1:-}"; mac=$("${VIRSH[@]}" domiflist "$1" | awk 'NR > 2 && NF { print $5; exit }'); "${VIRSH[@]}" domif-setlink "$1" "$mac" "$2" >/dev/null ;;
  ssh) name_ok "${1:-}"; vm_ssh "$@" ;;
  install) name_ok "${1:-}"; do_install "$@" ;;
  *) sed -n '2,/^set -u/{/^set -u/d;s/^# \{0,1\}//;p}' "$0"; exit 2 ;;
esac
