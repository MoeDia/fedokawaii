-- apps.sh: Mason's registry and the tools LazyVim's first start installs (nvim --headless).
-- Mason asks the GitHub API (or api.mason-registry.dev) for the registry's latest release;
-- neither is reachable from this sandbox, so that one answer is given here
-- (APPS_MASON_REGISTRY_TAG, the newest tag `git ls-remote` lists). The registry itself and
-- every tool still come from GitHub release downloads, through Mason's own code.
local tag = os.getenv("APPS_MASON_REGISTRY_TAG")
local out = function(s) io.stdout:write(s .. "\n") end
require("lazy").load({ plugins = { "mason.nvim" } })
local Result = require("mason-core.result")
local providers = require("mason-core.providers")
if tag and tag ~= "" then
  providers.github.get_latest_release = function(repo)
    if repo == "mason-org/mason-registry" then
      return Result.success({ tag_name = tag })
    end
    return Result.failure("no GitHub API in this sandbox")
  end
end
local mr = require("mason-registry")
local ok_update = false
for attempt = 1, 2 do         -- (LazyVim's own refresh may have started before the answer above)
  local done = false
  mr.update(function(success)
    ok_update, done = success, true
  end)
  vim.wait(300000, function() return done end, 200)
  out("registry update " .. attempt .. ": " .. tostring(ok_update))
  if ok_update then break end
end
for _, s in ipairs(mr.sources.list or {}) do
  local src = s:get()
  out("registry: " .. src:get_display_name())
end
local want = { "stylua", "shfmt", "lua-language-server" }
local pending = 0
for _, name in ipairs(want) do
  local ok, p = pcall(mr.get_package, name)
  if not ok then
    out(name .. ": not in the registry")
  elseif p:is_installed() then
    out(name .. ": installed")
  elseif p:is_installing() then    -- LazyVim's config already started it (its ensure_installed)
    pending = pending + 1
    p:once("install:success", function() out(name .. ": installed") pending = pending - 1 end)
    p:once("install:failed", function() out(name .. ": FAILED") pending = pending - 1 end)
  else
    pending = pending + 1
    p:install({}, function(success, err)
      out(name .. ": " .. (success and "installed" or ("FAILED " .. tostring(err))))
      pending = pending - 1
    end)
  end
end
vim.wait(600000, function() return pending == 0 end, 200)
vim.cmd("qa")
