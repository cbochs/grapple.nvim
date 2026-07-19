local TagActions = {}

---@alias grapple.action.options table
---@alias grapple.action fun(opts?: table): string?

---@class grapple.action.tag_options
---
---Provided by Window
---@field window grapple.window
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
    local Path = require("grapple.path")

    vim.ui.input({ prompt = string.format("Rename %s", Path.fs_short(opts.path)) }, function(input_name)
        if not input_name then
            return
        end

        -- HACK: just re-tag the existing tag with a new name
        require("grapple").tag({
            path = opts.path,
            name = input_name,
            scope_id = opts.scope.id,
        })

        -- Re-render window once tag has been renamed, regardless of whether
        -- the renaming was successful
        opts.window:render()
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

---Open the configured fuzzy picker for the current scope.
---Picker is selected by settings.fuzzy_picker ("snacks", "fzf_lua",
---"telescope", "auto"). With "auto" the order is snacks -> fzf-lua -> telescope.
---@param opts grapple.action.tag_options
---@return string? error
function TagActions.open_fuzzy_picker(opts)
    local scope = opts.scope
    local picker = require("grapple").app().settings.fuzzy_picker
    local picker_opts = { scope = scope.name, id = scope.id }

    local function try_snacks()
        local ok = pcall(require, "snacks")
        if not ok then
            return false
        end
        require("grapple.extensions.snacks").open_tags(picker_opts)
        return true
    end

    local function try_fzf_lua()
        local ok = pcall(require, "fzf-lua")
        if not ok then
            return false
        end
        require("grapple.extensions.fzf_lua").open_tags(picker_opts)
        return true
    end

    local function try_telescope()
        local ok = pcall(require, "telescope")
        if not ok then
            return false
        end
        require("telescope").extensions.grapple.tags()
        return true
    end

    if picker == "snacks" then
        try_snacks()
    elseif picker == "fzf_lua" then
        try_fzf_lua()
    elseif picker == "telescope" then
        try_telescope()
    elseif picker == "auto" then
        if not try_snacks() then
            if not try_fzf_lua() then
                try_telescope()
            end
        end
    end
end

return TagActions
