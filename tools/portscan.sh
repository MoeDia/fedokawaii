#!/usr/bin/env bash
# tools/portscan.sh — this machine as a stranger sees it, every port, against the list. Another
# computer at the end of a cable into this machine's firewall: a network namespace, or a test VM
# (--vm NAME, tools/vm-create.sh). nmap at the far end, from two kinds of address: a private one
# (the LAN) and a public one (the world), each over IPv4 and IPv6, all 65535 TCP and UDP ports.
# What decides is what the firewall let through, read in the kernel right after it (nftables, a
# set of the ports that passed): UDP's silence means nothing to nmap, a set does not guess. nmap
# adds what answers now.
#   sudo bash tools/portscan.sh [--vm NAME] [--out FILE]   (the table; FILE keeps nmap's own lines)
# Exit 0: exactly the list's doors pass, from both sides · 1 a difference (named) · 2 misuse.
# Nothing stays: the cable, the namespace and the nftables table go at the end; nmap, if it is not
# installed, runs from a temporary folder (Fedora's package, unpacked, not installed); in a VM,
# it is installed there.
set -uo pipefail
IFS=$'\n\t'
export LC_ALL=C.UTF-8
REPO_DIR=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)
OUT="" VM=""
while (($#)); do
  case $1 in
    --vm) VM=${2:-}; shift 2 || { echo "portscan: --vm NAME" >&2; exit 2; } ;;
    --out) OUT=${2:-}; shift 2 || { echo "portscan: --out FILE" >&2; exit 2; } ;;
    -h|--help) sed -n '2,/^set -u/{/^set -u/d;s/^# \{0,1\}//;p}' "$0"; exit 0 ;;
    *) echo "portscan: unknown option $1" >&2; exit 2 ;;
  esac
done
[[ $EUID -eq 0 ]] || { echo "portscan: run with sudo" >&2; exit 2; }
source "$REPO_DIR/lib/common.sh"
source "$REPO_DIR/lib/net.sh"
read_conf "$REPO_DIR/fedokawaii.conf"
TARGET_USER=$(sed -n 1p /var/lib/fedokawaii/user 2>/dev/null | tr -d '[:space:]')
TARGET_USER=${TARGET_USER:-${SUDO_USER:-root}}
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)

