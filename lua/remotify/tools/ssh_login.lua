-- lua/remotify/tools/ssh_login_command

local M = {}

---@class SSHConn
---@field key string|nil
---@field port integer|nil
---@field user string|nil
---@field host string|nil

---@param cmd string
---@return SSHConn|nil result
---@return string|nil err
function M.parse(cmd)
	if not cmd or cmd:match("^%s*$") then
		return nil, "empty input"
	end

	local result = { key = nil, port = nil, user = nil, host = nil }

	local key = cmd:match("%-i%s+([^%s]+)")
	if key then
		result.key = key
	end

	local port = cmd:match("%-p%s+(%d+)")
	if port then
		result.port = tonumber(port)
	end

	local userhost = cmd:match("([%w._%-]+@[%w._%-]+)$") or cmd:match("([%w._%-]+)$")

	if userhost then
		local user, host = userhost:match("^(.-)@(.+)$")
		if user and host then
			result.user, result.host = user, host
		else
			result.host = userhost
		end
	else
		return nil, "missing host"
	end

	return result, nil
end

return M
