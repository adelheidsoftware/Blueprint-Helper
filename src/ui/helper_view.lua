-- The helper view inside the client's Plugins window, built with PrettyUI.
--
-- The client hands over an emptied content layer on every ContentLayerReady, which fires on each resize step and
-- tab switch, so the view keeps almost no state of its own: Render rebuilds a SimpleView from the view model. The
-- only view state is whether the history is unfolded. main.lua debounces the mount to one build per burst of
-- events. The layout is designed for the default 203 x 230 layer and only lets the history grow with more room.

local Client = require("src/client")
local ConfirmDialog = require("src/ui/confirm_dialog")
local Theme = require("src/ui/theme")

local HelperView = {}
HelperView.__index = HelperView

local TEXT_HEIGHT = 18
local HISTORY_TILE = 16

-- Horizontal geometry of the SimpleView, in interface units. PADDING is PrettyUI's default, passed explicitly when
-- the view is created so these numbers and the view agree. SCROLLBAR is PrettyUI's 16 px bar plus its 2 px gap; it
-- appears as soon as the content is taller than the layer, which the unfolded history always causes, and it takes
-- its room from the content. The bar is reserved always so nothing moves or gets covered when it appears.
local PADDING = 14
local SCROLLBAR = 18

local ICON_SIZE = 24 -- PrettyUI's default sprite button
local ICON_GAP = 4 -- between the title and its icons, and between two icons
local HISTORY_TILE_GAP = 2
local HISTORY_LABEL_GAP = 2

local LEVEL_TOOLTIP = "XP by level: Poor 20%, Satisfactory 40%, Good 60%, Very good 70%, Excellent 80%, Perfect 100%."
local CONTRADICTION_TOOLTIP = "No hidden ranks fit every reading. Suggestions continue from the readings that agree "
    .. "most; the undo icon drops the newest one."

-- The states in which a blueprint is selected and the title row shows its name and the reset icon.
local PUZZLE_STATES = { prototyping = true, arranging = true, solved = true, contradiction = true }

---@param actions table { onReset = function(), onForget = function(), onRerender = function() }
---@param settings table the live settings table; compactHistory and showXp are read at render time
function HelperView.new(actions, settings)
    local self = setmetatable({}, HelperView)
    self.actions = actions
    self.settings = settings
    self.layer = nil
    self.view = nil
    self.stale = true -- the client emptied the layer, so the view's components are already gone
    self.historyOpen = false
    return self
end

-- A new content layer has been handed over; the previous view's components no longer exist.
function HelperView:SetLayer(layer)
    self.layer = layer
    self.view = nil
    self.stale = true
end

function HelperView:destroyView()
    if self.view ~= nil and not self.stale then
        pcall(function()
            self.view:Destroy()
        end)
    end
    self.view = nil
end

-- Builds the view for the given view model. Safe to call whenever something changed.
---@param vm table from Session:ViewModel()
function HelperView:Render(vm)
    if self.layer == nil then
        return
    end
    self:destroyView()
    local layer = self.layer
    local width, height = layer.width, layer.height
    if type(width) ~= "number" or width <= 0 then
        return
    end
    local ok, err = pcall(function()
        self.view = prettyui.SimpleView.new(layer, {
            width = width,
            height = height,
            layout = { paddingLeft = PADDING, paddingRight = PADDING },
        })
        self.stale = false
        self:build(self.view, vm, width)
    end)
    if not ok then
        log("Blueprint Helper: view failed to build: " .. tostring(err))
    end
end

-- Tooltip options. The content layer is small, so every tooltip opens below its control and is kept narrow enough
-- to fit there. The title-row icons use their own left-opening tips, see addTitleRow.
local function tip(text)
    if text == nil then
        return nil
    end
    return { text = text, placement = "below", maxWidth = 150 }
end

