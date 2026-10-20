#!/usr/bin/env bash
# tests/content/test_shell.sh — the shell (~/.bashrc.d/fedokawaii.sh and ble.sh's settings,
# ~/.config/blesh/init.sh), read by a real bash in a terminal of its own (pty_run.py), as
# Fedora's ~/.bashrc reads it. The prompt after each kind of command: ✓ in green after a
# success, ✗ and the exit code in vermilion after a failure, the time a slow one took — and
# nothing after an empty Enter or in a new window; every pixel icon with the space its second
# half needs, and the header exactly one column short of the window, in foot and on the text
# consoles, in a git repository and in a folder named in Japanese. Then the aliases, what
# loads in which order (ble.sh first, attached last), zoxide learning folders, and ble.sh's
# colours: the terminal's 16 only. (ble.sh itself is not here: a stand-in records what the
# shell asks of it, and its settings are read with stand-ins for its three commands.)
. "$(dirname "$0")/lib.sh"
ICONS=$REPO/configs/home/.config/fedokawaii/icons.sh
# shellcheck source=/dev/null
. "$ICONS"
COLS=110

home() {   # home — a fresh home: Fedora's ~/.bashrc, the shell's files, stand-ins for its tools
  sandbox
  config .bashrc.d/fedokawaii.sh .config/readline/inputrc .config/blesh .config/fedokawaii/fzf.opts .config/bat
  export INPUTRC=$HOME/.config/readline/inputrc   # (/etc/profile.d/fedokawaii-home.sh, on the machine)
  cat >"$HOME/.bashrc" <<'EOF'
# .bashrc — Fedora's /etc/skel/.bashrc, as far as ~/.bashrc.d goes
if [ -d ~/.bashrc.d ]; then
    for rc in ~/.bashrc.d/*; do
        if [ -f "$rc" ]; then
            . "$rc"
        fi
    done
fi
unset rc
EOF
  # zoxide: its shell code (a cd that goes where it is told), and every call kept
  stub zoxide 'case $1 in init) printf "%s\n" "__zoxide_z() { builtin cd \"\$@\"; }" "__zoxide_zi() { :; }" "__zoxide_z_complete() { :; }" "cd() { __zoxide_z \"\$@\"; }" ;; esac'
  stub eza; stub bat
}
# session TERM LINE… — a bash -i in a terminal COLS wide, started in the home; each LINE typed
# at its own prompt, then exit. Its output is in $TMP/out
session() {
  local term=$1 a=(); shift
  for l in "$@" exit; do a+=(--line "$l"); done
  (cd "$HOME" && TERM=$term python3 -I "$C/pty_run.py" --cols "$COLS" --rows 30 --timeout 30 --each '\x1b]133;A' \
    "${a[@]}" -- bash -i >"$TMP/out" 2>&1)
}
# headers — each prompt's header line (from its OSC 133;A mark to the line's end), one per line
headers() { python3 -I - "$TMP/out" <<'PY'
import re, sys
raw = open(sys.argv[1], "rb").read().decode("utf-8", "replace")
for seg in raw.split("\x1b]133;A\x1b\\")[1:]:
    print(seg.split("\n")[0].rstrip("\r"))
PY
}
# width TEXT — the columns TEXT takes in foot: escapes none, a kanji two, a pixel icon one
width() { python3 -I - "$1" <<'PY'
import re, sys, unicodedata
t = re.sub(r"\x1b\[[0-9;]*m|\x1b\][^\x1b]*\x1b\\\\|[\x01\x02]", "", sys.argv[1])
print(sum(2 if unicodedata.east_asian_width(c) in "WF" else 1 for c in t))
PY
}
plain() { sed 's/\x1b\[[0-9;]*m//g' <<<"$1"; }
nth() { sed -n "$1p" <<<"$H"; }

# ── the prompt in foot ───────────────────────────────────────────────────────
home
session foot true '(exit 3)' '' '__kawa_t0=$((__kawa_t0 - 4200000))' '__kawa_t0=$((__kawa_t0 - 125000000))' 'sleep 0'
H=$(headers)
case_ "foot: a new window's prompt carries no mark"
eq "$(wc -l <<<"$H")" 7 "seven prompts: $(plain "$H")"
lacks "$(nth 1)" "$ICON_CHECK"; lacks "$(nth 1)" "$ICON_CROSS"
case_ "foot: ✓ in the theme's green after a success, alone"
has "$(nth 2)" $'\e[92m'"$ICON_CHECK "$'\e[0m'; lacks "$(nth 2)" "$ICON_CROSS"; lacks "$(plain "$(nth 2)")" "s  "
case_ "foot: ✗ and the exit code in vermilion after a failure; foot told the status (OSC 133;D)"
has "$(nth 3)" $'\e[91m'"$ICON_CROSS  3"$'\e[0m'; lacks "$(nth 3)" "$ICON_CHECK"
has "$(cat "$TMP/out")" $'\e]133;D;3\e\\'
case_ "foot: Enter on an empty line ran nothing: no mark"
lacks "$(nth 4)" "$ICON_CHECK"; lacks "$(nth 4)" "$ICON_CROSS"
case_ "foot: a command of 3 s or more: the time it took after its mark, faint; 10 s or more: a notice too"
has "$(nth 5)" "$ICON_CHECK "$'\e[0m \e[90m4.2s\e[0m  '
has "$(nth 6)" $'\e[90m2m05s\e[0m'
has "$(cat "$TMP/out")" $'\e]777;notify;done in 2m05s;'
lacks "$(cat "$TMP/out")" "done in 4.2s"
case_ "foot: a quick command: its mark, no time"
has "$(nth 7)" "$ICON_CHECK"; [[ $(plain "$(nth 7)") =~ [0-9]\.[0-9]s ]] && _no "a time shown: $(plain "$(nth 7)")" || _ok
case_ "foot: every pixel icon is followed by two spaces — its own second half, then the gap"
for i in 1 2 3 4 5 6 7; do
  h=$(plain "$(nth "$i")")
  python3 -I - "$h" <<'PY' && _ok || _no "header $i: an icon without its two spaces: $h"
import sys
t = sys.argv[1]
sys.exit(any(0xFE000 <= ord(c) <= 0xFEFFF and t[i + 1:i + 3] != "  " for i, c in enumerate(t)))
PY
done
[[ $(plain "$(nth 1)") == "$ICON_TORII_SMALL   ~ "* ]] && _ok || _no "the torii (the words' height, not the seal's), its second half and two spaces (as after a heading's kanji), the path: $(plain "$(nth 1)")"
case_ "foot: each header ends one column short of the window's edge (nothing wraps), whatever it shows"
for i in 1 2 3 4 5 6 7; do eq "$(width "$(nth "$i")")" $((COLS - 1)) "header $i: $(plain "$(nth "$i")")"; done
case_ "foot: the line you type on starts with the desktop's chevron, in paper colour"
has "$(cat "$TMP/out")" $'\n\e[37m'"$ICON_CHEVRON_RIGHT"$'\e[0m '
lacks "$(cat "$TMP/out")" "❯"

case_ "foot, in a git repository and a folder named in Japanese: branch icon, counts, still one column short"
home; mkdir -p "$HOME/repo" "$HOME/日本語のフォルダ"
git -C "$HOME/repo" init -q -b main; echo a >"$HOME/repo/a"; git -C "$HOME/repo" add a; echo b >"$HOME/repo/b"
session foot 'cd ~/repo' 'cd ~/日本語のフォルダ'
H=$(headers)
has "$(plain "$(nth 2)")" "$ICON_BRANCH  main +1 ?1 "
for i in 2 3; do eq "$(width "$(nth "$i")")" $((COLS - 1)) "header $i: $(plain "$(nth "$i")")"; done

# ── the prompt on the text consoles ──────────────────────────────────────────
case_ "a text console (TERM=linux): plain marks — # · ok · x and the code · > — the same colours, one column short"
home
session linux true '(exit 2)'
H=$(headers)
lacks "$(cat "$TMP/out")" $'\xf3\xbe'
[[ $(plain "$(nth 1)") == "#  ~ "* ]] && _ok || _no "the plain torii: $(plain "$(nth 1)")"
has "$(nth 2)" $'\e[92mok\e[0m'; has "$(nth 3)" $'\e[91mx 2\e[0m'
has "$(cat "$TMP/out")" $'\n\e[37m>\e[0m '
for i in 1 2 3; do eq "$(width "$(nth "$i")")" $((COLS - 1)) "header $i: $(plain "$(nth "$i")")"; done

# ── one prompt, one timer ────────────────────────────────────────────────────
case_ "the prompt is the shell's one PROMPT_COMMAND (Fedora's OSC 3008 hook, set before, is gone); PS0 is its timer"
home
sed -i '1i PROMPT_COMMAND=("" __systemd_osc_context_precmdline); PS0='"'"'$(__systemd_osc_context_ps0)'"'"'' "$HOME/.bashrc"
out=$(bash -ic 'declare -p PROMPT_COMMAND; printf "%s\n" "$PS0"' 2>/dev/null)
has "$out" 'declare -a PROMPT_COMMAND=([0]="__kawa_prompt")'
has "$out" '${__kawa_one:$((__kawa_t0 = ${EPOCHREALTIME/[.,]/}, 0)):0}\e]133;C\e\\'
lacks "$out" systemd

# ── the aliases ──────────────────────────────────────────────────────────────
case_ "ls, ll and lt are eza (folders first; ll: everything, hidden files, git state; lt: a tree), cat is bat as cat prints"
home
out=$(bash -ic 'alias ls ll lt cat' 2>/dev/null)
has "$out" "alias ls='eza --group-directories-first'"
has "$out" "alias ll='eza -la --group-directories-first --git --time-style=long-iso'"
has "$out" "alias lt='eza -T -L 2 --group-directories-first'"
has "$out" "alias cat='bat -pp'"
bash -ic 'ls -x; cat notes.txt' >/dev/null 2>&1
called '^eza --group-directories-first -x$'; called '^bat -pp notes.txt$'
case_ "… and no others for them: no la (ll shows hidden files), no grep (Fedora's colorgrep.sh has it), no ls fallback"
out=$(bash -ic 'alias' 2>/dev/null)
lacks "$out" "alias la="; lacks "$out" "alias grep="
lacks "$(cat "$REPO/configs/home/.bashrc.d/fedokawaii.sh")" "command -v eza"
case_ "EDITOR and VISUAL are the system's (/etc/profile.d/editor.sh), not set again here"
lacks "$(cat "$REPO/configs/home/.bashrc.d/fedokawaii.sh")" "EDITOR="

# ── what loads when ──────────────────────────────────────────────────────────
case_ "ble.sh: loaded first (--attach=none), attached last — after the prompt, PS0, the aliases and zoxide are in place"
home; mkdir -p "$HOME/.local/share/blesh"
cat >"$HOME/.local/share/blesh/ble.sh" <<EOF
printf 'load %s\n' "\$*" >>"$TMP/ble.log"; [[ \$(type -t __kawa_prompt) ]] && echo "loaded late" >>"$TMP/ble.log"
BLE_VERSION=0.4.0-fake
ble-attach() { { echo attach; declare -p PROMPT_COMMAND; echo "PS0 \${PS0:+set}"; alias ls; type -t __zoxide_z cd; } >>"$TMP/ble.log"; }
EOF
bash -ic : >/dev/null 2>&1
log=$(cat "$TMP/ble.log")
eq "$(head -n1 <<<"$log")" "load --attach=none"
lacks "$log" "loaded late"
eq "$(grep -c '^attach$' <<<"$log")" 1 "attached once"
has "$log" 'declare -a PROMPT_COMMAND=([0]="__kawa_prompt")'; has "$log" "PS0 set"
has "$log" "alias ls='eza --group-directories-first'"; has "$log" $'function\nfunction'
case_ "… its settings in ble.sh's own place for them (~/.config/blesh/init.sh: no --rcfile); fzf's code not read twice"
f=$(cat "$REPO/configs/home/.bashrc.d/fedokawaii.sh")
lacks "$f" "--rcfile"; lacks "$f" "--norc"; lacks "$f" "fzf --bash"
[[ -f $REPO/configs/home/.config/blesh/init.sh ]] && _ok || _no "no configs/home/.config/blesh/init.sh"
[[ $(grep -v '^\s*#' "$REPO/configs/home/.bashrc.d/fedokawaii.sh" | grep -v '^\s*$' | tail -n1) == '[[ -n ${BLE_VERSION-} ]] && ble-attach' ]] \
  && _ok || _no "ble-attach is not the file's last line"
case_ "with no ble.sh at all, a new shell says nothing (plain bash)"
home
out=$(TERM=foot python3 -I "$C/pty_run.py" --cols 80 --timeout 20 --each '\x1b]133;A' --line exit -- bash -i 2>&1)
lacks "$out" "No such file"; lacks "$out" "not found"; lacks "$out" "ble.sh"

# ── zoxide ───────────────────────────────────────────────────────────────────
case_ "zoxide learns a folder when you arrive in it — one call then, none on any other prompt"
home; session foot; reset_calls             # (the first shell wrote zoxide's code to the cache)
session foot 'cd /' true '' 'cd ~'
eq "$(grep -c '^zoxide add' "$CALLS")" 2 "$(grep '^zoxide' "$CALLS" | tr '\n' '|')"
called '^zoxide add -- /$'; called "^zoxide add -- $HOME\$"
eq "$(grep -c '^zoxide init' "$CALLS")" 0 "its shell code was read from the cache, not asked for again"

# ── ble.sh's settings ────────────────────────────────────────────────────────
# the faces of the pinned ble.sh whose own colours are fixed ones (xterm's 256): each must
# be set here, from the terminal's 16. (vbell*: no bell — edit_bell is off; prompt_status_line:
# no status line is used)
FIXED="region region_target region_match region_insert disabled overwrite_mode syntax_command
syntax_quoted syntax_quotation syntax_escape syntax_expr syntax_error syntax_varname
syntax_delimiter syntax_param_expansion syntax_history_expansion syntax_function_name
syntax_comment syntax_glob syntax_brace syntax_tilde syntax_document syntax_document_begin
command_builtin_dot command_builtin command_function command_jobs command_directory
command_suffix command_suffix_new filename_directory filename_directory_sticky filename_orphan
filename_setuid filename_setgid filename_character varname_unset varname_empty varname_number
varname_expr varname_array varname_hash varname_readonly varname_transform varname_export
varname_new argument_error auto_complete cmdinfo_cd_cdpath menu_filter_input
menu_complete_selected"
blerc() {   # blerc TERM — init.sh read with stand-ins for ble.sh's commands: $TMP/faces, opts, imports
  rm -f "$TMP/faces" "$TMP/opts" "$TMP/imports"
  TERM=$1 bash -c 'ble-face() { printf "%s\n" "$@" >>"$T/faces"; }; bleopt() { printf "%s\n" "$@" >>"$T/opts"; }
    ble-import() { printf "%s\n" "$*" >>"$T/imports"; }; set -e; . "$1"' _ "$REPO/configs/home/.config/blesh/init.sh"
}
export T=$TMP
for term in foot linux; do
  case_ "init.sh ($term): every colour is one of the terminal's — 0–15, and foot's 16/17 only in foot"
  blerc "$term"; eq "$?" 0
  bad=$(grep -oE '(fg|bg)=[^,]*' "$TMP/faces" | grep -vE '^(fg|bg)=([0-9]|1[0-5])$' || true)
  if [[ $term == foot ]]; then bad=$(grep -vxE '(fg|bg)=1[67]' <<<"$bad" || true); fi
  eq "$bad" "" "colours outside the palette: $bad"
  case_ "init.sh ($term): every face whose ble.sh colour is a fixed one is set here"
  for f in $FIXED; do
    grep -qE "^(${f}|${f%%_*}_@)=" "$TMP/faces" && _ok || _no "$f keeps ble.sh's own colour"
  done
done
case_ "init.sh: no bold (Fusion Pixel has none), the suggestion faint, the chosen entry filled in vermilion in foot"
blerc foot
lacks "$(cat "$TMP/faces")" bold
grep -qx 'auto_complete=fg=8' "$TMP/faces" && _ok || _no "the suggestion is not faint"
grep -qx 'menu_complete_selected=fg=17,bg=16' "$TMP/faces" && _ok || _no "the chosen entry is not the desktop's active mark"
case_ "init.sh: ble.sh's own exit and time lines off (the prompt shows them), no bell; fzf and zoxide through ble.sh, after the first prompt"
for o in exec_errexit_mark= exec_elapsed_mark= edit_bell=; do grep -qx "$o" "$TMP/opts" && _ok || _no "bleopt $o missing"; done
eq "$(sort "$TMP/imports" | tr '\n' ' ')" "-d integration/fzf-completion -d integration/fzf-key-bindings -d integration/zoxide "

done_
