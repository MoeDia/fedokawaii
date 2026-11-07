# round 28 pulse · Sat 07 21:45 (Dubai)

pace: 158/228 done (69%) · time used 45% · ahead 24.0 h · ETA Sun 08 15:47 · left 63 · blocked 0 · owner 7
alerts: usage limit hit 5× (last 2026-11-07T12:09 UTC); 3 errors in 2 h
run: conductor active · passes 1 (oldest 8 min) · last activity 1 min ago · commits since start 183 · hold False
machine: load 1.10 0.66 0.55/12 · mem free 18.2 GB · disk free 610 GB · up 45.5 h · cpu tccd1 50° · cpu tctl 54° · gpu edge 43° · gpu junction 35° · gpu mem 56° · ssd composite 39° · ssd sensor 1 39° · ssd sensor 2 41°
dark: True (active) · pulse timer active
tokens since start: out 3,014,326 · in 7,176 · cache write 10,936,148 · cache read 232,987,496 · msgs 3491 · out last 6 h 675,078
out by model: last 6 h claude-opus-5-5 574,057 · claude-sonnet-5-5 83,583 · claude-haiku-5-5 17,438 · since start claude-opus-5-5 2,548,235 · claude-sonnet-5-5 402,048 · claude-haiku-5-5 64,043

## now / blocked / owner
- [now] dsun2 daily (S11/S13/S14): suite + clean-install VM, only on Sun 8 Dubai time, skipped if the last daily passed under 12 h ago with no system-level change since; VM as its own background unit — S13,S14; not before its own day (Dubai date): until then the next row is the first todo dated today or earlier
- [owner] c1b his eyes on the cooler's display with the PC dark: no 99 (S6) — only he can see it; assumed: dark. If it still blinks: the steady real temperature instead (S6)
- [owner] o01 his picks on the options pack, relayed by Claude; each pick built, the others dropped — assumed meanwhile: my strongest, each in r28-questionnaire.md part A
- [owner] o02 the RAM: restart, Delete, F7, OC, DRAM Frequency DDR5-4800, F10; then ram-check three copies for 20 minutes — still 5600 MT/s on 6 Nov; wrong bits measured, ledger r27-note-flips-2; say it before he installs anything built here
- [owner] o03 Phase E: his answers to the questionnaire applied: the last edit of the repo — then the ISO again
- [owner] o04 the ISO installed on his PC: fedokawaii lives there on Fedora 45, self-maintaining until Fedora 46 — the VM cannot show his firmware: the rehearsal first
- [owner] o05 T62: r28-track, r28-pulse, r28-dark, r28-cooler, the round's sudo and polkit rules and linger removed, never in the ISO — 
- [owner] o06 triad, his private repo fluvia4ai/triad: a read-only deploy key's public key posted for him, added with his OK; installed by default, self-updating, taught in Part 1 — the last line, owner 00:24

## last done
- sa28 Neovim Rust: keep rust-analyzer/clippy/rustfmt/taplo/Space r/codelldb; add inlay hints with a toggle key; crates.nvim only if tiny (Sat 7 Nov 21:29)
- sa29 Part 2 lessons re-ordered ~30 min/day: Python and Bash first (Bash its own early track, Python+SQLite), then web (HTML/CSS/JS, HTMX+FastAPI) and TUI (Textual, ratatui), then Rust (Rustlings-style); short units: CLI, regex, HTTP, data structures, git, testing, debugging, security; track list in the lessons' table of contents (Sat 7 Nov 21:36)
- sa27 dwl: menus open and close as his pick c 2 omori, under ASan headless, frames looked at (Sat 7 Nov 20:58)
- sa28 dwl: window open and close built: his pick a 5 mozaiku as the default, behind the same switch, the others one switch away (S9) (Sat 7 Nov 21:02)
- sa29 dwl: the workspace move built: his pick b 4 heya as the default, the others one switch away (S10) (Sat 7 Nov 21:05)
- sb01 dojo sandbox: rootless podman (bubblewrap where too heavy) seeing only ~/dojo, no sudo, localhost-only servers, checkers inside; `dojo` command, launcher entry, Super+U; Space r/t/d run inside the box; `dojo reset` rebuilds the box but never deletes project files, wiping files a separate command that asks first; pages open in Helium (Sat 7 21:16)

## commits
- Sat 21:36 46aedc45 sa29: plan: one now (dsun2), next sb02 noted
- Sat 21:36 18dcd739 sa29: Part 2 re-ordered: Python and Bash first, then short units, web and TUI, then Rust; track list in the syllabus
- Sat 21:31 19baebfb sa25d3: FONT-09 checks Sumi Icons Bar and Sumi UI 16 (and Bold) against the toolkit's; rest -> sa25d3b
- Sat 21:29 e73dd504 sa28: Neovim Rust: inlay hints on in Rust buffers, Space c h toggles them; crates.nvim not added
- Sat 21:26 c26c4828 sa15e3: tairyoku's inks on the glyph meters: the downloads mark, Super+R's books, torrents (C_HP/C_HP_HI, foot 34/35, no fire)
- Sat 21:16 7ccc9c79 sb01: the dojo — a rootless podman box that sees only ~/dojo (dojo shell/run/db/doctor/reset/wipe), launcher entry, Neovim's Space r/t run inside it; core proved on this PC
- Sat 21:05 ade1f8f4 sa29: dwl's workspaces move as his pick b-4 heya (360/0), headless frames looked at; -> sb01
- Sat 21:02 44be77bc sa28: dwl's windows open and close as his pick a-5 mozaiku (300/220), headless frames looked at; -> sa29

## repairs

## errors (2 h)
- [   124][  1.239942] (read_unsupported_feature      ) busno=5, sleep-multiplier= 2.00, Testing for unsupported feature 0xdd returned Error_Info[DDCRC_RETRIES in ddc_write_read_with_retry, causes: DDCRC_DDC_DATA(10)]
- [   124][  1.240164] (read_unsupported_feature      ) Turning off dynamic sleep and retrying
- [   124][  1.345351] (read_unsupported_feature      ) busno=5, sleep-multiplier= 1.00, Retesting for unsupported feature 0xdd returned Error_Info[DDCRC_REPORTED_UNSUPPORTED in ddc_get_nontable_vcp_value_full]

steering received: S20 S21 S22 S23 S24 S25 S26 S27
options: a1-window.jpg, b1-workspace.jpg, c1-scroll.jpg, d1-prompt.jpg, f1-bar.jpg, g1-power.jpg, h2-menus.jpg, t1-transparency.jpg