-- "INVENTION_ICON_SPIRIT_SPROCKET" -> "Spirit sprocket", from the sprite's name in the client; nil when unknown.
local function moduleName(spriteId)
    local name = Client.lookup(function()
        return id.Sprite.FromID(spriteId)
    end)
    if type(name) ~= "string" or name == "" then
        return nil
    end
    name = name:gsub("^INVENTION_ICON_", ""):gsub("^INVENT_", ""):gsub("_", " "):lower()
    return name:sub(1, 1):upper() .. name:sub(2)
end

-- Layout numbers for the room a row really has: the layer minus the padding and the scrollbar. At the default
-- 203 px layer that is 157 px. Five full tiles with their normal gap need 192, so the gap tightens first and the
-- tiles shrink after; above 300 px the tiles grow instead.
local function metrics(layerWidth)
    local usable = layerWidth - 2 * PADDING - SCROLLBAR
    local gap = Theme.TILE_GAP
    local tile = math.floor((usable - 4 * gap) / 5)
    if tile < Theme.TILE then
        gap = Theme.TILE_GAP_TIGHT
        tile = math.floor((usable - 4 * gap) / 5)
    end
    if usable >= 300 then
        tile = 44
    elseif tile > Theme.TILE then
        tile = Theme.TILE
    elseif tile < 20 then
        tile = 20
    end
    local historyTiles = 5 * HISTORY_TILE + 4 * HISTORY_TILE_GAP
    local historyLabel = usable - HISTORY_LABEL_GAP - historyTiles
    if historyLabel < 60 then
        historyLabel = 60
    end
    return { usable = usable, tile = tile, gap = gap, historyLabel = historyLabel }
end

-- Five module tiles with a label beneath each. The label is the slot number; the two slots of the suggested swap
-- read "[n]" in blue, and once the Perfect order is known a misplaced module reads "slot>target" in green. Plain
-- ASCII only, because the client's fonts carry no arrows.
local function addRow(view, sprites, marks, targets, m)
    local size, gap = m.tile, m.gap
    for slot = 1, 5 do
        local spriteId = sprites and sprites[slot] or -1
        if spriteId ~= nil and spriteId >= 0 then
            view:AddSprite(spriteId, {
                size = size,
                inline = slot > 1,
                columnGap = gap,
                tooltip = tip(moduleName(spriteId)),
            })
        else
            view:AddText({
                text = "-",
                width = size,
                height = size,
                inline = slot > 1,
                columnGap = gap,
                colour = Theme.MUTED,
            })
        end
    end
    for slot = 1, 5 do
        local marked = marks ~= nil and marks[slot]
        local target = targets ~= nil and targets[slot] or nil
        local text, colour
        if marked then
            text, colour = "[" .. slot .. "]", Theme.HIGHLIGHT
        elseif target ~= nil and target ~= slot then
            text, colour = slot .. ">" .. target, Theme.ANSWER
        else
            text, colour = tostring(slot), Theme.MUTED
        end
        view:AddText({
            text = text,
            width = size,
            height = 14,
            inline = slot > 1,
            columnGap = gap,
            marginTop = 2,
            colour = colour,
        })
    end
end

-- The readings so far, newest first: a level name each, with the arrangement as small tiles unless the history is
-- set to compact. Drawn straight into the view behind a toggle button, because PrettyUI's collapse sections cannot
-- hold sprites.
function HelperView:addHistory(view, vm, m)
    local count = vm.readingCount
    if count == 0 then
        return
    end
    local open = self.historyOpen
    local actions = self.actions
    view:AddSimpleButton(string.format("%s History (%d)", open and "-" or "+", count), function()
        self.historyOpen = not self.historyOpen
        actions.onRerender()
    end, { marginTop = 4 })
    if not open then
        return
    end
    local compact = self.settings.compactHistory
    for i = count, 1, -1 do
        local reading = vm.readings[i]
        if compact then
            view:AddText({ text = reading.levelName, colour = Theme.levelColour(reading.level), height = HISTORY_TILE })
        else
            -- The level name takes whatever the five 16 px tiles leave: 67 px at the default layer size, which is
            -- just enough for "Satisfactory". The rows run newest first and the toggle carries the count, so no
            -- reading number is shown.
            view:AddText({
                text = reading.levelName,
                colour = Theme.levelColour(reading.level),
                width = m.historyLabel,
                height = HISTORY_TILE,
                maxLines = 1,
                marginTop = 2,
                columnGap = HISTORY_LABEL_GAP,
            })
            for slot = 1, 5 do
                local spriteId = reading.row[slot]
                if spriteId ~= nil and spriteId >= 0 then
                    view:AddSprite(spriteId, {
                        size = HISTORY_TILE,
                        inline = true,
                        columnGap = HISTORY_TILE_GAP,
                        tooltip = tip(moduleName(spriteId)),
                    })
                end
            end
        end
    end
