---@class grapple.window
---@field content grapple.tag.content
---@field ns_id integer
---@field au_id integer
---@field buf_id integer
---@field win_id integer
---@field win_opts grapple.vim.win_opts
---@field rendered boolean
local Window = {}
Window.__index = Window

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
        ns_id = WINDOW_NS,
        au_id = WINDOW_GROUP,
        buf_id = nil,
        win_id = nil,
        win_opts = win_opts or {},
        rendered = false,
    }, self)
end

---Create a valid nvim api window configuration
---@return grapple.vim.win_opts win_opts
function Window:canonicalize()
    local opts = vim.tbl_deep_extend("keep", self.win_opts, {})

    -- window title
    if self:has_content() then
        local title = self.content:title()
        if title then
            opts.title = title
        end
    end

    if not opts.title then
        opts.title_pos = nil
    end

    if opts.title and opts.title_padding then
        opts.title = string.format("%s%s%s", opts.title_padding, opts.title, opts.title_padding)
        opts.title_padding = nil
    end

    -- window size
    if opts.width and opts.width < 1 then
        opts.width = math.floor(vim.o.columns * opts.width)
        assert(opts.width >= 1)
    end

    if opts.height and opts.height < 1 then
        opts.height = math.floor(vim.o.lines * opts.height)
        assert(opts.height >= 1)
    end

    -- window position
    if opts.row and opts.row < 1 then
        opts.row = math.floor((vim.o.lines - opts.height) * opts.row - 1)
        assert(opts.row >= 0)
    end

    if opts.col and opts.col < 1 then
        opts.col = math.floor((vim.o.columns - opts.width) * opts.col - 1)
        assert(opts.col >= 0)
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

---@return boolean
function Window:is_rendered()
    return self:is_open() and self:has_content() and self.rendered
end

function Window:open()
    if self:is_open() then
        return
    end

    -- Create temporary buffer
    self.buf_id = self:create_buffer()

    -- Create window
    local win_opts = self:canonicalize()

    self.win_id = vim.api.nvim_open_win(self.buf_id, true, win_opts)
    vim.api.nvim_set_option_value("concealcursor", "nvic", { win = self.win_id })
    vim.api.nvim_set_option_value("conceallevel", 3, { win = self.win_id })
end

---@return string? error
function Window:close()
    if self:is_closed() then
        return
    end

    -- Defer closing window
    vim.schedule(function()
        if vim.api.nvim_win_is_valid(self.win_id) then
            vim.api.nvim_win_close(self.win_id, true)
            self.win_id = nil
            self.buf_id = nil
        end
    end)

    if self:is_rendered() then
        self.rendered = false
        local err = self.content:sync(self.buf_id)
        if err then
            return err
        end
    end
end

---@param content grapple.tag.content
---@return string? error
function Window:attach(content)
    if self:has_content() and self.content:id() ~= content:id() then
        local err = self:detach()
        if err then
            return err
        end
    end

    self.content = content
    self.rendered = false
end

---@return string? error
function Window:detach()
    if self:is_rendered() then
        local err = self.content:detach(self.buf_id)
        if err then
            return err
        end
    end

    self.content = nil
    self.rendered = false
end

---@return string? error
function Window:refresh()
    if not self:is_rendered() then
        return "window is not rendered"
    end

    local err = self.content:sync(self.buf_id)
    if err then
        return err
    end

    ---@diagnostic disable-next-line: redefined-local
    local err = self:render()
    if err then
        return err
    end
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

    -- Prevent "BufWinLeave" from closing the window
    vim.api.nvim_clear_autocmds({
        event = { "BufUnload", "BufWinLeave" },
        group = self.au_id,
        buffer = self.buf_id,
    })

    -- Replace active buffer
    self.buf_id = self:create_buffer()
    vim.api.nvim_win_set_buf(self.win_id, self.buf_id)

    -- Update window options
    local win_opts = self:canonicalize()
    vim.api.nvim_win_set_config(self.win_id, win_opts)

    -- Safety: we are guaranteed to have content by this point
    local err = self.content:update()
    if err then
        return err
    end

    ---@diagnostic disable-next-line: redefined-local
    local err = self.content:attach(self)
    if err then
        return err
    end

    ---@diagnostic disable-next-line: redefined-local
    self.content:render(self.buf_id, self.ns_id)

    -- Prevent undo after content has been rendered. Set undolevels to -1 before
    -- rendering and then set back to its global default afterwards
    -- See :h clear-undo
    local undolevels = vim.api.nvim_get_option_value("undolevels", { scope = "global" })
    vim.api.nvim_set_option_value("undolevels", undolevels, { buf = self.buf_id })

    -- Restore cursor location
    local ok = pcall(vim.api.nvim_win_set_cursor, 0, cursor)
    if not ok then
        vim.api.nvim_win_set_cursor(self.win_id, { 1, 0 })
    end

    self.rendered = true
end

function Window:create_buffer()
    local buf_id = vim.api.nvim_create_buf(false, true)

    vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf_id })
    vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf_id })
    vim.api.nvim_set_option_value("filetype", "grapple", { buf = buf_id })
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

        local cursor = vim.api.nvim_win_get_cursor(self.win_id)
        local line = vim.api.nvim_get_current_line()
        local expected_column = self.content:minimum_column(line)
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

    vim.api.nvim_create_autocmd({ "BufWinLeave", "WinLeave" }, {
        group = self.au_id,
        buffer = buf_id,
        once = true,
        callback = function(opts)
            local err = self:close()
            if err then
                vim.notify(err, vim.log.levels.ERROR)
            end

            vim.api.nvim_clear_autocmds({
                event = { "BufUnload", "BufWinLeave", "WinLeave" },
                group = self.au_id,
                buffer = self.buf_id,
            })
        end,
    })

    vim.api.nvim_create_autocmd({ "VimResized" }, {
        group = self.au_id,
        buffer = buf_id,
        callback = function()
            local win_opts = self:canonicalize()
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

---Safety: used only inside a callback hook when a window is open
---@return integer[]
function Window:cursor()
    return vim.api.nvim_win_get_cursor(self.win_id)
end

function Window:current_line()
    return vim.api.nvim_get_current_line()
end

return Window
