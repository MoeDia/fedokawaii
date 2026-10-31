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

1. **The candidate.** A writable snapshot of the running root (`root.cand`, top level) receives the
   transaction: `dnf5 --installroot=<cand> --use-host-config upgrade` from the downloaded cache
   (scriptlets run chrooted; systemd's skip themselves in a chroot; a new kernel lands in the
   candidate's own empty /boot, never the real one). The candidate is checked where it lies: every
   binary of ours links (`ldd` inside it), each config we own parses with its program's own check
   run inside it (`systemd-nspawn --ephemeral -D cand --private-network`, read-only, no session),
   dwl and the C helpers rebuilt against it start headless (pixman) inside it, the greeter's and
   the panel's GTK load, rpm's database is whole (`rpm --root cand -Va` on our files), the BLS entry
   the new kernel would get has root= and rootflags (B3 #7), its initramfs would hold amdgpu, btrfs
   and the splash (B3 #6).
2. **Bisection and the fixer work on candidates**, never on the running system: a red candidate is
   thrown away; halves of the package set are tried in fresh candidates (cheap: a snapshot is
   copy-on-write; no reboot); the AI fixer edits a candidate (B6 #12–13).
3. **Then the running system** takes exactly the transaction the green candidate proved (the same
   package set, the same cache, `-C`), in place, online, under rpm's inhibitor (B1 rpm-plugin-
   systemd-inhibit), with the "before" snapshot pinned and an in-flight marker; then the full
   verify and the desktop smoke test (the real GPU, the real session's programs, headless) — the
   checks a container cannot make.
4. **Red after that** (rare: what only the real machine shows) → the pinned snapshot is restored
   (kawa-snap restore: the writable copy swapped in at the next start, kernels matched) and the
   report says "restart to get the system before the update back"; the hold and the retry follow.

Why online and not offline for the routine update (B2 #8 argues offline): the candidate removes
the reason (an untried transaction under a running desktop), and an offline update costs him two
restarts and a password each time; the transaction itself is short and inhibited; a cut-off one is
caught at the next start (§4, phase 5). Release upgrades stay offline (Fedora's documented path,
§4.4), after a green VM pre-flight and a green candidate.

## 3. The disk layout this needs (T48 builds it; migrated on the PC once, the ISO makes it so)

| top-level subvolume | mounted at | rolled back with the system? | why |
|---|---|---|---|
| `root` | / | yes | the system: packages, /etc, the rpm database (/usr/lib/sysimage/rpm: rolls back with the packages — B1 Changes/RelocateRPMToUsr) |
| `home` (new) | /home | **never** | his files, configs and repositories: a restore must not take them back in time (B1 #9 — today /home is inside `root`) |
| `log` (new) | /var/log | never | the journal and dnf's logs of the run that failed survive the restore that undoes it |
| `fk` (new) | /var/lib/fedokawaii-update | never | the updater's own memory — phase, holds, history, reports, the fixer's attempts (B4 #8: a rollback must not erase the updater's memory) |
| `root/.snapshots` | /.snapshots | — | kept nested as today (kawa-snap restore moves nested subvolumes across, tested) |
| `root/home/dia/Downloads`, `…/VM`, `var/lib/machines`, `var/lib/portables` | — | no (nested subvolumes are never in a snapshot) | as today; Downloads and VM move into `home` with the migration |

Migration (one boot-time unit before greetd, `fedokawaii-split.service`, after a pinned snapshot):
a reflink copy of /home's files (nested subvolumes excluded, then moved across by rename — Btrfs
renames a subvolume between parents, as kawa-snap restore does), SELinux contexts kept (`cp -a
--reflink=always` keeps xattrs), compared (file count, sizes, a checksum sample), the fstab line
added, mounted; the shadowed copy inside `root` removed only after a good boot. The same for
/var/log. The ISO (T56) creates the layout from the start. (B5 refines the procedure.)

## 4. The flow of the button (a state machine; its phase in `fk`, every step idempotent — B2 #9)

Phase 0 — **may it start?** One run at a time (its own flock; dnf5/PackageKit/dnf5daemon not
holding rpm's lock — B3 #4); not on battery below 50 % (a desktop: always on AC); the games VM not
holding the dGPU (the fixer needs it); space: Btrfs unallocated ≥ 5 GiB and free ≥ 15 GiB read
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
silence); the in-flight marker written to `fk`: the snapshot's number, the package set.

Phase 5 — **the transaction** on the running system: `dnf5 -C upgrade` of exactly the candidate's
set; the guard's follow-ups (dwl relinked, helpers, theme); a power cut here leaves the marker:
at the next start, `fedokawaii-resume.service` (before greetd) sees it — if rpm's database shows the
set complete and verify passes, the run finishes; else the pinned snapshot is restored (kawa-snap
restore) and the machine restarts once into it; either way a notice at login says what happened.

Phase 6 — **the real checks**: verify (no new red against the baseline); the configs we own
against the new versions (each program's own check: `foot --check-config`, waybar/mako/yazi/greetd
parse, gtklock + kawa-lockmod load in a headless cage); the desktop smoke test (§4.2); the boot
pieces (the new kernel's vmlinuz and initramfs present and sane, its BLS entry with root= and
rootflags, grub.cfg's snapshot submenu present — B3 #5–7, B4 #13).

Phase 7 — **keep or undo**: green → kept; the previous run's pin released; a restart recommended
only when the kernel, systemd, glibc, Mesa or the session's libraries changed (dnf5
needs-restarting — B1), then the next start is on probation (§4.3). Red → the pinned snapshot
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

### 4.2 The desktop smoke test

Headless dwl on the real GPU (gles2, renderD128) as him, a runtime folder of its own, a throw-away
home with copies of the installed configs (tools/kit.sh's machinery), the session's autostart:
pass when within 20 s dwl has committed frames, waybar, mako, kawa-panel and the warm windows are
running, a shot of the bar is not blank and matches the bar's geometry check
(tools/regress/bar-geometry), and nothing crashed (coredumps for our programs: none new). A
container cannot do this (B4 #18: the headless compositor smoke test in verify).

### 4.3 Probation of the next start (B1 #7, B2 #5, #7)

A start after a kernel/systemd/glibc/Mesa change is on probation: Fedora's grub boot counting
(`boot_counter`, 08_fallback_counting: two failed starts → the entry before, i.e. the previous
kernel) plus our own system-level `fedokawaii-boot-good.service` that sets `boot_success` only
once the session has run dwl for 60 s with its helpers (today only a user-session timer does it,
two minutes into a login). The previous kernel is never removed while a probation is open; the
pinned snapshot stays until it closes. A start that never reaches userspace twice → the previous
kernel; a userspace that cannot start the session → the rescue screen (start-dwl) says so and
offers "go back to the system before the update" (kawa-snap restore) — the boot menu's snapshot
entries stay the last resort (read-only boots are fragile on Fedora: B1 #3, B2 #11, B3 #10).

### 4.4 Release upgrades (T46)

The same button, when the next Fedora has settled (WAIT days), RPM Fusion and our COPRs have it,
the VM pre-flight (T05's harness: install at the target release, setup, theme, verify, smoke) is
green, and a candidate `--releasever=N distro-sync` built from the running root is green. Then
Fedora's documented path on the real machine (`dnf5 system-upgrade download --releasever=N`,
reboot, the offline transaction), judged by facts after it (os-release, rpm's set, verify, smoke —
B1 #6, B3 #1, #3: dnf5's exit status and silent returns to the old release are not trusted); red →
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
and recorded as a local override the next toolkit update reconciles. Everything else ends "held +
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
| 10 | rpm's database damaged before the run | phase 0: `rpm -qa` + `rpm --verifydb`; rebuilt in the candidate first, the live one only after a green candidate | rpmdb-damage.sh |
| 11 | a scriptlet fails | the candidate is red → bisect → held; the running system never saw it | broken-pkg.sh --scriptlet |
| 12 | a library our builds load changes its soname (wlroots deps, libdisplay-info — B3 #17) | the candidate rebuilds dwl and the helpers against it; still red → held | broken-lib.sh |
| 13 | an option of a config we own renamed or dropped | the candidate's config check red → bisect → held → the fixer (T47) | fixer-bench.sh |
| 14 | Mesa breaks the desktop | the candidate's smoke test runs with the real render node bound into the container (Mesa from the candidate, the running kernel) → red → held | broken-mesa.sh (a Mesa build that fails on gles2) |
| 15 | a new kernel or initramfs does not start (B3 #6, #16) | probation: two failed starts → the previous kernel (grub boot counting); the kernel held; said at login | broken-boot.sh --initramfs |
| 16 | a boot argument breaks the start | as 15 | broken-boot.sh --arg |
| 17 | the session does not start on the real machine though the candidate passed | the live smoke test red → the pinned snapshot restored at the next start; the rescue screen offers it too | broken-session.sh |
| 18 | SELinux: an older root under a newer policy | kawa-snap restore writes `/.autorelabel` when the policy versions differ (B5); the relabel's progress on the splash (B3 #19) | selinux-relabel.sh |
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

## 6. Attacks (the skeptic's pass)

1. *The candidate passes, the live run differs.* — The candidate's transaction is stored (`--store`)
   and the live run replays it from the same cache (`dnf5 replay`, -C): the same NEVRAs, no new
   metadata in between. Proven by test 3/17 comparing `rpm -qa` of candidate and live.
2. *A chroot is not the system: scriptlets act differently.* — True for service restarts and
   triggers that talk to systemd; those are exactly what the live checks (phase 6) and probation
   catch. The candidate catches what breaks files, links, configs and Mesa.
3. *kernel-install in the candidate writes into an empty /boot and fails, a false red.* — The
   candidate gets a scratch /boot (a tmpfs with the loader skeleton bound at cand/boot); its
   entries are inspected there (root=, initramfs content), then thrown away. Must be proven in the
   VM first (T49 test 15).
4. *Copy-on-write candidates eat the disk.* — Only what the transaction writes (1–3 GB typical),
   counted in phase 0's floor; the candidate deleted at the end of the run.
5. *Bisection assumes one culprit.* — ddmin finds a smallest failing subset; two interacting
   packages are held together; past ⌈log2 |S|⌉ rounds the whole set is held and said.
6. *A held library holds its dependents and their security fixes.* — Said package by package in
   the report; advisories on held ones said plainly; retried each press; the fixer tried.
7. *A restore to an older root forgets the locks (they live in /etc).* — The holds are `fk`'s;
   phase 0 writes them into /etc/dnf/versionlock.toml every run.
8. *snapper's cleanup deletes the pinned snapshot.* — snapper's timeline is off; cleanup is ours
   (by number), and it skips every number pinned in `fk`.
9. *dnf5 says failure on success, success on failure (B3 #3).* — Facts decide: rpm's set, verify,
   smoke, os-release.
10. *Boot counting falls back forever if our boot-good unit breaks.* — The fallback is the
    previous kernel, which still works; verify checks the unit is enabled and ran on this boot;
    T49 breaks it on purpose.
11. *The /home migration loses data.* — Copy, compare, switch, keep the old copy until a good
    boot, a pinned snapshot before; rehearsed in the VM with a home of real size and nested
    subvolumes.
12. *A restore swaps root under his running session.* — Only at the next start; until then the
    session runs on; the notice says why he should restart.
13. *Changes he made in /etc after the snapshot are lost by a restore.* — He never edits /etc; the
    theme's are re-applied after a restore; /home and /var/log are not in root.
14. *The fixer can be steered by text in a changelog or a log (prompt injection).* — It has no
    tools: its answer is a JSON proposal of edits to our own config files, applied by our code
    after the key check; the checks it must pass are outside its reach (B6 #13).
15. *The fixer invents an option.* — Any key not in the new version's man page/`--help`/default
    config is rejected before it is tried (B6 #11).
16. *The model file is huge and may be corrupt.* — Checksum-pinned; missing or wrong → the fixer
    is skipped, said; never downloaded during a run that needs it urgently.
17. *GitHub serves a broken or hostile toolkit.* — Release tags only, the new toolkit's selftest
    before re-exec; (T45 decides a signing key: tags signed, the PC verifies).
18. *He presses update twice, or closes the window.* — One run (flock); the window is a view of
    the unit.
19. *It takes long.* — Progress in the window and the pane; he can keep working; the GPU work
    (smoke, fixer) is short and measured (T60).
20. *The smoke test disturbs his session.* — Its own runtime folder and outputs, headless; it
    never touches his Wayland display; its VRAM freed at exit (measured).
21. *Third-party repositories make every release day red.* — Lenient for routine updates;
    for releases, waiting until they have it (as today) is the documented gate.
22. *A release upgrade in a candidate is not what system-upgrade does offline.* — The candidate is
    an extra gate; the VM pre-flight is the main one; the real one is judged by facts after.
23. *The games VM is running from home/dia/VM.* — Phase 0 refuses while it runs (the fixer needs
    the dGPU; a restore must not move a running disk).
24. *installonly_limit=2 removes the kernel probation would fall back to.* — No kernel transaction
    while a probation is open; the third kernel waits for the next press.
25. *A partial set slips past verify.* — Phase 6: duplicates, `dnf5 check`, `rpm -V` of the set.
26. *verify is red before the update (qBittorrent today).* — The baseline: only new reds count.
27. *A restore needs a restart — "never leave him on a broken desktop" is broken.* — The broken
    state exists only after a live red, which the candidate makes rare; the restart is offered at
    once with the reason; the rescue screen offers the same at the next start if he ignores it.
28. *Read-only snapshot boots hang on Fedora (B2 #11, B3 #10).* — They are not part of the flow;
    the boot menu keeps them as the last resort only, and the rescue screen's restore needs none.
29. *The updater's own code has a bug that breaks every run.* — Its state machine is tested on
    stubs (test_update_flow.sh: every branch) and every injection in the VM (T49) before it ships;
    a run that dies says where it stopped, and the next one starts from phase 0.
30. *An update changes the updater's dependencies (python, jq, btrfs-progs) mid-run.* — The run is
    bash + coreutils + dnf5 + btrfs-progs; the toolkit checks they load before the live phase;
    the run re-execs nothing after the transaction except verify (which fails red if it cannot run).
31. *Firmware.* — Listed, never applied by the button (B1 #15); a separate explicit step later.
32. *Snapshots are not backups.* — Said in the menu and the Learn piece: undo on this disk vs a
    copy on another drive (T48).

(Open after B5: the /home split's exact procedure and SELinux after restore; then T49 proves each row.)
