# ~/.config/blesh/init.sh — ble.sh's settings, read while ~/.bashrc.d/fedokawaii.sh loads it.
# ble.sh (the Bash Line Editor, lib/upstream.sh) does the typing: the line coloured as you
# type it (an unknown command in vermilion before you run it, a quote not yet closed, a
# file that exists underlined), a grey suggestion from your history — → (or End) takes it,
# Ctrl+→ one word of it, Enter runs only what you typed — and a completion menu that Tab and
# the arrows move through, narrowed as you type. Everything else stays as bash and
# ~/.config/readline/inputrc have it (Up/Down search by what is typed, Ctrl+←/→ and
# Ctrl+Backspace by word).
# shellcheck shell=bash disable=SC2034

# ── one place for each thing ────────────────────────────────────────────────
# The prompt shows how a command ended and how long it took (✓ / ✗ and its code, the
# time): ble.sh's own lines for them ("[ble: exit 1]", "[ble: elapsed …]") stay off.
bleopt exec_errexit_mark= exec_elapsed_mark=
# no bell (a Tab that finds nothing): ~/.config/readline/inputrc's bell-style none is
# readline's, and ble.sh has its own switch for it
bleopt edit_bell=

# ── fzf and zoxide, through ble.sh ──────────────────────────────────────────
# ble.sh reads the keys itself, so fzf's keys go through it: Ctrl+R, Ctrl+T and Alt+C from
# Fedora's fzf (/usr/share/fzf/shell/key-bindings.bash, read with its readline lines left
# out). fzf's ** completion (bash-completion has read it) and zoxide's `cd` completion
# (fedokawaii.sh has) are wrapped so they open only for Tab, never for the suggestion that
# follows your typing. -d: done just after the first prompt shows, not before it.
ble-import -d integration/fzf-key-bindings
ble-import -d integration/fzf-completion
ble-import -d integration/zoxide

# ── colours: the terminal's 16 only, so both themes are right and a theme switch ─
# ── (foot's palette, changed live) recolours the line as it does everything else ─
# 8 faint · 9 vermilion · 10 matcha · 11 yamabuki · 12 indigo · 13 wisteria · 14 asagi.
# The "bright" ones throughout: on paper the theme makes them the deeper inks, so they
# read as well on both grounds. No bold: Sumi Term has none; the colours carry it.
# (NAME_@ is every face whose name starts so; the lines after it make the exceptions)
#   what you type: commands in asagi, the shell's own words (if, for, do…), variables and
#   expansions in wisteria, quoted text in yamabuki, | ; && > and options in indigo,
#   comments faint, a mistake — an unknown command, a quote never closed — in vermilion
ble-face syntax_@=fg=13 command_@=fg=14 varname_@=fg=13
ble-face syntax_default=none syntax_command=fg=14 syntax_function_name=fg=14 \
  syntax_quoted=fg=11 syntax_quotation=fg=11 syntax_document=fg=11 syntax_document_begin=fg=11 \
  syntax_tilde=fg=12 syntax_delimiter=fg=12 argument_option=fg=12 syntax_comment=fg=8 \
  syntax_error=fg=9 argument_error=fg=9 command_suffix_new=fg=9 command_keyword=fg=13 \
  varname_unset=fg=8
#   a word that names a file that exists is underlined, coloured by kind as eza colours it
#   (a folder typed as a command — autocd goes into it — as folders are)
ble-face filename_@=fg=11,underline
ble-face filename_directory=fg=12,underline filename_directory_sticky=fg=12,underline \
  command_directory=fg=12,underline cmdinfo_cd_cdpath=fg=12,underline filename_url=fg=12,underline \
  filename_link=fg=14,underline filename_executable=fg=10,underline \
  filename_orphan=fg=9,underline filename_warning=fg=9,underline \
  filename_other=underline filename_ls_colors=underline
# the suggestion: faint, like a pencil line, nothing behind it
ble-face auto_complete=fg=8 disabled=fg=8
# the completion menu: entries coloured by kind, as eza colours them. The chosen one wears
# the desktop's mark for what is active — filled in vermilion, as in every fzf list (foot's
# colours 16 and 17, which only foot has: elsewhere, on the text consoles, reversed).
# Selected text is reversed, as foot shows a selection; a history search's match vermilion.
ble-face menu_complete_match=none menu_filter_input=fg=9 menu_filter_fixed=fg=15 \
  region=reverse region_target=reverse region_insert=fg=12 region_match=fg=9 overwrite_mode=reverse
if [[ $TERM == foot* ]]; then
  ble-face menu_complete_selected=fg=17,bg=16
else
  ble-face menu_complete_selected=reverse
fi
