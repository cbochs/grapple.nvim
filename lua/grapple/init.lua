local autocmds = require("grapple.autocmds")
local commands = require("grapple.commands")
local config = require("grapple.config")
local highlight = require("grapple.highlight")
local log = require("grapple.log")
local tags = require("grapple.tags")
local types = require("grapple.types")

local M = {}

--- @class Grapple.Options
--- @field buffer integer
--- @field index integer
--- @field name string
--- @field file_path string

---@param opts? Grapple.Config
function M.setup(opts)
    config.load(opts)
    log.new({ level = config.log_level })
    highlight.load()

    if config.scope ~= types.Scope.NONE and not config.integrations.resession then
        tags.load(config.save_path)
    end

    autocmds.create_autocmds()
    commands.create_commands()
end

---@param opts? Grapple.Options
function M.tag(opts)
    opts = vim.tbl_extend("force", { buffer = 0 }, opts or {})
    tags.tag(config.scope, opts)
end

---@param opts? Grapple.Options
function M.untag(opts)
    opts = opts or { buffer = 0 }
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
function M.find(opts)
    opts = opts or { buffer = 0 }
    return tags.find(config.scope, opts)
end

---@param opts? Grapple.Options
function M.key(opts)
    opts = opts or { buffer = 0 }
    return tags.key(config.scope, opts)
end

---@param opts? Grapple.Options
function M.exists(opts)
    return M.find(opts) ~= nil
end

---@param opts? Grapple.Options
function M.select(opts)
    local tag = M.find(opts)
    if tag ~= nil then
        tags.select(tag)
    end
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
    M.cycle(opts, types.Direction.BACKWARD)
end

---@param opts? Grapple.Options
function M.cycle_forward(opts)
    M.cycle(opts, types.Direction.FORWARD)
end

---@param scope? Grapple.Scope
function M.reset(scope)
    tags.reset(scope or config.scope)
end

return M
