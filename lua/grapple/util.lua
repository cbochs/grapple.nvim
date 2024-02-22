local Util = {}

---@return "windows" | "macos" | "linux"
function Util.get_os()
    if vim.uv.os_uname().version:match("Windows") then
        return "windows"
    elseif vim.uv.os_uname().sysname == "Darwin" then
        return "macos"
    else
        return "linux"
    end
end

Util.os = Util.get_os()
Util.windows = Util.os == "windows"
Util.macos = Util.os == "macos"
Util.linux = Util.os == "linux"

---@param path string
---@return boolean
function Util.exists(path)
    local abs_path = Util.absolute(path)

    local permission = vim.uv.fs_access(abs_path, "R")
    if not permission then
        return false
    end

    return permission
end

---@param path string
---@return string abs_path
function Util.absolute(path)
    local norm_path = vim.fs.normalize(path)

    -- TODO: upwards relative paths are hard :p

    ---@type string
    ---@diagnostic disable-next-line: assign-type-mismatch
    local abs_path = vim.fn.fnamemodify(norm_path, ":p")

    return abs_path
end

---@param path string
---@return boolean
function Util.is_absolute(path)
    if Util.windows then
        return path:match("^%a:\\")
    end

    return vim.startswith(path, "/")
end

---@param path string
---@param root? string
---@return string rel_path
function Util.relative(path, root)
    if not root then
        return Util.absolute(path)
    end

    local abs_path = Util.absolute(path)
    local abs_root = Util.absolute(root)

    local start_index = 1
    local end_index = nil

    if vim.startswith(abs_path, abs_root) then
        start_index = string.len(abs_root) + 1
    end

    -- TODO: might prefer keeping trailing slashes
    if vim.endswith(abs_path, "/") then
        end_index = string.len(abs_path) - 1
    end

    local rel_path = string.sub(abs_path, start_index, end_index)
    if rel_path == "" then
        rel_path = "."
    end

    return rel_path
end

---@param path string
---@param root string
---@return boolean
function Util.is_relative(path, root)
    local abs_path = Util.absolute(path)
    local abs_root = Util.absolute(root)

    return vim.startswith(abs_path, abs_root)
end

---@param ... string
---@return string path
function Util.join(...)
    return vim.fs.joinpath(...)
end

return Util
