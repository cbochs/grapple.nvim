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

---@param list table
---@param fn fun(acc: any, value: any, index?: integer): any
---@param init any
---@return any
function Util.reduce(list, fn, init)
    local acc = init
    for i, v in ipairs(list) do
        if i == 1 and not init then
            acc = init
        else
            fn(acc, v, i)
        end
    end
    return acc
end

---@param path string
---@return boolean
function Util.exists(path)
    local permission = vim.uv.fs_access(path, "R")
    if not permission then
        return false
    end

    return permission
end

---@param path string
---@return string abs_path, string? error
function Util.absolute(path)
    if path == "" then
        return "", "no path provided"
    end

    local normal_path = vim.fs.normalize(path)

    ---@type string
    ---@diagnostic disable-next-line: assign-type-mismatch
    local expanded_path = vim.fn.fnamemodify(normal_path, ":p")

    local abs_parts = Util.reduce(vim.split(expanded_path, "/"), function(path_parts, part)
        if part == "" and not vim.tbl_isempty(path_parts) then
            return path_parts
        elseif part == "." then
            return path_parts
        elseif part == ".." then
            table.remove(path_parts)
            return path_parts
        else
            table.insert(path_parts, part)
            return path_parts
        end
    end, {})

    local abs_path = table.concat(abs_parts, "/")

    ---@type string
    ---@diagnostic disable-next-line: assign-type-mismatch
    abs_path = vim.fn.fnamemodify(abs_path, ":p")

    if not Util.exists(abs_path) then
        return "", string.format("no such file or directory: %s", path)
    end

    ---@diagnostic disable-next-line: return-type-mismatch
    return abs_path, nil
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
---@return string rel_path, string? error
function Util.relative(path, root)
    if not root then
        return Util.absolute(path)
    end

    local abs_path, err = Util.absolute(path)
    if err then
        return "", err
    end

    ---@diagnostic disable-next-line: redefined-local
    local abs_root, err = Util.absolute(root)
    if err then
        return "", err
    end

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

    return rel_path, nil
end

---@param path string
---@param root string
---@return boolean
function Util.is_relative(path, root)
    local abs_path, err = Util.absolute(path)
    if err then
        return false
    end

    ---@diagnostic disable-next-line: redefined-local
    local abs_root, err = Util.absolute(root)
    if err then
        return false
    end

    return vim.startswith(abs_path, abs_root)
end

---@param ... string
---@return string path
function Util.join(...)
    return vim.fs.joinpath(...)
end

return Util
