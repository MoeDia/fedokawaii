-- ~/.config/nvim/lua/plugins/editor.lua — the small helpers around the text.
return {
  -- Treesitter: the parsers that let neovim read code's real structure (colours; neovim itself uses
  -- them, autocmds.lua starts them). This plugin only builds them (lua/config/prefetch.lua) and
  -- brings their queries, so it must be on the path from the start.
  { "nvim-treesitter/nvim-treesitter", branch = "main", lazy = false },

  -- Git in the margin: what changed, line by line; ] h and [ h go to the next and previous block.
  {
    "lewis6991/gitsigns.nvim",
    -- A moment after the text: git answers later anyway. With no file named, at the first file.
    event = vim.fn.argc(-1) > 0 and "VeryLazy" or { "BufReadPost", "BufNewFile" },
    opts = {
      on_attach = function(buf)
        local gs = require("gitsigns")
        vim.keymap.set("n", "]h", function() gs.nav_hunk("next") end, { buffer = buf, desc = "next changed block" })
        vim.keymap.set("n", "[h", function() gs.nav_hunk("prev") end, { buffer = buf, desc = "previous changed block" })
      end,
    },
  },

  -- A key that waits for the next one shows what that can be: Space, then wait, is your menu.
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      preset = "helix",
      spec = {
        { "<leader>b", group = "buffer" },
        { "<leader>c", group = "code" },
        { "<leader>d", group = "debug" },
        { "<leader>f", group = "find" },
        { "<leader>g", group = "git" },
        { "<leader>q", group = "quit" },
        { "<leader>r", group = "run" },
      },
    },
  },

  -- Mason installs the language servers and the debuggers (setup.sh MASON_TOOLS); options.lua puts
  -- its folder on the PATH, so nothing needs it loaded but its own commands.
  { "mason-org/mason.nvim", cmd = { "Mason", "MasonInstall", "MasonUpdate" }, opts = {} },
}
