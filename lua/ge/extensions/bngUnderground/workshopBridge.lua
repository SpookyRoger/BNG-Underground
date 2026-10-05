-- Native scene/camera adapter. It never changes the campaign profile or money.
local U=require('/lua/ge/extensions/bngUnderground/util')
local Bridge=require('/lua/ge/extensions/bngUnderground/bridge')
local M={}
local function orbit(id)
  local cameras=id and core_camera.getCameraDataById(id)
  return cameras and cameras.orbit
end
local function vector(v) return v and {v.x,v.y,v.z} end
function M.capture()
  local id=be:getPlayerVehicleID(0);local cam=orbit(id)
  return {lighting=U.copy(core_environment.getTimeOfDay()),camera=core_camera.getActiveCamName(0),
    rotation=cam and vector(cam.defaultRotation),distance=cam and cam.defaultDistance,
    offset=cam and vector(cam.orbitOffset),orbit=cam and cam:serialize()}
end
function M.spawn(content,state,siteId)
  local cfg,model=Bridge.configuration(content,state)
  if not cfg then return false,model end
  local site=content.locationsById[siteId]
  local vehicle=core_vehicles.replaceVehicle(model,{config=cfg,pos=vec3(site.pos),rot=quat(site.rot),
    autoEnterVehicle=true,canSpawnAnotherVehicleCheck=false})
  if not vehicle then return false,'BeamNG could not construct the workshop car.' end
  return true,nil,vehicle:getId()
end
function M.initialize(id,complete)
  local vehicle=getObjectByID(id)
  if not vehicle then return false,'The workshop vehicle disappeared during construction.' end
  -- The same native one-frame handshake used by career part shopping/painting.
  -- It works independently of navgraph caching and map.objects physics tracking.
  core_vehicleBridge.requestValue(vehicle,function(value)
    if value and value.ping==true then complete() end
  end,'ping')
  return true
end
function M.ready(content,state,id)
  local vehicle=id and getObjectByID(id)
  local spec=content.vehiclesById[state.activeCar]
  if not vehicle or not spec or vehicle.jbeam~=spec.model or be:getPlayerVehicleID(0)~=id then return false end
  local data=core_vehicle_manager.getVehicleData(id)
  local refs=data and data.vdata and data.vdata.refNodes and data.vdata.refNodes[0]
  return refs and refs.ref~=nil and refs.left~=nil and refs.back~=nil or false
end
function M.place(content,state,id,siteId)
  if not M.ready(content,state,id) then return false,'The workshop car is still initializing.' end
  local vehicle=getObjectByID(id);local site=content.locationsById[siteId]
  spawn.safeTeleport(vehicle,vec3(site.pos),quat(site.rot))
  if be:getPlayerVehicleID(0)~=id then be:enterVehicle(0,vehicle) end
  core_vehicleBridge.executeAction(vehicle,'setFreeze',true)
  vehicle:queueLuaCommand('electrics.setLightsState(0)')
  return true
end
function M.present(id,viewId,settings)
  local vehicle=getObjectByID(id)
  if not vehicle then return end
  commands.setGameCamera();core_camera.setByName(0,'orbit',false)
  for _,view in ipairs(settings.views) do if view.id==viewId then core_camera.setDefaultRotation(id,vec3(view.rotation)) end end
  core_camera.setDefaultDistance(id,settings.cameraDistance)
  core_camera.setDistance(id,settings.cameraDistance)
  core_camera.resetCamera(0)
  if scenetree.OnlyGui then scenetree.OnlyGui:setFrustumCameraCenterOffset(Point2F(settings.cameraOffsetX,0)) end
  -- Temporary inspection lighting is restored on exit; street night is unchanged.
  local tod=U.copy(core_environment.getTimeOfDay())
  if tod then tod.time=core_environment.getSolarTimeOfDayValue(settings.lightPreset,tod) or 0;tod.play=false;core_environment.setTimeOfDay(tod) end
end
function M.stats(id,token,revision)
  local vehicle=getObjectByID(id)
  if vehicle then vehicle:queueLuaCommand('extensions.load("bngUndergroundWorkshop");extensions.bngUndergroundWorkshop.request('..serialize(token)..','..tostring(revision)..')') end
end
function M.restore(snapshot,id)
  local vehicle=id and getObjectByID(id)
  if vehicle then core_vehicleBridge.executeAction(vehicle,'setFreeze',false) end
  if snapshot and snapshot.lighting then core_environment.setTimeOfDay(U.copy(snapshot.lighting)) end
  if scenetree.OnlyGui then scenetree.OnlyGui:setFrustumCameraCenterOffset(Point2F(0,0)) end
  commands.setGameCamera()
  local cam=orbit(id)
  if cam and snapshot then
    cam:init()
    if snapshot.rotation then cam:setDefaultRotation(vec3(snapshot.rotation)) end
    if snapshot.distance then cam:setDefaultDistance(snapshot.distance) end
    if snapshot.offset then cam:setOffset(vec3(snapshot.offset)) end
    if snapshot.orbit then cam:deserialize(snapshot.orbit) end
  end
  local name=snapshot and snapshot.camera
  if name=='free' or name=='game' or name=='follower' then name='orbit' end
  core_camera.setByName(0,name or 'orbit',false)
end
return M
