#!/usr/bin/env bash
# lib/net.sh — the network's doors, kept by one list (system/net-allow.list). setup.sh writes the
# firewall, the kernel's settings and the DNS from here; verify and the report read the same
# values (the *_wrong functions print one line per difference: nothing printed, all is well).
# Reads REPO_DIR, TARGET_HOME and SSH_SERVER; uses write_file, log and die (lib/common.sh) to write.
#
# The firewall (firewalld's own files, whole, so nothing else collects in them):
# · zone public, the network card's: target DROP, nothing answers but the list's world doors.
#   Its public IPv6 address is reachable from anywhere, so this zone is what the internet meets.
# · zone kawa-lan, bound to the private address ranges (a zone with sources comes before the
#   card's): the list's lan and world doors, the rest refused out loud, pings answered.
# · policy kawa-no-upnp: no program on this machine asks the router to open a port.

NET_ZONE_LAN=kawa-lan
NET_POLICY=kawa-no-upnp
# (IPv4's private and link-local ranges; IPv6's unique-local and link-local ones)
NET_LAN_SOURCES=(10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 169.254.0.0/16 fc00::/7 fe80::/10)
# DNS over TLS: Cloudflare, then Quad9 when it cannot answer; measured from this PC against the
# router's plain DNS (ledger r27-43): as fast at p50, and the router lost names these answer.
# Opportunistic: encrypted wherever the network allows it, and a network that blocks port 853
# costs privacy, not the internet. (Domains=~. keeps every name away from the router's DNS.)
NET_DNS="1.1.1.1#cloudflare-dns.com 1.0.0.1#cloudflare-dns.com 2606:4700:4700::1111#cloudflare-dns.com 2606:4700:4700::1001#cloudflare-dns.com 9.9.9.9#dns.quad9.net 149.112.112.112#dns.quad9.net 2620:fe::fe#dns.quad9.net 2620:fe::9#dns.quad9.net"
NET_DNS_FILE=/etc/systemd/resolved.conf.d/90-fedokawaii.conf
NET_SYSCTL_FILE=/etc/sysctl.d/60-fedokawaii-net.conf

# ssh_wanted — sshd runs only where it can be used: SSH_SERVER=yes and a key to log in with
ssh_wanted() { [[ $SSH_SERVER == yes ]] && grep -qsE '^[^#[:space:]]' "$TARGET_HOME/.ssh/authorized_keys"; }
_net_on() {
  case $1 in
    always) return 0 ;;
    ssh) ssh_wanted ;;
    remote) [[ -e $TARGET_HOME/.config/systemd/user/fk-remote.service ]] ;;
    *) return 1 ;;
  esac
}
# net_doors WHERE → the doors open to WHERE (lan: its own and the world's), a line each, in order
net_doors() {
  local p w when rest
  while IFS=' ' read -r p w when rest; do
    [[ $p == [0-9]* ]] || continue
    if [[ $w == "$1" || ($1 == lan && $w == world) ]] && _net_on "$when"; then printf '%s\n' "$p"; fi
  done <"$REPO_DIR/system/net-allow.list" | LC_ALL=C sort -u
}
_net_ports_xml() {
  local p
  while IFS= read -r p; do printf '  <port port="%s" protocol="%s"/>\n' "${p%/*}" "${p#*/}"; done < <(net_doors "$1")
}
# net_fw_file REL → what /etc/firewalld/REL holds
net_fw_file() {
  local s
  printf '<?xml version="1.0" encoding="utf-8"?>\n'
  case $1 in
    zones/public.xml)
      printf '<zone target="DROP">\n  <short>The world</short>\n'
      printf '  <description>Fedokawaii: what the internet meets. Nothing answers but the world doors of system/net-allow.list.</description>\n'
      _net_ports_xml world
      printf '</zone>\n' ;;
    "zones/$NET_ZONE_LAN.xml")
      printf '<zone>\n  <short>The home network</short>\n'
      printf '  <description>Fedokawaii: private addresses. The lan and world doors of system/net-allow.list.</description>\n'
      for s in "${NET_LAN_SOURCES[@]}"; do printf '  <source address="%s"/>\n' "$s"; done
      _net_ports_xml lan
      printf '</zone>\n' ;;
    "policies/$NET_POLICY.xml")
      cat <<'XML'
