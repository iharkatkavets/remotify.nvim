-- lua/remotify/floating/floating.lua

local M = {}

---@class FloatingOpts
---@field relative? "editor"|"win"|"cursor"          -- default "editor"
---@field win? integer                               -- when relative="win"
---@field strategy? "center"|"cursor"|"manual"       -- default "center"
---@field width? integer|number|fun(cols:integer, lines:integer):integer
---@field height? integer|number|fun(cols:integer, lines:integer):integer
---@field min_width? integer|number
---@field min_height? integer|number
---@field max_width? integer|number
---@field max_height? integer|number
---@field row? integer                                -- used in "manual"
---@field col? integer                                -- used in "manual"
---@field margin_top? integer
---@field margin_bottom? integer
---@field margin_left? integer
---@field margin_right? integer
---@field offset_row? integer                         -- extra offset (for cursor strategy)
---@field offset_col? integer
---@field border? string|table                        -- "rounded"|"single"|chars table
---@field title? string
---@field title_pos? "left"|"center"|"right"
---@field winblend? integer                           -- 0..100
---@field zindex? integer
---@field focusable? boolean                          -- default true
---@field no_default_maps? boolean
---@field buf? integer                                -- reuse buffer if valid
---@field on_close? fun()                             -- called after close

---@class FloatingHandle
---@field buf integer
---@field win integer
---@field width integer
---@field height integer
---@field row integer
---@field col integer
---@field opts FloatingOpts
---

local function is_num(x)
	return type(x) == "number"
end

local function resolve_dim(spec, total, default)
	if spec == nil then
		return default
	end
	if type(spec) == "function" then
		local ok, v = pcall(spec, vim.o.columns, vim.o.lines)
		if ok and is_num(v) then
			return math.floor(v)
		end
		return default
	elseif is_num(spec) then
		-- if 0 < spec <= 1 treat as fraction of total
		if spec > 0 and spec <= 1 then
			return math.max(1, math.floor(spec * total))
		else
			return math.max(1, math.floor(spec))
		end
	else
		return default
	end
end

local function clamp(v, vmin, vmax)
	if vmin and v < vmin then
		v = vmin
	end
	if vmax and v > vmax then
		v = vmax
	end
	return v
end

local function resolve_minmax(x, total)
	if x == nil then
		return nil
	end
	if is_num(x) and x > 0 and x <= 1 then
		return math.floor(total * x)
	end
	return x
end

local function compute_layout(opts)
	local cols, lines = vim.o.columns, vim.o.lines
	local rel = opts.relative or "editor"

	-- base width/height from spec (with defaults)
	local width = resolve_dim(opts.width, cols, math.floor(cols * 0.6))
	local height = resolve_dim(opts.height, lines, math.floor(lines * 0.5))

	-- clamp to min/max (accept fractions too)
	local min_w = resolve_minmax(opts.min_width, cols)
	local max_w = resolve_minmax(opts.max_width, cols)
	local min_h = resolve_minmax(opts.min_height, lines)
	local max_h = resolve_minmax(opts.max_height, lines)
	width = clamp(width, min_w, max_w)
	height = clamp(height, min_h, max_h)

	local margin_t = opts.margin_top or 0
	local margin_b = opts.margin_bottom or 0
	local margin_l = opts.margin_left or 0
	local margin_r = opts.margin_right or 0

	-- working area
	local work_cols = cols - (margin_l + margin_r)
	local work_lines = lines - (margin_t + margin_b)

	-- ensure it fits working area
	width = math.min(width, work_cols)
	height = math.min(height, work_lines)

	local row, col

	if (opts.strategy or "center") == "manual" and opts.row and opts.col then
		row, col = opts.row, opts.col
	elseif (opts.strategy or "center") == "cursor" then
		local cc = vim.api.nvim_win_get_cursor(0) -- {line, col} (1-based line)
		local c_row = cc[1]
		local c_col = cc[2]
		row = c_row + 1 + (opts.offset_row or 1)
		col = c_col + 1 + (opts.offset_col or 1)
		-- clamp into working area
		row = math.max(margin_t, math.min(row, lines - height - margin_b))
		col = math.max(margin_l, math.min(col, cols - width - margin_r))
	else
		-- center by default (Telescope dropdown vibe)
		row = margin_t + math.floor((work_lines - height) / 3) -- a bit upper-third
		col = margin_l + math.floor((work_cols - width) / 2)
	end

	return row, col, width, height, rel
end

-- --- public API ------------------------------------------------------------

---@param opts FloatingOpts
---@return FloatingHandle
M.present = function(opts)
	opts = opts or {}

	local row, col, width, height, relative = compute_layout(opts)

	local buf
	if opts.buf and vim.api.nvim_buf_is_valid(opts.buf) then
		buf = opts.buf
	else
		buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
	end
	---@cast buf integer

	local win_opts = {
		relative = relative,
		win = (relative == "win") and (opts.win or 0) or nil,
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = opts.border or "rounded",
		title = opts.title,
		title_pos = opts.title_pos or "center",
		zindex = opts.zindex,
		focusable = opts.focusable ~= false,
	}

	local win = vim.api.nvim_open_win(buf, true, win_opts)

	if is_num(opts.winblend) then
		vim.api.nvim_set_option_value("winblend", opts.winblend, { win = win })
	end

	if not opts.no_default_maps then
		vim.keymap.set("n", "q", function()
			M.close({ buf = buf, win = win, opts = opts })
		end, { buffer = buf, silent = true, noremap = true })
	end

	return {
		buf = buf,
		win = win,
		width = width,
		height = height,
		row = row,
		col = col,
		opts = opts,
	}
end

---@param h FloatingHandle
M.close = function(h)
	if not h then
		return
	end
	if h.win and vim.api.nvim_win_is_valid(h.win) then
		vim.api.nvim_win_close(h.win, true)
	end
	if h.opts and type(h.opts.on_close) == "function" then
		pcall(h.opts.on_close)
	end
end

---@param h FloatingHandle
---@param patch FloatingOpts
M.reposition = function(h, patch)
	if not (h and h.win and vim.api.nvim_win_is_valid(h.win)) then
		return
	end
	h.opts = vim.tbl_deep_extend("force", h.opts or {}, patch or {})
	local row, col, width, height = compute_layout(h.opts)
	h.row, h.col, h.width, h.height = row, col, width, height
	vim.api.nvim_win_set_config(h.win, {
		relative = h.opts.relative or "editor",
		win = ((h.opts.relative or "editor") == "win") and (h.opts.win or 0) or nil,
		width = width,
		height = height,
		row = row,
		col = col,
		border = h.opts.border or "rounded",
		title = h.opts.title,
		title_pos = h.opts.title_pos or "center",
		zindex = h.opts.zindex,
	})
	if is_num(h.opts.winblend) then
		vim.api.nvim_set_option_value("winblend", h.opts.winblend, { win = h.win })
	end
end

return M
