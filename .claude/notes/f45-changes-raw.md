# Fedora 45 raw digest (facts only, no recommendations)

Written for the fedokawaii main agent so it can decide what to adopt. Every fact has its source next to it; nothing here is a decision or a recommendation. Scratch copies of the fetched pages and query outputs are in /tmp/f45raw (outside the repo; /tmp is cleared at reboot). The dnf5 user cache (~/.cache/libdnf5) now holds the F45 metadata, so further `dnf5 --releasever=45 ... repoquery` calls are fast until it expires (`fedora` after 7 days, `updates` after 6 hours).

- Date of research: 2026-11-01, finished 2026-11-01 14:22 UTC. This PC runs on UTC+04, so times printed by dnf5 are local (4 hours later than UTC).
- This PC: Fedora 44 (kernel 7.2.11-200.fc44 running), dnf5 5.4.6.0. Fedora 45 final target date is Tuesday 2026-11-03 (two days after this snapshot), so every F45 package version below is a snapshot of the repositories on 2026-11-01 and can still move.

Contents: 0 what was fetched and what not; 1 state of the release; 2 the 46 accepted changes grouped; 3 package versions F44 here versus F45; 4 Python 3.15 (including the removed and deprecated lists); 5 other facts (third-party repos, upgrade docs, kmscon, systemd, known issues, manifest check); 6 sources.

## 0. What was fetched, what could not be

Fetched (primary sources only):

