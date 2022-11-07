local _scope = require("grapple.scope")
local log = require("grapple.log")
local state = require("grapple.state")
local types = require("grapple.types")

---@class Grapple.Tag
---@field key string | integer
---@field file_path string
---@field cursor table

---@alias Grapple.TagKey string | integer

---@alias Grapple.Cursor table

local M = {}

---@type table<string, Grapple.Tag[]>
local _tags = {}

---@private
---@param scope Grapple.Scope
local function _scoped_tags(scope)
    local scope_path = _scope.resolve(scope)
    _tags[scope_path] = _tags[scope_path] or {}
    return _tags[scope_path]
end

---@private
---@param scope Grapple.Scope
---@param key Grapple.TagKey
---@return Grapple.Tag
local function _get(scope, key)
    return _scoped_tags(scope)[key]
end

---@private
---@param scope Grapple.Scope
---@param tag Grapple.Tag
---@param key Grapple.TagKey | nil
local function _set(scope, tag, key)
    local scoped_tags = _scoped_tags(scope)
    if key == nil then
        table.insert(scoped_tags, tag)
    elseif type(key) == "string" then
        scoped_tags[key] = tag
    elseif type(key) == "number" then
        table.insert(scoped_tags, key, tag)
    end
end

---@private
---@param scope Grapple.Scope
---@param tags Grapple.Tag[]
local function _set_all(scope, tags)
    local scope_path = _scope.resolve(scope)
    _tags[scope_path] = tags
end

---@private
---@param scope Grapple.Scope
---@param tag Grapple.Tag
---@param key Grapple.TagKey
local function _update(scope, tag, key)
    _scoped_tags(scope)[key] = tag
end

---@private
---@param scope Grapple.Scope
---@param key Grapple.TagKey
local function _unset(scope, key)
    local scoped_tags = _scoped_tags(scope)
    if type(key) == "string" then
        scoped_tags[key] = nil
    elseif type(key) == "number" then
        table.remove(scoped_tags, key)
    end
end

---@private
local function _prune()
    for _, scope_path in ipairs(vim.tbl_keys(_tags)) do
        if vim.tbl_isempty(_tags[scope_path]) then
            _tags[scope_path] = nil
        end
    end
end

---@private
---@param scope Grapple.Scope
function M.tags(scope)
    return _scoped_tags(scope)
end

---@param scope Grapple.Scope
function M.reset(scope)
    local scope_path = _scope.resolve(scope)
    _tags[scope_path] = nil
end

---@param scope Grapple.Scope
---@param opts Grapple.Options
function M.tag(scope, opts)
    if opts.buffer == nil then
        log.error("ArgumentError - buffer cannot be nil.")
        error("ArgumentError - buffer cannot be nil.")
    end

    if not vim.api.nvim_buf_is_valid(opts.buffer) then
        log.error("ArgumentError - buffer is invalid.")
        error("ArgumentError - buffer is invalid.")
    end

    ---@type Grapple.Tag
    local tag = {
        file_path = vim.api.nvim_buf_get_name(opts.buffer),
        cursor = vim.api.nvim_buf_get_mark(opts.buffer, '"'),
    }

    local old_tag = M.find(scope, { buffer = opts.buffer })
    if old_tag ~= nil then
        log.warn("Replacing mark. Old tag: " .. old_tag.file_path .. ". New tag: " .. tag.file_path)
        tag.cursor = old_tag.cursor
        M.untag(scope, { buffer = 0 })
    end

    _set(scope, tag, opts.key)
end

---@param scope Grapple.Scope
---@param opts Grapple.Options
function M.untag(scope, opts)
    local tag_key = M.key(scope, opts)
    if tag_key ~= nil then
        _unset(scope, tag_key)
    end
end

---@param scope Grapple.Scope
---@param tag Grapple.Tag
---@param cursor Grapple.Cursor
function M.update(scope, tag, cursor)
    local tag_key = M.key(scope, { file_path = tag.file_path })
    if tag_key ~= nil then
        local new_tag = vim.deepcopy(tag)
        new_tag.cursor = cursor
        _update(scope, new_tag, tag_key)
    end
end

