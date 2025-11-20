-- lua/remotify/tools/scp.lua

local scp_commands = require("remotify.tools.scp_commands")
local log = require("remotify.tools.log")

local M = {}

---@param conn SSHConn
---@param remote_dir string
---@return boolean ok, string|nil err, string|nil local_dir
M.copy_from_remote = function(conn, remote_dir, local_dir)
	if not conn or not conn.host or remote_dir == nil or remote_dir == "" then
		return false, "missing connection or remote_dir"
	end

	local args = scp_commands.make_copy_from_remote(conn, remote_dir, local_dir)
	log.debug("scp with args " .. vim.inspect(args))

	-- Prefer vim.system (Neovim 0.10+). Falls back to jobstart if unavailable.
	if vim.system then
		local res = vim.system(args, { text = true }):wait()
		if res.code ~= 0 then
			return false, ("scp failed (%d): %s"):format(res.code, res.stderr or res.stdout or ""), nil
		end
	else
		-- Async fallback that blocks until exit using a simple latch
		local done, code, output = false, nil, ""
		vim.fn.jobstart(args, {
			stdout_buffered = true,
			stderr_buffered = true,
			on_stdout = function(_, data)
				output = output .. table.concat(data, "\n")
			end,
			on_stderr = function(_, data)
				output = output .. table.concat(data, "\n")
			end,
			on_exit = function(_, c)
				code = c
				done = true
			end,
		})
		-- crude wait loop; in real code, refactor to be async-friendly
		local start = vim.loop.hrtime()
		while not done do
			if (vim.loop.hrtime() - start) / 1e9 > 300 then
				return false, "scp timed out after 300s", nil
			end
			vim.wait(20) -- yield
		end
		if code ~= 0 then
			return false, ("scp failed (%d): %s"):format(code or -1, output), nil
		end
	end
	return true
end

return M
