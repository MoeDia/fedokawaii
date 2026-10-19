#!/usr/bin/env bash
# tests/static/test_syntax.sh — every file of the desktop reads as what it is: the shell
# scripts (bash -n, shellcheck), the shell inside configs (waybar's clicks, dwl's keys…),
# every JSON / TOML / YAML / INI / desktop / XML / Lua file (and .visidatarc, which is Python),
# and the configs the programs themselves can check (mako, foot, fuzzel) — read by those
# programs when they are here.
# The configs are read as theme.sh installs them: rendered into the throw-away home.
. "$(dirname "$0")/../lib/harness.sh"
S=$(cd "$(dirname "$0")" && pwd)
skipped() { printf '  – skipped: %s\n' "$1"; }
# a program from the machine — first the Fedora 44 build in /opt/f44 where there is one (the
# test sandbox: its own system's foot is older than Fedora's and knows fewer keys)
real() {
  [[ -x /opt/f44/bin/$1 ]] && { printf '/opt/f44/bin/%s' "$1"; return 0; }
  PATH=$ORIG_PATH command -v "$1" 2>/dev/null
}
ORIG_PATH=$PATH
sandbox
config .                                         # every config, rendered (theme.sh's render())
cd "$REPO" || exit 1

# ── shell ────────────────────────────────────────────────────────────────────────────────
mapfile -t SH < <(python3 "$S/parsecheck.py" shell "$REPO")
mapfile -t SOURCED < <(python3 "$S/parsecheck.py" sourced "$REPO")
# (the Python programs — kawa-panel, kawa-greet — are compiled below instead)
PY=(); for f in bin/* system/*; do [[ -f $f && $(head -n1 "$f") =~ ^#!.*python3$ ]] && PY+=("$f"); done
case_ "the file list is whole: every script in bin/ and system/, the libraries, the session"
eq "$(printf '%s\n' "${SH[@]}" | grep -c '^bin/')" "$(( $(find bin -type f | wc -l) - $(printf '%s\n' "${PY[@]}" | grep -c '^bin/') ))" "a script in bin/ is not seen as shell"
case_ "the Python programs in bin/ and system/ compile (Python's own parser; nothing written)"
((${#PY[@]} >= 2)) && _ok || _no "only ${#PY[@]} found: ${PY[*]}"
for f in "${PY[@]}"; do
  out=$(python3 -I -c 'import sys; compile(open(sys.argv[1], encoding="utf-8").read(), sys.argv[1], "exec")' "$f" 2>&1) && _ok || _no "$f: $out"
done
has "${SH[*]}" lib/common.sh; has "${SH[*]}" system/start-dwl; has "${SH[*]}" configs/home/.config/dwl/autostart.sh
has "${SH[*]}" configs/home/.bashrc.d/fedokawaii.sh; has "${SH[*]}" setup.sh; has "${SH[*]}" system/kawa-torrra.profile.sh; has "${SH[*]}" system/fedokawaii-report

case_ "every shell file parses (bash -n)"
for f in "${SH[@]}" "${SOURCED[@]}"; do
  if err=$(bash -n "$f" 2>&1); then _ok; else _no "$f: ${err:0:300}"; fi
done

case_ "every shell file is clean for shellcheck -S warning -x"
if command -v shellcheck >/dev/null; then
  shellcheck -S warning -x -f gcc "${SH[@]}" >"$TMP/sc" 2>&1
  for f in "${SH[@]}"; do
    if grep -q "^$f:" "$TMP/sc"; then _no "$(grep "^$f:" "$TMP/sc" | head -n 3 | tr '\n' ' ')"; else _ok; fi
  done
else skipped "shellcheck is not installed (dnf install ShellCheck)"; fi

case_ "the shell inside the configs parses: waybar's exec and clicks, dwl's keys, mako, the portals, Exec="
n=0
while IFS= read -r -d '' where && IFS= read -r -d '' text; do
  n=$((n + 1))
  if err=$(bash -n -c "$text" 2>&1); then _ok; else _no "$where: ${err:0:200} — in: ${text:0:120}"; fi
done < <(python3 "$S/deps.py" snippets "$REPO")
((n > 60)) && _ok || _no "only $n pieces of shell found in the configs (the reader lost some)"

case_ "the shell inside the configs is clean for shellcheck (as sh, -S warning)"
if command -v shellcheck >/dev/null; then
  while IFS= read -r -d '' where && IFS= read -r -d '' text; do
    out=$(printf '%s\n' "$text" | shellcheck -s sh -S warning -f gcc - 2>&1) && _ok || _no "$where: ${out:0:200}"
  done < <(python3 "$S/deps.py" snippets "$REPO")
else skipped "shellcheck is not installed"; fi

# ── data files ───────────────────────────────────────────────────────────────────────────
case_ "every JSON, TOML, YAML, INI, desktop, XML and option file reads as its format"
data=$(python3 "$S/parsecheck.py" data "$REPO" "$HOME")
while IFS= read -r ln; do
  case $ln in ok\ *) _ok ;; skip\ *) skipped "${ln#skip }" ;; *) _no "$ln" ;; esac
done <<<"$data"
for k in jsonc toml desktop xml mimeapps systemd ini ini-top mpv mako python; do
  has "$data" "ok $k " "no $k file was read at all"
done

case_ "the bar lists only modules that exist and are configured"
eq "$(python3 "$S/parsecheck.py" waybar "$HOME/.config/waybar/config.jsonc")" ""

case_ "every Lua file compiles (yazi's plugins and frame, mpv's scripts, neovim's, the notes)"
mapfile -t LUA < <(find configs -name '*.lua' | sort)
((${#LUA[@]} >= 9)) && _ok || _no "only ${#LUA[@]} Lua files found"
lua=$(python3 "$S/parsecheck.py" lua "${LUA[@]}")
if [[ $lua == skip* ]]; then skipped "${lua#skip }"
else
  while IFS= read -r ln; do [[ $ln == ok\ * ]] && _ok || _no "$ln"; done <<<"$lua"
  eq "$(grep -c '^ok' <<<"$lua")" "${#LUA[@]}" "every Lua file read"
fi

# ── the programs' own readers ────────────────────────────────────────────────────────────
# (no display and no session bus: each reads its config, then stops where it would connect)
quiet() {   # quiet PROGRAM ARG… — with no display and no session bus (and /opt/f44's libraries)
  local e=(env -u WAYLAND_DISPLAY -u DISPLAY -u DBUS_SESSION_BUS_ADDRESS "XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR")
  [[ $1 == /opt/f44/* ]] && e+=(LD_LIBRARY_PATH=/opt/f44/lib)
  "${e[@]}" timeout 20 "$@"
}

case_ "mako reads its config with both themes (makoctl reload would take it)"
if m=$(real mako); then
  for t in dark light; do
    ln -sfn "themes/$t" "$HOME/.config/fedokawaii/current"
    out=$(quiet "$m" -c "$HOME/.config/mako/config" 2>&1)
    lacks "$out" "Failed to parse" "$t: $out"
    lacks "$out" "nvalid" "$t: $out"
  done
  ln -sfn themes/dark "$HOME/.config/fedokawaii/current"
  # (and the reader is a real one: a bad line is caught)
  cp "$HOME/.config/mako/config" "$TMP/mako.bad"; echo 'bogus-key=1' >>"$TMP/mako.bad"
  out=$(quiet "$m" -c "$TMP/mako.bad" 2>&1)
  has "$out" "Failed to parse" "mako did not notice a bad key: $out"
else skipped "mako is not installed"; fi

case_ "foot reads its config with both themes (foot --check-config)"
if f=$(real foot); then
  for t in dark light; do
    ln -sfn "themes/$t" "$HOME/.config/fedokawaii/current"
    out=$(quiet "$f" --check-config -c "$HOME/.config/foot/foot.ini" 2>&1) \
      && _ok || _no "$t: $out"
    lacks "$out" "err:" "$t: $out"
  done
  ln -sfn themes/dark "$HOME/.config/fedokawaii/current"
else skipped "foot is not installed"; fi

case_ "fuzzel reads its config with both themes (fuzzel --check-config)"
if f=$(real fuzzel); then
  for t in dark light; do
    ln -sfn "themes/$t" "$HOME/.config/fedokawaii/current"
    out=$(quiet "$f" --check-config --config "$HOME/.config/fuzzel/fuzzel.ini" 2>&1) \
      && _ok || _no "$t: $out"
  done
  ln -sfn themes/dark "$HOME/.config/fedokawaii/current"
else skipped "fuzzel is not installed"; fi

case_ "the launcher entries pass desktop-file-validate"
if v=$(real desktop-file-validate); then
  for f in "$HOME"/.local/share/applications/*.desktop; do
    out=$("$v" "$f" 2>&1) && _ok || _no "${f##*/}: $out"
  done
else skipped "desktop-file-validate is not installed (the spec's rules above still ran)"; fi

done_
