-- lua/remotify/core/confirm.lua

local M = {}

function M.push(ssh_conn, remote_dir)
	local remote = {}
	if ssh_conn and ssh_conn.user and #ssh_conn.user then
		table.insert(remote, ssh_conn.user)
		table.insert(remote, "@")
	end
	if ssh_conn and ssh_conn.host and #ssh_conn.host then
		table.insert(remote, ssh_conn.host)
	end
	table.insert(remote, ":")
	table.insert(remote, remote_dir)
	local choice = vim.fn.confirm(
		"Do you want upload to " .. "" .. table.concat(remote, "") .. " ?",
		"&Yes\n&No",
		2 -- default choice = 2 (No)
	)
	return choice == 1
end

return M
