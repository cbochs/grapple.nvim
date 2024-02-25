local Tag = require("grapple.tag")
local Util = require("grapple.util")

---@class grapple.tag.container.insert
---@field path string
---@field cursor? integer[]
---@field index? integer

---@class grapple.tag.container.get
---@field path? string
---@field index? integer

---@class grapple.tag.container.move
---@field path string
---@field index integer

---@class grapple.tag.container
---@field tags grapple.tag[]
local TagContainer = {}
TagContainer.__index = TagContainer

function TagContainer:new()
    return setmetatable({
        tags = {},
    }, self)
end

function TagContainer:len()
    return #self.tags
end

function TagContainer:is_empty()
    return self:len() == 0
end

---@param opts grapple.tag.container.insert
---@return string? error
function TagContainer:insert(opts)
    if self:has(opts.path) then
        return string.format("tag already exists: %s", opts.path)
    end

    local abs_path, err = Util.absolute(opts.path)
    if not abs_path then
        return err
    end

    local tag = Tag:new(abs_path, opts.cursor)
    table.insert(self.tags, opts.index or (#self.tags + 1), tag)

    return nil
end

---@param opts grapple.tag.container.move
---@return string? error
function TagContainer:move(opts)
    local index = self:index(opts.path)
    if not index then
        return string.format("tag does not exist for file path: %s", opts.path)
    end

    local tag = self.tags[index]

    if opts.index == index then
        return nil
    elseif opts.index < index then
        table.remove(self.tags, index)
        table.insert(self.tags, opts.index, tag)
        return nil
    elseif opts.index > index then
        table.insert(self.tags, opts.index + 1, tag)
        table.remove(self.tags, index)
        return nil
    end

    error(string.format("tag could not be moved from index %s to %s: %s", index, opts.index, opts.path))
end

---@param opts grapple.tag.container.get
---@return string? error
function TagContainer:remove(opts)
    if self:is_empty() then
        return "tag container is empty"
    end

    local index, err = self:find(opts)
    if not index then
        return err
    end

    table.remove(self.tags, index)

    return nil
end

---@param opts grapple.tag.container.get
---@return boolean success, string? error
function TagContainer:update(opts)
    local tag, err = self:get(opts)
    if not tag then
        return false, err
    end

    ---@diagnostic disable-next-line: redefined-local
    local ok, err = tag:update()
    if not ok then
        return false, err
    end

    return true, nil
end

function TagContainer:clear()
    self.tags = {}
end

---@param opts grapple.tag.container.get
---@return grapple.tag | nil, string? error
function TagContainer:get(opts)
    local index, err = self:find(opts)
    if not index then
        return nil, err
    end

    return self.tags[index], nil
end

---@param opts grapple.tag.container.get
---@return integer | nil index, string? error
function TagContainer:find(opts)
    local index
    if opts.path then
        index = self:index(opts.path)

        if not index then
            return nil, string.format("tag does not exist for file path: %s", opts.path)
        end
    elseif opts.index then
        index = opts.index

        if index < 1 or index > #self.tags then
            return nil, string.format("tag index is out-of-bounds: %s", opts.index)
        end
    end

    if not index then
        return nil, "must provide either a tag path or index"
    end

    return index, nil
end

---@param path string
---@return integer | nil index
function TagContainer:index(path)
    local abs_path, _ = Util.absolute(path)
    if not abs_path then
        return nil
    end

    for i, tag in ipairs(self.tags) do
        if tag.path == abs_path then
            return i
        end
    end
end

---@param path string
---@return boolean
function TagContainer:has(path)
    return self:index(path) ~= nil
end

-- Implements Serializable
function TagContainer:into_table()
    ---@param tag grapple.tag
    ---@return grapple.tag.format
    local function into_table(tag)
        return tag:into_table()
    end

    ---@class grapple.tag.container.format
    return {
        tags = vim.tbl_map(into_table, self.tags),
    }
end

-- Implements Deserialize
---@param tbl grapple.tag.container.format
---@return grapple.tag.container | nil, string? error
function TagContainer.from_table(tbl)
    local container = TagContainer:new()

    for _, tag_tbl in ipairs(tbl.tags) do
        local tag, err = Tag.from_table(tag_tbl)
        if not tag then
            return nil, err
        end

        table.insert(container.tags, tag)
    end

    return container, nil
end

return TagContainer
