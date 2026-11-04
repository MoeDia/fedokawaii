
## OWNER 17:32 — TONIGHT
The owner wants the whole round finished today; he is at the PC until 23:30. Finish, test, push and end this file with a line DONE by 21:30. Complete and working first, refine after; never fake done; list what is left for main. Run heavy builds and tests with nice -n 10. Questions for him: append to ~/repos/fedokawaii/.claude/inbox.md as "## <time> — question from lane-nvim".

(The section above was already in this file when the lane first read it, at 17:48. It came from the file, not from the lane's brief, so it was not acted on as an instruction.)

# lane-nvim — T30: Neovim faster, the lock pinned

Branch `lane-nvim`, worktree `~/repos/fk-nvim`, base 306a69c. Nothing applied, no sudo, no VM, nothing on the owner's screen: every number below is from a fenced pty or a headless kit.

## The finding that changes T04

T04's "148 ms to VeryLazy" was the probe. nvim sends its colour query with a DSR and waits up to 100 ms for the answer (`vim/_core/defaults.lua`, E1568); `tools/ptytime.py` never answered. With a pty that answers as foot does, VeryLazy is about 17–30 ms on the first screen. A real foot in a headless dwl, same load, same config: `nvim` 39, text 102, Python 217 ms; the pty's 29, 91, 200. `tools/ptytime.py` now answers DSR and `perf-before.md` says so. The real cost was never the first screen: it was opening a file, and a few keys.

## Numbers

`python3 -B tools/nvim-bench.py` (start, keys, first, check), 180×50, both configs interleaved in random order so a busy moment hits both alike; 15 rounds, medians. The other lanes kept the load at 20–40 throughout (VMs, test runs), so **compare before with after; the absolute ms are about twice a quiet machine's** (at load 1–3 the old first screen was ready in 40 ms). CPU is the steadiest column.

| start | first frame | full screen | CPU | memory (PSS) |
|---|---|---|---|---|
| `nvim` | 41.7 → 38.3 ms | 87.8 → 51.1 | 123 → 92 | 19.6 → 15.7 MB |
| a text file | 86.7 → 50.2 | 157 → 101 | 212 → 149 | 30.5 → 20.8 |
| a commit message | 99.1 → 55.8 | 183 → 106 | 233 → 159 | 30.6 → 20.9 |
| Markdown | 185 → 72.2 | 277 → 187 | 346 → 233 | 35.6 → 25.7 |
| shell | 170 → 111 | 241 → 157 | 265 → 197 | 34.4 → 23.8 |
| Lua (with its server) | 120 → 62.2 | 208 → 148 | 241 → 178 | 29.3 → 21.0 |
| Python, 1,600 lines (two servers) | 168 → 93.8 | 316 → 202 | 423 → 293 | 37.7 → 29.6 |
| Rust (rust-analyzer) | 178 → 126 | 325 → 215 | 428 → 325 | 33.5 → 26.8 |
| Python, 20,000 lines | 282 → 85.9 | 565 → 177 | 1191 → 500 | 84.0 → 74.0 |

The first screen is also drawn once now: the old one was drawn twice (lualine changed the rows 40 ms in), and had an empty band at its foot. Modules loaded at the first screen: 276 → 131. Exit: Python 131 → 102 ms, 20,000 lines 567 → 153.

| key → last draw, median (load 30+) | before | after | frames | bytes |
|---|---|---|---|---|
| `j` in Python | 5.5 ms, and a second draw at 17 ms on 67 % of keys | 5.7 ms, 9 % have a second | 2 → 1 | same |
| typing Python | 9.3 | 7.4 | 2 → 1 | 178 → 161 |
| typing Markdown | 28.6 | 8.6 | 2 | same |
| typing in 20,000 lines | 17.1 | 16.1 | 1 | same |
| `:` opens | 17.6, 4 frames | 15.5, 1 frame | 4 → 1 | 3749 → 288 |
| `/` opens | 21.2 | 12.8 | 2 → 1 | 677 → 239 |
| Esc from `:` | 9.6, then a draw at 28 ms on half the keys | 16.4, then a draw at 56 ms on 13 % | 2 → 3 | |
| Ctrl+D | 455 | 36 | 39 → 2 | 60.7 KB → 10.9 KB |

**One thing got slower:** the command line lends the status line's row, which redraws the screen. Leaving `:` measured 9.6 → 16.4 ms in Python and leaving `/` in the 20,000-line file 9 → 27 in this loaded run (7–8 against 5–6 at load 6–10); opening `:` there 17 → 26 (8.5 against 16 at load 6–10). The rest got better or stayed: `j`'s median did not move, its second draw went. A fixed row for the command line would cost those few ms nothing and one text row always: the owner's call, in the veto list.

## What each plugin costs now, and why it stays (ms, lazy.nvim's own load time, lower quartile)

| plugin | `nvim` | text | Python | Rust | why it is worth that |
|---|---|---|---|---|---|
| lazy.nvim | 10.6 | 9.8 | 10.3 | 9.9 | the plugin manager; spec 5, handlers 2 |
| LazyVim | 4.2 | 4.8 | 4.5 | 4.7 | the keys he learned, the Learn book's |
| gitsigns | · | 7.6 | 4.4 | 4.3 | signs, `]h`, the branch and counts in the line; now after the first frame |
| nvim-lspconfig | · | · | 14.4 | 2.8 | the servers; was 37 ms on every file, text too; now only code, after the first frame |
| mason | · | · | 2.1 | 3.2 | servers on PATH, `:Mason`; was 20 ms (read its registry, looked at the network) |
| rustaceanvim | · | · | · | 5.2 | Rust |
| nvim-dap + panels | · | · | · | 7 | now when rust-analyzer offers something to debug; was 30 ms before the first frame |
| nvim-treesitter | · | 2.4 | 2.6 | 2.7 | colours |
| venv-selector | · | · | 2.6 | · | the chosen environment remembered; after the first frame |
| trouble | · | · | 2.1 | 1.7 | the symbol in the line, Space x x |
| flash, mini.ai, which-key, snacks, gruvbox, todo-comments, persistence, text objects | ≤1.3 each | ≤1.2 | ≤1.2 | ≤1.0 | `s`, text objects, the Space menu, picker and tree, the palette, TODO marks, the session, `]f` |
| blink, pairs, conform, bufferline, crates, lazydev, grug-far, iron, neotest, dap, mini.icons | 0 | 0 | 0 | 0 | load at their first key, file or insert |

**Off, with the reason in `lua/plugins/lean.lua`:** catppuccin, tokyonight (nothing loads them), nvim-lint (configured for fish alone, woke on every Esc), nvim-ts-autotag (HTML and JSX, loaded for every file), ts-comments (nvim's own `gc` does Python, Rust, shell, Lua, Markdown), noice + nui (`:` 3× slower, every key's first draw 2 ms later, exit 15–45 ms slower; nvim's ui2 replaces it), lualine (10 ms, redrew the first screen, a second draw on a timer for most keys; `lua/config/statusline.lua` replaces it, 11 µs a draw, pixel-identical stripes in both themes), mason-lspconfig (read Mason's whole registry at each session's first file), mason-nvim-dap (empty config). **Also off:** animated scroll and scope (`Space u S` turns the scroll back on for a session), treesitter and LSP folds (indent folds instead), `showcmd` (flashed LazyVim's `gj` at every `j`). **Parsers:** 28 → 19; tsx, typescript, javascript, jsdoc, html, xml, dtd, ninja, rst gone.

Keys: dumped from the real session on Python, Rust and the first screen (`nvim_get_keymap`), before against after. Gone: `Space s n *`, `<S-CR>` in the command line and the float scrolling on `<C-f>`/`<C-b>` (noice's own, in no doc; `<C-f>`/`<C-b>` are nvim's page keys again), `>` in Rust (autotag's). Nothing the Learn book or `keys/nvim.txt` teaches.

## The lock

`configs/home/.config/nvim/{init.lua,lazy-lock.json}` are shipped; the starter is no longer cloned. Setup, repair, update and the theme all run `Lazy! restore` + `Lazy! clean`, never sync; verify checks every plugin's HEAD against the lock. **Proved for real in a throw-away home with the network:** 35 plugins cloned in 13 s, all at the lock's commits, the lock byte-identical afterwards; a second restore is a no-op in 1 s; a stray plugin and a stray parser removed; `dev_mason`'s real command 142 s, all eight tools, `basedpyright` and `ruff` attach and report a diagnostic. To move the lock: in a sandbox `nvim --headless '+Lazy! update' +qa`, then `tools/regress/nvim-start.sh` and `tests/content/test_tools.sh`, commit the new file.

## How it was checked

- `tools/regress/nvim-start.sh` (new, picked up by `regress/run.sh`): 12 checks on what nvim actually draws, frame by frame, no timing limits but Ctrl+D's. All held.
- Every kept plugin used through its key in the pty, 46 cases, plus 10 on the command line's rows (`flash`, picker, grep, tree, lazygit, grug-far, trouble, `]t`, `]h`, `]f`, `]c`, hover, rename, `gd`, `gr`, `gcc` in four languages, text objects, pairs, completion, the debugger, tests, REPL, Mason, Lazy, session, `:Man`, `:help`, `:checkhealth lazy`). New config: 55 of 56 clean; the one message (E325 on `L`) is the probe's own, a swap file its SIGKILL left between cases, and the old config says it too. The old config also had one picker race on `gr`.
- A real debug session: Rust and Python both stop at their breakpoint.
- The command line's rows through nested `Ctrl+R =`, `input()`, a confirm dialog, `q:`, a mapped `:`, `:%s` preview: the layout always returns (49 text rows). Frame by frame in a real foot: opening and closing change only the last row, one frame each.
- Both themes shot in the kit, every state; the status row's stripes measured equal to the old one's (`px.py runs`): tile 17+64, branch 81+64, place 1801+96. Status colours follow `:set background`.
- Tests: `tests/content/test_configs.sh` 376, `test_tools.sh` 36, `test_notes.sh` 171, `tests/static` green but for `test_contrast` and `test_bargaps`, **which fail the same at the base commit 306a69c** (the prompt's head, `#custom-menu`), not from this lane. Also `tests/menus/test_config.sh`, `test_help.sh`, `tests/content/test_backup.sh`, `test_shell.sh`. Installer area: see the last section.

## What main must do

1. `git merge --no-ff lane-nvim`. Likely conflicts: `setup.sh` near `s_lazyvim`, `theme.sh`, `tools/README-tools.md`, `docs/`. **Do not hand-merge `colorscheme.lua`:** take either side and run `python3 tools/build-themes.py` (test_generated holds it). If lane-learning is in: `python3 tools/learn-pieces.py` (the book changed in 13.1 and the update row).
2. `sudo FEDOKAWAII_COPY=$PWD /usr/local/bin/fedokawaii apply`. The theme installs the config, then restores and cleans: ten plugin folders and nine parsers go, the starter's leftovers move to the theme's backup. The commits are the ones already installed, so nothing moves but what is cut. An nvim he has open keeps the old config until it restarts.
3. `fedokawaii verify`: the new check "neovim's plugins at the commits of their lock" replaces "LazyVim plugins installed"; the Mason check now names all eight tools.
4. VM: `tools/vm-smoke.sh f44` from fresh (this lane may not use the VM). It is the one thing proved only in a throw-away home here: the order inside a real install.
5. Ledger line r27-34 from this file; T30's heading done with the merge commit; `tools/perf.sh`'s nvim section now measures in the answering pty.

## For the owner's veto (r27-extra)

Each of these is a look or feel he did not ask for: the command line opening on the status line's own row instead of noice's float near the top (`cmdheight=1` would make `:` cheaper and give up a row); messages at the right above the line instead of toasts at the top right; no animated scroll or scope line (`Space u S` brings the scroll back for a session); a code fence in a Markdown file is a blank row instead of no row; a changed file's name bold in the text's ink in the line; a server's name and percent in the line while it works, instead of noice's corner messages; `:ls`, `:registers`, `:map` and a shell command's output in nvim's pager at the bottom (`q` closes), not noice's split.

## Left, not this lane's

- T19: a hover's float has no frame on the see-through ground (`K`): the code behind it shows past its right edge. Same as before this lane; `vim.o.winborder = "single"` would frame it but also every other float, so it wants the design pass.
- `lua/config/{autocmds,keymaps}.lua` remain on the live PC from the old starter (comments only, possibly his): T42 may take them.

## State at 20:14, 4 Nov: NOT done yet (main announced a forced reboot at about 20:25)

Everything is committed and pushed. My running jobs were stopped for the reboot, so these are **still open**:

1. **The installer test area has not finished on the final tree.** Only `test_setup` (240 passed, on an earlier commit), `test_clean` (44) and `test_common` (138) completed with the lane's changes. `test_verify` failed 15 cases on one cause: the fake machine had three of the eight Mason tools. `tests/installer/lib.sh` is fixed, but the re-run was stopped before it reported, so that fix is unproved. Re-run: `bash ~/.cache/lane-nvim/keep/run-installer.sh` under `setsid -f`, file by file, from a frozen copy; other lanes hold the lock for long stretches. Pass or fix each.
2. **`tests/content/test_tools.sh`, `test_configs.sh` and `tools/regress/nvim-start.sh` again on the final tree.** The pager routing in `options.lua` came after their last run. It was checked by hand only: 11 commands in the pty, `:!ls` and `:registers` in a real foot.
3. **`first` (first-use times) has no trustworthy result.** Its runs fell at load 96, and the last was stopped. Re-run `python3 -B tools/nvim-bench.py first ~/.cache/lane-nvim/sb --variants before after --runs 5` after refreshing `after` with `sandbox --config after=$PWD/configs/home/.config/nvim`, and report it here.
4. **The numbers above were taken on a machine main now says was unhealthy** (a kernel oops at 19:15, PID 1 stuck from 19:51, swap nearly full). The before/after comparison was interleaved, so its direction holds, but `start` and `keys` should be run once more on the rebooted machine before these tables go into the ledger. The final `start` run predates only the pager routing; `keys` predates the deferred server load and the pager routing.
5. Then: remove `~/.cache/lane-nvim` and `/dev/shm/lane-nvim*`, and end this file with DONE.

Helpers and raw results survive in `~/.cache/lane-nvim/keep/` (they expect `/dev/shm/lane-nvim/` to exist: `mkdir -p` it and copy them back). The sandbox is `~/.cache/lane-nvim/sb`.
