#!/usr/bin/env bash
# tests/static/test_deps.sh — nothing the desktop runs is missing from a fresh install.
# Every program called by the scripts in bin/ and system/, the session (autostart.sh), the
# shell (~/.bashrc.d), waybar's exec and clicks, mako's actions, the launcher entries, yazi's
# keymaps and plugins (and yazi's own openers and previews), dwl's keys, the systemd units and
# the other configs must come from bin/ or system/, lib/upstream.sh, setup's own builds, a
# package lib/manifest.sh installs, or a Fedora 44 Minimal Install (fixtures/programs.txt says
# which, package by package). The same for every launcher entry mimeapps.list names.
# First, the reader itself (shcmds.py): what it must and must not take for a program.
. "$(dirname "$0")/../lib/harness.sh"
S=$(cd "$(dirname "$0")" && pwd)
sandbox
# (sorted: a substitution's program is met before the command around it)
progs() { python3 "$S/shcmds.py" -c "$1" | cut -f2 | LC_ALL=C sort | tr '\n' ' ' | sed 's/ $//'; }
guarded() { python3 "$S/shcmds.py" -c "$1" | awk -F'\t' '$3 == "guarded" { print $2 }' | tr '\n' ' ' | sed 's/ $//'; }

# ── the reader ───────────────────────────────────────────────────────────────────────────
case_ "pipes, lists and groups: each program in turn"
eq "$(progs 'a | b && c || d; e & f
{ g; } ; (h)')" "a b c d e f g h"
case_ "arguments are not programs, however they look"
eq "$(progs 'echo rm -rf / ; printf "%s" "kill"; grep -q sudo file')" "grep"
case_ "assignments, local and export: the program after them, the ones inside them"
eq "$(progs 'A=1 B="$(uname -r)" curl -s x; local v=$(date +%s) w=`hostname`')" "curl date hostname uname"
case_ "\$( ), backticks, <( ) and \${x:-\$( )}: read again as programs"
eq "$(progs 'x=$(jq . <<<"$(cat f)"); y=${z:-$(id -u)}; while read -r l; do :; done < <(lsblk -J)')" "cat id jq lsblk"
case_ "\$(( )), (( )) and [[ … =~ (a|b) ]]: arithmetic and tests, no programs"
eq "$(progs '(( n > 1 )) && x=$(( n * 2 )); [[ $a =~ ^(foo|bar)$ && -n $(tr a b) ]] && wc -l')" "tr wc"
case_ "case patterns are not programs; the commands under them are"
eq "$(progs 'case $1 in start|stop) systemctl "$1" ;; (*.png) magick "$1" x.jpg ;; *) exit 2 ;; esac')" "magick systemctl"
case_ "case inside \$( ): its ) does not end the substitution"
eq "$(progs 'x=$(case $a in b) date ;; esac); stat f')" "date stat"
case_ "here-documents: data, except the \$( ) of an unquoted one"
eq "$(progs 'cat <<EOF
rm -rf /
$(uname)
EOF
python3 - <<'"'"'PY'"'"'
import os; os.system("reboot")
PY
sort x')" "cat python3 sort uname"
case_ "comments are not programs; a # inside a word is not a comment"
eq "$(progs '# rm -rf /
grep -c x#y f   # wipe')" "grep"
case_ "functions defined in the script are not programs; their bodies are read"
eq "$(progs 'f() { curl x; }
function g { wget y; }
f; g; h')" "curl h wget"
case_ "programs that run a program: the one they run counts too"
eq "$(progs 'setsid -f kawa-term yazi "$d"; timeout -s KILL 3 nvim --server s; env -u X A=1 nice -n 5 btop')" \
   "btop env kawa-term nice nvim setsid timeout yazi"
eq "$(progs 'sudo -u bob snapper list; footclient -a float -T t -- lazygit; foot -D "$d" -- htop; footclient')" \
   "foot footclient footclient htop lazygit snapper sudo"
eq "$(progs 'kawa-float --once n "title" 60x21 -- zathura x; kawa-float bad use')" "kawa-float kawa-float zathura"
eq "$(progs 'flock -n 9 || exit 0; flock /tmp/l tar -c x; xargs -0 -r rm -f; find . -name x -exec stat {} +')" \
   "find flock flock rm stat tar xargs"