<policy target="CONTINUE" priority="-100">
  <short>No UPnP</short>
  <description>Fedokawaii: no program on this machine opens a port on the router (UPnP, NAT-PMP, PCP).</description>
  <ingress-zone name="HOST"/>
  <egress-zone name="ANY"/>
  <rule><port port="1900" protocol="udp"/><reject/></rule>
  <rule><port port="5351" protocol="udp"/><reject/></rule>
</policy>
XML
      ;;
  esac
}
_net_fw_files() { printf '%s\n' zones/public.xml "zones/$NET_ZONE_LAN.xml" "policies/$NET_POLICY.xml"; }
# _net_field KEY <<<"$(firewall-cmd --zone=Z --list-all)" → that line's value, sorted, one line
_net_field() { sed -n "s/^[[:space:]]*$1:[[:space:]]*//p" | tr ' ' '\n' | sed '/^$/d' | LC_ALL=C sort -u | paste -sd' ' -; }
# net_firewall_wrong — the firewall against the list: saved files and running rules alike
net_firewall_wrong() {
  local f z all want have i
  firewall-cmd -q --state 2>/dev/null || { echo "firewalld is not running"; return 0; }
  systemctl is-enabled --quiet firewalld.service || echo "firewalld is not on for every boot"
  while IFS= read -r f; do
    [[ -f /etc/firewalld/$f && $(<"/etc/firewalld/$f") == "$(net_fw_file "$f")" ]] || echo "/etc/firewalld/$f is not as the list says"
  done < <(_net_fw_files)
  have=$(firewall-cmd --get-default-zone 2>/dev/null)
  [[ $have == public ]] || echo "the default zone is ${have:-unknown}, not public"
  for z in public "$NET_ZONE_LAN"; do
    if ! all=$(firewall-cmd --zone="$z" --list-all 2>/dev/null); then echo "zone $z is not running"; continue; fi
    want=$(net_doors "$([[ $z == public ]] && echo world || echo lan)" | paste -sd' ' -)
    have=$(_net_field ports <<<"$all")
    [[ $have == "$want" ]] || echo "zone $z opens ports [$have], the list says [$want]"
    have=$(_net_field services <<<"$all")
    [[ -z $have ]] || echo "zone $z opens services: $have"
    have=$(_net_field target <<<"$all")
    [[ $have == "$([[ $z == public ]] && echo DROP || echo default)" ]] || echo "zone $z has target $have"
    have=$(_net_field forward <<<"$all")
    [[ $have == no ]] || echo "zone $z forwards"
    have=$(_net_field masquerade <<<"$all")
    [[ $have == no ]] || echo "zone $z masquerades"
    grep -q '^[[:space:]]*rule' <<<"$all" && echo "zone $z holds rules of its own"
    if [[ $z == "$NET_ZONE_LAN" ]]; then
      have=$(_net_field sources <<<"$all")
      want=$(printf '%s\n' "${NET_LAN_SOURCES[@]}" | LC_ALL=C sort -u | paste -sd' ' -)
      [[ $have == "$want" ]] || echo "zone $z holds sources [$have], should be [$want]"
    fi
  done
  firewall-cmd --info-policy="$NET_POLICY" 2>/dev/null | grep -q '(active)' || echo "policy $NET_POLICY is not running"
  # (the card with the default route: a connection tied to another zone would skip all of it)
  while IFS= read -r i; do
    have=$(firewall-cmd --get-zone-of-interface="$i" 2>/dev/null) || have=none
    [[ $have == public || $have == none ]] || echo "$i is in zone $have, not public"
  done < <(ip route show default 2>/dev/null | sed -n 's/.* dev \([^ ]*\).*/\1/p' | sort -u)
  return 0
}
# net_firewall — the firewall as the list says; reloaded only when something had to change
# (a reload keeps every connection that is up: nothing in use is cut)
net_firewall() {
  local f p want rc=0
  local -A old=()
  systemctl enable --now firewalld.service >/dev/null 2>&1 || die "firewalld does not start (systemctl status firewalld)"
  while IFS= read -r f; do
    p=/etc/firewalld/$f; want=$(net_fw_file "$f")
    [[ -f $p && $(<"$p") == "$want" ]] && continue
    old[$p]=""; [[ -f $p ]] && old[$p]=$(<"$p")
    printf '%s\n' "$want" | write_file "$p" 0644
    restorecon "$p" 2>/dev/null || true
  done < <(_net_fw_files)
  rm -f /etc/firewalld/zones/*.old
  # a firewalld that refuses the files keeps what was there: its old rules, and a clear stop here
  if ! firewall-cmd -q --check-config >/dev/null 2>&1; then
    for p in "${!old[@]}"; do
      if [[ -n ${old[$p]} ]]; then printf '%s\n' "${old[$p]}" | write_file "$p" 0644; else rm -f "$p"; fi
    done
    die "firewalld refuses the new rules (firewall-cmd --check-config): the old ones stay"
  fi
  if ((${#old[@]})) || [[ -n $(net_firewall_wrong) ]]; then firewall-cmd -q --reload || rc=$?; fi
  ((rc == 0)) || die "firewalld did not reload ($rc)"
  [[ $(firewall-cmd --get-default-zone) == public ]] || firewall-cmd -q --set-default-zone=public
  want=$(net_firewall_wrong)
  [[ -z $want ]] || die "the firewall is not as the list says:"$'\n'"    ${want//$'\n'/$'\n'    }"
  log "the firewall: as system/net-allow.list says"
}
# _net_sysctl_rows → KEY VALUE, a line each; a key for every interface is checked on the ones
# that count: all, default, and the card with the default route
_net_sysctl_rows() {
  local k v i
  while IFS='= ' read -r k v; do
    [[ $k == net.* ]] || continue
    if [[ $k == *'*'* ]]; then
      for i in all default $(ip route show default 2>/dev/null | sed -n 's/.* dev \([^ ]*\).*/\1/p' | sort -u); do printf '%s %s\n' "${k/\*/$i}" "$v"; done
    else printf '%s %s\n' "$k" "$v"; fi
  done <"$REPO_DIR/system/sysctl-net.conf" | sort -u
}
net_sysctl_wrong() {
  local k v have
  cmp -s "$REPO_DIR/system/sysctl-net.conf" "$NET_SYSCTL_FILE" || echo "$NET_SYSCTL_FILE is not the project's"
  while IFS=' ' read -r k v; do
    have=$(sysctl -n "$k" 2>/dev/null) || have=none
    [[ $have == "$v" ]] || echo "$k = $have, should be $v"
  done < <(_net_sysctl_rows)
}
net_sysctl() {
  cmp -s "$REPO_DIR/system/sysctl-net.conf" "$NET_SYSCTL_FILE" \
    || { write_file "$NET_SYSCTL_FILE" 0644 <"$REPO_DIR/system/sysctl-net.conf"; restorecon "$NET_SYSCTL_FILE" 2>/dev/null || true; }
  sysctl -q -p "$NET_SYSCTL_FILE" || die "the kernel refuses $NET_SYSCTL_FILE (above)"
}
_net_dns_conf() {
  printf '%s\n' "# Fedokawaii — names over TLS (lib/net.sh says why these); no LLMNR and no mDNS: nothing here" \
    "# answers for names on the network, and neither is a door for anyone to spoof" \
    "[Resolve]" "DNS=$NET_DNS" "Domains=~." "DNSOverTLS=opportunistic" "LLMNR=no" "MulticastDNS=no"
}
net_dns_wrong() {
  [[ -f $NET_DNS_FILE && $(<"$NET_DNS_FILE") == "$(_net_dns_conf)" ]] || echo "$NET_DNS_FILE is not the project's"
}
net_dns() {
  [[ -z $(net_dns_wrong) ]] && return 0
  _net_dns_conf | write_file "$NET_DNS_FILE" 0644
  restorecon "$NET_DNS_FILE" 2>/dev/null || true
  systemctl try-reload-or-restart systemd-resolved.service 2>/dev/null || true
}
# net_strays → every socket others could reach that the list does not name: "tcp/1234 what"
net_strays() {
  local proto addr f rest port known
  known=$(awk '/^[0-9]/ && $2 != "local" { print $1 }' "$REPO_DIR/system/net-allow.list")
  while IFS=' ' read -r proto _ _ _ addr _ f rest; do
    port=${addr##*:}
    case ${addr%:*} in 127.*|'[::1]'|'[::ffff:127.'*) continue ;; esac
    grep -qxF "$port/$proto" <<<"$known" && continue
    printf '%s/%s %s\n' "$port" "$proto" "$(sed -n 's/.*(("\([^"]*\)".*/\1/p' <<<"$f $rest")"
  done < <(ss -H -tulnp 2>/dev/null) | LC_ALL=C sort -u
}
