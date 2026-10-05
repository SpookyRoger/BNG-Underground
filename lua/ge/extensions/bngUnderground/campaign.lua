-- Pure campaign state machine. No engine calls; services are injected at the boundary.
local U = require('/lua/ge/extensions/bngUnderground/util')
local E = require('/lua/ge/extensions/bngUnderground/economy')
local P = require('/lua/ge/extensions/bngUnderground/progression')
local G = require('/lua/ge/extensions/bngUnderground/garage')
local S = require('/lua/ge/extensions/bngUnderground/sponsors')
local Onboarding = require('/lua/ge/extensions/bngUnderground/onboarding')
local Inbox = require('/lua/ge/extensions/bngUnderground/inbox')
local Tuning = require('/lua/ge/extensions/bngUnderground/tuning')
local Parts = require('/lua/ge/extensions/bngUnderground/parts')
local Content = require('/lua/ge/extensions/bngUnderground/content')
local Showcases = require('/lua/ge/extensions/bngUnderground/showcases')
local PaintShop = require('/lua/ge/extensions/bngUnderground/paintShop')
local Bodywork = require('/lua/ge/extensions/bngUnderground/bodywork')
local WorkshopBuilds = require('/lua/ge/extensions/bngUnderground/workshopBuilds')
local Results = require('/lua/ge/extensions/bngUnderground/raceResults')
local M = {}

function M.new(content, starter)
  if not starter then
    return {
      schema=content.settings.saveSchema,cash=content.settings.startingCash,chapter=1,rep=0,completed=false,activeCar=false,
      intro={stage='dealership'},garage={},events={},discovered={},showcases={},sponsorsCompleted={},
      receipts={},receiptOrder={},serial=0,lifetimeEarned=0,totalWins=0,ledger={},messageFlags={},messageSerial=0,
      inbox={{id='opening-drive',sender=content.settings.introduction.friend,title='Take my keys for tonight.',read=false,
        locationId=content.settings.introduction.dealership,text=content.settings.introduction.message}},
      preferences={night=true,minimap=true},lastResult=false,raceHistory={}
    }
  end
  if not U.contains(content.settings.starters, starter) then return nil, 'Choose an available starter.' end
  local car = content.vehiclesById[starter]
  local chapter = content.chapters[1]
  return {
    schema=content.settings.saveSchema, cash=content.settings.startingCash-car.price,
    chapter=1, rep=0, completed=false, activeCar=starter,
    garage={[starter]={tier=0,equippedTier=0,bodykit=false}},
    events={}, discovered={}, showcases={}, sponsorsCompleted={},
    receipts={}, receiptOrder={}, serial=0, lifetimeEarned=0, totalWins=0, messageSerial=0,
    ledger={{amount=-car.price,reason='First car / '..car.name}},
    inbox={{id='chapter-1-entry',sender=chapter.sender,title=chapter.name,text=chapter.intro,read=false}},
    preferences={night=true}, lastResult=false,raceHistory={}
  }
end

