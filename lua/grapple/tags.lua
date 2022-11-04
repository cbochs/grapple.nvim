local log = require("grapple.log")
local state = require("grapple.state")
local types = require("grapple.types")

---@class Grapple.Tag
---@field key string | integer
---@field file_path string
---@field cursor table

---@alias Grapple.Cursor table

local M = {}

---@private
M._tags = {}

---@param scope Grapple.Scope
function M.resolve_scope(scope)
    local scope_key = nil

    if scope == types.Scope.NONE then
        scope_key = "none"
    elseif scope == types.Scope.GLOBAL then
        scope_key = "global"
    elseif scope == types.Scope.DIRECTORY then
        scope_key = vim.fn.getcwd()
    elseif scope == types.Scope.LSP then
        -- todo(cbochs): implement
    end

    M._tags[scope_key] = M._tags[scope_key] or {}
    return scope_key
end

---@param scope Grapple.Scope
function M.reset(scope)
    local scope_key = M.resolve_scope(scope)
    M._tags[scope_key] = {}
end

---Tag a buffer.
---@param scope Grapple.Scope
---@param opts Grapple.Options
function M.tag(scope, opts)
    local scope_key = M.resolve_scope(scope)
    local project = M._tags[scope_key]

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
    local tag = { file_path = vim.api.nvim_buf_get_name(opts.buffer) }

    local old_tag = M.find(scope, { buffer = opts.buffer })
    if old_tag ~= nil then
        log.warn("Replacing mark. Old tag: " .. old_tag.file_path .. ". New tag: " .. tag.file_path)
        tag.cursor = old_tag.cursor
        M.untag(scope, { buffer = 0 })
    end

    if opts.name then
        project[opts.name] = tag
    elseif opts.index then
        table.insert(project, opts.index, tag)
    else
        table.insert(project, tag)
    end
end

---@param scope Grapple.Scope
---@param opts Grapple.Options
function M.untag(scope, opts)
    local scope_key = M.resolve_scope(scope)
    local project = M._tags[scope_key]
    local tag_key = M.key(scope, opts)
    if tag_key ~= nil then
        if type(tag_key) == "number" then
            table.remove(project, tag_key)
        elseif type(tag_key) == "string" then
            project[tag_key] = nil
        end
    end
end

---@param scope Grapple.Scope
---@param tag Grapple.Tag
---@param cursor Grapple.Cursor
function M.update(scope, tag, cursor)
    local scope_key = M.resolve_scope(scope)
    local project = M._tags[scope_key]
    local tag_key = M.key(scope, { file_path = tag.file_path })
    project[tag_key].cursor = cursor
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
    local scope_key = M.resolve_scope(scope)
    local project = M._tags[scope_key]
    local tag_key = M.key(scope, opts)
    return project[tag_key]
end

---@param scope Grapple.Scope
---@param opts Grapple.Options
---@return string | integer | nil
function M.key(scope, opts)
    local scope_key = M.resolve_scope(scope)
    local project = M._tags[scope_key]
    local tag_key = nil

    if opts.file_path or opts.buffer and vim.api.nvim_buf_is_valid(opts.buffer) then
        local buffer_name = opts.file_path or vim.api.nvim_buf_get_name(opts.buffer)
        for key, mark in pairs(project) do
            if mark.file_path == buffer_name then
                tag_key = key
                break
            end
        end
    else
        tag_key = opts.name or opts.index
    end

    return tag_key
end

---@param scope Grapple.Scope
---@param start_index integer
---@param direction Grapple.Direction
---@return Grapple.Tag | nil
function M.next(scope, start_index, direction)
    local step = 1
    if direction == types.Direction.BACKWARD then
        step = -1
    end

    local scope_key = M.resolve_scope(scope)
    local project = M._tags[scope_key]
    if #project == 0 then
        return nil
    end

    local index = start_index + step
    if index <= 0 then
        index = #project
    end
    if index > #project then
        index = 1
    end

    while project[index] == nil and index ~= start_index do
        index = index + step
        if index <= 0 then
            index = #project
        end
        if index > #project then
            index = 1
        end
    end

    return project[index]
end

---@param scope Grapple.Scope
---@return Grapple.Tag[]
function M.tags(scope)
    local scope_key = M.resolve_scope(scope)
    local project = M._tags[scope_key]
    return vim.deepcopy(project)
end

---@param save_path string
function M.load(save_path)
    if state.file_exists(save_path) then
        M._tags = state.load(save_path)
    end
end

---Save tags to a persisted file.
---@param save_path string
function M.save(save_path)
    state.save(save_path, M._tags)
end

return M
