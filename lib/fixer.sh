# shellcheck shell=bash
# lib/fixer.sh — the local AI fixer's place in the update (.claude/notes/update-design.md §4.5,
# system/kawa-fixer): before a culprit bisection found is held, a failure of a config of ours goes
# to the model on this PC's own card — in a copy of the system with the culprit in, and a copy of
# the home, never the real ones. Its edit counts only if the program's own check and all of the
# candidate's checks then pass; it waits in UP_FIXNEW until the package itself is in, then is kept
# in UP_FIXES (the updater's memory, never rolled back), laid over the configs from then on
# (theme.sh's place, fixes_apply), and said in the report; an update undone takes its fix back out
# (the old version would refuse the new text). Everything else: held and told, as before. Sourced
# by setup.sh after lib/update.sh.
FIXER=/usr/local/sbin/kawa-fixer
UP_FIXES=$UPD/fixes            # in force
UP_FIXNEW=$UPD/fixes.new       # proven in a copy, its package not in yet
UP_HOME=$UP_TOP/home.cand      # a writable copy of /home while candidates exist: their config checks read it
UP_FIX_LINES=()                # (what the fixer did this run, for the report's lines)
UP_MENDED=""                   # (the files it mended, for the report's own line and the notice)

# up_home_copy — /home is its own subvolume (the split): its copy costs nothing and is dropped with
# the candidate's top. Without it the candidate's programs would check no config at all
up_home_copy() {
  [[ -d $UP_HOME ]] && return 0
  mountpoint -q /home || return 0
  btrfs subvolume snapshot /home "$UP_HOME" >/dev/null || log "a copy of the home could not be made — the candidate's config checks read none"
}
up_home_drop() {
  [[ -d $UP_HOME ]] || return 0
  btrfs subvolume delete --commit-after "$UP_HOME" >/dev/null 2>&1 || log "the copy $UP_HOME could not be removed — the next update removes it"
}
# fixes_cand — the kept fixes on a candidate that has just received its packages (and its home's copy)
fixes_cand() {
  local d
  for d in "$UP_FIXES" "$UP_FIXNEW"; do
    [[ -n $(compgen -G "$d/*.json") && -x $FIXER ]] || continue
    "$FIXER" reapply --fixes "$d" --home "$UP_HOME${TARGET_HOME#/home}" --root "$UP_CAND" >/dev/null 2>&1 || true
  done
}
# fixes_commit — the packages are in: what waited comes into force; fix-new names them, for fixes_undo
# (never before: a theme run would lay a fix on a config whose program does not know it yet)
fixes_commit() {
  local f
  [[ -n $(compgen -G "$UP_FIXNEW/*.json") ]] || return 0
  mkdir -p "$UP_FIXES"
  for f in "$UP_FIXNEW"/*.json; do mv -f -- "$f" "$UP_FIXES/"; echo "${f##*/}" >>"$UPD/fix-new"; done
  rmdir -- "$UP_FIXNEW" 2>/dev/null || true
}
# fixes_undo — the update did not stay: its fixes out again, each file as it was; fixes_settled: it stayed
fixes_undo() {
  local n
  [[ -s $UPD/fix-new && -x $FIXER ]] || return 0
  while IFS= read -r n; do
    "$FIXER" unapply "$UP_FIXES/$n" --home "$TARGET_HOME" --root / || log "the fixer's edit $n could not be taken back"
  done <"$UPD/fix-new"
  rm -f -- "$UPD/fix-new"
}
fixes_settled() { rm -f -- "$UPD/fix-new"; }
# fixes_apply — the same on the running system, after the theme: /etc's too (a home's file written
# as its owner: kawa-fixer write_keep). Each one that is no longer needed is dropped, said
fixes_apply() {
  [[ -n $(compgen -G "$UP_FIXES/*.json") && -x $FIXER ]] || return 0
  local out
  out=$("$FIXER" reapply --fixes "$UP_FIXES" --home "$TARGET_HOME" --root /) || true
  log "$out"
}
# up_fix WHYFILE NAME… — NAME… make the candidate red for what WHYFILE says. → 0 mended: kept, and
# nothing to hold · 1 no fix: hold them (UP_FIX_LINES says why, if the fixer got that far). The
# transaction: NAME… stored on their own — or UP_FIX_TX, one stored already (a move to a new Fedora)
up_fix() {
  local why=$1 rc=0 dir=$UPD/fix line tx=${UP_FIX_TX:-$UPD/try}; shift
  [[ -x $FIXER ]] || return 1
  # (a failure no config edit can mend is held at once: no copy made, the card left alone)
  "$FIXER" names --why-file "$why" "$@" >/dev/null 2>&1 || return 1
  [[ -d $UP_HOME ]] || { UP_FIX_LINES+=("the fixer could not run: no copy of the home"); return 1; }
  log "the local AI fixer tries: $(head -n1 "$why")"
  rm -rf -- "$dir" "$UPD/cand-boot"; mkdir -p "$dir" "$UPD/cand-boot/loader/entries" "$UPD/cand-boot/grub2"
  cp -a /boot/grub2/grubenv "$UPD/cand-boot/grub2/" 2>/dev/null || true   # (as cand_try: the scratch /boot shaped like the real one)
  if [[ -z ${UP_FIX_TX:-} ]]; then
    rm -rf -- "$UPD/try"
    dnf -q -y upgrade --store="$UPD/try" "$@" >/dev/null 2>&1 || { UP_FIX_LINES+=("the fixer could not run: those packages could not be stored on their own"); return 1; }
  fi
  [[ -s $tx/transaction.json ]] || return 1
  cand_drop
  btrfs subvolume snapshot / "$UP_CAND" >/dev/null || return 1
  if ! cand_run "$tx" dnf5 --disable-plugin=actions -y -C replay /tx >>"$UPD/cand.log" 2>&1; then
    cand_drop; UP_FIX_LINES+=("the fixer could not run: the transaction does not go through"); return 1
  fi
  fixes_cand     # (what an earlier round of this run has already mended)
  # the runner: a program as the desktop's user, in the candidate, no network, no display
  printf '#!/usr/bin/bash\nexec systemd-nspawn --quiet --register=no --private-network --link-journal=no --console=pipe -D %q --bind=%q:/home --user=%q --chdir=%q --setenv=HOME=%q -- "$@"\n' \
    "$UP_CAND" "$UP_HOME" "$TARGET_USER" "$TARGET_HOME" "$TARGET_HOME" >"$dir/run"
  chmod 0755 "$dir/run"
  up_fix_case "$why" "$dir" "$@" >"$dir/case.json"
  line=$("$FIXER" run "$dir/case.json" --out "$dir/out.json" --log "$dir/log" 2>&1) || rc=$?
  log "the fixer: $line"
  if ((rc == 0)) && cand_run "$tx" /usr/bin/bash /run/fk-check >>"$UPD/cand.log" 2>&1; then
    "$FIXER" keep "$dir/out.json" --fixes "$UP_FIXNEW" >/dev/null
    UP_FIX_LINES+=("$line")
    UP_MENDED+=${UP_MENDED:+, }$(sed -E 's/^fixed (.*) in [0-9]+ tr.*/\1/' <<<"$line")
    cand_drop; rm -rf -- "$UPD/cand-boot"; [[ -n ${UP_FIX_TX:-} ]] || rm -rf -- "$UPD/try"
    return 0
  fi
  # (its edits stayed in the home's copy: a clean one for what follows)
  ((rc == 0)) && line="its fix passed its own check, not the whole system's: held"
  UP_FIX_LINES+=("the fixer: $line")
  cand_drop; rm -rf -- "$UPD/cand-boot"; [[ -n ${UP_FIX_TX:-} ]] || rm -rf -- "$UPD/try"
  up_home_drop; up_home_copy
  return 1
}
# up_fix_case WHYFILE DIR NAME… → the case for kawa-fixer, as JSON: the failure, what was held
# (from UPD/set: old and new versions), the two systems. No value of ours in a shell string: all by jq
up_fix_case() {
  local why=$1 dir=$2 n; shift 2
  for n; do awk -v n="$n" '$1 == n { printf "%s %s %s\n", $1, $2, $3 }' "$UPD/set"; done \
    | jq -Rn '[inputs | split(" ") | {name: .[0], old: .[1], new: .[2]}]' >"$dir/packages.json"
  jq -n --rawfile why "$why" --slurpfile pk "$dir/packages.json" --arg run "$dir/run" \
     --arg home "$UP_HOME${TARGET_HOME#/home}" --arg home_in "$TARGET_HOME" --arg root "$UP_CAND" \
     --arg user "$TARGET_USER" --arg user_home "$TARGET_HOME" \
     '{why: ($why | split("\n") | map(select(length > 0))), packages: $pk[0], runner: [$run], home: $home, home_in: $home_in,
       root: $root, root_in: "", old_root: "/", user: $user, user_home: $user_home, budget_s: 1500}'
}
