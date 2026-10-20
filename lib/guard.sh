#!/usr/bin/env bash
# lib/guard.sh — package updates that cannot take the desktop down (setup.sh sources it; root)
#
# What depends on package versions, and what keeps each standing:
#   dwl            linked to its own copy of wlroots (lib/common.sh: wlr_keep), so a new
#                  wlroots in Fedora never touches it. What the copy and dwl load from Fedora
#                  (libinput, xkbcommon, Wayland, pixman, libseat, libdrm, Mesa's gbm…) is
#                  recorded (NEEDS); a transaction that would take one of them for good is
#                  stopped before it runs (system/kawa-dnf-guard); one Fedora rebuilt wlroots
#                  for is let through, and the copy taken again from the rebuild right after
#                  (wlr_sound), dwl relinked (r_dwl). After every transaction dwl is started
#                  once, headless, to prove it starts (dwl_starts) — not only that it links.
#                  No second dwl is kept: a rebuild replaces the binary only once it has built,
#                  and the snapshot before every transaction (kawa-snap) is the way back.
#   the C helpers  (kawa-clipkeep, -saver, -lockmod: GTK, gtklock's module API)
#                  rebuilt by the theme when one no longer finds its libraries (helpers_sound)
#   the greeter    kawa-greet (GTK 3 through PyGObject) and the panel: their typelibs loaded
#                  once after each transaction (gi_sound); a login screen that still cannot
#                  start says so on tty1 (fedokawaii-login-failed), a desktop that cannot
#                  start opens the rescue screen (start-dwl) — never a black screen
#   Python         a new minor version (3.14 → 3.15): torrra (its own Python 3.13, through
#                  uv tool) and Syncplay (Fedora's python3) checked, reinstalled if they no longer load
#   kernels        the standing rule (setup.sh: installonly_limit=2, the one before kept until
#                  the newest has reached the desktop): a bad new kernel is skipped in the boot
#                  menu; after a kernel transaction every boot image made (dracut), the boot's
#                  arguments on every entry
#   configs        foot's and fuzzel's own checks run when either changed (an option a new
#                  version dropped): said, for the next toolkit update to carry the fix
# The manifest's packages: never removed by a transaction of yours (kawa-dnf-guard).
# No dnf versionlock: holding a library back would hold every package that needs its newer
# version back with it (security fixes too) — the guard stops only what would really break.

GUARD_ACTIONS=/etc/dnf/libdnf5-plugins/actions.d/fedokawaii-guard.actions

