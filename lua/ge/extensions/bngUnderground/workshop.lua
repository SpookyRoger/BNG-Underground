-- Physical workshop access and arrival prompts. Engine distance/speed are injected.
local M = {}
local promptedSite
function M.context(content,state,distanceOf,stopped,busy)
  local nearest,distance=nil,math.huge
  for _,site in ipairs(content.locations) do
    if (site.type=='garage' or site.type=='shop') and site.chapter<=state.chapter then
      local d=distanceOf(site.pos)
      if d<distance then nearest=site;distance=d end
    end
  end
  local radius=content.settings.workshopRadius
  local near=nearest~=nil and distance<=radius
  local ready=near and stopped==true and not busy
  local reason
  if busy then reason='Finish the current event before entering a workshop.'
  elseif not near then reason='Drive to a workshop parking bay, park within '..radius..' metres and stop.'
  elseif not stopped then reason='Stop the car before opening the workshop. If you paused while rolling, return to driving and brake first.'
  else reason='Workshop open. Buy cars, switch your active car or fit its purchased parts.' end
  return {siteId=near and nearest.id or false,siteName=near and nearest.name or false,
    nearestId=nearest and nearest.id or false,nearestName=nearest and nearest.name or false,
    distance=distance<math.huge and math.floor(distance) or false,radius=radius,near=near,ready=ready,reason=reason}
end
function M.resetVisit(context) promptedSite=context and context.siteId or nil end
function M.shouldPrompt(context)
  if not context.near then promptedSite=nil;return false end
  if context.ready and promptedSite~=context.siteId then promptedSite=context.siteId;return true end
  return false
end
return M