function M.validate(content, state)
  if type(state) ~= 'table' then return false, 'Save is not an object.' end
  if state.schema ~= content.settings.saveSchema then return false, 'Unsupported save version. Keep this save for a compatible release.' end
  if not U.money(state.cash) or not U.money(state.rep) or not U.money(state.serial) then return false, 'Invalid saved balances.' end
  if type(state.chapter)~='number' or state.chapter%1~=0 or not content.chaptersById[state.chapter] then return false, 'Invalid chapter.' end
  for _, key in ipairs({'garage','events','discovered','showcases','sponsorsCompleted','receipts','receiptOrder','ledger','inbox','preferences'}) do
    if type(state[key]) ~= 'table' then return false, 'Missing save field: '..key end
  end
  if Onboarding.pending(state) then
    if state.activeCar~=false or next(state.garage) or state.chapter~=1 or state.rep~=0 or next(state.events) or state.cash~=content.settings.startingCash then return false,'Invalid opening-drive state.' end
  elseif type(state.activeCar)~='string' or not state.garage[state.activeCar] or not content.vehiclesById[state.activeCar] then return false, 'Active car is missing.' end
  if state.preferences.streetTraffic~=nil and type(state.preferences.streetTraffic)~='boolean' then return false,'Invalid street traffic preference.' end
  if state.intro and (type(state.intro)~='table' or (state.intro.stage~='dealership' and state.intro.stage~='complete')) then return false,'Invalid introduction.' end
  if state.messageFlags and type(state.messageFlags)~='table' then return false,'Invalid message history.' end
  if state.messageSerial~=nil and not U.money(state.messageSerial) then return false,'Invalid message sequence.' end
  for id, car in pairs(state.garage) do
    if not content.vehiclesById[id] or type(car)~='table' or not U.money(car.tier) or car.tier>#content.settings.upgradeTiers then return false, 'Invalid garage entry: '..tostring(id) end
    local tier=car.equippedTier or car.tier
    if not U.money(tier) or tier>car.tier then return false, 'Invalid equipped package.' end
    if car.mode and car.mode~='grip' and car.mode~='drift' and car.mode~='drag' then return false,'Invalid build type.' end
    local paintOk,paintError=PaintShop.validate(content,car)
    if not paintOk then return false,paintError end
    if car.mode=='drift' and (not car.driftOwned or not content.vehiclesById[id].driftConfig) then return false, 'Drift build not owned.' end
    if car.mode=='drag' and (not car.dragOwned or not content.vehiclesById[id].dragConfig) then return false, 'Drag build not owned.' end
    local partsOk,partsError=Parts.validate(content,id,car)
    if not partsOk then return false,partsError end
    local bodyworkOk,bodyworkError=Bodywork.validate(content,id,car)
    if not bodyworkOk then return false,bodyworkError end
    local tuningOk,tuningError=Tuning.validate(content,id,car)
    if not tuningOk then return false,tuningError end
  end
  if not U.money(state.lifetimeEarned) or not U.money(state.totalWins) then return false, 'Invalid statistics.' end
  local sponsorOk,sponsorError=S.validate(content,state)
  if not sponsorOk then return false,sponsorError end
  local coverOk,coverError=Showcases.validate(content,state)
  if not coverOk then return false,coverError end
  for _,record in pairs(state.events) do
    if type(record)~='table' or not U.money(record.attempts) or not U.money(record.wins) then return false,'Invalid event record.' end
    if record.medal and record.medal~='bronze' and record.medal~='silver' and record.medal~='gold' then return false,'Invalid medal.' end
    for _,key in ipairs({'bestTime','bestScore'}) do
      local n=record[key]
      if n~=nil and (type(n)~='number' or n~=n or n<0 or n==math.huge) then return false,'Invalid result metric.' end
    end
  end
  local messageIds={}
  for _,entry in ipairs(state.inbox) do
    if type(entry)~='table' or type(entry.sender)~='string' or type(entry.title)~='string' or type(entry.text)~='string' then return false,'Invalid message.' end
    if entry.id and type(entry.id)~='string' then return false,'Invalid message identifier.' end
    -- Older schema-1 saves may have duplicate/missing IDs; Inbox.prepare repairs
    -- them after loading. New saves must persist an unambiguous message identity.
    if state.messageSerial~=nil and (not entry.id or messageIds[entry.id]) then return false,'Duplicate or missing message identifier.' end
    if entry.id then messageIds[entry.id]=true end
    if entry.eventId and not content.eventsById[entry.eventId] then return false,'Unknown invitation race.' end
    if entry.locationId and not content.locationsById[entry.locationId] then return false,'Unknown message destination.' end
    if entry.read~=nil and type(entry.read)~='boolean' then return false,'Invalid message read state.' end
  end
  for _,entry in ipairs(state.ledger) do
    if type(entry)~='table' or type(entry.reason)~='string' or type(entry.amount)~='number' or not U.money(math.abs(entry.amount)) then return false,'Invalid account entry.' end
  end
  for _,receipt in ipairs(state.receiptOrder) do if type(receipt)~='string' then return false,'Invalid receipt.' end end
  local resultsOk,resultsError=Results.validate(content,state)
  if not resultsOk then return false,resultsError end
  return true
