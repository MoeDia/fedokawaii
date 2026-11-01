VERDICT: PASS WITH CONDITIONS

Third look at T48: FIRST (2) — the flat layout and the offline /home split — on branch t48 at 771853a
(2026-11-01, working tree: only the ledger and tools/claude-loop.sh newer), plus the owed items: the
overlay restore proof, the two tests of verdict-2 finding 15, and FIRST (3)'s "root's timeline off once
/home has its own". Same rules: read-only; I ran only `bash -n`, shellcheck and the two stub tests.

What I checked and reproduced myself
- `git diff f56e526 t48` whole; system/fedokawaii-split, system/kawa-snap, setup.sh (s_layout, --layout,
  snapper_limits, r_system, s_finalize, the kernels mode, snap_boot, contained/heal), verify.sh, the
  autostart notice, tests, the three tools scripts; update-design.md §3/§3.1; systemd.offline-updates(7)
  as installed (systemd 259.10) and `systemctl cat` of system-update.target / -pre / -cleanup.service.
- Stub tests run by me: test_split 51 passed/0 failed; test_snap 203/0 (= the ledger). shellcheck -x on
  fedokawaii-split, kawa-snap, split-cut.sh, overlay-restore.sh, vm-clone.sh: clean; bash -n: ok.
- VM evidence read: /dev/shm/r27/split-cut.first9.txt (7 cut points + "none" whole: ok; the two fail-*
  rows "armed again"), split-cut.fail.summary (the two failures re-run after the harness fix: ok, exit 0),
  the case logs (none, part-home, fail-fstab, fail-copied-home), overlay-restore.summary + .log (second
  run: 11/11 ✔, saved_entry back on the real kernel entry). The VM's kickstart is the PC's layout (one
  Btrfs subvolume `root` with /home inside, XFS /boot, ESP, SELinux enforcing).
- PC facts (read-only, sudo -n): / = /dev/nvme0n1p3[/root] `compress=zstd:1,noatime`; /home, /var/log,
  /.snapshots not mountpoints; nested: root/home/dia/Downloads, root/home/dia/VM, root/.snapshots (45
  snapshots), root/var/lib/{machines,portables}; `btrfs subvolume list -o /` prints top-relative paths
  (`root/home/dia/Downloads`) exactly as `below()` parses them; btrfs-progs 7.1, coreutils 9.10,
  util-linux 2.41.5, snapper 0.13, grub-btrfs 4.14; /var/log: 60 files, 56 non-empty; /var/log/journal is
  NOCOW (C) and boot.log is 0 bytes after a normal boot; /home labels: data_home_t, container_ro_file_t,
  container_file_t with MCS categories, svirt_home_t, chrome_sandbox_home_t … (all policy types — fine
  for `cp -a` as root); no immutable files under /home; no /system-update; 849 GB free; snapper root
  TIMELINE_CREATE=yes today; /etc/selinux/fixfiles_exclude_dirs does not exist.
- The fstab writer's text logic run on a copy of the PC's real fstab (in /tmp): the four lines come out
  `UUID=7ea4… /home btrfs subvol=home,compress=zstd:1,noatime 0 0` (and log, fk, snapshots), the /,
  /boot (xfs) and /boot/efi lines kept untouched.

What holds (the core is sound and proven)
- Data safety on reading, every step: nothing inside `root` is deleted during `run` (only `clean`, in a
  later normal start, when all four mounts are from their subvolumes, with `rm --one-file-system` and a
  refusal while a subvolume sits inside); `gone` never deletes a subvolume that holds another (checked by
  `below`, no `-R` anywhere, `--commit-after`); the copies are trusted only after the tree compare
  (type, mode, owner, group, SELinux label, mtime, size, the subvolume root `.` included) and the content
  sample; nested subvolumes are moved by rename, never copied; `back` is complete and idempotent from
  every step incl. after fstab (the kept original goes back first, then snapshots, then the nested
  subvolumes, then the copies — and a copy that still holds a subvolume is left, not deleted); a cut
  resumes (`tries`, the link kept to the end) and the fourth start puts all back. The VM showed every cut
  point resumed ("start 2"), his files byte-identical (hard-linked pair still 2 links, fifo, symlink,
  xattr, NOCOW file, a newline and a space in names, Downloads/VM moved), the journal on [/log], snapper
  and the boot menu on `snapshots/N`, clean leaving root's /home and /var/log empty, and a restore of a
  pre-split snapshot (1) keeping his files and the layout; from an overlay start, `kawa-snap restore`
  works and comes back on the root subvolume with the layout flat.
