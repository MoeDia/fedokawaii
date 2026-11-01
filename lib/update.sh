# shellcheck shell=bash
# lib/update.sh — the update button (Super+U → update): one run from A to Z, in phases
# (.claude/notes/update-design.md §4). Each phase is written to UPD/phase as it begins, so a run
# cut anywhere is known to the next one, which finishes or undoes it — never repeats it half-way:
#   start      may it start: no other package manager at work, room on every disk, the games
#              VM off; the checks before it (what is red already is the baseline)
#   fetch      the repositories refreshed; the transaction resolved once and stored, not run
#   candidate  a copy of this system receives it first, in a container of its own; red → the
#              culprits found in fresh copies (halves of the set) and held, the rest stored again
#   snapshot   every stored package's signature checked; the system before it, pinned
#   replay     that same transaction on the running system, then the desktop's own steps
#   check      verify (only new reds count) and the desktop's start
#   end        kept — or the system before it back (at the next start) and the set held; the report
# Sourced by setup.sh: its log, die, record, dnf_detached and the update's own steps.
UPD=$STATE_DIR/update                # (the fk subvolume once T48 makes it: never rolled back)
UP_TOP=/run/fedokawaii/top           # the file system's top level, while a candidate exists
UP_CAND=$UP_TOP/root.cand
UP_RUN=$(date +%s)

up_phase() {   # (not written: a full disk — fatal only once the running system is about to change)
  if printf '%s %s\n' "$1" "$UP_RUN" | write_file "$UPD/phase" 0644 2>/dev/null; then return 0; fi
  if [[ $1 != @(start|fetch|candidate|end) ]]; then
    die "the update's state could not be written to $UPD (a full disk?) — nothing changed on the running system"
  fi
}
up_was() { local p=end; [[ -s $UPD/phase ]] && IFS=" " read -r p _ <"$UPD/phase"; echo "$p"; }
up_labels() { sed 's/ — .*//' | sort -u; }   # (a check's label: its detail after the dash may vary)

