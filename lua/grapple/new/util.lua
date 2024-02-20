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

    if vim.endswith(abs_path, "/") then
        end_index = string.len(abs_path) - 1
    end

    return string.sub(abs_path, start_index, end_index)
end

---@param path string
---@param root string
---@return boolean
function Util.is_relative(path, root)
    local abs_path = Util.absolute(path)
    local abs_root = Util.absolute(root)

    return vim.startswith(abs_path, abs_root)
end

-- TODO: remove this code
--
---@param path string
---@param max_length integer
---@return string compact_path
function Util.compact(path, max_length)
    ---@diagnostic disable-next-line: redefined-local
    local path = Util.absolute(path)

    ---@type string
    ---@diagnostic disable-next-line: assign-type-mismatch
    local basename = vim.fs.basename(path)

    if string.len(basename) > max_length then
        return string.sub(basename, 1, max_length - 2) .. ".."
    end

    local index = 1
    while string.len(path) > max_length do
        local parts = vim.split(path, "/", { plain = true })
        if index == #parts or (parts[#parts] == "" and index == #parts - 1) then
            parts[index] = string.sub(parts[index], 1, max_length - 2 * index)
        elseif parts[index] ~= "" then
            parts[index] = string.sub(parts[index], 1, 1)
        end

        path = table.concat(parts, "/")

        index = index + 1
        if index > #parts then
            break
        end
    end

    return path
end

return Util
