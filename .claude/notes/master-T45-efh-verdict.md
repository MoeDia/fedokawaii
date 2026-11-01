# The master's verdict — T45 (e) (f) (h) and the main fixes of 1 Nov 2026 (10:36–11:45)

Reviewed: t45 at 44d881b (`git diff main...t45`), main at 7aaf42a (29bbfc7, 2fb0189); the evidence
in /dev/shm/r27/master/T45; the design §4, §4.2, §4.3. Facts checked on this PC, never from memory:
/etc/grub.d/08_fallback_counting, 10_reset_boot_success, 12_menu_auto_hide (sudo), grub.cfg's
section order (00_header → 08 → 10_linux/blscfg → 10_reset → 12), `grub2-editenv - list`
(saved_entry, boot_success=1, boot_indeterminate=2, menu_auto_hide=2), /boot/grub2/grubenv (a plain
0600 file on the xfs /boot; no ESP copy), one BLS entry with literal `options root=… rootflags=subvol=root`
(no rescue entry), /etc/sysconfig/kernel UPDATEDEFAULT=yes → 20-grub.install:177 writes
`tmp_saved_entry` into grubenv at every kernel install, grub2-set-bootflag writes by rename,
grub-boot-success.timer: globally disabled (setup.sh:470), PartOf=dwl-session.target, started by
configs/home/.config/dwl/autostart.sh:49 — so linger never marks a boot; the desktop does.
sp5100_tco loaded, /dev/watchdog0 present, RuntimeWatchdogUSec=0, kernel.panic=0.
dracut.cmdline(7): rd.emergency needs rd.shell=0 (both set); rd.retry default 180 s.
installonly_limit=2 in force (/etc/dnf/libdnf5.conf.d/90-fedokawaii.conf, setup.sh:401).
SELinux enforcing: a transient unit with `StandardOutput=append:/var/lib/fedokawaii/update/…`
writes (probed with systemd-run, then removed); `systemctl show -p ExecMainStatus` of a vanished
unit prints 0; a oneshot's TimeoutStartSec defaults to infinity.
Run myself: tools/regress/session-start.sh as root → runuser with as_user's exact environment,
`--dwl /usr/local/bin/dwl`: green in 8.97 s, nothing left behind (the (e) claim holds).

## Verdict: FAIL — six must-fix items before t45 merges into main; the core of (f) is sound and proven

What is right and proven: the GRUB counting as built matches the scripts on this PC exactly
(armed 3/0/1: three tries of the new kernel, the fourth start takes entry 1 and sticks at -1 until
userspace unsets it; the menu hidden on the first try only); the proof of a good start is the
desktop's own two minutes, not linger's; the VM proofs (fail: held, out, the one before the default
in 203 s; pass: closed in 142 s, snapshot back to number cleanup) are real Fedora 44 updates with
kernel 7.2.13 and the checks are strong enough that a broken counter, missing panic=10 or a
missing close would each show as BROKEN. test_update_flow's probation cases assert the right
calls and files. The main fixes are correct. The findings below are what an update on his PC
would still get wrong.

## Findings, most severe first

### must-fix

1. **A check that could not run is judged "the desktop does not start" — on his PC that is a false
   red that holds the whole set and (once /home is split) restores the system at the next start.**
   tools/regress/session-start.sh:30-31 exits 2 ("the kit failed: <last two lines of kit.log>") for
   anything from a dwl crash to a full /dev/shm, a missing python3-pillow (then line 33-36 says
   "nothing drawn: 0 colours", exit 1), a kit time-out; lib/guard.sh:189-195 `desktop_starts`
   treats every non-zero exit the same and returns only `tail -n 1` of the output; lib/update.sh:64
   wraps it as "the desktop does not start — …"; u_check → u_undo (lib/update.sh:280-292) holds
   every package of the set and offers/does the restore. The evidence shows the message this
   produces: fail.log/pass.log "red after the update: the desktop does not start — [2026-11-01
   11:27:53.589] [info] Using CSS file /tmp/kit.ezTJaQ/home/.config/waybar/style.css" — waybar's log
   noise, not a reason (the owner's "clear message" rule). The design's own principle for the
   candidate ("a container that does not even start is no verdict on the packages", cand_try) must
   hold here too. Fix: session-start.sh and bar-geometry.sh return 1 only with their own verdict
   line (dwl ended before the script → "dwl does not start: <dwl.log's last lines>"; a process
   missing; the bar blank or off its measure) and 2 for their own machinery (no theme link, mktemp,
   PIL import, grim, the kit's time limit); desktop_starts keeps the whole verdict (the line
   starting "session-start (" / "bar-geometry (", not the last line) and passes 2 through; in
   up_more/u_check an exit 2 stops the run as "stopped (check): the desktop check could not run —
   <why>" with nothing held and no restore — and runs the check a second time first (one retry:
   a loaded PC must not undo an update). tests: the world's stand-in (tests/installer/lib.sh:129-135)
   models exit 2 as a red — change it with the code, add the "could not run" case and the retry.

