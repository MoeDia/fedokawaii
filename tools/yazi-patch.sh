#!/usr/bin/env bash
# tools/yazi-patch.sh — src/yazi/yazi.patch regenerated from an edited yazi tree: a checkout of YAZI_COMMIT
# (fedokawaii.conf) with your edits in its working tree. Its first lines say what the patch is (git apply reads past them).
#   bash tools/yazi-patch.sh YAZI_TREE
# Exit: 0 written · 1 not a checkout of the pinned commit.
set -eu
tree=${1:?usage: yazi-patch.sh YAZI_TREE}
repo=$(cd "$(dirname "$0")/.." && pwd)
pin=$(sed -n 's/^YAZI_COMMIT="\([0-9a-f]\{40\}\)".*/\1/p' "$repo/fedokawaii.conf")
[[ $(git -C "$tree" rev-parse HEAD 2>/dev/null) == "$pin" ]] || { echo "yazi-patch: $tree is not a checkout of $pin" >&2; exit 1; }
out=$repo/src/yazi/yazi.patch
{
  cat <<'HEAD'
src/yazi/yazi.patch — the desktop's yazi (setup.sh: build_yazi), against YAZI_TAG/YAZI_COMMIT (fedokawaii.conf).
yazi 26.9.1 draws its pop-ups in Rust: rounded, their titles in the rule, theme.toml reaching only their colours. Here every
one of them (rename and the other inputs, trash and the other confirms, help, which, open with, completion, tasks, notices) is
§4's panel drawn in whole cells of Sumi Icons Term (yazi-fm/src/frame.rs), with §7's heading inside, its keys as tiles; never a
rounded frame, from Lua either; a confirm fits what it says; its files named under their folder. `yazi --version`: Patch.
Regenerate: tools/yazi-patch.sh.

HEAD
  git -C "$tree" add -N . >/dev/null
  git -C "$tree" diff --no-color
} >"$out.$$" && mv -f "$out.$$" "$out"
echo "yazi-patch: $(grep -c '^diff ' "$out") files → src/yazi/yazi.patch"