eq "$(progs 'exec swaybg -c x; exec 9>lock; command ls; nohup wl-paste &')" "ls nohup swaybg wl-paste"
case_ "shell handed over as text: sh -c, trap, swayidle, alias"
eq "$(progs "sh -c 'cat a; tac b' _; trap 'rm -f \"\$t\"' EXIT; swayidle -w timeout 600 'kawa-lock' resume 'wlopm --on x' before-sleep 'kawa-lock --now'; alias ll='eza -l'")" \
   "cat eza kawa-lock kawa-lock rm sh swayidle tac wlopm"
case_ "the desktop's helpers by full path, and /usr/bin/x, are found by name"
eq "$(progs '"$HOME/.local/bin/kawa-x" a; ~/.local/bin/kawa-y; /usr/bin/zz; /usr/local/bin/fedokawaii remind')" \
   "fedokawaii kawa-x kawa-y zz"
case_ "a name only known when it runs is left out"
eq "$(progs '"$cmd" a; "${arr[@]}"; $X')" ""
case_ "python inside a script: subprocess.run([\"prog\", …])"
eq "$(progs 'python3 -c '"'"'import subprocess; subprocess.run(["pdfinfo", p])'"'"'')" "pdfinfo python3"
case_ "guarded: checked with command -v (or type / hash), or with a fallback after ||"
eq "$(guarded 'command -v kawa-veil >/dev/null && kawa-veil x; dbus-update-activation-environment --systemd || systemctl --user import-environment; jq .')" \
   "kawa-veil dbus-update-activation-environment"
eq "$(guarded 'wl-copy x && notify-send y; grim | wl-copy; resvg a b')" "" "&& and | are no fallback"

# ── the closure ──────────────────────────────────────────────────────────────────────────
pkgs() {   # pkgs GPU STEAM → every package setup installs for that machine
  (STEAM=$2 SPOTIFY=yes STATE_DIR=$TMP/nostate; . "$REPO/lib/manifest.sh"; manifest_all "$1") >"$TMP/pkgs.$1.$2"
}
pkgs amd yes; pkgs intel yes; pkgs amd no

calls=$(python3 "$S/deps.py" calls "$REPO")
case_ "every kind of place a program is named was read"
for src in script waybar desktop yazi dwl systemd config; do
  has "$(cut -f1 <<<"$calls" | sort -u | tr '\n' ' ')" "$src" "nothing read from: $src"
done
(($(wc -l <<<"$calls") > 500)) && _ok || _no "only $(wc -l <<<"$calls") calls found"
for p in kawa-drives xournalpp makoctl wpctl yazi fuzzel footclient btop kawa-pick node; do
  has "$(cut -f3 <<<"$calls" | sort -u | tr '\n' ' ')" " $p " "the call of $p was not found"
done

case_ "every program the desktop runs is installed (AMD, with Steam: the likely first machine)"
out=$(python3 "$S/deps.py" check "$REPO" "$S/fixtures" "$TMP/pkgs.amd.yes"); r=$?
while IFS= read -r ln; do [[ -n $ln ]] && _no "$ln"; done <<<"$out"
eq "$r" 0
case_ "… on an Intel machine as well (nothing relies on an AMD-only package)"
out=$(python3 "$S/deps.py" check "$REPO" "$S/fixtures" "$TMP/pkgs.intel.yes")
eq "$out" ""
case_ "… and with STEAM=no (nothing relies on the games' packages)"
out=$(python3 "$S/deps.py" check "$REPO" "$S/fixtures" "$TMP/pkgs.amd.no")
eq "$out" ""

