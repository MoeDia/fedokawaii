#!/usr/bin/env bash
# round28.sh (6 Nov): the owner's round-28 brief into the run's inbox, economy mode, start.
set +e
export XDG_RUNTIME_DIR=/run/user/$(id -u) DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus
M="$HOME/repos/fedokawaii"
{ printf '\n## %s — open\n' "$(date '+%F %H:%M')"; cat <<'EOF'
ROUND 28 — THE OWNER'S BRIEF (6 Nov 00:14, his answers 00:20; relayed by Claude, his words kept). Read all of it before anything else.

HOW THIS ROUND RUNS
0. ECONOMY AND CALM (owner 00:24): he moved to the x5 plan. Trickle the work SLOWLY: --effort medium (set below), NO lanes at all: only the main run, ONE small task at a time, strictly sequential, no parallel subagents (owner 00:26), no idle polling passes, image generation only where needed. He keeps the PC running for days: there is no deadline. YOU decide the best build order. NOTHING MAY BREAK: small steps, verify after each, a snapshot before any system change, one VM at a time, never image generation while a VM runs, keep his login services, the page and the conductor healthy. Every lane in ~/.config/fedokawaii/r27-lanes stays paused (#) and MAXL is 0: the main run alone does the whole round, one small piece after another.
1. PHASE A — OPTIONS FIRST, NO BUILDING YET: an options pack on his page (.claude/review/next/, short recordings for motion), 2-4 choices each: (a) window open/close animation, (b) the workspace move, (c) the menu scroll open/close, (d) the final prompt with the new icon INSIDE the pastel ribbon, (e) the lock screen with the engraved quote, (f) the bigger top bar with the clock scroll, (g) the power menu layout, (h) Super+U / Super+R tightened, (i) Helium's theme. Ask his picks on the page; build those parts only after.
2. PHASE B build to his picks. PHASE C learning, nvim, apps. PHASE D repo and script cleanup, ISO.
3. PHASE E — THE FINAL QUESTIONNAIRE: before the last edit, ask him a very large number of questions (100+ is fine) on his page in batches by topic, every detail; apply his answers; that is the LAST time the repo is edited. Then the ISO is built, installed on his PC, and fedokawaii lives there self-maintaining on Fedora 45 only until Fedora 46.
4. Executive decisions are allowed wherever he did not choose; one line each in the plan.

DESIGN
- Window open/close animations "still don't feel right": options (A).
- MENUS OPEN/CLOSE AS A REAL RETRO JAPANESE SCROLL: stronger, clearly a hanging scroll unrolling and rolling up (rods, paper, edges); "hack the dwl border system" to draw it; options.
- TOP BAR: bigger bar, bigger icons and text, SUPER CRISP (icons drawn at real size, no blurry scaling, right hinting), still fully floating (no band); the middle date/time INSIDE a scroll with clear, bigger, dominant left and right scroll ends; the clock keeps seconds.
- THE PROMPT: the new icon INSIDE the pastel ribbon, not outside; "a bit childish": make it elegant and refined.
- LOCK: the top quote ENGRAVED majestically and theatrically INTO the wall, an ancient carving, super graphic; far more complexity and detail in the wall; keep the torches and the M1 Hannya / M2 angel masters.
- MENUS AS ONE UNIT: cut wasted space (Super+U, Super+R, all); executive industry-grade alignment and spacing; a much better power menu; every menu complements the others.
- MOTION PERFORMANCE (workspace moves, window spawns): high priority in the final touch-up, measured.
- Research the YouTuber "Hayyoth" (design and work philosophy); bring in what fits.

LEARNING
- DROP the Learn book as a book; keep its content re-cut into a DAILY system: each day ONE lesson from Part 1 and ONE from Part 2, about 30 minutes together. His philosophy: small daily consistent effort.
- PART 1: the system we built: using it, keys, menus, updates, snapshots, ASOBI, Helium (a short chapter on using it efficiently), triad, keeping it healthy.
- PART 2: Python first, then Rust; fundamentals: debugging (very important), git properly, testing, deployment basics, basic security, reading docs; Neovim to its max with HIS config. Simple robust examples, exercises; he is a slow learner: tiny steps, repetition, checks.
- The parts complement each other day by day. Lessons live in a Learning menu (Super+U): today's pair, progress, next; each lesson one idea, one exercise, one check.
- NEOVIM: his OWN minimal config (lazy.nvim + a handful of hand-picked plugins, every line explained in lessons); NO transparency while nvim runs; a BIGGER font in nvim by default.
- PROGRAMMING FONT: the best, most solid, coolest one by real render trials (e.g. Iosevka, JetBrains Mono, Maple Mono, Commit Mono, Monaspace; with Nerd glyphs); executive choice, written down with why.

APPS AND HOME
- HELIUM: configure and optimise fully; theme it HEAVILY like a TUI program of ours in our dark/light DNA; a solid, symmetrical, minimal toolbar; essential extensions beyond uBlock Origin (few, executive).
- STOAT (Discord replacement): install and theme it; REMOVE every installed web app (WhatsApp and the like).
- SYNCPLAY: a TUI view in our theme of who joined, left, is ready, with a ready toggle like the GUI client.
- TRIAD (owner 00:24: keep it for the VERY END of the round): his private repo fluvia4ai/triad, installed by default, self-updating and self-improving, taught in Part 1. Access: post a read-only deploy key's PUBLIC key on his page; Claude adds it to triad (through Google Chrome on his Mac) with his OK.
- HOME FOLDERS, all lower-case, the bare minimum: ~/downloads, ~/captures (screenshots + recordings), ~/notes (Super+N), ~/books (Super+R), ~/dojo (projects + Part 2 exercises). No Desktop, Documents, Music, Pictures, Videos, Templates, Public; xdg-user-dirs set; the whole system's naming clean and intentional.

REPO, SCRIPT, ISO
- Repo and script: super compartmentalised, clear, CLEAN; drop the unnecessary; better names and structure; combine what belongs together; optimise a lot; no over-engineering; a clear commenting system; the code a work of art.
- Research "Anthropic says .md files are dead, HTML is next" against Anthropic's own docs; adopt only where it really helps; never break CLAUDE.md for Claude Code.
- A NEW Super+U menu, "the inventory": a clean live table of every installed app and where it updates from, every menu we created, every app we modified and how; all stored cleanly and reachable there.
- ISO: Fedora 45 only, newest stable everything, a robust unbreakable unit with a full TUI install (Omarchy-grade), the boot loader wallpaper upgraded, the install fully solid.
- A FULL SCAN at the end: every new design element everywhere, nothing left in the old style. Then Phase E, the last edit, the ISO, his install.
EOF
} >> "$M/.claude/inbox.md"
sed -i -E 's/--effort (max|high)/--effort medium/g' "$HOME/.local/bin/r27-lane-loop" "$HOME/.local/bin/r27-conductor"
sed -i 's/MAXL=[0-9]*/MAXL=0/' "$HOME/.local/bin/r27-conductor"
sed -i -E 's/^([a-z][a-z0-9-]*\|)/#\1/' "$HOME/.config/fedokawaii/r27-lanes"
systemctl --user enable --now r27-lane-conductor; systemctl --user restart r27-lane-conductor
sleep 4; echo "brief: in the inbox | effort: $(grep -o -- '--effort [a-z]*' "$HOME/.local/bin/r27-lane-loop" | head -1) | lanes: none (main alone, one task at a time) | conductor: $(systemctl --user is-active r27-lane-conductor)"
