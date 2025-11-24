-- lua/remotify/core/file_sys.lua

local errf = require("remotify.core.errf").errf

local M = {}

---@param dir_name string|nil  -- directory name (optional)
---@return string|nil temp_dir  -- path to created local temp dir
---@return string|nil err        -- error message, if any
M.make_temp_dir = function(dir_name)
	local tmp_dir = vim.fn.tempname()
	local name

	if dir_name and #dir_name > 0 then
		local parent = vim.fn.fnamemodify(tmp_dir, ":h")
		name = parent .. "/" .. dir_name
	else
		name = tmp_dir
	end

	local ok, res = pcall(vim.fn.mkdir, name, "p")
	if not ok then
		return nil, errf("Failed to create directory: " .. tostring(res))
	end
	if res ~= 1 then
		return nil, errf("Failed to create directory (%s): %s"):format(tostring(name), tostring(res))
	end

	return name, nil
end

return M
