-- Native run attribution only. Engine gates, vehicles, rewards and UI belong to
-- their adapters/rules. Persist a new serial after an actual start, including retry.
local U=require('/lua/ge/extensions/bngUnderground/util')
local P=require('/lua/ge/extensions/bngUnderground/progression')
local M={}
function M.matches(state,current)
  local car=state.garage[state.activeCar]
  return current and car and current.serial==state.serial and current.car==state.activeCar
    and current.mode==(car.mode or 'grip') and current.tier==(car.equippedTier or car.tier or 0) or false
end
function M.started(content,state,current,missionId,commit)
  local event=content.eventsByMission[missionId]
  if not event then return false,'Choose a BNG Underground race.' end
  local allowed,reason=P.canEnter(content,state,event.id)
  if not allowed then return false,reason end
  local car=state.garage[state.activeCar]
  if not car then return false,'Race in your active owned car.' end
  if current and current.missionId==missionId and current.serial==state.serial then
    if not M.matches(state,current) then return false,'The active paid build changed during this race. Return to the city and try again.' end
    return true,U.copy(current),false -- repeated native started notification
  end
  local nextState=U.copy(state);nextState.serial=nextState.serial+1
  if not U.money(nextState.serial) then return false,'The campaign race sequence could not be saved.' end
  local ok,saved=pcall(commit,nextState)
  if not ok or saved~=true then return false,'The race could not be tracked in the saved campaign. Return to the city and try again.' end
  return true,{missionId=missionId,event=event.id,serial=nextState.serial,car=state.activeCar,
    mode=car.mode or 'grip',tier=car.equippedTier or car.tier or 0},true
end
function M.stopped(current,missionId)
  if current and current.missionId~=missionId then return current end
end
function M.receipt(current,missionId,attempt)
  if not current or current.missionId~=missionId or type(attempt)~='table' then return nil end
  if current.receipt then return current.receipt end -- one paid settlement per native run
  local metrics=type(attempt.data)=='table' and attempt.data or {}
  return table.concat({current.serial,current.event,tostring(attempt.date),tostring(metrics.time),tostring(metrics.score),tostring(metrics.place)},':')
end
function M.restore(content,state,snapshot,foreground)
  if type(snapshot)~='table' or not U.money(snapshot.serial) or snapshot.serial<1 or snapshot.serial~=state.serial then return nil end
  local event=content.eventsById[snapshot.event]
  if not event or event.missionId~=foreground or (snapshot.missionId and snapshot.missionId~=event.missionId) then return nil end
  if not P.canEnter(content,state,event.id) or (snapshot.car and snapshot.car~=state.activeCar) then return nil end
  local car=state.garage[state.activeCar]
  if not car then return nil end
  local mode,tier=car.mode or 'grip',car.equippedTier or car.tier or 0
  if (snapshot.mode and snapshot.mode~=mode) or (snapshot.tier and snapshot.tier~=tier) then return nil end
  if snapshot.receipt~=nil and (type(snapshot.receipt)~='string' or state.receipts[snapshot.receipt]~=true) then return nil end
  return {missionId=event.missionId,event=event.id,serial=snapshot.serial,car=state.activeCar,mode=mode,tier=tier,receipt=snapshot.receipt}
end
return M
