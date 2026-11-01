#!/usr/bin/env bash
# tools/vm-clone.sh — a second test VM from one made by tools/vm-create.sh, so two proofs can run
# side by side: its fresh install and saved states are reflink copies (no space until they differ;
# the states keep reading SRC's base image, never written), its own disk, UEFI variables, serial
# log and ssh port. tools/vm-snap.sh and vm-run.sh then take NAME like any other.
#   bash tools/vm-clone.sh SRC NAME [--port P]   (P: SRC's port + 1)
# Exit 0 · 1 it could not · 2 misuse.
set -u
H=$HOME/VM/harness
V=(virsh -q -c qemu:///session)
src=${1:-} name=${2:-}; shift 2 2>/dev/null || true
port=""; [[ ${1:-} == --port && ${2:-} =~ ^[0-9]+$ ]] && port=$2
[[ $src =~ ^[a-z0-9-]+$ && $name =~ ^[a-z0-9-]+$ && -d $H/$src && ! -e $H/$name ]] \
  || { echo "usage: bash tools/vm-clone.sh SRC NAME [--port P] (SRC made by vm-create.sh, NAME new)" >&2; exit 2; }
[[ $("${V[@]}" domstate "fk-$src" 2>/dev/null) == "shut off" ]] || { echo "vm-clone: stop fk-$src first (vm-snap.sh $src stop)" >&2; exit 1; }
port=${port:-$(($(cat "$H/$src/port") + 1))}
S=$H/$src D=$H/$name
mkdir -p "$D" || exit 1
for f in base.qcow2 nvram.base.fd "$S"/state-*; do
  cp --reflink=auto "$S/${f##*/}" "$D/" || { rm -rf "$D"; exit 1; }
done
qemu-img create -q -f qcow2 -b "$D/base.qcow2" -F qcow2 "$D/disk.qcow2" || { rm -rf "$D"; exit 1; }
echo "$port" >"$D/port"
nv=$HOME/.config/libvirt/qemu/nvram/fk-${name}_VARS.qcow2
cp --reflink=auto "$D/nvram.base.fd" "$nv" || { rm -rf "$D"; exit 1; }
# (SRC's definition with NAME's files: no uuid or mac of SRC's, the port forward on P)
"${V[@]}" dumpxml "fk-$src" \
  | sed -e "s|<name>fk-$src</name>|<name>fk-$name</name>|" -e '/<uuid>/d' -e '/<mac address=/d' \
        -e "s|$S/|$D/|g" -e "s|>[^<]*fk-${src}_VARS\.qcow2<|>$nv<|" \
        -e "/<portForward/,/<\/portForward>/s|<range start='[0-9]*'|<range start='$port'|" >"$D/domain.xml"
"${V[@]}" define "$D/domain.xml" >/dev/null || { rm -rf "$D" "$nv"; echo "vm-clone: the definition was refused ($D/domain.xml)" >&2; exit 1; }
st=(); for f in "$D"/state-*.qcow2; do [[ -f $f ]] && { f=${f##*/state-}; st+=("${f%.qcow2}"); }; done
echo "vm-clone: fk-$name ready from fk-$src (ssh port $port; states: ${st[*]:-none})"
