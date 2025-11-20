-- lua/remotify/log.lua

local M = {}

-- where to store log file
local logfile = vim.fn.stdpath("data") .. "/remotify.log"
local errf = require("remotify.core.errf").errf

-- levels
local levels = { error = 1, warn = 2, info = 3, debug = 4 }
local current_level = levels.debug -- change to "info" in production

-- internal write function
local function write(level, msg)
	if levels[level] > current_level then
		return
	end
	local f = io.open(logfile, "a")
	if not f then
		vim.notify(errf("remotify.log: cannot open " .. logfile), vim.log.levels.ERROR)
		return
	end
	local line = string.format("[%s][%s] %s\n", os.date("%H:%M:%S"), level:upper(), msg)
	f:write(line)
	f:close()

	-- optionally echo errors/warnings also in nvim
	if level == "error" or level == "warn" then
		vim.schedule(function()
			vim.notify(msg, level == "error" and vim.log.levels.ERROR or vim.log.levels.WARN, { title = "remotify" })
		end)
	end
end

M.debug = function(msg)
	write("debug", type(msg) == "table" and vim.inspect(msg) or tostring(msg))
end

M.info = function(msg)
	write("info", type(msg) == "table" and vim.inspect(msg) or tostring(msg))
end

M.warn = function(msg)
	write("warn", type(msg) == "table" and vim.inspect(msg) or tostring(msg))
end

M.error = function(msg)
	write("error", type(msg) == "table" and vim.inspect(msg) or tostring(msg))
end

-- expose the logfile path (for :edit or :vsplit)
M.logfile = logfile

return M
