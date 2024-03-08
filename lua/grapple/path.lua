local Util = require("grapple.util")

local Path = {}

-- A somewhat faithful implementation of Go's filepath packages
--
-- Please note that this does not aim to parse or understand the entire spec
-- for both Unix and Windows file paths. Most noteably, Windows absolute paths
-- are a syscall to the win32 api (GetFullPathNameW). Because of this, some
-- paths might not parse correctly.
--
-- However, most - if not all - use cases should be covered by simply parsing
-- the Windows path as a Unix path + (optional) drive letter. At least, doing
-- so has passed a good number of Go's filepath test suite.
--
-- For more details on what this module supports, please see the path_spec.lua
--
-- For more details on Go's filepath package, please see:
-- https://pkg.go.dev/path/filepath

---@return "windows" | "macos" | "linux"
function Path.get_os()
    if vim.loop.os_uname().version:match("Windows") then
        return "windows"
    elseif vim.loop.os_uname().sysname == "Darwin" then
        return "macos"
    else
        return "linux"
    end
end

Path.os = Path.get_os()
Path.windows = Path.os == "windows"
Path.macos = Path.os == "macos"
Path.linux = Path.os == "linux"
Path.unix = Path.macos or Path.linux

Path.separator = Path.windows and "\\" or "/"
Path.double_separator = string.format("%s%s", Path.separator, Path.separator)

function Path.is_separator(str, index)
    local char = str.sub(str, index, index)

    if Path.windows then
        return char == "\\" or char == "/"
    end

    return char == "/"
end

---@param word_a string | nil
---@param word_b string | nil
---@return boolean
function Path.are_same(word_a, word_b)
    if word_a == nil or word_b == nil then
        return word_a == word_b
    end

    if Path.windows then
        -- Windows paths are case-insensitive
        return string.lower(word_a) == string.lower(word_b)
    else
        return word_a == word_b
    end
end

---@param path string
---@return string slashed
function Path.to_slash(path)
    if Path.separator == "/" then
        return path
    end

    local slashed = string.gsub(path, Path.separator, "/")

    return slashed
end

---@param path string
---@return string unslashed
function Path.from_slash(path)
    if Path.separator == "/" then
        return path
    end

    local unslashed = string.gsub(path, "/", Path.separator)

    return unslashed
end

---@param path string
---@return string | nil volume, integer path_start
function Path.volume(path)
    if Path.windows then
        if string.sub(path, 2, 2) == ":" then
            return string.sub(path, 1, 2), 3
        end

        return nil, 1
    else
        return nil, 1
    end
end

---@param path string
---@return string clean_path
function Path.clean(path)
    local volume, path_start = Path.volume(path)

    -- stylua: ignore
    path = path
        :sub(path_start)
        :gsub("\\", Path.separator)
        :gsub("/", Path.separator)

    -- Path begins with a separator
    local rooted = Path.is_separator(path, 1)

    -- Expand upward-relative path operatives
    local dotdot = 0
    local path_parts = Util.reduce(
        vim.tbl_filter(Util.not_empty, vim.split(path, Path.separator)),

        ---@param parts string[]
        ---@param part string
        ---@return string[] parts
        function(parts, part)
            if part == "." then
                return parts
            elseif part == ".." then
                if #parts > dotdot then
                    table.remove(parts)
                elseif not rooted then
                    table.insert(parts, "..")
                    dotdot = #parts
                end
                return parts
            else
                table.insert(parts, part)
                return parts
            end
        end,
        {}
    )

    local clean_path = table.concat(path_parts, Path.separator)

    if rooted then
        clean_path = Path.separator .. clean_path
    end

    if clean_path == "" then
        clean_path = "."
    end

    if volume then
        clean_path = volume .. clean_path
    end

    return clean_path
end

---@param path string
---@return boolean
function Path.is_absolute(path)
    if Path.is_uri(path) then
        return true
    end

    if Path.windows then
        -- Windows is more complicated
        if Path.is_separator(path, 1) and Path.is_separator(path, 2) then
            return true
        end

        local volume, path_start = Path.volume(path)
        if not volume then
            return false
        end

        path = string.sub(path, path_start)
        if path == "" then
            return false
        end

        return Path.is_separator(path, 1)
    else
        return vim.startswith(path, "/")
    end
end

---@param path string
---@return string abs_path
function Path.absolute(path)
    if Path.is_absolute(path) then
        return Path.clean(path)
    end

    return Path.clean(Path.join(vim.loop.cwd(), path))
end

---Matches IsLocal(path string)
---@param path string
function Path.is_relative(path)
    if Path.windows then
        if path == "" then
            return false
        end
        if Path.is_separator(path, 1) then
            return false
        end
        if string.find(path, ":") then
            return false
        end

        local clean_path = Path.clean(path)
        if clean_path == ".." or vim.startswith(clean_path, "..\\") then
            return false
        end

        return true
    else
        if Path.absolute(path) or path == "" then
            return false
        end

        local clean_path = Path.clean(path)
        if clean_path == ".." or vim.startswith(clean_path, "../") then
            return false
        end

        return true
    end
end

