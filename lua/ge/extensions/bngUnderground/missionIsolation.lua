-- Temporary in-memory mission policy. Stock files and saved mission progress are untouched.
local M = {}
local originals={}
function M.apply(content)
  local changed=false
  for _,mission in ipairs(gameplay_missions_missions.getAllMissions()) do
    local original=originals[mission.id]
    if not content.eventsByMission[mission.id] and mission.id:match('^'..content.settings.level..'/') and (not original or original.mission~=mission) then
      originals[mission.id]={mission=mission,visible=mission.careerSetup.showInFreeroam,start=mission.startCondition}
      mission.careerSetup.showInFreeroam=false
      mission.startCondition={type='bnguOutsideCampaign'}
      changed=true
    end
  end
  return changed
end
function M.restore()
  for _,original in pairs(originals) do
    original.mission.careerSetup.showInFreeroam=original.visible
    original.mission.startCondition=original.start
  end
  originals={}
end
function M.snapshot()
  local out={}
  for id,original in pairs(originals) do out[id]={visible=original.visible,start=original.start} end
  return out
end
function M.restoreSnapshot(data)
  for id,original in pairs(data or {}) do
    local mission=gameplay_missions_missions.getMissionById(id)
    if mission then originals[id]={mission=mission,visible=original.visible,start=original.start} end
  end
end
return M
