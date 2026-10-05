local U = require('/lua/ge/extensions/bngUnderground/util')
local M = {}
local saved
function M.capture()
  if not saved and core_environment then saved=U.copy(core_environment.getState()) end
end
function M.apply(content, state)
  if not core_environment or not getCurrentLevelIdentifier or getCurrentLevelIdentifier()~=content.settings.level then return end
  M.capture()
  if content.settings.features.night and state.preferences.night then
    local tod=U.copy(core_environment.getTimeOfDay())
    if tod then
      tod.time=core_environment.getSolarTimeOfDayValue(content.settings.nightPreset,tod) or content.settings.nightTimeFallback
      tod.play=false
      core_environment.setTimeOfDay(tod)
    end
    local v=getPlayerVehicle(0)
    if v then v:queueLuaCommand('electrics.setLightsState(2)') end
  elseif saved then core_environment.setState(U.copy(saved)) end
end
function M.restore()
  if saved and core_environment then core_environment.setState(U.copy(saved)) end
  saved=nil
end
function M.clear() saved=nil end
function M.snapshot() return U.copy(saved) end
function M.restoreSnapshot(value) saved=U.copy(value) end
return M
