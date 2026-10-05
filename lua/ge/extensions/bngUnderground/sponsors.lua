local U = require('/lua/ge/extensions/bngUnderground/util')
local E = require('/lua/ge/extensions/bngUnderground/economy')
local G = require('/lua/ge/extensions/bngUnderground/garage')
local Inbox = require('/lua/ge/extensions/bngUnderground/inbox')
local P = require('/lua/ge/extensions/bngUnderground/progression')
local M = {}
local function count(events)
  local total=0
  for _,cleared in pairs(events or {}) do if cleared==true then total=total+1 end end
  return total
end
local function raceBonus(spec,purse) return math.floor(purse*spec.bonus) end
function M.validate(content,state)
  for id,completed in pairs(state.sponsorsCompleted) do
    if completed~=true or not content.sponsorsById[id] then return false,'Unknown completed sponsor contract.' end
  end
  local contract=state.sponsor
  if not contract then return true end
  if type(contract)~='table' or not content.sponsorsById[contract.id] or type(contract.events)~='table' then return false,'Invalid sponsor.' end
  local spec=content.sponsorsById[contract.id]
  if state.sponsorsCompleted[contract.id] or state.chapter<spec.chapter or count(contract.events)>=spec.wins then return false,'Invalid active contract progress.' end
  for id,cleared in pairs(contract.events) do
    local event=content.eventsById[id]
    if cleared~=true or not event or not U.contains(spec.kinds,event.kind) then return false,'Invalid qualifying sponsor clear.' end
  end
  return true
end
-- Preview and settlement share the same integer race-bonus formula. A replay
-- can advance a newly signed contract, but an already-delivered race cannot.
function M.preview(content,state,event,payout)
  local contract=state.sponsor
  local spec=contract and content.sponsorsById[contract.id]
  if not spec or not content.settings.features.sponsors or not U.contains(spec.kinds,event.kind) then return nil end
  local distinct=contract.events[event.id]~=true
  local completion=distinct and count(contract.events)+1>=spec.wins and spec.reward or 0
  local out={name=spec.name,rate=spec.bonus,newClear=distinct,completion=completion,medals={}}
  for medal,purse in pairs(payout.medals) do
    local bonus=raceBonus(spec,purse)
    out.medals[medal]={base=purse,bonus=bonus,completion=completion,total=purse+bonus+completion}
  end
  out.totalMin=out.medals[event.boss and 'gold' or 'bronze'].total;out.totalMax=out.medals.gold.total
  return out
end
function M.view(content,state)
  local rows={}
  for _,spec in ipairs(content.sponsors) do
    local row=U.copy(spec);row.active=state.sponsor and state.sponsor.id==spec.id or false
    row.completed=state.sponsorsCompleted[spec.id]==true
    row.clears=row.completed and spec.wins or (row.active and count(state.sponsor.events) or 0)
    row.remaining=math.max(0,spec.wins-row.clears);row.eventIds={};row.deliveredNames={}
    if not content.settings.features.sponsors then row.reason='Sponsorships are disabled.'
    elseif row.completed then row.reason='This contract is complete.'
    elseif row.active then row.reason='Your active contract. Choose any qualifying race below.'
    elseif state.sponsor then row.reason='Finish your active contract before signing another.'
    elseif state.chapter<spec.chapter then row.reason='Reach chapter '..spec.chapter..' to sign.'
    elseif G.style(state,content)<spec.style then row.reason='Your active car needs style level '..spec.style..' to sign.'
    else row.signable=true end
    for _,event in ipairs(content.events) do
      if U.contains(spec.kinds,event.kind) then
        local delivered=row.active and state.sponsor.events[event.id]==true
        if delivered then table.insert(row.deliveredNames,event.name)
        elseif P.canEnter(content,state,event.id) then table.insert(row.eventIds,event.id) end
      end
    end
    table.sort(row.eventIds,function(a,b)
      local ea,eb=content.eventsById[a],content.eventsById[b]
      return ea.chapter~=eb.chapter and ea.chapter>eb.chapter or ea.chapter==eb.chapter and ea.name<eb.name
    end)
    table.insert(rows,row)
  end
  return rows
end
function M.sign(content, state, id)
  if not content.settings.features.sponsors then return false, 'Sponsorships are disabled.' end
  local spec = content.sponsorsById[id]
  if not spec then return false, 'Unknown sponsor.' end
  if state.sponsor then return false, 'Finish your current contract first.' end
  if state.sponsorsCompleted[id] then return false, 'You have completed this contract.' end
  if state.chapter < spec.chapter then return false, 'Reach chapter '..spec.chapter..' first.' end
  if G.style(state,content) < spec.style then return false, 'Your active car needs style level '..spec.style..'.' end
  state.sponsor = {id=id, events={}}
  Inbox.add(state,{sender=spec.name,title='Welcome to the crew.',text='You are signed. Clear '..spec.wins..' different '..table.concat(spec.kinds,' / ')..' meets for $'..spec.reward..' at completion. Every qualifying clear adds '..math.floor(spec.bonus*100+0.5)..'% to its purse. Earlier meets count if you clear them again after signing; repeating a delivered meet earns the race bonus but no new contract progress.'})
  return true
end
function M.reward(content, state, event, purse)
  local contract = state.sponsor
  if not contract or not content.settings.features.sponsors then return 0 end
  local spec = content.sponsorsById[contract.id]
  if not spec or not U.contains(spec.kinds, event.kind) then return 0 end
  -- A distinct-event requirement prevents farming a contract with a single race.
  local bonus = raceBonus(spec,purse)
  E.credit(state, bonus, spec.name..' race bonus')
  contract.events[event.id] = true
  local completion=0
  if count(contract.events) >= spec.wins then
    E.credit(state, spec.reward, spec.name..' contract completed')
    state.sponsorsCompleted[spec.id] = true
    state.sponsor = nil
    Inbox.add(state, {sender=spec.name,title='Contract complete',text='You delivered. Your $'..spec.reward..' signing completion bonus is in the account.'})
    bonus=bonus+spec.reward
    completion=spec.reward
  end
  return bonus,{raceBonus=bonus-completion,completion=completion,name=spec.name}
end
return M
