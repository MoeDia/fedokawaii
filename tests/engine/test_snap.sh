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
    "s|^lock=/run/kawa-snap.lock |lock=$TMP/runroot/kawa-snap.lock |" \
    "s|^uphase=/var/lib/fedokawaii/update/phase |uphase=$TMP/runroot/update-phase |" \
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
case_ "pre: fstab names /.snapshots on its subvolume but it is not mounted there — no snapshot (snapper would write inside the system), dnf goes on, said"
fresh; cmdline 4242 dnf -y install htop
stub findmnt 'case "$*" in *--fstab*) echo rw,subvol=snapshots,compress=zstd:1 ;; *) echo "/dev/vda3[/root]" ;; esac'
out=$(kawa-snap pre 4242); eq "$?" 0; eq "$out" ""; not_called '^snapper'; called '^logger .*/.snapshots is not mounted from its subvolume'
stub findmnt 'case "$*" in *--fstab*) echo rw,subvol=snapshots,compress=zstd:1 ;; *) echo "/dev/vda3[/snapshots]" ;; esac'
kawa-snap pre 4242 >/dev/null; called '^snapper -c root create -t pre'
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
  T=$TMP/kawa-snap/top B=$TMP/boot; mkdir -p "$T" "$B/loader/entries"
  pointed "$REPO/system/kawa-snap" "$STUBS/kawa-snap" \
    "s|/proc/|$P/|g" "s|^state=/run/kawa-snap.pre\$|state=$TMP/runroot/kawa-snap.pre|" \
    "s|^lock=/run/kawa-snap.lock |lock=$TMP/runroot/kawa-snap.lock |" \
    "s|^uphase=/var/lib/fedokawaii/update/phase |uphase=$TMP/runroot/update-phase |" \
    's|\[\[ \$EUID -eq 0 \]\]|[[ ${FK_EUID:-$EUID} -eq 0 ]]|' \
    "s|^top=/run/kawa-snap/top |top=$T |" "s|/boot/|$B/|g" "s|sync -f /boot |sync -f $B |" \
    "s|/usr/local/sbin/fedokawaii-split|$STUBS/fedokawaii-split|" "s|cp -a /usr/local/sbin/kawa-snap |cp -a $STUBS/kawa-snap |"
  pointed "$REPO/system/fedokawaii-split" "$STUBS/fedokawaii-split" 's|\[\[ \$EUID -eq 0 \]\]|[[ ${FK_EUID:-0} -eq 0 ]]|'
  mk() {   # mk DIR KERNEL MARK
    mkdir -p "$1/usr/lib/modules/$2" "$1/etc" "$1/.snapshots"; : >"$1/usr/lib/modules/$2/vmlinuz"; echo "$3" >"$1/etc/mark"
  }
  mk "$T/root" 6.18.0 now
  mkdir -p "$T/root/etc/sysconfig"; echo UPDATEDEFAULT=yes >"$T/root/etc/sysconfig/kernel"; rm -f "$TMP/adds" "$TMP/recursive"
  for n in 1 41; do
    mk "$T/root/.snapshots/$n/snapshot" 6.17.1 "then$n"
    mkdir -p "$T/root/.snapshots/$n/snapshot/etc/sysconfig"; echo UPDATEDEFAULT=yes >"$T/root/.snapshots/$n/snapshot/etc/sysconfig/kernel"
    : >"$T/root/.snapshots/$n/snapshot/.autorelabel"; ln -sf /var/lib/dnf/system-upgrade "$T/root/.snapshots/$n/snapshot/system-update"
    printf '<?xml version="1.0"?>\n<snapshot>\n  <type>%s</type>\n  <num>%s</num>\n  <date>2026-10-1%s 09:00:00</date>\n  <description>%s</description>\n</snapshot>\n' \
      "$([[ $n == 1 ]] && echo single || echo pre)" "$n" "${n:0:1}" "$([[ $n == 1 ]] && echo 'fedokawaii baseline' || echo 'dnf install a &amp; b')" >"$T/root/.snapshots/$n/info.xml"
  done
  : >"$B/vmlinuz-6.18.0"; printf 'title Fedora\nversion 6.18.0\n' >"$B/loader/entries/abc-6.18.0.conf"
  stub findmnt 'case "$*" in *--fstab*) echo rw,subvol=root,compress=zstd:1 ;; *FSTYPE*) echo btrfs ;;
  *FSROOT*) echo "${FK_FSROOT:-/root}" ;; *SOURCE*) echo "/dev/vda3[/root]" ;; esac'
  # (/home its own subvolume unless FK_HOME_INSIDE: then a restore must be asked --with-home)
  # (/boot and the ESP mounted unless FK_BOOT_UNMOUNTED)
  stub mountpoint "if [ \"\$2\" = \"$T\" ] || { [ \"\$2\" = /home ] && [ -z \"\${FK_HOME_INSIDE:-}\" ]; } || { { [ \"\$2\" = /boot ] || [ \"\$2\" = \"$B/efi\" ]; } && [ -z \"\${FK_BOOT_UNMOUNTED:-}\" ]; }; then exit 0; fi; exit 1"
  stub mount; stub umount; stub restorecon; stub grubby; stub sync; stub grub2-editenv
  stub pgrep 'exit "${FK_PGREP:-1}"'
  ln -sfn /var/lib/dnf/system-upgrade "$T/root/.snapshots/41/snapshot/etc/system-update"
  # (the add records the copy's UPDATEDEFAULT as it runs: the default must not move with it)
  stub chroot 'r=$1; shift; [ "$1 $2" != "kernel-install add" ] || { sed -n "s/^UPDATEDEFAULT=/updatedefault=/p" "$r/etc/sysconfig/kernel" >>"'"$TMP"'/adds"; exit "${FK_ADD:-0}"; }'
  stub kernel-install
  # (exch: the two names swapped in one step, as renameat2 RENAME_EXCHANGE does)
  stub exch '[ -n "${FK_EXCH_FAIL:-}" ] && exit 1; mv -T "$1" "$1.x" && mv -T "$2" "$1" && mv -T "$1.x" "$2"'
  stub btrfs 'case "$1 $2" in
  "subvolume snapshot") cp -a "$3" "$4" ;;
  "subvolume delete") shift 2; [ "$1" = -R ] && { echo "delete -R" >>"'"$TMP"'/recursive"; shift; }; [ "$1" = --commit-after ] && shift; rm -rf "$1" ;;
  "subvolume list") [ -d "$4/.snapshots/1" ] && echo "ID 260 gen 9 top level 256 path <FS_TREE>/${4##*/}/.snapshots"
                    [ -f "$4/home/dia/Downloads/film.mkv" ] && echo "ID 258 gen 9 top level 256 path <FS_TREE>/${4##*/}/home/dia/Downloads" ;;
  "filesystem sync") ;;
  "subvolume show") case $3 in */top/home) [ -z "${FK_HOME_INSIDE:-}" ] || exit 1 ;; *) [ -e "$3" ] || exit 1 ;; esac
                    printf "\tCreation time:\t\t2026-10-16 08:00:00 +0000\n" ;;
