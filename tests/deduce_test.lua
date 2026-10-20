-- Tests for src/core/deduce.lua: the readings it works from (Seeds.consistent), the greedy layer and the layer choice.
local T = require("harness")
local Permutations = require("src/core/permutations")
local Seeds = require("src/core/seeds")
local Deduce = require("src/core/deduce")
local OpeningTable = require("src/core/opening_table")

local L = T.LEVEL
local IDENTITY = Permutations.indexOf({ 1, 2, 3, 4, 5 })

-- Survivors by the direct definition, for comparison.
local function bruteSurvivors(readings)
    local out = {}
    for id = 1, Seeds.COUNT do
        local keep = true
        for _, r in ipairs(readings) do
            if Seeds.grade(r.arrangement, id) ~= r.level then
                keep = false
                break
            end
        end
        if keep then
            out[#out + 1] = id
        end
    end
    return out
end

-- The most Perfect arrangements a swap can leave in its worst outcome.
local function worstAnswersOf(V, arrangement)
    local _, answers = Seeds.score(V, arrangement)
    local worst = 0
    for level = 1, 5 do
        worst = math.max(worst, answers[level])
    end
    return worst
end

T.section("deduce: survivors")
do
    local second = Permutations.swap(IDENTITY, 1, 2)
    local third = Permutations.swap(second, 3, 5)
    local readings = {
        { arrangement = IDENTITY, level = L.POOR },
        { arrangement = second, level = L.SATISFACTORY },
        { arrangement = third, level = L.GOOD },
    }
    local V, contradiction = Seeds.consistent(readings)
    T.check(not contradiction, "consistent readings are not a contradiction")
    T.sameList(V, bruteSurvivors(readings), "survivors match the direct definition")
    T.check(#V > 0, "some seeds survive three readings")
end
do
    local V, contradiction = Seeds.consistent({})
    T.equal(#V, 7200, "no readings keeps every seed")
    T.check(not contradiction, "no readings is not a contradiction")
end

T.section("deduce: contradiction")
do
    local readings = {
        { arrangement = IDENTITY, level = L.POOR },
        { arrangement = IDENTITY, level = L.GOOD },
    }
    local V, contradiction = Seeds.consistent(readings)
    T.check(contradiction, "the same row with two levels is a contradiction")
    T.equal(#V, 2640 + 1440, "the seeds agreeing with either reading are kept")
    local move = Deduce.nextSwap({ current = IDENTITY, survivors = V, levelKey = "x", visited = { [IDENTITY] = true } })
    T.check(move ~= nil, "suggestions continue after a contradiction")
end

T.section("deduce: solved")
do
    local V = Seeds.filter(Seeds.all(), IDENTITY, L.PERFECT)
    T.equal(Deduce.nextSwap({ current = IDENTITY, survivors = V, levelKey = "0", visited = {} }), nil,
        "no suggestion when the row is Perfect")
    T.equal(Deduce.nextSwap({ current = IDENTITY, survivors = {}, levelKey = "", visited = {} }), nil,
        "no suggestion without survivors")
end

T.section("deduce: greedy")
do
    local V = Seeds.filter(Seeds.all(), IDENTITY, L.POOR)
    local move = Deduce.greedy(IDENTITY, V, { [IDENTITY] = true })
    T.check(move.i >= 1 and move.j <= 5 and move.i < move.j, "greedy names a valid slot pair")
    T.equal(move.bound, nil, "greedy promises no bound")
    -- No other swap leaves fewer Perfect arrangements in its worst outcome.
    local best = math.huge
    for _, t in ipairs(Permutations.TRANSPOSITIONS) do
        best = math.min(best, worstAnswersOf(V, Permutations.swap(IDENTITY, t.i, t.j)))
    end
    T.equal(worstAnswersOf(V, Permutations.swap(IDENTITY, move.i, move.j)), best, "greedy minimises the worst-case answers left")
    -- A visited arrangement is avoided when an unvisited one is available.
    local avoided = Permutations.swap(IDENTITY, move.i, move.j)
    local second = Deduce.greedy(IDENTITY, V, { [IDENTITY] = true, [avoided] = true })
    T.check(Permutations.swap(IDENTITY, second.i, second.j) ~= avoided, "greedy does not revisit a graded arrangement")
end

T.section("deduce: layer choice")
do
    local poor = Seeds.filter(Seeds.all(), IDENTITY, L.POOR)
    local visited = { [IDENTITY] = true }
    local onPath = Deduce.nextSwap({ current = IDENTITY, survivors = poor, levelKey = "5", visited = visited })
    local entry = OpeningTable["5"]
    T.check(entry ~= nil, "the opening table has an entry for a Poor opening")
    T.equal(onPath.i, entry[1], "the table's swap is suggested, slot 1")
    T.equal(onPath.j, entry[2], "the table's swap is suggested, slot 2")
    T.equal(onPath.bound, entry[3], "with the table's bound")
    T.equal(onPath.bound, 11, "11 swaps at most after a Poor opening")

    local offPath = Deduce.nextSwap({ current = IDENTITY, survivors = poor, levelKey = "5", visited = visited, onPath = false })
    local greedy = Deduce.greedy(IDENTITY, poor, visited)
    T.check(offPath.i == greedy.i and offPath.j == greedy.j and offPath.bound == nil,
        "greedy takes over once the player left the path")

    local excellent = Seeds.filter(Seeds.all(), IDENTITY, L.EXCELLENT)
    T.equal(Seeds.distinctAnswers(excellent), 10, "an Excellent opening leaves ten answers, inside the search's range")
    local small = Deduce.nextSwap({ current = IDENTITY, survivors = excellent, levelKey = "1", visited = visited })
    T.check(small.bound == nil or small.bound == 9, "the search, when it finishes, reports a bound of 9 swaps")
end

T.section("deduce: levelKey")
T.equal(Deduce.levelKey({ 5, 3, 4 }), "5.3.4", "levels joined by dots")
T.equal(Deduce.levelKey({ 2 }), "2", "single level")