end

-- The title row: the blueprint's name, or the plugin's outside a puzzle, with the controls as icons at its right.
-- Reset (trash) in any puzzle state, and undo for "forget the last reading" in the contradiction state. The icons
-- flow after the title, which is cut to leave them room, because PrettyUI positions a tooltip from its control's
-- flow position. The tooltips open to the left so they fit between the icon and the layer's edge.
function HelperView:addTitleRow(view, vm, m)
    local inPuzzle = PUZZLE_STATES[vm.state] == true
    local title = inPuzzle and vm.blueprint or "Blueprint Helper"
    local icons = inPuzzle and (vm.state == "contradiction" and 2 or 1) or 0
    local titleWidth = m.usable - icons * (ICON_GAP + ICON_SIZE)
    if titleWidth < 40 then
        titleWidth = 40
    end
    view:AddText({
        text = title,
        colour = Theme.TITLE,
        width = titleWidth,
        height = TEXT_HEIGHT,
        maxLines = 1,
        columnGap = ICON_GAP,
    })
    if not inPuzzle then
        return
    end
    local actions = self.actions
    local function iconTip(text)
        return { text = text, placement = "left", maxWidth = titleWidth - 24 }
    end
    if vm.state == "contradiction" then
        view:AddSpriteButton("UNDO", function()
            actions.onForget()
        end, {
            inline = true,
            size = ICON_SIZE,
            columnGap = ICON_GAP,
            tooltip = iconTip("Forget the newest reading; use it when a level was mis-read."),
        })
    end
    view:AddSpriteButton("TRASH", function()
        ConfirmDialog.show({
            title = "Reset this puzzle?",
            body = "The readings for this blueprint are forgotten and the helper starts again from the next graded "
                .. "row.",
            onConfirm = actions.onReset,
        })
    end, {
        inline = true,
        size = ICON_SIZE,
        columnGap = ICON_GAP,
        tooltip = iconTip("Forget this blueprint's readings and start again."),
    })
end

