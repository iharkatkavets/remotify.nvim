-- lua/remotify/commands/pull.lua

local ssh = require("remotify.tools.ssh")
local scp = require("remotify.tools.scp")
local file_sys = require("remotify.core.file_sys")
local sync_on_save = require("remotify.sync_on_save")

local M = {}

local function confirm_directory(dir)
	local choice = vim.fn.confirm(
		"Do you want to select directory " .. dir .. "?",
		"&Yes\n&No",
		2 -- default choice = 2 (No)
	)

	if choice == 1 then
		return true -- Yes
	else
		return false -- No or Esc
	end
end

local function ask_select_remote_dir(conn, completion)
	local p = require("remotify.pickers.explorer").new(conn, function(exp_err, remote_dir)
		if not remote_dir then
			vim.notify("Remotify: " .. exp_err, vim.log.levels.ERROR)
			return
		end

		if confirm_directory(remote_dir) then
			completion(remote_dir)
			return
		end
	end)
	p:open()
end

local function copy_to_local_dir(conn, remote_dir, completion)
	local local_dir, derr = file_sys.make_temp_dir(nil)
	if not local_dir then
		vim.notify("Remotify: fail to create tmp dir" .. derr, vim.log.levels.ERROR)
		return
	end
	local ok, cp_err = scp.copy_from_remote(conn, remote_dir, local_dir)
	if not ok then
		vim.notify("Remotify: fail to copy remote dir" .. cp_err, vim.log.levels.ERROR)
		return
	end

	local working_dir = local_dir .. "/" .. vim.fn.fnamemodify(remote_dir, ":t")
	completion(working_dir)
end

local function start_rsync(conn, remote_dir, local_dir)
	vim.fn.chdir(local_dir)
	sync_on_save.enable_on_save(conn, local_dir, remote_dir)
end

M.run = function()
	require("remotify.prompts.ssh").ask_ssh_login(function(conn, _)
		if not conn then
			return
		end
		ssh.try_connect(conn, function(conn_err)
			if conn_err then
				vim.notify("Remotify: " .. conn_err, vim.log.levels.ERROR)
				return
			end
			ask_select_remote_dir(conn, function(remote_dir)
				copy_to_local_dir(conn, remote_dir, function(local_dir)
					start_rsync(conn, remote_dir, local_dir)
				end)
			end)
		end)
	end)
end

return M
