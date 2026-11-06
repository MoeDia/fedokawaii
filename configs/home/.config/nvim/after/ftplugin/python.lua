-- ~/.config/nvim/after/ftplugin/python.lua — Python's Space r keys, in Python files alone.
local run = require("config.run")
local function map(mode, key, action, desc) vim.keymap.set(mode, key, action, { buffer = true, desc = desc }) end

-- The whole file, with the project's Python (uv run: its .venv).
map("n", "<leader>rf", function() run.cmd({ "uv", "run", "--", "python", vim.fn.expand("%:p") })() end, "run the file")
-- The project's tests.
map("n", "<leader>rt", run.cmd({ "uv", "run", "--", "pytest" }), "run the tests")
-- The REPL, Jupyter-like (lua/plugins/repl.lua): open or hide it, close it.
map("n", "<leader>rr", "<Cmd>IronRepl<CR>", "the REPL, open or hide")
map("n", "<leader>rq", function() require("iron.core").close_repl() end, "close the REPL")
-- Send it code: the cell ("# %%" lines part a file into cells), the cell and on to the next, the
-- line, the selection.
map("n", "<leader>rc", function() require("iron.core").send_code_block(false) end, "run the cell")
map("n", "<leader>rn", function() require("iron.core").send_code_block(true) end, "run the cell, go to the next")
map("n", "<leader>rl", function() require("iron.core").send_line() end, "run the line")
map("x", "<leader>rs", function() require("iron.core").visual_send() end, "run the selection")
