-- lua/remotify/core/strings.lua

local M = {}

--- Split a string into lines on `\r`/`\n`, dropping empty trailing newline.
---@param s string|nil input
---@return string[] lines table of lines
function M.to_lines(s)
	local t = {}
	for line in tostring(s or ""):gmatch("[^\r\n]+") do
		t[#t + 1] = line
	end
	return t
end

return M
