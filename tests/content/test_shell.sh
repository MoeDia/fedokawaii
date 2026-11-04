#!/usr/bin/env bash
# tests/content/test_shell.sh — the shell (~/.bashrc.d/fedokawaii.sh and ble.sh's settings,
# ~/.config/blesh/init.sh), read by a real bash in a terminal of its own (pty_run.py), as
# Fedora's ~/.bashrc reads it. The prompt — one short line: the torii green after a
# command that went well, vermilion after one that failed (and its code, vermilion), the
# folder after the one above it, the branch and * for changes, the time a slow command took,
# the jobs waiting, then the › — in foot and on the text consoles, in a git repository and
# in a folder named in Japanese. Then the aliases, what loads in which order (ble.sh first,
# attached last), zoxide learning folders, and ble.sh's colours: the terminal's 16 only.
# (ble.sh itself is not here: a stand-in records what the shell asks of it, and its
# settings are read with stand-ins for its three commands.)
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
  (cd "$HOME" && TERM=$term python3 -I "$REPO/tests/lib/pty_run.py" --cols "$COLS" --rows 30 --timeout 30 --each '\x1b]133;A' \
    "${a[@]}" -- bash -i >"$TMP/out" 2>&1)
}
# headers — each prompt's header line (from its OSC 133;A mark to the line's end), one per line
headers() { python3 -I - "$TMP/out" <<'PY'
import re, sys
raw = open(sys.argv[1], "rb").read().decode("utf-8", "replace")
parts, out = raw.split("\x1b]133;A\x1b\\"), []
seen = lambda t: len(re.sub(r"\x1b\[[0-9;?]*[A-Za-z]|\x1b\][^\x1b]*\x1b\\\\|[\x01\x02]", "", t))
for prev, seg in zip(parts, parts[1:]):
    line = re.sub(r"\x1b\[[0-9;?]*[A-LN-Za-ln-z]", "", seg.split("\n")[0].rstrip("\r"))   # (cursor moves out, colours kept)
    # readline 8.3 draws the line again over itself as keys come (a carriage return, then the
    # prompt with its mark anew, on the same row): the same prompt, its fullest drawing kept
    if out and prev.endswith("\r"):
        out[-1] = max(out[-1], line, key=seen)
    else:
        out.append(line)
print("\n".join(out))
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
# (each prompt as it reads: the line up to its ›, the › and its space, then what was typed)
P() { local l=$1; l=${l%%"$ICON_CHEVRON_RIGHT"*}; plain "$l"; }
# (the blocks: S the line's edge, C the stamp edge between two blocks — the left one's paper over
# the right one's —, B N INK the words of a block on paper N (foot's 26–29, the vermilion 16))
S=$'\e[38;5;27;49m'"$ICON_CAP_STAMP_START"
C() { printf '\e[38;5;%s;48;5;%sm%s' "$1" "$2" "$ICON_CAP_STAMP"; }
B() { printf '\e[38;5;%s;48;5;%sm %s ' "$2" "$1" "$3"; }
END() { printf '\e[38;5;%s;49m%s\e[0m \e[38;5;20m%s \e[0m ' "$1" "$ICON_CAP_STAMP" "$ICON_CHEVRON_RIGHT"; }
# (the mood's head: the demon in the dark, red; it roars when the last command failed)
HEAD="$ICON_HEAD_ONI $ICON_HEAD_ONI_2" ROAR="$ICON_HEAD_ONI_ROAR $ICON_HEAD_ONI_ROAR_2"
MARK=$'\e[38;5;20m'"$HEAD"$'\e[0m '"$S"
case_ "foot: a new window's prompt — the mood's head, then a strip of stamps: the line's edge, the folder on its paper (27), the stamp edge between and at the end, the › in vermilion and its second half, a space"
eq "$(wc -l <<<"$H")" 7 "seven prompts: $(plain "$H")"
eq "$(plain "$(nth 1)")" "$HEAD $ICON_CAP_STAMP_START ~ $ICON_CAP_STAMP $ICON_CHEVRON_RIGHT  true"
has "$(nth 1)" "$MARK$(B 27 30 '~')$(END 27)"
case_ "foot: after a success the same; no ✓, no code"
eq "$(P "$(nth 2)")" "$HEAD $ICON_CAP_STAMP_START ~ $ICON_CAP_STAMP "; lacks "$(cat "$TMP/out")" "$ICON_CHECK"
case_ "foot: after a failure the code, a block of its own on the lacquer (24) in its cream (25: 7.9 : 1 and more); foot told the status (OSC 133;D)"
eq "$(P "$(nth 3)")" "$ROAR $ICON_CAP_STAMP_START ~ $ICON_CAP_STAMP 3 $ICON_CAP_STAMP "
has "$(nth 3)" "$(B 27 30 '~')$(C 27 24)$(B 24 25 3)$(END 24)"
has "$(cat "$TMP/out")" $'\e]133;D;3\e\\'
case_ "foot: Enter on an empty line ran nothing: the result before it stands"
eq "$(P "$(nth 4)")" "$ROAR $ICON_CAP_STAMP_START ~ $ICON_CAP_STAMP 3 $ICON_CAP_STAMP "
case_ "foot: a command of 3 s or more: the time it took, on its paper (29); 10 s or more: a notice too"
eq "$(P "$(nth 5)")" "$HEAD $ICON_CAP_STAMP_START ~ $ICON_CAP_STAMP 4.2s $ICON_CAP_STAMP "
has "$(nth 5)" "$(C 27 29)$(B 29 30 4.2s)$(END 29)"
has "$(nth 6)" "$(B 29 30 2m05s)"
has "$(cat "$TMP/out")" $'\e]777;notify;done in 2m05s;'
lacks "$(cat "$TMP/out")" "done in 4.2s"
case_ "foot: a quick command: no time"
eq "$(P "$(nth 7)")" "$HEAD $ICON_CAP_STAMP_START ~ $ICON_CAP_STAMP "
case_ "foot: one short line — no heading over it, nothing padded, no clock, no rule"
eq "$(grep -c $'\e]133;A' "$TMP/out")" 7 "one mark a prompt"
for i in 1 2 3 4 5 6 7; do h=$(P "$(nth "$i")"); (($(width "$h") < 24)) && _ok || _no "prompt $i: [$h]"; done
lacks "$(plain "$H")" "─"; lacks "$(plain "$H")" "╌"
lacks "$(grep -v '^ *#' "$REPO/configs/home/.bashrc.d/fedokawaii.sh")" "\$(date" "no date started at each prompt"
lacks "$(cat "$TMP/out")" "❯"

case_ "foot, in a git repository and a folder named in Japanese: the branch on its paper (28), its mark and * for changes; the folder above in the folder's block"
home; mkdir -p "$HOME/repo/sub" "$HOME/日本語のフォルダ"
git -C "$HOME/repo" init -q -b main; echo a >"$HOME/repo/a"; git -C "$HOME/repo" add a
session foot 'cd ~/repo' 'echo b >b' 'cd sub' 'cd ~/日本語のフォルダ'
H=$(headers)
eq "$(P "$(nth 2)")" "$HEAD $ICON_CAP_STAMP_START repo $ICON_CAP_STAMP $ICON_BRANCH  main* $ICON_CAP_STAMP " "a file staged: changes"
has "$(nth 2)" "$(B 27 30 repo)$(C 27 28)$(B 28 30 "$ICON_BRANCH  main*")$(END 28)"
eq "$(P "$(nth 4)")" "$HEAD $ICON_CAP_STAMP_START repo/sub $ICON_CAP_STAMP $ICON_BRANCH  main* $ICON_CAP_STAMP " "the folder and the one above it"
has "$(nth 4)" "$(B 27 30 repo/sub)"
eq "$(P "$(nth 5)")" "$HEAD $ICON_CAP_STAMP_START 日本語のフォルダ $ICON_CAP_STAMP "

# ── the prompt on the text consoles ──────────────────────────────────────────
case_ "a text console (TERM=linux): plain marks — # for the torii, > for the › — in the 16 colours"
home
session linux true '(exit 2)'
H=$(headers)
lacks "$(cat "$TMP/out")" $'\xf3\xbe'
eq "$(plain "$(nth 2)")" "# ~  > (exit 2)"; has "$(nth 2)" $'\e[32m#\e[0m'
eq "$(plain "$(nth 3)")" "# ~  2  > exit"; has "$(nth 3)" $'\e[31m#\e[0m'; has "$(nth 3)" $'\e[31m2\e[0m'
has "$(nth 3)" $'\e[90m>\e[0m '

# ── one prompt, one timer ────────────────────────────────────────────────────
case_ "the prompt is the shell's one PROMPT_COMMAND (Fedora's OSC 3008 hook, set before, is gone); PS0 is its timer"
home
sed -i '1i PROMPT_COMMAND=("" __systemd_osc_context_precmdline); PS0='"'"'$(__systemd_osc_context_ps0)'"'"'' "$HOME/.bashrc"
out=$(bash -ic 'declare -p PROMPT_COMMAND; printf "%s\n" "$PS0"' 2>/dev/null)
has "$out" 'declare -a PROMPT_COMMAND=([0]="__kawa_prompt")'
has "$out" '${__kawa_one:$((__kawa_t0 = ${EPOCHREALTIME/[.,]/}, __kawa_ran = 1, 0)):0}\e]133;C\e\\'
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
out=$(TERM=foot python3 -I "$REPO/tests/lib/pty_run.py" --cols 80 --timeout 20 --each '\x1b]133;A' --line exit -- bash -i 2>&1)
lacks "$out" "No such file"; lacks "$out" "not found"; lacks "$out" "ble.sh"

# ── zoxide ───────────────────────────────────────────────────────────────────
case_ "zoxide learns a folder when you arrive in it — one call then, none on any other prompt"
home; session foot; reset_calls             # (the first shell wrote zoxide's code to the cache)
session foot 'cd /' true '' 'cd ~'
eq "$(grep -c '^zoxide add' "$CALLS")" 2 "$(grep '^zoxide' "$CALLS" | tr '\n' '|')"
called '^zoxide add -- /$'; called "^zoxide add -- $HOME\$"
eq "$(grep -c '^zoxide init' "$CALLS")" 0 "its shell code was read from the cache, not asked for again"

# ── the running program in the title (Super+/) ───────────────────────────────
case_ "a program with a key sheet names its window while it runs (Super+/ shows its keys first): its first word past sudo, env, options and VAR=…, an alias looked through, its folder dropped, cut at ; & | and a leading \\; a program with a window of its own (zathura, mpv), any other command, or one with no sheet, leaves the folder there; ble.sh's PREEXEC hook, no process started, safe under set -u"
home; mkdir -p "$HOME/.config/fedokawaii/keys"
for s in nvim lazygit vd yazi zathura mpv; do : >"$HOME/.config/fedokawaii/keys/$s.txt"; done
out=$(bash -c 'set -u; . <(sed -n "/^__kawa_preexec() {/,/^}/p" "$1"); alias lg=lazygit v="nvim -p"
  for c in "nvim x" "sudo -E nvim /etc/fstab" "LANG=C env nvim" "/usr/bin/nvim" "lg" "v a b" "vd t.csv" "yazi" \
    "ls -la" "git status" "btop" "sudo -u root nvim" "" "  " "Nvim" "../nvim" \
    "\\nvim a" "nvim;ls" "lazygit&" "zathura a.pdf" "mpv film.mkv" "sudo" "nvim>out" "nvim<in"; do
    printf "%s|" "$c"; __kawa_preexec "$c" | od -An -c | tr -s " " | tr -d "\n"; echo; done' _ "$HOME/.bashrc.d/fedokawaii.sh" 2>&1)
eq "$out" "nvim x| 033 ] 2 ; n v i m 033 \\
sudo -E nvim /etc/fstab| 033 ] 2 ; n v i m 033 \\
LANG=C env nvim| 033 ] 2 ; n v i m 033 \\
/usr/bin/nvim| 033 ] 2 ; n v i m 033 \\
lg| 033 ] 2 ; l a z y g i t 033 \\
v a b| 033 ] 2 ; n v i m 033 \\
vd t.csv| 033 ] 2 ; v d 033 \\
yazi| 033 ] 2 ; y a z i 033 \\
ls -la|
git status|
btop|
sudo -u root nvim|
|
  |
