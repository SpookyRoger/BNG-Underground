-- Native paint presets and purchase rules. No engine access or live previews.
local U=require('/lua/ge/extensions/bngUnderground/util')
local E=require('/lua/ge/extensions/bngUnderground/economy')
local M={}
local function colour(content,id)
  for _,entry in ipairs(content.settings.paints) do if entry.id==id then return entry end end
end
local function finish(content,id)
  for _,entry in ipairs(content.paintShop.finishes) do if entry.id==id then return entry end end
end
function M.checkCatalog(content)
  local catalog=content.paintShop
  assert(type(catalog)=='table' and catalog.version==1 and type(catalog.finishes)=='table','Invalid paint shop catalog')
  local ids={}
  for _,entry in ipairs(catalog.finishes) do
    assert(type(entry.id)=='string' and entry.id:match('^[%w_]+$') and not ids[entry.id] and type(entry.name)=='string' and type(entry.description)=='string','Invalid paint finish identity')
    ids[entry.id]=true
    for _,key in ipairs({'metallic','roughness','clearcoat','clearcoatRoughness'}) do
      local value=entry[key]
      assert(type(value)=='number' and value==value and value>=0 and value<=1,'Invalid native paint property')
    end
  end
  assert(ids[catalog.defaultFinish],'Missing default paint finish')
  for _,entry in ipairs(content.settings.paints) do
    assert(type(entry.rgba)=='table' and #entry.rgba==4,'Invalid paint colour')
    for _,value in ipairs(entry.rgba) do assert(type(value)=='number' and value==value and value>=0 and value<=1,'Invalid paint colour channel') end
  end
end
function M.finishId(content,car)
  return car.paint and (car.paintFinish or content.paintShop.defaultFinish) or nil
end
function M.validate(content,car)
  if car.paint and not colour(content,car.paint) then return false,'Invalid saved finish.' end
  if car.paintFinish~=nil and (not car.paint or type(car.paintFinish)~='string' or not finish(content,car.paintFinish)) then return false,'Invalid saved paint material.' end
  return true
end
local function change(content,state,arg,preview)
  local car=state.garage[state.activeCar]
  if not car then return false,'Buy your own car before painting it.' end
  local id,material
  if type(arg)=='string' then
    id=arg;material=M.finishId(content,car) or content.paintShop.defaultFinish
  elseif type(arg)=='table' then
    -- An open quote must still describe the same car and fitted respray.
    if arg.car~=state.activeCar or arg.basePaint~=(car.paint or false) or arg.baseFinish~=(M.finishId(content,car) or false) then return false,'Your car or fitted paint changed. Choose the respray again.' end
    id=arg.colour;material=arg.finish
  else return false,'Choose a colour and finish.' end
  local selected,coat=colour(content,id),finish(content,material)
  if not selected or not coat then return false,'Unknown colour or finish.' end
  local current=M.finishId(content,car)
  if content.settings.features.paintFinishes==false and material~=(current or content.paintShop.defaultFinish) then return false,'Paint finish choices are disabled.' end
  if car.paint==id and current==material then return preview==true,'This colour and finish are already fitted.' end
  if not preview then
    local ok,err=E.debit(state,content.settings.resprayCost,'Respray / '..selected.name..' / '..coat.name)
    if not ok then return false,err end
  end
  car.paint=id;car.paintFinish=material
  return true
end
function M.purchase(content,state,arg) return change(content,state,arg,false) end
function M.preview(content,state,arg)
  local proposed=U.copy(state)
  local ok,err=change(content,proposed,arg,true)
  if not ok then return nil,err end
  return proposed
end
function M.apply(content,car,cfg)
  local ok,err=M.validate(content,car)
  if not ok then return false,err end
  if not car.paint then return true end -- keep all original preset colours
  local selected,coat=colour(content,car.paint),finish(content,M.finishId(content,car))
  cfg.paints={}
  -- Keep the existing campaign's uniform three-palette respray contract.
  for index=1,3 do
    cfg.paints[index]={baseColor=U.copy(selected.rgba),metallic=coat.metallic,roughness=coat.roughness,clearcoat=coat.clearcoat,clearcoatRoughness=coat.clearcoatRoughness}
  end
  return true
end
function M.view(content)
  local rows={}
  for _,entry in ipairs(content.paintShop.finishes) do rows[#rows+1]={id=entry.id,name=entry.name,description=entry.description} end
  return {defaultFinish=content.paintShop.defaultFinish,finishes=rows}
end
return M
