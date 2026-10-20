-- Reads the Discovery interface into a plain snapshot table. This is the only module that touches Discovery's
-- components, and it only ever reads them; the overlay gets their positions from here.
--
-- Handles are resolved when the interface appears and dropped when it unloads. Every property read is guarded, so a
-- component the client replaced underneath yields valid = false instead of an error.

local Client = require("src/client")
local InterfaceIds = require("src/game/interface_ids")

local Reader = {}
Reader.__index = Reader

-- Reads a property without letting a stale handle raise.
local function get(component, key)
    return Client.lookup(function()
        return component[key]
    end)
end

local function typeOf(name)
    return Client.lookup(function()
        return ui.ComponentType[name]
    end)
end

function Reader.new()
    local self = setmetatable({}, Reader)
    self.interfaceId = InterfaceIds.interface()
    self.handles = nil
    return self
end

-- Resolves one component by name and checks its type; nil when missing or of another type.
local function resolve(name, expectedType)
    local combined = InterfaceIds.component(name)
    if combined == nil then
        return nil
    end
    local component = ui.Interfaces:GetComponent(combined)
    if component == nil then
        return nil
    end
    local wanted = typeOf(expectedType)
    if wanted ~= nil and get(component, "type") ~= wanted then
        return nil
    end
    return component
end

local function resolveAll(names, expectedType)
    local handles = {}
    for i, name in ipairs(names) do
        handles[i] = resolve(name, expectedType)
    end
    return handles
end

