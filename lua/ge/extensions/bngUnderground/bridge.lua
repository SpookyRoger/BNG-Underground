-- Native vehicles, GPS and HUD layout adapter. Other engine features have separate adapters.
local U = require('/lua/ge/extensions/bngUnderground/util')
local G = require('/lua/ge/extensions/bngUnderground/garage')
local Onboarding = require('/lua/ge/extensions/bngUnderground/onboarding')
local Workshop = require('/lua/ge/extensions/bngUnderground/workshop')
local HudLayout = require('/lua/ge/extensions/bngUnderground/hudLayout')
local M = {}
local originalLayout, originalVehicle

function M.isCareer()
  return career_career and career_career.isActive()
end
function M.isCity(content)
  return getCurrentLevelIdentifier and getCurrentLevelIdentifier()==content.settings.level
end
function M.busy()
  return gameplay_missions_missionManager and
    (gameplay_missions_missionManager.getForegroundMissionId()~=nil or gameplay_missions_missionManager.isCurrentlyProcessingStep())
end
function M.captureVehicle()
  if originalVehicle then return end
  local v=getPlayerVehicle(0)
  if v then
    local p=v:getPosition()
    local q=quatFromDir(v:getDirectionVector(),v:getDirectionVectorUp())
    originalVehicle={model=v.jbeam,config=U.copy(core_vehicle_partmgmt.getConfig()),pos={p.x,p.y,p.z},rot={q.x,q.y,q.z,q.w}}
  end
end
function M.restoreVehicle()
  if originalVehicle then
    local v=core_vehicles.replaceVehicle(originalVehicle.model,{config=originalVehicle.config})
    if v then spawn.safeTeleport(v,vec3(originalVehicle.pos),quat(originalVehicle.rot)) end
  end
  originalVehicle=nil
end
function M.clearVehicleSnapshot() originalVehicle=nil end
function M.configuration(content,state)
  if Onboarding.pending(state) then return Onboarding.configuration(content,function(path) return U.copy(jsonReadFile(path)) end) end
  return G.configuration(content,state,function(path) return U.copy(jsonReadFile(path)) end)
end
function M.spawnCar(content,state,atHome)
  local cfg,model=M.configuration(content,state)
  if not cfg then return false,model end
  local options={config=cfg,autoEnterVehicle=true,canSpawnAnotherVehicleCheck=false}
  if atHome then
    local site=content.locationsById.home
    -- Supply the transform to the native asynchronous constructor itself.
    options.pos=vec3(site.pos);options.rot=quat(site.rot)
  end
  local veh
  if getPlayerVehicle(0) then veh=core_vehicles.replaceVehicle(model,options)
  else veh=core_vehicles.spawnNewVehicle(model,options) end
  if not veh then return false,'BeamNG could not spawn the selected car.' end
  veh:queueLuaCommand('electrics.setLightsState(2)')
  return true,nil,veh:getId()
end
function M.campaignVehicleId(content,state)
  local vehicle=getPlayerVehicle(0)
  local id=Onboarding.pending(state) and content.settings.introduction.car or state.activeCar
  return vehicle and vehicle.jbeam==content.vehiclesById[id].model and vehicle:getId() or nil
end
function M.joinVehicleReady(content,state,id)
  local vehicle=id and getObjectByID(id)
  local carId=Onboarding.pending(state) and content.settings.introduction.car or state.activeCar
  if not vehicle or vehicle.jbeam~=content.vehiclesById[carId].model then return false end
  local data=core_vehicle_manager.getVehicleData(id)
  local refs=data and data.vdata and data.vdata.refNodes and data.vdata.refNodes[0]
  -- Map publication follows native physics/Lua initialization. A returned
  -- object alone does not prove that node transforms or cameras are usable.
  return refs and refs.ref~=nil and refs.left~=nil and refs.back~=nil and map.objects and map.objects[id]~=nil or false
end
function M.placeJoinCar(content,state,id)
  if not M.joinVehicleReady(content,state,id) then return false,'The campaign car is still initializing.' end
  local vehicle=getObjectByID(id)
  local site=content.locationsById.home
  spawn.safeTeleport(vehicle,vec3(site.pos),quat(site.rot))
  if be:getPlayerVehicleID(0)~=id then be:enterVehicle(0,vehicle) end
  return true
