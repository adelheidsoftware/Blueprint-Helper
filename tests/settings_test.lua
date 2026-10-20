-- Tests for src/settings.lua against the PersistentDB double.
local T = require("harness")
local Settings = require("src/settings")
local Constants = require("src/constants")
local PersistentDbDouble = require("doubles/persistentdb")

T.section("settings: defaults")
do
    local db = PersistentDbDouble.new()
    local s = Settings.load(db)
    T.equal(s.mode, "guide", "Guide is the default mode")
    T.equal(s.overlay, true, "overlay on by default")
    T.equal(s.showXp, true, "XP shown by default")
    T.equal(s.compactHistory, false, "history not compact by default")
end

T.section("settings: round trip")
do
    local db = PersistentDbDouble.new()
    local s = Settings.load(db)
    s.mode = "logbook"
    s.overlay = false
    Settings.save(db, s)
    local again = Settings.load(db)
    T.equal(again.mode, "logbook", "mode persisted")
    T.equal(again.overlay, false, "overlay persisted")
    T.equal(again.showXp, true, "untouched field keeps its default")
end

T.section("settings: bad stored values are ignored")
do
    local db = PersistentDbDouble.new()
    db:SetStructuredData(Constants.DB_KEYS.settings, { mode = "autopilot", overlay = "yes", showXp = 1, compactHistory = true })
    local s = Settings.load(db)
    T.equal(s.mode, "guide", "unknown mode falls back to the default")
    T.equal(s.overlay, true, "non-boolean overlay falls back")
    T.equal(s.showXp, true, "non-boolean showXp falls back")
    T.equal(s.compactHistory, true, "valid field is kept")
    db:SetString(Constants.DB_KEYS.settings, "garbage")
    T.equal(Settings.load(db).mode, "guide", "a non-table entry is ignored")
end
