# The update system — written design (T44, round 27)

The owner's words (CLAUDE.md, 2026-10-25 19:51–20:17, "FINAL decision on updates"): one item in
Super+U, "update"; he clicks it and it does everything A to Z — snapshot → refresh → update (packages,
the tools we ship, nvim plugins by the lock, firmware listed) → verify → desktop smoke test → keep, or
roll back → hold the culprit by bisection → the local AI fixer → retry → a short, clear report. He
never runs dnf. No background auto-updates; a quiet notice when updates have waited 2+ weeks or a
release nears its end. Release upgrades through the same button once a VM pre-flight is green.
Snapshot = undo on this disk, backup = a copy on another drive. Bulletproof: every failure mode
injected in the VM ends in a working system and a clear message.

Sources: `.claude/notes/update-research.md` (batches B1–B6; a claim here cites "B1 #n" = the batch's
design bullet n, or the source's URL).

## 1. Where we start (1 Nov 2026, read from the code)

| piece | what it does today | file |
|---|---|---|
| `fedokawaii update` (Super+U → update) | `setup.sh --update`: network, toolkit first, preflight 10 GB, snapshot "before update DATE" (important), lenient repos, `dnf upgrade --refresh` (twice, then without third-party repos), then ~35 contained steps (settings, manifest, drivers, wlroots, upstream pins, fonts, torrra, Prowlarr, nvim plugins (lock kept, six back), dev tools, old kernels, dracut, dwl at its pin, the theme, guard hooks, sound, GTK), verify, records (`last-update`), kernel-restart hint | setup.sh `do_update` |
| snapshots around every dnf run | libdnf5 actions → `kawa-snap pre/post` (snapper pre/post pair, the boot menu's list) | system/kawa-snap, `snap_hooks` |
| the guard | before a transaction: stops one that would remove a manifest package or a library our builds load (NEEDS); after: `fedokawaii-after-dnf.service` (relink dwl / helpers, checks, a notice) | system/kawa-dnf-guard, lib/guard.sh |
| dwl's own wlroots | a private copy; a Fedora wlroots bump never touches dwl; `dwl_starts`: headless, pixman, 1 s | lib/guard.sh |
| restore | `kawa-snap restore N|old`: a writable copy of snapshot N swapped in as `root` (the replaced one kept as `root.old`), nested subvolumes moved across, kernels the copy has put back into /boot (kernel-install in a chroot), kernels it lacks removed, its newest the default — at the next start | system/kawa-snap |
| boot menu | grub-btrfs (no daemon): the newest ten "before" points, read-only boots | kawa-snap boot |
| release upgrade | `fedokawaii upgrade`: released + settled (WAIT 60 days), RPM Fusion ready, COPRs left out, libraries dwl needs present in the new release, preflight 20 GB, snapshot, `dnf system-upgrade` download + reboot, `fedokawaii-after-upgrade.service` | setup.sh `do_upgrade`, `do_after_upgrade` |
| verify | ~258 checks; the record the menu reads | verify.sh |
| reminders | `fedokawaii remind` (every 90 days; release WAIT) | system/fedokawaii |

What is missing against his words: no desktop smoke test (dwl alone, 1 s, pixman — not the session);
no automatic rollback (a red verify is only reported); no bisection, no hold (versionlock was refused
on purpose: lib/guard.sh "No dnf versionlock"); no AI fixer; no VM pre-flight; the report is the
terminal's scroll; /home is inside the root subvolume (a restore takes his files back in time —
B1 #9); a transaction cut by power has no "finish or roll back" at the next boot; a kernel or a root
that does not boot falls back only by hand (the boot menu).

## 2. The core idea: every change is proven in a copy first

The research's lesson (B2 #4, #8, #9; B4 #3, #11, #17; B3 #1, #3, #13): updaters fail people when a
half-done change meets the running system, when "rollback" means a reboot into an unknown state, and
when nobody can tell which package broke what. So the button never changes the running system with
an untried transaction:

1. **The candidate.** The transaction is resolved once, on the running root, and stored, not run:
   `dnf5 -C upgrade --store=$fk/tx` (dnf5-upgrade(8): "store … instead of running it"; packages and
   transaction.json in the folder). A writable snapshot of the running root (`root.cand`, top
   level) then receives it **inside a container**: `systemd-nspawn -D cand --private-network
   --bind-ro=$fk/tx --bind=<scratch>:/boot --bind=<dGPU render node> … dnf5 --disable-plugin=actions
   -C replay /tx` — the container gives the scriptlets their own /proc, /sys, /dev and /run (kernel
   %posttrans → kernel-install → dracut builds the host-only image it will boot with; nothing
   reaches the host's udev or systemd), and the actions plugin is off: inside the container its
   configuration is the candidate's own copy, whose kawa-snap pre/post and guard would act there
   (snapper on the container's root, the guard arming follow-ups) — and outside a container
   (`--installroot`) dnf5 would load the host's plugins (installroot(7)). Preconditions, checked in
   phase 0: the candidate's /etc/kernel/cmdline holds root= and rootflags=subvol=root (kernel-install
   ignores /proc/cmdline in a container, so without it every kernel update is a false red on the
   BLS check — this PC has it, B5 #8); the render node granted to the container
   (`--property=DeviceAllow=/dev/dri/by-path/pci-0000:03:00.0-render rw`). The candidate's SELinux
   labels are the container's, not the live ones: nothing is ever copied out of it — only its
   verdict is used. `replay` performs "the exact same operations … an error in case
   of any differences in installed packages or their versions" (dnf5-replay(8)): the same
   transaction later on the live root is replay's own guarantee, no comparison needed. The new
   kernel lands in the scratch /boot, never the real one. His configs live in /home/dia/.config:
   a writable snapshot of `home` (after the split) is bound in at /home for the checks and the
   fixer. The candidate is checked where it lies: every binary of ours links (`ldd`), each config
   we own parses with its program's own check, dwl and the C helpers rebuilt against it start
   headless, the greeter's and the panel's GTK load, `rpm -V` of our files, the BLS entry the new
   kernel would get has root= and rootflags (B3 #7), its initramfs holds amdgpu, btrfs and the
   splash (B3 #6), and Mesa from the candidate draws: dwl headless with gles2 on the dGPU's render
   node, bound by path (`/dev/dri/by-path/pci-0000:03:00.0-render` — node numbers change across
   kernels, and T32 moves the session to the iGPU). Proven in the VM first (ledger r27-49-exp1: the
   replay into a bare chroot worked, the kernel only in the scratch /boot, the same 1,973 packages
   live; the container replaces the bare chroot because dracut and grub's tools need /proc, /sys
   and /dev).
2. **Bisection and the fixer work on candidates**, never on the running system: a red candidate is
   thrown away; halves of the package set are tried in fresh candidates (cheap: a snapshot is
   copy-on-write; no reboot); the AI fixer edits a candidate (B6 #12–13).
3. **Then the running system** replays exactly that stored transaction (`dnf5 -C replay $fk/tx`),
   in place, online, under rpm's inhibitor (B1 rpm-plugin-systemd-inhibit), with the "before"
   snapshot pinned and an in-flight marker; then the full verify and the desktop smoke test (the
   real GPU, the real session's programs, headless) — the checks a container cannot make. Every
   stored package is verified first (`rpmkeys --checksig`): replay skips OpenPGP checks.
4. **Red after that** (rare: what only the real machine shows) → the pinned snapshot is restored
   (kawa-snap restore, hardened per §3.1: the writable copy exchanged in for the next start,
   kernels matched) and the report says "restart to get the system before the update back"; the
   hold and the retry follow. **Automatic restores only once /home is its own subvolume**
   (`findmnt -no FSROOT /home` = /home): before the split a restore would take his files back in
   time, so until then it is offered, never done by itself; the split comes before the live
   replay is enabled on the PC.
5. **What the copy does not hold: the toolkit's own steps.** After the replay the update runs its
   steps on the running system (setup.sh `update_steps`): the settings, the manifest's packages this
   machine lacks, the hardware's (firmware, microcode: lib/hardware.sh), the tools at their pins,
   the fonts, our builds, the theme. They are the toolkit's changes, not Fedora's: each toolkit
   commit is proven before it reaches him (tests/, a fresh VM install, update-green.sh), and on a
   machine that already has them they install nothing (the PC's press of 1 Nov: none; the stale VM
   of run 7: python3-pyte, wlrctl, wireless-regdb, three small transactions). The same after-checks
   judge them with the packages; a red is undone with the update (the pinned snapshot) and the set
   is held, since the culprit cannot be told apart then: the report says "all N packages together".
   Storing them with the upgrade (`dnf5 do --store … --action=upgrade --action=install …`, one
   transaction the copy would prove) was weighed and not taken (the master's should-fix 2, 1 Nov;
   the reason met its re-review 3): `--skip-unavailable` (dnf5-do(8)) covers a wanted package that is
   not there, not one that conflicts or whose dependencies are broken — that stops the one resolve,
   Fedora's upgrade with it; and `--skip-broken` would let dnf drop parts of the upgrade to make a
   want fit — a partial upgrade, which the update never makes. A live install that fails is one step
   reported, the upgrade kept, and the next press tries it again.

Why online and not offline for the routine update (B2 #8 argues offline): the candidate removes
the reason (an untried transaction under a running desktop), and an offline update costs him two
restarts and a password each time; the transaction itself is short (the VM: 34 s for 56 packages)
and inhibited; a cut-off one is caught at the next start (§4, phase 5). Honestly: most runs carry a
kernel, Mesa or glibc and want a restart anyway (phase 7 recommends it, never forces it) — online
keeps the rest of his session alive meanwhile. Its cost: the transaction runs twice (candidate and
live, ≈ 2× its time; T60 measures). Release upgrades stay offline (Fedora's documented path,
§4.4), after a green VM pre-flight and a green candidate.

## 3. The disk layout this needs (T48 builds it; migrated on the PC once, the ISO makes it so)

| top-level subvolume | mounted at | rolled back with the system? | why |
|---|---|---|---|
| `root` | / | yes | the system: packages, /etc, the rpm database (/usr/lib/sysimage/rpm: rolls back with the packages — B1 Changes/RelocateRPMToUsr) |
| `home` (new) | /home | **never** | his files, configs and repositories: a restore must not take them back in time (B1 #9 — today /home is inside `root`) |
| `log` (new) | /var/log | never | the journal and dnf's logs of the run that failed survive the restore that undoes it |
| `fk` (new) | /var/lib/fedokawaii/update | never | the updater's own memory — phase, holds, history, reports, the fixer's attempts (B4 #8: a rollback must not erase the updater's memory) |
| `snapshots` (moved out of root) | /.snapshots | — | top level, so a restore carries nothing nested and no `delete -R` can reach a snapshot (B5 #2, #6); a snapshot refused unless /.snapshots is that mounted subvolume; listed in /etc/selinux/fixfiles_exclude_dirs |
| `root/home/dia/Downloads`, `…/VM`, `var/lib/machines`, `var/lib/portables` | — | no (nested subvolumes are never in a snapshot) | Downloads and VM move into `home` with the split (renamed: VM images are NOCOW, never copied); machines/portables stay (empty, systemd's) |

Never /var or /var/lib whole: the SELinux store (/var/lib/selinux), alternatives, rpm-state and
authselect must roll back with /etc and /usr (B5 #5; Fedora moved the rpmdb into /usr for the same
reason). fstab names subvolumes (`subvol=`, never subvolid), with the same options as /, no
`nofail` on /home; the lines are re-asserted in an incoming root's fstab before every exchange.

The split (once, `fedokawaii-split`, B5 #4): offline — a unit wanted by `system-update.target`, so
nothing holds /home open — after a pinned snapshot: snapper's timers and snapperd stopped; refused
while a VM runs; the top level mounted (subvolid=5); `btrfs subvolume create top/home`; `cp -aT
--reflink=always -x /home top/home` (-a keeps SELinux contexts and xattrs; -x stops at the nested
subvolumes, checked); Downloads and VM renamed across (`mv`); the trees compared (counts, sizes,
a checksum sample); the fstab line added; mounted over /home (the old directory not renamed); the
shadowed copy removed with plain `rm` only after a good boot; snapshots from before the split
marked not restorable (they hold the old /home). The same for /var/log and `fk`; `.snapshots`
renamed to the top level. The ISO (T56) creates the layout from the start.

**As built (1 Nov 2026, T48 FIRST (2): system/fedokawaii-split; proven by tools/vm-inject/split-cut.sh
and overlay-restore.sh, reviewed by the master — .claude/notes/master-T48-verdict-3.md).** Where it
differs from the text above: the copy is `cp -aT --reflink=auto -x` (btrfs refuses to reflink
journald's NOCOW files into a COW folder: those are written again, the room for it checked before
arming — du of /home + /var/log + 5 GiB); the copy is compared entry by entry (type, mode, owners,
SELinux label, time, size) and 64 files by content, files a process holds open there (plymouth's
boot.log in the offline start) copied as they were and left out of both; each step is synced and a
cut resumes at the next start (the /system-update link stays until the end, three tries), a failure
or a fourth start puts all of it back and keeps the reason with the program's checksum (repair arms
it again only for a new program); snapshots from before the split stay restorable: kawa-snap gives
the restored root the layout's fstab lines and today's kawa-snap and fedokawaii-split, so his files,
the logs and the updater's memory stay today's; the old copies the mounts hide are removed by the
start-up run once a start was good (boot_success=1), or by repair; "refused while a VM runs" is moot
(nothing runs in the offline start); /etc/selinux/fixfiles_exclude_dirs is not needed (no relabel
of the whole disk is ever run). A half layout (a put-back that could not undo everything) is
`state: broken` — verify says it with the reason, nothing arms over it, kawa-snap treats the disk
as not split (--with-home asked, no fstab lines given).

### 3.1 kawa-snap restore, hardened before the button relies on it (B5 #1–3, #8, #11, #17)

Three unsafe spots in today's restore (system/kawa-snap), each fixed and each cut point proven in
the VM (T49 restore-cut.sh: power off after every step):
1. *The swap is two renames* (lines 187–188): between them no `root` exists, and the kernel mounts
   by name — a cut there ends in dracut's emergency shell. → One `exch` (RENAME_EXCHANGE: atomic,
   between subvolumes under any parent; `exch` from util-linux is installed) of `root.new` ↔
   `root`, then the swapped-out tree renamed `root.old`, then `btrfs filesystem sync` before any
   /boot edit and before the word "restart".
2. *Nested subvolumes are moved before the swap, and leftovers deleted with `delete -R`* (lines
   149–153, 176–189): a cut or a failed rename lets the next run delete every snapshot. → Snapshots
   at the top level (§3) leave nothing nested to carry; never `-R` a subvolume that holds another
   (`btrfs subvolume list -o` checked first); deletions with `--commit-after` and `btrfs subvolume
   sync` (else "may appear again after a crash").
3. *Kernel and root paired by two unrelated writes*: `kernel-install add` in the copy flips grub's
   `saved_entry` before the swap, `grubby --set-default` after it — a cut in either window boots a
   kernel without its modules. → `kernel-install add` with UPDATEDEFAULT=no (the copy's
   /etc/sysconfig/kernel for the run), needing the copy's /etc/kernel/cmdline (rootflags=subvol=root),
   a valid fstab and machine-id, /dev /proc /sys /run /boot /boot/efi bound; the default set once,
   after the exchange and the sync; `restorecon -R /boot` on the host; orphan kernels removed with
   `kernel-install remove` only after the restored root has booted; installonly_limit stays 2 and no
   kernel transaction runs while a probation is open (that run holds the kernel: one at rest, the
   previous one only until the new is marked good — setup.sh's rule kept).
Also: /.autorelabel, /system-update and /etc/system-update stripped from the copy before the
exchange; no blanket relabel (a restored root is self-consistent: labels and policy travel together
— B5 #11) — a `restorecon -R -n -v` dry run on /home, /var/log and /boot relabels only the
differences; the ESP and the bootloader are never rolled back and never "repaired" to older
versions (B5 #10: excluded from rpm -Va verdicts); `restore old` reconciles /boot as a restore does;
retention: `root.old` plus at most two timestamped ones in the plain folder `root.old.d` (out of
grub-btrfs's list: GRUB_BTRFS_IGNORE_PREFIX_PATH); the booted or default subvolume never deleted.
(rpm's database needs no checkpoint before a snapshot: a Btrfs snapshot is one instant and SQLite
recovers its write-ahead log from it as after a power cut; no transaction runs under the lock.)

As built (1 Nov, after the master's first review — .claude/notes/master-T48-verdict-1.md):
- the order: the copy (with a mark file, `.kawa-snap-copy`) → its kernels made whole in /boot (vmlinuz,
  image and entry; added with UPDATEDEFAULT=no and grubenv's stale `tmp_saved_entry` dropped) →
  `sync -f /boot` and the ESP, each checked (else undone: the added kernels removed, the copy gone) →
  `btrfs filesystem sync` → `exch` → sync → **the default at once** (grubby, then `sync -f /boot`) →
  the moves, the names (finish) → restorecon /boot, the boot menu's list, sync. The remaining
  window (between `exch` and the default: milliseconds) is healed by setup.sh's `kernel_match` at
  the start-up run (a running kernel without modules in / → the newest whole kernel that has them
  the default, said), reachable because every boot image loads xfs and vfat itself
  (/etc/dracut.conf.d/fedokawaii.conf force_drivers, dracut.conf(5)) and so mounts /boot.
- a leftover `root.new` WITH the mark is a copy never exchanged in (removed); WITHOUT it, the system
  that ran before a restore cut after its exchange: that restore is finished (its default, the
  moves, the names), never deleted, and nothing else is done in that run. The system that ran is
  never left under the copy's name (root.old, else root.old.d/TIME-PID).
- one restore at a time (flock on /run/kawa-snap.lock; a dnf run's `pre` waits for it, ten minutes at
  most), none while a package transaction runs.
- while /home is inside root (before the split, §3): refused unless `--with-home` — Super+U says his
  home goes back too and passes it on his "yes".
- from a snapshot started from the boot menu (/ an overlay: systemd.volatile=overlay) the disk and
  the snapshot are read from the kernel's arguments (root=UUID=, rootflags=subvol=): restore works
  there too. The start-up kernel rules (setup.sh --kernels) never run in such a start (its FSROOT is
  not /root, or the overlay; the unit has ConditionKernelCommandLine=!systemd.volatile).
- deletions `--commit-after`; no `btrfs subvolume sync` (it only waits for the space to come back —
  the space floor's business, not the restore's safety).

## 4. The flow of the button (a state machine; its phase in `fk`, every step idempotent — B2 #9)

This machine (checked 1 Nov 2026): no LUKS, no Flatpak (`rpm -q flatpak`: none), Secure Boot off
(`mokutil --sb-state`; the ISO may turn it on — §5 row 44), the dGPU (RX 9060 XT) at PCI 03:00.0, the
iGPU at 15:00.0, one kernel at rest (setup.sh `old_kernels_out`, fedokawaii-kernels.timer).

Phase 0 — **may it start?** One run at a time (its own flock; dnf5/PackageKit/dnf5daemon not
holding rpm's lock — B3 #4); the games VM not holding the dGPU (the fixer needs it); space: Btrfs unallocated ≥ 5 GiB and free ≥ 15 GiB read
from `btrfs filesystem usage`, not df (B1 #10, B3 #14), /boot ≥ 300 MB and the ESP ≥ 50 MB free
(B3 #5); a run left mid-flight is finished first (phase 5's recovery); verify now — its failures
become the **baseline** (an update is judged by what it makes newly red, never by what was red
before it).

Phase 1 — **the toolkit first**: this repository's newest commit at its signed release tag from
GitHub (r24-41b), re-exec from it; an unreachable GitHub: go on with the installed toolkit, said.

Phase 2 — **refresh and download**: `dnf5 upgrade --refresh --downloadonly` (third-party
repositories lenient: one failing is left out, said — B3 #15); the package set recorded (name,
old → new, the repository); upstream tools at their pins (lib/upstream.sh), nvim plugins at the
lock (lazy-lock.json), Flatpaks none; firmware listed only (`fwupdmgr get-updates`, never applied —
B1 #15). Nothing to do → "up to date", the run ends.

Phase 3 — **the candidate** (§2.1): built, checked. Green → phase 4. Red → **bisect** (§4.1).
Known-bad versions listed in the toolkit (a machine-readable known-issues file the toolkit ships:
B4 #16) are held before the candidate is built.

Phase 4 — **snapshot**: "before update DATE", important, pinned in `fk` (not cleaned up until the
next update has passed its probation, §4.3), checked to exist (B3 #12: never trust a hook's
silence; the dnf hook gets `raise_error=1` so a stray dnf run without a snapshot stops too — B5
#14); (no rpm checkpoint: §3.1) the in-flight marker written to `fk`: the snapshot's
number, the package set. Every stored package verified (`rpmkeys --checksig` against the system's
keys) before any replay: `dnf5 replay` skips OpenPGP checks for stored packages (seen in the VM,
ledger r27-49-exp1).

Phase 5 — **the transaction** on the running system: `dnf5 -C replay $fk/tx` — the stored
transaction the candidate proved (replay's own guarantee: the same operations, or an error); the guard's follow-ups (dwl relinked, helpers, theme); a power cut here leaves the marker:
at the next start, `fedokawaii-resume.service` (before greetd) sees it and reads the facts (B5 #15:
libdnf5 never looks for unfinished history): leftover `/var/lib/rpm-state/kernel/installing_core_*`,
stray `name;<hex>` files, `dnf5 check --dependencies --duplicates`, `rpm -V` of the set, the set
installed or not — clean and complete → the run finishes (follow-ups, then the session-free
checks: a verify subset that needs no session; the rest at login); anything else → the pinned
snapshot is restored (§3.1, only once /home is split — before that, the rescue screen offers it)
and the machine restarts once into it; the marker records "restored once", so a second start
never restores again; either way a notice at login says what happened.

Phase 6 — **the real checks**: verify (no new red against the baseline); the configs we own
against the new versions (each program's own check: `foot --check-config`, waybar/mako/yazi/greetd
parse, gtklock + kawa-lockmod load in a headless cage, nvim's plugins from the lock and a
`:checkhealth` subset); the desktop smoke test (§4.2); the boot
pieces (the new kernel's vmlinuz and initramfs present and sane, its BLS entry with root= and
rootflags, grub.cfg's snapshot submenu present — B3 #5–7, B4 #13).

Phase 7 — **keep or undo**: green → kept; a restart recommended only when the kernel, systemd,
glibc, Mesa or the session's libraries changed (dnf5 needs-restarting — B1), then the next start
is on probation (§4.3). A pin is released only by a closed probation (a good start after it),
never by a later green run — several may be open at once. The pin itself is snapper's: `snapper
modify -c '' N` (no cleanup algorithm: snapper never removes it), released with `-c number`;
snapper's timeline off, its number cleanup the only one (no cleanup code of ours). The kernels:
the previous one is removed (setup.sh `old_kernels_out`, fedokawaii-kernels.timer) only after
`fedokawaii-boot-good` has marked the new one good — the update's own "one kernel" step moves
here and never runs while a probation is open. Red → the pinned snapshot
restored at the next start (§2.4), the held package(s) found in candidates (§4.1) so the next
press does not repeat it.

Phase 8 — **the report**: a notice (one line: "updated · 142 packages · restart when you like" /
"held 1 · mesa 26.1 — the desktop did not start with it · the rest updated"), the Super+U pane
(what changed, what was held and why, what the fixer did, the snapshot to go back to), the log in
`fk`. A run that stopped says where and what is left (never silent — B4 #14).

### 4.1 Bisection and holds (B2 #4, #12)

A red candidate: the set S split in halves (dnf5 resolves each half's dependencies within S),
each half tried in a fresh candidate; ddmin to a smallest failing subset, bounded by ⌈log2 |S|⌉
rounds (≈ 8 for 200 packages, each a few minutes). The culprit(s) **held**: `dnf5 versionlock add`
at the installed version, the hold recorded in `fk` (the check that failed, the version refused,
the date); the rest applied with `best=False` (packages that need a held version wait with it,
listed). Each later press retries the held ones in a candidate first (newer versions only), and
releases the lock when they pass; a held package with a security advisory (`dnf5 advisory list`)
is said plainly in the report. No background retries (his decision: the button only).
*As built (1 Nov, the master's 18):* a red only on the running system (the copy was green) cannot
be split in halves — the running system is no copy to try halves in — so the whole set is held
together and said so: "held: all N packages together (which one broke it could not be told apart;
newer versions are tried)". Holds are named by family (lib/common.sh hold_families: one version,
one reason, names that begin alike — kernel, kernel-core … as "kernel"), two at most in the
report's line and its notice, then "and N more"; the Super+U held pane names three, then "and N
more"; the held row counts families.

### 4.2 The desktop smoke test

Headless dwl on the real GPU (gles2, the dGPU's render node by path,
`/dev/dri/by-path/pci-0000:03:00.0-render`, never renderD128: node numbers change) as him, a runtime folder of its own, a throw-away
home with copies of the installed configs (tools/kit.sh's machinery), the session's autostart:
pass when within 20 s dwl has committed frames, waybar, mako, kawa-panel and the warm windows are
running, a shot of the bar is not blank and matches the bar's geometry check
(tools/regress/bar-geometry), and nothing crashed (coredumps for our programs: none new). A
container cannot do this (B4 #18: the headless compositor smoke test in verify).

### 4.3 Probation of the next start (B1 #7, B2 #5, #7)

A start after a kernel/systemd/glibc/Mesa change is on probation: Fedora's grub boot counting
(B5 #9: 08_fallback_counting runs before 10_reset_boot_success, decrements `boot_counter` while
`boot_success` is 0, and at 0 sets `default=1` — the second menu position, which must be the
previous kernel (checked in grub.cfg) — then sticks at -1 until userspace unsets it; armed with
`boot_counter=3 boot_success=0`, with `rd.shell=0 rd.emergency=reboot` and `kernel.panic` set while
armed so a hang becomes a counted failure — a userspace hang counts only when a reboot happens, so
systemd's RuntimeWatchdogSec (the board's watchdog, sp5100_tco on this AMD chipset: checked in T48)
is armed only while the probation is open; the off-by-one proven in the VM). *As built (1 Nov,
T45 (f)):* the proof of a good start stays the one the desktop already uses — Fedora's own
grub-boot-success timer, started by autostart.sh, writes `boot_success=1` two minutes into the
desktop (the same proof that lets the kernel before go: setup.sh old_kernels_out). Our
`fedokawaii-boot-good.path` watches grubenv and runs `setup.sh --boot-good` the moment it changes
(the service is skipped while no probation is open; it waits for the setup lock, so a mark during
an update run is never missed): on the new kernel → `boot_counter` unset, the trial arguments
(`rd.shell=0 rd.emergency=reboot panic=10`, on its entry only) and the watchdog drop-in removed,
every pinned snapshot back to snapper's number cleanup; on the one before with `boot_counter=-1`
(GRUB ran out) → the new kernel held at its version (versionlock, recorded in `fk`), removed, the
running one the default, a notice at login; the one before chosen by hand → the trial waits.
Armed after every green update (UPD/probation: SNAPSHOT KERNEL|- DAY a line; a kernel only when
it brought one): `boot_counter=3 boot_success=0 boot_indeterminate=1` (the menu stays hidden on
the first try; three tries, then entry 1). A second system-level marker was weighed and dropped:
marking at the login screen would let a kernel that breaks only the desktop lose the one before. The previous kernel is never removed while a probation is open; the
pinned snapshot stays until it closes. A start that never reaches userspace twice → the previous
kernel; a userspace that cannot start the session → the rescue screen (start-dwl) says so and
offers "go back to the system before the update" (kawa-snap restore) — the boot menu's snapshot
entries stay the last resort (read-only boots are fragile on Fedora: B1 #3, B2 #11, B3 #10).

### 4.4 Release upgrades (T46)

The same button, when the next Fedora has settled (a 7-day floor after its release day — B3 #18;
setup.sh's WAIT of 60 goes), RPM Fusion and our COPRs have it,
the VM pre-flight (T05's harness: install at the target release, setup, theme, verify, smoke) is
green, and a candidate `--releasever=N distro-sync` built from the running root is green. Then
Fedora's documented path on the real machine (`dnf5 system-upgrade download --releasever=N`,
reboot, the offline transaction — the pinned snapshot taken before `offline reboot`), judged by
facts after it (`dnf5 offline status` and `log`, os-release, rpm's set, verify, smoke — B1 #6, B3 #1,
#3, B5 #16: on failure dnf5's cleanup unit reboots into a half-updated normal system, so the first
start after an offline run restores the pinned snapshot by itself unless all is complete); red →
the pinned snapshot restored, "Fedora N waits" with the failing checks. Fedora 45 (3 Nov 2026,
B1 #13: systemd 262, dracut 111, grub2 81, rpm 6.1 with signatures enforced) is the first.

### 4.5 The AI fixer (T47; B6)

Only for what bisection held: llama.cpp's `llama-server` (Vulkan, a pinned tag, the dGPU chosen
explicitly), one model chosen by measurement on this card (gpt-oss-20b, Qwen3.x-27B at 3 bits,
Devstral Small 2: B6 #4–6), loaded only during the run. Its input: the failing check and its
output, the package's changelog and the new man page / `--help`, our config file, the allowed
actions; its output: JSON (verdict fix | cannot_fix) with SEARCH/REPLACE edits on one of our
config files; any key not in the new docs is rejected mechanically (B6 #11). It edits a candidate
with the held package in; the failing check must turn green and the full candidate checks pass;
two attempts at most; then the fix is applied to the running system with the package (phase 5–6)
as a `*.local` override (never the theme-owned file, which the next theme run rewrites), recorded
in `fk` for the next toolkit update to reconcile. Everything else ends "held +
told". If it cannot beat "hold and wait" on the graded breakage set (T47), the class is held-only.

## 5. Failure modes → answer → the T49 test that proves it (tools/vm-inject/)

| # | failure | answer | test |
|---|---|---|---|
| 1 | power cut while downloading | nothing changed; the next press goes on from dnf's cache | power-cut.sh @download |
| 2 | power cut while the candidate is built or checked | the running root untouched; the leftover `root.cand` removed by the next run's phase 0 | power-cut.sh @candidate |
| 3 | power cut in the live transaction | the in-flight marker → `fedokawaii-resume` before greetd: rpm's set complete and verify green → finished; else the pinned snapshot restored + one restart; a notice at login either way | power-cut.sh @transaction |
| 4 | power cut in the follow-ups (relink, theme) | marker at phase "post" → the follow-ups run again (idempotent), then the checks | power-cut.sh @post |
| 5 | the network drops | two retries, then stop: "nothing changed — try again later" | network-kill.sh |
| 6 | a bad or unsigned package (F45 enforces signatures — B1) | dnf refuses before the candidate; the repository named | broken-pkg.sh --unsigned |
| 7 | the disk too full before | phase 0 refuses, says how much is needed and offers snapshot cleanup | disk-full.sh |
| 8 | Btrfs metadata full (no unallocated space — B3 #14) | phase 0 reads `btrfs filesystem usage`; refuses with the balance it will run | disk-full.sh --metadata |
| 9 | /boot or the ESP full (B3 #5) | phase 0 checks; a kernel is pruned only outside a probation | boot-full.sh |
| 10 | rpm's database damaged before the run | phase 0: `rpm -qa` and `rpm --verify -a` (B5); `rpmdb --rebuilddb` in the candidate first, the live one only after a green candidate | rpmdb-damage.sh |
| 11 | a scriptlet fails | the candidate is red → bisect → held; the running system never saw it | broken-pkg.sh --scriptlet |
| 12 | a library our builds load changes its soname (wlroots deps, libdisplay-info — B3 #17) | the candidate rebuilds dwl and the helpers against it; still red → held | broken-lib.sh |
| 13 | an option of a config we own renamed or dropped | the candidate's config check red → bisect → held → the fixer (T47) | fixer-bench.sh |
| 14 | Mesa breaks the desktop | the candidate's smoke test runs with the real render node bound into the container (Mesa from the candidate, the running kernel) → red → held | broken-mesa.sh (a stub libEGL that aborts) |
| 15 | a new kernel or initramfs does not start (B3 #6, #16) | probation: two failed starts → the previous kernel (grub boot counting); the kernel held; said at login | broken-boot.sh --initramfs |
| 16 | a boot argument breaks the start | as 15 | broken-boot.sh --arg |
| 17 | the session does not start on the real machine though the candidate passed | the live smoke test red → the pinned snapshot restored at the next start; the rescue screen offers it too | broken-session.sh |
| 18 | SELinux: an older root under a newer policy | no blanket relabel (it relabels every writable Btrfs mount, snapshots too, permissive, for a long time — B5 #11): the restored root is label-consistent (labels and policy travel together); `restorecon -R -n -v` on /home, /var/log and /boot, relabelling only the differences | selinux-relabel.sh |
| 19 | a third-party repository lags or 404s (RPM Fusion has no 45 yet — B3 #15) | left out of this run, its packages wait, said | thirdparty-lag.sh |
| 20 | a third-party package conflicts with Fedora's (freeworld Mesa) | candidate red → bisect → held | broken-pkg.sh --conflict |
| 21 | the fixer makes it worse | it only edits a candidate; the checks decide; two attempts; then held + told | fixer-worse.sh |
| 22 | the fixer hangs or the GPU resets (B6 #14) | a wall-clock budget; the unit killed; held + told | fixer-hang.sh |
| 23 | the restored system is worse | `kawa-snap restore old` swaps back (rollback of a rollback) | rollback-of-rollback.sh |
| 24 | a restore takes his files back | /home is its own subvolume, never in a snapshot of root (§3) | home-survives.sh |
| 25 | a restore erases the updater's memory | holds and history in `fk`; phase 0 writes the holds back into dnf's versionlock file | holds-survive.sh |
| 26 | another package manager holds rpm's lock | phase 0 waits 60 s, then says who holds it | lock-held.sh |
| 27 | stale offline or system-upgrade state (B3 #4) | phase 0 cleans it when no upgrade is pending | stale-offline.sh |
| 28 | the toolkit from GitHub is bad | only a release tag; the new toolkit's own selftest before the re-exec; red → the installed one | toolkit-bad.sh |
| 29 | the window is closed or Ctrl+C mid-run | the run is a systemd unit; the window only shows it; reopening shows the progress | close-window.sh |
| 30 | the power button pressed mid-transaction | rpm's inhibitor and the run's own block shutdown; logind shows why | inhibit.sh |
| 31 | the boot menu's snapshot list or a BLS entry broken by a kernel install (B3 #7, B4 #13) | phase 6 checks root=/rootflags and the submenu; grubby and kawa-snap boot mend them | bls-broken.sh |
| 32 | a release upgrade returns to the old release silently (B3 #1) | judged by os-release and rpm's set after it, never dnf's status; red → restore + "Fedora N waits" | upgrade-fail.sh |
| 33 | the release nears its end and the upgrade stays red | notices 90, 30, 7 days before SUPPORT_END, with the failing checks; the PC stays on the working release | eol.sh |
| 34 | a held package gets a security advisory | said plainly in every report and once as a notice | advisory.sh |
| 35 | updates waited two weeks or more | one quiet notice (no background updates: his decision) | remind.sh |
| 36 | the clock is wrong (TLS fails) | phase 0 checks time sync | clock.sh |
| 37 | a snapshot cannot be taken | the run stops before any change (B3 #12) | snapper-broken.sh |
| 38 | snapshots fill the disk over months | cleanup by count (no qgroups — B3 #11), a space floor checked before each snapshot, the pinned ones kept | space.sh |
| 39 | a duplicate or mixed set after a cut | phase 6: `dnf5 repoquery --duplicates`, `dnf5 check`, `rpm -V` of the set | power-cut.sh (all points) |
| 40 | verify itself broken by the update | verify runs from the toolkit; a verify that cannot run is red, never green | verify-broken.sh |
| 41 | power cut during a restore (between any two of its steps) | one atomic exchange, a sync before /boot, the default set last (§3.1): every cut leaves a root that boots with its kernels | restore-cut.sh (each step) |
| 42 | a stored package tampered with between download and replay | `rpmkeys --checksig` of every stored package before any replay (replay skips OpenPGP checks) | broken-pkg.sh --tampered |
| 43 | the split of /home is cut off half-way | offline, copy then compare then mount; the old /home untouched until a good boot; the pinned snapshot | split-cut.sh |
| 44 | the bootloader (grub2-efi, shim) updated badly — it fails before boot counting can act, and it never rolls back (B5 #10, synthesis 17) | two stored transactions — tx1 with `--exclude=grub2-efi*,shim*`, tx2 those packages alone — both
replayed in the candidate; live, tx2 only after tx1 is green (one stored transaction cannot be
replayed in parts); the previous EFI files kept (`EFI/fedora/*.prev`); /boot and /boot/efi excluded from rpm -V verdicts after a restore; older grub2-efi or shim never reinstalled onto the ESP. Secure Boot is off on this PC; the ISO, if it turns it on, adds the SBAT/dbx checks before such a step | broken-bootloader.sh |

## 6. Attacks (the skeptic's pass)

1. *The candidate passes, the live run differs.* — One stored transaction, resolved once on the
   live root, replayed in both; replay itself errors on any difference in the installed set
   (dnf5-replay(8)). Seen in the VM: the same 1,973 packages.
2. *A chroot is not the system: scriptlets act differently.* — True for service restarts and
   triggers that talk to systemd; those are exactly what the live checks (phase 6) and probation
   catch. The candidate catches what breaks files, links, configs and Mesa.
3. *kernel-install in the candidate writes into an empty /boot, or dracut fails without /proc, a
   false red.* — The candidate runs in a container (its own /proc, /sys, /dev, /run) with a scratch
   /boot holding the loader skeleton; in the bare-chroot trial (r27-49-exp1) the kernel landed in
   the scratch /boot and dracut fell back to a generic image — the container makes it the host-only
   one; proven in the VM before T45 (c) ships.
4. *Under --installroot, dnf5 runs the host's plugins: the candidate would snapshot the live root
   and arm the guard's follow-ups on the live system.* — Every candidate run with
   `--disable-plugin=actions` (installroot(7): plugin paths are the host's), inside its container.
5. *A stored package is swapped between download and replay; replay skips OpenPGP checks.* —
   `rpmkeys --checksig` of every stored package against the system's keys before any replay
   (row 42).
6. *The candidate has no /home after the split, so the config checks and the fixer find nothing.*
   — A writable snapshot of `home` is bound in; an accepted fix lands in the `*.local` override
   (T42/T45), never in a theme-owned file the next theme run would rewrite.
7. *Copy-on-write candidates eat the disk.* — Only what the transaction writes (1–3 GB typical),
   counted in phase 0's floor; the candidate deleted at the end of the run.
8. *Bisection assumes one culprit.* — ddmin finds a smallest failing subset; two interacting
   packages are held together; past ⌈log2 |S|⌉ rounds the whole set is held and said.
9. *A held library holds its dependents and their security fixes.* — Said package by package in
   the report; advisories on held ones said plainly; retried each press; the fixer tried.
10. *A restore to an older root forgets the locks (they live in /etc).* — The holds are `fk`'s;
   phase 0 writes them into /etc/dnf/versionlock.toml every run.
11. *snapper's cleanup deletes the pinned snapshot.* — A pinned snapshot has no cleanup algorithm
   (`snapper modify -c ''`): snapper's own cleanup never removes it; the timeline is turned off
   (its timer is enabled on the PC today).
12. *dnf5 says failure on success, success on failure (B3 #3).* — Facts decide: rpm's set, verify,
   smoke, os-release.
13. *Boot counting falls back forever if our boot-good unit breaks.* — The fallback is the
    previous kernel, which still works; verify checks the unit is enabled and ran on this boot;
    T49 breaks it on purpose.
14. *The /home migration loses data.* — Copy, compare, switch, keep the old copy until a good
    boot, a pinned snapshot before; rehearsed in the VM with a home of real size and nested
    subvolumes.
15. *A restore swaps root under his running session.* — Only at the next start; until then the
    session runs on; the notice says why he should restart.
16. *Changes he made in /etc after the snapshot are lost by a restore.* — He never edits /etc; the
    theme's are re-applied after a restore; /home and /var/log are not in root.
17. *The fixer can be steered by text in a changelog or a log (prompt injection).* — It has no
    tools: its answer is a JSON proposal of edits to our own config files, applied by our code
    after the key check; the checks it must pass are outside its reach (B6 #13).
18. *The fixer invents an option.* — Any key not in the new version's man page/`--help`/default
    config is rejected before it is tried (B6 #11).
19. *The model file is huge and may be corrupt.* — Checksum-pinned; missing or wrong → the fixer
    is skipped, said; never downloaded during a run that needs it urgently.
20. *GitHub serves a broken or hostile toolkit.* — Release tags only, signed; the public key ships
    in the toolkit and the PC verifies the tag's signature (`git verify-tag`) before the re-exec,
    then the new toolkit's selftest; anything red → the installed toolkit, said.
21. *He presses update twice, or closes the window.* — One run (flock); the window is a view of
    the unit.
22. *It takes long.* — Progress in the window and the pane; he can keep working; the GPU work
    (smoke, fixer) is short and measured (T60).
23. *The smoke test disturbs his session.* — Its own runtime folder and outputs, headless; it
    never touches his Wayland display; its VRAM freed at exit (measured).
24. *Third-party repositories make every release day red.* — Lenient for routine updates;
    for releases, waiting until they have it (as today) is the documented gate.
25. *A release upgrade in a candidate is not what system-upgrade does offline.* — The candidate is
    an extra gate; the VM pre-flight is the main one; the real one is judged by facts after.
26. *The games VM is running from home/dia/VM.* — Phase 0 refuses while it runs (the fixer needs
    the dGPU; a restore must not move a running disk).
27. *installonly_limit=2 removes the kernel probation would fall back to.* — No kernel transaction
    runs while a probation is open (the kernel is held for that run, said in the report); the
    previous kernel is removed only after the new one is marked good; one kernel at rest otherwise.
28. *A partial set slips past verify.* — Phase 6: duplicates, `dnf5 check`, `rpm -V` of the set.
29. *verify is red before the update (qBittorrent today).* — The baseline: only new reds count.
30. *A restore needs a restart — "never leave him on a broken desktop" is broken.* — The broken
    state exists only after a live red, which the candidate makes rare; the restart is offered at
    once with the reason; the rescue screen offers the same at the next start if he ignores it.
31. *Read-only snapshot boots hang on Fedora (B2 #11, B3 #10).* — They are not part of the flow;
    the boot menu keeps them as the last resort only, and the rescue screen's restore needs none.
32. *The updater's own code has a bug that breaks every run.* — Its state machine is tested on
    stubs (test_update_flow.sh: every branch) and every injection in the VM (T49) before it ships;
    a run that dies says where it stopped, and the next one starts from phase 0.
33. *An update changes the updater's dependencies (python, jq, btrfs-progs) mid-run.* — The run is
    bash + coreutils + dnf5 + btrfs-progs; the toolkit checks they load before the live phase;
    the run re-execs nothing after the transaction except verify (which fails red if it cannot run).
34. *Firmware.* — Listed, never applied by the button (B1 #15); a separate explicit step later.
35. *Snapshots are not backups.* — Said in the menu and the Learn piece: undo on this disk vs a
    copy on another drive (T48).

No case is left open on paper: B5 is folded in (§3, §3.1, phase 4–5, §4.3, §4.4, rows 18, 41–44).
What remains is proof: each row's test in the VM (T49), the candidate container first (T45 c).
