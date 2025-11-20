-- lua/remotify/tools/uri.lua

local M = {}

-- Accepts forms like:
--   host:/abs/remote/path
--   user@host:/abs/remote/path
--   host:/abs/remote/path
--   user@host
-- Returns table or nil+err
function M.parse_uri(s)
	s = s or ""
	s = s:gsub("^%s+", ""):gsub("%s+$", "")
	if s == "" then
		return nil, "Empty input"
	end

	local user, host, path

	-- user@host:/path
	user, host, path = s:match("^([%w._%-]+)@([%w%.-]+):(/.+)$")
	if user and host then
		return { user = user, host = host, path = path }
	end

	-- host:/path  (user default)
	host, path = s:match("^([%w%.-]+):(/.+)$")
	if host then
		return { host = host, path = path }
	end

	-- user@host  (ask path later)
	user, host = s:match("^([%w._%-]+)@([%w%.-]+)$")
	if user and host then
		return { user = user, host = host }
	end

	-- host only
	host = s:match("^([%w%.-]+)$")
	if host then
		return { host = host }
	end

	return nil, "Could not parse. Try user@host:/abs/path"
end

return M
