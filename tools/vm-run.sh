#!/usr/bin/env bash
# tools/vm-run.sh — a command in a test VM (tools/vm-create.sh) over ssh, its exit status back;
# or files in and out.
#   bash tools/vm-run.sh NAME CMD…           run CMD (a shell line) as dia in the VM
#   bash tools/vm-run.sh NAME --repo [DIR]   this repository's tracked files (as they are in the
#                                            working tree) into ~/fedokawaii in the VM (DIR: another)
#   bash tools/vm-run.sh NAME --get PATH OUT a file from the VM (PATH) to OUT on this PC
#   bash tools/vm-run.sh NAME --wait [S]     until ssh answers (default 600 s)
# Exit: CMD's status · 255 ssh could not reach it · 2 misuse.
set -u
H=$HOME/VM/harness
name=${1:-}
[[ $name =~ ^[a-z0-9-]+$ && -d $H/$name && $# -ge 2 ]] || { echo "usage: bash tools/vm-run.sh NAME CMD… | --repo | --get PATH OUT | --wait" >&2; exit 2; }
shift
port=$(cat "$H/$name/port" 2>/dev/null) || { echo "vm-run: $name has no port (not created by vm-create.sh?)" >&2; exit 2; }
SSH=(ssh -q -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5
     -o ServerAliveInterval=15 -i "$H/id_ed25519" -p "$port" dia@127.0.0.1)
case $1 in
  --repo)
    src=${2:-$(cd "$(dirname "$0")/.." && pwd)}
    # (a Minimal Install has no tar: the README's first command puts it there, as here)
    "${SSH[@]}" 'command -v tar >/dev/null || sudo dnf install -y -q tar >/dev/null' || exit 1
    # (tracked files, from the working tree: what apply would take, uncommitted edits included)
    git -C "$src" ls-files -z | tar -C "$src" --null -T - -cf - \
      | "${SSH[@]}" 'rm -rf ~/fedokawaii && mkdir -p ~/fedokawaii && tar -C ~/fedokawaii -xf -' ;;
  --get)
    [[ $# -eq 3 ]] || { echo "usage: bash tools/vm-run.sh NAME --get PATH OUT" >&2; exit 2; }
    "${SSH[@]}" "cat -- '$2'" >"$3" ;;
  --wait)
    end=$((SECONDS + ${2:-600}))
    until "${SSH[@]}" true 2>/dev/null; do
      ((SECONDS >= end)) && { echo "vm-run: $name: no ssh within ${2:-600} s" >&2; exit 255; }
      sleep 5
    done ;;
  *) "${SSH[@]}" "$*" ;;
esac
