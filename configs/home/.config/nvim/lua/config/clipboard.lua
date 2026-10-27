-- ~/.config/nvim/lua/config/clipboard.lua — the desktop's clipboard and the editor's, each in its
-- place (the editor and the notes window both use it). With nvim's "unnamedplus" (LazyVim's
-- default) every x, dd or cw put what it took out on the desktop's clipboard: a link copied in
-- the browser was gone after one deleted letter, and Super+V's history filled with them.
-- So: what you copy (y) goes to the desktop's clipboard as well; what you delete or change
-- stays in the editor (its own register, for dd then p); p and P put in what was copied last,
-- anywhere — the desktop's newest copy when one came after the editor's last (another program,
-- Super+V), else the editor's own.
local M = {}

-- (a copy's text as the clipboard gives it back: its last line's end left out)
local function norm(s) return (s or ""):gsub("\r?\n$", "") end
local last = nil -- what this editor last put on the desktop's clipboard, normalised

local function fresh()
  local ok, plus = pcall(vim.fn.getreg, "+")
  if ok and plus ~= "" and norm(plus) ~= last then
    vim.fn.setreg('"', plus, vim.fn.getregtype("+"))
    last = norm(plus)
  end
end

function M.setup()
  vim.o.clipboard = ""
  vim.api.nvim_create_autocmd("TextYankPost", {
    group = vim.api.nvim_create_augroup("fedokawaii_clipboard", { clear = true }),
    callback = function()
      local e = vim.v.event
      if e.operator ~= "y" or (e.regname ~= "" and e.regname ~= "+") then return end
      if e.regname == "" then vim.fn.setreg("+", e.regcontents, e.regtype) end
      last = norm(table.concat(e.regcontents, "\n"))
    end,
  })
  for _, k in ipairs({ "p", "P" }) do
    vim.keymap.set({ "n", "x" }, k, function()
      if vim.v.register == '"' then fresh() end -- ("ap and the like: that register, as asked)
      return k
    end, { expr = true, desc = "paste: the newest copy, here or on the desktop" })
  end
end

return M
