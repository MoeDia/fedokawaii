#!/usr/bin/env bash
# tests/installer/test_upstream.sh — lib/upstream.sh: the desktop's pinned tools from GitHub
# releases (satty, yazi, bluetui, lazygit, herdr), the Nerd Font, Fusion Pixel and GE-Proton,
# in the fake machine with fake releases. Each is fetched, checked against its pinned SHA-256
# and put in the user's home by the user; a second run finds it in place; a download that
# differs by a byte, is cut off half-way or cannot happen at all changes nothing; a library
# the binary needs is installed from whichever package provides it now; GE-Proton follows its
# newest release and keeps the two newest. Syncplay and ble.sh come from their pinned commits:
# fetched and built by the user, put in only once they load. LocalSend's release is a folder,
# kept whole.
. "$(dirname "$0")/lib.sh"
H=/home/fkuser
LIB=/home/fkuser/fedokawaii/lib
# up CODE — bash CODE with lib/common.sh and lib/upstream.sh loaded, as setup has them (root,
# the desktop user fkuser, a private temp folder): output in $OUT, status in $RC
up() {
  fkrun bash -c 'set -u; LOG_FILE=/var/log/fk-upstream.log; . "$1/common.sh"; . "$1/upstream.sh"
    export TARGET_USER=fkuser TARGET_HOME=/home/fkuser TARGET_UID=31000 TARGET_GID=31000 STATE_DIR=/var/lib/fedokawaii
    make_tmp; eval "$2"' _ "$LIB" "$1"
}
satty='"${UPSTREAM[0]}"'

world fresh; releases
dl=$FKH/dl
keep start

# ── a pinned binary ──────────────────────────────────────────────────────────
case_ "install_upstream_bin: fetched, checked, put in ~/.local/bin by you, its tag recorded"
up "install_upstream_bin $satty"; eq "$RC" 0
has "$OUT" "verified: satty-x86_64-unknown-linux-gnu.tar.gz"; has "$OUT" "✔ satty v0.22.0 → ~/.local/bin (satty)"
[[ -x $W$H/.local/bin/satty ]] && _ok || _no "satty not installed"
eq "$(fk stat -c '%U %a' "$H/.local/bin/satty")" "fkuser 755"
eq "$(cat "$W$H/.local/share/fedokawaii/upstream/satty")" v0.22.0
eq "$(fk stat -c %U "$H/.local/share/fedokawaii/upstream/satty")" fkuser
case_ "a second run: in place, nothing downloaded"
reset_calls; up "install_upstream_bin $satty"; eq "$RC" 0; has "$OUT" "satty v0.22.0 — in place"; not_called 'curl'
case_ "yazi (a zip with two binaries in a folder): both installed"
up 'install_upstream_bin "${UPSTREAM[1]}"'; eq "$RC" 0
[[ -x $W$H/.local/bin/yazi && -x $W$H/.local/bin/ya ]] && _ok || _no "yazi or ya missing"
case_ "bluetui (the release file is the binary itself, no archive): installed under the tool's name"
up 'install_upstream_bin "${UPSTREAM[2]}"'; eq "$RC" 0
has "$OUT" "verified: bluetui-x86_64-linux-musl"; has "$OUT" "✔ bluetui v0.8.2 → ~/.local/bin (bluetui)"
eq "$(fk "$H/.local/bin/bluetui" 2>&1)" "bluetui 0.8.2" "runs as ~/.local/bin/bluetui"
eq "$(cat "$W$H/.local/share/fedokawaii/upstream/bluetui")" v0.8.2

case_ "lazygit (its binary at the archive's top, beside LICENSE and README): installed alone, its tag recorded"
up 'install_upstream_bin "$(printf "%s\n" "${UPSTREAM[@]}" | grep "^lazygit|")"'; eq "$RC" 0
has "$OUT" "✔ lazygit v0.66.1 → ~/.local/bin (lazygit)"
[[ -x $W$H/.local/bin/lazygit && ! -e $W$H/.local/bin/LICENSE && ! -e $W$H/.local/bin/README.md ]] && _ok || _no "lazygit missing, or its LICENSE / README put in ~/.local/bin"
eq "$(cat "$W$H/.local/share/fedokawaii/upstream/lazygit")" v0.66.1
case_ "herdr (its release file is the binary itself, like bluetui's): installed under the tool's name"
up 'install_upstream_bin "$(printf "%s\n" "${UPSTREAM[@]}" | grep "^herdr|")"'; eq "$RC" 0
has "$OUT" "verified: herdr-linux-x86_64"; has "$OUT" "✔ herdr v0.9.5 → ~/.local/bin (herdr)"
eq "$(fk "$H/.local/bin/herdr" --version 2>&1)" "herdr 0.9.5" "runs as ~/.local/bin/herdr"
eq "$(cat "$W$H/.local/share/fedokawaii/upstream/herdr")" v0.9.5
case_ "an older tag recorded: fetched again, the new tag recorded"
echo v0.21.0 >"$W$H/.local/share/fedokawaii/upstream/satty"
reset_calls; up "install_upstream_bin $satty"; eq "$RC" 0; called 'curl.*satty-x86_64'
eq "$(cat "$W$H/.local/share/fedokawaii/upstream/satty")" v0.22.0

