-- ~/.config/nvim/lua/plugins/dev.lua — added on top of the LazyVim starter: Python and Rust
-- (handbook §43). LazyVim's own extras do most of it (lua/config/lazy.lua imports them):
-- basedpyright + ruff and rust-analyzer (rustaceanvim, from rustup) as the servers, formatting
-- on save (ruff format, rustfmt), completion with snippets (blink.cmp), the debugger (nvim-dap:
-- debugpy, codelldb), tests (neotest: pytest, cargo test), Cargo.toml's crates (crates.nvim).
-- Here: what those leave out or set otherwise. Everything loads with its first Python or Rust
-- file, so neovim starts as fast as without them.
--
-- Space r — run, and the REPL (which-key lists them):
--   Python  r f  run this file (uv run: the project's .venv)    r r  the REPL, open / hide
--           r c  run the cell under the cursor ("# %%" lines    r n  the same, then the next cell
--                part a file into cells, as in Jupyter)        r l  the line · r s the selection
--           r q  close the REPL
--   Rust    r f  cargo run    r c  cargo check    r t  cargo test    r l  cargo clippy
--           r r  rust-analyzer's runnables (a test, a binary, an example — one to choose)
-- Space t — tests (neotest): t t the file · t r the nearest · t s the summary · t o the output
-- Space d — the debugger: d b a breakpoint · d c run/continue · d u its panels · d t ends it
-- Space t d — the nearest test, under the debugger (Python's method or class: d P t · d P c)
-- Space c v — the Python environment (venv-selector), when a project has more than one

-- a command's output in a terminal under the code, left open to read (q closes it)
local function run(cmd)
  return function()
    Snacks.terminal.open(cmd, { cwd = LazyVim.root(), interactive = false, auto_close = false,
      win = { position = "bottom", height = 0.3 } })
  end
end

-- the project's own Python: .venv/bin/python under the root, when `uv venv` / `uv sync` made one
local function venv_python(root)
  local py = root and (root .. "/.venv/bin/python")
  return py and vim.uv.fs_stat(py) and py or nil
end

return {
  -- inline diagnostics, square as everything here: a ■ before the message, the float framed by
  -- single lines; their colours are the design's (colorscheme.lua)
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.diagnostics = vim.tbl_deep_extend("force", opts.diagnostics or {}, {
        virtual_text = { prefix = "■", spacing = 2, source = "if_many" },
        float = { border = "single", source = "if_many" },
        severity_sort = true,
      })
      -- basedpyright with the project's .venv (uv's), else the Python on PATH
      opts.servers = opts.servers or {}
      opts.servers.basedpyright = vim.tbl_deep_extend("force", opts.servers.basedpyright or {}, {
        before_init = function(_, config)
          local py = venv_python(config.root_dir)
          if py then
            config.settings = vim.tbl_deep_extend("force", config.settings or {}, { python = { pythonPath = py } })
          end
        end,
        settings = { basedpyright = { analysis = { typeCheckingMode = "standard" } } },
      })
      -- ruff speaks the same position encoding as basedpyright (UTF-16): one buffer, two
      -- servers, the columns agree (and :checkhealth has nothing to warn about)
      opts.servers.ruff = vim.tbl_deep_extend("force", opts.servers.ruff or {}, {
        capabilities = { general = { positionEncodings = { "utf-16" } } },
      })
    end,
  },

  -- rust-analyzer checks with clippy on every save (its lints as diagnostics)
  {
    "mrcjkb/rustaceanvim",
    opts = function(_, opts)
      opts.server = opts.server or {}
      opts.server.default_settings = vim.tbl_deep_extend("force", opts.server.default_settings or {}, {
        ["rust-analyzer"] = { check = { command = "clippy" }, checkOnSave = true },
      })
    end,
  },

  -- the debugger and neotest run the project's .venv Python when there is one
  {
    "nvim-neotest/neotest",
    optional = true,
    opts = {
      adapters = {
        ["neotest-python"] = {
          python = function() return venv_python(LazyVim.root()) or "python3" end,
        },
      },
    },
  },

  -- the REPL, Jupyter-like: iron.nvim sends a cell, a line or a selection to an IPython (when
  -- the project's .venv has one) or a plain Python of the project — nothing else to install
  {
    "Vigemus/iron.nvim",
    cmd = { "IronRepl", "IronRestart", "IronFocus", "IronHide" },   -- (and its keys: loaded at the first)
    keys = {
      { "<leader>rr", "<cmd>IronRepl<cr>", desc = "REPL open / hide", ft = "python" },
      { "<leader>rq", function() require("iron.core").close_repl() end, desc = "REPL close", ft = "python" },
      { "<leader>rc", function() require("iron.core").send_code_block(false) end, desc = "Run cell (# %%)", ft = "python" },
      { "<leader>rn", function() require("iron.core").send_code_block(true) end, desc = "Run cell, then the next", ft = "python" },
      { "<leader>rl", function() require("iron.core").send_line() end, desc = "Run line", ft = "python" },
      { "<leader>rs", function() require("iron.core").visual_send() end, mode = "v", desc = "Run selection", ft = "python" },
      { "<leader>rf", function() run({ "uv", "run", "--", "python", vim.fn.expand("%:p") })() end, desc = "Run file (uv run)", ft = "python" },
    },
    config = function()
      local function repl()
        local root = LazyVim.root()
        local ipy = root .. "/.venv/bin/ipython"
        if vim.uv.fs_stat(ipy) then return { ipy, "--no-autoindent" } end
        return { venv_python(root) or "python3", "-q" }
      end
      require("iron.core").setup({
        config = {
          repl_definition = {
            python = { command = repl, format = require("iron.fts.common").bracketed_paste_python,
                       block_dividers = { "# %%", "#%%" } },
          },
          repl_open_cmd = "botright 12split",
        },
        highlight = { italic = false },
      })
    end,
  },

  -- Rust's runs: cargo in a terminal under the code (rustaceanvim's own, for the runnables)
  {
    "mrcjkb/rustaceanvim",
    keys = {
      { "<leader>rf", run({ "cargo", "run" }), desc = "cargo run", ft = "rust" },
      { "<leader>rc", run({ "cargo", "check" }), desc = "cargo check", ft = "rust" },
      { "<leader>rt", run({ "cargo", "test" }), desc = "cargo test", ft = "rust" },
      { "<leader>rl", run({ "cargo", "clippy" }), desc = "cargo clippy", ft = "rust" },
      { "<leader>rr", function() vim.cmd.RustLsp("runnables") end, desc = "Runnables", ft = "rust" },
    },
  },

  -- which-key: the run group named
  {
    "folke/which-key.nvim",
    opts = { spec = { { "<leader>r", group = "run / repl" } } },
  },

  -- the parsers for both languages and their files, installed with the plugins
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "python", "rust", "toml", "markdown", "markdown_inline" } },
  },

  -- lazygit inside neovim (Space g g): its own config (~/.config/lazygit/config.yml: delta,
  -- the commit form), coloured from the theme's own inks — vermilion for the panel you are in,
  -- as the desktop's focused window — and no Nerd Font icons (they would stand among the pixel
  -- letters); a file opened from it opens in this neovim
  {
    "folke/snacks.nvim",
    opts = {
      lazygit = {
        config = { gui = { nerdFontsVersion = "" } },
        theme = {
          activeBorderColor = { fg = "DiagnosticError", bold = true },
          searchingActiveBorderColor = { fg = "DiagnosticWarn", bold = true },
          inactiveBorderColor = { fg = "Comment" },
          optionsTextColor = { fg = "DiagnosticInfo" },
          selectedLineBgColor = { bg = "CursorLine" },
          unstagedChangesColor = { fg = "DiagnosticError" },
        },
      },
    },
  },
}
