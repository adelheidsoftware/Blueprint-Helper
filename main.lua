-- Entry point. Wiring only: checks the PrettyUI dependency, loads the settings, builds the reader, session,
-- watcher, view and overlay, subscribes to the client's events and tears everything down in PluginShutdown.
-- The puzzle logic lives in src/core/ and never touches the client; src/game/ and src/ui/ do.
--
-- What this plugin touches, for review:
--   reads        the Discovery interface's components, by name and read-only; src/game/interface_ids.lua lists
--                them and src/game/discovery_reader.lua is the only file that reads them
--   draws        its own components on the plugin build layer (src/game/overlay.lua) and PrettyUI views in the
--                Plugins window (src/ui/); it never assigns to a game component
--   stores       four settings in PersistentDB (src/settings.lua); no puzzle data is persisted
--   sends        nothing: no urls in the manifest, no HTTPRequest
--   permissions  none requested, none checked
--   events       Event.Logic, Event.ContentLayerReady and Event.SettingsLayerReady, all unsubscribed in
--                PluginShutdown

local Client = require("src/client")
local Constants = require("src/constants")
local Settings = require("src/settings")
local Session = require("src/core/session")
local Reader = require("src/game/discovery_reader")
local Watcher = require("src/game/watcher")
local Overlay = require("src/game/overlay")
local HelperView = require("src/ui/helper_view")
local SettingsView = require("src/ui/settings_view")

local MIN_PRETTYUI = { 1, 2, 0 }
local VIEW_DEBOUNCE_TICKS = 5 -- ContentLayerReady fires on every resize step; build once the burst is over

local function versionAtLeast(text, minimum)
    if type(text) ~= "string" then
        return false
    end
    local parts = {}
    for number in text:gmatch("%d+") do
        parts[#parts + 1] = tonumber(number)
    end
    for i = 1, #minimum do
        local have = parts[i] or 0
        if have > minimum[i] then
            return true
        end
        if have < minimum[i] then
            return false
        end
    end
    return true
end

if prettyui == nil or not versionAtLeast(prettyui.version, MIN_PRETTYUI) then
    log(string.format("Blueprint Helper %s needs PrettyUI %d.%d.%d or newer; found %s. Nothing enabled.",
        Constants.VERSION, MIN_PRETTYUI[1], MIN_PRETTYUI[2], MIN_PRETTYUI[3],
        tostring(prettyui and prettyui.version or "none")))
    -- The client requires this hook to be global.
    function PluginShutdown()
    end
    return
end

local settings = Settings.load(PersistentDB)
local session = Session.new({ mode = settings.mode })
local reader = Reader.new()
local overlay = Overlay.new()
local lastViewModel = session:ViewModel()
local watcher -- assigned below; the view callbacks only ever ask it for a render on the next tick

-- Button callbacks must not rebuild the view they live in while PrettyUI is still handling the click, so they
-- change the session and leave the render to the watcher's next Logic tick.
local helperView = HelperView.new({
    onReset = function()
        session:Reset()
        watcher:RequestRender()
    end,
    onForget = function()
        session:ForgetLastReading()
        watcher:RequestRender()
    end,
    onRerender = function()
        watcher:RequestRender()
    end,
}, settings)

local function renderOverlay(vm)
    local enabled = settings.overlay and not reader:Busy()
    overlay:Render(vm, reader:SlotRects(), reader:Sources(), reader:BoardIcons(), enabled)
end

watcher = Watcher.new({
    reader = reader,
    session = session,
    onChanged = function(vm)
        lastViewModel = vm
        helperView:Render(vm)
        renderOverlay(vm)
    end,
    -- The Discovery window can be dragged, so the marks re-read the component positions every poll, and they step
    -- aside while the game shows the Prototype animation or a dialog.
    onPolled = renderOverlay,
})

local function onSettingsChanged()
    Settings.save(PersistentDB, settings)
    session:SetMode(settings.mode)
    watcher:RequestRender()
end

local settingsRemountPending = false
local settingsView = SettingsView.new(settings, {
    onChanged = onSettingsChanged,
    -- "Reset all data": every remembered blueprint and the settings themselves. The settings tab is rebuilt on the
    -- next tick rather than from inside its own dialog callback.
    onResetAll = function()
        session:ForgetAll()
        Settings.restoreDefaults(settings)
        onSettingsChanged()
        settingsRemountPending = true
    end,
})

local pendingLayer = nil
local pendingSince = 0

Event.ContentLayerReady.Subscribe(Constants.EVENTS.contentLayer, function(event)
    pendingLayer = event.component
    pendingSince = watcher.tick
    helperView:SetLayer(nil) -- the old components are gone with the cleared layer
end)

Event.SettingsLayerReady.Subscribe(Constants.EVENTS.settingsLayer, function(event)
    settingsView:Mount(event.component)
end)

-- Mounts the view once the resize burst has settled. Guarded like the poll so one failed build cannot stop later ones.
local logMountError = Client.errorLog("view failed to mount")
Event.Logic.Subscribe(Constants.EVENTS.viewDebounce, function(event)
    if settingsRemountPending then
        settingsRemountPending = false
        pcall(function()
            settingsView:Remount()
        end)
    end
    if pendingLayer == nil or event.logicTick - pendingSince < VIEW_DEBOUNCE_TICKS then
        return
    end
    local layer = pendingLayer
    pendingLayer = nil
    local ok, err = pcall(function()
        helperView:SetLayer(layer)
        helperView:Render(lastViewModel)
    end)
    if not ok then
        logMountError(err)
    end
end)

watcher:Start()
log(string.format("Blueprint Helper %s enabled (PrettyUI %s)", Constants.VERSION, tostring(prettyui.version)))

-- The client requires this hook to be global.
function PluginShutdown()
    watcher:Stop()
    Event.Logic.Unsubscribe(Constants.EVENTS.viewDebounce)
    Event.ContentLayerReady.Unsubscribe(Constants.EVENTS.contentLayer)
    Event.SettingsLayerReady.Unsubscribe(Constants.EVENTS.settingsLayer)
    helperView:Destroy()
    settingsView:Destroy()
    overlay:Destroy()
    Settings.save(PersistentDB, settings)
end