case_ "a download that differs by one byte: refused, nothing installed, no tag (exit 1)"
back start; printf 'x' >>"$dl/satty-x86_64-unknown-linux-gnu.tar.gz"
up "install_upstream_bin $satty"; eq "$RC" 1
has "$OUT" "its SHA-256 is not the pinned one — refused"
[[ ! -e $W$H/.local/bin/satty && ! -e $W$H/.local/share/fedokawaii/upstream/satty ]] && _ok || _no "something was installed"
case_ "…the same with a working copy already there: it stays as it was"
back start; up "install_upstream_bin $satty"; printf 'x' >>"$dl/satty-x86_64-unknown-linux-gnu.tar.gz"
echo v0.21.0 >"$W$H/.local/share/fedokawaii/upstream/satty"; before=$(sha256sum <"$W$H/.local/bin/satty")
up "install_upstream_bin $satty"; eq "$RC" 1
eq "$(sha256sum <"$W$H/.local/bin/satty")" "$before" "the copy there untouched"
case_ "offline: three tries (the pause stubbed), then 'download failed', nothing changed (exit 1)"
back start; fkh net off
up "install_upstream_bin $satty"; eq "$RC" 1
has "$OUT" "attempt 3/3 failed"; has "$OUT" "download failed: https://github.com/gabm/Satty/releases/download/v0.22.0/"
[[ ! -e $W$H/.local/bin/satty ]] && _ok || _no "installed while offline"
case_ "a transfer cut off half-way every time: refused (never a half file installed)"
back start; fkh partial-satty-x86_64-unknown-linux-gnu.tar.gz
up "install_upstream_bin $satty"; eq "$RC" 1; [[ ! -e $W$H/.local/bin/satty ]] && _ok || _no "a half download installed"
case_ "a transfer that times out once: the second try installs it"
back start; fkh fail-curl-satty-x86_64-unknown-linux-gnu.tar.gz 1
up "install_upstream_bin $satty"; eq "$RC" 0; has "$OUT" "attempt 1/3 failed"; [[ -x $W$H/.local/bin/satty ]] && _ok || _no "not installed"
case_ "the release renamed its binary: said, nothing installed (exit 1)"
back start; up 'e=${UPSTREAM[0]%|*}; install_upstream_bin "$e|satty-gtk"'; eq "$RC" 1
has "$OUT" "satty-gtk not found inside the satty v0.22.0 archive"
[[ ! -e $W$H/.local/share/fedokawaii/upstream/satty ]] && _ok || _no "a tag recorded for nothing"

# ── libraries ────────────────────────────────────────────────────────────────
case_ "a library the binary needs and Fedora no longer pulls in: installed by its name, recorded for the manifest"
back start; fkh ldd-missing "satty libssl.so.3"; fkh provides "libssl.so.3()(64bit) openssl3-libs"; fkh_add available openssl3-libs
up "install_upstream_bin $satty"; eq "$RC" 0
has "$OUT" "satty needs libssl.so.3()(64bit)"; pkg_has openssl3-libs && _ok || _no "openssl3-libs not installed"
eq "$(cat "$W/var/lib/fedokawaii/upstream-libs")" openssl3-libs
fkrun bash -c '. /home/fkuser/fedokawaii/lib/manifest.sh; STEAM=yes STATE_DIR=/var/lib/fedokawaii manifest_all amd'
has "$OUT" openssl3-libs "the manifest counts it (verify never takes it for something you added)"
case_ "…none provides it: nothing installed (exit 1)"
back start; fkh ldd-missing "satty libssl.so.3"
up "install_upstream_bin $satty"; eq "$RC" 1; has "$OUT" "satty is still missing: libssl.so.3"
[[ ! -e $W$H/.local/bin/satty ]] && _ok || _no "installed without its library"
case_ "the copy in your home lost a library since: fetched again (its fresh copy says what it needs)"
back start; up "install_upstream_bin $satty"; fkh ldd-missing "satty libgtk-4.so.1"
fkh provides "libgtk-4.so.1()(64bit) gtk4"; fkh_add available gtk4
up "install_upstream_bin $satty"; eq "$RC" 0; has "$OUT" "satty v0.22.0 lacks a library — fetching it again"; pkg_has gtk4 && _ok || _no "gtk4 not installed"

# ── the tools the desktop no longer has ──────────────────────────────────────
case_ "retire_upstream: presenterm and spotify_player (ours: their records say so) out of ~/.local/bin, records too"
back start; up "install_upstream_bin $satty"
for t in presenterm spotify_player; do
  printf '#!/bin/sh\n' >"$W$H/.local/bin/$t"; echo v0.1.0 >"$W$H/.local/share/fedokawaii/upstream/$t"
