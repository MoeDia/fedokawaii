#!/usr/bin/env bash
# ═════════════════════════════════════════════════════════════════════════════
#  fedokawaii.sh — the one entry point.
#
#    sudo bash fedokawaii.sh             menu (for the install; once it is done, the system's
#                                        own control is `fedokawaii` — Super+U)
#    sudo bash fedokawaii.sh ACTION      run one action directly:
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
#      apply    from your working copy (fedokawaii copy): it becomes the toolkit, then its
#               configs are applied — and packages and system parts too when they changed
#
#  Run from a working copy on a finished install, theme and update and repair make that
#  copy the toolkit first (your saved settings merged in): what root runs, and what your
#  home has, always come from the same files.
#
#  Exit status: 0 done · 1 it could not (the lines above say why) · 2 misuse (or not run
#  with sudo) · 3 it ran, and something still needs you (verify, repair, apply, drift) ·
#  4 drift: in sync but for an optional part · 130 stopped (Ctrl+C)
# ═════════════════════════════════════════════════════════════════════════════
set -Eeuo pipefail
IFS=$'\n\t'
REPO_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
STATE_DIR=/var/lib/fedokawaii
LOG_FILE=/var/log/fedokawaii.log
# (help needs no root: it only reads this header)
if [[ ${1:-} == @(-h|--help|help) ]]; then sed -n '3,/^# ═/p' "${BASH_SOURCE[0]}" | sed '$d; s/^# \{0,2\}//'; exit 0; fi
[[ $EUID -eq 0 ]] || { echo "run with sudo: sudo bash fedokawaii.sh" >&2; exit 2; }
touch "$LOG_FILE"
source "$REPO_DIR/lib/common.sh"
TOOLKIT=/usr/local/lib/fedokawaii

# the desktop user: the one setup recorded; before that, USERNAME from fedokawaii.conf,
# or whoever ran sudo
# (Fedora's user names: letters of either case, digits, . _ - — a leading digit too)
# (each read `|| true`: a file not there yet is an empty answer, never the end of the script)
conf_user=$(sed -n 's/^USERNAME=["'"'"']\{0,1\}\([A-Za-z0-9_.][A-Za-z0-9_.-]*\).*/\1/p' "$REPO_DIR/fedokawaii.conf" 2>/dev/null | tail -n1) || true
user=$(head -n1 "$STATE_DIR/user" 2>/dev/null | tr -d '[:space:]') || true
[[ -n $user ]] || user=${conf_user:-${SUDO_USER:-}}
[[ $user == root ]] && user=""

state_line() {
  local p t
  p=$(cat "$STATE_DIR/phase" 2>/dev/null || echo "not started")
  case $p in 'done') p="complete" ;; "not started") ;; *) p="phase $p of 3" ;; esac
  t="not applied"
  [[ -n $user && -f $(getent passwd "$user" | cut -d: -f6)/.local/state/fedokawaii/theme-applied ]] && t="applied"
  printf '%s' "setup: $p · theme: $t"
}

# run from a working copy (not the toolkit), on a finished install
from_copy() { [[ $REPO_DIR != "$TOOLKIT" && $(cat "$STATE_DIR/phase" 2>/dev/null) == "done" && -d $TOOLKIT ]]; }
as_desk() { runuser -u "$user" -- "$@"; }   # the desktop user (who owns the working copy)

