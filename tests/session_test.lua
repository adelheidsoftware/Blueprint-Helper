-- Tests for src/core/session.lua with scripted snapshots, following the sequences the client produces.
local T = require("harness")
local Session = require("src/core/session")
local Permutations = require("src/core/permutations")
local Seeds = require("src/core/seeds")

local L = T.LEVEL

local function label(extra)
    return string.format("<col=ffff00>Optimisation: X<br>You will gain : <col=ffffff>12269</col> + <col=ffff00>%d</col> extra XP.", extra)
end
local LABEL = {
    [L.POOR] = label(0),
    [L.SATISFACTORY] = label(12270),
    [L.GOOD] = label(24539),
    [L.VERY_GOOD] = label(30674),
    [L.EXCELLENT] = label(36809),
    [L.PERFECT] = label(49078),
}
local ANALYSING = "Analysing..."

local MODULES = { 25074, 25081, 26156, 26158, 26214 }

local function snapshot(fields)
    local s = { valid = true, blueprint = "Bandos components", stage = "arrange", row = {}, boardState = {}, scoreText = "",
        instructions = "Arrange the modules to optimise the experience gain of this discovery." }
    for k, v in pairs(fields) do
        if v ~= nil then
            s[k] = v
        end
    end
    if s.stage == "prototype" and fields.instructions == nil then
        s.instructions = "Select five modules to build the prototype."
    end
    return s
end

-- Applies a swap to a sprite row.
local function swapped(row, i, j)
    local out = { row[1], row[2], row[3], row[4], row[5] }
    out[i], out[j] = out[j], out[i]
    return out
end

-- Plays a graded arrangement: pending poll, then the result.
local function grade(session, tick, row, level, blueprint)
    session:Ingest(snapshot({ row = row, scoreText = ANALYSING, blueprint = blueprint }), tick)
    return session:Ingest(snapshot({ row = row, scoreText = LABEL[level], blueprint = blueprint }), tick + 28)
end

-- The level a fixed seed gives a sprite row, with MODULES as modules 1..5.
local function graderFor(seedId)
    return function(spriteRow)
        local arrangement = {}
        for slot = 1, 5 do
            for module = 1, 5 do
                if MODULES[module] == spriteRow[slot] then
                    arrangement[slot] = module
                end
            end
        end
        return Seeds.grade(Permutations.indexOf(arrangement), seedId)
    end
end

local IDENTITY = Permutations.indexOf({ 1, 2, 3, 4, 5 })

T.section("session: states")
do
    local s = Session.new()
    T.equal(s:ViewModel().state, "idle", "starts idle")
    s:Ingest(nil, 1)
    T.equal(s.state, "idle", "closed is idle")
    s:Ingest(snapshot({ stage = "prototype", blueprint = "No Project", instructions = "", row = { -1, -1, -1, -1, -1 } }), 8)
    T.equal(s.state, "choosing", "an empty instructions label means no blueprint is selected yet")
    s:Ingest(snapshot({ stage = "prototype", row = { -1, -1, -1, -1, -1 } }), 10)
    T.equal(s.state, "prototyping", "the board stage is prototyping")
    -- snapshot() fills the instructions label in, so these two remove it again to reach the board fallback.
    local unlabelled = snapshot({ stage = "prototype", blueprint = "No Project", row = { -1, -1, -1, -1, -1 },
        boardState = { { spriteId = -1, visible = false, rejected = false } } })
    unlabelled.instructions = nil
    s:Ingest(unlabelled, 11)
    T.equal(s.state, "choosing", "without the instructions label, an empty board means no blueprint is selected")
    unlabelled = snapshot({ stage = "prototype", blueprint = "No Project", row = { -1, -1, -1, -1, -1 },
        boardState = { { spriteId = 25074, visible = true, rejected = false } } })
    unlabelled.instructions = nil
    s:Ingest(unlabelled, 11)
    T.equal(s.state, "prototyping", "without the instructions label, modules on the board mean a blueprint is selected")
    s:Ingest(snapshot({ valid = false }), 12)
    T.equal(s.state, "unreadable", "missing components are unreadable")
    s:Ingest(snapshot({ row = { 25074, -1, -1, -1, -1 }, scoreText = "Place all the modules on the track." }), 14)
    T.equal(s.state, "arranging", "a partly filled track is arranging")
    T.equal(s:ViewModel().readingCount, 0, "no reading yet")
