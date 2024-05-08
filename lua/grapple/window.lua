local Path = require("grapple.path")
local Util = require("grapple.util")

---@class grapple.window
---@field content grapple.tag_content | grapple.scope_content | grapple.container_content
---@field entries grapple.window.entry[]
---@field ns_id integer
---@field au_id integer
---@field buf_id integer
---@field win_id integer
---@field win_opts grapple.vim.win_opts
local Window = {}
Window.__index = Window

---@alias grapple.hook_fn fun(window: grapple.window): string? error
---@alias grapple.title_fn fun(...: any): string?

-- Create global namespace for Grapple windows
local WINDOW_NS = vim.api.nvim_create_namespace("grapple")

-- Create global autocommand group for Grapple windows. All autocommands are
-- buffer-local and will be cleared whenever the buffer is closed.
local WINDOW_GROUP = vim.api.nvim_create_augroup("GrappleWindow", { clear = true })

---@param win_opts? grapple.vim.win_opts
---@return grapple.window
function Window:new(win_opts)
    return setmetatable({
        content = nil,
        entries = nil,
        ns_id = WINDOW_NS,
        au_id = WINDOW_GROUP,
        buf_id = nil,
        win_id = nil,
        alt_win = nil,
        win_opts = win_opts or {},
    }, self)
end

---Create a valid nvim api window configuration
---@return vim.api.keyset.win_config win_opts
function Window:window_options()
    ---@type vim.api.keyset.win_config
    ---@diagnostic disable-next-line: assign-type-mismatch
    local opts = vim.tbl_deep_extend("keep", self.win_opts, {})

    -- Window title
    if self:has_content() and self.content:title() then
        opts.title = self.content:title()
    end

    if opts.title and opts.title_padding then
        opts.title = string.format("%s%s%s", opts.title_padding, opts.title, opts.title_padding)
    end

    if not opts.title then
        opts.title_pos = nil
    end

    -- Remove custom fields
    if opts.title_padding then
        opts.title_padding = nil
    end

    -- Add "help" footer for nvim-0.10
    if vim.fn.has("nvim-0.10") == 1 then
        opts.footer = "Press '?' to toggle Help"
        opts.footer_pos = "center"
    end

    -- Window size
    if opts.width and opts.width < 1 then
        opts.width = math.max(1, math.floor(vim.o.columns * opts.width))
    end

    if opts.height and opts.height < 1 then
        opts.height = math.max(1, math.floor(vim.o.lines * opts.height))
    end

    -- Window position
    if opts.row and opts.row < 1 then
        opts.row = math.max(0, math.floor((vim.o.lines - opts.height) * opts.row - 1))
    end

    if opts.col and opts.col < 1 then
        opts.col = math.max(0, math.floor((vim.o.columns - opts.width) * opts.col - 1))
    end

    return opts
end

---@return boolean
function Window:is_open()
    return self.win_id ~= nil
end

---@return boolean
function Window:is_closed()
    return not self:is_open()
end

---@return boolean
function Window:has_content()
    return self.content ~= nil
end

function Window:has_entries()
    return self.entries ~= nil
end

---@return boolean
function Window:is_rendered()
    return self:is_open() and self:has_content() and self:has_entries()
end

function Window:open()
    if self:is_open() then
        return
    end

    -- Store current window as the "alternate window"
    self.alt_win = vim.api.nvim_get_current_win()

    -- Create temporary buffer
    self.buf_id = self:create_buffer()

    -- Create window
    local win_opts = self:window_options()
    self.win_id = vim.api.nvim_open_win(self.buf_id, true, win_opts)

    -- Set window highlights
    self:set_highlight("NormalFloat", "GrappleNormal")
    self:set_highlight("FloatBorder", "GrappleBorder")
    self:set_highlight("FloatTitle", "GrappleTitle")
    self:set_highlight("FloatFooter", "GrappleFooter")

    -- Setup window to conceal line IDs
    vim.api.nvim_set_option_value("concealcursor", "nvic", { win = self.win_id })
    vim.api.nvim_set_option_value("conceallevel", 3, { win = self.win_id })
end

---@return string? error
function Window:close()
    if self:is_closed() then
        return
    end

    local err = self:sync()
    if err then
        return err
    end

    if vim.api.nvim_win_is_valid(self.win_id) then
        vim.api.nvim_win_close(self.win_id, true)
    end

    self.win_id = nil
    self.buf_id = nil
    self.alt_win = nil
    self.entries = nil
