-- ~/.config/nvim/lua/config/statusline.lua — the editor's bottom line, without a plugin: there in
-- the first frame (lualine came 10–40 ms after the text, and redrew the first screen when it
-- came), and drawn in the same frame as the key that changed it (lualine's own timer: up to 16 ms
-- later, a second draw for most keys). Its colours are colorscheme.lua's (KawaSt*): they follow
-- the theme. The first screen has no line at all, and no row is given up or taken back for that.
local M = {}

-- what nvim_get_mode() says → the word, and the colour of its tile
local MODES = {
  n = { "NORMAL", "Normal" }, no = { "O-PENDING", "Normal" }, nov = { "O-PENDING", "Normal" },
  noV = { "O-PENDING", "Normal" }, ["no\22"] = { "O-PENDING", "Normal" },
  v = { "VISUAL", "Visual" }, vs = { "VISUAL", "Visual" }, V = { "V-LINE", "Visual" },
  Vs = { "V-LINE", "Visual" }, ["\22"] = { "V-BLOCK", "Visual" }, ["\22s"] = { "V-BLOCK", "Visual" },
  s = { "SELECT", "Visual" }, S = { "S-LINE", "Visual" }, ["\19"] = { "S-BLOCK", "Visual" },
  i = { "INSERT", "Insert" }, ic = { "INSERT", "Insert" }, ix = { "INSERT", "Insert" },
  R = { "REPLACE", "Replace" }, Rc = { "REPLACE", "Replace" }, Rx = { "REPLACE", "Replace" },
  Rv = { "V-REPLACE", "Replace" }, Rvc = { "V-REPLACE", "Replace" }, Rvx = { "V-REPLACE", "Replace" },
  c = { "COMMAND", "Command" }, cv = { "EX", "Command" }, ce = { "EX", "Command" },
  r = { "REPLACE", "Command" }, rm = { "MORE", "Command" }, ["r?"] = { "CONFIRM", "Command" },
  ["!"] = { "SHELL", "Terminal" }, t = { "TERMINAL", "Terminal" }, nt = { "NORMAL", "Normal" },
}
local UNKNOWN = { "NORMAL", "Normal" }
local LOCK = "\243\190\128\160"     -- Sumi Icons: lock (U+FE020), as in icons.sh
local FOLDER = "\243\190\128\177"   -- Sumi Icons: folder (U+FE031), as in icons.sh

-- (a word in the line: a % in it is a %)
local function text(s) return (s:gsub("%%", "%%%%")) end

