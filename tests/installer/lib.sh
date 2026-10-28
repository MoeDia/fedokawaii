#!/usr/bin/env bash
# tests/installer/lib.sh — what the installer's tests share: a fake Fedora 44 Server to run
# setup.sh, theme.sh, verify.sh and check.sh in, as root, without touching this machine.
#
#   world fresh|built       a fresh sandbox with a fake machine in $W: this machine's /etc copied
#                           (plus the desktop user fkuser, uid 31000, and Fedora's os-release), the
#                           project cloned in /home/fkuser/fedokawaii, and the fake Fedora's commands
#                           (tests/installer/stubs) as its /usr/local/bin. "fresh": just installed
#                           from the Server image (Minimal Install, UEFI, an AMD desktop on
#                           ethernet). "built": setup finished (and the theme applied, with --themed)
#   fk CMD…                 CMD as root inside the fake machine: a private mount namespace where
#                           /etc, /var/lib, /var/log, /var/tmp, /usr/local, /boot, /home, /root,
#                           /run, /dev, /sys/class, /sys/bus/pci, /sys/firmware, /sys/module and
#                           /proc/{cpuinfo,meminfo,cmdline} are the fake machine's own. (Not root:
#                           a user namespace with this user's subordinate ids, so fkuser is real.)
#   fkrun CMD…              fk, with its output (stdout + stderr, no colours) in $OUT, its status in $RC
#   the hardware: hw_amd · hw_apu · hw_intel · hw_nvidia · hw_hybrid · hw_vm · hw_nogpu · hw_wifi ·
#                 hw_laptop · hw_bios · hw_secureboot   (each replaces the GPU part, or adds)
#   pkg_has NAME · state FILE · fkh FILE [CONTENT] — the fake machine's records, read or set
# The fake Fedora's records are in $FKH ($W/var/lib/fkh): installed, available, userinstalled,
# files (what rpm -ql lists), units, calls.log (every stub's call: "user[command] args") —
# $CALLS, for called/not_called.
# Not root: the whole test file runs again inside a user namespace of this user's own ids, as
# its root — the fake machine needs root, and in there this machine's own files are out of
# reach (its root is not mapped: they are nobody's). A file that never makes a fake machine
# sets FK_PURE=1 first and runs as it is.
if ((EUID != 0)) && [[ -z ${FK_PURE:-} ]]; then
  if unshare --map-root-user --map-users=auto --map-groups=auto true 2>/dev/null; then
    exec unshare --map-root-user --map-users=auto --map-groups=auto bash "$0" "$@"
  fi
  printf '%s: skipped — the fake machine needs root, or user namespaces with subordinate ids (/etc/subuid)\n' "$(basename "$0" .sh)"
  exit 0
fi
. "$(dirname "${BASH_SOURCE[0]}")/../lib/harness.sh"
TI=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# This machine's accounts, measured now and again at the end: a test that changed them has
# written outside its fake machine — said loudly, and the test file fails. (Every link a test
# plants is relative and stays inside $W, so it leads to the fake machine's file inside the
# namespace and out here alike.)
HOST_FILES=(/etc/passwd /etc/group /etc/shadow /etc/sudoers)
host_sums() { local f; for f in "${HOST_FILES[@]}"; do [[ -r $f ]] && sha256sum "$f"; done; return 0; }
HOST_SUMS=$(host_sums)
host_guard() {
  local now; now=$(host_sums)
  [[ $now == "$HOST_SUMS" ]] && return 0
  printf '\n✘✘ THIS MACHINE CHANGED: %s— a test wrote outside its fake machine\n' "$(diff <(echo "$HOST_SUMS") <(echo "$now") | sed -n 's/^> [0-9a-f]*  //p' | tr '\n' ' ')" >&2
  return 1
}
# shellcheck disable=SC2034  # (OUT, RC, the pins and STUBS are read by the test files and the harness)
W="" FKH="" OUT="" RC=0
FK_UID=31000
conf_val() { sed -n "s/^$1=\"\\([^\"]*\\)\".*/\\1/p" "$REPO/fedokawaii.conf"; }
# shellcheck disable=SC2034
DWL_COMMIT=$(conf_val DWL_COMMIT) TFC_COMMIT=$(conf_val TFC_COMMIT)

