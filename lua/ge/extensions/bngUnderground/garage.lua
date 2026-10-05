local E = require('/lua/ge/extensions/bngUnderground/economy')
local Tuning = require('/lua/ge/extensions/bngUnderground/tuning')
local Parts = require('/lua/ge/extensions/bngUnderground/parts')
local PaintShop = require('/lua/ge/extensions/bngUnderground/paintShop')
local Bodywork = require('/lua/ge/extensions/bngUnderground/bodywork')
local M = {}
local function styleFlags(car,content,id)
  if not car then return false,false,false end
  local gripHardware = (not car.mode or car.mode == 'grip') and (car.equippedTier or car.tier or 0) >= 2
  local personalized=Bodywork.fittedCount(content,id,car)>=2
  return car.paint and true or false,(car.bodykit and car.kitEquipped~=false or personalized) and true or false,gripHardware
end
function M.style(state,content)
  local paint,kit,grip=styleFlags(state.garage[state.activeCar],content,state.activeCar)
  return (paint and 1 or 0)+(kit and 2 or 0)+(grip and 1 or 0)
end
function M.styleBreakdown(state,content)
  local paint,kit,grip=styleFlags(state.garage[state.activeCar],content,state.activeCar)
  return {
    {id='paint',name='Campaign finish',points=1,active=paint,description='A purchased respray fitted to this car.'},
    {id='kit',name='Personalized bodywork',points=2,active=kit,description='Fit an owned style kit or at least two custom bodywork groups. Factory pieces add no points; the kit and pieces share this two-point allowance.'},
    {id='grip',name='Club / Pro grip build',points=1,active=grip,description='Fit an owned Club or Pro grip package. Drift and drag builds do not add this point.'}
  }
end
function M.buy(content, state, id)
  local car = content.vehiclesById[id]
  if not car then return false, 'Unknown car.' end
  if state.garage[id] then return false, 'You already own this car.' end
  if car.chapter > state.chapter then return false, 'Reach chapter '..car.chapter..' first.' end
  local ok, err = E.debit(state, car.price, 'Bought '..car.name)
  if not ok then return false, err end
  state.garage[id] = {tier=0, equippedTier=0, bodykit=false}
  state.activeCar = id
  return true
end
function M.upgrade(content, state)
  local car = state.garage[state.activeCar]
  local tier = content.settings.upgradeTiers[car.tier+1]
  if not tier then return false, 'This car already has every package.' end
  if state.chapter < tier.chapter then return false, 'Unlocked in chapter '..tier.chapter..'.' end
  local ok, err = E.debit(state, tier.cost, tier.name..' / '..state.activeCar)
  if not ok then return false, err end
  car.tier = car.tier+1; car.equippedTier = car.tier
  car.mode = 'grip'
  return true
end
function M.equip(content, state, tier)
  local car = state.garage[state.activeCar]
  if type(tier) ~= 'number' or tier % 1 ~= 0 or tier < 0 or tier > car.tier then return false, 'Package not owned.' end
  car.equippedTier = tier
  car.mode = 'grip'
  return true
end
function M.driftBuild(content, state)
  local car = state.garage[state.activeCar]
  local spec = content.vehiclesById[state.activeCar]
  if not spec.driftConfig then return false, 'This workshop has no drift conversion for this model.' end
  if not car.driftOwned then
    local ok, err = E.debit(state, spec.driftCost, 'Drift build / '..spec.name)
    if not ok then return false, err end
    car.driftOwned = true
  end
  car.mode = 'drift'
  return true
end
function M.dragBuild(content, state)
  local car = state.garage[state.activeCar]
  local spec = content.vehiclesById[state.activeCar]
  if not spec.dragConfig then return false, 'No drag conversion is offered for this model.' end
  if state.chapter < 2 then return false, 'Specialist drag builds unlock in chapter 2.' end
  if not car.dragOwned then
    local ok, err = E.debit(state, spec.dragCost, 'Drag build / '..spec.name)
    if not ok then return false, err end
    car.dragOwned = true
  end
  car.mode = 'drag'
  return true
end
function M.paint(content, state, id)
  return PaintShop.purchase(content,state,id)
end
function M.bodykit(content, state)
  local car = state.garage[state.activeCar]
  if car.bodykit then return false, 'Style kit already owned.' end
  if not next(content.vehiclesById[state.activeCar].styleParts or {}) then return false, 'No kit available for this car.' end
  local ok, err = E.debit(state, content.settings.styleKitCost, 'Style kit / '..state.activeCar)
  if not ok then return false, err end
  car.bodykit = true; car.kitEquipped = true
  return true
end
function M.configuration(content, state, readConfig)
  local spec = content.vehiclesById[state.activeCar]
  local car = state.garage[state.activeCar]
  local tier = car.equippedTier or car.tier
  local key = tier == 0 and 'stock' or content.settings.upgradeTiers[tier].id
  local configName = car.mode == 'drift' and car.driftOwned and spec.driftConfig or spec.configs[key]
  if car.mode == 'drag' and car.dragOwned then configName = spec.dragConfig end
  local path = '/vehicles/'..spec.model..'/'..configName..'.pc'
  local cfg = readConfig(path)
  if not cfg then return nil, 'Missing stock configuration: '..path end
  if not cfg.parts and not cfg.vehicles then
    local parts={}
    for slot,part in pairs(cfg) do if type(part)=='string' then parts[slot]=part end end
    cfg = {parts=parts,vars=cfg.vars}
  end
  cfg.format=nil
  Parts.apply(content,state,cfg)
  Tuning.apply(content,state,cfg)
  if car.bodykit and car.kitEquipped ~= false then
    cfg.parts = cfg.parts or {}
    for slot, part in pairs(spec.styleParts or {}) do cfg.parts[slot] = part end
  end
  Bodywork.apply(content,state,cfg)
  local paintOk,paintError=PaintShop.apply(content,car,cfg)
  if not paintOk then return nil,paintError end
  return cfg, spec.model
end
return M
