---@class Error
---@field type string
---@field message string
local Error = {}
Error.__index = Error

---@param type string
---@param message string
function Error:new(type, message, err)
    return setmetatable({
        type = type,
        message = message,
    }, self)
end

---@param error_builder ErrorBuilder
function Error:is(error_builder)
    return self.type == error_builder.type
end

function Error:error()
    return self.message
end

return Error