# the commands inside the namespace: the fake machine mounted over this one's paths
# shellcheck disable=SC2016  # expanded by the inner bash
FK_INNER='set -e; W=$1; shift
  python3 -I -c "import fcntl, socket, struct; s = socket.socket(); f = struct.unpack(\"16sH14x\", fcntl.ioctl(s, 0x8913, struct.pack(\"16sH14x\", b\"lo\", 0)))[1]; fcntl.ioctl(s, 0x8914, struct.pack(\"16sH14x\", b\"lo\", f | 1))"   # (loopback up: SIOCSIFFLAGS)
  # /usr/bin and /usr/share: the fake machine'"'"'s own folders of links to this machine'"'"'s (kept
  # reachable under $W/.usr), so what a package adds or takes away there can differ
  # (read-only: nothing run in the fake machine can write through a link to this machine'"'"'s)
  mkdir -p "$W/.usr/bin" "$W/.usr/share"
  for d in bin share; do mount --bind "/usr/$d" "$W/.usr/$d"; mount -o remount,bind,ro "$W/.usr/$d"; done
  mount --bind "$W/usrbin" /usr/bin; mount --bind "$W/usrshare" /usr/share
  for d in etc var/lib var/log var/tmp usr/local boot home root; do mount --bind "$W/$d" "/$d"; done
  mount -t tmpfs -o mode=755 fkrun /run; mkdir -p /run/user /run/lock
  mount --bind "$W/sys/class" /sys/class; mount --bind "$W/sys/bus/pci" /sys/bus/pci
  mount --bind "$W/sys/firmware" /sys/firmware; mount --bind "$W/sys/module" /sys/module
  for f in cpuinfo meminfo cmdline; do mount --bind "$W/proc/$f" "/proc/$f"; done
  # /dev: the few real nodes every program needs, and the fake machine'"'"'s render nodes and
  # /dev/ntsync (character devices: /dev/null standing in)
  mkdir -p "$W/.dev"; mount --rbind /dev "$W/.dev"; mount -t tmpfs -o mode=755 fkdev /dev
  for n in null zero full random urandom tty; do : >"/dev/$n"; mount --bind "$W/.dev/$n" "/dev/$n"; done
  ln -s /proc/self/fd /dev/fd; ln -s fd/0 /dev/stdin; ln -s fd/1 /dev/stdout; ln -s fd/2 /dev/stderr
  mkdir -p /dev/shm /dev/dri; mount -t tmpfs fkshm /dev/shm
  # terminals of its own (verify starts herdr on one): a devpts instance of the fake machine'"'"'s
  mkdir -p /dev/pts; mount -t devpts -o newinstance,ptmxmode=0666,mode=620 fkpts /dev/pts && ln -s pts/ptmx /dev/ptmx
  for n in "$W"/dev/dri/* "$W"/dev/ntsync; do
    [[ -e $n ]] || continue; t=/dev/${n#"$W"/dev/}; : >"$t"; mount --bind "$W/.dev/null" "$t"
  done
  umount -l "$W/.dev"                       # (this machine'"'"'s /dev: no longer reachable from in here)
  if [[ -d /run/user && -d $W/runuser ]]; then mount --bind "$W/runuser" /run/user; fi
  set +e; cd /
  exec env -i PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin HOME=/root USER=root \
    LOGNAME=root TERM=dumb LANG=C.UTF-8 SUDO_USER=fkuser FK_W="$W" timeout 240 "$@"'
# (a network namespace of its own, only loopback in it: nothing run in the fake machine can
# reach the network — whatever program a script calls, by any path — and every download
# comes from the stubs)
fk() {
  local ns=(unshare -m -n --propagation private)
  ((EUID == 0)) || ns=(unshare --map-root-user --map-users=auto --map-groups=auto -m -n --propagation private)
  "${ns[@]}" bash -c "$FK_INNER" _ "$W" "$@"
}
# shellcheck disable=SC2034
fkrun() { OUT=$(fk "$@" 2>&1); RC=$?; OUT=$(sed 's/\x1b\[[0-9;]*m//g' <<<"$OUT"); }
# fk_plain CMD… — CMD with the fake machine's ids but none of its mounts (so $W/.usr and $W/.dev
# are the empty folders they are out here: never this machine's /usr/bin or /dev)
fk_plain() {
  if ((EUID == 0)); then "$@"; else unshare --map-root-user --map-users=auto --map-groups=auto "$@"; fi
}
# what the fake machine made with its own ids, given back to this user before it is removed
fk_clean() {
  [[ -n $W && -d $W ]] || return 0
  ((EUID == 0)) || fk_plain bash -c 'chown -R 0:0 "$1"; chmod -R u+rwX "$1"' _ "$W" 2>/dev/null
  return 0
}
# keep NAME · back NAME — the whole fake machine set aside, and put back as it was then
keep() { fk_plain bash -c 'rm -rf "$2"; cp -a "$1" "$2"' _ "$W" "$TMP/kept-$1" 2>/dev/null || cp -a "$W" "$TMP/kept-$1"; }
back() {
  [[ -d $TMP/kept-$1 ]] || { echo "harness: nothing kept as $1" >&2; return 1; }
  fk_plain bash -c 'rm -rf "$2" && cp -a "$1" "$2"' _ "$TMP/kept-$1" "$W"; : >"$CALLS"; chmod 666 "$CALLS"
}

# usr_farm — the fake /usr/bin and /usr/share: links to this machine's, without the editors and
# the like a Minimal Install does not have (the package hooks of the fake dnf add them back),
# and with the icon themes, Vulkan drivers and launcher entries Fedora's packages would bring
# (and a locale folder of its own: setup adds the lock screen's words, art/gtklock.mo)
usr_farm() {
  local b=$W/usrbin s=$W/usrshare n
  mkdir -p "$b" "$s"
  (cd /usr/bin && find . -mindepth 1 -maxdepth 1 -printf "$W/.usr/bin/%f\\0") | xargs -0 ln -s -t "$b"
  (cd /usr/share && find . -mindepth 1 -maxdepth 1 ! -name icons ! -name vulkan ! -name applications ! -name locale ! -name plymouth -printf "$W/.usr/share/%f\\0") | xargs -0 ln -s -t "$s"
  for n in vi vim view vimdiff nano emacs flatpak snap nvim agreety greetd gnome-shell steam; do rm -f "$b/$n"; done
  mkdir -p "$s/icons" "$s/applications" "$s/vulkan/icd.d" "$s/locale"
  for n in /usr/share/locale/*; do [[ $n == */fk ]] || ln -s "$W/.usr$n" "$s/locale/${n##*/}"; done   # (fk: the lock screen's, setup's own)
  mkdir -p "$s/plymouth/themes"   # (sumi: the boot splash, theme.sh's own — a machine that ran it has one)
  for n in /usr/share/plymouth/*; do [[ -e $n && $n != */themes ]] || continue; ln -s "$W/.usr$n" "$s/plymouth/${n##*/}"; done
  for n in /usr/share/plymouth/themes/*; do [[ -e $n && $n != */sumi ]] || continue; ln -s "$W/.usr$n" "$s/plymouth/themes/${n##*/}"; done
  for n in /usr/share/icons/*; do   # (Sumi-*: the pointers, setup's own — a machine that ran theme.sh has them)
    [[ $n == */Papirus* || $n == */Adwaita || $n == */Sumi-* ]] || ln -s "$W/.usr$n" "$s/icons/${n##*/}"
  done
}
fake_cmd() { printf '#!/bin/sh\nexit 0\n' >"$1"; chmod 755 "$1"; }
# fake_pylibs — the Python libraries Syncplay needs (Fedora's python3-twisted+tls, -pyOpenSSL,
# -certifi, -pem), as stand-ins this machine's python3 finds inside the fake machine: in its
# /usr/local site folder, which is the fake machine's own. (FK_PYLIBS: that folder, for a test)
fake_pylibs() {
  local pp m
  # (the folder Fedora's python3 reads under /usr/local: stubs/python3 keeps it read under -I)
  pp=$(python3 -I -c 'import sys; print("/usr/local/lib/python%d.%d/site-packages" % sys.version_info[:2])')
  FK_PYLIBS=$W$pp
  mkdir -p "$FK_PYLIBS/twisted/internet"
  for m in twisted/__init__ twisted/internet/__init__ certifi/__init__ pem/__init__ OpenSSL/__init__; do
    mkdir -p "$FK_PYLIBS/${m%/*}"; : >"$FK_PYLIBS/$m.py"
  done
  printf 'def optionsForClientTLS(*a, **k):\n    pass\n' >"$FK_PYLIBS/twisted/internet/ssl.py"
  # PyGObject and the typelibs the login screen and the panel ask for (lib/guard.sh: gi_sound);
  # $FKH/gi-broken: a namespace that no longer loads
  mkdir -p "$FK_PYLIBS/gi/repository"; : >"$FK_PYLIBS/gi/repository/__init__.py"
  printf 'def require_version(ns, v):\n    import os\n    if ns in open("/var/lib/fkh/gi-broken").read().split() if os.path.exists("/var/lib/fkh/gi-broken") else False:\n        raise ValueError("Namespace %%s not available" %% ns)\n' >"$FK_PYLIBS/gi/__init__.py"
  for m in $(grep -ohE 'require_version\("\w+"' "$REPO/system/kawa-greet" "$REPO/bin/kawa-panel" | cut -d'"' -f2 | sort -u); do
    : >"$FK_PYLIBS/gi/repository/$m.py"
  done
}

