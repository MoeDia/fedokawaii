# lane-network: T39 network security, rock solid

Branch `lane-network`, worktree `~/repos/fk-network`. Sudo + own VM (`fk-r27-net`, port 2295, 3 GB) allowed; no apply, no dwl restart, no reboot of the PC.

## State (4 Nov 18:55)
lane-research2 had written nothing for T39 when this began ("T39 network: not started" in its notes), so the audit is this lane's own, from the installed programs and their man pages.

Built, tested on the VM and live:
- `system/net-allow.list`: every door, one list. `lib/net.sh` makes the firewall from it; verify, the report and the scan hold the machine against it.
- Firewall: zone `public` (the card, what the internet meets) target DROP, torrents' 6881 only. Zone `kawa-lan`, bound to the private ranges: LocalSend, the remote page, SSH (when each is there), DHCPv6. Policy `kawa-no-upnp`: UDP 1900 and 5351 refused on the way out.
- SSH: on only with a key in authorized_keys and SSH_SERVER=yes, LAN only, keys only. His PC has an empty authorized_keys and no login in 60 days of journal, so sshd is off. The VMs keep it: they hold the harness key.
- `system/sysctl-net.conf` → `/etc/sysctl.d/60-fedokawaii-net.conf`; NetworkManager's MPTCP handling off (`91-fedokawaii-net.conf`) so strict rp_filter survives a boot.
- Names over TLS: Cloudflare, then Quad9 (`DNSOverTLS=opportunistic`, `Domains=~.`). Prowlarr's container through the same resolver.
- `tools/portscan.sh [--vm NAME]`, `tools/net-proof.sh`, `tests/installer/test_net.sh`, verify's network section, report rows NET-07/08/09/20/21/25/26, the Guide's 33.2–33.3, the Learn book's 8.4 and exercise 8.5.

## What main must do to merge and apply
(to be finished)

## Open questions
(none)
