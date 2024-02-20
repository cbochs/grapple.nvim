local Error = require("grapple.new.error")

---@class ErrorBuilder
---@field type string
---@field err fun(...): string
local ErrorBuilder = {}
ErrorBuilder.__index = ErrorBuilder

---@param type string
---@param err fun(...): string
---@return ErrorBuilder
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

---@return Error
function ErrorBuilder:new(...)
    return Error:new(self.type, self.err(...))
end

return ErrorBuilder
