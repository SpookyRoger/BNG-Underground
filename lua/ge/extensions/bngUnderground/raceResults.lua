-- Bounded, optional race journal. Actual settlement supplies rewards; this module
-- never awards money, advances chapters, starts missions or calls the engine.
local U = require('/lua/ge/extensions/bngUnderground/util')
local M = {limit=40}
local medals={bronze=true,silver=true,gold=true}
local modes={grip=true,drift=true,drag=true}
local function finite(n) return type(n)=='number' and n==n and n>=0 and n<1e9 end
local function text(s) return type(s)=='string' and #s>0 and #s<=1024 end
local function date(n) return type(n)=='number' and n==n and n>0 and n<1e11 and n%1==0 end

function M.metrics(raw)
  raw=type(raw)=='table' and raw or {}
  local clean={}
  if finite(raw.time) and raw.time>0 then clean.time=raw.time end
  if finite(raw.score) then clean.score=raw.score end
  if finite(raw.place) and raw.place>=1 and raw.place%1==0 then clean.place=raw.place end
  return clean
end

function M.record(content,state,event,result,receipt,metrics,nativeDate,chapterBefore)
  if content.settings.features.results~=true then return end
  local car=state.garage[state.activeCar]
  local entry={id=receipt,eventId=event.id,carId=state.activeCar,mode=car.mode or 'grip',
    tier=car.equippedTier or car.tier or 0,attempt=state.events[event.id].attempts,
    won=result.won==true,first=result.first==true,medal=result.medal or false,
    cash=result.cash,basePurse=result.basePurse or 0,rep=result.rep,
    sponsorPayment=U.copy(result.sponsorPayment or false),text=result.text,
    chapterBefore=chapterBefore,chapterAfter=state.chapter,completed=state.completed==true,
    metrics=M.metrics(metrics)}
  if date(nativeDate) then entry.date=nativeDate end
  state.raceHistory=state.raceHistory or {}
  U.push(state.raceHistory,entry,M.limit)
end

function M.validate(content,state)
  local history=state.raceHistory
  if history==nil then return true end -- Schema-1 saves have no invented old runs.
  if type(history)~='table' or #history>M.limit then return false,'Invalid race history.' end
  local count,ids=0,{}
  for key,entry in pairs(history) do
    count=count+1
    if type(key)~='number' or key%1~=0 or key<1 or key>#history or type(entry)~='table' then return false,'Invalid race history order.' end
    if not text(entry.id) or ids[entry.id] or not content.eventsById[entry.eventId] or not content.vehiclesById[entry.carId]
      or not state.garage[entry.carId] then return false,'Invalid race history identity.' end
    ids[entry.id]=true
    local spec=content.vehiclesById[entry.carId]
    if not modes[entry.mode] or not U.money(entry.tier) or entry.tier>#content.settings.upgradeTiers
      or (entry.mode=='drift' and not spec.driftConfig) or (entry.mode=='drag' and not spec.dragConfig) then return false,'Invalid recorded build.' end
    if not U.money(entry.attempt) or entry.attempt<1 or type(entry.won)~='boolean' or type(entry.first)~='boolean'
      or type(entry.completed)~='boolean' or not text(entry.text) then return false,'Invalid recorded outcome.' end
    local record=state.events[entry.eventId]
    if not record or entry.attempt>record.attempts then return false,'Race history has no matching attempt.' end
    if not U.money(entry.chapterBefore) or not content.chaptersById[entry.chapterBefore] or not U.money(entry.chapterAfter)
      or not content.chaptersById[entry.chapterAfter] or entry.chapterAfter<entry.chapterBefore or entry.chapterAfter>entry.chapterBefore+1 then return false,'Invalid recorded progression.' end
    if entry.date~=nil and not date(entry.date) then return false,'Invalid native result date.' end
    if not U.money(entry.cash) or not U.money(entry.basePurse) or not U.money(entry.rep) then return false,'Invalid recorded rewards.' end
    local bonus=0
    if entry.sponsorPayment~=false then
      local sponsor=entry.sponsorPayment
      if type(sponsor)~='table' or not text(sponsor.name) or not U.money(sponsor.raceBonus) or not U.money(sponsor.completion) then return false,'Invalid recorded sponsor payment.' end
      bonus=sponsor.raceBonus+sponsor.completion
    end
    if entry.cash~=entry.basePurse+bonus then return false,'Recorded rewards do not add up.' end
    if entry.won then
      if not medals[entry.medal] or (not entry.first and entry.rep~=0) then return false,'Invalid recorded clear.' end
    elseif entry.first or entry.medal~=false or entry.cash~=0 or entry.rep~=0 or entry.sponsorPayment~=false then return false,'Invalid recorded retry.' end
    if type(entry.metrics)~='table' then return false,'Invalid recorded measurements.' end
    for key,n in pairs(entry.metrics) do
      if (key~='time' and key~='score' and key~='place') or not finite(n)
        or (key=='time' and n<=0) or (key=='place' and (n<1 or n%1~=0)) then return false,'Invalid recorded measurement.' end
    end
  end
  if count~=#history then return false,'Invalid race history order.' end
  return true
end

function M.view(content,state)
  if content.settings.features.results~=true then return {} end
  local out={}
  for _,saved in ipairs(state.raceHistory or {}) do
    local row=U.copy(saved)
    local event=content.eventsById[row.eventId]
    row.name=event.name;row.kind=event.kind;row.missionType=event.missionType
    row.carName=content.vehiclesById[row.carId].name
    row.buildName=row.mode=='grip' and (row.tier==0 and 'Stock' or content.settings.upgradeTiers[row.tier].name)
      or (row.mode=='drift' and 'Drift build' or 'Drag build')
    row.chapterName=content.chaptersById[row.chapterAfter].name
    table.insert(out,row)
  end
  return out
end
return M
