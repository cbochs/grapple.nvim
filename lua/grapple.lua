local autocmds = require("grapple.autocmds")
local builtin = require("grapple.builtin")
local commands = require("grapple.commands")
local config = require("grapple.config")
local log = require("grapple.log")
local popup_scope = require("grapple.popup_scope")
local popup_tags = require("grapple.popup_tags")
local scope = require("grapple.scope")
local tags = require("grapple.tags")
local types = require("grapple.types")

local M = {}

--- @class Grapple.Options
--- @field buffer integer
--- @field file_path string
--- @field key Grapple.TagKey

---@param opts? Grapple.Config
function M.setup(opts)
    scope.reset()
    builtin.create_resolvers()
    autocmds.create_autocmds()
    commands.create_commands()

    config.load(opts)
    log.new({ level = config.log_level })
end

---@param opts? Grapple.Options
function M.tag(opts)
    opts = vim.tbl_extend("force", { buffer = 0 }, opts or {})
    tags.tag(config.scope, opts)
end

---@param opts? Grapple.Options
function M.untag(opts)
    opts = vim.tbl_extend("force", { buffer = 0 }, opts or {})
    tags.untag(config.scope, opts)
end

---@param opts? Grapple.Options
function M.toggle(opts)
    if M.exists(opts) then
        M.untag(opts)
    else
        M.tag(opts)
    end
end

---@param opts? Grapple.Options
function M.select(opts)
    local tag = M.find(opts)
    if tag ~= nil then
        tags.select(tag)
    end
end

---@param opts? Grapple.Options
function M.find(opts)
    opts = vim.tbl_extend("force", { buffer = 0 }, opts or {})
    return tags.find(config.scope, opts)
end

---@param opts? Grapple.Options
function M.key(opts)
    opts = vim.tbl_extend("force", { buffer = 0 }, opts or {})
    return tags.key(config.scope, opts)
end

---@param opts? Grapple.Options
function M.exists(opts)
    return M.key(opts) ~= nil
end

---@param opts? Grapple.Options
---@param direction Grapple.Direction
function M.cycle(opts, direction)
    local tag_key = M.key(opts)
    local start_index = (type(tag_key) == "number") and tag_key or 0
    local tag = tags.next(config.scope, start_index, direction)
    if tag ~= nil then
        tags.select(tag)
    end
end

---@param opts? Grapple.Options
function M.cycle_backward(opts)
    M.cycle(opts, types.direction.backward)
end

---@param opts? Grapple.Options
function M.cycle_forward(opts)
    M.cycle(opts, types.direction.forward)
end

---@param scope_? Grapple.Scope
function M.reset(scope_)
    tags.reset(scope_ or config.scope)
end

---@param scope_? Grapple.Scope
function M.popup_tags(scope_)
    scope_ = scope_ or config.scope
    local window_options = vim.deepcopy(config.popup_options)
    popup_tags.open(scope_, window_options)
end

function M.popup_scopes()
    local window_options = vim.deepcopy(config.popup_options)
    popup_scope.open(window_options)
end

function M.save()
    if config.scope == types.scope.none or config.integrations.resession then
        return
    end
    tags.save()
end

return M