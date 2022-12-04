local Path = require("plenary.path")
local log = require("grapple.log")
local quickfix = require("grapple.quickfix")
local scope = require("grapple.scope")
local state = require("grapple.state")
local types = require("grapple.types")

---@alias Grapple.TagKey string | integer

---@alias Grapple.FilePath string

---@alias Grapple.Cursor table

---@class Grapple.Tag
---@field file_path Grapple.FilePath
---@field cursor Grapple.Cursor

---@class Grapple.FullTag
---@field key Grapple.TagKey
---@field file_path Grapple.FilePath
---@field cursor Grapple.Cursor

---@class Grapple.PartialTag
---@field key Grapple.TagKey
---@field file_path Grapple.FilePath

local tags = {}

---@param path string
---@return string
local function resolve_file_path(path)
    if path == nil or path == "" then
        return ""
    end

    local expanded_path = Path:new(path):expand()
    local absolute_path = Path:new(expanded_path):absolute()
    return absolute_path
end

---@private
---@param scope_resolver Grapple.ScopeResolverLike
---@ereturn Grapple.TagTable
function tags.tags(scope_resolver)
    return state.scope(scope_resolver)
end

---@private
---@param scope_resolver Grapple.ScopeResolverLike
---@return integer
function tags.count(scope_resolver)
    return state.count(scope_resolver)
end

---@param scope_resolver Grapple.ScopeResolverLike
function tags.reset(scope_resolver)
    state.reset(scope_resolver)
end

---@param full_tag Grapple.FullTag
---@return Grapple.QuickfixItem
function tags.quickfixer(full_tag)
    return {
        filename = full_tag.file_path,
        lnum = full_tag.cursor and full_tag.cursor[1] or 1,
        col = full_tag.cursor and (full_tag.cursor[2] + 1) or 1,
        text = string.format(" [%s] ", full_tag.key, full_tag.file_path),
    }
end

---@param scope_resolver Grapple.ScopeResolverLike
function tags.quickfix(scope_resolver)
    local scope_ = scope.get(scope_resolver)
    local full_tags = state.with_keys_raw(state.scope_raw(scope_))
    quickfix.send(scope_, full_tags, tags.quickfixer)
end

