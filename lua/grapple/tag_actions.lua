local Path = require("grapple.path")

local TagActions = {}

---@alias grapple.action.options table
---@alias grapple.action fun(opts?: table): string?

---@class grapple.action.tag_options
---
---Provided by TagContent
---@field scope grapple.resolved_scope
---
---User-provided information
---@field index? integer
---@field name? string
---@field path? string
---@field command? function

---@param opts grapple.action.tag_options
---@return string? error
function TagActions.select(opts)
    local scope = opts.scope

    scope:enter(function(container)
        local tag = container:get({
            index = opts.index,
            name = opts.name,
            path = opts.path,
        })

        if tag then
            tag:select(opts.command)
        end
    end)

    return nil
end

---@param opts grapple.action.tag_options
---@return string? error
function TagActions.quickfix(opts)
    local scope = opts.scope

    local tags, err = scope:tags()
    if not tags then
        return err
    end

    local quickfix_list = {}

    for _, tag in ipairs(tags) do
        ---See :h vim.fn.setqflist
        ---@class grapple.vim.quickfix
        table.insert(quickfix_list, {
            filename = tag.path,
            lnum = tag.cursor[1],
            col = tag.cursor[2] + 1,
            text = Path.fs_relative(scope.path, tag.path),
        })
    end

    if #quickfix_list > 0 then
        vim.fn.setqflist(quickfix_list, "r")
        vim.cmd.copen()
    end

    return nil
end

return TagActions
