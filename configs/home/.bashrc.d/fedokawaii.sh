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

# ── prompt ──────────────────────────────────────────────────────────────────
# Two lines: a header ruled like an entry in a ledger, then the line you type on.
#
#   ⛩   ~/repos/site   main +2 ~1 ╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌ ✗  2  4.2s  ☾  08:52:07 PM
#   ›
#
#   ⛩            a small vermilion torii (a pixel icon), where every entry starts
#   the path     the folders above in paper colour, the one you are in bright
#   git          branch, then only what is non-zero: +staged ~modified ?untracked
#                !conflicted ↑ahead ↓behind — one `git status` call, parsed in bash
#   the stitch   ╌ to the right edge, in the stitched rules' colour (edge2), so each
#                command reads as a new entry: the grammar of every heading on the desktop
#                (docs/design-system.md §7 — a glyph, two spaces, the name, one space, the
#                stitch), the torii standing where a menu's kanji stands
#   the right    after a command: ✓ in green when it succeeded, ✗ and its exit code in
#                vermilion when it failed, and the time it took when that was 3 s or more
#                — then sun or moon, and the time to the second. (Enter on an empty
#                line runs nothing: no mark)
#   ›            the pixel chevron every list of the desktop types after
# Also shown when they apply: user@host over SSH, the Python venv, background jobs.
#
# The header always fits its window on one line, ending one column short of the edge, at
# whatever width the window has now: it is laid out again whenever the width changes
# (ble.sh redraws the prompt then — a window opened beside it, a layout changed). When
# the stitch would be shorter than __kawa_rule_min, the header gives up, in this order and
# only as far as it must:
#   1  the folders above, to their first letters        ~/r/f/configs → ~/r/f/c/h/.config
#   2  the sky and the clock (the bar shows the time)
#   3  the folders above altogether                     … /.config
#   4  git's counts (the branch stays)
#   5  the time the command took
#   6  the branch
# Under 30 columns (a small tile) there is no stitch: the torii, the folder (without the
# "… /" before it when that is too much, cut in its middle with … only when even its name
# alone is too long) and the mark at the right edge.
# Nothing on the header has a background, so the cursor below never touches it.
# Colours are the terminal's 16, so the prompt follows the dark and light themes.
# Cost: pure bash outside git repositories (one git call inside); the timer is stamped
# by PS0 without a fork. A blank line separates each command's output from the next.
__kawa_rule_min=6
__kawa_in_git() {                              # pure bash: no fork outside repositories
  local d=$PWD
  while :; do [[ -e $d/.git ]] && return 0; [[ -z $d ]] && return 1; d=${d%/*}; done
}

# git: one porcelain-v2 call → branch and counts (sets __g_text and __g_plain, and the
# branch alone: __g_btext, __g_bplain)
__kawa_git() {
  local line head="" ab="" st=0 md=0 un=0 cf=0 x y ahead behind
  __g_text="" __g_plain="" __g_btext="" __g_bplain=""
  while IFS= read -r line; do
    case $line in
      '# branch.head '*) head=${line#\# branch.head } ;;
      '# branch.ab '*)   ab=${line#\# branch.ab } ;;
      '1 '*|'2 '*)       x=${line:2:1} y=${line:3:1}
                         [[ $x != . ]] && st=$((st + 1)); [[ $y != . ]] && md=$((md + 1)) ;;
      'u '*)             cf=$((cf + 1)) ;;
      '? '*)             un=$((un + 1)) ;;
    esac
  done < <(git --no-optional-locks status --porcelain=v2 --branch 2>/dev/null)
  [[ -n $head ]] || return 0
  [[ $head == '(detached)' ]] && head="detached"
  head=${head//[[:cntrl:]]/?}
  __g_text="$__c_git$__i_branch$head" __g_plain="$__i_branch$head"
  __g_btext=$__g_text __g_bplain=$__g_plain
  ((st)) && __g_add "$__c_add" "+$st"
  ((md)) && __g_add "$__c_mod" "~$md"
  ((un)) && __g_add "$__c_dim" "?$un"
  ((cf)) && __g_add "$__c_bad" "!$cf"
  if [[ -n $ab ]]; then
    read -r ahead behind <<<"$ab"; ahead=${ahead#+} behind=${behind#-}
    ((ahead)) && __g_add "$__c_git" "$__i_up$ahead"
    ((behind)) && __g_add "$__c_git" "$__i_down$behind"
  fi
  return 0
}
__g_add() { __g_text+=" $1$2$__c_off"; __g_plain+=" $2"; }

# Marks: the desktop's pixel icons in foot, the one terminal that has the icon font;
# plain characters anywhere else (the text consoles — Fedora 45 runs kmscon on tty2–6 —
# or a login from another machine).
# In foot every character is one column, but a pixel icon (and Fusion Pixel's arrows and
# ellipsis, drawn as wide as a kanji) is two columns of ink: foot draws it on into the
# column after it. So each such mark carries a space for its own second half — then the
# usual space comes after it, and nothing ever touches it. The widths below count it so.
if [[ $TERM != foot* ]]; then
  __i_torii='#  ' __i_branch='git: ' __i_sun='' __i_moon='' __i_ok='ok' __i_fail='x '
  __i_up='↑' __i_down='↓' __i_more='...' __i_rule='-' __i_mark='>'
else
  # shellcheck source=/dev/null
  . ~/.config/fedokawaii/icons.sh
  # (the torii at the words' height: the seal-sized one, as tall as a kanji, would come
  # down to within a few pixels of the ❯ on the line under it; after it, its second half
  # and two spaces, as after a heading's kanji)
  __i_torii="$ICON_TORII_SMALL   " __i_branch="$ICON_BRANCH  " __i_sun="$ICON_SUN  " __i_moon="$ICON_MOON  "
  __i_ok="$ICON_CHECK " __i_fail="$ICON_CROSS  " __i_up='↑ ' __i_down='↓ ' __i_more='… '
  __i_rule='╌' __i_mark=$ICON_CHEVRON_RIGHT
fi

# Colours are raw escapes wrapped in \001…\002 (readline: zero width). The finished
# line is kept in $__kawa_line and PS1 only *refers* to it, so a folder or branch
# named like $(command) is printed, never run. ✓ is the theme's green (matcha), the
# torii, ✗ and every failure its vermilion.
__c_torii=$'\001\e[91m\002'    __c_dir=$'\001\e[0;37m\002'   __c_here=$'\001\e[1;97m\002'
__c_git=$'\001\e[94m\002'      __c_add=$'\001\e[92m\002'     __c_mod=$'\001\e[93m\002'
__c_dim=$'\001\e[90m\002'      __c_bad=$'\001\e[91m\002'     __c_host=$'\001\e[33m\002'
__c_ok=$'\001\e[92m\002'       __c_sun=$'\001\e[93m\002'     __c_moon=$'\001\e[94m\002'
__c_time=$'\001\e[37m\002'     __c_off=$'\001\e[0m\002'
# the stitch: foot's colour 19 (edge2, the panels' stitched rules); faint on the consoles
__c_rule=$__c_dim; [[ $TERM == foot* ]] && __c_rule=$'\001\e[38;5;19m\002'
__kawa_one=x __kawa_fresh=1 __kawa_j='\j' __kawa_line='' __kawa_pwd=$PWD __kawa_z=0 __kawa_lineno=''
__g_text='' __g_plain='' __g_btext='' __g_bplain=''
# __kawa_t0: when the command being run started (PS0 stamps it; 0: no command since the
# last prompt — a new window, or Enter on an empty line)
__kawa_t0=0

# ── the header's layout: pure functions of the pieces and the width ──────────
# __kawa_w TEXT → __w: the columns TEXT takes in foot — Japanese, Chinese and Korean
# letters and emoji take two, so a folder or a branch named in them counts twice
__kawa_w() {
  local LC_ALL=C.UTF-8 wide=${1//[!ᄀ-ᅟ⺀-〾ぁ-㏿㐀-䶿一-鿿ꀀ-꓏가-힣豈-﫿︰-﹏！-｠￠-￦🌀-🙏🚀-🛿🤀-🧿𠀀-𿿽]/}
  __w=$(( ${#1} + ${#wide} ))
}

# __kawa_paths P → the place in three lengths, each the quiet folders above (__kp_d[i])
# and the bright one you are in (__kp_h), with their widths (__kp_dw[i], __kp_hw):
#   0  as it is                                       ~/repos/fedokawaii/configs/home/.config
#   1  the folders above to their first letter        ~/r/f/c/h/.config   (a dot folder: .c)
#   2  the folders above as … alone                   … /.config
# (never longer than the form before it: ~/repos stays ~/repos)
__kawa_paths() {
  local LC_ALL=C.UTF-8 p=$1 head part out=''
  if [[ $p == */* && $p != / ]]; then head=${p%/*}/ __kp_h=${p##*/}; else head='' __kp_h=$p; fi
  if [[ $head == / ]]; then out=/
  elif [[ -n $head ]]; then
    local -a parts; IFS=/ read -ra parts <<<"${head%/}"
    for part in "${parts[@]}"; do
      case $part in '~'|'') out+="$part/" ;; .*) out+="${part:0:2}/" ;; *) out+="${part:0:1}/" ;; esac
    done
  fi
  __kp_d=("$head" "$out" "")
  [[ -n $head ]] && __kp_d[2]="$__i_more/"
  local i; __kp_dw=()
  for i in 0 1 2; do __kawa_w "${__kp_d[i]}"; __kp_dw[i]=$__w; done
  for i in 1 2; do
    ((__kp_dw[i] < __kp_dw[i - 1])) || { __kp_d[i]=${__kp_d[i - 1]} __kp_dw[i]=${__kp_dw[i - 1]}; }
  done
  __kawa_w "$__kp_h"; __kp_hw=$__w
}

