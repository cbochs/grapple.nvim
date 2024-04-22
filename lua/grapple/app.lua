local Cache = require("grapple.cache")
local ContainerContent = require("grapple.container_content")
local ResolvedScope = require("grapple.resolved_scope")
local ScopeContent = require("grapple.scope_content")
local ScopeManager = require("grapple.scope_manager")
local Settings = require("grapple.settings")
local State = require("grapple.state")
local TagContent = require("grapple.tag_content")
local TagManager = require("grapple.tag_manager")
local Window = require("grapple.window")

---@class grapple.app
---@field context grapple.context
---@field settings grapple.settings
---
---@field scope_manager grapple.scope_manager
---@field tag_manager grapple.tag_manager
local App = {}
App.__index = App

---@class grapple.context
---@field cache grapple.cache
---@field state grapple.state

---A global instance of the Grapple app
---@type grapple.app
local app

---@return grapple.app
function App.get()
    if app then
        return app
    end

    app = App:new()
    app:update()

    return app
end

---@return grapple.app
function App:new()
    local settings = Settings:new()

    return setmetatable({
        context = {
            cache = Cache:new(),
            state = State:new(settings.save_path),
        },
        settings = settings,

        scope_manager = ScopeManager:new(),
        tag_manager = TagManager:new(),
    }, self)
end

---@param opts? grapple.settings
---@return string? error
function App:update(opts)
    self.settings:update(opts)

    for _, definition in ipairs(self.settings:scopes()) do
        if definition.delete then
            self:delete_scope(definition.name)
        else
            local err = self:define_scope(vim.tbl_extend("force", definition, { force = true }))
            if err then
                return err
            end
        end
    end
end

---@class grapple.options
---@field buffer? integer
---@field path? string
---@field name? string
---@field index? integer
---@field cursor? integer[]
---@field scope? string
---@field scope_id? string
---@field command? fun(path: string)

---Extract a valid path from the provided path or buffer options.
---@param path? string
---@param buffer? integer
---@param exclusions table
---@return string | nil path, string? error
local function extract_path(path, buffer, exclusions)
    -- Special case: get the path under the cursor
    if path and path == "<cfile>" then
        return vim.fn.expand("<cfile>")
    end

    if path then
        return path
    end

    buffer = buffer or 0

    if not vim.api.nvim_buf_is_valid(buffer) then
        return nil, string.format("invalid buffer: %s", buffer)
    end

    local buftype = vim.api.nvim_get_option_value("buftype", { buf = buffer })
    if vim.tbl_contains(exclusions.buftype, buftype) then
        return nil, string.format("invalid buftype for buffer %s: %s", buffer, buftype)
    end

    local filetype = vim.api.nvim_get_option_value("filetype", { buf = buffer })
    if vim.tbl_contains(exclusions.filetype, filetype) then
        return nil, string.format("invalid filetype for buffer %s: %s", buffer, filetype)
    end

    local bufname = vim.api.nvim_buf_get_name(buffer)
    if vim.tbl_contains(exclusions.name, bufname) then
        return nil, string.format('invalid name for buffer %s: "%s"', buffer, bufname)
    end

    return vim.api.nvim_buf_get_name(buffer), nil
end

---Create a new tag or update an existing tag on a path, URI, or buffer
---By default, uses the current scope
---@param opts? grapple.options
---@return string? error
function App:tag(opts)
    opts = opts or {}

    local path, err = extract_path(opts.path, opts.buffer, self.settings.exclusions)
    if err or not path then
        return err
    end

    opts.path = path

    return self:enter_with_save(function(container)
        return container:insert(opts)
    end, { scope = opts.scope, scope_id = opts.scope_id })
end

