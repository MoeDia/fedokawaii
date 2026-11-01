VERDICT: FAIL

The master's review of plan task T48, FIRST item (1) — `kawa-snap restore` hardened, setup.sh's
`orphan_kernels_out`, the VM cut-point proof — at commit c8461b3 (2026-11-01). Reviewed read-only:
/dev/shm/r27/master/T48/kawa-snap.at-HEAD (238 lines; identical to `git show c8461b3:system/kawa-snap`,
checked), the diffs, design-s3.md, restore-cut.sh and its six logs, the table (exit 0), the two test
logs (test_snap 118/0 — re-run by me, 118/0; test_upkeep 227/0, "exit 0 in 317 s"), shellcheck 0.11.0
(kawa-snap: clean). Sources used for tool behaviour: exch(1) (util-linux 2.41.5 on this PC),
btrfs-subvolume(8), kernel-install(8), kernel-command-line(7) and systemd-volatile-root(8), the
installed plugins /usr/lib/kernel/install.d/20-grub.install, 95-set-boot-entry.install,
/usr/bin/grub2-get-kernel-settings, grub-btrfs(8) 4.14 + its upstream script
(raw.githubusercontent.com/Antynea/grub-btrfs/master/41_snapshots-btrfs — the local copy is 0700),
the live PC's fstab/findmnt (read-only), the harness kickstart (~/VM/harness/f44/ks.cfg) and its
libvirt XML.

Summary: the three unsafe spots of §3.1 are addressed in code and the exchange itself is real and
proven (one `exch`, synced; `.snapshots` carried after it; a cut run finished by the next). But the
kernel side — the part that actually breaks a restore on this PC (undoing an update that brought a
kernel) — is neither durable in the right order nor closed as a window, and the VM proof never
exercised it: the snapshot was taken seconds before from the running system, so no kernel was ever
added, UPDATEDEFAULT was never in play, and the "KERNEL ok" column was true by construction. Two
further majors concern the real PC: the new `--kernels` run deletes live kernels from /boot when it
fires inside a boot-menu snapshot boot, and `restore` rolls his /home back while Super+U tells him
"your home stays as it is". Each of these is a one-to-five-line fix plus one honest VM run; none of
them is deep. The item is not done until they are.

────────────────────────────────────────────────────────────────────────────────────────────────
(a) §3.1, point by point
────────────────────────────────────────────────────────────────────────────────────────────────
1. One `exch` instead of two renames; `btrfs filesystem sync` before any /boot edit and before
   "restart" — IMPLEMENTED for the Btrfs side (kawa-snap.at-HEAD:225-228, 177, 237), proven in the
   VM (rows exchanged/moved/renamed/defaulted). PARTLY on the /boot side: /boot (XFS) and the ESP are
   never synced before the exchange (finding 1); the design's "sync before the word restart" is a
   bare `sync` whose status is not read (finding 9).
2. Nested subvolumes moved after the swap; never `-R`; `--commit-after`; `btrfs subvolume sync` —
   IMPLEMENTED except `btrfs subvolume sync` (nit 5). Moves after the exchange: 159-168, 229; a held
   root.new finished, never deleted: 182-186; `gone()` 151. Proven in the VM for `.snapshots` only
   (the PC has four more nested subvolumes — finding 4).