# built_files ROLE → our own builds of that role, one per line (those that exist)
#   wlroots: dwl's own copy · build: dwl, the C helpers, the file dialog · tool: release binaries
built_files() {
  local f kept; kept=$(wlr_home)/lib
  case $1 in
    wlroots) for f in "$kept"/*.so*; do [[ -f $f && ! -L $f ]] && echo "$f"; done ;;
    build)   for f in /usr/local/bin/dwl /usr/local/libexec/xdg-desktop-portal-termfilechooser \
                      "$TARGET_HOME"/.local/bin/{kawa-clipkeep,kawa-saver} \
                      "$TARGET_HOME"/.local/lib/fedokawaii/kawa-lockmod.so; do [[ -f $f ]] && echo "$f"; done ;;
    tool)    for f in "$TARGET_HOME"/.local/bin/{satty,yazi,ya,lazygit,herdr}; do [[ -f $f ]] && echo "$f"; done ;;
  esac
  return 0
}
# needs_record — STATE/needs: every library our own builds load from Fedora, with its package
# and the strongest role that loads it; and STATE/manifest, the packages the desktop is built
# from (kawa-dnf-guard reads both, before every transaction)
needs_record() {
  local role f so path pkg kept; kept=$(wlr_home)/lib
  {
    printf 'wlroots %s\n' "$DWL_WLROOTS"
    for role in wlroots build tool; do
      while IFS= read -r f; do
        while read -r so path; do
          [[ $path == "$kept"/* ]] && continue                       # (dwl's own copies)
          [[ $so =~ ^(ld-linux|libc|libm|libdl|libpthread|librt)[.-] ]] && continue   # (glibc's: for good)
          pkg=$(rpm -qf --qf '%{NAME}\n' "$path" 2>/dev/null | sed -n 1p) || pkg=""   # (none owns it: not Fedora's)
          if [[ -n $pkg && $pkg != *' '* ]]; then printf '%s %s %s\n' "$so" "$pkg" "$role"; fi   # (an if: a library no package owns never fails the loop)
        done < <(as_user ldd "$f" 2>/dev/null | awk '$2 == "=>" && $3 ~ /^\// { print $1, $3 }')
      done < <(built_files "$role")
    done | awk '!($1 in r) { r[$1] = $3; p[$1] = $2; o[++n] = $1 } END { for (i = 1; i <= n; i++) print o[i], p[o[i]], r[o[i]] }' | sort
  } | write_file "$STATE_DIR/needs" 0644
  manifest_all "$(cat "$STATE_DIR/gpu" 2>/dev/null || echo amd)" | sort -u | write_file "$STATE_DIR/manifest" 0644
}

# guard_hooks — the guard before and after every dnf transaction, its unit, its records
guard_hooks() {
  install -m 0755 "$REPO_DIR/system/kawa-dnf-guard" /usr/local/sbin/kawa-dnf-guard
  write_file "$GUARD_ACTIONS" <<'EOF'
# installed by setup.sh — every dnf transaction checked before it runs and followed up after
# it (system/kawa-dnf-guard; handbook: "Updates that cannot break the desktop"). Read before
# fedokawaii-snapper.actions: a transaction the guard stops leaves no snapshot behind. (No
# raise_error: a guard that fails on its own lets the transaction through — never holds it.)
pre_transaction::::mode=json:/usr/local/sbin/kawa-dnf-guard pre
post_transaction::::mode=json:/usr/local/sbin/kawa-dnf-guard post
EOF
  write_file /etc/systemd/system/fedokawaii-after-dnf.service <<UNIT
# installed by setup.sh — after a dnf transaction (kawa-dnf-guard post starts it; at the next
# start too, when one was cut off or came with the move to a new Fedora): the rebuilds it
# calls for, the checks, a notice with the outcome
[Unit]
Description=Fedokawaii: after a dnf transaction — rebuilt where needed, checked
After=network-online.target fedokawaii-after-upgrade.service
Wants=network-online.target
ConditionPathExists=$STATE_DIR/after-dnf

[Service]
Type=oneshot
ExecStart=/usr/bin/bash $TOOLKIT/setup.sh --after-dnf
Nice=10

[Install]
WantedBy=multi-user.target
UNIT
  systemctl daemon-reload
  systemctl is-enabled --quiet fedokawaii-after-dnf.service || systemctl enable --quiet fedokawaii-after-dnf.service
  restorecon /usr/local/sbin/kawa-dnf-guard "$GUARD_ACTIONS" /etc/systemd/system/fedokawaii-after-dnf.service 2>/dev/null || true
  needs_record
}

# dwl_starts — the installed dwl starts: headless, as you, in a runtime folder of its own (your
# own session, if one runs, is never touched); its startup command marks that it got there
dwl_starts() {
  local d rc
  d=$(as_user mktemp -d "${TMPDIR:-/var/tmp}/fedokawaii-dwl.XXXXXX") || return 1
  as_user env -i HOME="$TARGET_HOME" PATH=/usr/bin:/bin XDG_RUNTIME_DIR="$d" WLR_BACKENDS=headless \
    WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1 timeout 20 /usr/local/bin/dwl \
    -s "touch '$d/started'; sleep 1; kill -TERM \$PPID" >"$KAWA_TMP/dwl-start.log" 2>&1 && rc=0 || rc=$?
  [[ -e $d/started ]] && ((rc == 0)) && { as_user rm -rf -- "$d"; return 0; }
  as_user rm -rf -- "$d"; rm -f "$STATE_DIR/dwl-started"   # (verify's record of a pass: no longer true)
  log "dwl does not start (exit $rc): $(grep -v '^$' "$KAWA_TMP/dwl-start.log" | tail -n 3 | tr '\n' ' ')"
  return 1
}
# wlr_sound — dwl's own wlroots loads every library it needs; one Fedora replaced (a rebuild
# for a new libinput, say) is taken again from Fedora's wlroots of the same version, when it
# has one — the copy before kept until the new one is in place
wlr_sound() {
  local h f bad=0; h=$(wlr_home)
  wlr_kept || { wlr_keep; return; }
  for f in "$h"/lib/*.so*; do
    [[ -f $f && ! -L $f ]] || continue
    [[ $(as_user ldd "$f" 2>/dev/null) == *'not found'* ]] && bad=1
  done
  ((bad)) || return 0
  pkg-config --exists "wlroots-$DWL_WLROOTS" || { log "dwl's own wlroots $DWL_WLROOTS misses a library, and this Fedora has no wlroots $DWL_WLROOTS to take it again from"; return 1; }
  log "dwl's own wlroots $DWL_WLROOTS misses a library — taken again from Fedora's rebuild"
  rm -rf -- "$h.before"; mv -T -- "$h" "$h.before"
  if wlr_keep; then rm -rf -- "$h.before"; rm -f "$STATE_DIR/dwl.sha256"; return 0; fi
  rm -rf -- "$h"; mv -T -- "$h.before" "$h"; return 1
}
# dwl_sound — dwl as it must be after a transaction: its wlroots whole, linked, and it starts —
# else rebuilt (r_dwl; on a themed desktop the theme then builds it with src/dwl/config.h)
dwl_sound() {
  r_dwl
  if [[ -f $TARGET_HOME/.local/state/fedokawaii/theme-applied && ! -s $STATE_DIR/dwl.sha256 ]]; then r_theme; fi
  dwl_starts || { log "dwl still does not start — the rescue screen says so at login; the snapshot before the transaction is the way back (fedokawaii snapshots)"; return 1; }
}
# helpers_sound — the C helpers find their libraries, else built again by the theme
helpers_sound() {
  local t f bad=()
  for t in kawa-clipkeep kawa-saver kawa-lockmod; do
    f=$TARGET_HOME/.local/bin/$t; [[ $t == kawa-lockmod ]] && f=$TARGET_HOME/.local/lib/fedokawaii/kawa-lockmod.so
    [[ -f $f ]] || continue
    [[ $(as_user ldd "$f" 2>/dev/null) == *'not found'* ]] && bad+=("$t")
  done
  ((${#bad[@]})) || return 0
  log "$(IFS=' '; echo "${bad[*]}") no longer find a library — built again"
  for t in "${bad[@]}"; do as_user rm -f "$TARGET_HOME/.local/state/fedokawaii/$t.sha256"; done
  r_theme
}
# gi_sound — the login screen and the panel load the GTK their code asks for (typelibs, PyGObject)
gi_sound() {
  local f bad=()
  for f in /usr/local/bin/kawa-greet "$TARGET_HOME/.local/bin/kawa-panel"; do
    [[ -f $f ]] || continue
    as_user python3 -I - "$f" >>"$LOG_FILE" 2>&1 <<'PY' || bad+=("${f##*/}")