end

---@param content grapple.tag_content | grapple.scope_content | grapple.container_content
---@return string? error
function Window:attach(content)
    if self:has_content() then
        local err = self:detach()
        if err then
            return err
        end
    end

    self.content = content
    self.entries = nil
end

---@return string? error
function Window:detach()
    if not self:has_content() then
        return
    end

    local err = self.content:detach(self)
    if err then
        return err
    end

    ---@diagnostic disable-next-line: redefined-local
    local err = self:sync()
    if err then
        return err
    end

    self.content = nil
    self.entries = nil
end

---@return string? error
function Window:sync()
    if not self:is_rendered() then
        return
    end

    local parsed_entries, err = self:parse_lines()
    if not parsed_entries then
        return err
    end

    ---@diagnostic disable-next-line: redefined-local
    local err = self.content:sync(self.entries, parsed_entries)
    if err then
        return err
    end

    return nil
end

---@class grapple.window.entity
---@field current boolean
---@field ... any

---@class grapple.window.entry
---@field data table
---@field line string
---@field index integer
---@field min_col integer unused now
---@field highlights grapple.vim.highlight[]
---@field extmarks grapple.vim.extmark[]

---@class grapple.window.parsed_entry
---@field data any
---@field line string
---@field modified boolean unused (for now)
---@field index? integer
---@field min_col? integer unused now
---@field highlights? grapple.vim.highlight[]
---@field extmarks? grapple.vim.extmark[]

---@return grapple.window.parsed_entry[] | nil, string? error
function Window:parse_lines()
    if not self:is_rendered() then
        return nil, "window is not rendered"
    end

    if not vim.api.nvim_buf_is_valid(self.buf_id) then
        return nil, "buffer is not valid"
    end

    ---@diagnostic disable: redefined-local
    local lines = vim.tbl_filter(Util.not_empty, self:lines())

    ---@type grapple.window.parsed_entry[]
    local parsed_entries = {}

    for _, line in ipairs(lines) do
        local entry = self.content:parse_line(line, self.entries)
        table.insert(parsed_entries, entry)
    end

    return parsed_entries, nil
end

---@param line string
---@return integer min_col
function Window:minimum_column(line)
    return self.content:minimum_column(line)
end

---@return string? error
function Window:refresh()
    if not self:is_rendered() then
        return "window is not rendered"
    end

    local err = self:sync()
    if err then
        return err
    end

    ---@diagnostic disable-next-line: redefined-local
    local err = self:render()
    if err then
        return err
    end
end

---Convenience function for getting the line for an entry
---@param entry grapple.window.entry
---@return string line
local function to_line(entry)
    return entry.line
end

---Convenience function for getting the highlights for an entry
---@param entry grapple.window.entry
---@return grapple.vim.highlight[]
local function to_highlights(entry)
    return entry.highlights
end

---Convenience function for getting the extmark for an entry
---@param entry grapple.window.entry
---@return grapple.vim.extmark[]
local function to_extmarks(entry)
    return entry.extmarks
end

