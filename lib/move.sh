# shellcheck shell=bash
# lib/move.sh — the next Fedora, through the same button (.claude/notes/update-design.md §4.4). A
# press that ends with this Fedora current looks at the next one:
#   out, settled    released(), then WAIT days (upkeep.conf, 7) — sooner when this one ends within
#                   60 days, or when asked (fedokawaii upgrade --now)
#   its repositories  RPM Fusion has it; a COPR with no build for it is left out, said
#   the test VM     a fresh Fedora N with this whole desktop on it, in a VM (tools/vm-preflight.sh).
#                   Its verdict in UPD/preflight-N for 30 days: green goes on; red → "Fedora N
#                   waits" with the checks, tried again after those days or with a newer toolkit
#   told            the first press that gets this far only says so: "press update again". Never
#                   a restart he was not told about
#   a copy first    the next press: the whole move tried in a copy of this system (cand_try), the
#                   snapshot pinned, Fedora's own download, the restart: its offline transaction
#   judged by facts the next start, before the login (setup.sh --after-upgrade), never by dnf's
#                   word (it reports failures on a half-done system): the release, every package of
#                   the set, then the desktop's steps, verify and the desktop's start against the
#                   press's baseline. Red anywhere → the pinned snapshot back, one restart, said
# Sourced by setup.sh after lib/update.sh. UPD survives a restore: everything the outcome needs is there.
MOVE=$UPD/move                # FROM TO SNAPSHOT TIME — armed before the restart, until it is judged
MOVE_TOLD=$UPD/move-told      # N: "ready" was said; the next press moves
MOVE_SET=$UPD/move-set        # NAME OLD NEW of the move's transaction, as up_set writes them
MOVE_LAST=$UPD/last-upgrade   # TIME FROM TO ok|partial|checks|failed: the status, the login's notice
MOVE_AFTER=/etc/systemd/system/fedokawaii-after-upgrade.service
MOVE_VALID=$((30 * 86400))    # (a verdict is tried again after this long: monthly, design §4.4)
MOVE_SKIP=()

