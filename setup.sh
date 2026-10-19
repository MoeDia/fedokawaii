#!/usr/bin/env bash
# ═════════════════════════════════════════════════════════════════════════════
#  setup.sh — the software half of Fedokawaii. Normally started from the menu:
#  sudo bash fedokawaii.sh    (or: sudo bash fedokawaii.sh setup | all)
#
#    sudo bash setup.sh            build (3 phases; resumes itself after each reboot)
#    sudo bash setup.sh --update   the season's update: fedokawaii.conf's system values again,
#                                  dnf upgrade (snapshotted), the desktop's own tools, verify
#    sudo bash setup.sh --upgrade [--now]   move to the next Fedora release, once it has settled
#    sudo bash setup.sh --repair   verify, fix what can be fixed (packages, services, session,
#                                  release tools, torrra, Prowlarr, theme), verify again
#    sudo bash setup.sh --toolkit  from a working copy: it becomes the toolkit, your saved
#                                  settings merged in (fedokawaii.sh apply runs this, then theme)
#  (after setup, all of these run from the `fedokawaii` command / menu, Super+U)
#    sudo bash setup.sh --status   progress          --reset   forget progress
#    sudo bash setup.sh --no-reboot  run the current phase without rebooting
#
#  Installs software only. Configs, colours and keybindings are theme.sh's job;
#  it runs near the end only when you chose "Both" (state file: with-theme).
#  Exit: 0 done (or rebooting to go on) · 1 stopped: the line above says why · 2 misuse ·
#        3 repair or update ran, and something still needs you
# ═════════════════════════════════════════════════════════════════════════════
set -Eeuo pipefail
IFS=$'\n\t'
export LC_ALL=C.UTF-8      # every tool's output in one language and format, whatever yours is
REPO_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
STATE_DIR=/var/lib/fedokawaii
LOG_FILE=/var/log/fedokawaii.log
RESUME_UNIT=fedokawaii-resume.service
TOOLKIT=/usr/local/lib/fedokawaii
MODE=build NO_REBOOT=0 UPGRADE_FLAG="" RESUMED=0 STARTED_FROM=""

# (the options first: --help needs neither sudo nor a valid fedokawaii.conf, and a mistyped
# option stops the run before anything is touched)
for a in "$@"; do
  case $a in
    --resume) RESUMED=1 ;;
    --update) MODE=update ;;  --repair) MODE=repair ;;  --status) MODE=status ;;  --reset) MODE=reset ;;
    --toolkit) MODE=toolkit ;;  --kernels) MODE=kernels ;;
    --upgrade) MODE=upgrade ;;  --now) UPGRADE_FLAG=--now ;;  --after-upgrade) MODE="after-upgrade" ;;
    --no-reboot) NO_REBOOT=1 ;;
    -h|--help) sed -n '3,/^# ═/p' "$0" | sed '$d'; exit 0 ;;
    *) echo "unknown option: $a (sudo bash setup.sh --help lists them)" >&2; exit 2 ;;
  esac
done
[[ $EUID -eq 0 ]] || { echo "run with sudo: sudo bash fedokawaii.sh" >&2; exit 2; }
mkdir -p "$STATE_DIR"
# the log, root's alone (it records every command): past 8 MB the old one is kept as
# fedokawaii.log.1 and a new one begins — never more than two, so years of updates fit
if [[ -f $LOG_FILE && $(stat -c %s "$LOG_FILE" 2>/dev/null || echo 0) -gt 8388608 ]]; then mv -f "$LOG_FILE" "$LOG_FILE.1"; fi
touch "$LOG_FILE"; chmod 600 "$LOG_FILE"
source "$REPO_DIR/lib/common.sh"
source "$REPO_DIR/lib/manifest.sh"
source "$REPO_DIR/lib/upstream.sh"
source "$REPO_DIR/lib/hygiene.sh"
source "$REPO_DIR/lib/hardware.sh"
load_conf "$REPO_DIR"

# The error report, on stderr. Inside a $(…), a <(…) or a pipeline (errtrace hands the trap
# down) it only ends that piece, silently: what a $(…) captures, or a <(…) feeds a loop, is
# then never the report itself — and the command that used it reports, here, with its line.
# (a command run or retry saw fail is named, not the helper's own return: failed_what)
# shellcheck disable=SC2154  # rc is assigned inside the trap string
trap 'rc=$?; ((BASH_SUBSHELL == 0)) || exit $rc; failed_what "${FUNCNAME[0]:-main}:$LINENO"
      _out "${C_RED}✘ line $LINENO${FUNCNAME[0]:+ in ${FUNCNAME[0]}(), called from line ${BASH_LINENO[-2]}}: ${FAILED_SHOW:0:160} (exit $rc)${C_RESET}" >&2
      _out "  log: $LOG_FILE — fix the cause, then run the same command again (finished steps are skipped)" >&2; exit $rc' ERR
trap '_out ""; _out "${C_RED}✘ interrupted — run the same command again to continue${C_RESET}"; exit 130' INT TERM
if [[ $MODE == status ]]; then        # read-only, so it works while another run holds the lock
  # shellcheck disable=SC1091
  source /etc/os-release
  echo "phase $(cat "$STATE_DIR/phase" 2>/dev/null || echo 1) · user $(cat "$STATE_DIR/user" 2>/dev/null || echo '(not chosen yet)') · Fedora $VERSION_ID · theme $([[ -f $STATE_DIR/with-theme ]] && echo 'with setup' || echo separate)"
  find "$STATE_DIR" -name 'done.*' -printf '  ✔ %f\n' | sed 's/done\.//' | sort; exit 0
fi
if [[ $MODE == kernels ]]; then     # (the boot's own run: never waits — another run is on, so next start)
  exec 9>"$STATE_DIR/lock"; flock -n 9 || exit 0
else take_lock "$STATE_DIR/lock"; fi
make_tmp
# A run resumed after a reboot (fedokawaii-resume.service) that stops: nobody typed a command
# to "run again", and tty1, the service's own screen, has no login of its own until you
# switch away and back. So it ends by saying how to carry on (the reason is above it).
if ((RESUMED)); then
  resume_hint() {
    _out ""
    if [[ $(phase) == 'done' ]]; then    # (the final check: the build is in place)
      _out "${C_GOLD}  The desktop is installed, but its last steps found a problem (above).${C_RESET}"
      _out "${C_GOLD}  Restart the computer, log in, then run:  fedokawaii repair${C_RESET}"
      return 0
    fi
    _out "${C_GOLD}  Setup stopped — the reason is above. Once it is put right, carry on either way:${C_RESET}"
    _out "${C_GOLD}    · restart the computer: setup continues by itself${C_RESET}"
    _out "${C_GOLD}    · or press Alt+F2, log in, and run:  sudo bash $TOOLKIT/setup.sh${C_RESET}"
  }
  trap 'rc=$?; rm -rf "$KAWA_TMP"; [[ -n ${FOLLOWER:-} ]] && kill "$FOLLOWER" 2>/dev/null
        ((rc == 0)) || resume_hint; true' EXIT
fi

# shellcheck disable=SC1091
source /etc/os-release
FEDORA_VER=$VERSION_ID

if [[ -f $STATE_DIR/user ]]; then
  TARGET_USER=$(head -n1 "$STATE_DIR/user" | tr -d '[:space:]')
  # (the record of who the desktop is for: a user that is not there — the file damaged, the
  # user renamed — would make every step fail somewhere far from the cause)
  [[ -n $TARGET_USER && $TARGET_USER != root ]] && getent passwd "$TARGET_USER" >/dev/null \
    || die "$STATE_DIR/user names '$TARGET_USER', who is not a user of this machine — write the desktop user's name in it (or delete it: setup then takes USERNAME, or whoever ran sudo)"
else
  TARGET_USER=${USERNAME:-${SUDO_USER:-}}
  [[ -n $TARGET_USER && $TARGET_USER != root ]] || die "cannot tell who the desktop user is — run with sudo from your user, or set USERNAME"
fi
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
TARGET_UID=$(id -u "$TARGET_USER"); TARGET_GID=$(id -g "$TARGET_USER")
export TARGET_USER TARGET_HOME TARGET_UID TARGET_GID

detect_gpu() {   # the GPU the desktop is built for: GPU in fedokawaii.conf, else the cards'
  # (lib/hardware.sh, hw_gpu: amd, intel — or nvidia, vm, none, which it is not built for)
  [[ $GPU != auto ]] && { echo "$GPU"; return; }
  hw_gpu
}
phase() {   # the phase setup is in: 1 when none is recorded (a line end from another editor is no matter)
  local p; p=$(head -n1 "$STATE_DIR/phase" 2>/dev/null | tr -d '[:space:]') || p=""
  echo "${p:-1}"
}
set_phase() { printf '%s\n' "$1" | write_file "$STATE_DIR/phase" 0644; }   # (whole or not at all)

# ── the toolkit: this repository, installed for good ──────────────────────────
# Root runs it, often with nobody watching (the resume after a reboot, every update), so
# never from your clone — anything running as you could change a script there: from a
# root-owned copy in /usr/local/lib/fedokawaii, made at the first reboot and used from then
# on by everything (the `fedokawaii` command, Super+U, setup's later phases). Your clone
# can go once setup is done. A newer clone, run once (sudo bash fedokawaii.sh update, or
# repair), replaces the copy — its fedokawaii.conf merged with your saved settings (conf_merge).
install_toolkit() {
  local sum b
  # (the folder this run was started from — your clone or download: once the run is through
  # it goes, as the very last thing; clone_done. A build records it for its later phases,
  # across the restarts; an update or a repair keeps it for this run alone. `--toolkit` —
  # what `fedokawaii apply` runs from your working copy — never: that folder is yours to keep)
  if [[ $REPO_DIR != "$TOOLKIT" && $REPO_DIR == "$TARGET_HOME"/?* ]]; then
    case $MODE in
      build)         [[ $(phase) == 'done' ]] || printf '%s\n' "$REPO_DIR" | write_file "$STATE_DIR/started-from" 0644 ;;
      update|repair) STARTED_FROM=$REPO_DIR ;;
    esac
  fi
  if [[ $REPO_DIR != "$TOOLKIT" ]]; then
    toolkit_back
    rm -rf "$TOOLKIT.new" "$TOOLKIT.old"
    mkdir -p "${TOOLKIT%/*}"
    # copied inside a folder only root can enter, root's own from the first byte: nothing
    # running as you can reach the copy while it is made and checked
    mkdir -m 0700 "$TOOLKIT.new"
    cp -a --no-preserve=ownership "$REPO_DIR/." "$TOOLKIT.new/t"
    # (the settings the copy was made with, kept by `fedokawaii copy` in its .git: read from
    # this copy of root's, never from your folder — conf_merge measures the copy against them)
    b=$TOOLKIT.new/t/.git/fedokawaii-conf-base
    if [[ -d $TOOLKIT.new/t/.git && ! -L $TOOLKIT.new/t/.git && -f $b && ! -L $b ]]; then
      cp -p -- "$b" "$TOOLKIT.new/conf-base"
    fi
    rm -rf "$TOOLKIT.new/t/.git"
    chown -R root:root "$TOOLKIT.new/t"; chmod -R u=rwX,go=rX "$TOOLKIT.new/t"   # (no set-id bits)
    # plain files and folders only: a link would point root's toolkit at a file of yours. The
    # copy itself is checked, once made — the clone could have changed while it was read
    sum=$(find "$TOOLKIT.new/t" ! -type f ! -type d -print -quit)
    if [[ -n $sum ]]; then
      rm -rf "$TOOLKIT.new"
      die "the project folder holds a link or other special file (${sum#"$TOOLKIT.new/t/"}) — the toolkit is made only of plain files"
    fi
    cp -p "$TOOLKIT.new/t/fedokawaii.conf" "$TOOLKIT.new/copy.conf"   # (as this copy has it)
    conf_merge "$TOOLKIT.new/t/fedokawaii.conf"
    # (two renames, a moment apart: cut off between them, the old toolkit is still whole in
    # $TOOLKIT.old, and toolkit_back puts it back before anything else looks)
    if [[ -d $TOOLKIT ]]; then mv -T "$TOOLKIT" "$TOOLKIT.old"; fi
    mv -T "$TOOLKIT.new/t" "$TOOLKIT"
    write_file "$STATE_DIR/conf-from-copy.conf" 0644 <"$TOOLKIT.new/copy.conf"
    rm -rf "$TOOLKIT.new" "$TOOLKIT.old"
  fi
  install -m 0755 "$TOOLKIT/system/fedokawaii" /usr/local/bin/fedokawaii
  install -m 0755 "$TOOLKIT/system/fedokawaii-report" /usr/local/bin/fedokawaii-report
  restorecon -R "$TOOLKIT" /usr/local/bin/fedokawaii /usr/local/bin/fedokawaii-report 2>/dev/null || true
}

# toolkit_back — the toolkit, should a power cut have come between install_toolkit's two
# renames: its old copy, whole, put back (nothing deletes $TOOLKIT.old while it is the only one)
toolkit_back() {
  [[ ! -e $TOOLKIT && -d $TOOLKIT.old && ! -L $TOOLKIT.old ]] || return 0
  mv -T -- "$TOOLKIT.old" "$TOOLKIT" && log "the toolkit put back from $TOOLKIT.old (an update was cut off as it replaced it)"
}

