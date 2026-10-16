#!/usr/bin/env bash
# tests/installer/test_upstream.sh — lib/upstream.sh: the desktop's pinned tools from GitHub
# releases (satty, yazi, presenterm, spotify_player), the Nerd Fonts, PixelMplus and GE-Proton,
# in the fake machine with fake releases. Each is fetched, checked against its pinned SHA-256
# and put in the user's home by the user; a second run finds it in place; a download that
# differs by a byte, is cut off half-way or cannot happen at all changes nothing; a library
# the binary needs is installed from whichever package provides it now; GE-Proton follows its
# newest release and keeps the two newest.
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
back start; fkh ldd-missing "spotify_player libssl.so.3"; fkh provides "libssl.so.3()(64bit) openssl3-libs"; fkh_add available openssl3-libs
up 'install_upstream_bin "${UPSTREAM[3]}"'; eq "$RC" 0
has "$OUT" "spotify_player needs libssl.so.3()(64bit)"; pkg_has openssl3-libs && _ok || _no "openssl3-libs not installed"
eq "$(cat "$W/var/lib/fedokawaii/upstream-libs")" openssl3-libs
fkrun bash -c '. /home/fkuser/fedokawaii/lib/manifest.sh; STATE_DIR=/var/lib/fedokawaii manifest_all amd'
has "$OUT" openssl3-libs "the manifest counts it (verify never takes it for something you added)"
case_ "…none provides it: nothing installed (exit 1)"
back start; fkh ldd-missing "spotify_player libssl.so.3"
up 'install_upstream_bin "${UPSTREAM[3]}"'; eq "$RC" 1; has "$OUT" "spotify_player is still missing: libssl.so.3"
[[ ! -e $W$H/.local/bin/spotify_player ]] && _ok || _no "installed without its library"
case_ "the copy in your home lost a library since: fetched again (its fresh copy says what it needs)"
back start; up "install_upstream_bin $satty"; fkh ldd-missing "satty libgtk-4.so.1"
fkh provides "libgtk-4.so.1()(64bit) gtk4"; fkh_add available gtk4
up "install_upstream_bin $satty"; eq "$RC" 0; has "$OUT" "satty v0.22.0 lacks a library — fetching it again"; pkg_has gtk4 && _ok || _no "gtk4 not installed"

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
case_ "the Nerd Fonts: each family in its folder, by you, tags recorded, the font cache made"
back start; up 'install_nerd_fonts'; eq "$RC" 0
[[ -s $W$H/.local/share/fonts/JetBrainsMonoNerd/JetBrainsMonoNerdFont-Regular.ttf && -s $W$H/.local/share/fonts/DepartureMonoNerd/DepartureMonoNerdFont-Regular.otf ]] && _ok || _no "a family missing"
eq "$(cat "$W$H/.local/share/fedokawaii/upstream/nerd-DepartureMono")" v3.5.1
called 'fkuser\[fc-cache\] -f'
reset_calls; up 'install_nerd_fonts'; has "$OUT" "JetBrainsMono Nerd Font v3.5.1 — in place"; not_called curl
case_ "one family's download altered: that one refused (exit 1), the other installed"
back start; printf 'x' >>"$dl/JetBrainsMono.tar.xz"
up 'install_nerd_fonts'; eq "$RC" 1
[[ ! -e $W$H/.local/share/fonts/JetBrainsMonoNerd && -s $W$H/.local/share/fonts/DepartureMonoNerd/DepartureMonoNerdFont-Regular.otf ]] && _ok || _no "wrong families installed"
case_ "PixelMplus: only the 12 px faces and the licence"
back start; up 'install_pixelmplus'; eq "$RC" 0
eq "$(ls "$W$H/.local/share/fonts/PixelMplus" | tr '\n' ' ')" "LICENSE_E PixelMplus12-Regular.ttf "
up 'install_pixelmplus'; has "$OUT" "PixelMplus 12 — in place"

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
case_ "an archive holding two top folders (or none with Steam's file): refused"
ge_release GE-Proton10-27; r=$TMP/two; mkdir -p "$r/GE-Proton10-27" "$r/GE-ProtonX"; : >"$r/GE-Proton10-27/compatibilitytool.vdf"
tar -czf "$dl/GE-Proton10-27.tar.gz" -C "$r" .; (cd "$dl" && sha512sum GE-Proton10-27.tar.gz >GE-Proton10-27.sha512sum)
up 'install_ge_proton'; eq "$RC" 1; has "$OUT" "did not hold one GE-Proton folder"

done_
