-- Detached fitting proposals and exact comparisons. No engine or storage access.
local U=require('/lua/ge/extensions/bngUnderground/util')
local Parts=require('/lua/ge/extensions/bngUnderground/parts')
local Paint=require('/lua/ge/extensions/bngUnderground/paintShop')
local Bodywork=require('/lua/ge/extensions/bngUnderground/bodywork')
local Tuning=require('/lua/ge/extensions/bngUnderground/tuning')
local Builds=require('/lua/ge/extensions/bngUnderground/workshopBuilds')
local M={}
function M.equal(a,b)
  if type(a)~=type(b) then return false end
  if type(a)~='table' then return a==b end
  for k,v in pairs(a) do if not M.equal(v,b[k]) then return false end end
  for k in pairs(b) do if a[k]==nil then return false end end
  return true
end
function M.propose(content,state,request)
  if type(request)~='table' or request.car~=state.activeCar or not state.garage[state.activeCar] then return nil,'The active car changed. Enter the workshop again.' end
  local kind,arg=request.kind,U.copy(request.argument)
  local car=state.garage[state.activeCar]
  local proposed,err,action,label,cost,fitted,allowed
  if kind=='saved' then
    proposed=U.copy(state);label='Fitted car';cost=0;fitted=true;allowed=true
  elseif kind=='build' then
    local row
    proposed,row=Builds.preview(content,state,arg)
    if not proposed then return nil,row end
    action=row.action;arg=row.argument;label=row.name;cost=row.cost;fitted=row.fitted;allowed=row.unlocked
  elseif kind=='part' then
    local view=Parts.view(content,state)
    if not view or type(arg)~='table' or arg.car~=view.car or arg.hardware~=view.signature or arg.build~=view.key then return nil,'The fitted hardware changed. Choose the part again.' end
    local row
    if arg.part=='base' then
      for _,category in ipairs(view.categories) do
        if category.id==arg.category then row={name='Base '..category.name,owned=true,compatible=view.grip,unlocked=true,fitted=not view.selected[arg.category],cost=0} end
      end
    else
      for _,option in ipairs(view.options) do if option.id==arg.part and option.category==arg.category then row=option end end
    end
    if not row or not row.compatible then return nil,'This hardware does not fit your current build.' end
    proposed,err=Parts.preview(content,state,arg)
    action=row.owned and 'fitPart' or 'buyPart';label=row.name
    cost=row.owned and 0 or row.cost;fitted=row.fitted;allowed=row.unlocked
  elseif kind=='bodywork' then
    local view=Bodywork.view(content,state)
    if not view or type(arg)~='table' or arg.car~=view.car or arg.hardware~=view.signature or arg.build~=view.key then return nil,'The fitted bodywork changed. Choose the piece again.' end
    local row
    if arg.part=='base' then
      for _,category in ipairs(view.categories) do if category.id==arg.category then row={name='Equipped-build '..category.name,owned=true,compatible=true,unlocked=true,fitted=not view.selected[arg.category],cost=0} end end
    else
      for _,option in ipairs(view.options) do if option.id==arg.part and option.category==arg.category then row=option end end
    end
    if not row or not row.compatible then return nil,'This bodywork does not fit your current body and build.' end
    proposed,err=Bodywork.preview(content,state,arg)
    action=row.owned and 'fitBodywork' or 'buyBodywork';label=row.name
    cost=row.cost;fitted=row.fitted;allowed=row.unlocked
  elseif kind=='tuning' then
    proposed,err=Tuning.preview(content,state,arg)
    action='tune';label='Workshop setup';cost=0;allowed=true
    if proposed then
      local key=Tuning.key(content,car)
      fitted=M.equal(proposed.garage[state.activeCar].tuning and proposed.garage[state.activeCar].tuning[key] or {},car.tuning and car.tuning[key] or {})
    end
  elseif kind=='paint' then
    if type(arg)~='table' then return nil,'Choose a colour and finish.' end
    proposed,err=Paint.preview(content,state,arg)
    action='paint';label='Respray';cost=content.settings.resprayCost;allowed=true
    fitted=arg.colour==car.paint and arg.finish==Paint.finishId(content,car)
  elseif kind=='style' then
    if type(arg)~='boolean' or not next(content.vehiclesById[state.activeCar].styleParts or {}) then return nil,'No style kit is available for this car.' end
    proposed=U.copy(state)
    proposed.garage[state.activeCar].bodykit=arg or car.bodykit
    proposed.garage[state.activeCar].kitEquipped=arg
    action=car.bodykit and 'toggleKit' or 'bodykit';label=arg and 'Style kit' or 'Original bodywork'
    cost=car.bodykit and 0 or content.settings.styleKitCost;allowed=true
    fitted=arg==(car.bodykit and car.kitEquipped~=false or false)
  else return nil,'Choose a workshop build, part, paint, bodywork or tuning preview.' end
  if not proposed then return nil,err end
  return {state=proposed,request=U.copy(request),action=action,argument=arg,label=label,cost=cost,
    fitted=fitted==true,unlocked=allowed==true,canBuy=not fitted and allowed and state.cash>=cost or false}
end
return M
