local Helpers = {}

Helpers.root_dir = vim.fn.fnamemodify(".", ":p")
Helpers.test_dir = vim.fs.joinpath(Helpers.root_dir, ".tests/")
Helpers.temp_dir = vim.fs.joinpath(Helpers.test_dir, "tmp/")
vim.fn.mkdir(Helpers.temp_dir, "p")

function Helpers.tbl_join(...)
    local joined = {}
    for _, tbl in ipairs({ ... }) do
        for _, v in ipairs(tbl) do
            table.insert(joined, v)
        end
    end
    return joined
end

---@param ... string
function Helpers.fs_path(...)
    return vim.fs.joinpath(Helpers.temp_dir, ...)
end

---@param ... string
function Helpers.fs_exist(...)
    return vim.uv.fs_stat(Helpers.fs_path(...))
end

---@param ... string
function Helpers.fs_mkdir(...)
    local dir_path = Helpers.fs_path(...)
    vim.fn.mkdir(dir_path, "p")
    return dir_path
end

---@param ... string
function Helpers.fs_touch(...)
    local fd = assert(vim.uv.fs_open(Helpers.fs_path(...), "w", 438))
    assert(vim.uv.fs_close(fd))
end

---@param ... string
function Helpers.fs_cd(...)
    vim.fn.chdir(Helpers.fs_path(...))
end

function Helpers.fs_rm(path, flags)
    vim.fn.delete(Helpers.fs_path(path), flags)
end

---@param layout table
function Helpers.fs_layout(layout)
    ---@diagnostic disable-next-line: redefined-local
    local function recurse(layout, path)
        if type(layout) == "string" then
            Helpers.fs_touch(path)
        elseif type(layout) == "table" then
            Helpers.fs_mkdir(path)
            for name, inner in pairs(layout) do
                recurse(inner, vim.fs.joinpath(path, name))
            end
        else
            error(vim.inspect({
                error = "Invalid layout",
                path = path,
                layout = layout,
            }))
        end
    end

    for name, inner in pairs(layout) do
        recurse(inner, name)
    end
end

return Helpers
