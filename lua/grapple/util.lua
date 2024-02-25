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

---@param uri string
---@return string path, string | nil protocol
function Util.parts(uri)
    local protocol, path = string.match(uri, "^(.*)://(.*)$")

    if not protocol then
        return path, nil
    end

    ---@class grapple.uri.parts
    local parts = {
        protocol = "",
        -- user = "",
        -- hostname = "",
        -- port = "",
        path = "",
    }

    return path, protocol
end

function Util.is_valid(uri)
    local path, protocol = Util.parts(uri)
    local path = Util.absolute(path)
end

---@param path string
---@return string | nil abs_path, string? error
function Util.absolute(path)
    if path == "" then
        return nil, "no path provided"
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
        return nil, string.format("no such file or directory: %s", path)
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
---@return string | nil rel_path, string? error
function Util.relative(path, root)
    if not root then
        return Util.absolute(path)
    end

    local abs_path, err = Util.absolute(path)
    if not abs_path then
        return nil, err
    end

    ---@diagnostic disable-next-line: redefined-local
    local abs_root, err = Util.absolute(root)
    if not abs_root then
        return nil, err
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
    local abs_path, _ = Util.absolute(path)
    if not abs_path then
        return false
    end

    ---@diagnostic disable-next-line: redefined-local
    local abs_root, _ = Util.absolute(root)
    if not abs_root then
        return false
    end

    return vim.startswith(abs_path, abs_root)
end

---@param path string
---@return string | nil short_path, string? error
function Util.short(path)
    local abs_path, err = Util.absolute(path)
    if not abs_path then
        return nil, err
    end

    ---@type string
    ---@diagnostic disable-next-line: assign-type-mismatch
    local short_path = vim.fn.fnamemodify(abs_path, ":~:.")

    if short_path == "" then
        short_path = "."
    end

    return short_path
end

---@param ... string
---@return string path
function Util.join(...)
    return vim.fs.joinpath(...)
end

-- HACK: This feels seriously wrong
-- Load the `" mark for a given file path. Afaik this cannot be obtained
-- from the shada file directly and must be inspected on an open AND loaded
-- buffer. There are several difficulties present:
-- 1. the buffer must be in the background
-- 2. the buffer must be loaded for marks to be present
-- 3. the buffer must not trigger autocommands (e.g. LSP)
-- 4. nvim_buf_set_name does not load the buffer
-- 5. nvim_buf_call does not load the buffer (see reference)
-- 6. nvim_create_buf does not cooperate with bufload
--
-- Reference: https://www.reddit.com/r/neovim/comments/10idl7u/how_to_load_a_file_into_neovims_buffer_without/
--
---@param path string
---@return integer[] | nil cursor, string? error
function Util.cursor(path)
    local abs_path, err = Util.absolute(path)
    if not abs_path then
        return nil, err
    end

    ---@type integer
    ---@diagnostic disable-next-line: assign-type-mismatch
    local buf_id = vim.fn.bufadd(abs_path)
    if buf_id == 0 then
        return nil, string.format("could not add buffer for path: %s", abs_path)
    end

    if not vim.api.nvim_buf_is_loaded(buf_id) then
        local eventignore = vim.api.nvim_get_option_value("eventignore", { scope = "global" })
        vim.api.nvim_set_option_value("eventignore", "all", { scope = "global" })
        vim.fn.bufload(buf_id)
        vim.api.nvim_set_option_value("eventignore", eventignore, { scope = "global" })
    end

    local mark = vim.api.nvim_buf_get_mark(buf_id, '"')

    local buf_ids = vim.api.nvim_list_bufs()
    if not vim.tbl_contains(buf_ids, buf_id) then
        vim.api.nvim_buf_delete(buf_id, { force = true })
    end

    return mark, nil
end

return Util
