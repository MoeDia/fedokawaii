VERDICT: FAIL — one data-safety hole in "restore → a → yes"; the rest stands (PASS once must-fix 1 is closed with its tests)

Fourth look at T48: Super+U's two new "as you" features — **a file, back** (79cd435) and **restore / the drive**
(2074718) — read at main's HEAD (84b02bc; the reviewed files unchanged there and at f09860c, checked with
`git diff --stat`). Read-only; the throw-away checkout /dev/shm/r27w-t48review (removed at the end) ran the
three test files; nothing of the owner's session touched; no VM, no apply.

What I read and ran
- system/fedokawaii: rows (720–757), section_of/icon_of, explain's pane for file/restore/drive and drive_rows
  (887–1027), job_head/JOBS/run (1064–1131), time_rows, as_it_was, need_files, file_back, backup_back,
  backup_drive (1203–1331). bin/kawa-backup whole (times, mount_ro, everything, drive, pick_target, ready/
  open_repo/probe, the lock). configs/home/.config/fedokawaii/files.sh (free_name's dir form, restored_dir,
  restore_into). bin/kawa-pick (the back mode, 98–101), yazi-pick/kawa-pick.yazi/main.lua, keymap.toml,
  yazi/init.lua 166–227. setup.sh snapper_configs/snapper_limits (2160–2185), verify.sh 686–690,
  lib/manifest.sh 166, PACKAGES.md, the Learn rows, tools/kit-keys.py and kit.sh's --tui-wait, the tests
  (test_backup 239–259, test_menu 405–536, test_pick 137–148), the ledger rows r27-52-file and r27-52-restore.
- Ran from the checkout (PATH with ~/.local/bin): tests/menus/test_pick.sh 101 passed/0 failed;
  tests/content/test_backup.sh 228/0 with the REAL restic 0.19.1 — the FUSE case ran (no "skipped" line;
  /dev/fuse and the setuid fusermount3 of fuse3-3.18.3 are on this PC); tests/engine/test_menu.sh: see the
  line at the end. bash -n: ok on the four scripts; shellcheck 0.11.0 -x: no warnings, only the file's old
  info notes (SC2015/SC2031 — 1289 and 1312 are of that kind, harmless).
