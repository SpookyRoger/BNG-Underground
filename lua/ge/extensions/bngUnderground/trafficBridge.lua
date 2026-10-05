-- Native civilian population adapter. Never owns player or pre-existing traffic.
local U = require('/lua/ge/extensions/bngUnderground/util')
local UiSession = require('/lua/ge/extensions/bngUnderground/uiSession')
local M = {}
local loadingTag='bngUndergroundTraffic'
local held=false
local function isOwned(obj,names)
  if not obj or obj:isPlayerControlled() then return false end
  local expected=names[obj:getField('name','')]
  return expected~=nil and expected==(obj.jbeam or obj.JBeam or obj:getField('JBeam','0'))
end
function M.sessionKey() return tostring(os.time()) end
function M.isOwned(id,names) return isOwned(getObjectByID(id),names) end
function M.owned(names)
  local ids={}
  if not next(names) then return ids end
  for _,obj in ipairs(getAllVehiclesByType()) do if isOwned(obj,names) then ids[#ids+1]=obj:getId() end end
  return ids
end
function M.removeOwned(names)
  for _,id in ipairs(M.owned(names)) do
    local obj=getObjectByID(id)
    if isOwned(obj,names) then gameplay_traffic.removeTraffic(id,true);obj:delete() end
  end
end
function M.count() return gameplay_traffic.getTrafficAmount() end
function M.state() return gameplay_traffic.getState() end
function M.mapReady(id) return map.objects and map.objects[id]~=nil end
function M.captureVars()
  local data=U.copy(gameplay_traffic.getTrafficVars())
  -- Native activeAmount defaults to infinity; encode it for session serialization.
  if data.activeAmount==math.huge then data.activeAmount=nil;data.unlimitedActive=true end
  return data
end
function M.restoreVars(saved)
  local data=U.copy(saved)
  if data.unlimitedActive then data.activeAmount=math.huge end
  data.unlimitedActive=nil
  gameplay_traffic.setTrafficVars(data)
end
function M.setStreetVars(amount)
  gameplay_traffic.setTrafficVars({aiMode='traffic',aiAware='auto',activeAmount=amount,baseAggression=0.35,
    speedLimit=-1,enableRespawn=true,enableRandomEvents=false})
end
function M.spawn(group,groupName)
  core_multiSpawn.spawnGroup(group,#group,{name=groupName,mode='traffic',gap=20,randomPaints=true})
end
function M.activate(ids)
  assert(ids[1],'Cannot activate an empty campaign population')
  gameplay_traffic.activate(ids)
  for _,id in ipairs(ids) do
    local obj=getObjectByID(id)
    if obj then obj.playerUsable=false;obj:queueLuaCommand('electrics.setLightsState(2)') end
  end
end
function M.lockOwned(names)
  for _,id in ipairs(M.owned(names)) do
    local obj=getObjectByID(id)
    if obj then obj.playerUsable=false end
  end
end
function M.cover(callback)
  held=true;UiSession.enter()
  core_gamestate.requestEnterLoadingScreen(loadingTag,callback)
end
function M.captureInput() if held then UiSession.enter() end end
function M.releaseCover()
  if not held then return end
  held=false;UiSession.leave();core_gamestate.requestExitLoadingScreen(loadingTag)
end
function M.changed() end -- Root supplies UI publication after constructing the coordinator.
return M
