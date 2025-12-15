-- lua/remotify/core/errf.lua

local M = {}

--- Format an error string with the caller's short source file as a prefix.
---@param msg string human-readable error message
---@return string formatted_error "<caller>: <msg>" (falls back to "unknown" if source missing)
function M.errf(msg)
	local info = debug.getinfo(2, "S")
	local file = info and info.short_src or "unknown"
	return string.format("%s: %s\n", file, msg)
end

return M