# __kawa_fit COLS LEAD P0 P1 P2 G1 G2 X ST DU CK → __fit: which form of the header fits
# COLS (every other argument a width in columns: the torii and host, the path's three
# forms, git with its counts and the branch alone, venv and jobs; on the right the mark,
# then the time taken and the clock, each with the space before it). 0–6: the richest form
# that leaves a rule of __kawa_rule_min or more (the list above the prompt); n: none does,
# or the window is under 30 columns — no rule
__kawa_fit() {
  local c=$1 lead=$2 x=$8 st=$9 s pw gw du ck r
  __fit=n
  ((c >= 30)) || return 0
  for s in 0 1 2 3 4 5 6; do
    case $s in
      0) pw=$3 gw=$6 du=${10} ck=${11} ;;
      1) pw=$4 ;;
      2) ck=0 ;;
      3) pw=$5 ;;
      4) gw=$7 ;;
      5) du=0 ;;
      6) gw=0 ;;
    esac
    r=$((st + du + ck)); ((r)) && r=$((r + 1))
    if ((lead + pw + gw + x + 1 + __kawa_rule_min + r <= c - 1)); then __fit=$s; return 0; fi
  done
}

# __kawa_cut TEXT MAX → __cut: TEXT in MAX columns or fewer, cut in the middle with …
__kawa_cut() {
  local LC_ALL=C.UTF-8 t=$1 n=${#1} k e
  __cut=$t; __kawa_w "$t"; ((__w <= $2)) && return 0
  __kawa_w "$__i_more"; e=$__w
  for ((k = n - 1; k > 0; k--)); do
    __cut="${t:0:(k + 1) / 2}$__i_more${t:n - k / 2}"; ((k / 2)) || __cut="${t:0:k}$__i_more"
    __kawa_w "$__cut"; ((__w <= $2)) && return 0
  done
  __cut=${__i_more:0:$2}
}

# __kawa_layout → __kawa_line, from the pieces __kawa_prompt gathered and $COLUMNS now
__kawa_layout() {
  local c=${COLUMNS:-80} i g gw du duw ck ckw right rw rule pad room
  __kawa_fit "$c" "$__kp_leadw" "$((__kp_dw[0] + __kp_hw))" "$((__kp_dw[1] + __kp_hw))" \
    "$((__kp_dw[2] + __kp_hw))" "$__kp_gw" "$__kp_bw" "$__kp_xw" "$__kp_stw" "$__kp_duw" "$__kp_ckw"
  if [[ $__fit == n ]]; then
    # the torii, the folder (after "… /" while there is room for it, cut in its middle only
    # when even it alone is too long) and the mark at the edge when that fits too
    local d=${__kp_d[2]} dw=${__kp_dw[2]} need=$((__kp_hw + (__kp_stw ? 2 + __kp_stw : 0)))
    room=$((c - 1 - __kp_leadw - dw))
    ((need > room && dw)) && d='' dw=0 room=$((c - 1 - __kp_leadw))
    if ((__kp_stw && need > room && room - 2 - __kp_stw >= 6)); then
      __kawa_cut "$__kp_h" $((room - 2 - __kp_stw))
    elif ((__kp_stw && need <= room)); then __cut=$__kp_h
    else __kawa_cut "$__kp_h" "$room"; fi
    __kawa_w "$__cut"
    __kawa_line="$__kp_lead$__c_dir$d$__c_here$__cut$__c_off"
    pad=$((room - __w - __kp_stw))
    if ((__kp_stw && pad >= 2)); then
      printf -v pad '%*s' "$pad" ''
      __kawa_line+="$pad$__kp_st"
    fi
    return 0
  fi
  i=2; ((__fit == 0)) && i=0; ((__fit == 1 || __fit == 2)) && i=1
  g=$__kp_g gw=$__kp_gw; ((__fit >= 4)) && g=$__kp_b gw=$__kp_bw; ((__fit == 6)) && g='' gw=0
  du=$__kp_du duw=$__kp_duw; ((__fit >= 5)) && du='' duw=0
  ck=$__kp_ck ckw=$__kp_ckw; ((__fit >= 2)) && ck='' ckw=0
  right="$__kp_st$du$ck" rw=$((__kp_stw + duw + ckw))
  rule=$((c - 1 - __kp_leadw - __kp_dw[i] - __kp_hw - gw - __kp_xw - 1 - (rw ? rw + 1 : 0)))
  printf -v rule '%*s' "$rule" ''; rule=${rule// /$__i_rule}
  __kawa_line="$__kp_lead$__c_dir${__kp_d[i]}$__c_here$__kp_h$__c_off$g$__kp_x $__c_rule$rule$__c_off"
  [[ -n $right ]] && __kawa_line+=" ${right# }"
  return 0
}

__kawa_prompt() {
  local rc=$? now dt t p v n hour
  local LC_ALL=C.UTF-8                          # count characters, not bytes; AM/PM in English
  # ble.sh runs PROMPT_COMMAND again when the window's width changes under a prompt that is
  # already up (its prompt is keyed on the width and on its line number, which is new for
  # each prompt): then the header is only laid out anew — its mark, time and clock stay
  # those of the command that ended
  if [[ -n ${_ble_edit_lineno-} && $_ble_edit_lineno == "$__kawa_lineno" ]]; then
    __kawa_layout
    return 0
  fi
  __kawa_lineno=${_ble_edit_lineno-}
  history -a                                    # save it now: new windows start with it
  printf '\e]133;D;%s\e\\' "$rc"                # previous command finished
  # where you are — a folder's name could carry escape sequences of its own (one from a
  # cloned repo or an archive could set the clipboard), so control characters become ?
  # (~ only for your home and what is inside it: not for a /home/you2 beside it)
  case $PWD in "$HOME"|"$HOME"/*) p=\~${PWD#"$HOME"} ;; *) p=$PWD ;; esac
  p=${p//[[:cntrl:]]/?}
  printf '\e]2;%s\e\\' "$p"                     # window title → shown in the bar
  __kawa_osc7
  # zoxide learns a folder when you arrive in it (by cd or a bare folder name): one call
  # then, none on any other prompt
  if [[ $PWD != "$__kawa_pwd" ]]; then
    __kawa_pwd=$PWD
    ((__kawa_z)) && zoxide add -- "$PWD" 2>/dev/null
  fi

  # the pieces, each with its width (the layout picks from them for the width there is)
  __kawa_paths "$p"
  __kp_lead="$__c_torii$__i_torii$__c_off" t=$__i_torii
  if [[ -n ${SSH_CONNECTION:-} ]]; then
    __kp_lead+="$__c_host$USER@${HOSTNAME%%.*}$__c_off " t+="$USER@${HOSTNAME%%.*} "
  fi
  __kawa_w "$t"; __kp_leadw=$__w
  __kp_g='' __kp_gw=0 __kp_b='' __kp_bw=0
  if __kawa_in_git; then
    __kawa_git
    if [[ -n $__g_text ]]; then
      __kp_g="  $__g_text$__c_off" __kp_b="  $__g_btext$__c_off"
      __kawa_w "  $__g_plain"; __kp_gw=$__w; __kawa_w "  $__g_bplain"; __kp_bw=$__w
    fi
  fi
  __kp_x='' t=''
  v=${VIRTUAL_ENV:-}; v=${v##*/}; v=${v//[[:cntrl:]]/?}
  [[ -n $v ]] && __kp_x+="  $__c_dim($v)$__c_off" t+="  ($v)"
  n=${__kawa_j@P}; ((n)) && __kp_x+="  ${__c_dim}jobs $n$__c_off" t+="  jobs $n"
  __kawa_w "$t"; __kp_xw=$__w

  # the right end: how the command went, how long it took, the sky and the clock — each
  # with the space before it (two after a word, one after an icon's second half)
  __kp_st='' __kp_stw=0 __kp_du='' __kp_duw=0 __kp_ck='' __kp_ckw=0
  if ((__kawa_t0)); then
    if ((rc)); then __kp_st="$__c_bad$__i_fail$rc$__c_off" t="$__i_fail$rc"
    else __kp_st="$__c_ok$__i_ok$__c_off" t=$__i_ok; fi
    __kawa_w "$t"; __kp_stw=$__w
    now=${EPOCHREALTIME/[.,]/}; dt=$(( (now - __kawa_t0) / 100000 ))    # tenths of a second
    t=""
    if ((dt >= 600)); then printf -v t '%dm%02ds' $((dt / 600)) $((dt / 10 % 60))
    elif ((dt >= 30)); then t="$((dt / 10)).$((dt % 10))s"; fi
    if [[ -n $t ]]; then
      n='  '; ((rc)) || n=' '
      __kp_du="$n$__c_dim$t$__c_off"; __kawa_w "$n$t"; __kp_duw=$__w
    fi
    # 10 s or more: a notice, which foot shows only while its window is not the one you
    # are in — start an upgrade, go elsewhere, and hear when it is done (and where)
    if ((dt >= 100)) && [[ $TERM == foot* ]]; then
      if ((rc)); then n="failed ($rc) after $t"; else n="done in $t"; fi
      printf '\e]777;notify;%s;%s\e\\' "$n" "${p//;/,}"
    fi
    __kawa_t0=0
  fi
  n=''; ((__kp_duw)) && n='  '; ((__kp_stw && !__kp_duw)) && { n=' '; ((rc)) && n='  '; }
  printf -v hour '%(%H)T' -1
  if ((10#$hour >= 6 && 10#$hour < 18)); then __kp_ck="$n$__c_sun$__i_sun$__c_off" t="$n$__i_sun"
  else __kp_ck="$n$__c_moon$__i_moon$__c_off" t="$n$__i_moon"; fi
  printf -v v '%(%I:%M:%S %p)T' -1
  __kp_ck+="$__c_time$v$__c_off" t+=$v
  __kawa_w "$t"; __kp_ckw=$__w

  __kawa_layout
  # a blank line before each entry — not after clear, and not in a tile of under 10 rows,
  # where it would push the line you type off the window (ble.sh: "(line 3) …")
  local gap='\n'; ((__kawa_fresh || ${LINES:-24} < 10)) && gap='' __kawa_fresh=0
  PS1="$gap"'\[\e]133;A\e\\\]${__kawa_line}\n\[\e[37m\]'"$__i_mark"'\[\e[0m\] '
}
clear() { command clear "$@"; __kawa_fresh=1; }    # no blank line at the top after clear
# The prompt is this function alone: Fedora's systemd hook (OSC 3008, marks no program
# here reads) would start two processes for every command
PROMPT_COMMAND=(__kawa_prompt)
# PS0 prints when a command starts: marks the output for foot (OSC 133;C) and stamps the
# start time into __kawa_t0 inside an arithmetic expansion, which prints nothing.
# (the stamp comes first: after "\e\\" a "$" would be read as escaped)
PS0='${__kawa_one:$((__kawa_t0 = ${EPOCHREALTIME/[.,]/}, 0)):0}\e]133;C\e\\'

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
# presets in ~/.config/btop/btop.conf, which p then cycles through. (btop picks a layout
# only as it starts, and draws nothing in less than 36×6; the bar's memory button opens it
# floating at 112×33, room for all four boxes.) Asked for with -p, a preset is yours.
#   preset  boxes                    needs (columns × rows, btop's own minimums)
#   0       cpu  mem  net  proc      80 × 24
#   1       cpu over proc            60 × 24
#   2       cpu                      60 × 8
#   3       proc                     44 × 16
#   4       mem over net             36 × 16
#   5       mem                      36 × 10
__kawa_btop_presets=('0 80 24' '1 60 24' '2 60 8' '3 44 16' '4 36 16' '5 36 10')
__kawa_btop_preset() {   # COLUMNS LINES → __preset: the first that fits, or '' (none does)
  local e p w h
  __preset=''
  for e in "${__kawa_btop_presets[@]}"; do
    p=${e%% *} w=${e#* } h=${w#* } w=${w%% *}
    if (($1 >= w && $2 >= h)); then __preset=$p; return 0; fi
  done
}
btop() {
  local a
  for a; do [[ $a == -p* || $a == --preset* ]] && { command btop "$@"; return; }; done
  __kawa_btop_preset "${COLUMNS:-80}" "${LINES:-24}"
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
# __kawa_heading VAR KANJI NAME [P] — VAR: fzf's options for that heading, as wide as the list:
# fzf's width less a column each side — and less the preview's P per cent at the right (fzf
# gives it the whole per cent of its width, rounded down)
__kawa_h=""
__kawa_heading() {
  printf -v "$1" -- '%s' "--with-shell='bash -c' --bind='start,resize:transform-header:. ~/.config/fedokawaii/screen.sh && screen_heading $2 $3 \$((FZF_COLUMNS - FZF_COLUMNS * ${4:-0} / 100 - 2)) && printf \"\\\\n \"'"
}
__kawa_heading __kawa_h 探 files 55
export FZF_CTRL_T_OPTS="$__kawa_h --preview='$__kawa_peek' --preview-window=right,55%,border-left"
export FZF_ALT_C_COMMAND='fd --type d --hidden --exclude .git --strip-cwd-prefix'
__kawa_heading __kawa_h 道 folders 55
export FZF_ALT_C_OPTS="$__kawa_h --preview='eza -T -L 2 --color=always --group-directories-first {}' --preview-window=right,55%,border-left"
__kawa_heading __kawa_h 歴 history
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
