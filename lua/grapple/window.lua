local Util = require("grapple.util")

---@class grapple.window
---@field content grapple.tag_content | grapple.scope_content
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
    if opts.title and opts.title == "{{ title }}" then
        if self:has_content() then
            local title = self.content:title()
            if title then
                opts.title = title
            else
                opts.title = nil
            end
        else
            opts.title = nil
        end
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

    -- Create temporary buffer
    self.buf_id = self:create_buffer()

    -- Create window
    local win_opts = self:window_options()
    self.win_id = vim.api.nvim_open_win(self.buf_id, true, win_opts)

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
        self.win_id = nil
        self.buf_id = nil
    end

    self.entries = nil
end

---@param content grapple.tag_content | grapple.scope_content
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

---@alias grapple.window.entity any

---@class grapple.window.entry
---@field data table
---@field line string
---@field index integer
---@field min_col integer
---@field highlights grapple.vim.highlight[]
---@field mark grapple.vim.extmark | nil

---@class grapple.window.parsed_entry
---@field data any
---@field line string
---@field index? integer
---@field min_col? integer
---@field highlights? grapple.vim.highlight[]
---@field mark? grapple.vim.extmark | nil

---@return grapple.window.parsed_entry[] | nil, string? error
function Window:parse_lines()
    if not self:is_rendered() then
        return nil, "window is not rendered"
    end

    ---@diagnostic disable: redefined-local
    local lines = vim.tbl_filter(Util.is_empty, self:lines())

    ---@type grapple.window.parsed_entry[]
    local parsed_entries = {}

    for _, line in ipairs(lines) do
        local entry = self.content:parse_line(line)
        table.insert(parsed_entries, entry)
    end

    return parsed_entries, nil
end

---@param line string
---@return integer min_col
function Window:minimum_column(line)
    local parsed_entry = self.content:parse_line(line)

    local index = parsed_entry.index
    if not index then
        return 0
    end

    return self.entries[index].min_col
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
---@return grapple.vim.extmark?
local function to_mark(entry)
    return entry.mark
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
        event = { "BufUnload", "BufLeave" },
        group = self.au_id,
        buffer = self.buf_id,
    })

    -- Replace active buffer
    self.buf_id = self:create_buffer()
    vim.api.nvim_win_set_buf(self.win_id, self.buf_id)

    -- Update window options
    local win_opts = self:window_options()
    vim.api.nvim_win_set_config(self.win_id, win_opts)

    -- Update window entries
    local entities, err = self.content:entities()
    if not entities then
        return err
    end

    self.entries = {}

    for i, entity in ipairs(entities) do
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

    for _, mark in ipairs(vim.tbl_map(to_mark, self.entries)) do
        vim.api.nvim_buf_set_extmark(self.buf_id, self.ns_id, mark.line, mark.col, mark.opts)
    end

    -- Attach the content to the rendered buffer
    ---@diagnostic disable-next-line: redefined-local
    local err = self.content:attach(self)
    if err then
        return err
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

    vim.keymap.set("n", "q", vim.cmd.close, { buffer = buf_id })
    vim.keymap.set("n", "<c-c>", vim.cmd.close, { buffer = buf_id })
    vim.keymap.set("n", "<esc>", vim.cmd.close, { buffer = buf_id })
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

---Safety: used only inside a callback hook when a window is open
---@param action grapple.action
---@param opts? grapple.action.options
---@return string? error
function Window:perform(action, opts)
    local err = self:close()
    if err then
        return err
    end

    ---@diagnostic disable-next-line: redefined-local
    local err = self.content:perform(action, opts)
    if err then
        return err
    end
end

---Safety: used only when a buffer is available
---@return grapple.window.parsed_entry
function Window:current_entry()
    local current_line = self:current_line()
    local entry = self.content:parse_line(current_line)
    return entry
end

---Safety: used only when a buffer is available
---@return string
function Window:current_line()
    return vim.api.nvim_get_current_line()
end

---Safety: used only when a buffer is available
function Window:lines()
    return vim.api.nvim_buf_get_lines(self.buf_id, 0, -1, true)
end

---Safety: used only inside a callback hook when a window is open
---@return integer[]
function Window:cursor()
    return vim.api.nvim_win_get_cursor(self.win_id)
end

return Window