end

T.section("session: a puzzle solved by following suggestions")
do
    local s = Session.new()
    local row = MODULES
    local changed = grade(s, 100, row, L.POOR)
    T.check(changed, "the first reading changes the view model")
    local vm = s:ViewModel()
    T.equal(vm.readingCount, 1, "one reading")
    T.equal(vm.level, L.POOR, "level read from the label")
    T.equal(vm.xpPercent, 20, "Poor is 20% XP")
    T.check(vm.permutationsLeft > 1, "many permutations remain after a Poor opening")
    T.check(vm.suggestion ~= nil, "Guide mode suggests a swap")
    T.equal(vm.suggestion.text, "Swap 1 and 2", "the opening table's first move after Poor is slots 1 and 2")
    T.equal(vm.suggestion.bound, 11, "at most 11 swaps after a Poor opening")

    -- Follow the suggestions against a fixed seed that grades the opening row Poor.
    local V = Seeds.filter(Seeds.all(), IDENTITY, L.POOR)
    local levelFor = graderFor(V[7])
    T.equal(levelFor(row), L.POOR, "the chosen seed grades the opening Poor")

    local tick = 200
    local swaps = 0
    while s.state ~= "solved" and swaps < 15 do
        local suggestion = s:ViewModel().suggestion
        T.check(suggestion ~= nil, "a suggestion exists while unsolved")
        if suggestion == nil then
            break
        end
        row = swapped(row, suggestion.i, suggestion.j)
        grade(s, tick, row, levelFor(row))
        tick = tick + 100
        swaps = swaps + 1
    end
    T.equal(s.state, "solved", "following the suggestions reaches Perfect")
    T.check(swaps <= 11, "within 11 swaps (" .. swaps .. ")")
    T.check(s.onPath, "the player stayed on the suggested path")
    local final = s:ViewModel()
    T.equal(final.suggestion, nil, "no suggestion once solved")
    T.equal(final.level, L.PERFECT, "final level is Perfect")
    T.check(final.answer ~= nil, "the answer is shown")
    local allHome = final.targetSlots ~= nil
    for slot = 1, 5 do
        if final.targetSlots == nil or final.targetSlots[slot] ~= slot then
            allHome = false
        end
    end
    T.check(allHome, "every module sits in its target slot once Perfect")

    -- After Invent the interface reloads with no project: the result stays on show until another blueprint.
    s:Ingest(nil, tick)
    T.equal(s:ViewModel().state, "idle", "closed is idle")
    s:Ingest(snapshot({ stage = "prototype", blueprint = "No Project", instructions = "", row = { -1, -1, -1, -1, -1 } }), tick + 10)
    local kept = s:ViewModel().kept
    T.check(kept ~= nil and kept.solved and kept.answer ~= nil, "the solved puzzle is remembered while choosing")
    T.equal(kept and kept.blueprint, "Bandos components", "under its blueprint's name")
    s:Ingest(snapshot({ stage = "prototype", blueprint = "Armadyl components", row = { -1, -1, -1, -1, -1 } }), tick + 20)
    T.equal(s:ViewModel().kept, nil, "selecting another blueprint parks it")
    -- The game shows the solved blueprint's board again: all five modules count as confirmed and the order is shown.
    s:Ingest(snapshot({ stage = "prototype", row = { -1, -1, -1, -1, -1 } }), tick + 30)
    local again = s:ViewModel()
    T.equal(again.state, "prototyping", "back on the board of the solved blueprint")
    T.equal(again.prototyping and again.prototyping.confirmedCount, 5, "all five modules are confirmed after a Perfect")
    T.check(again.answer ~= nil and again.targetBySprite ~= nil, "the known order is available for the board marks")
    -- The game shows the solved blueprint's track again, still graded Perfect: the kept reading makes it solved at
    -- once, and the row the game already graded adds no reading.
    s:Ingest(snapshot({ row = row, scoreText = LABEL[L.PERFECT] }), tick + 40)
    local track = s:ViewModel()
    T.equal(track.state, "solved", "back on the track of the solved blueprint is solved")
    T.equal(track.readingCount, final.readingCount, "the already graded Perfect row adds no reading")
    T.equal(track.suggestion, nil, "and nothing is suggested")
