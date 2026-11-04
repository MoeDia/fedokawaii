# Learn piece, ready to place (T50, T63): installing from the ISO

## Installing fedokawaii from the stick

You need: a stick of 2 GB or more, a wired network, a disk inside the PC of 60 GB or more, UEFI on.
The stick is erased, and the disk you choose is erased: everything on it.

**Before anything:** Super+U → backups → before you wipe. Your folders, keys, browser and progress go to a
drive, read back and checked. "safe to wipe" means just that. Keep that drive apart from the stick.

**The stick:** write the release's `fedokawaii-DATE.iso` to it, whole:
`sudo dd if=fedokawaii-DATE.iso of=/dev/sdX bs=4M oflag=direct status=progress` (`lsblk` shows which sdX it is).

**The install:**

1. Start from the stick (the firmware's boot menu: F12 on most boards). The firmware's picture stays a few
   seconds while the system loads, then the menu: *install fedokawaii* starts by itself after 5 s.
   *check this stick, then install* first reads every file against the list made when the ISO was built.
2. One page of questions: your name, your password twice, the disk (only disks inside the PC are offered,
   never a USB drive; with several you must choose), time zone, keyboard (`F2` from any row, before you type
   a password), this PC's name. Then one confirmation that names the disk.
3. From there on nothing asks: the base system (minutes), a restart, then the desktop, through its own
   restarts, on one screen with a count of its steps. Take the stick out when you like; it is not needed
   after the first restart, and a PC that starts from it again says fedokawaii is installed, instead of
   offering to erase anything by accident (`i` on that page installs again, on purpose).
4. The login screen means it is done. Log in with the name and password you gave.

**Your things back:** plug in the drive. The first login notices it and tells you; Super+U → backups → bring back.

**What it refuses, and why:** a PC started without UEFI, less than 4 GB of memory, no disk of 60 GB inside the
PC, no wired network, a PC with an NVIDIA card alone (the desktop is built on AMD's and Intel's open drivers).
Each says so on one screen and turns the PC off: nothing has been touched.

**If it stops half way:** before the first restart, the screen says what failed and any key turns the PC off;
start again from the stick. After it, setup says what stopped it; any key restarts, and setup carries on from
there.

**What it is made of:** Fedora's own netinst, its signed shim, GRUB and kernel untouched, so Secure Boot works
as it comes. Packages come from Fedora's mirrors at install time, current to the day. `tools/build-iso.sh`
builds it again from the same pins to the same bytes.