# ── start ────────────────────────────────────────────────────────────────────────────────────
u_start() {
  up_phase start
  local p d un why rc=0
  # (a restore waits for the restart — the running root is no longer the system's — or a snapshot
  # started from the boot menu: an update there would pin, hold and change the wrong system)
  on_the_system || die "this start is not the system itself (a restore waits for the restart, or a snapshot from the boot menu runs) — restart first; nothing changed"
  # (SELinux on: a domain that may start a desktop — the update's unit, unconfined_service_t
  # (fedokawaii.sh update_unit), or yours by hand, unconfined_t; bash a unit starts without it
  # lands in initrc_t, where the desktop check's bar never starts and every check would be blind)
  d=$(id -Z 2>/dev/null) || d=""
  if selinuxenabled 2>/dev/null && [[ $d != *:@(unconfined_service_t|unconfined_t):* ]]; then
    die "this run is in SELinux's ${d:-unknown} domain, where the desktop's start check cannot start a desktop — press update in Super+U (fedokawaii update); nothing changed"
  fi
  for p in dnf5 dnf packagekitd dnf5daemon-server; do
    if pgrep -x "$p" >/dev/null 2>&1; then die "another package manager is running ($p) — update again once it has finished"; fi
  done
  for d in /sys/bus/pci/devices/*; do
    [[ $(cat "$d/class" 2>/dev/null) == 0x03* && $(readlink "$d/driver" 2>/dev/null) == */vfio-pci ]] || continue
    die "the games VM holds the graphics card — stop it, then update"
  done
  # (the copy's container: without it every update would look red — said, never guessed)
  command -v systemd-nspawn >/dev/null || die "systemd-nspawn is missing (systemd-container) — fedokawaii repair puts it in; nothing changed"
  up_leftovers   # (before the space is measured: a stale copy is gigabytes)
  preflight 15360
  if mountpoint -q /boot/efi; then need_space /boot/efi 50; fi
  # (Btrfs writes into unallocated chunks: free space alone can hide a disk that cannot take a write)
  un=$(btrfs filesystem usage -b / 2>/dev/null | awk '/Device unallocated:/ { print $3; exit }') || un=""
  if [[ $un =~ ^[0-9]+$ ]] && ((un < 5 * 1024 ** 3)); then
    die "only $(numfmt --to=iec --suffix=B "$un") of the disk is unallocated — this needs 5GB: delete old snapshots (fedokawaii snapshots), then: sudo btrfs balance start -dusage=50 /"
  fi
  # (the checks' own tools first: an install from before they were in the manifest lacks them, and
  # an update that cannot check could never be the one that brings them)
  rpm -q python3-pillow >/dev/null 2>&1 || dnf_install python3-pillow || die "the checks' own tool could not be installed (python3-pillow) — nothing changed"
  log "the checks before it (what is red now does not count against the update)"
  bash "$REPO_DIR/verify.sh" >/dev/null 2>&1 || true
  cp -- "$STATE_DIR/last-verify-fails" "$UPD/baseline" 2>/dev/null || : >"$UPD/baseline"
  why=$(up_more) || rc=$?
  ((rc == 2)) && die "the desktop's start check could not run ($why) — nothing changed; press update again"
  [[ -z $why ]] || { log "red before the update: ${why//$'\n'/ · }"; printf '%s\n' "$why" >>"$UPD/baseline"; }
}
up_leftovers() {   # what a run cut before its end left (a power cut: no exit trap ran) — its copy
                   # of the system, dropped; its pinned snapshot, if no probation took it over
                   # (every green run's does), back to snapper's number cleanup
  local n
  n=$(cat "$UPD/snap" 2>/dev/null) || n=""
  if [[ $n =~ ^[0-9]+$ ]] && ! grep -q "^$n " "$UPD/probation" 2>/dev/null; then
    snapper -c root modify -c number "$n" >/dev/null 2>&1 || log "snapshot $n could not be released to the cleanup (snapper)"
    rm -f -- "$UPD/snap"
  fi
  btrfs subvolume list / 2>/dev/null | awk '$NF == "root.cand" { f = 1 } END { exit !f }' || return 0
  up_top; cand_drop
}
# desk_reds VERDICT — the desktop check's verdict ("session-start (dark): not running: waybar ·
# nothing drawn: …", "bar-geometry (light): the clock's gaps: …"), a line an item, the item in the
# label (up_labels compares what comes before " — "): a red that was there before the update — the
# light theme's clock, say — never hides one it brings, mako gone. "not running: X" keeps its name;
# any other item is named up to its first ": "; the bar's measure keeps its theme
desk_reds() {
  awk '{ if (match($0, /^[a-z-]+ \([a-z]+\): /)) { head = substr($0, 1, RLENGTH - 2); rest = substr($0, RLENGTH + 1) }
         else { head = $1; rest = $0 }
         n = split(rest, it, / · /)
         for (i = 1; i <= n; i++) {
           k = it[i]; if (k !~ /^not running: /) { j = index(k, ": "); if (j) k = substr(k, 1, j - 1) }
           if (head ~ /^bar-geometry/) k = head ": " k
           print "the desktop does not start: " k " — " head ": " it[i] } }' <<<"$1"
}
up_more() {   # the checks verify does not make, a line for each that is red: the desktop's start
              # (desktop_starts), and our builds' libraries and the boot pieces (lib/cand-check.sh:
              # every boot entry with root= and rootflags=, its image readable, btrfs in it or built in)
  local why out rc=0
  why=$(desktop_starts) || rc=$?
  # (2: the check itself could not run — no verdict on the update: the caller stops the run)
  ((rc == 2)) && { printf '%s\n' "${why:-no reason given}"; return 2; }
  ((rc == 0)) || desk_reds "$why"
  # (into a variable first: a red check's exit inside a pipe would set off setup.sh's ERR trap)
  out=$(FK_USER=$TARGET_USER bash "$REPO_DIR/lib/cand-check.sh" 2>/dev/null) || true
  printf '%s\n' "$out" | sed -n 's/^red: //p'
}