---Delete a tag on a path, URI, or buffer
---By default, uses the current scope
---@param opts? grapple.options
---@return string? error
function App:untag(opts)
    opts = opts or {}

    local path, err = extract_path(opts.path, opts.buffer, self.settings.exclusions)
    if err or not path then
        return err
    end

    opts.path = path

    self:enter_with_save(function(container)
        return container:remove(opts)
    end, { scope = opts.scope, scope_id = opts.scope_id })
end

---Toggle a tag on a path, URI, or buffer. Lookup is done by index, name, path, or buffer
---By default, uses the current scope
---@param opts? grapple.options
---@return string? error
function App:toggle(opts)
    opts = opts or {}

    local path, err = extract_path(opts.path, opts.buffer, self.settings.exclusions)
    if err or not path then
        return err
    end

    opts.path = path

    return self:enter_with_save(function(container)
        if container:has(opts) then
            return container:remove(opts)
        else
            return container:insert(opts)
        end
    end, { scope = opts.scope, scope_id = opts.scope_id })
end

---Select a tag by index, name, path, or buffer
---By default, uses the current scope
---@param opts? grapple.options
---@return string? error
function App:select(opts)
    opts = opts or {}

    local path, _ = extract_path(opts.path, opts.buffer, self.settings.exclusions)
    opts.path = path

    return self:enter_with_event(function(container)
        local index, err = container:find(opts)
        if err then
            return err
        end

        local tag = assert(container:get({ index = index }))

        tag:select(opts.command or self.settings.command)
    end, { scope = opts.scope, scope_id = opts.scope_id })
end

---@param current_index? integer
---@param direction "next" | "prev"
---@param length integer
---@return integer
local function next_index(current_index, direction, length)
    -- Fancy maths to get the next index for a given direction
    -- 1. Change to 0-based indexing
    -- 2. Perform index % container length, being careful of negative values
    -- 3. Change back to 1-based indexing
    -- stylua: ignore
    current_index = (
        current_index
        or direction == "next" and length
        or direction == "prev" and 1
    ) - 1

    local next_inc = direction == "next" and 1 or -1
    local next_idx = math.fmod(current_index + next_inc + length, length) + 1

    return next_idx
end

-- Cycle through and select the next or previous available tag for a given scope.
---By default, uses the current scope
---@param direction "next" | "prev" | "previous" | "forward" | "backward"
---@param opts? grapple.options
---@return string? error
function App:cycle_tags(direction, opts)
    -- stylua: ignore
    direction = direction == "forward" and "next"
        or direction == "backward" and "prev"
        or direction == "previous" and "prev"
        or direction

    ---@cast direction "next" | "prev"

    if not vim.tbl_contains({ "next", "prev" }, direction) then
        return string.format("invalid direction: %s", direction)
    end

    opts = opts or {}

    local path, _ = extract_path(opts.path, opts.buffer, self.settings.exclusions)
    opts.path = path

    return self:enter_with_event(function(container)
        if container:is_empty() then
            return
        end

        local index = next_index(container:find(opts), direction, container:len())

        local tag, err = container:get({ index = index })
        if err or not tag then
            return err
        end

        ---@diagnostic disable-next-line: redefined-local
        local err = tag:select(opts.command or self.settings.command)
        if err then
            return err
        end
    end, { scope = opts.scope, scope_id = opts.scope_id })
end

---Update a tag in a given scope
---@param opts? grapple.options
---@return string? error
function App:touch(opts)
    opts = opts or {}

    local path, _ = extract_path(opts.path, opts.buffer, self.settings.exclusions)
    opts.path = path

    return self:enter(function(container)
        return container:update(opts)
    end, { scope = opts.scope, scope_id = opts.scope_id })
end

---Search for a tag in a given scope
---@param opts? grapple.options
---@return grapple.tag | nil, string? error
function App:find(opts)
    opts = opts or {}

    local path, _ = extract_path(opts.path, opts.buffer, self.settings.exclusions)
    opts.path = path

    ---@type grapple.tag | nil, string? error
    local tag, err = self:enter_with_result(function(container)
        local index, err = container:find(opts)
        if not index then
            return nil, err
        end

        return assert(container:get({ index = index })), nil
    end, { scope = opts.scope, scope_id = opts.scope_id })

    if not tag then
        return nil, err
    end

    return tag, nil
