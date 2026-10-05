-- Pure temporary HUD layout policy. Never saves or changes installed app files.
local U=require('/lua/ge/extensions/bngUnderground/util')
local M={}
local damageApps={damageApp=true,detailedDamageApp=true}
local function position(app,left,bottom,width,height)
  local p=app.placement or {}
  local changed=p.left~=left or p.bottom~=bottom or p.top~=nil or p.right~=nil or (width and p.width~=width) or (height and p.height~=height)
  app.placement=p;p.left=left;p.bottom=bottom;p.right=nil;p.top=nil
  if width then p.width=width end
  if height then p.height=height end
  return changed
end
function M.apply(current,wantsMap)
  local layout=U.copy(current);layout.apps=layout.apps or {}
  local changed,hasMap=false,false
  for _,app in ipairs(layout.apps) do
    if app.appName=='navigation' then
      hasMap=true
      if wantsMap then
        if not app.bnguMinimap and app.bnguNavigationPlacement==nil then app.bnguNavigationPlacement=U.copy(app.placement or {});changed=true end
        changed=position(app,'24px','24px','300px','350px') or changed
      elseif app.bnguNavigationPlacement~=nil then
        app.placement=app.bnguNavigationPlacement;app.bnguNavigationPlacement=nil;changed=true
      end
    elseif damageApps[app.appName] then
      if wantsMap then
        if app.bnguDamagePlacement==nil then app.bnguDamagePlacement=U.copy(app.placement or {});changed=true end
        changed=position(app,'340px','24px') or changed
      elseif app.bnguDamagePlacement~=nil then
        app.placement=app.bnguDamagePlacement;app.bnguDamagePlacement=nil;changed=true
      end
    end
  end
  if wantsMap and not hasMap then
    table.insert(layout.apps,{appName='navigation',bnguMinimap=true,placement={left='24px',bottom='24px',width='300px',height='350px'}});changed=true
  elseif not wantsMap then
    for index=#layout.apps,1,-1 do if layout.apps[index].bnguMinimap then table.remove(layout.apps,index);changed=true end end
  end
  return layout,changed
end
return M