esac'
}
flat() {   # the disk as fedokawaii-split leaves it: the snapshots, home, log and fk at the top level
  mv -T "$T/root/.snapshots" "$T/snapshots"; mkdir -p "$T/root/.snapshots" "$T/home" "$T/log" "$T/fk" "$T/snapshots/41/snapshot/usr/local/sbin"
  for n in 1 41; do printf 'UUID=ab12\t/\tbtrfs\tsubvol=root,compress=zstd:1\t0 0\n' >"$T/snapshots/$n/snapshot/etc/fstab"; done
}
case_ "list: every snapshot from its info.xml (XML escapes undone), numbered order, the booted one marked"
disk; out=$(kawa-snap list); eq "$?" 0
eq "$(sed -n 1p <<<"$out")" $'1\tsingle\t2026-10-11 09:00:00\tfedokawaii baseline\t-'
eq "$(sed -n 2p <<<"$out")" $'41\tpre\t2026-10-14 09:00:00\tdnf install a & b\t-'
FK_FSROOT=/root/.snapshots/41/snapshot kawa-snap list | grep -q $'^41\t.*\tbooted$' && _ok || _no "booted not marked"
case_ "a subvolume inside /home (~/Downloads, before the flat layout): moved across, the folders above it made as they were"
disk; mkdir -p "$T/root/home/dia/Downloads"; chmod 700 "$T/root/home/dia"; echo film >"$T/root/home/dia/Downloads/film.mkv"
kawa-snap restore 41 --with-home >/dev/null 2>&1; eq "$?" 0
eq "$(cat "$T/root/home/dia/Downloads/film.mkv" 2>&1)" film; [[ ! -e $T/root.old/home/dia/Downloads ]] && _ok || _no "left in root.old"
eq "$(stat -c %a "$T/root/home/dia")" 700 "home/dia made with another mode"
case_ "…the snapshot has an empty folder in its place: it gives way"
disk; mkdir -p "$T/root/home/dia/Downloads" "$T/root/.snapshots/41/snapshot/home/dia/Downloads"; echo film >"$T/root/home/dia/Downloads/film.mkv"
kawa-snap restore 41 --with-home >/dev/null 2>&1; eq "$?" 0; eq "$(cat "$T/root/home/dia/Downloads/film.mkv" 2>&1)" film
case_ "a kernel put back that kernel-install then leaves in /boot on the way out (an entry without its token): said, nothing else changed"
disk; stub chroot 'r=$1; shift; case "$1 $2" in
  "kernel-install add") : >"'"$B"'/vmlinuz-$3"; : >"'"$B"'/loader/entries/$3.conf"; exit 0 ;;
