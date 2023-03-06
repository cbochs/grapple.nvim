local settings = require("grapple.settings")

local grapple = {}

local initialized = false

--- @class Grapple.Options
--- @field buffer integer
--- @field file_path string
--- @field key Grapple.TagKey
--- @field scope Grapple.Scope

grapple.resolvers = require("grapple.scope_resolvers")

function grapple.initialize()
    if initialized then
        return
    end
    initialized = true

    require("grapple.autocmds").create()
    require("grapple.commands").create()
    require("grapple.migrations").migrate()
end

---@param overrides? Grapple.Settings
function grapple.setup(overrides)
    settings.update(overrides)
    require("grapple.log").global({ log_level = settings.log_level })

    grapple.initialize()
end

---@param opts? Grapple.Options
function grapple.tag(opts)
    opts = vim.tbl_extend("force", { buffer = 0 }, opts or {})

    local scope = require("grapple.state").ensure_loaded(opts.scope or settings.scope)
    require("grapple.tags").tag(scope, opts)
end

---@param opts? Grapple.Options
function grapple.untag(opts)
    opts = vim.tbl_extend("force", { buffer = 0 }, opts or {})

    local scope = require("grapple.state").ensure_loaded(opts.scope or settings.scope)
    require("grapple.tags").untag(scope, opts)
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

    local scope = require("grapple.state").ensure_loaded(opts.scope or settings.scope)
    return require("grapple.tags").find(scope, opts)
end

---@param opts? Grapple.Options
function grapple.key(opts)
    opts = vim.tbl_extend("force", { buffer = 0 }, opts or {})

    local scope = require("grapple.state").ensure_loaded(opts.scope or settings.scope)
    return require("grapple.tags").key(scope, opts)
end

---@param opts? Grapple.Options
function grapple.exists(opts)
    return grapple.key(opts) ~= nil
end

---@param direction Grapple.Direction
---@param opts? Grapple.Options
function grapple.cycle(opts, direction)
    opts = opts or {}

    local tag_key = grapple.key(opts)
    local start_index = (type(tag_key) == "number") and tag_key or 0
    local scope = require("grapple.state").ensure_loaded(opts.scope or settings.scope)

    local tag = require("grapple.tags").next(scope, start_index, direction)
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

---@param scope? Grapple.Scope
function grapple.tags(scope)
    scope = require("grapple.state").ensure_loaded(scope or settings.scope)
    return require("grapple.tags").full_tags(scope)
end

---@param scope? Grapple.ScopeResolverLike
function grapple.reset(scope)
    scope = require("grapple.state").ensure_loaded(scope or settings.scope)
    require("grapple.state").reset(scope)
end

---@param scope? Grapple.ScopeResolverLike
function grapple.quickfix(scope)
    scope = require("grapple.state").ensure_loaded(scope or settings.scope)
    require("grapple.tags").quickfix(scope)
end

---@param scope? Grapple.ScopeResolverLike
function grapple.popup_tags(scope)
    scope = require("grapple.state").ensure_loaded(scope or settings.scope)

    local popup_tags = require("grapple.popup_tags")
    local popup_handler = popup_tags.handler
    local popup_state = { scope = scope }
    local popup_items = require("grapple.tags").full_tags(scope)
    local popup_keymaps = {
        { mode = "n", key = "q", action = popup_tags.actions.close },
        { mode = "n", key = "<esc>", action = popup_tags.actions.close },
        { mode = "n", key = "<cr>", action = popup_tags.actions.select },
        { mode = "n", key = "<c-v>", action = popup_tags.actions.select_vsplit },
        { mode = "n", key = "<c-q>", action = popup_tags.actions.quickfix },
    }

    local window_options = vim.deepcopy(settings.popup_options)
    if vim.fn.has("nvim-0.9") == 1 then
        window_options.title = popup_state.scope
    end

    local popup = require("grapple.popup")
    local popup_menu = popup.open(window_options, popup_handler, popup_state)
    popup.update(popup_menu, popup_items)
    popup.keymap(popup_menu, popup_keymaps)
end

function grapple.popup_scopes()
    local popup_scopes = require("grapple.popup_scopes")
    local popup_handler = popup_scopes.handler
    local popup_state = {}
    local popup_items = require("grapple.state").scopes()
    local popup_keymaps = {
        { mode = "n", key = "q", action = popup_scopes.actions.close },
        { mode = "n", key = "<esc>", action = popup_scopes.actions.close },
    }

    local window_options = vim.deepcopy(settings.popup_options)
    if vim.fn.has("nvim-0.9") == 1 then
        window_options.title = "Loaded Scopes"
    end

    local popup = require("grapple.popup")
    local popup_menu = popup.open(window_options, popup_handler, popup_state)
    popup.update(popup_menu, popup_items)
    popup.keymap(popup_menu, popup_keymaps)
end

function grapple.save()
    if settings.integrations.resession then
        return
    end
    require("grapple.state").save(settings.save_path)
    require("grapple.state").prune(settings.save_path)
end

return grapple
