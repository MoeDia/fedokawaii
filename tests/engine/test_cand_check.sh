#!/usr/bin/env bash
# tests/engine/test_cand_check.sh — lib/cand-check.sh's checks of the configs we own (T45 (7)): each
# program's own word on its config, red when it refuses, never red on a warning. The checks are real;
# the programs are stand-ins that answer as the real ones were measured to (update-design.md §2.5).
. "$(dirname "$0")/lib.sh"

fresh() {
  sandbox
  S=$TMP/say; mkdir -p "$S" "$HOME/.local/bin"
  stub runuser 'shift 3; exec "$@"'
  stub getent "echo \"t:x:1000:1000::$HOME:/bin/bash\""
  stub lsinitrd
  stub foot "[ -e $S/foot-bad ] && exit 230; exit 0"
  stub nvim "cat $S/nvim-says >&2 2>/dev/null; exit \$(cat $S/nvim-rc 2>/dev/null || echo 0)"
  # (the real yazi prints its config error and waits for a key; a good start waits for q)
  printf '%s\n' '#!/bin/bash' "[ -e $S/yazi-bad ] && printf 'Failed to load\n\nCaused by:\nTOML parse error at line 3\n'" \
    'IFS= read -rsn1 _' 'exit 0' >"$HOME/.local/bin/yazi"
  chmod +x "$HOME/.local/bin/yazi"
  G=$TMP/greetd.toml
  printf '%s\n' '[terminal]' 'vt = 1' '[default_session]' 'command = "bash -c greeter"' 'user = "greeter"' >"$G"
}
chk() { FK_FIXER=/nonexistent FK_USER=t FK_GREETD=$G bash "$REPO/lib/cand-check.sh" 2>/dev/null; rc=$?; }

case_ "every config taken: not one word about them"
fresh; w=$(chk); lacks "$w" foot; lacks "$w" nvim; lacks "$w" yazi; lacks "$w" greetd
case_ "foot refuses its config: red, in its words"
fresh; : >"$S/foot-bad"; w=$(chk); has "$w" "red: foot does not take its config"
case_ "nvim: an error in its config (status 0, words on stderr): red, the line named"
fresh; printf 'Error in /home/t/.config/nvim/init.lua:\nE5112: Lua chunk: init.lua:4: = expected near is\n' >"$S/nvim-says"
w=$(chk); has "$w" "red: nvim does not take its config: Error in /home/t/.config/nvim/init.lua:"
case_ "nvim: a plugin's traceback with no Error line: red"
fresh; printf 'a plugin says something\nstack traceback:\n\tfoo.lua:1\n' >"$S/nvim-says"; w=$(chk); has "$w" "red: nvim does not take its config: stack traceback"
case_ "nvim: a warning is no red (a new nvim's deprecation words)"
fresh; printf 'vim.tbl_islist is deprecated. Run ":checkhealth vim.deprecated" for more information\n' >"$S/nvim-says"; w=$(chk); lacks "$w" nvim
case_ "nvim that does not start at all: red"
fresh; echo 127 >"$S/nvim-rc"; w=$(chk); has "$w" "red: nvim does not start (status 127)"
case_ "yazi: its config error at a real start: red"
fresh; : >"$S/yazi-bad"; w=$(chk); has "$w" "red: yazi does not take its config"
case_ "yazi not there: not this check's word (verify's)"
fresh; rm "$HOME/.local/bin/yazi"; w=$(chk); lacks "$w" yazi
case_ "greetd: not TOML: red"
fresh; printf 'not = = toml [\n' >"$G"; w=$(chk); has "$w" "red: greetd cannot read greetd.toml"
case_ "greetd: what greetd(5) requires missing: red"
fresh; printf '[terminal]\nvt = 1\n' >"$G"; w=$(chk); has "$w" "red: greetd cannot read greetd.toml"
fresh; printf '[default_session]\ncommand = "bash"\n' >"$G"; w=$(chk); has "$w" "red: greetd cannot read greetd.toml"
case_ "greetd: the greeter's program gone: red, named"
fresh; printf '[terminal]\nvt = 1\n[default_session]\ncommand = "/nothing/here --x"\n' >"$G"; w=$(chk); has "$w" "red: greetd's greeter is not there: /nothing/here"
case_ "the copy's own reds, from before its packages (--before), are not this update's: another's still is"
fresh; : >"$S/foot-bad"
B=$TMP/before; FK_FIXER=/nonexistent FK_USER=t FK_GREETD=$G bash "$REPO/lib/cand-check.sh" --before >"$B" 2>/dev/null
has "$(cat "$B")" "foot does not take its config"; lacks "$(cat "$B")" "red:"
w=$(FK_BEFORE=$B FK_FIXER=/nonexistent FK_USER=t FK_GREETD=$G bash "$REPO/lib/cand-check.sh" 2>/dev/null); lacks "$w" foot
: >"$S/yazi-bad"; w=$(FK_BEFORE=$B FK_FIXER=/nonexistent FK_USER=t FK_GREETD=$G bash "$REPO/lib/cand-check.sh" 2>/dev/null); lacks "$w" foot; has "$w" "red: yazi does not take its config"
case_ "the fixer there: its table's reds, in its words, beside yazi's and greetd's"
fresh; F=$TMP/fixer; : >"$F"; chmod +x "$F"
printf 'import sys\nprint("red: mako does not take its config — Failed to parse")\nsys.exit(1)\n' >"$F"
w=$(FK_FIXER=$F FK_USER=t FK_GREETD=$G bash "$REPO/lib/cand-check.sh" 2>/dev/null); has "$w" "red: mako does not take its config — Failed to parse"; lacks "$w" foot
case_ "any red: the exit says so"
fresh; : >"$S/foot-bad"; chk >/dev/null; eq "$rc" 1

done_
