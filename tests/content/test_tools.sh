#!/usr/bin/env bash
# tests/content/test_tools.sh — the shell and its everyday tools as the machine has them, not
# stand-ins: an interactive bash in a terminal of its own (pty_run.py) reading Fedora's
# ~/.bashrc, ~/.bashrc.d/fedokawaii.sh and the real ble.sh at lib/upstream.sh's commit, with
# the real eza, fd, zoxide and fzf; then lazygit, yazi and neovim (LazyVim, its plugins) on
# their first start. Nothing may say a warning or an error: not the shell's start (the first
# one builds ble.sh's caches and says only that; the second says nothing at all), not an alias
# or a key's widget, not a tool's first window, not :checkhealth lazy.
# The real programs are the caller's (found on its PATH before the sandbox narrows it):
#   FEDOKAWAII_BLESH     a ble.sh built at the pinned commit (else ~/.local/share/blesh)
#   FEDOKAWAII_NVIM_DATA neovim's plugins (~/.local/share/nvim's layout: lazy/, site/…)
# A part whose program is not at hand is skipped, and says so.
. "$(dirname "$0")/lib.sh"
BLESH_DIR=${FEDOKAWAII_BLESH:-$HOME/.local/share/blesh}
BLESH_PIN=$(sed -n 's/^BLESH_COMMIT=//p' "$REPO/lib/upstream.sh")
NVIM_DATA=${FEDOKAWAII_NVIM_DATA:-$HOME/.local/share/nvim}
declare -A REAL=()
for t in eza fd zoxide fzf lazygit nvim yazi git; do REAL[$t]=$(command -v "$t" 2>/dev/null); done
blesh_ok() { [[ -r $BLESH_DIR/ble.sh ]] && [[ $(bash "$BLESH_DIR/ble.sh" --version 2>/dev/null) == *"+${BLESH_PIN:0:7}" ]]; }