2. **`trap up_exit EXIT` (setup.sh:2877) replaces the EXIT trap that removes KAWA_TMP and kills
   dnf's journal follower** (lib/common.sh:515 from make_tmp, called at setup.sh:92; the setup-mode
   trap at setup.sh:108). Every update run leaks /var/tmp/fedokawaii.XXXXXX (dwl-start.log, the
   guard's `changed`), and a `die` while dnf_detached's `journalctl -f` runs (FOLLOWER) leaves it
   orphaned when setup.sh is run from a terminal (the VM proofs' way; inside the unit systemd's
   cgroup kill hides it). Fix: up_exit ends with `rm -rf "$KAWA_TMP"; [[ -n ${FOLLOWER:-} ]] &&
   kill "$FOLLOWER"` (or chains the previous trap); a test that a stopped run leaves no fedokawaii.*
   under /var/tmp.

3. **Nothing closes a probation if the path unit's one trigger is missed; `--kernels` then removes
   the fallback kernel while the counter, the trial arguments and the watchdog stay armed.**
   lib/update.sh:345-346 says "Closed by setup.sh --kernels, a quarter of an hour into every start"
   — false: setup.sh:3521-3528 (kernels mode) never calls up_probation_close, and old_kernels_out
   (setup.sh:485-504) only asks for boot_success=1, not for a closed probation. A path unit
   unwatches grubenv while its service runs (systemd path.c: path_enter_running → path_unwatch;
   re-armed only when the service stops) and the service waits on the setup lock (setup.sh:89)
   for as long as an update or apply runs — the one trigger it got may have been
   20-grub.install:177's `tmp_saved_entry` write during the replay. The service does read the
   state, so a mark before it runs is not lost; a mark while nothing triggers again is. Fix (cheap,
   makes the comment true): `--kernels` calls up_probation_close before old_kernels_out, and
   old_kernels_out desktop returns early while $UPD/probation names a kernel other than the running
   one; a test: probation open, boot_success=1, no path trigger → the kernels timer's run closes it
   and only then removes the one before.

4. **The button's real path (fedokawaii.sh update_unit → tail --pid → ExecMainStatus; system/fedokawaii
   follow_update) has never run on a real system.** The VM proofs call `setup.sh --update` directly
   (tools/vm-inject/probation.sh:532, update-green.sh:600); the engine tests stub systemd-run and
   systemctl (tests/engine/lib.sh:20-23). The first real run would be on his PC. I proved the
   SELinux/append part myself (above); the rest — the unit's environment (no HOME/TERM/SUDO_USER:
   TARGET_USER from the state file, FK_TERM colours into run.log, as_user's notify-send reaching
   the live bus from a system unit), tail following to the end, a non-zero ExecMainStatus of a
   failed unit, `reset-failed` on the next press — is one VM run away. Fix: update-green.sh (or a
   sibling) runs `fedokawaii update` as the menu does (root bash fedokawaii.sh update) at least
   once, pass and stopped, and checks run.log's last line equals the terminal's, the exit status,
   and that a second press while it runs follows and starts nothing.