NS=kawa-scan VETH=kawa-scan0 TABLE=kawa_scan
# (the far end's addresses: documentation and private ranges, unused anywhere else)
LAN4=10.199.39 LAN6=fd39:39:39 WORLD4=203.0.113 WORLD6=2001:db8:39
MAC=52:54:00:39:39:39
TMP=$(mktemp -d /dev/shm/kawa-scan.XXXXXX)
ME=(runuser -u "$TARGET_USER" -- env "HOME=$TARGET_HOME" "XDG_RUNTIME_DIR=/run/user/$(id -u "$TARGET_USER")")
V=("${ME[@]}" virsh -q -c qemu:///session)
vm() { "${ME[@]}" bash "$REPO_DIR/tools/vm-run.sh" "$VM" "$@"; }
chmod 755 "$TMP"; XML=$TMP/card.xml
printf '%s\n' "<interface type='ethernet'><mac address='$MAC'/><target dev='$VETH' managed='no'/><model type='virtio'/></interface>" >"$XML"
cleanup() {
  [[ -z $VM ]] || "${V[@]}" detach-device "fk-$VM" "$XML" --live >/dev/null 2>&1
  ip netns del "$NS" 2>/dev/null
  ip link del "$VETH" 2>/dev/null
  nft delete table inet "$TABLE" 2>/dev/null
  rm -rf -- "$TMP"
}
trap cleanup EXIT
trap 'exit 1' INT TERM HUP

# this end of the cable
cable() {
  ip addr add "$LAN4.1/24" dev "$VETH"; ip addr add "$WORLD4.1/24" dev "$VETH"
  ip -6 addr add "$LAN6::1/64" dev "$VETH" nodad; ip -6 addr add "$WORLD6::1/64" dev "$VETH" nodad
  ip link set "$VETH" up
}
if [[ -n $VM ]]; then
  # the other computer: a test VM, its second card on this machine's tap, nmap installed there.
  # The target is this end of the cable (the VM's own first card copies this machine's address)
  ip tuntap add dev "$VETH" mode tap user "$TARGET_USER" || exit 1
  cable
  "${V[@]}" attach-device "fk-$VM" "$XML" --live >/dev/null || { echo "portscan: fk-$VM does not take a second card" >&2; exit 1; }
  sleep 3
  vm 'command -v nmap >/dev/null || sudo dnf install -y -q nmap >/dev/null' || { echo "portscan: nmap does not install in fk-$VM" >&2; exit 1; }
  IF=$(vm "ip -o link | grep -i $MAC | cut -d: -f2 | tr -d ' '")
  [[ -n $IF ]] || { echo "portscan: the VM shows no second card" >&2; exit 1; }
  vm "sudo nmcli device set $IF managed no; sudo ip addr add $LAN4.2/24 dev $IF; sudo ip addr add $WORLD4.2/24 dev $IF; sudo ip -6 addr add $LAN6::2/64 dev $IF nodad; sudo ip -6 addr add $WORLD6::2/64 dev $IF nodad; sudo ip link set $IF up" \
    || { echo "portscan: the VM's second card" >&2; exit 1; }
  sleep 2
  target4=""
  FAR=(vm sudo nmap)
else
  # nmap: installed, or Fedora's package and its libraries unpacked here for this run alone
  NMAP=$(command -v nmap) || NMAP=""
  NMAP_ENV=()
  if [[ -z $NMAP ]]; then
    mkdir -p "$TMP/rpm" "$TMP/root"
    dnf download -q --arch="$(uname -m)" --destdir="$TMP/rpm" nmap liblinear libssh2 >/dev/null 2>&1 \
      || { echo "portscan: nmap could not be fetched (the network?)" >&2; exit 1; }
    for r in "$TMP"/rpm/*.rpm; do rpm2cpio "$r" | (cd "$TMP/root" && cpio -idm --quiet); done
    NMAP=$TMP/root/usr/bin/nmap
    NMAP_ENV=("LD_LIBRARY_PATH=$TMP/root/usr/lib64" "NMAPDIR=$TMP/root/usr/share/nmap")
    [[ -x $NMAP ]] && env "${NMAP_ENV[@]}" "$NMAP" --version >/dev/null \
      || { echo "portscan: the unpacked nmap does not run" >&2; exit 1; }
  fi
  # the other computer: a namespace, its cable
  ip netns add "$NS" || exit 1
  ip link add "$VETH" type veth peer name scan0 netns "$NS" || exit 1
  cable
  N=(ip netns exec "$NS")
  IF=scan0
  "${N[@]}" ip link set lo up
  "${N[@]}" ip addr add "$LAN4.2/24" dev scan0; "${N[@]}" ip addr add "$WORLD4.2/24" dev scan0
  "${N[@]}" ip -6 addr add "$LAN6::2/64" dev scan0 nodad; "${N[@]}" ip -6 addr add "$WORLD6::2/64" dev scan0 nodad
  "${N[@]}" ip link set scan0 up
  FAR=("${N[@]}" env "${NMAP_ENV[@]}" "$NMAP")
  # the target: this machine's real addresses (so a socket bound to one of them counts too); with
  # none of a family, this end of the cable
  target4=$(ip -4 -o addr show scope global | awk -v v="$VETH" '$2 != v { sub(/\/.*/, "", $4); print $4; exit }')
  target6=$(ip -6 -o addr show scope global | awk -v v="$VETH" '$2 != v { sub(/\/.*/, "", $4); print $4; exit }')
  target4=${target4:-$LAN4.1} target6=${target6:-$LAN6::1}
  "${N[@]}" ip route add "$target4/32" via "$LAN4.1" 2>/dev/null
  "${N[@]}" ip -6 route add "$target6/128" via "$LAN6::1" 2>/dev/null
