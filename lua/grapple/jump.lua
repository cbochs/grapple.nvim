local config = require("grapple.config")
local marks = require("grapple.marks")

M = {}

local forward_key = vim.api.nvim_replace_termcodes("<c-i>", true, false, true)
local backward_key = vim.api.nvim_replace_termcodes("<c-o>", true, false, true)

-- EXTERNAL API --

---Jump to the next marked buffer in the jumplist.
function M.jump_forward()
    M._jump_forward(config.project_root)
end

---Jump to the previous marked buffer in the jumplist.
function M.jump_backward()
    M._jump_backward(config.project_root)
end

-- INTERNAL API --

---@param project_root string
function M._jump_forward(project_root)
    local jumplist = vim.fn.getjumplist()
    local jumps = jumplist[1]
    local current_index = jumplist[2] + 1
    local current_buffer = vim.fn.bufnr()

    for i = (current_index + 1), #jumps do
        local buffer = jumps[i].bufnr
        local mark = marks.find_mark(project_root, { buffer = buffer })
        if mark ~= nil and buffer ~= current_buffer then
            local jump_distance = i - current_index
            vim.api.nvim_feedkeys(jump_distance .. forward_key, "n", false)
            break
        end
    end
end

---@param project_root string
function M._jump_backward(project_root)
    local jumplist = vim.fn.getjumplist()
    local jumps = jumplist[1]
    local current_index = jumplist[2] + 1
    local current_buffer = vim.fn.bufnr()

    for i = 1, (current_index - 1) do
        local buffer = jumps[current_index - i].bufnr
        local mark = marks.find_mark(project_root, { buffer = buffer })
        if mark ~= nil and buffer ~= current_buffer then
            local jump_distance = i
            vim.api.nvim_feedkeys(jump_distance .. backward_key, "n", false)
            break
        end
    end
end

return M
