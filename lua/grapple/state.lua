local Path = require("grapple.path")

---@class grapple.state
---@field save_dir string
local State = {}
State.__index = State

---Reference: https://github.com/golgote/neturl/blob/master/lib/net/url.lua
---
---@param plain_string string
---@return string
local function path_encode(plain_string)
    local encoded = string.gsub(plain_string, "([^%w])", function(match)
        return string.upper(string.format("%%%02x", string.byte(match)))
    end)

    return encoded
end

---@param encoded_string string
---@return string
---@diagnostic disable-next-line: unused-function, unused-local
local function path_decode(encoded_string)
    local decoded = string.gsub(encoded_string, "%%(%x%x)", function(match)
        return string.char(tonumber(match, 16))
    end)

    return decoded
end

---@param save_dir string
---@return grapple.state
function State:new(save_dir)
    return setmetatable({
        save_dir = save_dir,
    }, self)
end

function State:save_path(name)
    return Path.join(self.save_dir, string.format("%s.json", path_encode(name)))
end

function State:ensure_created()
    if Path.exists(self.save_dir) then
        return
    end

    vim.fn.mkdir(self.save_dir, "-p")
end

---@param name string
---@return boolean exists
function State:exists(name)
    local path = self:save_path(name)

    return Path.exists(path)
end

---@return string[]
function State:list()
    local files = {}
    for name, type in vim.fs.dir(self.save_dir) do
        if type ~= "file" then
            goto continue
        end

        name = path_decode(name)
        name = string.gsub(name, "%.json", "")
        table.insert(files, name)

        ::continue::
    end
    return files
end

---@return string? error, string? error_kind
function State:remove(name)
    local path = self:save_path(name)
    local _, err = vim.loop.fs_unlink(path)
    if err then
        return err, "FS_UNLINK"
    end
end

---@param name string
---@return any decoded, string? error, string? error_kind
function State:read(name)
    self:ensure_created()
    local path = self:save_path(name)

    local fd, err, err_kind = vim.loop.fs_open(path, "r", 438)
    if not fd then
        return nil, err, err_kind
    end

    ---@diagnostic disable-next-line: redefined-local
    local stat, err, err_kind = vim.loop.fs_fstat(fd)
    if not stat then
        assert(vim.loop.fs_close(fd), string.format("could not close file: %s", path))
        return nil, err, err_kind
    end

    ---@diagnostic disable-next-line: redefined-local
    local data, err, err_kind = vim.loop.fs_read(fd, stat.size, 0)
    if not data then
        assert(vim.loop.fs_close(fd), string.format("could not close file: %s", path))
        return nil, err, err_kind
    end

    assert(vim.loop.fs_close(fd))

    local ok, decoded = pcall(vim.json.decode, data)
    if not ok then
        ---@diagnostic disable-next-line: redefined-local
        local err = decoded
        return nil, err, "JSON_DECODE"
    end

    return decoded, nil
end

---@param name string
---@param obj any
---@return string? error, string? error_kind
function State:write(name, obj)
    self:ensure_created()
    local path = self:save_path(name)

    local ok, encoded = pcall(vim.json.encode, obj)
    if not ok then
        local err = encoded
        return err, "JSON_ENCODE"
    end

    local fd, err, err_kind = vim.loop.fs_open(path, "w", 438)
    if not fd then
        return err, err_kind
    end

    assert(type(encoded) == "string", "could not encode as json")
    assert(vim.loop.fs_write(fd, encoded, 0))
    assert(vim.loop.fs_close(fd))

    return nil
end

return State
