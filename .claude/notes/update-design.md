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

## 2. The disk layout this needs (prerequisite; built in T48, migrated on the PC once)

(to be written from B1 + B5)

## 3. The flow of the button

(to be written)

## 4. Failure modes → answer → the T49 test that proves it

(to be written)

## 5. Attacks (the skeptic's pass, ≥ 30)

(to be written)