5. **The renders are not of HEAD.** crop1.png (11:31) shows the "held" row faint with value "soon"
   while the pane says "1 held" — the row's old SOON state; crop2.png (11:38) shows a pane text
   ("an update goes in whole, or what breaks the desktop is held — …") that HEAD does not contain
   (system/fedokawaii:971 says "held at its version — let go by itself / once a newer one passes");
   the (h) commit is 11:41. Nothing proves HEAD's held pane (its wrapping at the pane's 41/45
   columns, the cut at a word) or the update tab's row. Fix: re-render both from HEAD, both themes,
   and measure (the owner's rule: pixel-perfect in both).

6. **A run resumed at `was=replay` can undo a transaction that is still running.** setup.sh:2891-2895:
   after a cut update unit (OOM, `systemctl stop fedokawaii-update.service`) the dnf child unit
   (fedokawaii-dnf-*, its own service) keeps installing; the next press finds the unit inactive,
   starts anew, reads `replay`, up_complete fails on packages not yet in, and u_undo holds the set
   and restores/offers while rpm writes. u_start's pgrep (lib/update.sh:38) runs only on the fresh
   path. Fix: before judging a cut replay, wait for any active fedokawaii-dnf-* unit as dnf_detached
   does (setup.sh:2576-2586) and refuse while `pgrep -x dnf5` matches; a test with the stub's dnf
   unit "still active".

### should-fix

7. **(e) is marked DONE while three of the design's phase-6 checks are not built and not recorded
   as deferred**: yazi (load the config), greetd (config parse), nvim (plugins from the lock, a
   checkhealth subset) — only foot --check-config is in lib/cand-check.sh:93; and §4.2's "coredumps
   for our programs: none new" is not in session-start.sh (tests/run.sh got a coredump check, the
   update's smoke test did not). Either build them or write the deferral into the plan's task line
   and the ledger with the reason, as the lock screen's was.

8. **Design §4.3 "entry 1 … must be the previous kernel (checked in grub.cfg)" is not checked.**
   up_probation (lib/update.sh:349-361) arms boot_counter without confirming that the BLS entries
   are exactly [new, running] (two entries, the second `version $now`, no rescue, GRUB_DISABLE_RECOVERY).
   On this PC today it holds (one entry, no rescue); a rescue entry or a third kernel would make
   entry 1 something else. Fix: count /boot/loader/entries and read the second's `version`; else do
   not arm, and say so. Related: the design's §3.1 rule "no kernel transaction runs while a probation
   is open" is not enforced in u_fetch; installonly_limit=2 keeps the chain from reaching three
   kernels (dnf removes the untried one), but when the trial kernel is the running, unmarked one
   and a newer kernel comes in, dnf removes the proven one before. Enforce the rule (hold the kernel
   family while $UPD/probation names a kernel ≠ running) or document why the limit suffices.

9. **A false "(checks)" after every green update on his PC.** setup.sh:2916 `[[ -s last-verify-fails ]]
   && result=checks` counts the baseline's reds (the PC is 259/260 today; the VM logs show
   "update done (checks)" with six pre-existing reds) → the status says "verify found problems:
   repair" for an update that made nothing newly red. result=checks only when u_check found new
   reds (it did not, or the run would have been undone) — so effectively never from here; keep
   `partial` for failed steps/holds.

10. **A stopped run's reason may be a previous run's.** lib/update.sh:304 greps '✘' over the whole
    $LOG_FILE; a run that dies without a ✘ line (killed, a write failure) reports the last ✘ of an
    older run. Grep this run's part only (`tail -c +$((RUN_LOG_FROM + 1))`, as last.log does).

11. **up_holds_apply's "already locked" test never matches.** lib/update.sh:221/229 greps
    "$n-$v" in `dnf versionlock list`, which prints the TOML entries (name = "…", value = "…" on
    separate lines, dnf5-versionlock(8) "VERSIONLOCK FILE FORMAT") — so `versionlock exclude` is
    re-run on every press; the test stub (stubs/dnf:207) prints "name-version" lines, so the test
    passes while the real check is dead. Parse the TOML (name + evr value) or just re-run exclude
    knowingly after proving dnf5 does not duplicate entries (sudo dnf versionlock list after two
    excludes in the VM).

12. **The trial should fail fast.** With rd.shell=0 rd.emergency=reboot (lib/update.sh:347) a new
    kernel whose boot image cannot find root waits dracut's rd.retry (180 s) before the reboot:
    three tries ≈ 9 minutes of a black screen before the one before comes, with no message. Add
    rd.retry=30 (this NVMe PC needs seconds) to UP_TRIAL — or say in the Learn piece what those
    minutes are.

