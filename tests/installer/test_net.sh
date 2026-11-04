#!/usr/bin/env bash
# tests/installer/test_net.sh — every door of the machine (T39): system/net-allow.list makes the
# firewall (lib/net.sh), and verify holds the machine against it. setup's steps in the fake
# machine: the files as the list says, a reload only when something changed, a refused file
# leaving the old ones in place; SSH only with a key; the remote page's door only with the page;
# the kernel's settings and the names over TLS; verify naming each difference.
. "$(dirname "$0")/lib.sh"
TK=/usr/local/lib/fedokawaii
V() { fkrun bash "$TK/verify.sh" "$@"; }
# one step of setup, as setup runs it: lib/net.sh with the machine's settings
step() {
  fkrun bash -c 'set -Eeuo pipefail; IFS=$'"'"'\n\t'"'"'; REPO_DIR=/usr/local/lib/fedokawaii LOG_FILE=/tmp/net.log STATE_DIR=/var/lib/fedokawaii
    . "$REPO_DIR/lib/common.sh"; . "$REPO_DIR/lib/net.sh"; read_conf "$REPO_DIR/fedokawaii.conf"
    TARGET_USER=fkuser TARGET_HOME=/home/fkuser; "$@"' _ "$@"
}
zone() { cat "$W/etc/firewalld/zones/$1.xml" 2>/dev/null; }
key() { fk runuser -u fkuser -- bash -c 'mkdir -p /home/fkuser/.ssh; echo "ssh-ed25519 AAAAC3Nza fkuser@laptop" >/home/fkuser/.ssh/authorized_keys'; }

world built
keep built

case_ "the list itself: every row a port, a place and a condition this code knows; every lan or world door has a reason"
while IFS=' ' read -r p w when rest; do
  [[ $p =~ ^[0-9]+/(tcp|udp)$ ]] && _ok || _no "$p is no port/proto"
  [[ $w == @(world|lan|local|shut) ]] && _ok || _no "$p: $w is no place"
  [[ $when == @(always|ssh|remote) ]] && _ok || _no "$p: $when is no condition"
  [[ -n $rest ]] && _ok || _no "$p has no reason"
done < <(grep '^[0-9]' "$REPO/system/net-allow.list")
eq "$(grep -v '^#' "$REPO/system/net-allow.list" | grep -c 'world')" 2 "two world doors, torrents' alone: a new one is a decision, and this test says so"