end

T.section("session: target slots once the order is known")
do
    local s = Session.new()
    -- Grade the opening Poor against a fixed seed, then follow the suggestions until one answer remains.
    local V = Seeds.filter(Seeds.all(), IDENTITY, L.POOR)
    local levelFor = graderFor(V[11])
    local row = MODULES
    grade(s, 100, row, levelFor(row))
    local tick = 200
    while s:ViewModel().permutationsLeft > 1 and tick < 2000 do
        local suggestion = s:ViewModel().suggestion
        if suggestion == nil then
            break
        end
        row = swapped(row, suggestion.i, suggestion.j)
        grade(s, tick, row, levelFor(row))
        tick = tick + 100
    end
    local vm = s:ViewModel()
    T.equal(vm.permutationsLeft, 1, "one permutation left")
    T.check(vm.targetSlots ~= nil, "target slots are reported")
    local answerRow, targets = vm.answer, vm.targetSlots
    local consistent = targets ~= nil and answerRow ~= nil
    if targets ~= nil and answerRow ~= nil then
        for slot = 1, 5 do
            if answerRow[targets[slot]] ~= row[slot] then
                consistent = false
            end
        end
    end
    T.check(consistent, "each module's target slot holds it in the Perfect order")
end

T.section("session: deviating from the path")
do
    local s = Session.new()
    grade(s, 100, MODULES, L.POOR)
    local suggestion = s:ViewModel().suggestion or { i = 1, j = 2 }
    local other = suggestion.i == 1 and suggestion.j == 2 and { 3, 4 } or { 1, 2 }
    grade(s, 200, swapped(MODULES, other[1], other[2]), L.SATISFACTORY)
    T.check(not s.onPath, "a different swap leaves the path")
    local vm = s:ViewModel()
    T.check(vm.suggestion ~= nil, "suggestions continue off the path")
    T.equal(vm.readingCount, 2, "the deviating reading still counts")
end

T.section("session: contradiction and forgetting")
do
    local s = Session.new()
    grade(s, 100, MODULES, L.POOR)
    local row2 = swapped(MODULES, 1, 2)
    grade(s, 200, row2, L.GOOD)
    -- The same arrangement again, mis-read as Satisfactory.
    grade(s, 300, MODULES, L.SATISFACTORY)
    T.equal(s.state, "contradiction", "a second level for a graded row is a contradiction")
    local vm = s:ViewModel()
    T.equal(vm.state, "contradiction", "the view model carries the state")
    T.check(vm.suggestion ~= nil, "suggestions continue")
    s:ForgetLastReading()
    T.equal(s.state, "arranging", "forgetting the bad reading clears the contradiction")
    T.equal(s:ViewModel().readingCount, 2, "two readings remain")
end

T.section("session: the game's Perfect outranks a contradiction")
do
    local s = Session.new()
    grade(s, 100, MODULES, L.POOR)
    local row2 = swapped(MODULES, 1, 2)
    grade(s, 200, row2, L.GOOD)
    -- The opening row again, mis-read as Good: the history is contradictory from here on.
    grade(s, 300, MODULES, L.GOOD)
    T.equal(s.state, "contradiction", "a second level for the opening row is a contradiction")
    grade(s, 400, row2, L.PERFECT)
    T.check(s.contradiction, "the history is still contradictory")
    T.equal(s.state, "solved", "but a Perfect shown by the game makes the puzzle solved")
    grade(s, 500, MODULES, L.SATISFACTORY)
    T.equal(s.state, "contradiction", "a later non-Perfect reading shows the contradiction again")
    s:ForgetLastReading()
    T.check(s.contradiction, "the remaining history is still contradictory")
    T.equal(s.state, "solved", "and ends in Perfect, so forgetting the newest reading returns to solved")