13. **The harness VM's smoke test is red, so VM proofs never exercise a green desktop check.**
    tools/hl-dwl.sh:34-40 says "pixman on a machine with none" but any renderD* without
    mem_info_vram_total gets v=0 and `((0 > -1))` picks gles2 on it — virtio-gpu in the VM. Treat a
    missing mem_info_vram_total as no GPU (pixman) and make update-green/probation assert the check
    is green in the VM ("red after the update" must not appear in a green run's log).

14. **Leftovers of a run cut before `end`.** A pinned snapshot (snapper modify -c '' at
    lib/update.sh:251) from a run cut in snapshot/replay/check that never reached up_probation, or
    ended "offered"/"restored", is never released (space, for years); a root.cand left by a cut
    candidate phase is removed only by a later run that has updates (cand_try). u_start should
    release the previous run's pinned snapshot when that run did not end ok (UPD/report's outcome)
    and the pinned "before" of an "offered" run once the next update's probation closes; mount the
    top and drop a stale root.cand at every start.

15. **u_start does not refuse while a restore waits for a restart.** After UP_END=restored (or a
    restore from Super+U) the running root is the broken one until the restart; a press then runs a
    fresh update on it, applies the whole-set holds, pins a snapshot of the broken root. Refuse with
    "restart first: the system before the last update comes back at the next start" (UPD/report's
    outcome `restored`, or kawa-snap's own marker).

16. **Holds are appended, never deduplicated.** lib/update.sh:212 and :381 `>>"$UPD/holds"`: a close
    cut in its dnf remove (then triggered again at the next mark) or a re-hold writes the same
    NAME VERSION twice; held_count and the pane count them twice. Skip a line whose NAME+VERSION exists.

17. **verify.sh:223 checks fedokawaii-boot-good.path but not fedokawaii-update-resume.service**
    (enabled at lib/guard.sh:172) — the unit that undoes a cut transaction before the login screen
    is the more important of the two. One more row.

18. **The whole-set hold after a live-only red is a conscious deviation from §4/§4.1 ("the held
    package(s) found in candidates") that the design does not record.** It is defensible (a red
    the candidate could not see cannot be bisected in candidates; only the exact versions are
    excluded, newer ones come through) — write it into §4.3/§4.1 "as built", and make the report
    say it: "N packages held together — which one broke the desktop could not be told apart; newer
    versions are tried". With 60 held, system/fedokawaii:424-432 groups by version+why, so the pane
    would show 3 of ~50 families and "?" for packages sharing nothing; show "and N more", and key
    families by source package (record it in the holds file from UPD/sources) instead of a name
    prefix.

### notes

- lib/update.sh:363-364 UP_DOG written after UP_END=ok: a write_file failure there (ERR → die) ends
  the run after the update is kept, with up_exit skipping u_report (UP_END set) — no report, no
  notice, last-update not recorded. Order up_probation's writes before UP_END, or let up_exit report.
- The watchdog drop-in (RuntimeWatchdogSec=1min) stays in effect during a trial boot's suspend/resume
  if he ever suspends; sp5100_tco keeps counting in S3 on some boards — a spurious reboot would count
  as a failed start. He does not suspend today; worth one line in the Learn piece.
- The update's own `grub2-editenv set boot_success=0` (up_probation) makes the same session's
  `--kernels` and `fedokawaii-split clean` skip until the next good start — harmless, but the log
  line "this start has not reached the desktop for two minutes" is then untrue; say "a kernel is on trial".
- fedokawaii-update-resume.service runs at every boot once $UPD/phase exists (it exists forever
  after the first run). Measured: a setup.sh start is 36 ms — acceptable; a dedicated marker
  written only in the replay phase would make the condition exact.
- GRUB's menu shows for GRUB_TIMEOUT=5 s on the second to fourth starts of a trial
  (menu_hide_ok=0 once boot_indeterminate is 2) — by Fedora's design; say so in the Learn piece.
- tests/run.sh:181-184: coredumpctl reads the journal; as the test user this needs journal access
  (he has it) — the check silently finds nothing on a machine without it. `coredumpctl … || true`
  with a note is fine; just know it.
- hdr "update done ($result): $UP_LINE" (setup.sh:2927) prints the outcome twice when u_report's
  notice already carried it; cosmetic.

## Main fixes (29bbfc7, 2fb0189): PASS
- tests/installer/lib.sh: the world's anaconda fstab and built()'s pace_fstab pass — correct; the
  mpris.so link replaced, never written through — correct. Results claimed (233/0, 70/0, 84/0,
  214/0, 175/0) match installer2.log (25/25).
- stubs findmnt (xfs /boot), mount (a remount recorded), bluetoothctl — correct and minimal.
- tests/run.sh core-dump check — correct (exit 1 only with dumps under /tmp/kawa-test*).
- tools/kit.sh foot --server --log-no-syslog — correct (foot(1) has it).
- setup.sh released(): Fedora's own server alone, `-f` in CURL makes a 403 "not released", no
  fallback to a mirror — correct, zero fallbacks; the test case asserts no mirror asked and no day
  recorded.
- lib/manifest.sh python3-pillow with its evidence line — correct.
- tools/hl-dwl.sh: the most-VRAM rule is right for the PC (dGPU, or the iGPU when the games VM holds
  the card) — see 13 for the VM.

## What to do with this
Fix 1–6, re-run test_update_flow, the engine area, one VM run of the button through the unit
(4) and one re-render (5); then hand me the diff of the fixes only. 7–18 go into the plan as
T45 items with their own acceptance tests before the task is called done.

## Re-review (1 Nov, 12:35–12:55) — t45 at b006c8f (dbc5f3e + one hl-dwl fix), re-read as a re-review

Read: the diff 44d881b..dbc5f3e of lib/ setup.sh fedokawaii.sh system/fedokawaii verify.sh tools/ tests/,
b006c8f, the evidence in /dev/shm/r27/master/T45-2 (tests-sf/sf2, the two renders, run 1), the ledger's
fix list. Run myself at b006c8f: tests/engine/test_status.sh 204/0, tests/installer/test_verify.sh 178/0,
tests/static/test_dwlconfig.sh 2/0; `bash -uc 'echo $((x+1))'` (set -u does fail on an unset name in
arithmetic — RUN_LOG_FROM is set at source time, lib/common.sh:291, after LOG_FILE, setup.sh:34: fine);
dracut 108 on this PC: 77initqueue/dracut-initqueue.sh:14-16,78-80 (RDRETRY = rd.retry×2 half-seconds,
then emergency_shell → rd.emergency=reboot); the PC's boot state (sudo): one BLS entry 7.2.11, grubenv
boot_success=1, no boot_counter, dracut-config-rescue not installed, python3-pillow-12.3.0-1 installed.
The VM run 3 (update-button.sh from b006c8f, f44b): its result file at 12:44:52, and the VM itself read
live (read-only) while it ran — its unit, process tree, run.log and the presses' output files.

### must-fix
1. **FIXED.** lib/guard.sh:177-189: 0 · 1 red · 2 could not run, one retry on 2, the check's own line
   (`^session-start[ :(]` / `^bar-geometry[ :(]`), never the last line of noise. lib/update.sh:68
   (up_more passes 2), :59 (u_start: die "nothing changed" — before u_fetch/u_snapshot, setup.sh:2902-2908),
   :284 (u_check: UP_STAY=1, nothing held, nothing undone), :315 (the phase kept → the next press resumes
   at the checks, setup.sh:2900). tools/regress/session-start.sh:30-41: dwl died → exit 1 with its verdict,
   the kit's machinery / PIL / the shot → 2. Tests: the stand-in models 2 with a countdown
   (tests/installer/lib.sh:428-433, stubs/dnf:96); test_update_flow.sh:140-150 (one retry → ok, three
   calls; cannot run after the replay → stopped, phase `check`, no hold, no restore, the next press ok
   without a replay). Residue, not blocking: bar-geometry.sh:25 still exits 2 for every kit failure
   (dwl dying included) — covered because session-start runs first in desktop_starts and names it; a
   "could not run" message may still quote kit.log's last line (session-start.sh:35) — it stops nothing.
   Note: lib/update.sh:54 installs python3-pillow with dnf before the pinned snapshot (on the PC it is
   present; in the VM it went in under the after-dnf guard) — acceptable, say it in the Learn piece.
2. **FIXED.** lib/update.sh:423 does what lib/common.sh:515 / setup.sh:108 did (KAWA_TMP, FOLLOWER;
   resume_hint is setup-mode only). test_update_flow.sh:107-109 finds no /var/tmp/fedokawaii.* after a
   stopped run — meaningful: the world bind-mounts /var/tmp (lib.sh:75).
3. **FIXED.** setup.sh:3533 (`--kernels`: up_probation_close before orphan/old_kernels_out; safe with no
   file, lib/update.sh:378-379); setup.sh:496-499 (old_kernels_out returns while UPD/probation names a
   kernel — every caller: 547, 2867, 3269, 3533); the comment at lib/update.sh:358-361 is true now.
   Tests :235-245: the close's `unset boot_counter` precedes the remove in the call log; the update's
   own one-kernel step keeps the one before.
4. **FIXED in substance — the harness itself is not yet sound.** tools/vm-inject/update-button.sh ran the
   real path on f44b (run 3, b006c8f): `fedokawaii.sh update` as root → the unit → append:run.log →
   tail --pid → ExecMainStatus. Proven: a press returns 0 with the run's own last line; the stopped run
   (another dnf5) returns 1 with its reason said; the report file ok; a concurrent press from root's
   front and the user's menu got ONE unit between them (starts: 2, not 3; both ended on the same line,
   exit 0) — a press while one runs only follows. Not proven: the "three presses, one unit" row — the
   first press's unit had already ended when the second came 40 s later (first.out: "update done (ok):
   updated · 49 packages" stamped 12:38:08; the second press's unit started 12:38:51 and did 12 more
   packages; the VM's clock after a revert and its journal were not kept, so whether the first unit
   was launched earlier than the harness assumes or was a leftover cannot be told from the out dir).
   Four of seven rows read BROKEN for that reason alone — the button's mechanics are right in all of
   them. Also seen in the VM: the desktop check under the unit's as_user RUNS (its own verdict line),
   so the environment is right; notify-send from the unit is not checked by the script.
