-- Compact session-only course projection. Native route generation is injected.
local U=require('/lua/ge/extensions/bngUnderground/util')
local M={maxPoints=12000}
local cached={}
local function finite(value) return type(value)=='number' and value==value and value~=math.huge and value~=-math.huge end
local function unavailable(event,reason,retryable)
  return {eventId=event.id,available=false,points={},reason=reason,retryable=retryable or false}
end
function M.clear() cached={} end
local function project(event,geometry)
  local out=U.copy(geometry)
  out.eventId=event.id;out.closed=event.course.layout=='Circuit';out.laps=event.course.laps
  return out
end
function M.get(event,provider)
  if not event.course or (event.missionType~='aiRace' and event.missionType~='timeTrial') then
    return unavailable(event,'This meet has no course outline. GPS still goes to its start.')
  end
  if event.course.branching then return unavailable(event,'This course has multiple branches. GPS still goes to its start.') end
  if type(event.missionId)~='string' or type(event.course.sourceSha256)~='string' then return unavailable(event,'Course outline could not be loaded. You can retry or set GPS.',true) end
  local key=event.missionId..'/'..event.course.sourceSha256
  if cached[key] then return project(event,cached[key]) end
  local ok,raw=pcall(provider,event,M.maxPoints)
  if not ok or type(raw)~='table' then return unavailable(event,'Course outline could not be loaded. You can retry or set GPS.',true) end
  if raw.mode=='none' then return unavailable(event,'This meet has no course outline. GPS still goes to its start.') end
  if (raw.mode~='road' and raw.mode~='checkpoints') or type(raw.points)~='table' or #raw.points>M.maxPoints then
    return unavailable(event,'Course outline could not be loaded. You can retry or set GPS.',true)
  end
  local points={}
  for index=1,#raw.points do
    local point=raw.points[index]
    if type(point)~='table' or not finite(point[1]) or not finite(point[2]) then
      return unavailable(event,'Course outline could not be loaded. You can retry or set GPS.',true)
    end
    local previous=points[#points]
    if not previous or previous[1]~=point[1] or previous[2]~=point[2] then points[#points+1]={point[1],point[2]} end
  end
  if #points<2 then return unavailable(event,'Course outline is not ready. You can retry or set GPS.',true) end
  local out={available=true,mode=raw.mode,points=points}
  cached[key]=out
  return project(event,out)
end
return M
