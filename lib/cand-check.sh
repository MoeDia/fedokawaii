#!/usr/bin/bash
# lib/cand-check.sh — run inside the update's candidate (a copy of this system that has just
# received the transaction, in a container: lib/update.sh cand_run), as root: what must hold
# before the running system gets the same. A line "red: WHAT" for each failure; exit 1 if any.
# FK_USER: the desktop's user · FK_GPU: the machine's graphics (amd, intel, …)
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
# a new kernel: its boot entry finds this root, its boot image holds what this machine starts with
for e in /boot/loader/entries/*.conf; do
  [[ -f $e ]] || continue
  grep -Eq '^options .*root=' "$e" && grep -Eq '^options .*rootflags=subvol=' "$e" \
    || no "the new kernel's boot entry has no root= or rootflags= (${e##*/})"
  k=$(awk '$1 == "version" { print $2; exit }' "$e")
  [[ -n $k ]] || { no "a new boot entry names no version (${e##*/})"; continue; }
  [[ -s /boot/initramfs-$k.img ]] || { no "the new kernel $k has no boot image"; continue; }
  mods=btrfs; [[ ${FK_GPU:-} == amd ]] && mods+=" amdgpu"
  list=$(lsinitrd "/boot/initramfs-$k.img" 2>/dev/null)
  for m in $mods; do grep -q "/$m\.ko" <<<"$list" || no "the boot image of $k has no $m"; done
done
# the configs we own, read by their programs' own checks
runuser -u "$user" -- env HOME="$home" foot --check-config >/dev/null 2>&1 || no "foot does not take its config (foot --check-config)"
exit "$red"