# what the verdicts were made with: a newer toolkit tries again what a red one refused
toolkit_id() { cat "$REPO_DIR/setup.sh" "$REPO_DIR/theme.sh" "$REPO_DIR"/lib/*.sh 2>/dev/null | sha256sum | cut -c1-12; }
move_verdict() {   # move_verdict FILE → 0 green · 1 red, recent, same toolkit: its reasons on stdout · 2 none
  local st=- t=0 id=-
  [[ -s $1 ]] && IFS=' ' read -r st t id <"$1"
  [[ $t =~ ^[0-9]+$ ]] && (($(date +%s) - t < MOVE_VALID)) || return 2
  [[ $st == green ]] && return 0
  [[ $st == red && $id == "$(toolkit_id)" ]] || return 2
  sed 1d -- "$1"; return 1
}
move_write() {   # move_write FILE green|red WHY — a verdict kept
  printf '%s %s %s\n%s\n' "$2" "$(date +%s)" "$(toolkit_id)" "${3:-}" | write_file "$1" 0644
}
move_say() {   # move_say NOTICE-ID LINE — said in the window and, once a day for the same line, as a notice
  log "$2"
  local seen=$UPD/move-said; [[ $(cat "$seen" 2>/dev/null) == "$(date +%F) $2" ]] && return 0
  printf '%s %s\n' "$(date +%F)" "$2" | write_file "$seen" 0644 2>/dev/null || true
  as_user notify-send -a update -u "$1" -- update "$2" 2>/dev/null || true
}
move_waits() { move_say critical "Fedora $1 waits: $(head -n1 <<<"$2") (Fedora $FEDORA_VER stays as it is)"; }

# ── the gates ────────────────────────────────────────────────────────────────────────────────
move_gates() {   # move_gates N [--now] → 0 go on · 1 not yet (said only when it is out)
  local n=$1 now_flag=${2:-} out wait end t r ok_rf=1 c
  out=$(released "$n") || { [[ -z $now_flag ]] || log "Fedora $n is not released yet"; return 1; }
  wait=$(upkeep WAIT 7); end=$(support_end || echo 0)
  t=$(( (out + wait * 86400 - $(date +%s) + 86399) / 86400 ))
  if ((t > 0)) && [[ $now_flag != --now ]] && ! ((end > 0 && end - $(date +%s) < 60 * 86400)); then
    log "Fedora $n is out; it settles $wait days — offered in $t day(s)"; return 1
  fi
  # (its release tree, not its release package: that one is published months ahead)
  for r in free nonfree; do
    retry 2 10 "${CURL[@]}" -o /dev/null --head \
      "https://download1.rpmfusion.org/$r/fedora/releases/$n/Everything/x86_64/os/repodata/repomd.xml" || ok_rf=0
  done
  ((ok_rf)) || { log "RPM Fusion has no Fedora $n yet — it waits for that"; return 1; }
  MOVE_SKIP=()
  for c in "${COPRS[@]}"; do
    "${CURL[@]}" --max-time 15 "https://copr.fedorainfracloud.org/api_3/project?ownername=${c%%/*}&projectname=${c#*/}" 2>/dev/null \
      | jq -e --arg ch "fedora-$n-x86_64" '.chroot_repos | has($ch)' >/dev/null 2>&1 \
      || { MOVE_SKIP+=("--disablerepo=copr:copr.fedorainfracloud.org:${c/\//:}"); log "COPR $c has nothing for Fedora $n yet — left out; its packages stay as they are"; }
  done
  libs_ready "$n" "${MOVE_SKIP[@]}" && r=0 || r=$?
  ((r != 2)) || { log "Fedora $n's repositories could not be asked which libraries they have — the next press tries again"; return 1; }
  ((r == 0)) || { move_waits "$n" "a library dwl needs is not in it"; return 1; }
  return 0
}
move_tryvm() {   # move_tryvm N → 0 green · 1 not: said. The test VM, unless a verdict stands
  local n=$1 f=$UPD/preflight-$1 why rc=0 tmp
  why=$(move_verdict "$f") || rc=$?
  ((rc == 0)) && return 0
  ((rc == 1)) && { move_waits "$n" "$why"; return 1; }
  log "Fedora $n is tried first: a test VM, this whole desktop installed on it from nothing — about an hour, in the background, this system untouched"
  tmp=$(as_user mktemp) || die "no room for a file of yours in /tmp — nothing changed"; rc=0
  as_user nice -n 19 bash "$REPO_DIR/tools/vm-preflight.sh" "$n" --out "$tmp" || rc=$?
  why=$(cat "$tmp" 2>/dev/null) || why=""; rm -f -- "$tmp"
  case $rc in
    0) move_write "$f" green ""; ok "Fedora $n is green in the test VM" ;;
    1) move_write "$f" red "${why:-the test VM says red, with no reason}"
       move_waits "$n" "${why:-the test VM says red}"; return 1 ;;
    *) move_say normal "the test VM for Fedora $n could not run (${why:-the lines above}) — the next press tries again"; return 1 ;;
  esac
}