# conf_merge NEW — fedokawaii.conf, key by key, for the toolkit about to be made from this copy
# (NEW is this copy's, and becomes the merge). What the menu's settings saved in the toolkit is
# kept, unless this copy changed that key since the toolkit was last made from a copy: then
# that edit is what you mean. With no earlier copy on record, the pins (DWL_*, TFC_*) are this
# copy's and every setting the toolkit's. A key new here comes from here. (By content, never
# by date: a fresh clone or download is always "newer".) A saved value replaced is logged,
# and the toolkit's file before is kept: /var/lib/fedokawaii/fedokawaii.conf.before.
conf_merge() {
  local new=$1 old=$TOOLKIT/fedokawaii.conf last line k v had=0 win s
  last=$(conf_base "$TOOLKIT.new/conf-base"); [[ -n $last ]] || last=$STATE_DIR/conf-from-copy.conf
  local -A tv=() tl=() lv=()
  local -a out=() taken=()
  [[ -f $old ]] || return 0
  while IFS= read -r line || [[ -n $line ]]; do
    if [[ $line =~ $CONF_RE ]]; then
      k=${BASH_REMATCH[1]}; tv[$k]=${BASH_REMATCH[3]}${BASH_REMATCH[4]}${BASH_REMATCH[5]}; tl[$k]=$line
    fi
  done <"$old"
  [[ -f $last ]] && had=1
  if ((had)); then
    while IFS= read -r line || [[ -n $line ]]; do
      if [[ $line =~ $CONF_RE ]]; then lv[${BASH_REMATCH[1]}]=${BASH_REMATCH[3]}${BASH_REMATCH[4]}${BASH_REMATCH[5]}; fi
    done <"$last"
  fi
  while IFS= read -r line || [[ -n $line ]]; do
    if [[ $line =~ $CONF_RE ]]; then
      k=${BASH_REMATCH[1]} v=${BASH_REMATCH[3]}${BASH_REMATCH[4]}${BASH_REMATCH[5]}
      [[ " ${CONF_RETIRED[*]} " == *" $k "* ]] && continue   # (a setting gone since: its line out)
      if [[ -v tv[$k] && ${tv[$k]} != "$v" ]]; then
        if ((had)) && [[ -v lv[$k] ]]; then
          if [[ ${lv[$k]} == "$v" ]]; then win=toolkit; else win=copy; fi
        elif [[ $k == DWL_* || $k == TFC_* ]]; then win=copy
        else win=toolkit; fi
        if [[ $win == toolkit ]]; then line=${tl[$k]}; else taken+=("$k=\"$v\" (was \"${tv[$k]}\")"); fi
      fi
    fi
    out+=("$line")
  done <"$new"
  printf '%s\n' "${out[@]}" >"$new"
  # a saved value this copy no longer accepts: that key is this copy's (each problem line
  # starts with its key's name); should anything still not pass, the whole file is
  local bad=() i
  mapfile -t bad < <(conf_problems "$new" | awk '{ print $1 }' | sort -u)
  if ((${#bad[@]})); then
    for k in "${bad[@]}"; do
      [[ $k =~ ^[A-Z_]+$ ]] || continue
      line=$(grep -m1 -E "^[[:space:]]*$k=" "$TOOLKIT.new/copy.conf") || continue
      for i in "${!out[@]}"; do if [[ ${out[i]} =~ ^[[:space:]]*$k= ]]; then out[i]=$line; fi; done
      taken+=("$k (the saved value no longer passes)")
    done
    printf '%s\n' "${out[@]}" >"$new"
    if [[ -n $(conf_problems "$new") ]]; then
      cp -p "$TOOLKIT.new/copy.conf" "$new"; taken=("every setting: the saved ones do not pass this copy's checks")
    fi
  fi
  if ((${#taken[@]})); then
    cp -p "$old" "$STATE_DIR/fedokawaii.conf.before"
    printf -v s '%s · ' "${taken[@]}"
    log "fedokawaii.conf, from this copy: ${s% · } — the toolkit's file before: $STATE_DIR/fedokawaii.conf.before"
  fi
}
# an update or repair run from a copy: the copy becomes the toolkit first, and the rest of
# the run is the toolkit's — its fedokawaii.conf (your saved settings with this copy's
# changes) and its files (verify.sh, theme.sh, the session launcher read them). A copy the
# toolkit refuses stops the run there, before anything is applied: never a run on the
# copy's settings, which would undo what you saved through the menu.
toolkit_first() {
  [[ $REPO_DIR != "$TOOLKIT" ]] || return 0
  install_toolkit
  settings_from_toolkit
}
settings_from_toolkit() {
  [[ $REPO_DIR != "$TOOLKIT" && -f $TOOLKIT/fedokawaii.conf ]] || return 0
  local bad
  bad=$(conf_problems "$TOOLKIT/fedokawaii.conf")
  [[ -z $bad ]] || die "the toolkit's fedokawaii.conf has problems — nothing applied: ${bad//$'\n'/ · }"
  read_conf "$TOOLKIT/fedokawaii.conf"
  REPO_DIR=$TOOLKIT
}

# ── resume across reboots: a one-shot unit takes tty1 and re-runs this script ──
install_resume_unit() {
  install_toolkit
  write_file "/etc/systemd/system/$RESUME_UNIT" <<EOF
[Unit]
Description=Fedokawaii setup — resume after reboot
After=network-online.target systemd-user-sessions.service
Wants=network-online.target
# (greetd too: enabled near the very end, it must not take tty1 from a run that resumes there)
Conflicts=getty@tty1.service kmsconvt@tty1.service greetd.service

[Service]
Type=oneshot
ExecStart=/usr/bin/bash $TOOLKIT/setup.sh --resume
StandardInput=tty-force
StandardOutput=tty
StandardError=tty
TTYPath=/dev/tty1
TTYReset=yes
TTYVHangup=yes
TimeoutStartSec=0
Environment=TERM=linux

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload; systemctl enable "$RESUME_UNIT" >/dev/null 2>&1
}
remove_resume_unit() {
  systemctl disable "$RESUME_UNIT" >/dev/null 2>&1 || true
  rm -f "/etc/systemd/system/$RESUME_UNIT"; systemctl daemon-reload
}
reboot_to() {
  set_phase "$1"; install_resume_unit
  (( NO_REBOOT )) && { log "reboot when ready — phase $1 starts by itself"; exit 0; }
  hdr "rebooting in 10 s → phase $1 continues on this screen"; sleep 10; systemctl reboot; exit 0
}
# wait_for_network — the network, given time to come up: minutes for a run the resume unit
# started at boot (Wi-Fi and DHCP may still be on their way), half a minute for one you typed
# (it is either there or not)
online() { curl -sS -o /dev/null --proto '=https' --max-time 8 https://mirrors.fedoraproject.org/ 2>/dev/null; }
wait_for_network() {
  local n=6 rc=0 was; ((RESUMED)) && n=30
  retry "$n" 5 online && return 0
  online || rc=$?
  if ((rc == 60)); then
    # the network answers, but every certificate is refused (curl's 60): a clock years off —
    # the RTC left on local time by Windows, or its battery flat — fails every https download
    # the same way, and "no network" would send you to the wrong place. chrony is asked to
    # set it from the network now, then one more try; failing that, the clock is named
    was=$(date '+%F %H:%M')
    # (makestep acts on a measurement chrony already has; waitsync gives it up to 20 s for a
    # first one; then once more, should its own stepping allowance be used up)
    chronyc -a makestep >/dev/null 2>&1 || true
    chronyc waitsync 4 0 0 5 >/dev/null 2>&1 || true
    chronyc -a makestep >/dev/null 2>&1 || true
    if online; then log "the clock was wrong ($was) — set from the network: $(date '+%F %H:%M')"; return 0; fi
    die "online, but every site's certificate is refused: the clock is probably wrong ($was) — set it (sudo timedatectl set-time 'YYYY-MM-DD HH:MM'; timedatectl shows it), then run it again"
  fi
  die "no network — connect to one (nmtui), then run it again"
}

# contained FN [ARG…] — run FN in a subshell with errexit really on, so a failure ends FN
# alone (the line that failed is reported); its status lands in CONTAINED_RC, and contained
# itself always returns 0. (`set +e; ( set -e; FN ); set -e` is not enough: with errtrace,
# the subshell's failure also sets off this script's ERR trap, which ends the whole run.)
CONTAINED_RC=0
contained() {
  local saved; saved=$(trap -p ERR)
  trap - ERR; set +e
  # shellcheck disable=SC2154  # rc is assigned inside the trap string
  # shellcheck disable=SC2034  # lvl is read inside the trap string
  ( set -e; lvl=$BASH_SUBSHELL       # (deeper: a $(…) or <(…) inside FN — it just ends, as above)
    # (a function that returned its own failure has said why: no "return 1" line after it —
    # but a command run or retry saw fail is named)
    trap 'rc=$?; ((BASH_SUBSHELL == lvl)) || exit $rc; failed_what "${FUNCNAME[0]:-main}:$LINENO"
          [[ $FAILED_SHOW == return* ]] && exit $rc
          _out "${C_RED}✘ line $LINENO${FUNCNAME[0]:+ in ${FUNCNAME[0]}()}: ${FAILED_SHOW:0:160} (exit $rc)${C_RESET}" >&2; exit $rc' ERR
    "$@" )
  CONTAINED_RC=$?
  set -e; eval "$saved"
  return 0
}

# ═════════════════════════════════════════════════════════════════════════════
#  PHASE 1 — readiness, package manager, boot policy, update, base, trim
# ═════════════════════════════════════════════════════════════════════════════
s_ready() {
  bash "$REPO_DIR/check.sh" || die "this machine is not ready — see the ✘ items above (log: /var/log/fedokawaii-check.log)"
  printf '%s\n' "$TARGET_USER" | write_file "$STATE_DIR/user" 0644
}

s_baseline() {          # what the installer + you put there, so verify.sh can spot extras later
  dnf repoquery --userinstalled --qf '%{name}\n' | sort -u >"$STATE_DIR/baseline-userinstalled"
  log "$(wc -l <"$STATE_DIR/baseline-userinstalled") packages were user-installed before setup"
}

s_dnf() {
  write_file /etc/dnf/libdnf5.conf.d/90-fedokawaii.conf <<EOF
# Fedokawaii — only values that differ from Fedora's defaults (guide: "DNF's settings on this desktop")
[main]
max_parallel_downloads=$DNF_PARALLEL
fastestmirror=True
minrate=5k
timeout=20
installonly_limit=2
defaultyes=True
# never as a weak dependency: Node 22 (neovim recommends tree-sitter-cli, which recommends
# "nodejs" — nodejs22 on Fedora 44; on 45 the package named nodejs, which owns /usr/bin/node
# as nodejs24-bin does and would stop the media step). One Node.js: the manifest's 24.
# Nor PackageKit, the background updater of software centres (forbidden: dnf only), which
# PackageKit-Qt6, a library some Qt programs link, recommends. Nor what LibreOffice recommends
# beyond Writer, Calc and Impress: Java (for its database and old macros — some 200 MB) and
# its offline help (F1 opens the same help online, in Brave)
exclude_from_weak=nodejs,nodejs22*,PackageKit,java-*-openjdk-headless,libreoffice-help-*
EOF
  local k want v dump; dump=$(dnf --dump-main-config 2>/dev/null) || dump=""
  # checked, and reported — never a reason to stop: a later dnf may print a value its own way
  # (minrate is shown in bytes: 5k = 5120 — low enough for a slow phone tether, a stalled
  # mirror still dropped after timeout=20 s)
  for k in "max_parallel_downloads:$DNF_PARALLEL" fastestmirror:1 minrate:5120 timeout:20 installonly_limit:2 defaultyes:1 \
           'exclude_from_weak:nodejs,nodejs22*,PackageKit,java-*-openjdk-headless,libreoffice-help-*'; do
    want=${k#*:}; v=$(sed -n "s/^${k%%:*} *= *//p" <<<"$dump")
    [[ $v == "$want" || ( $want == 1 && $v == [Tt]rue ) || ( $want == 5120 && $v == 5[kK] ) ]] \
      || log "dnf shows ${k%%:*}='$v' where the drop-in sets $want — /etc/dnf/dnf.conf may override it"
  done
  # (no protected list of our own: dnf also refuses a protected package's replacement — a
  # sudo-rs, a retired greetd — and would then hold every later update back for good. The
  # manifest's packages are marked as yours instead, so dnf's clean-up never takes them.)
  # package metadata is fetched when you update (`dnf upgrade --refresh`), not every hour or
  # so in the background by dnf's makecache timer: no downloads and no work between updates
  # Masked, not disabled: Fedora 44's dnf5-makecache.timer is a static unit (switched on by a
  # link its package ships, not by an [Install] section), which `disable` cannot turn off — it
  # only prints why. A mask holds through dnf updates; `systemctl unmask` undoes it
  local u
  for u in dnf5-makecache.timer dnf-makecache.timer; do
    systemctl cat "$u" >/dev/null 2>&1 || continue
    [[ $(systemctl is-enabled "$u" 2>/dev/null) == masked ]] && continue
    run systemctl mask --now "$u"
  done
  return 0
}

# other_os → the other systems this machine starts (Windows Boot Manager…), one per line: what
# os-prober finds, as GRUB's menu does (Fedora keeps it on). Recorded for verify.
other_os() {
  command -v os-prober >/dev/null || return 0
  os-prober 2>/dev/null | cut -d: -f2 | grep . | sort -u || true
}
s_boot() {
  # Hidden menu (Fedora's own mechanism): stays hidden while the last boot succeeded,
  # appears by itself after a failed one. The timer marks a boot successful — two minutes
  # after the desktop starts it (autostart.sh), never at boot: with linger your own systemd
  # starts at boot, desktop or not, so Fedora's every-session timer would count any boot
  # that got that far, one whose desktop never came up as well. Once the
  # theme is applied, BOOT_MENU_SECONDS decides instead (theme.sh shows the themed menu).
  # Beside another system (dual boot) it stays shown, as Fedora's installer leaves it: a
  # hidden menu would look as if that system were gone.
  local others; others=$(other_os)
  if [[ -n $others ]]; then
    printf '%s\n' "$others" | write_file "$STATE_DIR/other-os" 0644
    log "this machine also starts $(paste -sd, - <<<"$others" | sed 's/,/, /g') — the boot menu stays shown"
    run grub2-editenv - unset menu_auto_hide
  elif [[ -f $TARGET_HOME/.local/state/fedokawaii/theme-applied ]] && ((BOOT_MENU_SECONDS > 0)); then
    rm -f "$STATE_DIR/other-os"
    log "boot menu: left to the theme (shown for $BOOT_MENU_SECONDS s)"
  else
    rm -f "$STATE_DIR/other-os"
    run grub2-editenv - set menu_auto_hide=1
  fi
  run systemctl --global disable grub-boot-success.timer
  s_kernels
}

# ── one kernel ────────────────────────────────────────────────────────────────
# One kernel at rest: the newest. dnf keeps two while an update installs one (installonly_limit=2,
# its minimum; the one running is never taken), and the one before goes once the newest has
# proven itself: it is the one running and — for the run at boot — this start has reached the
# desktop for two minutes (grubenv's boot_success: GRUB clears it at every start, the
# desktop's grub-boot-success timer sets it). Until then the one before stays in the boot menu
# as the way back. Update and repair ask the same of the start they run in: repair is what the
# rescue screen sends you to when the desktop does not start, and then the kernel before is the
# one that works. Setup alone (the installer's kernel, before any desktop) needs only the first.
KERNEL_PKGS=(kernel kernel-core kernel-modules kernel-modules-core kernel-modules-extra kernel-devel kernel-devel-matched)
old_kernels_out() {   # old_kernels_out [desktop]
  local now v n vers=() pk=()
  now=$(uname -r)
  mapfile -t vers < <(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-core 2>/dev/null | grep -v 'not installed' | sort -V)
  ((${#vers[@]} > 1)) || return 0
  if [[ ${vers[-1]} != "$now" ]]; then
    log "kernel ${vers[-1]} is installed and waits for a restart — $now stays until it runs"; return 0
  fi
  if [[ ${1:-} == desktop ]] && ! grub2-editenv - list 2>/dev/null | grep -qx boot_success=1; then
    log "this start has not reached the desktop for two minutes — the kernel before $now stays as the way back"; return 0
  fi
  for v in "${vers[@]:0:${#vers[@]}-1}"; do
    for n in "${KERNEL_PKGS[@]}"; do rpm -q "$n-$v" >/dev/null 2>&1 && pk+=("$n-$v"); done
  done
  ((${#pk[@]})) || return 0
  log "one kernel: $now stays, the one before it goes — ${pk[*]}"
  # (no repository needed to remove: none is asked, so it works offline too)
  run dnf -y --disable-repo='*' remove "${pk[@]}"
}
one_kernel() { s_kernels; old_kernels_out; }   # (setup: the installer's kernel, once the newest runs)
# s_kernels — the rule at every start: a quarter of an hour in, the boot's own run
s_kernels() {
  write_file /etc/systemd/system/fedokawaii-kernels.service <<UNIT
# installed by setup.sh — one kernel: the ones before the newest go once it has reached the
# desktop (handbook §29.5)
[Unit]
Description=Fedokawaii: one kernel — the one before the newest removed once the newest has proven itself

[Service]
Type=oneshot
ExecStart=/usr/bin/bash $TOOLKIT/setup.sh --kernels
Nice=19
UNIT
  write_file /etc/systemd/system/fedokawaii-kernels.timer <<'UNIT'
# installed by setup.sh — a quarter of an hour after every start (the desktop marks a good
# start after two minutes)
[Unit]
Description=Fedokawaii: one kernel, checked after every start

[Timer]
OnBootSec=15min

[Install]
WantedBy=timers.target
UNIT
  systemctl daemon-reload
  systemctl is-enabled --quiet fedokawaii-kernels.timer || systemctl enable fedokawaii-kernels.timer
}

s_update() { wait_for_network; tidy_after_cut; run dnf -y upgrade --refresh; }

s_base() {
  dnf_install "${PKG_BASE[@]}"
  timedatectl set-timezone "$TIMEZONE"; timedatectl set-ntp true
  # a name of the machine's own: without one, NetworkManager takes whatever the network hands
  # out, and a browser running when it changes refuses its next window ("profile in use on
  # another computer" — the profile lock records the name). The installer's name is kept.
  local h; h=$(hostnamectl --static 2>/dev/null) || h=""
  if [[ -z $h || $h == localhost || $h == localhost.localdomain ]]; then
    # (a nicety, never a reason to stop: hostnamed may not answer on a damaged system)
    if hostnamectl set-hostname fedokawaii; then log "the machine's name: fedokawaii (none was set)"
    else log "could not name the machine (hostnamectl) — name it later: sudo hostnamectl set-hostname NAME"; fi
  fi
}

s_trim() {              # one editor (neovim), no rescue kernel image
  local p rm=() others
  for p in "${PKG_REMOVE[@]}"; do pkg_installed "$p" && rm+=("$p"); done
  if ((${#rm[@]})); then
    others=$(dnf -q repoquery --installed --whatrequires="$(IFS=,; echo "${rm[*]}")" --qf '%{name}\n' \
             | grep -vxF -f <(printf '%s\n' "${PKG_REMOVE[@]}") || true)
    [[ -z $others ]] || die "removing $(IFS=' '; echo "${rm[*]}") would take these with it: $others"
    run dnf -y remove "${rm[@]}"
  fi
  editor_policy
}

# ── a quiet boot ──────────────────────────────────────────────────────────────
# From the power button to the login screen nothing but the splash and then the login — and
# from the desktop back to the login screen at a logout. Two parts:
# · the boot's own arguments on every entry (BOOT_ARGS, lib/common.sh): rhgb — the splash
#   (the installer adds it with quiet, but not on every install: a text-mode one leaves them
#   out); quiet loglevel=3 rd.udev.log_level=3 — the kernel's and the initramfs' messages only
#   when critical; systemd.show_status=false — no status lines ("[FAILED] …") over the
#   console; vt.global_cursor_default=0 — no cursor blinking on it; and
#   systemd.tty.term.console=dumb: systemd 257 and later asks the console for its size as
#   PID 1 starts, and waits for the answer; with Plymouth holding the screen it sometimes
#   never comes, and about one boot in ten stops on a black screen at "Starting Switch Root"
#   until a key is pressed (systemd mends it in 261). A dumb console TERM makes systemd skip
#   the question: nothing visible changes, and the login consoles set their own TERM (linux).
# · why the console matters at all: greetd switches tty1 to text and clears it before every
#   login screen and every session (its design: text programs may run there), so for a moment
#   — after the splash at boot, after the desktop at logout — the screen shows tty1 itself.
#   Blank (nothing is written there: the greeter's command keeps its output off it) and with
#   no cursor, that moment is a plain ground like the frames either side of it (the theme's
#   console palette makes the console's black sumi ink).
# The cursor the boot hides comes back for a login on a text console (Ctrl+Alt+F2…, the
# rescue shell): /etc/profile.d/fedokawaii-console.sh. The messages all stay in the journal
# (journalctl -b), and Esc during the splash shows the start-up as text.
s_quiet_boot() {
  console_boot_arg
  write_file /etc/profile.d/fedokawaii-console.sh <<'EOF'
# /etc/profile.d/fedokawaii-console.sh — installed by setup.sh. The boot hides the text
# consoles' cursor (vt.global_cursor_default=0: none blinks on tty1, the console the login
# screen shares); a login on a text console (Ctrl+Alt+F2…, the rescue shell) shows it again
[ "$TERM" = linux ] && [ -t 1 ] && printf '\033[?25h'
EOF
}
console_boot_arg() {   # each on every boot entry (only one an entry lacks: grubby is not run for nothing)
  local a want
  a=$(grubby --info=ALL 2>/dev/null | grep '^args=') || a=""
  for want in "${BOOT_ARGS[@]}"; do
    [[ -n $a ]] && ! grep -vqE -- "[\" ]$want([\" ]|\$)" <<<"$a" && continue
    run grubby --update-kernel=ALL --args="$want"
  done
}
# kernel_images — every kernel at rest has its boot image (/boot/initramfs-VERSION.img). dracut
# makes it from a scriptlet of the kernel's package, and a scriptlet that fails does not fail
# dnf: the update ends well, and the new entry does not boot (the kernel before it still does,
# from the menu). Made again here; verify names any still missing
kernel_images() {
  local v rc=0
  for v in $(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-core 2>/dev/null | grep -v 'not installed'); do
    # (no kernel file either: /boot is not where it should be — nothing is written into a stand-in)
    [[ -s /boot/vmlinuz-$v ]] || { log "no /boot/vmlinuz-$v — is /boot mounted? (findmnt /boot) nothing made"; rc=1; continue; }
    [[ -s /boot/initramfs-$v.img ]] && continue
    log "kernel $v has no boot image (initramfs) — dracut makes it now"
    run dracut -f --kver "$v" || { log "dracut could not make the boot image for $v — that kernel would not start (the one before it still does); sudo dracut -f --kver $v shows why"; rc=1; }
  done
  return "$rc"
}
editor_policy() {       # neovim is the editor (EDITOR, VISUAL, vi); no rescue kernel image
  rm -f /boot/vmlinuz-0-rescue-* /boot/initramfs-0-rescue-* /boot/loader/entries/*-0-rescue*.conf
  write_file /etc/profile.d/editor.sh <<'EOF'
export EDITOR=nvim
export VISUAL=nvim
EOF
  # vi is a two-line script that runs nvim — never a link to it: dracut puts vi into every
  # boot image (its rescue shell's editor) and follows a link to the program itself, then
  # fails on nvim's Lua libraries ("could not locate dependency …/lpeg.so"): no boot image
  # for a new kernel, and none with the splash. A script brings only itself and /bin/sh
  write_file /usr/local/bin/vi 0755 <<'EOF'
#!/bin/sh
exec nvim "$@"
EOF
}

s_tuning() {   # an always-plugged desktop: the CPU at full speed, Wi-Fi and Bluetooth never napping
  local new=0
  cmp -s "$REPO_DIR/system/tuned.conf" /etc/tuned/profiles/fedokawaii/tuned.conf || new=1
  install -D -m 0644 "$REPO_DIR/system/tuned.conf" /etc/tuned/profiles/fedokawaii/tuned.conf
  systemctl enable --now tuned.service
  # (applied when it is new or another is active — not again on every run)
  if ((new)) || [[ $(tuned-adm active 2>/dev/null) != *": fedokawaii" ]]; then run tuned-adm profile fedokawaii; fi
  [[ $(tuned-adm active 2>/dev/null) == *fedokawaii* ]] \
    || log "tuned does not show the fedokawaii profile yet (tuned-adm active) — verify checks it; update and repair apply it again"
  write_file /etc/NetworkManager/conf.d/90-fedokawaii.conf <<'EOF'
# Fedokawaii — Wi-Fi power saving off (2 = disable): a desktop is always plugged in, and a
# radio that naps between packets adds lag to games, calls and screen sharing
[connection]
wifi.powersave = 2
EOF
  nmcli general reload conf >/dev/null 2>&1 || true
  write_file /etc/modprobe.d/fedokawaii-btusb.conf <<'EOF'
# Fedokawaii — Bluetooth power saving off: a controller on a USB Bluetooth dongle lags or
# drops when the dongle sleeps between packets, and a desktop has no battery to save.
# Read when btusb loads: from the next start
options btusb enable_autosuspend=0
EOF
  # the sound card's codec never napping: Fedora's kernel lets it power down after a second
  # of silence (power_save=1), and it clicks in the speakers as it wakes — at every volume
  # change, every notice. Off when the driver loads, and off now (no restart needed)
  write_file /etc/modprobe.d/fedokawaii-audio.conf <<'EOF'
# Fedokawaii — the sound card's codec never powers down between sounds: waking, it clicks in
# the speakers (a desktop has no battery to save). Read when snd_hda_intel loads
options snd_hda_intel power_save=0
EOF
  if [[ -w /sys/module/snd_hda_intel/parameters/power_save ]]; then
    echo 0 >/sys/module/snd_hda_intel/parameters/power_save || true
  fi
  # sleep is suspend alone — never hibernation (memory written to disk), nor its mixes: a
  # desktop that sleeps only when asked, with its swap in compressed memory (zram), has no use
  # for them, and a hibernation that cannot resume loses the session
  write_file /etc/systemd/sleep.conf.d/90-fedokawaii.conf <<'EOF'
# Fedokawaii — suspend only: no hibernation, hybrid sleep or suspend-then-hibernate
[Sleep]
AllowHibernation=no
AllowHybridSleep=no
AllowSuspendThenHibernate=no
EOF
  # every sleep is locked first: a keyboard's Sleep key is dwl's (kawa-power sleep: the lock,
  # then the sleep), not logind's, which would sleep first and lock as it wakes; any other
  # sleep waits for the lock (swayidle's before-sleep: kawa-lock waits up to 10 s).
  # (Some keyboards' Sleep key sends KEY_SUSPEND, which logind takes for the hibernate key:
  # that one is dwl's too.) And a restart or shut down, whoever asks, waits for Steam to close
  # properly while the desktop still runs (kawa-steam --guard: it sends your games' saves to
  # Steam Cloud as it closes, done in a few seconds) — logind's wait for both, 25 s at most
  write_file /etc/systemd/logind.conf.d/90-fedokawaii.conf <<'EOF'
# Fedokawaii — the Sleep key is the desktop's (locked, then asleep), whichever key code it
# sends (KEY_SLEEP: logind's suspend key; KEY_SUSPEND: its hibernate key); a sleep from
# elsewhere waits for the lock, a restart or shut down for Steam to close properly (its saves
# to Steam Cloud). Read by systemd-logind when it starts: from the next start
[Login]
HandleSuspendKey=ignore
HandleSuspendKeyLongPress=ignore
HandleHibernateKey=ignore
HandleHibernateKeyLongPress=ignore
InhibitDelayMaxSec=25
EOF
}

# The project's earlier name was Scriptorium. What an install under that name put on the
# system is taken out, so none of it runs beside this one: its kernel-prune timer and resume
# service, its dnf hooks (a second snapshot per transaction), its dconf defaults (another
# GTK theme and a close button in every title bar). Its greeter goes once the login points
# at kawa-greet. Only those exact paths; nothing in your home (README lists those).
retire_old_name() {
  local u f found=0
  for u in scrip-kernel-prune.timer scrip-kernel-prune.service scriptorium-resume.service; do
    [[ -e /etc/systemd/system/$u ]] || continue
    found=1; systemctl disable --now "$u" >/dev/null 2>&1 || true; rm -f "/etc/systemd/system/$u"
  done
  for f in /etc/dnf/libdnf5.conf.d/90-scriptorium.conf \
           /etc/dnf/libdnf5-plugins/actions.d/scriptorium-snapper.actions \
           /etc/dconf/db/local.d/00-scriptorium /usr/local/sbin/scrip-kernel-prune /usr/local/sbin/scrip-snap; do
    [[ -e $f ]] || continue
    found=1; rm -f "$f"
  done
  if [[ -e /usr/local/bin/scrip-greeter ]] && ! grep -qs scrip-greeter /etc/greetd/config.toml; then
    found=1; rm -f /usr/local/bin/scrip-greeter
  fi
  ((found)) || return 0
  systemctl daemon-reload
  command -v dconf >/dev/null && dconf update
  log "Scriptorium (this project's old name): its system files are out — what it left in your home is listed in README"
}

phase1() {
  retire_old_name
  step "1.0 readiness check"                       s_ready
  step "1.1 record user-installed packages"        s_baseline
  step "1.2 dnf5 tuning"                           s_dnf
  step "1.3 boot menu"                              s_boot
  step "1.4 full system update"                    s_update
  step "1.5 base packages"                         s_base
  step "1.5b performance: tuned profile, Wi-Fi"      s_tuning
  step "1.6 remove nano, vim, rescue kernel"       s_trim
  step "1.6b a quiet boot: kernel arguments, blank console" s_quiet_boot
  step "1.7 inbound SSH ($SSH_SERVER)"               s_ssh
  reboot_to 2
}

# ═════════════════════════════════════════════════════════════════════════════
#  PHASE 2 — repositories, GPU drivers, media (drivers before their consumers)
# ═════════════════════════════════════════════════════════════════════════════
# ── what waits for a repository to catch up with this Fedora ──────────────────
# RPM Fusion builds its freeworld drivers and libheif-freeworld for one exact version of the
# Fedora package they go with (their specs: mesa-filesystem = VERSION, libheif = VERSION):
# for a few days around a release, or a Mesa update, one is ahead of the other and dnf cannot
# install them. A COPR may have no build for a new release yet. Neither stops setup: the rest
# is installed, what waits is recorded (lib/manifest.sh, waiting), said once, and verify warns
# while it waits; update and repair try again and clear the record. Any other failure stops.
wait_add() { { waiting "$1"; echo "$2"; } | grep . | sort -u | write_file "$STATE_DIR/pending-$1" 0644; }
wait_del() {
  local rest; rest=$(waiting "$1" | grep -vxF -- "$2" || true)
  if [[ -n $rest ]]; then printf '%s\n' "$rest" | write_file "$STATE_DIR/pending-$1" 0644; else rm -f "$STATE_DIR/pending-$1"; fi
}
rf_base() {   # rf_base PKG → the Fedora package RPM Fusion's PKG is made for, version for version
  case ${1%.i686} in libheif-freeworld) echo libheif ;; mesa-*-freeworld) echo mesa-filesystem ;; esac
}
# rf_behind PKG — 0 when RPM Fusion's newest PKG is made for another version of its Fedora
# package than the newest Fedora has: the two out of step. 1 otherwise — the versions agree, or
# the repositories could not be asked (a failure is then something else)
rf_behind() {
  local base want have
  base=$(rf_base "$1"); [[ -n $base ]] || return 1
  want=$(dnf -q repoquery --latest-limit=1 --qf '%{version}\n' "${1%.i686}" 2>/dev/null | head -n1) || return 1
  have=$(dnf -q repoquery --latest-limit=1 --qf '%{version}\n' "$base" 2>/dev/null | head -n1) || return 1
  [[ -n $want && -n $have && $want != "$have" ]]
}
RF_SAID=""
rf_said() {   # rf_said PKG — why it waits, in plain words with both versions, once a run for each
  local base want have
  [[ " $RF_SAID " == *" ${1%.i686} "* ]] && return 0
  RF_SAID+=" ${1%.i686}"
  base=$(rf_base "$1")
  want=$(dnf -q repoquery --latest-limit=1 --qf '%{version}\n' "${1%.i686}" 2>/dev/null | head -n1)
  have=$(dnf -q repoquery --latest-limit=1 --qf '%{version}\n' "$base" 2>/dev/null | head -n1)
  log "${1%.i686} ${want:-?} from RPM Fusion is made for $base ${want:-?}; Fedora has $base ${have:-?} — it installs itself with the update or repair after Fedora's $base reaches ${want:-it} (Fedora's own $base works meanwhile)"
}
# rf_pair PKG — RPM Fusion's PKG made for a NEWER Fedora package than Fedora's stable updates
# have (RPM Fusion builds against the version in Fedora's testing updates, days before it
# reaches everyone): that one package, at exactly that version, taken from testing — for each
# architecture installed — and then PKG. Nothing else comes from testing. 0 done · 1 not
# possible (testing does not have that version: RPM Fusion is behind, or ahead of testing too)
rf_pair() {
  local p=${1%.i686} base want have test a mine pkgs=()
  base=$(rf_base "$p"); [[ -n $base ]] || return 1
  want=$(dnf -q repoquery --latest-limit=1 --qf '%{version}\n' "$p" 2>/dev/null | head -n1)
  have=$(dnf -q repoquery --latest-limit=1 --qf '%{version}\n' "$base" 2>/dev/null | head -n1)
  [[ -n $want && -n $have && $want != "$have" ]] || return 1
  [[ $(printf '%s\n%s\n' "$have" "$want" | sort -V | tail -n1) == "$want" ]] || return 1   # (RPM Fusion behind: wait)
  test=$(dnf -q repoquery --enablerepo=updates-testing --latest-limit=1 --qf '%{version}\n' "$base-$want" 2>/dev/null | head -n1)
  [[ $test == "$want" ]] || return 1
  for a in x86_64 i686; do rpm -q "$base.$a" >/dev/null 2>&1 && pkgs+=("$base-$want.$a"); done
  ((${#pkgs[@]})) || pkgs=("$base-$want.x86_64")
  log "$p $want needs $base $want; Fedora's stable updates have $have — $base $want taken from Fedora's testing updates (that package only), then $p"
  # (named on dnf's line, Fedora's package would become yours; it stays what it was — needed
  # by something — so verify never takes it for something you added)
  mine=$(dnf repoquery --userinstalled --qf '%{name}\n' 2>/dev/null | grep -cx "$base" || true)
  run dnf -y install --enablerepo=updates-testing "${pkgs[@]}" || return 1
  if ((mine == 0)); then run dnf -y mark dependency "$base" || true; fi
  dnf_install "$1"
}
# rf_get PKG [DNF ARG…] — RPM Fusion's PKG: 0 installed (paired with Fedora's package from its
# testing updates when RPM Fusion is a step ahead: rf_pair) · 2 out of step with Fedora,
# recorded to wait · 1 any other failure
rf_get() {
  local p=$1; shift
  # (out of step asked first: an install that cannot work is never tried — nor said as failed)
  if rf_behind "$p"; then
    if rf_pair "$p"; then wait_del rpmfusion "$p"; return 0; fi
    wait_add rpmfusion "$p"; rf_said "$p"; return 2
  fi
  dnf_install "$@" "$p" || return 1
  wait_del rpmfusion "$p"
}
rf_need() {   # rf_need PKG [DNF ARG…] — rf_get, where any failure but waiting stops the run
  local rc=0; rf_get "$@" || rc=$?
  ((rc != 1)) || die "could not install $1 (the lines above say why)"
}
# copr_on OWNER/PROJECT — the COPR enabled: 0 · 2 no build for this Fedora yet (dnf: "Chroot not
# found"), recorded to wait — its packages are left out, said once · 1 any other failure
copr_on() {
  local out rc=0
  out=$(run dnf -y copr enable "$1") || rc=$?
  printf '%s\n' "$out"
  if ((rc == 0)); then wait_del copr "$1"; return 0; fi
  grep -q 'Chroot not found in the given Copr project' <<<"$out" || return 1
  wait_add copr "$1"
  log "the COPR $1 has no build for Fedora $FEDORA_VER yet — $(copr_pkgs "$1" | tr '\n' ' ')left out until it has; update or repair adds it then"
  return 2
}
not_waiting() {   # not_waiting PKG… → those not waiting for a repository, one per line
  local w; w=$(waiting_pkgs | grep . || true)
  if [[ -z $w ]]; then printf '%s\n' "$@"; else printf '%s\n' "$@" | grep -vxF -f <(printf '%s\n' "$w") || true; fi
}
# waiting_retry — what waits, tried again (by update and repair, in manifest_sync): what is in
# leaves the record. RPM Fusion's is tried only once the versions agree
waiting_retry() {
  local c p r rc=0
  while IFS= read -r c; do
    [[ -n $c ]] || continue
    r=0; copr_on "$c" || r=$?
    if ((r == 0)); then log "the COPR $c has a build for Fedora $FEDORA_VER now — enabled"; elif ((r == 1)); then rc=1; fi
  done < <(waiting copr)
  while IFS= read -r p; do
    [[ -n $p ]] || continue
    # (no longer wanted: another GPU now, Steam's 32-bit ones with STEAM=no, or RPM Fusion's
    # Vulkan driver, which Fedora's replaced — vulkan_fedora)
    if [[ ( $p == mesa-* && $(cat "$STATE_DIR/gpu" 2>/dev/null) != amd ) || ( $p == *.i686 && $STEAM != yes ) \
          || $p == mesa-vulkan-drivers-freeworld* ]]; then
      wait_del rpmfusion "$p"; continue
    fi
    r=0; rf_get "$p" || r=$?
    if ((r == 0)); then log "$p from RPM Fusion: in now"; elif ((r == 1)); then rc=1; fi
  done < <(waiting rpmfusion)
  return "$rc"
}

s_repos() {
  wait_for_network
  local base=https://mirrors.rpmfusion.org r repos c
  pkg_installed rpmfusion-free-release || retry 3 10 dnf -y install \
    "$base/free/fedora/rpmfusion-free-release-$FEDORA_VER.noarch.rpm" \
    "$base/nonfree/fedora/rpmfusion-nonfree-release-$FEDORA_VER.noarch.rpm"

  [[ -f /etc/yum.repos.d/brave-browser.repo ]] || run dnf -y config-manager addrepo --from-repofile="$BRAVE_REPO_URL"

  # Claude Code: official signed repo. The key file must hold exactly one key, the one the
  # docs name (a second key appended to it would otherwise be trusted too); it is kept
  # locally, so dnf never fetches a key again, and the repo may only provide claude-code.
  if [[ ! -f /etc/yum.repos.d/claude-code.repo ]]; then
    local key=$KAWA_TMP/claude-code.asc keys pins
    retry 3 10 "${CURL[@]}" -o "$key" "$CLAUDE_KEY_URL"
    # (a file that is no key at all — a Wi-Fi sign-in page — holds 0 keys: said below)
    keys=$(gpg --show-keys --with-colons "$key" 2>/dev/null | grep -c '^pub:' || true)
    pins=$(gpg --show-keys --with-colons "$key" 2>/dev/null \
             | awk -F: '/^pub:/ { want = 1; next } want && /^fpr:/ { print $10; want = 0 }') || pins=""
    [[ $keys == 1 && $pins == "$CLAUDE_KEY_FPR" ]] \
      || die "Claude Code signing key: expected only $CLAUDE_KEY_FPR, the file holds $keys key(s): ${pins//$'\n'/ }"
    install -D -m 0644 "$key" /etc/pki/rpm-gpg/RPM-GPG-KEY-claude-code
    rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-claude-code
    write_file /etc/yum.repos.d/claude-code.repo <<EOF
[claude-code]
name=Claude Code
baseurl=$CLAUDE_REPO_BASEURL
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-claude-code
includepkgs=claude-code
EOF
  fi
  for r in "${COPRS[@]}"; do
    c=0; copr_on "$r" || c=$?
    ((c != 1)) || die "could not enable the COPR $r (the lines above say why)"
  done
  run dnf -y upgrade --refresh                     # RPM Fusion builds now match the base libraries
  repos=$(dnf repolist --enabled)
  for r in rpmfusion-free rpmfusion-nonfree brave-browser claude-code; do
    grep -q "^$r " <<<"$repos" || die "repository $r is not enabled"
  done
}

# vulkan_fedora — RPM Fusion's Vulkan driver (an earlier setup's), 64- and 32-bit, swapped for
# Fedora's own: the two conflict, so each is one dnf swap (lib/manifest.sh says why Fedora's)
vulkan_fedora() {
  local p
  for p in mesa-vulkan-drivers-freeworld mesa-vulkan-drivers-freeworld.i686; do
    wait_del rpmfusion "$p"
    pkg_installed "$p" || continue
    run dnf -y swap --allowerasing "$p" "mesa-vulkan-drivers${p#mesa-vulkan-drivers-freeworld}" || return 1
  done
}

# (AMDGPU_ARG, the kernel argument LACT needs: lib/common.sh)
amd_arg_everywhere() {   # every boot entry carries it
  local a; a=$(grubby --info=ALL 2>/dev/null | grep '^args=') || return 1
  ! grep -vqF -- "$AMDGPU_ARG" <<<"$a"
}
s_gpu() {
  local gpu; gpu=$(detect_gpu); echo "$gpu" >"$STATE_DIR/gpu"
  [[ $gpu == amd || $gpu == intel ]] \
    || die "no AMD or Intel GPU found (the cards are: $gpu) — the desktop is built on their open drivers; a card the kernel does not drive yet: set GPU= in fedokawaii.conf"
  log "GPU: $gpu"
  vulkan_fedora || die "could not put Fedora's Vulkan driver in place of RPM Fusion's (the lines above say why)"
  dnf_install "${PKG_GPU_COMMON[@]}"
  if [[ $gpu == amd ]]; then
    # RPM Fusion's freeworld drivers (H.264 and HEVC) wait while they are out of step with
    # Fedora's Mesa (rf_get): Fedora's own work meanwhile, and update or repair swaps them in.
    # VA: since Fedora 44 Fedora's VA drivers live inside mesa-dri-drivers (which obsoletes
    # mesa-va-drivers), and RPM Fusion's build installs beside it. Never --allowerasing for
    # it: a conflict must stop the run, not take mesa-dri-drivers — and the desktop — with it
    if pkg_installed mesa-va-drivers; then run dnf -y swap mesa-va-drivers mesa-va-drivers-freeworld
    else rf_need mesa-va-drivers-freeworld; fi
    # (Vulkan: Fedora's own, in PKG_GPU_COMMON above — lib/manifest.sh says why)
    # (and LACT, from its COPR — left out while that has no build for this Fedora: s_repos)
    local amd_pkgs; mapfile -t amd_pkgs < <(not_waiting "${PKG_GPU_amd[@]}")
    dnf_install "${amd_pkgs[@]}"
    if pkg_installed lact; then systemctl enable lactd.service; fi
    run grubby --update-kernel=ALL --args="$AMDGPU_ARG"
  else
    run dnf -y install "${PKG_GPU_intel[@]}" --allowerasing
  fi
}

# s_hardware — what this machine's own hardware needs (lib/hardware.sh: the firmware the
# kernel did not find, the CPU's microcode, Wi-Fi's parts, the sound DSP's firmware),
# installed and recorded as part of the manifest; then the device firmware updates fwupd
# knows of, listed (never applied: fwupdmgr update is yours to run)
s_hardware() {
  local want=() need=() p rc=0 fw
  mapfile -t want < <(hw_wanted | grep . | sort -u)
  for p in "${want[@]}"; do pkg_installed "$p" || need+=("$p"); done
  if ((${#need[@]})); then
    log "this machine needs: $(IFS=' '; echo "${need[*]}")"
    run dnf -y install --skip-unavailable "${need[@]}" || rc=1
  fi
  { cat "$STATE_DIR/hardware-pkgs" 2>/dev/null; for p in "${want[@]}"; do pkg_installed "$p" && echo "$p"; done; } \
    | grep . | sort -u | write_file "$STATE_DIR/hardware-pkgs" 0644 || true
  for p in "${need[@]}"; do pkg_installed "$p" || { log "$p could not be installed — repair tries again"; rc=1; }; done
  # new microcode is loaded early, from the initramfs: made again now, not at the next kernel
  for p in "${need[@]}"; do
    if [[ $p == microcode_ctl || $p == amd-ucode-firmware ]] && pkg_installed "$p"; then
      log "the CPU's microcode: the boot images made again, so the next start loads it early"
      run dracut -f --regenerate-all || rc=1; break
    fi
  done
  # NetworkManager's Wi-Fi part, new: NetworkManager takes up its plugins only as it starts —
  # restarted now (if it runs), so the radio is managed before verify looks; the connection
  # it drops meanwhile is waited for
  for p in "${need[@]}"; do
    if [[ $p == NetworkManager-wifi ]] && pkg_installed "$p"; then
      log "NetworkManager's Wi-Fi part is in: NetworkManager restarted, so it manages the radio now"
      run systemctl try-restart NetworkManager.service || rc=1
      wait_for_network; break
    fi
  done
  # a device driver missing altogether is a kernel matter: said, so it is known
  while IFS= read -r p; do [[ -n $p ]] && log "no driver holds this device: $p (lspci -nnk names it)"; done < <(hw_driverless)
  if command -v fwupdmgr >/dev/null; then
    fwupdmgr refresh >>"$LOG_FILE" 2>&1 || true     # (2: already fresh — fine)
    fw=$(hw_fw_updates)
    printf '%s\n' "$fw" | grep . | write_file "$STATE_DIR/fw-updates" 0644 || : >"$STATE_DIR/fw-updates"
    [[ -z $fw ]] || log "firmware updates for this machine's devices: $(tr '\n' ';' <<<"$fw") — fwupdmgr update applies them, when you choose"
  fi
  return "$rc"
}

# (in setup, a driver package that will not install yet never stops the build: the desktop
# comes up without it, and update and repair try again)
s_hardware_setup() { s_hardware || log "some of this machine's drivers or firmware are not in yet — update and repair try again"; }

s_media() {
  # full ffmpeg first, so mpv & co. link against it instead of pulling ffmpeg-free
  if pkg_installed ffmpeg-free; then run dnf -y swap ffmpeg-free ffmpeg --allowerasing
  else run dnf -y install ffmpeg --allowerasing; fi
  local media; mapfile -t media < <(printf '%s\n' "${PKG_MEDIA[@]}" | grep -vx libheif-freeworld)
  dnf_install "${media[@]}"
  # HEVC for HEIF photos: RPM Fusion's, made for one exact libheif — it waits like the drivers
  rf_need libheif-freeworld
  local e enc
  enc=$(ffmpeg -hide_banner -encoders 2>/dev/null) \
    || die "ffmpeg does not start (ffmpeg -version says why) — when RPM Fusion's build is behind one of Fedora's libraries, run setup again in a day or two"
  for e in libx264 libx265 libsvtav1 libaom-av1; do grep -qw "$e" <<<"$enc" || die "ffmpeg lacks encoder $e"; done
}

phase2() {
  wait_for_network; tidy_after_cut
  step "2.1 repositories (RPM Fusion, Brave, Claude Code, COPR)" s_repos
  step "2.2 GPU drivers + amdgpu kernel argument"                s_gpu
  step "2.2b this machine's drivers and firmware"                s_hardware_setup
  step "2.3 ffmpeg (RPM Fusion) + media tools"                   s_media
  reboot_to 3
}

# ═════════════════════════════════════════════════════════════════════════════
#  PHASE 3 — compositor, session, desktop, apps, upstream tools, gate, finish
# ═════════════════════════════════════════════════════════════════════════════
s_build() {
  dnf_install "${PKG_BUILD[@]}"
  # dwl's own copy of wlroots (lib/common.sh: wlr_keep), kept for good from here on
  wlr_keep || die "wlroots $DWL_WLROOTS is not in this Fedora (it has $(wlr_has)) — install on a Fedora that ships it (44 or 45)"
  ok "wlroots $DWL_WLROOTS kept for dwl: $(wlr_home)"
}

# dwl_keep_yours SRC — before dwl's folder is put back to the pin, your own work in it is set
# aside, never thrown away: a HEAD of yours as a branch, edits beyond src/dwl/dwl.patch and
# new files as a stash (cd ~/.local/src/dwl; git branch · git stash list). The patch's own
# changes are told apart by their lines.
dwl_keep_yours() {
  local src=$1 head stamp mine patch
  [[ -d $src/.git ]] || return 0
  stamp=$(date +%Y%m%d-%H%M%S)
  head=$(as_user git -C "$src" rev-parse HEAD 2>/dev/null) || return 0
  # (upstream's own commits — a fresh clone stands on its newest — are not yours)
  if [[ $head != "$DWL_COMMIT" && -z $(as_user git -C "$src" branch -r --contains HEAD 2>/dev/null) ]]; then
    as_user git -C "$src" branch -f "before-fedokawaii-$stamp" HEAD
    log "dwl: your HEAD ${head:0:12} kept as the branch before-fedokawaii-$stamp (~/.local/src/dwl)"
  fi
  [[ -n $(as_user git -C "$src" status --porcelain 2>/dev/null) ]] || return 0
  mine=$(as_user git -C "$src" diff HEAD | grep -E '^[-+]' | grep -vE '^(\+\+\+|---) ' | LC_ALL=C sort | sha256sum) || mine=""
  patch=$(grep -E '^[-+]' "$REPO_DIR/src/dwl/dwl.patch" | grep -vE '^(\+\+\+|---) ' | LC_ALL=C sort | sha256sum)
  if [[ $mine != "$patch" || -n $(as_user git -C "$src" ls-files --others --exclude-standard 2>/dev/null) ]]; then
    as_user git -C "$src" -c user.name=fedokawaii -c user.email=fedokawaii@localhost \
      stash push --quiet --include-untracked -m "before fedokawaii $stamp"   # (a stash needs a name)
    log "dwl: your changes in ~/.local/src/dwl kept as a stash (git stash list there)"
  fi
}
# checkout_sound SRC — a source folder whose .git is no repository (a clone a stopped run cut
# off in its first moment, a home put back from a backup that left .git out) would fail
# every later fetch, for good, with a message about the network: it is moved aside, said,
# and the line after clones afresh. (One git can still read is left alone, whatever its state:
# fetch and checkout put it right.)
checkout_sound() {
  local src=$1 aside
  [[ -d $src/.git ]] || return 0
  as_user git -C "$src" rev-parse --git-dir >/dev/null 2>&1 && return 0
  aside="$src.damaged-$(date +%Y%m%d-%H%M%S)"
  as_user mv -- "$src" "$aside" || die "${src/#$TARGET_HOME/\~}/.git is no git repository (a clone a stopped run cut off?) — move the folder away, then run again"
  log "${src/#$TARGET_HOME/\~}/.git was no git repository (a clone a stopped run cut off?) — moved to ${aside/#$TARGET_HOME/\~}; cloning again"
}
s_dwl() {
  local src=$TARGET_HOME/.local/src/dwl
  as_user mkdir -p "$TARGET_HOME/.local/src"
  checkout_sound "$src"
  # (Codeberg has its slow minutes: a transfer slower than 1 KB/s for a minute is given up
  # and tried again — a stalled connection would otherwise hold the clone for ever)
  local slow=(-c http.lowSpeedLimit=1000 -c http.lowSpeedTime=60)
  [[ -d $src/.git ]] || retry 3 10 as_user git "${slow[@]}" clone --quiet https://codeberg.org/dwl/dwl.git "$src"
  retry 3 10 as_user git -C "$src" "${slow[@]}" fetch --quiet --tags --force \
    || die "could not fetch dwl from codeberg.org — try again in a while (reachable, and still refused: the checkout may be damaged — move ${src/#$TARGET_HOME/\~} away, then run again)"
  [[ $(as_user git -C "$src" rev-parse "$DWL_TAG^{commit}") == "$DWL_COMMIT" ]] \
    || die "dwl tag $DWL_TAG does not point at the pinned commit $DWL_COMMIT — refusing to build"
  dwl_keep_yours "$src"
  as_user git -C "$src" checkout --quiet --force "$DWL_COMMIT"
  as_user git -C "$src" clean -fdxq -e config.h
  # src/dwl/dwl.patch: keybindings read the first layout (us), so Super+Q etc. keep working
  # while Arabic is active; gappx pixels of gap between tiled windows; full window
  # borders, on one window at a time; floating windows open centred; a click outside a
  # menu closes it; a monitor plugged in later is set up again (kawa-display --hotplug);
  # a new mode on one monitor leaves the others side by side; the active keyboard layout
  # is printed for the bar; a drawing tablet's pen reaches drawing apps as a pen (pressure,
  # tilt) and is the mouse everywhere else; on SIGUSR1 (kawa-theme, when the theme
  # switches) the borders take the theme's colours and the pointers are loaded again.
  # git apply refuses (and setup stops) if upstream ever changes the lines it touches.
  # (the patch is fed on stdin, so the repo may live where the user cannot read it)
  as_user git -C "$src" apply --check - <"$REPO_DIR/src/dwl/dwl.patch" \
    || die "src/dwl/dwl.patch no longer applies to $DWL_COMMIT — review before building"
  as_user git -C "$src" apply - <"$REPO_DIR/src/dwl/dwl.patch"
  # upstream defaults until theme.sh installs src/dwl/config.h; both define what the patch adds
  [[ -f $src/config.h ]] || as_user cp "$src/config.def.h" "$src/config.h"
  if ! { grep -q '^static const unsigned int gappx' "$src/config.h" && grep -q 'bordercolor\[3\]\[4\]' "$src/config.h"; }; then
    die "$src/config.h predates src/dwl/dwl.patch (gaps, frames) — run Theme, or delete it to start from upstream defaults"
  fi
  local args; mapfile -t args < <(dwl_make_args)
  # built by you from clean (make does not see a changed WLR_LIBS); installed by root as a
  # copy of the one file (take_built): root runs nothing in your folders
  as_user make -C "$src" clean >>"$LOG_FILE" 2>&1
  as_user make -C "$src" -j"$(nproc)" "${args[@]}" >>"$LOG_FILE" 2>&1
  take_built "$src/dwl" /usr/local/bin/dwl 0755 || die "dwl was not built (see $LOG_FILE)"
  rm -f /usr/local/bin/dwl.prev                           # (the build before it, an earlier version kept: one dwl)
  [[ $(as_user /usr/local/bin/dwl -v 2>&1) == *"${DWL_TAG#v}"* ]] || die "installed dwl is not $DWL_TAG"
  grep -q libxcb <<<"$(as_user ldd /usr/local/bin/dwl)" || die "dwl was built without XWayland"
  grep -qF "$(wlr_home)/lib/libwlroots" <<<"$(as_user ldd /usr/local/bin/dwl)" || die "dwl is not linked to its own wlroots"
}

install_start_dwl() {   # the session launcher, with the keyboard from fedokawaii.conf
  local t; t=$(mktemp)
  sed "s|@KB_LAYOUTS@|$KB_LAYOUTS|; s|@KB_TOGGLE@|$KB_TOGGLE|" "$REPO_DIR/system/start-dwl" >"$t"
  install -m 0755 "$t" /usr/local/bin/start-dwl; rm -f "$t"
}

s_session() {
  dnf_install "${PKG_SESSION[@]}"
  grep -qw greetd <<<"$(semodule -l)" || die "greetd SELinux module not loaded"
  id greetd >/dev/null 2>&1 || die "greetd user missing"
  install_start_dwl
  greetd_config
  # greetd is enabled only in the last step, after verify.sh has passed
}
greetd_config() {   # the login: the greeter, its look, and greetd pointed at our own file of it
  local t d
  install -m 0755 "$REPO_DIR/system/kawa-greet" /usr/local/bin/
  rm -f /usr/local/bin/kawa-greeter                      # (the text login before it)
  # its look, both themes (the greeter's own user reads them): the lock screen's colours and
  # pictures, so the two are one design
  for t in dark light; do
    d=/usr/local/share/fedokawaii/greeter/$t
    install -d -m 0755 "$d"
    install -m 0644 "$REPO_DIR/configs/home/.config/fedokawaii/themes/$t/gtklock.css" \
      "$REPO_DIR/configs/home/.local/share/fedokawaii/$t/"{padlock,seal-1,seal-2,seal-3,seal-4,seal-5,seal-6,seal-7}.png "$d/"
  done
  # which theme it wears: a folder of yours, where kawa-theme notes the one you switch to
  install -d -m 0755 -o "$TARGET_UID" -g "$TARGET_GID" /var/lib/fedokawaii-greeter
  # the theme it wears from the start (THEME); kawa-theme keeps it the one you last had
  [[ -s /var/lib/fedokawaii-greeter/theme ]] \
    || printf '%s\n' "$THEME" | install -m 0644 -o "$TARGET_UID" -g "$TARGET_GID" /dev/stdin /var/lib/fedokawaii-greeter/theme
  # the lock's and login's two messages in the desktop's words (kawa-lock: LANGUAGE=fk)
  install -D -m 0644 "$REPO_DIR/art/gtklock.mo" /usr/share/locale/fk/LC_MESSAGES/gtklock.mo
  # the pixel font crisp for every account (the greeter's too): /etc/fonts
  install -m 0644 "$REPO_DIR/system/60-fedokawaii-pixel.conf" /etc/fonts/conf.d/
  # greetd's own config.toml stays the package's: ours is a file of its own, and greetd is
  # pointed at it (so updates never meet a changed file, and leave no .rpmnew behind)
  write_file /etc/greetd/fedokawaii.toml <<EOF
# /etc/greetd/fedokawaii.toml — installed by setup.sh (greetd reads it: greetd.service.d/
# fedokawaii.conf). The login screen: kawa-greet in cage (one full-screen window, -d: no
# window frame, -s: Ctrl+Alt+F2… still reach the text consoles), for $TARGET_USER — with the
# desktop's pointer of the theme you last had, on the card the desktop draws on (start-dwl
# --gpu: WLR_DRM_DEVICES, or nothing). Its own messages and the greeter's go to the journal
# (journalctl -t kawa-greet), never over the screen. greetd runs this line through /bin/sh.
[terminal]
vt = 1

[default_session]
command = "env \$(/usr/local/bin/start-dwl --gpu) \\"XCURSOR_THEME=Sumi-\$(cat /var/lib/fedokawaii-greeter/theme)\\" systemd-cat -t kawa-greet cage -d -s -- /usr/local/bin/kawa-greet $TARGET_USER"
user = "greetd"
EOF
  # greetd's own unit with this desktop's drop-in. A login screen that cannot start (its
  # greeter crashing) makes greetd stop: systemd starts it again — five times within a minute,
  # two seconds apart — and then gives up. Never for ever: each start takes tty1 back, so an
  # endless loop would pull you off the text console you are mending it from, every few
  # seconds. Given up, it says so on tty1 (fedokawaii-login-failed) — never a black screen
  # with nothing to go on, never another login in its place
  write_file /etc/systemd/system/greetd.service.d/fedokawaii.conf <<'EOF'
# installed by setup.sh: greetd reads fedokawaii.toml, and owns tty1 alone (Fedora 45 runs
# kmscon there, earlier releases agetty). It starts once the boot splash has gone
# (plymouth-quit-wait): never beside it, the two taking the screen from each other. A login
# screen that keeps stopping: five tries in a minute, then fedokawaii-login-failed says so
[Unit]
Conflicts=getty@tty1.service kmsconvt@tty1.service
After=getty@tty1.service kmsconvt@tty1.service plymouth-quit-wait.service
StartLimitIntervalSec=60
StartLimitBurst=5
OnFailure=fedokawaii-login-failed.service

[Service]
ExecStart=
ExecStart=/usr/bin/greetd --config /etc/greetd/fedokawaii.toml
Restart=always
RestartSec=2
EOF
  write_file /etc/systemd/system/fedokawaii-login-failed.service <<'EOF'
# installed by setup.sh — greetd gave up (its login screen stopped five times in a minute):
# said on tty1, with the way back, instead of a black screen
[Unit]
Description=Fedokawaii: the login screen could not start (said on tty1)

[Service]
Type=oneshot
StandardOutput=tty
StandardError=journal
TTYPath=/dev/tty1
TTYReset=yes
ExecStart=/usr/bin/printf '\033[?25h\n  The login screen could not start: it stopped five times in a row.\n\n  Ctrl+Alt+F2 opens a text console. Log in there, then:\n\n      fedokawaii repair               finds what broke and fixes it\n      sudo systemctl restart greetd   the login screen again\n\n  Why it stopped: journalctl -b -u greetd -t kawa-greet\n\n'
EOF
  systemctl daemon-reload
  restorecon -R /usr/local/bin /usr/local/share/fedokawaii /etc/greetd /etc/fonts/conf.d /var/lib/fedokawaii-greeter
}

s_desktop() {
  dnf_install "${PKG_DESKTOP[@]}"
  systemctl enable bluetooth.service
  i2c_dev
  as_user xdg-user-dirs-update
}
i2c_dev() {   # i2c-dev at every boot (monitor brightness over DDC/CI), and now: ddcutil ships
  # a modules-load file for it; ours stays should a later ddcutil drop it
  printf '%s\n' "# the monitors' I2C buses for ddcutil (kawa-brightness) — setup.sh" i2c-dev \
    | write_file /etc/modules-load.d/fedokawaii-i2c.conf 0644
  modprobe i2c-dev
}
s_look()    { dnf_install "${PKG_LOOK[@]}"; }
# (tree-sitter-cli recommends "nodejs", Node 22: never taken — exclude_from_weak, s_dnf)
s_apps()    { dnf_install "${PKG_APPS[@]}"; }

s_upstream() {
  local e; for e in "${UPSTREAM[@]}"; do install_upstream_bin "$e"; done
  install_nerd_fonts
  install_fusion
  s_localsend
}
# LocalSend (lib/upstream.sh): never a reason to stop — the gate, update and repair try again
s_localsend() {
  contained install_localsend
  ((CONTAINED_RC == 0)) || log "LocalSend is not installed yet (why: above, or $LOG_FILE) — update and repair try again"
}
# Syncplay (lib/upstream.sh): never a reason to stop — update and repair try again
s_syncplay() {
  contained install_syncplay
  ((CONTAINED_RC == 0)) || log "Syncplay is not installed yet (why: above, or $LOG_FILE) — update and repair try again"
}
# ble.sh (lib/upstream.sh): never a reason to stop — the shell is plain bash without it, and
# the gate, update and repair try again
s_blesh() {
  contained install_blesh
  ((CONTAINED_RC == 0)) || log "ble.sh is not installed yet (why: above, or $LOG_FILE) — the gate, update and repair try again"
}

# ── lpf's leftovers ──────────────────────────────────────────────────────────
# Spotify is its web player now (the launcher's Spotify: open.spotify.com in a Brave app
# window); its app was built here by lpf until then. lpf, lpf-spotify-client and the
# spotify-client it built are RETIRED_PKGS: handed back to dnf, whose clean-up (r_hygiene)
# takes them — /etc/sudoers.d/pkg-build goes with lpf's package. What a package's removal
# never takes goes here once lpf is gone: its build account (the user and group pkg-build,
# which lpf made) and /var/lib/lpf (that account's home: the recipe's state, its build
# folders, Spotify's download, the logs). Update and repair; nothing while lpf is installed.
lpf_leftovers_out() {
  pkg_installed lpf && return 0
  local gone=()
  if [[ -e /var/lib/lpf ]]; then rm -rf --one-file-system -- /var/lib/lpf || return 1; gone+=(/var/lib/lpf); fi
  if getent passwd pkg-build >/dev/null; then userdel pkg-build || return 1; gone+=("the user pkg-build"); fi
  if getent group pkg-build >/dev/null; then groupdel pkg-build || return 1; gone+=("the group pkg-build"); fi
  if [[ -e /etc/sudoers.d/pkg-build.rpmsave ]]; then rm -f /etc/sudoers.d/pkg-build.rpmsave; gone+=(/etc/sudoers.d/pkg-build.rpmsave); fi
  ((${#gone[@]})) || return 0
  local e; printf -v e '%s · ' "${gone[@]}"
  log "lpf's leftovers (it built Spotify's app here once) removed: ${e% · }"
}

# ── the file dialog: yazi, through xdg-desktop-portal-termfilechooser ────────
# Not packaged for Fedora, so built like dwl: hunkyburrito's fork (the maintained one) at
# the pinned tag, which must resolve to the pinned commit; configured, compiled and staged
# as you in ~/.local/src, then its four files copied to /usr/local by root (root writes
# nothing in your home), the portal file last, once the binary has been seen to run. There
# xdg-desktop-portal (≥ 1.20.1 reads $XDG_DATA_DIRS), D-Bus and systemd --user find it.
# kawa-pick (bin/) is the wrapper it runs: the samples it ships are left out.
# It is the only file dialog (wlroots-portals.conf names no other, and GTK apps go through the
# portal: GTK_USE_PORTAL=1): if any of it fails, nothing is installed, verify says so as a
# failure, and update and repair build it again.
TFC_REPO=https://github.com/hunkyburrito/xdg-desktop-portal-termfilechooser.git
TFC_BIN=/usr/local/libexec/xdg-desktop-portal-termfilechooser
TFC_FILES=(/usr/local/lib/systemd/user/xdg-desktop-portal-termfilechooser.service
           /usr/local/share/dbus-1/services/org.freedesktop.impl.portal.desktop.termfilechooser.service
           /usr/local/share/xdg-desktop-portal/portals/termfilechooser.portal)   # (in this order)
tfc_current() {   # installed at TFC_TAG, runs, and the portals, D-Bus and systemd can find it
  local f
  [[ $(as_user "$TFC_BIN" -v 2>/dev/null) == "xdg-desktop-portal-termfilechooser ${TFC_TAG#v}" ]] || return 1
  for f in "${TFC_FILES[@]}"; do [[ -f $f ]] || return 1; done
}
build_filechooser() {
  local src=$TARGET_HOME/.local/src/xdg-desktop-portal-termfilechooser stage f
  [[ ${TFC_TAG:-} =~ ^v[0-9]+\.[0-9]+(\.[0-9]+)?$ && ${TFC_COMMIT:-} =~ ^[0-9a-f]{40}$ ]] \
    || die "fedokawaii.conf: TFC_TAG must look like v1.4.3, TFC_COMMIT be its 40-character commit"
  { command -v meson >/dev/null && pkg-config --exists inih libsystemd; } \
    || die "meson, inih-devel or systemd-devel missing (lib/manifest.sh, PKG_BUILD) — update installs them"
  stage=$src/build/stage
  as_user mkdir -p "$TARGET_HOME/.local/src"
  checkout_sound "$src"
  [[ -d $src/.git ]] || retry 3 10 as_user git clone --quiet "$TFC_REPO" "$src" || die "could not clone $TFC_REPO"
  retry 3 10 as_user git -C "$src" fetch --quiet --tags --force || die "could not fetch $TFC_REPO"
  [[ $(as_user git -C "$src" rev-parse "$TFC_TAG^{commit}") == "$TFC_COMMIT" ]] \
    || die "termfilechooser tag $TFC_TAG does not point at the pinned commit $TFC_COMMIT — refusing to build"
  as_user git -C "$src" checkout --quiet --force "$TFC_COMMIT"
  as_user git -C "$src" clean -fdxq
  # -Dwerror=false: upstream builds with -Werror, and a newer compiler's new warning must not
  # fail a pinned release · no man page (no scdoc) · sd-bus from systemd · its user unit
  as_user meson setup "$src/build" "$src" --prefix=/usr/local --buildtype=release -Dwerror=false \
    -Dman-pages=disabled -Dsd-bus-provider=libsystemd -Dsystemd=enabled >>"$LOG_FILE" 2>&1
  as_user meson compile -C "$src/build" >>"$LOG_FILE" 2>&1
  as_user meson install -C "$src/build" --no-rebuild --destdir "$stage" >>"$LOG_FILE" 2>&1
  for f in "$TFC_BIN" "${TFC_FILES[@]}"; do
    [[ -f $stage$f && ! -L $stage$f ]] || die "the termfilechooser build did not make $f"
  done
  [[ $(as_user "$stage$TFC_BIN" -v 2>/dev/null) == "xdg-desktop-portal-termfilechooser ${TFC_TAG#v}" ]] \
    || die "the termfilechooser just built does not run"
  take_built "$stage$TFC_BIN" "$TFC_BIN" 0755 || die "could not install $TFC_BIN"
  for f in "${TFC_FILES[@]}"; do take_built "$stage$f" "$f" 0644 || die "could not install $f"; done
  restorecon "$TFC_BIN"; restorecon -R /usr/local/lib/systemd /usr/local/share/dbus-1 /usr/local/share/xdg-desktop-portal
  # a user manager already running (linger keeps one) learns of the new unit and D-Bus name now
  if [[ -S /run/user/$TARGET_UID/bus ]]; then
    as_user systemctl --user daemon-reload || true
    as_user busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus ReloadConfig >/dev/null 2>&1 || true
  fi
  tfc_current || die "termfilechooser $TFC_TAG is not in place after installing it"
  ok "file dialogs: yazi (termfilechooser $TFC_TAG) — the portals take it up at the next login"
}
s_filechooser() {
  contained build_filechooser
  ((CONTAINED_RC == 0)) || log "no file dialog yet: termfilechooser did not build (why: above, or $LOG_FILE), and the portals name only it — update or repair build it"
}

# ── torrents: Prowlarr (a rootless container) finds them, torrra downloads them ──
# One API key between the two. Its master copy is ~/.config/fedokawaii/secrets.sh (yours,
# 600): Prowlarr gets it as a podman secret (podman keeps that copy in its own store, yours
# alone), torrra from kawa-torrra in memory — never in a program's settings, never on a
# command line.
TORRRA_VENV=.local/share/pipx/venvs/torrra

prowlarr_image() { sed -n 's/^Image=//p' "$REPO_DIR/system/prowlarr.container"; }   # (the one place it is named)
prowlarr_key() {   # → the key, made in secrets.sh the first time (or if it is not valid)
  local sec=$TARGET_HOME/.config/fedokawaii/secrets.sh key
  as_user install -d -m 700 "$TARGET_HOME/.config/fedokawaii"
  # a plain file of yours, never followed through a link (this runs as root)
  [[ -L $sec ]] && die "$sec is a symbolic link — make it a plain file (mode 600) and run again"
  [[ -e $sec ]] || as_user install -m 600 /dev/null "$sec"
  [[ $(stat -c %u "$sec") == "$TARGET_UID" ]] || chown -h "$TARGET_UID:$TARGET_GID" "$sec"
  as_user chmod 600 "$sec"
  # shellcheck disable=SC2016  # expanded by the user's bash, after sourcing the file
  key=$(as_user bash -c '. "$1" >/dev/null 2>&1; printf %s "${PROWLARR_API_KEY:-}"' _ "$sec")
  if [[ ! $key =~ ^[0-9a-f]{32}$ ]]; then
    # 32 hex characters starting with a letter: nothing along the way can take it for a number
    key=""
    until [[ $key =~ ^[a-f][0-9a-f]{31}$ ]]; do key=$(od -An -N16 -tx1 /dev/urandom | tr -d ' \n'); done
    as_user sed -i -e '/^# Prowlarr ↔ torrra/d' -e '/^[[:space:]]*\(export[[:space:]]\+\)\?PROWLARR_API_KEY=/d' "$sec"
    if [[ -s $sec && -n $(tail -c1 "$sec") ]]; then printf '\n' | as_user tee -a "$sec" >/dev/null; fi
    printf '# Prowlarr ↔ torrra (made by setup.sh; Prowlarr is handed it again at every update)\nPROWLARR_API_KEY=%s\n' "$key" \
      | as_user tee -a "$sec" >/dev/null
  fi
  # (not exported: only kawa-torrra reads it, from this file, so no other program you start
  # carries it in its environment)
  printf %s "$key"
}

prowlarr_accepts() {   # the key ($PROWLARR_KEY) goes to curl on stdin, never as an argument
  printf 'header = "X-Api-Key: %s"\n' "$PROWLARR_KEY" \
    | as_user curl -fsS --max-time 5 -K - -o /dev/null http://127.0.0.1:9696/api/v1/health
}

# Prowlarr's container file installed or refreshed, files an older setup left owned by a
# container user handed back, the key handed over — and Prowlarr restarted only when one of
# these changed. Setup and every update.
prowlarr_up() {
  local dir=$TARGET_HOME/.config/containers/systemd data=$TARGET_HOME/.config/prowlarr
  local image key restart=0 was=0
  image=$(prowlarr_image)
  as_user mkdir -p "$dir" "$data"
  as_user systemctl --user is-active --quiet prowlarr.service && was=1
  key=$(prowlarr_key) && [[ $key =~ ^[0-9a-f]{32}$ ]] \
    || die "Prowlarr's key could not be read or made — secrets.sh must be a plain file of yours, mode 600"
  if ! cmp -s "$REPO_DIR/system/prowlarr.container" "$dir/prowlarr.container"; then
    # written by you, not by root: the folder is yours, and a link in it leads nowhere root's
    as_user tee "$dir/prowlarr.container" <"$REPO_DIR/system/prowlarr.container" >/dev/null \
      && as_user chmod 644 "$dir/prowlarr.container" || die "could not write $dir/prowlarr.container"
    restart=1
  fi
  if [[ -n $(find "$data" ! -user "$TARGET_USER" -print -quit) ]]; then
    as_user systemctl --user stop prowlarr.service 2>/dev/null || true
    run as_user podman unshare chown -R 0:0 "$data" || die "could not hand ~/.config/prowlarr back to you"
    restart=1
  fi
  if [[ $(as_user podman secret inspect --showsecret --format '{{.SecretData}}' prowlarr-api-key 2>/dev/null) != "$key" ]]; then
    printf %s "$key" | as_user podman secret create --replace prowlarr-api-key - >/dev/null \
      || die "podman did not take Prowlarr's key"
    restart=1
  fi
  if ! as_user podman image exists "$image"; then
    retry 3 20 as_user podman pull --quiet "$image" >/dev/null || die "could not fetch the Prowlarr image ($image)"
  fi
  as_user systemctl --user daemon-reload
  if ((restart)) || ! as_user systemctl --user is-active --quiet prowlarr.service; then
    # Notify=healthy: this returns once Prowlarr answers (first start: up to a few minutes).
    # One that does not start is stopped again: left, Restart=on-failure would try it every
    # 10 s until the next boot
    run as_user systemctl --user restart prowlarr.service \
      || { as_user systemctl --user stop --no-block prowlarr.service || true; die "Prowlarr did not start — journalctl --user -u prowlarr"; }
  fi
  # (retry logs the command it repeats: the key travels in the environment, not in its words)
  PROWLARR_KEY=$key retry 10 3 prowlarr_accepts \
    || { ((was)) || as_user systemctl --user stop --no-block prowlarr.service || true
         die "Prowlarr does not take the key from secrets.sh — journalctl --user -u prowlarr"; }
  # the sites torrra searches through: the usual public ones, each added once (those you
  # have, or switched off, are left as they are) — never a reason to stop: one Prowlarr cannot
  # reach now is added all the same, and a run that could not add one says so
  local out
  if out=$(printf %s "$key" | as_user python3 -I "$REPO_DIR/system/prowlarr-indexers.py" 2>&1); then log "$out"
  else log "Prowlarr's indexers: not all added — $(tr '\n' ' ' <<<"$out")(update and repair try again)"; fi
  # it runs on demand (torrra's search, `prowlarr`): checked, it goes back to sleep — unless
  # it was already running when this began
  ((was)) || as_user systemctl --user stop --no-block prowlarr.service || true
}

# torrra itself: Python 3.13 (libtorrent has wheels only up to 3.13), its command wrapped
# by kawa-torrra, and its settings: Prowlarr as the indexer, best-seeded results first,
# downloads in ~/Downloads, the terminal's own colours — and no key in them
torrra_up() {
  local py=$TARGET_HOME/$TORRRA_VENV/bin/python old=$TARGET_HOME/.local/bin/torrra
  # (torrra.app: the whole program loads — Textual, Rich and httpx with it, not only libtorrent)
  local probe='import sys, importlib.metadata as m, torrra, libtorrent, torrra.__main__, torrra.app; sys.exit(m.version("torrra") != sys.argv[1])'
  if ! as_user "$py" -I -c "$probe" "$TORRRA_VERSION" 2>/dev/null; then
    # its libraries at the versions torrra was released with (system/torrra-constraints.txt),
    # and pipx's own `torrra` command kept in pipx's folder: on your PATH it would run torrra
    # without the key — `torrra` is kawa-torrra's
    retry 3 20 run as_user env PIPX_HOME="$TARGET_HOME/.local/share/pipx" PIPX_BIN_DIR="$TARGET_HOME/.local/share/pipx/bin" \
      pipx install --force --python python3.13 --pip-args="-c $REPO_DIR/system/torrra-constraints.txt" "torrra==$TORRRA_VERSION" \
      || die "torrra did not install"
  fi
  as_user "$py" -I -c "$probe" "$TORRRA_VERSION" || die "torrra $TORRRA_VERSION is installed but does not load (libtorrent, or a library under it)"
  # pipx's `torrra` an older setup left in ~/.local/bin (a link into its venv): gone
  if [[ -L $old && $(readlink -- "$old") == */pipx/venvs/torrra/* ]]; then as_user rm -f -- "$old"; fi
  install -m 0755 "$REPO_DIR/system/kawa-torrra" /usr/local/bin/kawa-torrra
  install -m 0644 "$REPO_DIR/system/kawa-torrra.profile.sh" /etc/profile.d/kawa-torrra.sh
  restorecon /usr/local/bin/kawa-torrra /etc/profile.d/kawa-torrra.sh
  as_user mkdir -p "$TARGET_HOME/.config/torrra"
  as_user "$py" -I - "$TARGET_HOME/.config/torrra/config.toml" "$TARGET_HOME/Downloads" <<'PY'
import os, sys, tomllib, tomli_w
path, downloads = sys.argv[1], sys.argv[2]
try:
    with open(path, "rb") as f:
        cfg = tomllib.load(f)
except FileNotFoundError:
    cfg = {}
except tomllib.TOMLDecodeError as e:     # yours, with a slip in it: left exactly as it is
    print(f"~/.config/torrra/config.toml does not read as TOML ({e}) — left as it is; fix it or delete it")
    sys.exit(0)
g = cfg.setdefault("general", {})
g.setdefault("download_path", downloads)
g.setdefault("default_sort", "seeders")
if g.get("theme") in (None, "gruvbox", "textual-dark", "ansi-light"):   # what older setups chose
    g["theme"] = "ansi-dark"                             # foot's 16 colours, right on both themes
idx = cfg.setdefault("indexers", {})
idx["default"] = "prowlarr"
p = idx.setdefault("prowlarr", {})
p["url"] = "http://127.0.0.1:9696"
p.pop("api_key", None)
tmp = path + ".tmp"
with open(tmp, "wb") as f:
    tomli_w.dump(cfg, f)
os.replace(tmp, path)
PY
}

# ~/Downloads as its own btrfs subvolume, so /home's snapshots leave it out: the space of
# a deleted download comes back at once, not when the last snapshot holding it expires.
# Made only while the folder is still empty (and before snapper's /home config exists).
downloads_subvolume() {
  local d=$TARGET_HOME/Downloads mode=755
  [[ $(stat -f -c %T "$TARGET_HOME") == btrfs ]] && command -v btrfs >/dev/null || return 0
  btrfs subvolume show "$d" >/dev/null 2>&1 && return 0
  if [[ -e $d ]]; then
    mode=$(stat -c %a "$d")
    as_user rmdir -- "$d" 2>/dev/null || { log "your Downloads folder already holds files — it stays inside /home's snapshots"; return 0; }
  fi
  # made by you (a subvolume is yours to make in your own folder): root touches nothing there
  run as_user btrfs subvolume create "$d"
  as_user chmod "$mode" "$d"; restorecon "$d"
}

s_torrents() {
  # rootless podman needs subordinate user and group IDs (Fedora's installer normally makes
  # them); a range past every one already given out, so it never overlaps another user's
  local f start
  for f in subuid subgid; do
    grep -q "^$TARGET_USER:" "/etc/$f" && continue
    start=$(awk -F: 'BEGIN { m = 100000 } { if ($2 + $3 > m) m = $2 + $3 } END { print m }' "/etc/$f")
    usermod "--add-${f}s" "$start-$((start + 65535))" "$TARGET_USER"
  done
  # linger: your user manager runs without a login too, so update, repair and verify (as
  # root, from a text console as well) can reach your services — Prowlarr, the portals
  loginctl enable-linger "$TARGET_USER"
  user_stop
  retry 15 2 test -S "/run/user/$TARGET_UID/bus" || die "user systemd instance did not start"
  as_user podman system migrate >/dev/null 2>&1 || true      # picks up new sub-IDs
  downloads_subvolume
  torrra_up
  prowlarr_up
  open_ports
}
user_stop() {   # with linger your own systemd runs until shutdown: then it never holds the machine long
  write_file /etc/systemd/system/user@.service.d/fedokawaii.conf <<'EOF'
# installed by setup.sh — with linger, Prowlarr and the portals stop at shutdown: your own
# systemd has 30 s for all of them, then what is left is ended. 30 s, not less: a container
# writing its database needs a moment
[Service]
TimeoutStopSec=30s
EOF
  systemctl daemon-reload
}
OPEN_PORTS=(6881/tcp 6881/udp "$LOCALSEND_PORT/tcp" "$LOCALSEND_PORT/udp")
open_ports() {   # torrra's port and LocalSend's, open in the firewall (when firewalld runs: otherwise said)
  local p
  firewall-cmd -q --state 2>/dev/null || { log "firewalld is not running — the ports of torrra (6881) and LocalSend ($LOCALSEND_PORT) are left as they are"; return 0; }
  # asked first, then added where missing — saved and running alike — so a repair changes
  # nothing when it is open already, and never reloads firewalld (a reload drops what other
  # programs added while it runs: Docker's rules, should you install it)
  for p in "${OPEN_PORTS[@]}"; do
    firewall-cmd -q --permanent --query-port="$p" || firewall-cmd -q --permanent --add-port="$p"
    firewall-cmd -q --query-port="$p" || firewall-cmd -q --add-port="$p"
  done
}

s_lazyvim() {
  if [[ ! -f $TARGET_HOME/.config/nvim/init.lua ]]; then
    local t; t=$(as_user mktemp -d)
    retry 3 10 as_user git clone --quiet --depth 1 https://github.com/LazyVim/starter "$t"
    as_user rm -rf "$t/.git"
    as_user mkdir -p "$TARGET_HOME/.config/nvim"
    as_user cp -rn "$t/." "$TARGET_HOME/.config/nvim/"; as_user rm -rf "$t"
  fi
  run as_user timeout 900 nvim --headless '+Lazy! sync' +qa
}

s_gaming() {
  [[ $STEAM == yes ]] || return 0
  # Steam needs 32-bit Mesa: Fedora's Vulkan driver, named, so that no other build of it is
  # picked for Steam; on AMD also RPM Fusion's VA driver, as the 64-bit one (out of step with
  # Fedora's Mesa, it waits with its 64-bit one — Fedora's stands in, through Steam itself)
  local x=mesa-va-drivers-freeworld.i686
  dnf_install mesa-vulkan-drivers.i686
  if [[ $(cat "$STATE_DIR/gpu" 2>/dev/null) == amd ]]; then
    if waiting rpmfusion | grep -qx "${x%.i686}"; then wait_add rpmfusion "$x"   # (its 64-bit one waits: so does it)
    else rf_need "$x"; fi
  fi
  dnf_install "${PKG_GAMING[@]}"
  modprobe ntsync 2>/dev/null || true             # now too, not only from the next boot on
  usermod -aG gamemode "$TARGET_USER"             # gamemode's CPU/GPU boosts are for this group
  # GE-Proton comes from GitHub: down, or changed in a way this cannot follow, it must not
  # stop the build — Steam has its own Proton meanwhile, and update tries again
  contained install_ge_proton
  ((CONTAINED_RC == 0)) || log "GE-Proton is not installed yet (why: above, or $LOG_FILE) — Steam's own Proton works meanwhile; update tries again"
}

s_groups() { usermod -aG video,render "$TARGET_USER"; input_group_out; }   # (subuids: s_torrents)
# Earlier builds put you in the input group too. Nothing here needs it — logind hands the
# session its keyboard and mouse, Steam's rules (steam-devices) open a controller — and while
# you are in it, any program you run can read every key you press. Taken out once, and said;
# put back by hand (a controller no game sees: handbook §21.1), it stays — the record says so
input_group_out() {
  [[ -f $STATE_DIR/input-group-out ]] && return 0
  if [[ " $(id -nG "$TARGET_USER") " == *" input "* ]]; then
    gpasswd -d "$TARGET_USER" input >/dev/null
    log "$TARGET_USER is out of the input group (in it, any program could read every key pressed) — from the next login; a controller no game sees: handbook §21.1"
  fi
  record input-group-out "$(date +%s)"
}

s_ssh() {                       # a desktop doesn't need inbound SSH (SSH_SERVER=no)
  local z s
  if [[ $SSH_SERVER == no ]]; then systemctl disable --now sshd.service 2>/dev/null || true
  else systemctl enable --now sshd.service; fi
  # the firewall's ports to match — firewalld is Fedora Server's, and running; if it is not,
  # sshd's state above is what counts, and that is said rather than stopping the run
  z=$(firewall-cmd --get-default-zone 2>/dev/null) \
    || { log "firewalld is not running — its ssh/cockpit ports are left as they are"; return 0; }
  # asked first, then changed where needed — saved and running alike — so nothing is reloaded:
  # a reload drops what other programs added while firewalld runs (Docker's rules, should you
  # install it), and a repair that finds the ports right changes nothing
  if [[ $SSH_SERVER == no ]]; then
    for s in ssh cockpit; do
      if firewall-cmd -q --permanent --zone="$z" --query-service="$s"; then
        firewall-cmd -q --permanent --zone="$z" --remove-service="$s"
      fi
      if firewall-cmd -q --zone="$z" --query-service="$s"; then
        firewall-cmd -q --zone="$z" --remove-service="$s"
      fi
    done
  else
    firewall-cmd -q --permanent --zone="$z" --query-service=ssh || firewall-cmd -q --permanent --zone="$z" --add-service=ssh
    firewall-cmd -q --zone="$z" --query-service=ssh || firewall-cmd -q --zone="$z" --add-service=ssh
  fi
}

s_theme() {
  [[ -f $STATE_DIR/with-theme ]] || { log "theme not requested (menu → Theme, any time)"; return 0; }
  run bash "$REPO_DIR/theme.sh" --user "$TARGET_USER"
}
s_gate() {
  # from here on repair may run too (do_repair): everything is installed, only the login waits
  : >"$STATE_DIR/gate-reached"
  # packages left twice by a transaction a power cut stopped (a restart mid-phase): the older go
  tidy_duplicates || log "dnf could not tidy packages installed twice — verify names them"
  # (a driver package phase 2 could not install, or a device plugged in since: tried again —
  # so are the parts that come from GitHub and may not have come: GE-Proton, the file dialog)
  s_hardware_setup
  if [[ $STEAM == yes && -z $(up_tag ge-proton) ]]; then
    contained install_ge_proton
    ((CONTAINED_RC == 0)) || log "GE-Proton is still not installed — Steam's own Proton works meanwhile; update tries again"
  fi
  tfc_current || s_filechooser
  syncplay_current || s_syncplay
  localsend_current || s_localsend
  blesh_current || s_blesh
  # (and LazyVim's plugins: 3.09 is done once nvim has run, even when GitHub let some clones
  # fail — then only nvim itself fetches them again; repair cannot run before the build ends)
  if [[ ! -d $TARGET_HOME/.local/share/nvim/lazy/LazyVim ]]; then
    contained r_nvim
    ((CONTAINED_RC == 0)) || log "LazyVim's plugins could not be fetched yet (why: above, or $LOG_FILE)"
  fi
  # the last check: what it finds is repaired here and now — the same fixes as fedokawaii
  # repair — and checked again; only what is still wrong after that stops setup
  if ! run bash "$REPO_DIR/verify.sh" --pre-finalize; then
    local net=1
    log "verify found problems (above) — setup repairs them now, as fedokawaii repair would, and checks again"
    online || { net=0; log "offline: only what needs no network is repaired"; }
    heal_all "$net"
    run bash "$REPO_DIR/verify.sh" --pre-finalize \
      || die "verify still finds problems after repairing (above): each line says what to do — then run setup again (it resumes here)"
    ok "repaired: verify passes now"
  fi
}

# snapshots kept within bounds for a machine left alone for months: ranges, so the clean-up
# removes more when space runs low (FREE_LIMIT: a fifth of the disk stays free), hourly ones
# for a few hours, daily ones for a week, at most two monthly ones, none for years — so a
# deleted file's space comes back within two months at most (sooner when space runs low)
# snapper_has NAME — snapper has a config NAME: its file, which is what snapper keeps (read
# directly: list-configs is a table whose layout changes between snapper versions)
snapper_has() { [[ -f /etc/snapper/configs/$1 ]]; }
# snapper_configs — the configs for / and, when it is Btrfs, /home (setup's end, and repair)
snapper_configs() {
  snapper_has root || run snapper -c root create-config / || return 1
  if [[ $(findmnt -no FSTYPE /home) == btrfs ]]; then
    snapper_has home || run snapper -c home create-config /home || return 1
  fi
  return 0
}
snapper_limits() {
  local c
  for c in root home; do
    snapper_has "$c" || continue
    run snapper -c "$c" set-config NUMBER_LIMIT=4-20 NUMBER_LIMIT_IMPORTANT=4-10 TIMELINE_LIMIT_HOURLY=2-8 \
      TIMELINE_LIMIT_DAILY=2-7 TIMELINE_LIMIT_WEEKLY=0 TIMELINE_LIMIT_MONTHLY=0-2 TIMELINE_LIMIT_YEARLY=0 FREE_LIMIT=0.2
  done
}

# s_scrub — once a month, every block of the Btrfs file system read back and checked
# against its checksum (btrfs scrub): a disk that starts to fail shows up in verify long
# before a file is lost. Idle I/O priority, so the desktop never waits on it.
s_scrub() {
  [[ $(findmnt -no FSTYPE / 2>/dev/null) == btrfs ]] || { log "/ is not Btrfs — no scrub"; return 0; }
  write_file /etc/systemd/system/fedokawaii-scrub.service <<'UNIT'
# installed by setup.sh — the monthly check of the Btrfs file system (handbook §38.2)
[Unit]
Description=Fedokawaii: read every block of the Btrfs file system and check it (btrfs scrub)
ConditionPathIsMountPoint=/

[Service]
Type=oneshot
# -B: wait for the end (so the journal has the result) · -c 3: idle I/O, the desktop first
ExecStart=/usr/bin/btrfs scrub start -B -c 3 /
Nice=19
UNIT
  write_file /etc/systemd/system/fedokawaii-scrub.timer <<'UNIT'
# installed by setup.sh — once a month, at a random hour of its first day (Persistent: a
# machine that was off then catches up at its next start)
[Unit]
Description=Fedokawaii: the monthly Btrfs scrub

[Timer]
OnCalendar=monthly
RandomizedDelaySec=1d
Persistent=true

[Install]
WantedBy=timers.target
UNIT
  systemctl daemon-reload
  systemctl enable --now fedokawaii-scrub.timer
}
# s_report — the machine's health in one file (fedokawaii-report: ~/fedokawaii-report.txt),
# made by itself once, at the first start of the finished desktop: it waits for your session,
# reads everything (the install, verify, the journal, the session's parts, the network, the
# timings) and leaves the verdict at the file's top. Again at any time: `fedokawaii report`.
# Once only: the marker it leaves (/var/lib/fedokawaii/report-first.done) keeps it from the
# starts after.
s_report() {
  write_file /etc/systemd/system/fedokawaii-report.service <<'UNIT'
# installed by setup.sh — the health report, once, at the first start of the finished desktop
[Unit]
Description=Fedokawaii: the health report after the first start (~/fedokawaii-report.txt)
After=graphical.target network-online.target
Wants=network-online.target
ConditionPathExists=!/var/lib/fedokawaii/report-first.done

[Service]
Type=oneshot
ExecStart=/usr/local/bin/fedokawaii-report --boot
ExecStartPost=/usr/bin/touch /var/lib/fedokawaii/report-first.done
Nice=10
TimeoutStartSec=15min

[Install]
WantedBy=graphical.target
UNIT
  systemctl daemon-reload
  systemctl enable --quiet fedokawaii-report.service
}
snap_hooks() {   # pre/post snapshots around every dnf transaction
  install -m 0755 "$REPO_DIR/system/kawa-snap" /usr/local/sbin/kawa-snap
  write_file /etc/dnf/libdnf5-plugins/actions.d/fedokawaii-snapper.actions <<'EOF'
# pre/post snapper snapshots around every dnf transaction (libdnf5-plugin-actions); dnf's
# own process id is passed, so each snapshot is named by the command that made it
pre_transaction::::/usr/local/sbin/kawa-snap pre ${pid}
post_transaction::::/usr/local/sbin/kawa-snap post ${pid}
EOF
  restorecon -R /usr/local/sbin /etc/dnf
}

s_finalize() {
  install_toolkit                                  # (once more: a run that never rebooted)
  systemctl enable greetd.service
  systemctl set-default graphical.target
  restorecon -R "$TARGET_HOME" /usr/local
  # snapshots: config for / (and /home), timers, and pre/post around every dnf transaction
  snapper_configs
  snapper_limits
  systemctl enable --now snapper-timeline.timer snapper-cleanup.timer
  systemctl enable --now fstrim.timer              # weekly TRIM (Fedora's preset, made explicit)
  s_scrub                                          # the monthly Btrfs scrub
  s_report                                         # the health report, after the first start
  # the tidying before the baseline (a snapshot would keep every cached download for good) and
  # before the snapshot hooks (its autoremove is no change worth a snapshot); none of it can
  # stop a finished build
  dnf_unneeded_out || true
  clean_caches || true
  snap_hooks
  run snapper -c root create -d "fedokawaii baseline"     # no cleanup algorithm: kept until you delete it
  record setup-done "$(date +%s)"                  # (the menu's title: "set up 17 Oct")
  record_snapshots                                 # (the menu's count: the baseline included)
  # the phase, then the resume unit, go last: should anything above fail, the next start
  # carries on here (holding greetd back meanwhile, its Conflicts=). "done" is written before
  # the unit goes: taking away the unit this very run may be part of can end the run with it
  # (seen on the real machine: TERM straight after) — the build is complete by then. (So the
  # baseline still holds both: a rollback to it ends the build once more at its next start.)
  set_phase 'done'
  remove_resume_unit
  # (the clone goes after the final check, at the very end of phase3: this run may still be
  # reading its scripts from it)
}
dnf_unneeded_out() {   # dependencies nothing needs any more (a build step's, a swap's): taken out
  local list
  list=$(hy_unneeded)
  [[ -n $list ]] || return 0
  log "no longer needed by anything: $(tr '\n' ' ' <<<"$list")"
  run dnf -y autoremove
}

# clone_done — the very last thing a build, an update or a repair does: the folder it was
# started from (your clone of the project, or where you unpacked a download) goes — the
# toolkit holds all of it now, and `fedokawaii copy` makes a working copy whenever you want to
# change something — with the download it came from (NAME.zip or NAME.tar.gz beside it or in
# ~/Downloads, unless that one is newer) and the folder it stood in when that is left empty.
# Nothing of yours goes with it:
#   · anything that may be your own — files that differ from the toolkit, a fedokawaii.conf
#     changed after the run read it, in git a change, an untracked file, a stash, a commit on
#     any branch or a tag not on GitHub — and the whole folder is first packed into
#     ~/.local/state/fedokawaii/started-from-TIME.tar.gz (should that fail, nothing is removed)
#   · a folder that is not the project's alone (other things beside the project's files, as
#     when a download was unpacked straight into ~/Downloads): only the project's own files go
#   · never: a working copy (`fedokawaii copy`'s, or git with other worktrees), a standard
#     folder, a mount point, the toolkit, anything outside your home
# Everything is removed as you, never as root: nothing can lead it outside your home.
clone_done() {
  local d=${STARTED_FROM:-} why="" a parent name pack own=() other=() e
  if [[ -z $d ]]; then
    d=$(head -n1 "$STATE_DIR/started-from" 2>/dev/null) || return 0
  fi
  rm -f "$STATE_DIR/started-from"; STARTED_FROM=""
  [[ -n $d && -d $d && ! -L $d && $d == "$TARGET_HOME"/?* && $d != "$TOOLKIT" ]] || return 0
  [[ -f $d/setup.sh && -f $d/fedokawaii.sh && -f $d/lib/manifest.sh ]] || return 0
  case ${d#"$TARGET_HOME"/} in
    Desktop|Documents|Downloads|Music|Pictures|Public|Templates|Videos|repos|Drives)
      log "${d/#$TARGET_HOME/\~} kept: it is one of your standard folders — the project's files in it are yours to tidy"; return 0 ;;
  esac
  if mountpoint -q -- "$d" || [[ -n $(find "$d" -mindepth 1 -xdev -type d -exec mountpoint -q {} \; -print -quit 2>/dev/null) ]]; then
    log "${d/#$TARGET_HOME/\~} kept: a drive is mounted in it"; return 0
  fi
  if [[ $d == "$TARGET_HOME/repos/fedokawaii" || -f $d/.git/fedokawaii-conf-base ]]; then
    log "${d/#$TARGET_HOME/\~} kept: it is your working copy (fedokawaii copy)"; return 0
  fi
  if [[ -e $d/.git ]] && (($(as_user git -C "$d" worktree list 2>/dev/null | wc -l) > 1)); then
    log "${d/#$TARGET_HOME/\~} kept: git has other worktrees of it"; return 0
  fi
  # what stands in it: the project's own entries (PROJECT_TOP, lib/common.sh), and anything else
  local -A top=()
  for e in "${PROJECT_TOP[@]}"; do top[$e]=1; done
  while IFS= read -r -d '' e; do
    e=${e##*/}
    if [[ -v top[$e] ]]; then own+=("$e"); else other+=("$e"); fi
  done < <(find "$d" -mindepth 1 -maxdepth 1 -print0)
  if [[ -n $(find "$d" -path "$d/.git" -prune -o ! -type f ! -type d -print -quit) ]]; then why="it holds links"
  elif ! cmp -s "$d/fedokawaii.conf" "$STATE_DIR/conf-from-copy.conf" && ! cmp -s "$d/fedokawaii.conf" "$TOOLKIT/fedokawaii.conf"; then
    why="its fedokawaii.conf changed after this run read it"
  elif [[ -n $(diff -rq --exclude=.git --exclude=fedokawaii.conf "$d" "$TOOLKIT" 2>&1) ]]; then
    why="it differs from the toolkit"
  elif [[ -e $d/.git ]]; then
    if [[ -n $(as_user git -C "$d" status --porcelain --untracked-files=normal -- . ':!fedokawaii.conf' 2>&1) ]]; then why="git has changes in it"
    elif [[ -n $(as_user git -C "$d" stash list 2>&1) ]]; then why="git has a stash in it"
    elif [[ $(as_user git -C "$d" rev-list --count --branches --tags --not --remotes 2>/dev/null || echo x) != 0 ]]; then why="git has commits or tags not on GitHub"
    fi
  fi
  # the download it came from (taken before the folder goes): only one fetched before the folder was
  # unpacked. The folder's change time says when that was: unzip and tar set its modified time back
  # to the commit's, but nothing can set its change time back
  name=${d##*/} parent=${d%/*}
  local downloads=() unpacked
  unpacked=$(stat -c %Z -- "$d")
  for a in "$parent/$name".{zip,tar.gz,tgz} "$TARGET_HOME/Downloads/$name".{zip,tar.gz,tgz}; do
    [[ -f $a && ! -L $a ]] && (($(stat -c %Y -- "$a") <= unpacked)) && downloads+=("$a")
  done
  if [[ -n $why ]]; then
    pack=$TARGET_HOME/.local/state/fedokawaii/started-from-$(date +%Y%m%d-%H%M%S).tar.gz
    if ! as_user mkdir -p "${pack%/*}" || ! as_user tar -czf "$pack" -C "$parent" -- "$name" 2>>"$LOG_FILE"; then
      as_user rm -f -- "$pack"
      log "${d/#$TARGET_HOME/\~} kept: $why, and it could not be packed first (is the disk full?) — delete it yourself when you are done with it"
      return 0
    fi
    log "${d/#$TARGET_HOME/\~}: $why — the whole folder is kept, packed, in ${pack/#$TARGET_HOME/\~}"
  fi
  # (this run started from it: whatever it still reads comes from the toolkit from here on —
  # bash keeps reading this script from the file it opened, gone or not)
  [[ $REPO_DIR != "$d" ]] || REPO_DIR=$TOOLKIT
  if ((${#other[@]})); then
    # not the project's alone: its own entries go, the rest stays where it is
    (cd "$d" && as_user rm -rf --one-file-system -- "${own[@]}") \
      || { log "${d/#$TARGET_HOME/\~}: the project's files could not all be removed — delete them yourself"; return 0; }
    printf -v e '%s, ' "${other[@]:0:5}"
    log "${d/#$TARGET_HOME/\~}: the project's files removed; the rest is yours and stays (${e%, }$( ((${#other[@]} > 5)) && echo ' …'))"
    return 0
  fi
  as_user rm -rf --one-file-system -- "$d" || { log "${d/#$TARGET_HOME/\~} could not be removed — delete it yourself"; return 0; }
  log "${d/#$TARGET_HOME/\~} removed: the toolkit has all of it (a terminal still inside it: cd ~)"
  for a in "${downloads[@]}"; do
    as_user rm -f -- "$a" && log "${a/#$TARGET_HOME/\~} removed: the download it came from"
  done
  # the folder it stood in, now empty: gone too — never your home, a hidden one, or one of
  # the standard folders (Downloads, Documents…, ~/repos, ~/Drives)
  case ${parent##*/} in Desktop|Documents|Downloads|Music|Pictures|Public|Templates|Videos|repos|Drives|.*) return 0 ;; esac
  if [[ $parent != "$TARGET_HOME" && -d $parent && ! -L $parent && -z $(ls -A -- "$parent") ]]; then
    as_user rmdir -- "$parent" && log "${parent/#$TARGET_HOME/\~} removed: empty once it was gone"
  fi
  return 0
}

# clean_caches — what a build, an update or a repair leaves behind and nothing reads again:
# dnf's downloaded packages; pip's and npm's download caches (torrra, neovim's language
# servers: fetched again if ever needed); the toolkit's half-made copies and the temp folders
# of runs a power cut stopped; Prowlarr's images it no longer runs; and the theme's backups
# of your replaced files beyond the newest ten runs. Never what is used: dnf's metadata, the
# sources dwl and the file dialog are rebuilt from, the plugins
clean_caches() {
  local f n
  run dnf clean packages >/dev/null 2>&1 || true
  # (as you: in your home root never deletes through a path you could have made a link)
  as_user rm -rf --one-file-system -- "$TARGET_HOME/.cache/pip" "$TARGET_HOME/.npm/_cacache" "$TARGET_HOME/.npm/_npx" 2>/dev/null || true
  rm -rf -- /root/.cache/pip 2>/dev/null
  for f in "${TMPDIR:-/var/tmp}"/fedokawaii.*; do
    [[ -d $f && $f != "${KAWA_TMP:-}" ]] && rm -rf -- "$f"
  done
  toolkit_back; rm -rf -- "$TOOLKIT.new" "$TOOLKIT.old"
  as_user podman image prune -f >/dev/null 2>&1 || true
  n=$(prune_theme_backups as_user)                  # (as you: nothing can lead root elsewhere)
  f=$TARGET_HOME/.local/state/fedokawaii/backup
  ((n)) && log "the theme's $n oldest backup folder(s) removed (the newest $THEME_BACKUPS_KEPT kept: ${f/#$TARGET_HOME/\~})"
  return 0
}

phase3() {
  wait_for_network; tidy_after_cut
  step "3.01 build dependencies"                       s_build
  step "3.02 dwl $DWL_TAG (pinned commit)"             s_dwl
  step "3.03 login: greetd + kawa-greet + SELinux"        s_session
  step "3.04 desktop stack"                            s_desktop
  step "3.05 fonts, icons, toolkit themes"             s_look
  step "3.06 applications"                             s_apps
  step "3.07 upstream binaries (checksummed)"          s_upstream
  step "3.07b file dialog: yazi (termfilechooser ${TFC_TAG:-})" s_filechooser
  step "3.07c Syncplay $SYNCPLAY_TAG (pinned commit, no window)" s_syncplay
  step "3.07e ble.sh ${BLESH_COMMIT:0:7} (pinned commit: the shell's typing)" s_blesh
  step "3.08 Prowlarr + torrra (wired together)"       s_torrents
  step "3.09 LazyVim + plugins"                        s_lazyvim
  step "3.10 Steam + GE-Proton"                        s_gaming
  step "3.11 groups"                                   s_groups
  step "3.12 theme (only if chosen)"                   s_theme
  step "3.12b one kernel (the newest)"                 one_kernel
  step "3.13 verify gate"                              s_gate
  step "3.14 enable login, snapshots, baseline"        s_finalize
  bash "$REPO_DIR/verify.sh" || die "final verification failed — see above"
  clone_done || true
  hdr "Fedokawaii is built — rebooting into the login screen in 15 s"
  (( NO_REBOOT )) && exit 0
  sleep 15; systemctl reboot
}

# ═════════════════════════════════════════════════════════════════════════════
#  the season's records: what the `fedokawaii` menu shows (world-readable, one line each)
# ═════════════════════════════════════════════════════════════════════════════
record() {   # record NAME LINE — /var/lib/fedokawaii/NAME, replaced in one step
  printf '%s\n' "$2" | write_file "$STATE_DIR/$1" 0644
}
record_snapshots() {   # how many snapshots there are (the menu cannot ask: snapper is root's)
  # (snapper's own 0 is the running system, not a snapshot; none left is a count too: 0 —
  # snapper not answering leaves the record as it was)
  local list
  list=$(snapper -c root --csvout list --columns number 2>/dev/null) || return 0
  record snapshots "$(awk 'NR > 1 && /^[1-9][0-9]*$/ { n++ } END { print n + 0 }' <<<"$list")" || true
  return 0
}
space_free() {   # space_free PATH → bytes free (Btrfs: its own estimate, which counts snapshots)
  local f=""
  if [[ $(findmnt -no FSTYPE --target "$1" 2>/dev/null) == btrfs ]]; then
    # "    Free (estimated):     123456789      (min: 61728394)"
    f=$(btrfs filesystem usage -b "$1" 2>/dev/null | awk '/Free \(estimated\)/ { print $3; exit }') || f=""
  fi
  [[ $f =~ ^[0-9]+$ ]] || f=$(df -B1 --output=avail "$1" 2>/dev/null | tail -n1 | tr -dc 0-9) || f=""
  echo "${f:-0}"
}
need_space() {   # need_space PATH MiB — stop, saying what to do, when there is not room enough
  local f; f=$(space_free "$1")
  ((f >= $2 * 1024 ** 2)) && return 0
  die "only $(numfmt --to=iec --suffix=B "$f") free on $1 — this needs $(numfmt --to=iec --suffix=B $(($2 * 1024 ** 2))): delete old snapshots (fedokawaii snapshots, then sudo snapper -c root delete --sync N: --sync waits until Btrfs has freed the space), empty the trash, clear caches (handbook §38.2)"
}

# the package transaction as a system service of its own: a closed window, a desktop that
# stops, or systemd restarting itself during the update can never cut it off halfway. Its
# output goes to the journal (no file for the service to be allowed to write: SELinux has
# no say), is followed here as it comes, and is copied into the log at the end. Never
# given a time limit.
dnf_detached() {   # dnf_detached ARG… — dnf ARG…, detached from this session; its exit status
  local unit rc IFS=' '
  unit=fedokawaii-dnf-$(date +%s)-$$
  if [[ ${RUN_SHOWN:-} == 1 ]]; then _out "${C_DIM}    (as $unit)${C_RESET}"   # (run said the command already)
  else _out "${C_DIM}$(_ts) \$ dnf $*  (as $unit)${C_RESET}"; fi
  journalctl -f -n 0 -o cat -u "$unit.service" 2>/dev/null 9>&- &
  FOLLOWER=$!
  systemd-run --quiet --unit="$unit" --service-type=exec --wait --collect \
    -p StandardOutput=journal -p StandardError=journal -p SyslogIdentifier=fedokawaii-dnf \
    -E LC_ALL=C.UTF-8 /usr/bin/dnf "$@" 9>&- && rc=0 || rc=$?
  sleep 1; kill "$FOLLOWER" 2>/dev/null || true; wait "$FOLLOWER" 2>/dev/null || true; FOLLOWER=""
  journalctl -o cat --no-pager "_SYSTEMD_UNIT=$unit.service" >>"$LOG_FILE" 2>/dev/null || true
  return "$rc"
}

# detach_dnf — from here on, every dnf that changes packages runs as dnf_detached does. Update
# and repair run in a window you can close (Super+U): the big upgrade was already its own unit,
# and now the small changes after it (the manifest's installs, swaps, removals, autoremove,
# distro-sync) are too, so closing the window never cuts a transaction in half. Queries and the
# rest (repoquery, mark, copr, makecache …) still go straight to dnf.
detach_dnf() {
  dnf() {
    local a sub=""
    for a in "$@"; do [[ $a == -* ]] || { sub=$a; break; }; done
    case $sub in
      install|remove|swap|autoremove|distro-sync|upgrade|downgrade|reinstall) dnf_detached "$@" ;;
      *) command dnf "$@" ;;
    esac
  }
}

# before an update or a move: everything that could make it go wrong, checked first, while
# nothing has changed yet
preflight() {   # preflight ROOT_MiB — space, clock, dnf's own state, nothing pending
  need_space / "$1"
  need_space /boot 300
  [[ $(timedatectl show -p NTPSynchronized --value 2>/dev/null) == yes ]] \
    || log "the clock is not synchronised yet (a wrong clock breaks downloads) — if this fails, check it: timedatectl"
  # an offline transaction armed for the next restart (dnf's /system-update link): restart
  # first. One only stored — a download a stopped move left — is cleared: never installed
  # by surprise at some later restart
  if [[ -e /system-update || -L /system-update ]]; then
    die "an earlier update is waiting to be installed at the next restart — restart first (or: sudo dnf offline clean)"
  fi
  dnf offline clean >/dev/null 2>&1 || true
  if [[ -n $(dnf -q repoquery --duplicates 2>/dev/null) ]]; then
    log "duplicate packages left by an interrupted transaction — tidied first"
    dnf_detached -y remove --duplicates || die "dnf could not tidy the duplicates — fedokawaii repair"
  fi
  dnf -q check >/dev/null 2>&1 || log "dnf check reports problems (dnf check shows them) — the update goes on; repair can help after"
}
snapshot_before() {   # snapshot_before WHAT [important] — a numbered snapshot, checked to exist.
                      # The ones before an update and before a move are marked important
                      # (kept among the last ten of those)
  local n imp=()
  [[ ${2:-} == important ]] && imp=(-u important=yes)
  n=$(snapper -c root create -t single -c number "${imp[@]}" -p -d "before $1" 2>/dev/null) || n=""
  if ! [[ $n =~ ^[0-9]+$ ]] || [[ -z $(snapper -c root --csvout list --columns number 2>/dev/null | grep -x "$n") ]]; then
    die "the snapshot before $1 could not be taken — nothing changed (sudo snapper -c root list; fedokawaii repair)"
  fi
  ok "snapshot $n: before $1"
}

# the manifest kept whole, one way for update and repair: what is missing installed (a
# package a newer Fedora no longer has is reported, not fatal), every manifest package
# marked as yours (so `dnf autoremove` never takes one that first came as a dependency),
# nothing forbidden, and the packages dropped from the manifest handed back to dnf
manifest_sync() {
  local p q avail gpu rc=0 r want=() miss=() gone=() failed=() bad=() mine=() ui others wait
  gpu=$(cat "$STATE_DIR/gpu" 2>/dev/null || echo amd)
  mapfile -t want < <(manifest_all "$gpu")
  # what waited for RPM Fusion or a COPR to catch up with this Fedora: tried again first
  waiting_retry || rc=1
  # RPM Fusion's Vulkan driver (an earlier setup's) swapped for Fedora's own, both arches
  vulkan_fedora || { log "could not put Fedora's Vulkan driver in place of RPM Fusion's — repair tries again"; rc=1; }
  # (what waits is not missing: verify warns about it, and the next update tries again)
  wait=$(waiting_pkgs)
  for p in "${want[@]}"; do grep -qxF -- "$p" <<<"$wait" && continue; pkg_provided "$p" || miss+=("$p"); done
  if ((${#miss[@]})); then
    log "missing from the manifest: $(IFS=' '; echo "${miss[*]}")"
    for p in "${miss[@]}"; do
      if ! avail=$(dnf -q repoquery --available --whatprovides "$p" 2>/dev/null); then failed+=("$p")   # could not ask (offline?)
      elif [[ -z $avail ]]; then gone+=("$p")                                                            # not in this Fedora at all
      elif ! retry 3 10 dnf -y install "$p"; then failed+=("$p"); fi                                     # there, but would not install
    done
    if ((${#failed[@]})); then
      log "could not be installed now: $(IFS=' '; echo "${failed[*]}") — the next update or repair tries again"; rc=1
    fi
  fi
  # LACT's service, once LACT is in (its COPR may have had no build when setup ran)
  if [[ $gpu == amd ]] && pkg_installed lact && ! systemctl is-enabled --quiet lactd.service 2>/dev/null; then
    systemctl enable lactd.service || rc=1
  fi
  # the list of what Fedora no longer has — rewritten only when every package could be asked about
  if ((${#failed[@]} == 0)); then
    if ((${#gone[@]})); then
      log "not in this Fedora's repositories (renamed or retired): $(IFS=' '; echo "${gone[*]}") — the rest of the desktop goes on without them"
      printf '%s\n' "${gone[@]}" | write_file "$STATE_DIR/unavailable" 0644
    else rm -f "$STATE_DIR/unavailable"; fi
  fi
  # every manifest package marked as yours, so dnf's clean-up never takes one — under the name
  # it has now (a package Fedora renamed is marked by its new name)
  ui=$(dnf repoquery --userinstalled --qf '%{name}\n' 2>/dev/null) || ui=""
  for p in "${want[@]}"; do
    if rpm -q "$p" >/dev/null 2>&1; then q=$p   # (itself, when installed: never another provider)
    else q=$(rpm -q --qf '%{NAME}\n' --whatprovides "$p" 2>/dev/null | awk 'NR == 1') || continue; fi
    [[ -n $q && $q != *' '* ]] || continue
    grep -qxF -- "$q" <<<"$ui" || mine+=("$q")
  done
  if ((${#mine[@]})); then
    mapfile -t mine < <(printf '%s\n' "${mine[@]}" | sort -u)
    run dnf -y mark user "${mine[@]}" >/dev/null || true
  fi
  # retired, or Steam's once STEAM is no: handed back to dnf (dnf autoremove clears them when
  # nothing needs them — Steam's games and settings in your home stay)
  local back=("${RETIRED_PKGS[@]}")
  [[ $STEAM == yes ]] || back+=("${PKG_GAMING[@]}")
  for p in "${back[@]}"; do
    if grep -qx "$p" <<<"$ui" && ! grep -qx "$p" "$STATE_DIR/baseline-userinstalled"; then run dnf -y mark dependency "$p" || true; fi
  done
  # (and the 32-bit drivers Steam's step added — by arch: the 64-bit ones stay)
  if [[ $STEAM != yes ]]; then
    local gi=()
    mapfile -t gi < <(dnf repoquery --userinstalled --qf '%{name}.%{arch}\n' 2>/dev/null \
                      | grep -xE 'mesa-va-drivers-freeworld\.i686|mesa-vulkan-drivers\.i686' || true)
    if ((${#gi[@]})); then run dnf -y mark dependency "${gi[@]}" || true; fi
  fi
  for p in "${FORBIDDEN_PKGS[@]}"; do if pkg_installed "$p"; then bad+=("$p"); fi; done
  if ((${#bad[@]})); then
    # never at the cost of something the desktop needs: what would go with them is looked at first
    others=$(dnf -q repoquery --installed --whatrequires="$(IFS=,; echo "${bad[*]}")" --qf '%{name}\n' 2>/dev/null \
             | grep -vxF -f <(printf '%s\n' "${FORBIDDEN_PKGS[@]}") || true)
    if [[ -n $others ]]; then
      log "left in place: $(IFS=' '; echo "${bad[*]}") — removing them would take $(tr '\n' ' ' <<<"$others")with them"
    else
      run dnf -y remove "${bad[@]}" || log "dnf could not remove $(IFS=' '; echo "${bad[*]}") — repair tries again"
    fi
  fi
  return "$rc"
}

# third-party repositories never stop dnf: one that is down, or not yet (or never) built
# for a new Fedora, is skipped with a warning instead of failing every dnf command —
# Fedora's own and RPM Fusion stay strict (the system needs them whole)
repos_lenient() {
  local r
  while read -r r; do
    [[ $r == copr:* || $r == brave-browser || $r == claude-code ]] || continue
    dnf config-manager setopt "$r.skip_if_unavailable=1" >/dev/null 2>&1 || true
  done < <(dnf repo list --all --json 2>/dev/null | jq -r '.[].id' 2>/dev/null)
}
third_party_off() {   # → --disablerepo=… for every repository that is not Fedora's or RPM Fusion's
  local r
  while read -r r; do
    if [[ $r == copr:* || $r == brave-browser || $r == claude-code ]]; then printf -- '--disablerepo=%s\n' "$r"; fi
  done < <(dnf repo list --enabled --json 2>/dev/null | jq -r '.[].id' 2>/dev/null || true)
  return 0
}
# the packages: one transaction, detached, snapshotted around (the dnf actions hook). Should
# a third-party repository fail it — a signing key changed, a repository gone — it runs again
# without them, and says so: Fedora's own updates never wait on Brave's or a COPR's
dnf_upgrade() {
  local off=() i
  for i in 1 2; do
    dnf_detached -y upgrade --refresh && return 0
    # (a transaction cut off half-way leaves packages twice, which the next try would trip on)
    tidy_duplicates || true
    if ((i == 1)); then log "the update did not go through — trying once more in 30s"; sleep 30; fi
  done
  mapfile -t off < <(third_party_off)
  ((${#off[@]})) || return 1
  log "trying again without the third-party repositories ($(IFS=' '; echo "${off[*]#--disablerepo=}"))"
  dnf_detached -y upgrade --refresh "${off[@]}" || return 1
  UPDATE_STEPS_FAILED+=("third-party packages (a repository failed: dnf repo list; the next update tries again)")
}

# ═════════════════════════════════════════════════════════════════════════════
#  --update — the season's update: one command for everything (fedokawaii update)
# ═════════════════════════════════════════════════════════════════════════════
# Only the checks before it, the snapshot and the package transaction can stop it. Every
# step after the packages runs on its own (contained): one that fails — GitHub down, a
# registry unreachable — is reported, and the rest goes on. Its outcome is recorded for the
# menu (/var/lib/fedokawaii/last-update); a run cut short is recorded as "interrupted".
UPDATE_STEPS_FAILED=()
# neovim's plugins: the versions you have now are kept first (the last six), so an update that
# breaks something can be undone (handbook: "Recipe: undo a bad update"); then brought up to date
nvim_plugins() {
  local lock=$TARGET_HOME/.config/nvim/lazy-lock.json keep=$TARGET_HOME/.local/state/fedokawaii/lazy-lock
  if [[ -f $lock && ! -L $lock ]]; then
    as_user mkdir -p "$keep"
    as_user cp -- "$lock" "$keep/lazy-lock.$(date +%Y%m%d-%H%M).json"
    as_user bash -c 'ls -1t "$1"/lazy-lock.*.json | tail -n +7 | xargs -r rm -f --' _ "$keep"
  fi
  run as_user timeout 900 nvim --headless '+Lazy! sync' +qa
}
step_on() {   # step_on WHAT FN… — one contained step; a failure is remembered, not fatal
  log "update: $1"; local what=$1; shift
  contained "$@"
  ((CONTAINED_RC == 0)) || UPDATE_STEPS_FAILED+=("$what")
}
do_update() {
  [[ $(phase) == 'done' ]] || die "finish the build first"
  detach_dnf
  # (until it gets to the end; a disk too full to hold even this: preflight says so, below)
  record last-update "$(date +%s) stopped" 2>/dev/null || true
  wait_for_network
  local newest running result=ok e every
  hdr "Fedokawaii update · Fedora $FEDORA_VER"
  toolkit_first
  preflight 10240
  snapshot_before "update $(date +%F)" important   # (counted apart from the dnf pairs: the last
                                                   # seasons' starting points outlast busy months)
  repos_lenient
  # the packages first: nothing else may stand in their way (a setting that no longer
  # applies on a later Fedora is reported below, and the packages that fix it are in)
  # (vi a script, not a link to nvim, before a new kernel's boot image is made: editor_policy)
  [[ -L /usr/local/bin/vi ]] && step_on "vi: a script for nvim (dracut follows a link into nvim)" editor_policy
  dnf_upgrade || die "dnf could not update (the lines above say why) — the snapshot taken before it is the way back (fedokawaii snapshots); try again later, or: fedokawaii repair"
  # then the system values of fedokawaii.conf, applied again — each on its own: edit it
  # (fedokawaii settings), then update (keyboard layouts take effect at the next login)
  step_on "the toolkit's command" install_toolkit
  # (a build finished before the menu read its date: the day its last phase ended)
  [[ -s $STATE_DIR/setup-done ]] || record setup-done "$(stat -c %Y "$STATE_DIR/phase" 2>/dev/null || date +%s)"
  step_on "the old name's leftovers" retire_old_name
  step_on "out of the input group (once)" input_group_out
  step_on "dnf's settings" s_dnf
  step_on "the time zone" timedatectl set-timezone "$TIMEZONE"
  step_on "the session launcher (keyboard)" install_start_dwl
  step_on "inbound SSH ($SSH_SERVER)" s_ssh
  step_on "the performance profile" s_tuning
  step_on "a quiet boot (the boot's arguments, a blank console)" s_quiet_boot
  step_on "your services' stop at shutdown" user_stop
  step_on "the manifest" manifest_sync
  step_on "the machine's own drivers and firmware" s_hardware
  step_on "nothing doubled or fighting" r_hygiene
  step_on "dwl's own wlroots" wlr_step
  # the desktop's own tools: pinned, so normally nothing to do
  for e in "${UPSTREAM[@]}"; do step_on "${e%%|*}" install_upstream_bin "$e"; done
  step_on "Nerd Fonts" install_nerd_fonts
  step_on "Fusion Pixel 12" install_fusion
  step_on "Syncplay" install_syncplay
  step_on "LocalSend" install_localsend
  step_on "ble.sh" install_blesh
  step_on "the tools this desktop no longer has" retire_upstream
  if [[ $STEAM == yes ]]; then step_on "GE-Proton" install_ge_proton; fi
  if ! tfc_current; then step_on "the yazi file dialog" build_filechooser; fi
  # torrra: libtorrent (the part that talks to the network) to its newest; torrra itself
  # held at TORRRA_VERSION and the rest as installed (only-if-needed, on purpose: an eager
  # upgrade would move the interface libraries torrra 2.5.1 was written for) — then checked,
  # and installed again if a newer Python left it unable to start
  step_on "torrra's libtorrent" run as_user env PIPX_HOME="$TARGET_HOME/.local/share/pipx" pipx runpip torrra install --quiet --upgrade \
    --upgrade-strategy only-if-needed "torrra==$TORRRA_VERSION" libtorrent
  step_on "torrra" torrra_up
  # Prowlarr's newest image, fetched now (it runs on demand: its next start uses it); the
  # images it replaced go
  step_on "Prowlarr's image" run as_user podman pull --quiet "$(prowlarr_image)"
  step_on "Prowlarr" prowlarr_up
  as_user podman image prune -f >/dev/null 2>&1 || true
  clean_caches || true                              # (what this update downloaded and no longer needs)
  step_on "neovim's plugins" nvim_plugins
  step_on "one kernel" old_kernels_out desktop                 # (last season's, once this start has proven the newest; this update's new one waits for a restart)
  step_on "the kernels' boot images (dracut)" kernel_images   # (a new kernel whose scriptlet failed)
  # the desktop's configs as this toolkit has them (yours kept in the theme's backup), then
  # sound checked under them: an update brings the whole desktop up to date, not only packages
  # dwl's source at the pinned commit (DWL_TAG/DWL_COMMIT may have moved with this toolkit
  # or the settings): fetched and checked out whole, so the theme builds the new one
  step_on "dwl at its pinned commit" r_dwl
  step_on "the theme (configs, dwl, helpers)" r_theme
  step_on "sound (PipeWire keeps running)" r_sound
  bash "$REPO_DIR/verify.sh" || result=checks
  ((${#UPDATE_STEPS_FAILED[@]} == 0)) || result=partial
  record last-update "$(date +%s) $result"
  record last-update-done "$(date +%s)"            # (the season counts from here: a run that stopped does not count)
  record_snapshots
  if ((${#UPDATE_STEPS_FAILED[@]})); then
    printf -v e '%s · ' "${UPDATE_STEPS_FAILED[@]}"
    log "not updated this time (the lines above say why; the next update tries again): ${e% · }"
  fi
  newest=$(rpm -q --last kernel-core); newest=${newest%%$'\n'*}; newest=${newest%% *}; newest=${newest#kernel-core-}
  running=$(uname -r)
  [[ $newest == "$running" ]] || hdr "kernel $newest installed — restart to use it (the one before stays, to fall back to)"
  # whether the next Fedora is out, recorded for the menu (which never has to ask)
  if released $((FEDORA_VER + 1)) >/dev/null; then log "Fedora $((FEDORA_VER + 1)) is out — the menu shows when the move to it is offered"; fi
  every=$(upkeep EVERY 90)
  clone_done || true                                # (the very last: the folder this update was run from)
  hdr "update done ($result) — the next one in $every days"
}

# ═════════════════════════════════════════════════════════════════════════════
#  --upgrade — the next Fedora release (fedokawaii upgrade)
# ═════════════════════════════════════════════════════════════════════════════
# Fedora's own way (dnf system-upgrade: everything downloaded first, installed after a
# restart, before anything else runs), with what a toolkit that is never edited needs:
#   · only a released Fedora (its release tree is published: staged ones are not readable),
#     and only once it has settled — WAIT days (upkeep.conf, 60) after its release day,
#     sooner only when yours ends within 60 days, or when asked (--now)
#   · RPM Fusion must already have it (ffmpeg, the freeworld drivers come from there);
#     a COPR that has not built for it yet is left out of the move (and skipped by dnf
#     until it has: repos_lenient)
#   · every library the desktop's own programs need must be in the new release: one dwl
#     (or its own wlroots) needs stops the move; one another of them needs is reported
#   · the system up to date first, room enough, a snapshot of / (marked important)
#   · after the restart, one run of the rest (fedokawaii-after-upgrade.service): the
#     manifest again, duplicates, torrra for the new Python, the theme, the checks, a report
upkeep() {   # upkeep KEY DEFAULT → a number from your upkeep.conf (fedokawaii remind), or DEFAULT
  local v                # — within the same bounds the menu keeps (EVERY 7–365, WAIT 0–180);
  # read as you (it is your file), and none at all — never written until `fedokawaii remind`
  # changes something — simply means the defaults
  # (a number in quotes too: the menu reads EVERY="30" as 30)
  v=$(as_user sed -n "s/^$1=[\"']\{0,1\}\([0-9]\{1,3\}\).*/\1/p" "$TARGET_HOME/.config/fedokawaii/upkeep.conf" 2>/dev/null | tail -n1) || v=""
  [[ $v =~ ^[0-9]+$ ]] || { echo "$2"; return 0; }
  v=$((10#$v))                                    # (10#: "08" is eight, not octal)
  case $1 in
    EVERY) ((v >= 7 && v <= 365)) || v=$2 ;;
    WAIT)  ((v <= 180)) || v=$2 ;;
  esac
  echo "$v"
}
# released N → Fedora N's release day (epoch) when it is out: its release tree is published
# only then (staged ones cannot be read). The tree itself is the final compose, made about a
# week before the release day: so a week after it, or today if that is sooner. Recorded in
# /var/lib/fedokawaii/release-N, for the menu. Returns 1 when it is not out (or Fedora's
# servers cannot be reached).
released() {
  local u h d
  if [[ -s $STATE_DIR/release-$1 ]]; then cat "$STATE_DIR/release-$1"; return 0; fi
  for u in "https://dl.fedoraproject.org/pub/fedora/linux/releases/$1/Everything/x86_64/os/repodata/repomd.xml" \
           "https://download.fedoraproject.org/pub/fedora/linux/releases/$1/Everything/x86_64/os/repodata/repomd.xml"; do
    h=$("${CURL[@]}" --max-time 20 -o /dev/null -D - --head "$u" 2>/dev/null) || continue
    d=$(sed -n 's/^[Ll]ast-[Mm]odified: *//p' <<<"$h" | tr -d '\r' | tail -n1)
    d=$(date -d "$d" +%s 2>/dev/null) && d=$((d + 7 * 86400)) || d=$(date +%s)
    ((d <= $(date +%s))) || d=$(date +%s)
    record "release-$1" "$d"; echo "$d"; return 0
  done
  return 1
}
support_end() {   # → this release's end of support (os-release SUPPORT_END), as an epoch
  local d; d=$(. /etc/os-release 2>/dev/null; printf '%s' "${SUPPORT_END:-}")
  [[ -n $d ]] && date -d "$d" +%s 2>/dev/null
}
libs_ready() {   # libs_ready N [--disablerepo=…] — the libraries our own builds need, all in Fedora N
                 # (asked without the repositories named: the COPRs left out of the move)?
                 # 0 yes (or only a tool's is missing: reported) · 1 one dwl needs is missing ·
                 # 2 Fedora N's repositories could not be asked (nothing is concluded)
  local f so kept provided missing=() hard=0 caps list
  local -A users=() core=()
  kept=$(wlr_home)/lib
  for f in /usr/local/bin/dwl "$kept"/*.so* /usr/local/libexec/xdg-desktop-portal-termfilechooser \
           "$TARGET_HOME"/.local/bin/{kawa-veil,kawa-clipkeep,satty,yazi,ya,lazygit}; do
    [[ -f $f ]] || continue
    while read -r so; do
      [[ -e $kept/$so ]] && continue                              # (dwl's own copies)
      [[ $so =~ ^(ld-linux|libc|libm|libdl|libpthread|librt)[.-] ]] && continue
      users[$so]+="${f##*/} "
      [[ $f == /usr/local/bin/dwl || $f == "$kept"/* ]] && core[$so]=1
    done < <(as_user readelf -d "$f" 2>/dev/null | awk '/NEEDED/ { gsub(/[][]/, "", $5); print $5 }' | sort -u)
  done
  ((${#users[@]})) || return 0
  # one question for all of them: which of these does Fedora N provide?
  caps=$(for so in "${!users[@]}"; do printf '%s()(64bit),' "$so"; done)
  provided=$(dnf -q --releasever="$1" "${@:2}" repoquery --whatprovides="${caps%,}" --qf '%{provides}\n' 2>/dev/null) \
    || { log "Fedora $1's repositories could not be asked which libraries they have"; return 2; }
  for so in "${!users[@]}"; do
    grep -qxF "${so}()(64bit)" <<<"$provided" && continue
    missing+=("$so (${users[$so]% })")
    [[ -n ${core[$so]:-} ]] && hard=1
  done
  ((${#missing[@]} == 0)) && return 0
  printf -v list '%s · ' "${missing[@]}"; log "not in Fedora $1: ${list% · }"
  ((hard == 0))
}
do_upgrade() {
  [[ $(phase) == 'done' ]] || die "finish the build first"
  local now_flag=${1:-} to=$((FEDORA_VER + 1)) out wait t r ok_rf=1 c skip=() end ans
  wait_for_network
  wait=$(upkeep WAIT 60)
  hdr "Fedora $FEDORA_VER → $to"
  out=$(released "$to") || die "Fedora $to is not released yet — nothing changed"
  # settled? WAIT days from its release day — sooner only when yours ends within 60 days
  end=$(support_end || echo 0)
  t=$(( (out + wait * 86400 - $(date +%s) + 86399) / 86400 ))
  if ((t > 0)) && [[ $now_flag != --now ]] && ! (( end > 0 && end - $(date +%s) < 60 * 86400 )); then
    die "Fedora $to is out; it settles $wait days — offered in $t day(s) (or now: fedokawaii upgrade --now)"
  fi
  # (its release tree, not its release package: that one is published months ahead)
  for r in free nonfree; do
    retry 2 10 "${CURL[@]}" -o /dev/null --head \
      "https://download1.rpmfusion.org/$r/fedora/releases/$to/Everything/x86_64/os/repodata/repomd.xml" || ok_rf=0
  done
  ((ok_rf)) || die "RPM Fusion has no Fedora $to yet — wait a little; nothing changed"
  # COPRs not built for it yet: left out of this move (their packages stay as they are)
  for c in "${COPRS[@]}"; do
    "${CURL[@]}" --max-time 15 "https://copr.fedorainfracloud.org/api_3/project?ownername=${c%%/*}&projectname=${c#*/}" 2>/dev/null \
      | jq -e --arg ch "fedora-$to-x86_64" '.chroot_repos | has($ch)' >/dev/null 2>&1 \
      || { skip+=("--disablerepo=copr:copr.fedorainfracloud.org:${c/\//:}"); log "COPR $c has nothing for Fedora $to yet — left out; its packages stay as they are"; }
  done
  preflight 20480
  wlr_keep || die "dwl's own wlroots is missing and cannot be kept from this Fedora — moving on would leave dwl unable to start; fedokawaii repair first"
  libs_ready "$to" "${skip[@]}" && r=0 || r=$?
  ((r != 2)) || die "Fedora $to's repositories could not be asked which libraries they have — nothing changed; try again later"
  ((r == 0)) || die "a library dwl needs is not in Fedora $to (above) — staying on Fedora $FEDORA_VER, which is safe until its support ends"
  if [[ $(as_user podman info --format '{{.Host.DatabaseBackend}}' 2>/dev/null) != sqlite ]]; then
    run as_user podman system migrate --migrate-db || log "podman's database not migrated — Prowlarr may need: podman system migrate --migrate-db"
  fi
  repos_lenient
  log "bringing Fedora $FEDORA_VER fully up to date first"
  dnf_upgrade || die "the update before the move failed — nothing else changed"
  snapshot_before "Fedora $to" important
  log "downloading Fedora $to (this takes a while; nothing is installed yet)"
  if ! retry 2 30 dnf_detached -y system-upgrade download --releasever="$to" "${skip[@]}"; then
    log "the download stopped. If dnf says packages conflict, it can remove the ones that hold the move back — here they are:"
    dnf_detached system-upgrade download --releasever="$to" "${skip[@]}" --allowerasing --assumeno || true
    read -rp "  remove those (any the desktop needs come back afterwards, if Fedora $to has them) and go on? [y/N] " ans </dev/tty || ans=n
    [[ $ans == [yY] ]] || { dnf system-upgrade clean >/dev/null 2>&1; die "nothing changed — Fedora $FEDORA_VER stays as it is"; }
    retry 2 30 dnf_detached -y system-upgrade download --releasever="$to" "${skip[@]}" --allowerasing \
      || { dnf system-upgrade clean >/dev/null 2>&1; die "the download failed — nothing changed"; }
  fi
  # the rest, after the restart: once, by itself, logged
  write_file /etc/systemd/system/fedokawaii-after-upgrade.service <<EOF
[Unit]
Description=Fedokawaii — the rest of the move to Fedora $to
After=network-online.target
Wants=network-online.target
ConditionPathExists=$STATE_DIR/upgrade-pending

[Service]
Type=oneshot
ExecStart=/usr/bin/bash $TOOLKIT/setup.sh --after-upgrade
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload; systemctl enable fedokawaii-after-upgrade.service >/dev/null 2>&1
  record upgrade-pending "$(date +%s) $FEDORA_VER $to"
  hdr "ready: restarting into the installation of Fedora $to (20–40 minutes; leave it on)"
  sleep 5
  if ! dnf -y system-upgrade reboot; then   # (should it not restart: nothing armed is left behind)
    rm -f "$STATE_DIR/upgrade-pending"
    systemctl disable fedokawaii-after-upgrade.service >/dev/null 2>&1 || true
    rm -f /etc/systemd/system/fedokawaii-after-upgrade.service; systemctl daemon-reload || true
    dnf system-upgrade clean >/dev/null 2>&1 || true
    die "dnf could not arrange the restart into Fedora $to — nothing changed"
  fi
}
tidy_duplicates() {   # packages left twice by an interrupted transaction: the older go
  if [[ -n $(dnf -q repoquery --duplicates 2>/dev/null) ]]; then dnf_detached -y remove --duplicates; fi
}
# a power cut or a restart in the middle of a dnf run leaves packages installed twice, on
# which the next one trips: tidied before each phase's first package step (setup)
tidy_after_cut() { tidy_duplicates || log "dnf could not tidy packages installed twice — verify names them"; }
# r_hygiene — nothing doubled, nothing fighting (lib/hygiene.sh has the scan, verify shows
# it): packages installed twice, what dnf check finds, services that fight the desktop's own,
# a login other than greetd, dependencies nothing needs, what a stopped run left. Each part
# on its own; what cannot be put right is said, and the rest goes on.
r_hygiene() {
  local u why list rc=0 dm pk=()
  # the login first: switching off a login manager that fights greetd (below) also takes
  # the display-manager link, so greetd is put back here whatever holds that link — another
  # login manager, or nothing at all
  # (only once setup has finished: before that the login stays off — setup's own last step
  # switches it on, and until then its resume unit has the screen)
  dm=$(hy_display_manager)
  if [[ $(phase) == 'done' && $dm != greetd.service ]]; then
    log "the login was ${dm:-no login manager at all} — greetd again"
    [[ -z $dm ]] || systemctl disable "$dm" >>"$LOG_FILE" 2>&1 || true
    systemctl enable greetd.service >>"$LOG_FILE" 2>&1 || rc=1
  fi
  tidy_duplicates || rc=1
  list=$(hy_dnf_problems)
  if [[ -n $list ]]; then
    log "dnf check reports:"; head -n 20 <<<"$list" | sed 's/^/    /' | tee -a "$LOG_FILE"
    # the packages it names, brought back in line with the repositories (name-version-release.arch)
    mapfile -t pk < <(grep -oE '[A-Za-z0-9._+-]+-[0-9][^ ]*-[^ ]+\.(x86_64|i686|noarch|aarch64)' <<<"$list" \
                     | sed -E 's/-[^-]+-[^-]+$//' | sort -u)
    if ((${#pk[@]})); then run dnf -y distro-sync "${pk[@]}" || rc=1; fi
    [[ -z $(hy_dnf_problems) ]] || { log "dnf check still reports problems — they are in $LOG_FILE"; rc=1; }
  fi
  while IFS='|' read -r u why; do
    [[ -n $u ]] || continue
    log "$u fights $why — switched off"; systemctl disable --now "$u" >>"$LOG_FILE" 2>&1 || rc=1
  done < <(hy_services)
  while IFS='|' read -r u why; do
    [[ -n $u ]] || continue
    log "your $u fights $why — switched off"; as_user systemctl --user disable --now "$u" >>"$LOG_FILE" 2>&1 || rc=1
    # a static one (no [Install]: D-Bus or another unit starts it) cannot be disabled: masked
    if [[ $(as_user systemctl --user is-enabled "$u" 2>/dev/null) == static ]]; then
      as_user systemctl --user mask "$u" >>"$LOG_FILE" 2>&1 || rc=1
    fi
  done < <(hy_user_services)
  # dependencies nothing needs any more (a package you removed left them): taken out, in a
  # dnf run that is snapshotted like every other. Yours and the manifest's are marked as
  # yours, so never among them
  list=$(hy_unneeded)
  if [[ -n $list ]]; then
    log "no longer needed by anything: $(tr '\n' ' ' <<<"$list")"
    run dnf -y autoremove || rc=1
  fi
  lpf_leftovers_out || rc=1                        # (what lpf's removal leaves: its account and folder)
  while IFS= read -r u; do
    [[ -n $u ]] || continue
    rm -rf -- "$u" && log "removed what a stopped run left: $u"
  done < <(hy_leftovers)
  # configuration files a package update could not merge: listed, never touched (yours)
  list=$(hy_rpmnew)
  if [[ -n $list ]]; then
    printf '%s\n' "$list" | write_file "$STATE_DIR/rpmnew" 0644
    log "$(wc -l <<<"$list") configuration file(s) to compare by hand — the list: $STATE_DIR/rpmnew"
  else
    rm -f "$STATE_DIR/rpmnew"                      # (compared and gone: nothing left to show)
  fi
  return "$rc"
}
new_baseline() {   # new_baseline N — after a move: the old baselines age out with the others, a new one
  local n
  for n in $(snapper -c root --csvout list --columns number,description 2>/dev/null | awk -F, '$2 ~ /^fedokawaii baseline/ { print $1 }'); do
    snapper -c root modify -c number "$n" || true
  done
  snapper -c root create -d "fedokawaii baseline (Fedora $1)"
}
# Once, after the move, by itself (fedokawaii-after-upgrade.service): every part on its own —
# one that fails is reported, the rest goes on — and the outcome always recorded, whatever
# happens (the reminder tells you at your next login: nobody is logged in at this boot)
do_after_upgrade() {
  [[ -f $STATE_DIR/upgrade-pending ]] || exit 0
  local from="" to="" _ result=ok n
  IFS=' ' read -r _ from to <"$STATE_DIR/upgrade-pending" || true
  if ! [[ $to =~ ^[0-9]+$ ]]; then
    log "the move's record is unreadable — nothing to finish"
  elif [[ $FEDORA_VER != "$to" ]]; then   # the installation failed: the old release is back
    record last-upgrade "$(date +%s) $from $to failed"
    dnf system-upgrade clean >/dev/null 2>&1 || true      # (its download: never installed by surprise later)
  else
    UPDATE_STEPS_FAILED=()
    local net=1
    retry 30 10 online || { net=0; UPDATE_STEPS_FAILED+=("no network: what needs it is left for the next update"); log "no network yet — the steps that need it are left for the next update"; }
    if ((net)); then step_on "third-party repositories" repos_lenient; fi
    step_on "duplicates" tidy_duplicates
    # your own systemd, which lingering starts beside this unit at boot, is asked from here on
    # (services that fight, the theme, Prowlarr): given a minute to come up
    for n in {1..30}; do [[ -S /run/user/$TARGET_UID/bus ]] && break; sleep 2; done
    if ((net)); then
      step_on "the manifest" manifest_sync
      step_on "this machine's drivers and firmware (the new kernel's)" s_hardware
      step_on "nothing doubled or fighting" r_hygiene
      step_on "dwl and the libraries under it" r_dwl
      step_on "the desktop's own tools and their libraries" r_upstream
      step_on "torrra for the new Python" torrra_up
    fi
    step_on "the theme (dwl rebuilt if needed)" r_theme
    step_on "Prowlarr (Podman may have moved its store)" prowlarr_up
    step_on "a new baseline snapshot" new_baseline "$to"
    ((${#UPDATE_STEPS_FAILED[@]} == 0)) || result=partial
    if ! bash "$REPO_DIR/verify.sh" >>"$LOG_FILE" 2>&1 && [[ $result == ok ]]; then result=checks; fi
    # for you to look at, never changed by itself: configuration files the upgrade could not
    # merge (.rpmnew beside yours), and packages no longer in any repository
    n=$(find /etc \( -name '*.rpmnew' -o -name '*.rpmsave' \) 2>/dev/null | tee "$STATE_DIR/rpmnew" | wc -l) || n=0
    ((n == 0)) || log "$n configuration file(s) to compare (list: $STATE_DIR/rpmnew)"
    dnf -q repoquery --installed --extras --exclude='kernel*,gpg-pubkey' --qf '%{name}\n' 2>/dev/null >"$STATE_DIR/extras" || true
    record last-update "$(date +%s) $result"
    record last-update-done "$(date +%s)"
    record_snapshots
    record last-upgrade "$(date +%s) $from $to $result"
  fi
  rm -f "$STATE_DIR/upgrade-pending"
  systemctl disable fedokawaii-after-upgrade.service >/dev/null 2>&1 || true
  rm -f /etc/systemd/system/fedokawaii-after-upgrade.service; systemctl daemon-reload || true
}

# ═════════════════════════════════════════════════════════════════════════════
#  --repair — find what has gone wrong and put it right (alias: repair)
# ═════════════════════════════════════════════════════════════════════════════
# Every fix is idempotent and runs on its own (errexit really on inside, so a failing
# step stops only that fix); the summary says what was put right and what still needs
# you. Nothing here deletes your files: changed configs go to Theme's backup first.
HEALED=() STILL=()
heal() {   # heal WHAT FUNCTION… — run one fix, remember how it went
  local what=$1; shift
  log "repair: $what"
  contained "$@"
  if ((CONTAINED_RC == 0)); then HEALED+=("$what"); else STILL+=("$what"); fi
}

r_packages() {   # dnf's own state sound, the manifest complete, nothing forbidden
  dnf -q repoquery --installed bash >/dev/null 2>&1 || run dnf clean metadata
  if [[ -n $(dnf -q repoquery --duplicates 2>/dev/null) ]]; then run dnf -y remove --duplicates; fi
  repos_lenient
  manifest_sync
}
r_system() {     # failed units cleared, the session's own system pieces in place
  systemctl reset-failed || true
  install_toolkit
  install_start_dwl
  [[ -x /usr/local/bin/kawa-greet ]] || install -m 0755 "$REPO_DIR/system/kawa-greet" /usr/local/bin/
  restorecon -R /usr/local/bin /usr/local/sbin /etc/greetd 2>/dev/null || true
  [[ $(phase) != 'done' ]] || systemctl is-enabled --quiet greetd.service || systemctl enable greetd.service
  systemctl enable --now snapper-timeline.timer snapper-cleanup.timer 2>/dev/null || true
  snapper_configs
  snapper_limits
  snap_hooks
  s_scrub
  s_report                         # (the first-start report's unit: an install that lost it runs it next start)
  s_tuning
}
r_ports() { s_ssh; open_ports; }   # SSH as SSH_SERVER says; torrra's and LocalSend's ports open
r_boot() {       # the boot: its menu and success timer (s_boot), no rescue image, AMD's kernel
                 # argument, a quiet boot (its arguments, the consoles' cursor at login), every
                 # kernel's image; neovim the editor
  s_boot
  editor_policy
  # (an entry without it — verify fails it — gets it again: every entry, as setup did)
  if [[ $(cat "$STATE_DIR/gpu" 2>/dev/null) == amd ]] && ! amd_arg_everywhere; then
    run grubby --update-kernel=ALL --args="$AMDGPU_ARG"
  fi
  s_quiet_boot
  old_kernels_out desktop   # (first: no boot image is made for a kernel that is about to go)
  kernel_images
}
r_services() {   # the services setup enabled (a package reinstalled after a move starts off)
  systemctl enable bluetooth.service fstrim.timer
  # (LACT only while it is there: retired, or gone with its COPR, it is no longer a fault)
  if [[ $(cat "$STATE_DIR/gpu" 2>/dev/null) == amd ]] && systemctl cat lactd.service >/dev/null 2>&1; then
    systemctl enable lactd.service
  fi
  i2c_dev
}
r_user() {       # the user's session plumbing: linger and its stop, the bus, groups, fonts, secrets.sh's mode
  local sec=$TARGET_HOME/.config/fedokawaii/secrets.sh
  loginctl enable-linger "$TARGET_USER"
  user_stop
  s_groups
  if [[ $STEAM == yes ]]; then usermod -aG gamemode "$TARGET_USER"; fi
  retry 15 2 test -S "/run/user/$TARGET_UID/bus"
  if [[ -e $sec && ! -L $sec ]]; then
    [[ $(stat -c %u "$sec") == "$TARGET_UID" ]] || chown -h "$TARGET_UID:$TARGET_GID" "$sec"
    as_user chmod 600 "$sec"
  fi
  home_back
  as_user fc-cache -f >/dev/null
  as_user systemctl --user reset-failed || true
}
# home_back — files of root's in your home handed back to you (a program once run as root with
# your HOME: an older health report wrote ~/Downloads/fedokawaii-report.txt so). podman's
# storage keeps its containers' own ids; nothing outside your home, no link followed: find
# walks it itself, and -execdir changes each file from its own folder
home_back() {
  local n
  n=$(find "$TARGET_HOME" -xdev -path "$TARGET_HOME/.local/share/containers/storage" -prune -o -user 0 -print 2>/dev/null | grep -c .) || true
  ((n)) || return 0
  find "$TARGET_HOME" -xdev -path "$TARGET_HOME/.local/share/containers/storage" -prune -o -user 0 \
    -execdir chown -h "$TARGET_UID:$TARGET_GID" -- {} + 2>/dev/null || true
  log "your home: $n file(s) of root's handed back to you"
}
r_upstream() {   # release binaries and fonts present (each is a no-op when current) — each
  local e rc=0   # tried even when one before it failed
  for e in "${UPSTREAM[@]}"; do install_upstream_bin "$e" || rc=1; done
  retire_upstream || rc=1
  install_nerd_fonts || rc=1
  install_fusion || rc=1
  install_syncplay || rc=1
  install_blesh || rc=1
  install_localsend || rc=1
  if [[ $STEAM == yes ]]; then install_ge_proton || rc=1; fi
  return "$rc"
}
# dwl itself: its own wlroots, the libraries under both, and the binary — built again from the
# pinned commit when it is gone or no longer starts (the rescue screen sends you here)
r_dwl() {
  local f
  wlr_keep || log "no copy of wlroots $DWL_WLROOTS, and this Fedora no longer ships it — dwl cannot be rebuilt here"
  for f in "$(wlr_home)"/lib/*.so*; do      # (dwl's own: a rebuild below links what is there now)
    if [[ -f $f && ! -L $f ]]; then libs_for "$f" || true; fi
  done
  if [[ ! -x /usr/local/bin/dwl || ! -d $TARGET_HOME/.local/src/dwl/.git ]] \
     || [[ $(as_user git -C "$TARGET_HOME/.local/src/dwl" rev-parse HEAD 2>/dev/null) != "$DWL_COMMIT" ]] \
     || [[ $(as_user ldd /usr/local/bin/dwl 2>/dev/null) == *'not found'* ]]; then
    rm -f "$STATE_DIR/dwl.sha256"; s_dwl          # (theme.sh then builds it with src/dwl/config.h)
  fi
  return 0
}
wlr_has() {   # the wlroots this Fedora has (rpm's "not installed" goes to stdout: not shown)
  local v; v=$(rpm -q --qf '%{version}' wlroots-devel 2>/dev/null) || v="no wlroots-devel"; printf '%s' "$v"
}
wlr_step() {   # wlr_keep, saying why when it cannot
  wlr_keep && return 0
  log "dwl's own wlroots $DWL_WLROOTS: no copy kept, and this Fedora does not ship it (it has $(wlr_has))"
  return 1
}
# r_sound — sound that keeps running. Steady already: left alone (a restart would cut the
# sound of everything playing). Else PipeWire restarted clean first; if it still will not
# stay up, fedokawaii's own PipeWire and WirePlumber files are taken out one at a time
# (~/.local/state/fedokawaii/set-aside/) until it does — the one it crashed on stays out
# (and theme.sh leaves that version out: set_aside), the others go back. Without a session
# manager running (no login since boot, linger off) there is nothing to try.
r_sound() {
  [[ -S /run/user/$TARGET_UID/bus ]] || return 0
  pw_steady && return 0
  as_user systemctl --user reset-failed pipewire.service pipewire.socket wireplumber.service 2>/dev/null || true
  as_user systemctl --user restart pipewire.socket pipewire.service wireplumber.service 2>/dev/null || true
  pw_steady && return 0
  local rel src dst park=$TARGET_HOME/.local/state/fedokawaii/set-aside list
  list=$(set_aside_list)
  while IFS= read -r -d '' src; do
    rel=${src#"$REPO_DIR/configs/home/"} dst=$TARGET_HOME/$rel
    [[ -f $dst && ! -L $dst ]] || continue
    as_user mkdir -p "$park/${rel%/*}"
    as_user mv -f -- "$dst" "$park/$rel"
    as_user systemctl --user reset-failed pipewire.service pipewire.socket wireplumber.service 2>/dev/null || true
    as_user systemctl --user restart pipewire.socket pipewire.service wireplumber.service 2>/dev/null || true
    if pw_steady; then
      as_user mkdir -p "${list%/*}"
      printf '%s %s\n' "$(sha256sum <"$src" | cut -c1-64)" "$rel" | as_user tee -a "$list" >/dev/null
      log "PipeWire crashed at every start with ~/$rel — set aside in ${park/#$TARGET_HOME/\~} (sound works without it; a fixed version comes back with an update)"
      return 0
    fi
    as_user mv -f -- "$park/$rel" "$dst"     # not this one: back where it was
  done < <(find "$REPO_DIR/configs/home/.config/pipewire" "$REPO_DIR/configs/home/.config/wireplumber" -type f -print0 2>/dev/null | sort -z)
  as_user systemctl --user restart pipewire.socket pipewire.service wireplumber.service 2>/dev/null || true
  log "PipeWire does not keep running, and none of fedokawaii's sound files is the cause — journalctl --user -u pipewire -b says why"
  return 1
}
r_nvim() {   # LazyVim's plugins: the missing ones installed, at the lockfile's versions
  [[ -f $TARGET_HOME/.config/nvim/init.lua ]] || return 0
  run as_user timeout 900 nvim --headless '+Lazy! install' +qa
}
r_filechooser() { tfc_current || build_filechooser; }   # the yazi file dialog, built if missing or not TFC_TAG
r_theme() {      # every config back as the repo has it, dwl and the C helpers rebuilt if needed —
  # only where the theme was chosen: a "Setup only" machine keeps its own configs
  if [[ ! -f $TARGET_HOME/.local/state/fedokawaii/theme-applied ]]; then
    log "the theme was never applied here (Setup only) — left so"; return 0
  fi
  bash "$REPO_DIR/theme.sh" --user "$TARGET_USER"
}

problems() {   # problems → how many checks verify failed (it records its outcome)
  bash "$REPO_DIR/verify.sh" >/dev/null 2>&1 || true
  local t="" p="" f=""; { IFS=' ' read -r t p f _ <"$STATE_DIR/last-verify"; } 2>/dev/null || true
  [[ ${f:-} =~ ^[0-9]+$ ]] && echo "$f" || echo "?"
}
# heal_all NET — every fix repair makes, in order (NET 0: only what needs no network); each one
# contained, so one that fails never stops the rest. Repair runs it, and so does setup's last
# check when it finds something wrong (s_gate)
heal_all() {
  local net=$1
  heal "the old name's leftovers" retire_old_name
  ((net)) && heal "packages (dnf's state, the manifest complete, nothing forbidden)" r_packages
  ((net)) && heal "this machine's drivers and firmware" s_hardware
  heal "nothing doubled or fighting (twice-installed, services, the login, unneeded, leftovers)" r_hygiene
  heal "system services, login, snapshots" r_system
  heal "the login (greetd and its greeter)" greetd_config
  heal "the boot (success timer, no rescue image, the GPU's kernel argument, a quiet boot) and the editor" r_boot
  heal "services (Bluetooth, TRIM, the GPU tool, i2c-dev)" r_services
  heal "dnf's settings" s_dnf
  heal "the time zone ($TIMEZONE)" timedatectl set-timezone "$TIMEZONE"
  heal "inbound SSH ($SSH_SERVER) and the torrent port" r_ports
  heal "your session (linger, groups, fonts, secrets.sh mode)" r_user
  ((net)) && heal "dwl (its wlroots, libraries, binary)" r_dwl
  ((net)) && heal "release binaries, fonts, Syncplay, ble.sh and GE-Proton" r_upstream
  ((net)) && heal "the yazi file dialog (termfilechooser ${TFC_TAG:-})" r_filechooser
  ((net)) && heal "torrra" torrra_up
  ((net)) && heal "neovim's plugins (any missing)" r_nvim
  heal "Prowlarr (it starts, and takes the key from secrets.sh)" prowlarr_up
  heal "the theme (configs, dwl, helpers, wallpapers)" r_theme
  heal "sound (PipeWire keeps running)" r_sound
}
do_repair() {
  # (once setup reached its last check everything is installed: repair may put right what that
  # check found, before the login is switched on)
  [[ $(phase) == 'done' || ( $(phase) == 3 && -f $STATE_DIR/gate-reached ) ]] \
    || die "the build is not finished — run setup again; it resumes where it stopped"
  detach_dnf
  local before after net=1
  hdr "Fedokawaii repair · $TARGET_USER"
  # offline, it still puts right what needs no network: services, the session, the configs
  retry 6 5 online || { net=0; log "offline: only what needs no network is repaired now — run repair again once online"; }
  toolkit_first          # (run from a copy: everything below is then the toolkit's)
  before=$(problems)
  log "verify found $before problem(s) — fixing what can be fixed"
  heal_all "$net"
  clean_caches || true
  record_snapshots
  after=$(problems)
  clone_done || true                                # (the very last: the folder this repair was run from)
  hdr "repair done — verify: $before problem(s) before, $after now"
  local s
  if ((${#HEALED[@]})); then printf -v s '%s · ' "${HEALED[@]}"; ok "in order: ${s% · }"; fi
  if ((${#STILL[@]})); then
    printf -v s '%s · ' "${STILL[@]}"; log "still needs you: ${s% · } — the lines above say why"
  fi
  ((net)) || log "offline: packages, release tools, the file dialog and torrra were left for the next repair"
  [[ $after == 0 ]] || log "what verify still reports: fedokawaii verify"
  # (the outcome for whoever ran it: 0 when nothing is left to fix, 3 when something is —
  # 1 is reserved for repair itself stopping)
  if ((${#STILL[@]})) || [[ $after != 0 ]]; then exit 3; fi
}

# ─────────────────────────────────────────────────────────────────────────────
case $MODE in
  reset)  rm -f "$STATE_DIR"/done.* "$STATE_DIR"/phase "$STATE_DIR"/with-theme "$STATE_DIR"/gate-reached; remove_resume_unit
          echo "progress forgotten (the user and baseline records are kept)"; exit 0 ;;
  update) do_update; exit 0 ;;
  upgrade) do_upgrade "${UPGRADE_FLAG:-}"; exit 0 ;;
  after-upgrade) do_after_upgrade; exit 0 ;;
  repair) do_repair; exit 0 ;;
  kernels) [[ $(phase) == 'done' ]] || exit 0; old_kernels_out desktop; exit 0 ;;
  toolkit) [[ $(phase) == 'done' ]] || die "the build is not finished — setup makes the toolkit itself"
           [[ $REPO_DIR != "$TOOLKIT" ]] || { ok "this is the toolkit already"; exit 0; }
           toolkit_first; install_toolkit           # (the second: the fedokawaii command, from it)
           ok "the toolkit is now this copy ($TOOLKIT)"; exit 0 ;;
esac
hdr "Fedokawaii setup · Fedora $FEDORA_VER · phase $(phase) · $TARGET_USER$([[ -f $STATE_DIR/with-theme ]] && echo ' · with theme')"
case $(phase) in
  1) phase1 ;;  2) phase2 ;;  3) phase3 ;;
  done) ok "already built — menu: Theme, Verify, Update" ;;
  *) die "$STATE_DIR/phase says '$(phase)' — it should be 1, 2, 3 or done: write the phase setup was in (--status lists the finished steps), or start over: sudo bash setup.sh --reset" ;;
esac
