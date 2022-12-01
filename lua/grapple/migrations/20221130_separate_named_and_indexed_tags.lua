local migration = {}

migration.LEVEL = 2

---@param save_dir string
function migration.migrate(save_dir)
    local Path = require("plenary.path")
    local state = require("grapple.state")

    save_dir = save_dir or require("grapple.settings").save_path

    for file_name, _ in vim.fs.dir(save_dir) do
        if file_name == "migration_level" then
            goto continue
        end

        local file_path = Path:new(save_dir) / file_name
        local scope_state = vim.json.decode(file_path:read())

        if scope_state == nil then
            goto continue
        end
        if scope_state.__indexed ~= nil then
            goto continue
        end

        for key, _ in pairs(scope_state) do
            local new_key = tonumber(key) or key

            if new_key ~= key then
                scope_state[new_key] = scope_state[key]
                scope_state[key] = nil
            end
        end

        file_path:write(state.serialize(scope_state), "w")

        ::continue::
    end
end

return migration
