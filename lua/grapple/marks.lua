local autocmds = require("grapple.autocmds")
local config = require("grapple.config")
local log = require("grapple.log")
local state = require("grapple.state")

---@class Mark
---@field file_path string
---@field cursor table

local M = {}

local _state = nil

-- EXTERNAL API --

---Mark a buffer.
---@param opts { buffer?: number, index?: number, name?: string } | nil
function M.mark(opts)
    local mark_options = vim.tbl_extend("force", { buffer = 0 }, opts or {})
    M.create_mark(config.project_root, mark_options)
    autocmds.update_autocmds()
end

---Unmark a buffer.
---@param opts { buffer?: number, name?: string, index?: number }
function M.unmark(opts)
    M.delete_mark(config.project_root, opts)
    autocmds.update_autocmds()
end

---Toggle a mark.
---@param opts { buffer?: number, name?: string, index?: number }
function M.toggle(opts)
    local mark_key = M.find_key(config.project_root, opts)
    if mark_key ~= nil and (mark_key == opts.name or mark_key == opts.index) then
        M.unmark(opts)
    else
        M.mark(opts)
    end
end

---Select a mark.
---@param opts { buffer?: number, name?: string, index?: number }
function M.select(opts)
    M.select_mark(config.project_root, opts)
end

---Reset marks for the current project.
function M.reset()
    M.reset_marks(config.project_root)
end

-- INTERNAL API --

function M.default()
    return {}
end

---Initialize marks.
---@param save_path string
---@param force boolean?
function M.load(save_path, force)
    force = force or false

    if _state ~= nil and not force then
        log.warn("Marks have already been loaded.")
        return nil
    end

    if state.file_exists(save_path) then
        _state = state.load(save_path)
    else
        _state = M.default()
    end
end

---Save marks to a persisted file.
---@param save_path string
function M.save(save_path)
    state.save(save_path, _state)
end

---Reset marks or marks for a specific project.
---@param project_root string?
function M.reset_marks(project_root)
    if project_root ~= nil then
        _state[project_root] = nil
    else
        _state = M.default()
    end
end

---Mark a buffer.
---@param project_root string
---@param opts { buffer: number, index: number?, name: string? }
function M.create_mark(project_root, opts)
    _state[project_root] = _state[project_root] or {}

    if opts.name and opts.index then
        log.error("ArgumentError - The options 'name' and 'index' are mutually exclusive.")
        error("ArgumentError - The options 'name' and 'index' are mutually exclusive.")
        return nil
    end

    local new_mark = { file_path = vim.api.nvim_buf_get_name(opts.buffer) }
    local current_mark_key = M.find_key(project_root, { buffer = opts.buffer })

    if current_mark_key ~= nil then
        log.debug("Replacing mark.")
        new_mark.cursor = _state[project_root][current_mark_key].cursor
        _state[project_root][current_mark_key] = nil
    end

    if opts.name then
        _state[project_root][opts.name] = new_mark
    elseif opts.index then
        table.insert(_state[project_root], opts.index, new_mark)
    else
        table.insert(_state[project_root], new_mark)
    end
end

---Delete a mark.
---@param project_root string
---@param opts { buffer: number?, index: number?, name: string? }
---@return nil
function M.delete_mark(project_root, opts)
    local mark_key = M.find_key(project_root, opts)

    if mark_key == nil then
        log.warn("Could not delete mark. project_root: " .. project_root .. ". opts: " .. vim.inspect(opts))
        return nil
    end

    _state[project_root][mark_key] = nil
end

---Update a mark.
---@param project_root string
---@param cursor table
---@param opts { buffer: number?, index: number?, name: string? }
---@return nil
function M.update_mark(project_root, cursor, opts)
    local mark_key = M.find_key(project_root, opts)

    if mark_key == nil then
        log.warn("Could not update mark. project_root: " .. project_root .. ". opts: " .. vim.inspect(opts))
        return nil
    end

    _state[project_root] = _state[project_root] or {}
    _state[project_root][mark_key].cursor = cursor
end

---Select a mark.
---@param project_root string
---@param opts { buffer: number?, index: number?, name: string? }
---@return nil
function M.select_mark(project_root, opts)
    local mark = M.find_mark(project_root, opts)
    if mark == nil then
        log.warn("Could not select mark. project_root: " .. project_root .. ". opts: " .. vim.inspect(opts))
        return nil
    end

    local current_buffer = vim.api.nvim_buf_get_name(0)
    if mark.file_path == current_buffer then
        log.debug("Mark is currently selected.")
        return nil
    end

    vim.api.nvim_cmd({ cmd = "edit", args = { mark.file_path } }, {})
    if mark.cursor then
        vim.api.nvim_win_set_cursor(0, mark.cursor)
    end
end

---Attempt to find the mark for a given project.
---@param project_root string
---@param opts { buffer: number?, index: number?, name: string? }
---@return Mark | nil
function M.find_mark(project_root, opts)
    local project = _state[project_root] or {}
    local mark_key = M.find_key(project_root, opts)

    if mark_key == nil then
        return nil
    end

    return project[mark_key]
end

---Attempt to find a mark's key for a given project.
---@param project_root string
---@param opts { buffer: number?, index: number?, name: string? }
---@return string | number | nil
function M.find_key(project_root, opts)
    local project = _state[project_root] or {}
    local mark_key = nil

    if opts.buffer then
        local buffer_name = vim.api.nvim_buf_get_name(opts.buffer)
        for key, mark in pairs(project) do
            if mark.file_path == buffer_name then
                mark_key = key
                break
            end
        end
    elseif opts.name and project[opts.name] ~= nil then
        mark_key = opts.name
    elseif opts.index and project[opts.index] ~= nil then
        mark_key = opts.index
    end

    return mark_key
end

---Get a list of marks for a given project
---@param project_root string
---@return table
function M.marked_files(project_root)
    local project = _state[project_root] or {}
    local file_paths = {}
    for _, mark in pairs(project) do
        table.insert(file_paths, mark.file_path)
    end

    return file_paths
end

return M