esac'
out=$(FK_EXCH_FAIL=1 kawa-snap restore 41 --with-home 2>&1); eq "$?" 1; has "$out" "kernel 6.17.1 is still in /boot"; has "$out" "nothing changed"
eq "$(cat "$T/root/etc/mark")" now
case_ "the flat layout (fedokawaii-split): the snapshots read from their own subvolume at the top, the booted one marked"
disk; flat; out=$(kawa-snap list); eq "$?" 0; eq "$(cut -f1 <<<"$out" | paste -sd' ')" "1 41"
FK_FSROOT=/snapshots/41/snapshot kawa-snap list | grep -q $'^41\t.*\tbooted$' && _ok || _no "booted not marked"
case_ "…restore 41, from before the split: the copy gets the layout's fstab lines and mount points, the snapshots stay where they are"
out=$(kawa-snap restore 41 2>&1); eq "$?" 0 "$out"; eq "$(cat "$T/root/etc/mark")" then41   # (no --with-home: his files stay)
called "^btrfs subvolume snapshot $T/snapshots/41/snapshot $T/root.copy\$"
for l in "/home btrfs subvol=home" "/var/log btrfs subvol=log" "/var/lib/fedokawaii/update btrfs subvol=fk" "/.snapshots btrfs subvol=snapshots"; do
  grep -qx "UUID=ab12	${l// /	},compress=zstd:1	0	0" "$T/root/etc/fstab" && _ok || _no "no fstab line for ${l%% *}: $(cat "$T/root/etc/fstab")"
