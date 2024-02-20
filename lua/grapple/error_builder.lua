local Error = require("grapple.error")

---@class grapple.error.builder
---@field type string
---@field err fun(...): string
local ErrorBuilder = {}
ErrorBuilder.__index = ErrorBuilder

---@param type string
---@param err fun(...): string
---@return grapple.error.builder
function ErrorBuilder:create(type, err)
    return setmetatable({
        type = type,
        err = err,
    }, self)
end

function ErrorBuilder:default(type)
    return setmetatable({
        type = type,
        err = function(message)
            return message
        end,
    }, self)
end

---@return grapple.error
function ErrorBuilder:new(...)
    return Error:new(self.type, self.err(...))
end

return ErrorBuilder
