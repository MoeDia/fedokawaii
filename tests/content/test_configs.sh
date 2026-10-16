#!/usr/bin/env bash
# tests/content/test_configs.sh — the content helpers' configs, read as their programs read
# them: zathura's (and each theme's colours it includes), bat's, btop's (and each theme's
# colours), the fzf options every list of the desktop shares — and the clipboard and books
# windows' own fzf command lines, parsed by the real fzf when this machine has it.
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
    *) [[ $v == True || $v == False ]] && _ok || _no "$k = $v (True or False)" ;;
  esac
done <"$HOME/.config/btop/btop.conf"
case_ "btop.conf: kept as written (btop rewrites a config whose first line lacks its version unless told not to)"
has "$(cat "$HOME/.config/btop/btop.conf")" "save_config_on_exit = False"
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

done_