case_ "a machine that never had our firewall (Fedora Server's default zone, its stock open services): made in one step, one reload, every door as the list says"
back built
rm -f "$W"/etc/firewalld/zones/* "$W"/etc/firewalld/policies/*
rm -rf "$FKH/fw-run"; rm -f "$FKH/fw-default"; mkdir -p "$FKH/fw-run/zones" "$FKH/fw-run/policies"
printf '<zone>\n  <service name="ssh"/>\n  <service name="cockpit"/>\n</zone>\n' >"$W/etc/firewalld/zones/FedoraServer.xml"; cp "$W/etc/firewalld/zones/FedoraServer.xml" "$FKH/fw-run/zones/"
: >"$W/etc/firewalld/zones/public.xml.old"
: >"$CALLS"; step net_firewall; eq "$RC" 0 "$OUT"
has "$(zone public)" '<zone target="DROP">'
for d in 'port="6881" protocol="tcp"' 'port="6881" protocol="udp"'; do has "$(zone public)" "$d"; has "$(zone kawa-lan)" "$d"; done
lacks "$(zone public)" 53317; lacks "$(zone public)" 'service name'; lacks "$(zone public)" '<forward/>'
for d in 'port="53317" protocol="tcp"' 'port="53317" protocol="udp"' 'port="546" protocol="udp"'; do has "$(zone kawa-lan)" "$d"; done
for s in 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 169.254.0.0/16 fc00::/7 fe80::/10; do has "$(zone kawa-lan)" "<source address=\"$s\"/>"; done
lacks "$(zone kawa-lan)" 'target='; lacks "$(zone kawa-lan)" '<forward/>'
has "$(cat "$W/etc/firewalld/policies/kawa-no-upnp.xml")" 'port="1900"'; has "$(cat "$W/etc/firewalld/policies/kawa-no-upnp.xml")" 'port="5351"'
eq "$(cat "$FKH/fw-default")" public "the default zone"
eq "$(grep -c 'firewall-cmd\] .*--reload' "$CALLS")" 1 "one reload"
[[ ! -e $W/etc/firewalld/zones/public.xml.old ]] && _ok || _no "firewalld's .old left in the folder"
called 'systemctl\] enable --now firewalld.service'

case_ "run again with nothing to change: no reload (a reload's short hold on the network is never spent for nothing)"
: >"$CALLS"; step net_firewall; eq "$RC" 0 "$OUT"; not_called 'firewall-cmd\] .*--reload'

case_ "the rules running differ from the files (a port added while it runs, a rule by hand): the files win, by a reload"
sed -i 's|</zone>|  <port port="8080" protocol="tcp"/>\n</zone>|' "$FKH/fw-run/zones/public.xml"
: >"$CALLS"; step net_firewall; eq "$RC" 0 "$OUT"; called 'firewall-cmd\] .*--reload'; lacks "$(cat "$FKH/fw-run/zones/public.xml")" 8080

case_ "a file edited by hand comes back to what the list says"
sed -i 's/target="DROP"/target="ACCEPT"/' "$W/etc/firewalld/zones/public.xml"
: >"$CALLS"; step net_firewall; eq "$RC" 0 "$OUT"; has "$(zone public)" 'target="DROP"'; called 'firewall-cmd\] .*--reload'

case_ "firewalld refuses the new rules: the old files stay, its rules untouched, a clear stop"
sed -i 's/ The world / old /' "$W/etc/firewalld/zones/public.xml"; before=$(zone public)
rm -f "$W/etc/firewalld/policies/kawa-no-upnp.xml"
fkh fw-bad
: >"$CALLS"; step net_firewall; eq "$RC" 1; has "$OUT" "firewalld refuses the new rules"; not_called 'firewall-cmd\] .*--reload'
eq "$(zone public)" "$before" "the old zone is back"; [[ ! -e $W/etc/firewalld/policies/kawa-no-upnp.xml ]] && _ok || _no "a new file stayed"
rm -f "$FKH/fw-bad"

case_ "firewalld will not start: a clear stop, never a machine left without a firewall in silence"
back built; echo 1 >"$FKH/rc-enable-firewalld.service"
step net_firewall; eq "$RC" 1; has "$OUT" "firewalld does not start"

case_ "the remote page: its door opens from the LAN once the page is installed, never to the world"
back built
mkdir -p "$W/home/fkuser/.config/systemd/user"; : >"$W/home/fkuser/.config/systemd/user/fk-remote.service"
step net_firewall; eq "$RC" 0 "$OUT"; has "$(zone kawa-lan)" 'port="8737"'; lacks "$(zone public)" 8737

case_ "SSH: a key in authorized_keys opens the LAN's door and only that; a comment is no key; SSH_SERVER=no closes it whatever the keys"
back built
fk runuser -u fkuser -- bash -c 'mkdir -p /home/fkuser/.ssh; printf "# my keys\n\n" >/home/fkuser/.ssh/authorized_keys'
step net_firewall; eq "$RC" 0 "$OUT"; lacks "$(zone kawa-lan)" 'port="22"' "a comment is no key"
key; step net_firewall; eq "$RC" 0 "$OUT"; has "$(zone kawa-lan)" 'port="22" protocol="tcp"'; lacks "$(zone public)" 'port="22"'
fk sed -i 's/^SSH_SERVER="yes"/SSH_SERVER="no"/' "$TK/fedokawaii.conf"
step net_firewall; eq "$RC" 0 "$OUT"; lacks "$(zone kawa-lan)" 'port="22"'

case_ "s_ssh in setup: no key, sshd off and its rules still in place; a key, on for every boot"
back built
sshstep() {
  fkrun bash -c 'set -Eeuo pipefail; IFS=$'"'"'\n\t'"'"'; REPO_DIR=/usr/local/lib/fedokawaii LOG_FILE=/tmp/net.log STATE_DIR=/var/lib/fedokawaii
    . "$REPO_DIR/lib/common.sh"; . "$REPO_DIR/lib/net.sh"; read_conf "$REPO_DIR/fedokawaii.conf"; TARGET_USER=fkuser TARGET_HOME=/home/fkuser
    eval "$(sed -n "/^SSHD_DROPIN=/,/^s_network()/p" "$REPO_DIR/setup.sh")"; s_ssh'
}
fkh_add units "enabled sshd.service"; fkh_add units "active sshd.service"
: >"$CALLS"; sshstep; eq "$RC" 0 "$OUT"; called 'systemctl\] disable --now sshd.service'
has "$(cat "$W/etc/ssh/sshd_config.d/40-fedokawaii.conf")" "KbdInteractiveAuthentication no"
key; : >"$CALLS"; sshstep; eq "$RC" 0 "$OUT"; called 'systemctl\] enable sshd.service'; called 'systemctl\] reload-or-restart sshd.service'
echo 1 >"$FKH/rc-sshd-t"; : >"$CALLS"; sshstep; eq "$RC" 1 "sshd -t refused"; has "$OUT" "sshd refuses its configuration"; rm -f "$FKH/rc-sshd-t"

case_ "the kernel's settings: the file in place and in force at once; the names: over TLS, nothing from the router, no LLMNR, no mDNS; once"
back built
rm -f "$W/etc/sysctl.d/60-fedokawaii-net.conf" "$W/etc/systemd/resolved.conf.d/90-fedokawaii.conf" "$FKH/sysctl-now"
: >"$CALLS"; step net_sysctl; eq "$RC" 0 "$OUT"; cmp -s "$REPO/system/sysctl-net.conf" "$W/etc/sysctl.d/60-fedokawaii-net.conf" && _ok || _no "the file"
called 'sysctl\] -q -p /etc/sysctl.d/60-fedokawaii-net.conf'
: >"$CALLS"; step net_dns; eq "$RC" 0 "$OUT"; called 'systemctl\] try-reload-or-restart systemd-resolved.service'
d=$(cat "$W/etc/systemd/resolved.conf.d/90-fedokawaii.conf")
for l in 'DNSOverTLS=opportunistic' 'Domains=~.' 'LLMNR=no' 'MulticastDNS=no' 'cloudflare-dns.com' 'dns.quad9.net' '2606:4700:4700::1111'; do has "$d" "$l"; done
: >"$CALLS"; step net_dns; eq "$RC" 0; not_called 'try-reload-or-restart'

case_ "verify: a sound machine passes; each difference named, and it fails"
back built
V; eq "$RC" 0 "$(grep '✘' <<<"$OUT" | head -n4 | tr '\n' '|')"
has "$OUT" "✔  the firewall: only the list's doors (world: 6881/tcp 6881/udp"
has "$OUT" "✔  the kernel's network settings in force"; has "$OUT" "✔  names go over TLS; no LLMNR, no mDNS"
has "$OUT" "✔  what listens: only the list's doors"; has "$OUT" "✔  no forwarding"; has "$OUT" "✔  sshd off"
sed -i 's|</zone>|  <port port="22" protocol="tcp"/>\n</zone>|' "$FKH/fw-run/zones/public.xml"
V; eq "$RC" 3; has "$OUT" "✘  the firewall: zone public opens ports [22/tcp 6881/tcp 6881/udp], the list says [6881/tcp 6881/udp]"
back built; sed -i 's|</zone>|  <service name="ssh"/>\n</zone>|' "$FKH/fw-run/zones/kawa-lan.xml"
V; eq "$RC" 3; has "$OUT" "✘  the firewall: zone kawa-lan opens services: ssh"
back built; sed -i 's/ target="DROP"//' "$FKH/fw-run/zones/public.xml"
V; eq "$RC" 3; has "$OUT" "✘  the firewall: zone public has target default"
back built; sed -i 's|</zone>|  <forward/>\n</zone>|' "$FKH/fw-run/zones/public.xml"
V; eq "$RC" 3; has "$OUT" "✘  the firewall: zone public forwards"
back built; sed -i '/10.0.0.0/d' "$FKH/fw-run/zones/kawa-lan.xml"
V; eq "$RC" 3; has "$OUT" "✘  the firewall: zone kawa-lan holds sources"
back built; rm -f "$FKH/fw-run/policies/kawa-no-upnp.xml"
V; eq "$RC" 3; has "$OUT" "✘  the firewall: policy kawa-no-upnp is not running"
back built; echo FedoraServer >"$FKH/fw-default"
V; eq "$RC" 3; has "$OUT" "✘  the firewall: the default zone is FedoraServer, not public"
back built; sed -i 's/^LLMNR=no/LLMNR=yes/' "$W/etc/systemd/resolved.conf.d/90-fedokawaii.conf"
V; eq "$RC" 3; has "$OUT" "✘  names: /etc/systemd/resolved.conf.d/90-fedokawaii.conf is not the project's"
back built; mkdir -p "$FKH/sysctl-now.d"; echo 1 >"$FKH/sysctl-now.d/net.ipv4.conf.all.accept_redirects"; echo 2 >"$FKH/sysctl-now.d/net.ipv4.conf.enp5s0.rp_filter"
V; eq "$RC" 3; has "$OUT" "✘  the kernel's network settings: net.ipv4.conf.all.accept_redirects = 1, should be 0"; has "$OUT" "net.ipv4.conf.enp5s0.rp_filter = 2, should be 1"
back built; fkh_add units "active sshd.service"
V; eq "$RC" 3; has "$OUT" "✘  sshd off"
back built; key; V; eq "$RC" 3; has "$OUT" "✘  sshd on (a key in authorized_keys), at every boot"
back built; key; fkh_add units "enabled sshd.service"; fkh_add units "active sshd.service"
step net_firewall; eq "$RC" 0 "$OUT"
V; eq "$RC" 0 "$(grep '✘' <<<"$OUT" | head -n3 | tr '\n' '|')"; has "$OUT" "✔  sshd on (a key in authorized_keys)"

case_ "verify: a stray listener is said (the firewall holds it), never a failure; loopback is nobody's business; forwarding switched on is said"
back built
stub ss "cat <<'EOF'
tcp LISTEN 0 4096 127.0.0.1:43587 0.0.0.0:* users:((\"steam\",pid=2370,fd=46))
tcp LISTEN 0 128 0.0.0.0:6000 0.0.0.0:* users:((\"strange\",pid=2,fd=46))
udp UNCONN 0 0 [::]:4242 [::]:* users:((\"odd\",pid=3,fd=1))
EOF"
mkdir -p "$FKH/sysctl-now.d"; echo 1 >"$FKH/sysctl-now.d/net.ipv4.ip_forward"
V; eq "$RC" 0 "$(grep '✘' <<<"$OUT" | head -n3 | tr '\n' '|')"
has "$OUT" "!  listening, not on the list: 4242/udp odd 6000/tcp strange"; lacks "$OUT" "43587"
has "$OUT" "!  forwarding is on"

case_ "repair and the update run the same steps; setup's phase 1 too (one code path, whatever the way in)"
grep -q 'step "1.7b .*s_network' "$REPO/setup.sh" && _ok || _no "phase 1"
grep -q 'r_ports() { s_ssh; s_network; }' "$REPO/setup.sh" && _ok || _no "repair"
grep -q 'step_on .*s_network' "$REPO/setup.sh" && _ok || _no "update and apply"

done_
