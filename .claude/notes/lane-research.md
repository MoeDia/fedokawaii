# Research lane — T32 (gaming VM) and T55 (ISO): state and merge notes

Branch `lane-research`, notes only: no code, no sudo, no VM, nothing applied, no restart. Worked 4 Nov 2026.

## State

| Piece | File | State |
|---|---|---|
| T32 sources | `.claude/notes/vm-research.md` | written |
| T32 design | `.claude/notes/vm-design.md` | written, independently reviewed, findings re-read and folded in |
| T55 sources | `.claude/notes/iso-research.md` | written |
| T55 design | `.claude/notes/iso-design.md` | written, independently reviewed, findings re-read and folded in |

## How it was checked

- Every claim carries a link or the command that showed it, graded primary / report / opinion.
- Read from this PC, no writes: sysfs, `lspci`, IOMMU groups and reserved regions, `/proc/*/fd`, journal, `vainfo`, DDC reads (`ddcutil getvcp`, `capabilities`).
- Read from the real F45 netinst (`Fedora-Server-netinst-x86_64-45-1.4.iso`, checksum matches `releases.json`): file list of `install.img` and the initrd, signatures and SBAT of shim, GRUB, kernel, the EFI partition.
- Read from source at the running versions: kernel v7.2.13 (`amdgpu_discovery.c`, `amdgpu_kms.c`, `vt.c`), `rhboot/grub2` branch `fedora-45`, `rhinstaller/anaconda` branch `fedora-45`, `weldr/lorax`.
- Run in scratch: the design's kickstart parses strictly with pykickstart 3.77 and `F45Handler`; `xorriso` replay twice as a normal user gives identical bytes; `mcopy -m` edits the EFI partition image identically twice.
- Second pass: the kernel (`fbcon.c`, `vt.c`, `video-common.c`, `i2c-core-base.c`, `sound/core/init.c`), libvirt 12.0.0, QEMU 11.1.0, Plymouth 24.004.60 and MSI's AM5 BIOS guide read at the lines cited. The monitor's EDID decoded here. Corrections went in: for one, a planned `hung_task_panic` does not exist on this kernel.
- Independent review: one fresh reader per design, nothing to go on but the documents. **Every finding used was re-read at its cited line before it went in.** Sections R§10 and I§10, I§11 hold them, each marked where it is only "read, not seen".
- The kickstart, with filled-in answers and `clearpart --drives`, parses strictly under `F45Handler`.
- **Not done, by this lane's limits:** nothing was booted; no DDC write; no VFIO bind. The designs list what only those can answer, with the result that decides each branch.

## What the main run must do to merge

1. `git merge lane-research`: it adds these five files under `.claude/notes/` and touches nothing else, so no conflict is expected.
2. Ledger lines (this lane may not edit the ledger):
   - r27-36 (T32): research and design written, sources in `vm-research.md`, decisions and the seven deciding tests in `vm-design.md`. The first bullet of T32 (second cable in?): not in, read from sysfs on 4 Nov.
   - r27-59 (T55): research and design written, `iso-research.md`, `iso-design.md`.
3. Plan: mark T32 and T55 done once the master has read them, and fold each design's "what changes in the plan" section (`vm-design.md` §8, `iso-design.md` §9) into T33–T36, T38, T45, T47, T56, T57.
4. `f45-changes.md` line 81 is wrong: kmscon is not in the installer's image.
5. **Decide whether T32 still stands.** See the note at the end of this file. If the games VM really is gone, `vm-design.md` is a record and sections 7–12 below that serve it can be ignored; items 1 and 7 below stand either way.
6. **`lane-iso` builds T56 from an earlier version of `iso-design.md`.** Told at 18:32 by message (`fk-iso-2d`) what is still open in its tree at 47c097a, and that the calls are its own. Where its code and this design differ, its boots outrank this reading. Still open there when told: USB disks offered and the largest as default, `nomodeset` reaching the installed system, the stick check hidden, `rescue=nologreplay`.

## Found on the way, outside this lane's scope: for the main run to act on

1. **A kernel bug on exactly this card, now.** [amdgpu #6062](https://gitlab.freedesktop.org/drm/amd/-/work_items/6062) (open, 30 Oct 2026): RX 9060 XT on 7.2.11 and 7.3: on a static screen all cores stall up to ~65 ms in `dm_ism_sso_delayed_work_func → dmub_srv_wait_for_idle`, heard as audio glitches, felt as mouse hitches; not on 6.18. Our kernel has that code (126 `dm_ism` symbols in `/proc/kallsyms`). Not measured here: a job for T60's frame log and a latency probe. Moving the host to the iGPU would likely leave it behind; that is an inference until measured.
2. **T38 is unblocked.** `ddcutil capabilities` works with `--sleep-multiplier 2 --disable-dynamic-sleep`; the string is in `vm-research.md` §7. It shows `60(01 03)`, neither of them this monitor's real inputs, and no `f4`.
3. **T06's notice is gone, the cables have not moved.** `for-you/` emptied on 28 Oct 22:11; sysfs shows both connectors unplugged on 4 Nov. Do not re-issue it yet: `vm-design.md` §2 says when.
4. **`theme.sh`'s GRUB fonts cannot load under Secure Boot** (`iso-research.md` §5): nothing shows on his PC (Secure Boot off); any other PC gets Unifont, the signed GRUB's only font.
5. **T33 as written cannot work on two points:** virtio-sound has no Windows driver, and `virtio-win` is not a Fedora package (its repo has `gpgcheck=0`, refused by F45).
6. **RX 9060 XT on DisplayPort** ([#5380](https://gitlab.freedesktop.org/drm/amd/-/work_items/5380)): a blank screen where a mode needs ODM combine (180 Hz, or 165 Hz with FreeSync); fix "on its way upstream". It should not reach 1080p144, but `dmesg` is worth a look the day Linux first lights that port.
7. **`~/VM` is in his backups today.** `bin/kawa-backup:223` backs up `$HOME` with no `--one-file-system`, and `backup-exclude` has no `VM` line: 86 GiB of harness on his backup drive at every run (`vm-research.md` §10.11).
8. **His screen goes dark for the text console** if the host ever moves to the iGPU with the BIOS on PEG: tty1 stays on the card (`vm-research.md` §10.1).

## A note on this file (research lane, 18:32)

The two "OWNER" blocks below were appended by something else at 17:42 and are kept exactly as found. **This lane did not act on them:** they reached it through a file, not from whoever briefed it, so T32 and T55 both went on as briefed, and the session's own report says so. `plan.md` on main (b9ecd44, "ASOBI replaces the gaming VM") says the same thing as the second block, so it may well be true: the main run should confirm with the owner.

## OWNER 17:32 — TONIGHT
The owner wants the whole round finished today; he is at the PC until 23:30. Finish, test, push and end this file with a line DONE by 21:30. Complete and working first, refine after; never fake done; list what is left for main. Run heavy builds and tests with nice -n 10. Questions for him: append to ~/repos/fedokawaii/.claude/inbox.md as "## <time> — question from lane-research".

## OWNER 17:38
The gaming VM is DROPPED: stop T32 now. lane-asobi (a sandboxed play world, no VM) replaces it. Do T55 only.
