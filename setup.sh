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
MODE=build NO_REBOOT=0 UPGRADE_FLAG="" RESUMED=0

# (the options first: --help needs neither sudo nor a valid fedokawaii.conf, and a mistyped
# option stops the run before anything is touched)
for a in "$@"; do
  case $a in
    --resume) RESUMED=1 ;;
    --update) MODE=update ;;  --repair) MODE=repair ;;  --status) MODE=status ;;  --reset) MODE=reset ;;
    --toolkit) MODE=toolkit ;;
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
# shellcheck disable=SC2154  # rc is assigned inside the trap string
trap 'rc=$?; ((BASH_SUBSHELL == 0)) || exit $rc
      _out "${C_RED}✘ line $LINENO${FUNCNAME[0]:+ in ${FUNCNAME[0]}(), called from line ${BASH_LINENO[-2]}}: ${BASH_COMMAND:0:160} (exit $rc)${C_RESET}" >&2
      _out "  log: $LOG_FILE — fix the cause, then run the same command again (finished steps are skipped)" >&2; exit $rc' ERR
trap '_out ""; _out "${C_RED}✘ interrupted — run the same command again to continue${C_RESET}"; exit 130' INT TERM
if [[ $MODE == status ]]; then        # read-only, so it works while another run holds the lock
  # shellcheck disable=SC1091
  source /etc/os-release
  echo "phase $(cat "$STATE_DIR/phase" 2>/dev/null || echo 1) · user $(cat "$STATE_DIR/user" 2>/dev/null || echo '(not chosen yet)') · Fedora $VERSION_ID · theme $([[ -f $STATE_DIR/with-theme ]] && echo 'with setup' || echo separate)"
  find "$STATE_DIR" -name 'done.*' -printf '  ✔ %f\n' | sed 's/done\.//' | sort; exit 0
