# ~/.config/visidata/config.py — VisiData (vd, the Tables window) in the desktop's colours.
# Python: vd 3 reads it at start, in place of ~/.visidatarc (`vd --help` lists every option;
# `vd -b` tests this file without a screen).
#
# vd draws with curses: a colour is one of the terminal's by number (0-15, foot's palette)
# or by name (black … white = 0-7), so it follows the dark and light theme like the shell,
# bat and yazi — nothing per theme here. Its own defaults reach into the 256-colour cube
# (81, 215, 237 …), which neither palette has; each of those is set to a palette colour
# below, after fzf.opts: 15 the strongest ink, 8 quiet, 9 vermilion, 14 asagi, 3 yamabuki,
# and the desktop's own slots past the sixteen (foot.ini): 24 the fill of what is selected
# (the lacquer), 25 the words on it. 'normal' alone is the terminal's own text on its own ground.

options.color_default = 'normal'                 # cells: text on the ground
options.color_default_hdr = 'bold'               # column names, in the text's own ink: the
                                                 # cursor's one takes its colours below whole
options.color_bottom_hdr = 'underline 15'
options.color_current_row = '25 on 24'           # the row under the cursor, filled as fzf's
options.color_current_col = 'bold'
options.color_current_hdr = '25 on 24'           # the cursor's column name, filled the same
options.color_column_sep = '8'                   # the rules between columns
options.color_key_col = '14'                     # key columns (!) in asagi
options.color_hidden_col = '8'
options.color_selected_row = '3'                 # selected rows (s, |) in yamabuki, as yazi
options.color_note_row = '3'
options.color_note_type = '3'
options.color_edit_cell = '15 on 0'              # typing into a cell
options.color_edit_unfocused = '7 on 0'
options.color_status = 'bold on 0'               # the status line
options.color_active_status = 'bold 15 on 0'     # … of the active window: the same quiet line, its words strongest
options.color_inactive_status = '8 on 0'
options.color_keystrokes = 'bold 15 on 0'        # the keys you pressed, at the right
options.color_longname_status = '8'              # … and the command's name, muted beside them
options.color_aggregator = 'bold 15 on 0'        # the sum row (+)
options.color_code = 'bold 15 on 0'
options.color_longname_guide = '8'
options.color_guide_unwritten = '8'
options.color_graph_hidden = '8'
options.color_error = '9'
options.color_warning = '3'
options.color_working = 'bold 0 on 11'           # a load still running (on the status bar)
options.color_menu = '7 on 0'                    # the menu bar (Alt+H)
options.color_menu_active = '25 on 24'           # … its item under the cursor, as every menu's
options.color_menu_spec = '0 on 14'
options.color_menu_help = '7 on 0'
options.color_cmdpalette = '7 on 0'              # the command palette (Space)
options.color_sidebar = '7 on 0'
options.plot_colors = '9 14 3 2 4 5 6 11 10'     # the graph's series (.)

# q on a sheet with unsaved changes asks first (Ctrl+S saves: the name's extension picks
# the format — .csv, .tsv, .json, .xlsx needs python3-openpyxl, which is not installed)
options.quitguard = True

# no message of the day fetched from visidata.org at each day's first start: vd stays offline
options.motd_url = ''

# no menu line along the top ("VisiData 3.3 · Support VisiData"): Alt+H opens the menu all the same
options.disp_menu = False