# ── the press's end ──────────────────────────────────────────────────────────────────────────
# up_move_step [--now] — after a press whose system is current: said, tried, or moved. --now is
# fedokawaii upgrade: no settling, no "press again" (asked in so many words)
up_move_step() {
  local n=$((FEDORA_VER + 1)) flag=${1:-} why told=""
  [[ $UP_END == @(ok|current|held) ]] || return 0
  move_gates "$n" "$flag" || return 0
  why=$(move_verdict "$UPD/move-red-$n") || {
    (($? == 1)) && { move_waits "$n" "$why"; return 0; }
  }
  move_tryvm "$n" || return 0
  told=$(cat "$MOVE_TOLD" 2>/dev/null) || told=""
  if [[ $told != "$n" && $flag != --now ]]; then
    echo "$n" | write_file "$MOVE_TOLD" 0644
    hdr "Fedora $n is ready: press update again to move to it (a restart, 20–40 minutes)"
    move_say normal "Fedora $n is ready: press update again to move to it (a restart, 20–40 minutes)"
    return 0
  fi
  do_move "$n"
}
do_move() {   # do_move N — every gate green and he knows: tried in a copy, snapshot, download, restart
  local n=$1 from=$FEDORA_VER erase=()
  # (a kernel on trial first: the way back of the move's own kernel is the kernel running now)
  if [[ -s $UPD/probation ]] && awk '$2 != "-" { f = 1 } END { exit !f }' "$UPD/probation"; then
    hdr "a new kernel is on trial: restart, then press update again — Fedora $n follows"; return 0
  fi
  preflight 20480
  wlr_keep || { move_waits "$n" "dwl's own wlroots is missing and cannot be kept: fedokawaii repair first"; return 0; }
  if [[ $(as_user podman info --format '{{.Host.DatabaseBackend}}' 2>/dev/null) != sqlite ]]; then
    run as_user podman system migrate --migrate-db || log "podman's database not migrated — Prowlarr may need: podman system migrate --migrate-db"
  fi
  repos_lenient
  hdr "the move to Fedora $n, tried first in a copy of this system"
  up_top; rm -rf -- "$UPD/tx"
  if ! dnf_detached -y --setopt=keepcache=True --releasever="$n" distro-sync --store="$UPD/tx" "${MOVE_SKIP[@]}"; then
    # (what stands in its way may go: what the desktop needs comes back after the move if the new
    # release has it — the test VM has just shown that it does)
    log "dnf cannot resolve the move as it is — trying again, letting it remove what stands in the way"
    rm -rf -- "$UPD/tx"; erase=(--allowerasing)
    dnf_detached -y --setopt=keepcache=True --releasever="$n" distro-sync --store="$UPD/tx" --allowerasing "${MOVE_SKIP[@]}" \
      || { rm -rf -- "$UPD/tx"; move_waits "$n" "dnf cannot resolve or download the move (the log says why)"; return 0; }
  fi
  up_set "$UPD/tx" >"$MOVE_SET"
  log "$(wc -l <"$MOVE_SET") packages to move"
  if ! FK_MOVE=1 cand_try "$UPD/tx"; then
    move_write "$UPD/move-red-$n" red "$(cat "$UPD/why" 2>/dev/null)"
    rm -rf -- "$UPD/tx"; dnf -q clean packages >/dev/null 2>&1 || true
    move_waits "$n" "$(head -n1 "$UPD/why" 2>/dev/null)"; return 0
  fi
  ok "green in the copy: Fedora $n"
  rm -rf -- "$UPD/tx"
  # the system before it: first, so the download and what arms the restart are not part of it
  snapshot_before "Fedora $n" important
  snapper -c root modify -c '' "$SNAP_N" >/dev/null 2>&1 || log "snapshot $SNAP_N could not be pinned — it is kept as an important one"
  printf '%s\n' "$SNAP_N" | write_file "$UPD/snap" 0644
  log "downloading Fedora $n (nothing is installed yet)"
  if ! retry 2 30 dnf_detached -y system-upgrade download --releasever="$n" "${erase[@]}" "${MOVE_SKIP[@]}"; then
    dnf system-upgrade clean >/dev/null 2>&1 || true
    move_waits "$n" "the download stopped (the network?) — nothing changed; press update again"; return 0
  fi
  move_arm "$from" "$n"
  hdr "ready: restarting into the installation of Fedora $n in 30 seconds (20–40 minutes; leave it on)"
  as_user notify-send -a update -u critical -- update "restarting in 30 seconds: the move to Fedora $n (20–40 minutes; leave it on)" 2>/dev/null || true
  sleep "${MOVE_PAUSE:-30}"
  if ! dnf -y system-upgrade reboot; then   # (should it not restart: nothing armed is left behind)
    move_disarm
    dnf system-upgrade clean >/dev/null 2>&1 || true
    die "dnf could not arrange the restart into Fedora $n — nothing changed"
  fi
}
move_arm() {   # move_arm FROM TO — what the next starts need, written after the snapshot: a restore takes it all back
  local kc=/etc/kernel/cmdline
  write_file "$MOVE_AFTER" <<EOF
# installed by setup.sh (lib/move.sh) for the move to Fedora $2; gone once it is judged. Before the
# login: a desktop not yet rebuilt for the new release must not be started. Its own domain, as the
# update's (fedokawaii.sh update_unit): its desktop check cannot start a desktop from initrc_t
[Unit]
Description=Fedokawaii: the move to Fedora $2 judged and finished
After=network-online.target fedokawaii-update-resume.service plymouth-quit-wait.service
Wants=network-online.target
Before=display-manager.service greetd.service
Conflicts=getty@tty1.service kmsconvt@tty1.service
ConditionPathExists=$MOVE

[Service]
Type=oneshot
SELinuxContext=system_u:system_r:unconfined_service_t:s0
ExecStart=/usr/bin/bash $TOOLKIT/setup.sh --after-upgrade
TimeoutStartSec=0
StandardInput=null
StandardOutput=tty
StandardError=tty
TTYPath=/dev/tty1
TTYReset=yes
TTYVHangup=yes
Environment=TERM=linux

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload; systemctl enable fedokawaii-after-upgrade.service >/dev/null 2>&1
  printf '%s %s %s %s\n' "$1" "$2" "${SNAP_N:-}" "$(date +%s)" | write_file "$MOVE" 0644
  # the new kernel on trial, as after any update (up_probation; design §4.3) — four: the offline
  # start counts too. A start that fails is made a restart: its arguments through the file its
  # boot entry is written from (kernel-install, in the transaction)
  grub2-editenv - set boot_counter=4 boot_success=0 boot_indeterminate=1 || log "GRUB's start counting could not be armed (grub2-editenv)"
  if [[ -s $kc ]] && ! grep -qF "$UP_TRIAL" "$kc"; then
    printf '%s %s\n' "$(tr -d '\n' <"$kc")" "$UP_TRIAL" | write_file "$kc" 0644
  fi
  printf '%s\n' "# installed by fedokawaii (lib/move.sh) while the move's kernel is on trial" \
    '[Manager]' 'RuntimeWatchdogSec=1min' | write_file "$UP_DOG" 0644
}
move_disarm() {
  rm -f -- "$MOVE" "$UP_DOG"
  grub2-editenv - unset boot_counter >/dev/null 2>&1 || true
  sed -i "s/ $UP_TRIAL//" /etc/kernel/cmdline 2>/dev/null || true
  move_unit_off
}
move_unit_off() {
  [[ -e $MOVE_AFTER ]] || return 0
  systemctl disable fedokawaii-after-upgrade.service >/dev/null 2>&1 || true
  rm -f -- "$MOVE_AFTER"; systemctl daemon-reload || true
}

