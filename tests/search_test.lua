-- Tests for src/core/search.lua: exactness on small sets against an unpruned search, and the node cap.
local T = require("harness")
local Permutations = require("src/core/permutations")
local Seeds = require("src/core/seeds")
local Search = require("src/core/search")

local L = T.LEVEL
local COUNT = Permutations.COUNT
local IDENTITY = Permutations.indexOf({ 1, 2, 3, 4, 5 })

local function distance(a, b)
    return Permutations.DIST[(a - 1) * COUNT + b]
end

-- Minimax without any pruning: can every seed in V be made Perfect within `depth` swaps from c?
local function bruteSolvable(c, V, depth)
    if #V == 0 then
        return true
    end
    if depth == 0 then
        return false
    end
    for _, t in ipairs(Permutations.TRANSPOSITIONS) do
        local c2 = Permutations.swap(c, t.i, t.j)
        local buckets, counts = Seeds.split(V, c2)
        local ok = true
        for level = 1, 5 do
            if counts[level] > 0 and not bruteSolvable(c2, buckets[level], depth - 1) then
                ok = false
                break
            end
        end
        if ok then
            return true
        end
    end
    return false
end

local function bruteDepth(c, V, limit)
    for d = 0, limit do
        if bruteSolvable(c, V, d) then
            return d
        end
    end
    return nil
end

T.section("search: agrees with the unpruned search on small sets")
do
    math.randomseed(7)
    local excellent = Seeds.filter(Seeds.all(), IDENTITY, L.EXCELLENT)
    local veryGood = Seeds.filter(Seeds.all(), IDENTITY, L.VERY_GOOD)
    local pools = { excellent, veryGood }
    local compared = 0
    for trial = 1, 24 do
        local pool = pools[(trial % 2) + 1]
        local V = {}
        local picked = {}
        local size = 2 + (trial % 4)
        while #V < size do
            local id = pool[math.random(#pool)]
            if not picked[id] then
                picked[id] = true
                V[#V + 1] = id
            end
        end
        local expected = bruteDepth(IDENTITY, V, 4)
        if expected ~= nil then
            compared = compared + 1
            local move = Search.find(IDENTITY, V, 100000)
            T.check(move ~= nil, "search finishes on a small set")
            if move ~= nil then
                T.equal(move.bound, expected, string.format("trial %d: bound equals the unpruned minimum", trial))
                -- The move it returns really does finish within the bound.
                local c2 = Permutations.swap(IDENTITY, move.i, move.j)
                local buckets, counts = Seeds.split(V, c2)
                local ok = true
                for level = 1, 5 do
                    if counts[level] > 0 and not bruteSolvable(c2, buckets[level], move.bound - 1) then
                        ok = false
                    end
                end
                T.check(ok, string.format("trial %d: every outcome of the move finishes in bound - 1", trial))
            end
        end
    end
    T.check(compared >= 12, "enough small sets were comparable (" .. compared .. ")")
end

T.section("search: single answer")
do
    local target = Permutations.indexOf({ 2, 3, 1, 5, 4 })
    local V = {}
    for id = 1, Seeds.COUNT do
        if Seeds.answer[id] == target then
            V[#V + 1] = id
        end
    end
    local move = Search.find(IDENTITY, V, 1000)
    T.check(move ~= nil, "search finishes with one answer")
    T.equal(move.bound, distance(IDENTITY, target), "bound is the swap distance to the answer")
    local c2 = Permutations.swap(IDENTITY, move.i, move.j)
    T.equal(distance(c2, target), move.bound - 1, "the move steps towards the answer")
end

T.section("search: node cap")
do
    local satisfactory = Seeds.filter(Seeds.all(), IDENTITY, L.SATISFACTORY)
    T.equal(Search.find(IDENTITY, satisfactory, 200), nil, "a large set under a tiny cap gives nil")
    local excellent = Seeds.filter(Seeds.all(), IDENTITY, L.EXCELLENT)
    T.check(Search.find(IDENTITY, excellent, 1000000) ~= nil, "a generous cap always finishes")
end
