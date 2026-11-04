# T39: network security. Audit and plan (lane-research2, 4 Nov 2026)

Reads and two harmless outbound measurements only; **nothing was changed.** I had no root here, so firewalld's rules
are taken from the main run's read of 3 Nov (ledger `r27-39-audit`), and everything else was read at 18:00 today.
**This is the audit. `lane-network` built on it** (1da3116 to ff61694; its `system/net-allow.list` and `lib/net.sh` are
the truth now). Section 3 says where the build differs, and where I was wrong.

## 1. The findings that matter

1. **This PC has a public IPv6 address** (directly routed, no NAT) and `sshd` listens on `[::]:22` with the firewall's `ssh` open to any source. Whether the router filters inbound IPv6 is unknown. **So the firewall is the only defence I can vouch for**, and "behind the router" must not be assumed.
2. **sshd can't be used by anyone and nobody has tried:** `~/.ssh/authorized_keys` is empty (0 bytes), with keys-only login, and the journal holds 0 accepted, 0 failed, 0 invalid-user lines back to 27 Oct (8 boots; it does log sshd, 298 lines in that time). **Turn it off.** The plan allows "keys-only or off", and off removes the only always-on service exposed worldwide.
3. **Today's torrent engine asks the router to open ports.** `torrra/core/download.py:55-66` sets `enable_upnp: True`, `enable_natpmp: True`, `enable_lsd: True`, and listens on `0.0.0.0:6881,[::]:6881,0.0.0.0:0,[::]:0`. His "no UPnP surprises" is violated whenever a torrent runs. **`lane-torrents` already fixes it** by replacing torrra with its own engine, all three off (section 5): it holds only until that merge.
4. **The firewall's `mdns` is open and nothing uses it.** `avahi` is not installed, `resolved` shows `-mDNS`, `ss` shows no 5353. The comment in `/etc/systemd/resolved.conf.d/90-fedokawaii.conf` ("names on the home network go by mDNS (avahi: NAME.local)") is stale, and so is the wording of the check at `verify.sh:439`.
5. **OpenRGB's udev rule gives his user every I2C bus**, including the SMBus that holds the RAM's SPD (`60-openrgb.rules:8`). Not a network hole, but a local one; T36's digest drops it.
6. **DoT costs almost nothing here and is not blocked** (section 6), so DNS privacy is possible. **Correction of my own first test:** it showed all servers failing because `openssl` is not installed on this PC, not because of the network. The real test used Python's `ssl`.

## 2. Every listening socket today, and its fate

