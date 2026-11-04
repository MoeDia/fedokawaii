# Research lane — T32 (gaming VM) and T55 (ISO): state and merge notes

Branch `lane-research`, notes only: no code, no sudo, no VM, nothing applied, no restart. Worked 4 Nov 2026, third pass in the evening.

## State

| Piece | File | State |
|---|---|---|
| T32 sources | `.claude/notes/vm-research.md` | written |
| T32 design | `.claude/notes/vm-design.md` | written, independently reviewed, findings re-read and folded in; `lane-research2`'s T36, T38, T39 findings folded in; test S0 added |
| T55 sources | `.claude/notes/iso-research.md` | written |
| T55 design | `.claude/notes/iso-design.md` | written, independently reviewed, findings re-read and folded in; `lane-iso`'s boots folded in; section 10 on his real PC added |

## How it was checked

- Every claim carries a link or the command that showed it, graded primary / report / opinion.
- Read from this PC, no writes: sysfs, `lspci`, IOMMU groups and reserved regions, `/proc/*/fd`, journal, `vainfo`, DDC reads (`ddcutil getvcp`, `capabilities`).
- Read from the real F45 netinst (`Fedora-Server-netinst-x86_64-45-1.4.iso`, checksum matches `releases.json`): file list of `install.img` and the initrd, signatures and SBAT of shim, GRUB, kernel, the EFI partition.
- Read from source at the running versions: kernel v7.2.13 (`amdgpu_discovery.c`, `amdgpu_kms.c`, `vt.c`), `rhboot/grub2` branch `fedora-45`, `rhinstaller/anaconda` branch `fedora-45`, `weldr/lorax`.
- Run in scratch: the design's kickstart parses strictly with pykickstart 3.77 and `F45Handler`; `xorriso` replay twice as a normal user gives identical bytes; `mcopy -m` edits the EFI partition image identically twice.
- Second pass: the kernel (`fbcon.c`, `vt.c`, `video-common.c`, `i2c-core-base.c`, `sound/core/init.c`), libvirt 12.0.0, QEMU 11.1.0, Plymouth 24.004.60 and MSI's AM5 BIOS guide read at the lines cited. The monitor's EDID decoded here. Corrections went in: for one, a planned `hung_task_panic` does not exist on this kernel.
- Independent review: one fresh reader per design, nothing to go on but the documents. **Every finding used was re-read at its cited line before it went in.** Sections R§10 and I§10, I§11 hold them, each marked where it is only "read, not seen".
- The kickstart, with filled-in answers and `clearpart --drives`, parses strictly under `F45Handler`.
- **Third pass, citations:** a script fetched all 128 links and compared 48 quotes with the pages on their lines; every miss re-read by hand. 4 quotes were not word for word and are corrected; 2 links are dead; 3 quotes cannot be re-checked from here and say so at their lines (`iso-research.md` §12.1). It checks quoted words and links, not paraphrases.
- **Third pass, read from F45's own files and metadata:** blivet 3.14.2 and Anaconda's units from `install.img`; the initrd's file list and `modules.builtin` against this PC's hardware; `dnf5 repoquery` against `releases/45`; GRUB's `efi_gop.c` on `fedora-45`; Fedora's bug 2420697 and its Discourse threads through their JSON.
- **Not done, by this lane's limits:** nothing was booted; no DDC write; no VFIO bind. The designs list what only those can answer, with the result that decides each branch.

## What the main run must do to merge

1. `git merge lane-research`: it adds these five files under `.claude/notes/` and touches nothing else, so no conflict is expected.
2. Ledger lines (this lane may not edit the ledger):
   - r27-36 (T32): research and design written, sources in `vm-research.md`, decisions and the eight deciding tests in `vm-design.md`. The first bullet of T32 (second cable in?): not in, read from sysfs on 4 Nov.
   - r27-59 (T55): research and design written, `iso-research.md`, `iso-design.md`.
3. Plan: mark T32 and T55 done once the master has read them, and fold each design's "what changes in the plan" section (`vm-design.md` §8, `iso-design.md` §9) into T33–T36, T38, T45, T47, T56, T57.
4. `f45-changes.md` line 81 is wrong: kmscon is not in the installer's image.
5. **Decide whether T32 still stands.** See the note at the end of this file. If the games VM really is gone, `vm-design.md` is a record and sections 7–12 below that serve it can be ignored; items 1 and 7 below stand either way.
6. **`lane-iso` builds T56 from an earlier version of `iso-design.md`.** Where its code and this design differ, its boots outrank this reading, and what they settled is now in the design. The four items told at 18:32 were all fixed by its next commits (USB disks, `nomodeset`, the hidden stick check, `rescue=nologreplay`). The third pass's items are below.
7. **T54b needs a step nobody has:** writing the ISO to a stick (`iso-design.md` §9).
8. **One thing to put to the owner, when the ISO is final, in a review pack:** the two-minute rehearsal on his real PC, stick booted to the form and powered off, disk untouched (`iso-design.md` §10). It is the only way to see the real display path before he wipes.

## Third pass: what a VM cannot show, on the owner's real path (T56, T57)

Told to `lane-iso` by message (`fk-iso-2d`) at 19:00, and it took most of them; each is its call, each has its evidence in `iso-research.md` §12 and its design in `iso-design.md`. Read, not booted.