end
function M.focusJoinCar(content,state,id)
  if not M.joinVehicleReady(content,state,id) then return false,'The campaign car is unavailable after loading.' end
  local vehicle=getObjectByID(id)
  if be:getPlayerVehicleID(0)~=id then be:enterVehicle(0,vehicle) end
  commands.setGameCamera()
  core_camera.setByName(0,'orbit',false)
  core_camera.resetCamera(0)
  vehicle:queueLuaCommand('electrics.setLightsState(2)')
  return true
end
function M.playerPosition()
  local vehicle=getPlayerVehicle(0)
  if vehicle then local p=vehicle:getPosition();return {p.x,p.y,p.z} end
end
function M.routePoints()
  local points={}
  local route=core_groundMarkers.routePlanner and core_groundMarkers.routePlanner.path or {}
  for index,node in ipairs(route) do
    if index>3000 then break end
    points[#points+1]={node.pos.x,node.pos.y}
  end
  return points
end
function M.distance(pos)
  local v=getPlayerVehicle(0)
  if not v then return math.huge end
  return (v:getPosition()-vec3(pos)):length()
end
function M.isStopped()
  local v=getPlayerVehicle(0)
  return v and v:getVelocity():length()<1
end
function M.nearShop(content,state)
  local context=Workshop.context(content,state,M.distance,M.isStopped(),M.busy())
  return context.siteId and content.locationsById[context.siteId] or nil
end
function M.navigate(pos)
  core_groundMarkers.setPath({vec3(pos)},{clearPathOnReachingTarget=true})
end
function M.clearRoute() core_groundMarkers.setPath(nil) end
function M.refreshMap()
  if gameplay_missions_unlocks then gameplay_missions_unlocks.clearCache() end
  if gameplay_rawPois then gameplay_rawPois.clear() end
end
function M.defaults(mission)
  local settings={}
  for _,elem in ipairs(mission:getUserSettingsData() or {}) do settings[elem.key]=elem.value end
  return settings
end
function M.startEvent(event)
  local mission=gameplay_missions_missions.getMissionById(event.missionId)
  if not mission then return false,'Mission not found. Restart BeamNG after enabling this mod.' end
  local err=gameplay_missions_missionManager.startWithFade(mission,M.defaults(mission))
  if err then return false,'The game could not start this mission.' end
  return true
end
function M.ensureApp(state,enabled)
  if not ui_appLayouts then extensions.load('ui_appLayouts') end
  if ui_appLayouts.isEditing() then return false end
  local current=ui_appLayouts.getCurrentLayout()
  if not current then return false end
  local hasHud=false
  for _,app in ipairs(current.apps or {}) do
    if app.appName=='bngUnderground' then hasHud=true end
  end
  local wantsMap=enabled~=false and state.preferences.minimap~=false
  local layout,changed=HudLayout.apply(current,wantsMap)
  if hasHud and not changed then return true end
  if not originalLayout then originalLayout=U.copy(current) end
  -- 0.39's Vue store resolves named layouts from disk on refresh. A unique,
  -- unnamed layout plus the object hook preserves this temporary HUD addition.
  layout.filename=nil;layout.type='bngUndergroundTransient';layout.name='BNG Underground'
  layout.apps=layout.apps or {}
  if not hasHud then table.insert(layout.apps,{appName='bngUnderground',placement={left='24px',top='90px',width='340px',height='170px'}}) end
  ui_appLayouts.setCurrentLayout(layout)
  guihooks.trigger('appContainer:loadLayoutByObject',layout)
  return true
end
function M.restoreLayout()
  if originalLayout and ui_appLayouts then
    ui_appLayouts.setCurrentLayout(originalLayout)
    guihooks.trigger('appContainer:loadLayoutByObject',originalLayout)
  end
  originalLayout=nil
end
function M.clearLayoutSnapshot() originalLayout=nil end
function M.snapshot() return {layout=U.copy(originalLayout),vehicle=U.copy(originalVehicle)} end
function M.restoreSnapshot(value)
  originalLayout=U.copy(value and value.layout)
  originalVehicle=U.copy(value and value.vehicle)
end
function M.message(text,kind)
  guihooks.trigger('BNGUMessage',{text=text,kind=kind or 'info'})
  if ui_message then ui_message(text,6,'bngUnderground') end
end
return M
