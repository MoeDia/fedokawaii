# Round 27 — performance BEFORE (2026-10-27 03:15–03:45, the live PC)

dwl at the time: the r26 build + the crash/hotplug fixes and the frame log (nothing that changes
drawing). Raw outputs: `.claude/notes/perf/before-*.txt`; repeat with the same commands (T60).

| row | number | method (exact command) |
|---|---|---|
| idle CPU | 0.3 % of 12 threads | `bash tools/perf.sh` (30 s /proc/stat) |
| idle GPU | 0 % busy · 3.0 W · VRAM 273 MiB | perf.sh (gpu_busy_percent, hwmon power1_average) |
| idle RAM | 3.0 GiB used, 27.9 GiB available; PSS: steamwebhelper 1068 MiB, steam 219, Xwayland 42, dwl 37, waybar 29 | perf.sh (smaps_rollup) |
| boot | firmware 10.7 · loader 1.9 · kernel 1.7 · initrd 3.5 · userspace 2.6 s; greeter 7.7 s after the kernel; session 0.2 s; shutdown 0.3–4 s (one 18.6 s with stop time-outs, 25 Oct) | `. lib/pace.sh; pace_table 10` |
| frames, terminals | 0 dropped in 20 streaks (634 frames); build p50 55 µs, p99 264, max 668 | perf.sh phase terminal (frame log) |
| frames, switches | 0 dropped in 24 streaks; build p50 68 µs, max 466 | perf.sh phase switch |
| frames, menus | 0 dropped; build p50 62 µs, max 505 | perf.sh phase menus |
| animations (A lines) | right lengths (open 240 ms, switch 236, close 180); ~half the open/close ones skip 1–4 steps (2-refresh gaps); switches alone under load: 540, 0 skipped | `framestat.py --anim` on a live run (live-anim) and on perf-load |
| heavy scene | 0 dropped in 10,305 streak frames (120 s); build p50 80 µs, p99 204, max 567; CPU 1.3 %, GPU 10 %, VRAM 723 MiB, RAM 3.8 GiB, dwl RSS 96 MiB | `bash tools/perf-load.sh` |
| key → glass (dwl's part) | windows/switch/menus p50 8–10 ms, p95 12–25; typing in foot p50 18.6, p95 24, one 165 ms outlier; under load p50 5.3 | perf.sh / perf-load.sh (wtype: no kernel time) |
| new terminal | press → first frame 7–15 ms | perf.sh W lines |
| latency suite | 58 items ok (bar clicks 4–21 ms, panels 4, notices 3, Super+U rows 26, prompt 232, a command's answer 55, theme switch 110, wallpaper 68, OCR 114); FAIL: Brave cold (timed out at 20 s — the measure or Brave: to find), lazygit first frame 1010 ms (limit 400), a recording's first bytes 1209 ms (limit 1000) | `python3 /usr/local/lib/fedokawaii/system/fedokawaii-latency --full` |
| nvim | headless 10 ms (`--startuptime +qa`, no UI); **real terminal to LazyVim's VeryLazy and quit: 148 ms** (10 runs) | `python3 tools/ptytime.py --runs 10 -- nvim -c 'autocmd User VeryLazy ++once …qall!'` |
| TUI apps (pty, ready = nothing drawn for the settle time) | yazi 31 ms · btop 112 ms · lazygit 551 ms in this repo | `tools/ptytime.py --settle 400/2500/800` |
| not measured today | the login → desktop path (needs his password: the greetd trick gives the session start only — "session 0.2 s"); Brave cold (the tool timed out); a bar click with a real pointer (no virtual pointer tool installed: the latency suite clicks through its own path) | — |
