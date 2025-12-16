-- lua/remotify/push.lua

local ssh = require("remotify.tools.ssh")
local rsync = require("remotify.tools.rsync").rsync
local errf = require("remotify.core.errf").errf
local history = require("remotify.history.push")
local confirm = require("remotify.core.confirm")
local ask = require("remotify.ask.ask")

local M = {}

local function get_current_dir()
	return vim.loop.cwd()
end

local function notify_error(msg)
	vim.notify("Remotify: " .. msg, vim.log.levels.ERROR)
end

local function notify_info(msg)
	vim.notify("Remotify: " .. msg, vim.log.levels.INFO)
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
		if confirm.push(conn, remote_dir) then
			completion(remote_dir, nil)
			return
		end
		completion(nil, "Cancelled")
	end)
	p:open()
end

M.run = function()
	local local_dir = get_current_dir()

	local function perform_rsync(ssh_conn, remote_dir)
		local rsync_ok, rsync_err = rsync(ssh_conn, local_dir, remote_dir, true)
		if not rsync_ok then
			notify_error(rsync_err)
		else
			notify_info("rsync done")
		end
	end

	local prev = history.get(local_dir)
	if prev and prev.remote_dir and prev.ssh_conn and confirm.push(prev.ssh_conn, prev.remote_dir) then
		perform_rsync(prev.ssh_conn, prev.remote_dir)
		return
	end

	ask.ssh_login(function(ssh_conn, input_err)
		if input_err then
			notify_error(input_err)
			return
		end

		ssh.try_connect(ssh_conn, function(conn_err)
			if conn_err then
				notify_error(conn_err)
				return
			end

			ask_select_remote_dir(ssh_conn, function(remote_dir, dir_err)
				if dir_err then
					notify_error(dir_err)
					return
				end
				perform_rsync(ssh_conn, remote_dir)
				history.set(local_dir, ssh_conn, remote_dir)
			end)
		end)
	end)
end

return M