end

---Return if a tag exists. Used for statusline components
---@param opts? grapple.options
---@return boolean
function App:exists(opts)
    return App:find(opts) ~= nil
end

---Return the name or index of a tag. Used for statusline components
---@param opts? grapple.options
---@return string | integer | nil
function App:name_or_index(opts)
    opts = opts or {}

    local path, _ = extract_path(opts.path, opts.buffer, self.settings.exclusions)
    opts.path = path

    ---@type string | integer | nil
    local name_or_index, _ = self:enter_with_result(function(container)
        local tag = container:get(opts)
        if not tag then
            return nil
        end

        return tag.name or assert(container:find(opts))
    end, { scope = opts.scope, sync = false, event = false })

    return name_or_index
end

---Return the tags for a given scope (name) or loaded scope (id). Used for
---integrations
---@param opts? { scope?: string, scope_id?: string }
---@return grapple.tag[] | nil, string? error
function App:tags(opts)
    opts = opts or {}

    return self:enter_with_result(function(container)
        return vim.deepcopy(container.tags), nil
    end, { scope = opts.scope, scope_id = opts.scope_id })
end

---Create a user-defined scope
---@param definition grapple.scope_definition
---@return string? error
function App:define_scope(definition)
    return self.scope_manager:define(self.context, definition.name, definition.resolver, {
        force = definition.force,
        desc = definition.desc,
        fallback = definition.fallback,
        cache = definition.cache,
        hidden = definition.hidden,
    })
end

---Delete a user-defined or default scope
---@param scope_name string
---@return string? error
function App:delete_scope(scope_name)
    return self.scope_manager:delete(self.context, scope_name)
end

---Change the currently selected scope
---@param scope_name string
---@return string? error
function App:use_scope(scope_name)
    local scope, err = self.scope_manager:get(scope_name)
    if err or not scope then
        return err
    end

    if scope.name ~= self.settings.scope then
        self.settings:update({ scope = scope.name })

        vim.api.nvim_exec_autocmds("User", {
            pattern = "GrappleScopeChanged",
            modeline = false,
        })
    end
end

---Unload or reset tags for a given (scope) name or loaded scope (id)
---@param opts { scope?: string, scope_id?: string, reset?: boolean }
---@return grapple.resolved_scope | nil, string? error
function App:unload_scope(opts)
    local scope, err = self:resolve_scope({ scope = opts.scope, scope_id = opts.scope_id })
    if not scope then
        return nil, err
    end

    self.scope_manager:unload(self.context, scope.name)
    self.tag_manager:unload(self.context, scope.id, { reset = opts.reset })

    return scope, nil
end

---Open content in a new floating window
---@param content grapple.tag_content | grapple.scope_content | grapple.container_content
---@return string? error
function App:open(content)
    local window = Window:new(self.settings.win_opts)

    window:open()
    window:attach(content)

    return window:render()
end

---Open a floating window populated with all tags for a given (scope) name
---or loaded scope (id). By default, uses the current scope
---@param opts? { scope?: string, scope_id?: string, style?: string }
---@return string? error
function App:open_tags(opts)
    opts = opts or {}

    local scope, err = self:resolve_scope({ scope = opts.scope, scope_id = opts.scope_id })
    if not scope then
        return err
    end

    -- stylua: ignore
    local content = TagContent:new(
        self,
        scope,
        self.settings.tag_hook,
        self.settings.tag_title,
        self.settings.styles[opts.style or self.settings.style]
    )

    return self:open(content)
end

