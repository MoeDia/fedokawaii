#!/usr/bin/env bash
# tools/kit-tree-home.sh DEST — the home theme.sh makes from the tree, for tools/kit.sh --tree: the
# real theme.sh run once in the installer tests' fake machine (tests/installer/lib.sh), so its
# system half lands in the fake /etc and /usr/local and nothing of this machine changes. DEST gets
# the desktop user's files, owned by the caller; /home/fkuser in them is the kit's to replace.
dest=$(realpath -m "${1:?usage: kit-tree-home.sh DEST}")
. "$(dirname "$0")/../tests/installer/lib.sh"
world built
sed -i 's/^WALLPAPER_PACK=.*/WALLPAPER_PACK="no"/' "$W/usr/local/lib/fedokawaii/fedokawaii.conf"
fk_perms
fk bash /usr/local/lib/fedokawaii/theme.sh --user fkuser >"$TMP/theme-first.log" 2>&1 || { tail -n 20 "$TMP/theme-first.log"; exit 1; }
rm -rf "$dest"; mkdir -p "$dest"
tar -C "$W/home/fkuser" --exclude=./fedokawaii --exclude=./.local/src -cf - . | tar -C "$dest" --no-same-owner -xf - || exit 1
tail -n 3 "$TMP/theme-first.log"
