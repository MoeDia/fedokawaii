VERDICT: PASS

Second look at T48 FIRST (1) at commit 6cede28 (2026-11-01), same rules (read-only; test_snap run by
me: 164/0; shellcheck on kawa-snap 6cede28: clean; the evidence copy of kawa-snap is byte-identical
to `git show 6cede28:system/kawa-snap`; the working tree's kawa-snap and test harness equal 6cede28).
The five majors are closed and now proven in the VM under the conditions that matter (a snapshot
whose only kernel was removed from the running system, cuts after every step and once inside
dracut, the exchanged cut placed after the sync, restore old). What remains is small — three minors
and a few nits — none of which can leave him unbootable or lose data; they are to be closed in the
same pass, before `apply`, and the conditions are listed at the end. PASS holds under those.

────────────────────────────────────────────────────────────────────────────────────────────────
Earlier findings — closed / open / partly, with what I checked
────────────────────────────────────────────────────────────────────────────────────────────────
1. /boot not durable before the exchange — CLOSED. kawa-snap:291-294: `sync -f /boot` and the ESP,
   each `|| undo`, then `btrfs filesystem sync || undo`, then `exch` (296). The proof confirms the
   premise and the fix: adding.log shows that after a cut 3 s into dracut, /boot held 0 files and 0
   entries for A (the unsynced writes vanished exactly as predicted), and the next restore put A back
   whole; every other row ends "whole" (image non-empty + entry, read as root).
2. The kernel/root window — CLOSED. (i) 297→301: exchange, sync, `default_to` (grubby + `sync -f
   /boot`), then `finish` (303). (ii) the recovery branch 230-239 sets the default (`newest` + `whole`
   → `default_to`), finishes, restorecon, boot list, sync, exit 0 with a plain message; test_snap
   asserts grubby is called there. (iii) setup.sh `kernel_match`: a running kernel without modules →
   the newest whole kernel that has them made the default, logged and notified; exchanged.log shows
   it for real: the restored root came up under B ("7.2.13-nomod"), `setup.sh --kernels` set A, one
   restart, A with modules, then the next restore finished the cut one (rc=0). test_upkeep covers
   kernel_match with a faked `uname -r`. Two consequences of the design are new minors (N1, N3).
3. `--kernels` inside a boot-menu snapshot — CLOSED. setup.sh `on_the_system` (FSTYPE btrfs, FSROOT
   = /<fstab subvol>, no systemd.volatile=overlay) gates the dispatch; the unit carries
   `ConditionKernelCommandLine=!systemd.volatile` (systemd.unit(5): a single word matches the left
   hand side of an assignment, so `systemd.volatile=overlay` is caught). test_upkeep: FSROOT a
   snapshot path → nothing removed, nothing set; overlay on the cmdline → nothing removed. On the
   PC `findmnt -no FSTYPE,FSROOT /` is `btrfs /root`, fstab `subvol=root` — the rule runs there.
4. The proof — CLOSED. restore-cut.sh (the "two-kernels" state: prepare.log — S=2 under A=7.2.11, B=
   7.2.13 installed and running, A removed, "gone" asserted). Every row's log shows "kernel
   7.2.11… back into /boot" (the add ran each time), RUNNING asserted against the expected system,
   the kernel's modules, the next restore's exit, `grubby --default-kernel`, image+entry, root.old
   present, no root.new, `kawa-snap list` answers; restore old returns to the marked system under B
   with B the default. Outputs are logged verbatim. Two honesty points remain (N5).
5. /home on the PC — CLOSED. kawa-snap:164-166 refuses while `/home` is not a mountpoint unless
   `--with-home`; system/fedokawaii prints "home goes back to then too" in that case and passes
   `--with-home` on his typed "yes" ("home stays as it is" only once /home is a mount); test_menu
   covers both texts and both calls. On the PC `/home is not a mountpoint` → the guard engages.
6. ex-root left as root.new then deleted — CLOSED. 222-223: root.old, else root.old.d/TIME-PID; a
   leftover root.new without the mark is never deleted (231-239); with the mark it is a copy (240).
   Test "cannot be named root.old" present.
7. vmlinuz-only "present" — CLOSED. `whole()` 182 (vmlinuz + non-empty image + entry), used at 283
   and 232; tests for vmlinuz-only and for whole-left-alone.
8. No lock — CLOSED. 167 `flock -n` on /run/kawa-snap.lock; `pre` waits on it ≤ 600 s (90), never
   stopping dnf; 168 refuses while dnf5/dnf runs. Tests for both.
9. Sync status ignored — CLOSED. 291, 292, 294 undo; 297, 225, 236, 306 say so.
10. root.old-<ts> in the boot menu — CLOSED. Kept under the plain folder root.old.d (214-216),
    `GRUB_BTRFS_IGNORE_PREFIX_PATH` += root.old.d (prefix match is `"$isp"/*`, which this satisfies),
    `root.swap` replaced by `root.copy` in the exact list; test: two kept, listed nowhere.
11. /etc/system-update — CLOSED (259; test).
12. From a boot-menu snapshot (/ an overlay) — PARTLY. 115-126 read root=UUID= and rootflags=subvol=
    from /proc/cmdline; `list` marks the booted one and `restore` mounts the top by UUID; stub-tested
    (list + restore). Not proven in a real `systemd.volatile=overlay` boot, and the header (27-28)
    now promises it. Prove it as one more restore-cut row (boot the grub-btrfs entry of S, run
    `kawa-snap restore S --with-home`, start, assert as the others) — T48's read-only-boot acceptance
    is the natural place — or soften the header until then. Not gating: the running system's path is
    the one the button will use.
13. "nothing changed" after kernels were added — CLOSED (252-257; `added[]`; test for the remove).
14. half-bound chroot — CLOSED (270).
15. Test coverage — PARTLY. Added: the order, the mark both ways, the recovery's default, --with-home,
    the lock, dnf running, the failed rename, vmlinuz-only, whole, undo's remove, restore old with
    none, the overlay boot, root.old.d, /etc/system-update, the snapshot-boot guards, kernel_match.
    Still missing (nits, not gating): a nested subvolume other than `.snapshots` (the stub's
    `subvolume list` still answers only `.snapshots`, so `parents()` and the rmdir placeholder for
    home/dia/Downloads-style paths — four of them on the PC — run only in production); a /boot entry
    whose name does not carry the machine-id token (kernel-install remove exits 0 and leaves it).
16-23 (nits) — CLOSED: 218-219 the right message; 180 marker-gated seam; 246 wording; `--no-copy`
    everywhere a subvolume moves; design §3.1 "As built" aligned (no `subvolume sync`, said why);
    `parents()` 189-197 copies owner and mode; 281 drops a stale tmp_saved_entry; the table has a
    DEFAULT column.

────────────────────────────────────────────────────────────────────────────────────────────────
New findings
────────────────────────────────────────────────────────────────────────────────────────────────
N1. MINOR — the heal's precondition is not met on the PC until a boot image is rebuilt.
    Where: setup.sh:568-574 (s_kernels writes /etc/dracut.conf.d/fedokawaii.conf `force_drivers+="
    xfs vfat "`), no `dracut -f` follows; `kernel_images` (656-666) builds only missing images; the
    only regenerate-all is the microcode branch (1131). `apply` runs theme/verify, not s_kernels.
    What: `kernel_match` can only write grubenv and read /boot if /boot (XFS) mounts under a kernel
    whose modules the root lacks — that is exactly what `force_drivers` buys, but only in images
    built after the file exists. The VM proof wrote the file before installing B (prepare), so B's
    image had it; on the PC, 7.2.11's image predates it, so the exchanged-window heal would log
    "could not be made the default" and he would have to pick A in the GRUB menu by hand (A's entry
    is whole — not unbootable, but the designed heal is inert until the next kernel update).
    Fix: in s_kernels, compare the file's content before `write_file` (write_file has no changed
    status); when it is new or changed, `run dracut -f --kver "$(uname -r)"` once (and log it); make
    sure the step runs on `update`/`repair` so the PC gets it at the first of those; a test_upkeep
    assertion that the rebuild is called on first write and not on the second.
