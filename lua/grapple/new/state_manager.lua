local ErrorBuilder = require("grapple.new.error_builder")

-- JSON State Manager
---@class StateManager
---@field save_dir string
local StateManager = {}
StateManager.__index = StateManager

StateManager.FileError = ErrorBuilder:default("FILE_ERROR")

StateManager.NoExistError = ErrorBuilder:create(
    "UV_ENOENT",

    ---@param path string
    function(path)
        return string.format("no such file or directory: %s", path)
    end
)

StateManager.PermissionError = ErrorBuilder:create(
    "UV_EACCES",

    ---@param path string
    function(path)
        return string.format("permission denied: %s", path)
    end
)

StateManager.DecodeError = ErrorBuilder:default("JSON_DECODE_ERROR")
StateManager.EncodeError = ErrorBuilder:create(
    "JSON_ENCODE_ERROR",

    ---@param obj any
    function(obj)
        return string.format("failed to encode: %s", vim.inspect(obj))
    end
)

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

---@param state_path string
---@return StateManager
function StateManager:new(state_path)
    return setmetatable({
        save_dir = vim.fs.normalize(state_path),
    }, self)
end

function StateManager:save_path(name)
    return vim.fs.joinpath(self.save_dir, string.format("%s.json", path_encode(name)))
end

---@param name string
---@return boolean exists
function StateManager:exists(name)
    local path = self:save_path(name)

    local permission, err = vim.uv.fs_access(path, "RW")
    if err then
        return false
    end

    assert(type(permission) == "boolean", string.format("could not determine access: %s", path))

    return permission
end

---@return Error? error
function StateManager:remove(name)
    local path = self:save_path(name)
    local _, err = os.remove(path)
    if err then
        return StateManager.FileError:new(err)
    end
end

---@param name string
---@return any decoded, Error? error
function StateManager:read(name)
    local path = self:save_path(name)

    local fd, err, err_type = vim.uv.fs_open(path, "r", 438)
    if err_type == "ENOENT" then
        return {}, StateManager.NoExistError:new(path)
    elseif err_type then
        return {}, StateManager.FileError:new(err)
    end

    assert(fd, string.format("could not open file: %s", path))

    ---@diagnostic disable-next-line: redefined-local
    local stat, err = vim.uv.fs_fstat(fd)
    if err then
        assert(vim.uv.fs_close(fd), string.format("could not close file: %s", path))
        return {}, StateManager.FileError:new(err)
    end

    assert(stat, string.format("could not inspect file: %s", path))

    ---@diagnostic disable-next-line: redefined-local
    local data, err = vim.uv.fs_read(fd, stat.size, 0)
    if err then
        assert(vim.uv.fs_close(fd), string.format("could not close file: %s", path))
        return {}, StateManager.FileError:new(err)
    end

    assert(data, string.format("could not read file: %s", path))
    assert(type(data) == "string")

    assert(vim.uv.fs_close(fd))

    local ok, decoded = pcall(vim.json.decode, data)
    if not ok then
        ---@diagnostic disable-next-line: redefined-local
        local err_msg = decoded
        return {}, StateManager.DecodeError:new(err_msg)
    end

    return decoded, nil
end

---@param name string
---@param obj any
---@return Error? error
function StateManager:write(name, obj)
    local path = self:save_path(name)

    local ok, encoded = pcall(vim.json.encode, obj)
    if not ok then
        return StateManager.EncodeError:new(obj)
    end

    assert(type(encoded) == "string", "could not encode as json")

    local fd, err = vim.uv.fs_open(path, "w", 438)
    if err then
        return StateManager.FileError:new(err)
    end

    assert(fd, string.format("could not open file: %s", path))

    assert(vim.uv.fs_write(fd, encoded, 0))
    assert(vim.uv.fs_close(fd))

    return nil
end

return StateManager
