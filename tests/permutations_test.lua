-- Tests for src/core/permutations.lua.
local T = require("harness")
local Permutations = require("src/core/permutations")

local COUNT = Permutations.COUNT
local COMPOSE, INV, DIST = Permutations.COMPOSE, Permutations.INV, Permutations.DIST
local IDENTITY = Permutations.indexOf({ 1, 2, 3, 4, 5 })

local function compose(a, b)
    return COMPOSE[(a - 1) * COUNT + b]
end

local function distance(a, b)
    return DIST[(a - 1) * COUNT + b]
end

T.section("permutations: list")
T.equal(COUNT, 120, "120 arrangements")
T.equal(IDENTITY, 1, "the identity comes first")
T.sameList(Permutations.list[IDENTITY], { 1, 2, 3, 4, 5 }, "identity is 1 2 3 4 5")
do
    local seen = {}
    local unique = true
    for i = 1, COUNT do
        local key = table.concat(Permutations.list[i], "")
        if seen[key] then
            unique = false
        end
        seen[key] = true
        T.equal(Permutations.indexOf(Permutations.list[i]), i, "indexOf round-trips " .. key)
    end
    T.check(unique, "all arrangements distinct")
end
T.equal(Permutations.indexOf({ 1, 1, 2, 3, 4 }), nil, "indexOf rejects a repeated module")
T.equal(Permutations.indexOf({ 1, 2, 3 }), nil, "indexOf rejects a short array")
T.equal(Permutations.indexOf({ 0, 1, 2, 3, 4 }), nil, "indexOf rejects a module out of range")
T.equal(Permutations.indexOf({ 1, 2, 3, 4, 5.0 }), nil, "indexOf rejects a non-integer")

T.section("permutations: compose and inverse")
for a = 1, COUNT do
    T.equal(compose(a, INV[a]), IDENTITY, "a ∘ a⁻¹ is the identity")
    T.equal(compose(IDENTITY, a), a, "identity ∘ a is a")
    T.equal(compose(a, IDENTITY), a, "a ∘ identity is a")
end
do
    -- (a ∘ b)[s] = a[b[s]], checked against the arrays for every pair
    local ok = true
    for a = 1, COUNT do
        local pa = Permutations.list[a]
        for b = 1, COUNT do
            local pb = Permutations.list[b]
            local pc = Permutations.list[compose(a, b)]
            for s = 1, 5 do
                if pc[s] ~= pa[pb[s]] then
                    ok = false
                end
            end
        end
    end
    T.check(ok, "compose matches the array definition for all 14,400 pairs")
end

T.section("permutations: swaps and distance")
T.equal(#Permutations.TRANSPOSITIONS, 10, "ten transpositions")
for _, t in ipairs(Permutations.TRANSPOSITIONS) do
    local expected = { 1, 2, 3, 4, 5 }
    expected[t.i], expected[t.j] = t.j, t.i
    T.equal(t.index, Permutations.indexOf(expected), string.format("transposition (%d %d) has the right index", t.i, t.j))
end
for i = 1, 4 do
    for j = i + 1, 5 do
        local swapped = Permutations.list[Permutations.swap(IDENTITY, i, j)]
        local expected = { 1, 2, 3, 4, 5 }
        expected[i], expected[j] = j, i
        T.sameList(swapped, expected, string.format("swap(identity, %d, %d)", i, j))
        T.equal(Permutations.swap(Permutations.swap(IDENTITY, i, j), i, j), IDENTITY, "swapping twice returns")
        T.equal(distance(IDENTITY, Permutations.swap(IDENTITY, i, j)), 1, "one swap away")
        T.equal(Permutations.swap(IDENTITY, j, i), Permutations.swap(IDENTITY, i, j), "swap ignores slot order")
    end
end
do
    local ok = true
    for a = 1, COUNT do
        for b = 1, COUNT do
            if distance(a, b) ~= distance(b, a) then
                ok = false
            end
            if a == b and distance(a, b) ~= 0 then
                ok = false
            end
        end
    end
    T.check(ok, "distance is symmetric and zero on the diagonal")
end
do
    -- The distance table agrees with a breadth-first walk over single swaps, and nothing is more than four swaps
    -- from the identity.
    local depth = { [IDENTITY] = 0 }
    local frontier = { IDENTITY }
    while #frontier > 0 do
        local reached = {}
        for _, c in ipairs(frontier) do
            for _, t in ipairs(Permutations.TRANSPOSITIONS) do
                local c2 = Permutations.swap(c, t.i, t.j)
                if depth[c2] == nil then
                    depth[c2] = depth[c] + 1
                    reached[#reached + 1] = c2
                end
            end
        end
        frontier = reached
    end
    local ok, worst = true, 0
    for c = 1, COUNT do
        if depth[c] ~= distance(IDENTITY, c) then
            ok = false
        end
        worst = math.max(worst, depth[c])
    end
    T.check(ok, "the distance table equals the breadth-first swap distance")
    T.equal(worst, 4, "no arrangement is more than four swaps from the identity")
end
