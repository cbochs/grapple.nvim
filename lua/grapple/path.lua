local Path = require("plenary.path")

---@alias Grapple.Path string

---@alias Plenary.Path table

local path = {}

---@param path_ string | Plenary.Path
---@return Grapple.Path
function path.normalize(path_)
    return vim.fs.normalize(tostring(path_))
end

---@param ... string
---@return Grapple.Path
function path.append(...)
    local final_path
    for _, path_piece in ipairs({ ... }) do
        path_piece = tostring(path_piece)
        if final_path == nil then
            final_path = Path:new(path_piece)
        else
            final_path = final_path / path_piece
        end
    end
    return path.normalize(final_path)
end

---@param full_path Grapple.Path
---@param base_path Grapple.Path
---@return Grapple.Path
function path.make_relative(full_path, base_path)
    local relative_path = Path:new(full_path):make_relative(base_path)
    return path.normalize(relative_path)
end

---@param path_ Grapple.Path
---@return boolean
function path.exists(path_)
    return Path:new(path_):exists()
end

---@param path_ Grapple.Path
---@return boolean
function path.is_absolute(path_)
    return Path:new(path_):is_absolute()
end

---@param path_ Grapple.Path
function path.rm(path_)
    Path:new(path_):rm()
end

---@param dir_path Grapple.Path
function path.mkdir(dir_path)
    Path:new(dir_path):mkdir()
end

---@param file_path Grapple.Path
function path.read(file_path)
    return Path:new(file_path):read()
end

---@param file_path Grapple.Path
---@param data string
---@param mode string
function path.write(file_path, data, mode)
    Path:new(file_path):write(data, mode)
end

return path
