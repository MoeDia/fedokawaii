---
id: backups
title: Snapshots are not backups
part: 1
minutes: 13
---
## idea
A snapshot lives on the disk it protects: if the disk dies, both are gone. A backup lives on another disk, here a USB drive, written by restic. It keeps every version of your files, stores each piece once and encrypts everything with a password of your own, a sentence kept somewhere that is not this disk. Nothing runs by itself: you back up when the drive is plugged in, and a notice reminds you when the last backup is older than the days you set. The drive's name goes in Super+U, settings, as the backup target.

## exercise
Press Super+X for quick settings and look at the backup tile: it shows the age of the last backup. Press Super+U, move to settings, and find the backup target and the reminder days. Read them; change nothing unless you have the drive at hand. With the drive plugged in, choose backup in quick settings and watch the small window and the notice say what was done.

## check
```check
ask: Which setting names the drive that backups go to?
answer: BACKUP_TARGET
proof: grep -q '^BACKUP_TARGET=' fedokawaii.conf
```
