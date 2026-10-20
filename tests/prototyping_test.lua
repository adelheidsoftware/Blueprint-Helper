-- Tests for src/core/prototyping.lua, the prototyping tracker, driven directly with board states as the reader reports
-- them: visible on the board, hidden while on the track, rejected after Prototype.
local T = require("harness")
local Prototyping = require("src/core/prototyping")
local board = require("fixtures/prototyping_board").states

local none = {}

T.section("prototyping: two Prototypes")
do
    local p = Prototyping.new()
    p:Ingest(board(none, none))
    T.equal(p.confirmedCount, 0, "nothing known at the start")
    T.check(not p:HasProgress(), "no progress yet")
    -- Five on the track, Prototype: two come back rejected.
    local picked = { [25074] = true, [25079] = true, [26214] = true, [24255] = true, [25062] = true }
    p:Ingest(board(picked, none))
    T.equal(p.confirmedCount, 0, "nothing confirmed before Prototype")
    local afterFirst = { [25074] = true, [25079] = true, [26214] = true }
    local rejected1 = { [24255] = true, [25062] = true }
    p:Ingest(board(afterFirst, rejected1))
    T.equal(p.rejectedCount, 2, "two rejected")
    T.equal(p.confirmedCount, 3, "the three still on the track are confirmed")
    T.check(p.confirmed[25074] and p.confirmed[25079] and p.confirmed[26214], "the right ones")
    T.check(p:HasProgress(), "progress once something is confirmed")
    -- Two more picked, Prototype: one rejected.
    local second = { [25074] = true, [25079] = true, [26214] = true, [25084] = true, [26158] = true }
    p:Ingest(board(second, rejected1))
    T.equal(p.confirmedCount, 3, "picking more confirms nothing by itself")
    local rejected2 = { [24255] = true, [25062] = true, [25084] = true }
    local afterSecond = { [25074] = true, [25079] = true, [26214] = true, [26158] = true }
    p:Ingest(board(afterSecond, rejected2))
    T.equal(p.confirmedCount, 4, "four confirmed after the second Prototype")
    T.equal(p.rejectedCount, 3, "three rejected")
    -- The player takes a confirmed module off the track; it stays confirmed.
    p:Ingest(board({ [25074] = true, [25079] = true, [26214] = true }, rejected2))
    T.equal(p.confirmedCount, 4, "a confirmed module taken off the track stays confirmed")
    T.check(p.confirmed[26158], "including the one just removed")
    local view = p:View()
    T.equal(view.confirmedCount, 4, "the view carries the confirmed count")
    T.equal(view.rejectedCount, 3, "and the rejected count")
    T.check(view.confirmed == p.confirmed, "and the confirmed set itself, by sprite")
end

T.section("prototyping: reaching the track, and boards that cannot be read")
do
    local p = Prototyping.new()
    p:ConfirmAll({ 25074, 25079, 26214, 25084, 26158 })
    T.equal(p.confirmedCount, 5, "a complete track confirms all five")
    p:ConfirmAll({ 25074, 25079, 26214, 25084, 26158 })
    T.equal(p.confirmedCount, 5, "confirming again counts nothing twice")
    p:Ingest(nil)
    T.equal(p.confirmedCount, 5, "an unreadable board changes nothing")
    p:Ingest(board(none, none))
    T.equal(p.rejectedCount, 0, "a board without crosses rejects nothing")
end
