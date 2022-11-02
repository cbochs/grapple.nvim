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

    if config.scope ~= types.Scope.NONE then
        tags.load(config.save_path)
    end

    if config.integrations.portal then
        require("grapple.integrations.portal").load()
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

---@param scope? Grapple.Scope
function M.reset(scope)
    tags.reset(scope or config.scope)
end

return M
