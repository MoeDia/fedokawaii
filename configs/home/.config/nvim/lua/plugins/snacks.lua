-- ~/.config/nvim/lua/plugins/snacks.lua — snacks.nvim, one plugin with many parts; only these are
-- on: the first screen, the finder, the file tree, lazygit, the terminal, the indent line.
local WIDTH = 60 -- snacks' own: the first screen's width, and so its heading's

-- The first screen as a text screen of the desktop's (docs/design-system.md §7): the heading (編's
-- icon in vermilion, the name, the stitch to the right edge), the rows, how long the start took.
-- The colours are colorscheme.lua's, so they follow the theme.
local function row(icon, key, desc, action) return { icon = icon .. " ", key = key, desc = desc, action = action } end
local NAME = "  editor "
local ICON = "\243\190\128\191" -- Sumi Icons: code (U+FE03F), as in icons.sh

return {
  {
    "folke/snacks.nvim",
    -- At once, and before the rest: the first screen is its work.
    lazy = false,
    priority = 900,
    opts = {
      dashboard = {
        width = WIDTH,
        preset = {
          keys = {
            row("\u{f002}", "f", "find file", ":lua Snacks.picker.files()"),
            row("\u{f15b}", "n", "new file", ":ene | startinsert"),
            row("\u{f022}", "g", "find text", ":lua Snacks.picker.grep()"),
            row("\u{f0c5}", "r", "recent files", ":lua Snacks.picker.recent()"),
            row("\u{f423}", "c", "config", ":lua Snacks.picker.files({ cwd = vim.fn.stdpath('config') })"),
            row("\u{f04b2}", "l", "plugins", ":Lazy"),
            row("\u{f426}", "q", "quit", ":qa"),
          },
        },
        sections = {
          { -- (the icon one cell, as every heading's: its ink spills into the space after it)
            text = {
              { ICON, hl = "KawaIcon" },
              { NAME, hl = "KawaName" },
              { string.rep("─", WIDTH - 1 - #NAME), hl = "KawaStitch" },
            },
            align = "left",
            padding = 2,
          },
          { section = "keys", gap = 1, padding = 1 },
          { section = "startup" },
        },
      },
      -- The finder; and the tree, which is one of its windows, opens folders too.
      picker = { enabled = true },
      explorer = { enabled = true, replace_netrw = true },
      -- The line beside the block you are in, there at once, not drawn out over 16 frames.
      indent = { enabled = true, animate = { enabled = false } },
      -- lazygit (Space g g): its own config (~/.config/lazygit/config.yml), coloured from the theme's
      -- inks, vermilion for the panel you are in, and no Nerd Font icons among the pixel letters.
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
