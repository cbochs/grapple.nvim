return function()
    local highlight = require("grapple.highlight")
    local tag_key = require("grapple").key({ buffer = 0 })
    if tag_key ~= nil then
        return "%#" .. highlight.groups.lualine_tag_active .. "#" .. "[" .. tostring(tag_key) .. "]" .. "%*"
    else
        return "%#" .. highlight.groups.lualine_tag_inactive .. "#" .. "[U]" .. "%*"
    end
end