- The Fedora 45 ChangeSet [Releases/45/ChangeSet](https://fedoraproject.org/wiki/Releases/45/ChangeSet) (permalink [oldid=787860](https://fedoraproject.org/w/index.php?title=Releases/45/ChangeSet&oldid=787860)), parsed from the saved HTML; cross-checked against [Category:ChangeAcceptedF45](https://fedoraproject.org/wiki/Category:ChangeAcceptedF45) (46 pages, same set) and against the raw wikitext (`action=raw`) of all 46 change pages, which the one-line summaries below were condensed from.
- Fedora schedules: [F45](https://fedorapeople.org/groups/schedule/f-45/f-45-key-tasks.html), [F44](https://fedorapeople.org/groups/schedule/f-44/f-44-key-tasks.html), [F46](https://fedorapeople.org/groups/schedule/f-46/f-46-key-tasks.html); [docs.fedoraproject.org releases/f45](https://docs.fedoraproject.org/en-US/releases/f45/); [release life cycle](https://docs.fedoraproject.org/en-US/releases/lifecycle/); [Upgrading Fedora Linux Using DNF System Plugin](https://docs.fedoraproject.org/en-US/quick-docs/upgrading-fedora-offline/) (page version F44, last review 2026-04-29).
- The F45 release-notes sources on the Fedora forge (branch f45 of [docs/release-notes](https://forge.fedoraproject.org/docs/release-notes)).
- Repositories: `dnf5 --releasever=45 --repo=fedora --repo=updates repoquery --latest-limit=1 ...` as the normal user (metadata went to the user cache), `rpm -q` and `dnf5 repoquery --installed` for this PC, `dnf5 download` into /tmp of fedora-repos-45 and fedora-gpg-keys-45 and a plain download of the two RPM Fusion release-45 packages (file lists read with `rpm -qlp`; nothing was installed).
- Python: [What's New in Python 3.15](https://docs.python.org/3.15/whatsnew/3.15.html) and [PEP 790](https://peps.python.org/pep-0790/).
- Fedora Magazine ([F45 Beta announcement](https://fedoramagazine.org/announcing-fedora-linux-45-beta/), [Modernizing the console with kmscon](https://fedoramagazine.org/modernizing-the-console-with-kmscon/)), Fedora Discussion (Common Issues tag f45), meetbot minutes of the F45 Final Go/No-Go meetings, [RPM Fusion bug 7565](https://bugzilla.rpmfusion.org/show_bug.cgi?id=7565), [systemd NEWS](https://github.com/systemd/systemd/blob/main/NEWS) (v260 to v262).

Could not be fetched or does not exist (and why):

- **The official Fedora 45 release notes are not published.** [/en-US/fedora/f45/release-notes/](https://docs.fedoraproject.org/en-US/fedora/f45/release-notes/) and [/en-US/fedora/f45/](https://docs.fedoraproject.org/en-US/fedora/f45/) return HTTP 404; the [releases/f45](https://docs.fedoraproject.org/en-US/releases/f45/) page says "This is a development landing page for Fedora Linux 45. User documentation, when available, will be at https://docs.fedoraproject.org/en-US/fedora/f45/"; the docs version list shows rawhide, f44, f43 ... but no f45; `/rawhide/release-notes/` is a stale placeholder (copyright 2024, "compared to Fedora Linux 39"); `/f44/` redirects to `/latest/`. A draft exists only in the forge repository, see section 1.
- `https://fedoraproject.org/wiki/Releases/45/Schedule` and `https://fedoraproject.org/wiki/Releases/45` return 404 (the schedule is on fedorapeople.org).
- The "Release Notes tracker" links printed on the ChangeSet (pagure.io/fedora-docs/release-notes/issue/N) return 404; that repository now lives on forge.fedoraproject.org.
- `yazi`: no package of that name in the F44 or the F45 repos (fedora, updates), so no F45 version can be given; it is also not installed as an RPM on this PC.
- `wayland`: there is no binary package of that name in F44 or F45 (the source package is called wayland); the library and development packages are given instead.
- Not collected because outside the brief: upstream release notes of GTK, GLib, libinput, foot, NetworkManager, firewalld, selinux-policy, Mesa, PipeWire and other packages in the version table (only the version differences are given). systemd's NEWS for v260 to v262 was collected because it is the biggest base-system jump. `updates-testing` was queried only for gdb and mesa.

## 1. State of the release on 2026-11-01

- **Dates** ([F45 schedule](https://fedorapeople.org/groups/schedule/f-45/f-45-key-tasks.html)): Rawhide started F45 development 2026-02-03; F45 branched from Rawhide 2026-08-11; Beta freeze 2026-08-25; Beta released 2026-09-15; Final freeze 2026-10-20 to 2026-11-03; "Current Final Target date" Tue 2026-11-03; "Final Target date #3" Tue 2026-11-10; post-release cleanup 2026-11-04 to 2026-11-11; Fedora Linux 43 EOL auto closure Wed 2026-12-16; Fedora Linux 45 end of life Wed 2027-12-08.
- **Go/No-Go history** (meetbot minutes): [2026-10-15](https://meetbot.fedoraproject.org/meeting_matrix_fedoraproject-org/2026-10-15/f45-final-go-no-go-meeting.2026-10-15-17.00.html) automatic NO-GO because there was no suitable release candidate (target moved to 2026-10-27); [2026-10-22](https://meetbot.fedoraproject.org/meeting_matrix_fedoraproject-org/2026-10-22/f45-final-go-no-go-meeting.2026-10-22-17.00.html) NO-GO with RC-1.2 available, because the blocker bug about the eMudhra compromised certificate in ca-certificates was "not sufficiently addressed" and needed another RC (target moved to Tue 2026-11-03); [2026-10-29](https://meetbot.fedoraproject.org/meeting_matrix_fedoraproject-org/2026-10-29/f45-final-go-no-go-meeting.2026-10-29-18.02.html) "Fedora Linux 45 Final is GO and will release on the current target date of 2026-11-03 with RC-1.4".
- **Beta announcement** ([Fedora Magazine, 2026-09-15](https://fedoramagazine.org/announcing-fedora-linux-45-beta/)) names as highlights: kmscon replacing the in-kernel console; RPM signature checking enforced by default; oo7 replacing GNOME Keyring and KWallet as secrets backend; new versions including Podman 6, Pandas 3, MySQL and MariaDB; early access to Python 3.15, Go 1.27, GCC 16.2, glibc 2.44; Atomic Desktop ISOs built with image-builder; systemd-oomd and zram swap for Fedora CoreOS; Anaconda WebUI flows for Atomic Desktops and Stratis partitioning. Upgrading an existing system to the Beta is described as possible with DNF system-upgrade.
- **Repositories** (`dnf5 repoinfo`, releasever 45): `fedora` = 75,855 packages, metadata revision updated 2026-10-30 08:28:54 local, base URLs under `.../fedora/linux/development/45/Everything/x86_64/os/` (the pre-release tree); `updates` (metalink `updates-released-f45`) = 6,352 packages, updated 2026-11-01 00:56:28 local. `updates-testing` for 45 also exists.
- **Release notes draft** (not published): the forge repo [docs/release-notes](https://forge.fedoraproject.org/docs/release-notes) has 21 branches including `f45` (latest commit 6c68bcb5c1, 2026-10-20, "Emacs 31 in Fedora 45 (#433)"). The `f45` pages hold only two real items so far: [desktop.adoc](https://forge.fedoraproject.org/docs/release-notes/raw/branch/f45/modules/release-notes/pages/desktop.adoc) (new LibreOffice spell-check dictionaries `libreoffice-dict-<lang>`, not installed by default, `dnf install libreoffice-dict-fr --allowerasing` removes hunspell-fr) and [developers.adoc](https://forge.fedoraproject.org/docs/release-notes/raw/branch/f45/modules/release-notes/pages/developers.adoc) (GNU Emacs 31.1); [sysadmin.adoc](https://forge.fedoraproject.org/docs/release-notes/raw/branch/f45/modules/release-notes/pages/sysadmin.adoc) is an empty heading.
- **Fedora 44 end of life**: the F44 schedule gives Wed 2027-06-02 ("This is a changeable date and currently based off the Early Target Date", [F44 schedule](https://fedorapeople.org/groups/schedule/f-44/f-44-key-tasks.html)); the rule is "Release N is supported until four weeks after the release of Release N+2" ([life cycle](https://docs.fedoraproject.org/en-US/releases/lifecycle/)). F46's "Current Final Target date" is Tue 2027-04-20 ([F46 schedule](https://fedorapeople.org/groups/schedule/f-46/f-46-key-tasks.html)).

## 2. The accepted changes: 46 listed (19 System-Wide, 27 Self-Contained)

Source of the list, titles, scope and status: [Releases/45/ChangeSet](https://fedoraproject.org/wiki/Releases/45/ChangeSet) (generated by Fedora Program Management scripts; "Status" is the tracking-bug state and can lag: e.g. OpenSSL 4.0 says "Not being worked on" and Erlang 27 says "Unknown" while both are in the F45 repos). The "What" sentence is condensed from each change's own page (summary, description, upgrade/compatibility section). "In the F45 repos" lines are my checks with `dnf5 repoquery` on 2026-11-01. The ChangeSet has no Change for a kernel version, Mesa, Wayland, wlroots, GTK, PipeWire, systemd, SELinux policy or Rust (the kernel-related items are the Yama ptrace default, the kmscon console, the crypto-userspace-API restriction and the DRM-panic frontend; none changes the kernel version).

### Toolchain, languages and language stacks

- **GNU Toolchain Update (gcc 16.2, binutils 2.47, glibc 2.44, gdb 17.2)** (System-Wide; ChangeSet status: 100% code completed; page last updated 2026-07-21) [GNUToolchainF45](https://fedoraproject.org/wiki/Changes/GNUToolchainF45)
  - What: Updates the GNU toolchain to gcc 16.2, binutils 2.47, glibc 2.44 and gdb 17.2, stated to be backwards compatible with the previous Fedora; the page also references a separate "Shadow Stack by default" system-wide Change, whose own page now carries Category:ChangeAcceptedF46 and "Targeted release: Fedora Linux 46".
  - In the F45 repos on 2026-11-01: gcc 16.2.1-3.fc45 (same as F44), binutils 2.47-1.fc45 (F44 2.46.1-1), glibc 2.44-2.fc45 (F44 2.43-9), gdb 17.2-6.fc45 in fedora/updates while F44 already has gdb 18.1-1.fc44 and F45 updates-testing has gdb 18.1-1.fc45.
- **LLVM 23** (System-Wide; ChangeSet status: Change accepted; page last updated 2026-07-14) [LLVM-23](https://fedoraproject.org/wiki/Changes/LLVM-23)
  - What: Updates all LLVM sub-projects to version 23 with a soname change of the llvm libraries, an `llvm22` compat package for packages still needing clang/llvm 22 libraries, and libclc now built from the llvm source package (the page notes an upstream discussion between Mesa and libclc maintainers about changes that could affect how Mesa is built; reverted upstream).
  - In the F45 repos on 2026-11-01: llvm 23.1.4-1.fc45 (F44 repos: 22.1.8-4.fc44).
- **Golang 1.27** (System-Wide; ChangeSet status: 100% code completed; page last updated 2026-07-21) [golang1.27](https://fedoraproject.org/wiki/Changes/golang1.27)
  - What: Updates Go (package golang) to 1.27 with a mass rebuild of dependants; the page states no upgrade or compatibility impact.
  - In the F45 repos on 2026-11-01: golang 1.27.3-1.fc45 (F44 repos: 1.26.10-1.fc44).
- **Python 3.15** (System-Wide; ChangeSet status: 100% code completed; page last updated 2026-06-10) [Python3.15](https://fedoraproject.org/wiki/Changes/Python3.15)
  - What: Updates the Python stack from 3.14 to 3.15 (about 3900 packages rebuilt; python3.14 remains as a non-main package); user scripts may need a small amount of porting but 3.14 code is mostly forward compatible.
  - In the F45 repos on 2026-11-01: python3 / python3-libs 3.15.0-1.fc45; python3.14 3.14.8-1.fc45 (non-main); F44 repos also carry python3.15 3.15.0-1.fc44. See the Python section.
- **Setuptools 82+** (Self-Contained; ChangeSet status: 100% code completed; page last updated 2026-05-12) [Setuptools_82+](https://fedoraproject.org/wiki/Changes/Setuptools_82%2B)
  - What: Updates python-setuptools to 82+, which is not fully compatible: the `pkg_resources` module is removed (use importlib.resources / importlib.metadata), about 130 Rawhide packages were estimated to fail to build in March 2026, and a deprecated `python-setuptools80` compatibility package is provided.
  - In the F45 repos on 2026-11-01: python3-setuptools 83.0.0-2.fc45 and python3-setuptools80 80.10.2-9.fc45 (F44: python3-setuptools 80.10.2-3.fc44, installed here).
- **Pandas 3** (Self-Contained; ChangeSet status: 100% code completed; page last updated 2026-05-27) [Pandas3](https://fedoraproject.org/wiki/Changes/Pandas3)
  - What: Updates pandas from 2.3.x to 3.0.x (string handling improvements, consistent Copy-on-Write behaviour, removal of long-deprecated functionality).
  - In the F45 repos on 2026-11-01: python3-pandas 3.0.6-1.fc45 (F44: 2.3.3-3.fc44).
- **Deprecate python-dateutil** (Self-Contained; ChangeSet status: Finished; page last updated 2026-06-21) [DeprecatePython-dateutil](https://fedoraproject.org/wiki/Changes/DeprecatePython-dateutil)
  - What: Marks python-dateutil as deprecated in Fedora because upstream is unmaintained; it is still packaged for now and likely to be orphaned when the burden gets too high.
  - In the F45 repos on 2026-11-01: python3-dateutil 2.9.0.post0-15.fc45 still packaged.
- **Perl 5.44** (System-Wide; ChangeSet status: Testable; page last updated 2026-07-29) [perl5.44](https://fedoraproject.org/wiki/Changes/perl5.44)
  - What: Updates Perl to 5.44 (released 16 July 2026); packages that fail to rebuild are removed from the distribution, and modules installed locally with CPAN clients need reinstalling.
  - In the F45 repos on 2026-11-01: perl 5.44.0-527.fc45 (F44: 5.42.3-525).
- **Lua 5.5** (System-Wide; ChangeSet status: Finished; page last updated 2026-02-07) [Lua5.5](https://fedoraproject.org/wiki/Changes/Lua5.5)
  - What: Updates Lua from 5.4 to 5.5 (upstream release 22 December 2025: declarations for global variables, named vararg tables, more compact arrays, incremental major garbage collection).
  - In the F45 repos on 2026-11-01: lua 5.5.1-2.fc45 (F44: 5.4.8-5.fc44).
- **CMake drop non-standard variables** (System-Wide; ChangeSet status: Not being worked on; page last updated 2026-03-10) [CMake_drop_install_vars](https://fedoraproject.org/wiki/Changes/CMake_drop_install_vars)
  - What: Stops passing the non-standard variables -DINCLUDE_INSTALL_DIR, -DLIB_INSTALL_DIR, -DSYSCONF_INSTALL_DIR, -DSHARE_INSTALL_PREFIX and -DLIB_SUFFIX in the %cmake macro; packages relying on them fail to build until patched (the cmake change itself is held until affected packages are fixed).
  - In the F45 repos on 2026-11-01: ChangeSet status "Not being worked on"; cmake 4.3.0-5.fc45 (F44: 4.3.0-1.fc44).
- **Protobuf 5.x/6.x** (System-Wide; ChangeSet status: 100% code completed; page last updated 2026-06-08) [Protobuf_5.x/6.x](https://fedoraproject.org/wiki/Changes/Protobuf_5.x/6.x)
  - What: Updates protobuf to the newest major (5.x, 6.x if in time) and adds a deprecated `protobuf3` compatibility package for current dependants, with a plan to package the previous major as a compat package each time a new one arrives.
  - In the F45 repos on 2026-11-01: protobuf 33.5-7.fc45 and protobuf3 3.19.6-66.fc45 (F44: protobuf 3.19.6-20.fc44).
- **Ruby on Rails 8.1** (Self-Contained; ChangeSet status: 100% code completed; page last updated 2026-09-11) [Ruby_on_Rails_8.1](https://fedoraproject.org/wiki/Changes/Ruby_on_Rails_8.1)
  - What: Updates Ruby on Rails to 8.1.
  - In the F45 repos on 2026-11-01: rubygem-rails 8.1.3.1-1.fc45 (F44: 8.0.3-2.fc44).
- **Lazarus with multiple widgetsets** (Self-Contained; ChangeSet status: 100% code completed; page last updated 2026-07-14) [LazarusWithMultipleWidgetsets](https://fedoraproject.org/wiki/Changes/LazarusWithMultipleWidgetsets)
  - What: Offers the Lazarus IDE built with several widgetsets instead of only GTK2.
  - In the F45 repos on 2026-11-01: lazarus 4.8-4.fc45.
- **Changes/Erlang 27** (Self-Contained; ChangeSet status: Unknown; page last updated 2026-07-21) [Erlang_27](https://fedoraproject.org/wiki/Changes/Erlang_27)
  - What: Updates Erlang/OTP to version 27 (code compiled on 26 stays compatible; packages with NIFs are rebuilt in the mass rebuild).
  - In the F45 repos on 2026-11-01: ChangeSet status "Unknown" but erlang 27.3.4.18-1.fc45 is in the repo (F44: 26.2.5.21-8.fc44).

### Base system (RPM, kernel, boot, console, security, network, installer)

- **RPM 6.1** (System-Wide; ChangeSet status: 100% code completed; page last updated 2026-07-21) [RPM-6.1](https://fedoraproject.org/wiki/Changes/RPM-6.1)
  - What: Updates RPM to upstream 6.1: NSS-based user/group lookups restored by default, a separate keystore lock so queries work during transactions, improved `rpmkeys -Kv` output, better rpm-plugin-syslog with the journal, new man pages, scriptlet-running optimisation; no intentional incompatibilities.
  - In the F45 repos on 2026-11-01: rpm 6.1.0-1.fc45 (installed here: 6.0.2-1.fc44).
- **Enforcing signature checking by default** (System-Wide; ChangeSet status: 100% code completed; page last updated 2026-01-21) [Enforcing_signature_checking_by_default](https://fedoraproject.org/wiki/Changes/Enforcing_signature_checking_by_default)
  - What: Changes RPM's default package verification (`%_pkgverify_level`) from digest to all, so only packages with a verified signature can be installed unless overridden with `--nosignature` or the API equivalent; dnf5 (5.2.14.0 and later) can disable the check per package, and unsigned local packages need keys imported or an explicit override.
  - In the F45 repos on 2026-11-01: comes with rpm 6.1.0-1.fc45; dnf5 5.4.6.0 in both releases.
- **Restrict ptrace by default** (System-Wide; ChangeSet status: Finished; page last updated 2026-03-17) [Restrict_ptrace_by_default](https://fedoraproject.org/wiki/Changes/Restrict_ptrace_by_default)
  - What: Turns on the Yama ptrace restriction by default (unprivileged users can no longer ptrace-attach to non-child processes); installing a debugger-type tool (elfutils, systemtap, gdb, lldb, delve, strace, ltrace ...) pulls in the renamed `yama-ptrace-enable` (formerly elfutils-default-yama-scope) which restores today's unrestricted behaviour system-wide, while gdb-headless and gdb-minimal do not.
  - In the F45 repos on 2026-11-01: yama-ptrace-enable 0.196-1.fc45 present; elfutils-default-yama-scope absent in F45 (F44: 0.196-1.fc44).
- **Use kmscon as default VT console** (System-Wide; ChangeSet status: 100% code completed; page last updated 2026-04-24) [UseKmsconVTConsole](https://fedoraproject.org/wiki/Changes/UseKmsconVTConsole)
  - What: Replaces the kernel console fbcon with the userspace console kmscon on virtual terminals (autovt@.service now points to kmsconvt@.service, kmscon installed by default, fbcon stays compiled in as a fallback); caveat on the page: starting graphical programs from such a console (startx) no longer works directly and needs `kmscon-launch-gui`.
  - In the F45 repos on 2026-11-01: kmscon 10.0.4-5.fc45 (F44 repos already carry kmscon 10.0.4-3.fc44); the page lists a kmscon / kmscon-gl split. Details of use are in the Fedora Magazine article of 2026-10-19 and in the known issues below.
- **Change Proposal Name: rebase to OpenSSL 4.0** (System-Wide; ChangeSet status: Not being worked on; page last updated 2026-07-02) [OpenSSL40](https://fedoraproject.org/wiki/Changes/OpenSSL40)
  - What: Proposes rebasing to OpenSSL 4.0 (soname bump, ENGINE support removed) with openssl3 compatibility packages so that existing third-party packages keep working; the ChangeSet status is stale, see the repo check.
  - In the F45 repos on 2026-11-01: ChangeSet status is "Not being worked on" but F45 carries openssl / openssl-libs / openssl-devel 4.0.3-1.fc45, plus compat openssl3-libs, openssl3-devel and openssl3-devel-engine 3.5.9-1.fc45 in updates; openssl-gost-engine exists in F44 (3.0.3-11.fc44) and not in F45.
- **Disable in Kernel Crypto Userspace API (Phase 1)** (Self-Contained; ChangeSet status: Finished; page last updated 2026-08-18) [Disable_CRYPTO_USER_API](https://fedoraproject.org/wiki/Changes/Disable_CRYPTO_USER_API)
  - What: Phase 1 of switching off the in-kernel Crypto Userspace API (CRYPTO_USER_API, deprecated upstream): its use is restricted to known users (iwd, cryptsetup for TrueCrypt/VeraCrypt, libkcapi), which stay unaffected, so unknown users can be found; the page notes that the iwd package is unmaintained upstream and suggests wpa_supplicant.
  - In the F45 repos on 2026-11-01: libkcapi 1.5.1-2.fc45, iwd 3.12-2.fc45.
- **Use PAM in chpasswd and newusers** (Self-Contained; ChangeSet status: 100% code completed; page last updated 2026-04-24) [UsePAMInChpasswdNewusers](https://fedoraproject.org/wiki/Changes/UsePAMInChpasswdNewusers)
  - What: Makes `chpasswd` and `newusers` (shadow-utils) go through PAM so password quality, history and auditing rules apply; scripts that set passwords violating the PAM policy may now fail.
  - In the F45 repos on 2026-11-01: shadow-utils 4.20.0-2.fc45 (F44: 4.19.0-7.fc44).
- **Authselect: Remove NIS Profile** (Self-Contained; ChangeSet status: 100% code completed; page last updated 2026-08-19) [Authselect_Remove_NIS_Profile](https://fedoraproject.org/wiki/Changes/Authselect_Remove_NIS_Profile)
  - What: Removes the `nis` profile from authselect (NIS itself stays available through a custom profile or manual nsswitch.conf; systems with the profile selected keep working but `authselect check` reports issues).
  - In the F45 repos on 2026-11-01: authselect 1.8.0-1.fc45 (F44: 1.7.1-1.fc44).
- **Enable IPv6-mostly support in NetworkManager** (Self-Contained; ChangeSet status: 100% code completed; page last updated 2026-03-25) [IPv6-Mostly_Support_In_NetworkManager](https://fedoraproject.org/wiki/Changes/IPv6-Mostly_Support_In_NetworkManager)
  - What: Enables NetworkManager's support for IPv6-mostly networks (DHCP option 108, NAT64/PREF64) by default, giving a CLAT IPv4 address in 192.0.0.0-192.0.0.7 on such networks; transparent to users.
  - In the F45 repos on 2026-11-01: NetworkManager 1.58.1-3.fc45 (installed here: 1.56.1-2.fc44).
- **GRUB EFI for Confidential Computing** (Self-Contained; ChangeSet status: Change accepted; page last updated 2026-08-11) [Grub2LightForConfidentialComputing](https://fedoraproject.org/wiki/Changes/Grub2LightForConfidentialComputing)
  - What: Adds `grub-cc`, a separate minimal UEFI-only GRUB package that boots a Unified Kernel Image through BLS files for confidential-computing and sealed-container use; it does not replace the normal GRUB.
  - In the F45 repos on 2026-11-01: grub-cc 1-2.fc45 (new); grub2-efi-x64 2.12-83.fc45 (F44: 2.12-66.fc44).
- **DRM Panic Frontend** (Self-Contained; ChangeSet status: Finished; page last updated 2026-03-25) [DrmPanicFrontend](https://fedoraproject.org/wiki/Changes/DrmPanicFrontend)
  - What: Deploys a Fedora-branded web frontend for the DRM-panic QR code so a kernel panic screen links to a readable explanation, system information and bug-report steps.
- **Update xmlsec to version 1.3.9** (Self-Contained; ChangeSet status: 100% code completed; page last updated 2026-03-25) [Update_xmlsec_to_1_3](https://fedoraproject.org/wiki/Changes/Update_xmlsec_to_1_3)
  - What: Brings xmlsec 1.3.x (1.3.9) into Fedora; version 1.3 is not backward compatible with 1.2.
  - In the F45 repos on 2026-11-01: xmlsec1 1.3.11-7.fc45 (F44: 1.2.41-4.fc44).
- **Stratis Storage in Anaconda** (System-Wide; ChangeSet status: 100% code completed; page last updated 2026-07-21) [StratisAnacondaSupport](https://fedoraproject.org/wiki/Changes/StratisAnacondaSupport)
  - What: Adds support for installing Fedora onto Stratis filesystems, in Kickstart and in manual partitioning in the Anaconda WebUI (Cockpit Storage).
  - In the F45 repos on 2026-11-01: stratisd 3.9.3-3.fc45, stratis-cli 3.9.1-1.fc45, anaconda 45.30-1.fc45 (F44: anaconda 44.30-2).

### Graphics and desktop stack (Mesa, Wayland, wlroots, GTK, PipeWire, fonts, input, secrets)

- **Fontconfig 2.18** (System-Wide; ChangeSet status: 100% code completed; page last updated 2026-07-21) [Fontconfig2.18](https://fedoraproject.org/wiki/Changes/Fontconfig2.18)
  - What: Updates fontconfig from 2.17 to 2.18, basically compatible, but locally installed fonts may match differently (the page gives a per-font check, `fc-scan -f "%{genericfamily}\n" FILE`, and a ~/.config/fontconfig/conf.d rule to assign the generic family if it shows 0).
  - In the F45 repos on 2026-11-01: fontconfig 2.18.3-2.fc45 (F44: 2.17.0-4.fc44, installed here).
- **IBus 1.5.35** (Self-Contained; ChangeSet status: 100% code completed; page last updated 2026-08-18) [IBus_1.5.35](https://fedoraproject.org/wiki/Changes/IBus_1.5.35)
  - What: IBus 1.5.35 improves XKB keymap handling on Wayland desktops: ISO latch/shift states (KDE, Sway, Hyprland, COSMIC), an option to use the session keymap regardless of the engine keymap, and key-event forwarding with the Wayland input-method protocol v2.
  - In the F45 repos on 2026-11-01: ibus 1.5.35~rc1-1.fc45 (F44: 1.5.34-4.fc44).
- **oo7 Secrets Service Provider** (System-Wide; ChangeSet status: Change accepted; page last updated 2026-09-15) [oo7_Secrets_Service_Provider](https://fedoraproject.org/wiki/Changes/oo7_Secrets_Service_Provider)
  - What: Replaces GNOME Keyring as the default Secrets Service provider on Fedora desktops with oo7 (oo7-daemon, a PAM module, support code); existing GNOME Keyring data is migrated automatically.
  - In the F45 repos on 2026-11-01: oo7-daemon 0.7.0~beta^1.e91b98a-1.fc45; gnome-keyring 51.1-1.fc45 is still packaged. Two oo7 bugs were handled as release blockers or freeze exceptions in the 2026-10-29 Go/No-Go (see known issues).

### Packaging (renamed, retired, replaced, relocated packages)

- **Relocate RPM repository configs to /usr** (System-Wide; ChangeSet status: Change accepted; page last updated 2026-07-22) [RelocateRpmRepoConfigsToUsr](https://fedoraproject.org/wiki/Changes/RelocateRpmRepoConfigsToUsr)
  - What: Moves all packaged RPM repository configuration from /etc/yum.repos.d to /usr/share/dnf5/repos.d and the Fedora packaging GPG keys (fedora-gpg-keys) to /usr/share/pki/rpm-gpg; unmodified distribution repo files move cleanly, a modified file stays in /etc and overrides its /usr counterpart entirely, and DNF 4 / YUM stop working as system package managers because the configuration is no longer in their paths.
  - In the F45 repos on 2026-11-01: verified in the shipped package: fedora-repos-45-1.noarch installs /usr/share/dnf5/repos.d/{fedora,fedora-updates,fedora-updates-testing,fedora-cisco-openh264}.repo (gpgkey=file:///usr/share/pki/rpm-gpg/RPM-GPG-KEY-fedora-$releasever-$basearch) and only an empty /etc/yum.repos.d; fedora-gpg-keys-45-1 installs the keys under /usr/share/pki/rpm-gpg. This PC has fedora-repos-44-2 with /etc/yum.repos.d/fedora.repo (gpgkey=file:///etc/pki/rpm-gpg/...). The RPM Fusion release packages for 45 (45-0.2) still install their repo files in /etc/yum.repos.d and keys in /etc/pki/rpm-gpg.
- **Versioned libgit2 packages** (System-Wide; ChangeSet status: 100% code completed; page last updated 2026-06-12) [Versioned_libgit2_packages](https://fedoraproject.org/wiki/Changes/Versioned_libgit2_packages)
  - What: Only fully versioned libgit2 packages are provided from now on (libgit2_1.9 replaces the unversioned libgit2, libgit2_1.8 already exists) and dependants are adapted to the version they support; existing installs migrate automatically.
  - In the F45 repos on 2026-11-01: libgit2_1.9 1.9.7-3.fc45 present; unversioned libgit2 and libgit2_1.8 absent in F45 (F44: libgit2 1.9.7-1 and libgit2_1.8 1.8.5-1).
- **Sequoia %openpgpverify** (Self-Contained; ChangeSet status: 100% code completed; page last updated 2026-08-25) [Sequoia_openpgpverify](https://fedoraproject.org/wiki/Changes/Sequoia_openpgpverify)
  - What: Introduces the RPM macro `%openpgpverify`, using the Sequoia OpenPGP implementation instead of GnuPG (`%gpgverify`) by default, as a step in gradually moving away from GnuPG and toward post-quantum OpenPGP; affects the build system only.
- **NodeJS metapackages** (Self-Contained; ChangeSet status: 100% code completed; page last updated 2026-07-31) [NodeJSMetapackages](https://fedoraproject.org/wiki/Changes/NodeJSMetapackages)
  - What: The NodeJS team stops designating one stream as "default"; a chosen stream generates unversioned nodejs-* subpackages that act as a selector so the default can change without breaking upgrade paths (the page leaves open how current default-stream users are migrated).
  - In the F45 repos on 2026-11-01: F45: nodejs 22.23.1-4.fc45 (a package of that name), nodejs24 24.18.0-4.fc45; the F44 repos list nodejs22 and nodejs24 but no package named nodejs.
- **Switch distribution default version of MySQL from 8.4 to 9.7** (Self-Contained; ChangeSet status: 100% code completed; page last updated 2026-07-22) [MySQL_9.7](https://fedoraproject.org/wiki/Changes/MySQL_9.7)
  - What: Switches the distribution-default MySQL (the one that also provides unversioned names such as mysql-server) from 8.4 to 9.7; mysql8.4 stays available as versioned packages; mysql_native_password is gone in 9.x.
  - In the F45 repos on 2026-11-01: mysql 9.7.2-1.fc45 (F44 unversioned: 8.4.10-1; mysql9.7 9.7.1-2.fc44 exists as versioned packages in F44).
- **Switch distribution default version of MariaDB from 11.8 to 12.3** (Self-Contained; ChangeSet status: 100% code completed; page last updated 2026-07-24) [MariaDB_12.3](https://fedoraproject.org/wiki/Changes/MariaDB_12.3)
  - What: Switches the distribution-default MariaDB (unversioned names such as mariadb-server) from 11.8 to 12.3; mariadb11.8 stays available; innodb_snapshot_isolation defaults to ON in 12.3.
  - In the F45 repos on 2026-11-01: mariadb 12.3.2-101.fc45 (F44 unversioned: 11.8.8-3; mariadb12.3 12.3.2-2.fc44 exists as versioned packages in F44).
- **ODBC Stack Modernization** (Self-Contained; ChangeSet status: 100% code completed; page last updated 2026-08-03) [ODBC_stack_modernization](https://fedoraproject.org/wiki/Changes/ODBC_stack_modernization)
  - What: Modernises 8 ODBC packages (unixODBC, libiodbc and six drivers) so /etc/odbcinst.ini is generated from per-driver drop-in snippets by RPM file triggers, drivers move to a dedicated directory and bare library names resolve through a compiled-in search path.
  - In the F45 repos on 2026-11-01: unixODBC 2.3.14-36.fc45 (F44: 2.3.14-3.fc44).
- **Provide LibreOffice help packages in HTML and noarch** (Self-Contained; ChangeSet status: Finished; page last updated 2026-08-03) [LibreOffice_html_help](https://fedoraproject.org/wiki/Changes/LibreOffice_html_help)
  - What: Ships LibreOffice help as HTML in noarch packages instead of the embedded help system.
  - In the F45 repos on 2026-11-01: libreoffice-core 26.8.2.2-2.fc45 (F44: 26.2.6.3-1.fc44).
- **LibreOffice Dictionaries** (Self-Contained; ChangeSet status: 100% code completed; page last updated 2026-09-10) [LibreOfficeDictionaries](https://fedoraproject.org/wiki/Changes/LibreOfficeDictionaries)
  - What: Adds a new libreoffice-dictionaries source package with hunspell dictionaries taken from the LibreOffice upstream repository, as per-language `libreoffice-dict-<lang>` subpackages that conflict with the existing hunspell-<lang> packages.
  - In the F45 repos on 2026-11-01: F45 release-notes draft (desktop.adoc) says the new packages are not installed by default and the hunspell-<lang> packages stay the default.

### Other (containers, Atomic Desktops and CoreOS media, installer front ends)

- **Podman 6** (Self-Contained; ChangeSet status: 100% code completed; page last updated 2026-03-11) [Podman6](https://fedoraproject.org/wiki/Changes/Podman6)
  - What: Introduces Podman 6.0, a new major version with API/CLI breaking changes and the final removal of slirp4netns, cgroups v1 and the BoltDB backend (containers.conf may need migration); the page summary says "into Fedora 44" but its status block targets Fedora Linux 45.
  - In the F45 repos on 2026-11-01: podman 6.1.3-1.fc45 (installed here: 5.8.9-1.fc44).
- **Encapsule isolated devel containers** (Self-Contained; ChangeSet status: Change accepted; page last updated 2026-08-18) [Encapsule_devel_containers](https://fedoraproject.org/wiki/Changes/Encapsule_devel_containers)
  - What: Adds `encapsule`, a small CLI that runs "tools installed from the internet" (or a project working directory) inside a safer container instead of the home directory and host.
  - In the F45 repos on 2026-11-01: encapsule 0.6-1.fc45 (F44 repos also have 0.6-1.fc44).
- **Build disk images for Atomic Desktops with image-builder** (System-Wide; ChangeSet status: Testable; page last updated 2026-02-03) [BuildAtomicDesktopsWithImageBuilder](https://fedoraproject.org/wiki/Changes/BuildAtomicDesktopsWithImageBuilder)
  - What: Builds the Fedora Atomic Desktop ISOs with image-builder instead of lorax and adds qcow2 images (Silverblue, Kinoite) and an aarch64 raw image.
- **Anaconda WebUI Fedora Atomic** (Self-Contained; ChangeSet status: 100% code completed; page last updated 2026-08-18) [Anaconda_WebUI_Fedora_Atomic](https://fedoraproject.org/wiki/Changes/Anaconda_WebUI_Fedora_Atomic)
  - What: The Fedora Atomic ISO images switch from the GTK-based Anaconda installer to the Anaconda WebUI installer.
- **Web Based Remote Installation Support for Atomic Desktops** (Self-Contained; ChangeSet status: 100% code completed; page last updated 2026-08-18) [Web_Based_Remote_Installation_Support_For_Atomic_Desktops](https://fedoraproject.org/wiki/Changes/Web_Based_Remote_Installation_Support_For_Atomic_Desktops)
  - What: Allows installing an Atomic Desktop remotely through the Anaconda WebUI (boot with `inst.webui.remote`, finish in a browser on another machine over HTTPS with PIN authentication).
- **Native Butane Config Support in Ignition** (Self-Contained; ChangeSet status: 100% code completed; page last updated 2026-08-03) [IgnitionNativeButaneSupport](https://fedoraproject.org/wiki/Changes/IgnitionNativeButaneSupport)
  - What: Ignition accepts Butane YAML configs natively at first boot by merging the Butane transpiler into the Ignition package; the butane CLI stays available.
  - In the F45 repos on 2026-11-01: ignition 2.27.0-2.fc45, butane 2.27.0-2.fc45.
- **Filter Fedora Flatpaks for Atomic Desktops Version 2** (Self-Contained; ChangeSet status: Change accepted; page last updated 2026-03-25) [FilterFedoraFlatpaksAtomicDesktopsv2](https://fedoraproject.org/wiki/Changes/FilterFedoraFlatpaksAtomicDesktopsv2)
  - What: Lets image-based Fedora desktop outputs decide to filter the Fedora Flatpak repository for pre-installed Flatpaks and enable the Flathub verified-FLOSS subset by default (users of Fedora Flatpaks may need to enable the full fedora remote to keep getting updates); its page says "Targeted release: Fedora Linux 44" although it is categorised ChangeAcceptedF45.

Related Change that is not in the F45 set: [Enable Shadow Stack by Default on x86_64](https://fedoraproject.org/wiki/Changes/ShadowStack) (referenced from the GNU toolchain page as a separate F45 Change). Its Summary still says "on Fedora Linux 45", but its status block says "Targeted release: Fedora Linux 46" and it carries Category:ChangeAcceptedF46 (FESCo issue #3636).

## 3. Key package versions: this PC (F44) versus Fedora 45

F44 column = `rpm -q` on this PC; "F44 repos" column is filled only for packages not installed here (from `dnf5 --releasever=44 --repo=fedora --repo=updates repoquery`, which for installed packages is identical to what is installed, this PC being fully updated). F45 column = `dnf5 --releasever=45 --repo=fedora --repo=updates repoquery --latest-limit=1` on 2026-11-01 (x86_64/noarch; i686 entries exist for some libraries and are left out). The fedora/updates label is the repo that carried the newest build.

| Package | F44 here (`rpm -q`) | F44 repos latest (when not installed or newer than installed) | F45 (`repoquery`, repo) | Difference and facts |
|---|---|---|---|---|
| python3 | 3.14.8-1.fc44 |  | 3.15.0-1.fc45 (fedora) | minor differs (3.14 -> 3.15); python3.14 3.14.8-1.fc45 stays in F45 as a non-main package; the F44 updates repo already carries python3.15 3.15.0-1.fc44 as a parallel package |
| gcc | 16.2.1-3.fc44 |  | 16.2.1-3.fc45 (updates) | same upstream version; the F44 updates repo already carries gcc 16.2.1-3.fc44 |
| glibc | 2.43-9.fc44 |  | 2.44-2.fc45 (updates) | minor differs (2.43 -> 2.44) |
| llvm | not installed | 22.1.8-4.fc44 | 23.1.4-1.fc45 (updates) | major differs (22 -> 23); not installed on this PC (the F44 version is in the F44 repos column); libLLVM soname 22.1 -> 23.1 |
| rust | not installed | 1.99.1-2.fc44 | 1.99.1-2.fc45 (updates) | same upstream version; not installed on this PC (the F44 version is in the F44 repos column) |
| golang | not installed | 1.26.10-1.fc44 | 1.27.3-1.fc45 (updates) | minor differs (1.26 -> 1.27); not installed on this PC (the F44 version is in the F44 repos column) |
| systemd | 259.10-1.fc44 |  | 262.1-1.fc45 (updates) | major differs (259 -> 262); three upstream releases between (260, 261, 262); see the systemd section |
| dnf5 | 5.4.6.0-1.fc44 |  | 5.4.6.0-3.fc45 (fedora) | same upstream version |
| rpm | 6.0.2-1.fc44 |  | 6.1.0-1.fc45 (fedora) | minor differs (6.0 -> 6.1) |
| kernel-core | 7.2.11-200.fc44 and 7.2.13-200.fc44 |  | 7.2.13-300.fc45 (updates) | same upstream version; two kernels installed here: 7.2.11-200.fc44 (running) and 7.2.13-200.fc44 (installed, not yet booted); the -200 / -300 release prefix is the Fedora 44 / 45 build convention |
| mesa-dri-drivers | 26.2.5-1.fc44 |  | 26.2.5-1.fc45 (updates) | same upstream version; F45 updates-testing already has 26.2.6 (not in stable on 2026-11-01); RPM Fusion mesa-va-drivers-freeworld in F45 is 26.2.6 and requires mesa-filesystem = 26.2.6 (see third-party repos) |
| pipewire | 1.6.11-1.fc44 |  | 1.6.11-1.fc45 (updates) | same upstream version |
| wireplumber | 0.5.19-1.fc44 |  | 0.5.19-1.fc45 (updates) | same upstream version |
| gtk3 | 3.24.52-2.fc44 |  | 3.24.52-6.fc45 (fedora) | same upstream version |
| gtk4 | 4.22.5-2.fc44 |  | 4.24.1-1.fc45 (fedora) | minor differs (4.22 -> 4.24) |
| glib2 | 2.88.4-1.fc44 |  | 2.90.1-1.fc45 (updates) | minor differs (2.88 -> 2.90) |
| wlroots | 0.20.2-1.fc44 |  | 0.20.2-2.fc45 (fedora) | same upstream version; F45 also carries wlroots0.18 0.18.3-6 and wlroots0.19 0.19.3-2 (F44 additionally had wlroots0.15 and wlroots0.17, absent in F45); the F44 repos already serve wlroots 0.20.2 (from updates) |
| wayland | not a package |  | not a package | no binary package named wayland in either release; see next two rows |
| libwayland-client (wayland library) | 1.26.0-1.fc44 |  | 1.26.0-3.fc45 (fedora) | same upstream version |
| wayland-protocols-devel | 1.49-1.fc44 |  | 1.49-2.fc45 (fedora) | same upstream version |
| libinput | 1.31.3-1.fc44 |  | 1.32.0-1.fc45 (fedora) | minor differs (1.31 -> 1.32) |
| foot | 1.27.0-1.fc44 |  | 1.28.0-1.fc45 (fedora) | minor differs (1.27 -> 1.28) |
| waybar | 0.15.0-2.fc44 |  | 0.15.0-6.fc45 (fedora) | same upstream version |
| mako | 1.11.0-1.fc44 |  | 1.11.0-2.fc45 (fedora) | same upstream version |
| neovim | 0.12.6-1.fc44 |  | 0.12.6-1.fc45 (updates) | same upstream version |
| bash | 5.3.9-3.fc44 |  | 5.3.15-2.fc45 (fedora) | point release differs (5.3.9 -> 5.3.15) |
| coreutils | 9.10-5.fc44 |  | 9.11-6.fc45 (fedora) | minor differs (9.10 -> 9.11) |
| btrfs-progs | 7.1-1.fc44 |  | 7.1-1.fc45 (fedora) | same upstream version |
| snapper | 0.13.0-3.fc44 |  | 0.13.0-5.fc45 (fedora) | same upstream version |
| grub2-common | 2.12-66.fc44 |  | 2.12-83.fc45 (updates) | same upstream version |
| selinux-policy | 44.11-1.fc44 |  | 45.23-1.fc45 (fedora) | major differs (44 -> 45); version tracks the release number (44.x -> 45.x) |
| firewalld | 2.4.4-1.fc44 |  | 2.5.2-1.fc45 (fedora) | minor differs (2.4 -> 2.5) |
| NetworkManager | 1.56.1-2.fc44 |  | 1.58.1-3.fc45 (fedora) | minor differs (1.56 -> 1.58) |
| podman | 5.8.9-1.fc44 |  | 6.1.3-1.fc45 (fedora) | major differs (5 -> 6) |
| restic | 0.19.1-1.fc44 |  | 0.19.1-1.fc45 (fedora) | same upstream version |
| yazi | not installed |  | not found | n/a; no package named yazi in the F44 or F45 fedora/updates repos (not installed as an RPM on this PC) |
| zathura | 2026.07.18-1.fc44 |  | 2026.07.18-1.fc45 (fedora) | same upstream version |
| mpv | 0.41.0-5.fc44 |  | 0.41.0-10.fc45 (fedora) | same upstream version |
| ffmpeg-free | not installed | 8.1.3-1.fc44 | 9.0.2-3.fc45 (updates) | major differs (8 -> 9); not installed on this PC (the F44 version is in the F44 repos column); RPM Fusion ffmpeg 8.1.3-1.fc44 -> 9.0.2-1.fc45 is the one in the project manifest |

Extra repo facts: `kmscon` 10.0.4-5.fc45 is in F45 (F44 repos: 10.0.4-3.fc44); `fontconfig` 2.18.3-2.fc45 (F44: 2.17.0-4.fc44); `xorg-x11-server-Xwayland` 24.1.14-2.fc45 (F44: 24.1.14-1.fc44); `libadwaita` 1.10.0 (F44: 1.9.4); `pango` 1.58.2 (F44: 1.57.1); `vulkan-loader` 1.4.350.0 (F44: 1.4.341.0); `wl-clipboard` 2.3.0 (F44: 2.2.1^git20251124); `gtk-layer-shell` 0.10.1 (F44: 0.10.0); `dconf` 51.0 (F44: 0.49.0); `plymouth-plugin-script` 26.134.222 (F44: 24.004.60); `greetd` 0.10.3-12.fc45, `gtklock` 4.0.0-4.fc45, `cava` 0.10.2-8.fc45, `ddcutil` 3.0.2-1.fc45, `openrgb` 1.0~rc2-4.20260126git74cbdcc.fc45 and `stockfish` 18-5.fc45 exist in F45. `dwl` is in neither release (not a Fedora package).

## 4. Python 3.15

### 4.1 In Fedora 45

- **System Python in F45: 3.15.0** (`python3` and `python3-libs` 3.15.0-1.fc45 in the `fedora` repo, checked 2026-11-01). This PC has 3.14.8-1.fc44. `python3.14` 3.14.8-1.fc45 stays in F45 as a non-main package; the F44 updates repo already carries `python3.15` 3.15.0-1.fc44 as a parallel (non-main) package.
- **Change page**: [Changes/Python3.15](https://fedoraproject.org/wiki/Changes/Python3.15), System-Wide, owners Karolina Surma and Miro Hrončok, ChangeSet status "100% code completed", [tracking bug 2412434](https://bugzilla.redhat.com/show_bug.cgi?id=2412434), [FESCo issue #3509](https://pagure.io/fesco/issue/3509), [discussion thread](https://discussion.fedoraproject.org/t/169003), [announcement](https://lists.fedoraproject.org/archives/list/devel-announce@lists.fedoraproject.org/message/GTO4UUAKMULRANQOCWQJXSQIOW3U73VH/).
- From that page: "Update the Python stack in Fedora from Python 3.14 to Python 3.15"; about 4300 packages depend on Python 3 and about 3900 needed rebuilding; compatibility statement: "All the packages that depend on Python 3 must be rebuilt. User written Python 3 scripts/applications may require a small amount of porting, but mostly Python 3.14 is forward compatible with Python 3.15."; "Packages that fail to install because they failed to rebuild with Python 3.15 will be retired at Final Freeze unless they have a proposed Freeze Exception"; "Blocks release? Yes, we'd like to block Fedora 45 release on at least 3.15.0rc1". The page points maintainers at [Porting to Python 3.15](https://docs.python.org/3.15/whatsnew/3.15.html#porting-to-python-3-15).
- Upstream status ([PEP 790](https://peps.python.org/pep-0790/)): 3.15.0 final released Friday 2026-10-09 (What's New: "Python 3.15 was released on 9 October 2026"); 3.15.1 on 2026-10-21 and 3.15.2 on 2026-10-26 are out upstream (the docs page header reads "3.15.2 documentation"), so Fedora's 3.15.0-1.fc45 is two bugfix releases behind; 3.15.3 is expected 2026-12-01; bugfix releases roughly every second month for two years, then source-only security fixes until about October 2031.
- Related Python-stack Changes in the same release: [Setuptools 82+](https://fedoraproject.org/wiki/Changes/Setuptools_82%2B) (`pkg_resources` removed; python3-setuptools 83.0.0-2.fc45, compat python3-setuptools80 80.10.2-9.fc45), [Pandas 3](https://fedoraproject.org/wiki/Changes/Pandas3), [Deprecate python-dateutil](https://fedoraproject.org/wiki/Changes/DeprecatePython-dateutil).

### 4.2 Python-related packages (the third-party modules imported by the repo's own scripts, plus pip/setuptools)

Modules found by scanning the repo's *.py files and Python-shebang scripts (excluding tests/engine/fixtures and .claude/): PIL, numpy, gi, pikepdf, fontTools, cairo, markdown, playwright, dbus_next, yaml, scipy, syncplay. Playwright is not packaged in the F44 or F45 repos.

| Package | F44 here (`rpm -q`) | F44 repos | F45 repos | Difference |
|---|---|---|---|---|
| python3 | 3.14.8-1.fc44 | 3.14.8-1.fc44 | 3.15.0-1.fc45 | minor differs (3.14 -> 3.15) |
| python3-libs | 3.14.8-1.fc44 | 3.14.8-1.fc44 | 3.15.0-1.fc45 | minor differs (3.14 -> 3.15) |
| python3.14 | not installed | not found | 3.14.8-1.fc45 | n/a |
| python3.15 | not installed | 3.15.0-1.fc44 | not found | n/a |
| python3-setuptools | 80.10.2-3.fc44 | 80.10.2-3.fc44 | 83.0.0-2.fc45 | major differs (80 -> 83) |
| python3-pip | not installed | 26.0.1-3.fc44 | 26.1.2-5.fc45 | minor differs (26.0 -> 26.1) |
| python3-wheel | not installed | 0.45.1-20.fc44 | 0.48.0-1.fc45 | minor differs (0.45 -> 0.48) |
| python3-pillow | 12.3.0-4.fc44 | 12.3.0-4.fc44 | 12.3.0-3.fc45 | same upstream version |
| python3-numpy | 2.4.6-1.fc44 | 2.4.6-1.fc44 | 2.5.4-1.fc45 | minor differs (2.4 -> 2.5) |
| python3-gobject | 3.56.3-1.fc44 | 3.56.3-1.fc44 | 3.58.1-6.fc45 | minor differs (3.56 -> 3.58) |
| python3-pikepdf | not installed | 10.8.0-1.fc44 | 10.8.0-3.fc45 | same upstream version |
| python3-fonttools | 4.62.1-1.fc44 | 4.62.1-1.fc44 | 4.66.0-1.fc45 | minor differs (4.62 -> 4.66) |
| python3-cairo | 1.28.0-5.fc44 | 1.28.0-5.fc44 | 1.28.0-8.fc45 | same upstream version |
| python3-markdown | not installed | 3.10.3-1.fc44 | 3.11-1.fc45 | minor differs (3.10 -> 3.11) |
| python3-pyyaml | 6.0.3-3.fc44 | 6.0.3-3.fc44 | 6.0.3-6.fc45 | same upstream version |
| python3-scipy | 1.16.2-3.fc44 | 1.16.2-3.fc44 | 1.18.0-3.fc45 | minor differs (1.16 -> 1.18) |
| python3-dbus-next | not installed | 0.2.3-18.fc44 | 0.2.3-20.fc45 | same upstream version |
| python3-twisted | not installed | 25.5.0-6.fc44 | 26.4.0-3.fc45 | major differs (25 -> 26) |
| python3-pyte | not installed | 0.8.2-15.fc44 | 0.8.2-17.fc45 | same upstream version |
| python3-dateutil | 2.9.0.post0-7.fc44 | 2.9.0.post0-7.fc44 | 2.9.0.post0-15.fc45 | same upstream version |
| python3-playwright | not installed | not found | not found | n/a |

### 4.3 What's New in Python 3.15: removed and deprecated (official list, with links)

Source: [https://docs.python.org/3.15/whatsnew/3.15.html](https://docs.python.org/3.15/whatsnew/3.15.html) (docs.python.org). Section anchors are the page's own.

**Removed** ([Removed](https://docs.python.org/3.15/whatsnew/3.15.html#removed)); only module removed: `sre_compile`, `sre_constants`, `sre_parse`:

- [ast](https://docs.python.org/3.15/whatsnew/3.15.html#id1): constructors of AST nodes now raise TypeError when a required argument is omitted or an unknown keyword is passed (DeprecationWarning since 3.13)
- [collections.abc](https://docs.python.org/3.15/whatsnew/3.15.html#collections-abc): `ByteString` removed from `collections.abc.__all__` (deprecated since 3.12, removal of the class scheduled for 3.17)
- [ctypes](https://docs.python.org/3.15/whatsnew/3.15.html#id2): undocumented `ctypes.SetPointerType()` removed
- [datetime](https://docs.python.org/3.15/whatsnew/3.15.html#datetime): `strptime()` raises ValueError when the format has `%d` without a year directive
- [glob](https://docs.python.org/3.15/whatsnew/3.15.html#glob): undocumented `glob.glob0()` and `glob.glob1()` removed (use `glob.glob()` with `root_dir`)
- [http.server](https://docs.python.org/3.15/whatsnew/3.15.html#id3): `CGIHTTPRequestHandler` and the `--cgi` flag of `python -m http.server` removed
- [importlib](https://docs.python.org/3.15/whatsnew/3.15.html#importlib): `load_module()` methods of `Loader` and subclasses removed; the import system no longer calls them (use `exec_module()`)
- [importlib.resources](https://docs.python.org/3.15/whatsnew/3.15.html#importlib-resources): deprecated `package` parameter of `files()` removed
- [pathlib](https://docs.python.org/3.15/whatsnew/3.15.html#id4): `PurePath.is_reserved()` removed (use `os.path.isreserved()`)
- [platform](https://docs.python.org/3.15/whatsnew/3.15.html#platform): `platform.java_ver()` removed
- [sre_*](https://docs.python.org/3.15/whatsnew/3.15.html#sre): modules `sre_compile`, `sre_constants`, `sre_parse` removed
- [sysconfig](https://docs.python.org/3.15/whatsnew/3.15.html#sysconfig): `check_home` parameter of `sysconfig.is_python_build()` removed
- [threading](https://docs.python.org/3.15/whatsnew/3.15.html#id5): arbitrary positional/keyword arguments to the C implementation of `RLock` removed
- [types](https://docs.python.org/3.15/whatsnew/3.15.html#id6): `codeobject.co_lnotab` removed from `types.CodeType`
- [typing](https://docs.python.org/3.15/whatsnew/3.15.html#id7): `typing.ByteString` removed from `typing.__all__`; undocumented keyword syntax `NamedTuple("Point", x=int, y=int)` no longer supported; zero-field `TypedDict("TD")` / `TypedDict("TD", None)` no longer supported; `@typing.no_type_check_decorator` removed
- [wave](https://docs.python.org/3.15/whatsnew/3.15.html#id8): `getmark()`, `setmark()`, `getmarkers()` of `Wave_read` / `Wave_write` removed
- [zipimport](https://docs.python.org/3.15/whatsnew/3.15.html#zipimport): `zipimporter.load_module()` removed (use `exec_module()`)
- Removed C APIs ([section](https://docs.python.org/3.15/whatsnew/3.15.html#removed-c-apis)): `PyUnicode_AsDecodedObject/AsDecodedUnicode/AsEncodedObject/AsEncodedUnicode`, `PyImport_ImportModuleNoBlock`, `PyWeakref_GetObject` / `PyWeakref_GET_OBJECT`, `PySys_ResetWarnOptions`, `Py_GetExecPrefix`, `Py_GetPath`, `Py_GetPrefix`, `Py_GetProgramFullPath`, `Py_GetProgramName`, `Py_GetPythonHome` (use `PyConfig_Get`).
- Build: the implicit fallback to the bundled libmpdec was removed ([Build changes](https://docs.python.org/3.15/whatsnew/3.15.html#build-changes)).

**New deprecations in 3.15** ([section](https://docs.python.org/3.15/whatsnew/3.15.html#new-deprecations)):

- `ast`: creating instances of abstract AST nodes (`ast.AST`, `ast.expr`) deprecated, error in 3.20
- `base64`: accepting `+` and `/` with an alternative alphabet in `b64decode()` / `urlsafe_b64decode()` deprecated
- `CLI`: `-b` and `-bb` deprecated, become no-ops in 3.17
- `collections.abc`: importing or accessing `ByteString` now emits DeprecationWarning (removal 3.17)
- `hashlib`: the `string=` keyword for initial data in hash constructors deprecated, removal 3.19
- `http.cookies`: `Morsel.js_output` and `BaseCookie.js_output` deprecated, removal 3.19
- `imaplib`: altering `IMAP4.file` deprecated, removal 3.19
- `profile`: the `profile` module is deprecated, removal 3.17; use `profiling.tracing` (PEP 799)
- `re`: `re.match()` / `Pattern.match()` soft deprecated in favour of the new `prefixmatch()`; no removal planned
- `struct`: `Struct.__new__()` without the required argument and calling `__init__` on an initialised `Struct` deprecated, removal 3.20; `F` / `D` type codes soft deprecated for `Zf` / `Zd`
- `typing`: importing or accessing `typing.ByteString` emits DeprecationWarning; `isinstance()` / `issubclass()` on protocol classes that inherit a runtime-checkable protocol without being decorated deprecated (TypeError in 3.20)
- `webbrowser`: `webbrowser.MacOSXOSAScript` deprecated for `webbrowser.MacOS`, removal 3.17
- `__version__`: the `__version__`, `version` and `VERSION` attributes deprecated (removal 3.20; use `sys.version_info`) in argparse, csv, ctypes, ctypes.macholib, decimal (use `decimal.SPEC_VERSION`), http.server, imaplib, ipaddress, json, logging (`__date__` too), optparse, pickle, platform, re, socketserver, tabnanny, tarfile, tkinter.font, tkinter.ttk, wsgiref.simple_server, xml.etree.ElementTree, xml.sax.expatreader, xml.sax.handler, zlib
- Soft deprecations ([section](https://docs.python.org/3.15/whatsnew/3.15.html#soft-deprecations)): `re.match()` / `re.Pattern.match()`, and the `F` / `D` codes of `struct`; "There are no plans to remove soft deprecated APIs".
- Deprecated C APIs ([section](https://docs.python.org/3.15/whatsnew/3.15.html#deprecated-c-apis)): PEP 456 external string-hash definition (`Py_HASH_EXTERNAL`, removal 3.19), out-of-range values for unsigned formats in `PyArg_ParseTuple`, `_PyObject_CallMethodId` / `_PyObject_GetAttrId` / `_PyUnicode_FromId` (removal 3.20), `PyComplexObject.cval`, `bytes_warning` (removal 3.17), `Py_MATH_El` / `Py_MATH_PIl` (removal 3.20), several `Py_*` / `PY_*` macros soft deprecated.

**Scheduled removals listed on the page** (what will stop working in later releases):

- [Python 3.16](https://docs.python.org/3.15/whatsnew/3.15.html#pending-removal-in-python-3-16): setting `__loader__` without `__spec__.loader` (the import system will stop using `__loader__`); `array` format code `u`; `asyncio.iscoroutinefunction()`; the asyncio policy system (`AbstractEventLoopPolicy`, `DefaultEventLoopPolicy`, Windows selector/proactor policies, `get_event_loop_policy()`, `set_event_loop_policy()`; use `asyncio.run(..., loop_factory=...)`); `~True` / `~False`; `functools.reduce` with keyword arguments in the Python implementation; `logging` handlers with a `strm` argument; undotted extensions in `mimetypes.MimeTypes.add_type()` (ValueError); `shutil.ExecError`; `symtable.Class.get_methods`; `sys._enablelegacywindowsfsencoding()`; `sysconfig.expand_makefile_vars()`; the `TarFile.tarfile` attribute.
- [Python 3.17](https://docs.python.org/3.15/whatsnew/3.15.html#pending-removal-in-python-3-17): `datetime.strptime()` with `%e` and no year; `collections.abc.ByteString` and `typing.ByteString`; non-ASCII names to `encodings.normalize_encoding()`; the `profile` module; `webbrowser.MacOSXOSAScript`; the private `typing._UnionGenericAlias`; `tkinter.Variable.trace_variable()`, `trace()`, `trace_vdelete()`, `trace_vinfo()`; `-b` / `-bb` become no-ops.
- [Python 3.18](https://docs.python.org/3.15/whatsnew/3.15.html#pending-removal-in-python-3-18): booleans accepted where a file descriptor is expected; the `N` format specifier of `decimal.Decimal`; PEP 829: `import` lines in `name.pth` files silently ignored.
- [Python 3.19](https://docs.python.org/3.15/whatsnew/3.15.html#pending-removal-in-python-3-19): implicit MSVC-compatible struct layout from `_pack_` without `_layout_` on non-Windows (ctypes); `hashlib` `string=` keyword; `http.cookies` `js_output`; altering `IMAP4.file`; C API: external hash scheme.
- [Python 3.20](https://docs.python.org/3.15/whatsnew/3.15.html#pending-removal-in-python-3-20): `struct.Struct.__new__()` without format / `__init__` on initialised objects; the `__version__` attributes listed above; PEP 829 warnings for `import` lines in `.pth` files and `.pth` files no longer decoded in the locale encoding (must be utf-8-sig); instantiating abstract AST nodes; `isinstance()` on undecorated protocol subclasses (TypeError).
- [Future versions, no date](https://docs.python.org/3.15/whatsnew/3.15.html#pending-removal-in-future-versions): nested argparse groups, `argparse.FileType`; 3-argument `throw()` / `athrow()`; numeric literals immediately followed by keywords (`0in x`); `__index__` / `__int__` / `__float__` / `__complex__` returning subclasses; complex numbers as `real` / `imag` of `complex()`; `calendar.January` / `February`; `codecs.open()`; `codeobject.co_lnotab`; `datetime.utcnow()` / `utcfromtimestamp()`; `gettext` non-integer plural; `importlib.util.cache_from_source` `debug_override`; `importlib.metadata` EntryPoints tuple interface; `logging.warn()`; `mailbox` StringIO/text mode; `os.register_at_fork()` in multi-threaded processes; `os.path.commonprefix()`; `re` strictness for group references and names; `shutil.rmtree` `onerror`; `ssl.SSLContext()` without protocol, NPN, the `OP_NO_SSL*` / `OP_NO_TLS*` options and `PROTOCOL_*` constants; `threading` camelCase methods (`notifyAll`, `isSet`, `isDaemon`, `setDaemon`, `getName`, `setName`, `currentThread`, `activeCount`); `typing.Text`; `unittest.IsolatedAsyncioTestCase` non-None return; the `urllib.parse` `split*()` functions and `to_bytes()`; `wsgiref` partial writes; truth value of `xml.etree.ElementTree.Element`; `sys._clear_type_cache()`.

**Behaviour changes in 3.15 outside the "Removed" list** (listed because they can break working scripts):

- [UTF-8 is the default encoding](https://docs.python.org/3.15/whatsnew/3.15.html#whatsnew315-utf8-default) (PEP 686): `open(path)` without `encoding=` now uses UTF-8 whatever the locale; `encoding="locale"` keeps the old behaviour; `PYTHONUTF8=0` or `-X utf8=0` restores it.
- [`__cached__` no longer set](https://docs.python.org/3.15/whatsnew/3.15.html#other-language-changes): the module attribute (deprecated since 3.13) is no longer set or used by the import system or stdlib; use `__spec__.cached`; `__loader__` and `__package__` are also deprecated and scheduled for removal.
- [PEP 829 `.start` files](https://docs.python.org/3.15/whatsnew/3.15.html#whatsnew315-startup-files): `import` lines in `.pth` files are silently deprecated and ignored when a matching `.start` file exists.
- [Frame pointers enabled by default](https://docs.python.org/3.15/whatsnew/3.15.html#whatsnew315-frame-pointers) (PEP 831); `--without-frame-pointers` opts out of the build default.
- [tarfile](https://docs.python.org/3.15/whatsnew/3.15.html#tarfile): stricter extraction (symlink target normalisation in `data_filter()`, filters re-applied when substituting links, new `LinkFallbackError`, rejected members no longer extracted when `errorlevel()` is zero).
- [venv](https://docs.python.org/3.15/whatsnew/3.15.html#venv): on POSIX, `platlib` directories are created instead of the `lib64 -> lib` symlink.
- [Porting to Python 3.15](https://docs.python.org/3.15/whatsnew/3.15.html#porting-to-python-3-15): `sqlite3.connect()` parameters other than `database` keyword-only and positional-only first parameters of several `Connection` methods; `resource.RLIM_INFINITY` always positive; `mmap.mmap.resize()` removed on platforms without the syscall; ResourceWarning for an unclosed `xml.etree.ElementTree.iterparse()` that opened a file; `argparse` infers `dest` from a single-dash long option; padding no longer required in `base64.urlsafe_b64decode()`; `unittest` `assertWarns()` / `assertWarnsRegex()` no longer swallow non-matching warnings.
- Headline new features (for orientation): [explicit lazy imports (PEP 810)](https://docs.python.org/3.15/whatsnew/3.15.html#pep-810-explicit-lazy-imports), [`frozendict` (PEP 814)](https://docs.python.org/3.15/whatsnew/3.15.html#pep-814-add-frozendict-built-in-type), [`sentinel` (PEP 661)](https://docs.python.org/3.15/whatsnew/3.15.html#pep-661-add-sentinel-built-in-type), [unpacking in comprehensions (PEP 798)](https://docs.python.org/3.15/whatsnew/3.15.html#pep-798-unpacking-in-comprehensions), [`profiling` package and the Tachyon sampling profiler (PEP 799)](https://docs.python.org/3.15/whatsnew/3.15.html#pep-799-a-dedicated-profiling-package), [stable ABI for free-threaded builds (PEP 803)](https://docs.python.org/3.15/whatsnew/3.15.html#pep-803-stable-abi-for-free-threaded-builds), the upgraded experimental JIT, more colour in command-line tools.

## 5. Facts from the F45 repositories and docs that touch this PC

### 5.1 Third-party repositories configured on this PC, checked for Fedora 45 on 2026-11-01

`/etc/yum.repos.d` here holds: fedora, fedora-updates, fedora-updates-testing, fedora-cisco-openh264 (all from fedora-repos-44-2), rpmfusion-free and rpmfusion-nonfree (+ updates, updates-testing) from rpmfusion-{free,nonfree}-release-44-3, brave-browser, claude-code, and the COPRs ilyaz/LACT and zzahkaboom24/grub-btrfs. `/etc/dnf/repos.override.d/99-config_manager.repo` sets `skip_if_unavailable=1` for brave-browser, claude-code and the two COPRs.

| Repo | Uses `$releasever` | Result for 45 (HTTP 200 = served) |
|---|---|---|
| fedora, updates | yes | `repo=fedora-45` and `repo=updates-released-f45` metalinks load (see section 1) |
| fedora-cisco-openh264 | yes | `https://mirrors.fedoraproject.org/metalink?repo=fedora-cisco-openh264-45&arch=x86_64` 200 |
| rpmfusion-free / nonfree | yes | `repo=free-fedora-45` and `repo=nonfree-fedora-45` 200 |
| rpmfusion-free-updates / nonfree-updates | yes | `repo=free-fedora-updates-released-45` and `repo=nonfree-fedora-updates-released-45` 200 (66 and 78 mirror URLs; "both f45 repos are empty for now" per bug 7565 comment 7). These returned HTTP 404 while F45 was a branched pre-release, see below |
| COPR ilyaz/LACT, zzahkaboom24/grub-btrfs | yes (`fedora-$releasever-$basearch`) | `.../fedora-45-x86_64/repodata/repomd.xml` 200 for both |
| brave-browser, claude-code | no | release independent (`.../$basearch`, `.../rpm/stable`) |

- **RPM Fusion bug 7565** ([Branched releases: metalink for `*-fedora-updates-released-<ver>` returns HTTP 404 instead of an empty repo, aborting upgrades for users with the repo enabled](https://bugzilla.rpmfusion.org/show_bug.cgi?id=7565)): reported 2026-10-12 against F45; the reporter writes that on dnf this is "a noisy but survivable repo-refresh failure" while on rpm-ostree it aborts the whole transaction. Comments: 2026-10-12 leigh scott (CC): "Updates repo should be disabled until release!"; 2026-10-13 Nicolas Chauvet (assignee): "This is right, but it doesn't mean we cannot have an empty repo for f45 as fedora does."; 2026-10-16 assignee: "Empty repos are in place. Now it can be picked-up by mirror-manager at some point..."; 2026-10-27 assignee: "This seems fixed on the mirrormanager side. Can you confirm ? At least both f45 repos are empty for now." Bug status ASSIGNED. My check on 2026-11-01: both metalinks answer 200.
- In the same bug, comment 1 (by the reporter, not a maintainer statement) says repo files left in /etc/yum.repos.d by older release packages stay unowned and take precedence over /usr/share/dnf5/repos.d, and that `dnf config-manager setopt <repo>.enabled=1` writes /etc/dnf/repos.override.d/99-config_manager.repo which silently overrides packaged `enabled=` values. The [Beta announcement thread](https://discussion.fedoraproject.org/t/announcing-fedora-linux-45-beta/202126/14) (2026-09-18, a user) reports an rpm-ostree rebase failing on the same 404 and on missing /etc/pki/rpm-gpg/RPM-GPG-KEY-rpmfusion-*-fedora-45 files.
- Verified in the RPM Fusion F45 packages ([free](https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-45.noarch.rpm), [nonfree](https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-45.noarch.rpm), both 45-0.2, built 2026-08-12): they still install `/etc/yum.repos.d/rpmfusion-*.repo` and `/etc/pki/rpm-gpg/RPM-GPG-KEY-rpmfusion-*-fedora-{2020,45,46,47,latest,rawhide}`. The release-44-3 packages installed here already contain the key links for 44, 45, 46, latest and rawhide, so `gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-rpmfusion-free-fedora-$releasever` resolves for 45 on this PC. The F45 `fedora-repos-45-1` no longer puts anything in /etc/yum.repos.d (section 2, Relocate RPM repository configs).
- **Transient mesa skew on 2026-11-01**: RPM Fusion `mesa-va-drivers-freeworld` and `mesa-vulkan-drivers-freeworld` 26.2.6-1.fc45 (repo rpmfusion-free) require `mesa-filesystem(x86-64) = 26.2.6` and `libLLVM.so.23.1`, while Fedora F45 stable (`updates`) has mesa-filesystem / mesa-dri-drivers 26.2.5-1.fc45 and only `updates-testing` has 26.2.6-1.fc45. On F44 both sides are 26.2.5. The reporter of the bug above also mentions a "mesa/freeworld version-skew depsolve" failing a rebase.

### 5.2 Official upgrade instructions (docs, page version F44, last review 2026-04-29)

Source: [Upgrading Fedora Linux Using DNF System Plugin](https://docs.fedoraproject.org/en-US/quick-docs/upgrading-fedora-offline/).

- Sequence: `sudo dnf upgrade --refresh` and reboot ("Do not skip this step. System updates are required to receive signing keys of higher-versioned releases"); `sudo dnf system-upgrade download --releasever=N`; `sudo dnf offline reboot` (cancel with `sudo dnf offline clean`); the system reboots into the upgrade environment and then once more into the new release. The `dnf system-upgrade` command is embedded in DNF5.
- "You can also use 45 to upgrade to a Branched release, or rawhide to upgrade to Rawhide." "System upgrade is only officially supported and tested over 2 releases at most."
- "If some of your packages have unsatisfied dependencies, the upgrade will refuse to continue until you run it again with an extra --allowerasing option. This often happens with packages installed from third-party repositories for which an updated repository hasn't been yet published." `--best` shows more detail; `--setopt=keepcache=1` keeps the download cache across manual operations.
- Post-upgrade tasks listed: `rpmconf -a` for .rpmnew / .rpmsave files ("Some third-party packages drop edited configuration files in /etc/yum.repos.d/ and reverting these files to their original versions may disable updates for the software"); `remove-retired-packages [old release]`; `dnf repoquery --duplicates`; `dnf list --extras`; `dnf autoremove`; old kernel clean-up; `clean-rpm-gpg-pubkey`; dangling symlinks (`symlinks -r /usr`); rescue kernel regeneration; on BIOS systems the bootloader is not updated automatically.

### 5.3 kmscon as the default VT console (facts for a desktop that starts from greetd)

Sources: [Change page](https://fedoraproject.org/wiki/Changes/UseKmsconVTConsole), [Fedora Magazine, 2026-10-19, Jocelyn Falempe](https://fedoramagazine.org/modernizing-the-console-with-kmscon/), Common Issues threads [202025](https://discussion.fedoraproject.org/t/202025) and [201254](https://discussion.fedoraproject.org/t/201254).

- kmscon replaces the default console for tty1 to tty6 in F45; `autovt@.service` points to `kmsconvt@.service`; the page says installation and the boot process (for example the encryption password fallback) are not affected because fbcon stays compiled into the kernel, and a VT can be kept on fbcon with `sudo systemctl mask kmsconvt@tty5 && sudo systemctl enable --now getty@tty5`.
- kmscon uses pseudo-terminals (`tty` prints /dev/pts/N) and "the exclusive drm interface to the GPU": a graphical session or GPU program started from such a console does not work as it did with fbcon unless started through `kmscon-launch-gui` (e.g. `kmscon-launch-gui startx`).
- `setfont` and `loadkeys` have no effect; kmscon follows `localectl` (D-Bus) for the keyboard layout and uses X-style layout configuration (Common Issues 201254: switched layouts need XkbOptions in /etc/X11/xorg.conf.d/00-keyboard.conf; marked fixed by an update on 2026-09-23). Config file /etc/kmscon/kmscon.conf (example next to it); fonts must be under /usr/share/fonts because kmscon runs as root; `dpms-timeout` defaults to 600 s; sub-packages kmscon (built-in unifont), kmscon-freetype, kmscon-pango (deprecated), kmscon-gl.
- Common Issues 202025 (2026-09-14): reboot/poweroff in the console without authentication failed for regular users because SELinux blocked calls so that kmscon "thinks this is not a local session" (Bugzilla 2533000); marked fixed by an update on 2026-09-23.

### 5.4 systemd 259.10 (here) to 262.1 (F45): "Feature Removals and Incompatible Changes" in upstream NEWS

Source: [systemd NEWS](https://github.com/systemd/systemd/blob/main/NEWS) sections "CHANGES WITH 260 / 261 / 262". Selection of items touching units, timers, udev, journald, logind and nspawn (the sections contain more).

- v260: support for System V service scripts removed (`systemd-sysv-generator`, `systemd-rc-local-generator` with `rc-local.service`, `systemd-sysv-install`); libidn support removed (libidn2 needed); kernel baseline raised from 5.4 to 5.10 (recommended 5.14, 6.6 for full functionality); non-system users/groups in udev rules and networkd restored but deprecated with warnings; the `org.freedesktop.login1.Manager` methods `CanPowerOff()`, `CanReboot()`, `CanSuspend()` ... gained new return values (`inhibited`, `inhibitor-blocked`, `challenge-inhibitor-blocked`) that "may break downstream consumers such as desktop environments".
- v261: `systemd-nspawn --user=NAME` renamed `--uid=NAME` (old form accepted with a deprecation warning; bare `--user` now selects the user service manager scope); udev database version 0 support removed; libsystemd no longer guaranteed to link libm.
- v262: `Type=notify-reload` services must catch or block `ReloadSignal=` when sending `READY=1` or fail to start; `UnsetEnvironment=` now applies after expansion of `ExecStart=` command lines; manager rate-limit timers (`StartLimitIntervalSec=`) use CLOCK_BOOTTIME (suspend time counts); `journalctl -F` is rejected together with filters (unit, boot, time, cursor, grep) that used to be silently ignored; the legacy udev control socket is replaced by a symlink to the Varlink socket (`udevadm` uses Varlink); `systemd-sysupdate.service` / `.timer` renamed `systemd-sysupdate-update.service` / `.timer` (compatibility symlinks); DNS-SD services registered over resolved's D-Bus API are withdrawn when the client disconnects; `PrivateUsersOwnership=` in .nspawn defaults to `auto`; default OpenPGP keyring lookup now merges /usr and /etc keyrings.
- Announced for v263: removal of `/run/boot-loader-entries/` support in logind and of the experimental `systemd-sysupdated` D-Bus API.

### 5.5 Known issues recorded for F45

- Fedora Discussion, Common Issues, tag f45 ([list](https://discussion.fedoraproject.org/tags/c/ask/common-issues/82/none/f45/1452), 17 topics on 2026-11-01). Written for the F45 Beta: [202025](https://discussion.fedoraproject.org/t/202025) reboot/poweroff no longer work without authentication in the console for regular users (kmscon + SELinux; marked fixed by an update on 2026-09-23); [201254](https://discussion.fedoraproject.org/t/201254) switched keyboard layouts are not enabled in the console in Workstation (kmscon; marked fixed by an update); [201696](https://discussion.fedoraproject.org/t/201696) Cosmic spin fails to start into a graphical session; [202294](https://discussion.fedoraproject.org/t/202294) boot fails after repeated installations on firmware RAID using the GTK installer; [201648](https://discussion.fedoraproject.org/t/201648) Sugar on a Stick installer does not start. Older topics also tagged f45: [192286](https://discussion.fedoraproject.org/t/192286) upgrading to Fedora 44 breaks the Nvidia driver for older GPUs (GeForce 10xx and older); [72635](https://discussion.fedoraproject.org/t/72635) Windows with encrypted disks (Bitlocker) cannot be booted from the GRUB menu; [73577](https://discussion.fedoraproject.org/t/73577) clipboard not shared with KDE virtual machines; [108478](https://discussion.fedoraproject.org/t/108478) install media sometimes fail the media check at 4.8%; [92403](https://discussion.fedoraproject.org/t/92403) dnf system-upgrade can fail on Raspberry Pi; [89052](https://discussion.fedoraproject.org/t/89052) hard to reformat a btrfs partition or subvolume in the installer; [148562](https://discussion.fedoraproject.org/t/148562) root mount options ignored in Fedora Atomic Desktops 42 and later; [147276](https://discussion.fedoraproject.org/t/147276) installs to Intel-based Macs lack full Fedora customizations; [183548](https://discussion.fedoraproject.org/t/183548) input methods not handled by KDE initial setup; [183547](https://discussion.fedoraproject.org/t/183547) switched keyboard layout limitations in GNOME and KDE live installs; [74711](https://discussion.fedoraproject.org/t/74711) About the Common Issues category; [201707](https://discussion.fedoraproject.org/t/201707) "Additional list of important bugs for the upcoming Fedora 45 release" (points to Proposed Common Issues and the blocker bug lists).
- Go/No-Go blocker reviews ([2026-10-22](https://meetbot.fedoraproject.org/meeting_matrix_fedoraproject-org/2026-10-22/f45-final-go-no-go-meeting.2026-10-22-17.00.html), [2026-10-29](https://meetbot.fedoraproject.org/meeting_matrix_fedoraproject-org/2026-10-29/f45-final-go-no-go-meeting.2026-10-29-18.02.html)): 2556376 compromised eMudhra certificate in ca-certificates (accepted blocker; on 2026-10-22 judged "not sufficiently addressed" in RC2; on 2026-10-29 the minutes say "All blockers have been addressed. RC-1.4 is the compose that will be reviewed"); 2543511 Stratis encrypted pool fails to boot (accepted blocker, fixed in RC-1.4); 2552449 encrypted Stratis root drops to emergency mode (rejected as blocker); 2545809 no network interface configured via `ip=` in a Beta installation (rejected as blocker); 2558595 ssh passphrase not unlocked at login after upgrade from F44, oo7 (rejected as blocker, accepted as freeze exception, fix in the RCs); 2560819 after F44 to F45 `CreateItem(replace=true)` fails to replace Online Accounts migrated from gnome-keyring, oo7 (accepted blocker; "removing and recreating the affected account works" was judged sufficient); 2560255 selinux-policy update breaks SSH port forwarding (rejected as blocker, "can be fixed with an update"); 2544671 aarch64 Server boot image too large (accepted, addressed by raising the size limit).

### 5.6 The repo's own package manifest against the F45 repos

`lib/manifest.sh` (its header says names were verified for F44 and F45 on 2026-10-14) was re-checked on 2026-11-01 by sourcing it and querying every name in the PKG_* arrays against the F45 repos with fedora, updates, rpmfusion-free(+updates), rpmfusion-nonfree(+updates), fedora-cisco-openh264, brave-browser, claude-code and the two COPRs enabled for 45 (and the same for 44).

189 package names in lib/manifest.sh; present in the F45 repos: 189; present in the F44 repos: 189; same upstream version in both (only the release suffix may differ): 138; upstream version differs: 51.

| Package | F44 repos | F45 repos | Repo (F44 -> F45) |
|---|---|---|---|
| bash-completion | 2.17-2.fc44 | 2.18-1.fc45 | fedora -> fedora |
| dconf | 0.49.0-5.fc44 | 51.0-1.fc45 | fedora -> fedora |
| ffmpeg | 8.1.3-1.fc44 | 9.0.2-1.fc45 | rpmfusion-free-updates -> rpmfusion-free |
| file | 5.46-10.fc44 | 5.48-3.fc45 | updates -> fedora |
| fontconfig | 2.17.0-4.fc44 | 2.18.3-2.fc45 | fedora -> fedora |
| foot | 1.27.0-1.fc44 | 1.28.0-1.fc45 | updates -> fedora |
| gdk-pixbuf2-devel | 2.44.6^really2.44.4-3.fc44 | 2.44.8-3.fc45 | updates -> fedora |
| ghostscript | 10.06.0-3.fc44 | 10.07.1-3.fc45 | updates -> updates |
| glib2 | 2.88.4-1.fc44 | 2.90.1-1.fc45 | updates -> updates |
| google-noto-kufi-arabic-fonts | 20251201-2.fc44 | 20260601-3.fc45 | fedora -> fedora |
| google-noto-naskh-arabic-fonts | 20251201-2.fc44 | 20260601-3.fc45 | fedora -> fedora |
| google-noto-sans-fonts | 20251201-2.fc44 | 20260601-3.fc45 | fedora -> fedora |
| gtk4 | 4.22.5-2.fc44 | 4.24.1-1.fc45 | updates -> fedora |
| gtk-layer-shell | 0.10.0-1.fc44 | 0.10.1-2.fc45 | fedora -> fedora |
| intel-media-driver | 26.1.5-1.fc44 | 26.3.5-1.fc45 | rpmfusion-nonfree-updates -> rpmfusion-nonfree |
| jq | 1.8.1-3.fc44 | 1.8.2-5.fc45 | updates -> fedora |
| libadwaita | 1.9.4-1.fc44 | 1.10.0-2.fc45 | updates -> fedora |
| libheif-freeworld | 1.23.6-1.fc44 | 1.23.5-1.fc45 | rpmfusion-free-updates -> rpmfusion-free |
| libinput-devel | 1.31.3-1.fc44 | 1.32.0-1.fc45 | updates -> fedora |
| libreoffice-calc | 26.2.6.3-1.fc44 | 26.8.2.2-2.fc45 | updates -> updates |
| libreoffice-gtk3 | 26.2.6.3-1.fc44 | 26.8.2.2-2.fc45 | updates -> updates |
| libreoffice-impress | 26.2.6.3-1.fc44 | 26.8.2.2-2.fc45 | updates -> updates |
| libreoffice-writer | 26.2.6.3-1.fc44 | 26.8.2.2-2.fc45 | updates -> updates |
| libva-utils | 2.23.0-2.fc44 | 2.24.0-2.fc45 | fedora -> fedora |
| libvirt-daemon-kvm | 12.0.0-5.fc44 | 12.6.0-2.fc45 | updates -> fedora |
| mesa-va-drivers-freeworld | 26.2.5-1.fc44 | 26.2.6-1.fc45 | rpmfusion-free-updates -> rpmfusion-free |
| meson | 1.11.2-1.fc44 | 1.12.1-2.fc45 | updates -> updates |
| NetworkManager | 1.56.1-2.fc44 | 1.58.1-3.fc45 | updates -> fedora |
| NetworkManager-tui | 1.56.1-2.fc44 | 1.58.1-3.fc45 | updates -> fedora |
| nodejs24-npm-bin | 24.18.0-1.fc44 | 11.16.0-1.24.18.0.4.fc45 | updates -> fedora |
| pango-devel | 1.57.1-1.fc44 | 1.58.2-1.fc45 | fedora -> fedora |
| plymouth-plugin-script | 24.004.60-24.fc44 | 26.134.222-6.fc45 | fedora -> fedora |
| podman | 5.8.9-1.fc44 | 6.1.3-1.fc45 | updates -> fedora |
| poppler-utils | 26.01.0-3.fc44 | 26.08.0-1.fc45 | fedora -> fedora |
| python3 | 3.14.8-1.fc44 | 3.15.0-1.fc45 | updates -> fedora |
| python3-gobject | 3.56.3-1.fc44 | 3.58.1-6.fc45 | updates -> updates |
| python3-twisted | 25.5.0-6.fc44 | 26.4.0-3.fc45 | fedora -> fedora |
| python3-twisted+tls | 25.5.0-6.fc44 | 26.4.0-3.fc45 | fedora -> fedora |
| qalculate | 5.9.0-1.fc44 | 5.11.0-3.fc45 | fedora -> fedora |
| qemu-img | 10.2.2-1.fc44 | 11.1.2-1.fc45 | fedora -> fedora |
| qpdf | 12.3.2-1.fc44 | 12.4.2-1.fc45 | fedora -> updates |
| rocm-smi | 7.1.1-4.fc44 | 7.2.1-4.fc45 | updates -> fedora |
| rpmfusion-free-release | 44-3 | 45-0.2 | rpmfusion-free-updates -> rpmfusion-free |
| rpmfusion-nonfree-release | 44-3 | 45-0.2 | rpmfusion-nonfree-updates -> rpmfusion-nonfree |
| systemd-container | 259.10-1.fc44 | 262.1-1.fc45 | updates -> updates |
| systemd-devel | 259.10-1.fc44 | 262.1-1.fc45 | updates -> updates |
| tesseract | 5.5.3-2.fc44 | 5.5.4-1.fc45 | updates -> updates |
| uv | 0.12.24-1.fc44 | 0.13.5-3.fc45 | updates -> updates |
| vulkan-loader | 1.4.341.0-1.fc44 | 1.4.350.0-2.fc45 | fedora -> fedora |
| wl-clipboard | 2.2.1^git20251124.e808203-2.fc44 | 2.3.0-2.fc45 | fedora -> fedora |
| xdg-user-dirs | 0.18-11.fc43 | 0.20-2.fc45 | fedora -> fedora |

## 6. Sources (index)

- [F45 ChangeSet](https://fedoraproject.org/wiki/Releases/45/ChangeSet)
- [Category:ChangeAcceptedF45](https://fedoraproject.org/wiki/Category:ChangeAcceptedF45)
- [F45 schedule](https://fedorapeople.org/groups/schedule/f-45/f-45-key-tasks.html)
- [F44 schedule](https://fedorapeople.org/groups/schedule/f-44/f-44-key-tasks.html)
- [F46 schedule](https://fedorapeople.org/groups/schedule/f-46/f-46-key-tasks.html)
- [docs.fedoraproject.org releases/f45](https://docs.fedoraproject.org/en-US/releases/f45/)
- [Release life cycle](https://docs.fedoraproject.org/en-US/releases/lifecycle/)
- [Upgrading Fedora Linux Using DNF System Plugin](https://docs.fedoraproject.org/en-US/quick-docs/upgrading-fedora-offline/)
- [F45 release notes draft (forge, branch f45)](https://forge.fedoraproject.org/docs/release-notes/src/branch/f45)
- [Announcing Fedora Linux 45 Beta](https://fedoramagazine.org/announcing-fedora-linux-45-beta/)
- [Modernizing the console with kmscon](https://fedoramagazine.org/modernizing-the-console-with-kmscon/)
- [Go/No-Go 2026-10-15](https://meetbot.fedoraproject.org/meeting_matrix_fedoraproject-org/2026-10-15/f45-final-go-no-go-meeting.2026-10-15-17.00.html)
- [Go/No-Go 2026-10-22](https://meetbot.fedoraproject.org/meeting_matrix_fedoraproject-org/2026-10-22/f45-final-go-no-go-meeting.2026-10-22-17.00.html)
- [Go/No-Go 2026-10-29](https://meetbot.fedoraproject.org/meeting_matrix_fedoraproject-org/2026-10-29/f45-final-go-no-go-meeting.2026-10-29-18.02.html)
- [Common Issues tag f45](https://discussion.fedoraproject.org/tags/c/ask/common-issues/82/none/f45/1452)
- [RPM Fusion bug 7565](https://bugzilla.rpmfusion.org/show_bug.cgi?id=7565)
- [What's New in Python 3.15](https://docs.python.org/3.15/whatsnew/3.15.html)
- [PEP 790 (Python 3.15 schedule)](https://peps.python.org/pep-0790/)
- [systemd NEWS](https://github.com/systemd/systemd/blob/main/NEWS)
- [Changes/ShadowStack](https://fedoraproject.org/wiki/Changes/ShadowStack)