done
printf '#!/bin/sh\n# mine\n' >"$W$H/.local/bin/presenterm-mine"
fk chown -hR fkuser:fkuser "$H/.local"
up retire_upstream; eq "$RC" 0
has "$OUT" "presenterm — no longer part of the desktop"; has "$OUT" "spotify_player — no longer part of the desktop"
[[ ! -e $W$H/.local/bin/presenterm && ! -e $W$H/.local/bin/spotify_player ]] && _ok || _no "a retired binary stayed"
[[ ! -e $W$H/.local/share/fedokawaii/upstream/presenterm && ! -e $W$H/.local/share/fedokawaii/upstream/spotify_player ]] && _ok || _no "a record stayed"
[[ -x $W$H/.local/bin/satty && -f $W$H/.local/bin/presenterm-mine ]] && _ok || _no "a current tool, or a file of yours, went too"
case_ "…a presenterm of your own (no record of ours): left alone; a second run says nothing"
printf '#!/bin/sh\n' >"$W$H/.local/bin/presenterm"; fk chown fkuser:fkuser "$H/.local/bin/presenterm"
up retire_upstream; eq "$RC" 0; lacks "$OUT" "no longer part"
[[ -e $W$H/.local/bin/presenterm ]] && _ok || _no "yours was taken"

# ── what is written into the home ────────────────────────────────────────────
case_ "record_tag: a link planted where the tag goes is replaced, never followed (root's file untouched)"
back start; mkdir -p "$W$H/.local/share/fedokawaii/upstream"; ln -s ../../../../../../etc/passwd "$W$H/.local/share/fedokawaii/upstream/satty"
fk chown -hR fkuser:fkuser "$H/.local/share/fedokawaii"; pw=$(sha256sum <"$W/etc/passwd")
up 'record_tag satty v0.22.0'; eq "$RC" 0
eq "$(sha256sum <"$W/etc/passwd")" "$pw" "/etc/passwd"
[[ -f $W$H/.local/share/fedokawaii/upstream/satty && ! -L $W$H/.local/share/fedokawaii/upstream/satty ]] && _ok || _no "the link is still there"
case_ "up_tag: a tag file of a megabyte is read as its first 200 bytes"
rm -f "$W$H/.local/share/fedokawaii/upstream/satty"      # (never written through whatever is there)
head -c 1000000 /dev/zero | tr '\0' 'v' >"$W$H/.local/share/fedokawaii/upstream/satty"
up 'printf %s "$(up_tag satty)" | wc -c'; eq "$OUT" 200

case_ "user_put: written by the user, in one step; a link planted there replaced, its target untouched"
fk bash -c 'mkdir -p /home/fkuser/d; ln -s ../../../etc/passwd /home/fkuser/d/f; chown -hR fkuser:fkuser /home/fkuser/d'
pw=$(sha256sum <"$W/etc/passwd")
fkrun bash -c 'LOG_FILE=/dev/null; . /home/fkuser/fedokawaii/lib/common.sh; export TARGET_USER=fkuser TARGET_HOME=/home/fkuser TARGET_UID=31000
  echo hello | user_put 0640 /home/fkuser/d/f; echo rc=$?; stat -c "%U %a" /home/fkuser/d/f'
has "$OUT" "rc=0"; has "$OUT" "fkuser 640"; eq "$(sha256sum <"$W/etc/passwd")" "$pw" "/etc/passwd untouched"
eq "$(fk bash -c '[[ -L /home/fkuser/d/f ]] || cat /home/fkuser/d/f')" hello "a plain file now, with the content"
case_ "user_put into a folder of root's: refused (the user cannot write there), root's folder untouched"
fkrun bash -c 'LOG_FILE=/dev/null; . /home/fkuser/fedokawaii/lib/common.sh; export TARGET_USER=fkuser TARGET_HOME=/home/fkuser TARGET_UID=31000
  echo hello | user_put 0644 /etc/fk-new; echo rc=$?'
has "$OUT" "rc=1"; [[ ! -e $W/etc/fk-new ]] && _ok || _no "the user wrote into /etc"