---Open a floating window populated with all defined scopes
---@param opts? { all: boolean }
---@return string? error
function App:open_scopes(opts)
    local show_all = opts and opts.all or false
    local content = ScopeContent:new(self, self.settings.scope_hook, self.settings.scope_title, show_all)

    return self:open(content)
end

---Open a floating window populated with all loaded scopes
---@param opts? { all: boolean }
---@return string? error
function App:open_loaded(opts)
    local show_all = opts and opts.all or false
    local content = ContainerContent:new(self, self.settings.loaded_hook, self.settings.loaded_title, show_all)

    return self:open(content)
end

---Prune save files based on their last modified time
---@param opts { limit?: integer | string }
---@return string[] | nil, string? error
function App:prune(opts)
    local pruned_ids, err = self.tag_manager:prune(self.context, opts.limit or self.settings.prune)
    if not pruned_ids then
        return nil, err
    end

    return pruned_ids, nil
end

---@return grapple.resolved_scope | nil, string? error
function App:current_scope()
    return self.scope_manager:get_resolved(self.context, self.settings.scope)
end

---@return grapple.tag_container[]
function App:list_containers()
    return self.tag_manager:list(self.context)
end

---@param opts? { scope?: string, scope_id?: string }
---@return grapple.resolved_scope | nil, string? error
function App:resolve_scope(opts)
    opts = opts or {}

    if opts.scope_id then
        local scope = self.scope_manager:get_resolved_by_id(self.context, opts.scope_id)
        if scope then
            return scope, nil
        end

        ---@param container grapple.tag_container
        ---@return string id
        local to_id = function(container)
            return container.id
        end

        local ids = vim.tbl_map(to_id, self.tag_manager:list(self.context))
        if vim.tbl_contains(ids, opts.scope_id) then
            return ResolvedScope:new(nil, opts.scope_id, nil), nil
        end

        return nil, string.format("could not find resolved scope for id: %s", opts.scope_id)
    end

    return self.scope_manager:get_resolved(self.context, opts.scope or self.settings.scope)
end

---@class grapple.app.enter_options
---@field scope? string
---@field scope_id? string
---@field sync? boolean
---@field event? boolean

---@param callback fun(container: grapple.tag_container): string? error
---@param opts grapple.app.enter_options
---@return string? error
function App:enter(callback, opts)
    local scope, err = self:resolve_scope({ scope = opts.scope, scope_id = opts.scope_id })
    if not scope then
        return err
    end

    ---@diagnostic disable-next-line: redefined-local
    local container, err = self.tag_manager:load(self.context, scope.id)
    if not container then
        return err
    end

    ---@diagnostic disable-next-line: redefined-local
    local err = callback(container)
    if err then
        return err
    end

    if opts.sync then
        ---@diagnostic disable-next-line: redefined-local
        local err = self.tag_manager:sync(self.context, scope.id)
        if err then
            return err
        end
    end

    if opts.event then
        vim.api.nvim_exec_autocmds("User", {
            pattern = "GrappleUpdate",
            modeline = false,
        })
    end

    return nil
end

---@generic T
---@param callback fun(container: grapple.tag_container): T | nil, string? error
---@param opts? grapple.app.enter_options
---@return T | nil, string? error
function App:enter_with_result(callback, opts)
    local result

    local wrapped = function(container)
        local err
        result, err = callback(container)
        return err
    end

    local err = self:enter(wrapped, opts or {})

    return result, err
end

---@param callback fun(container: grapple.tag_container): string? error
---@param opts? grapple.app.enter_options
---@return string? error
function App:enter_with_save(callback, opts)
    return self:enter(callback, vim.tbl_deep_extend("force", opts or {}, { sync = true, event = true }))
end

---@param callback fun(container: grapple.tag_container): string? error
---@param opts? grapple.app.enter_options
---@return string? error
function App:enter_with_event(callback, opts)
    return self:enter(callback, vim.tbl_deep_extend("force", opts or {}, { sync = false, event = true }))
end

return App