end

function M.result(content, state, eventId, stars, receipt, metrics, nativeDate)
  local allowed, reason = P.canEnter(content, state, eventId)
  if not allowed then return false, reason end
  if type(receipt)~='string' or #receipt==0 then return false, 'Missing result receipt.' end
  if state.receipts[receipt] then return false, 'Result already recorded.' end
  local event = content.eventsById[eventId]
  local chapterBefore=state.chapter
  metrics=Results.metrics(metrics)
  stars=type(stars)=='table' and stars or {}
  local won = stars and stars[event.winStar] == true
  local record = state.events[event.id] or {attempts=0,wins=0}
  state.events[event.id] = record
  record.attempts = record.attempts+1
  state.receipts[receipt] = true
  table.insert(state.receiptOrder, receipt)
  if #state.receiptOrder > 512 then state.receipts[table.remove(state.receiptOrder,1)] = nil end
  if not won then
    state.lastResult={name=event.name,won=false,cash=0,rep=0,text='No entry fee lost. Try another meet, another build, or another line.'}
    Results.record(content,state,event,state.lastResult,receipt,metrics,nativeDate,chapterBefore)
    return true, state.lastResult
  end
  local first = not record.cleared
  local medal = stars[event.goldStar] and 'gold' or (stars[event.silverStar] and 'silver' or 'bronze')
  local purse = E.purse(content,event,first,medal)
  E.credit(state,purse,event.name..(first and ' / first clear' or ' / replay'))
  local rep = first and event.rep or 0
  state.rep=state.rep+rep; state.totalWins=state.totalWins+1
  record.cleared=true; record.wins=record.wins+1
  local rank={bronze=1,silver=2,gold=3}
  if not record.medal or rank[medal]>rank[record.medal] then record.medal=medal end
  if metrics.time then record.bestTime=math.min(record.bestTime or math.huge,metrics.time) end
  if metrics.score then record.bestScore=math.max(record.bestScore or 0,metrics.score) end
  local bonus,sponsorPayment=S.reward(content,state,event,purse)
  local message=first and P.advance(content,state,event) or nil
  if message then Inbox.add(state,message) end
  state.lastResult={name=event.name,won=true,cash=purse+bonus,basePurse=purse,sponsorPayment=sponsorPayment,rep=rep,medal=medal,first=first,chapter=state.chapter,
    text=message and message.title or (first and 'A new name on the board.' or 'Another night, another purse.')}
  Results.record(content,state,event,state.lastResult,receipt,metrics,nativeDate,chapterBefore)
  return true,state.lastResult
end

function M.discover(content,state,id)
  local site=content.locationsById[id]
  if not site or site.chapter>state.chapter then return false, 'Location unavailable.' end
  if not content.settings.features.discovery or state.discovered[id] then return false, 'Already discovered.' end
  state.discovered[id]=true;state.rep=state.rep+content.settings.discoveryRep
  Inbox.add(state,{sender='Mara',title=site.name,text=site.description})
  return true
end
function M.showcase(content,state,id)
  return Showcases.claim(content,state,id)
end