---@param base string
---@param targ string
---@return string | nil rel_path, string? error
function Path.relative(base, targ)
    local base_path = Path.clean(base)
    local targ_path = Path.clean(targ)

    if Path.are_same(base_path, targ_path) then
        return ".", nil
    end

    local base_volume, base_start = Path.volume(base)
    local targ_volume, targ_start = Path.volume(targ)

    base_path = string.sub(base_path, base_start)
    targ_path = string.sub(targ_path, targ_start)

    if base_path == "." then
        base_path = ""
    end

    -- Required:
    -- 1. Paths must be BOTH absolute or BOTH relative
    -- 2. Paths must share the same volume
    --
    -- Note: Cannot use Path.is_absolute since "\a" and "a" are both
    -- considered relative paths in Windows
    --
    local base_slashed = string.len(base_path) > 0 and Path.is_separator(base_path, 1)
    local targ_slashed = string.len(targ_path) > 0 and Path.is_separator(targ_path, 1)

    local same_kind = base_slashed == targ_slashed
    local same_vol = Path.are_same(base_volume, targ_volume)

    if not same_kind or not same_vol then
        return nil, string.format("cannot make %s relative to %s", base, targ)
    end

    local base_parts = vim.tbl_filter(Util.not_empty, vim.split(base_path, Path.separator))
    local targ_parts = vim.tbl_filter(Util.not_empty, vim.split(targ_path, Path.separator))

    local last_index = 1
    while Path.are_same(base_parts[last_index], targ_parts[last_index]) do
        last_index = last_index + 1

        if last_index > math.max(#base_parts, #targ_parts) then
            break
        end
    end

    if base_parts[last_index] == ".." then
        return nil, string.format("cannot make %s relative to %s", base, targ)
    end

    local rel_parts = {}
    if last_index <= #base_parts then
        for _ = last_index, #base_parts do
            table.insert(rel_parts, "..")
        end
    end
    for i = last_index, #targ_parts do
        table.insert(rel_parts, targ_parts[i])
    end

    local rel_path = table.concat(rel_parts, Path.separator)

    return rel_path, nil
end

---@param path string
---@return string basename
function Path.base(path)
    if path == "" then
        return "."
    end

    -- Remove trailing slashes
    if Path.is_separator(path, -1) then
        path = string.sub(path, 1, -2)
    end

    return vim.fn.fnamemodify(path, ":t")
end

---@param path string
---@param n? integer
---@return string basename
function Path.parent(path, n)
    if path == "" then
        return "."
    end

    -- Remove trailing slashes
    if Path.is_separator(path, -1) then
        path = string.sub(path, 1, -2)
    end

    n = n or 1
    local mods = table.concat(Util.ntimes(":h", n), "")

    return vim.fn.fnamemodify(path, mods)
end

---Not from the Go filepath package
---Check to see if a path can be the tail end of a join
---1. The path is relative to known directory (i.e. CWD or HOME)
---2. The path is absolute or is a URI
---@param path string
---@return boolean
function Path.is_joinable(path)
    return not vim.startswith(path, "./")
        and not vim.startswith(path, "../")
        and not vim.startswith(path, "~")
        and not Path.is_uri(path)
        and not Path.is_absolute(path)
end

---@param ... string
---@return string joined
function Path.join(...)
    -- TODO: Use vim.fs.joinpath when nvim-0.10 comes out
    -- TODO: Handle Windows path edge cases

    return Path.clean(table.concat({ ... }, Path.separator))
end

---Not from the Go filepath package
---Returns the absolute path after observing the filesystem
function Path.fs_absolute(path)
    -- Assume URIs are already absolute, don't clean them
    if Path.is_uri(path) then
        return path
    end

    path = vim.fs.normalize(path)
    path = Path.absolute(path)
    path = vim.fn.fnamemodify(path, ":p")
    return path
end

---Not from the Go filepath package
---Returns the relative path after observing the filesystem
---@param base string
---@param targ string
---@return string | nil rel_path, string? error
function Path.fs_relative(base, targ)
    -- Assume URIs cannot be made relative
    if Path.is_uri(targ) then
        return targ, nil
    end

    base = Path.fs_absolute(base)
    targ = Path.fs_absolute(targ)

    local path, err = Path.relative(base, targ)
    if not path then
        return nil, err
    end

    -- Add leading "./" to relative paths for better autocompletion
    if not vim.startswith(path, "..") then
        path = "." .. Path.separator .. path
    end

    -- Add trailing slash to directories
    if vim.fn.isdirectory(targ) == 1 then
        path = path .. Path.separator
    end

    return path
end

---Not from the Go filepath package
---Returns the short path after observing the filesystem
---@param path string
---@return string short_path, string? error
function Path.fs_short(path)
    -- Assume URIs are already as short as they can be
    if Path.is_uri(path) then
        return path
    end

    local abs_path = Path.absolute(path)

    ---@type string
    ---@diagnostic disable-next-line: assign-type-mismatch
    local short_path = vim.fn.fnamemodify(abs_path, ":~:.")

    return short_path
end

---Not from the Go filepath package
---Simple check to see if a path is a URI
---@param path string
---@return boolean
function Path.is_uri(path)
    -- URIs can be more complex than this. Just use a basic check right now
    local index = string.find(path, "://")

    -- 1. If there is no index, it is not a URI
    -- 2. If there is an index, check that it is not a Windows volume "C:"
    return index and index > 2 or false
end

---@param path string
---@return string | nil scheme, integer path_start
function Path.scheme(path)
    if not Path.is_uri(path) then
        return nil, 1
    end

    local index = assert(string.find(path, ":"))
    local scheme = string.sub(path, 1, index - 1)
    local path_start = index + 1

    return scheme, path_start
end

---Not from the Go filepath package
---@param path string
---@return boolean exists
function Path.exists(path)
    if Path.is_uri(path) then
        return true
    end

    return vim.loop.fs_stat(path) ~= nil
end

return Path