import importlib, re, sys
src = open(sys.argv[1], encoding="utf-8").read()
import gi
for ns, v in re.findall(r'gi\.require_version\(\s*"(\w+)"\s*,\s*"([\d.]+)"\s*\)', src):
    gi.require_version(ns, v)
    importlib.import_module("gi.repository." + ns)
PY
  done
  ((${#bad[@]} == 0)) || { log "$(IFS=' '; echo "${bad[*]}") cannot load its GTK libraries — fedokawaii repair puts the packages back; the snapshot before the transaction is the way back"; return 1; }
}
# configs_sound — the desktop's configs still read with the new foot and fuzzel
configs_sound() {
  local rc=0
  [[ -f $TARGET_HOME/.local/state/fedokawaii/theme-applied ]] || return 0
  if command -v foot >/dev/null && ! as_user foot --check-config >>"$LOG_FILE" 2>&1; then log "foot no longer reads ~/.config/foot/foot.ini as it is (its log says which line)"; rc=1; fi
  if command -v fuzzel >/dev/null && ! as_user fuzzel --check-config >>"$LOG_FILE" 2>&1; then log "fuzzel no longer reads ~/.config/fuzzel/fuzzel.ini as it is"; rc=1; fi
  return "$rc"
}

# do_after_dnf — once after a dnf transaction (fedokawaii-after-dnf.service): the steps it calls
# for, each on its own; recorded (STATE/last-after-dnf "EPOCH RESULT"), told in a notice
do_after_dnf() {
  local p=$STATE_DIR/after-dnf ch=$KAWA_TMP/changed result=ok n s
  [[ -f $p ]] || exit 0
  [[ $(phase) == 'done' ]] || { rm -f "$p"; exit 0; }       # (setup itself follows up)
  # (a transaction after this one notes its names in a new file: it gets a run of its own)
  sort -u "$p" >"$ch"; rm -f "$p"
  n=$(grep -c . "$ch") || n=0
  hdr "after dnf · $n package(s) changed"
  UPDATE_STEPS_FAILED=()
  step_on "dwl starts (its own wlroots, the libraries under both)" dwl_sound
  step_on "the desktop's helpers find their libraries" helpers_sound
  step_on "the release tools find their libraries" r_upstream_libs
  step_on "the login screen and panel load GTK" gi_sound
  if grep -qE '^python3(\.[0-9]+)?$' "$ch"; then
    step_on "torrra on its Python" torrra_up
    step_on "Syncplay on Fedora's Python" install_syncplay
  fi
  if grep -qE '^kernel(-core)?$' "$ch"; then
    step_on "the kernels' boot images (dracut)" kernel_images
    step_on "a quiet boot (the boot's arguments)" s_quiet_boot
  fi
  grep -qE '^(foot|fuzzel)$' "$ch" && step_on "foot's and fuzzel's configs" configs_sound
  step_on "the guard's records" needs_record
  bash "$REPO_DIR/verify.sh" >>"$LOG_FILE" 2>&1 || result=checks
  ((${#UPDATE_STEPS_FAILED[@]} == 0)) || result=partial
  record last-after-dnf "$(date +%s) $result"
  case $result in
    ok)      s="dnf changed $n package(s) — the desktop checked: it starts, everything in place" ;;
    checks)  s="dnf changed $n package(s) — verify finds something: Super+U → repair" ;;
    *)       printf -v s '%s · ' "${UPDATE_STEPS_FAILED[@]}"
             s="dnf changed $n package(s) — not right yet: ${s% · }. Super+U → repair (or the snapshot before it: fedokawaii snapshots)" ;;
  esac
  log "$s"
  if [[ -S /run/user/$TARGET_UID/bus ]]; then
    as_user notify-send -a upkeep -u "$([[ $result == ok ]] && echo low || echo critical)" -- "upkeep" "$s" 2>/dev/null || true
  fi
  [[ $result == ok ]]
}
# r_upstream_libs — each release tool finds its libraries (a package for one Fedora renamed)
r_upstream_libs() {
  local f rc=0
  while IFS= read -r f; do libs_for "$f" || rc=1; done < <(built_files tool)
  return "$rc"
}