fi
# what the firewall lets through: firewalld's input chain runs at priority 10, this after it, so
# a packet here passed. From this cable only: the machine's own traffic is never in these sets
nft -f - <<EOF || exit 1
table inet $TABLE {
  set lan_tcp4 { type inet_service; size 70000; flags dynamic; }
  set lan_tcp6 { type inet_service; size 70000; flags dynamic; }
  set lan_udp4 { type inet_service; size 70000; flags dynamic; }
  set lan_udp6 { type inet_service; size 70000; flags dynamic; }
  set world_tcp4 { type inet_service; size 70000; flags dynamic; }
  set world_tcp6 { type inet_service; size 70000; flags dynamic; }
  set world_udp4 { type inet_service; size 70000; flags dynamic; }
  set world_udp6 { type inet_service; size 70000; flags dynamic; }
  chain passed {
    type filter hook input priority 100; policy accept;
    iifname "$VETH" ip saddr $LAN4.2 meta l4proto tcp add @lan_tcp4 { th dport }
    iifname "$VETH" ip saddr $LAN4.2 meta l4proto udp add @lan_udp4 { th dport }
    iifname "$VETH" ip6 saddr $LAN6::2 meta l4proto tcp add @lan_tcp6 { th dport }
    iifname "$VETH" ip6 saddr $LAN6::2 meta l4proto udp add @lan_udp6 { th dport }
    iifname "$VETH" ip saddr $WORLD4.2 meta l4proto tcp add @world_tcp4 { th dport }
    iifname "$VETH" ip saddr $WORLD4.2 meta l4proto udp add @world_udp4 { th dport }
    iifname "$VETH" ip6 saddr $WORLD6::2 meta l4proto tcp add @world_tcp6 { th dport }
    iifname "$VETH" ip6 saddr $WORLD6::2 meta l4proto udp add @world_udp6 { th dport }
  }
}
EOF

scan() {   # scan SIDE PROTO FAMILY SOURCE TARGET → nmap's list of open ports in TMP/SIDE-PROTOFAMILY.open
  local side=$1 proto=$2 fam=$3 src=$4 dst=$5 flag=-sS six=() f=$TMP/$1-$2$3
  [[ $proto == udp ]] && flag=-sU
  [[ $fam == 6 ]] && six=(-6)
  "${FAR[@]}" "${six[@]}" -n -Pn "$flag" -p- -T4 --min-rate 4000 --max-retries 1 --open \
    -e "$IF" -S "$src" -oG - "$dst" >"$f.gnmap" 2>"$f.err" \
    || { echo "portscan: nmap failed ($side $proto$fam): $(cat "$f.err")" >&2; return 1; }
  sed -n 's/.*Ports: //p' "$f.gnmap" | tr ',' '\n' \
    | awk -F/ '$2 == "open" { gsub(/ /, "", $1); print $1 }' | LC_ALL=C sort -n | paste -sd' ' - >"$f.open"
}
passed() {   # passed SIDE PROTO FAMILY → the set's ports, in order, on one line
  nft list set inet "$TABLE" "$1_$2$3" | tr -d ' \t\n' | sed -n 's/.*elements={\([^}]*\)}.*/\1/p' \
    | tr ',' '\n' | LC_ALL=C sort -n | paste -sd' ' -
}
want() { net_doors "$1" | sed -n "s|/$2\$||p" | LC_ALL=C sort -n | paste -sd' ' -; }   # want lan|world tcp|udp

rc=0
printf '%-10s %-6s %-30s %s\n' "from" "proto" "the firewall lets through" "answering now"
for side in lan world; do
  for fam in 4 6; do
    for proto in tcp udp; do
      if [[ $side == lan ]]; then
        if [[ $fam == 4 ]]; then src=$LAN4.2; else src=$LAN6::2; fi
      elif [[ $fam == 4 ]]; then src=$WORLD4.2; else src=$WORLD6::2; fi
      if [[ -z $target4 ]]; then dst=${src%.2}.1; [[ $fam == 6 ]] && dst=${src%::2}::1   # (a VM: this end of the cable)
      elif [[ $fam == 4 ]]; then dst=$target4; else dst=$target6; fi
      scan "$side" "$proto" "$fam" "$src" "$dst" || rc=1
      got=$(passed "$side" "$proto" "$fam"); w=$(want "$side" "$proto")
      printf '%-10s %-6s %-30s %s\n' "$side" "$proto$fam" "${got:-nothing}" "$(cat "$TMP/$side-$proto$fam.open" 2>/dev/null)"
      if [[ $got != "$w" ]]; then echo "  ✘ $side $proto$fam: the list says [${w:-nothing}]"; rc=1; fi
      [[ -z $OUT ]] || { echo "# $side $proto$fam"; cat "$TMP/$side-$proto$fam.gnmap" 2>/dev/null; } >>"$OUT"
    done
  done
done
if ((rc == 0)); then echo "✔ exactly the list's doors, from the LAN and from the world, IPv4 and IPv6"; else echo "✘ not as system/net-allow.list says"; fi
exit "$rc"
