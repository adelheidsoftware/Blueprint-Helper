-- Test double for the client's PersistentDB: an in-memory store with the structured accessors the plugin uses, and
-- SetString for writing a value of the wrong type.
local PersistentDbDouble = {}
PersistentDbDouble.__index = PersistentDbDouble

function PersistentDbDouble.new()
    return setmetatable({ store = {} }, PersistentDbDouble)
end

function PersistentDbDouble:SetString(key, value)
    self.store[key] = value
    return true
end

function PersistentDbDouble:GetStructuredData(key)
    local v = self.store[key]
    return type(v) == "table" and v or nil
end

function PersistentDbDouble:SetStructuredData(key, value)
    self.store[key] = value
    return true
end

return PersistentDbDouble
