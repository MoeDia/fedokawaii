#!/usr/bin/env bash
# tools/net-proof.sh — what the doors are for still works, and what they keep out stays out: the
# names over TLS (nothing plain to port 53), updates, Syncplay, a real torrent swarm, the remote
# page and LocalSend from the far end of a cable (from the LAN they answer, from the world they do
# not), no UPnP leaving. Run after any change to the network's rules, as root; tools/portscan.sh
# proves the doors themselves, this what uses them. A program not running is said, not started
# (the remote page, LocalSend), the torrent session is its own: a real public swarm, Debian's
# installer, for a minute, kept nowhere.
#   sudo bash tools/net-proof.sh [--no-swarm]
# Exit 0 all well · 1 something failed (named) · 2 misuse.
set -uo pipefail
IFS=$'\n\t'
export LC_ALL=C.UTF-8
[[ $EUID -eq 0 ]] || { echo "net-proof: run with sudo" >&2; exit 2; }
SWARM=1; [[ ${1:-} == --no-swarm ]] && SWARM=0
U=$(sed -n 1p /var/lib/fedokawaii/user 2>/dev/null | tr -d '[:space:]'); U=${U:-${SUDO_USER:-root}}
UH=$(getent passwd "$U" | cut -d: -f6)
NS=kawa-proof VETH=kawa-proof0 TABLE=kawa_proof
TMP=$(mktemp -d /dev/shm/kawa-proof.XXXXXX)
cleanup() { ip netns del "$NS" 2>/dev/null; ip link del "$VETH" 2>/dev/null; nft delete table inet "$TABLE" 2>/dev/null; rm -rf -- "$TMP"; }
trap cleanup EXIT
trap 'exit 1' INT TERM HUP
rc=0
ok() { printf '✔ %s\n' "$*"; }
no() { printf '✘ %s\n' "$*"; rc=1; }
say() { printf '· %s\n' "$*"; }

# ── names ─────────────────────────────────────────────────────────────────────
nft -f - <<EOF || { no "nftables refused the counting table"; exit 1; }
table inet $TABLE {
  counter plain { }
  counter tls { }
  chain out {
    type filter hook output priority 100; policy accept;
    oifname != "lo" oifname != "$VETH" meta skuid != "$(id -u "$U")" meta l4proto { tcp, udp } th dport 53 counter name plain
    oifname != "lo" meta l4proto tcp th dport 853 counter name tls
  }
}
EOF
names=(fedoraproject.org github.com kernel.org syncplay.pl store.steampowered.com dl.flathub.org mirrors.fedoraproject.org router.bittorrent.com)
bad=0; for n in "${names[@]}"; do resolvectl query --cache=no --legend=no "$n" >/dev/null 2>&1 || { no "the name $n"; bad=1; }; done
((bad)) || ok "names resolve (${#names[@]}, none from a cache)"
pl=$(nft list counter inet "$TABLE" plain | sed -n 's/.*packets \([0-9]*\).*/\1/p'); tl=$(nft list counter inet "$TABLE" tls | sed -n 's/.*packets \([0-9]*\).*/\1/p')
if ((${tl:-0} > 0 && ${pl:-1} == 0)); then ok "names went over TLS ($tl packets to port 853, none to port 53)"
elif ((${pl:-1} > 0)); then no "names leaked: $pl packets to port 53"
else say "no new packets to port 853 (an open connection answered, or this network blocks it)"; fi

# ── what the machine fetches ──────────────────────────────────────────────────
timeout 180 dnf -q makecache --refresh >/dev/null 2>&1 && ok "updates: dnf reads every repository" || no "dnf makecache failed"
for u in https://github.com/ https://dl.flathub.org/repo/summary.idx https://lscr.io/v2/; do
  c=$(curl -sS -o /dev/null -m 15 -w '%{http_code}' "$u" 2>/dev/null)
  [[ $c =~ ^[234] ]] && ok "reachable: $u ($c)" || no "$u answered ${c:-nothing}"
