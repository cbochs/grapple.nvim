local log = require("grapple.log")
local state = require("grapple.state")
local types = require("grapple.types")

---@class Grapple.Tag
---@field key string | integer
---@field file_path string
---@field cursor table

---@alias Grapple.TagIndex string | number

---@alias Grapple.Cursor table

local M = {}

local _tags = {}

---@param scope Grapple.Scope
---@return string
local function resolve_scope(scope)
    local scope_key

    -- Perform scope resolution
    if scope == types.Scope.NONE then
        scope_key = "none"
    elseif scope == types.Scope.GLOBAL then
        scope_key = "global"
    elseif scope == types.Scope.DIRECTORY then
        scope_key = vim.fn.getcwd()
    elseif scope == types.Scope.LSP then
        -- There's no good way to disambiguate which client to use when multiple
        -- are present. For that reason, we choose to take the first active
        -- client that is attached to the current buffer.
        local clients = vim.lsp.get_active_clients({ bufnr = 0 })
        if #clients > 0 then
            local client = clients[1]
            scope_key = client.config.root_dir
        end
    elseif type(scope) == "function" then
        -- todo(cbochs): implement
        -- Grapple.ScopeResolver is falliable
    end

    -- Always fallback to the DIRECTORY scope
    if scope_key == nil then
        scope_key = resolve_scope(types.Scope.DIRECTORY)
    end

    -- By this point, scope_key is guaranteed to have been resolved
    ---@type string
    scope_key = scope_key

    _tags[scope_key] = _tags[scope_key] or {}
    return scope_key
end

---@private
---@param scope Grapple.Scope
---@param index Grapple.TagIndex
---@return Grapple.Tag
local function _get(scope, index)
    local scope_key = resolve_scope(scope)
    local scope_tags = _tags[scope_key]
    return scope_tags[index]
end

---@private
---@param scope Grapple.Scope
---@param tag Grapple.Tag
---@param index Grapple.TagIndex | nil
local function _set(scope, tag, index)
    local scope_key = resolve_scope(scope)
    local scope_tags = _tags[scope_key]

    if index == nil then
        table.insert(scope_tags, tag)
    elseif type(index) == "string" then
        scope_tags[index] = tag
    elseif type(index) == "number" then
        table.insert(scope_tags, index, tag)
    end
end

---@private
---@param scope Grapple.Scope
---@param tag Grapple.Tag
---@param index Grapple.TagIndex
local function _update(scope, tag, index)
    local scope_key = resolve_scope(scope)
    local scope_tags = _tags[scope_key]
    scope_tags[index] = tag
end

---@private
---@param scope Grapple.Scope
---@param index Grapple.TagIndex
local function _unset(scope, index)
    local scope_key = resolve_scope(scope)
    local tags = _tags[scope_key]

    if type(index) == "string" then
        tags[index] = nil
    elseif type(index) == "number" then
        table.remove(tags, index)
    end
end

---@private
local function _prune()
    for _, scope_key in ipairs(vim.tbl_keys(_tags)) do
        if vim.tbl_isempty(_tags[scope_key]) then
            _tags[scope_key] = nil
        end
    end
end

---@private
---@param scope Grapple.Scope
function M._tags(scope)
    local scope_key = resolve_scope(scope)
    local scope_tags = _tags[scope_key]
    return scope_tags
end

---@param scope Grapple.Scope
function M.reset(scope)
    local scope_key = resolve_scope(scope)
    _tags[scope_key] = {}
end

---@param scope Grapple.Scope
---@param opts Grapple.Options
function M.tag(scope, opts)
    if opts.name and opts.index then
        log.error("ArgumentError - 'name' and 'index' are mutually exclusive.")
        error("ArgumentError - 'name' and 'index' are mutually exclusive.")
    end

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

    _set(scope, tag, opts.name or opts.index)
end

---@param scope Grapple.Scope
---@param opts Grapple.Options
function M.untag(scope, opts)
    local tag_index = M.key(scope, opts)
    if tag_index ~= nil then
        _unset(scope, tag_index)
    end
end

---@param scope Grapple.Scope
---@param tag Grapple.Tag
---@param cursor Grapple.Cursor
function M.update(scope, tag, cursor)
    local tag_index = M.key(scope, { file_path = tag.file_path })
    if tag_index ~= nil then
        local new_tag = vim.deepcopy(tag)
        new_tag.cursor = cursor
        _update(scope, new_tag, tag_index)
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
    local tag_index = M.key(scope, opts)
    if tag_index ~= nil then
        return _get(scope, tag_index)
    else
        return nil
    end
end

---@param scope Grapple.Scope
---@param opts Grapple.Options
---@return Grapple.TagIndex | nil
function M.key(scope, opts)
    local tag_index = nil

    if opts.file_path or (opts.buffer and vim.api.nvim_buf_is_valid(opts.buffer)) then
        local scope_tags = M._tags(scope)
        local buffer_name = opts.file_path or vim.api.nvim_buf_get_name(opts.buffer)
        for key, mark in pairs(scope_tags) do
            if mark.file_path == buffer_name then
                tag_index = key
                break
            end
        end
    else
        tag_index = opts.name or opts.index
    end

    return tag_index
end

---@param scope Grapple.Scope
---@param start_index integer
---@param direction Grapple.Direction
---@return Grapple.Tag | nil
function M.next(scope, start_index, direction)
    local scope_tags = M._tags(scope)
    if #scope_tags == 0 then
        return nil
    end

    local step = 1
    if direction == types.Direction.BACKWARD then
        step = -1
    end

    local index = start_index + step
    if index <= 0 then
        index = #scope_tags
    end
    if index > #scope_tags then
        index = 1
    end

    while scope_tags[index] == nil and index ~= start_index do
        index = index + step
        if index <= 0 then
            index = #scope_tags
        end
        if index > #scope_tags then
            index = 1
        end
    end

    return scope_tags[index]
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
