#!/usr/bin/env bash
# tools/vm-iso-test.sh — the installer ISO proven in session VMs of its own, never on a real disk: it
# takes no device argument, it only ever makes a qcow2 under ~/VM/iso/vm/NAME, and it refuses a VM that
# is not its own (r27-iso*). Through the real screens: the firmware, GRUB, our questions typed with
# virsh send-key, the setup, the login. No answer file, nothing of the harness in the ISO: the VM's
# test marker, ssh and sudo reach the installed system through SMBIOS (systemd credentials), which a
# real PC never has.
#   bash tools/vm-iso-test.sh create NAME ISO [--disk GB] [--ram MIB] [--cpus N] [--port P] [--no-sb] [--bios] [--no-net] [--cd-first] [--usb QCOW2]
#   bash tools/vm-iso-test.sh start|stop|destroy|state NAME
#   bash tools/vm-iso-test.sh shot NAME OUT.png        the display, as it is
#   bash tools/vm-iso-test.sh keys NAME TEXT…          letters typed; words in <> are keys: <enter> <tab> <down>
#   bash tools/vm-iso-test.sh link NAME up|down        the network cable
#   bash tools/vm-iso-test.sh ssh NAME CMD…            on the installed system (user fk, the test's)
#   bash tools/vm-iso-test.sh say NAME [WORDS]         what the console says, read exactly; with WORDS: are they there
#   bash tools/vm-iso-test.sh install NAME [PASSWORD]  the questions answered through the screens
#   bash tools/vm-iso-test.sh watch NAME DIR [SECONDS] the display as PNGs, one each time it changes, until stopped
#   bash tools/vm-iso-test.sh run NAME ISO [--…]       one whole run: create, install, setup, login, verify, timed
#   bash tools/vm-iso-test.sh follow NAME              the same from the installed system's first start on
#   bash tools/vm-iso-test.sh matrix ISO DIR           the refusals and the stick's check: small VMs, read exactly
#   bash tools/vm-iso-test.sh midway ISO DIR           an install cut off: the reset, the mirrors gone
#   bash tools/vm-iso-test.sh again NAME ISO           the same VM and disk, started from a stick again
#   bash tools/vm-iso-test.sh over NAME ISO            a whole run over a finished install (`i` on that page)
#   bash tools/vm-iso-test.sh path NAME QCOW2          after a run: his things back, the update button, verify
#   bash tools/vm-iso-test.sh carry-save NAME QCOW2    test files packed by kawa-carry to a new USB drive
#   bash tools/vm-iso-test.sh carry-check NAME QCOW2   brought back from it (a VM made with --usb QCOW2), compared
# A run's record lands in ~/VM/iso/vm/NAME/run/ (its log, the screens, verify's output), a line per stage.
# Exit: 0 as asked · 1 failed · 2 misuse.
set -u
here=$(cd "$(dirname "$0")" && pwd)
V=$HOME/VM/iso/vm
VIRSH=(virsh -c qemu:///session)
KEY=$HOME/VM/harness/id_ed25519
TEST_USER=fk
TEST_PASSWORD=${FK_TEST_PASSWORD:-kawaii-test}

die() { echo "vm-iso-test: $*" >&2; exit 1; }
# (the PC is shared: a VM starts only with room for it and 3 GiB to spare, and never beside another of
# this tool's: a global OOM killed every VM on 4 Nov 18:15; the owner's rule since: one at a time, 4 GiB)
mem_guard() {
  local name=$1 want have
  if "${VIRSH[@]}" list --name | grep -E '^r27-iso' | grep -qvxF "$name"; then
    die "another VM of this lane is running: $("${VIRSH[@]}" list --name | grep -E '^r27-iso' | tr '\n' ' ')"
  fi
  want=$(sed -n "s|.*<memory unit='MiB'>\([0-9]*\)<.*|\1|p" "$V/$name/domain.xml")
  for _ in $(seq 180); do
    have=$(awk '/^MemAvailable/ { print int($2 / 1024) }' /proc/meminfo)
    ((have >= want + 3072)) && return 0
    echo "vm-iso-test: waiting for memory (${have} MiB free, $want + 3072 wanted)" >&2
    sleep 20
  done
  die "no memory for $name: $have MiB free"
}
name_ok() { [[ ${1:-} =~ ^r27-iso[a-z0-9-]*$ ]] || { echo "vm-iso-test: only VMs named r27-iso… are mine (got '${1:-}')" >&2; exit 2; }; }

credential() {   # credential NAME TEXT — an SMBIOS type 11 string systemd imports as a credential
  printf 'io.systemd.credential.binary:%s=%s' "$1" "$(printf '%s' "$2" | base64 -w0)"
}

do_create() {
  local name=$1 iso=$2; shift 2
  local disk=80 ram=4096 cpus=6 port="" sb=yes fw=efi link=up cdfirst=0 usb=""     # (the owner, 18:15: 4 GiB at most)
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
      --usb) usb=$2; shift 2 ;;
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
    os="<os><type arch='x86_64' machine='q35'>hvm</type><smbios mode='sysinfo'/></os>"
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
  # (built as the PC is, GPU=amd, as tools/vm-smoke.sh builds: the same packages, so what is proven is his)
  local resume
  resume=$(printf '%s\n' '[Service]' "ExecStartPre=-/usr/bin/sed -i 's/^GPU=\"auto\"/GPU=\"amd\"/' /usr/local/lib/fedokawaii/fedokawaii.conf")
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
    <entry>$(credential systemd.unit-dropin.fedokawaii-resume.service "$resume")</entry>
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
    ${usb:+<disk type='file' device='disk'><driver name='qemu' type='qcow2' cache='unsafe'/><source file='$usb'/><target dev='sdb' bus='usb'/></disk>}
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

# the console font, made as the builder makes it: what do_say reads the screen with
console_font() {
  local f=$V/.art/console/sumi-console.psf
  if [[ ! -s $f || $here/build-iso-art.py -nt $f ]]; then
    rm -rf "$V/.art"; mkdir -p "$V"
    SOURCE_DATE_EPOCH=1 python3 -B "$here/build-iso-art.py" "$V/.art" >/dev/null || return 1
  fi
  printf '%s\n' "$f"
}

do_say() {   # do_say NAME [WORDS] — the console's words now, or: are WORDS among them
  local name=$1 t f; shift
  f=$(console_font) || return 1
  t=$V/$name/say.png
  do_shot "$name" "$t" 2>/dev/null || return 1
  python3 -I -B "$here/iso-shot.py" "$t" "$f" "$@"
}

# wait_words NAME WORDS SECONDS — until the console says so
wait_words() {
  local name=$1 what=$2 end=$((SECONDS + $3))
  while ((SECONDS < end)); do
    do_say "$name" "$what" 2>/dev/null && return 0
    sleep 2
  done
  echo "vm-iso-test: $name: no '$what' on the screen within $3 s (last: $V/$name/say.png)" >&2
  return 1
}

do_install() {
  local name=$1 pw=${2:-$TEST_PASSWORD}
  wait_words "$name" "a new home" 600 || return 1
  # (Alt+F2 moves nothing; F2 from any row: the keyboards, and back)
  "${VIRSH[@]}" send-key "$name" KEY_LEFTALT KEY_F2 >/dev/null; sleep 1
  do_say "$name" "a new home" || { echo "vm-iso-test: Alt+F2 moved the screen" >&2; return 1; }
  do_keys "$name" "<f2>"
  wait_words "$name" "type to filter" 10 || { echo "vm-iso-test: F2 opened no keyboards" >&2; return 1; }
  do_keys "$name" "<esc>"
  wait_words "$name" "a new home" 10 || return 1
  do_keys "$name" "$TEST_USER" "<enter>" "$pw" "<enter>" "$pw" "<enter>" "<down>" "<down>" "<down>" "<down>" "<enter>" || return 1
  wait_words "$name" "will be erased" 20 || return 1
  do_keys "$name" "<enter>"
}

do_watch() {   # the display as PNGs, one each time it changes
  local name=$1 dir=$2 iv=${3:-2} last="" sum t
  mkdir -p "$dir"
  while "${VIRSH[@]}" domstate "$name" >/dev/null 2>&1; do
    t=$(date +%H%M%S)
    if do_shot "$name" "$dir/.new.png" 2>/dev/null; then
      sum=$(md5sum <"$dir/.new.png")
      if [[ $sum != "$last" ]]; then mv "$dir/.new.png" "$dir/$t.png"; last=$sum; fi
    fi
    sleep "$iv"
  done
}

# one whole run, through the real screens: the times are from the first boot to the login screen
stage() { printf '%s %6d s  %s\n' "$(date +%T)" "$((SECONDS - T0))" "$*" | tee -a "$R/log"; }
do_run() {
  local name=$1 iso=$2; shift 2
  do_create "$name" "$iso" "$@" || return 1
  R=$V/$name/run T0=$SECONDS
  mkdir -p "$R"
  mem_guard "$name"
  "${VIRSH[@]}" start "$name" >/dev/null || return 1
  stage "started: $(sha256sum "$iso" | cut -c1-16)"
  setsid -f bash "$0" watch "$name" "$R/screens" 3 >/dev/null 2>&1 </dev/null
  do_install "$name" || { stage "RED: the questions"; return 1; }
  stage "questions answered"
  do_follow "$name"
}

# do_follow NAME — from the installer's end to the desktop: the first start, setup's phases, the login,
# verify. A setup that stopped shows it on its own screen: RED with its reason, and `follow` carries on
# after a fix (a key restarts the VM). Timed from the run's start, or this follow's.
do_follow() {
  local name=$1 last="" ph since=$SECONDS
  R=$V/$name/run; mkdir -p "$R"
  [[ -n ${T0:-} ]] || T0=$SECONDS
  until vm_ssh "$name" true 2>/dev/null; do
    ((SECONDS - T0 > 3600)) && { stage "RED: the installed system never answered"; return 1; }
    "${VIRSH[@]}" domstate "$name" | grep -q running || "${VIRSH[@]}" start "$name" >/dev/null 2>&1
    sleep 5
  done
  stage "the installed system answers"
  while :; do
    ((SECONDS - T0 > 21600)) && { stage "RED: setup not done after 6 h (phase $last)"; return 1; }
    sleep 20
    ph=$(vm_ssh "$name" 'sudo head -n1 /var/lib/fedokawaii/phase 2>/dev/null') || continue
    if [[ $ph != "$last" ]]; then stage "phase: ${ph:-none yet}"; last=$ph; since=$SECONDS; fi
    [[ $ph == "done" ]] && break
    # (FK_SLOW_BEFORE=N: until setup's phase N a slow, far line, again after every restart: passt has no shaping)
    if [[ -n ${FK_SLOW_BEFORE:-} && ( -z $ph || $ph -lt $FK_SLOW_BEFORE ) ]]; then
      vm_ssh "$name" 'd=$(ip route show default | cut -d" " -f5 | head -n1); command -v tc >/dev/null && sudo tc qdisc replace dev "$d" root netem delay 100ms rate 20mbit' 2>/dev/null
    fi
    # (FK_RESET_PHASE: the power pulled once, a minute into that phase: setup carries on by itself)
    if [[ ${FK_RESET_PHASE:-} == "$ph" ]] && ((SECONDS - since > 60)); then
      stage "the reset, in phase $ph"
      "${VIRSH[@]}" reset "$name" >/dev/null
      FK_RESET_PHASE=""
      sleep 30
    fi
    if do_say "$name" "setup stopped" 2>/dev/null; then
      do_say "$name" >"$R/stopped.txt" 2>/dev/null
      vm_ssh "$name" 'sudo tail -n 60 /var/log/fedokawaii.log' >"$R/setup-tail.log" 2>&1
      stage "RED: setup stopped in phase ${ph:-?}: $R/stopped.txt, $R/setup-tail.log"
      return 1
    fi
  done
  stage "setup done"
  until vm_ssh "$name" 'systemctl is-active -q greetd' 2>/dev/null; do
    ((SECONDS - T0 > 25200)) && { stage "RED: no login screen"; return 1; }
    sleep 5
  done
  sleep 8
  do_shot "$name" "$R/login.png"
  stage "the login screen: $R/login.png"
  vm_ssh "$name" 'sudo cat /var/log/fedokawaii.log' >"$R/setup.log" 2>&1
  do_keys "$name" "$TEST_PASSWORD" "<enter>"
  sleep 25
  do_shot "$name" "$R/desktop.png"
  vm_ssh "$name" 'sudo fedokawaii verify' >"$R/verify.log" 2>&1
  local rc=$?
  stage "verify: exit $rc, $(sed 's/\x1b\[[0-9;]*m//g' "$R/verify.log" | grep -oE '[0-9]+ checks passed|[0-9]+ of [0-9]+ checks failed' | tail -n1), the failing lines: grep ✘ $R/verify.log"
  return "$rc"
}

# the owner's carry-over across a wipe, through a USB drive of the VM's (a qcow2 under ~/VM/iso/): test files
# of each kind in the home, packed with main's kawa-carry; on the next VM, brought back, every file compared
CARRY_PASSWORD=carry-test
carry_env='export XDG_RUNTIME_DIR=/run/user/$(id -u) DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus; export PATH=$HOME/.local/bin:$PATH'
do_carry_save() {
  local name=$1 img=$2
  qemu-img create -q -f qcow2 "$img" 6G || return 1
  "${VIRSH[@]}" attach-disk "$name" "$img" sdz --targetbus usb --subdriver qcow2 --cache unsafe --live >/dev/null || return 1
  sleep 5
  vm_ssh "$name" 'set -e
    d=$(lsblk -dnpo NAME,TRAN | awk "\$2 == \"usb\" { print \$1; exit }"); [ -n "$d" ]
    sudo mkfs.ext4 -q -L FKCARRY "$d"; sudo udevadm settle; sleep 3
    cd ~; mkdir -p Notes Documents blasphemous-save-backup-20261022 .ssh .config/net.imput.helium/Default
    echo "- [ ] the list" >Notes/todo.md; echo "مرحبا 日本語" >"Documents/العربية 日本語.txt"
    head -c 5000000 /dev/urandom >Documents/big.bin; echo save >blasphemous-save-backup-20261022/savegame
    echo key >.ssh/id_test; chmod 600 .ssh/id_test; printf "%s\n" "{}" >.config/net.imput.helium/Default/Preferences
    printf "export TEST_KEY=carried\n" >.config/fedokawaii/secrets.sh; chmod 600 .config/fedokawaii/secrets.sh
    find Notes Documents blasphemous-save-backup-20261022 .ssh/id_test .config/net.imput.helium .config/fedokawaii/secrets.sh -type f -print0 | sort -z | xargs -0 sha256sum >/tmp/carry.sums' || return 1
  vm_ssh "$name" "$carry_env; RESTIC_PASSWORD=$CARRY_PASSWORD kawa-carry pack </dev/null" || return 1
  vm_ssh "$name" 'cat /tmp/carry.sums' >"$img.sums" || return 1
  vm_ssh "$name" 'sudo sync'
  "${VIRSH[@]}" detach-disk "$name" sdz --live >/dev/null
  [[ -s $img.sums ]]
}
do_carry_check() {
  local name=$1 img=$2
  vm_ssh "$name" "$carry_env; for i in 1 2 3 4 5 6; do [ -n \"\$(lsblk -nro MOUNTPOINT,LABEL | grep FKCARRY | cut -d' ' -f1)\" ] && break; sleep 5; done; RESTIC_PASSWORD=$CARRY_PASSWORD kawa-carry back </dev/null" || return 1
  vm_ssh "$name" 'sha256sum --quiet -c -' <"$img.sums" || return 1
  [[ $(vm_ssh "$name" 'stat -c %a ~/.ssh/id_test ~/.config/fedokawaii/secrets.sh | tr "\n" " "') == "600 600 " ]] || { echo "vm-iso-test: a key lost its mode" >&2; return 1; }
  echo "vm-iso-test: every carried file back, byte for byte, modes kept"
}

# do_again NAME ISO — the same VM and disk, started from a stick again (first in the boot order): what a
# firmware that boots the stick twice shows, and an install over a finished one
do_again() {
  local name=$1 iso=$2 d=$V/$1
  "${VIRSH[@]}" destroy "$name" >/dev/null 2>&1
  iso=$(readlink -f "$iso")
  sed -i -E "s|<memory unit='MiB'>[0-9]+<|<memory unit='MiB'>4096<|; s|(<source file=')[^']*\.iso('/>)|\1$iso\2|; s|(<target dev='sda' bus='sata'/><readonly/>)(<boot order='1'/>)?|\1<boot order='1'/>|" "$d/domain.xml"
  "${VIRSH[@]}" define "$d/domain.xml" >/dev/null || return 1
  mem_guard "$name"
  "${VIRSH[@]}" start "$name" >/dev/null
}

# do_over NAME ISO — an install over a finished one: the stick boots again on the disk of the last run (it says
# fedokawaii is installed), `i`, the questions, and from there a whole run on a disk with real history
do_over() {
  local name=$1 iso=$2
  do_again "$name" "$iso" || return 1
  R=$V/$name/run T0=$SECONDS
  mkdir -p "$R"
  stage "started on a finished disk: $(sha256sum "$iso" | cut -c1-16)"
  setsid -f bash "$0" watch "$name" "$R/screens" 3 >/dev/null 2>&1 </dev/null
  wait_words "$name" "fedokawaii is installed" 300 || { stage "RED: the stick did not say so"; return 1; }
  do_say "$name" >"$R/installed.txt"; cp "$V/$name/say.png" "$R/installed.png"
  stage "the stick says it is installed"
  do_keys "$name" i
  do_install "$name" || { stage "RED: the questions"; return 1; }
  stage "questions answered"
  # (the stick stays in and first in the boot order, through the installer's own restart: it must say the disk
  # is taken, not ask again. Then it is taken out, as the page says, and enter restarts)
  until do_say "$name" "fedokawaii is installed" 2>/dev/null; do
    ((SECONDS - T0 > 3600)) && { stage "RED: the stick never said it, after the base system"; return 1; }
    sleep 3
  done
  do_say "$name" >"$R/installed-2.txt"; cp "$V/$name/say.png" "$R/installed-2.png"
  stage "base system in; the stick, still in, says the disk is taken"
  "${VIRSH[@]}" change-media "$name" sda --eject --force >/dev/null
  do_keys "$name" "<enter>"
  do_follow "$name"
}

# do_path NAME CARRY — the rest of the owner's path on an installed VM (T54b 5), after its run: his things back
# from the drive, the update button pressed, everything still green
do_path() {
  local name=$1 img=$2 rc
  R=$V/$name/run; T0=$SECONDS
  do_carry_check "$name" "$img" >"$R/carry.log" 2>&1; rc=$?
  stage "his things back from the drive: exit $rc ($(tail -n1 "$R/carry.log" | cut -c1-80))"
  ((rc == 0)) || return 1
  # (what Super+U's update runs, as root: the unit of its own, its output followed here)
  vm_ssh "$name" 'sudo bash /usr/local/lib/fedokawaii/fedokawaii.sh update' >"$R/update.log" 2>&1; rc=$?
  stage "the update button: exit $rc, $(sed 's/\x1b\[[0-9;]*m//g' "$R/update.log" | grep -E 'update|done|held|✔|✘' | tail -n1 | cut -c1-100)"
  ((rc == 0)) || return 1
  until vm_ssh "$name" true 2>/dev/null; do ((SECONDS - T0 > 7200)) && return 1; sleep 5; done
  vm_ssh "$name" 'sudo fedokawaii verify' >"$R/verify-after.log" 2>&1; rc=$?
  stage "verify after the update: exit $rc, $(sed 's/\x1b\[[0-9;]*m//g' "$R/verify-after.log" | grep -oE '[0-9]+ checks passed|[0-9]+ of [0-9]+ checks failed' | tail -n1)"
  return "$rc"
}

# do_midway ISO DIR — the two ways an install is cut off before its first restart: the reset (the stick starts
# over and asks again: the one place something is asked twice, and nothing is on the disk yet that could keep an
# answer) and the mirrors gone at the package step (our failure page, its words read)
do_midway() {
  local iso=$1 dir=$2 n=r27-iso-m t0=$SECONDS mac
  mkdir -p "$dir"
  do_create "$n" "$iso" --cpus 4 --port 2242 >/dev/null || return 1
  mem_guard "$n"
  "${VIRSH[@]}" start "$n" >/dev/null || return 1
  do_install "$n" || return 1
  wait_words "$n" "the packages" 300 || return 1
  "${VIRSH[@]}" reset "$n" >/dev/null
  if wait_words "$n" "a new home" 300; then
    printf 'green %4d s  reset during the packages: the form again, the disk given up\n' "$((SECONDS - t0))" | tee -a "$dir/matrix.txt"
  else
    printf 'RED   %4d s  reset during the packages: no form\n' "$((SECONDS - t0))" | tee -a "$dir/matrix.txt"
  fi
  do_say "$n" >"$dir/reset.txt"; cp "$V/$n/say.png" "$dir/reset.png"
  t0=$SECONDS
  do_keys "$n" "$TEST_USER" "<enter>" "$TEST_PASSWORD" "<enter>" "$TEST_PASSWORD" "<enter>" "<down>" "<down>" "<down>" "<down>" "<enter>" || return 1
  wait_words "$n" "will be erased" 20 || return 1
  do_keys "$n" "<enter>"
  wait_words "$n" "the packages" 300 || return 1
  mac=$("${VIRSH[@]}" domiflist "$n" | awk 'NR > 2 && NF { print $5; exit }')
  "${VIRSH[@]}" domif-setlink "$n" "$mac" down >/dev/null
  if wait_words "$n" "the install failed" 1500; then
    printf 'green %4d s  mirrors gone at the packages: our failure page\n' "$((SECONDS - t0))" | tee -a "$dir/matrix.txt"
  else
    printf 'RED   %4d s  mirrors gone at the packages: no failure page\n' "$((SECONDS - t0))" | tee -a "$dir/matrix.txt"
  fi
  do_say "$n" >"$dir/mirrors.txt"; cp "$V/$n/say.png" "$dir/mirrors.png"
  "${VIRSH[@]}" destroy "$n" >/dev/null 2>&1
  "${VIRSH[@]}" undefine "$n" --nvram >/dev/null 2>&1
  rm -rf "${V:?}/$n"
}

# the cases that end before a disk is touched, each in a small VM of its own, one after the other: what
# the screen says, read exactly, and a PNG of it in DIR
do_matrix() {
  local iso=$1 dir=$2 n=r27-iso-m; shift 2
  mkdir -p "$dir"
  one() {   # one CASE WORDS KEYS… -- CREATE-OPTIONS…
    local c=$1 want=$2 keys=() t0=$SECONDS; shift 2
    while (($#)) && [[ $1 != -- ]]; do keys+=("$1"); shift; done
    [[ ${1:-} == -- ]] && shift
    do_create "$n" "$iso" --cpus 2 --port 2242 "$@" >/dev/null || return 1
    mem_guard "$n"
    "${VIRSH[@]}" start "$n" >/dev/null || return 1
    if ((${#keys[@]})); then
      sleep 2
      # (the firmware, then the kernel loaded before the menu shows: keys as soon as it does)
      until do_shot "$n" "$V/$n/k.png" && python3 -I -c 'import sys; from PIL import Image; sys.exit(0 if Image.open(sys.argv[1]).convert("RGB").getpixel((5, 5)) == (24, 23, 21) else 1)' "$V/$n/k.png"; do sleep 1; ((SECONDS - t0 > 120)) && break; done
      do_keys "$n" "${keys[@]}"
    fi
    if wait_words "$n" "$want" 180 2>/dev/null; then
      printf 'green %4d s  %s: "%s"\n' "$((SECONDS - t0))" "$c" "$want" | tee -a "$dir/matrix.txt"
    else
      printf 'RED   %4d s  %s: no "%s"\n' "$((SECONDS - t0))" "$c" "$want" | tee -a "$dir/matrix.txt"
    fi
    do_say "$n" >"$dir/$c.txt" 2>/dev/null
    cp "$V/$n/say.png" "$dir/$c.png" 2>/dev/null
    "${VIRSH[@]}" destroy "$n" >/dev/null 2>&1
  }
  [[ -n ${FK_MATRIX_FROM:-} ]] || one disk-20g "no disk large enough" -- --disk 20
  [[ -n ${FK_MATRIX_FROM:-} ]] || one no-network "no network" -- --no-net
  one bios "without UEFI" -- --bios
  one ram-3g "not enough memory" -- --ram 3000
  one stick-check "a new home" "<down>" "<enter>" --
  "${VIRSH[@]}" undefine "$n" --nvram >/dev/null 2>&1
  rm -rf "${V:?}/$n"
  grep -c green "$dir/matrix.txt"
}

cmd=${1:-}; [[ -n $cmd ]] && shift
case $cmd in
  create) name_ok "${1:-}"; [[ $# -ge 2 ]] || exit 2; do_create "$@" ;;
  start) name_ok "${1:-}"; mem_guard "$1"; "${VIRSH[@]}" start "$1" ;;
  stop) name_ok "${1:-}"; "${VIRSH[@]}" destroy "$1" ;;
  destroy) name_ok "${1:-}"; "${VIRSH[@]}" destroy "$1" >/dev/null 2>&1; "${VIRSH[@]}" undefine "$1" --nvram >/dev/null 2>&1; rm -rf "${V:?}/$1" ;;
  state) name_ok "${1:-}"; "${VIRSH[@]}" domstate "$1" ;;
  shot) name_ok "${1:-}"; do_shot "$1" "$2" ;;
  keys) name_ok "${1:-}"; do_keys "$@" ;;
  link) name_ok "${1:-}"; mac=$("${VIRSH[@]}" domiflist "$1" | awk 'NR > 2 && NF { print $5; exit }'); "${VIRSH[@]}" domif-setlink "$1" "$mac" "$2" >/dev/null ;;
  ssh) name_ok "${1:-}"; vm_ssh "$@" ;;
  say) name_ok "${1:-}"; do_say "$@" ;;
  install) name_ok "${1:-}"; do_install "$@" ;;
  watch) name_ok "${1:-}"; do_watch "$@" ;;
  run) name_ok "${1:-}"; [[ $# -ge 2 ]] || exit 2; do_run "$@" ;;
  follow) name_ok "${1:-}"; do_follow "$1" ;;
  matrix) do_matrix "$@" ;;
  midway) do_midway "$@" ;;
  again) name_ok "${1:-}"; do_again "$@" ;;
  over) name_ok "${1:-}"; do_over "$@" ;;
  path) name_ok "${1:-}"; do_path "$@" ;;
  carry-save) name_ok "${1:-}"; do_carry_save "$@" ;;
  carry-check) name_ok "${1:-}"; do_carry_check "$@" ;;
  *) sed -n '2,/^set -u/{/^set -u/d;s/^# \{0,1\}//;p}' "$0"; exit 2 ;;
esac
