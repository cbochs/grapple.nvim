local Path = require("grapple.path")
local Tag = require("grapple.tag")

---@class grapple.tag.container.insert
---@field path string rquired, must be unique
---@field name? string optional, but must be unique
---@field cursor? integer[]
---@field index? integer

---@class grapple.tag.container.get
---@field index? integer
---@field name? string
---@field path? string

---@class grapple.tag.container.move
---@field path string
---@field index integer

---@class grapple.tag_container
---@field name string
---@field tags grapple.tag[]
---@field paths_index table<string, grapple.tag>
---@field names_index table<string, grapple.tag>
local TagContainer = {}
TagContainer.__index = TagContainer

---@param name string
---@return grapple.tag_container
function TagContainer:new(name)
    return setmetatable({
        name = name,
        tags = {},
        paths_index = {},
        names_index = {},
    }, self)
end

function TagContainer:len()
    return #self.tags
end

function TagContainer:is_empty()
    return self:len() == 0
end

---@param opts grapple.options
---@return string? error
function TagContainer:insert(opts)
    vim.validate({ path = { opts.path, "string" } })

    if opts.index and (opts.index < 1 or opts.index > #self.tags + 1) then
        return string.format("tag insert opts.index is out-of-bounds: %s", opts.index)
    end

    local path = Path.fs_absolute(opts.path)

    -- Grab previous information from the "path" tag
    local path_tag = self:get({ path = path })
    local cursor = opts.cursor or path_tag and path_tag.cursor
    local name = opts.name or path_tag and path_tag.name
    local tag = Tag:new(path, name, cursor)

    local index = opts.index or self:index({ path = path }) or (#self.tags + 1)

    -- It's possible the "path" tag and "name" tag are different.
    -- In this case, account for the possibility of two tags being
    -- removed during a single insert
    local name_tag = self:get({ name = opts.name })
    local same_tag = path_tag and name_tag and path_tag.path == name_tag.path
    if not same_tag then
        local name_index = self:index({ name = opts.name })
        if name_index and name_index < index then
            index = index + 1
        end
    end

    -- Attempt to clear the "path" tag and "name" tag
    self:remove({ path = path })
    self:remove({ name = name })

    -- Clamp the index to (at most) the end of the list
    index = math.min(index, #self.tags + 1)

    table.insert(self.tags, index, tag)

    -- Update path and name indices
    self.paths_index[tag.path] = tag
    if tag.name then
        self.names_index[tag.name] = tag
    end

    return nil
end

---@param opts grapple.options
---@return string? error
function TagContainer:remove(opts)
    if self:is_empty() then
        return "tag container is empty"
    end

    local index, err = self:find(opts)
    if not index then
        return err
    end

    local tag = assert(self:get({ index = index }))

    table.remove(self.tags, index)
    self.paths_index[tag.path] = nil
    if tag.name then
        self.names_index[tag.name] = nil
    end

    return nil
end

---@param opts grapple.options
---@return string? error
function TagContainer:update(opts)
    local index, err = self:find(opts)
    if not index then
        return err
    end

    local tag = assert(self:get({ index = index }))
    tag:update()
end

function TagContainer:clear()
    self.tags = {}
    self.paths_index = {}
    self.names_index = {}
end

---@param opts grapple.options
function TagContainer:has(opts)
    return self:get(opts) ~= nil
    -- stylua: ignore
end

---@param opts grapple.options
---@return grapple.tag | nil
function TagContainer:get(opts)
    -- stylua: ignore
    return self.tags[opts.index]
        or self.names_index[opts.name]
        or self.paths_index[opts.path and Path.fs_absolute(opts.path)]
end

---Search for a tag
---@param opts grapple.options
---@return integer | nil index, string? error
function TagContainer:find(opts)
    local index

    if opts.index then
        index = opts.index

        if index < 1 or index > #self.tags then
            return nil, string.format("tag index is out-of-bounds: %s", opts.index)
        end

        return index
    end

    if opts.name then
        index = self:index({ name = opts.name })

        if not index then
            return nil, string.format("tag does not exist for name: %s", opts.name)
        end

        return index
    end

    if opts.path then
        index = self:index({ path = opts.path })

        if not index then
            return nil, string.format("tag does not exist for path: %s", opts.path)
        end

        return index
    end

    return nil, "must provide either an index, name, or path"
end

---Lookup the tag index based on a given name or path
---@param opts table
---@return integer | nil index
function TagContainer:index(opts)
    if opts.path then
        opts.path = Path.fs_absolute(opts.path)
    end

    -- Short-circuit for container indices
    if (opts.path or opts.name) and not self:has(opts) then
        return nil
    end

    for i, tag in ipairs(self.tags) do
        for key, value in pairs(opts) do
            if tag[key] == value then
                return i
            end
        end
    end
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
        name = self.name,
        tags = vim.tbl_map(into_table, self.tags),
    }
end

-- Implements Deserialize
---@param tbl grapple.tag.container.format
---@return grapple.tag_container | nil, string? error
function TagContainer.from_table(tbl)
    local container = TagContainer:new(tbl.name)

    for _, tag_tbl in ipairs(tbl.tags) do
        local tag, err = Tag.from_table(tag_tbl)
        if not tag then
            return nil, err
        end

        table.insert(container.tags, tag)
        container.paths_index[tag.path] = tag
        if tag.name then
            container.names_index[tag.name] = tag
        end
    end

    return container, nil
end

---Unused
---@param opts grapple.tag.container.move
---@return string? error
function TagContainer:move(opts)
    local index = self:index({ path = opts.path })
    if not index then
        return string.format("tag does not exist for path: %s", opts.path)
    end

    local tag = self.tags[index]

    if opts.index == index then
        -- Do nothing
    elseif opts.index < index then
        table.remove(self.tags, index)
        table.insert(self.tags, opts.index, tag)
    elseif opts.index > index then
        table.insert(self.tags, opts.index + 1, tag)
        table.remove(self.tags, index)
    end
end

return TagContainer
