# shellcheck shell=bash
# lib/pace.sh — how fast, and how evenly, the machine starts and shuts down: read from the
# journal, start by start (fedokawaii-report's BOOT-40… and SHUT-… rows source it), and the
# one setting of the disk it shapes (pace_fstab: setup.sh). Reads only, but for pace_fstab,
# which prints. Bash; no other library needed.
#
#   pace_boots N        the last N starts, oldest first: one line each —
#                       ID FIRMWARE LOADER KERNEL INITRD USERSPACE GREETER SESSION SHUTDOWN TIMEOUTS
#                       seconds ("-": not in the journal). GREETER: from the kernel's start to the
#                       login screen (greetd started); SESSION: from your password to the
#                       desktop's session up (dwl-session.target); SHUTDOWN: from "powering
#                       down"/"rebooting" to the journal's end (Steam's wait before it is not
#                       counted: logind waits for it first); TIMEOUTS: the units that reached
#                       their stop time-out and were killed, comma-separated
#   pace_table N        the same as a table, with the limits below
#   pace_judge WHAT N   0 when within the limits, 1 when not (and why, printed):
#                       stages — the newest start's kernel, initrd, userspace and login screen
#                       even — the login screen's time over the starts (its spread)
#                       session — the newest login's session
#                       shutdown — every shut down's length · shuteven — their spread
#                       timeouts — no unit killed at its stop time-out
#   pace_fstab          stdin → stdout: an fstab with every Btrfs line's options holding
#                       noatime (relatime, atime and strictatime out)

# the limits, in seconds, on this desktop (an NVMe disk, no network wait, the splash from the
# first frame): what a start or a shut down beyond them has is a fault to find
PACE_KERNEL=3 PACE_INITRD=6 PACE_USERSPACE=10 PACE_GREETER=12 PACE_SESSION=4
PACE_SPREAD=3 PACE_SHUTDOWN=15 PACE_SHUT_SPREAD=8
# what pace_boot reads of a start (journalctl -g: the message, case-blind)
PACE_RX="Startup finished in .*\(kernel\)|Started greetd\.service|pam_unix\(greetd:session\): session opened|Reached target dwl-session\.target|System is (powering down|rebooting)|The system will (power off|reboot) now|timed out\. (Killing|Terminating)|Failed with result 'timeout'|Journal stopped"

pace_boot_ids() {   # pace_boot_ids N → the last N starts' ids, oldest first
  journalctl --list-boots --no-pager -q 2>/dev/null \
    | awk '$1 ~ /^-?[0-9]+$/ && $2 ~ /^[0-9a-f]{32}$/ { print $2 }' | tail -n "$1"
}
pace_boot() {   # pace_boot ID → the line pace_boots describes
  journalctl -b "$1" -q --no-pager -o short-monotonic -g "$PACE_RX" 2>/dev/null | awk -v id="$1" '
    function secs(s,   v) {          # systemd time spans: 845ms · 3.524s · 1min 2.345s · 1h 2min
      v = 0
      while (match(s, /[0-9.]+(h|min|ms|s|us)/)) {
        t = substr(s, RSTART, RLENGTH); s = substr(s, RSTART + RLENGTH)
        if (t ~ /ms$/) v += t / 1000; else if (t ~ /us$/) v += t / 1000000
        else if (t ~ /min$/) v += t * 60; else if (t ~ /h$/) v += t * 3600; else v += t + 0
      }
      return v
    }
    function f(x) { return x == "" ? "-" : sprintf("%.2f", x) }
    { if (!match($0, /^\[ *[0-9]+\.[0-9]+\]/)) next
      m = substr($0, RSTART + 1, RLENGTH - 2) + 0 }
    /Startup finished in .*\(kernel\)/ {
      s = $0; sub(/.*Startup finished in /, "", s); sub(/ = .*/, "", s)
      n = split(s, part, / \+ /)
      for (i = 1; i <= n; i++) if (match(part[i], /\(([a-z]+)\)/)) {
        k = substr(part[i], RSTART + 1, RLENGTH - 2); st[k] = secs(substr(part[i], 1, RSTART - 1)) }
      next }
    /Started greetd\.service/ { if (greet == "") greet = m; next }
    /pam_unix\(greetd:session\): session opened/ { if ($0 !~ /for user greetd([ (]|$)/ && login == "") login = m; next }
    /Reached target dwl-session\.target/ { if (login != "" && ready == "") ready = m; next }
    /System is (powering down|rebooting)/ { down = m; strong = 1; next }
    /The system will (power off|reboot) now/ { if (!strong) down = m; next }
    { last = m }
    /timed out\. (Killing|Terminating)|Failed with result .timeout./ {
      if (down != "" && m >= down) { u = $0; sub(/^[^]]*\] [^ ]+ [^:]+: /, "", u); sub(/:.*/, "", u)
        if (!(u in seen)) { seen[u] = 1; to = to (to == "" ? "" : ",") u } } }
    END {
      shut = (down != "" && last != "" && last >= down) ? last - down : ""
      printf "%s %s %s %s %s %s %s %s %s %s\n", id, f(st["firmware"]), f(st["loader"]), f(st["kernel"]),
        f(st["initrd"]), f(st["userspace"]), f(greet), f(ready == "" ? "" : ready - login), f(shut), to == "" ? "-" : to
    }'
}
pace_boots() { local id; for id in $(pace_boot_ids "$1"); do pace_boot "$id"; done; }

