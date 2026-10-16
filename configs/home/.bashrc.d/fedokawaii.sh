# ~/.bashrc.d/fedokawaii.sh — bash tuned for foot. Sourced by Fedora's stock ~/.bashrc.
# Interactive shells only; the prompt is pure bash outside git repositories
# (git-prompt runs only inside one).
# shellcheck shell=bash
[[ $- == *i* ]] || return

# ── environment ─────────────────────────────────────────────────────────────
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) PATH="$HOME/.local/bin:$PATH" ;; esac
export EDITOR=nvim VISUAL=nvim MANPAGER='nvim +Man!' LESS='-R --mouse -i'
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
shopt -s histappend cmdhist

# ── shell behaviour ─────────────────────────────────────────────────────────
shopt -s autocd cdspell dirspell globstar extglob checkwinsize no_empty_cmd_completion

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
#   ⛩ ~/repos/site   main +2 ~1 ┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈ 4.2s  ✗ 2  ☾ 08:52:07 PM
#   ❯
#
#   ⛩            a small vermilion torii (a pixel icon), where every entry starts
#   the path     the folders above in paper colour, the one you are in bright and bold
#                (the last three folders; …/ for the rest)
#   git          branch, then only what is non-zero: +staged ~modified ?untracked
#                !conflicted ↑ahead ↓behind — one `git status` call, parsed in bash
#   the rule     a dotted line to the right edge, so each command reads as a new entry
#   the right    time taken (3 s or more) · the exit code stamped in a vermilion seal
#                when the command failed · sun or moon · the time, to the second
#   ❯            paper colour, vermilion after a failure
# Also shown when they apply: user@host over SSH, the Python venv, background jobs.
# Nothing on the header has a background, so the cursor below never touches it.
# Colours are the terminal's 16, so the prompt follows the dark and light themes.
# Cost: pure bash outside git repositories (one git call inside); the timer is stamped
# by PS0 without a fork. A blank line separates each command's output from the next.
__kawa_in_git() {                              # pure bash: no fork outside repositories
  local d=$PWD
  while :; do [[ -e $d/.git ]] && return 0; [[ -z $d ]] && return 1; d=${d%/*}; done
}

# git: one porcelain-v2 call → branch and counts (sets __g_text and __g_plain)
__kawa_git() {
  local line head="" ab="" st=0 md=0 un=0 cf=0 x y ahead behind
  __g_text="" __g_plain=""
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
  __g_text="$__c_git$__i_branch $head" __g_plain="$__i_branch $head"
  ((st)) && __g_add "$__c_add" "+$st"
  ((md)) && __g_add "$__c_mod" "~$md"
  ((un)) && __g_add "$__c_dim" "?$un"
  ((cf)) && __g_add "$__c_bad" "!$cf"
  if [[ -n $ab ]]; then
    read -r ahead behind <<<"$ab"; ahead=${ahead#+} behind=${behind#-}
    ((ahead)) && __g_add "$__c_git" "↑$ahead"
    ((behind)) && __g_add "$__c_git" "↓$behind"
  fi
  return 0
}
__g_add() { __g_text+=" $1$2$__c_off"; __g_plain+=" $2"; }

# Marks: the desktop's pixel icons in foot, the one terminal that has the icon font;
# plain characters anywhere else (the text consoles — Fedora 45 runs kmscon on tty2–6 —
# or a login from another machine). An icon is one column wide and draws into the space after it.
if [[ $TERM != foot* ]]; then
  __i_torii='#' __i_branch='git:' __i_sun='' __i_moon='' __i_rule='-' __i_fail='x' __i_mark='>' __i_more='...'
else
  # shellcheck source=/dev/null
  [[ -r ~/.config/fedokawaii/icons.sh ]] && . ~/.config/fedokawaii/icons.sh
  __i_torii=${ICON_TORII:->} __i_branch=${ICON_BRANCH:-git:} __i_sun=${ICON_SUN:-} __i_moon=${ICON_MOON:-}
  __i_rule='┈' __i_fail='✗' __i_mark='❯' __i_more='…'
fi

# Colours are raw escapes wrapped in \001…\002 (readline: zero width). The finished
# line is kept in $__kawa_line and PS1 only *refers* to it, so a folder or branch
# named like $(command) is printed, never run.
__c_torii=$'\001\e[91m\002'    __c_dir=$'\001\e[0;37m\002'   __c_here=$'\001\e[1;97m\002'
__c_git=$'\001\e[94m\002'      __c_add=$'\001\e[92m\002'     __c_mod=$'\001\e[93m\002'
__c_dim=$'\001\e[90m\002'      __c_bad=$'\001\e[91m\002'     __c_host=$'\001\e[33m\002'
__c_seal=$'\001\e[30;101m\002' __c_sun=$'\001\e[93m\002'     __c_moon=$'\001\e[94m\002'
__c_time=$'\001\e[37m\002'     __c_off=$'\001\e[0m\002'
__kawa_t0=0 __kawa_one=x __kawa_fresh=1 __kawa_j='\j' __kawa_line='' __kawa_pwd=$PWD __kawa_z=0
__g_text='' __g_plain=''

__kawa_prompt() {
  local rc=$? now dt t p v dir here left lplain right rplain n w wide rule hour
  local LC_ALL=C.UTF-8                          # count characters, not bytes; AM/PM in English
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

  # the folders above quiet, this one bright
  if [[ $p =~ ^(.*)/([^/]+/[^/]+/[^/]+)$ && ${BASH_REMATCH[1]} == */* ]]; then p="$__i_more/${BASH_REMATCH[2]}"; fi
  if [[ $p == */* && $p != / ]]; then dir=${p%/*}/ here=${p##*/}; else dir="" here=$p; fi
  left="$__c_torii$__i_torii$__c_off " lplain="$__i_torii "
  if [[ -n ${SSH_CONNECTION:-} ]]; then
    left+="$__c_host$USER@${HOSTNAME%%.*}$__c_off " lplain+="$USER@${HOSTNAME%%.*} "
  fi
  left+="$__c_dir$dir$__c_here$here$__c_off" lplain+="$dir$here"

  if __kawa_in_git; then
    __kawa_git
    [[ -n $__g_text ]] && left+="  $__g_text$__c_off" lplain+="  $__g_plain"
  fi
  v=${VIRTUAL_ENV:-}; v=${v##*/}; v=${v//[[:cntrl:]]/?}
  [[ -n $v ]] && left+="  $__c_dim($v)$__c_off" lplain+="  ($v)"
  n=${__kawa_j@P}; ((n)) && left+="  ${__c_dim}jobs $n$__c_off" lplain+="  jobs $n"

  # the right end: duration, the failure seal, the sky and the clock
  right="" rplain=""
  if ((__kawa_t0)); then
    now=${EPOCHREALTIME/[.,]/}; dt=$(( (now - __kawa_t0) / 100000 ))    # tenths of a second
    t=""
    if ((dt >= 600)); then printf -v t '%dm%02ds' $((dt / 600)) $((dt / 10 % 60))
    elif ((dt >= 30)); then t="$((dt / 10)).$((dt % 10))s"; fi
    [[ -n $t ]] && right+="$__c_dim$t$__c_off  " rplain+="$t  "
    # 10 s or more: a notice, which foot shows only while its window is not the one you
    # are in — start an upgrade, go elsewhere, and hear when it is done (and where)
    if ((dt >= 100)) && [[ $TERM == foot* ]]; then
      if ((rc)); then n="failed ($rc) after $t"; else n="done in $t"; fi
      printf '\e]777;notify;%s;%s\e\\' "$n" "${p//;/,}"
    fi
    __kawa_t0=0
  fi
  ((rc)) && right+="$__c_seal $__i_fail $rc $__c_off  " rplain+=" $__i_fail $rc   "
  printf -v hour '%(%H)T' -1
  if ((10#$hour >= 6 && 10#$hour < 18)); then
    [[ -n $__i_sun ]] && right+="$__c_sun$__i_sun$__c_off " rplain+="$__i_sun "
  else
    [[ -n $__i_moon ]] && right+="$__c_moon$__i_moon$__c_off " rplain+="$__i_moon "
  fi
  printf -v t '%(%I:%M:%S %p)T' -1
  right+="$__c_time$t$__c_off" rplain+="$t"

  # the rule between them, to the window's right edge (dropped when it gets too narrow).
  # Measured in columns, not characters: Japanese, Chinese and Korean letters and emoji
  # take two, so a folder or a branch named in them counts twice (else the clock wraps
  # onto a line of its own)
  wide=${lplain//[!ᄀ-ᅟ⺀-〾ぁ-㏿㐀-䶿一-鿿ꀀ-꓏가-힣豈-﫿︰-﹏！-｠￠-￦🌀-🙏🚀-🛿🤀-🧿𠀀-𿿽]/}
  w=$(( ${COLUMNS:-80} - ${#lplain} - ${#wide} - ${#rplain} - 3 ))   # one column spare: no wrap at the edge
  if ((w >= 4)); then
    printf -v rule '%*s' "$w" ''; rule=${rule// /$__i_rule}
    __kawa_line="$left $__c_dim$rule$__c_off $right"
  else
    __kawa_line=$left
  fi

  local gap='\n'; ((__kawa_fresh)) && gap='' __kawa_fresh=0
  local mark='\[\e[37m\]'; ((rc)) && mark='\[\e[91m\]'
  PS1="$gap"'\[\e]133;A\e\\\]${__kawa_line}\n'"$mark$__i_mark"'\[\e[0m\] '
}
clear() { command clear "$@"; __kawa_fresh=1; }    # no blank line at the top after clear
PROMPT_COMMAND=__kawa_prompt
# PS0 prints when a command starts: marks the output for foot (OSC 133;C) and stamps the
# start time into __kawa_t0 inside an arithmetic expansion, which prints nothing.
# (the stamp comes first: after "\e\\" a "$" would be read as escaped)
PS0='${__kawa_one:$((__kawa_t0 = ${EPOCHREALTIME/[.,]/}, 0)):0}\e]133;C\e\\'

# ── aliases (few, each earns its place) ─────────────────────────────────────
# ls is eza: folders first, sizes readable; ll adds every detail and each file's git state;
# lt draws the folder as a tree, two levels deep. Colours: the terminal's 16 (the theme's).
if command -v eza >/dev/null; then
  alias ls='eza --group-directories-first'
  alias ll='eza -la --group-directories-first --git --time-style=long-iso'
  alias lt='eza -T -L 2 --group-directories-first'
else
  alias ls='ls --color=auto --group-directories-first'
  alias ll='ls -lAh'
fi
alias grep='grep --color=auto'
# the system's upkeep (the `fedokawaii` command; Super+U is its menu): short names for the
# three you type most
alias update='fedokawaii update' verify='fedokawaii verify' repair='fedokawaii repair'
# Prowlarr's web page (indexers, its login): it runs on demand, so start it, then open it
# prowlarr: its web page (Prowlarr started for it) · prowlarr stop: done with it
prowlarr() {
  if [[ ${1:-} == stop ]]; then systemctl --user stop prowlarr.service; return; fi
  systemctl --user start prowlarr.service && xdg-open http://localhost:9696 >/dev/null 2>&1
}
alias snaps='sudo snapper -c root list'
alias dwl-log='less +G ~/.cache/dwl.log'

# ── the helpers: fzf, zoxide, tldr ──────────────────────────────────────────
# tldr: its pages fetched on first use, then refreshed at most once a quarter (2160 hours) —
# the desktop's update rhythm — the next time you ask, never in the background; in the
# terminal's colours (the theme's)
export TLDR_CACHE_MAX_AGE=2160 TLDR_COLOR_NAME='red bold' TLDR_COLOR_DESCRIPTION=white \
  TLDR_COLOR_EXAMPLE=white TLDR_COLOR_COMMAND=cyan TLDR_COLOR_PARAMETER=yellow
# Each program's shell code is written once to ~/.cache/fedokawaii/<name>.bash and read
# from there — a new shell starts no extra process; the file is written again after any
# package change (the time of the rpm database: packages keep their build time on their
# files, so the program's own time is not enough) or a change to this file.
__kawa_init() {   # __kawa_init NAME COMMAND… — read COMMAND's shell code, cached
  local f=$HOME/.cache/fedokawaii/$1.bash bin="" d r stale=0 path=()
  IFS=: read -ra path <<<"$PATH"                # (found without a subshell: no extra process)
  for d in "${path[@]}"; do [[ -x $d/$2 && ! -d $d/$2 ]] && { bin=$d/$2; break; }; done
  [[ -n $bin ]] || return 1
  [[ -s $f ]] || stale=1
  for r in "$bin" /usr/lib/sysimage/rpm/rpmdb.sqlite "${BASH_SOURCE[0]}"; do [[ $f -ot $r ]] && stale=1; done
  if ((stale)); then
    mkdir -p "${f%/*}" && "${@:2}" >"$f.$$" 2>/dev/null && mv -f "$f.$$" "$f" || { rm -f "$f.$$"; return 1; }
  fi
  # shellcheck source=/dev/null
  . "$f"
}

# fzf — Ctrl+R: search the history · Ctrl+T: put a file or folder's path where you type ·
# Alt+C: go into a folder below this one · `nvim **<Tab>`: pick the argument fuzzily.
# fd lists the files (fast; skips .git and whatever .gitignore hides), bat and eza preview
# them, and every list wears the popups' look (~/.config/fedokawaii/fzf.opts): a ruled title,
# the theme's colours.
if command -v fzf >/dev/null && command -v fd >/dev/null; then
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git --strip-cwd-prefix'
  # the look every list of the desktop shares (rules, colours, the chevron): one file
  export FZF_DEFAULT_OPTS_FILE=$HOME/.config/fedokawaii/fzf.opts FZF_DEFAULT_OPTS="--height=50%"
  __kawa_peek="if [[ -d {} ]]; then eza -T -L 2 --color=always --group-directories-first {}; \
else bat --color=always --style=numbers --line-range=:300 {}; fi"
  export FZF_CTRL_T_COMMAND='fd --hidden --exclude .git --strip-cwd-prefix'
  export FZF_CTRL_T_OPTS="--border-label=' files ' --preview='$__kawa_peek' --preview-window=right,55%,border-left"
  export FZF_ALT_C_COMMAND='fd --type d --hidden --exclude .git --strip-cwd-prefix'
  export FZF_ALT_C_OPTS="--border-label=' folders ' --preview='eza -T -L 2 --color=always --group-directories-first {}' --preview-window=right,55%,border-left"
  export FZF_CTRL_R_OPTS="--border-label=' history '"
  unset __kawa_peek
  _fzf_compgen_path() { fd --hidden --exclude .git . "$1"; }        # what **<Tab> lists
  _fzf_compgen_dir()  { fd --type d --hidden --exclude .git . "$1"; }
  __kawa_init fzf fzf --bash
fi

# zoxide — `cd` learns the folders you go to: `cd proj` goes to the best match for "proj"
# from anywhere (~/repos/project), `cd re pro` matches both words in order, `cdi` picks
# from the list in fzf. A real path still works exactly like cd. yazi's `Z` uses the same list.
if command -v zoxide >/dev/null && __kawa_init zoxide zoxide init bash --cmd cd --hook none; then
  __kawa_z=1
fi

# ssh: few servers know foot's terminal type; every one knows xterm-256color
[[ $TERM == foot* ]] && ssh() { TERM=xterm-256color command ssh "$@"; }
