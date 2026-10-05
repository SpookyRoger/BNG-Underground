-- Matched build previews only. Ownership on detached copies never reaches saves.
local U=require('/lua/ge/extensions/bngUnderground/util')
local Parts=require('/lua/ge/extensions/bngUnderground/parts')
local M={}
function M.signature(content,state)
  local car=state.garage[state.activeCar]
  if not car then return nil end
  local key=Parts.key(content,car)
  return table.concat({state.activeCar,tostring(car.tier),Parts.signature(content,car,key),
    car.driftOwned and 'drift-owned' or 'drift-available',car.dragOwned and 'drag-owned' or 'drag-available'},'|')
end
local function options(content,state)
  local car=state.garage[state.activeCar];local spec=content.vehiclesById[state.activeCar]
  local fitted=Parts.key(content,car)
  local rows={{id='stock',name='Stock setup',description='Refit the stock base with its saved individual parts, bodywork and tuning. Other builds keep their settings.',
    tier=0,owned=true,compatible=true,unlocked=true,fitted=fitted=='stock',cost=0,chapter=1,action='equip',argument=0}}
  for tier,entry in ipairs(content.settings.upgradeTiers) do
    local owned=tier<=car.tier
    local previous=tier>car.tier+1 and content.settings.upgradeTiers[tier-1].name or nil
    rows[#rows+1]={id=entry.id,name=entry.name,description=entry.description..' A matched base for further individual customization; each build retains its own parts and tuning.',
      tier=tier,owned=owned,compatible=true,unlocked=owned or (not previous and state.chapter>=entry.chapter),blockedBy=previous,
      fitted=fitted==entry.id,cost=owned and 0 or entry.cost,chapter=entry.chapter,action=owned and 'equip' or 'upgrade',argument=owned and tier or nil}
  end
  for _,mode in ipairs({'drift','drag'}) do
    if spec[mode..'Config'] then
      local owned=car[mode..'Owned']==true;local chapter=mode=='drag' and 2 or 1
      rows[#rows+1]={id=mode,name=mode=='drift' and 'Drift build' or 'Drag build',
        description=mode=='drift' and 'A complete native drift conversion. Owned conversions refit free and retain their saved tuning and bodywork.' or 'A complete native drag conversion. Owned conversions refit free and retain their saved tuning and bodywork.',
        owned=owned,compatible=true,unlocked=state.chapter>=chapter,fitted=fitted==mode,cost=owned and 0 or spec[mode..'Cost'],chapter=chapter,action=mode..'Build'}
    end
  end
  return rows
end
function M.view(content,state)
  if content.settings.features.liveBuilds~=true or not state.garage[state.activeCar] then return nil end
  return {car=state.activeCar,signature=M.signature(content,state),options=options(content,state)}
end
function M.preview(content,state,arg)
  local view=M.view(content,state)
  if not view or type(arg)~='table' or arg.car~=view.car or arg.hardware~=view.signature then return nil,'The fitted car or owned builds changed. Choose the build again.' end
  local selected
  for _,row in ipairs(view.options) do if row.id==arg.choice then selected=row;break end end
  if not selected then return nil,'No matched build is offered for this car.' end
  local proposed=U.copy(state);local car=proposed.garage[state.activeCar]
  if selected.tier then
    -- Grant only the detached preview enough ownership to compose native parts.
    -- Real purchases still pass Campaign.upgrade one tier at a time.
    car.tier=math.max(car.tier,selected.tier);car.equippedTier=selected.tier;car.mode='grip'
  else car[selected.id..'Owned']=true;car.mode=selected.id end
  return proposed,selected
end
return M
