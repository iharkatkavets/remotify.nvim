-- lua/remotify/sync_on_save.lua

local rsync = require("remotify.tools.rsync").rsync
local log = require("remotify.tools.log")

local M = {}

-- robust normalizer: resolve symlinks + clean + strip trailing slashes
local function norm_real(p)
	if not p or p == "" then
		return ""
	end
	-- Neovim 0.10+: vim.uv == vim.loop
	local uv = vim.uv or vim.loop
	local real = uv.fs_realpath(p) or p
	real = vim.fs.normalize(real)
	-- strip trailing slashes (but keep root "/")
	real = real:gsub("/*$", "")
	if real == "" then
		real = "/"
	end
	return real
end

---@meta

---@class uv_timer
---@field start fun(self:uv_timer, timeout:integer, repeat_:integer, cb:fun())
---@field stop fun(self:uv_timer)
---@field close fun(self:uv_timer)

---@class uv
---@field new_timer fun():uv_timer
vim.loop = vim.loop

---@param conn SSHConn
---@param local_root string   -- local directory to mirror
---@param remote_root string  -- remote directory to mirror
---@param debounce_ms integer? -- optional debounce to avoid spamming rsync
function M.enable_on_save(conn, local_root, remote_root, debounce_ms)
	debounce_ms = debounce_ms or 300

	local aug = vim.api.nvim_create_augroup("RemotifySyncOnSave", { clear = true })

	-- simple debounce
	local timer = nil
	local function debounced_push()
		if timer then
			timer:stop()
			timer:close()
			timer = nil
		end
		timer = vim.loop.new_timer()
		timer:start(debounce_ms, 0, function()
			if timer then
				timer:stop()
				timer:close()
				timer = nil
			end
			vim.schedule(function()
				local ok, err = rsync(conn, local_root, remote_root, true) -- push local->remote
				if not ok then
					vim.notify("Remotify push failed: " .. (err or ""), vim.log.levels.ERROR)
				end
			end)
		end)
	end

	local_root = norm_real(local_root)
	log.debug("enable sync for " .. local_root)
	vim.api.nvim_create_autocmd("BufWritePost", {
		group = aug,
		pattern = "*",
		callback = function(args)
			local file = norm_real(vim.api.nvim_buf_get_name(args.buf))
			if file == "" then
				return
			end
			if file:sub(1, #local_root) ~= local_root then
				return
			end
			log.debug("BufWritePost on file: " .. file)
			debounced_push()
		end,
		desc = "Remotify: rsync push on save",
	})
end

function M.disable_on_save()
	pcall(vim.api.nvim_del_augroup_by_name, "RemotifySyncOnSave")
end

return M
