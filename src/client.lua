-- Guarded access to the client. A name the client does not know, or a component it replaced underneath, raises an
-- error when indexed; every lookup of that kind goes through here and yields nil instead. Errors caught in a loop
-- that runs every tick are logged through here too, so the console is not flooded with the same message.

local Client = {}

---@param fn function a lookup that may raise
---@return any value what `fn` returned, or nil when it raised
function Client.lookup(fn)
    local ok, value = pcall(fn)
    if ok then
        return value
    end
    return nil
end

-- The plugin build layer, which holds the overlay's marks and the confirmation dialogs.
---@return table? component
function Client.pluginLayer()
    return Client.lookup(function()
        return ui.Interfaces:GetComponent(id.Component.TOPLEVEL_V2__PLUGIN_BUILD_LAYER_TOP)
    end)
end

-- A logger for an error that may repeat every tick: it logs an error unless it is the same as the one before.
---@param context string what failed, for example "error while polling"
---@return function logError takes the error value
function Client.errorLog(context)
    local last = nil
    return function(err)
        if err ~= last then
            last = err
            log("Blueprint Helper: " .. context .. ": " .. tostring(err))
        end
    end
end

return Client
