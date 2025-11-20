-- lua/remotify/push.lua

local ssh = require("remotify.tools.ssh")
local rsync = require("remotify.tools.rsync").rsync
local errf = require("remotify.core.errf").errf

local M = {}

local function get_current_dir()
	return vim.loop.cwd()
end

---@param conn SSHConn
---@param completion fun(result: string|nil, err: string|nil)
---@return nil
--- Ask the user to select a remote directory.
--- completion(result, err):
---   - success: completion(result, nil)
---   - error:   completion(nil, err)
local function ask_select_remote_dir(conn, completion)
	local explorer = require("remotify.pickers.explorer")
	local p = explorer.new(conn, function(exp_err, remote_dir)
		if exp_err or not remote_dir then
			completion(nil, exp_err or errf("No directory selected"))
			return
		end
		if require("remotify.core.ui").confirm_directory(remote_dir) then
			completion(remote_dir, nil)
			return
		end
		completion(nil, "Cancelled")
	end)
	p:open()
end

M.run = function()
	require("remotify.prompts.ssh").ask_ssh_login(function(conn, input_err)
		if input_err then
			vim.notify("Remotify: " .. input_err, vim.log.levels.ERROR)
			return
		end
		ssh.try_connect(conn, function(conn_err)
			if conn_err then
				vim.notify("Remotify: " .. conn_err, vim.log.levels.ERROR)
				return
			end
			ask_select_remote_dir(conn, function(remote_dir, err)
				if not remote_dir then
					vim.notify("Remotify: " .. err, vim.log.levels.ERROR)
					return
				end
				rsync(conn, get_current_dir(), remote_dir, true)
			end)
		end)
	end)
end

return M
