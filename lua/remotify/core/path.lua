-- lua/remotify/core/path.lua

local M = {}

--- Join two path segments with a single slash, preserving root `/`.
---@param a string left segment (may be "/")
---@param b string right segment (without leading slash)
---@return string joined absolute or relative path
M.join = function(a, b)
	return (a == "/" and "/" .. b) or (a .. "/" .. b)
end

--- Return the parent directory of a path, trimming trailing slashes.
---@param p string input path
---@return string parent absolute path ("/" when at root)
M.parent_path = function(p)
	local s = (p == "/" and "/") or p:gsub("/+$", "")
	local d = s:match("^(.*)/[^/]+$") or "/"
	return d ~= "" and d or "/"
end

return M