- The offline-update contract: unit ordering and conditions as the man page's RECOMMENDATIONS 1, 3, 4
  (wants-symlink without [Install], FailureAction=reboot, DefaultDependencies=no, Requires/After
  sysinit.target, After system-update-pre.target, Before system-update.target). The link is kept until
  the end on purpose (recommendation 2 says remove it early): bounded by the tries counter (at most four
  offline starts) and, behind that, system-update-cleanup.service (SuccessAction=reboot, removes the
  link) — no endless loop that I can construct, except NIT 11. Another tool's link: never touched by arm
  (refused) and `run` does nothing for it — with the ordering flaw of finding 2.
- The fstab lines: same device and options as `/` (subvol stripped), subvol=NAME, replaced by mount point
  only for btrfs lines, `findmnt --verify`; the restored root gets them before `btrfs filesystem sync`
  and the exchange (kawa-snap 288–291, 326–328), so a pre-split snapshot restores with his files today's
  (proven, none.log). `.snapshots`, `home`, `/var/lib/fedokawaii/update` exist as mount points in the
  copy (a nested subvolume appears as an empty folder in a snapshot). An OLD kawa-snap inside a pre-split
  snapshot start can do little harm: versions before 1 Nov exit at "/ is not Btrfs" (overlay); the FIRST
  (1) version reads root/.snapshots (empty after the split) so `restore N` fails "there is no snapshot N",
  and `restore old` moves only root.new's nested machines/portables. (But see finding 7.)
- setup.sh: arming in repair's r_system, setup's end and --layout; the snapshot first (`-c number`,
  important); the split.failed checksum rule; the home snapper config only once /home is a btrfs mount
  (`findmnt -no FSTYPE /home`), root's timeline off only then; verify's row (verify runs as root, so the
  root-only `state` is fine). Super+U passes --with-home only while /home is not a mount — consistent
  with the new guard. Learn §8.2 is true once the split and the following repair have run (today root's
  hourly timeline still holds his files; the book is rebuilt at the end — say it in the ledger).
- No dead code; the test hook (power_cut, the `cut` file in a root-only folder) is the same pattern as
  kawa-snap's; no "…" truncation (cut -c1-160).

Earlier owed items — closed
- verdict-2 finding 12 (restore from a real boot-menu overlay start): CLOSED — overlay-restore.sh,
  second run 11/11 (the first run's failure was the harness's own one-time BLS entry sharing the kernel
  file, which grubby then picked; the proof removes it once the snapshot has started).
- verdict-2 finding 15 (a nested subvolume other than .snapshots moved by a restore; a /boot entry
  kernel-install leaves): CLOSED — test_snap cases "a subvolume inside /home … moved across, the
  folders above it made as they were" (+ the empty-placeholder case) and "a kernel put back that
  kernel-install then leaves in /boot … said, nothing else changed" (kawa-snap undo 271–283).

────────────────────────────────────────────────────────────────────────────────────────────────
Findings (MAJOR blocks the PC run · MINOR fix before done · NIT)
────────────────────────────────────────────────────────────────────────────────────────────────
No MAJOR: I found no step at which a file of his can be lost or the PC left unbootable. The MINORs
below are each small; several reduce the one real risk — a spurious "put back" that then blocks the
split on the PC until the program's checksum changes.

