# ~/.bashrc.d/fedokawaii.sh — bash tuned for foot. Sourced by Fedora's stock ~/.bashrc.
# Interactive shells only. Typing is ble.sh's (the Bash Line Editor, lib/upstream.sh): the
# line coloured as you type, a grey suggestion from your history, a completion menu. It is
# loaded first and attached last, as it asks; everything between is plain bash. The prompt
# is pure bash outside git repositories (git-prompt runs only inside one).
# shellcheck shell=bash
[[ $- == *i* ]] || return

# ── ble.sh: loaded now, attached at the end of this file ────────────────────
# Its settings and colours are ~/.config/blesh/init.sh, read while it loads.
# shellcheck source=/dev/null
[[ -r ~/.local/share/blesh/ble.sh ]] && source -- ~/.local/share/blesh/ble.sh --attach=none

# ── environment ─────────────────────────────────────────────────────────────
# (EDITOR and VISUAL are the system's: /etc/profile.d/editor.sh, setup.sh)
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) PATH="$HOME/.local/bin:$PATH" ;; esac
# (rustup's cargo, rustc…: $CARGO_HOME/bin, on PATH from /etc/profile.d/fedokawaii-home.sh)
export MANPAGER='nvim +Man!' LESS='-R --mouse -i'
# secrets live in the environment, never in configs — and only while the file is yours
# alone (chmod 600): one others could read is not used, and you are told
if [[ -r ~/.config/fedokawaii/secrets.sh ]]; then
  if [[ $(stat -c %a ~/.config/fedokawaii/secrets.sh) == 600 && -O ~/.config/fedokawaii/secrets.sh ]]; then
    # shellcheck source=/dev/null
    . ~/.config/fedokawaii/secrets.sh
  else
    printf 'secrets.sh not loaded: it must be yours and private — chmod 600 ~/.config/fedokawaii/secrets.sh\n' >&2
  fi
fi

# ── history: big, de-duplicated, saved as each command runs (new windows have it) ─
HISTSIZE=50000
HISTFILESIZE=100000
HISTCONTROL=ignoreboth:erasedups
HISTIGNORE='ls:ll:lt:cd:cd -:pwd:exit:clear:history'
HISTTIMEFORMAT='%F %T  '
shopt -s histappend

# ── shell behaviour ─────────────────────────────────────────────────────────
# a folder's name alone goes into it · ** matches any depth of folders · Tab on an empty
# line lists nothing. (bash itself has checkwinsize and cmdhist on; bash-completion turns
# extglob on)
shopt -s autocd globstar no_empty_cmd_completion

