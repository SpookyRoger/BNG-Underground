-- Pure native-variable tuning policy. Each car/build owns independent overrides.
local U = require('/lua/ge/extensions/bngUnderground/util')
local Parts = require('/lua/ge/extensions/bngUnderground/parts')
local M = {}
function M.key(content,car)
  return Parts.key(content,car)
end
local function finite(value)
  return type(value)=='number' and value==value and value~=math.huge and value~=-math.huge
end
local function controls(content,spec,car,key)
  local indexed={}
  for _,control in ipairs(Parts.controls(content,spec,car,key)) do indexed[control.id]=control end
  return indexed
end
local function checkValues(content,spec,car,key,values)
  if type(values)~='table' or not (spec.tuning and spec.tuning[key]) then return false,'Unknown tuning setup.' end
  local indexed=controls(content,spec,car,key)
  for id,value in pairs(values) do
    local control=indexed[id]
    if not control or not finite(value) or value<control.min or value>control.max then
      return false,'Tuning value is outside the fitted hardware range: '..tostring(id)
    end
  end
  return true
end
function M.savedSignature(content,state)
  local car=state.garage[state.activeCar];local key=M.key(content,car)
  local pieces={state.activeCar,Parts.signature(content,car,key)};local ids={}
  local values=car.tuning and car.tuning[key] or {}
  for id in pairs(values) do ids[#ids+1]=id end
  table.sort(ids)
  for _,id in ipairs(ids) do pieces[#pieces+1]=id..'='..string.format('%.17g',values[id]) end
  return table.concat(pieces,'|')
end
function M.validate(content,id,car)
  if car.tuning==nil then return true end -- older schema-1 builds retain their preset
  if type(car.tuning)~='table' then return false,'Invalid saved tuning.' end
  local spec=content.vehiclesById[id]
  for key,values in pairs(car.tuning) do
    if key~='stock' then
      local owned=key=='drift' and car.driftOwned or key=='drag' and car.dragOwned
      for tier,package in ipairs(content.settings.upgradeTiers) do if package.id==key and tier<=car.tier then owned=true end end
      if not owned then return false,'Tuning setup is not owned.' end
    end
    local ok,err=checkValues(content,spec,car,key,values)
    if not ok then return false,err end
  end
  return true
end
function M.set(content,state,arg)
  if content.settings.features.tuning==false then return false,'Workshop tuning is disabled.' end
  local car=state.garage[state.activeCar]
  local key=M.key(content,car)
  if type(arg)~='table' or arg.build~=key then return false,'The fitted build changed. Reopen Tuning.' end
  if arg.car~=nil and arg.car~=state.activeCar then return false,'The active car changed. Reopen Tuning.' end
  if arg.saved~=nil and arg.saved~=M.savedSignature(content,state) then return false,'The saved setup changed. Review Tuning again.' end
  local signature=Parts.signature(content,car,key)
  if (arg.hardware~=nil and arg.hardware~=signature) or (arg.hardware==nil and signature~=key) then return false,'The fitted parts changed. Reopen Tuning.' end
  local spec=content.vehiclesById[state.activeCar]
  local ok,err=checkValues(content,spec,car,key,arg.values)
  if not ok then return false,err end
  car.tuning=car.tuning or {}
  -- Store only deviations. An empty override restores the actual preset.
  local values={}
  local indexed=controls(content,spec,car,key)
  for id,value in pairs(arg.values) do if math.abs(value-indexed[id].baseline)>0.0000001 then values[id]=value end end
  car.tuning[key]=next(values) and values or nil
  return true
end
function M.preview(content,state,arg)
  if content.settings.features.liveTuning~=true then return nil,'Live workshop tuning is disabled.' end
  local car=state.garage[state.activeCar]
  if not car or type(arg)~='table' or arg.car~=state.activeCar or arg.hardware~=Parts.signature(content,car,M.key(content,car)) or arg.saved~=M.savedSignature(content,state) then return nil,'The fitted car or setup changed. Review Tuning again.' end
  local proposed=U.copy(state);local ok,err=M.set(content,proposed,arg)
  return ok and proposed or nil,err
end
function M.reset(content,state,arg)
  if content.settings.features.tuning==false then return false,'Workshop tuning is disabled.' end
  local car=state.garage[state.activeCar]
  if arg~=M.key(content,car) then return false,'The fitted build changed. Reopen Tuning.' end
  if car.tuning then car.tuning[arg]=nil end
  return true
end
function M.apply(content,state,cfg)
  local car=state.garage[state.activeCar]
  local values=car.tuning and car.tuning[M.key(content,car)]
  if values then
    cfg.vars=cfg.vars or {}
    local indexed=controls(content,content.vehiclesById[state.activeCar],car,M.key(content,car))
    for id,value in pairs(values) do
      cfg.vars[id]=value
      local control=indexed[id]
      -- One saved/UI setting applies identical ratios to both native AWD axles.
      for _,linkedId in ipairs(control and control.linkedIds or {}) do cfg.vars[linkedId]=value end
    end
  end
end
function M.view(content,state)
  if content.settings.features.tuning==false then return nil end
  local car=state.garage[state.activeCar]
  if not car then return nil end
  local key=M.key(content,car)
  local spec=content.vehiclesById[state.activeCar]
  local out={car=state.activeCar,key=key,signature=Parts.signature(content,car,key),savedSignature=M.savedSignature(content,state),controls={}}
  for _,control in ipairs(Parts.controls(content,spec,car,key)) do
    local row=U.copy(control);row.source=nil;row.linkedSources=nil
    table.insert(out.controls,row)
  end
  return out
end
return M