case_ "the check is not blind: a program nobody installs is caught, and says where it is called"
mkdir -p "$TMP/repo"; cp -r "$REPO"/{bin,system,lib,configs,src,setup.sh,theme.sh} "$TMP/repo/"
printf '#!/usr/bin/env bash\nnot-a-real-program --now\n' >"$TMP/repo/bin/kawa-zzz"
out=$(python3 "$S/deps.py" check "$TMP/repo" "$S/fixtures" "$TMP/pkgs.amd.yes")
has "$out" "not-a-real-program: installed by nothing — bin/kawa-zzz:2"
mkdir -p "$TMP/fx"; cp "$S"/fixtures/*.txt "$TMP/fx/"
grep -v '^jq ' "$S/fixtures/programs.txt" >"$TMP/fx/programs.txt"
has "$(python3 "$S/deps.py" check "$REPO" "$TMP/fx" "$TMP/pkgs.amd.yes")" "jq: installed by nothing"
case_ "… and an optional program called without a guard is caught"
printf '#!/usr/bin/env bash\nresvg in.svg out.png\n' >"$TMP/repo/bin/kawa-zzz"
has "$(python3 "$S/deps.py" check "$TMP/repo" "$S/fixtures" "$TMP/pkgs.amd.yes")" "resvg: optional, but called unguarded"
printf '#!/usr/bin/env bash\ncommand -v resvg >/dev/null && resvg in.svg out.png\n' >"$TMP/repo/bin/kawa-zzz"
lacks "$(python3 "$S/deps.py" check "$TMP/repo" "$S/fixtures" "$TMP/pkgs.amd.yes")" "resvg"
case_ "… and a fixture line that is not true to the manifest is caught"
sed 's/^git  *manifest  *git$/git manifest git-core-nonsense/' "$S/fixtures/programs.txt" >"$TMP/fx/programs.txt"
has "$(python3 "$S/deps.py" check "$REPO" "$TMP/fx" "$TMP/pkgs.amd.yes")" "package git-core-nonsense is not in lib/manifest.sh"

# ── default programs ─────────────────────────────────────────────────────────────────────
case_ "every launcher entry mimeapps.list and xdg-terminals.list name exists (and no type twice)"
out=$(python3 "$S/deps.py" desktop "$REPO" "$S/fixtures" "$TMP/pkgs.amd.yes"); r=$?
while IFS= read -r ln; do [[ -n $ln ]] && _no "$ln"; done <<<"$out"
eq "$r" 0
case_ "the guide's promises hold in mimeapps.list"
ma=$REPO/configs/home/.config/mimeapps.list
for pair in text/plain=kawa-edit.desktop inode/directory=kawa-files.desktop image/png=imv.desktop \
            video/mp4=kawa-play.desktop audio/flac=kawa-play.desktop application/pdf=org.pwmt.zathura-pdf-mupdf.desktop \
            application/vnd.comicbook+zip=org.pwmt.zathura-cb.desktop text/csv=kawa-tables.desktop \
            text/tab-separated-values=kawa-tables.desktop application/vnd.ms-excel=libreoffice-calc.desktop \
            application/vnd.openxmlformats-officedocument.wordprocessingml.document=libreoffice-writer.desktop \
            application/vnd.openxmlformats-officedocument.presentationml.presentation=libreoffice-impress.desktop \
            application/zip=kawa-files.desktop x-scheme-handler/magnet=kawa-torrents.desktop \
            x-scheme-handler/https=brave-origin.desktop text/x-script.python=kawa-edit.desktop \
            application/x-xopp=com.github.xournalpp.xournalpp.desktop; do
  grep -qxF "$pair" "$ma" && _ok || _no "mimeapps.list lacks $pair"
done
case_ "GIO (gio open, every GTK program) reads each default exactly as mimeapps.list says"
GIO=$( [[ -x /opt/f44/bin/gio ]] && echo /opt/f44/bin/gio || command -v gio 2>/dev/null)
if [[ -n $GIO ]]; then
  config .config/mimeapps.list .local/share/applications
cp "$REPO/bin/kawa-term" "$REPO/bin/kawa-play" "$HOME/.local/bin/"   # (an entry whose program is missing is skipped)
  # the packages' own entries, as stand-ins without a MimeType of their own: the default must
  # hold by mimeapps.list alone
  mkdir -p "$TMP/sys/applications"
  while read -r d _; do
    printf '[Desktop Entry]\nType=Application\nName=%s\nExec=/bin/true %%f\n' "$d" >"$TMP/sys/applications/$d"
  done < <(grep -v '^#' "$S/fixtures/desktop-files.txt")
  gio_env=(env XDG_DATA_DIRS="$TMP/sys")
  [[ $GIO == /opt/f44/* ]] && gio_env+=(LD_LIBRARY_PATH=/opt/f44/lib)
  n=0
  while IFS='=' read -r mime app; do
    n=$((n + 1))
    got=$("${gio_env[@]}" "$GIO" mime "$mime" 2>&1 | head -n 1)
    has "$got" ": ${app%;}" "$mime: $got"
  done < <(sed -n '/^\[Default Applications\]/,/^\[/{/^[a-z]/p}' "$HOME/.config/mimeapps.list")
  ((n > 100)) && _ok || _no "only $n defaults read"
else printf '  – skipped: gio is not installed\n'; fi

case_ "every plugin a yazi keymap runs is there"
out=$(python3 "$S/deps.py" plugins "$REPO" "$S/fixtures"); eq "$out" ""

done_
