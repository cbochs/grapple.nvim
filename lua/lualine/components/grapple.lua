return function()
    local highlight = require("grapple.highlight")
    local tag = require("grapple").find({ buffer = 0 })

    if tag ~= nil then
        return "%#" .. highlight.groups.lualine_tag_active .. "#" .. "[" .. tostring(tag.key) .. "]" .. "%*"
    else
        return "%#" .. highlight.groups.lualine_tag_inactive .. "#" .. "[U]" .. "%*"
    end
end