function M.command(content,state,action,arg)
  if action=='streetTraffic' then
    if content.settings.features.streetTraffic~=true then return false,'Campaign traffic is disabled in this build.' end
    if type(arg)~='boolean' then return false,'Choose whether campaign traffic is on or off.' end
    state.preferences.streetTraffic=arg;return true
  end
  if action=='readMessage' then return Inbox.read(state,arg) end
  if action=='readMessages' then return Inbox.readMany(state,arg) end
  if action=='minimap' then state.preferences.minimap=arg==true;return true end
  if action=='buyStarter' then return Onboarding.purchase(content,state,arg) end
  if action=='repair' then return E.repair(content,state) end
  if Onboarding.pending(state) and action~='night' then return false,'Choose your own car at Quarryside Auto Sales first.' end
  if action=='buyCar' then return G.buy(content,state,arg)
  elseif action=='selectCar' then
    if not state.garage[arg] then return false,'Car not owned.' end
    state.activeCar=arg;return true
  elseif action=='upgrade' then return G.upgrade(content,state)
  elseif action=='equip' then return G.equip(content,state,tonumber(arg))
  elseif action=='paint' then return G.paint(content,state,arg)
  elseif action=='bodykit' then return G.bodykit(content,state)
  elseif action=='toggleKit' then
    local car=state.garage[state.activeCar]
    if not car.bodykit then return false,'Style kit not owned.' end
    car.kitEquipped=car.kitEquipped==false;return true
  elseif action=='driftBuild' then return G.driftBuild(content,state)
  elseif action=='dragBuild' then return G.dragBuild(content,state)
  elseif action=='buyPart' then return Parts.buy(content,state,arg)
  elseif action=='fitPart' then return Parts.fit(content,state,arg)
  elseif action=='buyBodywork' then return Bodywork.buy(content,state,arg)
  elseif action=='fitBodywork' then return Bodywork.fit(content,state,arg)
  elseif action=='tune' then return Tuning.set(content,state,arg)
  elseif action=='resetTune' then return Tuning.reset(content,state,arg)
  elseif action=='signSponsor' then return S.sign(content,state,arg)
  elseif action=='tow' then return true,E.tow(content,state)
  elseif action=='showcase' then return M.showcase(content,state,arg)
  elseif action=='night' then state.preferences.night=arg==true;return true
  end
  return false,'Unknown campaign command.'
end

function M.view(content,state)
  local out=U.copy(state)
  out.raceHistory=nil;out.recentResults=Results.view(content,state)
  out.title=content.settings.title;out.version=content.settings.version
  out.chapterInfo=content.chaptersById[state.chapter]
  out.chapterWins=P.wins(content,state,state.chapter)
  out.chapterList=P.view(content,state)
  out.style=G.style(state,content);out.styleBreakdown=G.styleBreakdown(state,content);out.covers=Showcases.view(content,state);out.eventList={};out.vehicleList={}
  for _, event in ipairs(content.events) do
    local row=U.copy(event)
    row.unlocked,row.lockReason=P.canEnter(content,state,event.id)
    row.record=state.events[event.id]
    row.payout=E.preview(content,event,row.record)
    row.payout.sponsor=S.preview(content,state,event,row.payout)
    table.insert(out.eventList,row)
  end
  for _, spec in ipairs(content.vehicles) do
    local row=Content.vehicleView(spec);row.owned=state.garage[spec.id];row.unlocked=spec.chapter<=state.chapter
    table.insert(out.vehicleList,row)
  end
  out.locations=content.locations;out.sponsors=S.view(content,state)
  out.features=content.settings.features
  out.tuning=Tuning.view(content,state)
  out.parts=Parts.view(content,state)
  out.bodyworkShop=Bodywork.view(content,state)
  out.workshopBuilds=WorkshopBuilds.view(content,state)
  out.introduction=Onboarding.pending(state)
  out.dealership=content.locationsById[content.settings.introduction.dealership]
  out.startingCash=content.settings.startingCash;out.starters=content.settings.starters
  out.unreadMessages=Inbox.unread(state);out.latestMessage=nil
  for _,entry in ipairs(state.inbox) do if not entry.read then out.latestMessage=entry;break end end
  out.paints=content.settings.paints;out.upgradeTiers=content.settings.upgradeTiers
  out.paintShop=PaintShop.view(content)
  out.prices={paint=content.settings.resprayCost,bodykit=content.settings.styleKitCost,tow=content.settings.towCost,
    repair=out.introduction and 0 or content.settings.repairCost}
  out.receipts=nil;out.receiptOrder=nil
  return out
end
return M
