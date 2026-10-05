-- Native map-preview adapter. Does not start a mission, spawn a car or change GPS.
local M={}
function M.read(event,maxPoints)
  local mission=assert(gameplay_missions_missions.getMissionById(event.missionId),'Mission preview unavailable')
  assert(mission.missionType==event.missionType and type(mission.getWorldPreviewRoute)=='function','Mission preview type changed')
  local mode=mission.missionTypeData.mapPreviewMode or 'navgraph'
  if mode=='none' then return {mode='none',points={}} end
  assert(mode=='navgraph' or mode=='waypoints','Unknown native preview mode')
  local native=mission:getWorldPreviewRoute()
  assert(type(native)=='table','Native preview is not ready')
  assert(#native<=maxPoints,'Native preview exceeds the display budget')
  local points={}
  for _,node in ipairs(native) do
    local pos=assert(node.pos,'Native preview point is missing')
    points[#points+1]={pos.x or pos[1],pos.y or pos[2]}
  end
  return {mode=mode=='waypoints' and 'checkpoints' or 'road',points=points}
end
return M
