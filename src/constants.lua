-- Names shared across the plugin: the version string, event subscription names and PersistentDB keys.
-- Subscription names carry the plugin name so they cannot collide with another plugin's.

local Constants = {}

-- Keep in step with "version" in plugin.json; the client does not expose the manifest to Lua.
Constants.VERSION = "1.0.0"

Constants.EVENTS = {
    logic = "blueprint-helper.logic",
    viewDebounce = "blueprint-helper.viewDebounce",
    contentLayer = "blueprint-helper.contentLayer",
    settingsLayer = "blueprint-helper.settingsLayer",
}

Constants.DB_KEYS = {
    settings = "settings",
}

return Constants
