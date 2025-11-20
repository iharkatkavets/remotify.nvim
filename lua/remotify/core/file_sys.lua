-- lua/remotify/core/file_sys.lua

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

	local ok, err = pcall(vim.fn.mkdir, name, "p")
	if not ok or err ~= 1 then
		return nil, "Failed to create directory: " .. tostring(name)
	end

	return name, nil
end

return M
