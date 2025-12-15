-- lua/remotify/tools/scp_commands.lua

local M = {}

M.make_copy_from_remote = function(conn, remote_dir, local_dir)
	local args = { "scp", "-r", "-q" }

	if conn.key and #conn.key > 0 then
		table.insert(args, "-i")
		table.insert(args, conn.key)
	end
	-- IMPORTANT: scp uses -P (capital P) for port (ssh uses -p)
	if conn.port then
		table.insert(args, "-P")
		table.insert(args, tostring(conn.port))
	end

	local target = (conn.user and #conn.user > 0) and (conn.user .. "@" .. conn.host) or conn.host

	table.insert(args, (target .. ":" .. remote_dir))
	table.insert(args, local_dir)
	return args
end

return M
