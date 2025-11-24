-- lua/remotify/tools/ssh_commands.lua

local errf = require("remotify.core.errf").errf

local M = {}

---@class SSHDest
---@field host string
---@field user? string
---@field port? integer
---@field tty? boolean        -- allocate TTY for sudo/top etc.

---@class ExecOpts
---@field cwd? string
---@field env? table<string,string>  -- e.g. { PATH="/usr/local/bin", FOO="bar" }
---@field shell? "sh"|"bash"         -- default "bash"
---@field login? boolean             -- run as login shell: bash -l -c

-- --- helpers ---------------------------------------------------------------

-- single-quote for POSIX shells: abc'd -> 'abc'"'"'d'
local function shell_quote(s)
	return "'" .. tostring(s):gsub("'", "'\"'\"'") .. "'"
end

M.make_base_cmd = function(conn)
	local cmd = { "ssh", "-o", "BatchMode=yes" }
	if conn and conn.tty then
		table.insert(cmd, "-t")
	end
	if conn and conn.port then
		table.insert(cmd, "-p")
		table.insert(cmd, tostring(conn.port))
	end
	if conn and conn.identity then
		table.insert(cmd, "-i")
		table.insert(cmd, conn.identity)
	end
	if conn and conn.host then
		local target = conn.user and (conn.user .. "@" .. conn.host) or conn.host
		table.insert(cmd, target)
	end
	return cmd, nil
end

-- Build a remote command string with env/cwd, safely quoted
local function build_remote_str(exec, args, opts)
	opts = opts or {}
	local parts = {}

	-- export env
	if opts.env then
		for k, v in pairs(opts.env) do
			table.insert(parts, "export " .. k .. "=" .. shell_quote(v) .. ";")
		end
	end

	-- cd cwd
	if opts.cwd then
		table.insert(parts, "cd " .. shell_quote(opts.cwd) .. " &&")
	end

	-- command + args
	table.insert(parts, exec)
	if args and #args > 0 then
		local q = {}
		for _, a in ipairs(args) do
			table.insert(q, shell_quote(a))
		end
		table.insert(parts, table.concat(q, " "))
	end

	return table.concat(parts, " ")
end

-- --- public API ------------------------------------------------------------

M.make_connect = function(conn)
	local cmd, err = M.make_base_cmd(conn)
	if not cmd then
		return nil, err
	end
	table.insert(cmd, "printf true")
	return cmd, nil
end

M.make_resolve_home = function(conn)
	local cmd, err = M.make_base_cmd(conn)
	if not cmd then
		return nil, err
	end
	table.insert(cmd, 'printf %s "$HOME"')
	return cmd, nil
end

--- Make a generic exec command:
--- ssh ... target [ bash -lc "<env+cd+exec args...>" ]
---@param login SSHDest
---@param exec string                 -- executable name (e.g., "ls", "cat", "echo")
---@param args? string[]              -- arguments list (each item safely quoted)
---@param opts? ExecOpts
---@return table|nil, string|nil
M.make_cmd = function(login, exec, args, opts)
	if not exec or exec == "" then
		return nil, errf("Remotify: exec is required")
	end
	local base, err = M.make_base_cmd(login)
	if not base then
		return nil, err
	end

	local remote_str = build_remote_str(exec, args or {}, opts)
	local shell = (opts and opts.shell) or nil
	local o_login = (opts and opts.login) and "-l" or nil

	if shell then
		-- Use explicit shell; combine -l and -c as -lc if login is requested
		table.insert(base, shell)
		if o_login then
			table.insert(base, "-lc")
		else
			table.insert(base, "-c")
		end
		table.insert(base, remote_str)
	else
		-- No explicit shell: ssh will run $SHELL -c "<remote_str>" remotely
		table.insert(base, remote_str)
	end
	return base, nil
end

return M
