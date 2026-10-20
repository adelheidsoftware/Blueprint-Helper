-- Marks drawn over the Discovery window: outlines around slots and modules, with a slot number where one applies.
--
-- Everything lives on the plugin build layer, is clickthrough and disabled, and never touches a game component;
-- the overlay only reads the positions the reader hands it. Three uses:
--   - blue outlines on the two slots of the suggested swap;
--   - once the Perfect order is known, a green outline with the target slot number on every module that is not in
--     its slot yet, on the track and beside it;
--   - while prototyping, a green outline on every module confirmed by a Prototype.

local Client = require("src/client")
local Theme = require("src/ui/theme")

local Overlay = {}
Overlay.__index = Overlay

local LABEL_WIDTH, LABEL_HEIGHT = 18, 16

function Overlay.new()
    local self = setmetatable({}, Overlay)
    self.root = Client.pluginLayer()
    -- Without the font no numbers are drawn and the marks are outlines alone.
    self.font = Client.lookup(function()
        return id.Font.MUSEO_SANS_13PT_BOLD
    end)
    self.boxes = {} -- key -> outline rectangle
    self.badges = {} -- key -> filled rectangle behind the number
    self.labels = {} -- key -> the number
    return self
end

-- The outline for `key`, created on first use, in the given colour.
function Overlay:box(key, colour)
    local box = self.boxes[key]
    if box == nil and self.root ~= nil then
        box = ui.Rectangle.new(self.root)
        if box ~= nil then
            box.fill = false
            box.outlineThickness = Theme.OVERLAY_THICKNESS
            box.clickthrough = true
            box.enabled = false
            box.hidden = true
            self.boxes[key] = box
        end
    end
    if box ~= nil then
        box.rgba = colour
    end
    return box
end

-- The number for `key` on a small tab filled with the mark's own colour, created on first use. Tab first, then the
-- text, so the text draws on top. nil while the font is unavailable; mark() then shows the outline alone.
function Overlay:label(key, colour)
    local label = self.labels[key]
    if label == nil and self.root ~= nil and self.font ~= nil then
        local badge = ui.Rectangle.new(self.root)
        if badge ~= nil then
            badge.fill = true
            badge.clickthrough = true
            badge.enabled = false
            badge.hidden = true
            self.badges[key] = badge
        end
        label = ui.Text.new(self.root)
        if label ~= nil then
            label.font = self.font
            label.isShadowed = false
            label.clickthrough = true
            label.enabled = false
            label.hidden = true
            label:SetSize(LABEL_WIDTH, LABEL_HEIGHT)
            label:AlignTo(ui.AlignMode.CENTRE)
            self.labels[key] = label
        end
    end
    local badge = self.badges[key]
    if badge ~= nil then
        badge.rgba = colour
    end
    if label ~= nil then
        label.rgba = Theme.OVERLAY_TEXT
    end
    return label
end

local function hideAll(components)
    for _, component in pairs(components) do
        pcall(function()
            component.hidden = true
        end)
    end
end

function Overlay:Hide()
    hideAll(self.boxes)
    hideAll(self.badges)
    hideAll(self.labels)
end

local function place(component, x, y, width, height)
    component:SetPos(math.floor(x), math.floor(y))
    component:SetSize(math.floor(width), math.floor(height))
    component.hidden = false
end

local function hide(component)
    if component ~= nil then
        component.hidden = true
    end
end

-- Shows or hides one outline-plus-number pair. `text` nil means outline only; `rect` nil hides both. Positions are
-- global; the plugin layer sits at the global origin, so they are used as they are.
function Overlay:mark(key, rect, colour, text)
    local box = self:box(key, colour)
    local label = self:label(key, colour)
    local badge = self.badges[key]
    if rect ~= nil and box ~= nil then
        place(box, rect.x, rect.y, rect.width, rect.height)
    else
        hide(box)
        text = nil
    end
    if text ~= nil and label ~= nil then
        -- Tucked into the outline's top-right corner, so it reads as part of the outline.
        local x, y = rect.x + rect.width - LABEL_WIDTH - 1, rect.y + 1
        label.content = text
        if badge ~= nil then
            place(badge, x, y, LABEL_WIDTH, LABEL_HEIGHT)
        end
        place(label, x, y, LABEL_WIDTH, LABEL_HEIGHT)
    else
        hide(badge)
        hide(label)
    end
