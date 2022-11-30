local Path = require("plenary.path")
local scope = require("grapple.scope")
local settings = require("grapple.settings")

local state = {}

---@alias Grapple.StateKey string | integer

---@alias Grapple.StateItem Grapple.Tag

---@alias Grapple.StateTable table<Grapple.StateKey, Grapple.StateItem>

---@type table<Grapple.Scope, Grapple.StateTable>
local internal_state = {}

---Reference: https://github.com/golgote/neturl/blob/master/lib/net/url.lua
---
---@param plain_string string
---@return string
local function encode(plain_string)
    return string.gsub(plain_string, "([^%w])", function(match)
        return string.upper(string.format("%%%02x", string.byte(match)))
    end)
end

-- luacheck: ignore
---@param encoded_string string
---@return string
local function decode(encoded_string)
    return string.gsub(encoded_string, "%%(%x%x)", function(match)
        return string.char(tonumber(match, 16))
    end)
end

---@param state_ table
---@return string
local function serialize(state_)
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
local function deserialize(serialized_state)
    local separated_state = vim.json.decode(serialized_state)
    local state_ = separated_state

    for _, state_item in ipairs(separated_state.__indexed) do
        table.insert(state_, state_item)
    end
    state_.__indexed = nil

    return state_
end

---@param scope_state Grapple.StateTable
---@return boolean
local function should_persist(scope_state)
    return getmetatable(scope_state).__persist
end

---@param save_dir? string
function state.save(save_dir)
    save_dir = Path:new(save_dir or settings.save_path)
    if not save_dir:exists() then
        save_dir:mkdir()
    end

    for scope_, scope_state in pairs(internal_state) do
        if vim.tbl_isempty(scope_state) then
            goto continue
        end
        if not should_persist(scope_state) then
            goto continue
        end

        local save_path = save_dir / encode(scope_)
        save_path:write(serialize(scope_state), "w")

        ::continue::
    end
end

---@param scope_resolver Grapple.ScopeResolverLike
---@param save_dir? string
---@return Grapple.StateTable
function state.load(scope_resolver, save_dir)
    scope_resolver = scope.find_resolver(scope_resolver)
    if not scope_resolver.persist then
        return nil
    end

    local scope_ = scope.get(scope_resolver)

    save_dir = Path:new(save_dir or settings.save_path)
    local save_path = save_dir / encode(scope_)
    if not save_path:exists() then
        return nil
    end

    local serialized_state = save_path:read()

    return deserialize(serialized_state)
end

---@param save_dir? string
function state.prune(save_dir)
    save_dir = Path:new(save_dir or settings.save_path)
    for scope_, scope_state in pairs(internal_state) do
        local save_path = save_dir / encode(scope_)
        if vim.tbl_isempty(scope_state) and save_path:exists() then
            save_path:rm()
        end
    end
end

---@param scope_resolver Grapple.ScopeResolverLike
function state.ensure_loaded(scope_resolver)
    scope_resolver = scope.find_resolver(scope_resolver)
    local scope_ = scope.get(scope_resolver)

    if internal_state[scope_] ~= nil then
        return
    end

    internal_state[scope_] = state.load(scope_) or {}
    setmetatable(internal_state[scope_], {
        __persist = scope_resolver.persist,
    })
end

---@param scope_resolver Grapple.ScopeResolverLike
---@param key Grapple.StateKey
---@return Grapple.StateItem | nil
function state.get(scope_resolver, key)
    local scope_ = scope.get(scope_resolver)
    state.ensure_loaded(scope_)
    return vim.deepcopy(internal_state[scope_][key])
end

---@param scope_resolver Grapple.ScopeResolverLike
---@param data any
---@param key? Grapple.StateKey
function state.set(scope_resolver, data, key)
    local scope_ = scope.get(scope_resolver)
    state.ensure_loaded(scope_resolver)

    local state_item = vim.deepcopy(data)

    key = key or (#internal_state[scope_resolver] + 1)
    internal_state[scope_][key] = data

    return vim.deepcopy(state_item)
end

---@param scope_resolver Grapple.ScopeResolverLike
---@param key Grapple.StateKey
function state.unset(scope_resolver, key)
    state.set(scope_resolver, nil, key)
end

---@param scope_resolver Grapple.ScopeResolverLike
---@return Grapple.StateTable
function state.scope(scope_resolver)
    local scope_ = scope.get(scope_resolver)
    state.ensure_loaded(scope_resolver)
    return vim.deepcopy(internal_state[scope_])
end

---@param scope_resolver Grapple.ScopeResolverLike
function state.count(scope_resolver)
    local scope_ = scope.get(scope_resolver)
    state.ensure_loaded(scope_resolver)
    return #internal_state[scope_]
end

---@param scope_resolver? Grapple.ScopeResolverLike
function state.reset(scope_resolver)
    if scope_resolver ~= nil then
        local scope_ = scope.get(scope_resolver)
        internal_state[scope_] = nil
    else
        internal_state = {}
    end
end

return state
