-- One Discovery puzzle from the player's point of view. Consumes snapshot tables from the reader and exposes a view
-- model table for the UI; nothing in here touches the client API.
--
-- States: idle (Discovery closed), choosing (no blueprint selected), prototyping (picking modules, Prototype
-- confirming them), arranging (the track, readings flowing), solved (Perfect read), contradiction (no seed fits
-- every reading) and unreadable (open, but components missing). Every poll's snapshot decides the state afresh,
-- in this order:
--
--   snapshot                        state
--   nil (Discovery closed)          idle; the puzzle stays in memory
--   components missing              unreadable
--   the track showing               arranging, solved or contradiction, as the readings say (see arrangeState)
--   no blueprint selected           choosing; the kept puzzle stays untouched
--   the board showing               prototyping; another blueprint parks the current puzzle and restores its own
--
-- While arranging, Reset and ForgetLastReading change the readings and the state follows them the same way.
--
-- Every blueprint the player touches keeps its own readings, prototyping progress and solution for as long as the
-- plugin is enabled, so switching between blueprints and back loses nothing. Nothing is persisted.

local Permutations = require("src/core/permutations")
local Levels = require("src/core/levels")
local Seeds = require("src/core/seeds")
local Deduce = require("src/core/deduce")
local Commit = require("src/core/commit")
local Prototyping = require("src/core/prototyping")
local Row = require("src/core/row")

local Session = {}
Session.__index = Session

-- The three states of the arranging stage, the only ones Reset and ForgetLastReading move between.
local ARRANGE_STATES = { arranging = true, solved = true, contradiction = true }

---@param options table? { mode = "guide" | "logbook" }
function Session.new(options)
    local self = setmetatable({}, Session)
    self.mode = (options and options.mode) or "guide"
    self.commit = Commit.new()
    self.state = "idle"
    self.blueprint = nil
    self.snapshot = nil
    self.puzzles = {} -- blueprint name -> stored puzzle fields, for every blueprint touched while enabled
    self:clearPuzzle()
    return self
end

-- The fields that make up one blueprint's puzzle; moved as a set between `self` and `self.puzzles`.
local PUZZLE_FIELDS = { "identity", "moduleOf", "spriteOf", "readings", "visited", "contradiction", "answers",
    "answer", "suggestion", "onPath", "expected", "prototyping" }

function Session:storeCurrent()
    local stored = {}
    for _, field in ipairs(PUZZLE_FIELDS) do
        stored[field] = self[field]
    end
    return stored
end

function Session:restore(stored)
    for _, field in ipairs(PUZZLE_FIELDS) do
        self[field] = stored[field]
    end
end

