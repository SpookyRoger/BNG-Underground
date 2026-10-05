-- Session-only population coordinator. Engine operations are injected separately.
local U = require('/lua/ge/extensions/bngUnderground/util')
local M = {}
function M.enabled(content,state)
  return content and content.settings.features.streetTraffic==true and content.traffic and
    (state.preferences.streetTraffic==true or (state.preferences.streetTraffic==nil and content.traffic.enabledByDefault)) or false
end
function M.new(engine)
  local self={}
  local phase,clock,serial,cleanupClock='off',0,0,0
  local config,names,retired,ids,reported=nil,{},{},{},{}
  local pendingGroup,originalVars,reason
  local key=engine.sessionKey()
  local function count() return #engine.owned(names) end
  local function restoreVars()
    if originalVars and engine.count()==0 then engine.restoreVars(originalVars);originalVars=nil end
  end
  local function release()
    engine.releaseCover();engine.changed()
  end
  local function retire()
    for name,model in pairs(names) do retired[name]=model end
    names={};ids={};reported={}
    engine.removeOwned(retired);restoreVars()
  end
  local function fail(text)
    retire();phase='failed';reason=text;clock=0;release()
  end
  local function finish()
    phase='active';reason=nil;clock=0;release()
  end
  local function spawn()
    local group={}
    pendingGroup='bnguStreet_'..key..'_'..serial
    names={};ids={};reported={}
    for i,vehicle in ipairs(config.vehicles) do
      local name=pendingGroup..'_'..i
      names[name]=vehicle.model
      group[i]={model=vehicle.model,config=vehicle.config,vehicleName=name}
    end
    originalVars=originalVars or engine.captureVars()
    engine.setStreetVars(#group)
    phase='spawning';clock=0
    -- nil may mean queued by native multiSpawn. Completion is identified by name.
    local ok=pcall(engine.spawn,group,pendingGroup)
    if not ok then pendingGroup=nil;fail('Street traffic could not be created. You can keep driving.') end
  end
  local function decide()
    local native=engine.state()
    if native=='loading' or native=='spawning' then phase='waiting';clock=0;return end
    if engine.count()>0 then phase='existing';reason=nil;release();return end
    spawn()
  end
  function self.busy() return phase=='cover' or phase=='waiting' or phase=='spawning' or phase=='ready' end
  function self.jobPending() return pendingGroup~=nil end
  function self.start(catalog)
    if self.busy() or pendingGroup then return false,'A native traffic job is still finishing.' end
    config=catalog
    if count()>0 then phase='active';return true end
    retire();reason=nil;phase='cover';clock=0;serial=serial+1
    local generation=serial
    local ok=pcall(engine.cover,function() if phase=='cover' and serial==generation then decide() end end)
    if not ok then fail('The traffic loading screen could not be opened.') end
    engine.changed();return true
  end
  function self.stop()
    retire();phase='off';reason=nil;clock=0;release()
  end
  function self.groupSpawned(vehList,groupName)
    if groupName~=pendingGroup then return false end
    pendingGroup=nil
    if phase~='spawning' then engine.removeOwned(retired);restoreVars();engine.changed();return true end
    ids={}
    for _,id in ipairs(vehList or {}) do
      if engine.isOwned(id,names) then ids[#ids+1]=id end
    end
    if #ids==0 then fail('No campaign traffic cars were created. You can retry from the menu.');return true end
    phase='ready';clock=0
    -- Always supply the nonempty owned ID list; never activate arbitrary cars.
    local ok=pcall(engine.activate,U.copy(ids))
    if not ok then fail('Native street traffic could not be started.') end
    return true
  end
  function self.mapReady(id)
    if phase=='spawning' or phase=='ready' then
      if engine.isOwned(id,names) then reported[id]=true end
    end
  end
  function self.update(dt,missionBusy)
    if phase=='off' and not next(retired) and not pendingGroup then return end
    cleanupClock=cleanupClock+math.max(0,dt or 0)
    if not missionBusy and cleanupClock>=1 then
      cleanupClock=0
      engine.removeOwned(retired)
      if phase=='off' or phase=='failed' then restoreVars() end
      if phase=='active' then engine.lockOwned(names) end
    end
    if not self.busy() then return end
    engine.captureInput()
    clock=clock+math.max(0,dt or 0)
    if phase=='cover' and clock>config.existingTimeout then fail('Traffic loading did not open. You can keep driving.')
    elseif phase=='waiting' then
      local native=engine.state()
      if native~='loading' and native~='spawning' then decide()
      elseif clock>config.existingTimeout then fail('BeamNG is still preparing its traffic. Existing cars were left in place.') end
    elseif phase=='spawning' and clock>config.spawnTimeout then
      -- There is no public native job cancellation API. Remember exact names,
      -- clean partial/late cars, and prevent retry until that group completes.
      fail('Street traffic took too long. Driving is available while its job finishes.')
    elseif phase=='ready' then
      local ready=engine.state()=='on'
      for _,id in ipairs(ids) do ready=ready and engine.isOwned(id,names) and (reported[id] or engine.mapReady(id)) end
      if ready then finish()
      elseif clock>config.readyTimeout then fail('Street traffic did not become ready. You can retry from the menu.') end
    end
  end
  function self.view(enabled,missionBusy)
    local total=count()
    local missing=not missionBusy and ((phase=='active' and total==0) or (phase=='existing' and engine.count()==0))
    local label='Campaign traffic off'
    if missionBusy and enabled then label='Away during this event'
    elseif phase=='active' then label=total>0 and (total..' native civilian cars') or 'Campaign cars are temporarily unavailable'
    elseif phase=='existing' then label=engine.count()>0 and 'Using existing BeamNG traffic' or 'Existing traffic is unavailable'
    elseif phase=='failed' then label='Traffic unavailable'
    elseif self.busy() then label='Preparing street traffic'
    elseif engine.count()>0 then label='Campaign traffic off · existing BeamNG traffic remains' end
    return {enabled=enabled==true,phase=phase,count=total,busy=self.busy(),canRetry=(phase=='failed' or missing) and not pendingGroup or false,
      waitingForJob=pendingGroup~=nil,message=reason,label=label}
  end
  function self.snapshot()
    return {phase=phase,clock=clock,serial=serial,key=key,config=U.copy(config),names=U.copy(names),retired=U.copy(retired),
      ids=U.copy(ids),reported=U.copy(reported),pendingGroup=pendingGroup,originalVars=U.copy(originalVars),reason=reason}
  end
  function self.restore(data)
    if type(data)~='table' then return end
    phase=data.phase or 'off';clock=data.clock or 0;serial=data.serial or 0;key=data.key or key
    config=U.copy(data.config);names=U.copy(data.names or {});retired=U.copy(data.retired or {})
    ids=U.copy(data.ids or {});reported=U.copy(data.reported or {});pendingGroup=data.pendingGroup
    originalVars=U.copy(data.originalVars);reason=data.reason
    if self.busy() and config then
      local generation=serial
      engine.cover(function() if phase=='cover' and serial==generation then decide() end end)
    end
  end
  function self.endLevel()
    -- Native jobs can outlive a level switch. Retain their exact ownership and
    -- completion name, so a late callback cannot activate cars in another mode.
    self.stop();originalVars=nil;config=nil
  end
  return self
end
return M
