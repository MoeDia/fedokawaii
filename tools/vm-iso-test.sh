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
#   bash tools/vm-iso-test.sh guard NAME               the PC first: short of memory the VM waits, shorter still it goes
#   bash tools/vm-iso-test.sh run NAME ISO [--…]       one whole run: create, install, setup, login, verify, timed
#   bash tools/vm-iso-test.sh whole NAME ISO QCOW2 [--…] the owner's path, the final proof: a run with a drive of his
#                                                      things in, then the update button, the lock, the log out, the facts
#   bash tools/vm-iso-test.sh follow NAME              the same from the installed system's first start on
#   bash tools/vm-iso-test.sh matrix ISO DIR           the refusals and the stick's check: small VMs, read exactly
#   bash tools/vm-iso-test.sh midway ISO DIR           an install cut off: the reset, the mirrors gone
#   bash tools/vm-iso-test.sh again NAME ISO           the same VM and disk, started from a stick again
#   bash tools/vm-iso-test.sh over NAME ISO            a whole run over a finished install (`i` on that page)
#   bash tools/vm-iso-test.sh session NAME             at its keyboard: locked and unlocked, logged out and in
#   bash tools/vm-iso-test.sh path NAME QCOW2          after a run: his things back, the update button, verify
#   bash tools/vm-iso-test.sh facts NAME               what a run left: hash in logs, strays, firmware, the splash…
#   bash tools/vm-iso-test.sh carry-make QCOW2         the same drive made here, no VM (kawa-carry from this tree, mke2fs -d)
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
# (the owner again, 23:24, after the freeze: one VM at a time on the whole PC, whoever's: this one waits its turn)
mem_guard() {
  local name=$1 want have others waited=0
  if "${VIRSH[@]}" list --name | grep -E '^r27-iso' | grep -qvxF "$name"; then
    die "another VM of this lane is running: $("${VIRSH[@]}" list --name | grep -E '^r27-iso' | tr '\n' ' ')"
  fi
  while others=$(pgrep -a -x qemu-system-x86 | grep -oE 'guest=[^,]+' | grep -vxF "guest=$name" | tr '\n' ' ') && [[ -n $others ]]; do
    ((waited % 300 == 0)) && echo "vm-iso-test: $(date +%T) one VM at a time: waiting for $others" >&2
    sleep 20; waited=$((waited + 20))
  done
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
    SOURCE_DATE_EPOCH=1 python3 -B "$here/build-iso-art.py" --console "$V/.art" >/dev/null || return 1
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
# the PC first (a global OOM at 18:15, the freeze at 22:06): under 4 GiB available or 13 GiB of swap used the VM is paused
# until there is room again; under 1.5 GiB it goes, and its run with it. Ends with the VM.
do_guard() {
  local name=$1 avail used state paused=0 log=$V/$1/run/log
  while sleep 15; do
    state=$("${VIRSH[@]}" domstate "$name" 2>/dev/null) || return 0
    [[ $state == "shut off" ]] && return 0
    read -r avail used < <(awk '/^MemAvailable/ { a = $2 } /^SwapFree/ { f = $2 } /^SwapTotal/ { t = $2 } END { print int(a / 1024), int((t - f) / 1024) }' /proc/meminfo)
    if ((avail < 1536)); then
      printf '%s      the memory guard: %s MiB available, %s MiB of swap used: the VM stopped\n' "$(date +%T)" "$avail" "$used" >>"$log"
      "${VIRSH[@]}" destroy "$name" >/dev/null 2>&1
      return 0
    elif ((!paused && (avail < 4096 || used > 13312))); then
      printf '%s      the memory guard: %s MiB available, %s MiB of swap used: the VM paused\n' "$(date +%T)" "$avail" "$used" >>"$log"
      "${VIRSH[@]}" suspend "$name" >/dev/null 2>&1 && paused=1
    elif ((paused && avail >= 6144 && used <= 13312)); then
      printf '%s      the memory guard: %s MiB available again: the VM goes on\n' "$(date +%T)" "$avail" >>"$log"
      "${VIRSH[@]}" resume "$name" >/dev/null 2>&1 && paused=0
    fi
  done
}
do_run() {
  local name=$1 iso=$2; shift 2
  do_create "$name" "$iso" "$@" || return 1
  R=$V/$name/run T0=$SECONDS
  mkdir -p "$R"
  mem_guard "$name"
  "${VIRSH[@]}" start "$name" >/dev/null || return 1
  stage "started: $(sha256sum "$iso" | cut -c1-16)"
  setsid -f bash "$0" watch "$name" "$R/screens" 3 >/dev/null 2>&1 </dev/null
  setsid -f bash "$0" guard "$name" >/dev/null 2>&1 </dev/null
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
    # (FK_SLOW_BEFORE=N: until setup's phase N a slow line, 3 MB/s, again after every restart: passt has no shaping,
    # the installed system has no tc)
    if [[ -n ${FK_SLOW_BEFORE:-} && ( -z $ph || $ph -lt $FK_SLOW_BEFORE ) ]]; then
      vm_ssh "$name" 'sudo nft list table inet fkslow >/dev/null 2>&1 || { sudo nft add table inet fkslow && sudo nft "add chain inet fkslow in { type filter hook input priority -300; }" && sudo nft add rule inet fkslow in iifname "enp1s0" limit rate over 3 mbytes/second drop; }' 2>/dev/null
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
  # (the greeter is the lock's twin: its gate too, shut until Tab)
  do_keys "$name" "<tab>"; sleep 1.5
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
# (what a home holds for the test: run in that home, the sums on its output)
carry_things='cd ~; mkdir -p Notes Documents blasphemous-save-backup-20261022 .ssh .config/net.imput.helium/Default .config/fedokawaii
    echo "- [ ] the list" >Notes/todo.md; echo "مرحبا 日本語" >"Documents/العربية 日本語.txt"
    head -c 5000000 /dev/urandom >Documents/big.bin; echo save >blasphemous-save-backup-20261022/savegame
    echo key >.ssh/id_test; chmod 600 .ssh/id_test; printf "%s\n" "{}" >.config/net.imput.helium/Default/Preferences
    printf "export TEST_KEY=carried\n" >.config/fedokawaii/secrets.sh; chmod 600 .config/fedokawaii/secrets.sh
    find Notes Documents blasphemous-save-backup-20261022 .ssh/id_test .config/net.imput.helium .config/fedokawaii/secrets.sh -type f -print0 | sort -z | xargs -0 sha256sum'
carry_env='export XDG_RUNTIME_DIR=/run/user/$(id -u) DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus; export PATH=$HOME/.local/bin:$PATH'
do_carry_save() {
  local name=$1 img=$2
  qemu-img create -q -f qcow2 "$img" 6G || return 1
  "${VIRSH[@]}" attach-disk "$name" "$img" sdz --targetbus usb --subdriver qcow2 --cache unsafe --live >/dev/null || return 1
  sleep 5
  vm_ssh "$name" 'set -e
    d=$(lsblk -dnpo NAME,TRAN | awk "\$2 == \"usb\" { print \$1; exit }"); [ -n "$d" ]
    sudo mkfs.ext4 -q -L FKCARRY -E root_owner=$(id -u):$(id -g) "$d"; sudo udevadm settle
    for i in 1 2 3 4 5 6 7 8 9 10; do lsblk -nro LABEL,MOUNTPOINT | grep -q "^FKCARRY /" && break; sleep 2; done
    '"$carry_things"' >/tmp/carry.sums' || return 1
  vm_ssh "$name" "$carry_env; RESTIC_PASSWORD=$CARRY_PASSWORD kawa-carry pack </dev/null" || return 1
  vm_ssh "$name" 'cat /tmp/carry.sums' >"$img.sums" || return 1
  vm_ssh "$name" 'sudo sync'
  "${VIRSH[@]}" detach-disk "$name" sdz --live >/dev/null
  [[ -s $img.sums ]]
}
# the drive without a VM, so that a proof needs one install, not two: this tree's kawa-carry in a throw-away home, the
# folder it writes as an ext4 that mke2fs fills unprivileged (his uid and the installed test user's are both 1000)
do_carry_make() {
  local img=$1 root t raw rc=0
  root=$(cd "$here/.." && pwd)
  t=$(mktemp -d "$HOME/VM/iso/carry.XXXXXX") || return 1
  mkdir -p "$t/home/.config/fedokawaii" "$t/drive"
  cp "$root/configs/home/.config/fedokawaii/icons.sh" "$root/configs/home/.config/fedokawaii/carry.list" "$t/home/.config/fedokawaii/"
  # (nothing of this session in it: no display, no bus, no state of mine)
  local fence=(env -u WAYLAND_DISPLAY -u DISPLAY -u XDG_STATE_HOME -u XDG_CONFIG_HOME -u XDG_DATA_HOME
    DBUS_SESSION_BUS_ADDRESS=unix:path=/nonexistent XDG_CACHE_HOME="$t/home/.cache" HOME="$t/home")
  "${fence[@]}" bash -c "$carry_things" >"$img.sums" || rc=1
  ((rc)) || "${fence[@]}" KAWA_CARRY_SETTINGS="$root/fedokawaii.conf" RESTIC_PASSWORD="$CARRY_PASSWORD" \
    bash "$root/bin/kawa-carry" pack "$t/drive" </dev/null || rc=1
  raw=$t/drive.raw
  ((rc)) || mke2fs -q -F -t ext4 -L FKCARRY -d "$t/drive" -E root_owner="$(id -u):$(id -g)" "$raw" 6G || rc=1
  ((rc)) || qemu-img convert -f raw -O qcow2 "$raw" "$img" || rc=1
  chmod -R u+w "$t"; rm -rf "$t"
  ((rc == 0)) && [[ -s $img && -s $img.sums ]]
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
  "${VIRSH[@]}" undefine "$name" --keep-nvram >/dev/null 2>&1
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

# do_session NAME — at the keyboard of a finished install, with the desktop up: Super+Escape locks and the password
# opens it, the power menu's "log out" (Super+Shift+E, two rows down) ends the session and the greeter takes it back
do_session() {
  local name=$1 i
  R=$V/$name/run; [[ -n ${T0:-} ]] || T0=$SECONDS
  mkdir -p "$R"
  # wait_for NAME SECONDS CMD… — until the installed system says yes
  wait_for() { local n=$1 end=$((SECONDS + $2)); shift 2; until vm_ssh "$n" "$*" >/dev/null 2>&1; do ((SECONDS > end)) && return 1; sleep 1; done; }
  wait_for "$name" 60 "pgrep -u $TEST_USER -x waybar" || { stage "RED: no desktop to start from"; return 1; }
  "${VIRSH[@]}" send-key "$name" KEY_LEFTMETA KEY_ESC >/dev/null
  wait_for "$name" 15 "pgrep -u $TEST_USER -x gtklock" || { stage "RED: Super+Escape locked nothing"; do_shot "$name" "$R/no-lock.png"; return 1; }
  sleep 2; do_shot "$name" "$R/locked.png"
  # (the gate: shut, every key is nothing but the secret one, Tab; open, keys type)
  do_keys "$name" "<tab>"; sleep 1.5; do_shot "$name" "$R/lock-open.png"
  do_keys "$name" "$TEST_PASSWORD" "<enter>"
  wait_for "$name" 20 "! pgrep -u $TEST_USER -x gtklock" || { stage "RED: the password did not open the lock"; do_shot "$name" "$R/still-locked.png"; return 1; }
  sleep 2; do_shot "$name" "$R/unlocked.png"
  stage "locked and unlocked with the password: $R/locked.png, $R/unlocked.png"
  "${VIRSH[@]}" send-key "$name" KEY_LEFTMETA KEY_LEFTSHIFT KEY_E >/dev/null
  sleep 3; do_shot "$name" "$R/power-menu.png"
  do_keys "$name" "<down>" "<down>" "<enter>"
  wait_for "$name" 30 "! pgrep -u $TEST_USER -x dwl" || { stage "RED: log out left the session up"; do_shot "$name" "$R/no-logout.png"; return 1; }
  sleep 12; do_shot "$name" "$R/greeter.png"
  do_keys "$name" "<tab>"; sleep 1.5
  do_keys "$name" "$TEST_PASSWORD" "<enter>"
  wait_for "$name" 60 "pgrep -u $TEST_USER -x waybar" || { stage "RED: no desktop after logging in again"; do_shot "$name" "$R/no-login.png"; return 1; }
  sleep 8; do_shot "$name" "$R/desktop-again.png"
  stage "logged out and in again: $R/greeter.png, $R/desktop-again.png"
}

# do_path NAME CARRY — the rest of the owner's path on an installed VM (T54b 5), after its run: his things back
# from the drive, the update button pressed, everything still green
do_path() {
  local name=$1 img=$2 rc
  R=$V/$name/run; T0=$SECONDS
  do_carry_check "$name" "$img" >"$R/carry.log" 2>&1; rc=$?
  stage "his things back from the drive: exit $rc ($(tail -n1 "$R/carry.log" | cut -c1-80))"
  ((rc == 0)) || return 1
  vm_ssh "$name" 'sudo dnf -q check-upgrade' >"$R/waiting-updates.txt" 2>&1
  stage "waiting for the button: $(grep -cE '\.(x86_64|noarch|i686) ' "$R/waiting-updates.txt") packages"
  # (what Super+U's update runs, as root: the unit of its own, its output followed here)
  vm_ssh "$name" 'sudo bash /usr/local/lib/fedokawaii/fedokawaii.sh update' >"$R/update.log" 2>&1; rc=$?
  stage "the update button: exit $rc, $(sed 's/\x1b\[[0-9;]*m//g' "$R/update.log" | grep -E 'update|done|held|✔|✘' | tail -n1 | cut -c1-100)"
  ((rc == 0)) || return 1
  until vm_ssh "$name" true 2>/dev/null; do ((SECONDS - T0 > 7200)) && return 1; sleep 5; done
  vm_ssh "$name" 'sudo fedokawaii verify' >"$R/verify-after.log" 2>&1; rc=$?
  stage "verify after the update: exit $rc, $(sed 's/\x1b\[[0-9;]*m//g' "$R/verify-after.log" | grep -oE '[0-9]+ checks passed|[0-9]+ of [0-9]+ checks failed' | tail -n1)"
  return "$rc"
}

# do_whole NAME ISO CARRY [--…] — the owner's whole path: a fresh VM, the ISO, his things back from a drive, the
# update button, at the keyboard, what is left: a line a stage in the run's log, RED where it stopped
do_whole() {
  local name=$1 iso=$2 img=$3; shift 3
  do_run "$name" "$iso" --usb "$img" "$@" || { stage "RED: the run"; return 1; }
  do_path "$name" "$img" || { stage "RED: the path"; return 1; }
  do_session "$name" || return 1
  # (the other half of his trip: the installed system packs, to a new drive; the one brought back from goes out first)
  "${VIRSH[@]}" detach-disk "$name" sdb --live >/dev/null || { stage "RED: the drive would not come out"; return 1; }
  sleep 3
  do_carry_save "$name" "$R/carry-new.qcow2" >"$R/carry-new.log" 2>&1 || { stage "RED: packing on the installed system: $R/carry-new.log"; return 1; }
  stage "his things packed to a new drive: $(tail -n1 "$R/carry-new.log" | cut -c1-60)"
  rm -f "$R/carry-new.qcow2"
  do_facts "$name" >"$R/facts.txt" 2>&1
  stage "GREEN: the whole path. the facts: $R/facts.txt"
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

# do_facts NAME — what a run leaves behind that a user would never look at, each read from the installed system
do_facts() {
  vm_ssh "$1" 'set -u
    printf "release: "; . /etc/os-release; echo "$PRETTY_NAME"
    printf "kernels: "; rpm -q --qf "%{VERSION}-%{RELEASE} " kernel-core; echo
    printf "newest kernel in the repositories: "; dnf -q repoquery --latest-limit=1 --qf "%{version}-%{release}\n" kernel-core 2>/dev/null | tail -n1
    printf "repositories enabled: "; dnf -q repolist --enabled 2>/dev/null | sed 1d | cut -d" " -f1 | tr "\n" " "; echo
    printf "testing, rawhide or copr among them: "; dnf -q repolist --enabled 2>/dev/null | grep -ciE "testing|rawhide|copr"
    printf "packages with no fc45 in their name (each with its repository):\n"; dnf -q repoquery --installed --qf "%{name}-%{evr} %{from_repo}\n" 2>/dev/null | grep -v "fc45" | grep -v "^gpg-pubkey" | sed "s/^/  /"
    printf "secure boot: "; mokutil --sb-state 2>/dev/null || echo unknown
    printf "password hash in the logs: "; sudo sh -c "grep -l \"\\\$y\\\$\" /var/log/anaconda/* /root/*.cfg /var/log/fk-post.log /var/log/fedokawaii.log 2>/dev/null" | wc -l
    printf "the installer left behind: "; ls -d /etc/systemd/system/fedokawaii-resume.service* /var/lib/fedokawaii/first-boot 2>/dev/null | wc -l
    printf "the toolkit holds the round: "; ls -d /usr/local/lib/fedokawaii/.claude /usr/local/lib/fedokawaii/CLAUDE.md /usr/local/lib/fedokawaii/tools/claude-loop.sh 2>/dev/null | wc -l
    printf "console= on the kernel line: "; tr " " "\n" </proc/cmdline | grep -cx "console=tty[0-9]*"
    printf "splash crashes this boot: "; journalctl -b --no-pager 2>/dev/null | grep -c "plymouthd.*\(SEGV\|dumped core\)"
    printf "firmware: "; rpm -q linux-firmware amd-gpu-firmware realtek-firmware amd-ucode-firmware 2>&1 | grep -c "not installed"; 
    printf "kernel, initramfs: "; ls -s --block-size=M /boot/initramfs-*.img | tr "\n" " "; echo
    printf "fonts in it: "; sudo lsinitrd 2>/dev/null | grep -E "\.(ttf|otf)$" | sed "s/.* //" | tr "\n" " "; echo
    printf "ssh enabled: "; systemctl is-enabled sshd 2>/dev/null
    printf "the splash'"'"'s label plugin: "; rpm -q plymouth-plugin-label
    printf "firewall: "; sudo firewall-cmd --get-default-zone 2>/dev/null | tr "\n" " "; sudo firewall-cmd --list-services 2>/dev/null | tr "\n" " "; sudo firewall-cmd --list-ports 2>/dev/null; echo
    printf "disk: "; findmnt -no SOURCE / | cut -c1-40; sudo btrfs subvolume list / | wc -l
    printf "the release in the toolkit: "; cat /var/lib/fedokawaii/toolkit-release 2>/dev/null; echo
    printf "round tooling: units %s, sudo rule %s, polkit rule %s, worktrees %s\n" "$(systemctl --user list-unit-files 2>/dev/null | grep -c "^r27-")" \
      "$(ls /etc/sudoers.d/90-claude-temp 2>/dev/null | wc -l)" "$(ls /etc/polkit-1/rules.d/00-fedokawaii-round.rules 2>/dev/null | wc -l)" "$(ls -d ~/repos/fk-* 2>/dev/null | wc -l)"
    printf "in user@.service.d (his, all users): "; ls /etc/systemd/system/user@.service.d/ 2>/dev/null | tr "\n" " "; echo
    printf "the browser: "; rpm -q helium-bin; printf "its Widevine: "; jq -r .version /usr/local/lib/fedokawaii-widevine/manifest.json 2>/dev/null || echo none
    printf "the play world: "; id asobi 2>/dev/null | cut -d" " -f1; sudo flatpak --system list --columns=application 2>/dev/null | tr "\n" " "; echo
    printf "Flatpaks in this account: "; flatpak --user list 2>/dev/null | wc -l
    printf "snapshots: "; sudo snapper list-configs 2>/dev/null | sed 1,2d | cut -d" " -f1 | tr "\n" " "; rpm -q grub-btrfs
    printf "the fixer: "; ls /usr/local/sbin/kawa-fixer 2>/dev/null || echo none
    printf "the apps: "; for a in kawa-chess kawa-typing kawa-torrents kawa-panel kawa-carry kawa-stick; do command -v "$a" >/dev/null 2>&1 || PATH=$HOME/.local/bin:$PATH command -v "$a" >/dev/null 2>&1 && printf "%s " "$a" || printf "%s:MISSING " "$a"; done; echo
    printf "the lock: "; ls /usr/local/lib/fedokawaii/configs/home/.local/share/fedokawaii/dark/lock-scene.png ~/.local/share/fedokawaii/dark/lock-scene.png 2>/dev/null | wc -l'
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
      # (the firmware, then the kernel loaded before the menu shows: keys as soon as the plate's red edge is there)
      until do_shot "$n" "$V/$n/k.png" && python3 -I -c 'import sys; from PIL import Image; sys.exit(0 if Image.open(sys.argv[1]).convert("RGB").getpixel((640, 700)) == tuple(int(sys.argv[2][i:i + 2], 16) for i in (0, 2, 4)) else 1)' "$V/$n/k.png" "$(sed -n "s/^ *3: '\(.*\)',.*/\1/p" "$V/.art/console/glyphs.py")"; do sleep 1; ((SECONDS - t0 > 120)) && break; done
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
    untouched "$n" "$c" "$dir"
  }
  # (a refusal leaves the disk as it was: not one cluster of the blank image written)
  untouched() {
    if qemu-img map -f qcow2 --output=json "$V/$1/disk.qcow2" | grep -q '"data": true'; then
      printf 'RED          %s: something was written to its disk\n' "$2" | tee -a "$3/matrix.txt"
    fi
  }
  [[ -n ${FK_MATRIX_FROM:-} ]] || one disk-20g "no disk large enough" -- --disk 20
  [[ -n ${FK_MATRIX_FROM:-} ]] || one no-network "no network" -- --no-net
  one bios "without UEFI" -- --bios --cd-first
  one ram-3g "not enough memory" -- --ram 3000
  one stick-check "a new home" "<down>" "<enter>" --
  # a stick with one byte wrong, in a file nothing reads before the check (the 32-bit loader): after the questions, before the disk
  local bad=$dir/damaged.iso lba t0=$SECONDS
  cp --reflink=auto "$iso" "$bad" || return 1
  lba=$(xorriso -no_rc -indev "$iso" -find /EFI/BOOT/BOOTIA32.EFI -exec report_lba -- 2>/dev/null | awk '/^Report layout/ { next } /BOOTIA32/ { for (i = 1; i <= NF; i++) if ($i ~ /^[0-9]+$/) { print $i; exit } }')
  [[ $lba =~ ^[0-9]+$ ]] || { echo "vm-iso-test: no address for the file to damage" >&2; return 1; }
  printf 'X' | dd of="$bad" bs=1 seek=$((lba * 2048 + 4096)) conv=notrunc status=none
  do_create "$n" "$bad" --cpus 2 --port 2242 >/dev/null || return 1
  mem_guard "$n"
  "${VIRSH[@]}" start "$n" >/dev/null || return 1
  if do_install "$n" && wait_words "$n" "this stick is damaged" 300 2>/dev/null; then
    printf 'green %4d s  damaged: "this stick is damaged", after the questions\n' "$((SECONDS - t0))" | tee -a "$dir/matrix.txt"
  else
    printf 'RED   %4d s  damaged: no "this stick is damaged"\n' "$((SECONDS - t0))" | tee -a "$dir/matrix.txt"
  fi
  do_say "$n" >"$dir/damaged.txt" 2>/dev/null
  cp "$V/$n/say.png" "$dir/damaged.png" 2>/dev/null
  "${VIRSH[@]}" destroy "$n" >/dev/null 2>&1
  untouched "$n" damaged "$dir"
  rm -f "$bad"
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
  session) name_ok "${1:-}"; do_session "$1" ;;
  path) name_ok "${1:-}"; do_path "$@" ;;
  whole) name_ok "${1:-}"; [[ $# -ge 3 ]] || exit 2; do_whole "$@" ;;
  facts) name_ok "${1:-}"; do_facts "$1" ;;
  guard) name_ok "${1:-}"; do_guard "$1" ;;
  carry-make) [[ $# -eq 1 ]] || exit 2; do_carry_make "$1" ;;
  carry-save) name_ok "${1:-}"; do_carry_save "$@" ;;
  carry-check) name_ok "${1:-}"; do_carry_check "$@" ;;
  *) sed -n '2,/^set -u/{/^set -u/d;s/^# \{0,1\}//;p}' "$0"; exit 2 ;;
esac