home() {   # home — Fedora's ~/.bashrc, the desktop's shell and tool settings, the real tools
  sandbox
  config .bashrc.d/fedokawaii.sh .config/readline/inputrc .config/blesh .config/fedokawaii/fzf.opts .config/bat \
         .config/lazygit .config/yazi
  export INPUTRC=$HOME/.config/readline/inputrc   # (/etc/profile.d/fedokawaii-home.sh, on the machine)
  printf '%s\n' '# .bashrc — Fedora'"'"'s /etc/skel/.bashrc, as far as ~/.bashrc.d goes' \
    'if [ -d ~/.bashrc.d ]; then' '    for rc in ~/.bashrc.d/*; do' '        if [ -f "$rc" ]; then' \
    '            . "$rc"' '        fi' '    done' 'fi' 'unset rc' >"$HOME/.bashrc"
  local t; for t in "${!REAL[@]}"; do [[ -n ${REAL[$t]} ]] && ln -s "${REAL[$t]}" "$STUBS/$t"; done
  stub bat 'cat "$@"'                      # (the previews' highlighter: not under test here)
  mkdir -p "$HOME/repos/demo"
  git -C "$HOME/repos/demo" init -q -b main; echo hi >"$HOME/repos/demo/a.txt"
}
# shell LINE… — a bash -i 100 columns wide in the home; each LINE typed once its prompt is
# up and the screen has been still for a second (ble.sh draws its prompt more than once as it
# starts); its screen's text, escapes and ble.sh's end-of-output mark taken out (in a real
# terminal ble.sh erases "[ble: EOF]" at once: it is only seen here, where nothing answers
# its cursor reports), in $TMP/text
shell() {
  local a=() l
  for l in "$@" exit; do a+=(--line "$l"); done
  (cd "$HOME" && TERM=foot LANG=C.UTF-8 python3 -I "$REPO/tests/lib/pty_run.py" --cols 100 --rows 30 --timeout 90 \
     --each '\x1b]133;A' --quiet 1 "${a[@]}" -- bash -i >"$TMP/raw" 2>&1)
  text <"$TMP/raw" >"$TMP/text"
}
text() { python3 -I -c '
import re, sys
t = sys.stdin.buffer.read().decode("utf-8", "replace")
t = re.sub(r"\x1b\[[0-9;?<>=]*[ -/]*[@-~]|\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)|\x1b[P_][^\x1b]*\x1b\\|\x1b[()][0-9A-Z]|\x1b[78=>]", "", t)
t = t.replace("[ble: EOF]", "").replace("\r\n", "\n")
print("\n".join(l.split("\r")[-1].rstrip() for l in t.split("\n") if l.strip()))'; }
# alarms FILE — its lines that warn or fail ("bash: …", "warning", "error", "not found"…)
alarms() { grep -aiE '^bash: |\b(warn(ing)?|errors?|fail(ed|ure)?|not found|no such file|deprecated|unknown|invalid|cannot|panic)\b' "$1"; }

# ── the shell's start ─────────────────────────────────────────────────────────
if blesh_ok; then
  home; mkdir -p "$HOME/.local/share"; cp -a "$BLESH_DIR" "$HOME/.local/share/blesh"
  rm -rf "$HOME/.local/share/blesh/cache.d"          # (as setup leaves it: built, never started)
  case_ "the shell's first start: ble.sh ${BLESH_PIN:0:7} builds its caches and says only that"
  shell 'echo started'
  eq "$(alarms "$TMP/text")" "" "a warning or error at the first start"
  has "$(cat "$TMP/text")" "started"
  case_ "the second start says nothing at all: no line of ble.sh's, none of bash's"
  shell 'echo started'
  eq "$(grep -aE '^(ble[./]|bash: )' "$TMP/text")" "" "lines at the second start"
  eq "$(alarms "$TMP/text")" ""

  case_ "aliases and functions resolve: ls, ll, lt (eza), cd and cdi (zoxide); each runs cleanly"
  if [[ -n ${REAL[eza]} && -n ${REAL[zoxide]} && -n ${REAL[fd]} ]]; then
    shell 'type -t ls ll lt cd cdi | paste -sd " "' 'ls; ll >/dev/null; lt >/dev/null; echo listed' \
          'fd a.txt repos'
    has "$(cat "$TMP/text")" "alias alias alias function function"
    has "$(cat "$TMP/text")" "listed"; has "$(cat "$TMP/text")" "repos/demo/a.txt" "fd finds the file"
    eq "$(alarms "$TMP/text")" ""
  else skip "eza, fd or zoxide not on PATH"; fi

  case_ "zoxide: cd learns a folder — cd demo from home goes back to ~/repos/demo"
  if [[ -n ${REAL[zoxide]} ]]; then
    shell 'cd repos/demo' 'cd ~' 'cd demo; echo "AT $PWD"'
    has "$(cat "$TMP/text")" "AT $HOME/repos/demo"
    eq "$(alarms "$TMP/text")" ""
  else skip "no zoxide on PATH"; fi

  case_ "fzf: Ctrl+R, Ctrl+T and Alt+C bound through ble.sh; ** after cd; Ctrl+T's lister and the popups' look work"
  if [[ -n ${REAL[fzf]} && -n ${REAL[fd]} ]]; then
    shell 'ble-bind -P | grep -E "fzf-history-widget|fzf-file-widget|__fzf_cd__"' 'complete -p cd' \
          'cd repos; FZF_CTRL_T_OPTS+=" --filter=a.txt" __fzf_select__; echo; cd ~'
    has "$(cat "$TMP/text")" "-x C-r fzf-history-widget"; has "$(cat "$TMP/text")" "-x C-t fzf-file-widget"
    has "$(cat "$TMP/text")" "M-c 'ble/util/eval-stdout \"__fzf_cd__\"'"
    has "$(cat "$TMP/text")" "complete -o filenames -F _fzf_dir_completion cd"
    has "$(cat "$TMP/text")" "demo/a.txt" "Ctrl+T's list (fd, through fzf.opts)"
    eq "$(alarms "$TMP/text")" ""
  else skip "no fzf or fd on PATH"; fi
else
  case_ "the shell with ble.sh"; skip "no ble.sh ${BLESH_PIN:0:7} at $BLESH_DIR (FEDOKAWAII_BLESH names one)"
fi

# ── the tools' first start ────────────────────────────────────────────────────
# first ARGS… — the program's first window, 100×30, in ~/repos/demo; q typed after 4 s
first() { (cd "$HOME/repos/demo" && TERM=foot python3 -I "$REPO/tests/lib/pty_run.py" --cols 100 --rows 30 --timeout 20 \
            --send 4 q -- "$@" >"$TMP/raw" 2>&1); RC=$?; text <"$TMP/raw" >"$TMP/text"; }
case_ "lazygit's first start: the repository at once (no welcome popup to close), nothing warns"
if [[ -n ${REAL[lazygit]} ]]; then
  home; first lazygit; eq "$RC" 0
  lacks "$(cat "$TMP/text")" "Thanks for using lazygit"
  has "$(cat "$TMP/text")" "Status"; eq "$(alarms "$TMP/text")" ""
else skip "no lazygit on PATH"; fi

case_ "yazi's first start: the folder listed, nothing warns (no plugin missing, no bad key)"
if [[ -n ${REAL[yazi]} ]]; then
  home; first yazi; eq "$RC" 0
  has "$(cat "$TMP/text")" "a.txt"; eq "$(alarms "$TMP/text")" ""
else skip "no yazi on PATH"; fi

case_ "neovim (LazyVim): :checkhealth lazy has no WARNING or ERROR; a first file opens with no message"
if [[ -n ${REAL[nvim]} && -d $NVIM_DATA/lazy ]]; then
  home; mkdir -p "$HOME/.config/nvim" "$HOME/.local/share"
  cp -r "$REPO/configs/home/.config/nvim/." "$HOME/.config/nvim/"   # (the desktop's: as setup)
  ln -s "$NVIM_DATA" "$HOME/.local/share/nvim"
  (cd "$HOME/repos/demo" && timeout 120 nvim --headless '+checkhealth lazy' "+w! $TMP/health" +qa >"$TMP/nvim.out" 2>&1)
  eq "$(grep -E 'WARNING|ERROR' "$TMP/health")" "" "checkhealth lazy"
  has "$(cat "$TMP/health")" "luarocks disabled"
  (cd "$HOME/repos/demo" && timeout 60 nvim --headless a.txt "+lua vim.defer_fn(function()
      local f = io.open('$TMP/msgs', 'w'); f:write(vim.api.nvim_exec2('messages', { output = true }).output)
      f:close(); vim.cmd('qa!') end, 3000)" >"$TMP/nvim.out" 2>&1)
  eq "$(cat "$TMP/msgs" "$TMP/nvim.out")" "" "messages at the first file"
  (cd "$HOME/repos/demo" && timeout 60 nvim --headless +Tutor "+lua io.open('$TMP/tutor', 'w'):write(vim.bo.filetype)" +qa >"$TMP/nvim.out" 2>&1)
  eq "$(cat "$TMP/tutor" 2>/dev/null)" tutor "nvim +Tutor: the Learn book's first exercise ($(cut -c1-80 "$TMP/nvim.out"))"
  case_ "neovim: a Markdown file's highlighter has no conceal_lines (a key costs half), a float that is no file keeps neovim's own; folds by indent"
  printf '# t\n\n```python\nx = 1\n```\n' >"$HOME/repos/demo/b.md"
  (cd "$HOME/repos/demo" && timeout 60 nvim --headless b.md "+lua vim.defer_fn(function()
      local h = vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()]
      local float = vim.api.nvim_create_buf(false, true)
      vim.bo[float].buftype = 'nofile'
      vim.api.nvim_buf_set_lines(float, 0, -1, false, { '\`\`\`python', 'x = 1', '\`\`\`' })
      vim.treesitter.start(float, 'markdown')
      local f = io.open('$TMP/md', 'w')
      f:write(tostring(h and h._conceal_line or false), ' ', tostring(vim.treesitter.highlighter.active[float]._conceal_line), ' ', vim.wo.foldmethod)
      f:close(); vim.cmd('qa!') end, 1500)" >"$TMP/nvim.out" 2>&1)
  eq "$(cat "$TMP/md" 2>/dev/null)" "false true indent" "file, float, folds ($(cut -c1-120 "$TMP/nvim.out"))"
  case_ "neovim's status line: the mode's tile, a % in a name kept a %, a deep path its last three parts with no ellipsis, the place; nothing on the first screen"
  mkdir -p "$HOME/repos/demo/a/b/c/d"; : >"$HOME/repos/demo/a/b/c/d/100%.txt"
  (cd "$HOME/repos/demo" && timeout 60 nvim --headless 'a/b/c/d/100%.txt' "+lua vim.defer_fn(function()
      local render = require('config.statusline').render
      local f = io.open('$TMP/line', 'w')
      f:write(vim.o.statusline, '\n', render(), '\n')
      vim.bo.filetype = 'snacks_dashboard'
      f:write(render(), '\n'); f:close(); vim.cmd('qa!') end, 1000)" >"$TMP/nvim.out" 2>&1)
  line=$(sed -n 2p "$TMP/line" 2>/dev/null)
  eq "$(sed -n 1p "$TMP/line" 2>/dev/null)" "%!v:lua.require'config.statusline'.render()" "the option ($(cut -c1-120 "$TMP/nvim.out"))"
  has "$line" "%#KawaStNormal# NORMAL "; has "$line" "c/d/"; lacks "$line" "b/c"; has "$line" "100%%.txt"; has "$line" "Top"; lacks "$line" "…"
  eq "$(sed -n 3p "$TMP/line" 2>/dev/null)" "%#Normal#" "the first screen: no line"
else skip "no nvim, or no plugins at $NVIM_DATA (FEDOKAWAII_NVIM_DATA)"; fi

done_