Nvim|
../nvim| 033 ] 2 ; n v i m 033 \\
\\nvim a| 033 ] 2 ; n v i m 033 \\
nvim;ls| 033 ] 2 ; n v i m 033 \\
lazygit&| 033 ] 2 ; l a z y g i t 033 \\
zathura a.pdf|
mpv film.mkv|
sudo|
nvim>out| 033 ] 2 ; n v i m 033 \\
nvim<in| 033 ] 2 ; n v i m 033 \\"
case_ "nvim titles its window by the program in front: nvim; a terminal buffer's program (lazygit from Space g g); nvim again when it ends and its float closes with no BufEnter for the file, as snacks closes lazygit's"
if command -v nvim >/dev/null; then
  sed -n '/^vim.o.title = true/,$p' "$REPO/configs/home/.config/nvim/lua/config/options.lua" >"$TMP/title.lua"
  out=$(cd "$TMP" && timeout 30 nvim --clean --headless "+luafile $TMP/title.lua" "+lua
    local t = { vim.o.titlestring }
    vim.api.nvim_create_autocmd('TermClose', { callback = function() vim.api.nvim_win_close(0, true) end })
    vim.api.nvim_open_win(vim.api.nvim_create_buf(false, true), true, { relative = 'editor', row = 1, col = 1, width = 20, height = 5 })
    vim.fn.jobstart({ 'sleep', '0.3' }, { term = true })
    t[#t + 1] = vim.o.titlestring
    vim.defer_fn(function() t[#t + 1] = vim.o.titlestring; io.stdout:write(table.concat(t, ' ')); vim.cmd('qa!') end, 1500)" 2>&1)
  eq "$out" "nvim sleep nvim"
else printf "  – skipped: no nvim here\n"; fi
grep -qx '\[\[ -n \${BLE_VERSION-} \]\] && blehook PREEXEC+=__kawa_preexec' "$REPO/configs/home/.bashrc.d/fedokawaii.sh" \
  && _ok || _no "the hook is not registered with ble.sh"

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
