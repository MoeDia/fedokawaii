# lane-network: T39 network security, rock solid

Branch `lane-network`, worktree `~/repos/fk-network`. Sudo + own VM (`fk-r27-net`, port 2295) allowed; no apply, no dwl restart, no reboot of the PC.

lane-research2 had written nothing for T39 when this began ("T39 network: not started" in its notes), so the audit is this lane's own, from the installed programs, their man pages and measurements. Its digest came at 19:10 (`research-T39-network.md`, read here): it reached the same findings and withdrew its objection to DROP. One thing taken from it: `net_firewall_wrong` also checks firewalld's `allow-host-ipv6`, the policy IPv6 rests on under DROP.

## What was wrong (audit, 4 Nov 17:45, `ss -tulpn`, `firewall-cmd --list-all`)
- The PC has a public IPv6 address (2001:8f8:…). Zone `public` opened ssh, mdns, 6881 and 53317 to all of it, so LocalSend and sshd were reachable from the whole internet over IPv6.
- sshd listened on every address with an empty `authorized_keys` and no login in 60 days of journal: nobody could use it.
- The remote page's rule was on the live PC only, not in the repo, tied to one subnet.
- Kernel: redirects accepted and sent, loose paths. torrra asks the router for ports (UPnP, NAT-PMP on). DNS in plain to the router, which lost names (5 s stalls, 1337x.to and subsplease.org never answered).

## What is built
- `system/net-allow.list`: every door, one list. `lib/net.sh` makes the firewall from it; verify, the report and the scan hold the machine against it.
- Firewall: zone `public` (the card, what the internet meets) target DROP, torrents' 6881 only. Zone `kawa-lan`, bound to the private ranges (a zone with sources comes first): LocalSend, the remote page and SSH when each is there, DHCPv6's answers; the rest refused out loud. Policy `kawa-no-upnp`: UDP 1900 and 5351 refused on the way out, whatever program asks.
- SSH: on only with SSH_SERVER=yes and a key in authorized_keys; LAN only, keys only. So off on his PC, and on in the VMs (they hold the harness key), with no change to fedokawaii.conf's value.
- `system/sysctl-net.conf` → `/etc/sysctl.d/60-fedokawaii-net.conf`; `/etc/NetworkManager/conf.d/91-fedokawaii-net.conf` (MPTCP handling off, so strict rp_filter survives a boot).
- Names: DNS over TLS to Cloudflare, then Quad9 (`DNSOverTLS=opportunistic`, `Domains=~.`). `system/kawa-names`, a NetworkManager dispatcher script: on a network that lets no outside DNS through, the network's own DNS takes over and gives the names back. Prowlarr's container asks through the same resolver.
- `tools/portscan.sh [--vm NAME]` (all ports from outside, against the list), `tools/net-proof.sh` (what the doors are for still works), `tests/installer/test_net.sh`, verify's section "the network", report rows NET-07/08/09/20/21/25/26 and LS-01, the Guide's 33.2 and 33.3, the Learn book's 8.4 and exercise 8.5. firewalld in the manifest.

## Decisions (each with its source)
- Bindings left as they are: the remote page (0.0.0.0, IPv4), LocalSend (every address). The firewall decides; both ask for proof themselves (the page's token, LocalSend's client certificate and its accept dialog). Plain HTTP for the page stays: LAN only, as the owner set it up.
- Syncplay: outbound only. `syncplay-server` is installed but nothing starts it, so no door 8999.
- IPv6 temporary addresses: not added. The /64 prefix identifies the home anyway; little gained for a change only a reboot could prove.
- `log_martians` off: logged packets nobody reads.
- rp_filter strict needs `connection.mptcp-flags=1`: nm-settings-nmcli(5), "mptcp-flags": NetworkManager loosens strict rp_filter wherever it handles MPTCP. NetworkManager.conf(5) warns that strict breaks the connectivity check on all but the best route; harmless with one card.
- Opportunistic, not strict, TLS: strict means no names at all on a network that blocks 853, and no way for the update button to recover; also a clock-before-certificate trap at boot. The threat here is a passive provider.
- Cloudflare before Quad9, by measurement (below): Quad9's answers put Steam's Akamai CDN at 116–276 ms, Cloudflare's at 6–7 ms.

## Evidence
Ledger line to fold in (r27-43):
- **Scan, from the VM** (`sudo bash tools/portscan.sh --vm r27-net`, nmap 7.92 on a tap, all 65535 TCP and UDP, 18:32) and from a namespace (18:18), the same table, ✔ exactly the list:
  lan tcp4/tcp6 6881 8737 53317 · lan udp4/udp6 546 6881 53317 · world tcp4/udp4/tcp6/udp6 6881.
