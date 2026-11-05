---
id: doors
title: the doors: who can reach this machine
part: desktop
chapter: 8
minutes: 2
needs: [the-fixer]
optional: no
---

## 8.8 the doors: who can reach this machine

> **Word — port.** A numbered door on a computer, from 1 to 65535: a program *listens* at a port,
> and others connect to it.

Your PC has an address the whole internet can reach (its public IPv6 address), so what stands
between it and the world is the firewall. Nothing is open by accident here: every door is one line
of one file (`system/net-allow.list`), the firewall is made from that file, and `verify` fails if
the two ever differ.

| Who knocks | What they meet |
|---|---|
| the internet | silence, not even an answer to a ping. One door: torrents (6881), so that other peers can reach you while you download |
| your home network (private addresses: your phone, your other computer) | torrents, LocalSend (53317), the remote page (8737, with its token); anything else is refused at once |
| this computer | what it runs for itself: names (53), Prowlarr (9696), the update's local fixer (11434). These listen on this machine alone |

**SSH is off** while no key is in `~/.ssh/authorized_keys`: passwords are never accepted, so with no
key nobody could log in, and nothing listens. Put a key there and run `fedokawaii repair`: it comes
on, for your home network only.

**The router.** Programs like to ask a router to open a port for them (UPnP, NAT-PMP). Here the
firewall stops that request on its way out: nothing opens a door behind your back.

**Names.** Turning `fedoraproject.org` into an address goes encrypted (TLS) to Cloudflare, or to
Quad9 when Cloudflare cannot answer, so your provider cannot read which sites you look up. A network
that blocks this costs the privacy, never the names: they still resolve.
