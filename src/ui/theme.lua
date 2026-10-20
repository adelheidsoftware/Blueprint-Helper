-- Colours and sizes the UI uses, in one place. Colours are RGBA, as PrettyUI and the client take them.

local Levels = require("src/core/levels")

local Theme = {}

Theme.MUTED = 0x9C9185FF
Theme.TITLE = 0xF0BE79FF -- the game's gold title colour
Theme.WARNING = 0xFF7F7FFF

-- Two hues carry meaning everywhere: blue for "swap this pair", green for "solution" and "confirmed". They are the
-- same in the Plugins window and on the Discovery window, and the green is the game's own Perfect green.
Theme.HIGHLIGHT = 0x6FA8FFFF
Theme.ANSWER = 0x00FF00FF
Theme.OVERLAY_SWAP = Theme.HIGHLIGHT
Theme.OVERLAY_ANSWER = Theme.ANSWER
Theme.OVERLAY_TEXT = 0x141414FF -- dark numbers on a tab filled with the mark's own colour
Theme.OVERLAY_THICKNESS = 3

Theme.TILE = 32 -- module tile size in the view
Theme.TILE_GAP = 8
Theme.TILE_GAP_TIGHT = 4 -- when five full tiles would not fit the row with the normal gap

-- The level colours are the game's own, with full alpha.
---@param level integer 0..5
---@return integer rgba
function Theme.levelColour(level)
    return (Levels.ALL[level].colour << 8) | 0xFF
end

return Theme