- **Live proof** (`sudo bash tools/net-proof.sh`, 19:10), all ✔: 8 cold names, 24 packets to 853 and none to 53; dnf reads every repository; GitHub, Flathub, lscr.io, Steam's API; chrony has a source; Syncplay's server offers TLS; UPnP and NAT-PMP refused on the way out; the remote page answers the LAN (200, 401 without its token), silent to the world; LocalSend reaches its TLS question from the LAN, silent to the world; a ping from the world gets silence; a real swarm (Debian's installer): 41 peers, 3.9 MB in 8 s, 3 strangers came in through 6881.
- **The owner's Mac on the real LAN** (10.62.79.109): its page keeps polling through every firewall change (new TIME-WAIT ports after each, `ss -tan 'sport = :8737'`).
- **asobi**: `sudo -u asobi curl` Steam's API 200, a UDP STUN out and back, names resolve.
- **Prowlarr**: 127.0.0.1:9696 only; with the new quadlet one nameserver in the container and no plain name in a 60 s sniff; 7 of 8 indexers under 1 s. SubsPlease hangs on both IP families and the router's DNS has no answer for it either: the site, not this.
- **DNS, cold lookups through resolved, 40 names, 3 passes**: router p50 27.8/4.7/4.6 ms, p90 127/10.7/8.7, max 203/5195/5236, 1 failed; TLS p50 12.5/10.9/10.9, p90 114/12.6/13.9, max 233/166/19, none failed. Raw, per resolver: router UDP p50 4.8; Cloudflare DoT 7.2 (handshake 17 ms); Quad9 7.9 (20 ms); Google 26.5; Mullvad 124.5.
- **Failure injection in the VM**: 853 dropped, first lookup 26 s then 9–244 ms; 853 refused, 15–928 ms; Cloudflare gone, first 13 s then Quad9 at 262–380 ms; both gone, 280 s per lookup before kawa-names, and with it switched in 10 s, lookups 236–419 ms, back over TLS 2 s after they return, no AVC.
- **The reboot proof caught two bugs**: systemd's 50-default names default's rp_filter, and NetworkManager loosens it on the card at activation. After the fixes a VM reboot shows every value in force (verify's check, `net_sysctl_wrong`).
- **A sniff caught one more**: Podman's resolv.conf lists the servers behind pasta's forwarder, so Prowlarr's names went plain.
- Link-local to 546/udp passes, to any other port does not (a namespace, nft counters). Router advertisements counted before and after the firewall: 4 and 4.
- The PC's own reboot is not done here (forbidden to this lane): verify's section proves the settings at main's next reboot.

## What main must do to merge and apply
1. Merge conflicts, all small. `fedokawaii.conf` against lane-asobi: lane-asobi's removal of STEAM, this lane's three SSH_SERVER lines. `setup.sh` and `verify.sh` against lane-torrents: take this lane's side (`open_ports` is gone; `r_ports() { s_ssh; s_network; }`; verify's firewall block is the new section). `system/prowlarr.container` against lane-torrents: keep `Network=pasta:--dns-forward,169.254.1.1` and `DNS=169.254.1.1` here and drop their `DNS=1.1.1.1` and `DNS=9.9.9.9`: the same public resolvers, over TLS. `tests/engine/test_configs.sh` fails if a second nameserver stays. lane-torrents' `listen_interfaces` fallback to a random port is not on the list: while it is in use verify warns, nothing fails.
2. **Merge this before the next apply.** Main's apply from a tree without it (18:43 today) undid part of this on the live PC: ssh and 53317 open to the world again, DNS plain. I re-applied at 19:09, and each apply from an older tree undoes it again until this is in.
3. `fedokawaii apply` puts it in force; then `sudo bash tools/portscan.sh` and `sudo bash tools/net-proof.sh`, numbers into the ledger as r27-43.
4. After merging lane-learning: add `doors | the doors: who can reach this machine | 4` after `snapshots-report` in `docs/learn/syllabus.txt`, run `python3 tools/learn-pieces.py`, commit (the lessons refuse a section of the book in no lesson). The Learn PDF at T63.
5. Mark T39 done in the plan once the PC has rebooted with it and verify's section is green.
6. Harness note for lane-iso and lane-updates: `setup` now stops sshd on a machine with no key in `~/.ssh/authorized_keys`. VMs made by `tools/vm-create.sh` hold the harness key and stay reachable; the ISO's proof must put one there too if it drives the installed system over SSH.
7. `origin/remote`'s `install.sh` adds a rich rule to the default zone. Re-running it does no harm (private sources never reach that zone), verify reports "holds rules of its own", and the next apply or repair removes it. Left alone: not this lane's branch.

## Open questions
(none)
