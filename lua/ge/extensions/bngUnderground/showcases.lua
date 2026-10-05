-- Optional style features and build memories. Pure rules; engine access is injected.
local U=require('/lua/ge/extensions/bngUnderground/util')
local E=require('/lua/ge/extensions/bngUnderground/economy')
local G=require('/lua/ge/extensions/bngUnderground/garage')
local Inbox=require('/lua/ge/extensions/bngUnderground/inbox')
local PaintShop=require('/lua/ge/extensions/bngUnderground/paintShop')
local Bodywork=require('/lua/ge/extensions/bngUnderground/bodywork')
local M={}
local function siteById(content,id)
  local site=content.locationsById[id]
  return site and site.showcaseStyle and site or nil
end
local function finishExists(content,id)
  if id==false then return true end
  for _,finish in ipairs(content.settings.paints) do if finish.id==id then return true end end
  return false
end
local function snapshot(content,state)
  local car=state.garage[state.activeCar]
  return {car=state.activeCar,style=G.style(state,content),paint=car.paint or false,
    paintFinish=PaintShop.finishId(content,car),
    kit=car.bodykit and car.kitEquipped~=false or false,mode=car.mode or 'grip',tier=car.equippedTier or car.tier or 0,
    bodywork={[Bodywork.key(car)]=U.copy(Bodywork.selections(car))}}
end
function M.validate(content,state)
  for id,paid in pairs(state.showcases) do
    if not siteById(content,id) or type(paid)~='boolean' then return false,'Invalid cover-shoot history.' end
  end
  if state.coverRecords==nil then return true end -- earlier schema-1 flags remain valid
  if type(state.coverRecords)~='table' then return false,'Invalid cover build records.' end
  for id,record in pairs(state.coverRecords) do
    local site=siteById(content,id)
    if not site or state.showcases[id]~=true or type(record)~='table' then return false,'Cover record has no paid feature.' end
    local spec=content.vehiclesById[record.car]
    if not spec or not U.money(record.style) or record.style<site.showcaseStyle or record.style>4 then return false,'Invalid featured car/style.' end
    if not finishExists(content,record.paint) or type(record.kit)~='boolean' or not U.money(record.tier) or record.tier>#content.settings.upgradeTiers then return false,'Invalid featured finish/build.' end
    local paintOk,paintError=PaintShop.validate(content,{paint=record.paint,paintFinish=record.paintFinish})
    if not paintOk then return false,paintError end
    if record.mode~='grip' and record.mode~='drift' and record.mode~='drag' then return false,'Invalid featured build type.' end
    if record.mode~='grip' and not spec[record.mode..'Config'] then return false,'Featured specialist build is unavailable.' end
    local car={paint=record.paint,bodykit=record.kit,kitEquipped=true,mode=record.mode,tier=record.tier,equippedTier=record.tier,bodywork=record.bodywork}
    local bodyworkOk,bodyworkError=Bodywork.validateRecord(content,record.car,car)
    if not bodyworkOk then return false,bodyworkError end
    if G.style({activeCar=record.car,garage={[record.car]=car}},content)~=record.style then return false,'Featured style does not match its recorded build.' end
  end
  return true
end
local function describe(content,state,site)
  local style=G.style(state,content)
  local row={id=site.id,name=site.name,chapter=site.chapter,description=site.description,
    styleRequired=site.showcaseStyle,reward=site.showcaseReward,currentStyle=style,
    chapterOpen=site.chapter<=state.chapter,claimed=state.showcases[site.id]==true,
    record=U.copy(state.coverRecords and state.coverRecords[site.id]),eligible=false,ready=false}
  if not content.settings.features.showcases then row.reason='Cover shoots are disabled.'
  elseif row.claimed then row.reason='This cover shoot is already paid.'
  elseif not state.garage[state.activeCar] then row.reason='Buy your own starter before arranging a cover shoot.'
  elseif not row.chapterOpen then row.reason='Reach chapter '..site.chapter..' to arrange this feature.'
  elseif style<site.showcaseStyle then row.reason='Bring a car with style level '..site.showcaseStyle..'.'
  else row.eligible=true end
  return row
end
function M.context(content,state,id,distance,stopped,busy)
  local site=siteById(content,id)
  if not site then return {ready=false,eligible=false,reason='No cover shoot here.'} end
  local row=describe(content,state,site)
  local metres=distance and distance(site.pos) or math.huge
  row.distance=metres<math.huge and math.floor(metres) or nil
  row.near=metres<=content.settings.shopRadius
  if row.eligible then
    if busy then row.reason='Finish the current activity before arranging a cover shoot.'
    elseif not row.near then row.reason='Drive to '..site.name..' and park with your styled car.'
    elseif not stopped then row.reason='Stop your car at the feature location.'
    else row.ready=true end
  end
  return row
end
function M.claim(content,state,id)
  local site=siteById(content,id)
  if not site then return false,'No cover shoot here.' end
  local row=describe(content,state,site)
  if not row.eligible then return false,row.reason end
  state.showcases[id]=true;state.coverRecords=state.coverRecords or {}
  state.coverRecords[id]=snapshot(content,state)
  E.credit(state,site.showcaseReward,'Cover shoot / '..site.name)
  Inbox.add(state,{sender='Lumen Magazine',title='On the cover: '..site.name,locationId=id,
    text='Your '..content.vehiclesById[state.activeCar].name..' made the cut. $'..site.showcaseReward..' has been paid.'})
  return true
end
function M.view(content,state)
  if not content.settings.features.showcases then return nil end
  local rows={}
  for _,site in ipairs(content.locations) do if site.showcaseStyle then table.insert(rows,describe(content,state,site)) end end
  table.sort(rows,function(a,b) return a.chapter==b.chapter and a.name<b.name or a.chapter<b.chapter end)
  return rows
end
return M