# ── fonts ────────────────────────────────────────────────────────────────────
case_ "the Nerd Font: in its folder, by you, its tag recorded, the font cache made"
back start; up 'install_nerd_fonts'; eq "$RC" 0
[[ -s $W$H/.local/share/fonts/JetBrainsMonoNerd/JetBrainsMonoNerdFont-Regular.ttf ]] && _ok || _no "the family missing"
eq "$(cat "$W$H/.local/share/fedokawaii/upstream/nerd-JetBrainsMono")" v3.5.1
called 'fkuser\[fc-cache\] -f'
reset_calls; up 'install_nerd_fonts'; has "$OUT" "JetBrainsMono Nerd Font v3.5.1 — in place"; not_called curl
case_ "the download altered: refused (exit 1), nothing installed, no tag"
back start; printf 'x' >>"$dl/JetBrainsMono.tar.xz"
up 'install_nerd_fonts'; eq "$RC" 1
[[ ! -e $W$H/.local/share/fonts/JetBrainsMonoNerd && ! -e $W$H/.local/share/fedokawaii/upstream/nerd-JetBrainsMono ]] && _ok || _no "an altered download installed"
case_ "a file that cannot be written (a full home; here a folder you cannot write): failed and said, no tag — also where errexit is off (repair calls these under ||)"
back start; mkdir -p "$W$H/.local/bin" "$W$H/.local/share/fonts"; fk chown -R fkuser:fkuser "$H/.local"
fk chmod 555 "$H/.local/bin" "$H/.local/share/fonts"
up "install_upstream_bin $satty || echo FAILED"; has "$OUT" "FAILED"; lacks "$OUT" "✔ satty"
[[ ! -e $W$H/.local/share/fedokawaii/upstream/satty ]] && _ok || _no "the tag recorded for a binary not written"
up 'install_nerd_fonts || echo FAILED'; has "$OUT" "FAILED"
[[ ! -e $W$H/.local/share/fedokawaii/upstream/nerd-JetBrainsMono ]] && _ok || _no "the tag recorded for fonts not written"
fk chmod 755 "$H/.local/bin" "$H/.local/share/fonts"
case_ "Fusion Pixel 12 and 10: for every account (/usr/local/share/fonts), only the Japanese faces and the licence; the fonts before it gone from the home"
back start; mkdir -p "$W$H/.local/share/fonts/PixelMplus" "$W$H/.local/share/fonts/DepartureMonoNerd" "$W$H/.local/share/fedokawaii/upstream"
echo v3.5.1 >"$W$H/.local/share/fedokawaii/upstream/nerd-DepartureMono"; fk chown -R fkuser:fkuser "$H/.local"
up 'install_fusion'; eq "$RC" 0
eq "$(ls -A "$W/usr/local/share/fonts/fusion-pixel" | tr '\n' ' ')" ".version OFL.txt fusion-pixel-10px-monospaced-ja.ttf fusion-pixel-12px-monospaced-ja.ttf "
eq "$(stat -c '%U %a' "$W/usr/local/share/fonts/fusion-pixel/fusion-pixel-12px-monospaced-ja.ttf" "$W/usr/local/share/fonts/fusion-pixel/fusion-pixel-10px-monospaced-ja.ttf" | sort -u)" "root 644"
[[ ! -e $W$H/.local/share/fonts/PixelMplus && ! -e $W$H/.local/share/fonts/DepartureMonoNerd && ! -e $W$H/.local/share/fedokawaii/upstream/nerd-DepartureMono ]] && _ok || _no "an old pixel font left in the home"
called '^root\[fc-cache\] -f /usr/local/share/fonts/fusion-pixel'
reset_calls; up 'install_fusion'; has "$OUT" "Fusion Pixel 12 and 10 2026.08.11 — in place"; not_called curl
case_ "Fusion Pixel's download altered: refused, nothing installed"
back start; printf 'x' >>"$dl/fusion-pixel-font-10px-monospaced-ttf-v$(. "$REPO/lib/upstream.sh"; echo "$FUSION_TAG").zip"
up 'install_fusion'; eq "$RC" 1; [[ ! -e $W/usr/local/share/fonts/fusion-pixel ]] && _ok || _no "an altered font installed"

