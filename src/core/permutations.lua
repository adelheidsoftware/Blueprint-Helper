-- Arrangements of the five Discovery modules as permutations. An arrangement maps slot to module, both 1..5, so
-- 2 1 3 4 5 means module 2 sits in slot 1 and module 1 in slot 2. Module n is whatever sat in slot n of the first
-- graded row, so that row is always 1 2 3 4 5, the first entry of `list`. The rest of the engine refers to an
-- arrangement by its index in `list`, and the three tables built here let the hot loops in seeds.lua and search.lua
-- work on integers only:
--   COMPOSE  a ∘ b, applying b and then a. Swapping slots i and j of arrangement c is c ∘ t, where t is the
--            arrangement that only exchanges slots i and j; scoring.lua and seeds.lua also use it to put a seed's
--            ranks into an arrangement's slots.
--   INV      the inverse of an arrangement, for DIST below and for the Perfect arrangements in scoring.lua.
--   DIST     the smallest number of swaps that turns one arrangement into another: 1 2 3 4 5 to 2 1 3 4 5 is one
--            swap, to 2 3 1 4 5 two, and nothing is more than four away.

local Permutations = {}

local N = 5
Permutations.N = N

local list = {}
local indexByKey = {}

local function keyOf(p)
    return p[1] * 10000 + p[2] * 1000 + p[3] * 100 + p[4] * 10 + p[5]
end

-- Lexicographic order, so list[1] is the identity 1 2 3 4 5.
local function generate(prefix, remaining)
    if #remaining == 0 then
        local p = { prefix[1], prefix[2], prefix[3], prefix[4], prefix[5] }
        list[#list + 1] = p
        indexByKey[keyOf(p)] = #list
        return
    end
    for i = 1, #remaining do
        prefix[#prefix + 1] = remaining[i]
        local rest = {}
        for j = 1, #remaining do
            if j ~= i then
                rest[#rest + 1] = remaining[j]
            end
        end
        generate(prefix, rest)
        prefix[#prefix] = nil
    end
end
generate({}, { 1, 2, 3, 4, 5 })

local COUNT = #list -- 120
Permutations.COUNT = COUNT
Permutations.list = list

---@param arrangement integer[] slot -> module
---@return integer? index into Permutations.list, nil unless the array is a permutation of 1..5
function Permutations.indexOf(arrangement)
    if #arrangement ~= N then
        return nil
    end
    for s = 1, N do
        local module = arrangement[s]
        if math.type(module) ~= "integer" or module < 1 or module > N then
            return nil
        end
    end
    return indexByKey[keyOf(arrangement)]
end

-- COMPOSE[(a - 1) * COUNT + b] is the index of a ∘ b, where (a ∘ b)[s] = a[b[s]]. INV[a] is the inverse of a.
local COMPOSE = {}
local INV = {}
for a = 1, COUNT do
    local pa = list[a]
    local inverse = {}
    for s = 1, N do
        inverse[pa[s]] = s
    end
    INV[a] = indexByKey[keyOf(inverse)]
    local base = (a - 1) * COUNT
    for b = 1, COUNT do
        local pb = list[b]
        COMPOSE[base + b] = indexByKey[keyOf({ pa[pb[1]], pa[pb[2]], pa[pb[3]], pa[pb[4]], pa[pb[5]] })]
    end
end
Permutations.COMPOSE = COMPOSE
Permutations.INV = INV

-- Swapping slots i and j of arrangement c gives c ∘ t, with t the transposition of i and j.
local TRANSPOSITIONS = {}
local transpositionAt = {}
for i = 1, N - 1 do
    transpositionAt[i] = {}
    for j = i + 1, N do
        local t = { 1, 2, 3, 4, 5 }
        t[i], t[j] = j, i
        TRANSPOSITIONS[#TRANSPOSITIONS + 1] = { i = i, j = j, index = indexByKey[keyOf(t)] }
        transpositionAt[i][j] = #TRANSPOSITIONS
    end
end
Permutations.TRANSPOSITIONS = TRANSPOSITIONS -- the ten slot pairs as { i, j, index }, i < j

---@param arrangement integer arrangement index
---@param i integer slot
---@param j integer slot, in either order relative to i
---@return integer arrangement index after swapping the two slots
function Permutations.swap(arrangement, i, j)
    if i > j then
        i, j = j, i
    end
    return COMPOSE[(arrangement - 1) * COUNT + TRANSPOSITIONS[transpositionAt[i][j]].index]
end

local function cycleCount(p)
    local seen = { false, false, false, false, false }
    local count = 0
    for s = 1, N do
        if not seen[s] then
            count = count + 1
            local k = s
            while not seen[k] do
                seen[k] = true
                k = p[k]
            end
        end
    end
    return count
end

-- DIST[(a - 1) * COUNT + b] is the number of swaps that turn arrangement a into b. The rearrangement a⁻¹ ∘ b
-- splits into cycles (a module already in place is a cycle of one), and a cycle of length k takes k - 1 swaps, so
-- the total is N minus the number of cycles.
local DIST = {}
for a = 1, COUNT do
    local base, invBase = (a - 1) * COUNT, (INV[a] - 1) * COUNT
    for b = 1, COUNT do
        DIST[base + b] = N - cycleCount(list[COMPOSE[invBase + b]])
    end
end
Permutations.DIST = DIST

return Permutations
