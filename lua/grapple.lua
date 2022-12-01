local settings = require("grapple.settings")

local grapple = {}

local initialized = false

--- @class Grapple.Options
--- @field buffer integer
--- @field file_path string
--- @field key Grapple.TagKey

---@param overrides? Grapple.Settings
function grapple.initialize()
    if initialized then
        return
    end
    initialized = true

    require("grapple.autocmds").create()
    require("grapple.commands").create()
    require("grapple.scope").reset()
    require("grapple.scope_resolvers").create()
    require("grapple.migrations").migrate()
end

---@param overrides? Grapple.Settings
function grapple.setup(overrides)
    settings.update(overrides)
    require("grapple.log").global({ log_level = settings.log_level })
    require("grapple.migrations").migrate()
end

---@param opts? Grapple.Options
function grapple.tag(opts)
    opts = vim.tbl_extend("force", { buffer = 0 }, opts or {})
    require("grapple.tags").tag(settings.scope, opts)
end

---@param opts? Grapple.Options
function grapple.untag(opts)
    opts = vim.tbl_extend("force", { buffer = 0 }, opts or {})
    require("grapple.tags").untag(settings.scope, opts)
end

---@param opts? Grapple.Options
function grapple.toggle(opts)
    if grapple.exists(opts) then
        grapple.untag(opts)
    else
        grapple.tag(opts)
    end
end

---@param opts? Grapple.Options
function grapple.select(opts)
    local tag = grapple.find(opts)
    if tag ~= nil then
        require("grapple.tags").select(tag)
    end
end

---@param opts? Grapple.Options
function grapple.find(opts)
    opts = vim.tbl_extend("force", { buffer = 0 }, opts or {})
    return require("grapple.tags").find(settings.scope, opts)
end

---@param opts? Grapple.Options
function grapple.key(opts)
    opts = vim.tbl_extend("force", { buffer = 0 }, opts or {})
    return require("grapple.tags").key(settings.scope, opts)
end

---@param opts? Grapple.Options
function grapple.exists(opts)
    return grapple.key(opts) ~= nil
end

---@param opts? Grapple.Options
---@param direction Grapple.Direction
function grapple.cycle(opts, direction)
    local tag_key = grapple.key(opts)
    local start_index = (type(tag_key) == "number") and tag_key or 0
    local tag = require("grapple.tags").next(settings.scope, start_index, direction)
    if tag ~= nil then
        require("grapple.tags").select(tag)
    end
end

---@param opts? Grapple.Options
function grapple.cycle_backward(opts)
    grapple.cycle(opts, "backward")
end

---@param opts? Grapple.Options
function grapple.cycle_forward(opts)
    grapple.cycle(opts, "forward")
end

---@param scope? Grapple.ScopeResolverLike
function grapple.reset(scope)
    require("grapple.tags").reset(scope or settings.scope)
end

---@param scope? Grapple.ScopeResolverLike
function grapple.quickfix(scope)
    require("grapple.tags").quickfix(scope or settings.scope)
end

---@param scope? Grapple.ScopeResolverLike
function grapple.popup_tags(scope)
    scope = scope or settings.scope
    local window_options = vim.deepcopy(settings.popup_options)
    require("grapple.popup_tags").open(scope, window_options)
end

function grapple.popup_scopes()
    local window_options = vim.deepcopy(settings.popup_options)
    require("grapple.popup_scopes").open(window_options)
end

function grapple.save()
    if settings.integrations.resession then
        return
    end
    require("grapple.state").save(settings.save_path)
    require("grapple.state").prune(settings.save_path)
end

return grapple
