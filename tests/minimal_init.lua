-- TODO: Don't use vim.fs.joinpath, it's a nvim-0.10 feature
vim.fs.joinpath = vim.fs.joinpath
    or function(...)
        local path = table.concat({ ... }, "/")
        path = string.gsub(path, "//", "/")
        return path
    end

local root_path = vim.fn.fnamemodify(".", ":p")
local temp_path = vim.fs.joinpath(root_path, ".tests")

---@param name string directory name relative to test path
---@return string dir_path
local function path(name)
    return vim.fs.joinpath(temp_path, name)
end

---@param repo_name string the git repo name
local function install(repo_name)
    local pack_path = path("site/pack/deps/start")
    local plug_name = string.match(repo_name, ".*/(.*)")
    local plug_path = vim.fs.joinpath(pack_path, plug_name)
    local repo_url = string.format("https://github.com/%s.git", repo_name)

    if not vim.loop.fs_stat(plug_path) then
        print("Installing: " .. plug_name)
        vim.fn.mkdir(pack_path, "p")
        vim.fn.system({
            "git",
            "clone",
            "--depth=1",
            repo_url,
            plug_path,
        })
    end
end

vim.opt.runtimepath = { vim.env.VIMRUNTIME, root_path }
vim.opt.packpath = { path("site") }

install("nvim-lua/plenary.nvim")

-- stylua: ignore start
vim.env.XDG_CACHE_HOME  = path("cache")
vim.env.XDG_CONFIG_HOME = path("config")
vim.env.XDG_DATA_HOME   = path("data")
vim.env.XDG_STATE_HOME  = path("state")
-- stylua: ignore end
