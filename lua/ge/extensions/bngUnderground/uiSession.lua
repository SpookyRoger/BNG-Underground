-- Owns only BNG Underground's menu pause and gameplay-input capture.
-- Native Menu/First action maps stay available for controller navigation/Back.
local M = {}
local requestId = 'bngUndergroundMenu'
local maps = {'NormalActionMap','VehicleCommonActionMap','VehicleSpecificActionMap'}
local captured, pauseRequested = false, false
local previous = {}

local function captureMaps()
  for _,name in ipairs(maps) do
    local map = scenetree.findObject(name)
    if map then
      if previous[name] == nil then previous[name] = map.enabled end
      map:setEnabled(false)
    end
  end
end

function M.enter()
  captured = true
  captureMaps()
  if getMissionFilename() ~= '' and not pauseRequested then
    simTimeAuthority.pushPauseRequest(requestId)
    pauseRequested = true
  end
end

function M.update()
  if not captured then return end
  -- Vehicle replacement and binding reloads can re-enable an action map.
  captureMaps()
  if pauseRequested then
    -- Native UI initialization clears its named pause stack. Reacquire our
    -- idempotent request before enforcing pause, so leave() can release it.
    simTimeAuthority.pushPauseRequest(requestId)
    if not simTimeAuthority.getPause() then simTimeAuthority.pause(true) end
  end
end

function M.leave()
  for name,enabled in pairs(previous) do
    local map = scenetree.findObject(name)
    if map then map:setEnabled(enabled) end
  end
  previous = {}
  captured = false
  if pauseRequested then simTimeAuthority.popPauseRequest(requestId) end
  pauseRequested = false
end

function M.snapshot() return {captured=captured,previous=deepcopy(previous)} end
function M.restore(value)
  captured = value and value.captured or false
  previous = value and value.previous or {}
  pauseRequested = false
  if captured then M.enter() end
end
return M
