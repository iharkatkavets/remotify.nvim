-- lua/remotify/log.lua

local config = require("remotify.config")

local M = {}

local logfile = vim.fn.stdpath("log") .. "/remotify.log"
local errf = require("remotify.core.errf").errf

local levels = { error = 1, warn = 2, info = 3, debug = 4 }
local current_level = levels.info

local function set_level(level)
	current_level = levels[level] or levels.info
end

local function timestamp()
	return os.date("%a %b %d %H:%M:%S %Y")
end

local function format(msg, level)
	local info = debug.getinfo(4, "Sl") -- file + line of caller
	local file = info.short_src or "?"
	local line = info.currentline or 0
	return string.format("[%s  %s] %s:%d: %s\n", level, timestamp(), file, line, msg)
end

local function sync_level_from_config()
	local cfg = config.get()
	if cfg and cfg.log_level then
		set_level(cfg.log_level)
	end
end

sync_level_from_config()

local function write(level, msg)
	sync_level_from_config()
	if levels[level] > current_level then
		return
	end
	local f = io.open(logfile, "a")
	if not f then
		vim.notify(errf("remotify.log: cannot open " .. logfile), vim.log.levels.ERROR)
		return
	end
	f:write(format(msg, level:upper()))
	f:close()
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

M.logfile = logfile

return M
