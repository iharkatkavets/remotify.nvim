-- lua/remotify/core/ui.lua

local M = {}

function M.confirm_directory(dir)
	local choice = vim.fn.confirm(
		"Do you want to select directory " .. dir .. "?",
		"&Yes\n&No",
		2 -- default choice = 2 (No)
	)
	return choice == 1
end

return M
