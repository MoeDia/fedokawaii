#!/usr/bin/env bash
# tests/engine/test_inventory.sh — Super+U → system → inventory (kawa-inventory): the table of
# every app, read from the manifest and the pins — versions from dnf, never a list of its own.
. "$(dirname "$0")/lib.sh"
sandbox
INV=$REPO/bin/kawa-inventory
stub dnf5 'printf "%s\n" "neovim|0.12.6|updates" "ffmpeg|8.1.3|rpmfusion-free-updates" "lact|0.10.1|copr:copr.fedorainfracloud.org:ilyaz:LACT" "claude-code|2.1.309|@stored_transaction(claude-code)" "git|2.50|anaconda" "not-ours|1|fedora"'
export PATH=$STUBS:$PATH KAWA_TOOLKIT=$REPO
out=$("$INV" --tsv); eq "$?" 0 "the table is made"
case_ "every row has four fields, the manifest's apps only"
bad=$(awk -F'\t' 'NF != 4' <<<"$out" | wc -l); eq "$bad" 0 "four fields a row"
has "$out" $'neovim\t0.12.6\tFedora\t' "a Fedora package"
has "$out" $'ffmpeg\t8.1.3\tRPM Fusion\t' "RPM Fusion's"
has "$out" $'lact\t0.10.1\tCOPR ilyaz/LACT\t' "a COPR's"
has "$out" $'git\t2.50\tFedora\t' "the installer's own means Fedora"
has "$out" $'claude-code\t2.1.309\tits repository (claude-code)\t' "a vendor repository by its name"
lacks "$out" "not-ours" "a package the manifest does not list"
case_ "the pinned releases and ASOBI's programs"
has "$out" $'yazi\t' "a pinned release"; has "$out" "github.com/sxyazi/yazi release" "its source"
has "$out" $'Steam\t-\tFlathub (in ASOBI)\tasobi' "a Flatpak of ASOBI"
case_ "the aligned table and misuse"
has "$("$INV")" "pinned; changes with the desktop" "the aligned form"
case_ "what we changed and the menus of our own"
mod=$("$INV" modified); has "$mod" "yazi" "a patched app"; has "$mod" "patched," "how"; has "$mod" "kawa-saver" "a program written here"
men=$("$INV" menus); has "$men" "kawa-power" "a menu"; lacks "$men" "kawa-dwlstatus" "a script that only mentions menus"
rc 2 "$INV" --x
done_
