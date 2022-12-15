local path = require("grapple.path")

local log = {}

local _logger = {}

---@class Grapple.LogMode
---@field name string
---@field highlight string

---@class Grapple.LogSettings
local DEFAULT_SETTINGS = {
    plugin_name = "grapple",
    log_level = "warn",
    log_dir = path.normalize(vim.fn.stdpath("cache")),

    use_console = false,
    use_file = true,
    highlight = true,
}

-- stylua: ignore start
---@type Grapple.LogMode[]
local DEFAULT_MODES = {
    { name = "debug",  highlight = "Comment" },
    { name = "info",   highlight = "None" },
    { name = "warn",   highlight = "WarningMsg" },
    { name = "error",  highlight = "ErrorMsg" },
    { name = "fatal",  highlight = "ErrorMsg" },
}
-- stylua: ignore end

---@param level string
---@param info string
---@param date string
---@param message string
local function format_log(level, info, date, message)
    return string.format("[%-6s%s] %s: %s", level:upper(), date, info, message)
end

---@param formatted_lines string[]
---@param highlight string | nil
local function console_log(formatted_lines, highlight)
    if highlight ~= nil then
        vim.cmd(string.format("echohl %s", highlight))
    end

    for _, line in ipairs(formatted_lines) do
        vim.cmd(string.format([[echom "%s"]], line))
    end

    if highlight ~= nil then
        vim.cmd("echohl NONE")
    end
end

---@param level_name string
---@param modes Grapple.LogMode[]
local function get_log_level(level_name, modes)
    for mode_level, mode in ipairs(modes) do
        if level_name == mode.name then
            return mode_level
        end
    end
end

---@param settings? Grapple.LogSettings
---@param modes? Grapple.LogMode[]
function log.new(settings, modes)
    ---@type Grapple.LogSettings
    settings = vim.tbl_extend("force", DEFAULT_SETTINGS, settings or {})
    modes = modes or DEFAULT_MODES

    local logger = {}
    local log_dir = settings.log_dir
    local log_name = string.format("%s.log", settings.plugin_name)
    local log_path = path.append(log_dir, log_name)
    local log_level = get_log_level(settings.log_level, modes)

    if settings.use_file and not path.exists(log_dir) then
        path.mkdir(log_dir)
    end

    for mode_level, mode in ipairs(modes) do
        -- logger[mode.name .. "_fmt"] = function(...) end
        logger[mode.name] = function(message)
            if mode_level < log_level then
                return
            end

            local info = debug.getinfo(2, "Sl")
            local info_short = string.format("%s:%s", info.short_src, info.currentline)

            if settings.use_console then
                local date = os.date("%H:%M:%S")
                local formatted_message = format_log(mode.name, info_short, date, message)
                local formatted_lines = vim.tbl_map(function(line)
                    return string.format("[%s] %s", settings.plugin_name, vim.fn.escape(line, '"'))
                end, vim.split(formatted_message, "\n"))
                console_log(formatted_lines, settings.highlight and mode.highlight or nil)
            end

            if settings.use_file then
                local date = os.date()
                local formatted_message = format_log(mode.name, info_short, date, message)
                path.write(log_path, formatted_message .. "\n", "a")
            end
        end
    end

    return logger
end

---@param settings? Grapple.LogSettings
function log.global(settings)
    _logger = log.new(settings)
end

-- Create default logger
log.global()

setmetatable(log, {
    __index = function(_, index)
        return _logger[index]
    end,
})

return log