-- The body for a puzzle in progress (arranging, solved or contradiction): the row, the level, the suggestion, the
-- progress line and the history.
function HelperView:addPuzzle(view, vm, m)
    local marks = nil
    if vm.suggestion ~= nil then
        marks = { [vm.suggestion.i] = true, [vm.suggestion.j] = true }
    end
    addRow(view, vm.row, marks, vm.targetSlots, m)

    if vm.level ~= nil then
        local levelText = vm.levelName
        if vm.xpPercent ~= nil and self.settings.showXp then
            levelText = levelText .. " | " .. vm.xpPercent .. "% XP"
        end
        view:AddText({
            text = levelText,
            colour = Theme.levelColour(vm.level),
            height = TEXT_HEIGHT,
            marginTop = 6,
            tooltip = tip(LEVEL_TOOLTIP),
        })
    elseif vm.pending then
        view:AddText({ text = "Analysing...", colour = Theme.MUTED, height = TEXT_HEIGHT, marginTop = 6 })
    else
        view:AddText({ text = "Place all five modules.", colour = Theme.MUTED, height = TEXT_HEIGHT, marginTop = 6 })
    end

    if vm.state == "contradiction" then
        view:AddText({
            text = "Readings disagree; one was mis-read.",
            colour = Theme.WARNING,
            height = TEXT_HEIGHT,
            tooltip = tip(CONTRADICTION_TOOLTIP),
        })
    end
    -- The solved state shows no suggestion, and the level line already says Perfect.
    if vm.suggestion ~= nil then
        view:AddText({ text = vm.suggestion.text, height = TEXT_HEIGHT })
    end

    if vm.state ~= "solved" and vm.readingCount > 0 then
        -- The reading count is on the history toggle. Once one permutation is left the line turns green and says
        -- so; the tile labels carry the target slots.
        local known = vm.permutationsLeft == 1
        local progress = known and "Solution known" or string.format("%d permutations left", vm.permutationsLeft)
        if vm.suggestion ~= nil and vm.suggestion.bound ~= nil then
            local bound = vm.suggestion.bound
            progress = progress .. string.format(" | %d %s max", bound, bound == 1 and "swap" or "swaps")
        end
        view:AddText({
            text = progress,
            colour = known and Theme.ANSWER or Theme.MUTED,
            height = TEXT_HEIGHT,
            tooltip = known and tip("Each number under a tile shows where that module goes.") or nil,
        })
    end

    self:addHistory(view, vm, m)
end

function HelperView:build(view, vm, width)
    local m = metrics(width)
    self:addTitleRow(view, vm, m)

    if vm.state == "idle" then
        view:AddText({ text = "Open Discovery at an inventor's workbench.", marginTop = 6 })
        view:AddText({
            text = "Pick a blueprint, place five modules, then follow the swaps shown here.",
            colour = Theme.MUTED,
        })
    elseif vm.state == "unreadable" then
        view:AddText({
            text = "Discovery is open but its components could not be read. The plugin may need an update.",
            colour = Theme.WARNING,
            marginTop = 6,
        })
    elseif vm.state == "choosing" then
        view:AddText({ text = "Choosing a blueprint.", marginTop = 6 })
        local kept = vm.kept
        if kept == nil then
            view:AddText({ text = "Pick one from the list on the left.", colour = Theme.MUTED })
        elseif kept.answer ~= nil then
            view:AddText({
                text = string.format("%s: %s", kept.blueprint, kept.solved and "solved." or "solution found."),
                colour = Theme.ANSWER,
                height = TEXT_HEIGHT,
            })
            addRow(view, kept.answer, nil, nil, m)
        else
            view:AddText({
                text = string.format("%s: %d readings. Select it again to continue.", kept.blueprint,
                    kept.readingCount),
                colour = Theme.MUTED,
            })
        end
    elseif vm.state == "prototyping" then
        view:AddText({ text = "Choosing modules.", marginTop = 6 })
        local p = vm.prototyping
        if vm.answer ~= nil then
            -- The game shows the board again for a blueprint already worked out while the plugin was enabled.
            view:AddText({
                text = "Solution known from before: the five numbered modules, in this arrangement.",
                colour = Theme.ANSWER,
            })
            addRow(view, vm.answer, nil, nil, m)
        elseif p.confirmedCount > 0 or p.rejectedCount > 0 then
            view:AddText({
                text = string.format("%d of 5 confirmed, %d rejected.", p.confirmedCount, p.rejectedCount),
                colour = Theme.ANSWER,
            })
            if p.confirmedCount < 5 then
                view:AddText({
                    text = "Confirmed modules are outlined green in Discovery; fill the rest from the plain ones.",
                    colour = Theme.MUTED,
                })
            end
        else
            view:AddText({ text = "Place any five and Prototype; whatever stays is correct.", colour = Theme.MUTED })
        end
    else
        self:addPuzzle(view, vm, m)
    end
end

function HelperView:Destroy()
    self:destroyView()
    self.layer = nil
end

return HelperView
