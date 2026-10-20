-- Player preferences, the only thing the plugin stores. They live in one PersistentDB entry and every field is
-- validated on load, so a value written by an older build can never stop the plugin from enabling. Puzzle
-- progress is never stored.

local Constants = require("src/constants")

local Settings = {}

Settings.DEFAULTS = {
    mode = "guide", -- "guide" suggests the next swap, "logbook" only records readings
    overlay = true, -- outline slots and modules on the Discovery window
    showXp = true, -- show the XP percentage next to the level
    compactHistory = false, -- history as level names only, without module icons
}

local MODES = { guide = true, logbook = true }
local FLAGS = { "overlay", "showXp", "compactHistory" }

-- Puts every field of `settings` back to its default, in place, so everything holding the table sees the change.
---@param settings table
function Settings.restoreDefaults(settings)
    for key, value in pairs(Settings.DEFAULTS) do
        settings[key] = value
    end
end

---@param db table PersistentDB
---@return table settings with every field present and valid
function Settings.load(db)
    local settings = {}
    Settings.restoreDefaults(settings)
    local stored = db:GetStructuredData(Constants.DB_KEYS.settings)
    if type(stored) == "table" then
        if MODES[stored.mode] then
            settings.mode = stored.mode
        end
        for _, key in ipairs(FLAGS) do
            if type(stored[key]) == "boolean" then
                settings[key] = stored[key]
            end
        end
    end
    return settings
end

---@param db table PersistentDB
---@param settings table
function Settings.save(db, settings)
    local stored = {}
    for key in pairs(Settings.DEFAULTS) do
        stored[key] = settings[key]
    end
    db:SetStructuredData(Constants.DB_KEYS.settings, stored)
end

return Settings
