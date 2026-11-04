-- ~/.config/nvim/lua/plugins/lean.lua — LazyVim, lighter (T30; the numbers: tools/nvim-bench.py,
-- .claude/notes/lane-nvim.md). Off: what costs more than it gives here. Later: what the first
-- screen does not need waits for its key, its file or the frame after. The keys stay LazyVim's.

-- after the first frame when a file was named on the command line; else with the first file
local AFTER_FIRST_FRAME = vim.fn.argc(-1) > 0 and "VeryLazy" or "LazyFile"

return {
  -- two colour schemes nothing loads (the desktop's is gruvbox with its own palette)
  { "catppuccin", enabled = false },
  { "folke/tokyonight.nvim", enabled = false },
  -- nvim-lint: LazyVim configures it for fish alone, and it woke up on every save and every
  -- Esc for that; ruff and the servers lint Python, Rust and Lua
  { "mfussenegger/nvim-lint", enabled = false },
  -- closes HTML and JSX tags: loaded for every file, for files nobody writes here
  { "windwp/nvim-ts-autotag", enabled = false },
  -- nvim's own g c does Python, Rust, shell, Lua and Markdown (its commentstring by treesitter's
  -- injections); this added TSX's and a few more
  { "folke/ts-comments.nvim", enabled = false },
  -- a command line in a float and messages in another, redrawn in Lua (quit took 15–45 ms longer
  -- with it): nvim's own ui2 does both now (lua/config/options.lua), the notes window has it too
  { "folke/noice.nvim", enabled = false },
  { "MunifTanjim/nui.nvim", enabled = false },
  -- the status line: lua/config/statusline.lua
  { "nvim-lualine/lualine.nvim", enabled = false },
  -- mason-lspconfig only maps servers to Mason's names and enables what Mason holds: every
  -- start of a file read Mason's whole registry for that. The servers are listed in
  -- nvim-lspconfig's opts and Mason's folder is on the PATH
  { "mason-org/mason-lspconfig.nvim", enabled = false },
  -- (its config is empty: LazyVim loads it for :DapInstall alone)
  { "jay-babu/mason-nvim-dap.nvim", enabled = false },

  -- Mason: its folder on the PATH, its commands (:Mason, Space c m, the update's :MasonInstall).
  -- LazyVim also read the registry and looked for updates on the network at each first file or
  -- first save; what is installed is setup's job (setup.sh dev_mason)
  {
    "mason-org/mason.nvim",
    config = function(_, opts) require("mason").setup(opts) end,
  },

  -- the servers only for the kinds of file that have one: a text file or a commit message never
  -- pays for them (if a local.lua adds a server, its filetype goes here too)
  {
    "neovim/nvim-lspconfig",
    event = function() return {} end,
    ft = { "python", "rust", "lua", "toml" },
    cmd = { "LspInfo", "LspLog", "LspRestart", "LspStart", "LspStop" },
  },

  -- ] f, [ c and the like compile their language's queries (13–25 ms) when they are first
  -- pressed, not for every code file opened
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    event = function() return {} end,
    keys = {
      { "]f", mode = { "n", "x", "o" } }, { "[f", mode = { "n", "x", "o" } },
      { "]F", mode = { "n", "x", "o" } }, { "[F", mode = { "n", "x", "o" } },
      { "]c", mode = { "n", "x", "o" } }, { "[c", mode = { "n", "x", "o" } },
      { "]C", mode = { "n", "x", "o" } }, { "[C", mode = { "n", "x", "o" } },
      { "]a", mode = { "n", "x", "o" } }, { "[a", mode = { "n", "x", "o" } },
      { "]A", mode = { "n", "x", "o" } }, { "[A", mode = { "n", "x", "o" } },
    },
  },

  -- the signs come a moment after the text, as they always did: git answers later anyway
  {
    "lewis6991/gitsigns.nvim",
    event = function() return { AFTER_FIRST_FRAME } end,
  },
  {
    "folke/todo-comments.nvim",
    event = function() return { AFTER_FIRST_FRAME } end,
  },

  -- Ctrl+D and Ctrl+U land at once: the animated scroll took 460 ms to settle and wrote 60 KB of
  -- screen per press
  { "folke/snacks.nvim", opts = { scroll = { enabled = false } } },

  -- the parsers for what is written here; the others are never compiled by setup
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      opts.ensure_installed = {
        "bash", "c", "diff", "json", "lua", "luadoc", "luap", "markdown", "markdown_inline", "printf",
        "python", "query", "regex", "ron", "rust", "toml", "vim", "vimdoc", "yaml",
      }
    end,
  },

  -- no window of news when a plugin moves: the keys this desktop teaches are checked when it does
  { "LazyVim/LazyVim", opts = { news = { lazyvim = false, neovim = false } } },
}
