---@class grapple.window
---@field content grapple.tag.content
---@field ns_id integer
---@field au_id integer
---@field buf_id integer
---@field win_id integer
---@field win_opts grapple.vim.win_opts
local Window = {}
Window.__index = Window

---@param win_opts? grapple.vim.win_opts
---@return grapple.window
function Window:new(win_opts)
    return setmetatable({
        content = nil,
        ns_id = nil,
        au_id = nil,
        buf_id = nil,
        win_id = nil,
        win_opts = win_opts or {},
    }, self)
end

---@param opts grapple.vim.win_opts
---@return grapple.vim.win_opts valid_opts
function Window.canonicalize(opts)
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

function Window:open()
    if self:is_open() then
        return
    end

    -- Create or get namespaces
    self.ns_id = vim.api.nvim_create_namespace("grapple")
    self.au_id = vim.api.nvim_create_augroup("Grapple", { clear = true })

    -- Create temporary buffer
    self.buf_id = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_option_value("filetype", "grapple", { buf = self.buf_id })
    vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = self.buf_id })
    self:buffer_defaults()

    -- Create window
    local win_opts = Window.canonicalize(self.win_opts)
    self.win_id = vim.api.nvim_open_win(self.buf_id, true, win_opts)
end

---@return string? error
function Window:close()
    if self:is_closed() then
        return
    end

    if self.content then
        self.content:sync(self.buf_id)
    end

    if vim.api.nvim_win_is_valid(self.win_id) then
        vim.api.nvim_win_close(self.win_id, true)
    end

    self.ns_id = nil
    self.au_id = nil
    self.buf_id = nil
    self.win_id = nil
end

---@param content? grapple.tag.content
---@return string? error
function Window:attach(content)
    if not content and not self.content then
        return "no content available"
    end

    if self.content and content and self.content:id() ~= content:id() then
        local err = self:detach()
        if err then
            return err
        end
    end

    if content then
        self.content = content
    end

    local err = self.content:attach(self)
    if err then
        return err
    end
end

---@return string? error
function Window:detach()
    if not self.content then
        return
    end

    local err = self.content:detach(self.buf_id)
    if err then
        return err
    end

    self.content = nil

    return nil
end

---@param content? grapple.tag.content
---@return string? error
function Window:render(content)
    if self:is_closed() then
        return "window is not open"
    end

    -- Store cursor location to reposition later
    local cursor = vim.api.nvim_win_get_cursor(self.win_id)

    self.buf_id = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_option_value("filetype", "grapple", { buf = self.buf_id })
    vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = self.buf_id })
    self:buffer_defaults()

    -- Attach to content provider
    local err = self:attach(content)
    if err then
        return err
    end

    -- Safety: we are guaranteed to have content by this point
    ---@diagnostic disable-next-line: redefined-local
    local err = self.content:render(self.buf_id, self.ns_id)
    if err then
        return err
    end

    -- Set active buffer
    vim.api.nvim_win_set_buf(self.win_id, self.buf_id)

    -- Restore cursor location
    local ok = pcall(vim.api.nvim_win_set_cursor, 0, cursor)
    if not ok then
        vim.api.nvim_win_set_cursor(self.win_id, { 1, 0 })
    end
end

function Window:buffer_defaults()
    self:autocmd({ "WinLeave" }, {
        once = true,
        callback = function()
            ---@diagnostic disable-next-line: redefined-local
            local err = self:close()
            if err then
                vim.notify(err, vim.log.levels.ERROR)
            end
        end,
    })

    self:map("n", "q", "<cmd>close<cr>")
    self:map("n", "<c-c>", "<cmd>close<cr>")
    self:map("n", "<esc>", "<cmd>close<cr>")

    self:autocmd({ "VimResized" }, {
        callback = function()
            self:reposition()
        end,
    })
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
---@param opts grapple.action.options
---@return string? error
function Window:perform(action, opts)
    if self:is_closed() then
        return "window is not open"
    end

    if not self.content then
        return "no content available"
    end

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

---Safety: used only inside an autocmd associated with a known buffer
function Window:reposition()
    local win_opts = Window.canonicalize(self.win_opts)
    vim.api.nvim_win_set_config(self.win_id, win_opts)
end

---Safety: used only inside a callback hook when a window is open
---@return integer[]
function Window:cursor()
    return vim.api.nvim_win_get_cursor(self.win_id)
end

return Window