# ── Syncplay, from its pinned source ─────────────────────────────────────────
sp=$W$H/.local/share/fedokawaii/syncplay spt=$W$H/.local/share/fedokawaii/upstream/syncplay
PIN=$(. "$REPO/lib/upstream.sh"; syncplay_pin)   # (the commit, + the patch's SHA-256, 12 characters)
as_fk() { fkrun runuser -u fkuser -- env -i HOME=$H PATH=/usr/bin:/bin "$@"; }
case_ "install_syncplay: the tag fetched by you, checked against the pinned commit, our patch applied; its folder and two starters put in by you; the pin recorded"
back start; reset_calls
up 'install_syncplay'; eq "$RC" 0
has "$OUT" "✔ Syncplay v1.7.6 (no window) → ~/.local/bin (syncplay, syncplay-server)"
called '^fkuser\[git\] -c advice.detachedHead=false clone --quiet --depth 1 --branch v1.7.6 https://github.com/Syncplay/syncplay.git '
eq "$(fk stat -c '%U %a' "$H/.local/bin/syncplay")" "fkuser 755"; eq "$(fk stat -c '%U %a' "$H/.local/bin/syncplay-server")" "fkuser 755"
eq "$(fk stat -c %U "$H/.local/share/fedokawaii/syncplay/syncplay/__init__.py")" fkuser
called '^fkuser\[git\] -C /tmp/.*/s apply -$'
has "$(cat "$sp/syncplay/vendor/python_mpv_jsonipc/python_mpv_jsonipc.py" 2>/dev/null)" "# applied: src/syncplay/syncplay.patch" "the copy put in carries the patch"
[[ $PIN =~ ^993232ab095bb810593459bc705b3e6fc64ad161\+[0-9a-f]{12}$ ]] && _ok || _no "the pin: $PIN"
eq "$(cat "$spt")" "$PIN"
case_ "…its starter: Fedora's python3, isolated (-I), unbuffered (-u), always without the window (--no-gui)"
s=$(cat "$W$H/.local/bin/syncplay")
has "$s" "py=/usr/bin/python3 dir=$H/.local/share/fedokawaii/syncplay"; has "$s" 'exec "$py" -I -u -c'
as_fk "$H/.local/bin/syncplay" --version; has "$OUT" "You're using Syncplay version 1.7.6 (Yoitsu)"
as_fk "$H/.local/bin/syncplay" --room 'film night'; eq "$OUT" "syncplay (fake): --no-gui --room film night"
as_fk "$H/.local/bin/syncplay-server"; eq "$OUT" "syncplay-server (fake)"
case_ "a second run: in place, nothing fetched"
reset_calls; up 'install_syncplay'; eq "$RC" 0; has "$OUT" "Syncplay v1.7.6 — in place"; not_called 'git.* clone'
keep syncplay
case_ "the tag no longer the pinned commit: refused, the copy there untouched (exit 1)"
fkh tag-v1.7.6 0123456789012345678901234567890123456789; echo 1111111111111111111111111111111111111111 >"$spt"
before=$(cat "$W$H/.local/bin/syncplay"; cat "$sp/syncplay/__init__.py")
up 'install_syncplay'; eq "$RC" 1; has "$OUT" "Syncplay's tag v1.7.6 is not the pinned commit 993232ab095bb810593459bc705b3e6fc64ad161 — refused"
eq "$(cat "$W$H/.local/bin/syncplay"; cat "$sp/syncplay/__init__.py")" "$before"; eq "$(cat "$spt")" 1111111111111111111111111111111111111111
case_ "another commit recorded (the pin moved on): fetched again, the pin recorded"
back syncplay; echo 1111111111111111111111111111111111111111 >"$spt"; reset_calls
up 'install_syncplay'; eq "$RC" 0; called 'git.* clone .*Syncplay'; eq "$(cat "$spt")" "$PIN"
case_ "the pinned commit recorded without our patch (an install from before it): fetched again, with it"
back syncplay; echo 993232ab095bb810593459bc705b3e6fc64ad161 >"$spt"; reset_calls
up 'install_syncplay'; eq "$RC" 0; called 'git.* clone .*Syncplay'; called 'git\] -C .* apply -$'; eq "$(cat "$spt")" "$PIN"
case_ "the patch does not apply: refused, the copy there untouched (exit 1)"
back syncplay; echo 1111111111111111111111111111111111111111 >"$spt"; fkh rc-git-apply 1
before=$(cat "$W$H/.local/bin/syncplay"; cat "$sp/syncplay/__init__.py")
up 'install_syncplay'; eq "$RC" 1; has "$OUT" "src/syncplay/syncplay.patch does not apply to Syncplay v1.7.6 — refused"
eq "$(cat "$W$H/.local/bin/syncplay"; cat "$sp/syncplay/__init__.py")" "$before"; eq "$(cat "$spt")" 1111111111111111111111111111111111111111
rm -f "$FKH/rc-git-apply"
case_ "a starter gone, or one an older toolkit wrote: written again, nothing fetched"
back syncplay; rm -f "$W$H/.local/bin/syncplay-server"; sed -i 's/ -I -u -c / -I -c /' "$W$H/.local/bin/syncplay"; reset_calls
up 'install_syncplay'; eq "$RC" 0; has "$OUT" "Syncplay v1.7.6 — in place"; not_called 'git.* clone'
[[ -x $W$H/.local/bin/syncplay-server ]] && _ok || _no "syncplay-server not put back"
has "$(cat "$W$H/.local/bin/syncplay")" 'exec "$py" -I -u -c' "the older starter not written again"
case_ "Fedora's Twisted missing: said what the manifest installs, the copy there stays (exit 1)"
back syncplay; mv "$FK_PYLIBS/twisted" "$TMP/twisted.away"; echo 1111111111111111111111111111111111111111 >"$spt"
up 'install_syncplay'; eq "$RC" 1
has "$OUT" "does not load with /usr/bin/python3 — are the manifest's python3-twisted+tls"
[[ -f $sp/syncplay/client.py && -x $W$H/.local/bin/syncplay ]] && _ok || _no "the copy there was taken away"
mv "$TMP/twisted.away" "$FK_PYLIBS/twisted"
case_ "a copy whose libraries went since: not 'in place' (fetched again, and said when it still does not load)"
back syncplay; mv "$FK_PYLIBS/twisted" "$TMP/twisted.away"
up 'install_syncplay'; eq "$RC" 1; lacks "$OUT" "in place"
mv "$TMP/twisted.away" "$FK_PYLIBS/twisted"
case_ "offline: three tries (the pause stubbed), then said; nothing installed (exit 1)"
back start; fkh net off
up 'install_syncplay'; eq "$RC" 1; has "$OUT" "attempt 3/3 failed"; has "$OUT" "could not fetch Syncplay v1.7.6"
[[ ! -e $W$H/.local/bin/syncplay && ! -e $sp && ! -e $spt ]] && _ok || _no "something installed while offline"

