-- A prototyping board as the reader reports it, with the sprite IDs of a recorded prototyping stage. A module is
-- visible on the board, hidden while it sits on the track, and rejected once the game crosses it out.
local Board = {}

Board.SPRITES = { 25074, 25079, 25084, 26158, 26214, 24255, 25062, 25069, 25076, 25080 }

---@param onTrack table sprite ID -> true for the modules on the track
---@param rejected table sprite ID -> true for the modules crossed out
---@return table[] states { spriteId, visible, rejected } per board position
function Board.states(onTrack, rejected)
    local states = {}
    for i, sprite in ipairs(Board.SPRITES) do
        states[i] = { spriteId = sprite, visible = not onTrack[sprite], rejected = rejected[sprite] == true }
    end
    return states
end

return Board
