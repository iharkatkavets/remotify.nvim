-- lua/remotify/pickers/explorer.lua

local ssh_commands = require("remotify.tools.ssh_commands")
local ssh = require("remotify.tools.ssh")
local log = require("remotify.tools.log")
local path = require("remotify.core.path")
local errf = require("remotify.core.errf").errf

local Explorer = {}
Explorer.__index = Explorer

local keymaps = {
  "   KEY(S)    COMMAND   ",
  "                       ",
  "  <enter> -> open dir  ",
  "        u -> up        ",
  "        r -> refresh   ",
  "        s -> select    ",
  "        m -> mkdir     ",
  "        q -> quit      ",
}

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

local function max_keymap_lenght()
  local max_length = 0
  for _, value in ipairs(keymaps) do
    max_length = math.max(max_length, #value)
  end
  return max_length
end

local function compute_layout(opts)
  local cols, lines = vim.o.columns, vim.o.lines
  local rel = opts.relative or "editor"

  -- base width/height from spec (with defaults)
  local total_width = resolve_dim(opts.width, cols, math.floor(cols * 0.6))
  local total_height = resolve_dim(opts.height, lines, math.floor(lines * 0.5))

  -- clamp to min/max (accept fractions too)
  local min_w = resolve_minmax(opts.min_width, cols)
  local max_w = resolve_minmax(opts.max_width, cols)
  local min_h = resolve_minmax(opts.min_height, lines)
  local max_h = resolve_minmax(opts.max_height, lines)
  total_width = clamp(total_width, min_w, max_w)
  total_height = clamp(total_height, min_h, max_h)

  local margin_t = opts.margin_top or 0
  local margin_b = opts.margin_bottom or 0
  local margin_l = opts.margin_left or 0
  local margin_r = opts.margin_right or 0

  -- working area
  local work_cols = cols - (margin_l + margin_r)
  local work_lines = lines - (margin_t + margin_b)

  -- ensure it fits working area
  total_width = math.min(total_width, work_cols)
  total_height = math.min(total_height, work_lines)

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
    row = math.max(margin_t, math.min(row, lines - total_height - margin_b))
    col = math.max(margin_l, math.min(col, cols - total_width - margin_r))
  else
    -- center by default (Telescope dropdown vibe)
    row = margin_t + math.floor((work_lines - total_height) / 3) -- a bit upper-third
    col = margin_l + math.floor((work_cols - total_width) / 2)
  end

  local keymaps_width = max_keymap_lenght()
  local files_width = total_width - keymaps_width - 2
  local keymaps_col = col + files_width + 2

  return {
    files_row = row,
    files_col = col,
    files_width = files_width,
    files_height = total_height,
    keymaps_row = row,
    keymaps_col = keymaps_col,
    keymaps_width = keymaps_width,
    keymaps_height = total_height,
    relative = rel,
  }
end

local function close(opts)
  if not opts then
    return
  end
  if opts.win and vim.api.nvim_win_is_valid(opts.win) then
    vim.api.nvim_win_close(opts.win, true)
  end
  if opts.opts and type(opts.opts.on_close) == "function" then
    pcall(opts.opts.on_close)
  end
end

local function present_explorer(opts)
  opts = opts or {}

  local layout = compute_layout(opts)
  local files_buf
  if opts.files_buf and vim.api.nvim_buf_is_valid(opts.files_buf) then
    files_buf = opts.files_buf
  else
    files_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = files_buf })
  end
  ---@cast files_buf integer
  ---
  local keymaps_buf
  if opts.keymaps_buf and vim.api.nvim_buf_is_valid(opts.keymaps_buf) then
    keymaps_buf = opts.keymaps_buf
  else
    keymaps_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = keymaps_buf })
  end
  ---@cast keymaps_buf integer

  vim.api.nvim_buf_set_lines(keymaps_buf, 0, -1, false, keymaps)

  local keymaps_win_opts = {
    relative = layout.relative,
    win = (layout.relative == "win") and (opts.win or 0) or nil,
    width = layout.keymaps_width,
    height = layout.keymaps_height,
    row = layout.keymaps_row,
    col = layout.keymaps_col,
    style = "minimal",
    border = opts.border or "rounded",
    title = opts.keymaps_title or " Keymaps ",
    title_pos = opts.keymaps_title_pos or "center",
    zindex = opts.zindex,
    focusable = opts.focusable ~= false,
  }
  local keymaps_win = vim.api.nvim_open_win(keymaps_buf, true, keymaps_win_opts)

  if is_num(opts.winblend) then
    vim.api.nvim_set_option_value("winblend", opts.winblend, { win = keymaps_win })
  end

  local ns = vim.api.nvim_create_namespace("remotify_keymaps")

  vim.api.nvim_set_hl(0, "RemotifyHeader", { link = "Title" })
  vim.api.nvim_set_hl(0, "RemotifyKeys", { link = "Special" })
  vim.api.nvim_set_hl(0, "RemotifyAction", { link = "Statement" })
  local c2, c5, c6 = 10, 13, 23
  local function hl(line, start_col, end_col, group)
    vim.api.nvim_buf_set_extmark(keymaps_buf, ns, line, start_col, {
      end_col = end_col, -- end_col is enough for same-line highlight
      hl_group = group,
      hl_mode = "combine", -- combine with existing highlights
      priority = 200, -- ensure it wins if needed
    })
  end
  hl(0, 0, c6, "RemotifyHeader")
  for row = 2, #keymaps - 1 do
    hl(row, 0, c2, "RemotifyKeys")
    hl(row, c5, c6, "RemotifyAction")
  end

  local files_win_opts = {
    relative = layout.relative,
    win = (layout.relative == "win") and (opts.win or 0) or nil,
    width = layout.files_width,
    height = layout.files_height,
    row = layout.files_row,
    col = layout.files_col,
    style = "minimal",
    border = opts.border or "rounded",
    title = opts.files_title,
    title_pos = opts.files_title_pos or "center",
    zindex = opts.zindex,
    focusable = opts.focusable ~= false,
  }
  local files_win = vim.api.nvim_open_win(files_buf, true, files_win_opts)

  if is_num(opts.winblend) then
    vim.api.nvim_set_option_value("winblend", opts.winblend, { win = files_win })
  end

  return {
    files_buf = files_buf,
    files_win = files_win,
    files_width = layout.files_width,
    files_height = layout.files_height,
    files_row = layout.files_row,
    files_col = layout.files_col,
    keymaps_buf = keymaps_buf,
    keymaps_win = keymaps_win,
    keymaps_width = layout.keymaps_width,
    keymaps_height = layout.keymaps_height,
    keymaps_row = layout.keymaps_row,
    keymaps_col = layout.keymaps_col,
    opts = opts,
  }
