-- lua/remotify/history/push.lua

local errf = require("remotify.core.errf").errf

local M = {}

local uv = vim.uv or vim.loop

local function state_file()
	return vim.fn.stdpath("state") .. "/remotify/push_history.json"
end

local function ensure_dir(path)
	vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
end

local function read_file(path)
	local f = io.open(path, "rb")
	if not f then
		return nil
	end
	local s = f:read("*a")
	f:close()
	return s
end

local function write_file_atomic(path, data, log)
	vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")

	local tmp = path .. ".tmp"

	local f, err = io.open(tmp, "wb")
	if not f then
		errf("push_history: failed to open tmp file: " .. err)
		return nil, err
	end

	local ok, write_err = f:write(data)
	if not ok then
		f:close()
		errf("push_history: failed to write tmp file: " .. write_err)
		return nil, write_err
	end

	f:flush()
	f:close()

	local ok_rename, rename_err = os.rename(tmp, path)
	if not ok_rename then
		errf("push_history: failed to rename tmp file: " .. rename_err)
		return nil, rename_err
	end

	return true
end

local function load()
	local s = read_file(state_file())
	if not s or s == "" then
		return { version = 1, items = {} }
	end

	local ok, decoded = pcall(vim.json.decode, s)
	if not ok or type(decoded) ~= "table" then
		return { version = 1, items = {} }
	end

	decoded.version = decoded.version or 1
	decoded.items = decoded.items or {}
	return decoded
end

local function save(db)
	write_file_atomic(state_file(), vim.json.encode(db))
end

function M.get(local_dir)
	local db = load()
	return db.items[local_dir]
end

function M.set(local_dir, ssh_conn, remote_dir)
	local db = load()
	db.items[local_dir] = {
		ssh_conn = ssh_conn,
		remote_dir = remote_dir,
		updated_at_unix = os.time(),
	}
	save(db)
end

function M.prune(max_items)
	local db = load()
	local entries = {}
	for k, v in pairs(db.items) do
		entries[#entries + 1] = { k = k, t = tonumber(v.updated_at_unix) or 0 }
	end
	table.sort(entries, function(a, b)
		return a.t > b.t
	end)

	local keep = {}
	for i = 1, math.min(max_items or 200, #entries) do
		local key = entries[i].k
		keep[key] = db.items[key]
	end
	db.items = keep
	save(db)
end

return M