- Facts from the sources: `restic restore --help` line 41 (`--overwrite … never`), `restic mount --help`
  (default path templates "ids/%i" …: the design's ids/ID/<absolute path> is restic's own layout, and
  test_backup reads `$m/ids/$id$HOME/Documents/report.ods` through a real mount); restic v0.19.1
  internal/restorer/restorer.go (raw.githubusercontent.com, 776 lines): ensureDir 323–342, enterDir
  376–382, leaveDir 466–482, restoreNodeMetadataTo 295–305, shouldOverwrite 588–610; cmd/restic/cleanup.go
  19 (`signal.Notify(ch, syscall.SIGINT, syscall.SIGTERM)` — no SIGHUP); snapper(8) PERMISSIONS ("The
  .snapshots directory must be owned by root and must not be writable by anybody else"); snapper-configs(5)
  ALLOW_USERS/ALLOW_GROUPS/SYNC_ACL.
- The PC (read-only): /home is its own subvolume (`subvol=/home`); /home/.snapshots root:dia 0750 with 9
  snapshots; snapshot 10's info.xml root 0644 (its date in UTC, "16:00:02" = 20:00 here), `snapshot/dia`
  0700 dia and listable by dia — and snapper made that snapshot at 20:00, after the chgrp of 17:53
  (r27-49-apply6), so snapper lives with the group; /etc/snapper/configs/home: ALLOW_USERS="",
  ALLOW_GROUPS="", SYNC_ACL="no" (nothing lets a process of his delete a snapshot — right).
  /run/user/1000 is tmpfs (a FUSE mount inside it is fine: the portal's doc mount lives there already);
  /etc/fuse.conf has no user_allow_other and none is needed (no --allow-other). NOTHING OF 2074718 IS ON
  THE PC YET: the installed ~/.local/bin/kawa-backup (27 Oct) has no times/mount/everything/drive, the
  installed menu has no backup_back, and `kawa-backup status` says "not set up" (no BACKUP_TARGET).
- The renders measured (PIL, /dev/shm/r27/master/T48-4): dark-1-win: heading ink from x=27, rows' icons
  from x=27, the day's last ink x=792 = the rule's last ink x=792 (fileback-dark-list the same); the words
  from x=25; dark-4b-win: the file line from x=34; dark-2-win: "enter"/"a" from x=26/25; the dialog
  (dark-3-win, fileback-dark-dialog): heading from x=19, keys from x=34. The pane: heading x=403, text
  x=425, every `say` line ≤ 45 characters (counted), the drive's pieces ≤ 50 (tested).
- Two things I reproduced myself, since no test covers them: (a) the hang-up — a pty running the exact
  trap structure of backup_back (EXIT trap, `trap 'exit 129' HUP`, a background sleep for restic, a
  foreground sleep for the dialog), the master closed as foot closes a window: bash ended 0.05 s later,
  the EXIT trap ran, the restic stand-in was already gone (SIGHUP reaches the whole foreground group),
  `wait` returned; (b) yazi 26.x in a pty, SIGHUP sent: it ended in 1.05 s (exit 1). restic itself
  catches only INT/TERM (cleanup.go:19), so on HUP it ends at once and the kernel drops the FUSE
  connection; `fusermount3 -uz` then unmounts the dead mount and `rmdir` the folder. So "closed while a
  backup is open → nothing left behind" holds — proven here, not by the suite (should-fix 4).

What holds (proven)
- a file, back: the list is read as him (no password; the group, never ALLOW_USERS), newest first, one
  `date -f` for all dates, a bad number/9-without-a-snapshot/outside-the-snapshot answer = nothing taken,
  the copies land in ~/Restored/DATE-TIME (a second in the same second .2), reflinked where the disk
  allows, "name (1).ext" beside a second of one name, never over anything (restore_into only ever writes
  into the fresh folder); the snapshot is a read-only subvolume, nothing can write into it. The job
  window's dialog is kawa-pick's yazi with a back mode whose Enter enters folders and Esc first undoes
  marks/filter (main.lua), q takes the folder (cwd-file) — tested with the fake yazi, rendered with the
  real one.
- restore: `kawa-backup times` is open_repo'd (the drive opened when closed, "not plugged in" said, the
  lock respected), `mount` is restic's own read-only FUSE in a private folder under $XDG_RUNTIME_DIR, the
  wait loop ends on the id's folder or on restic's death (its first stderr line shown), the pick inside is
  the same back mode, the subshell's EXIT trap unmounts/waits/removes on every exit path (cancelled,
  nothing taken, could not open, error, HUP, TERM); test_backup proves times (newest first, 3 of 3), a
  real mount (a file read inside, a write refused, restic ends 0 at the unmount, not mounted after),
  everything (the missing folder back, his changed file kept), drive's six states without opening a drive.
- the drive: the row's value is the last part of a path/address only when ≤ 23 columns, else empty (no
  hard cut by fzf any more); the pane pieces a long name at spaces, / and : and never cuts; the states
  (open · plugged · out · address · none) are kawa-backup's and "not plugged in"/"none chosen yet" are in
  vermilion; Enter is kawa-backup's own picker (exit 4 = nothing, as `pause` reads it).
- Over-engineering: none. time_rows/as_it_was/restored_dir/restore_into are shared by three callers (one
  implementation each), kit-keys.py is 74 lines of test tooling, drive_rows' piece-splitting is the
  owner's "never cut" rule and nothing more. fuse3 is the one package the mount needs (restic's docs:
  fusermount3). No "…" anywhere.

