-- Tests for src/core/commit.lua: the rule that turns polled (row, label) pairs into readings, against the
-- sequences the client produces.
local T = require("harness")
local Commit = require("src/core/commit")

local L = T.LEVEL

local GOOD = '<col=ffff00>Optimisation: Good<br>You will gain : <col=ffffff>12269</col> + <col=ffff00>24539</col> extra XP.'
local VERY_GOOD = '<col=ffff00>Optimisation: Very Good<br>You will gain : <col=ffffff>12269</col> + <col=ffff00>30674</col> extra XP.'
local PERFECT = '<col=00ff00>Optimisation: Perfect<br>You will gain : <col=ffffff>12269</col> + <col=00ff00>49078</col> extra XP.'
local ANALYSING = "Analysing..."
local PLACE = "Place all the modules on the track."

local A = { 25074, 25081, 26156, 26158, 26214 }
local B_ROW = { 25074, 26158, 26156, 25081, 26214 }
local C_ROW = { 25074, 26158, 26214, 25081, 26156 }

T.section("commit: the opening reading")
do
    local c = Commit.new()
    T.equal(c:Observe(100, { 25074, -1, -1, -1, -1 }, PLACE), nil, "incomplete row commits nothing")
    T.equal(c:Observe(102, A, ANALYSING), nil, "pending text commits nothing")
    local r = c:Observe(130, A, GOOD)
    T.check(r ~= nil and r.level == L.GOOD, "result after the pending text commits")
    T.check(r ~= nil and r.row[2] == 25081, "the reading carries the row")
    T.equal(c:Observe(132, A, GOOD), nil, "the same result is not committed twice")
end

T.section("commit: a swap, including a same-level swap")
do
    local c = Commit.new()
    c:Observe(100, A, ANALYSING)
    c:Observe(130, A, GOOD)
    T.equal(c:Observe(200, B_ROW, ANALYSING), nil, "swap: pending")
    local r = c:Observe(228, B_ROW, VERY_GOOD)
    T.check(r ~= nil and r.level == L.VERY_GOOD and r.row[2] == 26158, "swap committed for the new row")
    T.equal(c:Observe(300, C_ROW, ANALYSING), nil, "same-level swap: pending")
    local same = c:Observe(326, C_ROW, VERY_GOOD)
    T.check(same ~= nil and same.row[3] == 26214, "same-level swap commits because the label passed through pending")
end

T.section("commit: the label is read before the row changes")
do
    -- If a poll sees the new result while the row read is still the old one, the result waits for the row.
    local c = Commit.new()
    c:Observe(100, A, ANALYSING)
    c:Observe(130, A, GOOD)
    T.equal(c:Observe(200, A, ANALYSING), nil, "pending text with the old row: nothing")
    T.equal(c:Observe(202, B_ROW, ANALYSING), nil, "row arrives while pending: nothing")
    local r = c:Observe(230, B_ROW, VERY_GOOD)
    T.check(r ~= nil and r.row[2] == 26158, "result pairs with the new row")
end

T.section("commit: two swaps inside one server tick")
do
    local c = Commit.new()
    c:Observe(100, A, ANALYSING)
    c:Observe(130, A, GOOD)
    c:Observe(200, B_ROW, ANALYSING)
    T.equal(c:Observe(210, C_ROW, ANALYSING), nil, "second swap replaces the pending row")
    local r = c:Observe(236, C_ROW, PERFECT)
    T.check(r ~= nil and r.level == L.PERFECT and r.row[3] == 26214, "the result belongs to the final row only")
end

T.section("commit: settle timer when the pending text was missed")
do
    local c = Commit.new()
    c:Observe(100, A, ANALYSING)
    c:Observe(130, A, GOOD)
    T.equal(c:Observe(200, B_ROW, GOOD), nil, "a result without a pending text is not trusted at once")
    T.equal(c:Observe(240, B_ROW, GOOD), nil, "still not after 40 ticks")
    local r = c:Observe(262, B_ROW, GOOD)
    T.check(r ~= nil and r.row[2] == 26158, "after 60 ticks the label is trusted")
end

T.section("commit: enabled mid-puzzle")
do
    local c = Commit.new()
    local r = c:Observe(100, B_ROW, VERY_GOOD)
    T.check(r ~= nil and r.level == L.VERY_GOOD, "the first complete row with a result is taken as is")
end

T.section("commit: emptying the track")
do
    local c = Commit.new()
    c:Observe(100, A, ANALYSING)
    c:Observe(130, A, GOOD)
    T.equal(c:Observe(200, { 25074, -1, 26156, 26158, 26214 }, PLACE), nil, "a lifted module is not a reading")
    T.equal(c:Observe(210, A, ANALYSING), nil, "putting it back is pending again")
    local r = c:Observe(236, A, GOOD)
    T.check(r ~= nil, "and commits when graded (the session deduplicates)")
    c:Reset()
    T.check(c:Observe(300, A, GOOD) ~= nil, "after Reset the first graded row is taken as the opening again")
end