# ── ble.sh, from its pinned commit ───────────────────────────────────────────
bd=$W$H/.local/share/blesh bt=$W$H/.local/share/fedokawaii/upstream/blesh
BLESH=$(. "$REPO/lib/upstream.sh"; echo "$BLESH_COMMIT")
case_ "install_blesh: the pinned commit fetched by its hash, by you, with its contrib/ part; built by you into a new folder; that copy put in and the commit recorded"
back start; reset_calls
up 'install_blesh'; eq "$RC" 0
has "$OUT" "✔ ble.sh ${BLESH:0:7} (the shell's colours, suggestions and menus) → ~/.local/share/blesh"
called "^fkuser\[git\] init -q /tmp/[^ ]*/s$"
called "^fkuser\[git\] -C /tmp/[^ ]*/s remote add origin https://github.com/akinomyoga/ble.sh.git$"
called "^fkuser\[git\] -C /tmp/[^ ]*/s fetch -q --depth 1 origin $BLESH$"
called "^fkuser\[git\] -C /tmp/[^ ]*/s -c advice.detachedHead=false checkout -q FETCH_HEAD$"
called "^fkuser\[git\] -C /tmp/[^ ]*/s submodule update -q --init --depth 1$"
called "^fkuser\[make\] -C /tmp/[^ ]*/s install INSDIR=/tmp/[^ ]*/new$"
eq "$(fk stat -c %U "$H/.local/share/blesh/ble.sh")" fkuser
eq "$(cat "$bt")" "$BLESH"
as_fk bash "$H/.local/share/blesh/ble.sh" --version; eq "$OUT" "ble.sh (Bash Line Editor), version 0.4.0-devel4+${BLESH:0:7}"
case_ "a second run: in place, nothing fetched"
reset_calls; up 'install_blesh'; eq "$RC" 0; has "$OUT" "ble.sh ${BLESH:0:7} — in place"; not_called '\[git\]'; not_called '\[make\]'
keep blesh
case_ "another commit recorded (the pin moved on), or a copy that is another commit: fetched and built again"
echo 1111111111111111111111111111111111111111 >"$bt"; reset_calls
up 'install_blesh'; eq "$RC" 0; called "git\] .* fetch -q --depth 1 origin $BLESH$"; eq "$(cat "$bt")" "$BLESH"
back blesh; sed -i "s/+${BLESH:0:7}/+0123456/" "$bd/ble.sh"; reset_calls
up 'install_blesh'; eq "$RC" 0; called 'make\] -C'; has "$(cat "$bd/ble.sh")" "+${BLESH:0:7}"
case_ "the build fails, or builds a copy that is not the pinned commit: refused, the copy there untouched (exit 1)"
back blesh; echo 1111111111111111111111111111111111111111 >"$bt"; before=$(cat "$bd/ble.sh"); fkh rc-make-blesh 2
up 'install_blesh'; eq "$RC" 1; has "$OUT" "ble.sh ${BLESH:0:7} did not build"
eq "$(cat "$bd/ble.sh")" "$before"; eq "$(cat "$bt")" 1111111111111111111111111111111111111111
rm -f "$FKH/rc-make-blesh"; fkh blesh-version 0.4.0-devel4+0123456
up 'install_blesh'; eq "$RC" 1; has "$OUT" "the ble.sh just built does not load as ${BLESH:0:7} — refused"
eq "$(cat "$bd/ble.sh")" "$before"; rm -f "$FKH/blesh-version"
case_ "its contrib/ part cut off once: tried again, put in"
back start; fkh fail-git-submodule 1
up 'install_blesh'; eq "$RC" 0; has "$OUT" "attempt 1/3 failed"; eq "$(cat "$bt")" "$BLESH"
case_ "offline: three tries (the pause stubbed), then said; nothing installed (exit 1)"
back start; fkh net off
up 'install_blesh'; eq "$RC" 1; has "$OUT" "attempt 3/3 failed"; has "$OUT" "could not fetch ble.sh ${BLESH:0:7}"
[[ ! -e $bd && ! -e $bt ]] && _ok || _no "something installed while offline"