done
c=$(curl -sS -m 15 -o /dev/null -w '%{http_code}' https://api.steampowered.com/ISteamWebAPIUtil/GetServerInfo/v1/ 2>/dev/null)
[[ $c == 200 ]] && ok "Steam's servers answer" || no "Steam's servers: ${c:-nothing}"
grep -q '^\^[*+]' <<<"$(timeout 15 chronyc -n sources 2>/dev/null)" && ok "the clock has a source" || no "chrony has no source"

# ── Syncplay: its public server, the way the client starts ────────────────────
python3 -I - <<'PY' && ok "Syncplay's server answers and offers TLS" || no "Syncplay's server (syncplay.pl:8999)"
import json, socket, sys
s = socket.create_connection(("syncplay.pl", 8999), timeout=10); s.settimeout(10)
s.sendall(b'{"TLS": {"startTLS": "send"}}\r\n')
d = b""
while b"\n" not in d: d += s.recv(4096)
sys.exit(0 if json.loads(d.split(b"\n")[0]).get("TLS", {}).get("startTLS") == "true" else 1)
PY

# ── no program opens a port on the router ─────────────────────────────────────
python3 -I - <<'PY' && ok "UPnP and NAT-PMP stop at the firewall" || no "UPnP or NAT-PMP left this machine"
import socket, subprocess, sys
gw = subprocess.run(["ip", "-4", "route", "show", "default"], capture_output=True, text=True).stdout.split()
gw = gw[2] if len(gw) > 2 else "192.0.2.1"
msg = b"M-SEARCH * HTTP/1.1\r\nHOST: 239.255.255.250:1900\r\nMAN: \"ssdp:discover\"\r\nMX: 1\r\nST: ssdp:all\r\n\r\n"
res = []
for dst, port, m in (("239.255.255.250", 1900, msg), (gw, 1900, msg), (gw, 5351, b"\0\0")):
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM); s.settimeout(2)
    try:
        s.connect((dst, port)); s.send(m); s.recv(4096); res.append(False)    # an answer: it got out
    except (ConnectionRefusedError, PermissionError, OSError, TimeoutError) as e:
        res.append(not isinstance(e, TimeoutError))                           # refused here: it never left
sys.exit(0 if all(res[1:]) else 1)
PY

# ── the far end of a cable: a neighbour, and a stranger ───────────────────────
T=$(ip -4 -o addr show scope global | awk -v v="$VETH" '$2 != v { sub(/\/.*/, "", $4); print $4; exit }')
ip netns add "$NS" && ip link add "$VETH" type veth peer name eth0 netns "$NS" || { no "the cable"; exit 1; }
ip addr add 10.199.42.1/24 dev "$VETH"; ip addr add 198.51.100.1/24 dev "$VETH"; ip link set "$VETH" up
N=(ip netns exec "$NS")
"${N[@]}" ip link set lo up; "${N[@]}" ip addr add 10.199.42.2/24 dev eth0; "${N[@]}" ip addr add 198.51.100.2/24 dev eth0; "${N[@]}" ip link set eth0 up
"${N[@]}" ip route add "$T/32" via 10.199.42.1
far() { "${N[@]}" curl -sS -k -m 4 -o /dev/null -w '%{http_code}' --interface "$1" "${@:2}" 2>&1; }
LAN=10.199.42.2 WORLD=198.51.100.2
if [[ -n $(ss -Htln 'sport = :8737') ]]; then
  c=$(far "$LAN" "http://$T:8737/"); [[ $c == *200 ]] && ok "the remote page answers the LAN" || no "the remote page, from the LAN: $c"
  c=$(far "$LAN" "http://$T:8737/api/state"); [[ $c == *401 ]] && ok "the remote page wants its token" || no "the remote page's state without a token: $c"
  c=$(far "$WORLD" "http://$T:8737/"); [[ $c == *000* || $c == *timed* ]] && ok "the remote page is silent to the world" || no "the remote page answered the world: $c"
