# lane-iso — T56, T57: the installer ISO (state: see the list; ends with DONE when finished)

## State (updated as it goes)
- Built: `tools/build-iso.sh`, `iso/` (kickstart, GRUB menu, screens), `tools/build-iso-art.py`, `tools/iso-shot.py` (reads the console exactly), `tools/vm-iso-test.sh` (the proof), `tests/installer/test_iso_tools.sh`.
- Proven by boots in the VM: firmware picture → themed menu (Secure Boot on and off; off: no black window, on: GRUB's terminal black for its seconds, nothing can change that under Secure Boot) → splash on the same ground → our form, drawn on VT 8 → Anaconda silent on tty1 → progress from its own lines → first start → setup on one screen. Two builds of one commit: the same bytes.
- Found on the way and fixed here (they matter beyond the ISO, main: see Merge):
  1. F45's Plymouth 26 crashes (SEGV in script.so) on every script theme without a label plugin + font: our splash becomes a text boot. `plymouth-plugin-label` in PKG_SESSION.
  2. RPM Fusion's F45 release package keeps its key under /usr/share/pki: setup.sh stopped at 2.1 on a clean F45. Fixed.
  3. bluez came as a dependency on F45 and setup's clean-up took it: manifest_mark before the gate. gtklock's PAM file written before gtklock was installed: lock_pam after it.
  4. The splash's ground was the old #0f0e0c: now #181715.
- The memory rule (owner 18:15, below): VMs 4 GiB, one at a time, enforced by `mem_guard`. My first run was already going at 6 GiB when I read it; it was left to finish its last minutes, every later VM is 4 GiB.
- `bin/kawa-carry` is main's (T54b 4): I had written another before seeing it, and removed mine.

## What main must do to merge
Merge lane-iso (new: `iso/`, `tools/build-iso.sh`, `tools/build-iso-art.py`, `tools/iso-shot.py`, `tools/vm-iso-test.sh`, `bin/kawa-stick`, tests; touches `setup.sh`, `lib/manifest.sh`, `lib/common.sh` PROJECT_TOP, `system/fedokawaii` (one row, backups → the installer), `system/plymouth/sumi/sumi.script`, packages.evidence, PACKAGES.md, README, fixtures). **Before the PC's first boot on F45: `plymouth-plugin-label` must be installed** (apply or update after the merge), or that boot is a text boot with a backtrace on screen.

**The ISO that ships:** when every lane is in, tag the commit `vYYYY.MM.DD`, push the tag (the update button adopts only v… tags, lane-updates), then:
```
bash tools/build-iso.sh --ref vYYYY.MM.DD --out ~/VM/iso/out      # 2 min; needs xorriso, mtools, cpio, python3-pillow (on this PC now, not in the manifest: a builder's tools)
bash tools/vm-iso-test.sh run r27-iso ~/VM/iso/out/fedokawaii-*.iso --no-sb --usb ~/VM/iso/carry.qcow2     # about 50 min, 4 GiB
bash tools/vm-iso-test.sh path r27-iso ~/VM/iso/carry.qcow2       # his things back, the update button, verify
gh release create vYYYY.MM.DD ~/VM/iso/out/fedokawaii-*.iso ~/VM/iso/out/fedokawaii-*.iso.sha256 --title "fedokawaii YYYY.MM.DD" --notes "the installer: README, From the ISO"
```
`kawa-stick` (Super+U → backups → the installer) takes the release's asset from GitHub by these names.

**For the owner, before the wipe (only he can):** the rehearsal: write the stick, start from it once (F11 on his MSI board), look at the menu, the splash and the form, press F2, hold the power button. Nothing is touched before the form's last page. It is the one thing a VM cannot show: his firmware, amdgpu, his monitor. Two minutes.

**Ledger lines (this lane does not edit the ledger):** r27-60 T56, r27-61 T57: see `.claude/notes/iso-runs.md`.

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
