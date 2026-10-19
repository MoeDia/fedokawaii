#!/usr/bin/env bash
# tests/content/test_configs.sh — the content helpers' configs, read as their programs read
# them: zathura's (and each theme's colours it includes), bat's, btop's (and each theme's
# colours), VisiData's and gdu's (terminal colours only, so they follow the theme through
# foot; run by the real vd when this machine has it), the fzf options
# every list of the desktop shares — and the clipboard and books windows' own fzf command
# lines, parsed by the real fzf when this machine has it.
. "$(dirname "$0")/lib.sh"
sandbox
TH=$REPO/configs/home/.config/fedokawaii/themes

# ── zathura ──────────────────────────────────────────────────────────────────
config .config/zathura/zathurarc
Z=$HOME/.config/zathura/zathurarc
# zathurarc(5), 0.5 to 2026.x (window-icon-document, gone in 2026.02, is not among them)
ZOPTS=" abort-clear-search adjust-open advance-pages-per-row completion-bg completion-fg
completion-group-bg completion-group-fg completion-highlight-bg completion-highlight-fg
database dbus-service default-bg default-fg double-click-follow exec-command filemonitor
first-page-column font guioptions highlight-active-color highlight-color highlight-fg
highlight-transparency incremental-search index-active-bg index-active-fg index-bg index-fg
inputbar-bg inputbar-fg link-hadjust link-zoom n-completion-items notification-bg
notification-error-bg notification-error-fg notification-fg notification-warning-bg
notification-warning-fg page-cache-size page-padding page-right-to-left page-thumbnail-size
pages-per-row recolor recolor-darkcolor recolor-keephue recolor-lightcolor recolor-reverse-video
render-loading render-loading-bg render-loading-fg sandbox scroll-full-overlap scroll-hstep
scroll-page-aware scroll-step scroll-wrap search-hadjust selection-clipboard
selection-notification show-directories show-hidden show-recent statusbar-basename
statusbar-bg statusbar-fg statusbar-h-padding statusbar-home-tilde statusbar-page-percent
statusbar-v-padding synctex synctex-editor-command vertical-center window-height window-icon
window-title-basename window-title-home-tilde window-title-page window-width zoom-center
zoom-max zoom-min zoom-step "
zcheck() {   # zcheck FILE — every line a comment, a known set, a known map or an include
  local f=$1 line n=0 k v
  while IFS= read -r line; do
    n=$((n + 1)); [[ -z ${line//[[:space:]]/} || $line == \#* ]] && continue
    read -r k v rest <<<"$line"
    case $k in
      set) [[ $ZOPTS == *[[:space:]]"$v"[[:space:]]* ]] && _ok || _no "${f##*/}:$n: unknown option $v" ;;
      map) [[ ${rest%% *} =~ ^(recolor|reload|print|toggle_statusbar|toggle_inputbar|toggle_index|zoom|scroll|navigate|quit)$ ]] \
             && _ok || _no "${f##*/}:$n: unknown function ${rest%% *}" ;;
      include) [[ -r $(dirname "$f")/$v ]] && _ok || _no "${f##*/}:$n: $v does not resolve" ;;
      *) _no "${f##*/}:$n: $line" ;;
    esac
  done <"$f"
}
case_ "zathurarc: every setting known to zathura, its include found (dark and light)"
mkdir -p "$HOME/.config/fedokawaii"
zcheck "$Z"
ln -sfn themes/light "$HOME/.config/fedokawaii/current"; zcheck "$Z"
ln -sfn themes/dark "$HOME/.config/fedokawaii/current"
case_ "the themes' zathurarc: colours only, each a colour zathura reads"
for t in dark light; do
  zcheck "$TH/$t/zathurarc"
  bad=$(grep -E '^set ' "$TH/$t/zathurarc" | grep -vE '^set +[a-z-]+ +"(#[0-9a-f]{6}|rgba\([0-9]+,[0-9]+,[0-9]+,[01]\.[0-9]+\))"$')
  eq "$bad" "" "$t: a value zathura would not read"