# apply — your working copy made the desktop's: every script parsed first (nothing applied
# if one does not), then the copy becomes the toolkit (setup.sh --toolkit: your saved
# settings merged in) and its configs are applied (theme); when packages or system parts
# changed, repair follows — it installs them and puts them in place. The copy is read as
# you: root reads nothing in your folders but the copy it makes (and checks) itself.
apply_copy() {
  local f out base bad=() changed=() theme=0 sys=0 rc=0
  from_copy || die "apply runs from your working copy on a finished install (fedokawaii copy makes one) — the toolkit itself: fedokawaii theme"
  [[ -n $user ]] || die "unknown desktop user — run setup first"
  hdr "Fedokawaii apply · $REPO_DIR → the toolkit"
  out=$(as_desk diff -rq --exclude=.git -- "$TOOLKIT" "$REPO_DIR" 2>/dev/null) || true
  while IFS= read -r f; do
    case $f in
      "Files $TOOLKIT/"*" differ") f=${f#"Files $TOOLKIT/"}; f=${f% and "$REPO_DIR"/*} ;;   # (a name may hold " and ")
      "Only in $REPO_DIR"*) f=${f#"Only in $REPO_DIR"}; f=${f#/}; f=${f/: //}; f="${f#/} (new)" ;;
      "Only in $TOOLKIT"*) f=${f#"Only in $TOOLKIT"}; f=${f#/}; f=${f/: //}; f="${f#/} (gone)" ;;
      *) continue ;;
    esac
    # fedokawaii.conf just as the copy had it when made or last applied: the settings you
    # changed since, through the menu, are the toolkit's — not a change of the copy's
    if [[ $f == fedokawaii.conf ]] && base=$(conf_base "$REPO_DIR/.git/fedokawaii-conf-base") && [[ -n $base ]] \
       && as_desk cmp -s -- "$REPO_DIR/fedokawaii.conf" "$base"; then continue; fi
    changed+=("$f")
  done <<<"$out"
  if ((${#changed[@]} == 0)); then
    ok "the copy and the toolkit are the same — nothing to apply (fedokawaii theme puts the configs back as they are)"; return 0
  fi
  log "${#changed[@]} file(s) differ from the toolkit:"; printf '    %s\n' "${changed[@]:0:40}"
  ((${#changed[@]} <= 40)) || log "… and $((${#changed[@]} - 40)) more (fedokawaii diff shows them all)"
  # every shell script parses (bash -n reads a script, never runs it)
  while IFS= read -r -d '' f; do
    if [[ $f == *.sh ]] || as_desk head -n1 -- "$f" 2>/dev/null | grep -qE '^#!.*[/ ](ba)?sh( |$)'; then
      as_desk bash -n -- "$f" 2>/dev/null || bad+=("${f#"$REPO_DIR/"}")
    fi
  done < <(as_desk find "$REPO_DIR" \( -path "$REPO_DIR/.git" -o -path "$REPO_DIR/docs" \) -prune -o -type f -print0)
  ((${#bad[@]} == 0)) || die "these do not parse — nothing was applied (bash -n FILE shows where): $(IFS=' '; echo "${bad[*]}")"
  # what each change needs: configs, helpers, pictures → theme; the rest → repair (which
  # runs theme itself); the handbook, tools and these notes only travel with the copy
  for f in "${changed[@]}"; do
    case $f in
      configs/*|bin/*|src/*|art/*|theme.sh*) theme=1 ;;
      docs/*|tools/*|*.md*|verify.sh*|check.sh*|fedokawaii.sh*) ;;
      *) sys=1 ;;
    esac
  done
  # (each step checked: the menu calls this under ||, where errexit is off — the old toolkit's
  # files must not be applied as if they were the copy's)
  bash "$REPO_DIR/setup.sh" --toolkit || { rc=$?; log "the copy did not become the toolkit — nothing was applied"; return "$rc"; }
  if ((sys)); then
    log "packages or system parts changed — repair installs and places them (and applies the theme)"
    bash "$TOOLKIT/setup.sh" --repair || rc=$?
    ((rc == 0 || rc == 3)) || return "$rc"
    ((rc == 0)) || log "repair ran; what still needs you is listed above"
  elif ((theme)); then
    bash "$TOOLKIT/theme.sh" --user "$user" || return $?
  else
    log "nothing here changes the desktop itself — the toolkit has the new files"
  fi
  ok "applied — keep the change in your copy's history: lazygit in $REPO_DIR (commit, then push)"
  return "$rc"                                    # (3: applied, and something still needs you)
}

misuse() { echo "fedokawaii.sh: $* — the actions: sudo bash fedokawaii.sh --help" >&2; exit 2; }
act() {
  # (a word more than an action takes is a slip, never ignored: `upgrade now` is no --now)
  case $1 in
    upgrade) (($# == 1)) || [[ $# == 2 && $2 == --now ]] || misuse "upgrade takes only --now" ;;
    conf)    (($# <= 2)) || misuse "conf takes one file" ;;
    *)       (($# == 1)) || misuse "$1 takes nothing more" ;;
  esac
  case $1 in
    check)  bash "$REPO_DIR/check.sh" ;;
    setup)  rm -f "$STATE_DIR/with-theme"; bash "$REPO_DIR/setup.sh" ;;
    all)    mkdir -p "$STATE_DIR"; touch "$STATE_DIR/with-theme"; bash "$REPO_DIR/setup.sh" ;;
    theme)  [[ -n $user ]] || die "unknown desktop user — run setup first"
            # (from a copy: it becomes the toolkit first — else the next fedokawaii theme,
            # run from the toolkit, would put the old files back)
            # (the menu calls this under ||, where errexit is off: hence the &&)
            if from_copy; then bash "$REPO_DIR/setup.sh" --toolkit && bash "$TOOLKIT/theme.sh" --user "$user"
            else bash "$REPO_DIR/theme.sh" --user "$user"; fi ;;
    apply)  apply_copy ;;
    drift)  [[ -n $user ]] || die "unknown desktop user — run setup first"
            bash "$REPO_DIR/theme.sh" --user "$user" --check ;;
    verify) bash "$REPO_DIR/verify.sh" ;;
    update) bash "$REPO_DIR/setup.sh" --update ;;
    upgrade) if [[ ${2:-} == --now ]]; then bash "$REPO_DIR/setup.sh" --upgrade --now
             else bash "$REPO_DIR/setup.sh" --upgrade; fi ;;
    repair) bash "$REPO_DIR/setup.sh" --repair ;;
    status) bash "$REPO_DIR/setup.sh" --status ;;
    conf)   # conf [FILE] — FILE (an edited copy) checked, and only then made the settings
            f=${2:-$REPO_DIR/fedokawaii.conf}
            # read once, into root's own copy: what is checked is exactly what is saved. Read
            # as whoever ran sudo — the copy is theirs: root never follows a link in it
            r=(cat --); [[ -n ${SUDO_USER:-} && $SUDO_USER != root ]] && r=(runuser -u "$SUDO_USER" -- cat --)
            t=$(mktemp) && "${r[@]}" "$f" >"$t" || { rm -f "${t:-}"; die "cannot read $f"; }
            p=$(conf_problems "$t")
            [[ -z $p ]] || { rm -f "$t"; die "not saved — fedokawaii.conf would have:"$'\n'"$(sed 's/^/    /' <<<"$p")"; }
            if [[ $f != "$REPO_DIR/fedokawaii.conf" ]]; then write_file "$REPO_DIR/fedokawaii.conf" 0644 <"$t"; fi
            rm -f "$t"
            ok "fedokawaii.conf: every value is valid — the next update applies it"
            log "BACKUP_TARGET and BACKUP_REMIND_DAYS count at once: the backup and its reminder read the file itself" ;;
    *) misuse "unknown action: $1 (check setup theme all verify update upgrade repair drift status apply)" ;;
  esac
}

if (($#)); then act "$@"; exit; fi

item() {   # item KEY NAME WHAT [NOTE] — gold key, aligned columns, notes dimmed
  printf '   %s%s%s  %-8s %-36s%s%s%s\n' "$C_GOLD" "$1" "$C_RESET" "$2" "$3" "$C_DIM" "${4:-}" "$C_RESET"
}

while :; do
  # (setup removes the folder it was started from once it is done: this menu then hands over)
  if [[ ! -f $REPO_DIR/setup.sh ]]; then
    printf '\n  %sthis folder was removed at the end of setup — from now on: fedokawaii (or Super+U on the desktop)%s\n' "$C_GOLD" "$C_RESET"
    cd / 2>/dev/null; exit 0
  fi
  printf '\n  %s%sF E D O K A W A I I%s\n  %s%s%s\n\n' "$C_BOLD" "$C_GOLD" "$C_RESET" "$C_DIM" "$(state_line)" "$C_RESET"
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
