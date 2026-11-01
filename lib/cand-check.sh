#!/usr/bin/bash
# lib/cand-check.sh — run inside the update's candidate (a copy of this system that has just
# received the transaction, in a container: lib/update.sh cand_run), as root: what must hold
# before the running system gets the same. A line "red: WHAT" for each failure; exit 1 if any.
# FK_USER: the desktop's user
export LC_ALL=C
red=0
no() { echo "red: $*"; red=1; }
user=${FK_USER:?}; home=$(getent passwd "$user" | cut -d: -f6)
# our own builds find every library they link
for f in /usr/local/bin/dwl /usr/local/bin/mako /usr/local/lib/fedokawaii-wlroots-*/lib/*.so* \
         /usr/local/libexec/xdg-desktop-portal-termfilechooser \
         "$home"/.local/bin/{kawa-clipkeep,kawa-saver,satty,yazi,ya,lazygit} "$home"/.local/lib/fedokawaii/kawa-lockmod.so; do
  [[ -f $f && ! -L $f ]] || continue
  m=$(ldd "$f" 2>/dev/null | awk '/not found/ { printf "%s ", $1 }')
  [[ -z $m ]] || no "${f##*/} misses ${m% }"
done
# a new kernel: its boot entry finds this root, its boot image starts this machine — btrfs, and
# every driver this machine runs on now that came in today's boot image (bound at /run/fk-ref.img:
# the disk's, the GPU's …; a generic image's spare file systems do not count), are in the new
# image or built into the new kernel (Fedora builds btrfs and virtio_blk in) — or the new kernel
# no longer has them at all
mods() { lsinitrd "$1" 2>/dev/null | sed -n 's|.*/\([^/]*\)\.ko\(\.[a-z]*\)\{0,1\}$|\1|p' | norm; }
norm() { tr - _ | sort -u; }   # (module names: a file's dashes are underscores to the kernel)
for e in /boot/loader/entries/*.conf; do
  [[ -f $e ]] || continue
  if ! { grep -Eq '^options .*root=' "$e" && grep -Eq '^options .*rootflags=subvol=' "$e"; }; then
    no "the new kernel's boot entry has no root= or rootflags= (${e##*/})"
  fi
  k=$(awk '$1 == "version" { print $2; exit }' "$e")
  [[ -n $k ]] || { no "a new boot entry names no version (${e##*/})"; continue; }
  [[ -s /boot/initramfs-$k.img ]] || { no "the new kernel $k has no boot image"; continue; }
  img=$(mods "/boot/initramfs-$k.img")
  [[ -n $img ]] || { no "the boot image of $k could not be read (lsinitrd)"; continue; }
  d=/usr/lib/modules/$k
  in=$({ echo "$img"; sed 's|.*/||; s|\.ko$||' "$d/modules.builtin" 2>/dev/null; } | norm)   # (in the image or built in)
  grep -qx btrfs <<<"$in" || no "the boot image of $k has no btrfs, and $k has it not built in"
  if [[ -s /run/fk-ref.img ]]; then
    lost=$(mods /run/fk-ref.img | comm -12 - <(cut -d' ' -f1 /proc/modules | norm) | comm -23 - <(echo "$in") \
           | comm -12 - <(cut -d: -f1 "$d/modules.dep" 2>/dev/null | sed 's|.*/||; s|\.ko.*||' | norm))
    [[ -z $lost ]] || no "the boot image of $k lacks what this machine starts with today: ${lost//$'\n'/ }"
  fi
done
# the configs we own, read by their programs' own checks
runuser -u "$user" -- env HOME="$home" foot --check-config >/dev/null 2>&1 || no "foot does not take its config (foot --check-config)"
exit "$red"