---@return string? error
function Window:render()
    if self:is_closed() then
        return "window is not open"
    end

    if not self:has_content() then
        return "no content available"
    end

    -- Store cursor location to reposition later
    local cursor = vim.api.nvim_win_get_cursor(self.win_id)

    -- Prevent "BufLeave" from closing the window
    vim.api.nvim_clear_autocmds({
        event = { "BufLeave" },
        group = self.au_id,
        buffer = self.buf_id,
    })

    -- Replace active buffer
    self.buf_id = self:create_buffer()
    vim.api.nvim_win_set_buf(self.win_id, self.buf_id)

    -- Update window options
    local win_opts = self:window_options()
    vim.api.nvim_win_set_config(self.win_id, win_opts)

    -- Attach the content to the window
    ---@diagnostic disable-next-line: redefined-local
    local err = self.content:attach(self)
    if err then
        return err
    end

    -- Update window entries
    local entities, err = self.content:entities()
    if not entities then
        return err
    end

    self.entries = {}

    for i, entity in ipairs(entities) do
        -- Change the cursor if the cursor is at the default position (1, 0)
        if entity.current and cursor[1] == 1 and cursor[2] == 0 then
            cursor = { i, 0 }
        end

        local entry = self.content:create_entry(entity, i)
        table.insert(self.entries, entry)
    end

    -- Render entries to the buffer
    vim.api.nvim_set_option_value("modifiable", true, { buf = self.buf_id })
    vim.api.nvim_buf_set_lines(self.buf_id, 0, -1, true, vim.tbl_map(to_line, self.entries))
    vim.api.nvim_set_option_value("modifiable", self.content:modifiable(), { buf = self.buf_id })

    for _, entry_hl in ipairs(vim.tbl_map(to_highlights, self.entries)) do
        for _, hl in ipairs(entry_hl) do
            vim.api.nvim_buf_add_highlight(self.buf_id, self.ns_id, hl.hl_group, hl.line, hl.col_start, hl.col_end)
        end
    end

    for _, entry_extmarks in ipairs(vim.tbl_map(to_extmarks, self.entries)) do
        for _, extmark in ipairs(entry_extmarks) do
            vim.api.nvim_buf_set_extmark(self.buf_id, self.ns_id, extmark.line, extmark.col, extmark.opts)
        end
    end

    -- Prevent undo after content has been rendered. Set undolevels to -1 when
    -- creating the buffer and then set back to its global default afterwards
    -- See :h clear-undo
    local undolevels = vim.api.nvim_get_option_value("undolevels", { scope = "global" })
    vim.api.nvim_set_option_value("undolevels", undolevels, { buf = self.buf_id })

    -- Restore cursor location
    local ok = pcall(vim.api.nvim_win_set_cursor, 0, cursor)
    if not ok then
        vim.api.nvim_win_set_cursor(self.win_id, { 1, 0 })
    end
end

---@return integer buf_id
function Window:create_buffer()
    local buf_id = vim.api.nvim_create_buf(false, true)

    vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf_id })
    vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf_id })
    vim.api.nvim_set_option_value("filetype", "grapple", { buf = buf_id })
    vim.api.nvim_set_option_value("modifiable", false, { buf = buf_id })
    vim.api.nvim_set_option_value("syntax", "grapple", { buf = buf_id })
    vim.api.nvim_set_option_value("undolevels", -1, { buf = buf_id })

    self:create_buffer_defaults(buf_id)

    return buf_id
end

function Window:create_buffer_defaults(buf_id)
    local function constrain_cursor()
        if not self:is_rendered() then
            return
        end

        local line = self:current_line()
        local expected_column = self:minimum_column(line)
        local cursor = vim.api.nvim_win_get_cursor(self.win_id)

        if cursor[2] < expected_column then
            vim.api.nvim_win_set_cursor(self.win_id, { cursor[1], expected_column })
        end
    end

    vim.api.nvim_create_autocmd("CursorMoved", {
        group = self.au_id,
        buffer = buf_id,
        callback = constrain_cursor,
    })

    vim.api.nvim_create_autocmd("InsertEnter", {
        group = self.au_id,
        buffer = buf_id,
        callback = vim.schedule_wrap(constrain_cursor),
    })

    vim.api.nvim_create_autocmd({ "BufLeave", "WinLeave" }, {
        group = self.au_id,
        buffer = buf_id,
        callback = function()
            local err = self:close()
            if err then
                vim.notify(err, vim.log.levels.ERROR)
            end

            -- Only run once
            vim.api.nvim_clear_autocmds({
                event = { "BufLeave", "WinLeave" },
                group = self.au_id,
                buffer = self.buf_id,
            })
        end,
    })

    vim.api.nvim_create_autocmd({ "VimResized" }, {
        group = self.au_id,
        buffer = buf_id,
        callback = function()
            local win_opts = self:window_options()
            vim.api.nvim_win_set_config(self.win_id, win_opts)
        end,
    })

    vim.keymap.set("n", "q", vim.cmd.close, { buffer = buf_id, desc = "Close" })
    vim.keymap.set("n", "<c-c>", vim.cmd.close, { buffer = buf_id, desc = "Close" })
    vim.keymap.set("n", "<esc>", vim.cmd.close, { buffer = buf_id, desc = "Close" })
end

-- See :h vim.keymap.set
---Safety: used only inside a callback hook when a window is open
---@param mode string | table
---@param lhs string
---@param rhs string | function
---@param opts table | nil
function Window:map(mode, lhs, rhs, opts)
    vim.keymap.set(
        mode,
        lhs,
        rhs,
        vim.tbl_extend("force", opts or {}, {
            buffer = self.buf_id,
        })
    )
