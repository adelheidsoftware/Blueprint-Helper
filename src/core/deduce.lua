-- From the readings so far to the next swap to suggest.
--
-- Three layers decide, all over the same survivor set:
--   1. the opening table, while the player has followed every suggestion and more than 12 Perfect arrangements
--      remain. Its key is the sequence of levels seen so far, which fully describes the situation as long as the
--      suggestions were followed (see opening_table.lua);
--   2. the endgame search, once 12 or fewer Perfect arrangements remain, which is when it is cheap enough to run live;
--   3. a greedy choice among the ten swaps otherwise: after the player left the suggested path while many answers
--      remain, or when the search runs out of budget.
-- Together they reach Perfect within 11 swaps of the opening row on every blueprint, 7.35 on average.

local Permutations = require("src/core/permutations")
local Seeds = require("src/core/seeds")
local Search = require("src/core/search")
local OpeningTable = require("src/core/opening_table")

local COUNT = Permutations.COUNT
local COMPOSE, TRANSPOSITIONS = Permutations.COMPOSE, Permutations.TRANSPOSITIONS
local answer = Seeds.answer

local Deduce = {}

Deduce.SEARCH_AT_MOST = 12 -- distinct answers at which the endgame search takes over
Deduce.NODE_CAP = 1000 -- search budget per decision; about 50 ms in the client at most

-- The key the opening table uses: the levels seen since the opening reading, opening first, joined by dots.
---@param levels integer[] in reading order
---@return string
function Deduce.levelKey(levels)
    local parts = {}
    for i, level in ipairs(levels) do
        parts[i] = tostring(level)
    end
    return table.concat(parts, ".")
end

-- Greedy layer. Of the ten swaps, prefer in this order: one that does not revisit an arrangement already graded,
-- the fewest Perfect arrangements left in its worst outcome, the shortest farthest answer, the fewest seeds in its
-- biggest outcome, one that could itself be Perfect, and finally the lowest slot pair.
---@param current integer arrangement index
---@param survivors integer[] seed ids
---@param visited table set of arrangement indices already graded this puzzle
---@return table move { i, j }
function Deduce.greedy(current, survivors, visited)
    local best = nil
    for swapIndex = 1, #TRANSPOSITIONS do
        local swapped = COMPOSE[(current - 1) * COUNT + TRANSPOSITIONS[swapIndex].index]
        local counts, answers, far = Seeds.score(survivors, swapped)
        local worstAnswers, worstSeeds = 0, 0
        for level = 1, 5 do
            if answers[level] > worstAnswers then
                worstAnswers = answers[level]
            end
            if counts[level] > worstSeeds then
                worstSeeds = counts[level]
            end
        end
        local couldBePerfect = answers[0] > 0 and 1 or 0
        local revisit = visited[swapped] and 1 or 0
        local better
        if best == nil then
            better = true
        elseif revisit ~= best.revisit then
            better = revisit < best.revisit
        elseif worstAnswers ~= best.worstAnswers then
            better = worstAnswers < best.worstAnswers
        elseif far ~= best.far then
            better = far < best.far
        elseif worstSeeds ~= best.worstSeeds then
            better = worstSeeds < best.worstSeeds
        elseif couldBePerfect ~= best.couldBePerfect then
            better = couldBePerfect > best.couldBePerfect
        else
            better = false
        end
        if better then
            best = {
                swapIndex = swapIndex,
                worstAnswers = worstAnswers,
                worstSeeds = worstSeeds,
                far = far,
                couldBePerfect = couldBePerfect,
                revisit = revisit,
            }
        end
    end
    assert(best ~= nil, "greedy: no swaps to choose from")
    local swap = TRANSPOSITIONS[best.swapIndex]
    return { i = swap.i, j = swap.j }
end

-- The next swap for a puzzle in progress, or nil when there is nothing left to learn: no survivors, or every
-- survivor says the current row is already Perfect.
---@param state table { current = arrangement index, survivors = ids, levelKey, visited = set, onPath = boolean? }
---   onPath defaults to true
---@return table? move { i, j, bound? }; bound is the most swaps still needed, known when the table or search answered
function Deduce.nextSwap(state)
    local survivors = state.survivors
    if #survivors == 0 then
        return nil
    end
    local distinct = Seeds.distinctAnswers(survivors)
    if distinct == 1 and answer[survivors[1]] == state.current then
        return nil
    end
    if state.onPath ~= false then
        local entry = OpeningTable[state.levelKey]
        if entry ~= nil then
            return { i = entry[1], j = entry[2], bound = entry[3] }
        end
    end
    if distinct <= Deduce.SEARCH_AT_MOST then
        local move = Search.find(state.current, survivors, Deduce.NODE_CAP)
        if move ~= nil then
            return move
        end
    end
    return Deduce.greedy(state.current, survivors, state.visited)
end

return Deduce
