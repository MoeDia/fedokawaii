VERDICT 5: PASS — verdict 4's must-fix closed by removal, should-fix 1 decided by measurement, the PC conditions met where a drive is not needed

Fifth look at T48 (restore / the drive / a file, back): main at ddaeef7 (local), the installed tools 3c3d583 (applied
22:22; the reviewed functions byte-identical between the two, `git diff --stat 3c3d583..ddaeef7` names them). Read-only;
nothing of the owner's session touched; no VM, no apply; the suite on ddaeef7 waited for with a bounded loop (its line at
the end).

What I read and measured
- The diff cf211b8..ddaeef7: bin/kawa-backup (+12: the lock holder's kind), system/fedokawaii (25: status_rows, pause,
  the snapshot list, time_rows), docs/design-system.md (+11: §7 Text, Facts, the window-padding line), test_menu (+24),
  test_backup (+1). At ddaeef7: status_rows 340–346, pause 1047–1057, job_head 1063–1069, snapshots 1154–1198, time_rows
  1202–1215, as_it_was 1216–1219, file_back 1224–1269, backup_back 1270–1322, backup_drive 1323–1328, drive_rows
  919–945; kawa-backup ready 147–174, restore 291–308, backup_times, mount_ro 316–321, drive 322–336; kawa-pick's back
  mode 98–101 and kawa-pick.yazi/main.lua 10–30; the ledger r27-52-restore-master, r27-52-restore-sf, r27-52-R4-sf1,
  r27-52-pc; plan.md:330 (T22's note). The working tree's uncommitted to-do removal (`git diff system/fedokawaii`):
  the learning tab's entry and the launch list only — none of the functions above.
- The renders (/dev/shm/r27/master/T48-5/, the kit, both moods, after; and before-*), measured with tools/px.py boxes
  grouped per text row (my script T48-5/_measure.py): the restore list — the heading's icon ink x 27, the three rows'
  icons x 35, the days' last ink x 793 = the rule's end (113 + 680), the paragraph x 25; the result — the paragraph x 25,
  the copied item x 34 (cell 33 plus the glyph's bearing), the ✓ x 35, the key line x 25. Every band identical dark/light
  (y 33–45, 73–88, 93–108, 113–125, 152–168, 172–209; 72–88, 113–125, 152–165, 189–209). Before: the rows' icons x 27
  under the heading's, the ✓ x 27. Super+U (/dev/shm/r27/audit/sys-crop.png): the tab's icon x 27, the rows' icons x 35,
  the selected row's fill from x 17, the pane's facts x 425–426 under the heading's name. So the job windows now sit on
  Super+U's grid, and §7's new words (column 0 = x 25, rows x 33, the cursor's column x 17) are the pixels.
- The PC (r27-52-pc; scripts and outputs T48-pc/): fileback.sh drove the installed `fedokawaii --run file` in a pty
  against HIS home and /home's snapshot 12 — the dialog found search-ui.html, the copy in ~/Restored/2026-11-01-222608
  is byte-identical to the snapshot's (`cmp`), its date kept, removed after, ~/Restored gone (it did not exist before).
  restore.sh take: a throw-away home and a folder target (never his home — right), two real backups; /proc/mounts shows
  "restic:… /run/user/1000/fedokawaii-backup.zetFqS fuse ro" at 4, 6 and 8 s while the dialog was open; Documents/notes.md
  taken with the newest backup's text; after: 0 mounts, no fedokawaii-backup.*/fedokawaii-back.* folder. restore.sh
  hangup: the pty hung up at 9 s with the mount open (6, 8 s) — rc 129, nothing left. Both "take" runs ended by pty_run's
  timeout (rc 124: the 'x' key was sent at a fixed time, before the outcome row) — the "any key" close is the kit's and
  test_menu's (rows 350–357), not exercised on the PC; the copies and the tear-down are. `fedokawaii verify` after the
  apply: 261/262, the one red his qbittorrent outside the manifest (T35's, in the baseline before the apply:
  /var/lib/fedokawaii/last-verify-fails) — not T48's.

What holds (proven)
- Must-fix 1 (restic's enterDir/leaveDir): closed by taking the in-place restore out — kawa-backup has no `everything`
  (test_backup:53 asserts rc 2 for the word), backup_back's comment 1272–1275 keeps the reason, test_menu:503–504 asserts
  it is not offered and no "in place" is said, the pane says "copied into ~/Restored … never over what is there" (546).
  The proportionate answer: the one promise the owner set ("nothing of his may be removed by this button") is kept by
  not having the button; the safe form is written in the ledger for when it is wanted.
- Should-fix 1: decided by measurement, built, tested — `aligned` asserts one cell in (377–383), the columns row (355–359:
  the facts +3, the outcome +1, the key line +0 from the heading). Numbers above.
- Should-fix 2: file_back 1262–1265 and backup_back 1316–1318 (`whole`: "the whole home is not taken in one go — mark its
  folders (space), then enter"); row 508–509.
- Should-fix 3: backup_back 1309 — restic still alive after the loop → "did not open within two minutes (a slow drive?) —
  try again"; dead → its first stderr line; the one number is the loop's (1200 × 0.1 s).
- Should-fix 4: row 519–523 — the restore under pty_run --hangup while the dialog shows → fusermount3 -uz called, no
  folder left; and on the PC with the real restic (above).
- Should-fix 5: time_rows 1208–1210 — a day outside this year says its year; row 510–512.
- Should-fix 6: moot (everything gone). Should-fix 7: kawa-backup 165–172 — the lock holder writes its kind, opened to
  append; mount_ro sets LOCK_KIND=restore; the words "the backup is open for a restore (Super+U → restore) — close that
  window first"; test_backup:250 inside the real FUSE mount (223/0 in the suite).
- Should-fix 8: file_back 1232 (no folder → "no snapshots of your files yet — one is taken every hour"), 1233 (there but
  not enterable → repair); rows 458–459. Should-fix 9: backup_back 1292–1294 (compared as words, "08" no longer bash's
  error), row 505–507; drive_rows 923 ("kawa-backup is missing — repair"). Should-fix 10: r27-52-pc says what the PC
  proved and what it could not.
- Over-engineering: none — 25 lines in the menu, 12 in kawa-backup, the test tooling already there.

Must-fix
None.

Should-fix
1. The flow's middle screen is on the other grid: kawa-pick's yazi dialog draws its heading at x 17 and its rows at x 25
   while the window before and after it draw at 25/33 — the heading jumps one cell left when the dialog opens and back
   when it closes. Owned by T22 (plan.md:330 commits yazi's whole grid to column 0 = x 25); keep it there and measure
   it with px.py when yazi is rebuilt — the one grammar fault left in this flow.
2. The back mode's q with marks takes the folder you are in, not the marks (main's own finding in r27-52-pc): kawa-pick
   98–101 fills `keep` from the marks only when yazi hands them (Enter); q quits with the cwd file and the marks are lost.
   Harmless (into ~/Restored, nothing overwritten) but more than asked. Two lines in kawa-pick.yazi/main.lua: on q with
   `#tab.selected > 0`, emit "open" (the marks) instead of quit — with a row in test_pick. T22's, or now.
3. The next PC run of a job window should send its closing key on seeing "any key" (pty_run after a match, or later), so
   the close path is exercised on the PC too — the two runs here ended by the timeout, not by the key. Nit.
4. Still owed, hardware permitting: the drive's pane and row with a real USB label (`fedokawaii --explain drive`, the row's
   value, `kawa-backup drive` with a plugged drive) — two minutes when one is plugged in; the ledger says so already.

## Verdict: PASS
The data-safety hole of verdict 4 is gone with the button that had it; the lists, the dialog, the copies, the mount and its
tear-down, the drive's states and the job windows' grid are built, tested (test_menu's new rows, test_backup 223/0 with the
real restic) and run once for real on this PC — a file back from his own snapshot, a file from a real backup through a real
FUSE mount, a window closed on an open mount, nothing left behind. What is left is one grid fault inside T22's yazi rebuild
and a check that needs a drive plugged in.

Test line: test_update_flow 341/0, test_backup 223/0, test_status 216/0 in the suite on ddaeef7 (/dev/shm/r27p/
suite-ddaeef7.log lines 82, 6, 54); engine/test_menu 738 passed, 0 failed (line 46; menus/test_menu 84/0, line 109); the
suite's end, read by me at 23:12: "✔ all 128 test files passed", "== suite rc=0 in 2808 s".
