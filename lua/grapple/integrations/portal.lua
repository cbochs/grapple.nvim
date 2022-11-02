local M = {}

local function is_tagged(jump)
    local query = require("portal.query")
    local grapple = require("grapple")
    return query.valid.predicate(jump) and query.different.predicate(jump) and grapple.find({ buffer = jump.buffer })
end

function M.load()
    local ok, query = pcall(require, "portal.query")
    if ok then
        query.register("tagged", is_tagged, {
            name = "Tagged",
            name_short = "T",
        })
    end
end

return M
