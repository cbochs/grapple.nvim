local popup = require("grapple.popup")
local state = require("grapple.state")

local popup_scopes = {}

popup_scopes.handler = {}

---@param popup_menu Grapple.PopupMenu
---@param scope Grapple.FullTag
---@return string
function popup_scopes.handler.serialize(_, scope)
    local count = state.count(scope)
    local text = " [" .. count .. "] " .. scope
    return text
end

---@param popup_menu Grapple.PopupMenu
---@param line string
---@return Grapple.Scope
function popup_scopes.handler.deserialize(_, line)
    local pattern = "%] (.*)"
    local scope = string.match(line, pattern)
    return scope
end

---@param popup_menu Grapple.PopupMenu
function popup_scopes.handler.resolve(popup_menu)
    ---@type Grapple.PopupTag[]
    local original_scopes = popup_menu.items

    ---@type Grapple.PartialTag[]
    local modified_scopes = popup.items(popup_menu)

    popup_scopes.resolve_differences(original_scopes, modified_scopes)
end

function popup_scopes.resolve_differences(original_scopes, modified_scopes)
    ---@type table<string, Grapple.PartialTag>
    local scope_lookup = {}
    for _, scope in ipairs(modified_scopes) do
        scope_lookup[scope] = true
    end

    -- Reset scopes that were removed from the popup menu
    for _, scope in ipairs(original_scopes) do
        if not scope_lookup[scope] then
            state.reset(scope)
        end
    end
end

popup_scopes.actions = {}

---@param popup_menu Grapple.PopupMenu
function popup_scopes.actions.close(popup_menu)
    popup.close(popup_menu)
end

return popup_scopes