| Socket | Owner | Reach today | Decision | Source |
|---|---|---|---|---|
| `0.0.0.0:22`, `[::]:22` | sshd | **world** (firewall `ssh`) | **Off:** `SSH_SERVER=no` | finding 2; `setup.sh:2083` already does the rest |
| `0.0.0.0:8737` | `fk-remote` (`~/.local/share/fedokawaii/remote/server.py`, the owner's page) | LAN, by a rich rule for `10.62.79.0/24`, IPv4 only | **Keep** (CLAUDE.md: "never remove"). Moves to the LAN zone | ledger `r27-39-audit` |
| `fe80::…%enp8s0:546` udp | NetworkManager, DHCPv6 | link | Keep: `dhcpv6-client` | |
| `127.0.0.53:53`, `127.0.0.54:53` | resolved | loopback | Keep | |
| `127.0.0.1:323`, `[::1]:323` | chronyd control | loopback | Keep | |
| `127.0.0.1:11434` | Ollama | loopback | T47 decides its life (the ledger's finding) | |
| `127.0.0.1:19696` | `pasta` (`pid 4056331`): a lane's trial container | loopback | Not the installer's: a run's leftover to check at the end | |
| `127.0.0.1:2230`, `:2290` | `passt` for proof VMs `fk-r27-updates`, `r27-iso` | loopback | Not the installer's | |
| *not running now* `127.0.0.1:9696` | Prowlarr (`system/prowlarr.container`: `PublishPort=127.0.0.1:9696:9696`) | loopback | Keep. Rootless through `pasta`, no DNAT, so firewalld's `StrictForwardPorts` caveat does not apply | `man firewalld.conf` |
| *while it runs* `:6881` tcp and udp | torrra | world | Keep, by need; section 5 | |
| *while it runs* `:53317` tcp and udp | LocalSend | world | **LAN zone** | ledger: "LAN is enough" |
| none | Steam `:27036` | the ledger saw it on 3 Nov | Moves into ASOBI's account (plan T32). `lane-network`'s list keeps it `shut` at the firewall | |
| none | Syncplay | `bin/kawa-together` is a client of public servers; no listener | Nothing to do. The plan's "server only when hosting" has no caller today | `bin/kawa-together:7-13` |

**Rule for the allow-list:** loopback is never a finding; every non-loopback socket must be listed.

## 3. The firewall: planned and built

Firewalld 2.4.4. Stock `public` carries `ssh`, `mdns`, `dhcpv6-client`, and `FedoraServer` adds `cockpit` (`/usr/lib/firewalld/zones/`). **A clean install must therefore not assume which default zone it got: VM-prove it** (memory `clean-install-vm-often`).

**Two zones instead of rich rules:** `public`, the card's, what the world meets; and a LAN zone bound by the private source ranges rather than `10.62.79.0/24`, because his router can renumber and today's rule would silently lock him out of his own page. His global IPv6 prefix is **not** in it, so `8737` stays unreachable from the IPv6 Internet, and `fk-remote` binds IPv4 only anyway. Add the zone **before** removing the old rule for `8737`: it was the page's only protection, so there must never be a moment when it is cut.

**Where `lane-network`'s build differs (read at 18:50, not re-proved here):**

| | Planned here | Built | Verdict |
|---|---|---|---|
| `public`'s target | default, because "dropping ICMPv6 breaks path MTU discovery" | **DROP** | **The build is right and my reason was wrong** (below) |
| `sshd` | `SSH_SERVER=no` | only with `SSH_SERVER=yes` and a key in `authorized_keys`, LAN only | The same today (the file is empty), better later |
| `rp_filter` | keep loose, "T33 is coming" | strict, proved over a reboot, NetworkManager's MPTCP loosening caught | Right: T33 is gone |
| DNS | `DNSOverTLS=yes`, Quad9 | `opportunistic`, Cloudflare then Quad9 | A fair trade (section 6) |
| UPnP | off in the torrent engine | also a policy rejecting UDP 1900 and 5351 leaving the host | Better |

**Why DROP is safe, from firewalld's own source:**
- `filter_INPUT` accepts `ct state established,related` before any zone (`firewall/core/nftables.py:760-780`), so a Packet Too Big for our own connection passes. **Path MTU discovery is unaffected.** RFC 4890 section 4.4.1 says these must not be dropped, and they are not.
- Neighbour Discovery has no connection to belong to: the kernel marks NS, NA, RS, RA and MLD untracked (`nf_conntrack_proto_icmpv6.c`, `noct_valid_new`), so they do reach the zones, and a DROP could kill them. It does not, because the built-in policy **`allow-host-ipv6`** (`/usr/lib/firewalld/policies/`, priority -15000, ANY to HOST) accepts NA, NS, RA, redirect and MLD first.
- **I doubted this and tested it, 18:42, with the build's zones active** (`firewall-cmd --get-active-zones`; the target itself needs root to read): one `ping -6` to the router's global address, its neighbour entry went from STALE through a fresh probe to REACHABLE, `Icmp6OutNeighborSolicits` 86 to 87, `Icmp6InNeighborAdvertisements` 75 to 76.
- **One dependency:** under DROP, IPv6 now rests on that one stock policy. If an update renamed it, IPv6 would stop with no error at all. `net_firewall_wrong` already checks `kawa-no-upnp`; the same line for `allow-host-ipv6` would make that loud. Small, and it is what update-proofing is for.

**Settled, source before interface.** I had asked for an explicit `ingress-priority`, not having found the order documented. It is in the source, `_policy_dispatch_sort_key` (`nftables.py:1172-1246`): at equal priority a source-bound zone sorts before an interface-bound one (1 against 2), and the default zone is always last, "a catch-all". **No priority is needed;** `lib/net.sh`'s comment is right.

**Reload:** a new zone needs one reload. `firewalld.conf`'s `ReloadPolicy` defaults to dropping new connections during it. Rootless `pasta` and `passt` add no firewall rules, so it should not touch them.

## 4. Sysctls

`/etc/sysctl.d/60-fedokawaii-net.conf`. Against `docs.kernel.org/networking/ip-sysctl`, read today. **`all` is not enough on its own:** for `accept_redirects` on a non-forwarding host the kernel enables it if "at least one of `conf/{all,interface}/accept_redirects` is TRUE". So write `all`, `default` and the `*` glob, the way Fedora's `50-default.conf` does for `rp_filter`. systemd applies the prefix when a NIC appears.

| Key | Now | Set | Why |
|---|---|---|---|
| `net.ipv4.conf.*.accept_redirects` | 1 (`all`, `enp8s0`) | **0** | A host with one gateway needs none; a redirect is an on-LAN route hijack |
| `net.ipv4.conf.*.secure_redirects` | 1 | **0** | Same; moot at the above, set for clarity |
| `net.ipv4.conf.*.send_redirects` | 1 | **0** | It "sends redirects when acting as a router"; it is not one |
| `net.ipv6.conf.*.accept_redirects` | 1 | **0** | IPv6 parity |
| `net.ipv4.conf.*.accept_source_route` | 0 | keep | Fedora's already |
| `net.ipv6.conf.*.accept_source_route` | 0 | **-1** | The kernel doc: 0 or higher still accepts routing header type 2 (mobile IPv6), a negative value rejects them all; nothing here needs them |
| `net.ipv4.conf.*.rp_filter` | `all`=0, `enp8s0`=2 | **strict, as built** | I said keep Fedora's loose, for T33's bridges. T33 is gone, and `lane-network` proved strict over a reboot (section 3) |
| `tcp_syncookies`, `icmp_echo_ignore_broadcasts`, `icmp_ignore_bogus_error_responses` | 1, 1, 1 | keep | Kernel defaults |
| `net.ipv6.conf.*.accept_ra` | 1 | keep | He needs SLAAC |
| `net.ipv6.conf.*.use_tempaddr` | 0 | **set by NetworkManager**: `ipv6.ip6-privacy=2` (now `-1`) | Outbound connections stop showing a stable interface ID. Today's address is not EUI-64, so no MAC leaks already; low value, no measured cost yet. Check that NM's value overrides the sysctl |
| `log_martians`, `tcp_rfc1337`, `arp_*`, `tcp_timestamps` | | **leave** | No threat on one NIC that justifies a change. Martian logging adds journal noise with VMs. No hardening on faith |

Firewalld's `IPv6_rpfilter` is on by default (`man firewalld.conf`); `LogDenied` is off: keep it off.

## 5. Torrents (with `lane-torrents`, T29)

**Already done on `lane-torrents` (46ddd76, not merged):** `kawa-torrents/engine.py:335-338`: `listen_interfaces` `0.0.0.0:6881,[::]:6881`, `enable_lsd`, `enable_upnp`, `enable_natpmp` all `False`, with the comment "no port opened on the router behind your back"; `enable_dht` on, which magnets need. **Nothing for T39 to change there.** Two things for the merge:
- `engine.py:625` falls back to `0.0.0.0:0,[::]:0` if 6881 is taken. That is sound: the firewall still blocks those ports inbound and DHT keeps working. But verify's `ss` check would see an unlisted port, so **treat a libtorrent socket on an ephemeral port as allowed while the engine runs**, or have verify name the engine.
- Remove torrra's own settings from consideration once it is gone: `setup.sh:2930` (below) refers to it.
- **Honest cost:** without port mapping, behind the router's NAT on IPv4, peers cannot connect in, which can slow downloads on poorly seeded torrents. IPv6 peers still can reach him if the router passes them. **Measure before and after** in T29's stress test. If the loss is large, that is a decision to state in the ledger: one named port mapped on purpose, listed in the allow-list, not an accident of a default.
- **Security note for T29:** port 6881 accepts anyone by design, so libtorrent is the one internet-facing parser on this PC. Today `setup.sh:2930` refreshes torrra's; the new engine uses Fedora's `rb_libtorrent-python3`, so dnf keeps it current through the update button.

## 6. DNS privacy

**Today:** router `10.62.79.235`, plain; `LLMNR=no`; no mDNS.

**Measured 4 Nov, 18:05, from this PC, 5 tries each, Python `ssl`, certificate and name verified:**

| Server | TLS handshake | One query after it |
|---|---|---|
| `2620:fe::fe` Quad9 | 20 ms | 18 ms |
| `149.112.112.112` Quad9 | 23 ms | 20 ms |
| `9.9.9.9` Quad9 | 22 ms | 127 ms |
| `2606:4700:4700::1111` Cloudflare | 16 ms | 63 ms |
| `1.0.0.1` Cloudflare | 18 ms | 56 ms |
| `1.1.1.1` Cloudflare | 18 ms | 127 ms |
| `8.8.8.8` Google | 130 ms | 227 ms |
| Plain UDP for comparison: router | | 14 ms |
| Plain UDP: `1.1.1.1` / `9.9.9.9` | | 12 ms / 117 ms |

Names were uncached, and the medians of 5 are noisy. **So:** port 853 is open on this network and the extra cost is about one handshake (under 25 ms) when the connection is new.

**Built differently:** `lane-network` chose `opportunistic`, Cloudflare then Quad9 (`lib/net.sh`: "as fast at p50, and the router lost names these answer"; a network that blocks port 853 "costs privacy, not the internet"). The trade is real on both sides, as the next lines say, and it is decided there. **My narrower proposal, for the record:** `resolved` with Quad9, `DNS=2620:fe::fe#dns.quad9.net 2620:fe::9#dns.quad9.net 9.9.9.9#dns.quad9.net 149.112.112.112#dns.quad9.net`, `DNSOverTLS=yes`, `Domains=~.`, `FallbackDNS=` empty. Quad9 because it was among the fastest here over DoT, and its own policy says it "does not collect or record user IP addresses" (a Swiss public-benefit foundation). It blocks known malware domains on these addresses; `dns10.quad9.net` (9.9.9.10) is its unfiltered service, should a false positive ever matter.
- **`yes`, not `opportunistic`:** systemd's man page says opportunistic "makes DNS-over-TLS vulnerable to downgrade attacks". The price: "all DNS requests will fail" if the servers cannot be reached, and this network's policy could change. So **`verify` must test it**, and `kawa-refresh` must say so plainly. A router-side block would otherwise look like total network loss.
- **`DNSSEC=`:** leave `no` locally: Quad9 says "DNSSEC validation is enabled on all resolver addresses", and local validation is a separate change with separate failure modes.
- `/etc/resolv.conf` stays the stub, so browsers go through this. T31a's browser may do its own DoH: note what it does.

## 7. Verification

**Built by `lane-network`:** `system/net-allow.list`, one file that makes the firewall and that verify, the report and the scan all read; `tools/portscan.sh`, every port from outside over a veth pair with a LAN and a world address in both families; `tools/net-proof.sh`, each feature through the firewall (the page, LocalSend, Syncplay, DNS, a real torrent swarm). The rule the list follows is this digest's: loopback is never a finding, every other socket is listed.

**Not done, by decision: a scan from the real Internet.** It would answer only whether his router filters inbound IPv6. The firewall holds whatever the router does, so the answer changes nothing he could act on, and an online scanner would learn his address. So he is not asked. The Learn piece says it plainly: the firewall is what protects you, not the router.

**T39's accept, adjusted:** `ss` equals the list; the scan, per scope and family, equals the list; sysctls hold after a reboot; `sshd` inactive with no key; his page reachable from his LAN throughout; DoT's numbers in the ledger; torrent port-mapping off, with its before and after (T29); Learn piece "network".

## Sources

Commands (4 Nov 2026, 18:00 to 18:06, no root): `ss -tulpn`, `ip -br addr`, `sysctl`, `resolvectl status`, `nmcli`, `firewall-cmd --get-active-zones` (the rest of `firewall-cmd` needs root), `journalctl -u sshd`, `/usr/lib/firewalld/zones/*.xml`, `man firewalld.conf`, `man firewalld.zone`, `man firewall-cmd`, `/usr/lib/sysctl.d/50-default.conf`. Scripts for the DNS measurements: Python stdlib; not kept in the repo.
- Ledger `r27-39-audit` (3 Nov, the main run, read with root): firewall rules, `sshd -T`.
- Kernel: https://docs.kernel.org/networking/ip-sysctl.html
- systemd: https://www.freedesktop.org/software/systemd/man/latest/resolved.conf.html
- Quad9: https://www.quad9.net/service/service-addresses-and-features/ , https://quad9.net/privacy/policy/
- firewalld: https://firewalld.org/documentation/man-pages/firewalld.zones.html ; as installed, `/usr/lib/python3.14/site-packages/firewall/core/nftables.py`, `/usr/lib/firewalld/policies/allow-host-ipv6.xml`
- Kernel source: `net/netfilter/nf_conntrack_proto_icmpv6.c`, `net/ipv6/ndisc.c` at https://github.com/torvalds/linux
- ICMPv6 in firewalls: https://www.rfc-editor.org/rfc/rfc4890.txt
- The build: branch `lane-network`, `lib/net.sh`, `system/net-allow.list`, `tools/portscan.sh`, `tools/net-proof.sh` (read, not run)
- torrra as installed: `~/.local/share/uv/tools/torrra/lib/python3.13/site-packages/torrra/core/download.py`