1. **The stick check can call a good stick damaged.** `checkisomd5` hashes sectors; firmware or an automount may rewrite GPT fields. Fedora's own F45 issue, bug 2420697, NEW. Today's screen powers off and says write it again. Design: SHA-256 of the files, drop `implantisomd5`.
2. **T57 never meets his disk.** Every run starts wiped; his has subvolumes, snapshots, nested ones, and blivet deletes them one at a time. Design: `wipefs` in `%pre`, plus one row, a second install over a finished one. **My first version of this was wrong in one respect, and `lane-iso` has already built from it:** see item 7.
3. **Early deaths bring the form back.** `inst.notmux` starts `anaconda.service` when the first Anaconda ends without a reboot: a second Anaconda, a second `%pre`. It cannot be masked (`Requires`). Design: a drop-in that makes it the failure screen.
4. **`gfxmode=auto` keeps whatever mode the firmware left.** `theme.sh` writes `1920x1080,auto`, and so does `lane-iso` now. (My message overstated this as 800 × 600.)
5. **`gpu_problem()` read `/sys/class/drm`:** `lane-iso` now reads the PCI class.
6. **Checked, nothing to do:** his hardware is covered by the netinst's initrd; `console=` does not come back on later kernels; `implantisomd5`'s old bug is fixed; F45's firmware reaches a fresh install as weak dependencies (T57 row).
7. **From the independent review (`iso-research.md` §12.10), told to `lane-iso` at this push. The erase precedes every check Anaconda makes,** so a kickstart that cannot parse, a dead `updates` repo or an unsolvable package set now leave a blank disk. Design section 3: make those checks and hash `install.img` before the erase; verify the erase's own result; a failure screen that says whether the disk was erased. **This matters for his wipe. Until `lane-iso` has done it, the ISO can leave him with a blank disk on a passing mirror fault.**
8. **An unreadable stick:** three minutes of splash, then Dracut's raw report. `rd.retry=30` and an emergency hook in the second initrd (`iso-research.md` §12.9). In the notes only.
9. **`services --disabled=sshd` is missing from `iso/ks.cfg`:** `sshd` runs on first boot until setup's step 1.7. Its harness may depend on it, so it is its call.

The independent review was stopped early at the main run's request. What it did not reach is listed in §12.10. **Nothing in this lane was booted, so every item here is "read, not seen" until `lane-iso` boots it.**

## Found on the way, outside this lane's scope: for the main run to act on

1. **A kernel bug on exactly this card, now.** [amdgpu #6062](https://gitlab.freedesktop.org/drm/amd/-/work_items/6062) (open, 30 Oct 2026): RX 9060 XT on 7.2.11 and 7.3: on a static screen all cores stall up to ~65 ms in `dm_ism_sso_delayed_work_func → dmub_srv_wait_for_idle`, heard as audio glitches, felt as mouse hitches; not on 6.18. Our kernel has that code (126 `dm_ism` symbols in `/proc/kallsyms`). Not measured here: a job for T60's frame log and a latency probe. Moving the host to the iGPU would likely leave it behind; that is an inference until measured.
2. **T38 is unblocked.** `ddcutil capabilities` works with `--sleep-multiplier 2 --disable-dynamic-sleep`; the string is in `vm-research.md` §7. It shows `60(01 03)`, neither of them this monitor's real inputs, and no `f4`.
3. **T06's notice is gone, the cables have not moved.** `for-you/` emptied on 28 Oct 22:11; sysfs shows both connectors unplugged on 4 Nov. Do not re-issue it yet: `vm-design.md` §2 says when.
4. **`theme.sh`'s GRUB fonts cannot load under Secure Boot** (`iso-research.md` §5): nothing shows on his PC (Secure Boot off); any other PC gets Unifont, the signed GRUB's only font.
5. **T33 as written cannot work on two points:** virtio-sound has no Windows driver, and `virtio-win` is not a Fedora package (its repo has `gpgcheck=0`, refused by F45).
6. **RX 9060 XT on DisplayPort** ([#5380](https://gitlab.freedesktop.org/drm/amd/-/work_items/5380)): a blank screen where a mode needs ODM combine (180 Hz, or 165 Hz with FreeSync); fix "on its way upstream". It should not reach 1080p144, but `dmesg` is worth a look the day Linux first lights that port.
7. **`~/VM` is in his backups today.** `bin/kawa-backup:223` backs up `$HOME` with no `--one-file-system`, and `backup-exclude` has no `VM` line: 86 GiB of harness on his backup drive at every run (`vm-research.md` §10.11).
8. **His screen goes dark for the text console** if the host ever moves to the iGPU with the BIOS on PEG: tty1 stays on the card (`vm-research.md` §10.1).

## A note on this file (research lane, 18:32, updated at the end)

This lane finished at the main run's direct request (`fedokawaii-c4`, 19:09): it needed the lane's slot for the Fedora 45 work and asked for the finishing word below. T32 was still finished as briefed, because the brief named it; `vm-design.md` opens by saying `plan.md` on main has since replaced it.


The two "OWNER" blocks below were appended by something else at 17:42 and are kept exactly as found. **This lane did not act on them:** they reached it through a file, not from whoever briefed it, so T32 and T55 both went on as briefed, and the session's own report says so. `plan.md` on main (b9ecd44, "ASOBI replaces the gaming VM") says the same thing as the second block, so it may well be true: the main run should confirm with the owner.

## OWNER 17:32 — TONIGHT
The owner wants the whole round finished today; he is at the PC until 23:30. Finish, test, push and end this file with a line DONE by 21:30. Complete and working first, refine after; never fake done; list what is left for main. Run heavy builds and tests with nice -n 10. Questions for him: append to ~/repos/fedokawaii/.claude/inbox.md as "## <time> — question from lane-research".

## OWNER 17:38
The gaming VM is DROPPED: stop T32 now. lane-asobi (a sandboxed play world, no VM) replaces it. Do T55 only.

DONE
