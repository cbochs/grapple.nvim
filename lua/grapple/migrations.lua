local migrations = {}

function migrations.migrate(save_dir)
    if vim.g.grapple_testing then
        return
    end

    local Path = require("plenary.path")

    save_dir = Path:new(save_dir or require("grapple.settings").save_path)
    if not save_dir:exists() then
        save_dir:mkdir()
    end

    local migration_path = save_dir / "migration_level"
    migration_path:touch()

    local migration_level = tonumber(migration_path:read()) or 0

    local migration_list = {
        -- Give two weeks migration time. Delete 12-12-2022
        -- "20221126_save_as_individual_files",

        -- Give two weeks migration time. Delete 14-12-2022
        -- "20221130_separate_named_and_indexed_tags",
    }

    for _, migration_name in ipairs(migration_list) do
        local migration = require("grapple.migrations." .. migration_name)
        if migration_level < migration.LEVEL then
            migration.migrate()
            migration_level = migration_level + 1
            migration_path:write(tostring(migration_level), "w")
        end
    end
end

return migrations