---@param scope_resolver Grapple.ScopeResolverLike
---@param opts Grapple.Options
function tags.tag(scope_resolver, opts)
    local file_path
    local cursor

    if opts.file_path then
        file_path = resolve_file_path(opts.file_path)
    elseif opts.buffer then
        if not vim.api.nvim_buf_is_valid(opts.buffer) then
            log.error("ArgumentError - buffer is invalid. Buffer: " .. opts.buffer)
            error("ArgumentError - buffer is invalid. Buffer: " .. opts.buffer)
        end

        -- todo(cbochs): surface this as a setting for users
        local excluded_filetypes = { "grapple" }
        local buffer_filetype = vim.api.nvim_buf_get_option(opts.buffer, "filetype")
        if vim.tbl_contains(excluded_filetypes, buffer_filetype) then
            log.warn(string.format("Not tagging buffer, excluded filetype: %s", buffer_filetype))
            return
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

    local old_key = tags.key(scope_resolver, { file_path = file_path })
    if old_key ~= nil then
        log.debug(
            string.format(
                "Replacing tag. Old key: %s. New key: %s. Path: %s",
                old_key,
                (opts.key or "[append]"),
                tag.file_path
            )
        )
        local old_tag = tags.find(scope_resolver, { key = old_key })
        tag.cursor = old_tag.cursor
        tags.untag(scope_resolver, { file_path = file_path })
    end

    -- todo(cbochs): negative indices should probably be permitted
    -- Key validation must be performed AFTER the old tag is removed to ensure
    -- we correctly count the number of tags
    local key = opts.key
    if type(key) == "number" then
        -- Clamp the key between [1, #tags + 1], inclusive
        key = math.min(tags.count(scope_resolver) + 1, key)
        key = math.max(1, key)
    end

    return state.set(scope_resolver, tag, key)
end

---@param scope_resolver Grapple.ScopeResolverLike
---@param opts Grapple.Options
function tags.untag(scope_resolver, opts)
    local tag_key = tags.key(scope_resolver, opts)
    if tag_key == nil then
        log.debug(string.format("Unable to remove tag. opts: ", vim.inspect(opts)))
        return
    end
    state.unset(scope_resolver, tag_key)
end

---@param scope_resolver Grapple.ScopeResolverLike
---@param tag Grapple.Tag
---@param cursor Grapple.Cursor
---@return boolean
function tags.update(scope_resolver, tag, cursor)
    local tag_key = tags.key(scope_resolver, { file_path = tag.file_path })
    if tag_key ~= nil then
        log.debug(string.format("Updating tag cursor. tag: %s. new cursor: %s", vim.inspect(tag), vim.inspect(cursor)))

        local new_tag = vim.deepcopy(tag)
        new_tag.cursor = cursor

        state.set(scope_resolver, new_tag, tag_key)

        return true
    else
        log.debug(string.format("Unable to update tag. tag: %s", vim.inspect(tag)))
        return false
    end
end

---@param tag Grapple.Tag
---@return boolean
function tags.select(tag)
    if tag.file_path == vim.api.nvim_buf_get_name(0) then
        log.debug("Tagged file is already the currently selected buffer.")
        return true
    end

    if not Path:new(tag.file_path):exists() then
        log.warn("Tagged file does not exist.")
    end

    vim.api.nvim_cmd({ cmd = "edit", args = { tag.file_path } }, {})
    if tag.cursor then
        vim.api.nvim_win_set_cursor(0, tag.cursor)
    end

    return true
end

---@param scope_resolver Grapple.ScopeResolverLike
---@param opts Grapple.Options
---@return Grapple.Tag | nil
function tags.find(scope_resolver, opts)
    local tag_key = tags.key(scope_resolver, opts)
    if tag_key == nil then
        return nil
    end
    return state.get(scope_resolver, tag_key)
end

---@param scope_resolver Grapple.ScopeResolverLike
---@param opts Grapple.Options
---@return Grapple.TagKey | nil
function tags.key(scope_resolver, opts)
    if opts.key and state.exists(scope_resolver, opts.key) then
        return opts.key
    end

    if opts.file_path then
        local file_path = resolve_file_path(opts.file_path)
        return state.key(scope_resolver, { file_path = file_path })
    end

    if opts.buffer and vim.api.nvim_buf_is_valid(opts.buffer) then
        local file_path = vim.api.nvim_buf_get_name(opts.buffer)
        return state.key(scope_resolver, { file_path = file_path })
    end
end

---@param scope_resolver Grapple.ScopeResolverLike
---@return Grapple.TagKey[]
function tags.keys(scope_resolver)
    return state.keys(scope_resolver)
end

---@return string[]
function tags.scopes()
    return state.scopes()
end

---@param scope_resolver Grapple.ScopeResolverLike
function tags.compact(scope_resolver)
    local numbered_keys = vim.tbl_filter(function(key)
        return type(key) == "number"
    end, tags.keys(scope_resolver))
    table.sort(numbered_keys)

    local index = 1
    for _, key in ipairs(numbered_keys) do
        if key ~= index then
            log.debug(string.format("Found hole in scoped tags. Tag key: %s. Expected index: %s", key, index))
            tags.tag(scope_resolver, {
                file_path = tags.find(scope_resolver, { key = key }).file_path,
                key = index,
            })
        end
        index = index + 1
    end
end

---@param scope_resolver Grapple.ScopeResolverLike
---@param start_index integer
---@param direction Grapple.Direction
---@return Grapple.Tag | nil
function tags.next(scope_resolver, start_index, direction)
    local scoped_tags = tags.tags(scope_resolver)
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
