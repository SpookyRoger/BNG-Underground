-- Independent component purchases and fitted choices. No game-engine calls.
local U=require('/lua/ge/extensions/bngUnderground/util')
local E=require('/lua/ge/extensions/bngUnderground/economy')
local M={}
function M.key(content,car)
  if car.mode=='drift' or car.mode=='drag' then return car.mode end
  local tier=car.equippedTier or car.tier or 0
  return tier==0 and 'stock' or content.settings.upgradeTiers[tier].id
end
local function ownsBuild(content,car,key)
  if key=='stock' then return true end
  for tier,package in ipairs(content.settings.upgradeTiers) do if package.id==key then return tier<=car.tier end end
  return false
end
local function optionById(spec,id)
  for _,option in ipairs(spec.partsCatalog and spec.partsCatalog.options or {}) do if option.id==id then return option end end
end
local function categoryById(content,id)
  for _,category in ipairs(content.partsShop.categories) do if category.id==id then return category end end
end
local function categoryEnabled(content,category)
  return not category.feature or content.settings.features[category.feature]~=false
end
local function tuningGroups(category) return category.tuningGroups or {category.tuningGroup} end
local function replacesGroup(category,group)
  for _,name in ipairs(tuningGroups(category)) do if name==group then return true end end
  return false
end
local function previewControl(control)
  return {id=control.id,label=control.label,group=control.group,min=control.min,max=control.max,
    baseline=control.baseline,step=control.step,scale=control.scale,unit=control.unit,display=U.copy(control.display)}
end
function M.owned(content,car,option)
  if car.partsOwned and car.partsOwned[option.id] then return true end
  for key,patch in pairs(option.builds) do if patch.matchesBase and ownsBuild(content,car,key) then return true end end
  return false
end
function M.selections(car,key) return car.parts and car.parts[key] or {} end
function M.signature(content,car,key)
  local pieces={key}
  local selected=M.selections(car,key)
  for _,category in ipairs(content.partsShop.categories) do
    if selected[category.id] then table.insert(pieces,category.id..':'..selected[category.id]) end
  end
  return table.concat(pieces,'|')
end
function M.controls(content,spec,car,key)
  local selected=M.selections(car,key);local replaced={};local extra={}
  for _,category in ipairs(content.partsShop.categories) do
    local option=optionById(spec,selected[category.id])
    if option and option.builds[key] then
      for _,group in ipairs(tuningGroups(category)) do replaced[group]=true end
      for _,control in ipairs(option.builds[key].controls) do table.insert(extra,control) end
    end
  end
  local controls={}
  for _,control in ipairs(spec.tuning and spec.tuning[key] and spec.tuning[key].controls or {}) do
    if not replaced[control.group] then table.insert(controls,control) end
  end
  for _,control in ipairs(extra) do table.insert(controls,control) end
  return controls
end
function M.validate(content,id,car)
  local spec=content.vehiclesById[id]
  if car.partsOwned~=nil and type(car.partsOwned)~='table' then return false,'Invalid parts inventory.' end
  for optionId,owned in pairs(car.partsOwned or {}) do
    if owned~=true or not optionById(spec,optionId) then return false,'Unknown owned parts.' end
  end
  if car.parts~=nil and type(car.parts)~='table' then return false,'Invalid fitted parts.' end
  for key,selected in pairs(car.parts or {}) do
    if not ownsBuild(content,car,key) or type(selected)~='table' then return false,'Parts base build is not owned.' end
    for group,optionId in pairs(selected) do
      local option=optionById(spec,optionId)
      if not categoryById(content,group) or not option or option.category~=group or not option.builds[key] then return false,'Parts do not fit this build.' end
      if not M.owned(content,car,option) then return false,'Fitted parts are not owned.' end
    end
  end
  return true