# ── the start after it ───────────────────────────────────────────────────────────────────────
# do_after_upgrade — before the login: is the move whole; the rest of it (each part on its own, a
# failure reported, the rest goes on); the checks against the press's baseline. Cut by a power
# failure, it starts again at the next start (MOVE stays until the end): every part is idempotent
do_after_upgrade() {
  [[ -s $MOVE ]] || { move_unit_off; exit 0; }
  local from="" to="" snap="" _t result=ok why="" newest net=1 n
  IFS=' ' read -r from to snap _t <"$MOVE" || true
  if [[ $FEDORA_VER != "$to" ]]; then why="its installation did not take: this is still Fedora $FEDORA_VER"
  elif ! move_whole; then why="its installation did not finish: packages are missing or there twice"; fi
  [[ -z $why ]] || { move_undo "$from" "$to" "$snap" "$why"; exit 0; }
  hdr "Fedora $to is in: the desktop rebuilt for it, then checked (a few minutes)"
  UPDATE_STEPS_FAILED=()
  WAIT_STEP=5 wait_until 300 online || { net=0; UPDATE_STEPS_FAILED+=("no network: what needs it is left for the next update"); log "no network yet — the steps that need it are left for the next update"; }
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
  step_on "dnf's guard and what it knows (the new release's libraries)" guard_hooks
  step_on "Prowlarr (Podman may have moved its store)" prowlarr_up
  ((${#UPDATE_STEPS_FAILED[@]} == 0)) || result=partial
  if ! u_check; then move_undo "$from" "$to" "$snap" "$(cat "$UPD/why" 2>/dev/null)"; exit 0; fi
  # kept. Its snapshot, the kernel before it and its trial stay until a start has reached the
  # desktop: the probation closes them (lib/update.sh up_probation_close)
  newest=$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-core 2>/dev/null | sort -V | tail -n1) || newest=-
  printf '%s %s %s\n' "${snap:--}" "${newest:--}" "$(date +%F)" >>"$UPD/probation"
  sed -i "s/ $UP_TRIAL//" /etc/kernel/cmdline 2>/dev/null || true
  step_on "a new baseline snapshot" new_baseline "$to"
  ((${#UPDATE_STEPS_FAILED[@]} == 0)) || result=partial
  # for you to look at, never changed by itself: configuration files the move could not merge
  # (.rpmnew beside yours), and packages no longer in any repository
  n=$(find /etc \( -name '*.rpmnew' -o -name '*.rpmsave' \) 2>/dev/null | tee "$STATE_DIR/rpmnew" | wc -l) || n=0
  ((n == 0)) || log "$n configuration file(s) to compare (list: $STATE_DIR/rpmnew)"
  dnf -q repoquery --installed --extras --exclude='kernel*,gpg-pubkey' --qf '%{name}\n' 2>/dev/null >"$STATE_DIR/extras" || true
  record last-update "$(date +%s) $result"
  record last-update-done "$(date +%s)"
  record_snapshots
  printf '%s %s %s %s\n' "$(date +%s)" "$from" "$to" "$result" | write_file "$MOVE_LAST" 0644
  rm -f -- "$MOVE" "$MOVE_TOLD" "$MOVE_SET" "$UPD/preflight-$to" "$UPD/move-red-$to" "$UPD/move-said" "$UPD/snap"
  up_phase end || true
  move_unit_off
  ok "Fedora $to is in place ($result)"
}
move_whole() {   # every package of the move's set at its new version, nothing twice (dnf's own
                 # "check" is no verdict here: a third-party package may wait for its repository)
  [[ -s $MOVE_SET ]] || return 1
  up_complete "$MOVE_SET" nocheck
}
move_undo() {   # move_undo FROM TO SNAPSHOT WHY — the system before the move, at one restart; said
  local from=$1 to=$2 snap=$3 why=$4
  log "the move to Fedora $to is undone: ${why//$'\n'/ · }"
  move_write "$UPD/move-red-$to" red "$why"
  printf '%s %s %s failed\n' "$(date +%s)" "$from" "$to" | write_file "$MOVE_LAST" 0644
  grub2-editenv - unset boot_counter >/dev/null 2>&1 || true
  # (its pin goes with the next good start, as an update's)
  [[ -z $snap ]] || printf '%s - %s\n' "$snap" "$(date +%F)" >>"$UPD/probation"
  if [[ -z $snap ]] || ! /usr/local/sbin/kawa-snap restore "$snap"; then
    rm -f -- "$MOVE"; move_unit_off
    up_tell "the move to Fedora $to went wrong: $(head -n1 <<<"$why")" "snapshot ${snap:-?} is the system before it, and could not be put back by itself: Super+U → snapshots"
    return 0
  fi
  rm -f -- "$MOVE" "$MOVE_TOLD" "$MOVE_SET" "$UPD/snap"
  up_tell "the move to Fedora $to was undone: $(head -n1 <<<"$why")" "back on Fedora $from as it was (snapshot $snap); it is tried again after a month or with a newer toolkit"
  systemctl reboot
}
