#!/usr/bin/env bash
# tests/engine/test_snap.sh — kawa-snap, the snapshots around every dnf transaction: dnf's
# actions plugin runs `kawa-snap pre PID` before and `kawa-snap post PID` after, as root.
# The pair is named by the command that ran; whatever goes wrong (no snapper, no Btrfs, a full
# disk, an odd command line) dnf is never stopped, nothing reaches dnf's stdout (the plugin
# reads it), and the journal says why. /proc and /run are fixtures here (lib.sh's pointed).
. "$(dirname "$0")/lib.sh"

fresh() {
  sandbox
  P=$TMP/proc; mkdir -p "$P" "$TMP/runroot"
  pointed "$REPO/system/kawa-snap" "$STUBS/kawa-snap" \
    "s|/proc/|$P/|g" "s|^state=/run/kawa-snap.pre\$|state=$TMP/runroot/kawa-snap.pre|" \
    's|\[\[ \$EUID -eq 0 \]\]|[[ ${FK_EUID:-$EUID} -eq 0 ]]|'
  export FK_EUID=0
  # snapper: numbers its snapshots from 41; prints the number for -p
  stub snapper 'n=$(cat "'"$TMP"'/n" 2>/dev/null || echo 40); n=$((n + 1)); echo $n >"'"$TMP"'/n"
for a; do last=$a; done
printf "%s\n" "$last" >>"'"$TMP"'/descriptions"
case " $* " in *" -p "*) echo $n ;; esac'
  stub logger
  STATE=$TMP/runroot/kawa-snap.pre
}
cmdline() {   # cmdline PID ARG… — the process PID, as /proc tells it (NUL between the arguments)
  local pid=$1; shift; mkdir -p "$P/$pid"; printf '%s\0' "$@" >"$P/$pid/cmdline"
}
desc() { tail -n1 "$TMP/descriptions" 2>/dev/null; }

# ── the pair, named by the command ───────────────────────────────────────────
fresh; cmdline 4242 dnf -y install --setopt=install_weak_deps=False htop
case_ "pre: a numbered pre snapshot, named by the command (its options left out)"
out=$(kawa-snap pre 4242); eq "$?" 0; eq "$out" "" "nothing on dnf's stdout"
called '^snapper -c root create -t pre -p -c number -d dnf install htop$'
eq "$(cat "$STATE")" 41
case_ "post: the matching post snapshot, then the note of the pre forgotten"
out=$(kawa-snap post 4242); eq "$?" 0; eq "$out" ""
called '^snapper -c root create -t post --pre-number 41 -c number -d dnf install htop$'
[[ ! -e $STATE ]] && _ok || _no "the pre's note was left"
case_ "dnf5 run as dnf5, with an upgrade of everything"
fresh; cmdline 77 /usr/bin/dnf5 upgrade --refresh -y
kawa-snap pre 77; eq "$(desc)" "dnf upgrade"
case_ "the PID not given, not a number, or of no process: named by the date"
for p in "" '${pid}' abc 99999999 -1; do
  fresh; kawa-snap pre "$p"; eq "$?" 0 "[$p]"
  [[ $(desc) =~ ^dnf\ [0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}$ ]] && _ok || _no "[$p] → [$(desc)]"
done
case_ "a command of only options: named by the date"
fresh; cmdline 5 dnf -y --refresh; kawa-snap pre 5
[[ $(desc) =~ ^dnf\ [0-9]{4}- ]] && _ok || _no "[$(desc)]"

