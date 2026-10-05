-- BNG Underground. Original code: MIT (see /gameplay/bngUnderground/LICENSE.txt).
local M = {}
function M.copy(value)
  if type(value) ~= 'table' then return value end
  local out = {}
  for k, v in pairs(value) do out[k] = M.copy(v) end
  return out
end
function M.index(list)
  local out = {}
  for _, item in ipairs(list or {}) do assert(item.id and not out[item.id], 'Duplicate content ID'); out[item.id] = item end
  return out
end
function M.contains(list, value)
  for _, item in ipairs(list or {}) do if item == value then return true end end
  return false
end
function M.money(value)
  return type(value) == 'number' and value == value and value >= 0 and value < 1000000000 and value % 1 == 0
end
function M.push(list, item, limit)
  table.insert(list, 1, item)
  while #list > (limit or 30) do table.remove(list) end
end
return M
