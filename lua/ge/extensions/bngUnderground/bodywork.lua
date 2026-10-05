-- Independent native cosmetic pieces. Catalog evidence never enters the profile.
local U=require('/lua/ge/extensions/bngUnderground/util')
local E=require('/lua/ge/extensions/bngUnderground/economy')
local M={}
function M.key(car)
  local build=(car.mode=='drift' or car.mode=='drag') and car.mode or tostring(car.equippedTier or car.tier or 0)
  return build..(car.bodykit and car.kitEquipped~=false and ':kit' or ':base')
end
function M.selections(car) return car and car.bodywork and car.bodywork[M.key(car)] or {} end
local function rows(content,id) return content.bodyworkByCar and content.bodyworkByCar[id] or {} end
local function ownsVariant(car,key)
  local build,kit=key:match('^([^:]+):([^:]+)$')
  if kit~='base' and kit~='kit' then return false end
  if kit=='kit' and not car.bodykit then return false end
  if build=='drift' then return car.driftOwned==true end
  if build=='drag' then return car.dragOwned==true end
  local tier=tonumber(build)
  return tier and tier%1==0 and tier>=0 and tier<=car.tier or false
end
function M.owned(content,car,option)
  if option.cost==0 or (car.bodyworkOwned and car.bodyworkOwned[option.id]) then return true end
  for key,patch in pairs(option.builds) do if patch.matchesBase and ownsVariant(car,key) then return true end end
  return false
