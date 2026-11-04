#!/usr/bin/env bash
# tools/vm-preflight.sh — Fedora N tried before this machine moves to it (T46; update-design.md §4.4):
# a test VM (tools/vm-create.sh) installs Fedora N from its release tree, this whole desktop goes on
# it from nothing and starts (tools/vm-smoke.sh), what a new Fedora brings is checked
# (tools/vm-inject/f45-checks.sh). The VM is gone afterwards, whatever came of it: no file of it
# stays. Run as the desktop's user (a session VM); the update button runs it (lib/move.sh) and keeps
# the verdict. From the installed toolkit too: that folder has no .git, the harness wants one — a
# throw-away copy made one.
#   bash tools/vm-preflight.sh N [--out FILE] [--name NAME] [--port P] [--keep] [--ram MB]
#     --out   the verdict: nothing when green, else a line a reason (the failing checks)
#     --name  the VM's name (pf-N) · --port its ssh port (2299) · --keep the VM stays, to look at it
# A red install takes no longer to say so than a green one: about an hour, at the lowest priority.
# Exit 0 green · 1 red (the desktop does not install or start there) · 2 it could not run (no KVM,
# no room, Fedora N's tree unreachable): no verdict on Fedora N.
set -u
n="" out=/dev/null name="" port=2299 keep=0 ram=8192
while (($#)); do
  case $1 in
    --out) out=$2; shift 2 ;;
    --name) name=$2; shift 2 ;;
    --port) port=$2; shift 2 ;;
    --ram) ram=$2; shift 2 ;;
    --keep) keep=1; shift ;;
    -h|--help) sed -n '2,/^set -u/{/^set -u/d;s/^# \{0,1\}//;p}' "$0"; exit 0 ;;
    -*) echo "vm-preflight: unknown option $1" >&2; exit 2 ;;
    *) n=$1; shift ;;
  esac
done
[[ $n =~ ^[0-9]+$ ]] || { echo "usage: bash tools/vm-preflight.sh N [--out FILE] [--name NAME] [--port P] [--keep]" >&2; exit 2; }
name=${name:-pf-$n}
: >"$out"
say() { printf '%s %s\n' "$(date +%T)" "$*" >&2; }
cannot() { printf '%s\n' "$*" >"$out"; say "it could not run: $*"; exit 2; }
red() { printf '%s\n' "$@" >"$out"; say "red: $1"; exit 1; }

here=$(cd "$(dirname "$0")" && pwd)
root=${here%/tools}
[[ -r /dev/kvm && -w /dev/kvm ]] || cannot "no KVM here (/dev/kvm)"
for t in virt-install virsh qemu-img git; do command -v "$t" >/dev/null || cannot "$t is missing (fedokawaii repair puts it in)"; done
room=$(df --output=avail -BG "$HOME" | sed -n '2s/[^0-9]//gp')
((room >= 40)) || cannot "only $room GB free in your home; the test VM needs 40"
ss -ltn "sport = :$port" 2>/dev/null | grep -q LISTEN && cannot "port $port is taken"

copy=""
if ! git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  copy=$(mktemp -d) || cannot "no room for a copy of the toolkit"
  cp -a "$root/." "$copy/" && git -C "$copy" init -q && git -C "$copy" add -A || cannot "the copy of the toolkit could not be made"
  root=$copy here=$copy/tools
fi
watcher=""
gone() {
  [[ -z $watcher ]] || kill "$watcher" 2>/dev/null
  ((keep)) || bash "$here/vm-snap.sh" "$name" destroy >/dev/null 2>&1
  [[ -z $copy ]] || rm -rf -- "$copy"
}
trap gone EXIT
# a stale one from a run that was cut: never kept
[[ -d $HOME/VM/harness/$name ]] && { bash "$here/vm-snap.sh" "$name" destroy >/dev/null 2>&1 || cannot "the old VM $name could not be removed"; }
# (the VM's threads at the lowest priority: libvirt's daemon starts them, not this shell — and new
# ones come at each start)
pidf=$HOME/.cache/libvirt/qemu/run/fk-$name.pid
( while sleep 20; do
    p=$(cat "$pidf" 2>/dev/null) || continue
    for t in /proc/"$p"/task/*; do renice -n 19 -p "${t##*/}" >/dev/null 2>&1; done
  done ) & watcher=$!

say "Fedora $n: installing it in a test VM ($name)"
bash "$here/vm-create.sh" "$name" --release "$n" --port "$port" --ram "$ram" >&2 \
  || { [[ -d $HOME/VM/harness/$name ]] && tail -n 3 "$HOME/VM/harness/$name/virt-install.log" >&2; cannot "Fedora $n could not be installed in the test VM (its tree, or the network)"; }
say "Fedora $n: this desktop on it, from nothing, then started"
bash "$here/vm-smoke.sh" "$name" --timeout 240 >&2; rc=$?
s=$(ls -d "$HOME/VM/harness/$name"/smoke-* 2>/dev/null | sed -n '$p')
if ((rc != 0)); then
  # (the summary's reason, then what verify names: the first ten)
  mapfile -t why < <(
    [[ -s $s/summary ]] && sed 's/^[^·]*·[^·]*·[^·]*· //' "$s/summary"
    [[ -s $s/verify.log ]] && sed 's/\x1b\[[0-9;]*m//g' "$s/verify.log" | sed -n 's/^.*✘ *//p' | sed -n 1,10p)
  red "${why[@]:-the install stopped, with no reason written}"
fi
say "Fedora $n: what a new Fedora brings, checked"
mapfile -t why < <(FK_CHECKS_OUT=$(mktemp -d) bash "$here/vm-inject/f45-checks.sh" "$name" "$root" 2>&1 | sed -n 's/^red *//p')
((${#why[@]} == 0)) || red "${why[@]}"
say "Fedora $n: green"
exit 0
