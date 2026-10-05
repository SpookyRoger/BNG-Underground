-- Collection/repair construction adapter. No money or save operations.
local Bridge=require('/lua/ge/extensions/bngUnderground/bridge')
local WorkshopBridge=require('/lua/ge/extensions/bngUnderground/workshopBridge')
local Onboarding=require('/lua/ge/extensions/bngUnderground/onboarding')
local M={}
function M.transform(upright)
  local vehicle=getPlayerVehicle(0)
  if not vehicle then return nil,'There is no campaign car to change.' end
  local p=vehicle:getPosition()
  local q=quatFromDir(vehicle:getDirectionVector(),upright and vec3(0,0,1) or vehicle:getDirectionVectorUp())
  return {pos={p.x,p.y,p.z},rot={q.x,q.y,q.z,q.w}}
end
function M.spawn(content,state,transform)
  local cfg,model=Bridge.configuration(content,state)
  if not cfg then return false,model end
  local options={config=cfg,pos=vec3(transform.pos),rot=quat(transform.rot),autoEnterVehicle=true,canSpawnAnotherVehicleCheck=false}
  local vehicle
  if getPlayerVehicle(0) then vehicle=core_vehicles.replaceVehicle(model,options)
  else vehicle=core_vehicles.spawnNewVehicle(model,options) end
  if not vehicle then return false,'BeamNG could not construct this car.' end
  return true,nil,vehicle:getId()
end
M.initialize=WorkshopBridge.initialize
function M.ready(content,state,id)
  local car=Onboarding.pending(state) and content.settings.introduction.car or state.activeCar
  return WorkshopBridge.ready(content,{activeCar=car},id)
end
function M.place(content,state,id,transform)
  if not M.ready(content,state,id) then return false,'The car is still initializing.' end
  local vehicle=getObjectByID(id)
  spawn.safeTeleport(vehicle,vec3(transform.pos),quat(transform.rot))
  return true
end
function M.focus(id)
  local vehicle=id and getObjectByID(id)
  if not vehicle or be:getPlayerVehicleID(0)~=id then return end
  commands.setGameCamera();core_camera.setByName(0,'orbit',false);core_camera.resetCamera(0)
  vehicle:queueLuaCommand('electrics.setLightsState(2)')
end
return M
