local Path = require("plenary.path")
local log = require("grapple.log")
local scope = require("grapple.scope")
local settings = require("grapple.settings")

local state = {}

---@alias Grapple.StateKey string | integer

---@alias Grapple.StateItem Grapple.Tag

---@alias Grapple.FullStateItem Grapple.FullTag

---@alias Grapple.ScopeState table<Grapple.StateKey, Grapple.StateItem>

---@class Grapple.ScopePair
---@field scope Grapple.Scope
---@field resolver Grapple.ScopeResolver

---@type table<Grapple.Scope, Grapple.ScopeState>
local internal_state = {}

---Reference: https://github.com/golgote/neturl/blob/master/lib/net/url.lua
---
---@param plain_string string
---@return string
function state.encode(plain_string)
    return string.gsub(plain_string, "([^%w])", function(match)
        return string.upper(string.format("%%%02x", string.byte(match)))
    end)
end

---@param encoded_string string
---@return string
function state.decode(encoded_string)
    return string.gsub(encoded_string, "%%(%x%x)", function(match)
        return string.char(tonumber(match, 16))
    end)
end

---@param state_ table
---@return string
function state.serialize(state_)
    local separated_state = {
        __indexed = {},
    }

    for _, state_key in ipairs(vim.tbl_keys(state_)) do
        if type(state_key) == "string" then
            separated_state[state_key] = state_[state_key]
        elseif type(state_key) == "number" then
            table.insert(separated_state.__indexed, state_[state_key])
        end
    end

    return vim.json.encode(separated_state)
end

---@param serialized_state string
---@return table
function state.deserialize(serialized_state)
    local separated_state = vim.json.decode(serialized_state)
    local state_ = separated_state

    for _, state_item in ipairs(separated_state.__indexed) do
        table.insert(state_, state_item)
    end
    state_.__indexed = nil

    return state_
end

---@param scope_state Grapple.ScopeState
---@return boolean
local function should_persist(scope_state)
    return getmetatable(scope_state).__persist
end

---@param scope_state Grapple.ScopeState
---@param scope_resolver Grapple.ScopeResolver
local function with_metatable(scope_state, scope_resolver)
    setmetatable(scope_state, {
        __persist = scope_resolver.persist,
        __resolver = scope_resolver,
    })
    return scope_state
end

---@param save_dir? string
function state.save(save_dir)
    save_dir = Path:new(save_dir or settings.save_path)
    if not save_dir:exists() then
        log.info(string.format("Save directory does not exist, creating. path: %s", save_dir))
        save_dir:mkdir()
    end

    log.debug(string.format("Saving state. save_dir: %s", save_dir))
    for scope_, scope_state in pairs(internal_state) do
        if vim.tbl_isempty(scope_state) then
            log.debug(string.format("Skipping save state. scope state is empty. scope: %s", scope_))
            goto continue
        end
        if not should_persist(scope_state) then
            log.debug(string.format("Skipping save state. scope state should not persist. scope: %s", scope_))
            goto continue
        end

        local save_path = save_dir / state.encode(scope_)
        save_path:write(state.serialize(scope_state), "w")
        log.debug(string.format("Saved scope state. path: %s", save_path))

        ::continue::
    end
end

---@param scope_ Grapple.Scope
---@param save_dir? string
---@return Grapple.ScopeState | nil
function state.load(scope_, save_dir)
    log.debug(string.format("Loading scope state. scope: %s", scope_))

    save_dir = Path:new(save_dir or settings.save_path)
    local save_path = save_dir / state.encode(scope_)
    if not save_path:exists() then
        log.debug(string.format("Cannot load scope state from disk, save path does not exist. path: %s", save_path))
        return nil
    end

    local serialized_state = save_path:read()
    local scope_state = state.deserialize(serialized_state)
    log.debug(string.format("Loaded scope state. scope: %s. ", scope_))

    return scope_state
end

---@param save_dir? string
function state.prune(save_dir)
    save_dir = Path:new(save_dir or settings.save_path)
    for scope_, scope_state in pairs(internal_state) do
        local save_path = save_dir / state.encode(scope_)
        if vim.tbl_isempty(scope_state) and save_path:exists() then
            log.debug(string.format("Pruning: scope is empty. scope: %s", scope_))
            save_path:rm()
        end
    end
