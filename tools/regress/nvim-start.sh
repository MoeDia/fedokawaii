#!/usr/bin/env bash
# tools/regress/nvim-start.sh — never again (T30): the editor as the desktop runs it, in a pty that
# answers as foot does (tools/nvim-bench.py), with the repository's config over the installed
# plugins (read, never written): the first screen drawn once and a file's first frame with its
# status line (lualine came later and redrew them), no server or Mason for a text file, a key's
# frame its only one (lualine's own timer drew a second), Ctrl+D landing at once (snacks' animated
# scroll: 460 ms, 60 KB a press), the command line on its own row, nvim +Tutor (the Learn book's
# first exercise, once disabled by accident). No timing limit but Ctrl+D's: the frames are what
# nvim drew, load cannot move them.
#   bash tools/regress/nvim-start.sh
# Exit 0 held · 1 broken (said) · 2 no plugins here to run it with
set -u
here=$(cd "$(dirname "$0")" && pwd)
repo=$(cd "$here/../.." && pwd)
[[ -d $HOME/.local/share/nvim/lazy/snacks.nvim ]] || { echo "no neovim plugins here"; exit 2; }
sb=$(mktemp -d "${TMPDIR:-/tmp}/regress-nvim.XXXXXX")
trap 'rm -rf "$sb"' EXIT
python3 -B "$repo/tools/nvim-bench.py" sandbox "$sb" --link --config this="$repo/configs/home/.config/nvim" || exit 2
python3 -B "$repo/tools/nvim-bench.py" check "$sb" --variants this