N2. MINOR — restore assumes /boot (and the ESP) are mounted.
    Where: kawa-snap:182 (`whole` reads /boot), 268-269 (`mountpoint -q /boot || continue` — an
    unmounted /boot is silently skipped, so the chroot's kernel-install writes into the copy's own
    /boot directory inside the subvolume), 291 (`sync -f /boot` on the root fs then), 185 (grubby on
    a grubenv that is not there).
    What: with /boot unmounted (the N1 state, or any failed mount) a restore "succeeds" with its
    kernel files inside the root subvolume where GRUB never looks; the default fails with a message
    but the final line still says "restart now".
    Fix: after mount_top, `mountpoint -q /boot || fail "/boot is not mounted — nothing changed"`, and
    the same for /boot/efi when fstab names it (`findmnt --fstab /boot/efi`); one test with the
    mountpoint stub answering no.
N3. MINOR — a restore cut after its exchange is finished only if someone runs a restore.
    Where: kawa-snap:230-239 (the finishing branch lives in `restore` only); `list` (140-153) reads
    `$top/$T/.snapshots`, which after such a cut is empty (the snapshots sit in root.new) and so
    prints nothing — Super+U then says "no snapshots yet" and never reaches the restore prompt; no
    boot-time hook calls kawa-snap (setup.sh calls only `kawa-snap boot`).
    What: the restored system runs fine, nothing is lost, but snapper sees no /.snapshots, the boot
    menu's list goes stale, and the only ways out are `restore old` (if a root.old exists) or a shell.
    Fix: smallest honest version — `list` notices an unmarked root.new and prints a line
    ("unfinished\t…\ta restore was cut short — kawa-snap finish") and a `finish` verb reuses 230-239;
    the start-up run (`--kernels`, already gated by on_the_system) calls `kawa-snap finish` so it
    heals itself within a quarter of an hour; a test for `list` and for the verb.
