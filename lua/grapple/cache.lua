---@class grapple.cache
---@field group_id integer
---@field cache table<string, grapple.cache.value>
local Cache = {}
Cache.__index = Cache

---@class grapple.cache.opts
---@field event? string
---@field pattern? string
---@field interval? integer

---@class grapple.cache.value
---@field event string?
---@field pattern string?
---@field interval integer?
---@field au_id integer?
---@field timer uv_timer_t?
---@field value any
---@field watching boolean

local CACHE_GROUP = vim.api.nvim_create_augroup("GrappleCache", { clear = true })

---@return grapple.cache
function Cache:new()
    return setmetatable({
        group_id = CACHE_GROUP,
        cache = {},
    }, self)
end

---@param id string
---@param opts grapple.cache.opts
function Cache:open(id, opts)
    if self.cache[id] then
        self:close(id)
    end

    ---@type grapple.cache.value
    local cache_value = {
        event = opts.event,
        pattern = opts.pattern,
        interval = opts.interval,
        watching = false,
    }

    self.cache[id] = cache_value
end

---@param id string
function Cache:close(id)
    local cache_value = self.cache[id]
    if not cache_value then
        return
    end

    if cache_value.watching then
        self:unwatch(id)
    end

    self.cache[id] = nil
end

---@param id string
function Cache:watch(id)
    local cache_value = self.cache[id]
    if not cache_value then
        return
    end

    if cache_value.watching then
        self:unwatch(id)
    end

    local callback = function()
        self:invalidate(id)
    end

    if cache_value.event then
        cache_value.au_id = vim.api.nvim_create_autocmd(cache_value.event, {
            group = self.group_id,
            pattern = cache_value.pattern,
            callback = callback,
        })
    end

    if cache_value.interval then
        cache_value.timer = vim.uv.new_timer()
        cache_value.timer:start(cache_value.interval, cache_value.interval, callback)
    end

    cache_value.watching = true
end

---@param id string
function Cache:unwatch(id)
    local cache_value = self.cache[id]
    if not cache_value then
        return
    end

    self:invalidate(id)

    if cache_value.au_id then
        vim.api.nvim_del_autocmd(cache_value.au_id)
    end

    if cache_value.timer then
        cache_value.timer:stop()
    end

    cache_value.watching = false
end

---@param id string
---@return any cached_value
function Cache:get(id)
    local cache_value = self.cache[id]
    if not cache_value then
        return
    end
    if not cache_value.watching then
        self:watch(id)
    end

    return cache_value.value
end

---@param id string
---@param value any
function Cache:store(id, value)
    local cache_value = self.cache[id]
    if not cache_value then
        return
    end
    if not cache_value.watching then
        self:watch(id)
    end

    cache_value.value = value
end

---@param id string
function Cache:invalidate(id)
    local cache_value = self.cache[id]
    if not cache_value then
        return
    end

    cache_value.value = nil
end

return Cache
