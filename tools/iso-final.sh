#!/usr/bin/env bash
# tools/iso-final.sh — the installer that ships, in one command: built from one commit, proven in a fresh VM, released.
#   bash tools/iso-final.sh COMMIT CARRY.qcow2     the build, the owner's whole path (tools/vm-iso-test.sh whole), the refusals
#   bash tools/iso-final.sh --release COMMIT       after a green proof of that commit: its tag pushed, the GitHub release
# It tags the commit vYYYY.MM.DD (its own date) here before the build, for the toolkit in the ISO to know which release it is;
# the tag leaves this PC only with --release, because the update button adopts every v… tag it finds on GitHub. The tools run
# from a copy of the commit (bash reads a running script from disk), the ISO and the record go under ~/VM/iso/final/SHORT/.
# Exit: 0 green · 1 red (the record says where) · 2 misuse.
set -u
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/.." && pwd)
release=0
if [[ ${1:-} == --release ]]; then release=1; shift; fi
commit=$(git -C "$repo" rev-parse --verify "${1:-}^{commit}" 2>/dev/null) || { sed -n '2,3p' "$0" >&2; exit 2; }
short=${commit:0:7}
dir=$HOME/VM/iso/final/$short
tag=v$(TZ=UTC git -C "$repo" log -1 --date=format-local:%Y.%m.%d --format=%cd "$commit")

if ((release)); then
  [[ -s $dir/green ]] || { echo "iso-final: no green proof of $short in $dir" >&2; exit 1; }
  iso=$(cat "$dir/green")
  git -C "$repo" push origin "refs/tags/$tag" || exit 1
  gh release create "$tag" "$iso" "$iso.sha256" --repo MoeDia/fedokawaii --title "fedokawaii ${tag#v}" \
    --notes "The installer, built from $short: README, From the ISO. Proven whole: $(sed -n 's/^.*GREEN: //p' "$dir/record" | tail -n1)" || exit 1
  exit 0
fi

carry=${2:-}
[[ -s $carry ]] && [[ -s $carry.sums ]] || { echo "iso-final: no drive of test things at '$carry' (vm-iso-test.sh carry-save)" >&2; exit 2; }
mkdir -p "$dir"
exec > >(tee -a "$dir/record") 2>&1
say() { printf '%s %s\n' "$(date +%T)" "$*"; }
say "commit $commit, tag $tag"
[[ $(git -C "$repo" rev-parse -q --verify "refs/tags/$tag^{commit}") == "$commit" ]] || git -C "$repo" tag -f "$tag" "$commit" >/dev/null || exit 1
frozen=$dir/tools
rm -rf "$frozen"; mkdir -p "$frozen"
git -C "$repo" archive "$commit" tools art system lib iso | tar -xf - -C "$frozen" || exit 1
nice -n 10 bash "$frozen/tools/build-iso.sh" --ref "$commit" --out "$dir" || { say "RED: the build"; exit 1; }
iso=$(compgen -G "$dir/fedokawaii-*-$short.iso") || { say "RED: no ISO in $dir"; exit 1; }
say "built: $(cat "$iso.sha256")"
vm=(bash "$frozen/tools/vm-iso-test.sh")
"${vm[@]}" whole r27-iso "$iso" "$carry" --no-sb; rc=$?
cp -a "$HOME/VM/iso/vm/r27-iso/run" "$dir/run" 2>/dev/null
"${vm[@]}" stop r27-iso >/dev/null 2>&1
((rc == 0)) || { say "RED: the whole path, exit $rc: $dir/run/log"; exit 1; }
"${vm[@]}" matrix "$iso" "$dir/matrix" >/dev/null; n=$(grep -c '^green' "$dir/matrix/matrix.txt")
reds=$(grep -c '^RED' "$dir/matrix/matrix.txt")
((reds == 0)) || { say "RED: the refusals, $reds of them: $dir/matrix/matrix.txt"; exit 1; }
printf '%s\n' "$iso" >"$dir/green"
say "GREEN: the whole path and $n refusals, $(sed -n 's/^.*verify after the update: //p' "$dir/run/log" | tail -n1): $iso"
