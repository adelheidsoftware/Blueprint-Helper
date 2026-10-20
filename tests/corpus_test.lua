-- Checks the scoring rule and the deduction against RuneKit's recorded puzzles (fixtures/discovery_samples.lua,
-- generated from RuneKit's research/discovery-samples.json by gen_fixtures.mjs): the seeds consistent with a
-- puzzle's readings must include the arrangement the game graded Perfect, and the rule must explain every recorded
-- row. RuneKit's own count of 535 of 537 includes two hand-transcribed rows that are not in the file.
local T = require("harness")
local Permutations = require("src/core/permutations")
local Seeds = require("src/core/seeds")

local samples = require("fixtures/discovery_samples")

T.section("corpus: shape")
T.equal(#samples, 25, "25 recorded puzzles")
local rows = 0
for _, sample in ipairs(samples) do
    rows = rows + #sample.observations
end
T.equal(rows, 535, "535 recorded rows")

T.section("corpus: every puzzle is explained")
local explained = 0
local contradictions = 0
for n, sample in ipairs(samples) do
    local readings = {}
    for i, observation in ipairs(sample.observations) do
        local index = Permutations.indexOf(observation.arrangement)
        T.check(index ~= nil, string.format("sample %d row %d is a permutation", n, i))
        readings[i] = { arrangement = index, level = observation.level }
    end
    local truth = Permutations.indexOf(sample.truth)
    T.check(truth ~= nil, string.format("sample %d truth is a permutation", n))

    local V, contradiction = Seeds.consistent(readings)
    T.check(#V > 0, string.format("sample %d keeps some seed", n))
    if contradiction then
        contradictions = contradictions + 1
    end

    -- The truth must be among the Perfect arrangements the survivors still allow.
    local found = false
    for _, id in ipairs(V) do
        if Seeds.answer[id] == truth then
            found = true
            break
        end
    end
    T.check(found, string.format("sample %d: the recorded Perfect arrangement is still possible (%d readings%s)", n,
        #readings, contradiction and ", contradiction" or ""))

    -- Rows explained by the best seed that has the truth as its answer.
    local best = 0
    for _, id in ipairs(V) do
        if Seeds.answer[id] == truth then
            local matches = 0
            for _, reading in ipairs(readings) do
                if Seeds.grade(reading.arrangement, id) == reading.level then
                    matches = matches + 1
                end
            end
            if matches > best then
                best = matches
            end
        end
    end
    explained = explained + best
end
T.equal(explained, rows, "the rule explains every recorded row")
T.equal(contradictions, 0, "no recorded puzzle contradicts the rule")
