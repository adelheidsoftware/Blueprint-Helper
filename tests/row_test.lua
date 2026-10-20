-- Tests for src/core/row.lua: when a track row counts as complete.
local T = require("harness")
local Row = require("src/core/row")

T.section("row: completeness")
T.check(Row.complete({ 25074, 25081, 26156, 26158, 26214 }), "five modules make a complete row")
T.check(not Row.complete({ 25074, 25081, 26156, 26158, -1 }), "an empty last slot makes it incomplete")
T.check(not Row.complete({ 25074, -1, 26156, 26158, 26214 }), "so does an empty slot in the middle")
T.check(not Row.complete({ 25074, 25081, 26156, 26158 }), "a missing fifth slot makes it incomplete")
T.check(not Row.complete({}), "an empty table is incomplete")
T.check(not Row.complete(nil), "nil is incomplete")