end

T.section("session: identity, reset and resume")
do
    local s = Session.new()
    grade(s, 100, MODULES, L.POOR)
    grade(s, 200, swapped(MODULES, 1, 2), L.GOOD)
    T.equal(s:ViewModel().readingCount, 2, "two readings")
    s:Ingest(nil, 300)
    T.equal(s.state, "idle", "closing Discovery goes idle")
    local idle = s:ViewModel()
    T.equal(idle.readingCount, 2, "the readings are kept while idle")
    T.equal(idle.blueprint, "Bandos components", "and so is the blueprint name")
    s:Ingest(snapshot({ stage = "prototype", blueprint = "No Project", instructions = "", row = { -1, -1, -1, -1, -1 } }), 350)
    T.equal(s.state, "choosing", "reopened Discovery starts with no blueprint")
    T.equal(s:ViewModel().readingCount, 2, "choosing a blueprint does not drop the kept puzzle")
    s:Ingest(snapshot({ row = swapped(MODULES, 1, 2), scoreText = LABEL[L.GOOD] }), 400)
    T.equal(s:ViewModel().readingCount, 2, "reopening the same blueprint resumes with the readings")
    s:Ingest(snapshot({ blueprint = "Armadyl components", row = { -1, -1, -1, -1, -1 }, stage = "prototype" }), 500)
    T.equal(s.state, "prototyping", "another blueprint on the board")
    T.equal(s:ViewModel().readingCount, 0, "a new blueprint starts fresh")
    local other = { 30001, 30002, 30003, 30004, 30005 }
    grade(s, 600, other, L.GOOD)
    T.equal(s:ViewModel().readingCount, 1, "readings for the new blueprint")
    s:Reset()
    T.equal(s:ViewModel().readingCount, 0, "Reset drops the readings")
    T.equal(s.state, "arranging", "and stays in the puzzle")
end

T.section("session: several blueprints remembered")
do
    local s = Session.new()
    local other = { 30001, 30002, 30003, 30004, 30005 }
    grade(s, 100, MODULES, L.POOR)
    grade(s, 200, swapped(MODULES, 1, 2), L.GOOD)
    T.equal(s:ViewModel().readingCount, 2, "two readings on Bandos")
    -- Switch to Armadyl through its board, then grade it.
    s:Ingest(snapshot({ stage = "prototype", blueprint = "Armadyl components", row = { -1, -1, -1, -1, -1 } }), 300)
    T.equal(s:ViewModel().readingCount, 0, "Armadyl starts fresh")
    grade(s, 400, other, L.SATISFACTORY, "Armadyl components")
    T.equal(s:ViewModel().readingCount, 1, "one reading on Armadyl")
    -- Back to Bandos, exactly as it was left.
    s:Ingest(snapshot({ row = swapped(MODULES, 1, 2), scoreText = LABEL[L.GOOD] }), 500)
    local vm = s:ViewModel()
    T.equal(vm.blueprint, "Bandos components", "Bandos is current again")
    T.equal(vm.readingCount, 2, "its two readings came back")
    T.check(vm.suggestion ~= nil, "and a suggestion with them")
    -- And Armadyl is still there too.
    s:Ingest(snapshot({ blueprint = "Armadyl components", row = other, scoreText = LABEL[L.SATISFACTORY] }), 600)
    T.equal(s:ViewModel().readingCount, 1, "Armadyl's reading is still remembered")
    -- Reset forgets only the current blueprint.
    s:Reset()
    T.equal(s:ViewModel().readingCount, 0, "Reset clears Armadyl")
    s:Ingest(snapshot({ row = swapped(MODULES, 1, 2), scoreText = LABEL[L.GOOD] }), 700)
    T.equal(s:ViewModel().readingCount, 2, "Bandos is untouched by Armadyl's reset")
    -- Forget all clears both; Armadyl is reopened on a pending label so that no new reading is taken.
    s:ForgetAll()
    T.equal(s:ViewModel().readingCount, 0, "ForgetAll clears the current blueprint")
    s:Ingest(snapshot({ blueprint = "Armadyl components", row = other, scoreText = ANALYSING }), 800)
    T.equal(s:ViewModel().readingCount, 0, "and every other one")
