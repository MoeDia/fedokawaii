VERDICT: PASS

The master's review of T29s (Syncplay and its mpv close as one), 2026-11-03 02:10, at 5773f71.
Reviewed: src/syncplay/syncplay.patch (fixes 3–6) line by line against upstream v1.7.6's own code in
/dev/shm/r27/t29s/src/s (client.start/stop, the retry policy, protocols.connectionLost, players/mpv.py
drop/stop_client/actuallySendLine and the listener, the vendored UnixSocket.run/MPVProcess/MPV._quit_callback/
terminate, consoleUI.run/promptFor, utils.getRuntimeDir's atexit cleanup, ui/__init__'s daemon console thread,
twisted 25.5's signal handling); bin/kawa-together; tests/yazi/test_syncplay.sh and syncplay_pair.py (the
B023 fix of 1292bb7 included); the evidence folder. The clone's diff is byte-identical to the repo's patch,
and the patch applies cleanly on a pristine v1.7.6 checkout (git apply --check). My own evidence, all under
/dev/shm/r27/master/T29s/own/ (an own runtime dir, a dead session bus, no WAYLAND/DISPLAY; only pids I
started were ever signalled): (1) logs/probe-1.log, probe-4.log — the patched copy in a pty against my own
server on 8911 with an observer in the room, 17 runs over 16 ways of ending: mpv's quit, q, SIGSEGV, SIGABRT,
SIGBUS, SIGKILL, SIGTERM, SIGINT, SIGHUP to mpv; Ctrl+C, SIGHUP (the window closed), SIGTERM to Syncplay; a
next file in the same mpv; the server gone then mpv closed. Every one: Syncplay and mpv both ended in
0.01–0.45 s (the 0.45 s are the core-dumping crashes), the room heard the leave at 0.00–0.34 s, nothing
printed after the action (Ctrl+C: its own "^C"), exactly one notice for SEGV/ABRT/BUS/KILL ("T  the film
stopped" / "mpv crashed (segmentation fault|aborted|bus error|killed): you left the room") and none for quit,
q, TERM, INT, HUP, Ctrl+C or the window closed; loadfile closed nothing (both alive 3 s later). (2) logs/
probe-2.log, probe-3.log — the server unreachable: the patched copy, like the installed one, holds the window
on "ERROR: Connection with server failed / Press enter to exit" (promptFor blocks the reactor before the
delayed reactor.stop), so the error stays readable: no regression there; the server gone for good retries
as upstream does (RECONNECT_RETRIES 999) and mpv closed meanwhile ends both in 0.11 s, quietly. (3) kit/
result.log — the fenced kit (tools/hl-dwl.sh, pid 1 = dwl inside) with my own copies, 2 runs each of Super+Q
on mpv, q, kill -9, Super+Q on Syncplay's foot: 8/8 both windows gone (0.16 s after the key, 0.15 s after
the kill, 0.06 s after the window's close), ps inside shows only server + observer, the leave heard 8/8 —
the same numbers as the evidence's 40/40. (4) logs/pair.log — the repository's own syncplay_pair.py run end to
end against my copy (a template home with the desktop's mpv config and icons.sh/screen.sh, ffmpeg films):
53 checks passed, 0 failed, the four closing cases included — joining, ready, pause, seek, chat, a differing
file, the room's next file, a server restart all still work, so no regression for normal use. The notice
follows the desktop's grammar (icon, two spaces, a lowercase title; a plain body; -a together gets mako's
5 s default) and only real crashes send it (exit 0/4 and TERM/HUP/INT excluded; exit 1–3 cannot reach
stop_client with idle=yes/keep-open=always). shellcheck -S style clean on kawa-together. The tests are
honest: the pty is read, the leave is read from bob's log, the notice from a stand-in notify-send, the
closing cases are skipped with a clear line (not passed) while the installed copy carries the older patch.

## MUST-FIX
none

## SHOULD-FIX
1. A folder left in $XDG_RUNTIME_DIR per session — syncplay/ep_client.py's os._exit(0) skips the atexit
   cleanup of utils.getRuntimeDir()'s TemporaryDirectory (syncplay-xxxxxxxx, holding mpv-socket).
   Evidence: 1 new syncplay-* folder after every one of my 17+ runs (probe logs: "new syncplay-* folders
   left: 1"); own/run has 17, the agent's /dev/shm/r27/t29s/own/run has 80 (23 still holding mpv-socket);
   the live /run/user/1000 has one from 2 Nov 18:32 (the old copy, the window closed). When Syncplay itself
   dies by a signal (the window closed = SIGHUP, or SIGTERM) the socket file stays inside too (probe-4: hup
   and term-sync). Why: the owner's "not a single file out of place, no leftovers anywhere"; it piles up
   over an uptime (tmpfs, one empty dir a session). Direction: before os._exit run the cleanup —
   `atexit._run_exitfuncs()` or `shutil.rmtree(getattr(getRuntimeDir, "cachedPath", None), ignore_errors=True)`
   in main() (and in stop() for the signal path: a SIGHUP/SIGTERM handler that does
   reactor.callFromThread(reactor.stop) so the window's close goes through the same stop — mind that
   stdout is gone then: nothing may print); assert in syncplay_pair.py that glob(RUN+"/syncplay-*") is
   unchanged after each closing case.
2. _sayCrash's once-only guard is a check-then-set across two threads: stop_client runs on the socket
   thread (quit_callback) and, within the next 0.1 s status ask, on the reactor thread
   (actuallySendLine's except → stop_client) — the ledger's own "two notices in the first run" shows both
   paths fire on one crash. The window between getattr(_crashSeen) and the assignment is a few
   bytecodes, so it is rare, not impossible. Direction: a threading.Lock around the check and set (or
   set _crashSeen under the listener's existing lock), two lines.

## NITS
1. _sayCrash's proc.wait(timeout=1) can run on the reactor thread (the actuallySendLine path) and hold the
   reactor up to 1 s if mpv is still alive when its socket died — only at the end anyway; poll() first,
   wait only on the socket thread, if it is ever touched again.
2. The Learn book's §16 Syncplay paragraph says nothing wrong but could say "close either window and both
   end; mpv crashing says so" — for the book pass on the owner's word.
3. The exploratory rounds logs' "stray mpv" counted every mpv of the user without --input-ipc-server=/run/user,
   i.e. the owner's own plain players too (hence "stray mpv=2"); the final kit evidence is clean, but that
   counter must not be reused.
4. A real lost connection (the server gone) still prints twisted's three ERROR lines
   ("<class 'twisted.python.failure.Failure'>…") in upstream's voice; the patch rightly limits the quiet to
   our own stop — a tidy-up for another task, not this one.
5. Closing Syncplay's window ends it by SIGHUP's default action: the room learns of the leave from the
   kernel's TCP close, not from a stop of Syncplay's — the same on the wire (0.00 s in my probes); SHOULD-FIX 1's
   handler would make every path one.

## The live check after the apply
- `head -c 200 ~/.local/share/fedokawaii/upstream/syncplay` equals syncplay_pin (993232ab…+ the patch's
  sha12) and ~/.local/share/fedokawaii/syncplay/syncplay/ep_client.py carries the os._exit; `fedokawaii
  verify` green on its Syncplay checks.
- `bash tests/yazi/test_syncplay.sh`: no "skipped: closing as one" line, 143 passed, 0 failed.
- On the live desktop with a second client in the room (a friend, or tests' observer.py against the same
  server): Super+Q on Syncplay's mpv → both windows gone within 0.2 s, no "terminated", no press-a-key,
  the other client's log says "<name> has left"; q in mpv the same; Super+Q on Syncplay's window → mpv gone
  with it; `kill -SEGV` of that mpv → exactly one notice, "<together icon>  the film stopped" over
  "mpv crashed (segmentation fault): you left the room", in the notice panel at the top right, nothing else;
  `ps -u dia -o comm | grep -c '^mpv$'` and the count of python3 syncplay processes unchanged after each.
- `ls -d /run/user/1000/syncplay-*` before and after a session: unchanged once SHOULD-FIX 1 is in.