# ── GE-Proton ────────────────────────────────────────────────────────────────
pd=$W$H/.local/share/Steam/compatibilitytools.d
ge_release() {   # ge_release NAME [TOP-FOLDER] — a newer release on the fake GitHub
  local n=$1 top=${2:-$1} r=$TMP/ge-$1
  rm -rf "$r"; mkdir -p "$r/$top"; echo '"compatibilitytools" { }' >"$r/$top/compatibilitytool.vdf"
  tar -czf "$dl/$n.tar.gz" -C "$r" "$top"; (cd "$dl" && sha512sum "$n.tar.gz" >"${n%-x86_64}.sha512sum.all")
  { echo "0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000  GE-ProtonX-aarch64.tar.gz"
    cat "$dl/${n%-x86_64}.sha512sum.all"; } >"$dl/$n.sha512sum"
  printf '{"tag_name":"%s","assets":[{"name":"%s.sha512sum","browser_download_url":"https://github.com/x/%s.sha512sum"},{"name":"%s.tar.gz","browser_download_url":"https://github.com/x/%s.tar.gz"},{"name":"GE-ProtonX-aarch64.tar.gz","browser_download_url":"https://github.com/x/GE-ProtonX-aarch64.tar.gz"}]}\n' \
    "${n%-x86_64}" "$n" "$n" "$n" "$n" >"$FKH/ge.json"
}
case_ "install_ge_proton: the newest release, checked against its own SHA-512, unpacked by you, tag recorded"
back start; up 'install_ge_proton'; eq "$RC" 0
[[ -f $pd/GE-Proton10-25/compatibilitytool.vdf ]] && _ok || _no "not unpacked"
eq "$(fk stat -c %U "$H/.local/share/Steam/compatibilitytools.d/GE-Proton10-25")" fkuser
eq "$(cat "$W$H/.local/share/fedokawaii/upstream/ge-proton")" GE-Proton10-25
case_ "…in place: nothing downloaded; a folder another tool put there is recorded as it is"
reset_calls; up 'install_ge_proton'; has "$OUT" "GE-Proton10-25 — in place"; not_called 'curl.*tar.gz'
rm -f "$W$H/.local/share/fedokawaii/upstream/ge-proton"; up 'install_ge_proton'
eq "$(cat "$W$H/.local/share/fedokawaii/upstream/ge-proton")" GE-Proton10-25 "recorded again"
case_ "a newer release (the -x86_64 naming of GE-Proton 11): installed, the newest two kept — by version, not by text"
mkdir -p "$pd/GE-Proton9-27" "$pd/GE-Proton10-9"; fk chown -R fkuser:fkuser "$H/.local/share/Steam"
ge_release GE-Proton11-1-x86_64
up 'install_ge_proton'; eq "$RC" 0
eq "$(ls "$pd" | sort -V | tr '\n' ' ')" "GE-Proton10-25 GE-Proton11-1-x86_64 "
eq "$(cat "$W$H/.local/share/fedokawaii/upstream/ge-proton")" GE-Proton11-1-x86_64
case_ "its checksum not matching: refused, nothing changed (exit 1)"
back start; up 'install_ge_proton'; ge_release GE-Proton10-26; printf 'x' >>"$dl/GE-Proton10-26.tar.gz"
up 'install_ge_proton'; eq "$RC" 1; has "$OUT" "checksum mismatch — refused"
eq "$(ls "$pd" | tr '\n' ' ')" "GE-Proton10-25 "
case_ "GitHub not reachable, or no x86_64 file in the release: said, nothing changed (exit 1)"
fkh net off; up 'install_ge_proton'; eq "$RC" 1; has "$OUT" "GitHub not reachable for GE-Proton"
rm -f "$FKH/net"; fkh ge.json '{"tag_name":"GE-Proton12-1","assets":[{"name":"GE-Proton12-1-aarch64.tar.gz","browser_download_url":"https://x/a.tar.gz"},{"name":"GE-Proton12-1-aarch64.sha512sum","browser_download_url":"https://x/a.sha512sum"}]}'
up 'install_ge_proton'; eq "$RC" 1; has "$OUT" "no GE-Proton release file for x86_64"
fkh ge.json 'this is not JSON'; up 'install_ge_proton'; eq "$RC" 1
up 'set -e; install_ge_proton'; eq "$RC" 1; has "$OUT" "no GE-Proton release file" "not JSON (a Wi-Fi sign-in page), under set -e as setup runs it: said plainly"
eq "$(ls "$pd" | tr '\n' ' ')" "GE-Proton10-25 "
case_ "unpacking cut off half-way (a power cut, a full home): nothing half-made is left to pass for installed"
# (your tar stops with Steam's file not yet written, once, while $FKH/cut-unpack is there)
cut_tar() { stub tar 'case " $* " in *" -xf - "*) /usr/bin/tar "$@"
  [ -f /var/lib/fkh/cut-unpack ] && { rm -f /var/lib/fkh/cut-unpack; find "$2" -name compatibilitytool.vdf -delete; exit 2; } ;;
  *) exec /usr/bin/tar "$@" ;; esac'; fkh cut-unpack; }