end

T.section("session: logbook mode")
do
    local s = Session.new({ mode = "logbook" })
    grade(s, 100, MODULES, L.POOR)
    T.equal(s:ViewModel().suggestion, nil, "Logbook shows no suggestion")
    T.check(s:ViewModel().permutationsLeft > 0, "but still counts permutations")
    s:SetMode("guide")
    T.check(s:ViewModel().suggestion ~= nil, "switching to Guide shows one without a new reading")
end

T.section("session: the prototyping tracker in the view model")
do
    -- The tracker itself is tested in prototyping_test.lua; this covers how the session wires it in.
    local board = require("fixtures/prototyping_board").states
    local function select(session, tick, blueprint, onTrack, rejected)
        local changed = session:Ingest(snapshot({ stage = "prototype", blueprint = blueprint, row = { -1, -1, -1, -1, -1 },
            boardState = board(onTrack, rejected) }), tick)
        return changed, session:ViewModel().prototyping
    end
    local s = Session.new()
    local none = {}
    local _, p = select(s, 10, "Zamorak components", none, none)
    T.check(p ~= nil and p.confirmedCount == 0, "the prototyping state carries an empty tracker")
    local picked = { [25074] = true, [25079] = true, [26214] = true, [24255] = true, [25062] = true }
    select(s, 20, "Zamorak components", picked, none)
    -- Prototype: two come back rejected. The row and the label are unchanged, so only the tracker can report it.
    local afterFirst = { [25074] = true, [25079] = true, [26214] = true }
    local rejected1 = { [24255] = true, [25062] = true }
    local changed
    changed, p = select(s, 60, "Zamorak components", afterFirst, rejected1)
    T.check(changed, "a Prototype outcome counts as a change, so the panel re-renders")
    T.equal(p.confirmedCount, 3, "and the view model carries the tracker's counts")
    changed = select(s, 80, "Zamorak components", afterFirst, rejected1)
    T.check(not changed, "the same board again is not a change")
    -- Another blueprint gets a tracker of its own; coming back restores this one.
    _, p = select(s, 200, "Armadyl components", none, none)
    T.equal(p.confirmedCount, 0, "a new blueprint starts the tracker over")
    _, p = select(s, 220, "Zamorak components", afterFirst, rejected1)
    T.equal(p.confirmedCount, 3, "and the first blueprint's tracker comes back with it")
    -- A Prototype that rejects all five: the track is empty when the crosses appear, so nothing is confirmed. The
    -- rejections alone keep the puzzle. The board on return shows no crosses, so only the stored tracker has them.
    local wrong = { [26158] = true, [25069] = true, [25076] = true, [25080] = true, [25084] = true }
    select(s, 300, "Armadyl components", wrong, none)
    _, p = select(s, 340, "Armadyl components", none, wrong)
    T.equal(p.rejectedCount, 5, "an all-wrong Prototype rejects five and confirms none")
    T.equal(p.confirmedCount, 0, "with nothing left on the track to confirm")
    select(s, 400, "Zamorak components", none, none)
    _, p = select(s, 420, "Armadyl components", none, none)
    T.equal(p.rejectedCount, 5, "rejections alone keep a blueprint's tracker across a switch")
end

T.section("session: a module set change mid-puzzle")
do
    local s = Session.new()
    grade(s, 100, MODULES, L.POOR)
    local replaced = { 25074, 25081, 26156, 26158, 99999 }
    grade(s, 200, replaced, L.GOOD)
    T.equal(s:ViewModel().readingCount, 1, "a different module set is a new puzzle")
end
