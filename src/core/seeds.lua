-- The seeds, the hidden rankings a blueprint can have, and the operations on sets of them.
--
-- A seed is a pair (module ranks M, slot ranks S), each a permutation of 1..5. Replacing every rank r by 6 - r on
-- both sides changes no penalty, so a seed and its mirror grade every arrangement alike and share the Perfect
-- arrangement; only one of each pair is kept, giving 60 x 120 = 7,200 seeds. A seed is referred to by its id 1..COUNT
-- and described by three parallel arrays: its module ranks, its slot ranks (both as permutation indices) and its
-- Perfect arrangement, which puts in every slot the module whose rank equals the slot's rank. A set of seeds is a
-- plain array of ids; a reading keeps the ids whose seed would have given that arrangement that level.

local Permutations = require("src/core/permutations")
local Scoring = require("src/core/scoring")

local COUNT = Permutations.COUNT -- 120 arrangements; the flattened tables are indexed (row - 1) * COUNT + column
local list = Permutations.list
local COMPOSE, DIST = Permutations.COMPOSE, Permutations.DIST
local GRADE = Scoring.GRADE

local Seeds = {}

local moduleRanks, slotRanks, answer = {}, {}, {}
local seedCount = 0
for m = 1, COUNT do
    local pm = list[m]
    local mirror = Permutations.indexOf({ 6 - pm[1], 6 - pm[2], 6 - pm[3], 6 - pm[4], 6 - pm[5] })
    if m <= mirror then
        for s = 1, COUNT do
            seedCount = seedCount + 1
            moduleRanks[seedCount], slotRanks[seedCount] = m, s
            answer[seedCount] = Scoring.perfectArrangement(m, s)
        end
    end
end

Seeds.COUNT = seedCount -- 7,200
Seeds.answer = answer -- id -> index of the Perfect arrangement

---@return integer[] ids every seed id, a fresh array
function Seeds.all()
    local all = {}
    for id = 1, seedCount do
        all[id] = id
    end
    return all
end

-- The level this seed would give the arrangement. The ranks sitting in the slots are the seed's module ranks composed
-- with the arrangement (one COMPOSE lookup), and GRADE holds the level of those against the seed's slot ranks.
---@param arrangement integer arrangement index
---@param id integer seed id
---@return integer level what the game would show for the arrangement if this seed were the blueprint's
local function grade(arrangement, id)
    return GRADE[(COMPOSE[(moduleRanks[id] - 1) * COUNT + arrangement] - 1) * COUNT + slotRanks[id]]
end
Seeds.grade = grade

-- The survivors for which `arrangement` grades as `level`: what one reading does to the survivors.
---@return integer[] survivors a fresh array
function Seeds.filter(survivors, arrangement, level)
    local kept, n = {}, 0
    for i = 1, #survivors do
        local id = survivors[i]
        if grade(arrangement, id) == level then
            n = n + 1
            kept[n] = id
        end
    end
    return kept
end

-- Survivors of a list of readings { arrangement = index, level = 0..5 }. When no seed fits every reading, one of
-- them was mis-read: the seeds agreeing with the most readings are kept and `contradiction` is true, so suggestions
-- keep coming.
---@return integer[] survivors
---@return boolean contradiction
function Seeds.consistent(readings)
    local survivors = Seeds.all()
    for _, reading in ipairs(readings) do
        survivors = Seeds.filter(survivors, reading.arrangement, reading.level)
    end
    if #survivors > 0 or #readings == 0 then
        return survivors, false
    end
    local best, kept = -1, {}
    for id = 1, seedCount do
        local matches = 0
        for _, reading in ipairs(readings) do
            if grade(reading.arrangement, id) == reading.level then
                matches = matches + 1
            end
        end
        if matches > best then
            best, kept = matches, { id }
        elseif matches == best then
            kept[#kept + 1] = id
        end
    end
    return kept, true
end

-- Distinct-answer counting without clearing a table between calls: every pass takes a new stamp value, and an answer
-- counts only if seen[key] does not already hold the current stamp. Keys are level * COUNT + answer, so score() can
-- count per level in the same array.
local stamp = 0
local seen = {}
for i = 1, 6 * COUNT do
    seen[i] = 0
end

---@return integer count how many different Perfect arrangements the survivors still allow
function Seeds.distinctAnswers(survivors)
    stamp = stamp + 1
    local n = 0
    for i = 1, #survivors do
        local key = answer[survivors[i]]
        if seen[key] ~= stamp then
            seen[key] = stamp
            n = n + 1
        end
    end
    return n
end

---@return integer swaps the most swaps any survivor's Perfect arrangement is away from `arrangement`
function Seeds.farthest(arrangement, survivors)
    local base, far = (arrangement - 1) * COUNT, 0
    for i = 1, #survivors do
        local distance = DIST[base + answer[survivors[i]]]
        if distance > far then
            far = distance
        end
    end
    return far
end

-- Scores `arrangement` over the survivors in one pass: how many seeds and how many distinct answers each level would
-- keep, and the farthest answer (in swaps from the arrangement) among the seeds that would not be Perfect. This is
-- the hot loop of both the greedy layer and the endgame search, so it builds no tables beyond the two small result
-- arrays and spells grade() out inline instead of calling it.
---@return integer[] counts seeds per level, indexed 0..5
---@return integer[] answers distinct answers per level, indexed 0..5
---@return integer farthest
function Seeds.score(survivors, arrangement)
    stamp = stamp + 1
    local counts = { [0] = 0, 0, 0, 0, 0, 0 }
    local answers = { [0] = 0, 0, 0, 0, 0, 0 }
    local base, far = (arrangement - 1) * COUNT, 0
    for i = 1, #survivors do
        local id = survivors[i]
        local level = GRADE[(COMPOSE[(moduleRanks[id] - 1) * COUNT + arrangement] - 1) * COUNT + slotRanks[id]]
        counts[level] = counts[level] + 1
        local perfect = answer[id]
        local key = level * COUNT + perfect
        if seen[key] ~= stamp then
            seen[key] = stamp
            answers[level] = answers[level] + 1
        end
        if level > 0 then
            local distance = DIST[base + perfect]
            if distance > far then
                far = distance
            end
        end
    end
    return counts, answers, far
end

-- Splits the survivors by the level each seed gives `arrangement`. Only built for a move that is actually taken or
-- searched.
---@return integer[][] buckets indexed 0..5
---@return integer[] counts indexed 0..5
function Seeds.split(survivors, arrangement)
    local buckets = { [0] = {}, {}, {}, {}, {}, {} }
    local counts = { [0] = 0, 0, 0, 0, 0, 0 }
    for i = 1, #survivors do
        local id = survivors[i]
        local level = grade(arrangement, id)
        local n = counts[level] + 1
        counts[level] = n
        buckets[level][n] = id
    end
    return buckets, counts
end

return Seeds
