-- lua/remotify/tools/rsync.lua

local ssh_commands = require("remotify.tools.ssh_commands")
local log = require("remotify.tools.log")

local M = {}

M.rsync = function(conn, src, dst, push)
	local args = { "rsync", "-az", "--delete", "-e", "ssh -o BatchMode=yes -T" }

	local target = (conn.user and #conn.user > 0) and (conn.user .. "@" .. conn.host) or conn.host

	if push then
		-- local -> remote
		table.insert(args, src .. "/") -- source
		table.insert(args, target .. ":" .. dst .. "/") -- dest
	else
		-- remote -> local
		table.insert(args, target .. ":" .. src .. "/") -- source
		table.insert(args, dst .. "/") -- dest
	end

	log.debug("rsync with args " .. vim.inspect(args))
	local res = vim.system(args, { text = true }):wait()
	if res.code ~= 0 then
		log.error(res.stderr or res.stdout or ("rsync failed, code " .. res.code))
		return false, res.stderr or res.stdout or ("rsync failed, code " .. res.code)
	end
	log.info("rsync success")
	return true
end

return M
