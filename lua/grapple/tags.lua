local _scope = require("grapple.scope")
local log = require("grapple.log")
local state = require("grapple.state")
local types = require("grapple.types")

---@class Grapple.Tag
---@field file_path string
---@field cursor table

---@alias Grapple.TagKey string | integer
---@alias Grapple.TagTable table<Grapple.TagKey, Grapple.Tag>
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
---@ereturn Grapple.TagTable
function M.tags(scope)
    return vim.deepcopy(_scoped_tags(scope))
end

---@param scope Grapple.Scope
function M.reset(scope)
    local scope_path = _scope.resolve(scope)
    _tags[scope_path] = nil
end

---@param scope Grapple.Scope
---@param opts Grapple.Options
function M.tag(scope, opts)
    local file_path
    local cursor

    if opts.buffer then
        if not vim.api.nvim_buf_is_valid(opts.buffer) then
            log.error("ArgumentError - buffer is invalid. Buffer: " .. opts.buffer)
            error("ArgumentError - buffer is invalid. Buffer: " .. opts.buffer)
        end
        file_path = vim.api.nvim_buf_get_name(opts.buffer)
        cursor = vim.api.nvim_buf_get_mark(opts.buffer, '"')
    elseif opts.file_path then
        if not state.file_exists(opts.file_path) then
            log.error("ArgumentError - file path does not exist. Path: " .. opts.file_path)
            error("ArgumentError - file path does not exist. Path: " .. opts.file_path)
        end
        file_path = opts.file_path
    else
        log.error("ArgumentError - a buffer or file path are required to tag a file.")
        error("ArgumentError - a buffer or file path are required to tag a file.")
    end

    ---@type Grapple.Tag
    local tag = {
        file_path = file_path,
        cursor = cursor,
    }

    local old_key = M.key(scope, { file_path = file_path })
    if old_key ~= nil then
        log.warn(
            "Replacing tag. Old key: "
                .. old_key
                .. ". New key: "
                .. (opts.key or "[tbd]")
                .. ". Path: "
                .. tag.file_path
        )
        local old_tag = M.find(scope, { key = old_key })
        tag.cursor = old_tag.cursor
        M.untag(scope, { file_path = file_path })
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

---@return string[]
function M.scopes()
    return vim.tbl_keys(_tags)
end

function M.reorder(scope)
    local numbered_keys = vim.tbl_filter(function(key)
        return type(key) == "number"
    end, M.keys(scope))
    table.sort(numbered_keys)

    local index = 1
    for _, key in ipairs(numbered_keys) do
        if key ~= index then
            M.tag(scope, { file_path = _get(scope, key).file_path, key = index })
        end
        index = index + 1
    end
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