3. Kernel/root pairing: UPDATEDEFAULT=no for the add, default once after the exchange and the sync,
   `restorecon -R /boot` on the host, orphan kernels removed only after the restored root has booted
   — IMPLEMENTED in form (213-221, 232-233, 235; setup.sh:504-515, 3396), but (i) the default is set
   after `finish`, not after the sync — the window the design closes is reopened and widened
   (finding 2); (ii) the recovery path never sets it (finding 2); (iii) "after the restored root has
   booted" is keyed on grubenv's boot_success, which a boot-menu snapshot boot also sets
   (finding 3); (iv) none of it was exercised in the VM (finding 4). The mechanism itself is sound: I
   verified that 20-grub.install sets `tmp_saved_entry` only when grub2-get-kernel-settings exports
   GRUB_UPDATE_DEFAULT_KERNEL=true, which it does only for `UPDATEDEFAULT=yes` in
   /etc/sysconfig/kernel (the chroot reads the copy's file), and 95-set-boot-entry.install promotes
   only an existing `tmp_saved_entry`.
   Also: /.autorelabel and /system-update stripped — IMPLEMENTED (195), `/etc/system-update` missed
   (finding 11). No blanket relabel — yes. `restore old` reconciles /boot as a restore does — yes,
   same code path (189, 197-221), not VM-proven. Retention `root.old` + at most two timestamped —
   IMPLEMENTED (170-175), with a boot-menu side effect (finding 10). The booted or default subvolume
   never deleted — holds (only `root.old-*` and a fresh `root.new` are ever deleted). rpm WAL
   checkpoint before snapshots — not in this item (snapshot creation unchanged).

────────────────────────────────────────────────────────────────────────────────────────────────
Findings
────────────────────────────────────────────────────────────────────────────────────────────────

1. MAJOR — /boot is not durable when the exchange is.
   Where: kawa-snap.at-HEAD:215-228 (the kernel loop, then `btrfs filesystem sync "$top"`, then
   `exch`); the only `sync` is line 237.
   What: `kernel-install add` in the chroot writes vmlinuz, the initramfs and the BLS entry to the
   bind-mounted /boot (XFS) and may touch the ESP. `btrfs filesystem sync` is BTRFS_IOC_SYNC on the
   Btrfs volume only; nothing flushes /boot before the exchange is committed. XFS journals metadata,
   not data: a cut after line 228 and before 237 can leave the restored root committed while its
   kernel's initramfs is zero-length or its entry file missing.
   Scenario (the main use on this PC): an update brought 7.2.11, the one-kernel rule removed 7.2.9;
   he restores the pre-update snapshot (7.2.9 only). 7.2.9 is added to /boot (218), the exchange
   commits (228), the plug is pulled during `finish`. Boot: the default is still 7.2.11 (see 2) or,
   once set, 7.2.9's entry — with a torn initramfs GRUB fails on it; the other entry boots a kernel
   the restored root has no modules for.
   Why the proof missed it: no kernel was added in any of the six runs (the per-step logs contain no
   "back into /boot" line — kawa-snap prints it on stdout, which the harness captured; the snapshot
   was taken from the running system seconds earlier, restore-cut.sh:26, so every K was already in
   /boot and line 216 skipped them all).
   Fix: after line 222 and before 225: `sync -f /boot && sync -f /boot/efi || undo "…/boot could not
   be written"` (syncfs on both file systems; their status read). Prove it with the VM run of
   finding 4.

2. MAJOR — the kernel/root window is reopened, and the recovery never closes it.
   Where: kawa-snap.at-HEAD:229 (`finish`) before 232 (`grubby --set-default`); 182-186 (the
   recovery branch calls `finish` and exits 1 without setting the default); setup.sh:504-515.
   What: the design (§3.1 point 3) sets the default "once, after the exchange and the sync". The
   code puts `finish` between them: the moves, two renames, up to N `btrfs subvolume delete
   --commit-after` (each a full transaction commit) and a sync — seconds, not milliseconds. In that
   window `saved_entry` still names the previous system's kernel. A cut there (the design's own
   stated failure: "boots a kernel without its modules") boots the restored root under the old
   kernel: the initramfs mounts it, then udev finds no /usr/lib/modules/<running> — no amdgpu unless
   dracut packed it, no NIC, no sound. Then it stays that way: the recovery path (184) moves the
   snapshots back and asks for "restore N again" but never sets the default; and `orphan_kernels_out`
   explicitly keeps the running kernel (`$v != "$now"`, setup.sh:511) even when it is the orphan, so
   the boot-time rule never repairs the default either. The VM rows moved/renamed/defaulted could
   not show any of this: snapshot and root had the same kernel, so "KERNEL ok" was tautological.
   Fix (three small changes): (i) move lines 232-233 to directly after line 228 — exchange, sync,
   default, then `finish`; (ii) in the recovery branch set the default too (K is not computed yet
   there — compute it from `$top/$T/usr/lib/modules` first) and run restorecon/boot_list/sync, so one
   run heals the cut instead of asking for a second full restore; (iii) in setup.sh's boot rule: if
   `/usr/lib/modules/$(uname -r)` does not exist, set the default to the newest kernel that has
   modules (`grubby --set-default`) and log it — the self-heal for the millisecond window that
   remains. Prove with the VM run of finding 4 (cut at "exchanged" and "moved" with differing
   kernels; assert `grubby --default-kernel` and the running kernel's modules after the next boot).

3. MAJOR — `setup.sh --kernels` inside a boot-menu snapshot boot deletes live kernels from /boot.
   Where: setup.sh:504-515 (`orphan_kernels_out`), 3396 (dispatch: only `phase == done`), 519-543
   (fedokawaii-kernels.timer, OnBootSec=15min, no Condition); setup.sh:2215 (snapshot boots are
   `systemd.volatile=overlay`). No guard anywhere (grep of setup.sh/verify.sh/system/tests at
   c8461b3: the only `systemd.volatile` handling is the remount-fs drop-in).
   What: a snapshot started from the boot menu runs the snapshot's own units with the real /boot
   mounted rw from its fstab; the user timer grub-boot-success sets boot_success=1 in the real
   grubenv after two minutes of desktop; fifteen minutes in, `orphan_kernels_out desktop` removes
   every /boot entry whose version is not the running one and has no modules in the SNAPSHOT's
   /usr/lib/modules — i.e. exactly the kernels the live system gained since that snapshot.
   Scenario: an update brought 7.2.11 (7.2.9 still in /boot during the probation); he opens the
   boot menu to look at the pre-update snapshot (its menu entry boots 7.2.9, which it has modules
   for), stays 15 minutes: `kernel-install remove 7.2.11` deletes the live system's newest kernel,
   initramfs and entry from the real /boot. If 7.2.9's package had already been removed from the
   live root (one-kernel rule) the live system is left with a /boot whose only kernel it has no
   modules for. The design's words "only after the restored root has booted" mean the `root`
   subvolume — not any root that reached a desktop. (`old_kernels_out` has the same exposure through
   kernel-core's %preun → kernel-install remove; this item adds the direct path.)
   Fix: in the `kernels)` dispatch (or at the top of both functions): return unless
   `findmnt -no FSTYPE,FSROOT /` is `btrfs /<T>` and /proc/cmdline has no `systemd.volatile` — one
   line; add `ConditionKernelCommandLine=!systemd.volatile=overlay` to the unit as a second belt;
   a test_upkeep case with FSROOT=/root/.snapshots/41/snapshot that asserts nothing is removed.

4. MAJOR — the VM proof does not prove what the ledger says it proves.
   Where: tools/vm-inject/restore-cut.sh:26-42; ledger r27-52a-restore "PROVEN … every start whole";
   logs /dev/shm/r27/master/T48/restore-cut/*.log (59-226 bytes each).
   What is proven: start after each cut; the exchange's atomicity (exchanged → old system, the
   uncommitted exchange simply absent); `.snapshots` carried after the exchange and a cut run
   finished by the next (the message is in moved.log/renamed.log; "1*").
   What is claimed but not exercised: (i) "the kernels that copy has go back in" — no `kernel-install
   add` ran (see finding 1); UPDATEDEFAULT handling, the chroot binds, dracut in the copy, the entry
   token: untouched; (ii) "its newest becomes the default, set last" — never different from the
   current default; (iii) KERNEL=ok — true by construction (same kernel on both sides); (iv) `restore
   old` — not run; (v) the PC's other nested subvolumes (home/dia/Downloads, home/dia/VM with NOCOW
   images possibly open by libvirt, var/lib/machines, var/lib/portables) — the VM built state moves
   only `.snapshots`; (vi) the end state after a recovery (root.old, no root.new, grubby's default,
   `kawa-snap list`) — not read; (vii) RUNNING is printed, not asserted (line 42 judges only
   start/snaps/kern), so a step that left the wrong system running would still exit 0; (viii) the
   checks' raw outputs are captured into variables, not logged — the table is the only record.
   On the cut model: `echo b >/proc/sysrq-trigger` discards the guest's page cache; the VM's disk has
   no cache attribute (QEMU default writeback), so every write the guest already issued survives in
   the host's cache. That is an honest model of what the page cache loses, not of a device cache;
   Btrfs/XFS barriers make the difference immaterial for consistency, but it must be said so in the
   ledger, and the steps rely on the syncs being in the right places — which finding 1 shows they
   are not for /boot. The cuts are "after each step", never during one (dracut's writes, the moves).
   Fix: re-run with a VM whose snapshot kernel differs from the running kernel (install the second
   kernel-core from the F44 repo in the "built" state, snapshot, remove the older one; or snapshot,
   then `dnf upgrade kernel*`), cut at all six points plus one during the add (kill -9 the chroot'd
   dracut, then sysrq), run `restore old` once, and assert per step: expected RUNNING, `grubby
   --default-kernel`, the entry file and initramfs of K[-1] present and non-empty, modules of the
   running kernel, no root.new, root.old present, `kawa-snap list` works; tee every check into the
   step's log. Until then the ledger line must say "proven for a same-kernel restore".

5. MAJOR — on the real PC, `restore` rolls his /home back, and Super+U promises it will not.
   Where: kawa-snap.at-HEAD:189-191, 226 (the whole `root` is exchanged); system/fedokawaii:1090-1091
   ("your home stays as it is"); the PC: /home is a directory inside `root` (fstab has one Btrfs line,
   `subvol=root`; only Downloads and VM are nested subvolumes and move across).
   What: until item (2) splits /home, a restore takes ~/.config, ~/repos (this repository's working
   tree included), notes, everything in his home except Downloads and VM back to the snapshot's
   time; `restore old` then discards what he wrote in between (recoverable by hand from root.old,
   unsaid). The script has no guard; the menu's text is false today; T48's acceptance ("on the PC: an
   undo to the pre-update snapshot and back") is scheduled before the split.
   Fix: `apply` may install the script (installing changes nothing), but before any restore runs on
   the PC: kawa-snap refuses restore while /home is not its own mount
   (`findmnt -no FSROOT /home` empty or `/`-rooted → fail "…/home is inside the system and would be
   taken back too — after the home split") — one test; the menu text corrected until then. The
   PC's undo-and-back acceptance waits for item (2), or is run with nothing of his written between
   the two restores and the ledger saying so.

6. MINOR — a kept system named root.new is deleted silently by the next run.
   Where: kawa-snap.at-HEAD:175 ("kept as $T.new (it could not be named $T.old)") vs 182-188.
   What: if line 170 or 175 fails (root.old a plain directory, an I/O error, two restores within one
   second colliding on `root.old-$(date +%s)`), the ex-root stays as root.new with its nested
   subvolumes already moved out; the next restore finds `list -o` empty and `gone`s it (187) — the
   "system before" is destroyed after being announced as kept.
   Fix: in `finish`, never leave an ex-root under the name root.new — on failure rename it to
   `$T.old-$(date +%s)` (or `-$$`), and make 187 refuse to delete a root.new that holds /etc/machine-id
   and no snapshot-fresh marker; a test for the failed-rename case.

7. MINOR — "kernel in /boot" means only vmlinuz exists.
   Where: kawa-snap.at-HEAD:216.
   What: a cut during or right after an add (findings 1/4) can leave `/boot/vmlinuz-$v` without its
   initramfs or entry; the next run skips the kernel, `grubby --set-default` then fails (no entry)
   and the message tells him to "choose kernel $v" from a menu that does not list it.
   Fix: require the loader entry and the initramfs too (or simply always `kernel-install add` the
   copy's kernels — it overwrites), and a test with a vmlinuz-only /boot.

8. MINOR — no lock: two restores at once destroy each other's work.
   Where: kawa-snap.at-HEAD:182-188, 191.
   What: a second `kawa-snap restore` (a double click in Super+U, an update's own call) sees the
   first run's root.new (no nested subvolumes yet), deletes it while the first is chroot'd into it
   running dracut, then makes its own copy.
   Fix: `exec 9>/run/kawa-snap.lock; flock -n 9 || fail "another kawa-snap is running"` before
   `mount_top`; `pre`/`post` should take the same lock (a restore under a running dnf transaction is
   the other half of this race).

9. MINOR — sync failures are swallowed, then "restart now" is said.
   Where: kawa-snap.at-HEAD:177, 225, 228 (`>/dev/null 2>&1`, no status), 237 (`sync`, no status).
   Fix: `|| fail` at 225 (nothing changed yet), `|| echo "…not confirmed on disk — wait a minute
   before restarting"` at 228/177/237 (the owner's rule: every script's errors handled).

10. MINOR — the retention puts `root.old-<ts>` subvolumes into the boot menu.
   Where: kawa-snap.at-HEAD:170-174 (two timestamped kept by design); setup.sh:2211-2212
   (GRUB_BTRFS_IGNORE_SPECIFIC_PATH exact: root, root.old, root.new, root.swap; PREFIX matches
   `prefix/*` only — grub-btrfs(8) and the upstream script: `[ "$path" = "$isp" ]`,
   `[[ "$path" == "$isp"/* ]]`).
   What: every ex-root began as `btrfs subvolume snapshot` (191), so `btrfs subvolume list -sa` lists
   it as a snapshot; grub-btrfs skips a subvolume only when it has no /boot directory; sorted
   `-rootid`, the two `root.old-<ts>` are the newest and take two of the ten slots as "N/A" entries
   (bootable, volatile — harmless, wrong). Before this change a timestamped one existed only when a
   delete failed. `root.swap` in that list is dead since this commit.
   Fix: keep the timestamped ones under a plain top-level directory (e.g. `root.old.d/<ts>`,
   `mkdir -p` once) and add `root.old.d` to GRUB_BTRFS_IGNORE_PREFIX_PATH; drop `root.swap`; a
   test_snap case that `kawa-snap list` ignores them and a verify check that grub-btrfs.cfg names no
   `root.old`.

11. MINOR — `/etc/system-update` is not stripped.
   Where: kawa-snap.at-HEAD:195. systemd.offline-updates(7): "the symlink /system-update or
   /etc/system-update". Fix: add it to the `rm -f`.

12. MINOR — from a boot-menu snapshot, kawa-snap refuses to run ("/ is not Btrfs").
   Where: kawa-snap.at-HEAD:105 (FSTYPE must be btrfs), 108-109 (`booted` from FSROOT), header 23-25
   and system/fedokawaii:1092 send him there; setup.sh:2215 boots snapshots with
   `systemd.volatile=overlay` → kernel-command-line(7): "/ is set up as an overlayfs mount".
   What: pre-existing, not a regression of this commit — but the header promises "then kawa-snap
   restore N from there", and T48's acceptance (a read-only snapshot boot) will meet it. In that
   boot `findmnt -no FSTYPE /` is `overlay`; FSROOT is the overlay's. Fix: derive the device and
   subvolume from /proc/cmdline (`root=`, `rootflags=subvol=`) when / is an overlay, or say plainly
   in the header and the menu that restore is done from the running system (the boot menu is for
   looking). Decide, then test it in the VM's snapshot boot.

13. MINOR — `undo` says "nothing changed" after kernels were added.
   Where: kawa-snap.at-HEAD:219, 193. With two kernels in K, a failure on the second leaves the first
   in /boot (entry, initramfs) until a later boot's orphan rule. Fix: track the versions this run
   added and `kernel-install remove` them in `undo`; or word it.

14. MINOR — a half-bound chroot is reused for the `remove`.
   Where: kawa-snap.at-HEAD:202-209 (binds made only when the array is empty), 219. If the third of
   six binds fails, `inside kernel-install remove` chroots with /dev and /proc only. Fix: `unbind`
   on any bind failure before returning 1.

15. MINOR — test coverage: the cases that matter and are missing (tests/engine/test_snap.sh,
   tests/installer/test_upkeep.sh).
   kawa-snap: a copy with two kernels where the second add fails (what stays in /boot); a failed
   `mv -T root.new root.old` followed by a second restore (finding 6); `restore old` with no
   root.old; `list` with root.old-<ts> present; a placeholder that is not empty ("left in root.old")
   and a nested subvolume other than .snapshots (home/dia/VM); restore while booted from a snapshot
   (FK_FSROOT) and from an overlay (FSTYPE overlay); a vmlinuz without entry (finding 7); the recovery
   path's default (finding 2 ii); the sync order (a stub `sync -f` called before `exch`, finding 1);
   /etc/system-update; no /etc/sysconfig/kernel at all; the lock (finding 8).
   setup.sh: `--kernels` under FSROOT=/root/.snapshots/N/snapshot and under `systemd.volatile=overlay`
   (finding 3); a running kernel without modules (finding 2 iii); an entry whose file name does not
   match the machine-id token (kernel-install remove exits 0 and leaves it — the log line never
   fires).

Nits
16. kawa-snap.at-HEAD:173 — `[[ … ]] && gone … || echo "kept (it holds a subvolume)"`: a failed
    delete is reported as "holds a subvolume".
17. kawa-snap.at-HEAD:152-154 — the power-cut seam ships in the installed script; acceptable and
    honest, but say so in the ledger, and gate it on a marker too (`[[ -e /run/kawa-snap.cut ]]`)
    so an exported variable alone can never reboot the PC (sudo's env reset is today's only guard).
18. kawa-snap.at-HEAD:190 — "there is no snapshot old" when root.old is missing: say "no system
    before the last restore is kept".
19. kawa-snap.at-HEAD:167 — `mv -T --no-copy` (coreutils 9.10 here) so mv can never fall into
    copy+delete of a subvolume if rename ever fails with EXDEV.
20. design §3.1 point 2 says `btrfs subvolume sync` after deletions; the code (151) does not — align
    the text, or add it where the space floor (later item) will need the space back.
21. kawa-snap.at-HEAD:166 — `mkdir -p` of a missing parent creates root-owned 0755 directories inside
    the restored copy (e.g. home/dia if the snapshot predates it).
22. 95-set-boot-entry.install promotes any stale `tmp_saved_entry` already in grubenv during the add:
    `grub2-editenv - unset tmp_saved_entry` before the loop costs one line.
23. restore-cut.sh:36 — after a recovery restore the script does not stop the VM between the two
    restores' kernels check; fine, but the table's `*` should also say the default entry was read.

Over-engineering (e): none worth the name — the script is lean; the one extravagance is the
production seam (nit 17), and the one piece of dead design is `root.swap` in setup.sh (finding 10).
Regressions (e): `list`, `pre/post`, `boot` unchanged and green; the boot-menu list regresses via the
retention (finding 10); Super+U's words no longer match the kernel behaviour only in spirit ("your
home stays" is the real mismatch, finding 5). Nothing in this code makes the flat layout or the
/home split harder — the exchange, `finish` and the ignore lists carry over; the /home guard of
finding 5 becomes the natural precondition check that item (2) lifts.

Real-PC differences from the VM (d): the layout is the same (ks.cfg: ESP, XFS /boot, one subvolume
`root`, /home inside; default subvolume 5 on both, mounted by name, so the exchange by name is
correct); the PC adds ~60 nested snapshots (one rename — fine), four more nested subvolumes (moves
not proven, finding 4 v), a libvirt VM that may hold ~/VM images open during a move (rename is not
blocked by open files; fine, unproven), and a real power supply (finding 1). Nothing in the code
can delete a snapshot: `.snapshots` is only ever renamed; `gone` is never applied to a subvolume
that holds one; the retention touches only `root.old-*`. His /home is the exposure (finding 5).

────────────────────────────────────────────────────────────────────────────────────────────────
The ledger's claims (r27-52a-restore and its "PROVEN" line): proven / not proven
────────────────────────────────────────────────────────────────────────────────────────────────
- ONE `exch`, never a moment without root ........................ PROVEN (226; VM rows)
- `btrfs filesystem sync` before/after it and after the moves .... PROVEN as written (225/228/177)
  — but /boot is not synced before the exchange: the durability the sentence implies ... NOT PROVEN
- kernels added with UPDATEDEFAULT=no, restored after ............ code + stub test; mechanism
  confirmed in Fedora's plugins; in the VM ........................ NOT EXERCISED (no add ran)
- the default set once, last (grubby after the exchange) ......... code; after `finish`, not after
  the sync; VM: same kernel, nothing to see ........................ NOT PROVEN
- nested subvolumes moved only after the exchange; a held root.new finished, never deleted
  ................................................................. PROVEN for .snapshots (VM moved/
  renamed); other nested subvolumes ................................ NOT EXERCISED
- deletions `--commit-after`, never `-R` ......................... PROVEN in code + stub test
- /.autorelabel and /system-update removed ........................ PROVEN (stub); /etc/system-update
  missed
- root.old + at most two timestamped, sorted by the suffix ....... PROVEN (stub); boot-menu side
  effect (finding 10)
- orphan_kernels_out: orphans out after boot_success, running kernel kept
  ................................................................. PROVEN (stub, test_upkeep); unsafe
  in a snapshot boot (finding 3); not VM-proven
- "every cut point proven in the VM, every start whole" .......... PROVEN only for a same-kernel
  restore on a VM without the PC's other nested subvolumes; the kernel path untouched ... NOT PROVEN
  as stated
- test_snap 118/0, test_upkeep 227/0, test_deps/test_pipefail green, shellcheck clean
  ................................................................. PROVEN (re-run / logs / shellcheck)

What must happen before this item is marked done and the PC gets it: findings 1-5 fixed (about
fifteen lines in kawa-snap, two in setup.sh, one in system/fedokawaii), the VM proof re-run as
finding 4 describes (two kernels, restore old, asserted states, logged outputs), the ledger line
rewritten to what the logs show, and the minor findings 6-15 closed or scheduled with the item.