pace_table() {   # pace_table N — the starts as a table (the newest last), then the limits
  pace_boots "$1" | awk '
    BEGIN { printf "%-8s %8s %7s %7s %7s %9s %8s %8s %9s  %s\n", "start", "firmware", "loader", "kernel", "initrd", "userspace", "greeter", "session", "shutdown", "stop time-outs" }
    { printf "%-8s %8s %7s %7s %7s %9s %8s %8s %9s  %s\n", substr($1, 1, 8), $2, $3, $4, $5, $6, $7, $8, $9, $10 }'
  printf 'limits: kernel %s s · initrd %s s · userspace %s s · login screen %s s from the kernel (spread %s s) · session %s s · shut down %s s (spread %s s) · no stop time-out\n' \
    "$PACE_KERNEL" "$PACE_INITRD" "$PACE_USERSPACE" "$PACE_GREETER" "$PACE_SPREAD" "$PACE_SESSION" "$PACE_SHUTDOWN" "$PACE_SHUT_SPREAD"
  echo "(the shut down of the start running now is not over: '-'; firmware and loader are the board's and the menu's: no limit)"
}

pace_judge() {   # pace_judge WHAT N — see the top
  pace_boots "$2" | awk -v what="$1" -v K="$PACE_KERNEL" -v I="$PACE_INITRD" -v US="$PACE_USERSPACE" \
      -v G="$PACE_GREETER" -v SE="$PACE_SESSION" -v SP="$PACE_SPREAD" -v SH="$PACE_SHUTDOWN" -v SS="$PACE_SHUT_SPREAD" '
    function over(name, v, lim) { if (v != "-" && v + 0 > lim + 0) { printf "%s: %s s, over %s s\n", name, v, lim; bad = 1 } }
    function spread(col, lim, name,   i, lo, hi, n) {
      n = 0; for (i = 1; i <= NR; i++) { v = row[i, col]; if (v == "-") continue; v += 0; n++
        if (n == 1 || v < lo) lo = v; if (n == 1 || v > hi) hi = v }
      if (n < 3) { printf "%s: %d starts with it in the journal — too few to judge (3 needed)\n", name, n; return }
      printf "%s over %d starts: %.2f to %.2f s (spread %.2f s, at most %s)\n", name, n, lo, hi, hi - lo, lim
      if (hi - lo > lim + 0) bad = 1 }
    { for (c = 1; c <= 10; c++) row[NR, c] = $c }
    END {
      if (NR == 0) { print "no start in the journal"; exit 1 }
      if (what == "stages") { over("kernel", row[NR, 4], K); over("initrd", row[NR, 5], I); over("userspace", row[NR, 6], US)
                              over("login screen (from the kernel)", row[NR, 7], G)
                              if (!bad) printf "this start: kernel %s · initrd %s · userspace %s · login screen %s s\n", row[NR, 4], row[NR, 5], row[NR, 6], row[NR, 7] }
      else if (what == "even") spread(7, SP, "the login screen")
      else if (what == "session") {
        for (i = NR; i >= 1 && row[i, 8] == "-"; i--) ;
        if (i < 1) { print "no login in these starts"; exit 0 }
        over("the session after the password", row[i, 8], SE); if (!bad) printf "the last login: the session up %s s after the password\n", row[i, 8] }
      else if (what == "shutdown") { n = 0
        for (i = 1; i <= NR; i++) if (row[i, 9] != "-") { n++; over("shut down of start " substr(row[i, 1], 1, 8), row[i, 9], SH) }
        if (!bad) printf "%d shut downs, each under %s s\n", n, SH }
      else if (what == "shuteven") spread(9, SS, "the shut down")
      else if (what == "timeouts") {
        for (i = 1; i <= NR; i++) if (row[i, 10] != "-") { printf "start %s: %s reached the stop time-out and was killed\n", substr(row[i, 1], 1, 8), row[i, 10]; bad = 1 }
        if (!bad) printf "no unit reached its stop time-out in the last %d starts\n", NR }
      else { print "pace_judge: what? " what; exit 2 }
      exit bad }'
}

pace_fstab() {   # stdin → stdout — every Btrfs line with noatime (the rest as it is)
  awk '/^[[:space:]]*#/ || NF < 4 || $3 != "btrfs" { print; next }
    { n = split($4, o, ","); out = ""; has = 0
      for (i = 1; i <= n; i++) {
        if (o[i] ~ /^(relatime|norelatime|atime|strictatime)$/ || (o[i] == "noatime" && has)) continue
        if (o[i] == "noatime") has = 1
        out = out (out == "" ? "" : ",") o[i] }
      if (!has) out = out ",noatime"
      $4 = out; print }' OFS='\t'
}