fi
take_lock "$STATE_DIR/lock"
make_tmp
# A run resumed after a reboot (fedokawaii-resume.service) that stops: nobody typed a command
# to "run again", and tty1, the service's own screen, has no login of its own until you
# switch away and back. So it ends by saying how to carry on (the reason is above it).
if ((RESUMED)); then
  resume_hint() {
    _out ""
    if [[ $(phase) == 'done' ]]; then    # (the final check, or the baseline: the build is in place)
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
  if [[ $REPO_DIR != "$TOOLKIT" ]]; then
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
    if [[ -d $TOOLKIT ]]; then mv "$TOOLKIT" "$TOOLKIT.old"; fi
    mv "$TOOLKIT.new/t" "$TOOLKIT"
    write_file "$STATE_DIR/conf-from-copy.conf" 0644 <"$TOOLKIT.new/copy.conf"
    rm -rf "$TOOLKIT.new" "$TOOLKIT.old"
  fi
  install -m 0755 "$TOOLKIT/system/fedokawaii" /usr/local/bin/fedokawaii
  restorecon -R "$TOOLKIT" /usr/local/bin/fedokawaii 2>/dev/null || true
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
  [[ -z $(conf_problems "$TOOLKIT/fedokawaii.conf") ]] || return 0
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
  local n=6; ((RESUMED)) && n=30
  retry "$n" 5 online || die "no network — connect to one (nmtui), then run it again"
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
    # (a function that returned its own failure has said why: no "return 1" line after it)
    trap 'rc=$?; ((BASH_SUBSHELL == lvl)) || exit $rc; [[ $BASH_COMMAND == return* ]] && exit $rc
          _out "${C_RED}✘ line $LINENO${FUNCNAME[0]:+ in ${FUNCNAME[0]}()}: ${BASH_COMMAND:0:160} (exit $rc)${C_RESET}" >&2; exit $rc' ERR
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
minrate=50k
timeout=20
installonly_limit=2
defaultyes=True
EOF
  local k want v dump; dump=$(dnf --dump-main-config 2>/dev/null) || dump=""
  # checked, and reported — never a reason to stop: a later dnf may print a value its own way
  # (minrate is shown in bytes: 50k = 51200)
  for k in "max_parallel_downloads:$DNF_PARALLEL" fastestmirror:1 minrate:51200 timeout:20 installonly_limit:2 defaultyes:1; do
    want=${k#*:}; v=$(sed -n "s/^${k%%:*} *= *//p" <<<"$dump")
    [[ $v == "$want" || ( $want == 1 && $v == [Tt]rue ) || ( $want == 51200 && $v == 50[kK] ) ]] \
      || log "dnf shows ${k%%:*}='$v' where the drop-in sets $want — /etc/dnf/dnf.conf may override it"
  done
  # (no protected list of our own: dnf also refuses a protected package's replacement — a
  # sudo-rs, a retired greetd — and would then hold every later update back for good. The
  # manifest's packages are marked as yours instead, so dnf's clean-up never takes them.)
  # package metadata is fetched when you update (`dnf upgrade --refresh`), not every hour or
  # so in the background by dnf's makecache timer: no downloads and no work between updates
  local u
  for u in dnf5-makecache.timer dnf-makecache.timer; do
    if systemctl cat "$u" >/dev/null 2>&1 && systemctl is-enabled --quiet "$u" 2>/dev/null; then
      run systemctl disable --now "$u"
    fi
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
  # appears by itself after a failed one. The timer marks a boot successful. Once the
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
  run systemctl --global enable grub-boot-success.timer
  # Two kernels at rest: the newest, and the one before it to fall back to from the boot
  # menu (dnf's installonly_limit=2, s_dnf) — after a kernel update, and after a move to a
  # new Fedora, the old one is still there until the next one replaces it
}

s_update() { wait_for_network; run dnf -y upgrade --refresh; }

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
editor_policy() {       # neovim is the editor (EDITOR, VISUAL, vi); no rescue kernel image
  rm -f /boot/vmlinuz-0-rescue-* /boot/initramfs-0-rescue-* /boot/loader/entries/*-0-rescue*.conf
  write_file /etc/profile.d/editor.sh <<'EOF'
export EDITOR=nvim
export VISUAL=nvim
EOF
  ln -sfn /usr/bin/nvim /usr/local/bin/vi
}

s_tuning() {   # an always-plugged desktop: the CPU at full speed, Wi-Fi never napping
  install -D -m 0644 "$REPO_DIR/system/tuned.conf" /etc/tuned/profiles/fedokawaii/tuned.conf
  systemctl enable --now tuned.service
  run tuned-adm profile fedokawaii
  [[ $(tuned-adm active 2>/dev/null) == *fedokawaii* ]] \
    || log "tuned does not show the fedokawaii profile yet (tuned-adm active) — verify checks it; update and repair apply it again"
  write_file /etc/NetworkManager/conf.d/90-fedokawaii.conf <<'EOF'
# Fedokawaii — Wi-Fi power saving off (2 = disable): a desktop is always plugged in, and a
# radio that naps between packets adds lag to games, calls and screen sharing
[connection]
wifi.powersave = 2
EOF
  nmcli general reload conf >/dev/null 2>&1 || true
}

# The project's earlier name was Scriptorium. What an install under that name put on the
# system is taken out, so none of it runs beside this one: its kernel-prune timer and resume
# service, its dnf hooks (a second snapshot per transaction), its dconf defaults (another
# GTK theme and a close button in every title bar). Its greeter goes once the login points
# at kawa-greeter. Only those exact paths; nothing in your home (README lists those).
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
  step "1.7 inbound SSH ($SSH_SERVER)"               s_ssh
  reboot_to 2
}

# ═════════════════════════════════════════════════════════════════════════════
#  PHASE 2 — repositories, GPU drivers, media (drivers before their consumers)
# ═════════════════════════════════════════════════════════════════════════════
s_repos() {
  wait_for_network
  local base=https://mirrors.rpmfusion.org r repos
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
    keys=$(gpg --show-keys --with-colons "$key" 2>/dev/null | grep -c '^pub:' || true)
    pins=$(gpg --show-keys --with-colons "$key" 2>/dev/null \
             | awk -F: '/^pub:/ { want = 1; next } want && /^fpr:/ { print $10; want = 0 }')
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
  for r in "${COPRS[@]}"; do run dnf -y copr enable "$r"; done
  run dnf -y upgrade --refresh                     # RPM Fusion builds now match the base libraries
  repos=$(dnf repolist --enabled)
  for r in rpmfusion-free rpmfusion-nonfree brave-browser claude-code; do
    grep -q "^$r " <<<"$repos" || die "repository $r is not enabled"
  done
}

s_gpu() {
  local gpu; gpu=$(detect_gpu); echo "$gpu" >"$STATE_DIR/gpu"
  [[ $gpu == amd || $gpu == intel ]] \
    || die "no AMD or Intel GPU found (the cards are: $gpu) — the desktop is built on their open drivers; a card the kernel does not drive yet: set GPU= in fedokawaii.conf"
  log "GPU: $gpu"
  dnf_install "${PKG_GPU_COMMON[@]}"
  if [[ $gpu == amd ]]; then
    # VA: since Fedora 44 Fedora's VA drivers live inside mesa-dri-drivers (which obsoletes
    # mesa-va-drivers), and RPM Fusion's build installs beside it. Never --allowerasing for
    # it: a conflict must stop the run, not take mesa-dri-drivers — and the desktop — with it
    if pkg_installed mesa-va-drivers; then run dnf -y swap mesa-va-drivers mesa-va-drivers-freeworld
    else run dnf -y install mesa-va-drivers-freeworld; fi
    # Vulkan: Fedora's build and RPM Fusion's conflict by design — the one swapped for the other
    if pkg_installed mesa-vulkan-drivers; then run dnf -y swap mesa-vulkan-drivers mesa-vulkan-drivers-freeworld --allowerasing
    else run dnf -y install mesa-vulkan-drivers-freeworld --allowerasing; fi
    dnf_install "${PKG_GPU_amd[@]}"
    systemctl enable lactd.service
    # LACT's clocks, voltages and fan curves need OverDrive (bit 14), which amdgpu leaves off:
    # its default mask (0xfff7bfff) plus that bit. Not 0xffffffff — that also switches on
    # GFX DCS (bit 19), which amdgpu keeps off as unstable (flicker, hangs on some cards)
    run grubby --update-kernel=ALL --args=amdgpu.ppfeaturemask=0xfff7ffff
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
  dnf_install "${PKG_MEDIA[@]}"
  local e enc; enc=$(ffmpeg -hide_banner -encoders 2>/dev/null)
  for e in libx264 libx265 libsvtav1 libaom-av1; do grep -qw "$e" <<<"$enc" || die "ffmpeg lacks encoder $e"; done
}

phase2() {
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
s_dwl() {
  local src=$TARGET_HOME/.local/src/dwl
  as_user mkdir -p "$TARGET_HOME/.local/src"
  [[ -d $src/.git ]] || retry 3 10 as_user git clone --quiet https://codeberg.org/dwl/dwl.git "$src"
  # (Codeberg has its slow minutes: the fetch is retried like the clone)
  retry 3 10 as_user git -C "$src" fetch --quiet --tags --force || die "could not fetch dwl from codeberg.org — try again in a while"
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
  # is printed for the bar. git apply refuses (and setup stops) if upstream ever changes
  # the lines it touches.
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
  keep_dwl_prev || log "dwl.prev not refreshed (start-dwl keeps the fallback it has)"   # (start-dwl's fallback)
  take_built "$src/dwl" /usr/local/bin/dwl 0755 || die "dwl was not built (see $LOG_FILE)"
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
greetd_config() {   # the login: the greeter, and greetd pointed at our own file of it
  install -m 0755 "$REPO_DIR/system/kawa-greeter" /usr/local/bin/
  # greetd's own config.toml stays the package's: ours is a file of its own, and greetd is
  # pointed at it (so updates never meet a changed file, and leave no .rpmnew behind)
  write_file /etc/greetd/fedokawaii.toml <<'EOF'
# /etc/greetd/fedokawaii.toml — installed by setup.sh (greetd reads it: greetd.service.d/
# fedokawaii.conf). The greeter is agreety (part of greetd): a plain user name + password
# prompt on tty1.
[terminal]
vt = 1

[default_session]
command = "/usr/local/bin/kawa-greeter"
user = "greetd"
EOF
  write_file /etc/systemd/system/greetd.service.d/fedokawaii.conf <<'EOF'
# installed by setup.sh: greetd reads fedokawaii.toml, and owns tty1 alone (Fedora 45 runs
# kmscon there, earlier releases agetty)
[Unit]
Conflicts=getty@tty1.service kmsconvt@tty1.service
After=getty@tty1.service kmsconvt@tty1.service

[Service]
ExecStart=
ExecStart=/usr/bin/greetd --config /etc/greetd/fedokawaii.toml
EOF
  systemctl daemon-reload
  restorecon -R /usr/local/bin /etc/greetd
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
# (tree-sitter-cli recommends "nodejs", which on Fedora 44 is Node 22: a second Node beside
# the manifest's 24 — one tool per job, so not taken)
s_apps()    { dnf_install --exclude='nodejs22*' "${PKG_APPS[@]}"; }

s_upstream() {
  local e; for e in "${UPSTREAM[@]}"; do install_upstream_bin "$e"; done
  install_nerd_fonts
  install_pixelmplus
}

# ── the file dialog: yazi, through xdg-desktop-portal-termfilechooser ────────
# Not packaged for Fedora, so built like dwl: hunkyburrito's fork (the maintained one) at
# the pinned tag, which must resolve to the pinned commit; configured, compiled and staged
# as you in ~/.local/src, then its four files copied to /usr/local by root (root writes
# nothing in your home), the portal file last, once the binary has been seen to run. There
# xdg-desktop-portal (≥ 1.20.1 reads $XDG_DATA_DIRS), D-Bus and systemd --user find it.
# kawa-pick (bin/) is the wrapper it runs: the samples it ships are left out.
# Never a reason to stop: if any of it fails, nothing is installed, file dialogs stay GTK's
# (wlroots-portals.conf lists termfilechooser, then gtk), and update and repair try again.
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
  ((CONTAINED_RC == 0)) || log "file dialogs stay GTK's for now: termfilechooser did not build (why: above, or $LOG_FILE) — update or repair try again"
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
    # Notify=healthy: this returns once Prowlarr answers (first start: up to a few minutes)
    run as_user systemctl --user restart prowlarr.service || die "Prowlarr did not start — journalctl --user -u prowlarr"
  fi
  # (retry logs the command it repeats: the key travels in the environment, not in its words)
  PROWLARR_KEY=$key retry 10 3 prowlarr_accepts \
    || die "Prowlarr does not take the key from secrets.sh — journalctl --user -u prowlarr"
  # it runs on demand (torrra's search, `prowlarr`): checked, it goes back to sleep — unless
  # it was already running when this began
  ((was)) || as_user systemctl --user stop --no-block prowlarr.service || true
}

# torrra itself: Python 3.13 (libtorrent has wheels only up to 3.13), its command wrapped
# by kawa-torrra, and its settings: Prowlarr as the indexer, best-seeded results first,
# downloads in ~/Downloads, the terminal's own colours — and no key in them
torrra_up() {
  local py=$TARGET_HOME/$TORRRA_VENV/bin/python
  local probe='import sys, importlib.metadata as m, torrra, libtorrent, torrra.__main__; sys.exit(m.version("torrra") != sys.argv[1])'
  if ! as_user "$py" -I -c "$probe" "$TORRRA_VERSION" 2>/dev/null; then
    retry 3 20 run as_user env PIPX_HOME="$TARGET_HOME/.local/share/pipx" pipx install --force --python python3.13 "torrra==$TORRRA_VERSION" \
      || die "torrra did not install"
  fi
  as_user "$py" -I -c "$probe" "$TORRRA_VERSION" || die "torrra $TORRRA_VERSION is installed but does not load (libtorrent)"
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
  retry 15 2 test -S "/run/user/$TARGET_UID/bus" || die "user systemd instance did not start"
  as_user podman system migrate >/dev/null 2>&1 || true      # picks up new sub-IDs
  downloads_subvolume
  torrra_up
  prowlarr_up
  torrent_port
}
torrent_port() {   # torrra's port, open in the firewall (when firewalld runs: otherwise said)
  if firewall-cmd -q --state 2>/dev/null; then
    firewall-cmd -q --permanent --add-port=6881/tcp --add-port=6881/udp && firewall-cmd -q --reload
  else log "firewalld is not running — torrra's port 6881 is left as it is"; fi
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
  # Steam needs 32-bit Mesa; on AMD it must be RPM Fusion's freeworld build too, or dnf
  # picks Fedora's mesa-vulkan-drivers.i686 (forbidden: the freeworld one conflicts with it)
  local extra=()
  [[ $(cat "$STATE_DIR/gpu" 2>/dev/null) == amd ]] && extra=(mesa-vulkan-drivers-freeworld.i686 mesa-va-drivers-freeworld.i686)
  dnf_install "${PKG_GAMING[@]}" "${extra[@]}"
  modprobe ntsync 2>/dev/null || true             # now too, not only from the next boot on
  usermod -aG gamemode "$TARGET_USER"             # gamemode's CPU/GPU boosts are for this group
  # GE-Proton comes from GitHub: down, or changed in a way this cannot follow, it must not
  # stop the build — Steam has its own Proton meanwhile, and update tries again
  contained install_ge_proton
  ((CONTAINED_RC == 0)) || log "GE-Proton is not installed yet (why: above, or $LOG_FILE) — Steam's own Proton works meanwhile; update tries again"
}

s_groups() { usermod -aG video,input,render "$TARGET_USER"; }   # (subuids: s_torrents)

s_ssh() {                       # a desktop doesn't need inbound SSH (SSH_SERVER=no)
  local z s
  if [[ $SSH_SERVER == no ]]; then systemctl disable --now sshd.service 2>/dev/null || true
  else systemctl enable --now sshd.service; fi
  # the firewall's ports to match — firewalld is Fedora Server's, and running; if it is not,
  # sshd's state above is what counts, and that is said rather than stopping the run
  z=$(firewall-cmd --get-default-zone 2>/dev/null) \
    || { log "firewalld is not running — its ssh/cockpit ports are left as they are"; return 0; }
  if [[ $SSH_SERVER == no ]]; then
    for s in ssh cockpit; do
      if firewall-cmd -q --permanent --zone="$z" --query-service="$s"; then
        firewall-cmd -q --permanent --zone="$z" --remove-service="$s"
      fi
    done
  else
    firewall-cmd -q --permanent --zone="$z" --query-service=ssh || firewall-cmd -q --permanent --zone="$z" --add-service=ssh
  fi
  firewall-cmd -q --reload
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
  # (and LazyVim's plugins: 3.09 is done once nvim has run, even when GitHub let some clones
  # fail — then only nvim itself fetches them again; repair cannot run before the build ends)
  if [[ ! -d $TARGET_HOME/.local/share/nvim/lazy/LazyVim ]]; then
    contained r_nvim
    ((CONTAINED_RC == 0)) || log "LazyVim's plugins could not be fetched yet (why: above, or $LOG_FILE)"
  fi
  run bash "$REPO_DIR/verify.sh" --pre-finalize \
    || die "verify found problems (above) — fedokawaii repair puts most of them right; then run setup again"
}

# snapshots kept within bounds for a machine left alone for months: ranges, so the clean-up
# removes more when space runs low (FREE_LIMIT: a fifth of the disk stays free), hourly ones
# for a few hours, daily ones for a week, at most two monthly ones, none for years — so a
# deleted file's space comes back within two months at most (sooner when space runs low)
snapper_limits() {
  local c
  for c in root home; do
    grep -q "^$c " <<<"$(snapper list-configs)" || continue
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
  grep -q '^root ' <<<"$(snapper list-configs)" || run snapper -c root create-config /
  if [[ $(findmnt -no FSTYPE /home) == btrfs ]]; then
    grep -q '^home ' <<<"$(snapper list-configs)" || run snapper -c home create-config /home
  fi
  snapper_limits
  systemctl enable --now snapper-timeline.timer snapper-cleanup.timer
  systemctl enable --now fstrim.timer              # weekly TRIM (Fedora's preset, made explicit)
  s_scrub                                          # the monthly Btrfs scrub
  snap_hooks
  # the resume unit goes last: should anything above fail, the next start carries on here
  # (holding greetd back meanwhile, its Conflicts=). The baseline is then the finished system
  remove_resume_unit
  set_phase 'done'
  run snapper -c root create -d "fedokawaii baseline"     # no cleanup algorithm: kept until you delete it
}

phase3() {
  wait_for_network
  step "3.01 build dependencies"                       s_build
  step "3.02 dwl $DWL_TAG (pinned commit)"             s_dwl
  step "3.03 login: greetd + agreety + SELinux"        s_session
  step "3.04 desktop stack"                            s_desktop
  step "3.05 fonts, icons, toolkit themes"             s_look
  step "3.06 applications"                             s_apps
  step "3.07 upstream binaries (checksummed)"          s_upstream
  step "3.07b file dialog: yazi (termfilechooser ${TFC_TAG:-})" s_filechooser
  step "3.08 Prowlarr + torrra (wired together)"       s_torrents
  step "3.09 LazyVim + plugins"                        s_lazyvim
  step "3.10 Steam + GE-Proton"                        s_gaming
  step "3.11 groups"                                   s_groups
  step "3.12 theme (only if chosen)"                   s_theme
  step "3.13 verify gate"                              s_gate
  step "3.14 enable login, snapshots, baseline"        s_finalize
  bash "$REPO_DIR/verify.sh" || die "final verification failed — see above"
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
  _out "${C_DIM}$(_ts) \$ dnf $*  (as $unit)${C_RESET}"
  journalctl -f -n 0 -o cat -u "$unit.service" 2>/dev/null 9>&- &
  FOLLOWER=$!
  systemd-run --quiet --unit="$unit" --service-type=exec --wait --collect \
    -p StandardOutput=journal -p StandardError=journal -p SyslogIdentifier=fedokawaii-dnf \
    -E LC_ALL=C.UTF-8 /usr/bin/dnf "$@" 9>&- && rc=0 || rc=$?
  sleep 1; kill "$FOLLOWER" 2>/dev/null || true; wait "$FOLLOWER" 2>/dev/null || true; FOLLOWER=""
  journalctl -o cat --no-pager "_SYSTEMD_UNIT=$unit.service" >>"$LOG_FILE" 2>/dev/null || true
  return "$rc"
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
  local p q avail gpu rc=0 want=() miss=() gone=() failed=() bad=() mine=() ui others
  gpu=$(cat "$STATE_DIR/gpu" 2>/dev/null || echo amd)
  mapfile -t want < <(manifest_all "$gpu")
  # on AMD, Fedora's own Vulkan driver (brought back by a move, say) swapped for RPM Fusion's
  # again, as setup did — the two conflict, and the freeworld one is the desktop's
  if [[ $gpu == amd ]] && pkg_installed mesa-vulkan-drivers; then
    run dnf -y swap mesa-vulkan-drivers mesa-vulkan-drivers-freeworld --allowerasing \
      || { log "could not swap mesa-vulkan-drivers for the freeworld build — repair tries again"; rc=1; }
  fi
  for p in "${want[@]}"; do pkg_provided "$p" || miss+=("$p"); done
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
  # (and on AMD, the 32-bit drivers Steam's step added — by arch: the 64-bit ones stay)
  if [[ $STEAM != yes ]]; then
    local gi=()
    mapfile -t gi < <(dnf repoquery --userinstalled --qf '%{name}.%{arch}\n' 2>/dev/null \
                      | grep -xE 'mesa-(vulkan|va)-drivers-freeworld\.i686' || true)
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
  record last-update "$(date +%s) stopped"         # (until it gets to the end)
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
  dnf_upgrade || die "dnf could not update (the lines above say why) — the snapshot taken before it is the way back (fedokawaii snapshots); try again later, or: fedokawaii repair"
  # then the system values of fedokawaii.conf, applied again — each on its own: edit it
  # (fedokawaii settings), then update (keyboard layouts take effect at the next login)
  step_on "the toolkit's command" install_toolkit
  step_on "the old name's leftovers" retire_old_name
  step_on "dnf's settings" s_dnf
  step_on "the time zone" timedatectl set-timezone "$TIMEZONE"
  step_on "the session launcher (keyboard)" install_start_dwl
  step_on "inbound SSH ($SSH_SERVER)" s_ssh
  step_on "the performance profile" s_tuning
  step_on "the manifest" manifest_sync
  step_on "the machine's own drivers and firmware" s_hardware
  step_on "nothing doubled or fighting" r_hygiene
  step_on "dwl's own wlroots" wlr_step
  # the desktop's own tools: pinned, so normally nothing to do
  for e in "${UPSTREAM[@]}"; do step_on "${e%%|*}" install_upstream_bin "$e"; done
  step_on "Nerd Fonts" install_nerd_fonts
  step_on "PixelMplus 12" install_pixelmplus
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
  step_on "neovim's plugins" nvim_plugins
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
libs_ready() {   # libs_ready N — the libraries our own builds need, all in Fedora N?
                 # 0 yes (or only a tool's is missing: reported) · 1 one dwl needs is missing ·
                 # 2 Fedora N's repositories could not be asked (nothing is concluded)
  local f so kept provided missing=() hard=0 caps
  local -A users=() core=()
  kept=$(wlr_home)/lib
  for f in /usr/local/bin/dwl "$kept"/*.so* /usr/local/libexec/xdg-desktop-portal-termfilechooser \
           "$TARGET_HOME"/.local/bin/{kawa-veil,kawa-clipkeep,satty,spotify_player,yazi,ya,presenterm}; do
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
  provided=$(dnf -q --releasever="$1" repoquery --whatprovides="${caps%,}" --qf '%{provides}\n' 2>/dev/null) \
    || { log "Fedora $1's repositories could not be asked which libraries they have"; return 2; }
  for so in "${!users[@]}"; do
    grep -qxF "${so}()(64bit)" <<<"$provided" && continue
    missing+=("$so (${users[$so]% })")
    [[ -n ${core[$so]:-} ]] && hard=1
  done
  ((${#missing[@]} == 0)) && return 0
  log "not in Fedora $1: $(IFS=','; echo "${missing[*]}" | sed 's/,/ · /g')"
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
  libs_ready "$to" && r=0 || r=$?
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
# r_hygiene — nothing doubled, nothing fighting (lib/hygiene.sh has the scan, verify shows
# it): packages installed twice, what dnf check finds, services that fight the desktop's own,
# a login other than greetd, dependencies nothing needs, what a stopped run left. Each part
# on its own; what cannot be put right is said, and the rest goes on.
r_hygiene() {
  local u why list rc=0 dm pk=()
  # the login first: switching off a login manager that fights greetd (below) also takes
  # the display-manager link, so greetd is put back here whatever holds that link — another
  # login manager, or nothing at all
  dm=$(hy_display_manager)
  if [[ $dm != greetd.service ]]; then
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
  [[ -x /usr/local/bin/kawa-greeter ]] || install -m 0755 "$REPO_DIR/system/kawa-greeter" /usr/local/bin/
  restorecon -R /usr/local/bin /usr/local/sbin /etc/greetd 2>/dev/null || true
  systemctl is-enabled --quiet greetd.service || systemctl enable greetd.service
  systemctl enable --now snapper-timeline.timer snapper-cleanup.timer 2>/dev/null || true
  grep -q '^root ' <<<"$(snapper list-configs)" || run snapper -c root create-config /
  snapper_limits
  snap_hooks
  s_scrub
  s_tuning
}
r_ports() { s_ssh; torrent_port; }   # SSH as SSH_SERVER says; torrra's port open
r_boot() {       # the boot: the menu's success timer, no rescue image; neovim the editor
  systemctl --global enable grub-boot-success.timer
  editor_policy
}
r_services() {   # the services setup enabled (a package reinstalled after a move starts off)
  systemctl enable bluetooth.service fstrim.timer
  # (LACT only while it is there: retired, or gone with its COPR, it is no longer a fault)
  if [[ $(cat "$STATE_DIR/gpu" 2>/dev/null) == amd ]] && systemctl cat lactd.service >/dev/null 2>&1; then
    systemctl enable lactd.service
  fi
  i2c_dev
}
r_user() {       # the user's session plumbing: linger, the bus, groups, fonts, secrets.sh's mode
  local sec=$TARGET_HOME/.config/fedokawaii/secrets.sh
  loginctl enable-linger "$TARGET_USER"
  s_groups
  if [[ $STEAM == yes ]]; then usermod -aG gamemode "$TARGET_USER"; fi
  retry 15 2 test -S "/run/user/$TARGET_UID/bus"
  if [[ -e $sec && ! -L $sec ]]; then
    [[ $(stat -c %u "$sec") == "$TARGET_UID" ]] || chown -h "$TARGET_UID:$TARGET_GID" "$sec"
    as_user chmod 600 "$sec"
  fi
  as_user fc-cache -f >/dev/null
  as_user systemctl --user reset-failed || true
}
r_upstream() {   # release binaries and fonts present (each is a no-op when current) — each
  local e rc=0   # tried even when one before it failed
  for e in "${UPSTREAM[@]}"; do install_upstream_bin "$e" || rc=1; done
  install_nerd_fonts || rc=1
  install_pixelmplus || rc=1
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
do_repair() {
  # (once setup reached its last check everything is installed: repair may put right what that
  # check found, before the login is switched on)
  [[ $(phase) == 'done' || ( $(phase) == 3 && -f $STATE_DIR/gate-reached ) ]] \
    || die "the build is not finished — run setup again; it resumes where it stopped"
  local before after net=1
  hdr "Fedokawaii repair · $TARGET_USER"
  # offline, it still puts right what needs no network: services, the session, the configs
  retry 6 5 online || { net=0; log "offline: only what needs no network is repaired now — run repair again once online"; }
  toolkit_first          # (run from a copy: everything below is then the toolkit's)
  before=$(problems)
  log "verify found $before problem(s) — fixing what can be fixed"
  heal "the old name's leftovers" retire_old_name
  ((net)) && heal "packages (dnf's state, the manifest complete, nothing forbidden)" r_packages
  ((net)) && heal "this machine's drivers and firmware" s_hardware
  heal "nothing doubled or fighting (twice-installed, services, the login, unneeded, leftovers)" r_hygiene
  heal "system services, login, snapshots" r_system
  heal "the login (greetd and its greeter)" greetd_config
  heal "the boot (success timer, no rescue image) and the editor" r_boot
  heal "services (Bluetooth, TRIM, the GPU tool, i2c-dev)" r_services
  heal "dnf's settings" s_dnf
  heal "the time zone ($TIMEZONE)" timedatectl set-timezone "$TIMEZONE"
  heal "inbound SSH ($SSH_SERVER) and the torrent port" r_ports
  heal "your session (linger, groups, fonts, secrets.sh mode)" r_user
  ((net)) && heal "dwl (its wlroots, libraries, binary)" r_dwl
  ((net)) && heal "release binaries, fonts and GE-Proton" r_upstream
  ((net)) && heal "the yazi file dialog (termfilechooser ${TFC_TAG:-})" r_filechooser
  ((net)) && heal "torrra" torrra_up
  ((net)) && heal "neovim's plugins (any missing)" r_nvim
  heal "Prowlarr (it starts, and takes the key from secrets.sh)" prowlarr_up
  heal "the theme (configs, dwl, helpers, wallpapers)" r_theme
  record_snapshots
  after=$(problems)
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