back start; cut_tar; up 'set -e; install_ge_proton'; [[ $RC != 0 ]] && _ok || _no "a cut-off unpack ended 0 (under set -e, as setup runs it)"
[[ -z $(ls "$pd" 2>/dev/null) ]] && _ok || _no "left in compatibilitytools.d: $(ls -A "$pd" | tr '\n' ' ')"
eq "$(cat "$W$H/.local/share/fedokawaii/upstream/ge-proton" 2>/dev/null)" "" "nothing recorded"
up 'install_ge_proton'; eq "$RC" 0; lacks "$OUT" "in place"
[[ -f $pd/GE-Proton10-25/compatibilitytool.vdf ]] && _ok || _no "the next run did not put it in whole"
case_ "…the same where errexit is off (repair calls it under ||): failed, said, nothing recorded"
back start; cut_tar; up 'install_ge_proton || echo "FAILED"'; has "$OUT" "FAILED"
eq "$(cat "$W$H/.local/share/fedokawaii/upstream/ge-proton" 2>/dev/null)" "" "nothing recorded"
[[ -z $(ls "$pd" 2>/dev/null) ]] && _ok || _no "left in compatibilitytools.d: $(ls -A "$pd" | tr '\n' ' ')"
rm -f "$STUBS/tar"
case_ "an archive holding two top folders (or none with Steam's file): refused"
ge_release GE-Proton10-27; r=$TMP/two; mkdir -p "$r/GE-Proton10-27" "$r/GE-ProtonX"; : >"$r/GE-Proton10-27/compatibilitytool.vdf"
tar -czf "$dl/GE-Proton10-27.tar.gz" -C "$r" .; (cd "$dl" && sha512sum GE-Proton10-27.tar.gz >GE-Proton10-27.sha512sum)
up 'install_ge_proton'; eq "$RC" 1; has "$OUT" "did not hold one GE-Proton folder"

# ── LocalSend: a release that is a whole folder ─────────────────────────────────────────
case_ "install_localsend: the folder whole in ~/.local/share/localsend, yours; localsend points into it; its tag recorded"
back start; up "install_localsend"; eq "$RC" 0 "$OUT"
has "$OUT" "verified: LocalSend-1.18.0-linux-x86-64.tar.gz"; has "$OUT" "✔ LocalSend v1.18.0 → ~/.local/share/localsend (localsend)"
[[ -x $W$H/.local/share/localsend/localsend_app && -f $W$H/.local/share/localsend/lib/libapp.so && -f $W$H/.local/share/localsend/data/flutter_assets/assets/img/logo-512.png ]] \
  && _ok || _no "the folder is not whole: $(cd "$W$H/.local/share/localsend" 2>/dev/null && find . | tr '\n' ' ')"
eq "$(readlink "$W$H/.local/bin/localsend")" ../share/localsend/localsend_app
eq "$(fk "$H/.local/bin/localsend" 2>&1)" "localsend_app 1.18.0" "runs through the link"
eq "$(fk stat -c %U "$H/.local/share/localsend/localsend_app")" fkuser
eq "$(cat "$W$H/.local/share/fedokawaii/upstream/localsend")" v1.18.0
case_ "…a second run: in place, nothing downloaded"
reset_calls; up "install_localsend"; eq "$RC" 0; has "$OUT" "LocalSend v1.18.0 — in place"; not_called 'curl'
case_ "…an older release there: replaced whole (no file of the old one left), the new tag recorded"
echo v1.17.0 >"$W$H/.local/share/fedokawaii/upstream/localsend"; echo old >"$W$H/.local/share/localsend/lib/libold.so"
up "install_localsend"; eq "$RC" 0
[[ ! -e $W$H/.local/share/localsend/lib/libold.so && ! -e $W$H/.local/share/localsend.new ]] && _ok || _no "the old release's file stayed"
eq "$(cat "$W$H/.local/share/fedokawaii/upstream/localsend")" v1.18.0
case_ "…a download that differs by one byte: refused, the copy there untouched (exit 1)"
printf 'x' >>"$dl/LocalSend-1.18.0-linux-x86-64.tar.gz"; echo v1.17.0 >"$W$H/.local/share/fedokawaii/upstream/localsend"
up "install_localsend"; eq "$RC" 1; has "$OUT" "its SHA-256 is not the pinned one — refused"
[[ -x $W$H/.local/share/localsend/localsend_app ]] && _ok || _no "the working copy was touched"
eq "$(cat "$W$H/.local/share/fedokawaii/upstream/localsend")" v1.17.0

done_