---@param tag Grapple.Tag
function M.select(tag)
    if tag.file_path == vim.api.nvim_buf_get_name(0) then
        log.debug("Tagged file is already the currently selected buffer.")
        return
    end

    if not state.file_exists(tag.file_path) then
        log.warn("Tagged file does not exist.")
        return
    end

    vim.api.nvim_cmd({ cmd = "edit", args = { tag.file_path } }, {})
    if tag.cursor then
        vim.api.nvim_win_set_cursor(0, tag.cursor)
    end
end

---@param scope Grapple.Scope
---@param opts Grapple.Options
---@return Grapple.Tag | nil
function M.find(scope, opts)
    local tag_key = M.key(scope, opts)
    if tag_key ~= nil then
        return _get(scope, tag_key)
    else
        return nil
    end
end

---@param scope Grapple.Scope
---@param opts Grapple.Options
---@return Grapple.TagKey | nil
function M.key(scope, opts)
    local tag_key = nil

    if opts.key then
        tag_key = opts.key
    elseif opts.file_path or (opts.buffer and vim.api.nvim_buf_is_valid(opts.buffer)) then
        local scoped_tags = M.tags(scope)
        local buffer_name = opts.file_path or vim.api.nvim_buf_get_name(opts.buffer)
        for key, mark in pairs(scoped_tags) do
            if mark.file_path == buffer_name then
                tag_key = key
                break
            end
        end
    end

    return tag_key
end

---@param scope Grapple.Scope
---@return Grapple.TagKey[]
function M.keys(scope)
    return vim.tbl_keys(_scoped_tags(scope))
end

---@param scope Grapple.Scope
---@param start_index integer
---@param direction Grapple.Direction
---@return Grapple.Tag | nil
function M.next(scope, start_index, direction)
    local scoped_tags = M.tags(scope)
    if #scoped_tags == 0 then
        return nil
    end

    local step = 1
    if direction == types.Direction.BACKWARD then
        step = -1
    end

    local index = start_index + step
    if index <= 0 then
        index = #scoped_tags
    end
    if index > #scoped_tags then
        index = 1
    end

    while scoped_tags[index] == nil and index ~= start_index do
        index = index + step
        if index <= 0 then
            index = #scoped_tags
        end
        if index > #scoped_tags then
            index = 1
        end
    end

    return scoped_tags[index]
end

---@param scope Grapple.Scope
---@return string[]
function M.serialize(scope)
    local scoped_keys = M.keys(scope)
    local scope_path = _scope.resolve(scope)
    local sanitized_scope_path = string.gsub(scope_path, "%p", "%%%1")

    local lines = {}
    for _, key in pairs(scoped_keys) do
        local tag = M.find(scope, { key = key })
        if tag ~= nil then
            local relative_path = string.gsub(tag.file_path, sanitized_scope_path .. "/", "")
            local text = " [" .. key .. "] " .. relative_path
            table.insert(lines, text)
        end
    end
    return lines
end

---@param line string
---@return Grapple.TagKey | nil
function M.parse_line(line)
    local start, _end = string.find(line, "%[.*%]")
    if not start or not _end then
        return nil
    end
    return string.sub(line, start + 2, _end - start - 2)
end

---@param scope Grapple.Scope
---@param lines string[]
function M.resolve_lines(scope, lines)
    local scoped_keys = {}
    for _, line in ipairs(lines) do
        local key = M.parse_line(line)
        if key then
            table.insert(scoped_keys, M.parse_line(line))
        end
    end

    local scoped_tags = {}
    for _, key in ipairs(scoped_keys) do
        local tag = M.find(scope, { key = key })
        if tag ~= nil then
            scoped_tags[key] = tag
        end
    end

    _set_all(scope, scoped_tags)
end

---@param save_path string
function M.load(save_path)
    if state.file_exists(save_path) then
        _tags = state.load(save_path)
    end
end

---@param save_path string
function M.save(save_path)
    _prune()
    state.save(save_path, _tags)
end

---@private
---@param data table<string, Grapple.Tag[]>
function M._raw_load(data)
    _tags = data
end

---@private
---@return table<string, Grapple.Tag[]>
function M._raw_save()
    _prune()
    return _tags
end

return M
