local autocmds = require("grapple.autocmds")
local commands = require("grapple.commands")
local log = require("grapple.log")
local popup_scope = require("grapple.popup_scope")
local popup_tags = require("grapple.popup_tags")
local scope = require("grapple.scope")
local scope_resolvers = require("grapple.scope_resolvers")
local settings = require("grapple.settings")
local tags = require("grapple.tags")
local types = require("grapple.types")

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

    autocmds.create()
    commands.create()

    scope.reset()
    scope_resolvers.create()

    log.new({ level = settings.log_level })
end

---@param overrides? Grapple.Settings
function grapple.setup(overrides)
    scope.reset()
    scope_resolvers.create()

    settings.update(overrides)
    log.new({ level = settings.log_level })

    -- Give two weeks migration time. Delete 12-12-2022
    local Path = require("plenary.path")
    require("grapple.migrations.26112022_save_as_individual_files").migrate(
        settings.save_path,
        tostring(Path:new(vim.fn.stdpath("data")) / "grapple.json"),
        tostring(Path:new(vim.fn.stdpath("data")) / "grapple")
    )

    -- Give two weeks migration time. Delete 14-12-2022
    require("grapple.migrations.30112022_separate_named_and_indexed_tags").migrate(settings.save_path)
end

---@param opts? Grapple.Options
function grapple.tag(opts)
    opts = vim.tbl_extend("force", { buffer = 0 }, opts or {})
    tags.tag(settings.scope, opts)
end

---@param opts? Grapple.Options
function grapple.untag(opts)
    opts = vim.tbl_extend("force", { buffer = 0 }, opts or {})
    tags.untag(settings.scope, opts)
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
        tags.select(tag)
    end
end

---@param opts? Grapple.Options
function grapple.find(opts)
    opts = vim.tbl_extend("force", { buffer = 0 }, opts or {})
    return tags.find(settings.scope, opts)
end

---@param opts? Grapple.Options
function grapple.key(opts)
    opts = vim.tbl_extend("force", { buffer = 0 }, opts or {})
    return tags.key(settings.scope, opts)
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
    local tag = tags.next(settings.scope, start_index, direction)
    if tag ~= nil then
        tags.select(tag)
    end
end

---@param opts? Grapple.Options
function grapple.cycle_backward(opts)
    grapple.cycle(opts, types.direction.backward)
end

---@param opts? Grapple.Options
function grapple.cycle_forward(opts)
    grapple.cycle(opts, types.direction.forward)
end

---@param scope_? Grapple.Scope
function grapple.reset(scope_)
    tags.reset(scope_ or settings.scope)
end

---@param scope_? Grapple.Scope
function grapple.quickfix(scope_)
    tags.quickfix(scope_ or settings.scope)
end

---@param scope_? Grapple.Scope
function grapple.popup_tags(scope_)
    scope_ = scope_ or settings.scope
    local window_options = vim.deepcopy(settings.popup_options)
    popup_tags.open(scope_, window_options)
end

function grapple.popup_scopes()
    local window_options = vim.deepcopy(settings.popup_options)
    popup_scope.open(window_options)
end

function grapple.save()
    local scope_resolver = scope.find_resolver(settings.scope)
    if scope_resolver.key == "none" then
        return
    end
    if settings.integrations.resession then
        return
    end
    tags.save()
end

return grapple
