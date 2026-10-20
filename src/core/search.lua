-- The endgame search: given the current row and the surviving seeds, the swap that minimises the number of further
-- swaps needed in the worst case.
--
-- It asks, for depth 1, 2, 3 and so on, whether every survivor can be brought to Perfect within that many swaps; the
-- first depth that works is the bound reported with the move. At each position it tries the ten swaps, splits the
-- survivors by the level each swap would produce, and requires every outcome to be solvable one swap sooner. It runs
-- once 12 or fewer Perfect arrangements remain (see deduce.lua); with the opening table ahead of it, it reaches
-- Perfect within 11 swaps on every blueprint, which is the best any strategy can guarantee. A node budget bounds the
-- cost, and when it runs out the caller falls back to the greedy layer.

local Permutations = require("src/core/permutations")
local Seeds = require("src/core/seeds")

local COUNT = Permutations.COUNT
local COMPOSE, TRANSPOSITIONS = Permutations.COMPOSE, Permutations.TRANSPOSITIONS

local Search = {}

-- RESOLVABLE[d]: the most distinct answers any strategy can tell apart in d graded swaps. A swap is answered by one
-- of five levels other than Perfect, each leading to a position with d - 1 swaps left, and by Perfect, which finishes
-- exactly one answer. So RESOLVABLE[d] = 1 + 5 * RESOLVABLE[d - 1]: 1, 6, 31, 156, ... A position with more answers
-- than that cannot be finished in d swaps, whatever is tried.
local RESOLVABLE = { [0] = 0 }
for d = 1, 20 do
    RESOLVABLE[d] = 1 + 5 * RESOLVABLE[d - 1]
end

local CAP_HIT = {} -- raised as an error value when the node budget runs out
local nodes, nodeCap = 0, 0

-- The swaps from `arrangement` worth trying at this depth, best first; or `immediate` when one swap makes every
-- survivor Perfect. A candidate is dropped when either bound says it cannot finish in depth - 1 more swaps. Each
-- candidate records its swap as an index into TRANSPOSITIONS, the arrangement that swap leads to, and its scores.
local function candidates(arrangement, survivors, depth)
    local cands = {}
    for swapIndex = 1, #TRANSPOSITIONS do
        local swapped = COMPOSE[(arrangement - 1) * COUNT + TRANSPOSITIONS[swapIndex].index]
        local counts, answers, far = Seeds.score(survivors, swapped)
        local worstAnswers, worstSeeds, done = 0, 0, true
        for level = 1, 5 do
            if counts[level] > 0 then
                done = false
                if answers[level] > worstAnswers then
                    worstAnswers = answers[level]
                end
                if counts[level] > worstSeeds then
                    worstSeeds = counts[level]
                end
            end
        end
        if done then
            return {}, { swapIndex = swapIndex, swapped = swapped, counts = counts }
        end
        if worstAnswers <= RESOLVABLE[depth - 1] and far <= depth - 1 then
            cands[#cands + 1] = {
                swapIndex = swapIndex,
                swapped = swapped,
                worstAnswers = worstAnswers,
                worstSeeds = worstSeeds,
                far = far,
                counts = counts,
            }
        end
    end
    table.sort(cands, function(x, y)
        if x.worstAnswers ~= y.worstAnswers then
            return x.worstAnswers < y.worstAnswers
        end
        if x.far ~= y.far then
            return x.far < y.far
        end
        if x.worstSeeds ~= y.worstSeeds then
            return x.worstSeeds < y.worstSeeds
        end
        return x.swapIndex < y.swapIndex
    end)
    return cands, nil
end

local solvable -- declared ahead: solvable and everyOutcomeSolvable call each other

-- Whether every level `cand` can produce leaves survivors that are solvable in depth - 1 swaps.
local function everyOutcomeSolvable(cand, survivors, depth)
    local buckets = Seeds.split(survivors, cand.swapped)
    for level = 1, 5 do
        if cand.counts[level] > 0 and not solvable(cand.swapped, buckets[level], depth - 1) then
            return false
        end
    end
    return true
end

-- Can every survivor be brought to Perfect within `depth` swaps from `arrangement`?
function solvable(arrangement, survivors, depth)
    if #survivors == 0 then
        return true
    end
    if depth == 0 then
        return false
    end
    if Seeds.distinctAnswers(survivors) > RESOLVABLE[depth] then
        return false
    end
    if Seeds.farthest(arrangement, survivors) > depth then
        return false
    end
    nodes = nodes + 1
    if nodes > nodeCap then
        error(CAP_HIT, 0)
    end
    local cands, immediate = candidates(arrangement, survivors, depth)
    if immediate then
        return true
    end
    if depth == 1 then
        return false
    end
    for i = 1, #cands do
        if everyOutcomeSolvable(cands[i], survivors, depth) then
            return true
        end
    end
    return false
end

-- The first candidate, in preference order, whose every outcome is solvable in depth - 1 swaps.
local function choose(arrangement, survivors, depth)
    local cands, immediate = candidates(arrangement, survivors, depth)
    if immediate then
        return immediate
    end
    for i = 1, #cands do
        if everyOutcomeSolvable(cands[i], survivors, depth) then
            return cands[i]
        end
    end
    error("search: no feasible move at a depth that was just proven solvable")
end

---@param current integer arrangement index of the row as it stands
---@param survivors integer[] surviving seeds, none of which has `current` as its answer
---@param cap integer most nodes to expand before giving up
---@return table? move { i, j, bound }: the slots to swap and the most swaps still needed; nil when the cap was hit
function Search.find(current, survivors, cap)
    nodes, nodeCap = 0, cap
    local ok, cand, bound = pcall(function()
        local depth = Seeds.farthest(current, survivors)
        if depth < 1 then
            depth = 1
        end
        while not solvable(current, survivors, depth) do
            depth = depth + 1
        end
        return choose(current, survivors, depth), depth
    end)
    if ok then
        local swap = TRANSPOSITIONS[cand.swapIndex]
        return { i = swap.i, j = swap.j, bound = bound }
    end
    -- On failure the second value is the error that was raised.
    if cand == CAP_HIT then
        return nil
    end
    error(cand, 0)
end

return Search
