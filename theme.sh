#!/usr/bin/env bash
# ═════════════════════════════════════════════════════════════════════════════
#  theme.sh — every config, colour and keybinding. Independent of setup.sh:
#  run it whenever you like once the software is installed. Safe to re-run.
#
#    sudo bash fedokawaii.sh theme    the usual way (the menu passes --user)
#    bash theme.sh                    as yourself: sudo is asked for only for the system
#                                     parts (/etc/dconf, the boot menu and console font,
#                                     the kernel command line, installing dwl)
#    sudo bash theme.sh --user NAME   as root, for that user (default: USERNAME in
#                                     fedokawaii.conf, else whoever ran sudo)
#    bash theme.sh --check            list files that differ from the repo; exit 3 if any
#                                     (4: in sync, but the boot menu and console could not
#                                     be made here — the one part that runs contained)
#
#  configs/home/   mirrors $HOME   →  copied as-is (tokens @HOME@ etc. rendered; fonts
#                                     and pointers copied byte for byte; the pointers'
#                                     other names made links, from art/cursor-names.txt)
#  pointers        Sumi-dark/light →  /usr/share/icons; ~/.local/share/icons/default links to
#                                     the one of the theme in use (kawa-theme keeps it so)
#  themes          dark + light    →  ~/.config/fedokawaii/current links to the one in
#                                     use (THEME in fedokawaii.conf on a new install;
#                                     afterwards whatever kawa-theme last chose)
#  wallpaper pack                  →  fetched once, kept as it came (WALLPAPER_PACK), then
#                                     drawn ahead for the monitor (~/.cache/fedokawaii)
#  configs/system/ mirrors /       →  /etc/dconf (GTK and LibreOffice defaults, root)
#  bin/*                           →  ~/.local/bin (menus, bar helpers, fetch)
#  src/dwl/config.h + dwl.patch    →  ~/.local/src/dwl, dwl rebuilt only if it changed
#  boot + console                  →  the GRUB menu's pixel theme, the text console's 16
#                                     colours (kernel command line) and its font
#  Replaced files are backed up to ~/.local/state/fedokawaii/backup/<time>/.
# ═════════════════════════════════════════════════════════════════════════════
set -Eeuo pipefail
IFS=$'\n\t'
export LC_ALL=C.UTF-8      # every tool's output in one language and format, whatever yours is
REPO_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
CHECK=0 TARGET_USER=""
while (($#)); do
  case $1 in
    --check) CHECK=1; shift ;;
    --user)  [[ -n ${2:-} && $2 != -* ]] || { echo "--user needs a user name: --user NAME" >&2; exit 2; }
             TARGET_USER=$2; shift 2 ;;
    -h|--help) sed -n '3,/^# ═/p' "$0" | sed '$d'; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

if [[ $EUID -eq 0 ]]; then LOG_FILE=/var/log/fedokawaii.log
else LOG_FILE=$HOME/.cache/fedokawaii-theme.log; mkdir -p "$HOME/.cache"; fi
export LOG_FILE
source "$REPO_DIR/lib/common.sh"
source "$REPO_DIR/lib/manifest.sh"
source "$REPO_DIR/lib/hardware.sh"
load_conf "$REPO_DIR"
# whom it is for: as root, --user, else USERNAME (read as setup reads it), else whoever ran sudo
if [[ $EUID -eq 0 ]]; then
  TARGET_USER=${TARGET_USER:-${USERNAME:-${SUDO_USER:-}}}
  [[ -n $TARGET_USER && $TARGET_USER != root ]] || { echo "as root: --user NAME" >&2; exit 2; }
else
  TARGET_USER=$(id -un)
