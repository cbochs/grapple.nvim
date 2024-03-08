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
---@field path? string
---@field name? string
---@field index? integer
---@field command? function

---@param opts grapple.action.tag_options
---@return string? error
function TagActions.select(opts)
    require("grapple").select({
        path = opts.path,
        name = opts.name,
        index = opts.index,
        scope = opts.scope.name,
        command = opts.command,
    })
end

---@param opts grapple.action.tag_options
---@return string? error
function TagActions.rename(opts)
    vim.ui.input({ prompt = string.format("Rename %s", opts.path) }, function(input_name)
        if not input_name then
            return
        end

        opts.scope:enter(function(container)
            local index, err = container:find({ path = opts.path })
            if not index then
                return err
            end
            container:insert({ path = opts.path, name = input_name, index = index })
        end)
    end)
end

---@param opts grapple.action.tag_options
---@return string? error
function TagActions.quickfix(opts)
    require("grapple").quickfix({ scope = opts.scope.name })
end

function TagActions.open_scopes()
    require("grapple").open_scopes()
end

return TagActions
