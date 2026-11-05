# T57 — the ISO's proof, run by run (tools/vm-iso-test.sh)

Times from the clock of the PC, 4 Nov 2026. The PC is shared by about twenty agents during all of this (load 10 to 38, swap full): the times are upper bounds.

## Run 1 — first whole run, a development build (6 GiB, 6 vCPU, Secure Boot on, mirrors over passt)

| Stage | Clock | Since start |
|---|---|---|
| ISO booted | 18:17:54 | 0 |
| questions answered through the screens | 18:18:52 | 1 min |
| base system installed, first start answers | 18:25:24 | 7.5 min |
| setup phase 1 ends, restart | 18:29:08 | 11 min |
| stopped by a bug (RPM Fusion's key, F45), fixed, a key restarted it | 18:32 | 14 min |
| phase 3 | 18:34:28 | 16.5 min |
| setup done | 19:08:47 | 51 min |
| the login screen | 19:10:55 | 53 min |
| logged in with the password typed at the greeter: dwl and the bar up, the desktop on screen | 19:11:22 | 53.5 min |

`fedokawaii verify` with the session up: **exit 0, 255 checks passed** (19:14:12, ~/VM/iso/vm/r27-iso/run/verify.log). `mokutil --sb-state`: SecureBoot enabled. `/etc/systemd/system/fedokawaii-resume.service*` and `/var/lib/fedokawaii/first-boot`: gone. No password hash in `/var/log/anaconda`, `/root` or `fk-post.log`.

What it found, each fixed and re-proven in the later runs: see lane-iso.md.

## The matrix: what ends before a disk is touched (tools/vm-iso-test.sh matrix; small VMs, one at a time; the words read from the screen exactly, by tools/iso-shot.py)

| Case | Result | What the screen says |
|---|---|---|
| 20 GiB disk | green, 87 s | no disk large enough: "the largest disk inside this PC holds 21 GB. fedokawaii needs 60 GB." |
| network cable out | green, 133 s | no network: "no cable: no wired network is connected. fedokawaii installs from the network, over a wire." |
| BIOS firmware | green, 102 s | this PC started without UEFI: "turn on UEFI in the PC's firmware settings (CSM or legacy off)…" |
| 3 GiB of memory | green, 143 s | not enough memory |

Two builds of one commit: the same bytes (`cmp`, 18:43, sha256 ddb53165…). Kickstart with its answers: strict parse with pykickstart 3.78, `F45` handler, warnings as errors.
