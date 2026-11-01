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

## Re-review 2 (1 Nov, 14:46–15:20) — main at aa9366a

Read: the Re-review above; /dev/shm/r27/master/T45-B (brief, diff a353613..HEAD, selinux-repro, update1.out,
update2.out, apply3.log, the merge's suite log); ledger r27-49-merge … B2; update-design §4.1 as built; plan.md's
T45 line; lib/update.sh whole; setup.sh:37-88, :328-338, :2538-2550, :2603-2617, :2916-2930, :3537-3542;
lib/guard.sh:170-190; lib/common.sh:335-341, :695-714; fedokawaii.sh:208-235; system/fedokawaii holds();
tests/installer/{lib.sh (fk, FK_INNER, back), stubs/_lib.sh, stubs/dnf, stubs/grubby, stubs/btrfs,
test_update_flow.sh, test_setup.sh:298-303, test_torture.sh:212-228}; tests/engine/test_{front,menu,status}.sh;
tools/vm-inject/{update-button,update-green,probation}.sh; tools/regress/{session-start,bar-geometry}.sh; the VM
proof /dev/shm/r27p/button5.txt and /dev/shm/r27/update-button-f44b/{run.log,state.txt,stop.txt,units.txt};
/dev/shm/r27p/head3.log (the HEAD suite). Ran (read-only, sudo): grubby --info=ALL; grub2-editenv list;
UPD/{probation,snap,report,phase,holds}; snapper list; grub.cfg (08_fallback_counting, menuentry positions);
journalctl of the unit (both presses) and the audit AVCs of both windows; restorecon -n -f over the 25 611 files
of the 96 updated packages (nothing to relabel); hold_families on a crafted file; transient-unit probes (id -Z):
bash → initrc_t; with the context → unconfined_service_t and `runuser -u dia` keeps it; stdbuf → bash
(dnf_detached's shape) → unconfined_service_t; an unknown context WITHOUT "-" → 229/SELINUX_CONTEXT, unit failed,
the journal names the step; WITH "-" → exit 0, running in initrc_t. Sources: systemd.exec(5) installed; dnf5
5.4.6.0 dnf5/commands/versionlock/versionlock_exclude.cpp (raw.githubusercontent); rhboot/grub2 fedora-44
grub-core/commands/blscfg.c; /usr/sbin/grubby 8.40-88 (:88-95, sort -Vr of the BLS basenames); 08_fallback_counting
as grub.cfg:136-155. Tests run by me: test_front 133/0, test_menu 611/0, test_status 207/0, test_update_flow
261/1 twice (15:02, 15:12 — the same row; its cause, this PC's own state, in must-fix 5); the HEAD suite still
running at 15:15 (/dev/shm/r27p/head3.log: test_setup 232/1 so far; test_update_flow not yet reached, and it will
carry the same red). The second press's test rows for (F)/(E) were read from the finished VM proof (14:51).

### Proven
- **(B) the PC's press of 14:39** — the unit in unconfined_service_t; NO red baseline (verify's one qbittorrent
  row only); 96 packages stored → green in the copy → snapshot 381 pinned (snapper: no cleanup, important=yes) →
  replay → steps → verify 1/262 (qbittorrent, in the baseline) → desktop check green → kernel 7.2.13 on trial:
  `grubby --info=ALL` = [7.2.13 (index 0), 7.2.11 (index 1)], the trial arguments on 7.2.13's entry only,
  grubenv saved_entry=…7.2.13 boot_counter=3 boot_success=0 boot_indeterminate=1, the watchdog drop-in,
  UPD/probation "381 7.2.13-200.fc44.x86_64 2026-11-01", report "ok · updated · 96 packages", press exit 0,
  4 min 14 s (journal). Labels of all 25 611 files of the set correct; 8 AVCs in the window (6 setfiles_t:
  restorecon denied `map` on libstdbuf.so — should-fix 3; 2 pasta_t — Prowlarr's network, unrelated). GRUB's way
  back: grub.cfg:37 `set default=saved_entry`, then :143 `set default=1` (08_fallback_counting); no menuentry
  before `blscfg` (:185), the grub-btrfs submenu after it (:301) → entry 1 = 7.2.11. The trial's close is still
  ahead (the next start) — not judged.
- **The SELinux cause (B1)** is real and reproduced by me; the fix puts the unit in the domain systemd gives any
  unit whose binary carries no policy (the dnf units already ran there: stdbuf is bin_t; dnf5 is rpm_exec_t —
  setools is not installed, so the transition from there was not queried; verified by outcome: every file of
  the set labelled right, no rpm/dnf AVC). No other unit runs the desktop check (desktop_starts' only caller:
  lib/update.sh:79); fedokawaii-kernels/boot-good/update-resume run bash → initrc_t, their paths were proven in
  the VM before (probation.sh) — the close on the PC is the next proof.
- **(D) 8, both halves**: lib/update.sh:398-408 (the menu exactly [new, running]), :98-104 (`--exclude=` of
  KERNEL_PKGS while a probation names a kernel; dnf5(8) list option). Order: blscfg sorts entries by filename
  with split_cmp/vercmp, newest first; grubby sorts the same basenames with `sort -Vr` — equal for Fedora kernel
  names (they could differ only on `~`/`+`, which Fedora kernel versions never carry). The rescue entry: the
  installer removes it (setup.sh:690; verify.sh:280), so [new, running] is the installed shape, and the VM run
  armed its trial (units.txt:18804). Tests :264-270, :275-281 meaningful — but see must-fix 5.
- **(G) 11**: the dnf5 5.4.6.0 source confirms it — specs each resolved, grouped by name, exclude_versions adds
  only the EVRs not present, "already excluded" otherwise, `vl_config.save()` only `if (changed)`; the installed
  dnf5-5.4.6.0-1.fc44 was not changed by the run. up_hold/up_holds_apply one call each (:244, :259); the stand-in
  adds each spec once; tests :85-92 meaningful (one call a press, none written twice, `versionlock list` never).
  **14**: up_leftovers :63-74 — the copy dropped (btrfs subvolume list), the pin released unless a probation lists
  it; tests :186-196 (the order before `filesystem usage`); the two vacuous "copy left behind" rows now read
  $FKH/subvolumes. **18**: hold_families (lib/common.sh:703-714) shared by pane and report; the report line capped
  (:330-333); tests: 60 held → ≤ 200 characters, "and 57 more.", "61 packages · 60 held".
- **The signal trap**: setup.sh:81-88 — MODE set at :37 (set -u safe); build + phase done → "built", exit 0 (the
  install's last reboot, :2547); every other mode "interrupted — press update again (Super+U) / run the same
  command again", 130 INT, 143 TERM; the EXIT trap writes the report with that line (test :190-197; update1.out
  :316-318 shows the old "✔ Fedokawaii is built" and "no reason could be written" — the motive). test_torture.sh
  :223 (INT → 130 + the text) agrees. The phase-1/2 reboot (:337 `systemctl reboot; exit 0`) can still print
  "interrupted" when the shutdown's TERM lands first — as before, cosmetic. The TERM test is sound: FK_INNER ends
  in `timeout 240 "$@"`, so setup.sh is its own process group and the stub's group kill reaches only the run.
- **(F) the harness**: update-button.sh waits for is-active and "upgrade --store=" in run.log (the fetch has
  begun), reads the InvocationID at each press (one: b2903890…), keeps the units' journal (units.txt), asserts the
  absence of "the desktop does not start" — and that assertion is what caught must-fix 1. The stop row holds.
  update-green.sh and probation.sh carry the same assertion but were not run since the fix: not yet proven.

### Must-fix
1. **lib/update.sh:27 (`up_labels` strips " — …"), :82 (every desktop red gets the one label), :310 (labels
   compared): a desktop red before the update hides ANY desktop red after it.** Shown by the agent's own proof
   under the fixed unit: units.txt:12686 "red before the update: the desktop does not start — bar-geometry
   (light): the clock's gaps:  (want 14 …)" and :18803 "red after the update: the desktop does not start —
   session-start (dark): not running: mako" — yet "update done (ok)" (run.log, state.txt), report ok. The notice
   daemon not starting after an update is the very thing the check exists for. The Re-review's point 13 ("a red
   baseline with this label masks EVERY desktop breakage") was answered only for its SELinux instance; the logic
   is unchanged. Fix: the desktop check's lines compared whole (check + finding), not by label — and a red
   desktop baseline said in the report ("checked against a desktop that was already red: …"); a test_update_flow
   row: session-red "not running: waybar" before, replay-breaks → "not running: mako" after → offered, held (the
   row at :151-155 stays green).
2. **(E) is not fixed, and the claim "the same SELinux cause — not VM-only" is refuted by its own proof**:
   button5.txt rc=1 — "the desktop check green before and after (no "the desktop does not start") BROKEN". In the
   VM the check is red for a different reason each time (bar-geometry's empty gaps before, mako after). The
   condition stands as written: KEEP=1, kit.log, play.log, mako's and waybar's own logs in the VM; fix the kit or
   the VM; then update-button, update-green and probation green. Until then no VM proof exercises a green desktop
   check — and 1 shows what that costs.
3. **The suite on HEAD is red**: tests/installer/test_setup.sh:303 greps the old `trap 'if [[ $(head -n1 …) ==
   "done" ]]; then` line, gone with on_signal → test_setup 232/1 (/dev/shm/r27p/head3.log). "All must pass before
   pushing": HEAD is 7 commits ahead of origin/main, unpushed — keep it so until green; the test must assert
   on_signal (build + done → "built"/0; else interrupted 130/143), best behaviourally (TERM a built fake machine in
   build mode: "built", exit 0).
4. **fedokawaii.sh:224 — the "-" in `SELinuxContext=-…` is a fallback that hides exactly the failure the fix is
   for.** My probe: a context that cannot be set runs the unit silently in initrc_t (exit 0 — the blind baseline
   again); without "-" the unit fails loudly (229/SELINUX_CONTEXT, the journal names the step, the press returns
   229). SELinux disabled is "ignored" already (systemd.exec(5)), so "-" buys nothing on this system. Drop it, and
   let u_start assert its domain (`id -Z` unconfined_service_t or unconfined_t while SELinux is on) so a run can
   never begin blind again; test_front asserts the property without "-".
5. **The fake machine inherits the PC's live state, so a test's verdict depends on what the PC is doing**:
   test_update_flow's "a kernel with a third entry … no trial" row (:280) fails 261/1 in both my runs (15:02, 15:12)
   with "the watchdog on with no trial" — the code is right (nothing armed, "not on trial: the boot menu is
   [… 0-rescue…]" said, probation "- "): tests/installer/lib.sh:195 `cp -a --no-preserve=ownership /etc/. "$W/etc/"`
   copies this PC's /etc into the fake machine, and since the real press /etc/systemd/system.conf.d/
   90-fedokawaii-probation.conf exists here (mtime 14:43) — the agent's 254/0 and 262/0 predate it; the HEAD suite
   (started 14:46) carries the same red. The coordinator confirmed the same cause in a one-case harness file and is
   fixing it on `next` (the world build drops the host's probation drop-in). That point fix is not enough: the same
   leak bit once before (memory: "installer world copies host /etc — an apply can change installer test results"),
   and every file the toolkit owns under /etc (its 90-fedokawaii*.conf drop-ins, versionlock.toml, the probation
   drop-in, greetd's and dnf's files) leaks the PC's state of the moment into a code test. Scrub at world build
   everything the toolkit writes under /etc (the list derivable from the toolkit's own writers), or build the
   world's /etc from a pristine Fedora /etc rather than this PC's; and make such rows assert their precondition
   (the file absent before `up`). The suite must be green on the pushed commit whatever this PC is doing.

### Should-fix
1. lib/update.sh:63-71 — up_leftovers releases every non-green run's snapshot, not only a cut run's: after
   UP_END=offered no probation line is written and UPD/snap persists, so the next press hands the very snapshot
   the report pointed him to ("snapshot N is the system before it") to snapper's number cleanup (kept a while by
   NUMBER_LIMIT_IMPORTANT, no longer pinned). Keep it pinned while the last report is offered — or say in that
   report that pressing update again releases it; a test row.
2. setup.sh:2696 / :1141 — the update's steps install manifest-missing and hardware packages live, after the
   replay, outside the stored and copy-proven transaction (the VM run: python3-pyte, wlrctl, wireless-regdb in
   three dnf transactions, units.txt:3975-4035; the PC's run had none). Either store them with the transaction (a
   second `--store` of `install`) or write the exception into update-design §3 and the Learn piece.
3. setup.sh:2613 `stdbuf -oL -eL dnf` — stdbuf's LD_PRELOAD is inherited by every scriptlet; confined ones
   (restorecon → setfiles_t) are denied `map` on /usr/libexec/coreutils/libstdbuf.so: 6 AVCs an update, and ld.so
   noise on scriptlets' stderr. dnf5 wrote the journal line-wise here anyway — try without stdbuf, or clear
   LD_PRELOAD for dnf's children.
4. lib/common.sh:695-699 says "never two sources merged"; :703-714 merges any names sharing their first component
   at one version and reason — python3-foo + python3-bar 3.14.1 → "python3" (my run). Use UPD/sources (up_sources
   already yields NAME SOURCE) when present, else the prefix; or soften the comment.
5. After a stop the unit stays `failed` (exit-code 143) until the next press's reset-failed (fedokawaii.sh:220)
   — right, but `systemctl --failed` shows it meanwhile: a line in the Learn piece. (C) was observed in spirit:
   the first press stopped by the agent at a red baseline, the cause found, fixed and recorded — no blind retry.

## Verdict 2: FAIL
Until must-fix 1–5 are done. What stands and need not be redone: (B) the PC's press, proven ok up to the trial's
close (the close itself: the journal of fedokawaii-boot-good after the next start, the pin released, 7.2.11 out —
record it); (D) 8 and (G) 11/14/18 built and proven; the signal trap; (F)'s harness, which is sound and did its
job. Conditions for the next review: 1 and 4 with their tests (test_update_flow, test_front) green; 2 with the
three VM proofs green and their logs kept in /dev/shm/r27; 3 fixed and 5's harness fix (from `next`) merged, then
the whole suite green on the commit that is pushed — run while this PC still has its kernel on trial, so the
world's independence from the PC's state is shown, not assumed; the should-fixes decided (done, or written down
as a decision in the ledger).

## Re-review 3 (1 Nov, 16:25–17:15) — main at 78ea68c

Read: the brief (/dev/shm/r27/master/T45-3/brief.md); Re-review 2; the diff aa9366a..78ea68c whole (lib/update.sh,
fedokawaii.sh, lib/common.sh, setup.sh, the tests, tools/vm-inject/*, tools/vm-run.sh, update-design §2.5, plan T45/T50);
lib/update.sh at 78ea68c whole; lib/guard.sh desktop_starts; tools/regress/{session-start,bar-geometry}.sh;
tests/installer/lib.sh world() and its stand-in desktop checks; system/fedokawaii status_kv/explain/pick; setup.sh
on_signal, dnf_detached, do_update's resume; ledger r27-49-master-2-fixes … R3; the VM proofs' kept logs (button7.txt +
run 7's units/state/stop; prob-main.txt + fail/pass logs; the green re-run's run.log and — read-only, through
vm-run.sh — the VM's own processes, units and journal while it hung). Sources: systemd.exec(5), ausearch(8),
dnf5-do(8), dnf5-upgrade(8), `dnf5 install --help` installed; the PC's journal (fk-buftest* 16:04–16:06; the press's
reloads 14:42); audit via ausearch. Ran (read-only, sudo): grub2-editenv list and the probation drop-in — 3/0/1 and
present at 16:28 and at the suite's end 17:10; UPD/*; a [[ == @() ]] probe (bash's [[ matches "as if extglob were
enabled": no shopt needed); desk_reds against a two-line bar verdict; shellcheck -S warning on the four changed scripts
(clean); a derivation of every literal /etc path setup.sh/theme.sh/lib/system write (82) against this PC's /etc and the
world scrub. Tests run by me from /dev/shm/r27w-master: test_front 133/0, test_update_flow 283/0 (serialised behind the
suite's installer lock). The whole suite on 78ea68c (/dev/shm/r27p/suite-78ea68c.log, from /dev/shm/r27w-suite =
78ea68c): rc=0 in 2915 s, 128 areas, none red — started 16:21 and ended with this PC's kernel still on trial.

### Proven
- **Must-fix 4**: fedokawaii.sh:225 no "-"; u_start (lib/update.sh:39-42) dies in any domain but unconfined_service_t
  (the unit) or unconfined_t (by hand) while `selinuxenabled`; test_front asserts the property without "-" (133/0).
- **Must-fix 1, the session half**: desk_reds (lib/update.sh:91-99) a line an item, the item in the label; up_labels
  compares before " — "; a kept update with a red desktop baseline says so (u_report :363-381, "red before it: …").
  Rows test_update_flow:164-176 meaningful (a waybar-red baseline kept and said; a bar red before + dwl gone after →
  offered, held); the real checks' format matches the stand-ins' (session-start.sh:33/43, bar-geometry.sh:20). The
  bar half is NOT closed — must-fix 2 below.
- **Must-fix 3**: on_signal (setup.sh:81-86) with the traps :87-88; test_setup:303-305 asserts the condition and the
  TERM trap, the behaviour in test_update_flow's TERM row and test_torture:223; test_setup 234/0 in the suite.
- **Must-fix 5**: tests/installer/lib.sh:229-233 scrubs by marker, by name (*fedokawaii*, *scriptorium*, kawa-*) and
  the listed unmarked files; my derivation: of the 82 /etc paths the toolkit names, none this PC has survives the scrub
  (grub and fstab the world writes itself, :221/:202, before it); the third-entry row asserts its precondition (:299).
  The suite green on the pushed commit while this PC's /etc held the trial's drop-in: the independence shown, not assumed.
- **(E)/(F)**: update-button run 7 (3d25e97 — fedokawaii.sh, lib/guard.sh, tools/regress unchanged to 78ea68c) 9/9
  held, units.txt: "the desktop does not start" 0 times, one invocation, the stop row; probation.sh (766b434) fail held
  in 213 s, pass in 173 s, exit 0; update-green from `next` (E4) exit 0. The re-run from 78ea68c did not finish:
  must-fix 1 below — (E) is not green on the pushed commit.
- **Should-fix 1** (c1841f6): up_leftovers :75-82 keeps an offered run's snapshot in UPD/offered, up_probation :443
  hands it to the probation, up_probation_close :483-486 releases it; row :129-134 (not released, in the probation,
  released by --boot-good).
- **Should-fix 3**: stdbuf gone (setup.sh:2612-2614); the measurement is real — the PC's journal: fk-buftest3
  (systemd-run, StandardOutput=journal, no stdbuf) wrote kernel-core's line 16:05:30.00, linux-firmware's :35.16,
  kernel-modules' 16:06:08.43 — line by line as each download ended; the 6 libstdbuf AVCs of the 14:39 press counted
  by me (`ausearch -m avc -ts today | grep -c libstdbuf` → 6); test_upkeep asserts no stdbuf in the unit.
- **Should-fix 4**: holds carry SOURCE (lib/update.sh:263-267, :278-287, :466); hold_families by source
  (lib/common.sh:701-706); rows :157-162 (python3-foo/-bar two families), :83 ("kernel", never kernel-core).
- **Should-fix 2 and 5** written (update-design §2.5; plan T50's acceptance).
- The open items — the PC's trial close (B3), (H) 7 with T58, (i) the tag — are stated as open in plan T45 and the
  ledger's next-pass note, not claimed.

### Must-fix
1. **setup.sh:2612 dnf_detached — the update can hang for good after a finished transaction.** update-green from
   78ea68c (VM f44, the run from 16:26): the replay unit fedokawaii-dnf-1793536088-1277 ended 16:28:47.27
   "Deactivated successfully", Result=success ExecMainStatus=0 — and `systemd-run --quiet … --wait --collect`
   (pid 55596) was still waiting at 16:46, its private-socket connection ESTAB, the unit already collected
   (`systemctl show`: LoadState=not-found), setup.sh --update blocked in phase replay, the VM idle (load 0.00), no
   "exit" line ever (stopped by the coordinator 16:52; the capture: /dev/shm/r27/master/T45-3/hang-evidence.txt).
   Around the end: two daemon-reloads from the transaction's own scriptlets (16:28:44.19, 16:28:46.49), PID 1 "Got
   disconnect on API bus" twice (16:28:44.46, 16:28:46.43), systemd's %triggerin scriptlets failing their own
   transient units ("Remote peer disconnected"). The PC's press of 14:39 had the same reload pattern (14:42:29.35/.63)
   and returned; E4 and run 7 returned: a race, not a certainty. Fact: the waiter's reference on the unit was lost (the
   unit collected while the waiter lived), so it vanished before systemd-run read its end; the why (a reload between
   start and end) is a hypothesis to confirm in systemd's src/run/run.c and the core's unit serialization. Today's
   recovery needs him: a stop, then a second press (do_update: was=replay → dnf_settle → up_complete → the steps) —
   against "he never has to step in". Fix: the end never read through a bus subscription — the coordinator's 79cd435
   (no --wait/--collect, RemainAfterExit=yes, `systemctl show -p ActiveState,SubState,ExecMainCode,ExecMainStatus`
   once a second, stop + reset-failed after, dnf_settle clearing a cut run's ended units) is the right shape; "never a
   time limit" stays. Proof wanted: a test_upkeep stub row (a systemd-run that returns at once, a unit whose end comes
   later; a cut run's ended unit cleared by dnf_settle), and the VM proofs from the fixed commit — update-green and
   update-button twice each, one of them with a daemon-reload storm in the VM during the replay
   (`while :; do systemctl daemon-reload; done` from a second ssh) to force the race the fix must survive.
2. **lib/guard.sh:185 `tail -n 1` — the bar check's reds reach desk_reds one at a time, so a red before can still hide
   one after.** bar-geometry.sh prints a line per failing item (`no`, :20), both themes in one run; desktop_starts keeps
   only the last line. Demonstrated with the frozen functions: a dark "rows" red (the bar growing, :29 — the first
   check) + a light "the clock's gaps" red (:55, the last): desk_reds labels both, the sed+tail keeps only the clock.
   Verdict 2's must-fix 1 is closed for session-start (one line a run, items joined with " · ") and open for
   bar-geometry. Fix: every `^bar-geometry (` / `^session-start (` line passed on (drop `tail -n 1`; desk_reds already
   takes a line an item); the stand-in's bar-red made two lines, the new one first → after the replay: offered, held;
   a row in test_update_flow.
3. **lib/update.sh:375 with system/fedokawaii:278-280 — the "red before it" suffix overflows the status row,
   untested.** For a kept update the status's `updated` continuation gets "N packages · the desktop's check was red
   before it, so not judged (Super+U → log)": 82 characters for 96 packages, + the row's 12 → 94 columns into a
   50-column pane (PANE=50, fzf nowrap) and `fedokawaii status` (test_status holds every row ≤ 44) — a cut line (the
   standing rule: fit, or cut at a word); with holds present `${l%% · held: *}` drops the suffix silently — two
   behaviours. No test_status row carries the suffix. Fix: a short fixed status form that fits (e.g. "· desktop: red
   before, not judged"), the sentence in the report's lines 3+ and the log; wording "its items red before it were not
   judged" (with per-item labels the rest IS judged); test_status rows ≤ 44 with the suffix, with and without holds.

### Should-fix
1. tools/vm-inject/update-{button,green}.sh — the SELinux rows cannot tell "no denial" from "no audit log": ausearch
   exits 1 and prints nothing for a missing /var/log/audit/audit.log as for nothing found (ausearch(8) EXIT STATUS), so
   avc.txt is empty either way. Log `systemctl is-active auditd` and the first checkpoint call's status beside avc.txt
   and fail the row when the instrument is absent (auditd is active on this PC; the VM's state is in no kept log).
2. probation.sh ran from 766b434: up_probation_close's new hold line ("kernel" as SOURCE, lib/update.sh:466) is proven
   on the stub only (test_update_flow:309); fail.log shows the old five-field line. Run probation.sh fail from the
   fixed commit before the PC's next kernel-bearing press.
3. update-design §2.5's reason against `dnf5 do --store` ("one wanted package that will not resolve would stop the
   whole update") overlooks `--skip-unavailable` (dnf5-do(8), dnf5-upgrade(8), `dnf5 install --help`); the decision
   can stand, the written reason should meet it.
4. The ledger's R3/E lines must record the 78ea68c green re-run as hung (never "exit N"), and the hang's entry
   (r27-49-hang) the evidence file's path.

## Verdict 3: FAIL
Until must-fix 1–3 are done: 1 with its stub row and the VM proofs green from the fixed commit (update-green ×2,
update-button ×2, one with the reload storm), 2 and 3 with their rows, and the whole suite green on the commit that is
pushed. What stands and need not be redone: Verdict 2's must-fix 3, 4, 5 (proven above) and must-fix 1's session half;
should-fix 1–5 decided and built; (F); probation.sh's two cases; run 7's nine rows; the PC's press of 14:39 up to its
trial's close (B3 still ahead: record the close from fedokawaii-boot-good's journal). The should-fixes decided (done, or
written in the ledger) by the next review.
