-- ~/.config/nvim/lua/plugins/look.lua — added on top of the LazyVim starter: the first screen
-- as a text screen of the desktop's (docs/design-system.md §7), in place of LazyVim's banner.
-- The heading — 編 in vermilion, the name, the stitch to the right edge — then the rows: the
-- glyph, the name in lower case, the key at the right in the quiet ink; then how long the
-- start took. The colours are colorscheme.lua's (KawaIcon, KawaName, KawaStitch and the
-- dashboard's own groups), so they follow the theme.
local WIDTH = 60 -- snacks' own: the rows' width, and so the heading's

return {
  {
    "folke/snacks.nvim",
    opts = function(_, opts)
      opts.dashboard = opts.dashboard or {}
      local d = opts.dashboard
      d.width = WIDTH
      d.preset = d.preset or {}
      for _, k in ipairs(d.preset.keys or {}) do
        if type(k.desc) == "string" then k.desc = k.desc:lower() end
      end
      local name = "  editor "
      local ICON = "\243\190\128\191" -- Sumi Icons: code (U+FE03F), as in icons.sh
      d.sections = {
        { -- (the icon one cell, as every heading's: its ink spills into the space after it)
          text = { { ICON, hl = "KawaIcon" }, { name, hl = "KawaName" },
                   { string.rep("─", WIDTH - 1 - #name), hl = "KawaStitch" } },
          align = "left", padding = 2,
        },
        { section = "keys", gap = 1, padding = 1 },
        { section = "startup" },
      }
    end,
  },
}
