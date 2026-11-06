#!/usr/bin/bash
# lib/cand-check.sh — run inside the update's candidate (a copy of this system that has just
# received the transaction, in a container: lib/update.sh cand_run), as root: what must hold
# before the running system gets the same — and on the running system itself, before and after
# its transaction (up_more: there without /run/fk-ref.img, every boot entry of the real /boot).
# A line "red: WHAT" for each failure; exit 1 if any. FK_USER: the desktop's user
export LC_ALL=C
red=0
no() { echo "red: $*"; red=1; }
user=${FK_USER:?}; home=$(getent passwd "$user" | cut -d: -f6)
as_him() { runuser -u "$user" -- env HOME="$home" "$@"; }
# what each program says of the configs we own, a line for each red
configs() {
  local fixer=${FK_FIXER:-/usr/local/sbin/kawa-fixer} out bad cmd g
  if [[ -x $fixer ]]; then   # (its table: foot, mako, mpv, nvim, greetd, the bar's and the lock's CSS)
    python3 -I "$fixer" checks --user "$user" 2>&1 | sed -n 's/^red: //p'
  else
    as_him foot --check-config >/dev/null 2>&1 || echo "foot does not take its config (foot --check-config)"
    # nvim: its config and plugins at a real start; an error is words on stderr, the status stays 0
    out=$(as_him timeout 60 nvim --headless -n -i NONE +qa 2>&1 </dev/null) || echo "nvim does not start (status $?)"
    if bad=$(grep -E -m1 '(^|[^[:alnum:]])E[0-9]+:|^Error|stack traceback' <<<"$out"); then echo "nvim does not take its config: ${bad:0:200}"; fi
  fi
  # yazi: no check of its own, and --version reads nothing: a real start in a terminal of its own, then q
  if [[ -x $home/.local/bin/yazi ]]; then
    as_him TERM=foot python3 -I -B -c '
import os, pty, select, sys, time
pid, fd = pty.fork()
if pid == 0:
    os.execv(sys.argv[1], sys.argv[1:])
out, q, end = b"", time.time() + 1, time.time() + 30
while time.time() < end:
    if select.select([fd], [], [], 0.2)[0]:
        try:
            d = os.read(fd, 65536)
        except OSError:
            break
        if not d:
            break
        out += d
    if q and time.time() > q:
        os.write(fd, b"q")
        q = 0
sys.exit(1 if b"parse error" in out or b"Caused by" in out else 0)
' "$home/.local/bin/yazi" / </dev/null >/dev/null 2>&1 || echo "yazi does not take its config (a real start)"
  fi
  # greetd: no check of its own (greetd --help): its file read as TOML, what greetd(5) requires, the greeter there
  g=${FK_GREETD:-/etc/greetd/fedokawaii.toml}
  if [[ -e $g ]]; then
    cmd=$(python3 -I -B -c '
import shlex, sys, tomllib
c = tomllib.load(open(sys.argv[1], "rb"))
print(c["terminal"]["vt"] and shlex.split(c["default_session"]["command"])[0])
' "$g" 2>/dev/null) || cmd=""
    if [[ -z $cmd ]]; then echo "greetd cannot read ${g##*/}: not TOML, or no terminal.vt or default_session.command"
    elif ! command -v "$cmd" >/dev/null; then echo "greetd's greeter is not there: $cmd"; fi
  fi
}
if [[ ${1:-} == --before ]]; then configs; exit 0; fi
# our own builds find every library they link (a move to a new Fedora: not asked — they are rebuilt
# after it, and the test VM has shown that they build there: lib/move.sh)
[[ -z ${FK_MOVE:-} ]] && for f in /usr/local/bin/dwl /usr/local/bin/{mako,foot,footclient} /usr/local/lib/fedokawaii-wlroots-*/lib/*.so* \
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
    no "a boot entry has no root= or rootflags= (${e##*/})"
  fi
  k=$(awk '$1 == "version" { print $2; exit }' "$e")
  [[ -n $k ]] || { no "a boot entry names no version (${e##*/})"; continue; }
  [[ -s /boot/initramfs-$k.img ]] || { no "kernel $k has no boot image"; continue; }
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
# the configs we own, read by their programs' own checks: what this update made red (in a candidate
# /run/fk-before says what was red before its packages — a container can make a program red by itself)
while IFS= read -r l; do
  [[ -z $l ]] || grep -qF -- "${l%% — *}" "${FK_BEFORE:-/run/fk-before}" 2>/dev/null || no "$l"
done < <(configs)
exit "$red"
