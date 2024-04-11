--[[
Remarks:
The statusline is opt-in: Can't be builtin to the app
Lualine: The statusline is far more responsive when using the on_event function!
Perhaps: 
  The default formatter: Add empty_slots, more_marks and scope_name
  See test case "custom formatter"
Test with mini.statusline

 TODO: public/non_public: Add "_" to names?
 TODO: Remove the second statusline example from the docs, in favor of builtin_formatter = "short"
 TODO: The docs...
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
---@field current? grapple.tag
---@field current_scope string
---@field formatter grapple.formatter
---@field on_event function
---@field opts grapple.statusline.options
---@field quick_select string[]
local Statusline = {}
Statusline.__index = Statusline

---A global instance of the statusline
---@type grapple.statusline
local statusline

local STATUSLINE_GROUP = vim.api.nvim_create_augroup("GrappleStatusline", { clear = true })

---@type grapple.formatter
function Statusline.default_formatter(opts, data)
    if #data.tags == 0 then
        return ""
    end

    local output = {}
    local qs = data.quick_select
    for i, tag in ipairs(data.tags) do
        local tag_str = tag.name and tag.name or qs[i] and qs[i] or i
        local tag_fmt = opts.inactive
        if data.current and data.current.path == tag.path then
            tag_fmt = opts.active
        end
        table.insert(output, string.format(tag_fmt, tag_str))
    end

    local result = table.concat(output)
    if opts.include_icon then
        result = string.format("%s %s", opts.icon, result)
    end

    return result
end

---@type grapple.formatter
function Statusline.short_formatter(_, data) -- name_or_index
    if #data.tags == 0 then
        return ""
    end

    local result = ""
    for i, tag in ipairs(data.tags) do
        if data.current and data.current.path == tag.path then
            local tag_str = tag.name and tag.name or i
            result = "" .. tag_str
            break
        end
    end
    return result
end

---@param app grapple.app
---@return grapple.statusline
function Statusline:new(app)
    local se = app.settings

    local formatter = se.statusline.formatter -- a custom user function
    if formatter == nil then
        local builtin = Statusline.formatters[se.statusline.builtin_formatter]
        formatter = builtin and builtin or Statusline.default_formatter
    end

    return setmetatable({ -- apply defaults
        cached_line = "",
        current = nil,
        current_scope = se.scope, -- updated on grapple.use_scope
        formatter = formatter,
        on_event = se.statusline.on_event_factory(), -- can be nil
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
    self.current = Grapple.find({ buffer = 0 })
    local tags, _ = Grapple.tags() -- using the current scope

    self.cached_line = self.formatter(self.opts, {
        current = self.current,
        scope_name = self.current_scope,
        tags = tags or {},
        quick_select = self.quick_select,
    })
end

-- Update the cache and notify consumers
function Statusline:update()
    self:update_cached()
    if not self.on_event then
        self.on_event = self:produce_on_event()
    end
    self:on_event()
end

-- Produce an on_event function notifying a statusline consumer
---@return function
function Statusline:produce_on_event()
    local supported = {
        {
            [[lualine]],
            function()
                require("lualine").refresh()
            end,
        },
        {
            [[mini.statusline]],
            function()
                vim.wo.statusline = "%{%v:lua.MiniStatusline.active()%}"
            end,
        },
    }
    local default = function() -- heirline, nvchad
        vim.cmd.redrawstatus()
    end
    local result
    for _, item in ipairs(supported) do
        local has, _ = pcall(require, item[1])
        if has then
            result = item[2]
            break
        end
    end
    return result or default
end

--          ╭─────────────────────────────────────────────────────────╮
--          │                       Public api                        │
--          ╰─────────────────────────────────────────────────────────╯
---@class grapple.statuslinebuiltins
Statusline.formatters = {
    default = Statusline.default_formatter, -- first example
    short = Statusline.short_formatter, -- second example
}

function Statusline.get()
    if statusline then
        return statusline
    end

    local app = require("grapple.app").get()
    statusline = Statusline:new(app)
    statusline:initialize()

    return statusline
end

-- The function to be used by consumers
-- Returns a cached statusline
---@return string
function Statusline:format()
    return self.cached_line
end

--- Is the current buffer tagged. Uses the last seen "current" tag
---@return boolean
function Statusline:is_current_buffer_tagged()
    return self.current ~= nil
end

return Statusline