done
grep -qx "UUID=ab12	/	btrfs	subvol=root,compress=zstd:1	0 0" "$T/root/etc/fstab" && _ok || _no "the / line changed"
[[ -d $T/root/var/lib/fedokawaii/update && -f $T/snapshots/41/info.xml && -f $T/snapshots/1/info.xml ]] && _ok || _no "a mount point or a snapshot missing"
case_ "…a copy whose fstab cannot be given the layout: nothing changed"
disk; flat; rm "$T/snapshots/41/snapshot/etc/fstab"; out=$(kawa-snap restore 41 2>&1); eq "$?" 1; has "$out" "the disk's layout"
eq "$(cat "$T/root/etc/mark")" now; [[ ! -e $T/root.new && ! -e $T/root.old ]] && _ok || _no "left changed"
case_ "…today's kawa-snap and fedokawaii-split go into the restored system (an older kawa-snap would look for the snapshots inside it)"
disk; flat; kawa-snap restore 41 >/dev/null 2>&1; eq "$?" 0
cmp -s "$T/root/usr/local/sbin/kawa-snap" "$STUBS/kawa-snap" && cmp -s "$T/root/usr/local/sbin/fedokawaii-split" "$STUBS/fedokawaii-split" \
  && _ok || _no "the restored system has not today's two programs: $(ls "$T/root/usr/local/sbin" 2>&1)"
case_ "a half layout (home at the top, log missing — a split put back in part): not the layout — --with-home asked, no fstab lines given"
disk; flat; rmdir "$T/log"; out=$(kawa-snap restore 41 2>&1); eq "$?" 1; has "$out" "/home is inside the system"
kawa-snap restore 41 --with-home >/dev/null 2>&1; eq "$?" 0; lacks "$(cat "$T/root/etc/fstab")" "subvol=home"
case_ "list on a root that is not Btrfs, or not mounted by subvol=: said, exit 1"
disk; stub findmnt 'case "$*" in *FSTYPE*) echo ext4 ;; esac'; out=$(kawa-snap list 2>&1); eq "$?" 1; has "$out" "not Btrfs"
case_ "restore 41: the copy is the system, the old one kept as root.old, the snapshots moved across, /boot matched"
disk; out=$(kawa-snap restore 41 --with-home 2>&1); eq "$?" 0 "$out"
eq "$(cat "$T/root/etc/mark")" then41; eq "$(cat "$T/root.old/etc/mark")" now
[[ -f $T/root/.snapshots/41/info.xml && ! -e $T/root.old/.snapshots/41 ]] && _ok || _no "the snapshots did not move across"
called '^chroot .*/top/root.new kernel-install add 6.17.1 /usr/lib/modules/6.17.1/vmlinuz$'
called "^grubby --set-default $B/vmlinuz-6.17.1\$"
has "$out" "restart now"
case_ "…in one atomic exchange, synced before and after; the kernels it lacks stay until it has started (no remove now)"
called "^exch $T/root $T/root.new\$"; [[ ! -e $T/root.new ]] && _ok || _no "root.new left behind"
eq "$(grep -c '^btrfs filesystem sync' "$CALLS")" 3 "three syncs (before and after the exchange, after the moves)"
not_called '^kernel-install remove'; [[ ! -e $TMP/recursive ]] && _ok || _no "a recursive delete ran"
case_ "…the kernels added without moving the default (the copy's UPDATEDEFAULT off for the add, back after), the default set last"
eq "$(cat "$TMP/adds")" updatedefault=no; eq "$(cat "$T/root/etc/sysconfig/kernel")" UPDATEDEFAULT=yes
eq "$(grep -n -E '^(exch|grubby)' "$CALLS" | cut -d: -f2 | cut -d' ' -f1 | paste -sd' ')" "exch grubby" "the default after the exchange"
case_ "…the copy starts clean: no /.autorelabel, no /system-update from the snapshot"
[[ ! -e $T/root/.autorelabel && ! -L $T/root/system-update ]] && _ok || _no "a relabel or an offline update would run at its first start"
case_ "…an update's open phase (a run cut, its snapshot offered) ended by the restore: no start judges the restored system by it; none there: none made"
disk; printf 'replay 1793500000\n' >"$TMP/runroot/update-phase"; kawa-snap restore 41 --with-home >/dev/null 2>&1; eq "$?" 0
eq "$(cut -d' ' -f1 "$TMP/runroot/update-phase")" end
disk; rm -f "$TMP/runroot/update-phase"; kawa-snap restore 41 --with-home >/dev/null 2>&1; [[ -e $TMP/runroot/update-phase ]] && _no "a phase made from nothing" || _ok
case_ "restore old: swapped back — the system before the restore again"
kawa-snap restore old --with-home >/dev/null 2>&1; eq "$?" 0
eq "$(cat "$T/root/etc/mark")" now; eq "$(cat "$T/root.old/etc/mark")" then41
[[ -f $T/root/.snapshots/41/info.xml ]] && _ok || _no "the snapshots stayed behind"
case_ "restore whose kernel cannot be put back into /boot: nothing changed"
disk; FK_ADD=1 kawa-snap restore 41 --with-home >/dev/null 2>&1; eq "$?" 1
eq "$(cat "$T/root/etc/mark")" now; [[ ! -e $T/root.old && ! -e $T/root.new ]] && _ok || _no "left changed"
not_called '^grubby'
case_ "an exchange that fails: nothing changed, the copy gone, the default untouched"
disk; FK_EXCH_FAIL=1 kawa-snap restore 41 --with-home >/dev/null 2>&1; eq "$?" 1
eq "$(cat "$T/root/etc/mark")" now; [[ ! -e $T/root.new && ! -e $T/root.old ]] && _ok || _no "left changed"
not_called '^grubby'
case_ "a restore cut after its exchange (the restored system runs, the snapshots still in root.new): finished — its default, the moves — never deleted, nothing else done"
disk; mv -T "$T/root" "$T/root.new"; cp -a "$T/root.new/.snapshots/41/snapshot" "$T/root"
: >"$B/vmlinuz-6.17.1"; echo img >"$B/initramfs-6.17.1.img"; printf 'version 6.17.1\n' >"$B/loader/entries/abc-6.17.1.conf"
out=$(kawa-snap restore 41 --with-home 2>&1); eq "$?" 0 "$out"; has "$out" "a restore cut short after its exchange is finished"
called "^grubby --set-default $B/vmlinuz-6.17.1\$"; not_called '^btrfs subvolume snapshot'