end
local function change(content,state,arg,purchase,preview)
  if content.settings.features.parts==false then return false,'Individual parts are disabled.' end
  local car=state.garage[state.activeCar];local spec=content.vehiclesById[state.activeCar]
  local key=M.key(content,car)
  if type(arg)~='table' or arg.build~=key or not spec.configs[key] then return false,'Choose a grip build before fitting parts.' end
  if arg.car~=nil and arg.car~=state.activeCar then return false,'The active car changed. Reopen Parts.' end
  if arg.hardware~=nil and arg.hardware~=M.signature(content,car,key) then return false,'The fitted parts changed. Review the comparison again.' end
  local category=categoryById(content,arg.category)
  if not category then return false,'Unknown parts category.' end
  if not categoryEnabled(content,category) then return false,category.name..' purchases and fitting are disabled.' end
  local selected=M.selections(car,key);local option
  if arg.part~='base' then
    option=optionById(spec,arg.part)
    if not option or option.category~=category.id or not option.builds[key] then return false,'These parts do not fit the active build.' end
    if selected[category.id]==option.id then return preview==true,'These parts are already fitted.' end
    if not selected[category.id] and option.builds[key].matchesBase then return preview==true,'The base build parts are already fitted.' end
    if not M.owned(content,car,option) then
      if not preview then
        if not purchase then return false,'Buy these parts before fitting them.' end
        if state.chapter<option.chapter then return false,'These parts unlock in chapter '..option.chapter..'.' end
        local ok,err=E.debit(state,option.cost,option.name..' / '..spec.name)
        if not ok then return false,err end
      end
      car.partsOwned=car.partsOwned or {};car.partsOwned[option.id]=true
    end
  elseif not selected[category.id] then return preview==true,'The base build parts are already fitted.' end
  -- Fitting hardware restores its declared groups. Other groups retain
  -- their saved tuning. Package changes keep an independent parts selection.
  if car.tuning and car.tuning[key] then
    for _,control in ipairs(M.controls(content,spec,car,key)) do
      if replacesGroup(category,control.group) then car.tuning[key][control.id]=nil end
    end
    if not next(car.tuning[key]) then car.tuning[key]=nil end
  end
  car.parts=car.parts or {};car.parts[key]=U.copy(selected)
  car.parts[key][category.id]=option and not option.builds[key].matchesBase and option.id or nil
  if not next(car.parts[key]) then car.parts[key]=nil end
  return true
end
function M.buy(content,state,arg) return change(content,state,arg,true) end
function M.fit(content,state,arg) return change(content,state,arg,false) end
-- A detached proposal only. Temporary ownership must never reach Storage.
function M.preview(content,state,arg)
  local proposed=U.copy(state)
  local ok,err=change(content,proposed,arg,false,true)
  if not ok then return nil,err end
  return proposed
end
function M.apply(content,state,cfg)
  local car=state.garage[state.activeCar];local spec=content.vehiclesById[state.activeCar]
  local key=M.key(content,car)
  for _,category in ipairs(content.partsShop.categories) do
    local option=optionById(spec,M.selections(car,key)[category.id])
    if option and option.builds[key] then
      local patch=option.builds[key];cfg.parts=cfg.parts or {};cfg.vars=cfg.vars or {}
      for slot,part in pairs(patch.parts) do cfg.parts[slot]=part end
      for slot,part in pairs(patch.preserveParts) do cfg.parts[slot]=part end
      for _,variable in ipairs(patch.clearVars) do cfg.vars[variable]=nil end
      for variable,value in pairs(patch.vars) do cfg.vars[variable]=value end
    end
  end
end
function M.view(content,state)
  if content.settings.features.parts==false then return nil end
  local car=state.garage[state.activeCar]
  if not car then return nil end
  local spec=content.vehiclesById[state.activeCar];local key=M.key(content,car)
  local out={key=key,car=state.activeCar,signature=M.signature(content,car,key),grip=spec.configs[key]~=nil,
    categories={},options={},selected=U.copy(M.selections(car,key))}
  local fittedControls=M.controls(content,spec,car,key)
  local baseControls=spec.tuning and spec.tuning[key] and spec.tuning[key].controls or {}
  local saved=car.tuning and car.tuning[key] or {}
  for _,category in ipairs(content.partsShop.categories) do
    if categoryEnabled(content,category) then
      local fitted=optionById(spec,out.selected[category.id])
      local row={id=category.id,name=category.name,description=category.description,resetGroups=U.copy(tuningGroups(category)),
        current={id=fitted and fitted.id or 'base',name=fitted and fitted.name or 'Base build hardware',controls={}},baseControls={},resetIds={}}
      -- The comparison uses the same group predicate as the actual hardware reset.
      for _,control in ipairs(fittedControls) do
        if replacesGroup(category,control.group) then
          local projected=previewControl(control);projected.savedValue=saved[control.id]
          table.insert(row.current.controls,projected)
          if saved[control.id]~=nil then table.insert(row.resetIds,control.id) end
        end
      end
      for _,control in ipairs(baseControls) do
        if replacesGroup(category,control.group) then table.insert(row.baseControls,previewControl(control)) end
      end
      table.insert(out.categories,row)
    end
  end
  for _,option in ipairs(spec.partsCatalog and spec.partsCatalog.options or {}) do
    if categoryEnabled(content,categoryById(content,option.category)) then
    local patch=option.builds[key];local selected=out.selected[option.category]
    local owned=M.owned(content,car,option)
    local row={id=option.id,category=option.category,name=option.name,description=option.description,cost=option.cost,
      chapter=option.chapter,owned=owned,compatible=patch~=nil,
      fitted=selected==option.id or (not selected and patch~=nil and patch.matchesBase),
      unlocked=owned or state.chapter>=option.chapter,partNames=patch and patch.partNames or {},engineName=option.engineName,controls={},adjustments={}}
    for _,control in ipairs(patch and patch.controls or {}) do
      table.insert(row.controls,control.label);table.insert(row.adjustments,previewControl(control))
    end
    table.insert(out.options,row)
    end
  end
  return out
end
return M
