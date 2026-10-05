-- The borrowed opening car is never inserted into the player's owned garage.
local G = require('/lua/ge/extensions/bngUnderground/garage')
local U = require('/lua/ge/extensions/bngUnderground/util')
local M = {}
function M.pending(state) return state and type(state.intro)=='table' and state.intro.stage=='dealership' or false end
function M.configuration(content,readConfig)
  local intro=content.settings.introduction
  return G.configuration(content,{activeCar=intro.car,garage={[intro.car]={tier=intro.tier,equippedTier=intro.tier,
    bodykit=true,kitEquipped=true,paint=intro.paint}}},readConfig)
end
function M.purchase(content,state,id)
  if not M.pending(state) then return false,'Your first car is already owned.' end
  if not U.contains(content.settings.starters,id) then return false,'Choose one of the three starter cars.' end
  local ok,err=G.buy(content,state,id)
  if not ok then return false,err end
  state.intro.stage='complete'
  U.push(state.inbox,{id='first-keys',sender=content.settings.introduction.friend,title='Your keys. Your choices.',read=false,
    text='I have my car back. Yours is ready to build. Several meets are open tonight: choose whatever suits your car. Head home for upgrades whenever you want.'},80)
  return true
end
return M