fi
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6) || TARGET_HOME=""
[[ -n $TARGET_HOME ]] || die "no user $TARGET_USER on this machine"
TARGET_UID=$(id -u "$TARGET_USER"); TARGET_GID=$(id -g "$TARGET_USER")
export TARGET_USER TARGET_HOME TARGET_UID TARGET_GID
# A stop half-way is safe — every file is replaced whole and the next run compares again —
# but say where it stopped and what had already changed.
# shellcheck disable=SC2154  # rc is assigned inside the trap string
# (on stderr; inside a $(…) or <(…) it only ends that piece, silently — see setup.sh)
# (as setup.sh's: a command lib/common.sh's run or retry saw fail is named, not their return)
trap 'rc=$?; ((BASH_SUBSHELL == 0)) || exit $rc; failed_what "${FUNCNAME[0]:-main}:$LINENO"; _out "${C_RED}✘ line $LINENO${FUNCNAME[0]:+ in ${FUNCNAME[0]}(), called from line ${BASH_LINENO[-2]}}: ${FAILED_SHOW:0:160} (exit $rc)${C_RESET}" >&2; exit $rc' ERR
on_exit() {                  # (explicit "return 0": a bare return in a trap handler would
  local rc=$?                # hand back the exit status and set off the ERR trap)
  ((rc == 0 || CHECK)) && return 0
  ((${#CHANGED[@]})) || return 0
  _out "  ${#CHANGED[@]} file(s) were already updated (previous versions in ${BACKUP/#$TARGET_HOME/\~});"
  _out "  fix the cause and run it again: whatever is already in sync is skipped"
}
CHANGED=()
trap on_exit EXIT
STATE=$TARGET_HOME/.local/state/fedokawaii
U() { if [[ $EUID -eq 0 ]]; then as_user "$@"; else "$@"; fi; }      # as the desktop user
R() { if [[ $EUID -eq 0 ]]; then "$@"; else sudo "$@"; fi; }         # as root
# the check reads system files too (/etc, the boot menu): without sudo they would all look
# changed, so as a user it asks for sudo once, up front
if ((CHECK)) && [[ $EUID -ne 0 ]] && ! sudo -n true 2>/dev/null; then
  echo "the check also reads system files (/etc, the boot menu) — sudo asks once:" >&2
  sudo -v || die "no sudo rights — run: sudo bash fedokawaii.sh drift"
fi
if ((CHECK == 0)); then
  U mkdir -p "$STATE"
  [[ -d $STATE && ! -L $STATE ]] || die "$STATE is not a folder"
  take_lock "$STATE"                                                  # your folder, opened read-only
fi
# dwl is the system's own, built from the desktop user's source (setup's record of who that
# is): for anyone else — a second person on the machine — the theme does their home alone,
# and their sessions run that same dwl
DESK_USER=$(head -n1 /var/lib/fedokawaii/user 2>/dev/null | tr -d '[:space:]') || DESK_USER=""
DWL_MINE=1; [[ -n $DESK_USER && $DESK_USER != "$TARGET_USER" ]] && DWL_MINE=0
# the theme styles installed software; it cannot run before setup has built dwl
[[ -x /usr/local/bin/dwl ]] && { ((DWL_MINE == 0)) || [[ -d $TARGET_HOME/.local/src/dwl ]]; } \
  || die "the software is not installed yet — run Setup first (sudo bash fedokawaii.sh setup)"

# The boot menu and the text console are always ink-dark: their colours come from the
# dark theme's generated colors.sh (tools/build-themes.py), read in a subshell so its
# THEME= line cannot touch this script's settings — and checked before anything changes.
ink() { ( . "$REPO_DIR/configs/home/.config/fedokawaii/themes/dark/colors.sh" && for v; do printf '%s ' "${!v}"; done ); }
IFS=' ' read -r -a CONSOLE_PALETTE <<<"$(ink C_ANSI)"            # (this script's IFS is \n\t)
IFS=' ' read -r INK_GROUND INK_SURFACE INK_EDGE INK_EDGE2 INK_FAINT INK_TEXT INK_STRONG INK_ACCENT \
  <<<"$(ink C_GROUND C_SURFACE C_EDGE C_EDGE2 C_FAINT C_TEXT C_STRONG C_ACCENT)"
((${#CONSOLE_PALETTE[@]} == 16)) && [[ -n ${INK_ACCENT:-} ]] \
  || die "the dark theme's colors.sh is incomplete (run tools/build-themes.py)"
CONSOLE_PALETTE[0]=$INK_GROUND                 # colour 0 is the console's background

# mpv's scaling: its high-quality profile (ewa_lanczossharp, debanding) wants a discrete
# GPU — written for an AMD card with memory of its own (2 GiB or more: not the shared
# memory of an APU); anywhere else mpv's own defaults, which integrated graphics keep up with
# (lib/hardware.sh, hw_discrete_amd)
MPV_SCALING="# scaling: mpv's own defaults (profile=high-quality is written with a discrete AMD GPU)"
hw_discrete_amd && MPV_SCALING="profile=high-quality              # ewa_lanczossharp scaling and debanding (discrete AMD GPU)"

# the pointer of every list (the fzf options file): the icon font's chevron
CHEVRON=$(. "$REPO_DIR/configs/home/.config/fedokawaii/icons.sh" && printf '%s' "$ICON_CHEVRON_RIGHT")

# btop's box for the discrete AMD card: its number in ROCm SMI's order (lib/hardware.sh,
# hw_btop_gpu) — and no card's box at all without one
BTOP_GPU=$(hw_btop_gpu); BTOP_BOXES="cpu ${BTOP_GPU:+$BTOP_GPU }mem net proc"

render() {      # render SRC → stdout, with fedokawaii.conf values (and the chevron) filled in
  sed -e "s|@HOME@|$TARGET_HOME|g" -e "s|@MONITOR_HZ@|$MONITOR_HZ|g" \
      -e "s|@WEATHER_CITY@|$WEATHER_CITY|g" -e "s|@NIGHT_LIGHT@|$NIGHT_LIGHT|g" \
      -e "s|@ICON_CHEVRON_RIGHT@|$CHEVRON|g" -e "s|^@MPV_SCALING@\$|$MPV_SCALING|" -e "s|@UID@|$TARGET_UID|g" \
      -e "s|@BTOP_BOXES@|$BTOP_BOXES|g" -e "s|@BTOP_GPU@|${BTOP_GPU:-gpu0}|g" "$1"
}

BACKUP="$TARGET_HOME/.local/state/fedokawaii/backup/$(date +%Y%m%d-%H%M%S)"
DRIFT=() TOTAL=0
changed() { local f; for f in "${CHANGED[@]}"; do [[ $f == *"$1"* ]] && return 0; done; return 1; }

# uinstall MODE SRC DEST — a file of the user's, written by the user, folders too (root
# never writes into the home: a link planted there could steer its write elsewhere)
uinstall() {
  U mkdir -p "$(dirname "$3")"
  U bash -c "$USER_PUT_SH" _ "$1" "$3" <"$2"
}

# place SRC DEST user|root — install only when the rendered content differs.
# Mode comes from content, not repo permission bits (web uploads drop them).
place() {
  local src=$1 dst=$2 who=$3 tmp mode=0644
  TOTAL=$((TOTAL + 1))
  tmp=$(mktemp)
  case ${src#"$REPO_DIR/"} in      # (the path inside the repo: wherever the repo itself lives)
    *.ttf|*.otf|*.png|*/cursors/*) cp "$src" "$tmp" ;;   # binary: byte for byte, never through sed
    *) render "$src" >"$tmp"
       [[ $(head -c2 "$src") == '#!' ]] && mode=0755 ;;
  esac
  if [[ -f $dst ]] && cmp -s "$tmp" "$dst" && [[ $(stat -c %a "$dst") == "${mode#0}" ]]; then rm -f "$tmp"; return 0; fi
  if ((CHECK)); then DRIFT+=("$dst"); rm -f "$tmp"; return 0; fi
  # the old version kept, copied by the user (-P: a link stays a link, never read through)
  if [[ -e $dst || -L $dst ]]; then
    U mkdir -p "$(dirname "$BACKUP${dst#"$TARGET_HOME"}")"
    U cp -P -- "$dst" "$BACKUP${dst#"$TARGET_HOME"}" 2>/dev/null || log "could not keep a copy of $dst"
  fi
  if [[ $who == root ]]; then R install -D -m "$mode" -o root -g root "$tmp" "$dst"
  else uinstall "$mode" "$tmp" "$dst"; fi
  rm -f "$tmp"; CHANGED+=("$dst")
}

# ── 1. home tree ─────────────────────────────────────────────────────────────
while IFS= read -r -d '' f; do
  rel=${f#"$REPO_DIR/configs/home/"}
  [[ $STEAM != yes && ( $rel == .config/MangoHud/* || $rel == .local/share/applications/steam.desktop ) ]] && continue   # the game overlay, Steam's entry: with Steam only
  set_aside "$rel" "$f" && continue        # repair took it out (it broke something): until it changes
  place "$f" "$TARGET_HOME/$rel" user
done < <(find "$REPO_DIR/configs/home" -type f -print0 | sort -z)
# the user units among them (the session target, the reminder): systemd --user reads them again
((CHECK)) || U systemctl --user daemon-reload 2>/dev/null || true

# ── 2. helpers ───────────────────────────────────────────────────────────────
for f in "$REPO_DIR"/bin/*; do   # (files only: a stray folder there, a __pycache__, is no helper)
  [[ -f $f ]] || continue
  place "$f" "$TARGET_HOME/.local/bin/${f##*/}" user
done

# ── 2b. the theme link, and the configs that are links into it ───────────────
# ~/.config/fedokawaii/current → themes/dark or themes/light. It is created once (from
# THEME in fedokawaii.conf) and then belongs to kawa-theme: re-running this script
# keeps whichever theme you switched to. Three apps have no include mechanism, so their
# whole config file is a link into the current theme; btop reads a colour theme only by
# name from its own themes folder, so "fedokawaii" there is a link too.
CUR=$TARGET_HOME/.config/fedokawaii/current
TOTAL=$((TOTAL + 1))
if [[ ! -L $CUR || ! -d $CUR ]]; then                     # missing or broken: start in $THEME
  if ((CHECK)); then DRIFT+=("$CUR (no theme chosen)")
  else
    # a real folder in its place (a backup or sync tool copied the link as a folder; the
    # handbook's "current is a folder, not a link"): kept in the backup first, like any file
    # replaced — whatever was edited inside it is yours
    if [[ -d $CUR && ! -L $CUR ]]; then
      U mkdir -p "$(dirname "$BACKUP${CUR#"$TARGET_HOME"}")"
      U cp -a -- "$CUR" "$BACKUP${CUR#"$TARGET_HOME"}" 2>/dev/null || log "could not keep a copy of $CUR"
      log "${CUR/#$TARGET_HOME/\~} was a folder, not a link — kept in the backup; the link to themes/$THEME is in its place"
    fi
    U rm -rf -- "$CUR"; U ln -sfn "themes/$THEME" "$CUR"; CHANGED+=("$CUR → themes/$THEME")
  fi
fi
LINKS=("../fedokawaii/current/qt6ct.conf:.config/qt6ct/qt6ct.conf"
       "../fedokawaii/current/imv:.config/imv/config"
       "../fedokawaii/current/wiremix.toml:.config/wiremix/wiremix.toml"
       "../../fedokawaii/current/btop.theme:.config/btop/themes/fedokawaii.theme")
for l in "${LINKS[@]}"; do
  target=${l%%:*} link=$TARGET_HOME/${l#*:}
  TOTAL=$((TOTAL + 1))
  [[ $(readlink "$link" 2>/dev/null) == "$target" ]] && continue
  if ((CHECK)); then DRIFT+=("$link (not a link to $target)"); continue; fi
  if [[ -f $link && ! -L $link ]]; then      # (kept, then taken away — by you: never root through your links)
    U mkdir -p "$(dirname "$BACKUP${link#"$TARGET_HOME"}")"
    U cp -P -- "$link" "$BACKUP${link#"$TARGET_HOME"}" 2>/dev/null || log "could not keep a copy of $link"
  fi
  U rm -f -- "$link"
  U mkdir -p "$(dirname "$link")"
  U ln -sfn "$target" "$link"
  CHANGED+=("$link → $target")
done

# files an earlier version installed that would now get in the way, or that belong to programs
# the desktop no longer has: moved to the backup (their folder too, once empty), but only
# while they are still ours — a file's content says so, or a link's target
retire() {   # retire FILE PATTERN
  local f=$TARGET_HOME/$1
  if [[ -L $f ]]; then [[ $(readlink "$f") == *"$2"* ]] || return 0
  else [[ -f $f ]] && grep -q -- "$2" "$f" || return 0; fi
  TOTAL=$((TOTAL + 1))
  if ((CHECK)); then DRIFT+=("$f (no longer used)"); return 0; fi
  U mkdir -p "$(dirname "$BACKUP/$1")"
  U cp -P -- "$f" "$BACKUP/$1" && U rm -f -- "$f"
  U rmdir --ignore-fail-on-non-empty -- "$(dirname "$f")"
  CHANGED+=("$f (retired)")
}
#   ~/.config/gtk-3.0/gtk.css — GTK 3 colours now live in the Fedokawaii themes; the old
#   file would pin one palette over both
retire .config/gtk-3.0/gtk.css 'current/gtk3.css'
#   ~/.local/share/applications/calf.desktop — hid Calf's JACK host, which came with EasyEffects
#   (both retired: PipeWire's own modules do their job)
retire .local/share/applications/calf.desktop "Calf's JACK host"
#   ~/.bashrc.d/scriptorium.sh — this project's old name: a second prompt and its aliases
retire .bashrc.d/scriptorium.sh 'scriptorium'
#   ~/.local/bin/kawa-audio — the old fuzzel sound menu: the sound panel (kawa-panel --sound)
#   took its place, and a copy left in ~/.local/bin would still answer to its name
retire .local/bin/kawa-audio 'kawa-audio — the sound menu'
#   ~/.local/bin/kawa-veil — the old theme and wallpaper transitions: kawa-saver --wash is the
#   one transition now (design-system §5)
retire .local/bin/kawa-veil 'usage: kawa-veil'
retire .local/state/fedokawaii/kawa-veil.sha256 ''
#   presenterm, sc-im and spotify_player — slides, sheets and Spotify are LibreOffice's and
#   Spotify's web player now: presenterm's link into the theme, the others' settings
retire .config/presenterm/config.yaml 'fedokawaii/current/'
retire .config/sc-im/scimrc 'sc-im'
retire .config/spotify-player/app.toml 'spotify_player'
retire .config/spotify-player/theme.toml 'spotify_player'
#   ~/.local/share/fedokawaii/icons/ — yazi's and herdr's logos, the launcher's Files and
#   Agents once: the desktop's own seals (current/apps) took their place
retire .local/share/fedokawaii/icons/yazi.png ''
retire .local/share/fedokawaii/icons/herdr.png ''
#   ~/.local/share/icons/default/index.theme — made the old pointers (Fedokawaii) the default;
#   the folder is now a link to the Sumi pointers of the theme in use (2c)
retire .local/share/icons/default/index.theme 'Inherits=Fedokawaii'
#   ~/.inputrc and ~/.visidatarc — now ~/.config/readline/inputrc (INPUTRC) and
#   ~/.config/visidata/config.py: nothing of the desktop's at the top of your home
retire .inputrc 'readline for bash'
retire .visidatarc 'VisiData (vd, the Tables window)'
#   ~/.local/share/applications/lpf*.desktop — lpf's entries, hidden while lpf built Spotify's
#   app here (Spotify is its web player now, and lpf is gone: setup.sh)
for LPF_ENTRY in lpf lpf-gui lpf-notify lpf-spotify-client; do retire ".local/share/applications/$LPF_ENTRY.desktop" 'lpf-spotify-client'; done

# ── 3. system tree (/etc, /usr/share/icons) ──────────────────────────────────
while IFS= read -r -d '' f; do
  place "$f" "/${f#"$REPO_DIR/configs/system/"}" root
done < <(find "$REPO_DIR/configs/system" -type f -print0 | sort -z)
# the dconf defaults of this project's old name (Scriptorium): another GTK theme and a close
# button in every title bar, compiled in after ours — out (setup.sh takes out the rest)
OLD_DCONF=/etc/dconf/db/local.d/00-scriptorium
if [[ -e $OLD_DCONF ]]; then
  TOTAL=$((TOTAL + 1))
  if ((CHECK)); then DRIFT+=("$OLD_DCONF (the old name's GTK defaults)")
  else R rm -f "$OLD_DCONF"; CHANGED+=("$OLD_DCONF (removed: the old name's GTK defaults)"); fi
fi

# ── 3a. the pointers ─────────────────────────────────────────────────────────
# Two pointer themes, Sumi-dark and Sumi-light (/usr/share/icons, for every account and the
# login screen; tools/build-cursors.py), each drawing every shape once under its standard
# name — placed with the system tree above. The other names programs ask by (left_ptr,
# hand2, xterm…) are links beside it, made here from art/cursor-names.txt (the toolkit holds
# only plain files).
while IFS=" " read -r name shape <&3; do
  [[ -z $name || $name == \#* ]] && continue
  for v in dark light; do
    link=/usr/share/icons/Sumi-$v/cursors/$name
    TOTAL=$((TOTAL + 1))
    [[ $(readlink "$link" 2>/dev/null) == "$shape" ]] && continue
    if ((CHECK)); then DRIFT+=("$link (not a link to $shape)"); continue; fi
    R ln -sfn "$shape" "$link"; CHANGED+=("$link → $shape")
  done
done 3<"$REPO_DIR/art/cursor-names.txt"
# ~/.local/share/icons/default → /usr/share/icons/Sumi-dark or Sumi-light: the pointers of
# whatever asks for "the default" theme — dwl itself, XWayland, and every program
# start-dwl's XCURSOR_THEME=default sends there. It wears the theme in use (the theme link,
# made above); kawa-theme re-points it with every switch.
MODE=$(readlink "$CUR" 2>/dev/null) || MODE=themes/$THEME
MODE=${MODE%/}; MODE=${MODE##*/}; [[ $MODE == light ]] || MODE=dark
DEFAULT=$TARGET_HOME/.local/share/icons/default
TOTAL=$((TOTAL + 1))
if [[ $(readlink "$DEFAULT" 2>/dev/null) != "/usr/share/icons/Sumi-$MODE" ]]; then
  if ((CHECK)); then DRIFT+=("$DEFAULT (not a link to /usr/share/icons/Sumi-$MODE)")
  else
    # a folder in its place (an earlier version's, its index.theme retired above): kept in
    # the backup first, should anything of yours be left in it
    if [[ -d $DEFAULT && ! -L $DEFAULT && -n $(ls -A -- "$DEFAULT") ]]; then
      U mkdir -p "$(dirname "$BACKUP${DEFAULT#"$TARGET_HOME"}")"
      U cp -a -- "$DEFAULT" "$BACKUP${DEFAULT#"$TARGET_HOME"}" 2>/dev/null || log "could not keep a copy of $DEFAULT"
    fi
    U mkdir -p "${DEFAULT%/*}"
    U rm -rf -- "$DEFAULT"; U ln -sfn "/usr/share/icons/Sumi-$MODE" "$DEFAULT"; CHANGED+=("$DEFAULT → /usr/share/icons/Sumi-$MODE")
  fi
fi
# the pointers before Sumi (~/.local/share/icons/Fedokawaii, while its index.theme still
# says so): replaced whole, so they go
OLD_POINTERS=$TARGET_HOME/.local/share/icons/Fedokawaii
if [[ -d $OLD_POINTERS && ! -L $OLD_POINTERS ]] && grep -qx 'Name=Fedokawaii' "$OLD_POINTERS/index.theme" 2>/dev/null; then
  TOTAL=$((TOTAL + 1))
  if ((CHECK)); then DRIFT+=("$OLD_POINTERS (the pointers before Sumi)")
  else U rm -rf -- "$OLD_POINTERS"; CHANGED+=("$OLD_POINTERS (removed: the pointers before Sumi)"); fi
fi


# ── 3b + 3c. boot menu, console palette and font ─────────────────────────────
# The one part of the theme that leans on tools Fedora may change around it (grubby, GRUB,
# ImageMagick, kbd's fonts), so it runs contained, last: if it fails, that is reported and
# shows up in --check, and everything else is themed all the same. (run_boot, after 6.)
boot_and_console() {
  # ── 3b. console palette ──────────────────────────────────────────────────────
  # The text console (login screen, Ctrl+Alt+F2…F6) takes its 16 colours from the kernel
  # parameters vt.default_{red,grn,blu}. Same order as foot's regular0-7 / bright0-7,
  # except colour 0, which is the console background: sumi ink instead of black.
  # grubby writes them to every boot entry and to /etc/default/grub, so new kernels
  # inherit them. They take effect at the next boot.
  # (the 16 colours: CONSOLE_PALETTE, read from the dark theme at the start)
  VT_ARGS=()
  for ch in red:0 grn:2 blu:4; do        # channel name : offset of its two hex digits
    vals=()
    for c in "${CONSOLE_PALETTE[@]}"; do vals+=("$((16#${c:${ch#*:}:2}))"); done
    VT_ARGS+=("vt.default_${ch%%:*}=$(IFS=,; echo "${vals[*]}")")
  done
  vt_in_sync() {          # every boot entry carries all three, with exactly these values
    local entries line v a n=0
    entries=$(R grubby --info=ALL) || return 1
    while IFS= read -r line; do
      [[ $line == args=* ]] || continue
      v=${line#args=}; v=${v#\"}; v=${v%\"}; n=$((n + 1))
      for a in "${VT_ARGS[@]}"; do [[ " $v " == *" $a "* ]] || return 1; done
    done <<<"$entries"
    ((n > 0))
  }
  TOTAL=$((TOTAL + 1))
  if ! vt_in_sync; then
    if ((CHECK)); then DRIFT+=("kernel command line: console palette (vt.default_*)")
    else
      R grubby --update-kernel=ALL --args="$(IFS=' '; echo "${VT_ARGS[*]}")"
      vt_in_sync || die "grubby did not record the console palette"
      CHANGED+=("kernel command line: console palette (next boot)")
    fi
  fi

  # ── 3c. boot menu (GRUB) and text-console font ───────────────────────────────
  # GRUB gets a pixel theme in the desktop's own language, at the monitor's native
  # resolution: plain sumi ink with a hem of seigaiha waves along the bottom edge, fading
  # upwards in an ordered dither (the grain of the desktop's transitions); the torii above
  # a quiet box of boot entries in Fusion Pixel (2×, 3× or 4× its pixel grid: 24, 36 or
  # 48 px), the chosen entry filled whole in vermilion — the desktop's one sign of what is
  # active — and a thin vermilion line counting down. Once an entry is chosen, nothing: the
  # box GRUB keeps for its own messages while it loads the system is drawn invisible (Fedora
  # prints none), so the screen stays plain until the boot splash takes over.
  # BOOT_MENU_SECONDS=0 hides the menu at every start (menu_auto_hide=2: even after a short or failed one), shown by holding
  # Shift or pressing Esc or F8 as the machine starts.
  # The text console (login, Ctrl+Alt+F2…F6) gets Terminus bold, larger from 1440p up.
  # Both take effect at the next boot.
  GRUB_THEME_DIR=/boot/grub2/themes/sumi
  native_mode() {   # the first connected monitor's preferred mode (listed first), or 1920x1080
    local s m
    for s in /sys/class/drm/card*-*/status; do
      [[ -r $s && $(<"$s") == connected ]] || continue
      m=$(head -n1 "${s%/status}/modes" 2>/dev/null)
      [[ $m =~ ^[0-9]+x[0-9]+$ ]] && { echo "$m"; return 0; }
    done
    echo 1920x1080
  }
  MODE=$(native_mode); MH=${MODE#*x}
  GS=$((MH / 720)); ((GS < 2)) && GS=2; ((GS > 4)) && GS=4   # pixel scale: 1080p/1440p ×2, 4K ×3, 5K ×4
  FS=$((12 * GS))                            # Fusion Pixel on a whole multiple of its 12 px grid
  GT=$(mktemp -d)
  # same pixels → same bytes on every run; PNG24/PNG32 below because GRUB reads only 8-bit
  # channels (ImageMagick would otherwise write tiny 1- or 2-bit palette files it rejects)
  PNG=(-strip -define "png:exclude-chunks=date,time")
  # the hem: five rows of the 48×24 wave tile in a quiet line colour, masked by a gradient
  # turned into an 8×8 ordered dither, enlarged ×GS and laid along the bottom
  HW=$(( ${MODE%x*} / GS + 1 )) HH=$((24 * 5))
  magick -size "$MODE" "xc:#$INK_GROUND" \
    \( -size "${HW}x$HH" "tile:$REPO_DIR/art/grub/pattern.xpm" \
       -colorspace gray -auto-level -colorspace sRGB +level-colors "#$INK_GROUND,#$INK_EDGE2" \
       \( -size "${HW}x$HH" gradient:black-white -ordered-dither o8x8 \) \
       -alpha off -compose CopyOpacity -composite -scale "$((GS * 100))%" \) \
    -gravity south -compose over -composite "${PNG[@]}" "PNG24:$GT/background.png"
  magick "$REPO_DIR/art/grub/torii.xpm" -scale "$((GS * 400))%" "${PNG[@]}" "PNG32:$GT/torii.png"
  for px in "menu_c:$INK_SURFACE" {menu_n,menu_s,menu_e,menu_w,menu_nw,menu_ne,menu_sw,menu_se}":$INK_EDGE" \
            "select_c:$INK_ACCENT"; do
    magick -size 1x1 "xc:#${px#*:}" "${PNG[@]}" "PNG24:$GT/${px%%:*}.png"
  done
  # the chosen entry's fill reaches 4·GS px past its words either side (GRUB draws a pixmap's
  # west and east parts outside the entry), as a menu's row does around its text
  for px in select_w select_e; do magick -size "$((4 * GS))x1" "xc:#$INK_ACCENT" "${PNG[@]}" "PNG24:$GT/$px.png"; done
  # the countdown, a thin trough under the menu (a 1 px edge round GS px of ground) that the
  # vermilion fills. GRUB 2.12 makes a progress bar at least 28 px tall, so it is drawn with
  # pixmaps as tall as its box (14·GS), clear but for the trough at their top
  PH=$((14 * GS))
  magick -size "1x$PH" xc:none -fill "#$INK_EDGE" -draw "point 0,0" -draw "point 0,$((GS + 1))" \
    -fill "#$INK_SURFACE" -draw "rectangle 0,1 0,$GS" "${PNG[@]}" "PNG32:$GT/bar_c.png"
  magick -size "1x$PH" xc:none -fill "#$INK_EDGE" -draw "rectangle 0,0 0,$((GS + 1))" "${PNG[@]}" "PNG32:$GT/bar_w.png"
  cp "$GT/bar_w.png" "$GT/bar_e.png"
  magick -size "1x$PH" xc:none -fill "#$INK_ACCENT" -draw "rectangle 0,1 0,$GS" "${PNG[@]}" "PNG32:$GT/hl_c.png"
  for px in term_c term_n term_s term_e term_w term_nw term_ne term_sw term_se; do   # the invisible box
    magick -size 1x1 xc:none "${PNG[@]}" "PNG32:$GT/$px.png"
  done
  # Fusion Pixel in GRUB's own bitmap format, made once with the same GRUB version as
  # Fedora's (grub-mkfont 2.12 --no-hinting -s N -n Fusion -r 0x20-0x7E,0xA0-0xFF,
  # 0x2010-0x2026, from fusion-pixel-12px-monospaced-ja.ttf); GRUB names it "Fusion Regular N"
  cp "$REPO_DIR/art/grub/fusion-$FS.pf2" "$GT/fusion.pf2"
  BW=$((440 * GS)) BH=$((84 * GS))           # the menu box: room for Fedora's entry names (70 letters;
                                             # setup keeps no rescue entry), five tall
  {
    printf '# /boot/grub2/themes/sumi/theme.txt — written by theme.sh for a %s screen;\n' "$MODE"
    printf '# re-run theme.sh after changing monitors.\n'
    printf 'desktop-image: "background.png"\ndesktop-color: "#%s"\ntitle-text: ""\n' "$INK_GROUND"
    printf 'terminal-font: "Fusion Regular %d"\nterminal-box: "term_*.png"\n\n' "$FS"
    printf '+ image {\n    left = 50%%-%d top = 50%%-%d\n    file = "torii.png"\n}\n' \
      $((22 * GS)) $((BH / 2 + 60 * GS))   # (44·GS square: 11 pixels × 4·GS; 16·GS above the box)
    printf '+ boot_menu {\n    left = 50%%-%d top = 50%%-%d width = %d height = %d\n' $((BW / 2)) $((BH / 2)) "$BW" "$BH"
    printf '    menu_pixmap_style = "menu_*.png"\n    selected_item_pixmap_style = "select_*.png"\n'
    printf '    item_font = "Fusion Regular %d"\n    selected_item_font = "Fusion Regular %d"\n' "$FS" "$FS"
    printf '    item_color = "#%s"\n    selected_item_color = "#%s"\n' "$INK_TEXT" "$INK_STRONG"   # (paper on the vermilion)
    printf '    item_height = %d item_padding = %d item_spacing = 0\n' $((16 * GS)) $((8 * GS))
    printf '    item_icon_space = 0 icon_width = 0 icon_height = 0\n    scrollbar = false\n}\n'
    printf '+ progress_bar {\n    id = "__timeout__"\n    left = 50%%-%d top = 50%%+%d width = %d height = %d\n' \
      $((BW / 2)) $((BH / 2 + 4 * GS - 1)) "$BW" "$PH"
    printf '    bar_style = "bar_*.png" highlight_style = "hl_*.png"\n}\n'
    printf '+ label {\n    left = 0 top = 50%%+%d width = 100%% align = "center"\n' $((BH / 2 + 18 * GS))   # (below the bar's box)
    printf '    font = "Fusion Regular %d" color = "#%s"\n' "$FS" "$INK_FAINT"
    printf '    text = "enter  boot     e  edit     c  console"\n}\n'
  } >"$GT/theme.txt"
  BOOT_CHANGED=0
  same() {   # same NEW INSTALLED — byte for byte; pictures pixel for pixel (an ImageMagick or
    local a b       # zlib update may encode the same picture differently): their pixel signatures
    R cmp -s "$1" "$2" && return 0
    [[ $1 == *.png ]] && R test -f "$2" || return 1
    a=$(R magick "$1" -format '%#' info: 2>/dev/null) b=$(R magick "$2" -format '%#' info: 2>/dev/null)
    [[ -n $a && $a == "$b" ]]
  }
  for f in "$GT"/*; do
    TOTAL=$((TOTAL + 1))
    same "$f" "$GRUB_THEME_DIR/${f##*/}" && continue
    if ((CHECK)); then DRIFT+=("$GRUB_THEME_DIR/${f##*/}"); continue; fi
    R install -D -m 0644 -o root -g root "$f" "$GRUB_THEME_DIR/${f##*/}"
    CHANGED+=("$GRUB_THEME_DIR/${f##*/}"); BOOT_CHANGED=1
  done
  # what an earlier theme put there and this one no longer makes goes (GRUB would still read
  # it: a select_n.png left over would draw over the chosen entry)
  while IFS= read -r f <&3; do
    [[ -e $GT/$f ]] && continue
    TOTAL=$((TOTAL + 1))
    if ((CHECK)); then DRIFT+=("$GRUB_THEME_DIR/$f: left over"); continue; fi
    R rm -f "$GRUB_THEME_DIR/$f"; CHANGED+=("$GRUB_THEME_DIR/$f removed"); BOOT_CHANGED=1
  done 3< <(R find "$GRUB_THEME_DIR" -maxdepth 1 -type f -printf '%f\n' 2>/dev/null)
  rm -rf "$GT"

  # the boot splash (Plymouth's script plugin, system/plymouth/sumi): after the menu, the same
  # ink and torii with "起動中 · starting Fedora", and the lock screen's box should a disk ask
  # for its password. It lives in the boot images, so a change remakes them (dracut, ~1 min) —
  # last of all, below: should dracut fail, the menu, the console and the rest are in place
  SPLASH_DIR=/usr/share/plymouth/themes/sumi SPLASH_CHANGED=0
  for f in "$REPO_DIR"/system/plymouth/sumi/*; do
    TOTAL=$((TOTAL + 1))
    same "$f" "$SPLASH_DIR/${f##*/}" && continue
    if ((CHECK)); then DRIFT+=("$SPLASH_DIR/${f##*/}"); continue; fi
    R install -D -m 0644 -o root -g root "$f" "$SPLASH_DIR/${f##*/}"
    CHANGED+=("$SPLASH_DIR/${f##*/}"); SPLASH_CHANGED=1
  done
  while IFS= read -r f <&3; do                      # (left overs go, as the menu's)
    [[ -e $REPO_DIR/system/plymouth/sumi/$f ]] && continue
    TOTAL=$((TOTAL + 1))
    if ((CHECK)); then DRIFT+=("$SPLASH_DIR/$f: left over"); continue; fi
    R rm -f "$SPLASH_DIR/$f"; CHANGED+=("$SPLASH_DIR/$f removed"); SPLASH_CHANGED=1
  done 3< <(R find "$SPLASH_DIR" -maxdepth 1 -type f -printf '%f\n' 2>/dev/null)
  TOTAL=$((TOTAL + 1))
  if [[ $(R plymouth-set-default-theme 2>/dev/null) != sumi ]]; then
    if ((CHECK)); then DRIFT+=("boot splash: not the sumi theme")
    else R plymouth-set-default-theme sumi; CHANGED+=("boot splash: the sumi theme"); SPLASH_CHANGED=1; fi
  fi
  # shown at once (ShowDelay=0, in plymouthd.conf beside the theme's line — the image carries
  # it): never a wait over a black screen first; the first frame itself is the boot argument
  # plymouth.use-simpledrm's (lib/common.sh, BOOT_ARGS)
  TOTAL=$((TOTAL + 1))
  if ! R grep -qx 'ShowDelay=0' /etc/plymouth/plymouthd.conf 2>/dev/null; then
    if ((CHECK)); then DRIFT+=("/etc/plymouth/plymouthd.conf: ShowDelay=0")
    else
      if R grep -q '^ShowDelay=' /etc/plymouth/plymouthd.conf 2>/dev/null; then R sed -i 's/^ShowDelay=.*/ShowDelay=0/' /etc/plymouth/plymouthd.conf
      elif R grep -qx '\[Daemon\]' /etc/plymouth/plymouthd.conf 2>/dev/null; then R sed -i '/^\[Daemon\]$/a ShowDelay=0' /etc/plymouth/plymouthd.conf
      else printf '[Daemon]\nShowDelay=0\n' | R tee -a /etc/plymouth/plymouthd.conf >/dev/null; fi   # (Fedora's own file: comments only)
      CHANGED+=("/etc/plymouth/plymouthd.conf: ShowDelay=0"); SPLASH_CHANGED=1
    fi
  fi
  # every kernel's boot image holds it (an image made before, or by a dracut that failed —
  # the installer's, a kernel update's — has Plymouth's text themes only: no splash). grep
  # reads lsinitrd's whole listing: `lsinitrd | grep -q` under pipefail failed whenever grep
  # stopped at its match (lsinitrd's SIGPIPE) — a splash that was there read as missing
  TOTAL=$((TOTAL + 1)) SPLASH_IMAGES=()
  for f in /boot/vmlinuz-*; do
    [[ -e $f && $f != */vmlinuz-0-rescue-* ]] || continue
    grep -q "usr/share/plymouth/themes/sumi/sumi.script" < <(R lsinitrd "/boot/initramfs-${f#/boot/vmlinuz-}.img" 2>/dev/null) \
      || SPLASH_IMAGES+=("/boot/initramfs-${f#/boot/vmlinuz-}.img")
  done
  if ((${#SPLASH_IMAGES[@]})); then
    if ((CHECK)); then DRIFT+=("boot images without the splash: ${SPLASH_IMAGES[*]}"); else SPLASH_CHANGED=1; fi
  fi

  # /etc/default/grub: the graphical menu with this theme, at the native mode
  grub_set() {   # grub_set KEY VALUE — one KEY=VALUE line, replaced or appended
    local cur
    TOTAL=$((TOTAL + 1))
    cur=$(R grep -m1 "^$1=" /etc/default/grub || true)
    [[ $cur == "$1=$2" ]] && return 0
    if ((CHECK)); then DRIFT+=("/etc/default/grub: $1=$2"); return 0; fi
    if [[ -n $cur ]]; then R sed -i "s|^$1=.*|$1=$2|" /etc/default/grub
    else printf '%s=%s\n' "$1" "$2" | R tee -a /etc/default/grub >/dev/null; fi
    CHANGED+=("/etc/default/grub: $1=$2"); BOOT_CHANGED=1
  }
  grub_set GRUB_THEME "\"$GRUB_THEME_DIR/theme.txt\""
  # gfxterm's own background, the theme's picture: once an entry is chosen GRUB leaves the menu
  # for its terminal, which it fills with black by default (the black box over the picture
  # while the system loads); with the same picture behind it, the screen does not change
  grub_set GRUB_BACKGROUND "\"$GRUB_THEME_DIR/background.png\""
  grub_set GRUB_TERMINAL_OUTPUT '"gfxterm"'
  grub_set GRUB_GFXMODE "\"$MODE,auto\""
  grub_set GRUB_TIMEOUT "$((BOOT_MENU_SECONDS > 0 ? BOOT_MENU_SECONDS : 5))"
  # Fedora hides the menu unless the last boot failed (menu_auto_hide in grubenv)
  TOTAL=$((TOTAL + 1))
  autohide=$(R grub2-editenv - list | grep -c '^menu_auto_hide=2' || true)
  if ((BOOT_MENU_SECONDS > 0 && autohide > 0)); then
    if ((CHECK)); then DRIFT+=("grubenv: menu_auto_hide is set (the menu stays hidden)")
    else R grub2-editenv - unset menu_auto_hide; CHANGED+=("boot menu: shown for $BOOT_MENU_SECONDS s"); fi
  elif ((BOOT_MENU_SECONDS == 0 && autohide == 0)) && ! R test -s /var/lib/fedokawaii/other-os; then   # (beside another system: shown)
    if ((CHECK)); then DRIFT+=("grubenv: menu_auto_hide is not set")
    else R grub2-editenv - set menu_auto_hide=2; CHANGED+=("boot menu: hidden (Fedora's default)"); fi
  fi
  TOTAL=$((TOTAL + 1))
  # (grub.cfg names the theme as GRUB reaches it: ($root)/grub2/themes/… when /boot is a
  # partition of its own — the installer's Btrfs layout — and /boot/grub2/themes/… otherwise)
  if ((BOOT_CHANGED)) || ! R grep -q "${GRUB_THEME_DIR#/boot/}/theme.txt" /boot/grub2/grub.cfg; then
    if ((CHECK)); then DRIFT+=("/boot/grub2/grub.cfg (not regenerated with the theme)")
    else
      R grub2-mkconfig -o /boot/grub2/grub.cfg >>"$LOG_FILE" 2>&1 || die "grub2-mkconfig failed — see $LOG_FILE"
      CHANGED+=("/boot/grub2/grub.cfg (boot menu theme; next boot)")
    fi
  fi

  # text console: Terminus bold at the size of Fedora's own console font — 8×16 (240 × 67 at
  # 1080p); from 2160p up, where 8×16 is too small to read, 16×32
  CFONT=ter-v16b; ((MH >= 2160)) && CFONT=ter-v32b
  TOTAL=$((TOTAL + 1))
  if ! grep -qx "FONT=\"$CFONT\"" /etc/vconsole.conf 2>/dev/null; then
    if ((CHECK)); then DRIFT+=("/etc/vconsole.conf: FONT=\"$CFONT\"")
    else
      [[ -f /usr/lib/kbd/consolefonts/$CFONT.psf.gz ]] || die "console font $CFONT missing — run Update (it installs what the manifest gained)"
      if grep -q '^FONT=' /etc/vconsole.conf 2>/dev/null; then R sed -i "s|^FONT=.*|FONT=\"$CFONT\"|" /etc/vconsole.conf
      else printf 'FONT="%s"\n' "$CFONT" | R tee -a /etc/vconsole.conf >/dev/null; fi
      CHANGED+=("/etc/vconsole.conf: console font $CFONT (next boot)")
    fi
  fi

  # the boot images with the splash, last (above: why): a failure is still this part's ✘
  if ((SPLASH_CHANGED)); then
    log "the boot images: made again with the splash (dracut, about a minute)"
    R dracut -f --regenerate-all >>"$LOG_FILE" 2>&1 || die "dracut could not remake the boot images with the splash (see $LOG_FILE) — the boot menu and the console are in place; repair tries again"
    CHANGED+=("boot images remade with the splash (next boot)")
  fi
}
BOOT_FAILED=0
# a theme run that could not make the boot menu or console marks what it failed on (root's,
# beside dwl's mark): --check counts that part as optional until one of these changes
BOOT_MARK=/var/lib/fedokawaii/boot.failed
boot_sum() {
  { cat "$REPO_DIR/theme.sh" "$REPO_DIR"/art/grub/* "$REPO_DIR"/system/plymouth/sumi/* "$REPO_DIR/configs/home/.config/fedokawaii/themes/dark/colors.sh"
    printf '%s\n' "$BOOT_MENU_SECONDS"; } 2>/dev/null | sha256sum | cut -d' ' -f1
}
run_boot() {   # boot_and_console in a subshell with errexit on; what it changed or found comes back
  local out saved rc t
  out=$(mktemp); saved=$(trap -p ERR)
  trap - ERR; set +e
  # shellcheck disable=SC2154  # rc is assigned inside the trap string
  # shellcheck disable=SC2034  # lvl is read inside the trap string
  ( set -e; lvl=$BASH_SUBSHELL
    trap 'rc=$?; ((BASH_SUBSHELL == lvl)) || exit $rc; failed_what "${FUNCNAME[0]:-main}:$LINENO"; _out "${C_RED}✘ boot menu / console: line $LINENO${FUNCNAME[0]:+ in ${FUNCNAME[0]}()}: ${FAILED_SHOW:0:160} (exit $rc)${C_RESET}" >&2; exit $rc' ERR
    n=${#CHANGED[@]} d=${#DRIFT[@]}
    trap 'rm -rf "${GT:-}"; { echo "T$TOTAL"; for x in "${CHANGED[@]:n}"; do echo "C$x"; done; for x in "${DRIFT[@]:d}"; do echo "D$x"; done; } >"$out"' EXIT
    boot_and_console )
  rc=$?
  set -e; eval "$saved"
  while IFS= read -r t; do
    case $t in T*) TOTAL=${t#T} ;; C*) CHANGED+=("${t#C}") ;; D*) DRIFT+=("${t#D}") ;; esac
  done <"$out"
  rm -f "$out"
  if ((rc)); then
    BOOT_FAILED=1
    log "the boot menu and console were not themed (why: above, or $LOG_FILE) — the rest of the theme is in place"
  fi
  return 0
}

# ── 4. dwl keybindings + colours ─────────────────────────────────────────────
SRC=$TARGET_HOME/.local/src/dwl
if ((DWL_MINE)); then
  [[ -d $SRC ]] || die "dwl source missing at $SRC — run setup.sh first"
  place "$REPO_DIR/src/dwl/config.h" "$SRC/config.h" user
fi
# the source must be the pinned commit, whole (setup and update put it there: never three of
# its files moved by hand, which would build a mix of two versions) …
if ((DWL_MINE)) && [[ $(U git -C "$SRC" rev-parse HEAD 2>/dev/null) != "$DWL_COMMIT" ]]; then
  if ((CHECK)); then DRIFT+=("$SRC (not at DWL_COMMIT $DWL_COMMIT)")
  else die "dwl's source in $SRC is not at DWL_COMMIT ($DWL_TAG) — fedokawaii repair fetches it"; fi
fi
# … and carry the current src/dwl/dwl.patch: a newer repo may extend it (setup applied the
# version it had). Restore dwl's own files and apply this one.
TOTAL=$((TOTAL + 1))
if ((DWL_MINE)) && ! U git -C "$SRC" apply --reverse --check - <"$REPO_DIR/src/dwl/dwl.patch" >/dev/null 2>&1; then
  if ((CHECK)); then DRIFT+=("$SRC (src/dwl/dwl.patch not applied as it is now)")
  else
    U git -C "$SRC" checkout --quiet "$DWL_COMMIT" -- dwl.c client.h config.def.h
    U git -C "$SRC" apply - <"$REPO_DIR/src/dwl/dwl.patch" || die "src/dwl/dwl.patch does not apply to $DWL_COMMIT"
    CHANGED+=("$SRC: src/dwl/dwl.patch re-applied")
  fi
fi
# what /usr/local/bin/dwl was built from (repo config.h + patch, the pinned commit, the make
# options): stamped after a successful install, so a build that failed half-way, or one
# from older sources, is redone on the next run however the file times look
DWL_MARK=/var/lib/fedokawaii/dwl.sha256              # (root's: nothing of yours decides a rebuild)
DWL_SUM=$({ cat "$REPO_DIR/src/dwl/config.h" "$REPO_DIR/src/dwl/dwl.patch"; printf '%s\n' "$DWL_COMMIT" "${DWL_MAKE[@]}" "$(wlr_home)"; } | sha256sum)
DWL_SUM=${DWL_SUM%% *}
dwl_current() { [[ -x /usr/local/bin/dwl && $(cat "$DWL_MARK" 2>/dev/null) == "$DWL_SUM" ]]; }
TOTAL=$((TOTAL + 1))

# ── 4a. Brave: sound with a shared screen ────────────────────────────────────
# Sharing a screen or a window in a call can carry the computer's sound too — Chromium's
# PulseAudio loopback for screen sharing, off by default and no longer a brave://flags
# switch (Brave clears it from its Local State), so ~/.local/bin/brave-origin starts Brave
# with it. Super+B and a shell find that first in PATH; links that start Brave go through
# its launcher entry, so Brave's own entry is copied to ~/.local/share/applications with
# its Exec lines pointing there — made again whenever Brave's own entry changes.
# The package also ships com.brave.Origin.desktop, the name the portals look Brave up by. Its
# NoDisplay=true sits in the wrong section (brave/brave-browser#52193), so the launcher would
# list Brave twice, once without the screen-share sound: its copy here is hidden as meant.
for BRAVE_ENTRY in brave-origin.desktop:show com.brave.Origin.desktop:hide; do
  BRAVE_SYS_DESKTOP=/usr/share/applications/${BRAVE_ENTRY%:*}
  BRAVE_USR_DESKTOP=$TARGET_HOME/.local/share/applications/${BRAVE_ENTRY%:*}
  [[ -r $BRAVE_SYS_DESKTOP ]] || continue
  TOTAL=$((TOTAL + 1))
  BT=$(mktemp)
  sed -E "s#^Exec=/usr/bin/brave-origin-stable( |\$)#Exec=$TARGET_HOME/.local/bin/brave-origin\1#" \
    "$BRAVE_SYS_DESKTOP" \
    | awk -v hide="$([[ ${BRAVE_ENTRY#*:} == hide ]] && echo 1)" \
        'hide && /^NoDisplay=/ { next } { print } hide && $0 == "[Desktop Entry]" { print "NoDisplay=true" }' >"$BT"
  if cmp -s "$BT" "$BRAVE_USR_DESKTOP"; then :
  elif ((CHECK)); then DRIFT+=("$BRAVE_USR_DESKTOP (Brave's launcher entry: screen-share sound)")
  else
    uinstall 0644 "$BT" "$BRAVE_USR_DESKTOP"
    CHANGED+=("$BRAVE_USR_DESKTOP (Brave starts with screen-share sound)")
  fi
  rm -f "$BT"
done

# ── 4c. Brave: the desktop's colours ─────────────────────────────────────────
# Brave's GTK theme mode paints its tab strip, toolbar, menus and dialogs from
# the GTK 3 theme kawa-theme switches (Fedokawaii / Fedokawaii-dark, which carry a few rules
# for Brave alone) and follows every switch live; web pages follow the portal's dark/light.
# The new-tab page gets the ground colour as CSS light-dark(), so it switches by itself.
# Both are settings of each profile (its Preferences, rewritten by Brave while it runs):
# set only while Brave is closed, and before its first start too — once per profile (and
# again only if the desktop's colours change): what you choose in Brave afterwards stays.
BRAVE_DIR="$TARGET_HOME/.config/BraveSoftware/Brave-Origin"
# shellcheck source=/dev/null
ground() { ( . "$REPO_DIR/configs/home/.config/fedokawaii/themes/$1/colors.sh" && printf '%s' "$C_GROUND" ); }
BRAVE_NTP="light-dark(#$(ground light), #$(ground dark))"
# The new tab is kept to its search box: Brave draws its widgets (the stats card above
# all) for dark pictures, and on paper they would be grey on grey.
BRAVE_SET='(if (.extensions.theme.id // "") == "" then .extensions.theme.system_theme = 1 else . end)
  | .brave.new_tab_page.background = {type: "color", random: false, selected_value: $ntp}
  | .brave.new_tab_page.show_stats = false | .brave.new_tab_page.hide_all_widgets = true'
# (a theme you install from the Web Store replaces GTK mode — Brave then drops it: left be)
BRAVE_OK='((.extensions.theme.id // "") != "" or .extensions.theme.system_theme == 1)
  and .brave.new_tab_page.background.type == "color" and .brave.new_tab_page.background.selected_value == $ntp
  and .brave.new_tab_page.hide_all_widgets == true'
BRAVE_MARK="$BRAVE_NTP · widgets off"         # what the marker below records (a new one: set again)
BRAVE_PREFS=()
for BP in "$BRAVE_DIR"/Default/Preferences "$BRAVE_DIR"/Profile\ */Preferences; do
  [[ -f $BP ]] && BRAVE_PREFS+=("$BP")
done
((${#BRAVE_PREFS[@]})) || BRAVE_PREFS=("$BRAVE_DIR/Default/Preferences")   # before the first start
for BP in "${BRAVE_PREFS[@]}"; do
  TOTAL=$((TOTAL + 1))
  BM="$STATE/brave-$(printf '%s' "$BP" | sha1sum | cut -c1-12)"     # set once: the colours it got
  if [[ -s $BP ]] && jq -e --arg ntp "$BRAVE_NTP" "$BRAVE_OK" "$BP" >/dev/null 2>&1; then
    ((CHECK)) || [[ $(cat "$BM" 2>/dev/null) == "$BRAVE_MARK" ]] || { printf '%s\n' "$BRAVE_MARK" | U tee "$BM" >/dev/null; }
    continue
  fi
  [[ $(cat "$BM" 2>/dev/null) == "$BRAVE_MARK" ]] && continue          # changed in Brave since: yours
  if ((CHECK)); then DRIFT+=("$BP (Brave not in the desktop's colours)")
  elif pgrep -u "$TARGET_UID" -f '/brave-origin/brave( |$)' >/dev/null; then
    log "Brave is open: its colours are set by the next Theme run (or Settings → Appearance → Theme → GTK)"
  else
    BT=$(mktemp)
    if [[ -s $BP ]]; then
      if ! jq --arg ntp "$BRAVE_NTP" "$BRAVE_SET" "$BP" >"$BT" 2>/dev/null; then
        log "Brave's Preferences does not read as JSON — left alone ($BP)"; rm -f "$BT"; continue
      fi
    else
      jq -n --arg ntp "$BRAVE_NTP" "$BRAVE_SET" >"$BT"
    fi
    uinstall 0600 "$BT" "$BP"; rm -f "$BT"
    printf '%s\n' "$BRAVE_MARK" | U tee "$BM" >/dev/null
    CHANGED+=("$BP (Brave: the desktop's colours, a ground-coloured new tab)")
  fi
done
# Widevine, Brave's player for protected media — Spotify's web player (the launcher's Spotify)
# plays nothing without it: switched on once, as brave://settings switches it (its Local
# State: brave.widevine_opted_in), while Brave is closed and before its first start too.
# Switched off in Brave afterwards, it stays off (the marker says it was set once).
BRAVE_LS="$BRAVE_DIR/Local State" BWM=$STATE/brave-widevine
TOTAL=$((TOTAL + 1))
if [[ -s $BRAVE_LS ]] && jq -e '.brave.widevine_opted_in == true' "$BRAVE_LS" >/dev/null 2>&1; then
  ((CHECK)) || [[ -e $BWM ]] || U touch "$BWM"
elif [[ -e $BWM ]]; then :                                            # switched off in Brave since: yours
# (Brave open: its starter, ~/.local/bin/brave-origin, switches it on before Brave's next start
# — Brave writes Local State again as it closes, so nothing may write it now; no drift either)
elif pgrep -u "$TARGET_UID" -f '/brave-origin/brave( |$)' >/dev/null; then
  ((CHECK)) || log "Brave is open: Widevine goes on at its next start (its starter switches it on) — close Brave and start it again"
elif ((CHECK)); then DRIFT+=("$BRAVE_LS (Widevine off: Spotify's web player cannot play)")
else
  BT=$(mktemp)
  if [[ ! -s $BRAVE_LS ]]; then jq -n '.brave.widevine_opted_in = true' >"$BT"
  elif ! jq '.brave.widevine_opted_in = true' "$BRAVE_LS" >"$BT" 2>/dev/null; then
    log "Brave's Local State does not read as JSON — Widevine left as it is ($BRAVE_LS)"; : >"$BT"
  fi
  if [[ -s $BT ]]; then
    uinstall 0600 "$BT" "$BRAVE_LS"; U touch "$BWM"
    CHANGED+=("$BRAVE_LS (Brave: Widevine on, for Spotify's web player)")
  fi
  rm -f "$BT"
fi

# ── 4d. Syncplay: watching together ──────────────────────────────────────────
# ~/.config/syncplay.ini is Syncplay's own: it writes the whole file again whenever you change
# something (a room given with -r, its window's settings). So only what is missing or empty
# is filled in here: Syncplay's public server (syncplay.pl, port 8999, its default), your
# login name, a room of your own (name-xxxx: tell it to your friends, or agree on another),
# mpv as the player, ~/Videos and ~/Downloads to find the room's file in by its name, and no
# update checks (dnf brings new versions), and its words on the film (chat, "connected to…")
# in mpv's own on-screen font — Syncplay's default, sans-serif, counts as unset, so they never
# change font a second after the film opens (mpv's script-opts/syncplayintf.conf sets the same
# for the moment before Syncplay has told mpv). Every other value already there stays as it is.
SYNCPLAY_INI=$TARGET_HOME/.config/syncplay.ini
TOTAL=$((TOTAL + 1))
if [[ -L $SYNCPLAY_INI ]]; then
  log "$SYNCPLAY_INI is a link — Syncplay's settings left as they are"
elif SP=$(U python3 -I - "$SYNCPLAY_INI" "$TARGET_USER" "$TARGET_HOME" "$CHECK" <<'PY'
import configparser, os, secrets, sys
path, user, home, check = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4] == "1"
want = {("server_data", "host"): "syncplay.pl", ("server_data", "port"): "8999",
        ("client_settings", "name"): user, ("client_settings", "room"): f"{user}-{secrets.token_hex(2)}",
        ("client_settings", "playerpath"): "/usr/bin/mpv",
        ("client_settings", "mediasearchdirectories"): repr([home + "/Videos", home + "/Downloads"]),
        ("general", "checkforupdatesautomatically"): "False",
        ("gui", "chatinputfontfamily"): "JetBrainsMono Nerd Font", ("gui", "chatoutputfontfamily"): "JetBrainsMono Nerd Font"}
cfg = configparser.RawConfigParser(strict=False)        # (as Syncplay reads it: a doubled %% stays)
try:
    with open(path, encoding="utf-8-sig") as f:
        cfg.read_file(f)
except FileNotFoundError:
    pass
except (configparser.Error, UnicodeError):
    sys.exit(4)
unset = ("", "None", "{}", "[]")
gaps = [k for k in want if cfg.get(*k, fallback="").strip() in unset + (("sans-serif",) if k[0] == "gui" else ())]
print(", ".join(k[1] for k in gaps))
if check or not gaps:
    sys.exit(3 if gaps else 0)
for sec, key in gaps:
    if not cfg.has_section(sec):
        cfg.add_section(sec)
    cfg.set(sec, key, want[sec, key].replace("%", "%%"))
tmp = path + ".kawa"
with open(os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600), "w", encoding="utf-8") as f:
    cfg.write(f)                                         # (600: a server password may join it)
if os.path.exists(path):
    os.chmod(tmp, os.stat(path).st_mode & 0o777)
os.replace(tmp, path)
PY
); then
  [[ -n $SP ]] && CHANGED+=("$SYNCPLAY_INI (Syncplay: $SP)")
else
  case $? in
    3) DRIFT+=("$SYNCPLAY_INI (Syncplay: $SP not set)") ;;
    *) log "$SYNCPLAY_INI does not read as Syncplay's settings — left as it is" ;;
  esac
fi

# ── 4e. Xournal++ (Sketch): the pen's two buttons ────────────────────────────
# A tablet's pen has two buttons on its side (the XP-Pen Star G430S's P01: the lower one is
# "button 1", the upper "button 2"). Xournal++ leaves both doing nothing until told, in its
# own settings.xml — which it writes whole again at every change. So once, a button still at
# Xournal++'s own "nothing" is given its tool here: the lower one erases while held, the
# upper one holds the page to drag it (the hand). After that (state: xournalpp-pen) the
# buttons are yours: a tool you choose — "nothing" too — stays as it is.
XPP_XML=$TARGET_HOME/.config/xournalpp/settings.xml
XPP_DONE=$TARGET_HOME/.local/state/fedokawaii/xournalpp-pen
TOTAL=$((TOTAL + 1))
if [[ -e $XPP_DONE ]]; then :
elif [[ -L $XPP_XML ]]; then
  log "$XPP_XML is a link — Xournal++'s settings left as they are"
elif XP=$(U python3 -I - "$XPP_XML" "$CHECK" <<'PY'
import os, sys, xml.etree.ElementTree as ET
path, check = sys.argv[1], sys.argv[2] == "1"
want = {"stylus": "eraser", "stylus2": "hand"}          # (Xournal++'s names: button 1, button 2)
try:
    tree = ET.parse(path); root = tree.getroot()
except FileNotFoundError:
    root = ET.Element("settings"); tree = ET.ElementTree(root)
except ET.ParseError:
    sys.exit(4)
if root.tag != "settings":
    sys.exit(4)
bc = root.find("data[@name='buttonConfig']")
if bc is None:
    bc = ET.SubElement(root, "data", name="buttonConfig")
gaps = []
for button, tool in want.items():
    d = bc.find(f"data[@name='{button}']")
    if d is None:
        d = ET.SubElement(bc, "data", name=button)
    a = d.find("attribute[@name='tool']")
    if a is not None and a.get("value", "none") != "none":
        continue                                         # (yours: chosen in its preferences)
    gaps.append(button)
    if a is None:
        a = ET.SubElement(d, "attribute", name="tool", type="string")
    a.set("type", "string"); a.set("value", tool)
print(", ".join(f"{b} → {want[b]}" for b in gaps))
if check or not gaps:
    sys.exit(3 if gaps else 0)
os.makedirs(os.path.dirname(path), exist_ok=True)
tmp = path + ".kawa"
tree.write(tmp, encoding="UTF-8", xml_declaration=True)
os.replace(tmp, path)
PY
); then
  [[ -n $XP ]] && CHANGED+=("$XPP_XML (the pen's buttons: $XP)")
  ((CHECK)) || U bash -c 'mkdir -p "${1%/*}" && : >"$1"' _ "$XPP_DONE"
else
  case $? in
    3) DRIFT+=("$XPP_XML (the pen's buttons: $XP not set)") ;;
    *) log "$XPP_XML does not read as Xournal++'s settings — left as it is" ;;
  esac
fi

# ── 4b. the desktop's own C helpers (src/, built with the tools that build dwl) ──
#   kawa-clipkeep  keeps a copy on the clipboard after the app it came from is closed
#   kawa-saver     the screensaver (and the lock behind it: away 15 minutes, kawa-idle)
#   kawa-lockmod   the lock screen's keys and wake guard (a gtklock module, GTK 3's headers)
# Built as you whenever their sources change; the hash of what each was built from is
# kept beside the state, so a re-run knows without rebuilding. Parts of the desktop like
# dwl: one that does not build stops the theme run.
TOOLS=(kawa-clipkeep kawa-saver kawa-lockmod)
tool_dest() { case $1 in kawa-lockmod) echo "$TARGET_HOME/.local/lib/fedokawaii/kawa-lockmod.so" ;; *) echo "$TARGET_HOME/.local/bin/$1" ;; esac; }
tool_sum() { local s x f=() d=$REPO_DIR/src/$1
  for x in "$d/Makefile" "$d"/*.c "$d"/*.h "$d"/*.xml; do [[ -f $x ]] && f+=("$x"); done
  s=$(cat "${f[@]}" | sha256sum); printf '%s' "${s%% *}"; }
tool_current() { [[ -f $(tool_dest "$1") && $(cat "$STATE/$1.sha256" 2>/dev/null) == "$(tool_sum "$1")" ]]; }
TOTAL=$((TOTAL + ${#TOOLS[@]}))

if ((CHECK)); then
  # the boot menu and console, the part the theme run carries on without (it says so): one it
  # could not make is a warning, not drift — else verify's final check would stop setup on it
  # for good. (Only while what it failed on is unchanged: changed, the theme run tries again.)
  OPTIONAL=() d0=${#DRIFT[@]}
  run_boot
  if ((BOOT_FAILED)); then OPTIONAL+=("boot menu / console: could not be compared (theme.sh --check says why)")
  elif ((${#DRIFT[@]} > d0)) && [[ $(cat "$BOOT_MARK" 2>/dev/null) == "$(boot_sum)" ]]; then
    for x in "${DRIFT[@]:d0}"; do OPTIONAL+=("$x — the theme run could not make it (its log says why)"); done
    DRIFT=("${DRIFT[@]:0:d0}")
  fi
  for t in "${TOOLS[@]}"; do
    tool_current "$t" || DRIFT+=("$(tool_dest "$t") (not built from src/$t)")
  done
  [[ $(U /usr/local/bin/dwl -v 2>&1) == *"${DWL_TAG#v}"* ]] || DRIFT+=("/usr/local/bin/dwl (not $DWL_TAG)")
  ((DWL_MINE == 0)) || dwl_current || DRIFT+=("/usr/local/bin/dwl (not built from src/dwl as it is now)")
  # (the wallpaper pack depends on the network: verify.sh reports it as a warning instead)
  if ((${#DRIFT[@]})); then
    printf '%s✘ %d of %d files differ from the repo:%s\n' "$C_RED" "${#DRIFT[@]}" "$TOTAL" "$C_RESET"
    printf '  %s\n' "${DRIFT[@]}"
  else
    printf '%s✔ theme in sync — %d files match the repo%s\n' "$C_OK" "$TOTAL" "$C_RESET"
  fi
  if ((${#OPTIONAL[@]})); then
    printf '%s! %snot made here (repair, or the next theme run, tries again):%s\n' "$C_GOLD" "${DRIFT[*]:+and }" "$C_RESET"
    printf '  %s\n' "${OPTIONAL[@]}"
  fi
  ((${#DRIFT[@]} == 0)) || exit 3            # (3: it ran, and things differ — 1 is an error)
  ((${#OPTIONAL[@]} == 0)) || exit 4         # (4: in sync but for the boot menu and console)
  exit 0
fi

hdr "Fedokawaii theme → $TARGET_USER"
if ((DWL_MINE)) && ! dwl_current; then
  # against dwl's own copy of wlroots (lib/common.sh), made now if setup predates it
  wlr_kept || R bash -c '. "$1/lib/common.sh"; DWL_WLROOTS=$2; wlr_keep' _ "$REPO_DIR" "$DWL_WLROOTS" \
    || die "dwl cannot be built: no copy of wlroots $DWL_WLROOTS, and this Fedora no longer ships it — the dwl you have stays"
  mapfile -t DWL_ARGS < <(dwl_make_args)
  # built by you, from clean (make does not notice a changed WLR_LIBS), and only the one
  # file taken in by root (take_built): root runs nothing in your folders
  U make -C "$SRC" clean >>"$LOG_FILE" 2>&1
  U make -C "$SRC" -j"$(nproc)" "${DWL_ARGS[@]}" >>"$LOG_FILE" 2>&1 || die "dwl failed to build with src/dwl/config.h — see $LOG_FILE"
  # (as root: run as yourself, theme.sh gets there through sudo — R)
  R env TARGET_USER="$TARGET_USER" TARGET_HOME="$TARGET_HOME" TARGET_UID="$TARGET_UID" \
    bash -c '. "$1/lib/common.sh"; take_built "$2" /usr/local/bin/dwl 0755' _ "$REPO_DIR" "$SRC/dwl" \
    || die "dwl failed to install — see $LOG_FILE"
  printf '%s\n' "$DWL_SUM" | R bash -c '. "$1/lib/common.sh"; write_file "$2" 0644' _ "$REPO_DIR" "$DWL_MARK"
  CHANGED+=("/usr/local/bin/dwl (rebuilt)")
  ok "dwl rebuilt with src/dwl/config.h (takes effect at next login)"
fi
for t in "${TOOLS[@]}"; do
  tool_current "$t" && continue
  VB=$(U mktemp -d)
  tar -C "$REPO_DIR/src/$t" -cf - . | U tar -C "$VB" -xf - --no-same-owner   # (unpacked by you)
  # (what root hands on goes through a pipe, never through a file in your folder)
  U make -s -C "$VB" O="$VB" >>"$LOG_FILE" 2>&1 || { U rm -rf "$VB"; die "$t failed to build from src/$t — see $LOG_FILE"; }
  U cat -- "$VB/$t" | uinstall 0755 /dev/stdin "$(tool_dest "$t")"
  tool_sum "$t" | uinstall 0644 /dev/stdin "$STATE/$t.sha256"
  CHANGED+=("$(tool_dest "$t") (built)")
  U rm -rf "$VB"
done

# ── 5. derived state ─────────────────────────────────────────────────────────
if changed /etc/dconf/; then R dconf update; ok "dconf defaults compiled"; fi
if changed /fontconfig/ || changed /.local/share/fonts/; then U fc-cache -f; fi   # new rules or the icon font
# the colourscheme plugin is fetched the first time its spec appears — install only: the
# plugins you have stay at their versions (they move with update, which keeps the old ones)
if changed /nvim/lua/plugins/ && [[ -f $TARGET_HOME/.config/nvim/init.lua ]]; then
  U timeout 900 nvim --headless '+Lazy! install' +qa >>"$LOG_FILE" 2>&1 && ok "neovim plugins installed (colourscheme)"
fi
# API keys live only here, read into the environment by the shell: yours alone (600)
SECRETS=$TARGET_HOME/.config/fedokawaii/secrets.sh
if [[ ! -f $SECRETS ]]; then uinstall 0600 /dev/null "$SECRETS"
elif [[ $(stat -c %a "$SECRETS") != 600 ]]; then
  U chmod 600 "$SECRETS"; CHANGED+=("$SECRETS (made private again: chmod 600)")
fi
# the terminal's see-through ground (foot.ini's last include): made once, on — then the
# setting is yours (Super+U → transparency, kawa-glass), never written here again
GLASS=$STATE/foot-glass.ini
[[ -f $GLASS ]] || uinstall 0644 <(printf '%s\n' "# ~/.local/state/fedokawaii/foot-glass.ini — the terminal's see-through ground (kawa-glass;" \
  "# Super+U → transparency). 1 is opaque. Read by foot.ini's last include." \
  "[colors-dark]" "alpha=0.92" "[colors-light]" "alpha=0.92") "$GLASS"
# (~/repos: where your projects go — and where Agents, herdr, opens: its launcher entry
# starts there, and a window cannot start in a folder that is not)
U mkdir -p "$TARGET_HOME/Pictures/Wallpapers" "$TARGET_HOME/Pictures/Screenshots" "$TARGET_HOME/.local/share/fedokawaii" \
  "$TARGET_HOME/repos"
# the drawn wallpaper and the old lock's picture, from before (the wallpapers are the pack's
# and your own, at full quality; the lock draws its own): their files go
U rm -f "$TARGET_HOME"/.local/share/fedokawaii/{dark,light}/{pattern,scene,lock}.{xpm,png}
# the wallpaper cache from before (~/.cache/kawa-wallpaper: now ~/.cache/fedokawaii's
# wallpaper-screens and wallpaper-previews)
U rm -rf "$TARGET_HOME/.cache/kawa-wallpaper"
# the wallpaper pack: fetched once (pictures already here are skipped), then drawn ahead for
# the monitor — each picture at the screen's exact size, and as the picker's preview — all
# cores at once, its progress in the log as it goes: the first login has nothing left to draw
if [[ $WALLPAPER_PACK == yes ]]; then
  if wp=$(U kawa-wallpaper --pack 2>&1 | tee -a "$LOG_FILE"; exit "${PIPESTATUS[0]}"); then
    ok "wallpaper pack ready ($(grep '^wallpaper pack:' <<<"$wp"))"
  else log "wallpaper pack: some pictures could not be fetched or drawn — re-run theme.sh later (details: $LOG_FILE)"; fi
  if wp=$(grep -E '^wallpaper cache: ([0-9]+ pictures drawn|no monitor)' <<<"$wp"); then log "$wp"; fi
fi
# GTK, libadwaita and the portal take the theme from your dconf settings, not a file
U kawa-theme settings || log "GTK settings follow the theme at your next login (no user D-Bus now)"
# the prompt, aliases and torrra come from ~/.bashrc.d, which Fedora's ~/.bashrc reads; one
# that does not (replaced by hand, or by a dotfiles tool) gets Fedora's few lines added
if ! grep -qs 'bashrc.d' "$TARGET_HOME/.bashrc"; then
  U tee -a "$TARGET_HOME/.bashrc" >/dev/null <<'RC' || die "could not add ~/.bashrc.d to ~/.bashrc"

# ~/.bashrc.d — added by Fedokawaii's theme.sh (the lines of Fedora's /etc/skel/.bashrc)
if [ -d ~/.bashrc.d ]; then
    for rc in ~/.bashrc.d/*; do
        if [ -f "$rc" ]; then
            . "$rc"
        fi
    done
fi
unset rc
RC
  # shellcheck disable=SC2088  # literal ~ in a message
  log "~/.bashrc did not read ~/.bashrc.d — Fedora's lines for that are added at its end"
fi

# ── 6. live session: reload what can reload ─────────────────────────────────
if pgrep -u "$TARGET_UID" -x dwl >/dev/null; then
  RT=/run/user/$TARGET_UID
  # (a glob, not find: root cannot read the document portal's FUSE mount in $RT, and find's
  # "Permission denied" on it ended the whole theme run there, before the boot part)
  WD=""; for s in "$RT"/wayland-*; do [[ -S $s ]] || continue; WD=${s##*/}; break; done
  live() { U env WAYLAND_DISPLAY="$WD" "$@" >/dev/null 2>&1 || true; }
  live kawa-display
  live kawa-theme apply                    # terminals, bar, notifications, GTK, Qt, wallpaper
  log "reloaded the theme in the running session (new fonts, foot settings and dwl apply at next login)"
fi
run_boot                                   # 3b + 3c, contained (see above): they apply at the next boot
if ((BOOT_FAILED)); then
  boot_sum | R bash -c '. "$1/lib/common.sh"; write_file "$2" 0644' _ "$REPO_DIR" "$BOOT_MARK" || true
elif [[ -e $BOOT_MARK ]]; then R rm -f -- "$BOOT_MARK"; fi

if ((${#CHANGED[@]})); then
  ok "${#CHANGED[@]} of $TOTAL files updated:"; printf '    %s\n' "${CHANGED[@]/#$TARGET_HOME/\~}" | tee -a "$LOG_FILE"
  [[ -d $BACKUP ]] && log "previous versions: ${BACKUP/#$TARGET_HOME/\~}"
else
  ok "all $TOTAL files already in sync"
fi
# the backups: the newest ten runs kept (each folder holds only what that run replaced)
prune_theme_backups U >/dev/null
T=$(mktemp); date '+%F %T' >"$T"; uinstall 0644 "$T" "$STATE/theme-applied"; rm -f "$T"