else say "the remote page is not running"; fi
if [[ -n $(ss -Htln 'sport = :53317') ]]; then
  # (LocalSend's HTTPS asks for a client certificate: the handshake reaching that question is the answer)
  c=$("${N[@]}" curl -sS -k -m 4 -o /dev/null --interface "$LAN" "https://$T:53317/api/localsend/v2/info" 2>&1); [[ $c == *"certificate required"* || $c == "" ]] && ok "LocalSend answers the LAN" || no "LocalSend, from the LAN: $c"
  c=$("${N[@]}" curl -sS -k -m 4 -o /dev/null --interface "$WORLD" "https://$T:53317/api/localsend/v2/info" 2>&1); [[ $c == *imed* ]] && ok "LocalSend is silent to the world" || no "LocalSend answered the world: $c"
else say "LocalSend is not running"; fi
c=$("${N[@]}" ping -c1 -W2 -I "$WORLD" "$T" 2>&1 | grep -c ' 0% packet loss'); ((c == 0)) && ok "a ping from the world: silence" || no "the world's ping answered"

# ── a real swarm, for a minute: peers, DHT, strangers coming in through the port ──
if ((SWARM)); then
  py=$UH/.local/share/uv/tools/torrra/bin/python; "$py" -I -c 'import libtorrent' 2>/dev/null || py=python3
  if ! "$py" -I -c 'import libtorrent' 2>/dev/null; then say "no libtorrent here: the swarm left out"
  elif [[ -n $(ss -Htln 'sport = :6881') ]]; then say "the torrents window is open: the swarm left out"
  else
    chmod 755 "$TMP"; d=$TMP/swarm; mkdir -p "$d"; chown "$U" "$d"     # (the session runs as you, its files in here)
    (cd "$d" && runuser -u "$U" -- env -u PYTHONPATH "$py" -I - "$d" >"$TMP/swarm.out" 2>&1) <<'PY' &
import json, sys, time, urllib.request, re
import libtorrent as lt
d = sys.argv[1]
idx = urllib.request.urlopen("https://cdimage.debian.org/debian-cd/current/amd64/bt-cd/", timeout=20).read().decode()
name = re.search(r'href="(debian-[0-9.]+-amd64-netinst\.iso\.torrent)"', idx).group(1)
data = urllib.request.urlopen("https://cdimage.debian.org/debian-cd/current/amd64/bt-cd/" + name, timeout=20).read()
ses = lt.session({"listen_interfaces": "0.0.0.0:6881,[::]:6881", "enable_dht": True, "enable_lsd": False, "enable_upnp": False, "enable_natpmp": False,
                  "dht_bootstrap_nodes": "dht.libtorrent.org:25401,router.bittorrent.com:6881", "download_rate_limit": 2_000_000, "upload_rate_limit": 200_000,
                  "alert_mask": lt.alert.category_t.peer_notification})
ti = lt.torrent_info(lt.bdecode(data))
h = ses.add_torrent({"ti": ti, "save_path": d})
best = 0; t0 = time.time(); got = 0; nodes = 0; incoming = set()
while time.time() - t0 < 60:
    time.sleep(2)
    s = h.status(); best = max(best, s.num_peers); got = s.total_wanted_done; nodes = ses.status().dht_nodes
    for a in ses.pop_alerts():
        if isinstance(a, lt.incoming_connection_alert): incoming.add(a.endpoint[0])
    if best >= 8 and got > 2_000_000 and nodes > 20 and incoming: break
    if s.errc.value(): print(json.dumps({"error": s.errc.message()})); sys.exit(1)
print(json.dumps({"torrent": name, "peers": best, "bytes": got, "dht_nodes": nodes, "listening": ses.is_listening(), "port": ses.listen_port(),
                  "came_in": len(incoming), "over_ipv6": sum(":" in i for i in incoming), "seconds": round(time.time() - t0)}))
ses.pause(); ses.remove_torrent(h)
PY
    swarm=$!
    wait "$swarm"; r=$(tail -n1 "$TMP/swarm.out")
    if python3 -I -c 'import json,sys; d=json.loads(sys.argv[1]); sys.exit(0 if d["peers"]>0 and d["bytes"]>0 and d["dht_nodes"]>0 and d["listening"] else 1)' "$r" 2>/dev/null; then ok "a real swarm: $r"
    else no "the swarm: $r"; fi
  fi
fi
((rc == 0)) && echo "✔ all well" || echo "✘ something failed (above)"
exit "$rc"
