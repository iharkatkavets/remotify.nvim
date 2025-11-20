-- lua/remotify/core/tables.lua

local M = {}

--- Render a value as a string, with special handling for tables.
--- Tables are mapped through `tostring` and concatenated without separators.
---@param x any value or string[]-like table
---@return string repr empty for nil, raw string for strings, concatenated entries for tables
function M.to_string(x)
	if x == nil then
		return ""
	end
	if type(x) == "string" then
		return x
	end
	if type(x) == "table" then
		return table.concat(vim.tbl_map(tostring, x))
	end
	return tostring(x)
end

return M
