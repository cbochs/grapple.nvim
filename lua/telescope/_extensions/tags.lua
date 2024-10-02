local Grapple = require("grapple")

local function create_finder()
    local tags, err = Grapple.tags()
    if not tags then
        ---@diagnostic disable-next-line: param-type-mismatch
        return vim.notify(err, vim.log.levels.ERROR)
    end

    local results = {}
    for i, tag in ipairs(tags) do
        ---@class grapple.telescope.result
        local result = {
            i,
            tag.path,
            (tag.cursor or { 1, 0 })[1],
            (tag.cursor or { 1, 0 })[2],
        }

        table.insert(results, result)
    end

    return require("telescope.finders").new_table({
        results = results,

        ---@param result grapple.telescope.result
        entry_maker = function(result)
            local utils = require("telescope.utils")

            local filename = result[2]
            local lnum = result[3]

            local entry = {
                value = result,
                ordinal = filename,
                display = function(entry)
                    local display, path_style, hl_group, icon

                    display, path_style = utils.transform_path({ path_display = {} }, entry.filename)
                    display, hl_group, icon = utils.transform_devicons(entry.filename, display)

                    if hl_group then
                        path_style = { { { 0, #icon }, hl_group } }
                    else
                        path_style = nil
                    end

                    return display, path_style
                end,
                filename = filename,
                lnum = lnum,
            }

            return entry
        end,
    })
end

local function delete_tag(prompt_bufnr)
    local action_state = require("telescope.actions.state")
    local selection = action_state.get_selected_entry()

    Grapple.untag({ path = selection.filename })

    local current_picker = action_state.get_current_picker(prompt_bufnr)
    current_picker:refresh(create_finder(), { reset_prompt = true })
end

return function(opts)
    local conf = require("telescope.config").values

    require("telescope.pickers")
        .new(opts or {}, {
            finder = create_finder(),
            sorter = conf.file_sorter({}),
            previewer = conf.grep_previewer({}),
            results_title = "Grapple Tags",
            prompt_title = "Find Grappling Tags",
            layout_strategy = "flex",
            attach_mappings = function(_, map)
                map("i", "<C-X>", delete_tag)
                map("n", "<C-X>", delete_tag)
                return true
            end,
        })
        :find()
end
