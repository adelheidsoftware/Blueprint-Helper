-- The polling loop. Subscribes to Event.Logic, asks the reader for a snapshot, feeds the session and tells the
-- view and overlay to render when something changed. Nothing in here decides anything about the puzzle.

local Client = require("src/client")
local Constants = require("src/constants")

local Watcher = {}
Watcher.__index = Watcher

Watcher.OPEN_POLL_TICKS = 2 -- 25 Hz while Discovery is open, enough to catch the "Analysing..." text
Watcher.CLOSED_POLL_TICKS = 25 -- twice a second while it is closed, just to notice it opening

---@param deps table { reader, session, onChanged = function(viewModel), onPolled = function(viewModel) }
function Watcher.new(deps)
    local self = setmetatable({}, Watcher)
    self.reader = deps.reader
    self.session = deps.session
    self.onChanged = deps.onChanged -- when the view model changed, or a render was requested
    self.onPolled = deps.onPolled -- every poll while Discovery is open, for marks that follow the game window
    self.open = false
    self.tick = 0
    self.forceRender = false
    self.logError = Client.errorLog("error while polling")
    return self
end

function Watcher:Start()
    Event.Logic.Subscribe(Constants.EVENTS.logic, function(event)
        self:onLogic(event.logicTick)
    end)
end

function Watcher:Stop()
    Event.Logic.Unsubscribe(Constants.EVENTS.logic)
end

-- Render on the next tick even if the session did not change (a setting changed, the view was remounted).
function Watcher:RequestRender()
    self.forceRender = true
end

-- One poll. An error is logged, unless it repeats the previous one, and polling continues, so one bad tick (a stale
-- component, a UI hiccup) cannot silently stop the plugin.
function Watcher:onLogic(tick)
    self.tick = tick
    local interval = self.open and Watcher.OPEN_POLL_TICKS or Watcher.CLOSED_POLL_TICKS
    if tick % interval ~= 0 and not self.forceRender then
        return
    end
    local ok, err = pcall(self.poll, self, tick)
    if not ok then
        self.forceRender = false
        self.logError(err)
    end
end

function Watcher:poll(tick)
    local snapshot = self.reader:Snapshot()
    self.open = snapshot ~= nil
    local changed = self.session:Ingest(snapshot, tick)
    local vm = nil
    if changed or self.forceRender then
        self.forceRender = false
        vm = self.session:ViewModel()
        self.onChanged(vm)
    end
    if self.open then
        self.onPolled(vm or self.session:ViewModel())
    end
end

return Watcher