N4. NIT — `default_to` returns 0 after a grubby failure and the run still ends with "restart now"
    (186, 301, 307); carry the failure to the last line ("choose kernel X at the next start") so the
    message he reads last is the true one.
N5. NIT — the evidence table is a composite: its footer "exit 1 in 979 s" is the 05:56–06:27 run in
    which the first "adding" method failed; the adding row and adding.log are the 06:36 re-run (the
    annotation says 06:40; the file says 06:36:55), and the failed attempt's log was overwritten
    (`: >"$log"`). The ledger must say exactly that, and the final restore-cut.sh deserves one clean
    run (eight rows, exit 0, ≈17 min) whose table is the one kept.
N6. NIT — test_menu "594/0" is claimed in the ledger with no log in the evidence (/dev/shm/r27/
    suite.log is an older run with other counts); hand the log over with the claim.
N7. NIT — before `apply` on the PC: the old kawa-snap may have left `root.new` (unmarked — the new
    script would take it for an ex-root and "finish" it: harmless, but the message would be false),
    `root.copy` or `root.swap` (no longer in grub-btrfs's ignore list). One read-only look at the top
    level (mount subvolid=5 read-only, `ls`) and a by-hand removal if anything is there.
N8. NIT — `kernel_match`'s "whole" test (vmlinuz + image) lacks the entry check kawa-snap's `whole`
    has; align them (grubby fails without an entry and the heal only logs).
N9. NIT — kawa-snap:90: `pre` waits for a restore's lock, but once a restore has exchanged the roots
    a dnf transaction run before the restart lands in the system that is about to be replaced
    (lost at reboot). The button (T45) will serialise this; until then the final message could say
    "install nothing before restarting".

────────────────────────────────────────────────────────────────────────────────────────────────
Conditions of this PASS (before `apply`, same pass; none is deep)
────────────────────────────────────────────────────────────────────────────────────────────────
- N1 (the image rebuild when the dracut conf is new, and the step on update/repair), N2 (the /boot
  mounted check), N3 (list says it, a finish verb, called from the start-up run) — each with its test.
- The ledger line for the round-2 proof written from the logs: eight rows, which were one run and
  which the re-run, exit codes as they were; "the overlay restore is stub-tested, VM proof owed with
  the read-only-boot acceptance" (finding 12); N7's look at the PC's top level, its result noted.
- Nothing of this changes the VM-proven core: one exchange, /boot durable first, the default at
  once, a cut run finished with its default, the kernel rules never in a snapshot boot, his /home
  only with his consent until the split. On that core the item is done.
