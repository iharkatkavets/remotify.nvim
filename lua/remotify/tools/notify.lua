-- lua/remotify/notify.lua

local M = {}

---@param msg string The message appeared in error log
M.error = function(msg)
  vim.notify("Remotify: " .. msg, vim.log.levels.ERROR)
end

---@param msg string The message appeared in info log
M.info = function(msg)
  vim.notify("Remotify: " .. msg, vim.log.levels.INFO)
end

return M