end

---See :h vim.api.nvim_create_autocmd
---Safety: used only inside a callback hook when a window is open
---@param event any
---@param opts vim.api.keyset.create_autocmd
function Window:autocmd(event, opts)
    vim.api.nvim_create_autocmd(
        event,
        vim.tbl_extend("force", opts or {}, {
            group = self.au_id,
            buffer = self.buf_id,
        })
    )
end

---Perform an action. Action may be sync or async. Prefer perform_close or
---perform_retain to ensure window state is synced with the content state
---before action is attempted.
---Safety: used only inside a callback hook when a window is open
---@param action grapple.action
---@param opts? grapple.action.options
---@return string? error
function Window:perform(action, opts)
    opts = vim.tbl_extend("force", opts or {}, {
        window = self,
    })

    ---@diagnostic disable-next-line: redefined-local
    local err = self.content:perform(action, opts)
    if err then
        return err
    end
end

---Perform an action after closing the Grapple window
---Safety: used only inside a callback hook when a window is open
---@param action grapple.action
---@param opts? grapple.action.options
---@return string? error
function Window:perform_close(action, opts)
    local err = self:close()
    if err then
        return err
    end

    return self:perform(action, opts)
end

---Perform an action, ensuring the Grapple window is not closed
---Safety: used only inside a callback hook when a window is open
---@param action grapple.action
---@param opts? grapple.action.options
---@return string? error
function Window:perform_retain(action, opts)
    local err = self:sync()
    if err then
        return err
    end

    -- Prevent "BufLeave" or "WinLeave" from closing the window
    vim.api.nvim_clear_autocmds({
        event = { "BufLeave", "WinLeave" },
        group = self.au_id,
        buffer = self.buf_id,
    })

    return self:perform(action, opts)
end

---Returns a parsed entry for the current line
---Safety: used only inside a callback hook when a window is open
---@return grapple.window.parsed_entry
function Window:current_entry()
    local current_line = self:current_line()
    local entry = self.content:parse_line(current_line, self.entries)
    return entry
end

---Returns a parsed entry for a line at a given index
---Safety: used only inside a callback hook when a window is open
---@param opts { index: integer }
---@return grapple.window.parsed_entry | nil, string? error
function Window:entry(opts)
    local lines = self:lines()

    local line = lines[opts.index]
    if not line then
        return nil, string.format("no entry for index: %s", opts.index)
    end

    local entry = self.content:parse_line(line, self.entries)

    return entry, nil
end

---Safety: used only inside a callback hook when a window is open
---@return string
function Window:current_line()
    return vim.api.nvim_get_current_line()
end

---Safety: used only inside a callback hook when a window is open
---@return string[]
function Window:lines()
    return vim.api.nvim_buf_get_lines(self.buf_id, 0, -1, true)
end

---Safety: used only inside a callback hook when a window is open
---@return integer[]
function Window:cursor()
    return vim.api.nvim_win_get_cursor(self.win_id)
end

---Returns the path for the buffer from current window before opening the
---Grapple window. In a sense, it's like vim's alternate file
---Safety: used only inside a callback hook when a window is open
---@return string | nil
function Window:alternate_path()
    -- It's possible that the alternate window is not valid after opening the
    -- grapple window. For example, opening Grapple from Telescope
    if not vim.api.nvim_win_is_valid(self.alt_win) then
        return
    end

    local alt_buf = vim.api.nvim_win_get_buf(self.alt_win)
    local alt_name = vim.api.nvim_buf_get_name(alt_buf)

    if alt_name == "" then
        return
    end

    return Path.fs_absolute(alt_name)
end

--- Replaces a highlight group in the window
--- @param new_from string
--- @param new_to string
function Window:set_highlight(new_from, new_to)
    local new_entry = new_from .. ":" .. new_to
    local replace_pattern = string.format("(%s:[^,]*)", vim.pesc(new_from))
    local new_winhighlight, n_replace = vim.wo[self.win_id].winhighlight:gsub(replace_pattern, new_entry)
    if n_replace == 0 then
        new_winhighlight = new_winhighlight .. "," .. new_entry
    end

    pcall(function()
        vim.wo[self.win_id].winhighlight = new_winhighlight
    end)
end

return Window
