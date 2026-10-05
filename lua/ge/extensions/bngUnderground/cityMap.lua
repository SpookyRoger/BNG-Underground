-- Road geometry only; selection and controller navigation belong to the paused Vue map.
local M = {}
local cached
function M.clear() cached=nil end
function M.get(content)
  if cached then return cached end
  local network=map and map.getMap()
  if not network or not network.nodes then return {error='Road map is not ready. Close and reopen the map.'} end
  local out={roads={},bounds={math.huge,math.huge,-math.huge,-math.huge}}
  local seen={}
  local function include(x,y)
    out.bounds[1]=math.min(out.bounds[1],x);out.bounds[2]=math.min(out.bounds[2],y)
    out.bounds[3]=math.max(out.bounds[3],x);out.bounds[4]=math.max(out.bounds[4],y)
  end
  for id,node in pairs(network.nodes) do
    for targetId,link in pairs(node.links or {}) do
      local target=network.nodes[targetId]
      local first,second=tostring(id),tostring(targetId)
      local key=first<second and (first..'|'..second) or (second..'|'..first)
      if target and not seen[key] and not link.hiddenInNavi then
        seen[key]=true
        local a,b=node.pos,target.pos
        table.insert(out.roads,{a.x,a.y,b.x,b.y,(link.drivability or 1)>=0.9 and 1 or 0})
        include(a.x,a.y);include(b.x,b.y)
      end
    end
  end
  for _,event in ipairs(content.events) do include(event.pos[1],event.pos[2]) end
  for _,site in ipairs(content.locations) do include(site.pos[1],site.pos[2]) end
  if #out.roads==0 then return {error='No roads available yet. Close and reopen the map.'} end
  cached=out
  return out
end
return M
