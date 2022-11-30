local Path = require("plenary.path")
local log = require("grapple.log")
local scope = require("grapple.scope")
local state = require("grapple.state")
local types = require("grapple.types")

---@class Grapple.Tag
---@field file_path string
---@field cursor table

---@alias Grapple.TagKey string | integer

---@alias Grapple.Cursor table

local tags = {}

---@private
---@param path string
---@return string | nil
local function resolve_file_path(path)
    local expanded_path = Path:new(path):expand()
    local absolute_path = Path:new(expanded_path):absolute()
    return absolute_path
end

---@private
---@param scope_ Grapple.Scope
---@ereturn Grapple.TagTable
function tags.tags(scope_)
    return state.scope(scope_)
end

---@private
---@param scope_ Grapple.Scope
---@return integer
function tags.count(scope_)
    return state.count(scope_)
end

---@param scope_ Grapple.Scope
function tags.reset(scope_)
    state.reset(scope_)
end

---@param scope_ Grapple.Scope
function tags.quickfix(scope_)
    local quickfix_items = {}
    for tag_key, tag in pairs(state.scope(scope_)) do
        local quickfix_item = {
            filename = tag.file_path,
            lnum = tag.cursor and tag.cursor[1] or 1,
            col = tag.cursor and (tag.cursor[2] + 1) or 1,
            text = string.format(" [%s] ", tag_key, tag.file_path),
        }
        table.insert(quickfix_items, quickfix_item)
    end
    vim.fn.setqflist(quickfix_items, "r")
    vim.fn.setqflist({}, "a", { title = scope.get(scope_) })
    vim.api.nvim_cmd({ cmd = "copen" }, {})
end

---@param scope_ Grapple.Scope
---@param opts Grapple.Options
function tags.tag(scope_, opts)
    local file_path
    local cursor

    if opts.file_path then
        file_path = resolve_file_path(opts.file_path)
        if file_path == nil then
            log.error("ArgumentError - file path does not exist. Path: " .. opts.file_path)
            error("ArgumentError - file path does not exist. Path: " .. opts.file_path)
        end
    elseif opts.buffer then
        if not vim.api.nvim_buf_is_valid(opts.buffer) then
            log.error("ArgumentError - buffer is invalid. Buffer: " .. opts.buffer)
            error("ArgumentError - buffer is invalid. Buffer: " .. opts.buffer)
        end

        -- todo(cbochs): add guard to ensure file path exists
        file_path = vim.api.nvim_buf_get_name(opts.buffer)
        cursor = vim.api.nvim_buf_get_mark(opts.buffer, '"')
    else
        log.error("ArgumentError - a buffer or file path are required to tag a file.")
        error("ArgumentError - a buffer or file path are required to tag a file.")
    end

    ---@type Grapple.Tag
    local tag = {
        file_path = file_path,
        cursor = cursor,
    }

    local old_key = tags.key(scope_, { file_path = file_path })
    if old_key ~= nil then
        log.debug(
            string.format(
                "Replacing tag. Old key: %s. New key: %s. Path: %s",
                old_key,
                (opts.key or "[append]"),
                tag.file_path
            )
        )
        local old_tag = tags.find(scope_, { key = old_key })
        tag.cursor = old_tag.cursor
        tags.untag(scope_, { file_path = file_path })
    end

    -- todo(cbochs): negative indices should probably be permitted
    -- Key validation must be performed AFTER the old tag is removed to ensure
    -- we correctly count the number of tags
    local key = opts.key
    if type(key) == "number" then
        -- Clamp the key between [1, #tags + 1], inclusive
        key = math.min(tags.count(scope_) + 1, key)
        key = math.max(1, key)
    end

    return state.set(scope_, tag, key)
end

---@param scope_ Grapple.Scope
---@param opts Grapple.Options
function tags.untag(scope_, opts)
    local tag_key = tags.key(scope_, opts)
    if tag_key == nil then
        log.debug(string.format("Unable to remove tag. opts: ", vim.inspect(opts)))
        return
    end
    state.unset(scope_, tag_key)
end

---@param scope_resolver Grapple.ScopeResolverLike
---@param tag Grapple.Tag
---@param cursor Grapple.Cursor
function tags.update(scope_resolver, tag, cursor)
    local tag_key = tags.key(scope_resolver, { file_path = tag.file_path })
    if tag_key ~= nil then
        log.debug(string.format("Updating tag cursor. tag: %s. new cursor: %s", vim.inspect(tag), vim.inspect(cursor)))

        local new_tag = vim.deepcopy(tag)
        new_tag.cursor = cursor

        return state.set(scope_resolver, new_tag, tag_key)
    else
        log.debug(string.format("Unable to update tag. tag: %s", vim.inspect(tag)))
    end
end

---@param tag Grapple.Tag
function tags.select(tag)
    if tag.file_path == vim.api.nvim_buf_get_name(0) then
        log.debug("Tagged file is already the currently selected buffer.")
        return
    end

    if not Path:new(tag.file_path):exists() then
        log.warn("Tagged file does not exist.")
    end

    vim.api.nvim_cmd({ cmd = "edit", args = { tag.file_path } }, {})
    if tag.cursor then
        vim.api.nvim_win_set_cursor(0, tag.cursor)
    end
end

---@param scope_ Grapple.Scope
---@param opts Grapple.Options
---@return Grapple.Tag | nil
function tags.find(scope_, opts)
    local tag_key = tags.key(scope_, opts)
    if tag_key == nil then
        return nil
    end
    return state.get(scope_, tag_key)
end

---@param scope_ Grapple.Scope
---@param opts Grapple.Options
---@return Grapple.TagKey | nil
function tags.key(scope_, opts)
    if opts.key and state.exists(scope_, opts.key) then
        return opts.key
    end

    if opts.file_path then
        local file_path = resolve_file_path(opts.file_path)
        return state.query(scope_, { file_path = file_path })
    end

    if opts.buffer and vim.api.nvim_buf_is_valid(opts.buffer) then
        local file_path = vim.api.nvim_buf_get_name(opts.buffer)
        return state.query(scope_, { file_path = file_path })
    end
end

---@param scope_ Grapple.Scope
---@return Grapple.TagKey[]
function tags.keys(scope_)
    return state.keys(scope_)
end

---@return string[]
function tags.scopes()
    return state.scopes()
end

---@param scope_ Grapple.Scope
function tags.compact(scope_)
    local numbered_keys = vim.tbl_filter(function(key)
        return type(key) == "number"
    end, tags.keys(scope_))
    table.sort(numbered_keys)

    local index = 1
    for _, key in ipairs(numbered_keys) do
        if key ~= index then
            log.debug(string.format("Found hole in scoped tags. Tag key: %s. Expected index: %s", key, index))
            tags.tag(scope_, {
                file_path = tags.find(scope_, { key = key }).file_path,
                key = index,
            })
        end
        index = index + 1
    end
end

---@param scope_ Grapple.Scope
---@param start_index integer
---@param direction Grapple.Direction
---@return Grapple.Tag | nil
function tags.next(scope_, start_index, direction)
    local scoped_tags = tags.tags(scope_)
    if #scoped_tags == 0 then
        return nil
    end

    local step = 1
    if direction == types.direction.backward then
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
function tags.save()
    state.save()
    state.prune()
end

return tags
