-- The six optimisation levels of a Discovery arrangement, numbered 0 (Perfect) to 5 (Poor). The number is also
-- what the scoring table produces and the digit used in the opening table's keys.
--
-- The game reports the level in one label, for example:
--   <col=ffff00>Optimisation: Good<br>You will gain : <col=ffffff>12269</col> + <col=ffff00>24539</col> extra XP.
-- The words depend on the client language and Good and Very good share a colour, but (base + extra) / base is
-- 1, 2, 3, 3.5, 4 or 5 from Poor to Perfect in every language, so the level is read from the two numbers.

local Levels = {}

Levels.PERFECT = 0

-- ratio: (base + extra) / base as the game shows it. xpFraction: share of the Perfect XP. colour: the game's text
-- colour for the level.
Levels.ALL = {
    [0] = { ratio = 5, xpFraction = 1.0, colour = 0x00FF00 },
    [1] = { ratio = 4, xpFraction = 0.8, colour = 0xFFFFFF },
    [2] = { ratio = 3.5, xpFraction = 0.7, colour = 0xFFFF00 },
    [3] = { ratio = 3, xpFraction = 0.6, colour = 0xFFFF00 },
    [4] = { ratio = 2, xpFraction = 0.4, colour = 0xFF7F00 },
    [5] = { ratio = 1, xpFraction = 0.2, colour = 0xFF0000 },
}

-- Display names. Only the display is English; nothing else in the plugin depends on the client language.
local NAMES = { [0] = "Perfect", "Excellent", "Very good", "Good", "Satisfactory", "Poor" }

---@param level integer 0..5
---@return string
function Levels.name(level)
    return NAMES[level]
end

-- The penalty (sum over slots of |module rank - slot rank|) is always even; 10 and 12 are both Poor.
---@param penalty integer
---@return integer level
function Levels.fromPenalty(penalty)
    if penalty >= 10 then
        return 5
    end
    return penalty // 2
end

-- The two XP numbers of the score label, or nil while it shows a pending or placeholder text.
local function xpNumbers(label)
    if type(label) ~= "string" then
        return nil
    end
    local plain = label:gsub("<[^>]*>", "") -- strip the colour and line-break tags; their hex digits are not XP
    local base, extra = plain:match("(%d+)%s*%+%s*(%d+)")
    if base == nil then
        return nil
    end
    return tonumber(base), tonumber(extra)
end

---@param label string? raw content of the game's score label
---@return integer? level nil when the label carries no result
function Levels.parse(label)
    local base, extra = xpNumbers(label)
    if base == nil or base <= 0 then
        return nil
    end
    local ratio = (base + extra) / base
    local best, bestDiff = nil, nil
    for level = 0, 5 do
        local diff = math.abs(ratio - Levels.ALL[level].ratio)
        if bestDiff == nil or diff < bestDiff then
            best, bestDiff = level, diff
        end
    end
    if bestDiff > 0.1 then
        return nil
    end
    return best
end

---@param label string?
---@return boolean pending true when the label has no XP result yet ("Analysing...", a placeholder, or empty)
function Levels.isPending(label)
    return xpNumbers(label) == nil
end

return Levels