done
case_ "zathurarc: r reloads (the guide's §16.1), Ctrl+r recolours, the font is the desktop's monospace"
has "$(cat "$Z")" $'map r reload'; has "$(cat "$Z")" $'map <C-r> recolor'
has "$(cat "$Z")" 'set font "JetBrainsMono Nerd Font'
has "$(cat "$REPO/configs/home/.config/fontconfig/fonts.conf")" "<family>JetBrainsMono Nerd Font</family>"
if command -v zathura >/dev/null; then
  case_ "zathurarc: every option it sets is one this zathura knows (its binary, and girara's for the window's)"
  zbin=("$(command -v zathura)"); while read -r l; do zbin+=("$l"); done < <(ldd "${zbin[0]}" 2>/dev/null | grep -o '/[^ ]*girara[^ ]*')
  for o in $(grep -hoE '^set +[a-z-]+' "$Z" "$TH"/*/zathurarc | awk '{print $2}' | sort -u); do
    cat "${zbin[@]}" | grep -aqF -- "$o" && _ok || _no "this zathura has no $o"
  done
fi

# ── bat ──────────────────────────────────────────────────────────────────────
case_ "bat: the terminal's 16 colours (follows the theme), the guide's decorations, nothing else"
config .config/bat/config
eq "$(grep -vE '^(#|$)' "$HOME/.config/bat/config")" "--theme=ansi
--style=numbers,changes,header"
if command -v bat >/dev/null; then
  BAT_CONFIG_PATH=$HOME/.config/bat/config bat --color=always "$Z" >/dev/null 2>"$TMP/err"; r=$?
  eq "$r" 0; eq "$(cat "$TMP/err")" "" "bat's complaint about its config"
fi

# ── btop ─────────────────────────────────────────────────────────────────────
config .config/btop/btop.conf
# btop 1.4.6+ (Fedora 44: 1.4.7) — its config names (btop_config.cpp)
BOPTS=" color_theme theme_background truecolor force_tty presets vim_keys rounded_corners
terminal_sync graph_symbol graph_symbol_cpu graph_symbol_gpu graph_symbol_mem graph_symbol_net
graph_symbol_proc shown_boxes update_ms proc_sorting proc_reversed proc_tree proc_colors
proc_gradient proc_per_core proc_mem_bytes proc_cpu_graphs proc_info_smaps proc_left
proc_filter_kernel proc_aggregate cpu_graph_upper cpu_graph_lower show_gpu_info cpu_invert_lower
cpu_single_graph cpu_bottom show_uptime check_temp cpu_sensor show_coretemp cpu_core_map
temp_scale base_10_sizes show_cpu_freq clock_format background_update custom_cpu_name
disks_filter mem_graphs mem_below_net zfs_arc_cached show_swap swap_disk show_disks
only_physical use_fstab zfs_hide_datasets disk_free_priv show_io_stat io_mode io_graph_combined
io_graph_speeds net_download net_upload net_auto net_sync net_iface base_10_bitrate
show_battery selected_battery show_battery_watts log_level save_config_on_exit
nvml_measure_pcie_speeds rsmi_measure_pcie_speeds gpu_mirror_graph shown_gpus custom_gpu_name0 "
case_ "btop.conf: every name btop's, every value of its kind"
while IFS= read -r line; do
  [[ -z $line || $line == \#* ]] && continue
  k=${line%% =*} v=${line#*= }
  [[ $BOPTS == *[[:space:]]"$k"[[:space:]]* ]] && _ok || _no "unknown name $k"
  case $k in
    graph_symbol) [[ $v =~ ^\"(braille|block|tty)\"$ ]] && _ok || _no "$k = $v" ;;
    color_theme) [[ $v =~ ^\"[^\"/]+\"$ ]] && _ok || _no "$k = $v" ;;
    show_gpu_info) [[ $v =~ ^\"(Auto|On|Off)\"$ ]] && _ok || _no "$k = $v" ;;
    clock_format) [[ $v =~ ^\"[^\"]*\"$ ]] && _ok || _no "$k = $v" ;;   # ("": no clock in the CPU box)
    presets) [[ $v =~ ^\"((cpu|mem|net|proc):[01]:(default|braille|block|tty)[, ]?)+\"$ ]] && _ok || _no "$k = $v" ;;
    *) [[ $v == True || $v == False ]] && _ok || _no "$k = $v (True or False)" ;;
  esac
done <"$HOME/.config/btop/btop.conf"
case_ "btop.conf: kept as written (btop rewrites a config whose first line lacks its version unless told not to)"
has "$(cat "$HOME/.config/btop/btop.conf")" "save_config_on_exit = False"
case_ "btop.conf: the graphics card's line in the CPU box is on (the guide's §26.5: load, memory, heat, watts)"
has "$(cat "$HOME/.config/btop/btop.conf")" 'show_gpu_info = "On"'
case_ "btop's theme, both: a file of that name for color_theme, every key btop's, every value a colour"
name=$(sed -n 's/^color_theme = "\(.*\)"/\1/p' "$HOME/.config/btop/btop.conf"); eq "$name" fedokawaii
BKEYS=" main_bg main_fg title hi_fg selected_bg selected_fg inactive_fg graph_text meter_bg proc_misc
cpu_box mem_box net_box proc_box div_line temp_start temp_mid temp_end cpu_start cpu_mid cpu_end
free_start free_mid free_end cached_start cached_mid cached_end available_start available_mid
available_end used_start used_mid used_end download_start download_mid download_end upload_start
upload_mid upload_end process_start process_mid process_end proc_pause_bg "
for t in dark light; do
  [[ -r $TH/$t/btop.theme ]] && _ok || _no "$t: no btop.theme"
  while IFS= read -r line; do
    [[ -z $line || $line == \#* ]] && continue
    [[ $line =~ ^theme\[([a-z_]+)\]=\"#[0-9a-f]{6}\"$ ]] && [[ $BKEYS == *[[:space:]]"${BASH_REMATCH[1]}"[[:space:]]* ]] \
      && _ok || _no "$t: $line"
  done <"$TH/$t/btop.theme"
done

# ── visidata ─────────────────────────────────────────────────────────────────
# (vd on this machine: the one on PATH — Fedora's visidata, or a venv's — else the live checks
# are skipped; the file itself is checked all the same)
config .visidatarc
VRC=$HOME/.visidatarc
case_ ".visidatarc: every colour one of the terminal's 16 (a number 0-15 or a curses name), or the desktop's own 16 and 17 (foot.ini: the selection's fill and words), and attributes — never the rest of the 256-colour cube; every option set once"
out=$(python3 -I - "$VRC" <<'EOF'
import ast, re, sys
src = open(sys.argv[1]).read()
names = {"black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"}
attrs = {"bold", "underline", "reverse", "italic", "dim", "normal", "blink", "standout", "on", "fg", "bg"}
seen, bad = {}, []
for node in ast.parse(src).body:
    if not (isinstance(node, ast.Assign) and len(node.targets) == 1 and isinstance(node.targets[0], ast.Attribute)
            and isinstance(node.targets[0].value, ast.Name) and node.targets[0].value.id == "options"):
        bad.append(f"line {node.lineno}: not an options.NAME = VALUE line"); continue
    k, v = node.targets[0].attr, node.value
    if k in seen: bad.append(f"line {node.lineno}: {k} set again (line {seen[k]})")
    seen[k] = node.lineno
    if k.startswith("color_") or k == "plot_colors":
        if not isinstance(v, ast.Constant) or not isinstance(v.value, str):
            bad.append(f"line {node.lineno}: {k} is not a string"); continue
        for w in v.value.split():
            if w in names or w in attrs or (w.isdigit() and 0 <= int(w) <= 17): continue
            bad.append(f"line {node.lineno}: {k}: {w!r} is not one of the terminal's 16 colours")
print("\n".join(bad))
EOF
)
eq "$out" ""
case_ ".visidatarc: the defaults vd takes from the 256-colour cube are all overridden (the ones its 3.3 options list has)"
for k in color_default_hdr color_current_col color_key_col color_selected_row color_note_type color_note_row color_edit_cell \
         color_edit_unfocused color_status color_active_status color_keystrokes color_aggregator color_code color_error \
         color_warning color_working color_menu color_menu_active color_menu_spec color_menu_help color_cmdpalette color_sidebar \
         color_longname_guide color_guide_unwritten color_graph_hidden plot_colors; do
  grep -q "^options\.$k = " "$VRC" && _ok || _no "$k is left at vd's default"
done
case_ ".visidatarc: what vd draws together stays readable in both palettes (foot.ini's dark and light) — the cursor's column name, each part of the status line: 3:1 or more"
out=$(python3 -I - "$VRC" "$REPO/configs/home/.config/foot/foot.ini" 2>&1 <<'EOF'
import ast, re, sys
opts = {n.targets[0].attr: n.value.value for n in ast.parse(open(sys.argv[1]).read()).body}
NAMES = "black red green yellow blue magenta cyan white".split()
def spec(name, default=""):        # "bold 0 on 9" → (0, 9): None where it sets no colour
    fg = bg = None; on = False
    for w in opts.get(name, default).split():
        if w == "on": on = True; continue
        n = int(w) if w.isdigit() else NAMES.index(w) if w in NAMES else None
        if n is None: continue
        if on and bg is None: bg = n
        elif not on and fg is None: fg = n
    return fg, bg
def first(*xs): return next((x for x in xs if x is not None), None)
ini = open(sys.argv[2]).read()
def lum(h):
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    c = [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c]
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]
bad = []
for theme in ("dark", "light"):
    sec = re.search(r"^\[colors-%s\]\n(.*?)(?=^\[|\Z)" % theme, ini, re.M | re.S).group(1)
    kv = dict(re.findall(r"^(\w+)=([0-9a-fA-F]{6})", sec, re.M))
    pal = {i: kv["regular%d" % i] for i in range(8)} | {8 + i: kv["bright%d" % i] for i in range(8)} \
        | {16: kv["16"], 17: kv["17"]}                     # (the desktop's own: the selection's fill and words)
    FG, BG = kv["foreground"], kv["background"]
    col = lambda n, d: pal[n] if n is not None else d
    # VisiData 3.3 (update_attr): a colour fills what is not set yet, and replaces what is
    # set only at a higher precedence — the header's two are equal, a status markup is higher
    dflt, hdr, cur = spec("color_default"), spec("color_default_hdr"), spec("color_current_hdr")
    pairs = {"the cursor's column name": (first(hdr[0], dflt[0], cur[0]), first(hdr[1], dflt[1], cur[1]))}
    st = spec("color_active_status")
    pairs["the status line"] = st
    for part, d in (("color_longname_status", "white"), ("color_keystrokes", ""), ("color_working", "")):
        f, b = spec(part, d)
        pairs["the status line's " + part[6:]] = (first(f, st[0]), first(b, st[1]))
    for what, (f, b) in pairs.items():
        lf, lb = lum(col(f, FG)), lum(col(b, BG))
        r = (max(lf, lb) + 0.05) / (min(lf, lb) + 0.05)
        if r < 3: bad.append(f"{theme}: {what}: colour {f} on {b} — {r:.1f}:1")
print("\n".join(bad))
EOF
)
eq "$out" ""
case_ ".visidatarc: q asks before dropping unsaved changes (quitguard)"
has "$(cat "$VRC")" "options.quitguard = True"
case_ ".visidatarc: vd fetches nothing at start (its message of the day from visidata.org is off)"
has "$(cat "$VRC")" "options.motd_url = ''"
if [[ -n $REAL_VD ]]; then
  mkdir -p "$HOME/t"; cd "$HOME/t" || exit 1
  printf 'city,temp,day\nSharjah,41,Mon\nDubai,40,Tue\n\xd8\xa7\xd9\x84\xd8\xb9\xd9\x8a\xd9\x86,38,Wed\n\xe6\x9d\xb1\xe4\xba\xac,24,Thu\n' >"trip to Japan.csv"
  case_ "vd reads .visidatarc without a complaint (batch mode: no screen), and loads a CSV with spaces in its name and Arabic and Japanese cells"
  "$REAL_VD" -b -o out.csv -- "trip to Japan.csv" >"$TMP/vd.out" 2>&1; r=$?
  eq "$r" 0 "$(tail -n 3 "$TMP/vd.out" | tr '\n' '|')"
  lacks "$(cat "$TMP/vd.out")" "unknown option"; lacks "$(cat "$TMP/vd.out")" "Traceback"; lacks "$(cat "$TMP/vd.out")" "rror"
  eq "$(wc -l <out.csv)" 5; has "$(cat out.csv)" $'\xd8\xa7\xd9\x84\xd8\xb9\xd9\x8a\xd9\x86,38,Wed'; has "$(cat out.csv)" $'\xe6\x9d\xb1\xe4\xba\xac,24,Thu'
  case_ "vd sorts a column as a number and saves (a replayed command log: # then [ on temp — the guide's example)"
  printf '%s\n' '{"sheet":"trip to Japan","col":"temp","row":"","longname":"type-int","input":"","keystrokes":"#"}' \
                '{"sheet":"trip to Japan","col":"temp","row":"","longname":"sort-asc","input":"","keystrokes":"["}' >sort.vdj
  "$REAL_VD" -b -p sort.vdj -o sorted.csv -- "trip to Japan.csv" >"$TMP/vd.out" 2>&1; r=$?
  eq "$r" 0 "$(tail -n 3 "$TMP/vd.out" | tr '\n' '|')"
  eq "$(cut -d, -f2 sorted.csv | tr '\n' ' ')" "temp 24 38 40 41 "
  case_ "an empty file, and a broken one (a quote never closed): vd opens them and says so, never a traceback"
  : >empty.csv; printf 'a,b\n1,"open\n' >broken.csv
  "$REAL_VD" -b -o e.tsv -- empty.csv >"$TMP/vd.out" 2>&1; r=$?; eq "$r" 0 "$(tail -n 2 "$TMP/vd.out" | tr '\n' '|')"
  lacks "$(cat "$TMP/vd.out")" "Traceback"
  "$REAL_VD" -b -o b.tsv -- broken.csv >"$TMP/vd.out" 2>&1; r=$?; eq "$r" 0 "$(tail -n 2 "$TMP/vd.out" | tr '\n' '|')"
  lacks "$(cat "$TMP/vd.out")" "Traceback"
  case_ "a large CSV (200,000 rows): loaded and saved in one piece, well within a minute"
  python3 -I -c 'cities = "Sharjah Dubai Ajman".split()
with open("big.csv", "w") as f:
    f.write("id,city,amount\n")
    for i in range(200000): f.write(f"{i},{cities[i % 3]},{i % 997}\n")'
  SECONDS=0; "$REAL_VD" -b -o big.tsv -- big.csv >"$TMP/vd.out" 2>&1; r=$?
  eq "$r" 0 "$(tail -n 2 "$TMP/vd.out" | tr '\n' '|')"; eq "$(wc -l <big.tsv)" 200001
  ((SECONDS < 60)) && _ok || _no "took ${SECONDS}s"
  case_ "vd on the terminal (a pseudo-terminal of its own) with this file: the column names and the status line, then q quits"
  out=$(python3 -I "$C/pty_run.py" --cols 100 --rows 30 --timeout 30 --send 4 'q' -- "$REAL_VD" -- "trip to Japan.csv" 2>/dev/null | sed 's/\x1b\[[0-9;?]*[a-zA-Z]//g')
  has "$out" "city"; has "$out" "temp"; has "$out" "Sharjah"; lacks "$out" "Traceback"
  cd / || exit 1
else skip "vd is not installed (dnf install visidata) — .visidatarc is checked, vd itself is not run"; fi

# ── gdu ──────────────────────────────────────────────────────────────────────
config .config/gdu/gdu.yaml
GDU=$HOME/.config/gdu/gdu.yaml
case_ "gdu.yaml: a style block only, every key gdu 5.32's (configuration.md), every colour one of tcell's 16 terminal names"
out=$(python3 -I - "$GDU" <<'EOF'
import re, sys
keys = {"style": {"header": {"text-color", "background-color", "hidden"}, "footer": {"text-color", "background-color", "number-color"},
                  "selected-row": {"text-color", "background-color"}, "result-row": {"number-color", "directory-color"},
                  "progress-modal": {"current-item-path-max-len"}, "use-old-size-bar": None}}
names = {"black", "maroon", "green", "olive", "navy", "purple", "teal", "silver", "gray", "red", "lime", "yellow", "blue", "fuchsia", "aqua", "white"}
path, bad = [], []
for n, ln in enumerate(open(sys.argv[1]), 1):
    if not ln.strip() or ln.lstrip().startswith("#"): continue
    m = re.match(r"( *)([a-z-]+):(?: (.*))?$", ln.rstrip("\n"))
    if not m: bad.append(f"line {n}: not key: value"); continue
    depth = len(m.group(1)) // 2
    path = path[:depth] + [m.group(2)]
    d = keys
    for k in path[:-1]: d = d.get(k) if isinstance(d, dict) else None
    if not isinstance(d, (dict, set)) or path[-1] not in d: bad.append(f"line {n}: {'.'.join(path)} is not a key gdu has"); continue
    if m.group(3) is not None and path[-1].endswith("-color") and m.group(3) not in names:
        bad.append(f"line {n}: {m.group(3)!r} is not one of tcell's 16 terminal colours")
print("\n".join(bad))
EOF
)
eq "$out" ""
if [[ -n $REAL_GDU ]]; then
  case_ "gdu reads gdu.yaml (no screen: --non-interactive) and sizes a folder"
  mkdir -p "$HOME/t/sub"; head -c 300000 /dev/zero >"$HOME/t/sub/big"; : >"$HOME/t/small"
  out=$("$REAL_GDU" --config-file "$GDU" --non-interactive --no-progress "$HOME/t" 2>&1); r=$?
  eq "$r" 0 "$(tail -n 2 <<<"$out" | tr '\n' '|')"; has "$out" "sub"; lacks "$out" "rror"
else skip "gdu is not installed (dnf install gdu) — gdu.yaml is checked, gdu itself is not run"; fi

# ── fzf ──────────────────────────────────────────────────────────────────────
config .config/fedokawaii/fzf.opts
case_ "fzf.opts: the chevron filled in, three lines"
lacks "$(cat "$HOME/.config/fedokawaii/fzf.opts")" "@ICON_"
eq "$(grep -c . "$HOME/.config/fedokawaii/fzf.opts")" 3
if [[ -z $REAL_FZF ]]; then
  skip "no fzf here: the options are not parsed"
else
  case_ "fzf.opts: every option and colour parsed by fzf ($("$REAL_FZF" --version | cut -d' ' -f1))"
  out=$(FZF_DEFAULT_OPTS_FILE=$HOME/.config/fedokawaii/fzf.opts "$REAL_FZF" --filter x </dev/null 2>&1); r=$?
  eq "$r" 1 "1 = nothing matched; 2 = an option it does not know: $out"
  # the windows' own command lines: fzf's stand-in runs the real one, filtering, with them
  stub fzf "exec '$REAL_FZF' \"\$@\" --filter '' >/dev/null 2>\"\$HOME/fzf.err\" </dev/null"
  stub kawa-cell 'echo 9x21'; stub cliphist
  for w in "kawa-clip --tui" "kawa-books --tui"; do
    case_ "$w: fzf takes every option and key it is given"
    rm -f "$HOME/fzf.err"; $w; r=$?
    eq "$(cat "$HOME/fzf.err" 2>/dev/null)" "" "fzf's complaint"; ((r <= 1)) && _ok || _no "fzf exited $r"
  done
  case_ "kawa-books --add: fzf takes its options too (then the library comes back)"
  stub fd; rm -f "$HOME/fzf.err"; kawa-books --add
  eq "$(cat "$HOME/fzf.err" 2>/dev/null)" ""
fi

# ── neovim: lazy.nvim's own settings ─────────────────────────────────────────
case_ "lazy.nvim: no luarocks (no plugin needs a rock: :checkhealth lazy has no ERROR for a missing luarocks or Lua 5.1), no update checks"
L=$REPO/configs/home/.config/nvim/lua/config/lazy.lua
setup_tbl=$(sed -n '/^require("lazy").setup({$/,/^})$/p' "$L")
has "$setup_tbl" "  rocks = { enabled = false }," "rocks off, at the top of setup()"
has "$setup_tbl" "  checker = { enabled = false },"
eq "$(tr -cd '{' <<<"$setup_tbl" | wc -c)" "$(tr -cd '}' <<<"$setup_tbl" | wc -c)" "{ } balanced"

done_
