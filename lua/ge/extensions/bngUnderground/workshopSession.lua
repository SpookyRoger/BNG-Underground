-- One native vehicle rebuild at a time. Adapter owns all engine/storage calls.
-- Unpaid proposals exist only here; the campaign state remains the paid car.
local U=require('/lua/ge/extensions/bngUnderground/util')
local Preview=require('/lua/ge/extensions/bngUnderground/workshopPreview')
local Campaign=require('/lua/ge/extensions/bngUnderground/campaign')
local M={}
function M.new(adapter)
  local api,s,serial={},nil,0
  local function changed() adapter.changed() end
  local function fault(text)
    s.phase='fault';s.error=tostring(text);changed()
  end
  local function startJob(target,proposal,kind)
    local configCall,cfg,model=pcall(adapter.configuration,target)
    if not configCall then fault(cfg);return false end
    if not cfg then fault(model);return false end
    s.revision=s.revision+1
    -- A direct reply from the rebuilt vehicle VM belongs to this exact job.
    -- Navigation-map publication can be cached and is not an initialization ack.
    local job={state=target,config=cfg,proposal=proposal,kind=kind,revision=s.revision,clock=0,initialized=false}
    s.job=job;s.phase=kind=='restore' and 'restoring' or 'loading';s.error=nil;s.stats=nil
    local spawnCall,ok,err,id=pcall(adapter.spawn,target,s.site)
    if not spawnCall or not ok then s.job=nil;fault(spawnCall and err or ok);return false end
    job.id=id
    local token=s.token
    local initCall,requested,initError=pcall(adapter.initialize,id,function() api.initialized(token,job.revision,id) end)
    if not initCall or not requested then fault(initCall and initError or requested);return false end
    changed();return true
  end
  local function finishExit()
    local current=s
    current.handingOff=true
    local ok,accepted,err=pcall(adapter.finish,current.snapshot,current.id,current.exitTarget)
    -- Ending the level may synchronously clean up this session through a hook.
    if s~=current then return ok and accepted==true end
    current.handingOff=false
    if not ok or accepted~=true then
      if adapter.hold then pcall(adapter.hold) end
      current.exitFault=true
      local reason=(ok and err or accepted) or 'The requested return was not accepted.'
      fault('Your paid car is restored, but the workshop could not finish returning. '..tostring(reason)..' Retry returning, restore the saved car here, or return to the main menu.')
      return false
    end
    s=nil;changed();return true
  end
  local function progressExit()
    if not s or not s.exitTarget or s.job or s.handingOff or s.exitFault then return end
    if s.actualConfig and Preview.equal(s.actualConfig,s.paidConfig) then finishExit()
    elseif s.phase~='fault' then startJob(U.copy(adapter.state()),nil,'restore') end
  end
  function api.active() return s~=nil end
  function api.handingOff() return s and s.handingOff==true or false end
  function api.awaitingScreen() return s and s.awaitingScreen==true or false end
  function api.enter(content,state,site,recovery,deferOpening)
    if s then return false,'The workshop is already open.' end
    local configCall,paid,err=pcall(adapter.configuration,state)
    if not configCall or not paid then return false,configCall and err or paid end
    local snapshot=recovery
    if snapshot==nil then
      local captureCall,captured=pcall(adapter.capture)
      if not captureCall then return false,captured end
      snapshot=captured
    end
    if type(snapshot)~='table' then return false,'The workshop could not capture the street presentation.' end
    serial=serial+1
    s={content=content,site=site,car=state.activeCar,token=tostring(serial)..':'..tostring(os.clock()),revision=0,
      phase='opening',paidConfig=paid,snapshot=U.copy(snapshot),viewId=content.workshopPresentation.views[1].id,
      awaitingScreen=deferOpening==true,openingState=deferOpening and U.copy(state) or nil}
    if not s.awaitingScreen then startJob(U.copy(state),nil,'open') end
    return true
  end
  function api.open()
    if not s or not s.awaitingScreen then return false end
    local paid=s.openingState
    s.awaitingScreen=false;s.openingState=nil
    return startJob(paid,nil,'open')
  end
  function api.cancelOpening()
    -- No vehicle, camera or lighting mutation has occurred before route acceptance.
    if not s or not s.awaitingScreen or s.job or s.id or s.revision~=0 then return false end
    s=nil;changed();return true
  end
  function api.preview(request)
    if not s or s.awaitingScreen or s.exitTarget or s.phase=='fault' then return false,'Enter the workshop before previewing parts.' end
    if Preview.equal(request,s.wanted and s.wanted.request) or (not s.job and not s.wanted and Preview.equal(request,s.quote and s.quote.request)) then return true end
    local proposal,err=Preview.propose(s.content,adapter.state(),request)
    if not proposal then return false,err end
    s.wanted={request=U.copy(request),clock=0};changed();return true
  end
  function api.initialized(token,revision,id)
    if not s or token~=s.token or not s.job or revision~=s.job.revision or id~=s.job.id then return false end
    s.job.initialized=true;return true
  end
  function api.stats(token,revision,id,value)
    if not s or token~=s.token or revision~=s.revision or id~=s.id or s.job then return false end
    local clean={}
    for _,key in ipairs({'power','torque','weight'}) do
      local n=value and value[key]
      if type(n)=='number' and n==n and n>0 and n<1000000 then clean[key]=n end
    end
    s.stats=clean;s.measuring=false
    if not s.quote then s.baselineStats=U.copy(clean) end
    changed();return true
  end
  function api.update(dt)
    if not s then return end
    if s.awaitingScreen then return end
    if s.wanted then s.wanted.clock=s.wanted.clock+dt end
    local job=s.job
    if job then
      job.clock=job.clock+dt
      local ok,ready=pcall(adapter.ready,job.state,job.id)
      if not ok then if s.phase~='fault' then fault(ready) end;return end
      if job.initialized and ready then
        local placeCall,placed,err=pcall(adapter.place,job.state,job.id,s.site)
        if not placeCall or not placed then
          if s.phase~='fault' then fault(placeCall and err or placed) end
          return
        end
        s.id=job.id;s.actualConfig=job.config;s.quote=job.proposal;s.job=nil;s.phase='ready';s.error=nil
        local presentCall,presentError=pcall(adapter.present,job.id,s.viewId,s.content.workshopPresentation)
        if not presentCall then fault(presentError);return end
        s.measuring=true;s.statsClock=0
        pcall(adapter.stats,job.id,s.token,job.revision)
        changed()
        if s.exitTarget then progressExit() end
        return
      end
      if job.clock>s.content.workshopPresentation.vehicleTimeout and s.phase~='fault' then
        local waiting=job.initialized and 'native vehicle references' or 'a reply from the rebuilt car'
        fault('Still waiting for '..waiting..'. The workshop remains paused. A late reply can recover it, or save your paid build and return to the main menu.')
      end
      return
    end
    if s.exitTarget then progressExit();return end
    if s.measuring then
      s.statsClock=s.statsClock+dt
      if s.statsClock>s.content.workshopPresentation.statsTimeout then s.measuring=false;changed() end
      return
    end
    if s.wanted and s.wanted.clock>=s.content.workshopPresentation.previewDelay then
      local request=s.wanted.request;s.wanted=nil
      local proposal,err=Preview.propose(s.content,adapter.state(),request)
      if not proposal then s.error=err;changed();return end
      local cfg,configError=adapter.configuration(proposal.state)
      if not cfg then s.error=configError;changed();return end
      if Preview.equal(cfg,s.actualConfig) then
        s.revision=s.revision+1 -- even a visually identical choice invalidates the old quote
        s.quote=proposal;s.phase='ready';changed()
      else startJob(proposal.state,proposal,'preview') end
    end
  end
  function api.buy(quote)
    if not s or s.exitTarget or s.job or s.wanted or s.measuring or s.phase~='ready' or not s.quote then return false,'Wait for this preview to finish.' end
    if type(quote)~='table' or quote.token~=s.token or quote.revision~=s.revision then return false,'The preview changed. Review it before buying.' end
    if not adapter.allowed(s.site,s.id) then return false,'Bring your active car to this workshop and stop before buying.' end
    if not adapter.ready(adapter.state(),s.id) then return false,'The preview vehicle changed. Leave and enter the workshop again.' end
    local proposal,err=Preview.propose(s.content,adapter.state(),s.quote.request)
    if not proposal or not proposal.canBuy then return false,err or 'This selection is fitted, locked or unaffordable.' end
    local paid=U.copy(adapter.state())
    local ok,result=Campaign.command(s.content,paid,proposal.action,proposal.argument)
    if not ok then return false,result end
    local cfg,configError=adapter.configuration(paid)
    if not cfg then return false,configError end
    if not Preview.equal(cfg,s.actualConfig) then return false,'The preview no longer matches the purchase. Choose it again.' end
    if not adapter.commit(paid) then return false,'The purchase could not be saved. No money was taken; the preview is still temporary.' end
    s.paidConfig=cfg;s.quote=nil;s.baselineStats=U.copy(s.stats);s.error=nil
    changed();return true
  end
  function api.view(viewId)
    if not s or s.exitTarget then return false end
    for _,entry in ipairs(s.content.workshopPresentation.views) do
      if entry.id==viewId then
        s.viewId=viewId
        -- Selecting an angle during replacement queues it for the new car.
        -- Performance reads do not lock the camera controls.
        if not s.job and s.id then
          local ok,err=pcall(adapter.present,s.id,viewId,s.content.workshopPresentation)
          if not ok then fault(err);return false,err end
        end
        changed();return true
      end
    end
    return false
  end
  function api.exit(target)
    if not s or s.awaitingScreen or s.handingOff then return false end
    target=target or 'play'
    if target~='play' and target~='board' and target~='menu' then return false end
    s.exitTarget=target;s.exitFault=false;s.wanted=nil;changed();progressExit();return true
  end
  function api.recover()
    if not s or s.phase~='fault' or s.handingOff then return false,'Recovery is available only while the workshop is waiting.' end
    local paid=U.copy(adapter.state())
    local ok,cfg,err=pcall(adapter.configuration,paid)
    if not ok or not cfg then fault(ok and err or cfg);return false,ok and err or cfg end
    -- The old job/replies cannot complete the new generation. Only paid state is
    -- reconstructed; queued/unbought proposals and a pending exit are discarded.
    s.job=nil;s.wanted=nil;s.quote=nil;s.exitTarget=nil;s.exitFault=false;s.measuring=false
    s.paidConfig=cfg;s.stats=nil;s.baselineStats=nil
    return startJob(paid,nil,'restore')
  end
  function api.projection()
    if not s then return {active=false} end
    local quote=s.quote and {request=U.copy(s.quote.request),label=s.quote.label,cost=s.quote.cost,fitted=s.quote.fitted,
      unlocked=s.quote.unlocked,canBuy=s.quote.canBuy,token=s.token,revision=s.revision} or nil
    return {active=true,site=s.site,car=s.car,phase=s.phase,error=s.error,viewId=s.viewId,
      pending=s.awaitingScreen==true or s.job~=nil or s.wanted~=nil or s.measuring==true or s.exitTarget~=nil,
      ready=s.phase=='ready' and not s.job and not s.wanted and not s.measuring and not s.exitTarget,
      measuring=s.measuring==true,loading=s.job~=nil,
      awaiting=s.job and (s.job.initialized and 'vehicleReferences' or 'vehicleReply') or nil,
      quote=quote,stats=U.copy(s.stats),baselineStats=U.copy(s.baselineStats),
      views=U.copy(s.content.workshopPresentation.views),exiting=s.exitTarget~=nil,
      canRetryExit=s.exitFault==true,handingOff=s.handingOff==true}
  end
  -- Reload remembers only the presentation snapshot; re-entry restores the paid
  -- configuration, never serialized preview ownership or an unpaid proposal.
  function api.snapshot() return s and {site=s.site,car=s.car,presentation=U.copy(s.snapshot)} or nil end
  function api.abandon(levelEnded)
    if not s then return end
    if s.awaitingScreen then s=nil;return end
    local id=s.id
    if not levelEnded then
      local ok,err,newId=adapter.spawn(adapter.state(),s.site)
      if ok then id=newId end
    end
    pcall(adapter.restore,s.snapshot,id)
    s=nil
  end
  return api
end
return M