end

---@param scope_resolver Grapple.ScopeResolverLike
---@return Grapple.Scope
function state.ensure_loaded(scope_resolver)
    scope_resolver = scope.find_resolver(scope_resolver)
    local scope_ = scope.get(scope_resolver)

    if internal_state[scope_] ~= nil then
        return scope_
    end

    local scope_state
    if scope_resolver.persist then
        scope_state = state.load(scope_)
    end
    if scope_state == nil then
        scope_state = {}
    end
    internal_state[scope_] = with_metatable(scope_state, scope_resolver)

    return scope_
end

---@param scope_ Grapple.Scope
---@param key Grapple.StateKey
---@return Grapple.StateItem | nil
function state.get(scope_, key)
    return vim.deepcopy(internal_state[scope_][key])
end

---@param scope_ Grapple.Scope
---@param data any
---@param key? Grapple.StateKey
---@return Grapple.StateItem
function state.set(scope_, data, key)
    local state_item = vim.deepcopy(data)

    key = key or (#internal_state[scope_] + 1)
    internal_state[scope_][key] = state_item

    return vim.deepcopy(state_item)
end

---@param scope_ Grapple.Scope
---@param key Grapple.StateKey
function state.unset(scope_, key)
    state.set(scope_, nil, key)
end

---@param scope_ Grapple.Scope
---@param key Grapple.StateKey
---@return boolean
function state.exists(scope_, key)
    return state.get(scope_, key) ~= nil
end

---@param scope_ Grapple.Scope
---@param properties table
---@return Grapple.StateKey | nil
function state.key(scope_, properties)
    return state.reverse_lookup(state.scope(scope_), properties)
end

---@param scope_state Grapple.ScopeState
---@param properties table
---@return Grapple.StateKey | nil
function state.reverse_lookup(scope_state, properties)
    for key, item in pairs(scope_state) do
        for attribute, value in pairs(properties) do
            if item[attribute] == value then
                return key
            end
        end
    end
end

---@param scope_ Grapple.Scope
---@return Grapple.StateKey[]
function state.keys(scope_)
    return vim.tbl_keys(state.scope(scope_))
end

---@return Grapple.Scope[]
function state.scopes()
    return vim.tbl_keys(internal_state)
end

---@param scope_ Grapple.Scope
---@return Grapple.ScopeState
function state.scope(scope_)
    return vim.deepcopy(internal_state[scope_])
end

---@param scope_ Grapple.Scope
---@return Grapple.FullStateItem[]
function state.with_keys(scope_)
    local with_keys = {}
    for key, item in pairs(state.scope(scope_)) do
        item.key = key
        table.insert(with_keys, item)
    end
    return with_keys
end

---@param scope_ Grapple.Scope
---@return integer
function state.count(scope_)
    return #internal_state[scope_]
end

---@return Grapple.ScopePair[]
function state.scope_pairs()
    local scope_pairs = {}
    for scope_, scope_state in pairs(internal_state) do
        table.insert(scope_pairs, {
            scope = scope_,
            resolver = getmetatable(scope_state).__resolver,
        })
    end
    return scope_pairs
end

---@param Grapple.Scope
---@return Grapple.ScopeResolver
function state.resolver(scope_)
    local scope_pairs = state.scope_pairs()
    for _, scope_pair in pairs(scope_pairs) do
        if scope_ == scope_pair.scope then
            return scope_pair.resolver
        end
    end
end

---@return table<Grapple.Scope, Grapple.ScopeState>
function state.state()
    return vim.deepcopy(internal_state)
end

---@param state_
---@param opts? { persist?: boolean }
function state.load_all(state_, opts)
    opts = opts or { persist = false }

    internal_state = state_
    for _, scope_state in pairs(internal_state) do
        if getmetatable(scope_state) == nil then
            setmetatable(scope_state, {
                __persist = opts.persist,
            })
        end
    end
end

---@param scope_? Grapple.Scope
function state.reset(scope_)
    if scope_ ~= nil then
        local scope_resolver = state.resolver(scope_)
        internal_state[scope_] = with_metatable({}, scope_resolver)
    else
        internal_state = {}
    end
end

return state
