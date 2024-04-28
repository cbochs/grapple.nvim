---@class grapple.cache
---@field group_id integer
---@field cache table<string, grapple.cache.value>
local Cache = {}
Cache.__index = Cache

---@class grapple.cache.options
---@field event? string | string[]
---@field pattern? string | string[]
---@field interval? integer
---@field debounce? integer in milliseconds

---@class grapple.cache.value
---@field event? string | string[]
---@field pattern? string | string[]
---@field interval? integer
---@field debounce? integer in milliseconds
--
---@field au_id? integer
---@field timer? uv.uv_timer_t
--
---@field debouncing boolean
---@field watching boolean
---@field value any

local CACHE_GROUP = vim.api.nvim_create_augroup("GrappleCache", { clear = true })

---@return grapple.cache
function Cache:new()
    return setmetatable({
        group_id = CACHE_GROUP,
        cache = {},
    }, self)
end

function Cache:exists(id)
    return self.cache[id] ~= nil
end

---@param id string
---@param opts grapple.cache.options
function Cache:open(id, opts)
    if self:exists(id) then
        self:close(id)
    end

    ---@type grapple.cache.value
    local cache_value = {
        event = opts.event,
        pattern = opts.pattern,
        interval = opts.interval,
        debounce = opts.debounce,
        debouncing = false,
        watching = false,
        value = nil,
    }

    self.cache[id] = cache_value
end

---@param id string
function Cache:close(id)
    if not self:exists(id) then
        return
    end

    local cache_value = self.cache[id]
    if cache_value.watching then
        self:unwatch(id)
    end

    self.cache[id] = nil
end

---@param id string
function Cache:watch(id)
    if not self:exists(id) then
        return
    end

    local cache_value = self.cache[id]
    if cache_value.watching then
        self:unwatch(id)
    end

    local callback = function()
        if cache_value.debouncing then
            return
        end

        self:invalidate(id)

        if cache_value.debounce then
            cache_value.debouncing = true

            local timer = assert(vim.loop.new_timer())
            timer:start(cache_value.debounce, 0, function()
                cache_value.debouncing = false
            end)
        end
    end

    if cache_value.event then
        cache_value.au_id = vim.api.nvim_create_autocmd(cache_value.event, {
            group = self.group_id,
            pattern = cache_value.pattern,
            callback = callback,
        })
    end

    if cache_value.interval then
        cache_value.timer = vim.loop.new_timer()
        cache_value.timer:start(cache_value.interval, cache_value.interval, callback)
    end

    cache_value.watching = true
end

---@param id string
function Cache:unwatch(id)
    if not self:exists(id) then
        return
    end

    self:invalidate(id)

    local cache_value = self.cache[id]
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
    if not self:exists(id) then
        return
    end

    local cache_value = self.cache[id]
    if not cache_value.watching then
        self:watch(id)
    end

    return cache_value.value
end

---@param id string
---@param value any
function Cache:store(id, value)
    if not self:exists(id) then
        self:open(id, {})
    end

    local cache_value = self.cache[id]
    if not cache_value.watching then
        self:watch(id)
    end

    cache_value.value = value
end

---@param id string
function Cache:invalidate(id)
    if not self:exists(id) then
        return
    end

    self.cache[id].value = nil
end

return Cache