end

---@param vm table view model
---@param rects table[] slot rectangles from the reader, indexed by slot
---@param sources table[] chosen modules beside or on the track, { spriteId, rect }
---@param boardIcons table[] prototyping board modules, { spriteId, rect, rejected }
---@param enabled boolean the overlay setting, and not while the game draws over the window
function Overlay:Render(vm, rects, sources, boardIcons, enabled)
    local inPuzzle = vm.state == "arranging" or vm.state == "contradiction"
    local inPrototyping = vm.state == "prototyping" and vm.prototyping ~= nil and vm.prototyping.confirmedCount > 0
    if not enabled or not (inPuzzle or inPrototyping) or self.root == nil then
        self:Hide()
        return
    end
    if inPrototyping then
        self:renderPrototyping(vm, sources, boardIcons)
        return
    end
    for i = 1, 10 do
        self:mark("board" .. i, nil, Theme.OVERLAY_ANSWER, nil)
    end
    self:renderSlots(vm, rects)
    self:renderSources(vm, sources)
end

local function targetText(targets, spriteId)
    local target = targets and targets[spriteId] or nil
    return target and tostring(target) or nil
end

-- Prototyping: confirmed modules get a green outline wherever they are, on the board or on the track. Rejected modules
-- already carry the game's own cross. A slot number is added when a kept puzzle already knows the order.
function Overlay:renderPrototyping(vm, sources, boardIcons)
    local confirmed = vm.prototyping.confirmed
    local targets = vm.targetBySprite
    for i = 1, 10 do
        local icon = boardIcons[i]
        if icon ~= nil and not icon.rejected and confirmed[icon.spriteId] then
            self:mark("board" .. i, icon.rect, Theme.OVERLAY_ANSWER, targetText(targets, icon.spriteId))
        else
            self:mark("board" .. i, nil, Theme.OVERLAY_ANSWER, nil)
        end
    end
    for i = 1, 5 do
        local source = sources[i]
        if source ~= nil and confirmed[source.spriteId] then
            self:mark("source" .. i, source.rect, Theme.OVERLAY_ANSWER, targetText(targets, source.spriteId))
        else
            self:mark("source" .. i, nil, Theme.OVERLAY_ANSWER, nil)
        end
        self:mark("slot" .. i, nil, Theme.OVERLAY_SWAP, nil)
    end
end

-- Modules still waiting beside the track: once the order is known, each shows the slot it belongs in.
function Overlay:renderSources(vm, sources)
    local targets = vm.targetBySprite
    for i = 1, 5 do
        local source = sources[i]
        local text = source and targetText(targets, source.spriteId) or nil
        self:mark("source" .. i, text and source.rect or nil, Theme.OVERLAY_ANSWER, text)
    end
end

-- The track: the suggested swap in blue, and misplaced modules in green with their target slot once the order is
-- known. A slot that is part of the swap keeps the blue even when it is also misplaced.
function Overlay:renderSlots(vm, rects)
    local swapSlots = {}
    if vm.suggestion ~= nil then
        swapSlots[vm.suggestion.i] = true
        swapSlots[vm.suggestion.j] = true
    end
    local targets = vm.targetSlots
    for slot = 1, 5 do
        local target = targets and targets[slot] or nil
        local misplaced = target ~= nil and target ~= slot
        local key = "slot" .. slot
        if swapSlots[slot] then
            self:mark(key, rects[slot], Theme.OVERLAY_SWAP, misplaced and tostring(target) or nil)
        elseif misplaced then
            self:mark(key, rects[slot], Theme.OVERLAY_ANSWER, tostring(target))
        else
            self:mark(key, nil, Theme.OVERLAY_SWAP, nil)
        end
    end
end

local function destroyAll(components)
    for _, component in pairs(components) do
        pcall(function()
            component:Destroy()
        end)
    end
end

function Overlay:Destroy()
    destroyAll(self.boxes)
    destroyAll(self.badges)
    destroyAll(self.labels)
    self.boxes = {}
    self.badges = {}
    self.labels = {}
end

return Overlay