# ── odd command lines ────────────────────────────────────────────────────────
case_ "quotes, \$(…), backticks: one description, never run"
fresh; cmdline 6 dnf install './a "b" $(touch '"$TMP"'/pwned) `id`.rpm'
kawa-snap pre 6; has "$(desc)" 'dnf install ./a "b" $(touch'; [[ ! -e $TMP/pwned ]] && _ok || _no "ran a command"
case_ "Arabic and Japanese file names: kept, whole letters (no broken UTF-8)"
fresh; cmdline 7 dnf install ./التنزيلات/حزمة.rpm ./ダウンロード.rpm
kawa-snap pre 7; eq "$(desc)" "dnf install ./التنزيلات/حزمة.rpm ./ダウンロード.rpm"
iconv -f UTF-8 -t UTF-8 <<<"$(desc)" >/dev/null 2>&1 && _ok || _no "not valid UTF-8"
case_ "a newline, a tab, an escape, broken UTF-8 in an argument: printable, valid text"
fresh; cmdline 8 dnf install $'two\nlines' $'a\ttab' $'esc\e[31mred' $'bad\xff\xfebytes'
kawa-snap pre 8; d=$(desc)
lacks "$d" $'\e'; lacks "$d" $'\t'; has "$d" "dnf install two"
iconv -f UTF-8 -t UTF-8 <<<"$d" >/dev/null 2>&1 && _ok || _no "not valid UTF-8: $d"
case_ "a very long command: cut to fit (at a whole letter)"
fresh; pk=(); for i in {1..30}; do pk+=("$(printf 'package-%02d' "$i")"); done
cmdline 9 dnf install "${pk[@]}" ダウンロード
kawa-snap pre 9; d=$(desc)
(( ${#d} <= 76 )) && _ok || _no "${#d} characters"; has "$d" "dnf install package-01 package-02"
iconv -f UTF-8 -t UTF-8 <<<"$d" >/dev/null 2>&1 && _ok || _no "cut inside a letter"
fresh; cmdline 10 dnf install "$(printf 'ダ%.0s' {1..100})"
kawa-snap pre 10; iconv -f UTF-8 -t UTF-8 <<<"$(desc)" >/dev/null 2>&1 && _ok || _no "cut inside a letter"

# ── when it cannot: dnf goes on, the journal says why ────────────────────────
case_ "snapper not installed: no snapshot, dnf goes on (exit 0, nothing on stdout), the journal says so"
fresh; cmdline 11 dnf install htop
out=$(without snapper -- kawa-snap pre 11); eq "$?" 0; eq "$out" ""
called '^logger -t kawa-snap -p user.warning -- no snapshot before this dnf run: snapper is not installed'
[[ ! -e $STATE ]] && _ok || _no "a note left for post"
reset_calls; out=$(without snapper -- kawa-snap post 11); eq "$?" 0; eq "$out" ""; not_called snapper
case_ "no Btrfs root (snapper has no config for it): the journal has snapper's own reason"
fresh; stub snapper 'echo "Unknown config." >&2; exit 1'
out=$(kawa-snap pre 11 2>&1); eq "$?" 0; eq "$out" ""
called 'logger .* no snapshot before this dnf run: Unknown config\.'
case_ "a full disk: said, dnf goes on"
fresh; stub snapper 'echo "Failure (error.something: No space left on device)." >&2; exit 1'
kawa-snap pre 11; called 'logger .*No space left on device'
case_ "post that fails: said, the pre's note still forgotten"
fresh; kawa-snap pre 11; stub snapper 'echo "Creating snapshot failed." >&2; exit 1'
out=$(kawa-snap post 11 2>&1); eq "$?" 0; eq "$out" ""
called 'logger .* no snapshot after this dnf run: Creating snapshot failed\.'
[[ ! -e $STATE ]] && _ok || _no "the pre's note was left"
case_ "post with no pre before it (it failed, or none was taken): nothing to pair, nothing done"
fresh; out=$(kawa-snap post 11); eq "$?" 0; eq "$out" ""; not_called snapper
case_ "snapper's output that is no number: never handed back as one"
fresh; stub snapper 'case " $* " in *" -p "*) echo "warning: quota not set up" ;; esac'
kawa-snap pre 11; called 'logger .*no snapshot before this dnf run: snapper gave no snapshot number'
reset_calls; kawa-snap post 11; not_called 'pre-number'
case_ "anything snapper prints on post stays off dnf's stdout"
fresh; kawa-snap pre 11; stub snapper 'echo "some chatter"'
eq "$(kawa-snap post 11)" ""
case_ "a note left by a dnf that was killed between its pre and post: the next pair is its own"
fresh; echo 17 >"$STATE"; kawa-snap pre 11; reset_calls; kawa-snap post 11
called 'pre-number 41 '
case_ "the journal unreachable (no logger): the warning goes to stderr, never stdout"
fresh; stub snapper 'exit 1'
out=$(without logger -- kawa-snap pre 11 2>/dev/null); eq "$out" ""
err=$(without logger -- kawa-snap pre 11 2>&1 >/dev/null); has "$err" "no snapshot before this dnf run"

# ── misuse ───────────────────────────────────────────────────────────────────
case_ "misuse: no word, an unknown word — exit 2 with the usage; never a snapshot"
fresh
out=$(kawa-snap 2>&1); eq "$?" 2; has "$out" "kawa-snap pre|post"
rc 2 kawa-snap frob; rc 2 kawa-snap PRE 1; not_called snapper
case_ "help"
out=$(kawa-snap --help); eq "$?" 0; has "$out" "libdnf5-plugin-actions"
case_ "run by hand as a user: it says dnf runs it, as root"
out=$(FK_EUID=1000 kawa-snap pre 1 2>&1); eq "$?" 2; has "$out" "as root"; not_called snapper
case_ "restore: a number or old, nothing else"
for a in "" 0 x -1 '41;id'; do rc 2 kawa-snap restore "$a"; done

# ── list and restore: the disk's top level a folder here ────────────────────────────────
disk() {   # a Fedora layout: root (kernel 6.18.0, marked "now"), its snapshots 1 and 41 (kernel 6.17.1, "then")
  fresh
  T=$TMP/top B=$TMP/boot; mkdir -p "$T" "$B/loader/entries"
  pointed "$REPO/system/kawa-snap" "$STUBS/kawa-snap" \
    "s|/proc/|$P/|g" "s|^state=/run/kawa-snap.pre\$|state=$TMP/runroot/kawa-snap.pre|" \
    's|\[\[ \$EUID -eq 0 \]\]|[[ ${FK_EUID:-$EUID} -eq 0 ]]|' \
    "s|^top=/run/kawa-snap/top |top=$T |" "s|/boot/|$B/|g"
  mk() {   # mk DIR KERNEL MARK
    mkdir -p "$1/usr/lib/modules/$2" "$1/etc" "$1/.snapshots"; : >"$1/usr/lib/modules/$2/vmlinuz"; echo "$3" >"$1/etc/mark"
  }
  mk "$T/root" 6.18.0 now
  for n in 1 41; do
    mk "$T/root/.snapshots/$n/snapshot" 6.17.1 "then$n"
    printf '<?xml version="1.0"?>\n<snapshot>\n  <type>%s</type>\n  <num>%s</num>\n  <date>2026-10-1%s 09:00:00</date>\n  <description>%s</description>\n</snapshot>\n' \
      "$([[ $n == 1 ]] && echo single || echo pre)" "$n" "${n:0:1}" "$([[ $n == 1 ]] && echo 'fedokawaii baseline' || echo 'dnf install a &amp; b')" >"$T/root/.snapshots/$n/info.xml"
  done
  : >"$B/vmlinuz-6.18.0"; printf 'title Fedora\nversion 6.18.0\n' >"$B/loader/entries/abc-6.18.0.conf"
  stub findmnt 'case "$*" in *--fstab*) echo rw,subvol=root,compress=zstd:1 ;; *FSTYPE*) echo btrfs ;;
  *FSROOT*) echo "${FK_FSROOT:-/root}" ;; *SOURCE*) echo "/dev/vda3[/root]" ;; esac'
  stub mountpoint "[ \"\$2\" = \"$T\" ]"
  stub mount; stub umount; stub restorecon; stub grubby; stub chroot 'shift; [ "$1 $2" != "kernel-install add" ] || exit "${FK_ADD:-0}"'
  stub kernel-install
  stub btrfs 'case "$1 $2" in
  "subvolume snapshot") cp -a "$3" "$4" ;;
  "subvolume delete") shift 2; [ "$1" = -R ] && shift; rm -rf "$1" ;;
  "subvolume list") [ -d "$4/.snapshots/1" ] && echo "ID 260 gen 9 top level 256 path <FS_TREE>/root/.snapshots" ;;
  "subvolume show") printf "\tCreation time:\t\t2026-10-16 08:00:00 +0000\n" ;;