────────────────────────────────────────────────────────────────────────────────────────────────
Must-fix
────────────────────────────────────────────────────────────────────────────────────────────────
1. MAJOR — "all of it back in place" can delete files of his and rewrites every folder he has, while the
   screen promises "nothing you have now is changed".
   Where: bin/kawa-backup:323 `r restore "$id:$path" --target "$HOME" --overwrite never`; system/fedokawaii
   1296–1300 (the confirmation).
   Why (restic v0.19.1, internal/restorer/restorer.go, read at the tag): `--overwrite never` only governs
   files and other leaf nodes (shouldOverwrite 588–610, used by withOverwriteCheck). Directories go
   through enterDir → ensureDir (376–382, 323–342), which, whatever the overwrite mode, does
   `fs.Lstat(target)`; `if err == nil && !fi.IsDir() { fs.Remove(target) }` ("try to cleanup unexpected
   file") and then MkdirAll. So wherever the backup holds a FOLDER and he now has a FILE or a SYMLINK of
   that name (a note that became a folder or the reverse, ~/Pictures turned into a link to another drive,
   a stand-in file), restic deletes his file/link silently and puts the backup's folder there. Then
   leaveDir (466–482) calls restoreNodeMetadataTo → fs.NodeRestoreMetadata on EVERY selected directory
   (traverseTreeInner 254–261: "selected for restore or any child restored"), with no overwrite check:
   the mode, mtime (and xattrs) of every folder he has — ~/Documents, ~/.ssh, ~/.config … — become the
   backup's. Neither is covered by test_backup's "everything" case (it only checks a missing folder
   returns and a changed file stays).
   Fix (small, in kawa-backup `everything`, plus the words):
   (a) before the restore, list the backup's directories (`restic ls --json ID` → the nodes with
       "type":"dir", or `restic ls ID` filtered) and test each path in his home: `[[ -e || -L ]] && ! -d`
       → refuse with those paths named ("~/notes is a file now; the backup has a folder of that name —
       move it aside first"), or exclude them (`--exclude`) and say what was left as his; exit without
       running restic when refusing. Nothing of his may be removed by this button, ever.
   (b) the confirmation says what is true: which backup ("the backup of yesterday at 21:00" — `m` is
       computed at 1290 and never used on the `a` path), that missing files come back (deleted ones too,
       as now), that files he has are kept, AND that his folders' dates and permissions become the
       backup's (or avoid that — there is no restic flag for it; honesty is the proportionate answer).
   (c) tests with the real restic in test_backup: a file where the backup has a folder → refused (or
       excluded) and named, the file still there byte for byte; a symlink the same; test_menu: the words
       (the backup named, the folders' sentence). A ledger line that this came from restic's source, with
       the line numbers, as the owner's "never from memory" rule asks.

────────────────────────────────────────────────────────────────────────────────────────────────
Should-fix (same pass, before the PC)
────────────────────────────────────────────────────────────────────────────────────────────────
1. Design, §7/§3, one cell: in the job window the heading's icon sits at content column 1 (x=25: the
   hairline, foot's 8 px, the margin cell, then one more) — job_head prints `'\n  %s'` and `pause` the
   same two spaces — while §7 puts a heading at column 0 and the dialog of the very same flow draws its
   heading at column 0 (x=17, measured). The rows' icons at column 1 (x=25) are where §7 wants rows, but
   they then stand UNDER the heading's icon instead of one cell in (§3 "indent: a heading's rows start one
   cell further in than the heading"); the result screen's file lines (x=33, restore_into's three spaces)
   are one cell in, so the three screens of one flow use two grammars. test_menu's `aligned` helper (374–
   379) asserts "the icon under the heading's" — it encodes the deviation and must change with the fix.
   Decide once (job_head/pause one space less, or §7 amended for job windows — and then the dialog's
   heading moved to match), re-render both moods, re-measure.
2. `q` at the top of the snapshot/backup ("~", the home itself) answers `$snap`, which the filter
   `"$snap"/*` (1263, 1319) rejects → "nothing taken" for a deliberate choice. Say it ("the whole home is
   not taken in one go — mark its folders") or take it; test it.
3. The two-minute cap (1314): when restic is still reading the index the screen says "the backup could
   not be opened: " with nothing after the colon (why is empty). Say "it did not open within two minutes
   (a slow drive): try again", and make the one number the message's.
4. A regression test for the closed window: in test_menu's harness, the restore run under a pty, SIGHUP
   to its process group (or the pty closed) while the stub mount is "open" → fusermount3 called, no
   fedokawaii-backup.* / fedokawaii-back.* left. I proved the mechanism (above); the suite should keep it.
5. time_rows (1212) prints "26 Oct" with no year; backups live twelve months (prune keeps 12 monthly), so
   a backup of last October reads as this October's. Add the year when it is not this year's; same for
   as_it_was. (Snapshots never reach that age; the shared helper does.)
6. `kawa-backup everything` streams restic's raw words ("restoring snapshot … to /home/dia", the summary)
   unindented into the job window, where `restore` (296) filters and indents. Same treatment.
7. While a backup is open for a restore its kawa-backup holds the backup lock (fd 8 inherited by restic),
   so "back up now" says "a backup is running already — wait for its notice": true in effect, wrong in
   words. A second lock message for the open restore, or one wording that covers both.
8. file_back (1235): when /home/.snapshots does not exist at all (a system before the split, a fresh
   install's first hour) it says "cannot be read here — fedokawaii repair lets you read them": repair
   would change nothing. "no snapshots of your files yet — one is taken every hour" when the folder is
   absent; the present wording only when it exists and cannot be entered.
9. Small: `((ans >= 1 …))` at 1289 with "08" typed prints bash's "value too great for base" line before
   "no backup 08 in the list" (compare as strings, as file_back does); drive_rows reads a missing
   kawa-backup as "none chosen yet" (924: `|| st=none`) — say the tool is missing, as the rows do.
10. The ledger: r27-52-restore reads as built and tested, which is true; add that it is NOT on the PC
    and that the PC has no backup target yet, so the first real run is still owed (conditions below).

Nits (no action needed unless passing by)
- backup_times sorts RFC 3339 strings lexically (`sort_by(.time)`): right for one time zone, which is
  this PC's case; `fromdate` would be exact across zones (restic's times carry fractions: use sub(…)).
- restore_into's long paths wrap in the 100-column window (never cut: allowed); the dialog's parent column
  shows the mount's parent folder at the root ("dia"/"home") — one level of the FUSE path shows, harmless.
- The drive's pane for a path target shows the repository folder's own name ("fedokawaii-backup") as the
  path's last piece — true, if a little technical.

What the proof does not cover (say so in the ledger)
- Nothing on the PC: the real session's FUSE mount in /run/user/1000 under the live foot, a real USB label
  in the drive's pane and row, kawa-backup's picker with root's password in the job window, the closed
  window with a real yazi and a real restic — all VM/kit/stub-proven only until `apply` and one real run.
- A restore while snapper's hourly cleanup removes the very snapshot being browsed (the copy says "not all
  of it: No such file" — fine, unproven).

Conditions (on must-fix 1 closed, the verdict turns to PASS WITH these)
- Must-fix 1 (a)(b)(c) with test_backup and test_menu green; should-fix 1–4 at least decided (1 and 4 built).
- Then `apply` on the PC and, with a target set (a folder is enough: `BACKUP_TARGET=/path`), one real pass of
  each: a file back from a snapshot; restore → a file from a backup (the mount seen in /proc/mounts while
  the dialog is open, gone after); restore → a → yes against a home holding one file where the backup has
  a folder (refused and named, nothing removed); the window closed mid-dialog (no fedokawaii-backup.* in
  /run/user/1000 after); the drive pane/row with the real label; `fedokawaii verify` green — each with the
  commands' output in the ledger, as the earlier T48 rows have.

## Verdict: FAIL
Until must-fix 1 is closed, the one button that promises "nothing you have now is changed" can remove a file
or a link of his (restic v0.19.1 restorer.go:332–336) and rewrites every folder's dates and permissions
(466–482) — the owner's hard rule for this feature. Everything else of the two commits — the lists, the
dialog, the copies, the mount and its tear-down, the drive, the tests, the renders — is sound and proven as
written above, so the fix is one function and its words, and the PASS WITH CONDITIONS above is a short step.

Test line: test_pick 101/0 and test_backup 228/0 (real restic, FUSE) from my checkout; test_menu 727 passed/0
failed in the background suite on a6f5049 (/dev/shm/r27p/suite-a6f5049.log line 45 — the reviewed files are
byte-identical there and at HEAD); my own test_menu run from the checkout was still going when this was
written; it ended as the review closed: test_menu 727 passed, 0 failed, exit 0 (the same figure).
