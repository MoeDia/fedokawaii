#!/usr/bin/env bash
# tests/content/test_tidy.sh — kawa-tidy on stub homes: what programs left at the top of the
# home moved where /etc/profile.d/fedokawaii-home.sh says (histories joined, yours first; a
# folder only where nothing is yet), the standard folders made for nothing taken away only
# while empty and switched off, an older version's leftovers out (its settings kept aside),
# caches trimmed to their limits each its own way — and nothing you made touched. The
# --check lists the report's CLEAN rows show; the weekly run only once a week; the profile
# itself as a POSIX shell reads it, and as setup's home_env reads it.
. "$(dirname "$0")/../lib/harness.sh"

home() {   # home — a fresh home with the toolkit's home file (KAWA_TOOLKIT)
  sandbox
  export KAWA_TOOLKIT=$TMP/toolkit; mkdir -p "$KAWA_TOOLKIT/system"
  cp "$REPO/system/fedokawaii-home.sh" "$KAWA_TOOLKIT/system/"
  stub systemd-tmpfiles; stub uv 'rm -rf "$HOME/.cache/uv/big"'; stub pgrep 'exit 1'
  T=$REPO/bin/kawa-tidy
}
mkfile() { mkdir -p "$(dirname "$1")"; truncate -s "${2}M" "$1"; }   # mkfile PATH MB (sparse: kawa-tidy counts the files' own sizes)
tidy() { OUT=$(bash "$T" "$@" 2>&1); RC=$?; }

home
case_ "moves: histories joined (the old lines first), folders moved whole, npm's cache gone — nothing else at the top"
printf 'old1\nold2\n' >"$HOME/.bash_history"; mkdir -p "$HOME/.local/state/bash"; printf 'new1\n' >"$HOME/.local/state/bash/history"
printf 'py\n' >"$HOME/.python_history"; printf '.less-history-file:\n' >"$HOME/.lesshst"
mkdir -p "$HOME/.cargo/bin" "$HOME/.rustup/toolchains/stable" "$HOME/.npm/_cacache" "$HOME/.npm/_logs" "$HOME/.visidata"
echo rustup >"$HOME/.cargo/bin/rustup"; echo t >"$HOME/.rustup/settings.toml"
tidy --move; eq "$RC" 0 "$OUT"
eq "$(cat "$HOME/.local/state/bash/history")" $'old1\nold2\nnew1'
eq "$(cat "$HOME/.local/state/python/history")" py
eq "$(cat "$HOME/.local/share/cargo/bin/rustup")" rustup; eq "$(cat "$HOME/.local/share/rustup/settings.toml")" t
[[ -d $HOME/.local/state/less && -f $HOME/.local/state/less/history && -d $HOME/.local/share/visidata ]] && _ok || _no "less's history, visidata's folder"
for f in .bash_history .python_history .lesshst .cargo .rustup .npm .visidata; do [[ ! -e $HOME/$f ]] && _ok || _no "~/$f still there"; done
has "$OUT" "~/.cargo → ~/.local/share/cargo"
tidy --move; eq "$OUT" "" "a second run: nothing to say"
case_ "a folder in both places stays (yours to look at) and is named; npm's folder with something of yours in it stays"
mkdir -p "$HOME/.cargo/registry" "$HOME/.npm/mine"; echo keep >"$HOME/.npm/mine/note"
tidy --move; [[ -d $HOME/.cargo/registry && -f $HOME/.npm/mine/note ]] && _ok || _no "removed"
tidy --check leftovers; eq "$RC" 1; has "$OUT" "~/.cargo: belongs in ~/.local/share/cargo"
tidy --check dotfiles; eq "$RC" 1; has "$OUT" "~/.cargo: belongs in"; has "$OUT" "~/.npm:"

home
case_ "dotfiles: Fedora's and the allowed ones pass; anything else named, a known one with what moves it"
touch "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.bash_logout" "$HOME/.steampid"; mkdir -p "$HOME/.config" "$HOME/.local" "$HOME/.cache" "$HOME/.ssh" "$HOME/.pki" "$HOME/.bashrc.d"
ln -s .local/share/Steam "$HOME/.steam"
tidy --check dotfiles; eq "$RC" 0 "$OUT"; has "$OUT" "nothing loose"
touch "$HOME/.wget-hsts" "$HOME/.node_repl_history"
tidy --check dotfiles; eq "$RC" 1
has "$OUT" "~/.wget-hsts: not the desktop's"; has "$OUT" "~/.node_repl_history: belongs in ~/.local/state/node/repl_history"

home
case_ "the standard folders made for nothing: an empty Desktop goes once switched off; Public with a file of yours stays; Templates not switched off stays and is named"
mkdir -p "$HOME/.config" "$HOME/Desktop" "$HOME/Public" "$HOME/Templates" "$HOME/Documents"; echo mine >"$HOME/Public/song.txt"
printf 'XDG_DESKTOP_DIR="$HOME/"\nXDG_PUBLICSHARE_DIR="$HOME"\nXDG_DOCUMENTS_DIR="$HOME/Documents"\n' >"$HOME/.config/user-dirs.dirs"
tidy --check dirs; eq "$RC" 1; has "$OUT" "~/Desktop: empty"; has "$OUT" "~/Public: yours"; has "$OUT" "~/Templates: xdg-user-dirs would make it again"
tidy; eq "$RC" 0 "$OUT"
[[ ! -e $HOME/Desktop && -f $HOME/Public/song.txt && -d $HOME/Templates && -d $HOME/Documents ]] && _ok || _no "$(ls "$HOME")"
called "^systemd-tmpfiles --user --clean$"

