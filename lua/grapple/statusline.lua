--[[
Remarks:
1. The statusline is opt-in: Can't be builtin to the app
2. Lualine: The statusline is far more responsive when using the on_update function!
--]]

local Grapple = require("grapple")

-- The data a formatter function uses to built the line
---@class grapple.statuslinedata
---@field scope_name string
---@field tags grapple.tag[]
---@field current? grapple.tag
---@field quick_select string[]

--The signature of a formatter function
---@alias grapple.formatter fun(opts: grapple.statusline.options, data: grapple.statuslinedata): string

---@class grapple.statusline
---@field cached_line string
---@field current_scope string
---@field formatter grapple.formatter
---@field on_update function
---@field opts grapple.statusline.options
---@field quick_select string[]
local Statusline = {}
Statusline.__index = Statusline

---A global instance of the statusline
---@type grapple.statusline
local statusline

local STATUSLINE_GROUP = vim.api.nvim_create_augroup("GrappleStatusline", { clear = true })

function Statusline.get()
    if statusline then
        return statusline
    end

    local app = require("grapple.app").get()
    statusline = Statusline:new(app)
    statusline:initialize()

    return statusline
end

---@param app grapple.app
---@return grapple.statusline
function Statusline:new(app)
    local se = app.settings
    return setmetatable({ -- apply defaults
        cached_line = "",
        current_scope = se.scope, -- updated on grapple.use_scope
        formatter = se.statusline.formatter,
        on_update = se.statusline.on_update,
        opts = se.statusline,
        quick_select = se:quick_select(), -- a constant
    }, self)
end

function Statusline:initialize()
    self:subscribe_to_events()
    self:subscribe_to_api() -- TODO: GrappleUpdate crashes!
    self:update_cached()
end

function Statusline:subscribe_to_events()
    vim.api.nvim_create_autocmd({ "BufEnter" }, {
        group = STATUSLINE_GROUP,
        pattern = "*",
        callback = function()
            self:update()
        end,
    })
    -- vim.api.nvim_create_autocmd({ "User" }, {
    --     group = STATUSLINE_GROUP,
    --     pattern = "GrappleScopeChanged",
    --     callback = function()
    --         self:update()
    --     end,
    -- })
    -- vim.api.nvim_create_autocmd({ "User" },
    --     group = STATUSLINE_GROUP,
    --     nested = false,
    --     pattern = "GrappleUpdate",
    --     callback = function()
    --         self:update()
    --     end,
    -- })
end

-- Decorate Grapple's api in order to update internally
function Statusline:subscribe_to_api()
    local function decorate(org_cmd)
        return function(...)
            org_cmd(...) -- Run the api function
            self:update() -- and update internally
        end
    end

    Grapple.toggle = decorate(Grapple.toggle)
    Grapple.tag = decorate(Grapple.tag)
    Grapple.untag = decorate(Grapple.untag)
    Grapple.reset = decorate(Grapple.reset)

    local grapple_use_scope = Grapple.use_scope
    ---@diagnostic disable-next-line: duplicate-set-field
    Grapple.use_scope = function(scope_name)
        grapple_use_scope(scope_name)
        self.current_scope = scope_name
        self:update()
    end
end

-- Update the cache
function Statusline:update_cached()
    local tags, _ = Grapple.tags() -- using the current scope

    ----@type grapple.statuslinedata
    local data = {
        current = Grapple.find({ buffer = 0 }),
        scope_name = self.current_scope,
        tags = tags or {},
        quick_select = self.quick_select,
    }

    self.cached_line = self.formatter(self.opts, data)
end

-- Update the cache and notify consumers
function Statusline:update()
    self:update_cached()
    self:on_update()
end

-- The function to be used by consumers
-- Returns a cached statusline
---@return string
function Statusline:format()
    return self.cached_line
end

return Statusline