5. **FIXED.** renders-both-moods.png is HEAD's held pane (system/fedokawaii:971's text, both moods, no
   truncation, the pane's labels and values on the update pane's columns) and it caught "4 held" against
   the row's "2" → 2b95146 (status_kv uses held_count: system/fedokawaii:263, :758; test_status.sh:65-68),
   update-tab-after-count-fix.png shows "61 packages · 2 held" (dark only — the count is text, the light
   layout is unchanged in the first render: acceptable). system/fedokawaii unchanged since 2b95146.
6. **FIXED.** setup.sh:2579-2591 dnf_settle (out of dnf_detached), :2894-2895 (a cut replay: settle, then
   refuse while dnf5 runs); stubs/systemctl:28-33 (a busy unit counts down, list-units); test :163-167.

### should-fix claimed done
- 9 **FIXED** setup.sh:2918 (result=ok unless steps failed or holds → partial). · 10 **FIXED** lib/update.sh:312
  (this run's bytes). · 12 **FIXED** lib/update.sh:362 rd.retry=30 — correct on this PC's dracut 108
  (≤ 30 s a try, the timeout hooks at 20 s, then rd.emergency=reboot); test and probation.sh assert the
  string. · 15 **FIXED** lib/update.sh:35 via on_the_system (setup.sh:1206-1210: FSROOT must be /root —
  after kawa-snap's exch, system/kawa-snap:342, the running root is no longer /root); test :264-267.
  · 16 **FIXED** lib/update.sh:217, :391. · 17 **FIXED** verify.sh:224; the world's units lib.sh:528; test_verify 178/0.
- 13 **FIXED BUT NOT WHAT WAS CLAIMED.** The renderer rule is right only since b006c8f (tools/hl-dwl.sh:37,
  vendor 0x1af4 — dbc5f3e's `*/virtio_gpu` never matched: the node's driver is virtio-pci). But the commit's
  "in f44b the session check is green with pixman" is contradicted by run 3's own log: "red before the
  update: the desktop does not start — session-start (dark): not running: waybar · not running: mako ·
  nothing drawn: the bar's rows hold 1 colour" (the VM's run.log line 4, 12:39:24) and the same after.
  dwl starts and the kit plays — waybar and mako do not come up in the VM's headless session. Because
  up_labels (lib/update.sh:29) compares labels without the detail, a red baseline with this label masks
  EVERY desktop breakage after an update in the VM: the VM proofs still never exercise the desktop check
  (my point 13's second half, the assertion, is not built either). On the PC the check is green (my run
  of 11:xx as the update runs it) — this is a VM-only blindness, but it must go.
- 7 **DECIDED, HALF RECORDED.** The coredump reasoning holds (each piece is checked running in its own
  runtime dir; nothing restarts in the kit). The yazi/greetd/nvim deferral is in the ledger
  (02-LEDGER.md:2359) but not in the plan's T45 task line (plan.md:558 still reads "(e) DONE …" with no
  deferral) — write it there, as asked.

