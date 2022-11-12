local _scope = require("grapple.scope")
local _tags = require("grapple.tags")
local log = require("grapple.log")
local popup = require("grapple.ui.popup")

local M = {}

---@class Grapple.Items
---@field tags Grapple.TagTable
---@field lines string[]
---@field map_relpath_tag table<string, Grapple.Tag>

---@param scope Grapple.Scope
---@return Grapple.Items
local function itemize(scope)
    local scoped_tags = _tags.tags(scope)
    local scope_path = _scope.resolve(scope)
    local sanitized_scope_path = string.gsub(scope_path, "%p", "%%%1")

    local lines = {}
    local map_relpath_tag = {}
    for key, tag in pairs(scoped_tags) do
        local relative_path = string.gsub(tag.file_path, sanitized_scope_path .. "/", "")
        local text = " [" .. key .. "] " .. relative_path
        table.insert(lines, text)
        map_relpath_tag[relative_path] = tag
    end

    return {
        tags = scoped_tags,
        lines = lines,
        map_relpath_tag = map_relpath_tag,
    }
end

---@class Grapple.PartialTag
---@field key string | integer
---@field relative_path string

---@param line string
---@return Grapple.PartialTag | nil
local function parse(line)
    if #line == 0 then -- no need to warn
        return nil
    end
    local pattern = "%[(.*)%] +(.*)"
    for key, relative_path in string.gmatch(line, pattern) do
        return { key = tonumber(key) or key, relative_path = relative_path }
    end
    log.warn(("Unable to parse line into tag key. Line:\n'%s'"):format(line))
    return nil
end

---@class Grapple.UIState
---@field scope Grapple.Scope
---@field popup Grapple.Popup
---@field items Grapple.Items
---@field opts table

---@param state Grapple.UIState
local function action_update(state)
    local new_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local partial_tags = vim.tbl_map(parse, new_lines)
    partial_tags = vim.tbl_filter(function(ptag)
        return ptag.key ~= nil
    end, partial_tags)

    ---@type Grapple.TagTable
    local new_tags = {}

    for i, new_line in ipairs(new_lines) do
        local ptag = parse(new_line)
        if ptag == nil then
            vim.notify(("[Grapple] - failed to parse '%s'"):format(new_line), "warn")
            return -- early return, cancel updates
        else
            local new_tag = vim.deepcopy(state.items.map_relpath_tag[ptag.relative_path])

            -- handle potential duplicate
            local new_tag_file_paths = vim.tbl_map(function(tag)
                return tag.file_path
            end, new_tags)

            if not vim.tbl_contains(new_tag_file_paths, new_tag.file_path) then
                if ptag.key ~= new_tag.key then
                    log.debug("using modified key for", ptag.relative_path)
                    new_tag.key = ptag.key -- use modified key
                else
                    log.debug("using line index for", ptag.relative_path)
                    new_tag.key = i -- use line index
                end
                table.insert(new_tags, new_tag)
            end
        end
    end

    log.debug("Updating tags to", new_tags)
    _tags.set_tags(state.scope, new_tags)

    -- Update items in state
    state.items = itemize(state.scope)

    -- Redraw buffer
    vim.api.nvim_buf_set_lines(state.popup.buffer, 0, -1, false, state.items.lines)
end

---@param state Grapple.UIState
local function action_close(state)
    popup.close(state.popup)
    if state.opts.autosave then
        action_update(state)
    end
end

---@param state Grapple.UIState
local function action_select(state)
    local new_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local is_modified = table.concat(state.items.lines) ~= table.concat(new_lines)
    if is_modified then
        if not state.opts.autosave then
            vim.notify("[Grapple] popup was modified but autosave is disabled.", "warn")
            -- redraw to initial state:
            vim.api.nvim_buf_set_lines(state.popup.buffer, 0, -1, false, state.items.lines)
            return -- early return, cancel select
        else
            action_update(state)
        end
    end

    local current_line = vim.api.nvim_get_current_line()
    local ptag = parse(current_line)
    if ptag == nil then
        return popup.close(state.popup)
    end
    local tag = _tags.find(state.scope, { key = ptag.key or "" })

    popup.close(state.popup)

    if tag ~= nil then
        log.debug("Selected tag", tag.file_path)
        _tags.select(tag)
    end
end

---@param scope Grapple.Scope
---@param opts Grapple.PopupConfig
function M.open(scope, opts)
    local winopts = opts.winopts
    if vim.fn.has("nvim-0.9") == 1 then
        winopts.title = _scope.resolve(scope)
        winopts.title_pos = "center"
    end

    local items = itemize(scope)
    local _popup = popup.open(items.lines, winopts)

    ---@type Grapple.UIState
    local state = { scope = scope, popup = _popup, items = items, opts = opts }

    local function trigger_action_fn(fn)
        return function()
            return fn(state)
        end
    end

    local close = trigger_action_fn(action_close)
    local select = trigger_action_fn(action_select)
    local update = trigger_action_fn(action_update)

    popup.on_leave(_popup, close)

    local kopts = { buffer = _popup.buffer, nowait = true }
    vim.keymap.set("n", "q", "<esc>", vim.tbl_extend("keep", { remap = true }, kopts))
    vim.keymap.set("n", "<esc>", close, kopts)
    vim.keymap.set("n", "<cr>", select, kopts)
    vim.keymap.set("n", "<c-s>", update, kopts)
end

return M
