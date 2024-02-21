local Tag = require("grapple.tag")
local Util = require("grapple.util")

---@class grapple.tag.container.insert
---@field path string
---@field cursor integer[]
---@field index? integer

---@class grapple.tag.container.move
---@field path string
---@field index integer

---@class grapple.tag.container.remove
---@field path? string
---@field index? integer

---@class grapple.tag.container.get
---@field path? string
---@field index? integer

---@class grapple.tag.container.update
---@field path string
---@field cursor integer[]

---@class grapple.tag.container
---@field tags grapple.tag[]
local TagContainer = {}
TagContainer.__index = TagContainer

function TagContainer:new()
    return setmetatable({
        tags = {},
    }, self)
end

---@param opts grapple.tag.container.insert
---@return grapple.tag, string? error
function TagContainer:insert(opts)
    if self:has(opts.path) then
        return {}, string.format("tag already exists: %s", opts.path)
    end

    local abs_path = Util.absolute(opts.path)

    assert(type(abs_path) == "string", "path must be a string")
    assert(type(opts.cursor) == "table", "cursor must be a table")
    assert(#opts.cursor == 2, "cursor must only have 2 values")
    assert(opts.cursor[1] >= 1, string.format("cursor row uses 1-based indexing: %s", opts.cursor[1]))
    assert(opts.cursor[2] >= 0, string.format("cursor col uses 0-based indexing: %s", opts.cursor[2]))

    local tag = Tag:new(abs_path, opts.cursor)
    table.insert(self.tags, opts.index or (#self.tags + 1), tag)

    return tag, nil
end

---@param opts grapple.tag.container.move
---@return grapple.tag, string? error
function TagContainer:move(opts)
    local index = self:index(opts.path)
    if not index then
        return {}, string.format("tag does not exist for file path: %s", opts.path)
    end

    local tag = self.tags[index]

    if opts.index == index then
        return tag, nil
    elseif opts.index < index then
        table.remove(self.tags, index)
        table.insert(self.tags, opts.index, tag)
        return tag, nil
    elseif opts.index > index then
        table.insert(self.tags, opts.index + 1, tag)
        table.remove(self.tags, index)
        return tag, nil
    end

    error(string.format("tag could not be moved from index %s to %s: %s", index, opts.index, opts.path))
end

---@param opts? grapple.tag.container.remove
---@return grapple.tag, string? error
function TagContainer:remove(opts)
    if #self.tags == 0 then
        return {}, "tag container is empty"
    end

    local index
    if opts and opts.path then
        index = self:index(opts.path)

        if not index then
            return {}, string.format("tag does not exist for file path: %s", opts.path)
        end
    elseif opts and opts.index then
        assert(type(opts.index) == "number", "opts.index must be a number")
        index = opts.index

        if index < 1 or index > #self.tags then
            return {}, string.format("tag index is out-of-bounds: %s", opts.index)
        end
    else
        index = #self.tags
    end

    return table.remove(self.tags, index)
end

---@param opts grapple.tag.container.update
---@return string? error
function TagContainer:update(opts)
    local tag, err = self:get({ path = opts.path })
    if err then
        return err
    end

    tag:update(opts.cursor)
end

function TagContainer:clear()
    self.tags = {}
end

---@param opts grapple.tag.container.get
---@return grapple.tag, string? error
function TagContainer:get(opts)
    local index
    if opts.path then
        index = self:index(opts.path)

        if not index then
            return {}, string.format("tag does not exist for file path: %s", opts.path)
        end
    elseif opts.index then
        index = opts.index

        if index < 1 or index > #self.tags then
            return {}, string.format("tag index is out-of-bounds: %s", opts.index)
        end
    else
        return {}, string.format("tag not found: %s", vim.inspect(opts))
    end

    return self.tags[index], nil
end

---@param path string
---@return integer | nil
function TagContainer:index(path)
    local abs_path = Util.absolute(path)

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
    ---@param obj Serializable
    ---@return table
    local function into_table(obj)
        return obj:into_table()
    end

    ---@class grapple.tag.container.format
    return {
        ---@type grapple.tag.format[]
        tags = vim.tbl_map(into_table, self.tags),
    }
end

-- Implements Deserialize
---@param tbl grapple.tag.container.format
---@return grapple.tag.container, string? error
function TagContainer.from_table(tbl)
    local container = TagContainer:new()

    for _, tag_tbl in ipairs(tbl.tags) do
        local tag, err = Tag.from_table(tag_tbl)
        if err then
            return {}, err
        end

        table.insert(container.tags, tag)
    end

    return container
end

return TagContainer