[[ -f $T/root/.snapshots/41/info.xml && -f $T/root/.snapshots/1/info.xml ]] && _ok || _no "the snapshots did not move back"
eq "$(cat "$T/root/etc/mark")" then41; eq "$(cat "$T/root.old/etc/mark")" now; [[ ! -e $T/root.new ]] && _ok || _no "root.new left"
[[ ! -e $TMP/recursive ]] && _ok || _no "a recursive delete ran"
case_ "older replaced systems: two kept with their time in root.old.d (out of the boot menu's list), the older ones removed"
disk; for t in 100 200 300; do mkdir -p "$T/root.old.d/$t"; done; mkdir -p "$T/root.old"; echo older >"$T/root.old/etc-mark"
kawa-snap restore 41 --with-home >/dev/null 2>&1; eq "$?" 0
eq "$(ls "$T/root.old.d" | wc -l)" 2 "two timestamped kept"; [[ ! -e $T/root.old.d/100 && ! -e $T/root.old.d/200 && -e $T/root.old.d/300 ]] && _ok || _no "the wrong ones went: $(ls "$T/root.old.d")"
[[ -f $T/root.old.d/$(ls "$T/root.old.d" | sort -n | tail -n1)/etc-mark ]] && _ok || _no "the root.old before not kept"
kawa-snap list | grep -q 'root.old.d\|^300' && _no "list shows the kept ones" || _ok
case_ "restore of a number that is not there: nothing changed"
disk; out=$(kawa-snap restore 7 --with-home 2>&1); eq "$?" 1; has "$out" "no snapshot 7"; not_called '^btrfs subvolume snapshot'
case_ "restore old with no system before kept: said, nothing changed"
disk; out=$(kawa-snap restore old --with-home 2>&1); eq "$?" 1; has "$out" "no system before the last restore is kept"
case_ "restore: the arguments — a number or old, then --with-home only"
disk; rc 2 kawa-snap restore 41 --bogus; rc 2 kawa-snap restore 41 --with-home extra
case_ "/home inside the system: refused unless --with-home (his files would go back too) — then done"
disk; out=$(FK_HOME_INSIDE=1 kawa-snap restore 41 2>&1); eq "$?" 1; has "$out" "/home is inside the system"
not_called '^btrfs subvolume snapshot'; eq "$(cat "$T/root/etc/mark")" now
FK_HOME_INSIDE=1 kawa-snap restore 41 --with-home >/dev/null 2>&1; eq "$?" 0; eq "$(cat "$T/root/etc/mark")" then41
case_ "/boot written to disk before the exchange (sync -f /boot), the default right after it, then the moves"
disk; kawa-snap restore 41 --with-home >/dev/null 2>&1; eq "$?" 0
order=$(grep -n -E '^(sync -f|exch|grubby|btrfs subvolume list -o)' "$CALLS" | cut -d: -f2 | cut -d' ' -f1-2 | uniq | paste -sd'|')
eq "$order" "sync -f|exch $T/root|grubby --set-default|sync -f|btrfs subvolume" "the order"
case_ "…the copy starts clean: /etc/system-update too"
[[ ! -L $T/root/etc/system-update ]] && _ok || _no "/etc/system-update left in the copy"
case_ "a leftover copy that was never exchanged in (it has the mark): removed, the restore goes on"
disk; cp -a "$T/root/.snapshots/1/snapshot" "$T/root.new"; : >"$T/root.new/.kawa-snap-copy"
out=$(kawa-snap restore 41 --with-home 2>&1); eq "$?" 0 "$out"; eq "$(cat "$T/root/etc/mark")" then41; eq "$(cat "$T/root.old/etc/mark")" now
[[ ! -e $T/root/.kawa-snap-copy ]] && _ok || _no "the restored system still has the copy's mark"
case_ "/boot not mounted: refused, nothing changed (the kernels would land inside the copy)"
disk; out=$(FK_BOOT_UNMOUNTED=1 kawa-snap restore 41 --with-home 2>&1); eq "$?" 1; has "$out" "/boot is not mounted — nothing changed"
not_called '^btrfs subvolume snapshot'
case_ "the default cannot be set: the last line says to choose the kernel, never just 'restart now'"
disk; stub grubby 'exit 1'; out=$(kawa-snap restore 41 --with-home 2>&1); eq "$?" 0
has "$out" "at the next start, choose kernel 6.17.1 in the boot menu"; lacks "$out" "restart now"
case_ "finish: a restore cut after its exchange — the snapshots back, its default; list says so until then"
disk; mv -T "$T/root" "$T/root.new"; cp -a "$T/root.new/.snapshots/41/snapshot" "$T/root"
: >"$B/vmlinuz-6.17.1"; echo img >"$B/initramfs-6.17.1.img"; printf 'version 6.17.1\n' >"$B/loader/entries/abc-6.17.1.conf"
out=$(kawa-snap list 2>&1 >/dev/null); has "$out" "a restore was cut short after its exchange"
out=$(kawa-snap finish 2>&1); eq "$?" 0 "$out"; has "$out" "a restore cut short after its exchange is finished"
[[ -f $T/root/.snapshots/41/info.xml && ! -e $T/root.new ]] && _ok || _no "not finished"; called "^grubby --set-default $B/vmlinuz-6.17.1\$"
out=$(kawa-snap finish 2>&1); eq "$?" 0; has "$out" "no restore to finish"
case_ "a leftover root.copy (a run cut before it marked its copy): removed — never taken for the system that ran"
disk; cp -a "$T/root/.snapshots/1/snapshot" "$T/root.copy"
out=$(kawa-snap restore 41 --with-home 2>&1); eq "$?" 0 "$out"; [[ ! -e $T/root.copy ]] && _ok || _no "root.copy left"
eq "$(cat "$T/root/etc/mark")" then41; eq "$(cat "$T/root.old/etc/mark")" now; lacks "$out" "cut short after its exchange"
case_ "…the copy made as root.copy, marked, then named root.new (a cut never leaves an unmarked root.new)"
called "^btrfs subvolume snapshot $T/root/.snapshots/41/snapshot $T/root.copy\$"
case_ "a kernel with only its vmlinuz in /boot (no image, no entry): put back whole"
disk; : >"$B/vmlinuz-6.17.1"; kawa-snap restore 41 --with-home >/dev/null 2>&1; eq "$?" 0
called '^chroot .*/top/root.new kernel-install add 6.17.1 '
case_ "a kernel whole in /boot: left as it is"
disk; : >"$B/vmlinuz-6.17.1"; echo img >"$B/initramfs-6.17.1.img"; printf 'version 6.17.1\n' >"$B/loader/entries/abc-6.17.1.conf"
kawa-snap restore 41 --with-home >/dev/null 2>&1; eq "$?" 0; not_called 'kernel-install add'
case_ "a kernel that cannot go in: the ones this run added taken out again, the copy's UPDATEDEFAULT back, nothing changed"
disk; FK_ADD=1 kawa-snap restore 41 --with-home >/dev/null 2>&1; eq "$?" 1
called '^chroot .*/top/root.new kernel-install remove 6.17.1$'; eq "$(cat "$T/root/etc/mark")" now
case_ "another restore running (its lock held): refused, nothing changed"
disk; mkdir -p "$TMP/runroot"; flock "$TMP/runroot/kawa-snap.lock" sleep 3 & sleep 0.3
out=$(kawa-snap restore 41 --with-home 2>&1); eq "$?" 1; has "$out" "another restore is running"; not_called '^btrfs subvolume snapshot'; wait
case_ "a package transaction running: refused, nothing changed"
disk; out=$(FK_PGREP=0 kawa-snap restore 41 --with-home 2>&1); eq "$?" 1; has "$out" "a package transaction is running"
case_ "the system that ran cannot be named root.old: kept in root.old.d with its time, never left as root.new"
disk; : >"$T/root.old"; kawa-snap restore 41 --with-home >/dev/null 2>&1; eq "$?" 0
[[ ! -e $T/root.new ]] && _ok || _no "left as root.new"
[[ -n $(ls "$T/root.old.d" 2>/dev/null | grep -- '-') ]] && _ok || _no "not kept in root.old.d: $(ls "$T/root.old.d" 2>&1)"
case_ "from a snapshot started from the boot menu (/ an overlay): the disk and the snapshot from the kernel's arguments"
disk; printf 'BOOT_IMAGE=/vmlinuz-6.17.1 root=UUID=1234-ab ro rootflags=subvol=root/.snapshots/41/snapshot systemd.volatile=overlay\n' >"$P/cmdline"
stub findmnt 'case "$*" in *--fstab*) echo rw,subvol=root,compress=zstd:1 ;; *FSTYPE*) echo overlay ;; *) echo overlay ;; esac'
stub mountpoint "if [ \"\$2\" = /home ] || [ \"\$2\" = /boot ] || [ \"\$2\" = \"$B/efi\" ]; then exit 0; fi; exit 1"   # (the top not mounted yet: mounted from the kernel's root=)
kawa-snap list | grep -q $'^41\t.*\tbooted$' && _ok || _no "the booted snapshot not marked"
kawa-snap restore 41 --with-home >/dev/null 2>&1; eq "$?" 0; called '^mount -o subvolid=5 /dev/disk/by-uuid/1234-ab '
eq "$(cat "$T/root/etc/mark")" then41

done_
