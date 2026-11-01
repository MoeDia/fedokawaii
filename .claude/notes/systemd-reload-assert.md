# Draft upstream report — systemd PID 1 aborts on a Reload() while an earlier reload's reply is pending

Status: DRAFT for the owner (not posted: an upstream report is outward-facing). Found 1 Nov 2026 (ledger
r27-49-pid1, r27-49-storm3); evidence /dev/shm/r27/master/T45-5/storm-3-pid1-crash.txt (gone after a reboot:
the facts are below).

**Where:** github.com/systemd/systemd/issues (searched 1 Nov: `gh search issues --repo systemd/systemd
"pending_reload_message"` and "method_reload assertion" — nothing; #43001 is a different reload bug).

---

**Title:** PID 1 aborts in method_reload() when a Reload() arrives while a previous reload's reply is pending

**systemd version:** 259.10 (Fedora 44, systemd-259.10-1.fc44.x86_64). The same two asserts are in v262's
src/core/dbus-manager.c.

**What happens:** during a `dnf` transaction whose scriptlets run `systemctl daemon-reload`, a second client
calling `systemctl daemon-reload` (a loop, one call every 0.2 s, waiting for each) makes PID 1 abort:

```
19:21:00.432625 systemd[1]: Reload requested from client PID 87332 ('systemctl') (unit fedokawaii-dnf-…service)...
19:21:00.432639 systemd[1]: Reloading...
19:21:00.566662 systemd[1]: Reloading finished in 133 ms.
19:21:00.583782 systemd[1]: Reload requested from client PID 87412 ('systemctl') (unit session-8.scope)...
19:21:00.584322 systemd[1]: Caught <ABRT>, from our own process.
19:21:00.650995 systemd[1]: Caught <ABRT>, dumped core as pid 87416.
19:21:00.651009 systemd[1]: Freezing execution.
```

Stack (coredumpctl info): `__assert_fail ← method_reload.lto_priv.0.cold (libsystemd-core-259.10) ←
object_find_and_run ← bus_process_object ← bus_process_internal ← io_callback ← source_dispatch ←
sd_event_dispatch ← sd_event_run ← manager_loop ← main`.

method_reload() asserts `!m->pending_reload_message_dbus` and `!m->pending_reload_message_vl`; a Reload that
arrives before the earlier one's reply has been sent hits them. Seen twice in two runs in a VM (once with
systemd itself in the transaction, once without). The machine is then frozen until a hard reset (no new
sessions: PAM → logind → PID 1).

**Expected:** a second Reload() while one is pending is queued (or answered with an error such as
EBUSY / -EAGAIN), never an abort of PID 1.

**Reproducer:** a transaction that reloads (any package with unit files) while another shell runs
`while :; do systemctl daemon-reload; sleep 0.2; done`.
