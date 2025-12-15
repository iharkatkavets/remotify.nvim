-- lua/remotify/tools/rsync.lua

local errf = require("remotify.core.errf").errf
local log = require("remotify.tools.log")

local M = {}

--- Sync directories via rsync over SSH.
---@param conn SSHConn|SSHDest -- remote connection details
---@param src string           -- source directory (local if push=true, remote otherwise)
---@param dst string           -- destination directory
---@param push boolean         -- true for local->remote, false for remote->local
---@return boolean             -- ok, Always true on success
---@return string|nil          -- error  Always nil on success
M.rsync = function(conn, src, dst, push)
	local ssh_part = { "ssh", "-o", "BatchMode=yes", "-T" }
	if conn.port then
		table.insert(ssh_part, "-p")
		table.insert(ssh_part, tostring(conn.port))
	end
	if conn.key and #conn.key > 0 then
		table.insert(ssh_part, "-i")
		table.insert(ssh_part, vim.fn.shellescape(conn.key))
	end
	local args = { "rsync", "-az", "--delete", "-e", table.concat(ssh_part, " ") }
	local cfg = require("remotify.config").get()
	if cfg.ignore then
		for _, pattern in ipairs(cfg.ignore) do
			table.insert(args, "--exclude")
			table.insert(args, pattern)
		end
	end

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
		local msg = errf(res.stderr or res.stdout or string.format("rsync failed (exit code %d)", res.code))
		log.error(msg)
		return false, msg
	end
	log.info("rsync done")
	return true, nil
end

return M
