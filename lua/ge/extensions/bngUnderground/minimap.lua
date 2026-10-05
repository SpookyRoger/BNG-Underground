-- Optional campaign symbols; the native Navigation app owns roads, player and GPS.
local M = {}
function M.draw(content,state,active)
  if not active or not content.settings.features.minimap or not state.preferences.minimap or not ui_apps_minimap_utils then return end
  local utils=ui_apps_minimap_utils
  if not utils.simpleCircle then return end
  for _,site in ipairs(content.locations) do
    if site.chapter<=state.chapter and (site.type=='garage' or site.type=='shop' or site.type=='dealership') then
      utils.simpleCircle(vec3(site.pos),site.type=='dealership' and color(199,163,255,255) or color(126,241,198,255),color(20,25,35,255),7)
    end
  end
end
return M