# ── fetch ────────────────────────────────────────────────────────────────────────────────────
u_fetch() {   # → 0 a transaction stored in UPD/tx · 1 nothing to update
  up_phase fetch
  local rc=0 off=() tp=() trial=""
  repos_lenient
  up_holds_apply
  rm -rf -- "$UPD/tx"
  dnf -q --refresh check-upgrade >/dev/null 2>&1 || rc=$?
  ((rc == 0)) && return 1
  ((rc == 100)) || die "dnf could not read the repositories (check-upgrade: exit $rc) — nothing changed; try again later"
  # (a kernel on trial, not yet proven: no other kernel this press — it would take the place of
  # the one GRUB falls back to; it comes once the trial has closed)
  [[ -s $UPD/probation ]] && trial=$(awk '$2 != "-" { k = $2 } END { print k }' "$UPD/probation")
  if [[ -n $trial ]]; then
    off=("--exclude=$(IFS=,; echo "${KERNEL_PKGS[*]}")")
    log "no new kernel this time: kernel $trial is still on trial — restart, and the next update brings it"
  fi
  # resolved and downloaded once, stored instead of run: the candidate and the running system
  # get exactly this (dnf5-upgrade(8) --store, dnf5-replay(8))
  # (the downloads kept in dnf's cache too: the halves a red set is cut into are stored from it)
  if ! dnf_detached -y --setopt=keepcache=True upgrade --store="$UPD/tx" "${off[@]}"; then
    mapfile -t tp < <(third_party_off)
    ((${#tp[@]})) || die "dnf could not resolve or download the update — nothing changed (the lines above say why)"
    log "trying again without the third-party repositories ($(IFS=' '; echo "${tp[*]#--disablerepo=}"))"
    rm -rf -- "$UPD/tx"
    dnf_detached -y --setopt=keepcache=True upgrade --store="$UPD/tx" "${off[@]}" "${tp[@]}" || die "dnf could not resolve or download the update — nothing changed (the lines above say why)"
    UPDATE_STEPS_FAILED+=("third-party packages (a repository failed: dnf repo list; the next update tries again)")
  fi
  [[ -s $UPD/tx/transaction.json ]] || return 1    # (only held packages had updates)
  up_set "$UPD/tx" >"$UPD/set"
  log "$(wc -l <"$UPD/set") packages to update"
}
up_set() {   # up_set TXDIR → NAME OLD NEW, a line a package (OLD "-": new · NEW "-": removed)
  jq -r '.rpms[] | [.action, .nevra] | @tsv' "$1/transaction.json" | awk -F'\t' '
    function name(n) { sub(/-[^-]+-[^-]+$/, "", n); return n }
    function evr(n)  { sub(/\.[^.]+$/, "", n); match(n, /-[^-]+-[^-]+$/); return substr(n, RSTART + 1) }
    $1 == "Replaced" { old[name($2)] = evr($2); next }
    $1 == "Remove"   { gone[name($2)] = evr($2); next }
    { new[name($2)] = evr($2) }
    END { for (n in new) print n, (n in old ? old[n] : "-"), new[n]
          for (n in gone) if (!(n in new)) print n, gone[n], "-" }' | sort
}

# ── candidate ────────────────────────────────────────────────────────────────────────────────
up_top() {
  mountpoint -q "$UP_TOP" && return 0
  local dev; dev=$(findmnt -no SOURCE / | sed 's/\[.*//')
  { mkdir -p "$UP_TOP" && mount -o subvolid=5 "$dev" "$UP_TOP"; } || die "the top of $dev could not be mounted — nothing changed"
}
cand_drop() {
  [[ -d $UP_CAND ]] || return 0
  btrfs subvolume delete --commit-after "$UP_CAND" >/dev/null 2>&1 || log "the copy $UP_CAND could not be removed — the next update removes it"
}
cand_run() {   # cand_run TXDIR CMD… — CMD in the candidate, a container of its own: no network,
               # nothing reaching this system's udev, systemd or journal, the transaction read-only
               # at /tx, a scratch /boot (a new kernel's files land there, never in the real one),
               # the boot image starting this machine now read-only at /run/fk-ref.img
  local tx=$1 ref=(); shift
  [[ -s /boot/initramfs-$(uname -r).img ]] && ref=(--bind-ro="/boot/initramfs-$(uname -r).img:/run/fk-ref.img")
  systemd-nspawn --quiet --register=no --private-network --link-journal=no -D "$UP_CAND" \
    --bind-ro="$tx:/tx" --bind="$UPD/cand-boot:/boot" --bind-ro="$REPO_DIR/lib/cand-check.sh:/run/fk-check" "${ref[@]}" \
    --setenv=FK_USER="$TARGET_USER" -- "$@"
}
cand_try() {   # cand_try TXDIR → 0 green · 1 red (UPD/why says why). A container that does not even
               # start is no verdict on the packages: the run stops there, nothing changed
  local rc=0
  # (the scratch /boot shaped like the real one: its entries folder, grub's environment)
  cand_drop; rm -rf -- "$UPD/cand-boot"; mkdir -p "$UPD/cand-boot/loader/entries" "$UPD/cand-boot/grub2"
  cp -a /boot/grub2/grubenv "$UPD/cand-boot/grub2/" 2>/dev/null || true
  btrfs subvolume snapshot / "$UP_CAND" >/dev/null || die "a copy of the system could not be made (btrfs subvolume snapshot) — nothing changed"
  if ! cand_run "$1" /usr/bin/true >"$UPD/cand.log" 2>&1; then
    cand_drop; die "the copy's container would not start ($(grep -v '^$' "$UPD/cand.log" | tail -n1)) — nothing changed"
  fi
  # (the actions plugin off: in there its kawa-snap and guard would act on the copy for nothing)
  if ! cand_run "$1" dnf5 --disable-plugin=actions -y -C replay /tx >>"$UPD/cand.log" 2>&1; then
    printf 'the transaction does not go through: %s\n' "$(grep -v '^$' "$UPD/cand.log" | tail -n2 | tr '\n' ' ')" >"$UPD/why"; rc=1
  elif ! cand_run "$1" /usr/bin/bash /run/fk-check >>"$UPD/cand.log" 2>&1; then
    sed -n 's/^red: //p' "$UPD/cand.log" >"$UPD/why"; rc=1
  fi
  cand_drop; rm -rf -- "$UPD/cand-boot"
  return "$rc"
}
u_candidate() {   # the stored transaction proven in a copy first; red → culprits held, the rest again
  up_phase candidate
  up_top
  local n=0
  log "the update, tried first in a copy of the system"
  until cand_try "$UPD/tx"; do
    log "red in the copy: $(head -n1 "$UPD/why") — finding the package(s) that cause it"
    ((++n <= 3)) || die "the update stays red in a copy of the system after three holds — nothing changed: $(head -n1 "$UPD/why")"
    up_bisect || die "red in a copy of the system ($(head -n1 "$UPD/why")), and the package that causes it could not be found: a part of the set could not be tried on its own — nothing changed, nothing held; the next press tries again"
    [[ -s $UPD/tx/transaction.json ]] || return 0   # (everything held)
  done
  ok "green in the copy: $(wc -l <"$UPD/set") packages"
}
# up_bisect — the set is red: halves tried in fresh candidates (dnf resolves each on its own; the
# packages from the store's kept downloads) until the smallest red part is left; held; the rest
# stored again. ⌈log2 n⌉ rounds at most. Two halves green alone but red together: the two held
# together — never a guess. → 1 a half could not be tried at all: no culprit named, nothing held
# up_sources — NAME SOURCE for each stored package (its source package: the kernel's, Mesa's … whole
# families, built and broken together) into UPD/sources; bins_of SOURCE… → their packages in the set
up_sources() {
  rpm -qp --qf '%{name} %{sourcerpm}\n' "$UPD/tx/packages"/*.rpm 2>/dev/null \
    | sed -E 's/-[^-]+-[^-]+\.src\.rpm$//' | sort -u >"$UPD/sources" || true
}
bins_of() { local IFS=' '; awk -v want=" $* " 'index(want, " " $2 " ") { print $1 }' "$UPD/sources" | sort -u; }   # (IFS: setup.sh's joins $* with newlines)
up_bisect() {
  local s=() a=() b=() pk=() h ra rb n
  # (by source package: a family goes in, or is held, whole — never half a kernel)
  up_sources
  mapfile -t s < <(awk '$3 != "-" { print $1 }' "$UPD/set" | while IFS= read -r n; do
                     awk -v n="$n" '$1 == n { print $2; f = 1 } END { if (!f) print n }' "$UPD/sources"
                   done | sort -u)
  while ((${#s[@]} > 1)); do
    h=$((${#s[@]} / 2)); a=("${s[@]:0:h}"); b=("${s[@]:h}")
    mapfile -t pk < <(bins_of "${a[@]}"); up_try "${pk[@]}" && ra=0 || ra=$?
    if ((ra == 1)); then s=("${a[@]}"); continue; fi
    mapfile -t pk < <(bins_of "${b[@]}"); up_try "${pk[@]}" && rb=0 || rb=$?
    if ((rb == 1)); then s=("${b[@]}"); continue; fi
    ((ra == 0 && rb == 0)) || return 1
    break
  done
  mapfile -t s < <(bins_of "${s[@]}")
  up_hold "$(head -n1 "$UPD/why")" "${s[@]}"
  rm -rf -- "$UPD/tx"
  dnf -q -y upgrade --store="$UPD/tx" >/dev/null 2>&1 || true   # (the rest: the holds keep the culprits out)
  if [[ -s $UPD/tx/transaction.json ]]; then up_set "$UPD/tx" >"$UPD/set"; else : >"$UPD/set"; fi
}
up_try() {   # up_try NAME… → 0 their update alone is green in a fresh candidate · 1 red (UPD/why) ·
             # 2 it could not be tried (dnf could not resolve or store it on its own)
  rm -rf -- "$UPD/try"
  # (from the downloads the first store kept, else fetched again)
  dnf -q -y upgrade --store="$UPD/try" "$@" >/dev/null 2>&1 || return 2
  [[ -s $UPD/try/transaction.json ]] || return 2
  local rc=0; cand_try "$UPD/try" || rc=1
  rm -rf -- "$UPD/try"
  return "$rc"
}

# ── holds: the version that broke something kept out (dnf5-versionlock(8) exclude), recorded
# in UPD so a restore of / (which takes /etc/dnf/versionlock.toml back) cannot forget them ─────
UP_HELD=0
# (each a single dnf call for all its names — a whole set is a hundred, and every call loads the
# repositories; dnf5 adds only the versions not excluded yet, so a hold in force is never written
# twice: dnf5 5.4.6 dnf5/commands/versionlock/versionlock_exclude.cpp, exclude_versions)
up_hold() {   # up_hold WHY NAME… — each name's new version (from UPD/set) held
  local why=$1 n v at spec=(); shift
  for n; do
    v=$(awk -v n="$n" '$1 == n { print $3; exit }' "$UPD/set")
    [[ -n $v && $v != - ]] || continue
    # NAME HELD AT DATE WHY (AT: the version it is held at; "-" a new package)
    at=$(rpm -q --qf '%{evr}\n' "$n" 2>/dev/null | sed -n 1p) || at=""
    grep -q "^$n $v " "$UPD/holds" 2>/dev/null || printf '%s %s %s %s %s\n' "$n" "$v" "${at:--}" "$(date +%F)" "$why" >>"$UPD/holds"
    spec+=("$n-$v"); log "held: $n $v — $why"; UP_HELD=$((UP_HELD + 1))
  done
  ((${#spec[@]})) || return 0
  dnf -q versionlock exclude "${spec[@]}" >/dev/null 2>&1 || log "could not hold ${#spec[@]} package(s) (dnf versionlock)"
}
up_holds_apply() {   # every hold in force again (a restore of / took /etc/dnf/versionlock.toml
                     # back) — but one whose package has moved on (a newer version went in,
                     # proven) is let go: the version it kept out is past
  [[ -s $UPD/holds ]] || return 0
  local n v at d why now hold=() spec=()
  while IFS=" " read -r n v at d why; do
    [[ -n $n ]] || continue
    now=$(rpm -q --qf '%{evr}\n' "$n" 2>/dev/null | sed -n 1p) || now=""
    if [[ -n $now && $now != "$at" ]]; then
      dnf -q versionlock delete "$n" >/dev/null 2>&1 || true; log "let go: $n $v (now at $now)"; continue
    fi
    hold+=("$n $v $at $d $why"); spec+=("$n-$v")
  done <"$UPD/holds"
  ((${#spec[@]} == 0)) || dnf -q versionlock exclude "${spec[@]}" >/dev/null 2>&1 || true
  if ((${#hold[@]})); then printf '%s\n' "${hold[@]}" | write_file "$UPD/holds" 0644; else rm -f -- "$UPD/holds"; fi
}

# ── snapshot, replay ─────────────────────────────────────────────────────────────────────────
u_snapshot() {
  up_phase snapshot
  local out n good
  # (dnf5 replay skips the OpenPGP check for stored packages: done here, against this system's
  # keys — every package must say so, a missing answer is no answer)
  n=0; [[ -d $UPD/tx/packages ]] && n=$(find "$UPD/tx/packages" -name '*.rpm' | wc -l)
  if ((n)); then
    out=$(find "$UPD/tx/packages" -name '*.rpm' -print0 | xargs -0 rpmkeys --checksig 2>&1 || true)
    good=$(grep -c ': digests signatures OK$' <<<"$out" || true)
    ((good == n)) || die "a package is not signed by a key this system trusts — nothing changed: $(grep -v ': digests signatures OK$' <<<"$out" | sed -n 1p)"
  fi
  # (rpm's database needs nothing first: a snapshot is one instant, and SQLite takes its
  # write-ahead log from it as after a power cut — no transaction runs while this one holds the lock)
  snapshot_before "update $(date +%F)" important
  # pinned: no cleanup algorithm, so snapper never removes it before the next start has proven
  # the update (update-design.md §4.3)
  snapper -c root modify -c '' "$SNAP_N" >/dev/null 2>&1 || log "snapshot $SNAP_N could not be pinned — it is kept as an important one"
  printf '%s\n' "$SNAP_N" | write_file "$UPD/snap" 0644
}
u_replay() {   # → 1 the transaction failed on the running system
  up_phase replay
  [[ -s $UPD/tx/transaction.json ]] || return 0
  log "the update on the running system: the transaction the copy proved"
  dnf_detached -y -C replay "$UPD/tx" && return 0
  echo "the transaction stopped on the running system (dnf replay)" >"$UPD/why"; return 1
}
up_complete() {   # every package of the stored set at its new version, nothing twice, dnf's check clean
  local n v
  while IFS=" " read -r n _ v; do
    [[ -n $n && $v != - ]] || continue
    rpm -q "$n-${v#*:}" >/dev/null 2>&1 || return 1
  done <"$UPD/set"
  [[ -z $(dnf -q repoquery --duplicates 2>/dev/null) ]] && dnf -q check >/dev/null 2>&1
}

# ── check, end ───────────────────────────────────────────────────────────────────────────────
u_check() {   # → 0 nothing newly red · 1 (UPD/why lists what)
  up_phase check
  local new after more rc=0
  bash "$REPO_DIR/verify.sh" || true
  after=$(cat "$STATE_DIR/last-verify-fails" 2>/dev/null) || after=""
  more=$(up_more) || rc=$?
  # (a check that did not happen undoes nothing: stopped here, the next press runs the checks again)
  # (its phase kept: the next press resumes here, against the baseline from before the update)
  ((rc == 2)) && { UP_STAY=1; die "the desktop's start check could not run ($more) — nothing held, nothing undone; press update again"; }
  [[ -z $more ]] || { log "red after the update: ${more//$'\n'/ · }"; after+=${after:+$'\n'}$more; }
  new=$(comm -13 <(up_labels <"$UPD/baseline") <(up_labels <<<"$after")) || new=""
  [[ -z $new ]] && return 0
  printf '%s\n' "$new" >"$UPD/why"; return 1
}
# u_undo — the update made something red: the set held (the next press will not repeat it) and
# the system before it back. Only once /home is its own subvolume is that done by itself — before,
# a restore would take his files back in time too, so it is offered
u_undo() {
  local n s=(); n=$(cat "$UPD/snap" 2>/dev/null) || n=""
  mapfile -t s < <(awk '$3 != "-" { print $1 }' "$UPD/set" 2>/dev/null)
  ((${#s[@]})) && up_hold "$(head -n1 "$UPD/why")" "${s[@]}"
  UP_TOGETHER=${#s[@]}   # (the whole set: red only on the running system, so never told apart)
  if [[ -z $n ]]; then UP_END=checks
  elif mountpoint -q /home && /usr/local/sbin/kawa-snap restore "$n"; then UP_END=restored
  else UP_END=offered; fi
}
u_report() {   # u_report — the outcome: UPD/report (the pane), the log beside it, a notice
  local held="" fam=() line why log n desk
  # (the holds by family, as the pane names them — two at most, then how many more: a notice is
  # a line, and a whole set held at once is hundreds of names)
  [[ -s $UPD/holds ]] && mapfile -t fam < <(hold_families "$UPD/holds" | cut -f1)
  ((${#fam[@]})) && held="${fam[0]}${fam[1]:+ · ${fam[1]}}"
  ((${#fam[@]} > 2)) && held+=" and $((${#fam[@]} - 2)) more"
  ((UP_TOGETHER > 1 && ${#fam[@]} > 2)) && held="all $UP_TOGETHER packages together (which one broke it could not be told apart; newer versions are tried)"
  [[ -n $UP_END ]] || UP_END=stopped
  n=$(wc -l 2>/dev/null <"$UPD/set") || n=0
  # (kept while the desktop's check was red before it: what it could not judge is said, never hidden)
  desk=$(sed -n '/^the desktop does not start/p' "$UPD/baseline" 2>/dev/null) || desk=""
  [[ $UP_END == @(ok|current|held) ]] || desk=""
  case $UP_END in
    ok)       line="updated · $n package$( ((n == 1)) || echo s)${held:+ · held: $held}" ;;
    current)  line="up to date${held:+ · held: $held}" ;;
    held)     line="held: $held — the rest was up to date" ;;
    restored) line="the update broke something: the system before it comes back at the next start${held:+ — held: $held}" ;;
    offered)  line="the update broke something: snapshot $(cat "$UPD/snap") is the system before it (Super+U → snapshots)${held:+ — held: $held}" ;;
    *)        why=$(tail -c +"$((RUN_LOG_FROM + 1))" "$LOG_FILE" 2>/dev/null | grep '✘' | tail -n1 | sed 's/\x1b\[[0-9;]*m//g; s/^.*✘ *//') || why=""   # (this run's own)
              line="stopped ($(up_was | sed 's/^end$/start/')): ${why:-no reason could be written (a full disk?)}" ;;
  esac
  [[ -z $desk ]] || line+=" · the desktop's check was red before it, so not judged (Super+U → log)"
  ((UP_STAY)) || up_phase end || true
  # (the stored transaction and the downloads kept for the halves: done with, whatever the outcome)
  rm -rf -- "$UPD/tx" "$UPD/try"; dnf -q clean packages >/dev/null 2>&1 || true
  # (no command that can fail inside these pipes: setup.sh's ERR trap would print from them)
  why=$(cat "$UPD/why" 2>/dev/null) || why=""
  [[ -z $desk ]] || why+=${why:+$'\n'}$(up_labels <<<"$desk" | sed 's/^/red before it: /')
  printf '%s %s\n%s\n%s' "$(date +%s)" "$UP_END" "$line" "${why:+$why$'\n'}" | write_file "$UPD/report" 0644 2>/dev/null || true
  log=$(tail -c +"$((RUN_LOG_FROM + 1))" "$LOG_FILE" 2>/dev/null) || log=""
  printf '%s\n' "$log" | write_file "$UPD/last.log" 0644 2>/dev/null || true
  as_user notify-send -a update -u "$([[ $UP_END == @(ok|current) ]] && echo low || echo critical)" -- update "$line" 2>/dev/null || true
  # shellcheck disable=SC2034  # (do_update's last line says it)
  UP_LINE=$line
  [[ $UP_END == @(ok|current|held) ]] || hdr "update: $line"
}
# ── a start after an update cut in its transaction (a power cut, a crash): before the login
# screen (fedokawaii-update-resume.service), never left half-done — its packages all in: kept,
# the button's next press does the rest; not whole: the system before it put back and started,
# once (only once /home is its own subvolume — before, offered); either way said at login ──────
up_boot() {
  [[ $(up_was) == replay ]] || return 0
  local n; n=$(cat "$UPD/snap" 2>/dev/null) || n=""
  if up_complete; then
    up_phase steps
    up_tell "the last update was cut off after its packages went in" "press update (Super+U) to finish it"
  elif [[ -e $UPD/restored-once || -z $n ]] || ! mountpoint -q /home; then
    up_tell "the last update was cut off half-way" "snapshot ${n:-?} is the system before it: Super+U → snapshots → ${n:-?}$(mountpoint -q /home || echo ' (your home goes back too, until /home is split)')"
  else
    date +%s | write_file "$UPD/restored-once" 0644
    echo "the last update was cut off half-way" >"$UPD/why"
    if /usr/local/sbin/kawa-snap restore "$n"; then
      UP_END=restored; u_report
      up_tell "the last update was cut off half-way" "the system before it (snapshot $n) was put back — press update again when you like"
      systemctl reboot
    else up_tell "the last update was cut off half-way" "snapshot $n is the system before it, and could not be put back by itself: Super+U → snapshots → $n"; fi
  fi
}
up_tell() { as_user kawa-foryou add update-cut "$1" "$2" 2>/dev/null || log "$1 — $2"; }   # (a notice at login, kept until clicked)

# ── probation: the start after an update (update-design §4.3). Its pinned snapshot stays until a
# start has reached the desktop (grubenv's boot_success: Fedora's timer, two minutes into the
# desktop — the same proof that lets the kernel before go); a kernel it brought is counted by
# GRUB (08_fallback_counting: three starts without that proof, then the one before), and while it
# is on trial a start that fails is made a restart — no rescue shell, a panic restarts, systemd's
# hardware watchdog on — so a hang counts too. UPD/probation: SNAPSHOT KERNEL|- DAY, a line an
# update (several may wait for one restart). Closed by setup.sh --boot-good the moment grubenv
# changes (fedokawaii-boot-good.path) and by setup.sh --kernels a quarter of an hour into every
# start (the path's one trigger may have gone to another write: a kernel install's saved entry);
# while it names a kernel, the one before is never removed (old_kernels_out) ─────────────────
UP_TRIAL="rd.shell=0 rd.emergency=reboot rd.retry=30 panic=10"   # (rd.retry: 30 s, not dracut's 180, before a start that cannot find its root gives up)
UP_DOG=/etc/systemd/system.conf.d/90-fedokawaii-probation.conf
up_probation() {   # after a green update
  local new now menu; now=$(uname -r)
  new=$(rpm -q --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-core 2>/dev/null | sort -V | tail -n1) || new=""
  [[ -n $new && $new != "$now" && -f /boot/vmlinuz-$new ]] || new=-
  # (GRUB's way back is the menu's second entry — set default=1, /etc/grub.d/08_fallback_counting:
  # on trial only when the menu is exactly [new, running]; a third entry, a rescue image or a
  # kernel from before, could put one never proven there — then no trial, and said)
  if [[ $new != - ]]; then
    menu=$(grubby --info=ALL 2>/dev/null) || menu=""
    menu=$(sed -n 's|^kernel="/boot/vmlinuz-\(.*\)"$|\1|p' <<<"$menu" | paste -sd ' ')
    if [[ $menu != "$new $now" ]]; then
      log "kernel $new is not on trial: the boot menu is [${menu:-unreadable}], not [$new $now] — GRUB's way back, its second entry, would not be the kernel running now"
      new=-
    fi
  fi
  printf '%s %s %s\n' "$(cat "$UPD/snap" 2>/dev/null || echo -)" "$new" "$(date +%F)" >>"$UPD/probation"
  [[ $new != - ]] || return 0
  grub2-editenv - set boot_counter=3 boot_success=0 boot_indeterminate=1 \
    || { log "GRUB's start counting could not be armed (grub2-editenv) — kernel $new is not on trial"; return 0; }
  grubby --update-kernel="/boot/vmlinuz-$new" --args="$UP_TRIAL" >/dev/null 2>&1 || log "kernel $new's trial arguments could not be set (grubby)"
  printf '%s\n' "# installed by fedokawaii (setup.sh: lib/update.sh up_probation) while a new kernel is on trial" \
    '[Manager]' 'RuntimeWatchdogSec=1min' | write_file "$UP_DOG" 0644
  log "kernel $new on trial at the next start: three starts to reach the desktop, else $now again"
}
up_probation_close() {   # this start has reached the desktop: the probation over (or the kernel failed it)
  [[ -s $UPD/probation ]] || return 0
  grep -qx boot_success=1 < <(grub2-editenv - list 2>/dev/null) || return 0
  local now c snap k d kernel=- n v pk=()
  now=$(uname -r)
  while IFS=' ' read -r snap k d; do [[ $k == - ]] || kernel=$k; done <"$UPD/probation"
  c=$(grub2-editenv - list 2>/dev/null | sed -n 's/^boot_counter=//p')
  if [[ $kernel != - && $kernel != "$now" ]] && rpm -q "kernel-core-$kernel" >/dev/null 2>&1; then
    [[ $c == -1 ]] || return 0      # (the one before chosen in the menu: the trial waits for the new one)
    # GRUB took the one before: the new kernel held at its version and taken out, this one the default
    v=${kernel%.*}
    for n in "${KERNEL_PKGS[@]}"; do
      rpm -q "$n-$kernel" >/dev/null 2>&1 || continue
      pk+=("$n-$kernel")
      grep -q "^$n $v " "$UPD/holds" 2>/dev/null || printf '%s %s %s %s %s\n' "$n" "$v" "${now%.*}" "$(date +%F)" "did not reach the desktop in three starts" >>"$UPD/holds"
      dnf -q versionlock exclude "$n-$v" >/dev/null 2>&1 || log "could not hold $n $v (dnf versionlock)"
    done
    grubby --set-default "/boot/vmlinuz-$now" >/dev/null 2>&1 || log "kernel $now could not be made the default (grubby)"
    ((${#pk[@]})) && { run dnf -y --disable-repo='*' remove "${pk[@]}" || log "kernel $kernel could not be removed — it stays in the boot menu, held"; }
    as_user kawa-foryou add update-kernel "kernel $kernel did not reach the desktop in three starts" \
      "back on $now; $kernel is held until a newer one comes (Super+U → update)" 2>/dev/null || true
    log "kernel $kernel did not reach the desktop in three starts: held, out; $now is the default"
  elif [[ $kernel == "$now" ]]; then
    grubby --update-kernel="/boot/vmlinuz-$kernel" --remove-args="$UP_TRIAL" >/dev/null 2>&1 || log "kernel $kernel's trial arguments could not be removed (grubby)"
    log "kernel $kernel reached the desktop: its trial is over"
  elif [[ $kernel != - ]]; then
    log "kernel $kernel is no longer on the system (a restore took it): its trial ends with it"
  fi
  [[ -z $c ]] || grub2-editenv - unset boot_counter || log "GRUB's start counting could not be turned off (grub2-editenv)"
  rm -f -- "$UP_DOG"
  # (the snapshots before the updates: back to snapper's number cleanup)
  while IFS=' ' read -r snap k d; do
    [[ $snap =~ ^[0-9]+$ ]] || continue
    snapper -c root modify -c number "$snap" >/dev/null 2>&1 || log "snapshot $snap could not be released to the cleanup (snapper)"
  done <"$UPD/probation"
  rm -f -- "$UPD/probation"
}
UP_END="" UP_STAY=0 UP_TOGETHER=0
up_exit() {   # (a run that stops anywhere: the candidate gone, the top unmounted, the report written —
              # quietly: the run's own error has been said, and its status stands — and what
              # make_tmp's own exit did, which this one replaces: the run's temp folder, dnf's follower)
  trap - ERR; set +e
  cand_drop
  if mountpoint -q "$UP_TOP" 2>/dev/null; then umount "$UP_TOP" 2>/dev/null || true; fi
  rmdir "$UP_TOP" 2>/dev/null || true
  if [[ -z $UP_END && -d $UPD ]]; then UP_END=stopped; u_report; fi
  rm -rf -- "$KAWA_TMP"; [[ -n ${FOLLOWER:-} ]] && kill "$FOLLOWER" 2>/dev/null
  return 0
}