end

local function reposition(h, patch)
  if not (h and h.files_win and vim.api.nvim_win_is_valid(h.files_win)) then
    return
  end
  h.opts = vim.tbl_deep_extend("force", h.opts or {}, patch or {})
  local row, col, width, height = compute_layout(h.opts)
  h.row, h.col, h.width, h.height = row, col, width, height
  vim.api.nvim_win_set_config(h.files_win, {
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
    vim.api.nvim_set_option_value("winblend", h.opts.winblend, { win = h.files_win })
  end
end

---@class Explorer
---@field login SSHConn
function Explorer.new(login, completion)
  local self = setmetatable({}, Explorer)
  self.login = login
  self.home = nil
  self.cwd = nil
  self.entries = {}
  self.completion = completion
  return self
end

function Explorer:resolve_home(cb)
  local argv = {
    "ssh",
  }
  if self.login.key and #self.login.key then
    table.insert(argv, "-i")
    table.insert(argv, self.login.key)
    table.insert(argv, "-o")
    table.insert(argv, "BatchMode=yes")
  end
  table.insert(argv, (self.login.user and (self.login.user .. "@" .. self.login.host)) or self.login.host)
  table.insert(argv, 'printf %s "$HOME"')
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

---Ask user for a directory name.
---Callback receives (result, err):
---  result : string|nil   -- the entered name
---  err    : string|nil   -- error message if cancelled or empty
local function ask_for_dir_name(cb)
  vim.ui.input({ prompt = "Enter name: ", default = "" }, function(text)
    if text == nil then
      cb(nil, errf("Cancelled"))
      return
    end
    if #text == 0 then
      cb(nil, errf("Empty name"))
      return
    end
    cb(text, nil)
  end)
end

function Explorer:make_title()
  local header_path = make_current_path(self.home, self.cwd or "")
  local header = (" [ %s ] "):format(header_path)
  return header
end

function Explorer:display_title()
  vim.api.nvim_win_set_config(self.state.files_win, {
    title = self:make_title(),
    title_pos = "left",
  })
end

-- Render helper: writes lines to the float’s buffer
function Explorer:render(lines)
  local buf = self.state.files_buf
  vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
  -- put cursor on first entry line (if any)
  if #lines > 2 then
    vim.api.nvim_win_set_cursor(self.state.files_win, { 1, 0 })
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
  local row = vim.api.nvim_win_get_cursor(self.state.files_win)[1]
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
  local row = vim.api.nvim_win_get_cursor(self.state.files_win)[1]
  local idx = row
  local entry = self.entries and self.entries[idx]
  if not entry then
    return
  end

  if entry:sub(-1) == "/" then
    local name = entry:sub(1, -2)
    local next_path = self.cwd == "/" and ("/" .. name) or path.join(self.cwd, name)
    close({ buf = self.state.files_buf, win = self.state.files_win })
    close({ buf = self.state.keymaps_buf, win = self.state.keymaps_win })
    self.completion(nil, next_path)
  else
    local full = self.cwd == "/" and ("/" .. entry) or path.join(self.cwd, entry)
    vim.notify("Remotify: can't select file " .. full, vim.log.levels.ERROR)
  end
end

function Explorer:make_dir()
  ask_for_dir_name(function(name, derr)
    if not name then
      vim.notify("Remotify: can't make dir" .. derr, vim.log.levels.ERROR)
      return
    end
    local full = self.cwd == "/" and ("/" .. name) or path.join(self.cwd, name)
    local args = { "-p", full }
    local argv, merr = ssh_commands.make_cmd(self.login, "mkdir", args)
    if not argv then
      vim.notify("Remotify: " .. tostring(merr), vim.log.levels.ERROR)
      return
    end

    ssh.connect_and_exec(argv, function(ssh_err, code, _, errlines)
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
      self.list(self, self.cwd)
    end)
  end)
end

function Explorer:up()
  self:list(path.parent_path(self.cwd or "/"))
end

function Explorer:open()
  self.state = present_explorer({
    strategy = "center",
    width = 0.6,
    height = 0.5,
    winblend = 8,
    files_title = self:make_title(),
    files_title_pos = "left",
    keymaps_title = " Keymaps ",
    keymaps_title_pos = "center",
  })

  -- Keymaps scoped to the floating buffer
  local buf = self.state.files_buf
  local map = function(lhs, fn)
    vim.keymap.set("n", lhs, fn, { buffer = buf, nowait = true, silent = true })
  end
  map("<CR>", function()
    self:enter()
  end)
  map("u", function()
    self:up()
  end)
  map("r", function()
    self:list(self.cwd)
  end)
  map("q", function()
    close({ buf = self.state.files_buf, win = self.state.files_win })
    close({ buf = self.state.keymaps_buf, win = self.state.keymaps_win })
  end)
  map("s", function()
    self:select_and_close()
  end)
  map("m", function()
    self:make_dir()
  end)
  -- automatically close when leaving the window
  vim.api.nvim_create_autocmd("WinLeave", {
    buffer = buf,
    once = true,
    callback = function()
      if vim.api.nvim_win_is_valid(self.state.files_win) then
        vim.api.nvim_win_close(self.state.files_win, true)
      end
    end,
  })

  self:resolve_home(function()
    self:list(self.home)
  end)
end

return Explorer
