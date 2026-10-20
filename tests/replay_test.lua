-- Replays every one of the 7,200 seeds through the suggestion engine under honest play and checks the
-- guarantee: Perfect within 11 swaps of the opening row, 7.348 swaps on average. The greedy layer alone must give
-- 13 and 7.502. The walk is by decision tree: every node is one decision on the survivors a player would have.
local T = require("harness")
local Permutations = require("src/core/permutations")
local Seeds = require("src/core/seeds")
local Deduce = require("src/core/deduce")
local OpeningTable = require("src/core/opening_table")

local IDENTITY = Permutations.indexOf({ 1, 2, 3, 4, 5 })

local function replay(decide)
    local swaps = {}
    local visited = { [IDENTITY] = 1 }
    local tableKeys = {}
    -- Moves without a bound come from the greedy layer: either the search gave up (few answers left) or no table
    -- entry covered the state (many answers left). Honest play should never see the second kind.
    local greedyAfterCap, greedyUncovered = 0, 0
    local function walk(c, V, key, k)
        local move = decide({ current = c, survivors = V, levelKey = key, visited = visited, onPath = true })
        if OpeningTable[key] ~= nil then
            tableKeys[key] = true
        end
        if move.bound == nil then
            if Seeds.distinctAnswers(V) <= Deduce.SEARCH_AT_MOST then
                greedyAfterCap = greedyAfterCap + 1
            else
                greedyUncovered = greedyUncovered + 1
            end
        end
        local c2 = Permutations.swap(c, move.i, move.j)
        local buckets, counts = Seeds.split(V, c2)
        for idx = 1, counts[0] do
            swaps[buckets[0][idx]] = k + 1
        end
        visited[c2] = (visited[c2] or 0) + 1
        for level = 1, 5 do
            if counts[level] > 0 then
                walk(c2, buckets[level], key .. "." .. level, k + 1)
            end
        end
        visited[c2] = visited[c2] - 1
        if visited[c2] == 0 then
            visited[c2] = nil
        end
    end
    local buckets, counts = Seeds.split(Seeds.all(), IDENTITY)
    for idx = 1, counts[0] do
        swaps[buckets[0][idx]] = 0
    end
    for level = 1, 5 do
        walk(IDENTITY, buckets[level], tostring(level), 0)
    end
    local worst, sum, histogram = 0, 0, {}
    for id = 1, Seeds.COUNT do
        local n = swaps[id]
        if n > worst then
            worst = n
        end
        sum = sum + n
        histogram[n] = (histogram[n] or 0) + 1
    end
    return {
        worst = worst,
        mean = sum / Seeds.COUNT,
        histogram = histogram,
        tableKeys = tableKeys,
        greedyAfterCap = greedyAfterCap,
        greedyUncovered = greedyUncovered,
    }
end

T.section("replay: table, search and greedy together")
do
    local r = replay(Deduce.nextSwap)
    T.equal(r.worst, 11, "worst case is 11 swaps")
    T.near(r.mean, 7.348, 0.001, "mean swaps over all seeds")
    T.equal(r.histogram[0], 60, "60 seeds are Perfect at the opening")
    T.equal(r.histogram[11], 152, "152 seeds need the full 11 swaps")
    local keys = 0
    for _ in pairs(r.tableKeys) do
        keys = keys + 1
    end
    T.equal(keys, 137, "every opening-table entry is reached")
    T.check(r.greedyAfterCap <= 40, "the node cap is rarely hit (" .. r.greedyAfterCap .. ")")
    T.equal(r.greedyUncovered, 0, "honest play never meets a state with many answers and no table entry")
end

T.section("replay: greedy alone")
do
    local r = replay(function(state)
        return Deduce.greedy(state.current, state.survivors, state.visited)
    end)
    T.equal(r.worst, 13, "greedy alone: worst 13")
    T.near(r.mean, 7.502, 0.001, "greedy alone: mean 7.502")
end
