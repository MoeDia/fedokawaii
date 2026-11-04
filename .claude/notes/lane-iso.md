# lane-iso — T56, T57: the installer ISO (state: see the list; ends with DONE when finished)

## State (updated as it goes)
- `tools/build-iso.sh`, `iso/` (kickstart, GRUB menu, screens), `tools/build-iso-art.py`, `tools/iso-shot.py` (reads the console exactly), `tools/vm-iso-test.sh` (the proof).
- Proven so far: GRUB menu under Secure Boot; our form on tty1; Anaconda silent on tty3; progress from its own lines.
- Global OOM on the PC 4 Nov 18:15:43 killed every VM (fk-r27-updates, fk-r27-net, mine) and r27-lane-updates: one ISO VM at a time from now, 6 GiB, `mem_guard`.


## OWNER 17:46 — THE FINAL FRESH INSTALL (shapes the end of the round)
When the round is done he WIPES this PC and does one last brand-new install from our ISO. Nothing may be tied to this install.
1. The ISO (T56–T57) is the real deliverable: install → a complete, coherent fedokawaii desktop with zero manual steps after; everything the round built must come from the repo/ISO, nothing from this PC's state.
2. Round tooling never ships: no ~/repos worktrees, lanes, r27-conductor, r27 units or the temporary sudo rule in the installed system (T62); include fk-remote only if it belongs in the product.
3. Self-contained and self-sustaining: the ONE Super+U update button updates everything (packages, Fedora releases, fedokawaii itself), with snapshots/rollback and the local AI fixer; where fedokawaii's own updates come from follows the decision already in CLAUDE.md.
4. Carry-over across the wipe: a "before you wipe" step (Super+U) that backs up his own data to a drive (~/Notes and the to-do, ~/blasphemous-save-backup-20261022, ~/.config/fedokawaii/secrets.sh, the browser profile, anything else that is his), and a restore step at the first boot of the fresh install. Prove the round trip in a VM.
5. The final proof (T57) is exactly his path: build the ISO, install it in a VM, restore a test backup, press the update button, all green.
6. Flatpak: allowed ONLY inside asobi (his answer 17:46); nothing Flatpak in his own account or on the desktop.

## OWNER 18:15 — memory
The PC is at 26 of 31 GB RAM with 21 agents. Your VMs: at most 4 GB RAM each, shut them down as soon as a test ends, never two of yours at once.
