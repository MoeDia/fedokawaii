---
id: claude-tools-projects
title: projects
part: ai
chapter: 71
minutes: 150
needs: [claude-tools-practice]
optional: yes
---

**71.5 ★★★ The reviewer.** Create the subagent of 71.4. Make a change with a deliberate bug, then
ask: *"use the reviewer subagent on the current diff"*.

*You should see:* the bug found, with file and line.

<!-- solution 71.5 -->
over the limit" — the reviewer reports something like: *"budget.py:41 — the warning misses the
case total == limit; PLAN.md says 'at or over'. Use >=, and add a test for exactly the limit."*
Note what it did *not* report: style. That is the description's "only what affects
correctness" at work.
<!-- /solution -->

**71.6 ★★★★ A morning report.** A script `~/.local/bin/morning` that pipes the last day's
`journalctl -p warning`, `dnf check-update` and `git -C ~/repos/fedokawaii status -s` into
`claude -p`, asking for a ten-line summary of what needs you today. Run it from a systemd user
timer at 09:00 and send the result with `notify-send`.

*You should see:* a notice each morning with ten short lines.

<!-- solution 71.6 -->
```sh
#!/bin/bash
# morning — what needs me today, in ten lines
set -u
{
  echo "## warnings since yesterday"; journalctl --since yesterday -p warning --no-pager -q | tail -n 200
  echo "## updates";                  dnf -q check-update 2>/dev/null | head -n 50
  echo "## repository";               git -C ~/repos/fedokawaii status -s | head -n 30
} | claude -p "Summarise what needs my attention today in at most ten short lines, \
most important first. Plain text, no preamble." > "$XDG_RUNTIME_DIR/morning.txt" \
  && notify-send -a morning "早 · morning" "$(cat "$XDG_RUNTIME_DIR/morning.txt")"
```

and a timer, `~/.config/systemd/user/morning.timer` with `OnCalendar=*-*-* 09:00` and
`Persistent=true`, beside a `morning.service` whose `ExecStart=%h/.local/bin/morning`;
then `systemctl --user enable --now morning.timer`.
<!-- /solution -->
