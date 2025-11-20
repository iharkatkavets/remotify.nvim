# Remotify.nvim

Browse a remote filesystem over SSH, pull a directory into a local temp workspace, and keep it in sync with the remote while you edit in Neovim.

## Requirements
- Neovim with Lua support (tested with 0.9+; uses `vim.system`/`vim.fs`).
- `ssh`, `scp`, and `rsync` available in `$PATH`; key-based auth is recommended (`ssh -o BatchMode=yes` is used).

## Setup
```lua
require("remotify").setup({
  default_remote = "user@host", -- prefill for the login prompt
  log_level = "info",
})
```
Add the plugin to your runtime path (e.g., via lazy.nvim, packer, etc.). No build step is needed.

## Commands
- `:RemotifyPull` — prompt for an SSH login, navigate remote directories in a floating picker, copy the chosen directory locally (temp dir), `:cd` into it, and enable sync-on-save to push edits back with `rsync`.
- `:RemotifyPushHere` — prompt for login, choose a remote directory, then push the current working directory to that remote path once via `rsync`.
- `:RemotifyPush` — presently the same as `:RemotifyPushHere` (reserved for a future variant).

Remote picker keys: `<CR>` to enter a directory, `h` to go up, `r` refresh, `s` select, `q` quit.

## Typical Workflow
1) Open Neovim in any directory and run `:RemotifyPull`.  
2) Enter a login (defaults to `ssh <default_remote>`), then pick the remote folder.  
3) Edit files in the pulled temp workspace; saves automatically push to the remote.  
4) For one-off uploads from your current project, run `:RemotifyPushHere` and pick the destination.

## Notes
- Logs are written to `stdpath("data")/remotify.log` when `log_level` allows; use them when debugging connection issues.
- `TODO.md` tracks planned work; check it before adding features.
