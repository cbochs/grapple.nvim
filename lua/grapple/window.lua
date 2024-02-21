---@class grapple.window
---@field content grapple.tag.content
---@field hook fun(window: grapple.window): string? | nil
---@field buf_id integer
---@field win_id integer
---@field ns_id integer
---@field augroup integer
local Window = {}
Window.__index = Window

---@param content grapple.tag.content
---@param hook? fun(window: grapple.window): string?
---@return grapple.window
function Window:new(content, hook)
    return setmetatable({
        content = content,
        hook = hook,
        buf_id = nil,
        win_id = nil,
        ns_id = nil,
        augroup = nil,
    }, self)
end

---@param opts grapple.vim.win_opts
---@return grapple.vim.win_opts valid_opts
function Window:canonicalize(opts)
    ---@diagnostic disable-next-line: redefined-local
    local opts = vim.tbl_deep_extend("keep", opts, {})

    -- window title
    if opts.title and type(opts.title) == "function" then
        opts.title = opts.title()
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

---@param opts grapple.vim.win_opts?
function Window:open(opts)
    if self:is_open() then
        return
    end

    local win_opts = self:canonicalize(opts or {})

    -- Create temporary buffer
    self.buf_id = vim.api.nvim_create_buf(false, false)
    vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = self.buf_id })

    -- Create window
    self.win_id = vim.api.nvim_open_win(self.buf_id, true, win_opts)

    -- Create or get virtual text namespace
    self.ns_id = vim.api.nvim_create_namespace("grapple")
end

---@return string? error
function Window:reconcile()
    if self:is_closed() then
        return
    end

    local err = self.content:reconcile(self.buf_id)
    if err then
        return err
    end
end

function Window:close()
    if self:is_closed() then
        return
    end

    if vim.api.nvim_win_is_valid(self.win_id) then
        vim.api.nvim_win_close(self.win_id, true)
    end

    self.win_id = nil
    self.buf_id = nil
    self.ns_id = nil
    self.augroup = nil
end

---@return string? error
function Window:render()
    if not self:is_open() then
        return "window is not open"
    end

    -- Store cursor location to reposition later
    local cursor = vim.api.nvim_win_get_cursor(self.win_id)

    -- Create or get autocommand group
    self.augroup = vim.api.nvim_create_augroup("Grapple", { clear = true })

    -- Create content buffer
    self.buf_id = vim.api.nvim_create_buf(false, true)

    -- Set buffer options
    vim.api.nvim_set_option_value("filetype", "grapple", { buf = self.buf_id })
    vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = self.buf_id })

    -- Update and render content
    local err = self.content:update()
    if err then
        return err
    end
    self.content:render(self.buf_id, self.ns_id)

    -- Set active buffer and restore cursor
    vim.api.nvim_win_set_buf(self.win_id, self.buf_id)
    vim.api.nvim_win_set_cursor(self.win_id, cursor)

    -- Notify hook
    if self.hook then
        ---@diagnostic disable-next-line: redefined-local
        local err = self.hook(self)
        if err then
            return err
        end
    end
end

-- See :h vim.keymap.set
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
---@param event any
---@param opts vim.api.keyset.create_autocmd
function Window:autocmd(event, opts)
    vim.api.nvim_create_autocmd(
        event,
        vim.tbl_extend("force", opts or {}, {
            group = self.augroup,
            buffer = self.buf_id,
        })
    )
end

---@param index? integer
---@return string? error
function Window:select(index)
    if not index then
        local cursor = vim.api.nvim_win_get_cursor(self.win_id)
        index = cursor[1]
    end

    local err = self:reconcile()
    if err then
        return err
    end

    ---@diagnostic disable-next-line: redefined-local
    local err = self.content:select(index)
    if err then
        return err
    end

    self:close()
end

---@return string? error
function Window:quickfix()
    if self:is_closed() then
        return
    end

    local err = self:reconcile()
    if err then
        return err
    end

    local list = self.content:quickfix()
    if #list > 0 then
        vim.fn.setqflist(list, "r")
        vim.cmd.copen()
    end

    self:close()
end

return Window