# ── foot shell integration ──────────────────────────────────────────────────
# OSC 7  : report the working directory → Ctrl+Shift+N opens a new foot here
# OSC 133: mark prompts and command output → Ctrl+Shift+Z/X jump between prompts,
#          Ctrl+Shift+G opens the last command's output in neovim
__kawa_osc7() {                      # a URI escapes bytes: walk the path byte by byte (LC_ALL=C)
  local LC_ALL=C i c out=$PWD
  if [[ $PWD == *[!-/:_.!\'\(\)~a-zA-Z0-9]* ]]; then          # only when something needs escaping
    out=
    for ((i = 0; i < ${#PWD}; i++)); do
      c=${PWD:i:1}
      case $c in [-/:_.!\'\(\)~a-zA-Z0-9]) out+=$c ;; *) printf -v c '%%%02X' "'$c"; out+=$c ;; esac
    done
  fi
  printf '\e]7;file://%s%s\e\\' "$HOSTNAME" "$out"
}

# the see-through ground as saved now (kawa-glass, Super+U → transparency): the terminal
# server read it as it started, so a window opened after a change shows it too — told once,
# as the shell starts (two small files read, no process)
__kawa_glass() {
  local l a="" g="" f
  [[ -r ~/.local/state/fedokawaii/foot-glass.ini ]] || return 0
  while IFS= read -r l; do [[ $l =~ ^alpha=([01](\.[0-9]+)?)$ ]] && a=${BASH_REMATCH[1]}; done \
    <~/.local/state/fedokawaii/foot-glass.ini
  while IFS= read -r l; do [[ $l =~ ^C_GROUND=([0-9a-fA-F]{6})$ ]] && g=${BASH_REMATCH[1]}; done \
    <~/.config/fedokawaii/current/colors.sh 2>/dev/null
  [[ -n $a && -n $g ]] || return 0
  f=${a#*.}000                               # (thousandths: 0.92 → 920)
  printf -v f '%02x' $(( (10#${f:0:3} * 255 + 500) / 1000 )); [[ $a == 1* ]] && f=ff
  # shellcheck disable=SC1003  # (the string terminator: ESC and a backslash)
  printf '\e]11;rgba:%s/%s/%s/%s\e\\' "${g:0:2}" "${g:2:2}" "${g:4:2}" "$f"
}
[[ $TERM == foot* ]] && __kawa_glass
unset -f __kawa_glass

# ── prompt ──────────────────────────────────────────────────────────────────
# One short line, a few words, and only colour carries the result:
#
#   ⛩ repos/fedokawaii  ⑂ main*  ›  ls          the last command went well: the torii green
#   ⛩ repos/fedokawaii  ⑂ main*  2  4.2s  ›     it failed (exit 2, after 4.2 s): vermilion
#
#   ⛩        the torii: green when the command before went well, vermilion when it failed
#   folder   the one you are in, in the strongest ink, after the one above it in the faint
#            ink (~ at home, / at the root) — the whole path is the window's title, in the bar
#   branch   in git: the branch mark faint, the branch muted; * when anything is not committed
#   the code only when it failed, vermilion
#   the time only when it took 3 s or more, muted
#   jobs     "jobs 1", muted, while a program waits in the background
#   ›        the desktop's pixel chevron, in the vermilion ink every list's search line has
# Two spaces between the parts, one after the torii (whose ink stops short of its second
# column: 14 px of air to the folder); the icons carry a space for their second half.
# A narrow window gives up the time, then the branch, then the folder's end. The line is
# the same once its command has run, so the history above reads as a column of them.
# On a text console (no foot) the same words, plain: '#' for the torii, '>' for the ›.
# Cost: pure bash outside git repositories (one git call inside); the timer is stamped by
# PS0 without a fork. A blank line separates each command's output from the next.
__kawa_in_git() {                              # pure bash: no fork outside repositories
  local d=$PWD
  while :; do [[ -e $d/.git ]] && return 0; [[ -z $d ]] && return 1; d=${d%/*}; done
}

# git: one porcelain-v2 call → the branch (__g_branch) and whether anything is not
# committed (__g_dirty). bash's own read: ble.sh's handles signals while it waits — a
# window retiled while git answered then redrew the prompt from the middle of making it
__kawa_git() {
  local line
  __g_branch='' __g_dirty=''
  while IFS= builtin read -r line; do
    case $line in
      '# branch.head '*) __g_branch=${line#\# branch.head } ;;
      '1 '*|'2 '*|'u '*|'? '*) __g_dirty='*' ;;
    esac
  done < <(git --no-optional-locks status --porcelain=v2 --branch 2>/dev/null)
  [[ $__g_branch == '(detached)' ]] && __g_branch=detached
  __g_branch=${__g_branch//[[:cntrl:]]/?}
  return 0
}

# the marks and inks: the desktop's pixel icons and the theme's colours in foot (a pixel
# icon is two columns of ink: each carries a space for its second half); plain text and
# the console's 16 colours elsewhere. Colours are raw escapes in \001…\002 (readline: zero
# width); the line is kept in $__kawa_line and PS1 only *refers* to it, so a folder or a
# branch named like $(command) is printed, never run.
if [[ $TERM == foot* ]]; then
  # shellcheck source=/dev/null
  . ~/.config/fedokawaii/icons.sh
  __i_torii="$ICON_TORII " __i_mark="$ICON_CHEVRON_RIGHT " __i_branch="$ICON_BRANCH  " __i_w=2 __i_bw=3
  __c_ok=$'\001\e[92m\002' __c_bad=$'\001\e[38;5;20m\002' __c_here=$'\001\e[38;5;23m\002'
  __c_dim=$'\001\e[38;5;21m\002' __c_dirty=$'\001\e[93m\002' __c_mark=$'\001\e[38;5;20m\002'
  __c_faint=$'\001\e[38;5;22m\002'
else
  __i_torii='#' __i_mark='>' __i_branch='' __i_w=1 __i_bw=0
  __c_ok=$'\001\e[32m\002' __c_bad=$'\001\e[31m\002' __c_here=$'\001\e[1;37m\002'
  __c_dim=$'\001\e[37m\002' __c_dirty=$'\001\e[33m\002' __c_mark=$'\001\e[90m\002'
  __c_faint=$'\001\e[90m\002'
fi
__c_off=$'\001\e[0m\002'
__kawa_one=x __kawa_fresh=1 __kawa_j='\j' __kawa_line='' __kawa_pwd=$PWD __kawa_z=0 __kawa_lineno=''
__kawa_ok=1 __kawa_rc=0 __kawa_took='' __kawa_jobs='' __kawa_place='' __kawa_above='' __g_branch='' __g_dirty=''
# __kawa_t0: when the command being run started (PS0 stamps it; 0: no command since the
# last prompt — a new window, or Enter on an empty line)
__kawa_t0=0

# __kawa_w TEXT → __w: the columns TEXT takes in foot — Japanese, Chinese and Korean
# letters and emoji take two, so a folder or a branch named in them counts twice
__kawa_w() {
  [[ $1 != *[!\ -~]* ]] && { __w=${#1}; return 0; }
  [[ ${LC_ALL-} == C.UTF-8 ]] || local LC_ALL=C.UTF-8
  local rest=${1//[\ -~]/}
  local wide=${rest//[!ᄀ-ᅟ⺀-〾ぁ-㏿㐀-䶿一-鿿ꀀ-꓏가-힣豈-﫿︰-﹏！-｠￠-￦🌀-🙏🚀-🛿🤀-🧿𠀀-𿿽]/}
  __w=$(( ${#1} + ${#wide} ))
}

# __kawa_layout → __kawa_line, from the pieces and $COLUMNS now: what does not fit goes
# (the time, then the branch, then the folder's end), a column kept free at the right
__kawa_layout() {
  if ((!__kawa_ran)) || [[ ${COLUMNS-} != +([0-9]) ]]; then __kawa_winsize || return 0; fi
  [[ ${LC_ALL-} == C.UTF-8 ]] || local LC_ALL=C.UTF-8
  local c=$((COLUMNS - 1)) place=$__kawa_place above=$__kawa_above git='' code='' took=$__kawa_took jobs=$__kawa_jobs pw aw gw cw tw jw
  [[ -n $__g_branch ]] && git=$__g_branch$__g_dirty
  ((__kawa_ok)) || code=$__kawa_rc
  __kawa_w "$place"; pw=$__w; __kawa_w "$above"; aw=$__w; __kawa_w "$git"; gw=$__w
  ((gw)) && gw=$((gw + __i_bw))
  cw=${#code} tw=${#took} jw=${#jobs}
  # (the torii and its space, the two spaces and the › and its space: the fixed part)
  local fixed=$((2 * __i_w + 4)) extra=$(( (gw ? gw + 2 : 0) + (cw ? cw + 2 : 0) + (tw ? tw + 2 : 0) + (jw ? jw + 2 : 0) ))
  if ((fixed + aw + pw + extra > c && tw)); then extra=$((extra - tw - 2)) took=''; fi
  if ((fixed + aw + pw + extra > c && jw)); then extra=$((extra - jw - 2)) jobs=''; fi
  if ((fixed + aw + pw + extra > c && gw)); then extra=$((extra - gw - 2)) git=''; fi
  ((fixed + aw + pw + extra > c)) && above='' aw=0
  while ((fixed + pw + extra > c && ${#place} > 1)); do place=${place:0:-1}; __kawa_w "$place"; pw=$__w; done
  local t=$__c_ok; ((__kawa_ok)) || t=$__c_bad
  __kawa_line="$t$__i_torii$__c_off $__c_faint$above$__c_here$place$__c_off"
  [[ -n $git ]] && __kawa_line+="  $__c_faint$__i_branch$__c_dim${git%\*}$__c_off${__g_dirty:+$__c_dirty*$__c_off}"
  [[ -n $code ]] && __kawa_line+="  $__c_bad$code$__c_off"
  [[ -n $took ]] && __kawa_line+="  $__c_dim$took$__c_off"
  [[ -n $jobs ]] && __kawa_line+="  $__c_dim$jobs$__c_off"
  __kawa_line+="  $__c_mark$__i_mark$__c_off "
  return 0
}

# the line once its command has run (ble.sh's final prompt): the same line — the history
# above reads as a column of them, each with its torii green or vermilion
__kawa_finalize() { __kawa_final="${__kawa_gap:+$'\n'}$__kawa_line"; }

__kawa_prompt() {
  local rc=$? now dt t p
  local LC_ALL=C.UTF-8                          # count characters, not bytes
  # ble.sh runs PROMPT_COMMAND again when the window's width changes under a prompt that is
  # already up (its line number is the same): then the line is only laid out anew
  if [[ -n ${_ble_edit_lineno-} && $_ble_edit_lineno == "$__kawa_lineno" ]]; then
    __kawa_layout; __kawa_finalize; __kawa_ps1
    return 0
  fi
  __kawa_lineno=${_ble_edit_lineno-}
  history -a                                    # save it now: new windows start with it
  printf '\e]133;D;%s\e\\' "$rc"                # previous command finished
  # where you are — a folder's name could carry escape sequences of its own (one from a
  # cloned repo or an archive could set the clipboard), so control characters become ?
  case $PWD in "$HOME"|"$HOME"/*) p=\~${PWD#"$HOME"} ;; *) p=$PWD ;; esac
  p=${p//[[:cntrl:]]/?}
  printf '\e]2;%s\e\\' "$p"                     # window title → shown in the bar
  __kawa_osc7
  if [[ $PWD != "$__kawa_pwd" ]]; then           # zoxide learns a folder when you arrive in it
    __kawa_pwd=$PWD
    ((__kawa_z)) && zoxide add -- "$PWD" 2>/dev/null
  fi
  # the folder, and the one above it (none at ~ or /, nor for a folder right in them: ~/x, /x)
  __kawa_above=''
  case $p in
    '~'|/) __kawa_place=$p ;;
    *) __kawa_place=${p##*/}; local up=${p%/*}; up=${up##*/}
       [[ -n $up && $up != '~' ]] && __kawa_above=$up/ ;;
  esac
  __g_branch='' __g_dirty=''
  __kawa_in_git && __kawa_git
  t=${__kawa_j@P}; __kawa_jobs=''; ((t)) && __kawa_jobs="jobs $t"

  # the result: the torii green, or vermilion and the code; the time when it was 3 s or more
  __kawa_took=''
  if ((__kawa_t0)); then
    __kawa_ok=$((rc == 0)) __kawa_rc=$rc
    now=${EPOCHREALTIME/[.,]/}; dt=$(( (now - __kawa_t0) / 100000 ))    # tenths of a second
    if ((dt >= 600)); then printf -v __kawa_took '%dm%02ds' $((dt / 600)) $((dt / 10 % 60))
    elif ((dt >= 30)); then __kawa_took="$((dt / 10)).$((dt % 10))s"; fi
    # 10 s or more: a notice, which foot shows only while its window is not the one you
    # are in — start an upgrade, go elsewhere, and hear when it is done (and where)
    if ((dt >= 100)) && [[ $TERM == foot* ]]; then
      if ((rc)); then t="failed ($rc) after $__kawa_took"; else t="done in $__kawa_took"; fi
      printf '\e]777;notify;%s;%s\e\\' "$t" "${p//;/,}"
    fi
    __kawa_t0=0
  fi

  __kawa_layout
  # a blank line before each entry — not after clear, and not in a tile of under 10 rows
  local gap='\n'; ((__kawa_fresh || ${LINES:-24} < 10)) && gap='' __kawa_fresh=0
  __kawa_gap=${gap:+1}
  __kawa_finalize; __kawa_ps1
}
# __kawa_ps1: the prompt — the blank line, foot's mark, the line (only *referred* to)
__kawa_ps1() {
  local gap=''; [[ -n $__kawa_gap ]] && gap='\n'
  PS1="$gap"'\[\e]133;A\e\\\]${__kawa_line}'
}
clear() { command clear "$@"; __kawa_fresh=1 __kawa_ran=0; }    # no blank line at the top after clear
# The prompt is this function alone: Fedora's systemd hook (OSC 3008, marks no program
# here reads) would start two processes for every command
PROMPT_COMMAND=(__kawa_prompt)
# PS0 prints when a command starts: marks the output for foot (OSC 133;C) and stamps the
# start time into __kawa_t0 (and __kawa_ran: the window holds more than its prompt now)
# inside an arithmetic expansion, which prints nothing.
# (the stamp comes first: after "\e\\" a "$" would be read as escaped)
PS0='${__kawa_one:$((__kawa_t0 = ${EPOCHREALTIME/[.,]/}, __kawa_ran = 1, 0)):0}\e]133;C\e\\'

# ── the prompt through a change of width ────────────────────────────────────
# foot reflows its lines when a window gets narrower: the header, which fills the old
# width, wraps onto two rows or more. ble.sh, redrawing the prompt for the new width, went
# back up only by the rows it had drawn — so the header's first part stayed above the new
# prompt, and every retile added another (stacked headers, the clock alone on a row). It is
# told where the prompt starts now: each row of the prompt above the line you type on
# (the blank line: __kawa_gap) takes ceil(width / columns) rows after
# the reflow, and the line you type on wraps as foot wraps it. Then ble.sh goes up exactly
# there, and the prompt is drawn over itself with nothing left behind. Only for this
# prompt, laid out as __kawa_layout last laid it: anything else (another PS1, a right-hand
# prompt, the cursor in a panel below) is ble.sh's own, as before.
__kawa_gap='' __kawa_final='' __kawa_ran=0
# __kawa_winsize: LINES and COLUMNS as the terminal has them this moment (stty asks it: ble.sh's
# own way, under bash 5.2, asks tput with its output in a pipe — and was answered terminfo's
# 80 columns)
__kawa_winsize() {
  local s
  s=$(stty size </dev/tty 2>/dev/null) && [[ $s == +([0-9])' '+([0-9]) ]] && LINES=${s% *} COLUMNS=${s#* }
}
__kawa_reflow() {
  # A burst of windows (several opened at once: dwl retiles every one each time) changes the
  # width again and again, faster than a redraw reaches the screen: a header drawn for one
  # width landed in a window already at the next, and was left above the new one. So the
  # width is first let settle: it is read again every 60 ms, and the header redrawn once it
  # has kept still for 300 ms (a single change: after one look, 60 ms). foot rewraps what is
  # on screen at every step, so the rows counted below hold for any number of them.
  local s0="$LINES:$COLUMNS" s1 quiet=0 n
  for ((n = 0; n < 40; n++)); do
    ble/util/msleep 60; __kawa_winsize
    s1="$LINES:$COLUMNS"
    if [[ $s1 == "$s0" ]]; then quiet=$((quiet + 60)); ((n == 0 || quiet >= 300)) && break
    else quiet=0 s0=$s1; fi
  done
  # a window nothing has run in yet (a new one, or one just cleared) holds only its prompt:
  # it is drawn again from the top, whatever widths it went through on the way — the burst
  # left nothing anywhere else on the screen to keep
  # (as ble.sh's own clear-screen does it: the line's drawing forgotten, the screen cleared)
  if ((!__kawa_ran)); then
    _ble_prompt_trim_opwd=
    ble/textarea#invalidate
    local -a DRAW_BUFF=()
    ble/canvas/panel/goto-top-dock.draw
    ble/canvas/bflush.draw
    # (and its scrollback, after the screen: a window the burst left only a row or two high
    # scrolled the top of its prompt into it — and foot, making the window taller again,
    # brought that row back down above the prompt drawn after the clear: the heading twice)
    # shellcheck disable=SC2154  # (ble.sh's: the terminal's clear-screen sequence)
    ble/util/buffer "$_ble_term_clear"$'\e[3J'
    _ble_canvas_x=0 _ble_canvas_y=0
    return 0
  fi
  [[ ${COLUMNS-} == +([0-9]) ]] || __kawa_winsize || return 1
  local c=$COLUMNS ow=${_ble_app_winsize[0]:-0} proy=${_ble_prompt_ps1_data[4]:-0}
  local y=${_ble_canvas_y:-0} x=${_ble_canvas_x:-0} w rows=0 off
  local -a above=(); [[ -n $__kawa_gap ]] && above=(0)
  ((c > 0 && ow > 0 && proy == ${#above[@]} && y >= proy && y < ${_ble_canvas_panel_height[0]:-0})) || return 1
  [[ -z ${_ble_prompt_rps1_shown-} ]] || return 1
  for w in "${above[@]}"; do rows=$((rows + (w > c ? (w + c - 1) / c : 1))); done
  off=$(((y - proy) * ow + x))
  _ble_canvas_y=$((rows + off / c)) _ble_canvas_x=$((off % c))
  # shellcheck disable=SC2034  # (ble.sh's draw buffer: its functions below fill and flush it)
  local -a DRAW_BUFF=()
  ble/canvas/panel#goto.draw 0 0 0
  ble/canvas/bflush.draw
}
[[ -n ${BLE_VERSION-} ]] && bleopt prompt_ps1_final='${__kawa_final}'
[[ -n ${BLE_VERSION-} ]] &&
  ble/function#advice around ble/application/onwinch/panel.process-redraw-here 'if __kawa_reflow; then ADVICE_EXIT=0; else ble/function#advice/do; fi'
# A width ble.sh comes to know between two of its redraws (bash reads it after any command
# the prompt runs, before the window's signal is handled) was drawn for as if nothing had
# moved, the header of the width before left above it: such a redraw goes the way of a
# change of width too. In a window nothing has run in yet — a new one, opened in a burst
# that retiles it again and again — the width is asked of the terminal before each redraw
# (one subshell; none once a command has run)
__kawa_render() {
  if [[ -z ${_ble_app_onwinch_Suppress-} && -n ${_ble_app_winsize[0]-} ]]; then
    ((__kawa_ran)) || __kawa_winsize
    [[ $COLUMNS != "${_ble_app_winsize[0]}" ]] && return 0
    # (a new window's height changing under its first prompt too — the burst retiles in both
    # directions: a heading drawn at the height before was left above the one drawn after)
    ((__kawa_ran)) || [[ $LINES == "${_ble_app_winsize[1]-}" ]] || return 0
  fi
  return 1
}
[[ -n ${BLE_VERSION-} ]] &&
  ble/function#advice around ble/application/render 'if __kawa_render; then ble/application/onwinch; else ble/function#advice/do; fi'

# ── aliases (few, each earns its place) ─────────────────────────────────────
# ls is eza: folders first, sizes readable; ll adds every detail, hidden files and each
# file's git state; lt draws the folder as a tree, two levels deep. Colours: the terminal's
# 16 (the theme's). No icons: eza's are Nerd Font drawings, smooth vector shapes that
# would sit between the pixel letters — colour already tells a folder from a file.
alias ls='eza --group-directories-first'
alias ll='eza -la --group-directories-first --git --time-style=long-iso'
alias lt='eza -T -L 2 --group-directories-first'
# cat is bat: the file in the theme's syntax colours, exactly as cat prints it otherwise —
# no line numbers in what you copy, no pager (bat file: the full view, numbers and git
# changes, paged). Piped or redirected, bat writes the bytes untouched, as cat does.
alias cat='bat -pp'
# the system's upkeep (the `fedokawaii` command; Super+U is its menu): short names for the
# three you type most
alias update='fedokawaii update' verify='fedokawaii verify' repair='fedokawaii repair'
# Prowlarr's web page (indexers, its login): started for it, asleep again 30 minutes later
# (kawa-prowlarr) · prowlarr stop: asleep now
alias prowlarr='kawa-prowlarr'
alias dwl-log='less +G ~/.cache/dwl.log'

# btop, typed in a terminal, starts in the richest of its layouts the window holds — the
# boxes btop.conf shows, or one of its presets (~/.config/btop/btop.conf), which p then
# cycles through. (btop picks a layout only as it starts, and draws nothing in less than
# 36×6; the bar's memory button opens it floating at 140×41, room for all five boxes.)
# Asked for with -p, a preset is yours.
#   layout  boxes                       needs (columns × rows, btop's own minimums)
#                                       with the card's box · on a machine without one
#   all     cpu  gpu  mem  net  proc    80 × 35             80 × 24
#   0       cpu  mem  net  proc         80 × 24             80 × 24
#   1       cpu over gpu over proc      66 × 35             —
#   2       cpu over proc               60 × 24             60 × 24
#   3       gpu over proc               66 × 27             —
#   4       cpu over gpu                66 × 19             —
#   5       proc                        44 × 16             44 × 16
#   6       mem over net                36 × 16             36 × 16
#   7       mem                         36 × 10             36 × 10
# (never the card's box alone: btop 1.4.5 stops on that layout. btop draws the card's box
# from 41 columns, but its words take 41 of them, whatever the width: the card's layouts
# wait for 66, where its load graph has 25 columns of its own)
# (the card: the box btop.conf shows for it — theme.sh writes it there for a discrete AMD
# card, as gpu0 or gpu1 in btop's own order, and leaves it out without one)
__kawa_btop_presets=('all 80 35 80 24' '0 80 24 80 24' '1 66 35 - -' '2 60 24 60 24' '3 66 27 - -'
  '4 66 19 - -' '5 44 16 44 16' '6 36 16 36 16' '7 36 10 36 10')
__kawa_btop_preset() {   # COLUMNS LINES [GPU 1|0] → __preset: the first that fits, or '' (none does)
  local e p w h gw gh g=${3-}
  if [[ -z $g ]]; then
    g=0
    while IFS= read -r e; do [[ $e == 'shown_boxes = '*gpu[0-5]* ]] && g=1; done <~/.config/btop/btop.conf 2>/dev/null
  fi
  __preset=''
  for e in "${__kawa_btop_presets[@]}"; do
    read -r p gw gh w h <<<"$e"
    ((g)) && w=$gw h=$gh
    [[ $w == - ]] && continue
    if (($1 >= w && $2 >= h)); then __preset=$p; return 0; fi
  done
}
btop() {
  local a
  for a; do [[ $a == -p* || $a == --preset* ]] && { command btop "$@"; return; }; done
  __kawa_btop_preset "${COLUMNS:-80}" "${LINES:-24}"
  [[ $__preset == all ]] && __preset=''
  command btop ${__preset:+-p "$__preset"} "$@"
}

# ── the helpers: fzf, zoxide, tldr ──────────────────────────────────────────
# tldr: its pages fetched on first use, then refreshed at most once a quarter (2160 hours) —
# the desktop's update rhythm — the next time you ask, never in the background; in the
# terminal's colours (the theme's)
export TLDR_CACHE_MAX_AGE=2160 TLDR_COLOR_NAME='red bold' TLDR_COLOR_DESCRIPTION=white \
  TLDR_COLOR_EXAMPLE=white TLDR_COLOR_COMMAND=cyan TLDR_COLOR_PARAMETER=yellow
# fzf — Ctrl+R: search the history · Ctrl+T: put a file or folder's path where you type ·
# Alt+C: go into a folder below this one · `nvim **<Tab>`: pick the argument fuzzily.
# fd lists the files (fast; skips .git and whatever .gitignore hides), bat and eza preview
# them, and every list wears the popups' look (~/.config/fedokawaii/fzf.opts, the theme's
# colours) and a text screen's heading (docs/design-system.md §7, screen.sh): its kanji, its
# name and the stitch across fzf's width, drawn again when the terminal changes size. fzf's own shell code is Fedora's: bash-completion reads its ** part
# (/etc/bash_completion.d/fzf), ble.sh its three keys (~/.config/blesh/init.sh).
export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git --strip-cwd-prefix'
# the look every list of the desktop shares (rules, colours, the chevron): one file
export FZF_DEFAULT_OPTS_FILE=$HOME/.config/fedokawaii/fzf.opts FZF_DEFAULT_OPTS="--height=50%"
__kawa_peek="if [[ -d {} ]]; then eza -T -L 2 --color=always --group-directories-first {}; \
else bat --color=always --style=numbers --line-range=:300 {}; fi"
export FZF_CTRL_T_COMMAND='fd --hidden --exclude .git --strip-cwd-prefix'
# __kawa_heading VAR ICON NAME [P] — VAR: fzf's options for that heading (ICON: its name in
# icons.sh, read as it is drawn), as wide as the list: fzf's width less a column each side —
# and less the preview's P per cent at the right (fzf gives it the whole per cent of its
# width, rounded down)
__kawa_h=""
__kawa_heading() {
  printf -v "$1" -- '%s' "--with-shell='bash -c' --bind='start,resize:transform-header:. ~/.config/fedokawaii/icons.sh && . ~/.config/fedokawaii/screen.sh && screen_heading \"\$ICON_$2\" $3 \$((FZF_COLUMNS - FZF_COLUMNS * ${4:-0} / 100 - 2)) && printf \"\\\\n \"'"
}
__kawa_heading __kawa_h FILE files 55
export FZF_CTRL_T_OPTS="$__kawa_h --preview='$__kawa_peek' --preview-window=right,55%,border-left"
export FZF_ALT_C_COMMAND='fd --type d --hidden --exclude .git --strip-cwd-prefix'
__kawa_heading __kawa_h FOLDER folders 55
export FZF_ALT_C_OPTS="$__kawa_h --preview='eza -T -L 2 --color=always --group-directories-first {}' --preview-window=right,55%,border-left"
__kawa_heading __kawa_h HOURGLASS history
export FZF_CTRL_R_OPTS=$__kawa_h
unset __kawa_peek __kawa_h
unset -f __kawa_heading
_fzf_compgen_path() { fd --hidden --exclude .git . "$1"; }        # what **<Tab> lists
_fzf_compgen_dir()  { fd --type d --hidden --exclude .git . "$1"; }

# zoxide — `cd` learns the folders you go to: `cd proj` goes to the best match for "proj"
# from anywhere (~/repos/project), `cd re pro` matches both words in order, `cdi` picks
# from the list in fzf. A real path still works exactly like cd. yazi's `Z` uses the same list.
# Its shell code is written once to ~/.cache/fedokawaii/zoxide.bash and read from there — a
# new shell starts no extra process for it; written again after any package change (the
# time of the rpm database: packages keep their build time on their files) or a change to
# this file.
__kawa_zoxide() {
  local f=$HOME/.cache/fedokawaii/zoxide.bash r stale=0
  [[ -s $f ]] || stale=1
  for r in /usr/lib/sysimage/rpm/rpmdb.sqlite "${BASH_SOURCE[0]}"; do [[ $f -ot $r ]] && stale=1; done
  if ((stale)); then
    mkdir -p "${f%/*}" && zoxide init bash --cmd cd --hook none >"$f.$$" && mv -f "$f.$$" "$f" || { rm -f "$f.$$"; return 1; }
  fi
  # shellcheck source=/dev/null
  . "$f"
}
__kawa_zoxide && __kawa_z=1

# ssh: few servers know foot's terminal type; every one knows xterm-256color
[[ $TERM == foot* ]] && ssh() { TERM=xterm-256color command ssh "$@"; }

# ── ble.sh: attached last, once everything above is in place ────────────────
# (your own ~/.bashrc.d/local.sh is read after this: ble.sh takes its aliases, functions
# and bindings as they come)
[[ -n ${BLE_VERSION-} ]] && ble-attach