-- the file's path from the working folder (or the project's root), its last three parts: its
-- folders, and its name
local function path()
  local full = vim.api.nvim_buf_get_name(0)
  if full == "" then return "", "" end
  local name = full
  local cwd = vim.uv.cwd() or ""
  if full:sub(1, #cwd + 1) == cwd .. "/" then
    name = full:sub(#cwd + 2)
  else
    local root = LazyVim.root.get({ normalize = true })
    if full:sub(1, #root + 1) == root .. "/" then name = full:sub(#root + 2) end
  end
  local parts = vim.split(name, "/", { plain = true })
  local dir = #parts > 1 and table.concat(parts, "/", math.max(1, #parts - 2), #parts - 1) .. "/" or ""
  local file = vim.bo.modified and "%#KawaStChanged#" or "%#KawaStFile#"
  return "%#KawaStQuiet#" .. text(dir), file .. text(parts[#parts]) .. (vim.bo.readonly and " " .. LOCK or "")
end

-- the project's name, when it is not the folder neovim was started in
local function root()
  local r = LazyVim.root.get({ normalize = true })
  if r == vim.uv.cwd() then return "" end
  return "%#KawaStRoot# " .. FOLDER .. " " .. text(vim.fs.basename(r))
end

local SEVERITY = { { "ERROR", "Error" }, { "WARN", "Warn" }, { "INFO", "Info" }, { "HINT", "Hint" } }
local function diagnostics()
  local counts = vim.diagnostic.count(0)
  local icons = LazyVim.config.icons.diagnostics
  local out = ""
  for _, d in ipairs(SEVERITY) do
    local n = counts[vim.diagnostic.severity[d[1]]]
    if n then out = out .. "%#KawaSt" .. d[2] .. "#" .. icons[d[2]] .. n .. " " end
  end
  return out == "" and "" or " " .. out
end

-- what gitsigns counted in this file
local function changes()
  local g = vim.b.gitsigns_status_dict
  if not g then return "" end
  local icons = LazyVim.config.icons.git
  local out = ""
  if (g.added or 0) > 0 then out = out .. "%#KawaStAdded#" .. icons.added .. g.added .. " " end
  if (g.changed or 0) > 0 then out = out .. "%#KawaStModified#" .. icons.modified .. g.changed .. " " end
  if (g.removed or 0) > 0 then out = out .. "%#KawaStRemoved#" .. icons.removed .. g.removed .. " " end
  return out
end

-- a language server at work: its name and how far it is, until it says it has finished
local busy = ""
local function on_progress(ev)
  local value = ev.data.params.value
  local client = vim.lsp.get_client_by_id(ev.data.client_id)
  if value.kind == "end" or not client then
    busy = ""
  else
    busy = client.name .. (value.percentage and " " .. value.percentage .. "%" or "")
  end
  vim.cmd.redrawstatus()
end

-- where the cursor is, in the file's symbols (Trouble's, from the first server that has them)
local symbols
local function here()
  if not (symbols and vim.b.trouble_lualine ~= false and symbols.has()) then return "" end
  return " " .. symbols.get()
end

-- A window too narrow for the whole line loses whole pieces, the least needed first, and never one
-- cut in its middle (neovim's own cut, %<, left "kawa.py<op   1:1" at 80 columns, no place at 60)
local GIVE_WAY = { "here", "busy", "root", "dap", "kind", "dir", "changes", "branch", "where", "diagnostics", "rec", "name", "place" }

-- the cells a piece takes: colours, the fill and a %'s escape take none
local function cells(s)
  return vim.api.nvim_strwidth((s:gsub("%%#[^#]*#", ""):gsub("%%[*=]", ""):gsub("%%%%", "%%")))
end

local function join(p)
  return p.tile .. p.branch .. p.root .. p.diagnostics .. "%#KawaStQuiet#" .. p.kind .. " " .. p.dir .. p.name
    .. "%#KawaStQuiet#" .. p.here .. "%=" .. p.busy .. p.rec .. p.dap .. p.changes .. p.where .. p.place
end

function M.render()
  -- (the first screen: the terminal's own ground, as the rest of it)
  if vim.bo.filetype == "snacks_dashboard" then return "%#Normal#" end
  local mode = MODES[vim.api.nvim_get_mode().mode] or UNKNOWN
  local head = vim.b.gitsigns_head or vim.g.gitsigns_head or ""
  local dir, name = path()
  local rec = vim.fn.reg_recording()
  local dap = package.loaded["dap"] and require("dap").status() or ""
  -- the place: Top, Bot or its percent, the line, the column
  local line, last = vim.fn.line("."), vim.fn.line("$")
  local where = line == 1 and "Top" or line == last and "Bot" or string.format("%2d%%%%", math.floor(line / last * 100))
  local p = {
    tile = "%#KawaSt" .. mode[2] .. "# " .. mode[1] .. " ",
    branch = head ~= "" and "%#KawaStKey# " .. text(head) .. " " or "",
    root = root(),
    diagnostics = diagnostics(),
    kind = vim.bo.filetype ~= "" and " " .. text(vim.bo.filetype) or "",
    dir = dir,
    name = name,
    here = here(),
    busy = busy ~= "" and "%#KawaStQuiet#" .. text(busy) .. " " or "",
    rec = rec ~= "" and "%#KawaStRecording#recording @" .. rec .. " " or "",
    dap = dap ~= "" and "%#KawaStDebug# " .. text(dap) .. " " or "",
    changes = changes(),
    where = "%#KawaStKey# " .. where,
    place = "%#KawaStKey#" .. string.format(" %3d:%-2d ", line, vim.fn.charcol(".")),
  }
  local whole = join(p)
  local over = cells(whole) - vim.o.columns
  if over <= 0 then return whole end
  for _, piece in ipairs(GIVE_WAY) do
    over = over - cells(p[piece])
    p[piece] = ""
    if over <= 0 then break end
  end
  return join(p)
end

function M.setup()
  -- (no 'showcmd': it has no row here, and in this line it flashed LazyVim's "gj" at every j — a
  -- frame of its own before the key's; which-key shows what a pending key can become)
  vim.o.showcmd = false
  vim.o.statusline = "%!v:lua.require'config.statusline'.render()"
  local group = vim.api.nvim_create_augroup("kawa_statusline", { clear = true })
  -- what the line says and neovim does not know it says: drawn again when that changes
  vim.api.nvim_create_autocmd({ "ModeChanged", "DiagnosticChanged", "RecordingEnter", "RecordingLeave" }, {
    group = group, callback = function() vim.cmd.redrawstatus() end,
  })
  vim.api.nvim_create_autocmd("User", {
    group = group, pattern = { "GitSignsUpdate", "DapProgressUpdate" }, callback = function() vim.cmd.redrawstatus() end,
  })
  vim.api.nvim_create_autocmd("LspProgress", { group = group, callback = on_progress })
  vim.api.nvim_create_autocmd("LspAttach", {
    group = group,
    callback = function(ev)
      local client = vim.lsp.get_client_by_id(ev.data.client_id)
      if symbols or not (client and client:supports_method("textDocument/documentSymbol")) then return end
      symbols = require("trouble").statusline({
        mode = "symbols", groups = {}, title = false, filter = { range = true },
        format = "{kind_icon}{symbol.name:Normal}", hl_group = "KawaStQuiet",
      })
    end,
  })
  -- the command line opens on this line's own row: the same rows are left for the text, so nothing
  -- above moves, and no row stays empty the rest of the time. Both options in one step, in the same
  -- frame (ui2 would close its window a tick later: a frame of this line one row too high)
  if vim.o.cmdheight ~= 0 then return end   -- (a neovim without ui2: its own row, nothing to lend)
  local function rows(height, status)
    if vim.v.event.cmdlevel ~= 1 then return end   -- (Ctrl+R = inside a command line: the outer one stays)
    vim.cmd("noautocmd set cmdheight=" .. height)
    vim.o.laststatus = status
  end
  vim.api.nvim_create_autocmd("CmdlineEnter", { group = group, callback = function() rows(1, 0) end })
  vim.api.nvim_create_autocmd("CmdlineLeave", { group = group, callback = function() rows(0, 3) end })
end

return M
