# /etc/profile.d/fedokawaii-home.sh — installed by setup.sh. Where programs keep their files
# in your home: settings in ~/.config, data in ~/.local/share, history and what programs
# remember in ~/.local/state, what can be made again in ~/.cache (the XDG folders) — and the
# programs that would otherwise drop a file or a folder straight into ~ told to use them.
# Read by every login and every bash (Fedora's /etc/profile and /etc/bashrc), by the session
# (start-dwl), by setup's commands run as you (lib/common.sh: home_env) and by kawa-tidy,
# which moves what an older version left in the old places (the name after each line).
# One variable a line, exactly `export NAME="$HOME/…"`: home_env reads them so.
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.cache"
export HISTFILE="$HOME/.local/state/bash/history"                 # ~/.bash_history
export LESSHISTFILE="$HOME/.local/state/less/history"             # ~/.lesshst
export PYTHON_HISTORY="$HOME/.local/state/python/history"         # ~/.python_history (Python 3.13 on)
export NODE_REPL_HISTORY="$HOME/.local/state/node/repl_history"   # ~/.node_repl_history
export SQLITE_HISTORY="$HOME/.local/state/sqlite/history"         # ~/.sqlite_history
export NPM_CONFIG_CACHE="$HOME/.cache/npm"                        # ~/.npm (npm's cache and logs)
export CARGO_HOME="$HOME/.local/share/cargo"                      # ~/.cargo (rustup's cargo, rustc…)
export RUSTUP_HOME="$HOME/.local/share/rustup"                    # ~/.rustup (the toolchains)
export VD_DIR="$HOME/.local/share/visidata"                       # ~/.visidata (visidata's saved sheets)
export GIT_CONFIG_GLOBAL="$HOME/.config/git/config"              # ~/.gitconfig (git config --global writes here)
# readline (bash's typing): the desktop's file when the theme put one there (a variable naming
# a file that is not there would leave out /etc/inputrc as well)
[ -r "$HOME/.config/readline/inputrc" ] && export INPUTRC="$HOME/.config/readline/inputrc"
# the folders the history files and git's settings go in: none of those programs makes its own
if [ -w "$HOME" ]; then
  for _d in bash less python node sqlite; do [ -d "$HOME/.local/state/$_d" ] || mkdir -p "$HOME/.local/state/$_d"; done
  [ -d "$HOME/.config/git" ] || mkdir -p "$HOME/.config/git"   # (git writes no file into a folder not there)
  unset _d
fi
case ":$PATH:" in *":$CARGO_HOME/bin:"*) ;; *) PATH="$PATH:$CARGO_HOME/bin" ;; esac
