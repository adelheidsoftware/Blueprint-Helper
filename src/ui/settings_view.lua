-- The settings tab in the client's Plugins window, built with PrettyUI. Rebuilt on every SettingsLayerReady. Writes
-- through to the settings table and tells the caller, so the helper view and overlay follow at once.

local ConfirmDialog = require("src/ui/confirm_dialog")

local SettingsView = {}
SettingsView.__index = SettingsView

---@param settings table the live settings table
---@param callbacks table { onChanged = function(), onResetAll = function() }
function SettingsView.new(settings, callbacks)
    local self = setmetatable({}, SettingsView)
    self.settings = settings
    self.callbacks = callbacks
    self.view = nil
    self.layer = nil
    return self
end

---@param layer table the component from Event.SettingsLayerReady
function SettingsView:Mount(layer)
    self:Destroy()
    self.layer = layer
    local settings = self.settings
    local callbacks = self.callbacks
    local ok, err = pcall(function()
        self.view = prettyui.SimpleView.new(layer, { width = layer.width, height = layer.height })
        local view = self.view
        view:AddTitle("Blueprint Helper")
        view:AddText("Changes apply immediately.")
        view:AddRadioButton({
            { text = "Guide: suggest the next swap", value = "guide" },
            { text = "Logbook: only track readings", value = "logbook" },
        }, {
            selectedValue = settings.mode,
            onChange = function(_, value)
                settings.mode = value
                callbacks.onChanged()
            end,
        })
        view:AddCheckboxButton({
            {
                text = "Highlight slots and modules on the Discovery window",
                value = "overlay",
                selected = settings.overlay,
            },
            {
                text = "Show the XP percentage next to the level",
                value = "showXp",
                selected = settings.showXp,
            },
            {
                text = "Compact history (levels only, no module icons)",
                value = "compactHistory",
                selected = settings.compactHistory,
            },
        }, {
            marginTop = 6,
            onChange = function(_, _, changedValue, selected)
                settings[changedValue] = selected
                callbacks.onChanged()
            end,
        })
        view:AddText({
            text = "Remembered blueprints last until you close the client. Only these settings are saved.",
            marginTop = 12,
        })
        view:AddFancyButton("Reset all data", function()
            ConfirmDialog.show({
                title = "Reset all data?",
                body = "Every remembered blueprint is forgotten and the settings go back to their defaults.",
                onConfirm = callbacks.onResetAll,
            })
        end, {
            variant = "negative",
            marginTop = 6,
            tooltip = {
                text = "Forget every remembered blueprint and restore the default settings.",
                placement = "above",
                maxWidth = 240,
            },
        })
    end)
    if not ok then
        log("Blueprint Helper: settings view failed to build: " .. tostring(err))
    end
end

-- Rebuilds the tab in place, for after a reset. Call it from a Logic tick, not from one of the tab's own buttons.
function SettingsView:Remount()
    if self.layer ~= nil then
        self:Mount(self.layer)
    end
end

function SettingsView:Destroy()
    if self.view ~= nil then
        pcall(function()
            self.view:Destroy()
        end)
        self.view = nil
    end
end

return SettingsView
