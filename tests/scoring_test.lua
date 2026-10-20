-- Tests for src/core/scoring.lua and the seed set in src/core/seeds.lua, against the direct definition of the rule.
local T = require("harness")
local Permutations = require("src/core/permutations")
local Scoring = require("src/core/scoring")
local Seeds = require("src/core/seeds")
local Levels = require("src/core/levels")

local COUNT = Permutations.COUNT
local list = Permutations.list
local IDENTITY = Permutations.indexOf({ 1, 2, 3, 4, 5 })

-- The rule as the game defines it: the sum over slots of |rank of the module there - rank of the slot|.
local function penalty(arrangement, moduleRanks, slotRanks)
    local total = 0
    for s = 1, 5 do
        total = total + math.abs(moduleRanks[arrangement[s]] - slotRanks[s])
    end
    return total
end

local function mirrored(ranks)
    return { 6 - ranks[1], 6 - ranks[2], 6 - ranks[3], 6 - ranks[4], 6 - ranks[5] }
end

-- The seeds in the order seeds.lua builds them: one of each mirror pair of module rankings, times every slot
-- ranking. Enumerated here independently so the test does not rely on the module's internals.
local SEED_M, SEED_S = {}, {}
for m = 1, COUNT do
    if m <= Permutations.indexOf(mirrored(list[m])) then
        for s = 1, COUNT do
            SEED_M[#SEED_M + 1] = m
            SEED_S[#SEED_S + 1] = s
        end
    end
end

T.section("scoring: seeds")
T.equal(Seeds.COUNT, 7200, "7,200 seeds, one per mirror pair")
T.equal(#SEED_M, 7200, "the test enumeration has the same size")
do
    local all = Seeds.all()
    T.equal(#all, 7200, "all() lists every seed")
    T.equal(all[1], 1, "ids start at 1")
    T.equal(all[7200], 7200, "ids are dense")
end

T.section("scoring: tables match the direct definition")
do
    -- For every seed and every arrangement: the table grade equals the level of the direct penalty, the penalty is
    -- even, the stored answer scores 0 and is the one perfectArrangement computes, and the 120 arrangements split
    -- 1 / 4 / 12 / 24 / 35 / 44 across the levels.
    local tableMatches, allEven, perfectScoresZero, answersMatch, distributionHolds = true, true, true, true, true
    local EXPECTED = { [0] = 1, 4, 12, 24, 35, 44 }
    for id = 1, Seeds.COUNT do
        local moduleRanks, slotRanks = list[SEED_M[id]], list[SEED_S[id]]
        local counts = { [0] = 0, 0, 0, 0, 0, 0 }
        for a = 1, COUNT do
            local p = penalty(list[a], moduleRanks, slotRanks)
            if p % 2 ~= 0 then
                allEven = false
            end
            local level = Levels.fromPenalty(p)
            if Seeds.grade(a, id) ~= level then
                tableMatches = false
            end
            counts[level] = counts[level] + 1
        end
        if penalty(list[Seeds.answer[id]], moduleRanks, slotRanks) ~= 0 then
            perfectScoresZero = false
        end
        if Scoring.perfectArrangement(SEED_M[id], SEED_S[id]) ~= Seeds.answer[id] then
            answersMatch = false
        end
        for level = 0, 5 do
            if counts[level] ~= EXPECTED[level] then
                distributionHolds = false
            end
        end
    end
    T.check(tableMatches, "table grade equals the direct penalty level for all 864,000 pairs")
    T.check(allEven, "penalty is always even")
    T.check(perfectScoresZero, "the stored answer scores a penalty of 0")
    T.check(answersMatch, "the stored answer is perfectArrangement(M, S)")
    T.check(distributionHolds, "every seed grades the 120 arrangements as 1 / 4 / 12 / 24 / 35 / 44")
end

T.section("scoring: mirror")
do
    -- A seed and its mirror (rank r -> 6 - r on both sides) grade every arrangement alike, which is why only one
    -- of each pair is kept.
    local ok = true
    for id = 1, Seeds.COUNT, 97 do
        local pm, ps = list[SEED_M[id]], list[SEED_S[id]]
        local mm, ms = mirrored(pm), mirrored(ps)
        for a = 1, COUNT do
            if Levels.fromPenalty(penalty(list[a], pm, ps)) ~= Levels.fromPenalty(penalty(list[a], mm, ms)) then
                ok = false
            end
        end
    end
    T.check(ok, "mirrored seeds are indistinguishable")
end

T.section("scoring: survivor operations")
do
    local V = Seeds.all()
    local buckets, counts = Seeds.split(V, IDENTITY)
    T.equal(counts[0], 60, "60 seeds grade the identity Perfect")
    T.equal(counts[5], 2640, "2,640 seeds grade the identity Poor")
    T.equal(Seeds.distinctAnswers(buckets[0]), 1, "the Perfect bucket has one answer")
    T.equal(Seeds.distinctAnswers(buckets[5]), 89, "the Poor bucket has 89 distinct answers")
    T.equal(Seeds.distinctAnswers(buckets[1]), 10, "the Excellent bucket has the 10 one-swap answers")
    T.equal(Seeds.farthest(IDENTITY, buckets[1]), 1, "every Excellent answer is one swap away")
    T.equal(Seeds.farthest(IDENTITY, buckets[5]), 4, "some Poor answers are four swaps away")
    local filtered = Seeds.filter(V, IDENTITY, 5)
    T.sameList(filtered, buckets[5], "filter agrees with split")
    local scoreCounts, scoreAnswers, far = Seeds.score(V, IDENTITY)
    T.equal(scoreCounts[5], 2640, "score counts agree with split")
    T.equal(scoreAnswers[5], 89, "score answers agree with distinctAnswers")
    T.equal(far, 4, "score farthest agrees with farthest")
end
