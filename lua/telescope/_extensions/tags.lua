local grapple = require("grapple")

local generate_grapple_finder = function()
  local tags = grapple.tags()
  local results_list = {}

  for idx, tag in ipairs(tags) do
    local filepath = tag.file_path
    local row, col = unpack(tag.cursor)
    table.insert(
      results_list,
      { idx, filepath, row, col }
    )
  end

  return require("telescope.finders").new_table({
    results = results_list,
    entry_maker = function(entry)
      local utils = require("telescope.utils")

      local ordinal = entry[1]
      local filepath = entry[2]
      local filepathDisplay = utils.transform_path({}, filepath)
      local lineNum = entry[3]

      return {
        value = entry,
        filename = filepath,
        display = filepathDisplay,
        ordinal = ordinal,
        lnum = lineNum
      }
    end
  })
end

local delete_grapple = function(prompt_bufnr)
  local action_state = require("telescope.actions.state")
  local selection = action_state.get_selected_entry()

  grapple.untag({ file_path = selection.filename })

  local current_picker = action_state.get_current_picker(prompt_bufnr)
  current_picker:refresh(generate_grapple_finder(), { reset_prompt = true })
end

return function(opts)
  opts = opts or {}

  require("telescope.pickers")
      .new(opts, {
        finder = generate_grapple_finder(),
        sorter = require("telescope.sorters").get_generic_fuzzy_sorter(),
        previewer = require("telescope.config").values.grep_previewer {},
        results_title = "Grapple Tags",
        prompt_title = "Find Grappling Tags",
        layout_strategy = "flex",
        attach_mappings = function(_, map)
          map("i", "<C-X>", delete_grapple)
          map("n", "<C-X>", delete_grapple)
          return true
        end,
      }):find()
end
