local U = require('/lua/ge/extensions/bngUnderground/util')
local M = {}
function M.credit(state, amount, reason)
  assert(U.money(amount), 'Invalid credit')
  state.cash = state.cash + amount
  state.lifetimeEarned = state.lifetimeEarned + amount
  U.push(state.ledger, {amount=amount, reason=reason}, 60)
end
function M.debit(state, amount, reason)
  if not U.money(amount) or state.cash < amount then return false, 'Not enough cash.' end
  state.cash = state.cash - amount
  U.push(state.ledger, {amount=-amount, reason=reason}, 60)
  return true
end
function M.purse(content, event, first, medal)
  local settings = content.settings
  local factor = first and 1 or settings.replayMultiplier
  if medal == 'gold' then factor = factor*settings.goldMultiplier
  elseif medal == 'silver' then factor = factor*settings.silverMultiplier end
  return math.floor(event.reward*factor + 0.5)
end
-- Quotes share the settlement formula. Sponsor bonuses remain separate.
function M.preview(content,event,record)
  local replay=record~=nil and record.cleared==true
  local medals={}
  for _,medal in ipairs({'bronze','silver','gold'}) do medals[medal]=M.purse(content,event,not replay,medal) end
  return {replay=replay,min=event.boss and medals.gold or medals.bronze,max=medals.gold,
    medals=medals,rep=replay and 0 or event.rep}
end
function M.tow(content, state)
  local cost = math.min(content.settings.towCost, state.cash)
  M.debit(state, cost, 'Recovery to garage')
  return cost
end
function M.repair(content,state)
  local cost=state.intro and state.intro.stage=='dealership' and 0 or content.settings.repairCost
  if cost==0 then return true,0 end
  local ok,err=M.debit(state,cost,'Vehicle repair')
  if not ok then return false,err end
  return true,cost
end
return M
