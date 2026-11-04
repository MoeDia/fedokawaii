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
