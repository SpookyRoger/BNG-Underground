-- Serialized paid vehicle changes. Native construction and persistence are injected.
local U=require('/lua/ge/extensions/bngUnderground/util')
local Equal=require('/lua/ge/extensions/bngUnderground/workshopPreview').equal
local M={}
function M.new(adapter)
  local api,job,serial={},nil,0
  local results,order={},{}
  local function changed() adapter.changed() end
  local function remember(ticket,result)
    results[ticket]=result;order[#order+1]=ticket
    while #order>16 do results[table.remove(order,1)]=nil end
  end
  local function complete(ok,err)
    local finished=job;job=nil
    remember(finished.ticket,{ok=ok,error=err})
    adapter.finished(ok,err,finished.context,finished.id);changed()
  end
  local function fault(err)
    job.phase='fault';job.error=tostring(err);changed()
  end
  local function construct(target,restoring)
    job.generation=job.generation+1;job.target=U.copy(target);job.restoring=restoring
    job.clock=0;job.initialized=false;job.phase=restoring and 'restoring' or 'loading';job.error=nil
    local transform=restoring and job.context.restore or job.context.target
    local called,ok,err,id=pcall(adapter.spawn,job.target,transform)
    if not called or not ok then fault(called and err or ok);return false end
    job.id=id
    local ticket,generation=job.ticket,job.generation
    local initCall,requested,initError=pcall(adapter.initialize,id,function() api.initialized(ticket,generation,id) end)
    if not initCall or not requested then fault(initCall and initError or requested);return false end
    changed();return true
  end
  function api.active() return job~=nil end
  function api.begin(content,nextState,context,recovery)
    if job then return nil,'Wait for the current car change to finish.' end
    serial=serial+1
    local ticket=tostring(os.clock())..':'..tostring(serial)
    job={ticket=ticket,generation=0,paid=U.copy(adapter.state()),candidate=U.copy(nextState),context=U.copy(context),timeout=content.workshopPresentation.vehicleTimeout}
    if recovery then job.failure='Interrupted car change discarded. Your saved car is restored.' end
    construct(job.candidate,recovery==true)
    return ticket
  end
  function api.initialized(ticket,generation,id)
    if not job or ticket~=job.ticket or generation~=job.generation or id~=job.id then return false end
    job.initialized=true;return true
  end
  function api.restore(reason)
    if not job then return false end
    job.failure=reason or 'The change was discarded. Your paid car was restored.'
    return construct(job.paid,true)
  end
  function api.update(dt)
    if not job then return end
    job.clock=job.clock+dt
    local called,ready=pcall(adapter.ready,job.target,job.id)
    if not called then if job.phase~='fault' then fault(ready) end;return end
    if job.initialized and ready then
      local transform=job.restoring and job.context.restore or job.context.target
      local placeCall,placed,placeError=pcall(adapter.place,job.target,job.id,transform)
      if not placeCall or not placed then if job.phase~='fault' then fault(placeCall and placeError or placed) end;return end
      if job.restoring then complete(false,job.failure);return end
      -- The candidate can only commit against the same paid profile it started from.
      if not Equal(adapter.state(),job.paid) then
        job.paid=U.copy(adapter.state());api.restore('The saved campaign changed. The car change was discarded.');return
      end
      local commitCall,saved,err=pcall(adapter.commit,job.candidate)
      if not commitCall or not saved then
        job.paid=U.copy(adapter.state())
        api.restore(commitCall and (err or 'Saving failed. Restoring the saved garage.') or tostring(saved));return
      end
      complete(true);return
    end
    if job.clock>job.timeout and job.phase~='fault' then
      fault(job.initialized and 'The car has replied, but its native references are still unavailable.' or 'The car is taking too long to initialize. The change has not been saved.')
    end
  end
  function api.result(ticket)
    if job and ticket==job.ticket then return {pending=true,ticket=ticket,phase=job.phase} end
    return results[ticket] or {ok=false,error='That car change is no longer pending. Review the saved garage.'}
  end
  function api.projection()
    if not job then return {active=false} end
    return {active=true,phase=job.phase,error=job.error,ticket=job.ticket,restoring=job.restoring,
      label=job.context.label or 'Preparing your car',awaiting=job.initialized and 'nativeReferences' or 'vehicleReply'}
  end
  -- Reload carries only the placement context. The unpaid candidate is discarded.
  function api.snapshot() return job and {context=U.copy(job.context)} or nil end
  function api.recover(content,context)
    return api.begin(content,adapter.state(),context,true)
  end
  function api.cancel()
    if not job then return end
    remember(job.ticket,{ok=false,error='The car change was cancelled.'});job=nil;changed()
  end
  return api
end
return M
