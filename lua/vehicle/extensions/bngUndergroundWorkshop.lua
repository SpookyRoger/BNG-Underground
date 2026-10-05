-- Read-only native engine curves and node mass for the currently constructed car.
-- No acceleration tests, vehicle driving or performance files are generated.
local M={}
function M.request(token,revision)
  local stats={}
  local ok,beams=pcall(function() return obj:calcBeamStats() end)
  if ok and beams then stats.weight=beams.total_weight end
  local engines=powertrain.getDevicesByCategory('engine') or {}
  local powers,torques={},{}
  for _,engine in ipairs(engines) do
    local success,data=pcall(function() return engine:getTorqueData() end)
    local curve=success and data and data.curves and data.curves[data.finalCurveName]
    if curve then
      for rpm,value in pairs(curve.power or {}) do powers[rpm]=(powers[rpm] or 0)+value end
      for rpm,value in pairs(curve.torque or {}) do torques[rpm]=(torques[rpm] or 0)+value end
    end
  end
  for _,value in pairs(powers) do stats.power=math.max(stats.power or 0,value) end
  for _,value in pairs(torques) do stats.torque=math.max(stats.torque or 0,value) end
  obj:queueGameEngineLua('if extensions.bngUnderground then extensions.bngUnderground.onWorkshopStats('..
    serialize(token)..','..tostring(revision)..','..tostring(obj:getId())..','..serialize(stats)..') end')
end
return M