1. MINOR — the content sample ignores the skip list the tree compare uses.
   Where: system/fedokawaii-split:228 (skip = folders holding a subvolume + files open under $p via
   /proc/*/fd) is applied to `tree` only; 232–234 sample `find … -type f -size +0 | shuf -n 64` and
   `cmp` the source against the copy with no filter.
   Scenario: a file a process holds open and appends to (the ledger's own case: plymouth's
   /var/log/boot.log in the offline start) is sampled — on the PC /var/log has 56 non-empty files, so
   the 64-file sample takes every one of them — and differs between the copy and the cmp → `back` →
   split.failed with this program's checksum → repair refuses to arm again until a new toolkit, verify
   red, nothing he can do. (boot.log is 0 bytes on the PC after a normal boot, so the odds are lower
   than in the VM, but the race is real: run 1 in the VM hit it.)
   Fix: filter the sampled names through the same `$skip` (and exclude the open files' paths); a stub
   test where a sampled file is "open" and differs → no back.

2. MINOR — `run` can exit 1 before it has checked that the link is ours (systemd.offline-updates(7) §5:
   "in case it … points to a different location, the service must exit without error").
   Where: fedokawaii-split:95–96 (the btrfs/subvol check → `fail`, exit 1) runs before 156 `armed ||
   exit 0`.
   Scenario: an offline start of another tool (dnf's system-upgrade, used by T46's release upgrade) on a
   root that is not the expected layout, or a boot-menu snapshot (/ an overlay) that carries such a link:
   our unit fails → FailureAction=reboot → the other update is cut mid-way. (On the PC's real root the
   check passes; the risk is in the exotic starts — but the contract is explicit.)
   Fix: in `run`, `armed || exit 0` first, the layout check after it; a test (another tool's link with /
   not btrfs → exit 0, nothing done).

3. MINOR — step 4's two writes are not durable at the only moment that matters.
   Where: fedokawaii-split:264 (`cp -a …/etc/fstab $D/fstab`, no sync), 265–266 (rewrite via mktemp +
   `mv -f`, no fsync), 267 `synced`; 183 `back` restores `$D/fstab` on `-f` alone.
   Scenario: a power cut between 264 and 267 (milliseconds, but the proof's cut points sit after each
   `synced`, so this window is unproven) can leave `$D/fstab` present and empty; the next start (or the
   fourth) runs `back`, which copies the empty file over /etc/fstab: the kernel still mounts / from the
   command line, but /boot and the ESP are not mounted — kernel-install, kawa-snap ("/boot is not
   mounted") and the one-kernel rule refuse from then on, and nothing in repair rewrites fstab.
   Fix: `sync -f "$D"` right after the backup copy (before the rewrite); `fstab()` fsyncs the temp file
   (`sync "$tmp"`) before `mv -f`; `back` uses the copy only if it is non-empty and has a btrfs `/` line
   (else leaves fstab alone and says so in the reason).

4. MINOR — a split that was put back makes every later `repair` end "still needs you".
   Where: setup.sh:2276 (s_layout returns 1 for "put back at its last try … the next toolkit tries
   again"); r_system (3201–3217) calls `s_layout` bare and runs under `contained` (set -e in a subshell):
   the return ends r_system there, before guard_hooks, s_scrub, s_report, s_tuning; heal records STILL
   and repair exits 3. The VM's fail logs show the same end for --layout ("✘ line 3495: return 1 …
   fix the cause, then run the same command again").
   Fix: that state is verify's red, not repair's failure — log and return 0 there (keep return 1 for an
   unreadable state and a failed arm), or call it `s_layout || log …` as s_finalize does; a test_upkeep
   line that r_system goes on past it.

5. MINOR — `clean` never runs by itself; "removed after a good boot" is only true if someone runs repair.
   Where: fedokawaii-split clean is called only from s_layout (setup.sh:2271–2272: repair, setup's end,
   --layout); verify.sh:677 then warns "old copies hidden under the new mounts — fedokawaii repair
   removes them" until he does — after the split and after every restore of a pre-split snapshot.
   Fix: the start-up run (setup.sh:3490–3491, `kernels` mode: already gated by on_the_system, a quarter of
   an hour after the start, and `boot_success=1` as orphan_kernels_out checks) runs
   `/usr/local/sbin/fedokawaii-split clean`; verify's hint says "removed in the next start"; a
   test_upkeep assertion that the kernels run calls it only on the system itself.

6. MINOR — two different tests for "the layout is whole" in kawa-snap.
   Where: kawa-snap:177 (the --with-home guard: `home` exists at the top) vs 288 (the fstab lines:
   `snapshots` is at the top); fedokawaii-split `state` (107–111) answers "nested" for every half state.
   Scenario: `back` could not move a subvolume back into root (180–193 says so only in its log) and so
   could not delete `home` (196), or could not move `snapshots` back (185): then (a) a restore runs
   without consent on a /home that is inside root (the guard sees `home`), or (b) the copy gets a
   `/home … subvol=home` line onto an orphan `home` holding only Downloads/VM — his files sit hidden
   under that mount; (c) `state` says "nested", verify says "repair arms the split", and `arm` refuses
   with "already at the top — not made by the split". Two failures are needed; the consequence is his
   files hidden.
   Fix: one disk-level test — all four of home, log, fk, snapshots exist at the top — used for the guard
   and for the lines (the overlay start has no `state`; this test works there too); `state` gains a
   third answer ("broken: NAME at the top but not mounted / not made whole") that verify shows with the
   reason; `back` writes "left behind: …" into split.failed when a move back or a delete failed; tests
   for the three.

7. MINOR — the restored copy keeps its own, older kawa-snap and has no fedokawaii-split.
   Where: kawa-snap:285–291 prepares the copy (strips markers, adds the lines) but leaves
   /usr/local/sbin as the snapshot had it.
   Scenario: every snapshot on the PC today (45, the baseline kept for good) predates this code. After
   `restore N` of one of them the running system's kawa-snap reads root/.snapshots (empty) — Super+U
   says "no snapshots yet" — and for snapshots before 1 Nov 07:05 the way back, `restore old`, is the
   unhardened two-rename version; fedokawaii-split is absent, so `state`/`clean`/verify's row cannot run
   until `update` brings the toolkit. The VM proof restored snapshot 1 and asserted files and mounts,
   not that the restored system can still list or restore.
   Fix: next to the fstab lines, install today's `kawa-snap` and `fedokawaii-split` into the copy's
   /usr/local/sbin (two `install -m 0755` lines; the restore already prepares the copy); a test_snap
   assertion; the ledger says the rest of the toolkit is that day's until `update`.

8. MINOR — a notice and a header that are false for pre-split snapshots started from the boot menu.
   Where: configs/home/.config/dwl/autostart.sh:114–116 ("your files as they are") keyed on
   systemd.volatile=overlay alone; kawa-snap:30–32 ("your files, in /home of their own, are today's").
   Scenario: a pre-split snapshot's fstab has no /home line, so in such a start /home is that day's
   files on the memory layer: he sees October's home, and anything he saves there is gone at the
   restart. All 45 of the PC's snapshots are such until they age out — the baseline never does.
   Fix: the notice tests `mountpoint -q /home`: mounted → today's text; not → "your files here are that
   day's too — nothing done here is kept"; the header: "in a snapshot made after the disk's new layout".

9. MINOR — /home's snapshots are not kept out of the boot menu by path.
   Where: setup.sh:2302 GRUB_BTRFS_IGNORE_PREFIX_PATH lacks `home/.snapshots`; only 2304's description
   "timeline" filters them. grub-btrfs lists every snapshot subvolume (`-sa`) and, with /boot a separate
   partition, gives each the real kernels.
   Scenario: once the home config exists (the next repair after the split) any `home` snapshot with
   another description — a later restore-file flow's "before …", or by hand — becomes a boot entry
   that starts a /home snapshot as root: dracut's emergency shell. Untested in the VM (the home config
   was created in the overlay run, its timeline never fired).
   Fix: add `home/.snapshots` to the prefix list (and `$t.copy`, `$t.new` are already specific paths);
   a test line in test_upkeep's snap_boot check.

10. MINOR — design §3's "a snapshot refused unless /.snapshots is that mounted subvolume" is not built.
    Where: kawa-snap pre (93–98), setup.sh snapshot_before (2641–2652), with `state` as in 6.
    Scenario: /.snapshots not mounted (its line lost, the subvolume renamed): snapper happily creates
    snapshots into the plain folder — nested inside root again, invisible to `kawa-snap list` (which
    reads the top-level `snapshots`), carried by the next restore's `finish`; `state` says "nested".
    Fix: when a top-level `snapshots` exists and /.snapshots is not mounted from it, `pre` notes
    (never stops dnf) and `snapshot_before` refuses; `state`'s "broken" answer (6) names it.

11. NIT — fedokawaii-split:159 `n=$(($(cat tries) + 1))`: non-numeric content (only a damaged file could)
    → arithmetic error, `n` unset, `set -u` exits before the counter is rewritten → FailureAction=reboot
    with nothing bounding it. `[[ $t =~ ^[0-9]+$ ]] || t=0`.
12. NIT — the give-up path (204) removes $D with its log before writing it anywhere, and the runtime
    journal (after --relinquish-var) is dropped at the reboot: the "why" is lost. Append $D/log to
    root's /var/log/fedokawaii-split.log first.
13. NIT — design §3 drift: it still says `--reflink=always` (built: auto, because journald's NOCOW files
    cannot reflink — rightly), "marked not restorable" (built: restorable with the lines — better),
    "refused while a VM runs" (moot offline), `/etc/selinux/fixfiles_exclude_dirs` (not on the PC).
    Add an "As built" paragraph as §3.1 has.
14. NIT — ledger honesty: write the evidence as it was — the nine-case table (first9) had two "armed
    again" rows from a harness assertion reading only the last line of `setup.sh --layout`; the two
    failure cases were re-run after the fix (fail.summary, exit 0); the overlay proof's first run
    re-entered the overlay because of the harness's own one-time entry (saved_entry=fk-overlay), the
    second run is the one kept; "a pinned snapshot" is `-c number important=yes` (NUMBER_LIMIT_IMPORTANT
    4-10 — not a pin); Learn §8.2's "of your files every hour" is true after the split + repair.
15. NIT — wording: `setup.sh --layout` ends a put-back state with the generic "fix the cause, then run
    the same command again" (4 removes it); verify's nested+failed row could add "nothing for you to
    do"; `arm`'s "a subvolume home is already at the top of the disk — not made by the split" is the
    wrong sentence when it is the split's own leftover (6).
16. NIT — tests: no stub run of the copy/compare/move/fstab path (btrfs as folders would do: `subvolume
    create` → mkdir, `show` → a marker) — the VM proof is the only guard of the heart of the program,
    and test_split's `subvolume show` always answers no, so `back`'s subvolume branches run only in the
    VM.
17. NIT — the copied journal files lose NOCOW (cp cannot carry the attribute); tmpfiles' journal-nocow
    re-sets +C on the folders at the next start, so only the active system.journal stays COW until it
    rotates. Performance only; `chattr +C` on the copy's journal folders before the copy would keep it.
18. NIT — `state` (verify) and `clean` (repair) share /run/fedokawaii-split/top without a lock; one's
    EXIT trap can unmount under the other (reads then fail; nothing wrong is deleted — the paths vanish).
    kawa-snap's flock pattern would be consistent.

What the proof does not cover (say so in the ledger; none blocks)
- Scale: the VM split ~80 MB in 3 s; the PC has 236 271 files/35 GB in /home, 552 MB /var/log, 45
  snapshots — minutes, not seconds; the tree listing (two `find -printf %Z` passes) and `shuf` over
  236k names are untested at that size (low risk).
- A cut inside step 4 or inside `end()`/`back()` (the cut points sit after each sync).
- The home snapper config's snapshots in the boot menu (9); verify/Super+U in a restored pre-split
  system (7); an immutable file under the hidden copies (none on the PC today).

Conditions of this PASS (same pass, before t48 → main and `apply` on the PC)
- Fix 1–10, each with its test; test_split and test_snap green; shellcheck clean.
- Because 1–3 and 6 change the program that was proven, one more VM run of `split-cut.sh f44b none
  fail-fstab` (≈6 min) with its table kept, and the ledger line of 14.
- Then the PC: `apply` (repair arms it after the snapshot) and a restart; afterwards verify green (with 5,
  without a second repair), `kawa-snap list` 45+, the boot menu on `snapshots/N`, Downloads and VM
  whole, the journal on [/log] — recorded with the commands' output, as the VM rows are.
On that, FIRST (2) is done: the invariants hold at every instant I could construct, and the VM has
shown each cut point and both failures ending whole.
