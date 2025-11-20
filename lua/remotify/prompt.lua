-- lua/remotify/prompt.lua

local M = {}

-- simple in-memory history per prompt "key"
local _hist = {}

--- Show an input box with optional history and defaults.
---@param opts {prompt:string, default?:string, key?:string}
---@param cb fun(text:string|nil)
function M.input(opts, cb)
	local key = opts.key or opts.prompt
	local default = opts.default or (_hist[key] and _hist[key][1]) or ""

	vim.ui.input({ prompt = opts.prompt, default = default }, function(text)
		if text and #text > 0 then
			_hist[key] = _hist[key] or {}
			-- push to front, dedupe
			if _hist[key][1] ~= text then
				table.insert(_hist[key], 1, text)
			end
			-- cap history length
			if #_hist[key] > 20 then
				_hist[key][21] = nil
			end
		end
		cb(text)
	end)
end

--- Coroutine/await version (yield until user answers).
---@param opts table
---@return string|nil
function M.input_async(opts)
	return coroutine.yield(function(resume)
		M.input(opts, function(text)
			resume(text)
		end)
	end)
end

return M
