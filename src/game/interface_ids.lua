-- The Discovery interface's components, by name. The names are the client's own for this interface
-- (id.Component.INVENT_DISCOVERY__*), so they survive an update that renumbers it. This is the only place that
-- knows them; the reader resolves them to handles.

local Client = require("src/client")

local InterfaceIds = {}

InterfaceIds.INTERFACE = "INVENT_DISCOVERY"

-- Component names, without the INVENT_DISCOVERY__ prefix, and the ui.ComponentType name each handle must have.
InterfaceIds.COMPONENTS = {
    -- The five track slots of the arranging stage; spriteID is the module, -1 when the slot is empty.
    trackIcons = { "TRACK_ICON_0", "TRACK_ICON_1", "TRACK_ICON_2", "TRACK_ICON_3", "TRACK_ICON_4" },
    trackIconType = "SPRITE",
    -- The ten board positions of the prototyping stage. A selected module's icon is hidden while the module sits on
    -- the track.
    partIcons = {
        "PART_ICON_0", "PART_ICON_1", "PART_ICON_2", "PART_ICON_3", "PART_ICON_4",
        "PART_ICON_5", "PART_ICON_6", "PART_ICON_7", "PART_ICON_8", "PART_ICON_9",
    },
    partIconType = "SPRITE",
    -- The red cross the game draws over a rejected module after Prototype.
    partRejected = {
        "PART_SELECTED_0", "PART_SELECTED_1", "PART_SELECTED_2", "PART_SELECTED_3", "PART_SELECTED_4",
        "PART_SELECTED_5", "PART_SELECTED_6", "PART_SELECTED_7", "PART_SELECTED_8", "PART_SELECTED_9",
    },
    partRejectedType = "SPRITE",
    -- The five chosen modules waiting beside the track while arranging, before the player places them.
    blueprintIcons = {
        "BLUEPRINT_ICON_0", "BLUEPRINT_ICON_1", "BLUEPRINT_ICON_2", "BLUEPRINT_ICON_3", "BLUEPRINT_ICON_4",
    },
    blueprintIconType = "SPRITE",
    -- One label carries the level and both XP numbers.
    scoreText = "TRACK_SCORE_TEXT",
    scoreTextType = "LABEL",
    -- The blueprint's name.
    subjectTitle = "SUBJECT_TITLE",
    subjectTitleType = "LABEL",
    -- Stage instructions. Empty until a blueprint is selected, which is how "choosing a blueprint" is recognised.
    instructionsText = "INSTRUCTIONS_TEXT",
    instructionsTextType = "LABEL",
    -- Visible while prototyping and while arranging respectively; tells the stage apart without reading any text.
    partsLayer = "WORKBENCH_PARTS_LAYER",
    trackLayer = "WORKBENCH_TRACK_LAYER",
    -- The whole window. An interface can stay loaded while hidden, so "open" means loaded and this is showing.
    rootLayer = "ROOT_LAYER",
    layerType = "LAYER",
    -- Things the game draws over the window: the Prototype animation and its confirmation dialogs. The plugin's
    -- outlines hide while any of them is visible.
    busy = { "DIALOG_CONTAINER", "WORKBENCH_OVERLAY", "LIGHTBULB_MODEL", "LIGHTBULB_CRACKED_MODEL" },
}

---@param name string component name without the interface prefix
---@return integer? combined component ID, nil when the client does not know the name
function InterfaceIds.component(name)
    return Client.lookup(function()
        return id.Component[InterfaceIds.INTERFACE .. "__" .. name]
    end)
end

---@return integer? interface ID, nil when the client does not know the name
function InterfaceIds.interface()
    return Client.lookup(function()
        return id.Interface[InterfaceIds.INTERFACE]
    end)
end

return InterfaceIds