-- The player selected another blueprint: park the current puzzle and bring back that blueprint's, if it has one.
function Session:switchTo(blueprint)
    if self.blueprint ~= nil and (#self.readings > 0 or self.prototyping:HasProgress()) then
        self.puzzles[self.blueprint] = self:storeCurrent()
    end
    self.blueprint = blueprint
    local stored = blueprint ~= nil and self.puzzles[blueprint] or nil
    if stored ~= nil then
        self:restore(stored)
        self.commit:Reset()
        self:deduce()
    else
        self:clearPuzzle()
    end
end

function Session:clearPuzzle()
    self.identity = nil -- blueprint name plus the sorted module sprite IDs
    self.moduleOf = {} -- sprite ID -> module index 1..5, fixed by the first complete row
    self.spriteOf = {} -- module index -> sprite ID
    self.readings = {} -- { arrangement = index, level, row = sprite IDs }
    self.visited = {} -- arrangement index -> true, for every arrangement graded this puzzle
    self.contradiction = false
    self.answers = 0 -- distinct Perfect arrangements the survivors still allow
    self.answer = nil -- arrangement index once exactly one fits
    self.suggestion = nil -- { i, j, bound? }
    self.onPath = true -- the player has followed every suggestion so far
    self.expected = nil -- the arrangement the last suggestion leads to
    self.prototyping = Prototyping.new() -- which modules a Prototype confirmed or rejected
    self.commit:Reset()
end

function Session:SetMode(mode)
    self.mode = mode
end

function Session:lastIsPerfect()
    local last = self.readings[#self.readings]
    return last ~= nil and last.level == Levels.PERFECT
end

-- The arranging-stage state the readings imply. The game's own Perfect ends the puzzle whatever else was read;
-- short of that, readings that no seed can explain outrank a puzzle in progress.
---@return string state "solved", "contradiction" or "arranging"
function Session:arrangeState()
    if self:lastIsPerfect() then
        return "solved"
    end
    if self.contradiction then
        return "contradiction"
    end
    return "arranging"
end

-- The player asked to start over on the same blueprint; its stored copy goes too.
function Session:Reset()
    if self.blueprint ~= nil then
        self.puzzles[self.blueprint] = nil
    end
    self:clearPuzzle()
    if ARRANGE_STATES[self.state] then
        self.state = self:arrangeState()
    end
end

-- Forgets every remembered blueprint, the current one included.
function Session:ForgetAll()
    self.puzzles = {}
    self:Reset()
end

-- Drops the most recent reading; offered after a contradiction.
function Session:ForgetLastReading()
    local n = #self.readings
    if n == 0 then
        return
    end
    local last = self.readings[n]
    self.readings[n] = nil
    local stillVisited = false
    for _, reading in ipairs(self.readings) do
        if reading.arrangement == last.arrangement then
            stillVisited = true
        end
    end
    if not stillVisited then
        self.visited[last.arrangement] = nil
    end
    self.onPath = false
    self:deduce()
    if ARRANGE_STATES[self.state] then
        self.state = self:arrangeState()
    end
end

local function identityOf(blueprint, row)
    local sprites = { row[1], row[2], row[3], row[4], row[5] }
    table.sort(sprites)
    return tostring(blueprint) .. "|" .. table.concat(sprites, ",")
end

-- Arrangement index of a complete row. The first row of a puzzle fixes which sprite is module 1..5. nil when a
-- sprite is not one of this puzzle's modules.
function Session:arrangementOf(row)
    if next(self.moduleOf) == nil then
        for slot = 1, 5 do
            self.moduleOf[row[slot]] = slot
            self.spriteOf[slot] = row[slot]
        end
    end
    local arrangement = {}
    for slot = 1, 5 do
        local module = self.moduleOf[row[slot]]
        if module == nil then
            return nil
        end
        arrangement[slot] = module
    end
    return Permutations.indexOf(arrangement)
end

-- Recomputes survivors and the suggestion from the readings.
function Session:deduce()
    if #self.readings == 0 then
        self.contradiction = false
        self.answers = 0
        self.answer = nil
        self.suggestion = nil
        self.expected = nil
        return
    end
    local survivors, contradiction = Seeds.consistent(self.readings)
    self.contradiction = contradiction
    self.answers = Seeds.distinctAnswers(survivors)
    self.answer = self.answers == 1 and Seeds.answer[survivors[1]] or nil

    local current = self.readings[#self.readings].arrangement
    local levels = {}
    for i, reading in ipairs(self.readings) do
        levels[i] = reading.level
    end
    local move = Deduce.nextSwap({
        current = current,
        survivors = survivors,
        levelKey = Deduce.levelKey(levels),
        visited = self.visited,
        onPath = self.onPath and not contradiction,
    })
    self.suggestion = move
    self.expected = move and Permutations.swap(current, move.i, move.j) or nil
end

function Session:addReading(reading)
    local arrangement = self:arrangementOf(reading.row)
    if arrangement == nil then
        return false
    end
    local last = self.readings[#self.readings]
    if last ~= nil and last.arrangement == arrangement and last.level == reading.level then
        return false
    end
    if self.expected ~= nil and arrangement ~= self.expected then
        self.onPath = false
    end
    self.readings[#self.readings + 1] = { arrangement = arrangement, level = reading.level, row = reading.row }
    self.visited[arrangement] = true
    self:deduce()
    return true
end

-- The parts of the session the view model depends on, as one string, to tell whether an ingest changed anything.
local function describe(session)
    local parts = { session.state, #session.readings, tostring(session.blueprint), tostring(session.contradiction),
        session.prototyping.confirmedCount, session.prototyping.rejectedCount }
    return table.concat(parts, "|")
end

local function describeSnapshot(snapshot)
    if snapshot == nil then
        return ""
    end
    return table.concat(snapshot.row, ",") .. "|" .. tostring(snapshot.scoreText)
end

-- Whether a blueprint is selected. The instructions label is empty until one is, in every language; when that
-- label could not be read, a module offered on the board means the same thing.
local function hasProject(snapshot)
    if type(snapshot.instructions) == "string" then
        return snapshot.instructions ~= ""
    end
    for _, module in ipairs(snapshot.boardState or {}) do
        if module.spriteId ~= nil and module.spriteId >= 0 then
            return true
        end
    end
    return false
end

-- Feeds one snapshot (nil when Discovery is closed). Returns true when the view model changed.
---@param snapshot table? from the reader
---@param tick integer logic tick
---@return boolean changed
function Session:Ingest(snapshot, tick)
    local before = describe(self) .. describeSnapshot(self.snapshot)
    self.snapshot = snapshot

    if snapshot == nil then
        -- Closed. The puzzle stays in memory so reopening the same blueprint resumes it.
        self.state = "idle"
        self.commit:Reset()
    elseif not snapshot.valid then
        self.state = "unreadable"
    elseif snapshot.stage == "arrange" then
        self:ingestArrange(snapshot, tick)
    elseif not hasProject(snapshot) then
        -- No blueprint selected. The kept puzzle stays untouched, so selecting the same blueprint again resumes it.
        self.state = "choosing"
    else
        if self.blueprint ~= snapshot.blueprint then
            self:switchTo(snapshot.blueprint)
        end
        self.state = "prototyping"
        self.prototyping:Ingest(snapshot.boardState)
    end

    return before ~= describe(self) .. describeSnapshot(snapshot)
end

-- The arranging stage. Takes a reading when the commit logic pairs a grade with the row, then sets the state from
-- the readings, so a blueprint restored with a Perfect already read shows as solved straight away.
function Session:ingestArrange(snapshot, tick)
    local row = snapshot.row
    if self.blueprint ~= snapshot.blueprint then
        self:switchTo(snapshot.blueprint)
    end
    if Row.complete(row) then
        local identity = identityOf(snapshot.blueprint, row)
        if self.identity ~= nil and self.identity ~= identity then
            -- Same blueprint, different modules: a fresh attempt.
            self:clearPuzzle()
        end
        self.identity = identity
        self.prototyping:ConfirmAll(row)
    end
    local reading = self.commit:Observe(tick, row, snapshot.scoreText)
    if reading ~= nil then
        self:addReading(reading)
    end
    self.state = self:arrangeState()
end

-- The sprite IDs of an arrangement, for display.
function Session:rowOf(arrangement)
    local sprites = {}
    local modules = Permutations.list[arrangement]
    for slot = 1, 5 do
        sprites[slot] = self.spriteOf[modules[slot]]
    end
    return sprites
end

local function swapText(i, j)
    if i > j then
        i, j = j, i
    end
    return string.format("Swap %d and %d", i, j)
end

-- Everything the UI shows, as plain data.
function Session:ViewModel()
    local last = self.readings[#self.readings]
    local vm = {
        state = self.state,
        blueprint = self.blueprint,
        row = self.snapshot and self.snapshot.row or {},
        level = last and last.level or nil,
        levelName = last and Levels.name(last.level) or nil,
        xpPercent = last and math.floor(Levels.ALL[last.level].xpFraction * 100 + 0.5) or nil,
        readings = {},
        readingCount = #self.readings,
        permutationsLeft = self.answers,
        pending = self.snapshot ~= nil and self.snapshot.scoreText ~= nil and Levels.isPending(self.snapshot.scoreText),
    }
    for i, reading in ipairs(self.readings) do
        vm.readings[i] = { level = reading.level, levelName = Levels.name(reading.level), row = reading.row }
    end
    if self.answer ~= nil then
        vm.answer = self:rowOf(self.answer)
        -- Which slot each module belongs in, by sprite, for marking modules that are not on the track yet.
        vm.targetBySprite = {}
        for target = 1, 5 do
            vm.targetBySprite[vm.answer[target]] = target
        end
        -- Where each module on the track belongs in the Perfect order, so the player can place all of them at once.
        if Row.complete(vm.row) then
            vm.targetSlots = {}
            for slot = 1, 5 do
                vm.targetSlots[slot] = vm.targetBySprite[vm.row[slot]]
            end
        end
    end
    -- The puzzle kept in memory, shown as the last result while no blueprint is selected.
    if #self.readings > 0 and self.blueprint ~= nil then
        vm.kept = {
            blueprint = self.blueprint,
            readingCount = #self.readings,
            solved = self:lastIsPerfect(),
            answer = vm.answer,
        }
    end
    if self.state == "prototyping" then
        vm.prototyping = self.prototyping:View()
    end
    if self.mode == "guide" and self.suggestion ~= nil and self.state ~= "solved" and self.state ~= "idle" then
        vm.suggestion = {
            i = self.suggestion.i,
            j = self.suggestion.j,
            text = swapText(self.suggestion.i, self.suggestion.j),
            bound = self.suggestion.bound,
        }
    end
    return vm
end

return Session
