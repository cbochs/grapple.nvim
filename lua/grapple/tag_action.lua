local Path = require("grapple.path")

local TagAction = {}

---@alias grapple.action fun(scope: grapple.scope.resolved, opts?: table): string?
---@alias grapple.action.options table

---@param scope grapple.scope.resolved
---@param opts grapple.tag.container.get
---@return string? error
function TagAction.select(scope, opts)
    local err = scope:enter(function(container)
        local tag, err = container:get(opts)
        if not tag then
            return err
        end

        ---@diagnostic disable-next-line: redefined-local
        local err = tag:select()
        if err then
            return err
        end
    end)
    if err then
        return err
    end

    return nil
end

---@param scope grapple.scope.resolved
---@param opts? table not used
---@return string? error
---@diagnostic disable-next-line: unused-local
function TagAction.quickfix(scope, opts)
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
            text = Path.relative(scope.path, tag.path),
        })
    end

    if #quickfix_list > 0 then
        vim.fn.setqflist(quickfix_list, "r")
        vim.cmd.copen()
    end

    return nil
end

return TagAction
