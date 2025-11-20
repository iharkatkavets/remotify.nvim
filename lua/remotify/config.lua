-- lua/remotify/config.lua

local M = {}

local defaults = {
	default_remote = "localhost",
	log_level = "info",
}

---@param opts table|nil
function M.setup(opts)
	-- Validate early (optional but nice)
	vim.validate({
		default_remote = { opts and opts.default_remote or defaults.default_remote, "string" },
		log_level = { opts and opts.log_level or defaults.log_level, "string" },
	})

	M._cfg = vim.tbl_deep_extend("force", defaults, opts or {})

	-- Make it read-only at runtime to avoid accidental mutation
	return setmetatable({}, {
		__index = function(_, k)
			return M._cfg[k]
		end,
		__newindex = function()
			error("remotify.config is read-only; use update()")
		end,
	})
end

function M.get()
	return M._cfg
end

---@param opts table
function M.update(opts)
	M._cfg = vim.tbl_deep_extend("force", M._cfg or {}, opts or {})
end

return M
