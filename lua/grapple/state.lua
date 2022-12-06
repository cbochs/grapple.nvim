local Path = require("plenary.path")
local helpers = require("grapple.helpers")
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

---@param scope_resolver Grapple.ScopeResolverLike
---@param key Grapple.StateKey
---@return Grapple.StateItem | nil
function state.get(scope_resolver, key)
    local scope_ = state.ensure_loaded(scope_resolver)
    return state.get_raw(scope_, key)
end

---@param scope_ Grapple.Scope
---@param key Grapple.StateKey
---@return Grapple.StateItem | nil
function state.get_raw(scope_, key)
    return vim.deepcopy(internal_state[scope_][key])
end

---@param scope_resolver Grapple.ScopeResolverLike
---@param data any
---@param key? Grapple.StateKey
---@return Grapple.StateItem
function state.set(scope_resolver, data, key)
    local scope_ = state.ensure_loaded(scope_resolver)
    return state.set_raw(scope_, data, key)
end

---@param scope_ Grapple.Scope
---@param data any
---@param key? Grapple.StateKey
---@return Grapple.StateItem
function state.set_raw(scope_, data, key)
    local state_item = vim.deepcopy(data)

    if key == nil then
        table.insert(internal_state[scope_], state_item)
    elseif type(key) == "number" then
        table.insert(internal_state[scope_], key, state_item)
    elseif type(key) == "string" then
        internal_state[scope_][key] = state_item
    else
        log.error(string.format("Invalid key. key: %s", key))
        error(string.format("Invalid key. key: %s", key))
    end

    return vim.deepcopy(state_item)
end

---@param scope_resolver Grapple.ScopeResolverLike
---@param key Grapple.StateKey
function state.unset(scope_resolver, key)
    local scope_ = state.ensure_loaded(scope_resolver)
    state.unset_raw(scope_, key)
end

---@param scope_ Grapple.Scope
---@param key Grapple.StateKey
function state.unset_raw(scope_, key)
    if type(key) == "number" then
        table.remove(internal_state[scope_], key)
    elseif type(key) == "string" then
        internal_state[scope_][key] = nil
    else
        log.error(string.format("Invalid key. key: %s", key))
        error(string.format("Invalid key. key: %s", key))
    end
end

---@param scope_resolver Grapple.ScopeResolverLike
---@param actions Grapple.StateAction[]
---@return Grapple.ScopeState
function state.commit(scope_resolver, actions)
    local scope_ = state.ensure_loaded(scope_resolver)
    return state.commit_raw(scope_, actions)
end

---@param scope_ Grapple.Scope
---@param actions Grapple.StateAction[]
---@return Grapple.ScopeState
function state.commit_raw(scope_, actions)
    for _, record in ipairs(actions) do
        if record.action == state.actions.type.set then
            state.set_raw(scope_, record.change.data, record.change.key)
        elseif record.action == state.actions.type.unset then
            state.unset_raw(scope_, record.change.key)
        elseif record.action == state.actions.type.move then
            local state_item = state.get_raw(scope_, record.change.old_key)
            state.unset_raw(scope_, record.change.old_key)
            state.set_raw(scope_, state_item, record.change.new_key)
        else
            log.error(string.format("Invalid change record type. type: %s", record.type))
            error(string.format("Invalid change record type. type: %s", record.type))
        end
    end
    return state.scope_raw(scope_)
end

---@param scope_resolver Grapple.ScopeResolverLike
---@param key Grapple.StateKey
---@return boolean
function state.exists(scope_resolver, key)
    return state.get(scope_resolver, key) ~= nil
end

---@param scope_resolver Grapple.ScopeResolverLike
---@param properties table
---@return Grapple.StateKey | nil
function state.key(scope_resolver, properties)
    return state.reverse_lookup(state.scope(scope_resolver), properties)
end

---@param scope_ Grapple.Scope
---@param properties table
---@return Grapple.StateKey | nil
function state.key_raw(scope_, properties)
    return state.reverse_lookup(state.scope_raw(scope_), properties)
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

---@param scope_resolver Grapple.ScopeResolverLike
---@return Grapple.StateKey[]
function state.keys(scope_resolver)
    return vim.tbl_keys(state.scope(scope_resolver))
end

function state.with_key(key, item)
    item = vim.deepcopy(item)
    item.key = key
    return item
end

---@param scope_resolver Grapple.ScopeResolverLike
---@return Grapple.FullStateItem[]
function state.with_keys(scope_resolver)
    local scope_state = state.scope(scope_resolver)
    return state.with_keys_raw(scope_state)
end

---@param scope_state Grapple.ScopeState
---@return Grapple.FullStateItem[]
function state.with_keys_raw(scope_state)
    return helpers.table.map(function(key, item)
        return state.with_key(key, item)
    end, scope_state)
end

---@return Grapple.Scope[]
function state.scopes()
    return vim.tbl_keys(internal_state)
end

---@param scope_resolver Grapple.ScopeResolverLike
---@return Grapple.ScopeState
function state.scope(scope_resolver)
    local scope_ = state.ensure_loaded(scope_resolver)
    return state.scope_raw(scope_)
end

---@param scope_ Grapple.Scope
---@return Grapple.ScopeState
function state.scope_raw(scope_)
    return vim.deepcopy(internal_state[scope_])
end

---@param scope_resolver Grapple.ScopeResolverLike
---@return integer
function state.count(scope_resolver)
    local scope_ = state.ensure_loaded(scope_resolver)
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

---@param scope_resolver? Grapple.ScopeResolverLike
function state.reset(scope_resolver)
    if scope_resolver ~= nil then
        local scope_ = scope.get(scope_resolver)
        internal_state[scope_] = with_metatable({}, scope_resolver)
    else
        internal_state = {}
    end
end

---@generic T
---@class Grapple.StateAction<T>
---@field action Grapple.StateActionType
---@field change T

---@class Grapple.StateChangeSet
---@field data any
---@field key Grapple.StateKey

---@class Grapple.StateChangeUnset
---@field key Grapple.StateKey

---@class Grapple.StateChangeMove
---@field old_key Grapple.StateKey
---@field new_key Grapple.StateKey

state.actions = {}

---@enum Grapple.StateActionType
state.actions.type = {
    set = "set",
    unset = "unset",
    move = "move",
}

---@param data Grapple.StateItem
---@param key Grapple.StateKey
---@return Grapple.StateAction<Grapple.StateChangeSet>
function state.actions.set(data, key)
    return {
        action = state.actions.type.set,
        change = {
            data = data,
            key = key,
        },
    }
end

---@param key Grapple.StateKey
---@return Grapple.StateAction<Grapple.StateChangeUnset>
function state.actions.unset(key)
    return {
        action = state.actions.type.unset,
        change = {
            key = key,
        },
    }
end

---@param old_key Grapple.StateKey
---@param new_key Grapple.StateKey
---@return Grapple.StateAction<Grapple.StateChangeMove>
function state.actions.move(old_key, new_key)
    return {
        action = state.actions.type.move,
        change = {
            old_key = old_key,
            new_key = new_key,
        },
    }
end

return state
