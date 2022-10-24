local autocmds = require("grapple.autocmds")
local commands = require("grapple.commands")
local config = require("grapple.config")
local jump = require("grapple.jump")
local log = require("grapple.log")
local marks = require("grapple.marks")

local M = {}

---PLugin entrypoint.
---@param opts? GrappleConfig
function M.setup(opts)
    log.new({ level = "error" }, true)
    config.load(opts)

    log.new(config.log)
    marks.load(config.state_path)
    autocmds.create_autocmds()
    commands.create_commands()
end

-- Marks API
M.mark = marks.mark
M.unmark = marks.unmark
M.toggle = marks.toggle
M.select = marks.select
M.reset = marks.reset

-- Jump API
M.jump_forward = jump.jump_forward
M.jump_backward = jump.jump_backward

return M