### the open ones (8, 11, 14, 18) against the PC's first run (98 updates, kernel 7.2.13, Mesa 26.2.5)
- 8 — acceptable to defer, for this run only: the PC has one kernel-core (7.2.11), no rescue entry and no
  dracut-config-rescue, so after the update the BLS entries are exactly [7.2.13, 7.2.11] and entry 1 is
  the running, proven kernel; installonly_limit=2 keeps it so. The §3.1 gap needs a second kernel inside
  an open trial — before T46 (a release upgrade always brings a kernel) both halves must be built.
- 11 — acceptable: only a failure path (a hold) re-runs `versionlock exclude`; a duplicate TOML entry
  does not change what dnf excludes. Prove dedupe or parse the TOML in the next pass.
- 14 — acceptable: a cut run leaves a pinned snapshot / root.cand — space, never breakage; the 5 GB
  unallocated gate (lib/update.sh:49-51) refuses the next press before the disk is in trouble.
- 18 — acceptable for function, not for looks: a live-only red on the PC holds all 98 at once. The pane is
  safe (system/fedokawaii:278 strips "held:", the row counts families), but the notice (lib/update.sh:323)
  carries "held: a b · c d …" for 98 packages — a critical notice of ~2.5 KB. Next pass: "N packages
  held together — …" in the notice, the design text, "and N more" in the pane.

