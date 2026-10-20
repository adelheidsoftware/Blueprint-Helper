-- When does a polled (row, label) pair become a reading?
--
-- When the row changes, the score label shows a pending text ("Analysing...") on the same tick and the result one
-- server tick later, and the server grades only the arrangement on the track when its tick lands. So a result that
-- follows a pending text belongs to the latest row, which also covers a swap that leaves the level unchanged. A
-- settle timer backs this up for the case where a poll missed the pending text.

local Levels = require("src/core/levels")
local Row = require("src/core/row")

local Commit = {}
Commit.__index = Commit

Commit.SETTLE_TICKS = 60 -- 1.2 s, two server ticks: trust the label without a pending text after this long

local function sameRow(a, b)
    if a == nil or b == nil then
        return false
    end
    for i = 1, 5 do
        if a[i] ~= b[i] then
            return false
        end
    end
    return true
end

local function copy(row)
    return { row[1], row[2], row[3], row[4], row[5] }
end

function Commit.new()
    local self = setmetatable({}, Commit)
    self:Reset()
    return self
end

-- Forget everything, for a new puzzle.
function Commit:Reset()
    self.lastRow = nil -- last complete row seen
    self.pendingRow = nil -- complete row whose grade has not been committed yet
    self.pendingSince = nil
    self.sawPending = false -- the label showed a pending text since pendingRow appeared
    self.synced = false -- a first reading was taken, so later results need a pending text or the timer
end

-- One poll. Returns a reading { row, level } when a grade can be paired with a row, else nil.
---@param tick integer logic tick
---@param row integer[] five sprite IDs, -1 for an empty slot
---@param scoreText string? raw content of the score label
---@return table? reading
function Commit:Observe(tick, row, scoreText)
    if not Row.complete(row) then
        -- The track is being filled or emptied; no grade can refer to this row.
        self.lastRow = nil
        self.pendingRow = nil
        self.sawPending = false
        return nil
    end
    if not sameRow(row, self.lastRow) then
        self.lastRow = copy(row)
        self.pendingRow = self.lastRow
        self.pendingSince = tick
        self.sawPending = false
    end
    if self.pendingRow == nil then
        return nil
    end
    local level = Levels.parse(scoreText)
    if level == nil then
        self.sawPending = true
        return nil
    end
    local trusted = self.sawPending or not self.synced or (tick - self.pendingSince) >= Commit.SETTLE_TICKS
    if not trusted then
        return nil
    end
    local reading = { row = self.pendingRow, level = level }
    self.pendingRow = nil
    self.sawPending = false
    self.synced = true
    return reading
end

return Commit
