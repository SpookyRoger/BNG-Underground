local U = require('/lua/ge/extensions/bngUnderground/util')
local PaintShop = require('/lua/ge/extensions/bngUnderground/paintShop')
local Bodywork = require('/lua/ge/extensions/bngUnderground/bodywork')
local M = {}
-- Avoid copying the full native tuning/fitment catalogs for every UI refresh.
function M.vehicleView(spec)
  local row={}
  for key,value in pairs(spec) do
    if key~='tuning' and key~='partsCatalog' then row[key]=U.copy(value) end
  end
  return row
end
function M.load(reader)
  reader = reader or jsonReadFile
  local c = {}
  for _, key in ipairs({'settings','chapters','events','vehicles','sponsors','locations','invitations','workshopNotes','partsShop','paintShop','bodyworkShop','bodyworkCatalog'}) do
    c[key] = assert(reader('/gameplay/bngUnderground/'..key..'.json'), 'Missing BNG Underground catalog: '..key)
  end
  PaintShop.checkCatalog(c)
  if c.settings.features.liveWorkshop==true then
    c.workshopPresentation=assert(reader('/gameplay/bngUnderground/workshopPresentation.json'),'Missing workshop presentation')
    local w=c.workshopPresentation
    assert(w.version==1 and #w.views>0 and w.previewDelay>=0.2 and w.vehicleTimeout>=5 and w.statsTimeout>=1,'Invalid workshop timing')
    assert(w.cameraDistance>=3 and w.cameraDistance<=15 and math.abs(w.cameraOffsetX)<=0.4,'Invalid workshop camera')
    for _,view in ipairs(w.views) do assert(type(view.id)=='string' and type(view.name)=='string' and #view.rotation==3,'Invalid workshop view') end
  end
  for _, key in ipairs({'chapters','events','vehicles','sponsors','locations'}) do c[key..'ById'] = U.index(c[key]) end
  Bodywork.checkCatalog(c)
  if c.settings.features.streetTraffic==true then
    c.traffic=assert(reader('/gameplay/bngUnderground/traffic.json'),'Missing BNG Underground traffic catalog')
    assert(type(c.traffic.enabledByDefault)=='boolean' and type(c.traffic.vehicles)=='table' and #c.traffic.vehicles>0 and #c.traffic.vehicles<=6,'Invalid traffic population')
    for _,key in ipairs({'spawnTimeout','readyTimeout','existingTimeout'}) do
      local value=c.traffic[key];assert(type(value)=='number' and value==value and value>=5 and value<=300,'Invalid traffic timeout')
    end
    for _,vehicle in ipairs(c.traffic.vehicles) do
      assert(vehicle.model=='simple_traffic' and type(vehicle.config)=='string' and vehicle.config:match('^[%w_]+$') and not vehicle.config:find('parked'),'Invalid civilian traffic vehicle')
    end
  end
  c.eventsByMission = {}
  for _, e in ipairs(c.events) do
    assert(c.chaptersById[e.chapter] and U.money(e.reward) and U.money(e.rep), 'Invalid event: '..e.id)
    c.eventsByMission[e.missionId] = e
  end
  for _, chapter in ipairs(c.chapters) do
    local regular, bosses = 0, 0
    for _, e in ipairs(c.events) do
      if e.chapter == chapter.id then if e.boss then bosses = bosses+1 else regular = regular+1 end end
    end
    assert(bosses == 1 and regular >= chapter.requiredWins, 'Unreachable chapter: '..chapter.id)
  end
  for _, id in ipairs(c.settings.starters) do assert(c.vehiclesById[id], 'Missing starter') end
  for _,invite in ipairs(c.invitations) do assert(c.eventsById[invite.eventId] and c.chaptersById[invite.chapter], 'Invalid invitation: '..invite.id) end
  for _,note in ipairs(c.workshopNotes) do assert(c.chaptersById[note.chapter] and c.locationsById[note.locationId] and U.money(note.tier),'Invalid workshop note: '..note.id) end
  local categories=U.index(c.partsShop.categories)
  for _,car in ipairs(c.vehicles) do
    local ids={}
    for _,option in ipairs(car.partsCatalog and car.partsCatalog.options or {}) do
      assert(not ids[option.id] and categories[option.category] and c.chaptersById[option.chapter] and U.money(option.cost),'Invalid parts catalog')
      ids[option.id]=true
    end
  end
  assert(c.locationsById[c.settings.introduction.dealership] and c.vehiclesById[c.settings.introduction.car],'Missing introduction content')
  assert(U.money(c.settings.repairCost) and type(c.settings.workshopRadius)=='number' and c.settings.workshopRadius>0,'Invalid repair/workshop settings')
  return c
end
return M
