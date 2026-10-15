#!/usr/bin/env bash
# ═════════════════════════════════════════════════════════════════════════════
#  fedokawai.sh — the one entry point.
#
#    sudo bash fedokawai.sh              menu (for the install; once it is done, the system's
#                                        own control is `fedokawai` — Super+U)
#    sudo bash fedokawai.sh ACTION       run one action directly:
#
#      check    is this machine ready? (read-only)
#      setup    install the software only — no configs, no colours, no keybindings
#      theme    apply configs, colours and keybindings only (needs setup first)
#      all      setup, with the theme applied automatically near the end
#      verify   prove the system matches the manifest (read-only)
#      update   the season's update (snapshot first; packages, the desktop's tools, checks)
#      upgrade  move to the next Fedora release once it has settled (upgrade --now: now)
#      repair   find what broke and fix it
#      drift    list config files that differ from the repo (read-only)
#      status   show setup progress
# ═════════════════════════════════════════════════════════════════════════════
set -Eeuo pipefail
IFS=$'\n\t'
REPO_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
STATE_DIR=/var/lib/fedokawai
LOG_FILE=/var/log/fedokawai.log
[[ $EUID -eq 0 ]] || { echo "run with sudo: sudo bash fedokawai.sh" >&2; exit 2; }
touch "$LOG_FILE"
source "$REPO_DIR/lib/common.sh"

# the desktop user: the one setup recorded; before that, USERNAME from fedokawai.conf,
# or whoever ran sudo
conf_user=$(sed -n 's/^USERNAME=["'"'"']\{0,1\}\([a-z_][a-z0-9_-]*\).*/\1/p' "$REPO_DIR/fedokawai.conf" 2>/dev/null | tail -n1)
user=$(cat "$STATE_DIR/user" 2>/dev/null || echo "${conf_user:-${SUDO_USER:-}}")
[[ $user == root ]] && user=""

state_line() {
  local p t
  p=$(cat "$STATE_DIR/phase" 2>/dev/null || echo "not started")
  case $p in 'done') p="complete" ;; "not started") ;; *) p="phase $p of 3" ;; esac
  t="not applied"
  [[ -n $user && -f $(getent passwd "$user" | cut -d: -f6)/.local/state/fedokawai/theme-applied ]] && t="applied"
  printf '%s' "setup: $p · theme: $t"
}

act() {
  case $1 in
    check)  bash "$REPO_DIR/check.sh" ;;
    setup)  rm -f "$STATE_DIR/with-theme"; bash "$REPO_DIR/setup.sh" ;;
    all)    mkdir -p "$STATE_DIR"; touch "$STATE_DIR/with-theme"; bash "$REPO_DIR/setup.sh" ;;
    theme)  [[ -n $user ]] || die "unknown desktop user — run setup first"
            bash "$REPO_DIR/theme.sh" --user "$user" ;;
    drift)  [[ -n $user ]] || die "unknown desktop user — run setup first"
            bash "$REPO_DIR/theme.sh" --user "$user" --check ;;
    verify) bash "$REPO_DIR/verify.sh" ;;
    update) bash "$REPO_DIR/setup.sh" --update ;;
    upgrade) if [[ ${2:-} == --now ]]; then bash "$REPO_DIR/setup.sh" --upgrade --now
             else bash "$REPO_DIR/setup.sh" --upgrade; fi ;;
    repair) bash "$REPO_DIR/setup.sh" --repair ;;
    status) bash "$REPO_DIR/setup.sh" --status ;;
    conf)   # conf [FILE] — FILE (an edited copy) checked, and only then made the settings
            f=${2:-$REPO_DIR/fedokawai.conf}
            # read once, into root's own copy: what is checked is exactly what is saved
            t=$(mktemp) && cat -- "$f" >"$t" || { rm -f "${t:-}"; die "cannot read $f"; }
            p=$(conf_problems "$t")
            [[ -z $p ]] || { rm -f "$t"; die "not saved — fedokawai.conf would have:"$'\n'"$(sed 's/^/    /' <<<"$p")"; }
            if [[ $f != "$REPO_DIR/fedokawai.conf" ]]; then write_file "$REPO_DIR/fedokawai.conf" 0644 <"$t"; fi
            rm -f "$t"
            ok "fedokawai.conf: every value is valid — the next update applies it" ;;
    *) die "unknown action: $1 (check setup theme all verify update upgrade repair drift status)" ;;
  esac
}

if (($#)); then act "$@"; exit; fi

item() {   # item KEY NAME WHAT [NOTE] — gold key, aligned columns, notes dimmed
  printf '   %s%s%s  %-8s %-36s%s%s%s\n' "$C_GOLD" "$1" "$C_RESET" "$2" "$3" "$C_DIM" "${4:-}" "$C_RESET"
}

while :; do
  printf '\n  %s%sF E D O K A W A I%s\n  %s%s%s\n\n' "$C_BOLD" "$C_GOLD" "$C_RESET" "$C_DIM" "$(state_line)" "$C_RESET"
  item 1 Check  "is this machine ready?"              "read-only"
  item 2 Setup  "install the software only"
  item 3 Theme  "configs, colours, keybindings only"
  item 4 Both   "setup, then the theme automatically"
  item 5 Verify "prove everything is installed right" "read-only"
  item 6 Update "the season's update, snapshot first"
  item 7 Drift  "configs that differ from the repo"   "read-only"
  item 8 Status "setup progress"                      "read-only"
  item 9 Repair "find what broke and fix it"
  item q Quit   ""
  read -rp $'\n  choose: ' c || exit 0
  case $c in
    # (an action that fails has said why; the menu stays)
    1) act check || true ;;   2) act setup || true ;;   3) act theme || true ;;   4) act all || true ;;
    5) act verify || true ;;  6) act update || true ;;  7) act drift || true ;;  8) act status || true ;;
    9) act repair || true ;;
    q|Q|'') exit 0 ;;
    *) echo "  1–9 or q" ;;
  esac
done
