-- Tests for src/core/levels.lua, against the six labels the client shows.
local T = require("harness")
local Levels = require("src/core/levels")

local L = T.LEVEL

local LABELS = {
    { '<col=ff0000>Optimisation: Poor!<br>You will gain : <col=ffffff>12269</col> + <col=ff0000>0</col> extra XP.', L.POOR },
    { '<col=ff7f00>Optimisation: Satisfactory<br>You will gain : <col=ffffff>12269</col> + <col=ff7f00>12270</col> extra XP.', L.SATISFACTORY },
    { '<col=ffff00>Optimisation: Good<br>You will gain : <col=ffffff>12269</col> + <col=ffff00>24539</col> extra XP.', L.GOOD },
    { '<col=ffff00>Optimisation: Very Good<br>You will gain : <col=ffffff>12269</col> + <col=ffff00>30674</col> extra XP.', L.VERY_GOOD },
    { '<col=ffffff>Optimisation: Excellent<br>You will gain : <col=ffffff>12269</col> + <col=ffffff>36809</col> extra XP.', L.EXCELLENT },
    { '<col=00ff00>Optimisation: Perfect<br>You will gain : <col=ffffff>12269</col> + <col=00ff00>49078</col> extra XP.', L.PERFECT },
}

T.section("levels: parse real labels")
for _, pair in ipairs(LABELS) do
    T.equal(Levels.parse(pair[1]), pair[2], "parses " .. Levels.name(pair[2]))
    T.check(not Levels.isPending(pair[1]), Levels.name(pair[2]) .. " is not pending")
end

T.section("levels: pending and placeholder texts")
for _, text in ipairs({ "Analysing...", "Place all the modules on the track.", "", "<col=ffff00>Optimisation: Good" }) do
    T.equal(Levels.parse(text), nil, string.format("no level in %q", text))
    T.check(Levels.isPending(text), string.format("%q is pending", text))
end
T.equal(Levels.parse(nil), nil, "nil label gives nil")
T.check(Levels.isPending(nil), "nil label is pending")

T.section("levels: other languages only change the words")
T.equal(Levels.parse("<col=ffff00>Optimierung: Gut<br>Du erhältst: <col=ffffff>12269</col> + <col=ffff00>24539</col> zusätzliche EP."),
    L.GOOD, "a translated label parses from its numbers")
T.equal(Levels.parse("You will gain : 1000 + 2500 extra XP."), L.VERY_GOOD, "ratio 3.5 is Very good")
T.equal(Levels.parse("You will gain : 1000 + 1700 extra XP."), nil, "a ratio off every level gives nil")
T.equal(Levels.parse("You will gain : 0 + 1700 extra XP."), nil, "a zero base gives nil")

T.section("levels: numbering")
T.equal(Levels.PERFECT, L.PERFECT, "Perfect is level 0")
T.equal(Levels.fromPenalty(0), L.PERFECT, "penalty 0 is Perfect")
T.equal(Levels.fromPenalty(2), L.EXCELLENT, "penalty 2 is Excellent")
T.equal(Levels.fromPenalty(8), L.SATISFACTORY, "penalty 8 is Satisfactory")
T.equal(Levels.fromPenalty(10), L.POOR, "penalty 10 is Poor")
T.equal(Levels.fromPenalty(12), L.POOR, "penalty 12 is Poor")
T.equal(Levels.name(L.POOR), "Poor", "English name")
T.equal(Levels.name(L.VERY_GOOD), "Very good", "two-word name")
T.near(Levels.ALL[L.GOOD].xpFraction, 0.6, 1e-9, "Good is 60% XP")
for level = 0, 5 do
    T.equal(Levels.parse(string.format("1000 + %d", math.floor(1000 * (Levels.ALL[level].ratio - 1) + 0.5))), level,
        "the level's own ratio parses back to it")
end