end
function M.signature(content,id,car)
  local pieces={M.key(car)};local selected=M.selections(car)
  for _,category in ipairs(content.bodyworkShop.categories) do pieces[#pieces+1]=category.id..':'..(selected[category.id] or 'base') end
  return table.concat(pieces,'|')
end
function M.checkCatalog(content)
  local policy,catalog=content.bodyworkShop,content.bodyworkCatalog
  assert(policy.version==1 and catalog.version==1 and #policy.categories>0,'Invalid bodywork catalog')
  assert(#policy.gripBuilds==#content.settings.upgradeTiers+1 and policy.gripBuilds[1]=='stock','Invalid bodywork build order')
  for i,tier in ipairs(content.settings.upgradeTiers) do assert(policy.gripBuilds[i+1]==tier.id,'Bodywork build order differs from packages') end
  content.bodyworkCategories=U.index(policy.categories);content.bodyworkByCar={}
  for id,spec in pairs(content.vehiclesById) do
    local source=assert(catalog.cars[id],'Missing bodywork for '..id);local indexed={}
    for _,option in ipairs(source.options) do
      assert(not indexed[option.id] and content.bodyworkCategories[option.category] and U.money(option.cost) and content.chaptersById[option.chapter] and type(option.style)=='boolean','Invalid bodywork choice')
      assert(type(option.builds)=='table' and next(option.builds),'Bodywork needs native mounting evidence')
      indexed[option.id]=option
    end
    content.bodyworkByCar[id]=indexed
  end
end
local function selectionsValid(content,id,car,requireOwnership)
  if car.bodywork~=nil and type(car.bodywork)~='table' then return false,'Invalid fitted bodywork.' end
  for key,selected in pairs(car.bodywork or {}) do
    if type(key)~='string' or type(selected)~='table' or (requireOwnership and not ownsVariant(car,key)) then return false,'Bodywork base build is not owned.' end
    for category,idPart in pairs(selected) do
      local option=rows(content,id)[idPart];local patch=option and option.builds[key]
      if not content.bodyworkCategories[category] or not option or option.category~=category or not patch or patch.matchesBase then return false,'Bodywork does not fit its saved build.' end
      if requireOwnership and not M.owned(content,car,option) then return false,'Fitted bodywork is not owned.' end
    end
  end
  return true
end
function M.validate(content,id,car)
  if car.bodyworkOwned~=nil and type(car.bodyworkOwned)~='table' then return false,'Invalid bodywork inventory.' end
  for part,owned in pairs(car.bodyworkOwned or {}) do if owned~=true or not rows(content,id)[part] then return false,'Unknown owned bodywork.' end end
  return selectionsValid(content,id,car,true)
end
function M.validateRecord(content,id,car)
  if type(car.bodywork)=='table' then for key in pairs(car.bodywork) do if key~=M.key(car) then return false,'Featured bodywork belongs to another build.' end end end
  return selectionsValid(content,id,car,false)
end
function M.fittedCount(content,id,car)
  if not car or not content then return 0 end
  local count=0
  for _,part in pairs(M.selections(car)) do local option=rows(content,id)[part];if option and option.style then count=count+1 end end
  return count
end
local function change(content,state,arg,purchase,preview)
  if content.settings.features.bodywork==false then return false,'Individual bodywork is disabled.' end
  local car=state.garage[state.activeCar]
  if not car or type(arg)~='table' or arg.car~=state.activeCar or arg.build~=M.key(car) or arg.hardware~=M.signature(content,state.activeCar,car) then return false,'The bodywork changed. Review this car again.' end
  local category=content.bodyworkCategories[arg.category]
  if not category then return false,'Unknown bodywork category.' end
  local selected=M.selections(car);local option,patch
  if arg.part~='base' then
    option=rows(content,state.activeCar)[arg.part];patch=option and option.builds[arg.build]
    if not option or option.category~=arg.category or not patch then return false,'This piece does not fit the current body and build.' end
  end
  local nextPart=option and not patch.matchesBase and option.id or nil
  if selected[arg.category]==nextPart then
    if preview then return true end
    return false,'This bodywork is already fitted.'
  end
  if option then
    if not M.owned(content,car,option) then
      if not purchase and not preview then return false,'Buy this bodywork before fitting it.' end
      if not preview then
        if option.chapter>state.chapter then return false,'Unlocked in chapter '..option.chapter..'.' end
        local ok,err=E.debit(state,option.cost,option.name..' / '..state.activeCar)
        if not ok then return false,err end
      end
      car.bodyworkOwned=car.bodyworkOwned or {};car.bodyworkOwned[option.id]=true
    end
  end
  car.bodywork=car.bodywork or {};car.bodywork[arg.build]=car.bodywork[arg.build] or {}
  car.bodywork[arg.build][arg.category]=nextPart
  return true
end
function M.buy(content,state,arg) return change(content,state,arg,true,false) end
function M.fit(content,state,arg) return change(content,state,arg,false,false) end
function M.preview(content,state,arg)
  local proposed=U.copy(state);local ok,err=change(content,proposed,arg,false,true)
  return ok and proposed or nil,err
end
function M.apply(content,state,cfg)
  local car=state.garage[state.activeCar];local key=M.key(car)
  for _,part in pairs(M.selections(car)) do
    local option=rows(content,state.activeCar)[part];local patch=option and option.builds[key]
    if patch then cfg.parts=cfg.parts or {};for slot,native in pairs(patch.parts) do cfg.parts[slot]=native end end
  end
end
function M.view(content,state)
  local car=state.garage[state.activeCar]
  if not car or content.settings.features.bodywork==false then return nil end
  local key=M.key(car);local selected=M.selections(car)
  local out={car=state.activeCar,key=key,signature=M.signature(content,state.activeCar,car),categories={},selected=U.copy(selected),options={}}
  for _,category in ipairs(content.bodyworkShop.categories) do out.categories[#out.categories+1]={id=category.id,name=category.name,description=category.description} end
  for _,option in ipairs(content.bodyworkCatalog.cars[state.activeCar].options) do
    local patch=option.builds[key];local owned=M.owned(content,car,option)
    out.options[#out.options+1]={id=option.id,category=option.category,name=option.name,description=option.description,
      cost=owned and 0 or option.cost,owned=owned,compatible=patch~=nil,unlocked=owned or option.chapter<=state.chapter,chapter=option.chapter,
      fitted=patch~=nil and (selected[option.category]==option.id or (not selected[option.category] and patch.matchesBase)),
      partNames=patch and U.copy(patch.nativeNames) or {},style=option.style,base=patch and patch.matchesBase or false}
  end
  return out
end
return M