pkg_has() { grep -qxF -- "$1" "$FKH/installed"; }
state() { cat "$W/var/lib/fedokawaii/$1" 2>/dev/null; }
fkh() { if (($# > 1)); then printf '%s\n' "${@:2}" >"$FKH/$1"; else : >"$FKH/$1"; fi; chmod 666 "$FKH/$1"; }
fkh_add() { printf '%s\n' "${@:2}" >>"$FKH/$1"; }
fkh_del() { local f=$FKH/$1; shift; local p; for p; do grep -vxF -- "$p" "$f" >"$f.n"; cat "$f.n" >"$f"; rm -f "$f.n"; done; }

world() {   # world fresh|built [--themed]
  local kind=$1 themed=0
  [[ -z ${FK_PURE:-} && $EUID -eq 0 ]] || { echo "harness: a fake machine needs root (a file with FK_PURE=1 makes none)" >&2; exit 1; }
  [[ ${2:-} == --themed ]] && themed=1
  # one fake machine at a time across test files (two at once remove each other's kept trees);
  # taken once, held until this test file ends
  if [[ -z ${FK_WORLD_LOCKED:-} ]]; then
    exec 8>/tmp/kawa-installer-tests.lock
    if ! flock -n 8; then
      echo "harness: waiting for the installer-test lock (another installer test holds it) — not a hang" >&2
      flock 8
    fi
    FK_WORLD_LOCKED=1
  fi
  fk_clean; sandbox
  chmod 755 "$TMP"; chmod 666 "$CALLS"
  trap 'r=$?; fk_clean; [[ -n $TMP ]] && rm -rf "$TMP"; host_guard || exit 1; exit $r' EXIT
  W=$TMP/w FKH=$TMP/w/var/lib/fkh
  mkdir -p "$W"/{etc,var/lib/fedokawaii,var/lib/systemd/linger,var/log,var/tmp,boot/grub2,home,root,runuser,dev/dri,proc} \
    "$W"/usr/local/{bin,lib,sbin,libexec,share} "$W"/sys/{class/drm,bus/pci/devices,bus/pci/drivers,firmware,module/i2c_dev} "$FKH/dl"
  chmod 1777 "$W/var/tmp"
  echo vmlinuz >"$W/boot/vmlinuz-$(uname -r)"; echo initramfs >"$W/boot/initramfs-$(uname -r).img"   # (the running kernel, as the installer left it)
  # (owned by whoever makes the fake machine — its root: out here a user's own files may show as nobody's)
  cp -a --no-preserve=ownership /etc/. "$W/etc/" 2>/dev/null
  usr_farm
  fake_pylibs
  # the desktop user, an administrator; Fedora's os-release; GRUB's defaults
  sed -i '/^fkuser:/d; /^greetd:/d' "$W/etc/passwd" "$W/etc/group"
  echo "fkuser:x:$FK_UID:$FK_UID:Fk User:/home/fkuser:/bin/bash" >>"$W/etc/passwd"
  echo "fkuser:x:$FK_UID:" >>"$W/etc/group"
  if grep -q '^wheel:' "$W/etc/group"; then sed -i -E 's/^(wheel:[^:]*:[^:]*:)(.*)$/\1\2,fkuser/; s/^(wheel:[^:]*:[^:]*:),/\1/' "$W/etc/group"
  else echo "wheel:x:3010:fkuser" >>"$W/etc/group"; fi
  rm -f "$W/etc/os-release"
  # (as the installer's Custom Operating System writes it — the handbook's choice: no edition)
  printf '%s\n' 'NAME="Fedora Linux"' 'VERSION="44 (Forty Four)"' 'ID=fedora' 'VERSION_ID=44' \
    'PRETTY_NAME="Fedora Linux 44 (Forty Four)"' 'SUPPORT_END=2027-05-19' >"$W/etc/os-release"
  mkdir -p "$W/etc/default"
  printf '%s\n' 'GRUB_TIMEOUT=5' 'GRUB_DISTRIBUTOR="$(sed '"'"'s, release .*$,,g'"'"' /etc/system-release)"' \
    'GRUB_DEFAULT=saved' 'GRUB_DISABLE_SUBMENU=true' 'GRUB_TERMINAL_OUTPUT="console"' \
    'GRUB_CMDLINE_LINUX="rootflags=subvol=root rhgb quiet"' 'GRUB_DISABLE_RECOVERY="true"' \
    'GRUB_ENABLE_BLSCFG=true' >"$W/etc/default/grub"
  printf 'KEYMAP="us"\n' >"$W/etc/vconsole.conf"
  mkdir -p "$W/etc/plymouth"; printf '# Administrator customizations go in this file\n#[Daemon]\n#Theme=fade-in\n' >"$W/etc/plymouth/plymouthd.conf"   # (Fedora's)
  rm -rf "$W/etc/systemd/system/display-manager.service" "$W/etc/yum.repos.d" "$W/etc/dnf" "$W/etc/greetd"
  # (and whatever of this project the machine running the tests has in its own /etc)
  grep -rlisZ -e fedokawaii -e scriptorium "$W/etc" 2>/dev/null | xargs -0r rm -f
  # /proc: an 8-core AMD CPU, 32 GB, booted normally
  printf 'processor\t: 0\nvendor_id\t: AuthenticAMD\nmodel name\t: AMD Ryzen 7 7700\n' >"$W/proc/cpuinfo"
  printf 'MemTotal:       32768000 kB\nMemFree:        30000000 kB\n' >"$W/proc/meminfo"
  printf 'BOOT_IMAGE=(hd0,gpt2)/vmlinuz-6.19 root=UUID=x ro rootflags=subvol=root rhgb quiet\n' >"$W/proc/cmdline"
  mkdir -p "$W/sys/firmware/efi/efivars" "$W/sys/class/bluetooth/hci0"
  # the fake Fedora's commands, and the project as the user cloned it
  cp -a --no-preserve=ownership "$TI/stubs/." "$W/usr/local/bin/"
  mkdir -p "$W/home/fkuser/fedokawaii"
  (cd "$REPO" && tar --exclude=./docs --exclude=./tests --exclude=./.git -cf - .) | tar -xf - --no-same-owner -C "$W/home/fkuser/fedokawaii"
  printf '%s\n' "# .bashrc" 'if [ -d ~/.bashrc.d ]; then for rc in ~/.bashrc.d/*; do . "$rc"; done; fi' >"$W/home/fkuser/.bashrc"
  # what dwl's build needs of wlroots: its header folder and library (a real .so, so ldd reads it)
  mkdir -p "$W/usr/local/fkh-sys/include/wlroots-0.20/wlr" "$W/usr/local/fkh-sys/lib64"
  echo '/* wlroots */' >"$W/usr/local/fkh-sys/include/wlroots-0.20/wlr/backend.h"
  cp -L "$(ldconfig -p 2>/dev/null | awk '/libz\.so\.1 / { print $NF; exit }')" "$W/usr/local/fkh-sys/lib64/libwlroots-0.20.so" 2>/dev/null \
    || cp -L /lib/x86_64-linux-gnu/libz.so.1 "$W/usr/local/fkh-sys/lib64/libwlroots-0.20.so"
  # the package world: Fedora 44 Server's Minimal Install (UEFI: grubby is there), everything
  # the manifest names available, and the release's own firmware and drivers
  printf '%s\n' bash sudo NetworkManager kernel-core grub2-tools grubby dnf5 firewalld openssh-server \
    nano nano-default-editor vim-minimal dracut-config-rescue linux-firmware systemd >"$FKH/installed"
  printf '%s\n' bash sudo NetworkManager kernel-core grub2-tools grubby firewalld openssh-server nano \
    vim-minimal dracut-config-rescue | sed 's/$/ User/' >"$FKH/userinstalled"
  { ( STATE_DIR=/nonexistent STEAM=yes; . "$REPO/lib/manifest.sh"; manifest_all amd; manifest_all intel; printf '%s\n' "${FORBIDDEN_amd[@]}" )
    printf '%s\n' mesa-vulkan-drivers.i686 mesa-vulkan-drivers-freeworld mesa-vulkan-drivers-freeworld.i686 mesa-va-drivers-freeworld.i686 amd-ucode-firmware microcode_ctl \
      NetworkManager-wifi wireless-regdb alsa-sof-firmware iwlwifi-mvm-firmware realtek-firmware kernel-core
    cat "$FKH/installed"; } | sort -u >"$FKH/available"
  echo "iwlwifi-mvm-firmware /usr/lib/firmware/iwlwifi-so-a0-gf-a0-89.ucode.xz" >"$FKH/fwfiles"
  echo "rocm-smi /usr/lib64/librocm_smi64.so.1.0" >"$FKH/files"      # (rpm -ql: the library btop opens)
  printf '%s\n' "global-enabled pipewire.socket" "global-enabled pipewire-pulse.socket" "global-enabled wireplumber.service" \
    "global-enabled grub-boot-success.timer" \
    "enabled sshd.service" "active sshd.service" "enabled firewalld.service" "active firewalld.service" \
    "enabled fstrim.timer" "static dnf5-makecache.timer" >"$FKH/units"
  echo dnf5-makecache.timer >"$FKH/unitfiles"      # (Fedora 44's: static — on by its package's own link)
  fake_cmd "$W/usrbin/nano"; fake_cmd "$W/usrbin/vi"     # (nano, vim-minimal: in a Minimal Install)
  mkdir -p "$W/etc/grub.d"   # (grub2-tools, in a Minimal Install: Shift/Esc/F8 shows the hidden menu)
  printf '#!/bin/sh\n' >"$W/etc/grub.d/12_menu_auto_hide"; chmod 755 "$W/etc/grub.d/12_menu_auto_hide"
  printf '%s\n' "ethernet:connected" >"$FKH/nm-devices"
  printf '%s\n' "fedokawaii-setup-host" >/dev/null
  : >"$FKH/calls.log"; CALLS=$FKH/calls.log
  # shellcheck disable=SC2034  # (the harness's stub writes there: a test's own stand-in)
  STUBS=$W/usr/local/bin
  printf 'H264High\nHEVCMain\nAV1Profile0\n' | sed 's/^/      VAProfile/; s/$/   : VAEntrypointVLD/' >"$FKH/vainfo-renderD128"
  hw_amd
  [[ $kind == built ]] && built "$themed"
  fk_perms
}
# fedora_release N — the fake machine as Fedora N Server instead (44 as made): its os-release;
# from 45 on, kmscon (the core group's) drawing the consoles — `kmscon CMD…` runs CMD as a
# kmscon console's login does, under a parent process named kmscon
fedora_release() {
  sed -i -E "s/^VERSION=\"[0-9]+/VERSION=\"$1/; s/^VERSION_ID=.*/VERSION_ID=$1/; s/^PRETTY_NAME=\"Fedora Linux [0-9]+/PRETTY_NAME=\"Fedora Linux $1/" "$W/etc/os-release"
  if (($1 >= 45)); then
    pkg_has kmscon || fkh_add installed kmscon
    printf '#!/bin/bash\n"$@"\nexit $?\n' >"$W/usr/local/bin/kmscon"; chmod 755 "$W/usr/local/bin/kmscon"
  fi
}
reboot_world() {   # what a restart changes: the kernel's arguments as recorded; what loads at boot
  if [[ -s $FKH/grub-args ]]; then head -n1 "$FKH/grub-args" | sed 's|^|BOOT_IMAGE=(hd0,gpt2)/vmlinuz-6.19 root=UUID=x |' >"$W/proc/cmdline"; fi
  if pkg_has ntsync-autoload; then : >"$W/dev/ntsync"; fi
  return 0
}
fk_perms() {   # the fake machine's own ownership: the user's home is fkuser's; the stub records anyone's
  chmod -R a+rwX "$FKH"
  fk chown -R "$FK_UID:$FK_UID" /home/fkuser /run/user 2>/dev/null
  [[ -d $W/var/lib/fedokawaii-greeter ]] && fk chown "$FK_UID:$FK_UID" /var/lib/fedokawaii-greeter   # (setup gives it to you)
  if [[ -d $W/runuser/$FK_UID ]]; then fk chown -R "$FK_UID:$FK_UID" "/run/user/$FK_UID"; fi
  return 0
}

# ── hardware (sysfs, as the kernel shows it) ─────────────────────────────────────
gpu() {   # gpu CARD VENDOR DEVICE DRIVER [VRAM] — a display card with its render node and a connector
  local c=$1 v=$2 d=$3 drv=$4 vram=${5:-} n pci
  n=$((128 + ${c#card})); pci=0000:0$((3 + ${c#card})):00.0
  mkdir -p "$W/sys/class/drm/$c/device" "$W/sys/class/drm/renderD$n/device" "$W/sys/class/drm/$c-DP-1"
  echo "$v" >"$W/sys/class/drm/$c/device/vendor"; echo "$v" >"$W/sys/class/drm/renderD$n/device/vendor"
  ln -sfn "../$c" "$W/sys/class/drm/$c-DP-1/device"          # (a connector: its device is the card)
  echo connected >"$W/sys/class/drm/$c-DP-1/status"; printf '2560x1440\n1920x1080\n' >"$W/sys/class/drm/$c-DP-1/modes"
  [[ -n $vram ]] && echo "$vram" >"$W/sys/class/drm/$c/device/mem_info_vram_total"
  echo "PCI_SLOT_NAME=$pci" >"$W/sys/class/drm/$c/device/uevent"
  mkdir -p "$W/sys/bus/pci/devices/$pci" "$W/sys/bus/pci/drivers/$drv"
  printf '0x030000\n' >"$W/sys/bus/pci/devices/$pci/class"; echo "$v" >"$W/sys/bus/pci/devices/$pci/vendor"; echo "$d" >"$W/sys/bus/pci/devices/$pci/device"
  [[ $drv == none ]] || ln -sfn "../../drivers/$drv" "$W/sys/bus/pci/devices/$pci/driver"
  [[ $drv == none ]] || ln -sfn "../../../../bus/pci/drivers/$drv" "$W/sys/class/drm/$c/device/driver"
  : >"$W/dev/dri/renderD$n"
}
nogpu() { rm -rf "$W"/sys/class/drm/* "$W"/dev/dri/* "$W"/sys/bus/pci/devices/*; }
hw_amd()    { nogpu; gpu card0 0x1002 0x73df amdgpu 12868124672; }                    # Radeon RX 6700 XT, 12 GB
hw_apu()    { nogpu; gpu card0 0x1002 0x164e amdgpu 536870912; }                      # Ryzen 7000's own graphics, 512 MB carved out
hw_intel()  { nogpu; gpu card0 0x8086 0xa780 i915; sed -i 's/AuthenticAMD/GenuineIntel/' "$W/proc/cpuinfo"; }
hw_nvidia() { nogpu; gpu card0 0x10de 0x2684 nouveau; }
hw_hybrid() { nogpu; gpu card0 0x8086 0xa7a0 i915; gpu card1 0x10de 0x28e0 nouveau; sed -i 's/AuthenticAMD/GenuineIntel/' "$W/proc/cpuinfo"; }
hw_igpu_amd() { nogpu; gpu card0 0x8086 0xa780 i915; gpu card1 0x1002 0x73df amdgpu 12868124672; }  # a desktop with the CPU's own graphics on, beside its AMD card
hw_vm()     { nogpu; gpu card0 0x1af4 0x1050 virtio-pci; }                            # a virtual machine's virtio-gpu
hw_nogpu()  { nogpu; }
hw_wifi()   { mkdir -p "$W/sys/class/ieee80211/phy0"; }
hw_laptop() { mkdir -p "$W/sys/class/power_supply/BAT0" "$W/sys/class/backlight/amdgpu_bl0"; echo Battery >"$W/sys/class/power_supply/BAT0/type"
              mv "$W/sys/class/drm/card0-DP-1" "$W/sys/class/drm/card0-eDP-1"; }
hw_bios()   { rm -rf "$W/sys/firmware/efi"; fkh_del installed grubby; sed -i '/^grubby /d' "$FKH/userinstalled"; }
hw_secureboot() {   # Secure Boot on: the EFI variable's fifth byte is 1
  printf '\x06\x00\x00\x00\x01' >"$W/sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c"; }

# fake_herdr FILE — herdr, as much of it as verify's start check sees: its version, `config
# check` (fails without a config, or with $FKH/herdr-bad-config), a start on a terminal (the
# lines a real one logs: the window's side attached, the first workspace in the folder it was
# started from; refused off a terminal, and nothing with $FKH/herdr-dead), `server stop`
fake_herdr() {
  cat >"$1" <<'EOF'
#!/bin/sh
L=$HOME/.config/herdr
case ${1:-} in
  --version) echo "herdr 0.9.5" ;;
  config) [ -f "$L/config.toml" ] && [ ! -e /var/lib/fkh/herdr-bad-config ] || { echo "config: issues found"; exit 1; }
          echo "config: ok" ;;
  server) [ "${2:-}" = stop ] || exit 2 ;;
  "") [ -t 0 ] || { echo "herdr: cannot attach without a usable terminal" >&2; exit 1; }
      [ -e /var/lib/fkh/herdr-dead ] && { echo "herdr: (stand-in) does not start" >&2; exit 1; }
      echo "INFO herdr::client::handshake: endpoint handshake succeeded generation=1 server_version=0.9.5" >>"$L/herdr-client.log"
      echo "INFO herdr::server::headless::bootstrap: created startup workspace cwd=$PWD" >>"$L/herdr-server.log" ;;
  *) exit 2 ;;
esac
EOF
  chmod 755 "$1"
}

# ── the GitHub releases, faked: archives made here, and the fake machine's copies of the
#    project pinned to them (lib/upstream.sh's SHA-256s are the real releases') ─────────────
fake_face() { printf 'a stand-in for %s\n' "$1"; }   # fake_face FILE — a face's stand-in bytes
pin_faces() {   # the fake machine's copies of the project: the terminal face's four files pinned to their stand-ins
  local d f name old
  for d in "$W/home/fkuser/fedokawaii" "$W/usr/local/lib/fedokawaii"; do
    f=$d/lib/upstream.sh; [[ -f $f ]] || continue
    while IFS='|' read -r name old; do sed -i "s/$old/$(fake_face "$name" | sha256sum | cut -d' ' -f1)/" "$f"
    done < <(. "$REPO/lib/upstream.sh"; printf '%s\n' "${TERM_FACE_FILES[@]}")
  done
}
releases() {
  local r=$TMP/rel d f sum name file old
  rm -rf "$r"; mkdir -p "$r"
  tool() { printf '#!/bin/sh\necho "%s %s"\n' "$1" "$2" >"$3"; chmod 755 "$3"; }
  mkdir -p "$r/satty" "$r/yazi/yazi-x86_64-unknown-linux-musl" "$r/lg" "$r/ud/UDEVGothic_NF_v2.2.0" "$r/ge/GE-Proton10-25"
  tool satty 0.22.0 "$r/satty/satty"; tool yazi 26.9.1 "$r/yazi/yazi-x86_64-unknown-linux-musl/yazi"; tool ya 26.9.1 "$r/yazi/yazi-x86_64-unknown-linux-musl/ya"
  tool bluetui 0.8.2 "$FKH/dl/bluetui-x86_64-linux-musl"     # (no archive: the release file is the binary)
  fake_herdr "$FKH/dl/herdr-linux-x86_64"                    # (no archive either)
  # (lazygit's and LocalSend's versions and file names as lib/upstream.sh pins them)
  local lgfile lsv
  lgfile=$(. "$REPO/lib/upstream.sh"; printf '%s\n' "${UPSTREAM[@]}" | awk -F'|' '$1 == "lazygit" { print $4 }')
  lsv=$(. "$REPO/lib/upstream.sh"; echo "${LOCALSEND_TAG#v}")
  tool lazygit "$(sed -E 's/^lazygit_([0-9.]+)_.*/\1/' <<<"$lgfile")" "$r/lg/lazygit"; echo licence >"$r/lg/LICENSE"; echo readme >"$r/lg/README.md"   # (as its release: beside them)
  for f in Regular Bold Italic BoldItalic; do fake_face "UDEVGothicNF-$f.ttf" >"$r/ud/UDEVGothic_NF_v2.2.0/UDEVGothicNF-$f.ttf"; done
  echo other >"$r/ud/UDEVGothic_NF_v2.2.0/UDEVGothic35NF-Regular.ttf"   # (a variant the archive has too: not taken)
  echo '"compatibilitytools" { }' >"$r/ge/GE-Proton10-25/compatibilitytool.vdf"
  # LocalSend: its release folder (the app, its libraries, its data)
  mkdir -p "$r/ls/lib" "$r/ls/data/flutter_assets/assets/img"; tool localsend_app "$lsv" "$r/ls/localsend_app"
  echo lib >"$r/ls/lib/libapp.so"; echo png >"$r/ls/data/flutter_assets/assets/img/logo-512.png"
  name=$(. "$REPO/lib/upstream.sh"; echo "$LOCALSEND_ASSET"); tar -czf "$FKH/dl/$name" -C "$r/ls" .
  tar -czf "$FKH/dl/satty-x86_64-unknown-linux-gnu.tar.gz" -C "$r/satty" .
  (cd "$r/yazi" && python3 -m zipfile -c "$FKH/dl/yazi-x86_64-unknown-linux-musl.zip" yazi-x86_64-unknown-linux-musl)
  tar -czf "$FKH/dl/$lgfile" -C "$r/lg" LICENSE README.md lazygit
  (cd "$r/ud" && python3 -m zipfile -c "$FKH/dl/UDEVGothic_NF_v2.2.0.zip" UDEVGothic_NF_v2.2.0)
  tar -czf "$FKH/dl/GE-Proton10-25.tar.gz" -C "$r/ge" GE-Proton10-25
  (cd "$FKH/dl" && sha512sum GE-Proton10-25.tar.gz >GE-Proton10-25.sha512sum)
  printf '%s\n' '{"tag_name":"GE-Proton10-25","assets":[' \
    '{"name":"GE-Proton10-25.sha512sum","browser_download_url":"https://github.com/x/GE-Proton10-25.sha512sum"},' \
    '{"name":"GE-Proton10-25.tar.gz","browser_download_url":"https://github.com/x/GE-Proton10-25.tar.gz"}]}' >"$FKH/ge.json"
  echo "-----BEGIN PGP PUBLIC KEY BLOCK-----" >"$FKH/dl/claude-code.asc"
  # the fake machine's copies of the project, pinned to these files
  for d in "$W/home/fkuser/fedokawaii" "$W/usr/local/lib/fedokawaii"; do
    f=$d/lib/upstream.sh; [[ -f $f ]] || continue
    while IFS='|' read -r name _ _ file old _; do
      sum=$(sha256sum "$FKH/dl/$file" | cut -d' ' -f1); sed -i "s/$old/$sum/" "$f"
    done < <(. "$REPO/lib/upstream.sh"; printf '%s\n' "${UPSTREAM[@]}")
    # (the terminal's face: its archive's sum and each of its four files', the stand-ins')
    old=$(. "$REPO/lib/upstream.sh"; echo "$TERM_FACE_SUM"); sum=$(sha256sum "$FKH/dl/UDEVGothic_NF_v2.2.0.zip" | cut -d' ' -f1)
    sed -i "s/$old/$sum/" "$f"
    old=$(. "$REPO/lib/upstream.sh"; echo "$LOCALSEND_SHA256"); sum=$(sha256sum "$FKH/dl/$(. "$REPO/lib/upstream.sh"; echo "$LOCALSEND_ASSET")" | cut -d' ' -f1)
    sed -i "s/$old/$sum/" "$f"
  done
  pin_faces
  chmod -R a+rwX "$FKH"
}

# ── a finished install (setup done; with --themed, the theme applied too) ──────────
built() {
  local themed=$1 S=$W/var/lib/fedokawaii U=$W/home/fkuser p
  echo "done" >"$S/phase"; echo fkuser >"$S/user"; echo amd >"$S/gpu"
  local gid=3100
  for p in video render gamemode; do gid=$((gid + 1))
    if grep -q "^$p:" "$W/etc/group"; then sed -i -E "s/^($p:[^:]*:[^:]*:)(.+)\$/\\1\\2,fkuser/; s/^($p:[^:]*:[^:]*:)\$/\\1fkuser/" "$W/etc/group"
    else echo "$p:x:$gid:fkuser" >>"$W/etc/group"; fi
  done
  printf '%s\n' bash sudo NetworkManager >"$S/baseline-userinstalled"
  echo 1792000000 >"$S/input-group-out"                      # (setup's groups step: never in input)
  # the toolkit: this repository, installed for good
  mkdir -p "$W/usr/local/lib/fedokawaii"; cp -a "$U/fedokawaii/." "$W/usr/local/lib/fedokawaii/"
  cp "$W/usr/local/lib/fedokawaii/system/fedokawaii" "$W/usr/local/bin/fedokawaii"
  cp "$W/usr/local/lib/fedokawaii/system/fedokawaii-report" "$W/usr/local/bin/fedokawaii-report"
  # dwl, its own wlroots, the session's system pieces
  # (-s CMD: started — CMD runs, and its SIGTERM ends it cleanly, as the real one: the guard's start test)
  printf '#!/bin/sh\n# ldd: libxcb.so.1 => /usr/lib64/libxcb.so.1 (0x1)\n# ldd: libwlroots-0.20.so => /usr/local/lib/fedokawaii-wlroots-0.20/lib/libwlroots-0.20.so (0x2)\n[ -f /var/lib/fkh/dwl-crash ] && exit 1\nif [ "$1" = -s ]; then trap "exit 0" TERM; sh -c "$2" & wait; exit 0; fi\necho "dwl 0.9"\n' >"$W/usr/local/bin/dwl"
  chmod 755 "$W/usr/local/bin/dwl"
  p=$W/usr/local/lib/fedokawaii-wlroots-0.20; mkdir -p "$p/lib" "$p/include/wlroots-0.20"
  cp "$W/usr/local/fkh-sys/lib64/libwlroots-0.20.so" "$p/lib/"; echo "-I/usr/local/lib/fedokawaii-wlroots-0.20/include/wlroots-0.20" >"$p/cflags"
  sed "s|@KB_LAYOUTS@|us,ara|; s|@KB_TOGGLE@|grp:alt_shift_toggle|" "$REPO/system/start-dwl" >"$W/usr/local/bin/start-dwl"; chmod 755 "$W/usr/local/bin/start-dwl"
  install -m 0755 "$REPO/system/kawa-greet" "$W/usr/local/bin/kawa-greet"
  for t in dark light; do   # the login screen's look, as greetd_config installs it
    mkdir -p "$W/usr/local/share/fedokawaii/greeter/$t"
    cp "$REPO/configs/home/.config/fedokawaii/themes/$t/"{gtklock.css,lock-scroll.png,lock-fibre.png} "$REPO/configs/home/.local/share/fedokawaii/$t/"{padlock,seal-?}.png \
      "$W/usr/local/share/fedokawaii/greeter/$t/"
  done
  mkdir -p "$W/var/lib/fedokawaii-greeter" "$W/etc/fonts/conf.d" "$W/usrshare/locale/fk/LC_MESSAGES"
  cp "$REPO/system/60-fedokawaii-pixel.conf" "$W/etc/fonts/conf.d/"; cp "$REPO/art/gtklock.mo" "$W/usrshare/locale/fk/LC_MESSAGES/gtklock.mo"   # (the fake /usr/share)
  fake_cmd "$W/usrbin/agreety"; fake_cmd "$W/usr/local/bin/kawa-torrra"
  mkdir -p "$W/etc/greetd" "$W/etc/systemd/system/greetd.service.d" "$W/etc/profile.d" "$W/etc/NetworkManager/conf.d" "$W/etc/dnf/libdnf5.conf.d" \
    "$W/etc/yum.repos.d" "$W/usr/local/sbin" "$W/etc/dnf/libdnf5-plugins/actions.d" "$W/etc/mpv/scripts"
  printf '[default_session]\ncommand = "env $(/usr/local/bin/start-dwl --gpu) \\"XCURSOR_THEME=Sumi-$(cat /var/lib/fedokawaii-greeter/theme)\\" systemd-cat -t kawa-greet cage -d -s -- /usr/local/bin/kawa-greet fkuser"\n' >"$W/etc/greetd/fedokawaii.toml"
  echo dark >"$W/var/lib/fedokawaii-greeter/theme"
  printf '[Unit]\nConflicts=getty@tty1.service kmsconvt@tty1.service\nAfter=getty@tty1.service kmsconvt@tty1.service plymouth-quit-wait.service systemd-user-sessions.service\nStartLimitIntervalSec=60\nStartLimitBurst=5\nOnFailure=fedokawaii-login-failed.service\n\n[Service]\nExecStart=\nExecStart=/usr/bin/greetd --config /etc/greetd/fedokawaii.toml\nRestart=always\nRestartSec=2\n' >"$W/etc/systemd/system/greetd.service.d/fedokawaii.conf"
  mkdir -p "$W/etc/systemd/system/plymouth-quit.service.d"
  printf '[Service]\nExecStart=\nExecStart=-/usr/bin/plymouth quit --retain-splash\n' >"$W/etc/systemd/system/plymouth-quit.service.d/fedokawaii.conf"
  printf '[Service]\nType=oneshot\nTTYPath=/dev/tty1\nExecStart=/usr/bin/printf %s\n' "'The login screen could not start'" >"$W/etc/systemd/system/fedokawaii-login-failed.service"
  printf 'export EDITOR=nvim\nexport VISUAL=nvim\n' >"$W/etc/profile.d/editor.sh"; : >"$W/etc/profile.d/kawa-torrra.sh"
  printf '%s\n' "[ \"\$TERM\" = linux ] && [ -t 1 ] && printf '\\033[?25h'" >"$W/etc/profile.d/fedokawaii-console.sh"
  printf '#!/bin/sh\nexec nvim "$@"\n' >"$W/usr/local/bin/vi"; chmod 755 "$W/usr/local/bin/vi"; : >"$W/etc/NetworkManager/conf.d/90-fedokawaii.conf"; : >"$W/etc/mpv/scripts/mpris.so"
  mkdir -p "$W/etc/modprobe.d" "$W/etc/systemd/system/user@.service.d"
  echo 'options btusb enable_autosuspend=0' >"$W/etc/modprobe.d/fedokawaii-btusb.conf"
  # game mode (setup.sh: game_mode): tuned's game profile, its polkit rule, a game's priority
  mkdir -p "$W/etc/tuned/profiles/fedokawaii-game" "$W/etc/polkit-1/rules.d" "$W/etc/security/limits.d"
  printf '[main]\ninclude=fedokawaii\n\n[sysfs]\n/sys/bus/pci/devices/0000:03:00.0/power_dpm_force_performance_level=high\n' >"$W/etc/tuned/profiles/fedokawaii-game/tuned.conf"
  printf 'polkit.addRule(function (action, subject) { return polkit.Result.NOT_HANDLED; });\n' >"$W/etc/polkit-1/rules.d/60-fedokawaii-game.rules"
  echo 'fkuser - nice -5' >"$W/etc/security/limits.d/60-fedokawaii-game.conf"
  echo 'options snd_hda_intel power_save=0' >"$W/etc/modprobe.d/fedokawaii-audio.conf"
  printf '[Service]\nTimeoutStopSec=30s\n' >"$W/etc/systemd/system/user@.service.d/fedokawaii.conf"
  mkdir -p "$W/etc/systemd/sleep.conf.d"; printf '[Sleep]\nAllowHibernation=no\nAllowHybridSleep=no\nAllowSuspendThenHibernate=no\n' >"$W/etc/systemd/sleep.conf.d/90-fedokawaii.conf"
  mkdir -p "$W/etc/systemd/resolved.conf.d"; printf '[Resolve]\nLLMNR=no\n' >"$W/etc/systemd/resolved.conf.d/90-fedokawaii.conf"
  printf '[zram0]\nzram-size = min(ram / 2, 16384)\ncompression-algorithm = zstd\n' >"$W/etc/systemd/zram-generator.conf"
  # the pace of a start and a shut down, a clean system and home (s_pace, s_clean)
  mkdir -p "$W/etc/systemd/system.conf.d" "$W/etc/systemd/user.conf.d" "$W/etc/systemd/journald.conf.d" "$W/etc/systemd/coredump.conf.d"
  printf '[Manager]\nDefaultTimeoutStopSec=15s\n' >"$W/etc/systemd/system.conf.d/90-fedokawaii.conf"
  printf '[Manager]\nDefaultTimeoutStopSec=10s\n' >"$W/etc/systemd/user.conf.d/90-fedokawaii.conf"
  printf '[Journal]\nSystemMaxUse=500M\n' >"$W/etc/systemd/journald.conf.d/40-fedokawaii.conf"
  printf '[Coredump]\nMaxUse=1G\nExternalSizeMax=1G\nProcessSizeMax=1G\n' >"$W/etc/systemd/coredump.conf.d/40-fedokawaii.conf"
  cp "$REPO/system/fedokawaii-home.sh" "$W/etc/profile.d/fedokawaii-home.sh"
  mkdir -p "$W/home/fkuser/.config"; printf 'XDG_DESKTOP_DIR="$HOME/"\nXDG_PUBLICSHARE_DIR="$HOME/"\nXDG_TEMPLATES_DIR="$HOME/"\n' >"$W/home/fkuser/.config/user-dirs.dirs"
  mkdir -p "$W/etc/systemd/logind.conf.d"; printf '[Login]\nHandleSuspendKey=ignore\nHandleSuspendKeyLongPress=ignore\nHandleHibernateKey=ignore\nHandleHibernateKeyLongPress=ignore\nInhibitDelayMaxSec=25\n' >"$W/etc/systemd/logind.conf.d/90-fedokawaii.conf"
  printf '[main]\nmax_parallel_downloads=10\nfastestmirror=True\nminrate=5k\ntimeout=20\ninstallonly_limit=2\ndefaultyes=True\nexclude_from_weak=nodejs,nodejs22*,PackageKit,java-*-openjdk-headless,libreoffice-help-*\n' >"$W/etc/dnf/libdnf5.conf.d/90-fedokawaii.conf"
  printf '[x]\ngpgcheck=1\n' >"$W/etc/yum.repos.d/brave-browser.repo"; cp "$W/etc/yum.repos.d/brave-browser.repo" "$W/etc/yum.repos.d/claude-code.repo"
  printf '#!/bin/sh\nexit 0\n' >"$W/usr/local/sbin/kawa-snap"; chmod 755 "$W/usr/local/sbin/kawa-snap"; : >"$W/etc/dnf/libdnf5-plugins/actions.d/fedokawaii-snapper.actions"
  # the boot menu's snapshots (snap_boot): grub-btrfs's script, the clean-up's drop-in, grub.cfg's submenu
  mkdir -p "$W/etc/grub.d" "$W/etc/systemd/system/snapper-cleanup.service.d" "$W/boot/grub2"
  printf '#!/bin/sh\nexit 0\n' >"$W/etc/grub.d/41_snapshots-btrfs"; chmod 755 "$W/etc/grub.d/41_snapshots-btrfs"
  printf '[Service]\nExecStartPost=-/usr/local/sbin/kawa-snap boot\n' >"$W/etc/systemd/system/snapper-cleanup.service.d/fedokawaii.conf"
  grep -qs grub-btrfs.cfg "$W/boot/grub2/grub.cfg" || echo 'configfile "${prefix}/grub-btrfs.cfg"' >>"$W/boot/grub2/grub.cfg"
  # dnf's guard (lib/guard.sh: guard_hooks), its records and its unit
  install -m 0755 "$REPO/system/kawa-dnf-guard" "$W/usr/local/sbin/kawa-dnf-guard"
  printf '%s\n' "pre_transaction::::mode=json:/usr/local/sbin/kawa-dnf-guard pre" "post_transaction::::mode=json:/usr/local/sbin/kawa-dnf-guard post" \
    >"$W/etc/dnf/libdnf5-plugins/actions.d/fedokawaii-guard.actions"
  printf '%s\n' "wlroots 0.20" "libxcb.so.1 libxcb build" >"$S/needs"
  : >"$W/etc/systemd/system/fedokawaii-after-dnf.service"
  mkdir -p "$W/etc/systemd/system"; ln -sfn ../../../usr/lib/systemd/system/greetd.service "$W/etc/systemd/system/display-manager.service"
  mkdir -p "$W/usr/local/libexec" "$W/usr/local/lib/systemd/user" "$W/usr/local/share/dbus-1/services" "$W/usr/local/share/xdg-desktop-portal/portals"
  printf '#!/bin/sh\necho "xdg-desktop-portal-termfilechooser 1.4.3"\n' >"$W/usr/local/libexec/xdg-desktop-portal-termfilechooser"
  chmod 755 "$W/usr/local/libexec/xdg-desktop-portal-termfilechooser"
  : >"$W/usr/local/lib/systemd/user/xdg-desktop-portal-termfilechooser.service"
  : >"$W/usr/local/share/dbus-1/services/org.freedesktop.impl.portal.desktop.termfilechooser.service"
  : >"$W/usr/local/share/xdg-desktop-portal/portals/termfilechooser.portal"
  # the notices' mako, as build_mako leaves it: the binary (its options' names in it), the
  # unit's drop-in, the record of what it was built from (the pins and the patch)
  mkdir -p "$W/usr/local/bin" "$W/usr/local/lib/systemd/user/mako.service.d"
  printf '#!/bin/sh\n# shadow-color summary-icon-color hanging-indent\necho "Usage: mako [options...]"\n' >"$W/usr/local/bin/mako"
  chmod 755 "$W/usr/local/bin/mako"
  printf '%s\n' "[Service]" "ExecStart=" "ExecStart=/usr/local/bin/mako" >"$W/usr/local/lib/systemd/user/mako.service.d/fedokawaii.conf"
  { printf '%s\n' "$(conf_val MAKO_TAG)" "$(conf_val MAKO_COMMIT)"; cat "$REPO/src/mako/mako.patch"; } | sha256sum | cut -d' ' -f1 >"$W/usr/local/bin/mako.built"
  : >"$W/var/lib/systemd/linger/fkuser"; : >"$W/dev/ntsync"
  # every manifest package installed and marked as yours; the services setup enabled
  ( STATE_DIR=/nonexistent STEAM=yes; . "$REPO/lib/manifest.sh"; manifest_all amd ) | sort -u >"$TMP/manifest"
  cp "$TMP/manifest" "$S/manifest"
  grep -vxF -e nano -e nano-default-editor -e vim-minimal -e dracut-config-rescue "$FKH/installed" \
    | cat - "$TMP/manifest" <(echo mesa-vulkan-drivers.i686) <(echo amd-ucode-firmware) | sort -u >"$FKH/installed.n"
  mv "$FKH/installed.n" "$FKH/installed"
  { printf '%s\n' bash sudo NetworkManager; cat "$TMP/manifest"; echo amd-ucode-firmware; } | sort -u | sed 's/$/ User/' >"$FKH/userinstalled"
  echo amd-ucode-firmware >"$S/hardware-pkgs"
  printf 'enabled %s\n' greetd.service bluetooth.service snapper-timeline.timer snapper-cleanup.timer fstrim.timer lactd.service \
    fedokawaii-scrub.timer fedokawaii-kernels.timer fedokawaii-report.service tuned.service firewalld.service fedokawaii-after-dnf.service >>"$FKH/units"
  sed -i '/ sshd.service$/d; /^global-enabled grub-boot-success\.timer$/d' "$FKH/units"   # (that timer: the desktop starts it)
  rm -f "$W/usrbin/nano" "$W/usrbin/vi"                     # (setup took them out)
  printf '%s\n' copr:copr.fedorainfracloud.org:ilyaz:LACT copr:copr.fedorainfracloud.org:zzahkaboom24:grub-btrfs >"$FKH/coprs"
  mkdir -p "$W/usrshare/vulkan/icd.d" "$W/usrshare/icons/Papirus" "$W/usrshare/icons/Papirus-Dark" "$W/usrshare/icons/Adwaita/cursors"
  : >"$W/usrshare/vulkan/icd.d/radeon_icd.x86_64.json"; fake_cmd "$W/usrbin/greetd"
  printf '%s\n' root home >"$FKH/snapper-configs"; echo "1,fedokawaii baseline" >"$FKH/snaps"
  mkdir -p "$W/etc/snapper/configs"; for c in root home; do echo 'SUBVOLUME="/"' >"$W/etc/snapper/configs/$c"; done
  sed -i 's/^static dnf5-makecache.timer$/masked dnf5-makecache.timer/' "$FKH/units"; echo 'masked dnf-makecache.timer' >>"$FKH/units"   # (both masked, dnf4's ahead of any package)
  echo fedokawaii >"$FKH/tuned-profile"; printf '%s\n' dhcpv6-client ssh >"$FKH/fw-services"; printf '%s\n' 'enabled sshd.service' 'active sshd.service' >>"$FKH/units"
  mkdir -p "$W/etc/ssh/sshd_config.d"; printf '%s\n' PasswordAuthentication\ no >"$W/etc/ssh/sshd_config.d/40-fedokawaii.conf"   # (SSH_SERVER=yes, as shipped)
  printf '%s\n' 6881/tcp 6881/udp 53317/tcp 53317/udp >"$FKH/fw-ports"
  echo menu_auto_hide=2 >"$FKH/grubenv"
  local q="rhgb quiet loglevel=3 rd.udev.log_level=3 systemd.show_status=false vt.global_cursor_default=0 systemd.tty.term.console=dumb initcall_blacklist=simpledrm_platform_driver_init split_lock_detect=off"
  printf '%s\n' "ro rootflags=subvol=root $q amdgpu.ppfeaturemask=0xfff7ffff" \
    "ro rootflags=subvol=root $q amdgpu.ppfeaturemask=0xfff7ffff" >"$FKH/grub-args"
  sed -i "s/rhgb quiet\$/$q amdgpu.ppfeaturemask=0xfff7ffff/" "$W/proc/cmdline"   # (this start: the same)
  echo fedokawaii >"$FKH/hostname"; : >"$FKH/podman-image"
  echo 'a1b2c3d4e5f60718293a4b5c6d7e8f90' >"$FKH/podman-secret"
  printf '[%s]\n' "$(for d in nyaasi SubsPlease tokyotosho thepiratebay yts Knaben limetorrents torrentdownloads; do
    printf '{"enable": true, "definitionName": "%s"},' "$d"; done | sed 's/,$//')" >"$FKH/prowlarr-indexers"
  echo $'Scrub started:    Sat Oct  3 02:00:00 2026\nStatus:           finished\nError summary:    no errors found' >"$FKH/scrub-status"
  # the user's home: tools at their pinned tags, fonts, GE-Proton, torrra, secrets, Prowlarr, nvim
  mkdir -p "$U/.local/bin" "$U/.local/share/fedokawaii/upstream" \
    "$W/usr/local/share/fonts/fedokawaii" "$U/.local/share/Steam/compatibilitytools.d/GE-Proton10-25" \
    "$U/.local/src/dwl/.git" "$U/.local/share/uv/tools/torrra/bin" "$U/.config/fedokawaii" "$U/.config/containers/systemd" \
    "$U/.config/prowlarr" "$U/.config/nvim" "$U/.config/torrra" "$U/.local/state/fedokawaii" "$U/Downloads" "$U/.local/share/nvim/lazy/LazyVim"
  local name tag bins b f
  while IFS='|' read -r name _ tag _ _ bins; do
    for b in $bins; do printf '#!/bin/sh\necho "%s %s"\n' "$b" "$tag" >"$U/.local/bin/$b"; chmod 755 "$U/.local/bin/$b"; done
    [[ $name == herdr ]] && fake_herdr "$U/.local/bin/herdr"
    echo "$tag" >"$U/.local/share/fedokawaii/upstream/$name"
  done < <(. "$REPO/lib/upstream.sh"; printf '%s\n' "${UPSTREAM[@]}")
  echo GE-Proton10-25 >"$U/.local/share/fedokawaii/upstream/ge-proton"
  # Syncplay from its pinned source: the folder, the two starters, the commit recorded
  ( . "$TI/stubs/_lib.sh"; FKH=$FKH fake_syncplay_source "$U/.local/share/fedokawaii/syncplay" )
  ( . "$REPO/lib/upstream.sh"; d=/home/fkuser/.local/share/fedokawaii/syncplay
    syncplay_starter syncplay ep_client "$d" --no-gui >"$U/.local/bin/syncplay"
    syncplay_starter syncplay-server ep_server "$d" >"$U/.local/bin/syncplay-server"
    syncplay_pin >"$U/.local/share/fedokawaii/upstream/syncplay" )
  chmod 755 "$U/.local/bin/syncplay" "$U/.local/bin/syncplay-server"
  # LocalSend's folder, its starter link, the release recorded
  mkdir -p "$U/.local/share/localsend/lib"; printf '#!/bin/sh\necho localsend\n' >"$U/.local/share/localsend/localsend_app"
  chmod 755 "$U/.local/share/localsend/localsend_app"; ln -sfn ../share/localsend/localsend_app "$U/.local/bin/localsend"
  ( . "$REPO/lib/upstream.sh"; echo "$LOCALSEND_TAG" ) >"$U/.local/share/fedokawaii/upstream/localsend"
  # ble.sh built from its pinned commit, the commit recorded
  ( . "$TI/stubs/_lib.sh"; fake_blesh_install "$U/.local/share/blesh" )
  ( . "$REPO/lib/upstream.sh"; echo "$BLESH_COMMIT" ) >"$U/.local/share/fedokawaii/upstream/blesh"
  # Python and Rust to learn with (s_dev): uv's CPython, rustup's toolchain, Mason's tools for them
  mkdir -p "$U/.local/share/uv/python/cpython-3.14.0-linux-x86_64-gnu/bin" "$U/.local/share/cargo/bin" "$U/.local/share/nvim/mason/bin"
  for b in cargo rustc rust-analyzer cargo-clippy rustfmt; do printf '#!/bin/sh\nexit 0\n' >"$U/.local/share/cargo/bin/$b"; chmod 755 "$U/.local/share/cargo/bin/$b"; done
  printf '#!/bin/bash\n. /usr/local/bin/_lib.sh\nfkh_log "$*"\nexit 0\n' >"$U/.local/share/cargo/bin/rustup"; chmod 755 "$U/.local/share/cargo/bin/rustup"   # (says what update asks of it)
  for b in basedpyright ruff codelldb; do printf '#!/bin/sh\nexit 0\n' >"$U/.local/share/nvim/mason/bin/$b"; chmod 755 "$U/.local/share/nvim/mason/bin/$b"; done
  cp "$REPO"/system/fonts/{SumiUI.ttf,LICENSE} "$W/usr/local/share/fonts/fedokawaii/"   # (install_faces')
  for f in Regular Bold Italic BoldItalic; do fake_face "UDEVGothicNF-$f.ttf" >"$W/usr/local/share/fonts/fedokawaii/UDEVGothicNF-$f.ttf"; done   # (install_term_face's)
  pin_faces
  printf '#!/bin/bash\nfor a; do [[ $a == - ]] && { cat >/dev/null; break; }; done\nexit 0\n' >"$U/.local/share/uv/tools/torrra/bin/python"; chmod 755 "$U/.local/share/uv/tools/torrra/bin/python"
  printf 'PROWLARR_API_KEY=a1b2c3d4e5f60718293a4b5c6d7e8f90\n' >"$U/.config/fedokawaii/secrets.sh"; chmod 600 "$U/.config/fedokawaii/secrets.sh"
  cp "$REPO/system/prowlarr.container" "$U/.config/containers/systemd/prowlarr.container"
  printf '[general]\ndefault = "prowlarr"\n' >"$U/.config/torrra/config.toml"; sed -i 's/^\[general\]/[indexers]/' "$U/.config/torrra/config.toml"
  echo '{}' >"$U/.config/nvim/lazy-lock.json"; echo 'x' >"$U/.config/nvim/init.lua"
  printf 'static const unsigned int gappx = 5;\nstatic float bordercolor[3][4];\n' >"$U/.local/src/dwl/config.h"
  echo "ref: refs/heads/main" >"$U/.local/src/dwl/.git/HEAD"              # (a repository git can read)
  : >"$U/.local/src/dwl/dwl.c"
  mkdir -p "$W/runuser/$FK_UID"; chmod 700 "$W/runuser/$FK_UID"
  ((themed)) && themed_home
  return 0
}
themed_home() {   # what theme.sh leaves: run it once in the fake machine (theme-applied then marks it)
  fk_perms
  fk bash /usr/local/lib/fedokawaii/theme.sh --user fkuser >"$TMP/theme-first.log" 2>&1 \
    || { printf 'harness: the first theme run failed:\n'; tail -n 20 "$TMP/theme-first.log"; }
}
