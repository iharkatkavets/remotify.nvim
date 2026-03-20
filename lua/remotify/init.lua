-- lua/remotify/init.lua

local pull = require("remotify.commands.pull")
local config = require("remotify.config")
local push = require("remotify.commands.push")
local info = require("remotify.commands.info")

local M = {}

local create_commands = function()
  vim.api.nvim_create_user_command("RemotifyPull", function()
    pull.run()
  end, {
    desc = "Download remote folder",
  })
  vim.api.nvim_create_user_command("RemotifyPushHere", function()
    push.run()
  end, {
    desc = "Upload the current folder to selected remote",
  })
  vim.api.nvim_create_user_command("RemotifyPush", function()
    push.run()
  end, {
    desc = "Upload the folder to remote",
  })
  vim.api.nvim_create_user_command("RemotifyInfo", function()
    info.run()
  end, {
    desc = "Report the status",
  })
end

M.setup = function(opts)
  config.setup(opts)
  create_commands()
end

return M
