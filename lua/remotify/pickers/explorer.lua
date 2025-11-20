-- lua/remotify/pickers/explorer.lua

local floating = require("remotify.floating.floating")
local ssh_commands = require("remotify.tools.ssh_commands")
local ssh = require("remotify.tools.ssh")
local log = require("remotify.tools.log")
local path = require("remotify.core.path")

local Explorer = {}
Explorer.__index = Explorer

---@class RemotifyExplorer
---@field login table
function Explorer.new(login, completion)
	local self = setmetatable({}, Explorer)
	self.login = login
	self.home = nil
	self.cwd = nil
	self.entries = {}
	self.completion = completion
	return self
end

-- resolve remote $HOME once
function Explorer:resolve_home(cb)
	local argv = {
		"ssh",
		"-o",
		"BatchMode=yes",
		(self.login.user and (self.login.user .. "@" .. self.login.host)) or self.login.host,
		'printf %s "$HOME"',
	} -- one string => remote shell expands $HOME
	ssh.connect_and_exec(argv, function(ssh_err, code, outlines, errlines)
		if ssh_err then
			vim.notify("Remotify: " .. tostring(ssh_err), vim.log.levels.ERROR)
			return
		end
		if code ~= 0 and #errlines > 0 then
			vim.schedule(function()
				vim.notify(table.concat(errlines, "\n"), vim.log.levels.ERROR)
			end)
			return
		end
		local home = table.concat(outlines, "\n"):gsub("%s+$", "")
		if home == "" then
			home = "/" -- very defensive fallback
		end
		self.home = home
		self.cwd = home
		vim.schedule(cb)
	end)
end

-- show `~` in the header if path starts with home
local function make_current_path(home, p)
	if not home or not p then
		return p
	end
	if p == home then
		return "~"
	end
	if p:sub(1, #home + 1) == home .. "/" then
		return "~" .. p:sub(#home + 1)
	end
	return p
end

function Explorer:make_title()
	local header_path = make_current_path(self.home, self.cwd or "")
	local header = ("[%s]  (<Enter>: open dir • h: up • r: refresh • q: quit • s: select)"):format(header_path)
	return header
end

function Explorer:display_title()
	vim.api.nvim_win_set_config(self.handle.win, {
		title = self:make_title(),
		title_pos = "left",
	})
end

-- Render helper: writes lines to the float’s buffer
function Explorer:render(lines)
	local buf = self.handle.buf
	vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
	-- put cursor on first entry line (if any)
	if #lines > 2 then
		vim.api.nvim_win_set_cursor(self.handle.win, { 3, 0 })
	end
end

-- Parse `ls -1Ap` into sorted entries (dirs first, keep trailing "/")
local function parse_ls(raw)
	local out = {}
	for line in tostring(raw or ""):gmatch("[^\r\n]+") do
		if line ~= "." and line ~= ".." and line ~= "" then
			table.insert(out, line)
		end
	end
	table.sort(out, function(a, b)
		local ad, bd = a:sub(-1) == "/", b:sub(-1) == "/"
		if ad ~= bd then
			return ad
		end
		return a:lower() < b:lower()
	end)
	return out
end

-- Fetch directory listing and render
function Explorer:list(dir)
	log.debug("List dir: " .. dir)
	if dir then
		self.cwd = dir
	end
	local args = { "-1AF" }
	if self.cwd and self.cwd ~= "" then
		table.insert(args, self.cwd)
	end

	local argv, err = ssh_commands.make_cmd(self.login, "ls", args)
	if not argv then
		vim.notify("Remotify: " .. tostring(err), vim.log.levels.ERROR)
		return
	end

	self:display_title()

	ssh.connect_and_exec(argv, function(ssh_err, code, outlines, errlines)
		if ssh_err then
			vim.notify("Remotify: " .. tostring(ssh_err), vim.log.levels.ERROR)
			return
		end
		if code ~= 0 and #errlines > 0 then
			vim.schedule(function()
				vim.notify(table.concat(errlines, "\n"), vim.log.levels.ERROR)
			end)
			return
		end
		self.entries = parse_ls(table.concat(outlines, "\n"))
		local lines = {}
		for _, e in ipairs(self.entries) do
			table.insert(lines, e)
		end
		vim.schedule(function()
			self:render(lines)
		end)
	end)
end

-- enter/up use absolute paths
function Explorer:enter()
	local row = vim.api.nvim_win_get_cursor(self.handle.win)[1]
	local idx = row
	local entry = self.entries and self.entries[idx]
	if not entry then
		return
	end

	if entry:sub(-1) == "/" then
		local name = entry:sub(1, -2)
		local next_path = self.cwd == "/" and ("/" .. name) or path.join(self.cwd, name)
		self:list(next_path)
	else
		local full = self.cwd == "/" and ("/" .. entry) or path.join(self.cwd, entry)
		log.debug("File: " .. make_current_path(self.home, full))
	end
end
--
-- enter/up use absolute paths
function Explorer:select_and_close()
	local row = vim.api.nvim_win_get_cursor(self.handle.win)[1]
	local idx = row
	local entry = self.entries and self.entries[idx]
	if not entry then
		return
	end

	if entry:sub(-1) == "/" then
		local name = entry:sub(1, -2)
		local next_path = self.cwd == "/" and ("/" .. name) or path.join(self.cwd, name)
		vim.api.nvim_win_close(self.handle.win, true)
		self.completion(nil, next_path)
	else
		local full = self.cwd == "/" and ("/" .. entry) or path.join(self.cwd, entry)
		vim.notify("Remotify: can't select file " .. full, vim.log.levels.ERROR)
	end
end

function Explorer:up()
	self:list(path.parent_path(self.cwd or "/"))
end

function Explorer:open()
	self.handle = floating.present({
		strategy = "center",
		width = 0.6,
		height = 0.5,
		winblend = 8,
		title = self:make_title(),
		title_pos = "left",
	})

	-- Keymaps scoped to the floating buffer
	local buf = self.handle.buf
	local map = function(lhs, fn)
		vim.keymap.set("n", lhs, fn, { buffer = buf, nowait = true, silent = true })
	end
	map("<CR>", function()
		self:enter()
	end)
	map("h", function()
		self:up()
	end)
	map("r", function()
		self:list(self.cwd)
	end)
	map("q", function()
		vim.api.nvim_win_close(self.handle.win, true)
	end)
	map("s", function()
		self:select_and_close()
	end)
	-- automatically close when leaving the window
	vim.api.nvim_create_autocmd("WinLeave", {
		buffer = buf,
		once = true,
		callback = function()
			if vim.api.nvim_win_is_valid(self.handle.win) then
				vim.api.nvim_win_close(self.handle.win, true)
			end
		end,
	})

	-- initial fill
	self:resolve_home(function()
		self:list(self.home) -- start at real home dir; header shows "~"
	end)
end

return Explorer
