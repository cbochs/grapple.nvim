local App = {}

---A global instance of the Grapple app
local app = nil

function App.get()
    if app then
        return app
    end

    local ScopeManager = require("grapple.scope_manager")
    local StateManager = require("grapple.state_manager")
    local TagManager = require("grapple.tag_manager")

    local state_manager = StateManager:new("test_saves")
    local tag_manager = TagManager:new(state_manager)
    local scope_manager = ScopeManager:new(tag_manager)

    ---@class grapple.app
    app = {
        scope_manager = scope_manager,
        state_manager = state_manager,
        tag_manager = tag_manager,
    }

    return app
end

return App