home
case_ "leftovers: Scriptorium's state, logs and helpers out; its settings kept aside, nothing else of the home touched"
mkdir -p "$HOME/.local/state/scriptorium" "$HOME/.local/bin" "$HOME/.config/scriptorium" "$HOME/.cache"
echo x >"$HOME/.local/bin/scrip-lock"; echo y >"$HOME/.local/bin/kawa-mine"; echo s >"$HOME/.config/scriptorium/conf"
mkdir -p "$HOME/.local/state/fedokawaii"; echo g >"$HOME/.local/state/fedokawaii/foot-glass.ini"   # (foot starts only with it)
touch "$HOME/.cache/scrip-lock-1.png" "$HOME/.cache/scriptorium-theme.log"
tidy --check leftovers; eq "$RC" 1; has "$OUT" "Scriptorium's helpers"
tidy; eq "$RC" 0 "$OUT"
for f in .local/state/scriptorium .local/bin/scrip-lock .cache/scrip-lock-1.png .cache/scriptorium-theme.log .config/scriptorium; do [[ ! -e $HOME/$f ]] && _ok || _no "$f still there"; done
eq "$(cat "$HOME/.local/state/fedokawaii/backup/scriptorium-config/conf")" s; eq "$(cat "$HOME/.local/bin/kawa-mine")" y
eq "$(cat "$HOME/.local/state/fedokawaii/foot-glass.ini")" g "the terminal's glass file stays (foot.ini includes it)"
tidy --check leftovers; eq "$RC" 0 "$OUT"

home
case_ "caches: over its limit, each its own way — cleared, oldest first, uv's prune, Brave's only while it is closed, a program's own only measured"
mkfile "$HOME/.cache/npm/a" 510; mkfile "$HOME/.cache/pip/b" 20
for i in 1 2 3 4 5 6; do mkfile "$HOME/.cache/thumbnails/large/$i.png" 100; touch -d "@$((1700000000 + i * 1000))" "$HOME/.cache/thumbnails/large/$i.png"; done
mkfile "$HOME/.cache/uv/big" 3100; mkfile "$HOME/.cache/BraveSoftware/Brave-Browser/Default/Cache/data" 1600
mkfile "$HOME/.cache/fedokawaii/wallpaper-screens/2560x1440/a.png" 1600
mkdir -p "$HOME/Documents"; mkfile "$HOME/Documents/big.iso" 50
tidy --check caches; eq "$RC" 1; has "$OUT" "over its limit"
stub pgrep 'exit 0'                                     # (Brave open)
tidy; eq "$RC" 0 "$OUT"
[[ ! -e $HOME/.cache/npm/a && -f $HOME/.cache/pip/b ]] && _ok || _no "npm over: cleared; pip under: kept"
eq "$(ls "$HOME/.cache/thumbnails/large" | tr '\n' ' ')" "3.png 4.png 5.png 6.png " "the oldest thumbnails out, until under 80 % of 500 MB"
[[ ! -e $HOME/.cache/uv/big ]] && _ok || _no "uv's prune"; called "^uv cache prune --quiet$"; not_called "^uv cache clean"
[[ -f $HOME/.cache/BraveSoftware/Brave-Browser/Default/Cache/data ]] && _ok || _no "Brave's cache cleared while Brave runs"
[[ -f $HOME/.cache/fedokawaii/wallpaper-screens/2560x1440/a.png && -f $HOME/Documents/big.iso ]] && _ok || _no "a program's own cache, or your file, touched"
stub pgrep 'exit 1'; tidy
[[ ! -e $HOME/.cache/BraveSoftware/Brave-Browser ]] && _ok || _no "Brave closed: its cache cleared"
tidy --check caches; eq "$RC" 1 "the drawn wallpapers still over: named, never trimmed here"; has "$OUT" "the wallpapers drawn ahead"

home
case_ "--weekly: the tidy once a week, then nothing until the week is up"
touch "$HOME/.lesshst"
tidy --weekly; [[ ! -e $HOME/.lesshst && -s $HOME/.local/state/fedokawaii/tidy.last ]] && _ok || _no "the first run tidies"
touch "$HOME/.lesshst"; tidy --weekly; [[ -e $HOME/.lesshst ]] && _ok || _no "a second run the same week does nothing"
echo $(( $(date +%s) - 8 * 86400 )) >"$HOME/.local/state/fedokawaii/tidy.last"
tidy --weekly; [[ ! -e $HOME/.lesshst ]] && _ok || _no "a week on: it tidies"
rc 2 bash "$T" --nonsense

case_ "the home file: a POSIX shell reads it (every variable under the home, the history folders made, cargo on PATH once)"
for sh in sh dash; do
  command -v "$sh" >/dev/null || continue
  mkdir -p "$TMP/h-$sh"
  o=$(env -i HOME="$TMP/h-$sh" PATH=/usr/bin:/bin "$sh" -c '. "$1"; . "$1"; echo "$CARGO_HOME|$HISTFILE|$PATH"' _ "$REPO/system/fedokawaii-home.sh")
  eq "$o" "$TMP/h-$sh/.local/share/cargo|$TMP/h-$sh/.local/state/bash/history|/usr/bin:/bin:$TMP/h-$sh/.local/share/cargo/bin"
  [[ -d $TMP/h-$sh/.local/state/python ]] && _ok || _no "the folders for the histories"
done
case_ "… and setup's home_env reads every variable of it (none written another way)"
n=$(grep -c '^export ' "$REPO/system/fedokawaii-home.sh")
m=$(bash -c '. "$1/lib/common.sh" 2>/dev/null; home_env /home/x' _ "$REPO" | grep -c '^[A-Z_]*=/home/x/')
eq "$m" "$n"
has "$(bash -c '. "$1/lib/common.sh" 2>/dev/null; home_env /home/x' _ "$REPO")" "RUSTUP_HOME=/home/x/.local/share/rustup"
done_