esac'
}
case_ "list: every snapshot from its info.xml (XML escapes undone), numbered order, the booted one marked"
disk; out=$(kawa-snap list); eq "$?" 0
eq "$(sed -n 1p <<<"$out")" $'1\tsingle\t2026-10-11 09:00:00\tfedokawaii baseline\t-'
eq "$(sed -n 2p <<<"$out")" $'41\tpre\t2026-10-14 09:00:00\tdnf install a & b\t-'
FK_FSROOT=/root/.snapshots/41/snapshot kawa-snap list | grep -q $'^41\t.*\tbooted$' && _ok || _no "booted not marked"
case_ "list on a root that is not Btrfs, or not mounted by subvol=: said, exit 1"
disk; stub findmnt 'case "$*" in *FSTYPE*) echo ext4 ;; esac'; out=$(kawa-snap list 2>&1); eq "$?" 1; has "$out" "not Btrfs"
case_ "restore 41: the copy is the system, the old one kept as root.old, the snapshots moved across, /boot matched"
disk; out=$(kawa-snap restore 41 2>&1); eq "$?" 0 "$out"
eq "$(cat "$T/root/etc/mark")" then41; eq "$(cat "$T/root.old/etc/mark")" now
[[ -f $T/root/.snapshots/41/info.xml && ! -e $T/root.old/.snapshots/41 ]] && _ok || _no "the snapshots did not move across"
called '^chroot .*/top/root.new kernel-install add 6.17.1 /usr/lib/modules/6.17.1/vmlinuz$'
called '^kernel-install remove 6.18.0$'; called "^grubby --set-default $B/vmlinuz-6.17.1\$"
has "$out" "restart now"
case_ "restore old: swapped back — the system before the restore again"
kawa-snap restore old >/dev/null 2>&1; eq "$?" 0
eq "$(cat "$T/root/etc/mark")" now; eq "$(cat "$T/root.old/etc/mark")" then41
[[ -f $T/root/.snapshots/41/info.xml ]] && _ok || _no "the snapshots stayed behind"
case_ "restore whose kernel cannot be put back into /boot: nothing changed"
disk; FK_ADD=1 kawa-snap restore 41 >/dev/null 2>&1; eq "$?" 1
eq "$(cat "$T/root/etc/mark")" now; [[ ! -e $T/root.old && ! -e $T/root.new ]] && _ok || _no "left changed"
not_called '^grubby'
case_ "restore of a number that is not there: nothing changed"
disk; out=$(kawa-snap restore 7 2>&1); eq "$?" 1; has "$out" "no snapshot 7"; not_called '^btrfs subvolume snapshot'

done_
