-- lua/remotify/tools/ssh.lua

local ssh_commands = require("remotify.tools.ssh_commands")
local log = require("remotify.tools.log")
local strings = require("remotify.core.strings")
local tables = require("remotify.core.tables")
local errf = require("remotify.core.errf").errf

local M = {}

-- callback(err?: string, code?: integer, stdout?: string, stderr?: string)
M.connect_and_exec = function(cmd, callback)
	log.debug(cmd)
	local ok, sys = pcall(vim.system, cmd, { text = false }, function(res)
		log.debug("out_lines:" .. res.stdout)
		log.debug("err_lines:" .. res.stderr)
		local out_lines = strings.to_lines(res.stdout)
		local err_lines = strings.to_lines(res.stderr)
		if res.code ~= 0 and res.stderr ~= "" then
			vim.schedule(function()
				callback(res.stderr, res.code, out_lines, err_lines)
			end)
		else
			vim.schedule(function()
				callback(nil, res.code, out_lines, err_lines)
			end)
		end
	end)
	if not ok then
		callback(errf("failed to start process: " .. tostring(sys)))
	end
end

-- callback(err?: string)
M.try_connect = function(conn, callback)
	local cmd, err = ssh_commands.make_connect(conn)
	if not cmd then
		callback(err or errf("failed to build ssh command"))
		return
	end

	M.connect_and_exec(cmd, function(conn_err, code, stdout, _)
		if conn_err then
			callback(conn_err)
		elseif code ~= 0 then
			callback(errf("failed to connect. error code " .. tostring(code)))
		elseif tables.to_string(stdout or "") ~= "true" then
			callback(errf("wrong response. expected 'true' but got '" .. tables.to_string(stdout) .. "'"))
		else
			callback(nil) -- success
		end
	end)
end

M.ls = function(conn, callback)
	local cmd, err = ssh_commands.make_ls(conn)
	if not cmd then
		callback(err or errf("failed to build ssh command"))
		return
	end
	M.connect_and_exec(cmd, callback)
end

return M