### main's two fixes, glanced
r27-found-4 (fd0739a): tests/static/test_dwlconfig.sh reads the patch's config.def.h hunk against
config.h's names that dwl.c reads, the fixture pinned to DWL_COMMIT — right, and it is the check that
would have caught 28 Oct–1 Nov; 2/0 at HEAD. sshd (6a9d389): verify.sh:539 grep -qix, the stand-in's
camel case under $FKH/sshd-camel — right; test_verify 178/0 at HEAD.

## Verdict: PASS WITH CONDITIONS
The six must-fix items are fixed with evidence; the seven should-fix items claimed are fixed (13 only
in its renderer half); the four deferred are safe for the first run on the PC as it stands today.
Conditions:
**Before the merge** (minutes): (A) plan.md's T45 line records the deferrals — 7's three config checks
and the coredump decision, 8, 11, 14, 18 — each with its acceptance test.
**Right after the merge, on the PC — the agent's run, watched, not the owner's click:** (B) `fedokawaii
apply` from main, verify green (the new resume-unit row included), nothing of his unsaved; then
`fedokawaii update` as the menu runs it; the ledger records: the baseline (verify 259/260, and NO "red
before the update: the desktop does not start"), the set, the probation armed for 7.2.13 (grubenv
3/0/1, the trial arguments with rd.retry=30, the watchdog drop-in), the report; then a restart through
greetd's initial_session, the probation closed (journal of fedokawaii-boot-good.service or the kernels
timer), the pin released, 7.2.11 removed; numbers before/after. (C) If that run ends offered, restored,
held or stopped: stop, report to him, no blind retry.
**Next pass, before any further press that can bring a kernel and before T46:** (D) 8 both halves;
(E) 13: find why waybar and mako are "not running" under the unit's as_user in the VM (KEEP=1, kit.log,
play.log), fix the kit or the VM, then update-green/probation/update-button assert that "the desktop
does not start" is absent from a green run's log; (F) update-button.sh launches the second press only
once the unit is active and past "the checks before it", asserts one unit instance across the presses
(ExecMainStartTimestamp or MainPID recorded at each press), keeps the VM's journal of the units in the
out dir, and runs green; (G) 11, 14, 18 as planned, 18's notice line capped; (H) 7's three checks with T58.