function Reader:resolveHandles()
    local names = InterfaceIds.COMPONENTS
    local handles = {
        trackIcons = resolveAll(names.trackIcons, names.trackIconType),
        partIcons = resolveAll(names.partIcons, names.partIconType),
        partRejected = resolveAll(names.partRejected, names.partRejectedType),
        blueprintIcons = resolveAll(names.blueprintIcons, names.blueprintIconType),
        scoreText = resolve(names.scoreText, names.scoreTextType),
        subjectTitle = resolve(names.subjectTitle, names.subjectTitleType),
        instructionsText = resolve(names.instructionsText, names.instructionsTextType),
        partsLayer = resolve(names.partsLayer, names.layerType),
        trackLayer = resolve(names.trackLayer, names.layerType),
        rootLayer = resolve(names.rootLayer, names.layerType),
        busy = {},
    }
    for _, name in ipairs(names.busy) do
        local component = resolve(name, nil) -- layers and models mixed, so no type check
        if component ~= nil then
            handles.busy[#handles.busy + 1] = component
        end
    end
    -- The reading itself needs the five slots, the score label, the title and the two stage layers. The rest only
    -- adds marks and the "choosing a blueprint" state, so it may be missing.
    local complete = handles.scoreText ~= nil and handles.subjectTitle ~= nil and handles.trackLayer ~= nil
        and handles.partsLayer ~= nil
    for i = 1, 5 do
        if handles.trackIcons[i] == nil then
            complete = false
        end
    end
    handles.complete = complete
    self.handles = handles
end

-- Open means loaded and showing. Closing with the X unloads the interface, but the client can also keep it loaded
-- while it is off screen; such an interface reports visible but has never been laid out, so the root layer must be
-- visible and have a width.
---@return boolean open
function Reader:IsOpen()
    if self.interfaceId == nil or ui.Interfaces:GetInterface(self.interfaceId) == nil then
        self.handles = nil
        return false
    end
    if self.handles == nil then
        self:resolveHandles()
    end
    local root = self.handles.rootLayer
    if root == nil then
        return true -- cannot tell; treat loaded as open rather than read nothing
    end
    local width = get(root, "width")
    return get(root, "visibleGlobal") == true and type(width) == "number" and width > 0
end

-- A module is rejected once the game shows the cross over it. The icon also fades to about half alpha, which is
-- checked as well in case the cross component changes.
local function isRejected(handles, i)
    local crossed = get(handles.partRejected[i], "visibleGlobal") == true
    local alpha = get(handles.partIcons[i], "alpha")
    return crossed or (type(alpha) == "number" and alpha < 0.75)
end

-- The current state of the interface, or nil when Discovery is not open.
---@return table? snapshot { valid, blueprint, stage, row, boardState, scoreText, instructions }
function Reader:Snapshot()
    if not self:IsOpen() then
        return nil
    end
    local h = self.handles
    local snapshot = { valid = h.complete, stage = "unknown", row = {}, boardState = {} }
    if not h.complete then
        return snapshot
    end

    if get(h.trackLayer, "visibleGlobal") == true then
        snapshot.stage = "arrange"
    elseif get(h.partsLayer, "visibleGlobal") == true then
        snapshot.stage = "prototype"
    end

    snapshot.blueprint = get(h.subjectTitle, "content")
    snapshot.scoreText = get(h.scoreText, "content")
    if h.instructionsText ~= nil then
        local instructions = get(h.instructionsText, "content")
        snapshot.instructions = type(instructions) == "string" and instructions or nil
    end

    for i = 1, 5 do
        local spriteId = get(h.trackIcons[i], "spriteID")
        if type(spriteId) ~= "number" then
            snapshot.valid = false
            spriteId = -1
        end
        snapshot.row[i] = spriteId
    end
    -- Prototyping board: a module is on the board while its icon is visible, on the track while it is hidden.
    for i = 1, 10 do
        local icon = h.partIcons[i]
        local spriteId = get(icon, "spriteID")
        spriteId = type(spriteId) == "number" and spriteId or -1
        snapshot.boardState[i] = {
            spriteId = spriteId,
            visible = get(icon, "visibleGlobal") == true,
            rejected = isRejected(h, i),
        }
    end
    if type(snapshot.scoreText) ~= "string" or type(snapshot.blueprint) ~= "string" then
        snapshot.valid = false
    end
    return snapshot
end

-- Screen rectangle of a visible, laid-out icon, else nil.
local function rectOf(icon)
    if icon == nil then
        return nil
    end
    local xy = get(icon, "xyGlobal")
    local width, height = get(icon, "width"), get(icon, "height")
    if xy ~= nil and type(width) == "number" and width > 0 and get(icon, "visibleGlobal") == true then
        return { x = xy.x, y = xy.y, width = width, height = height }
    end
    return nil
end

-- Screen rectangles of the five track slots, for the overlay; an entry is nil while its slot is not showing.
---@return table[] rects { x, y, width, height } indexed by slot
function Reader:SlotRects()
    local rects = {}
    if self.handles == nil then
        return rects
    end
    for i = 1, 5 do
        rects[i] = rectOf(self.handles.trackIcons[i])
    end
    return rects
end

-- True while the game draws something over the window: the Prototype animation or a confirmation dialog.
---@return boolean busy
function Reader:Busy()
    if self.handles == nil then
        return false
    end
    for _, component in ipairs(self.handles.busy) do
        if get(component, "visibleGlobal") == true then
            return true
        end
    end
    return false
end

-- The prototyping board: sprite, rectangle and rejected flag of every module icon currently showing.
---@return table[] icons { spriteId, rect, rejected }
function Reader:BoardIcons()
    local icons = {}
    if self.handles == nil then
        return icons
    end
    for i = 1, 10 do
        local icon = self.handles.partIcons[i]
        local spriteId = icon and get(icon, "spriteID")
        local rect = rectOf(icon)
        if type(spriteId) == "number" and spriteId >= 0 and rect ~= nil then
            icons[#icons + 1] = { spriteId = spriteId, rect = rect, rejected = isRejected(self.handles, i) }
        end
    end
    return icons
end

-- The chosen modules beside the track (arranging) or on it (prototyping): sprite and rectangle of each visible icon.
---@return table[] sources { spriteId, rect }
function Reader:Sources()
    local sources = {}
    if self.handles == nil then
        return sources
    end
    for i = 1, 5 do
        local icon = self.handles.blueprintIcons[i]
        local spriteId = icon and get(icon, "spriteID")
        local rect = rectOf(icon)
        if type(spriteId) == "number" and spriteId >= 0 and rect ~= nil then
            sources[#sources + 1] = { spriteId = spriteId, rect = rect }
        end
    end
    return sources
end

return Reader
