-- lua/remotify/tools/ssh.lua

local ssh_commands = require("remotify.tools.ssh_commands")
local log = require("remotify.tools.log")
local strings = require("remotify.core.strings")
local tables = require("remotify.core.tables")
local errf = require("remotify.core.errf").errf

local M = {}

---@alias ConnectAndExecCallback fun(err: string|nil, code: integer|nil, stdout: string[], stderr: string[])

--- Connect and execute the command.
---
---@param cmd string[]
---@param callback ConnectAndExecCallback
---@return nil
M.connect_and_exec = function(cmd, callback)
  log.debug(cmd)
  local ok, proc_or_err = pcall(vim.system, cmd, { text = true }, function(res)
    local stdout = res.stdout or ""
    local stderr = res.stderr or ""
    local out_lines = strings.to_lines(stdout)
    local err_lines = strings.to_lines(stderr)

    vim.schedule(function()
      if res.code ~= 0 then
        callback(
          stderr ~= "" and stderr or ("process exited with code " .. tostring(res.code)),
          res.code,
          out_lines,
          err_lines
        )
      else
        callback(nil, res.code, out_lines, err_lines)
      end
    end)
  end)

  if not ok then
    callback(errf("failed to start process: " .. tostring(proc_or_err)), -1, {}, {})
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
