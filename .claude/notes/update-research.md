# Update research — T43 (round 27): sources for a bulletproof one-button updater

The design (T44, `.claude/notes/update-design.md`) cites this file line by line. Each source: its link,
what it is, and the one thing it taught us. Six batches, one subagent each, merged by the main agent;
the synthesis (failure modes seen in practice, ranked, each with its countermeasure) goes at the top
once the batches are in.

This PC (checked 1 Nov 2026): Fedora 44 (SUPPORT_END 2027-05-19), dnf5 5.4.6, snapper 0.13.0 (config
`root` on /), grub2 2.12-66 + grub-btrfs 4.14, btrfs-progs 7.1, systemd 259.10. Disk: / = Btrfs
subvolume `root` (zstd:1, noatime) — **/home is inside it** (no own subvolume; only
home/dia/Downloads and home/dia/VM are), /boot = XFS on its own partition (outside every snapshot),
/boot/efi = vfat.

## Synthesis — the failure modes seen in practice

(after the six batches)

## Batch 1 — official documentation (dnf5, rpm, snapper, grub-btrfs, btrfs, systemd, Fedora, fwupd, greenboot)

## Batch 2 — how others do it (openSUSE, Fedora Atomic/bootc, Universal Blue/Bazzite, NixOS, Arch, ABRoot, A/B systems)

## Batch 3 — bug trackers (dnf5, snapper, grub-btrfs, Fedora Bugzilla/blockers, known issues)

## Batch 4 — failure stories (Fedora Discussion, Reddit, forums): why automated updaters end up useless

## Batch 5 — rollback specifics (/boot outside the root, kernels vs modules, SELinux, quotas, space)

## Batch 6 — the local AI fixer: prior art, runtimes and models on RDNA4 (gfx1200), their failure modes
