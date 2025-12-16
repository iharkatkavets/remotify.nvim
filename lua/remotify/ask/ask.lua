-- lua/remotify/ask/ask.lua

local prompt = require("remotify.prompt")
local ssh_login = require("remotify.tools.ssh_login")
local cfgmod = require("remotify.config")
local errf = require("remotify.core.errf").errf

local M = {}

--- Ask for SSH login (callback style).
--- completion(result, err):
---   - success: completion(result, nil)
---   - error:   completion(nil, err)
function M.ssh_login(completion)
	local cfg = cfgmod.get()
	local default_remote = (cfg.default_remote and ("ssh " .. cfg.default_remote)) or "ssh "

	prompt.input({
		prompt = "Enter ssh login (e.g. ssh -i key user@host): ",
		default = default_remote,
		key = "remotify_ssh_login",
	}, function(user_input)
		if not user_input then
			return completion(nil, errf("cancelled"))
		end
		local conn, perr = ssh_login.parse(user_input)
		if not conn then
			return completion(nil, perr)
		end
		completion(conn)
	end)
end

--- Ask for SSH login (coroutine/await style).
--- Usage:
---   local co = coroutine.create(function()
---     local conn, err = require("remotify.prompts.ssh").ask_ssh_login_async()
---   end)
---@return table|nil, string|nil
function M.ssh_login_async()
	local cfg = cfgmod.get()
	local default_remote = (cfg.default_remote and ("ssh " .. cfg.default_remote)) or "ssh "
	local user_input = prompt.input_async({
		prompt = "Enter ssh login (e.g. ssh -i key user@host): ",
		default = default_remote,
		key = "remotify_ssh_login",
	})
	if not user_input then
		return nil, errf("cancelled")
	end
	local conn, perr = ssh_login.parse(user_input)
	if not conn then
		return nil, perr
	end
	return conn, nil
end

return M
