-- BNG Underground: lifecycle/hooks and command routing. Domain modules have no engine dependencies.
local M = {}
M.dependencies = {'gameplay_missions_missions','gameplay_missions_missionManager','gameplay_missions_unlocks',
  'gameplay_rawPois','core_vehicles','core_vehicle_partmgmt','core_vehicle_manager','core_vehicleBridge','core_camera','core_environment','core_groundMarkers','core_gamestate','ui_appLayouts','ui_router','freeroam_freeroam','gameplay_traffic','core_multiSpawn'}
local U = require('/lua/ge/extensions/bngUnderground/util')
local Content = require('/lua/ge/extensions/bngUnderground/content')
local Campaign = require('/lua/ge/extensions/bngUnderground/campaign')
local RaceSession = require('/lua/ge/extensions/bngUnderground/raceSession')
local Progression = require('/lua/ge/extensions/bngUnderground/progression')
local Storage = require('/lua/ge/extensions/bngUnderground/storage')
local Bridge = require('/lua/ge/extensions/bngUnderground/bridge')
local Atmosphere = require('/lua/ge/extensions/bngUnderground/atmosphere')
local UiSession = require('/lua/ge/extensions/bngUnderground/uiSession')
local Onboarding = require('/lua/ge/extensions/bngUnderground/onboarding')
local Inbox = require('/lua/ge/extensions/bngUnderground/inbox')
local MissionIsolation = require('/lua/ge/extensions/bngUnderground/missionIsolation')
local CityMap = require('/lua/ge/extensions/bngUnderground/cityMap')
local CoursePreview = require('/lua/ge/extensions/bngUnderground/coursePreview')
local MissionPreview = require('/lua/ge/extensions/bngUnderground/missionPreview')
local Minimap = require('/lua/ge/extensions/bngUnderground/minimap')
local Workshop = require('/lua/ge/extensions/bngUnderground/workshop')
local WorkshopSession = require('/lua/ge/extensions/bngUnderground/workshopSession')
local WorkshopBridge = require('/lua/ge/extensions/bngUnderground/workshopBridge')
local GarageTransaction = require('/lua/ge/extensions/bngUnderground/garageTransaction')
local GarageBridge = require('/lua/ge/extensions/bngUnderground/garageBridge')
local Showcases = require('/lua/ge/extensions/bngUnderground/showcases')
local StreetTraffic = require('/lua/ge/extensions/bngUnderground/streetTraffic')
local TrafficBridge = require('/lua/ge/extensions/bngUnderground/trafficBridge')
local street = StreetTraffic.new(TrafficBridge)
local content, store, state
local showroom,transactions,leave
local active, pendingJoin, travelling, modal = false, false, false, false
local endingLevel=false
local loadError, blockedSave, raceRun, rejectMission
local updateClock, joinClock, notifyClock = 0, 0, 0
local radialAdded = false
local loadingTag = 'bngUndergroundJoin'
local loadingHeld = false
local cityLoaded = false
local joinCarReady = false
local joinCarRequested,joinVehicleId,joinVehicleClock=false,nil,0
local boardPage, dealerPrompted = 'city', false
local garageActions={buyCar=true,selectCar=true,upgrade=true,equip=true,paint=true,bodykit=true,toggleKit=true,driftBuild=true,dragBuild=true,tune=true,resetTune=true,buyPart=true,fitPart=true,buyBodywork=true,fitBodywork=true}
local function clearMapCaches() CityMap.clear();CoursePreview.clear() end

local function message(text,kind) Bridge.message(text,kind) end
local function dismissActivity()
  -- Native parking prompts can arrive after the custom route opens.
  -- The campaign menu owns this interaction until it returns to driving.
  if ui_missionInfo and ui_missionInfo.openState=='opened' then ui_missionInfo.closeDialogue() end
end
local function finishLoading()
  if loadingHeld then core_gamestate.requestExitLoadingScreen(loadingTag);loadingHeld=false end
end
local function load()
  if content then return true end
  local ok, result=pcall(Content.load)
  if not ok then loadError=tostring(result);log('E','bngUnderground','Content load failed: '..loadError);return false end
  content=result;store=Storage.new(content)
  state,loadError,blockedSave=store.load()
  if state then Inbox.prepare(state);if state.preferences.minimap==nil then state.preferences.minimap=true end end
  return true
end

function M.isActive() return active and not endingLevel and state~=nil and Bridge.isCity(content) and not Bridge.isCareer() end
function M.canEnter(id)
  if not M.isActive() then return false,'Start BNG Underground from its main-menu button.' end
  if pendingJoin or street.busy() then return false,'Wait for campaign loading to finish.' end
  if street.jobPending() then return false,'A native traffic job is still finishing. Keep driving until it completes.' end
  if showroom and showroom.active() then return false,'Leave the workshop before starting a race.' end
  if transactions and transactions.active() then return false,'Wait for the car change or restore the saved car before racing.' end
  return Progression.canEnter(content,state,id)
end
function M.isEventVisible(id)
  local event=content and content.eventsById[id]
  return M.isActive() and not Onboarding.pending(state) and event and event.chapter<=state.chapter or false
end
function M.getMapData()
  if not M.isActive() then return {error='Resume the campaign to view the city.'} end
  return CityMap.get(content)
end
function M.getCourseData(id)
  local unavailable={eventId=id,available=false,points={},retryable=true,reason='Return to campaign driving to preview a course.'}
  if not M.isActive() or Bridge.busy() then return unavailable end
  if content.settings.features.coursePreviews==false then unavailable.retryable=false;unavailable.reason='Course outlines are disabled.';return unavailable end
  local event=content.eventsById[id]
  if not event or Onboarding.pending(state) or not M.canEnter(id) then unavailable.retryable=false;unavailable.reason='Choose an available race to preview its course.';return unavailable end
  return CoursePreview.get(event,MissionPreview.read)
end
function M.onDrawOnMinimap() Minimap.draw(content,state,M.isActive() and not Bridge.busy()) end

function M.requestState()
  -- A passive HUD request in ordinary BeamNG must not parse the campaign or save.
  -- Omit profile/bank fields until the dedicated launcher requests real data.
  if not content then
    local idle={active=false,modal=modal,busy=false}
    guihooks.trigger('BNGUState',idle);return idle
  end
  if not load() then guihooks.trigger('BNGUState',{error=loadError,modal=modal});return end
  local view=state and Campaign.view(content,state) or {
    title=content.settings.title,version=content.settings.version,vehicleList={},
    startingCash=content.settings.startingCash,starters=content.settings.starters
  }
  if not state then
    for _,spec in ipairs(content.vehicles) do table.insert(view.vehicleList,Content.vehicleView(spec)) end
  end
  view.hasProfile=state~=nil;view.active=M.isActive();view.modal=modal
  view.error=loadError;view.blockedSave=blockedSave;view.busy=endingLevel or Bridge.busy() or pendingJoin or street.busy() or (transactions and transactions.active())
  view.loading=pendingJoin or street.busy()
  view.streetTraffic=street.view(state and StreetTraffic.enabled(content,state) or false,Bridge.busy())
  view.inCity=Bridge.isCity(content);view.careerActive=Bridge.isCareer()
  view.nearGarage=false
  view.menuPage=boardPage;view.nearDealership=false
  view.liveWorkshop=showroom and showroom.projection() or {active=false}
  view.carTransaction=transactions and transactions.projection() or {active=false}
  if view.active then
    view.playerPosition=Bridge.playerPosition()
    view.gpsRoute=Bridge.routePoints()
    view.nearDealership=Bridge.distance(content.locationsById[content.settings.introduction.dealership].pos)<=20 and Bridge.isStopped()
    view.stopped=Bridge.isStopped()
    view.workshop=Workshop.context(content,state,Bridge.distance,view.stopped,view.busy)
    view.nearGarage=view.workshop.siteName
    for _,event in ipairs(view.eventList) do
      local distance=Bridge.distance(event.pos)
      event.distance=distance<math.huge and math.floor(distance) or nil
      event.canStart=event.unlocked and not view.busy and (distance<75 or (event.record and event.record.cleared)) or false
    end
    view.locations=U.copy(content.locations)
    for _,location in ipairs(view.locations) do
      local distance=Bridge.distance(location.pos)
      location.distance=distance<math.huge and math.floor(distance) or nil
      location.near=distance<content.settings.shopRadius
    end
    for index,cover in ipairs(view.covers or {}) do
      view.covers[index]=Showcases.context(content,state,cover.id,Bridge.distance,view.stopped,view.busy)
    end
  end
  guihooks.trigger('BNGUState',view)
  return view
end

TrafficBridge.changed=function() if content then M.requestState() end end

local function commit(nextState)
  local invitations=Inbox.sync(content,nextState)
  local ok,err=store.save(nextState)
  if not ok then message(err,'error');return false end
  state=nextState
  if invitations>0 then guihooks.trigger('BNGUIncomingMessage',state.inbox[1]) end
  Bridge.refreshMap()
  M.requestState()
  return true
end

transactions=GarageTransaction.new({
  state=function() return state end,
  spawn=function(candidate,transform) return GarageBridge.spawn(content,candidate,transform) end,
  initialize=GarageBridge.initialize,
  ready=function(candidate,id) return GarageBridge.ready(content,candidate,id) end,
  place=function(candidate,id,transform) return GarageBridge.place(content,candidate,id,transform) end,
  commit=commit,changed=function() if content then M.requestState() end end,
  finished=function(ok,err,context,id)
    GarageBridge.focus(id);Atmosphere.apply(content,state)
    if not ok then message(err or 'The change was discarded. Your saved car is restored.','error');return end
    if context.action=='buyStarter' then Bridge.clearRoute();message('Your '..content.vehiclesById[state.activeCar].name..' is ready. Keep the change and choose your meets.')
    elseif context.action=='repair' then message(context.cost==0 and 'Car repaired in place. Free during testing.' or ('Car repaired. Cost: $'..context.cost..'.'))
    elseif context.action=='tow' then
      if Onboarding.pending(state) then Bridge.navigate(content.locationsById[content.settings.introduction.dealership].pos) end
      message('Recovered to Mara\'s Garage. Cost: $'..tostring(context.cost or 0)..'.')
    else message('Car ready and saved. Your campaign is up to date.') end
    if context.close then M.close() end
  end,
})
local function changeCar(nextState,action,result,site)
  local restore,err=GarageBridge.transform(action=='repair')
  if not restore then message(err,'error');return false end
  local target=site and {pos=U.copy(site.pos),rot=U.copy(site.rot)} or U.copy(restore)
  local cfg,configError=Bridge.configuration(content,nextState)
  if not cfg then message(configError,'error');return false end
  UiSession.enter();modal=true
  local ticket,beginError=transactions.begin(content,nextState,{target=target,restore=restore,action=action,
    cost=type(result)=='number' and result or 0,close=action=='repair' or (action=='tow' and Onboarding.pending(state)),
    label=action=='repair' and 'Repairing your car' or action=='tow' and 'Recovering your car' or 'Preparing your selected car'})
  if not ticket then message(beginError,'error');return false end
  return {pending=true,ticket=ticket}
end
function M.getTransactionResult(ticket) return transactions.result(ticket) end

showroom=WorkshopSession.new({
  state=function() return state end,
  configuration=function(paid) return Bridge.configuration(content,paid) end,
  capture=WorkshopBridge.capture,
  spawn=function(paid,site) return WorkshopBridge.spawn(content,paid,site) end,
  initialize=WorkshopBridge.initialize,
  ready=function(paid,id) return WorkshopBridge.ready(content,paid,id) end,
  allowed=function(site,id)
    local access=Workshop.context(content,state,Bridge.distance,Bridge.isStopped(),Bridge.busy() or street.busy())
    return access.ready and access.siteId==site and be:getPlayerVehicleID(0)==id
  end,
  place=function(paid,id,site) return WorkshopBridge.place(content,paid,id,site) end,
  present=WorkshopBridge.present,stats=WorkshopBridge.stats,restore=WorkshopBridge.restore,
  hold=function() modal=true;UiSession.enter() end,
  commit=commit,changed=function() if content then M.requestState() end end,
  finish=function(snapshot,id,target)
    WorkshopBridge.restore(snapshot,id)
    Atmosphere.apply(content,state)
    if target=='menu' then return leave(true)
    else
      if target=='board' then modal=true;boardPage='garage' else modal=false end
      -- Native navigate returns an explicit result after synchronous route hooks.
      -- Retain pause/session until it accepts; onWorkshopLeave sees handingOff.
      local result=ui_router.navigate(target=='board' and 'bngUnderground.board' or 'play')
      if not result or result.result~=true then
        modal=true;UiSession.enter()
        return false,'The requested game screen was not accepted.'
      end
      if target=='board' then UiSession.enter() else UiSession.leave() end
      return true
    end
  end,
})

local function openWorkshopScreen(siteId,presentation)
  local wasModal=modal
  local ok,err=showroom.enter(content,state,siteId,presentation,true)
  if not ok then message(err or 'The workshop could not be prepared.','error');return false end
  dismissActivity();UiSession.enter();modal=true
  -- Native navigation runs synchronous lifecycle hooks and reports acceptance.
  -- Keep the existing car and street scene until the screen has been accepted.
  local routed,result=pcall(ui_router.navigate,'bngUnderground.workshop')
  if not routed or not result or result.result~=true or not M.isActive() or not showroom.awaitingScreen() then
    showroom.cancelOpening()
    if M.isActive() then
      modal=wasModal
      if wasModal then UiSession.enter() else UiSession.leave() end
      message('The workshop screen could not open. Your car and saved build are unchanged. Try Enter workshop again.','error')
    else modal=false;UiSession.leave() end
    M.requestState();return false
  end
  UiSession.enter();modal=true
  showroom.open() -- a constructor fault now has a visible paused recovery screen
  M.requestState();return true
end
function M.enterWorkshop()
  if not M.isActive() or not content.settings.features.liveWorkshop then return false end
  if showroom.active() then return true end
  if transactions.active() then message('Wait for the car change to finish before entering the workshop.','info');return false end
  if pendingJoin or street.busy() or street.jobPending() or Onboarding.pending(state) then message('Finish campaign loading and choose your own car before entering a workshop.','info');return false end
  local access=Workshop.context(content,state,Bridge.distance,Bridge.isStopped(),Bridge.busy())
  if not access.ready then message(access.reason,'error');return false end
  if not Bridge.campaignVehicleId(content,state) then message('Bring your active owned car to the workshop.','error');return false end
  Workshop.resetVisit(access)
  return openWorkshopScreen(access.siteId)
end
function M.onWorkshopEnter()
  if not M.isActive() then
    modal=false;UiSession.leave()
    ui_router.navigate(getMissionFilename()~='' and 'play' or 'menu');return
  end
  modal=true;UiSession.enter()
  -- A direct route does not bypass the physical entry command or start a rebuild
  -- inside an unaccepted outer navigation. Return it to the collection instead.
  if not showroom.active() then M.showBoard('garage');return end
  M.requestState()
end
function M.onWorkshopLeave()
  if showroom.handingOff() then return end
  if showroom.awaitingScreen() then return end
  if showroom.active() then
    -- Route-level Back or an unexpected native route cannot expose unpaid parts.
    UiSession.enter();showroom.exit('play')
    if showroom.active() then ui_router.navigate('bngUnderground.workshop') end
  end -- The session's completed handoff owns pause release, including route order.
end
function M.onWorkshopStats(token,revision,id,value) return showroom.stats(token,revision,id,value) end

function M.open()
  if not M.isActive() then message('Start or continue BNG Underground using its button on the main menu.','info');return end
  if ui_appLayouts.isEditing() then message('Finish editing your UI layout before opening BNG Underground.','info');return end
  if modal then M.close() else M.showBoard() end
end

function M.close()
  if endingLevel then return false end
  if showroom.active() then return showroom.exit('play') end
  if pendingJoin or street.busy() or transactions.active() then return false end
  modal=false
  ui_router.navigate('play')
  -- Release happens when the menu route leaves, so the visible screen owns input.
  M.requestState()
end

function M.showBoard(page)
  if not M.isActive() or pendingJoin or street.busy() or Bridge.busy() then return false end
  boardPage=({city=true,events=true,garage=true,inbox=true,sponsors=true,progress=true,results=true})[page or 'city'] and (page or 'city') or 'city'
  if showroom.active() then return showroom.exit('board') end
  dismissActivity()
  UiSession.enter()
  local result=ui_router.navigate('bngUnderground.board')
  if result and result.result==false then UiSession.leave();return false end
  return true
end

function M.onMenuEnter() UiSession.enter() end
function M.onMenuLeave()
  if showroom.active() or transactions.active() or endingLevel then UiSession.enter()
  else UiSession.leave();if street.busy() then UiSession.enter() end end
end
function M.onBoardEnter()
  modal=true;UiSession.enter()
  if boardPage=='garage' and M.isActive() then Workshop.resetVisit(Workshop.context(content,state,Bridge.distance,Bridge.isStopped(),Bridge.busy())) end
  M.requestState()
end
function M.onBoardLeave()
  if showroom.active() then modal=true;UiSession.enter()
  elseif transactions.active() then modal=true;UiSession.enter();ui_router.navigate('bngUnderground.board')
  elseif endingLevel then UiSession.enter()
  else modal=false;UiSession.leave();if street.busy() then UiSession.enter() end end
  M.requestState()
end

-- A small read-only projection for the native Vue main-menu launch screen.
-- It does not create a profile, load a level, or activate ordinary Career.
function M.getLaunchData()
  if not load() then return {error=loadError,blockedSave=true,starters={}} end
  local data={version=content.settings.version,hasProfile=state~=nil,starters={},
    eventCount=#content.events,chapterCount=#content.chapters,carCount=#content.vehicles,
    startingCash=content.settings.startingCash,error=loadError,blockedSave=blockedSave,
    careerActive=Bridge.isCareer(),active=M.isActive(),busy=Bridge.busy() or pendingJoin or street.busy()}
  for _,id in ipairs(content.settings.starters) do
    local row=Content.vehicleView(content.vehiclesById[id])
    table.insert(data.starters,row)
  end
  if state then
    data.chapter=state.chapter;data.chapterName=content.chaptersById[state.chapter].name
    data.cash=state.cash;data.rep=state.rep;data.ownedCars=0
    data.introduction=Onboarding.pending(state)
    data.activeCarName=data.introduction and (content.settings.introduction.friend.."'s modified 200BX · opening drive") or content.vehiclesById[state.activeCar].name
    for _ in pairs(state.garage) do data.ownedCars=data.ownedCars+1 end
  end
  return data
end

local function abortJoin(err)
  active=false;pendingJoin=false;street.stop();UiSession.leave();ui_router.navigate('play');finishLoading()
  log('E','bngUnderground','Campaign join failed for vehicle '..tostring(joinVehicleId)..': '..tostring(err))
  message(tostring(err),'error');M.requestState()
end
local function joinCity()
  if not joinCarRequested then
    travelling=false
    Bridge.captureVehicle()
    Atmosphere.capture()
    local ok,err,id=Bridge.spawnCar(content,state,true)
    if not ok then
      abortJoin(err);return
    end
    joinCarRequested=true;joinVehicleId=id;joinVehicleClock=0
    log('I','bngUnderground','Campaign car requested; waiting for native nodes and map publication: '..tostring(id))
    return
  end
  if not joinCarReady then
    local checkOk,ready=pcall(Bridge.joinVehicleReady,content,state,joinVehicleId)
    if not checkOk then abortJoin(ready);return end
    if not ready then
      if joinVehicleClock>30 then
        abortJoin('The campaign car did not finish initializing. Return to the main menu and Continue to retry.')
      end
      return
    end
    local placeCall,placed,placeError=pcall(Bridge.placeJoinCar,content,state,joinVehicleId)
    if not placeCall then abortJoin(placed);return end
    if not placed then abortJoin(placeError);return end
    joinCarReady=true;joinVehicleClock=0
    Workshop.resetVisit(Workshop.context(content,state,Bridge.distance,Bridge.isStopped(),false))
    Atmosphere.apply(content,state);MissionIsolation.apply(content)
    Bridge.ensureApp(state,content.settings.features.minimap);Bridge.refreshMap()
    if StreetTraffic.enabled(content,state) then street.start(content.traffic) else street.stop() end
  end
  if street.busy() then return end
  if joinVehicleClock<0.25 then return end
  local focusCall,focused,focusError=pcall(Bridge.focusJoinCar,content,state,joinVehicleId)
  if not focusCall then abortJoin(focused);return end
  if not focused then
    abortJoin(focusError);return
  end
  Atmosphere.apply(content,state)
  log('I','bngUnderground','Campaign ready; player '..tostring(joinVehicleId)..' positioned at the home garage and camera restored.')
  pendingJoin=false
  modal=false;UiSession.leave();ui_router.navigate('play');M.requestState()
  finishLoading()
  if Onboarding.pending(state) then Bridge.navigate(content.locationsById[content.settings.introduction.dealership].pos);message(content.settings.introduction.friend..': Follow the GPS to Quarryside Auto Sales. My car is yours for the opening drive.') end
  if loadError then message(loadError,'info');loadError=nil end
end

local function begin(starter)
  local fresh=starter=='newCampaign'
  if blockedSave then return false,loadError end
  if pendingJoin or Bridge.busy() then return false,'A campaign or mission is already starting.' end
  if Bridge.isCareer() then return false,'Return to the main menu from ordinary Career before starting BNG Underground.' end
  if getMissionFilename()~='' then return false,'Return to the main menu before starting BNG Underground.' end
  if not state or fresh then
    local newState,err=Campaign.new(content,nil)
    if not newState then return false,err end
    if not commit(newState) then return false,'The new campaign could not be saved. Check the campaign error message.' end
  else
    local nextState=U.copy(state)
    if Inbox.sync(content,nextState)>0 and not commit(nextState) then return false,'The campaign inbox could not be saved.' end
  end
  dealerPrompted=false;boardPage='city';clearMapCaches()
  active=true;pendingJoin=true;joinCarReady=false;joinCarRequested=false;joinVehicleId=nil;joinVehicleClock=0;joinClock=0;cityLoaded=Bridge.isCity(content)
  core_gamestate.requestEnterLoadingScreen(loadingTag);loadingHeld=true
  -- Close the launch route before loading; finish the handoff again after spawn.
  UiSession.leave();modal=false;ui_router.navigate('play')
  if not Bridge.isCity(content) then
    travelling=true
    -- Native fourth argument suppresses the unrelated default car. Spawn the
    -- actual campaign build after the city-ready hook, behind our loading screen.
    if not freeroam_freeroam.startFreeroamByName(content.settings.level,'spawns_industrial',nil,false) then
      active=false;pendingJoin=false;travelling=false;finishLoading();ui_router.navigate('bngUnderground.launcher');return false,'West Coast, USA was not found.'
    end
  end
  M.requestState()
  return true
end

function M.launchFromMenu(starter)
  if not load() then return {ok=false,error=loadError} end
  if endingLevel then return {ok=false,error='Wait for the previous campaign level to close.'} end
  if transactions.active() then return {ok=false,error='Wait for the car change or restore the saved car before replacing the campaign.'} end
  local ok,err=begin(starter)
  if not ok then message(err,'error') end
  return {ok=ok,error=err}
end

leave=function(fromWorkshop)
  if showroom.active() and fromWorkshop~=true then return showroom.exit('menu') end
  if transactions.active() then message('Wait for your car or restore the saved car before leaving.','info');return end
  if pendingJoin or street.busy() then message('Wait for campaign loading to finish.','info');return end
  if Bridge.busy() then message('Finish or abandon the current mission before leaving the campaign.','error');return end
  if state then
    local ok,err=store.save(state)
    if not ok then message(err,'error');return false end
  end
  endingLevel=true;UiSession.enter()
  active=false;pendingJoin=false;raceRun=nil;rejectMission=nil;modal=false;street.stop()
  MissionIsolation.restore();clearMapCaches()
  finishLoading()
  Bridge.clearRoute();Atmosphere.restore();Bridge.clearVehicleSnapshot();Bridge.refreshMap()
  M.requestState();Bridge.restoreLayout()
  endActiveGameMode(function() ui_router.navigate('menu') end)
  return true
end

function M.command(action,arg)
  if not load() then message(loadError,'error');return end
  if endingLevel then return false end
  if transactions.active() then
    if action=='refresh' then return M.requestState() end
    if transactions.projection().phase=='fault' and action=='restoreSavedCar' then return transactions.restore() end
    if transactions.projection().phase=='fault' and action=='abortCarChange' then
      local saved,err=store.save(state)
      if not saved then message(err,'error');return false end
      endingLevel=true;transactions.cancel();UiSession.enter();modal=true
      endActiveGameMode(function() ui_router.navigate('menu') end)
      return true
    end
    message('Your car is still being prepared. The menu remains paused.','info');return false
  end
  if action=='begin' then M.launchFromMenu(arg);return end
  if action=='close' then M.close();return end
  if action=='leave' then return leave() end
  if action=='refresh' then M.requestState();return end
  if not M.isActive() then message('Resume BNG Underground first.','error');return end
  if action=='enterWorkshop' then return M.enterWorkshop() end
  if action=='workshopPreview' or action=='workshopBuy' or action=='workshopView' or action=='exitWorkshop' or action=='workshopAbort' or action=='workshopRecover' then
    if not showroom.active() then return false end
    if action=='exitWorkshop' then return showroom.exit(arg=='board' and 'board' or 'play') end
    if action=='workshopAbort' then
      -- End the level under our pause. An unpaid preview never gets a driving frame.
      if showroom.projection().phase~='fault' then return false end
      local saved,err=store.save(state)
      if not saved then message(err,'error');return false end
      endingLevel=true;showroom.abandon(true);street.stop();UiSession.enter()
      endActiveGameMode(function() ui_router.navigate('menu') end)
      return true
    end
    local ok,err
    if action=='workshopPreview' then ok,err=showroom.preview(arg)
    elseif action=='workshopBuy' then ok,err=showroom.buy(arg)
    elseif action=='workshopRecover' then ok,err=showroom.recover()
    else ok,err=showroom.view(arg) end
    if not ok and err then message(err,'error') end
    if ok and action=='workshopBuy' then message('Fitted and saved. This change is now yours.') end
    return ok
  end
  if showroom.active() then message('Leave the workshop before using campaign actions.','info');return false end
  if pendingJoin or street.busy() or street.jobPending() then message('Wait for campaign loading to finish.','info');return false end
  if action=='streetTraffic' or action=='retryTraffic' then
    if Bridge.busy() then message('Return to city driving before changing traffic.','info');return false end
    if action=='streetTraffic' then
      local nextState=U.copy(state)
      local ok,err=Campaign.command(content,nextState,action,arg)
      if not ok then message(err,'error');return false end
      if not commit(nextState) then return false end
    elseif not StreetTraffic.enabled(content,state) or not street.view(true,false).canRetry then return false end
    if StreetTraffic.enabled(content,state) then
      -- Close the paused board before holding a separate native loading cover.
      M.close()
      local ok,err=street.start(content.traffic)
      if not ok then message(err,'info') end
    else street.stop();if modal then UiSession.enter() end end
    M.requestState();return true
  end
  if action=='stockMenu' then modal=false;ui_router.navigate('pause');return end
  if action=='repair' then
    if Bridge.busy() or pendingJoin then message('Finish the current event before repairing.','error');return end
    local nextState=U.copy(state)
    local ok,cost=Campaign.command(content,nextState,action)
    if not ok then message(cost,'error');return end
    return changeCar(nextState,action,cost)
  end
  if action=='buyStarter' then
    local dealer=content.locationsById[content.settings.introduction.dealership]
    if not Onboarding.pending(state) or Bridge.busy() or Bridge.distance(dealer.pos)>20 or not Bridge.isStopped() then message('Park and stop at Quarryside Auto Sales to choose your starter.','error');return end
    local nextState=U.copy(state)
    local ok,err=Campaign.command(content,nextState,action,arg)
    if not ok then message(err,'error');return end
    return changeCar(nextState,action,err,dealer)
  end
  if Onboarding.pending(state) and action=='tow' then
    return changeCar(U.copy(state),action,0,content.locationsById.home)
  end
  if Onboarding.pending(state) and action~='navigateLocation' and action~='night' and action~='readMessage' and action~='readMessages' and action~='minimap' then message('Buy your own car at Quarryside Auto Sales before racing or modifying cars.','info');return end
  if action=='navigateEvent' or action=='navigateLocation' then
    if Bridge.busy() then message('Finish the current event before setting a city route.','error');return end
    local item=(action=='navigateEvent' and content.eventsById[arg]) or (action=='navigateLocation' and content.locationsById[arg])
    if not item or item.chapter>state.chapter then return end
    if action=='navigateEvent' and not M.canEnter(arg) then message('This event is still locked.','error');return end
    Bridge.navigate(item.pos);M.close();message('GPS set: '..item.name);return
  end
  if action=='startEvent' then
    local ok,err=M.canEnter(arg)
    if not ok then message(err,'error');return end
    if Bridge.busy() then message('A mission is already starting or running.','error');return end
    local event=content.eventsById[arg]
    if Bridge.distance(event.pos)>=75 and not (state.events[arg] and state.events[arg].cleared) then
      message('Drive to this meet first. Use Set GPS on the event card.','error');return
    end
    M.close()
    -- Native mission setup must not inherit our menu's physics pause.
    UiSession.leave()
    ok,err=Bridge.startEvent(event)
    if not ok then message(err,'error') end
    M.requestState();return
  end
  if Bridge.busy() then message('Return to the city before changing your campaign.','error');return end
  local workshopSite
  if garageActions[action] then
    local access=Workshop.context(content,state,Bridge.distance,Bridge.isStopped(),Bridge.busy())
    if not access.ready then message(access.reason,'error');return end
    workshopSite=content.locationsById[access.siteId]
  end
  if action=='showcase' then
    local access=Showcases.context(content,state,arg,Bridge.distance,Bridge.isStopped(),Bridge.busy())
    if not access.ready then message(access.reason,'error');return end
  end
  local nextState=U.copy(state)
  local ok,err=Campaign.command(content,nextState,action,arg)
  if not ok then message(err,'error');return end
  if garageActions[action] or action=='tow' then
    return changeCar(nextState,action,err,workshopSite or content.locationsById.home)
  else
    if not commit(nextState) then return end
  end
  if action=='night' then Atmosphere.apply(content,state) end
  if action=='minimap' then Bridge.ensureApp(state,content.settings.features.minimap) end
  if action=='tow' then message('Recovered to Mara\'s Garage. Cost: $'..tostring(err)..'.')
  elseif action=='signSponsor' then message('Contract signed. Different event wins count toward the target.')
  elseif action=='showcase' then message('Cover shoot complete. Payment received.')
  elseif action~='readMessage' and action~='readMessages' then message('Saved. Your campaign is up to date.') end
  M.requestState()
  return true -- acknowledgement only after the transaction is saved and published
end

local function prepareRaceSettings(mission,userSettings)
  if not M.isActive() or type(mission)~='table' then return false end
  local event=content.eventsByMission[mission.id]
  if not event then
    rejectMission=mission;message('Stock challenges are disabled in BNG Underground. Choose a campaign race.','info')
    return false
  end
  local ok,err=M.canEnter(event.id)
  if not ok then rejectMission=mission;message(err,'error');return false end
  if type(userSettings)~='table' then rejectMission=mission;return false end
  local defaults=Bridge.defaults(mission)
  for k in pairs(userSettings) do userSettings[k]=nil end
  for k,v in pairs(defaults) do userSettings[k]=v end
  return true
end
function M.onMissionStartWithFade(mission,userSettings)
  if not prepareRaceSettings(mission,userSettings) then return end
  -- Native marker starts and board starts both use the owned, paid-for build.
  local ok,err=Bridge.spawnCar(content,state,false)
  if not ok then rejectMission=mission;message(err,'error');return end
end
function M.startFromWithinMissionInstant(mission,userSettings,startingOptions)
  -- Native retries keep the existing initialized car; replacing it here would
  -- invalidate the native starting references without the fade preparation steps.
  prepareRaceSettings(mission,userSettings)
end

function M.onMissionReconfigured(data)
  if not M.isActive() or not data or not data.mission then return end
  data.newUserSettings=data.newUserSettings or {}
  prepareRaceSettings(data.mission,data.newUserSettings)
end

function M.onMissionAttemptAggregated(attempt,mission,progressKey)
  if not M.isActive() or not raceRun then return end
  if type(attempt)~='table' or type(mission)~='table' then return end
  if rejectMission and rejectMission.id==mission.id then return end
  local event=content.eventsByMission[mission.id]
  if not event or event.id~=raceRun.event or not RaceSession.matches(state,raceRun) then return end
  if gameplay_missions_missionManager.getForegroundMissionId()~=mission.id then return end
  local metrics=type(attempt.data)=='table' and attempt.data or {}
  -- Stable across duplicate callbacks and persisted before exposing a reward to the player.
  local receipt=RaceSession.receipt(raceRun,mission.id,attempt)
  if not receipt then return end
  local nextState=U.copy(state)
  local ok,result=Campaign.result(content,nextState,event.id,attempt.unlockedStars,receipt,metrics,attempt.date)
  if not ok then return end
  if not commit(nextState) then return end
  raceRun.receipt=receipt
  message(result.won and (event.name..': +$'..result.cash..' / +'..result.rep..' REP') or (event.name..': keep building, keep driving.'))
end

function M.onAnyMissionChanged(status,mission)
  if not content or type(mission)~='table' then return end
  if status=='stopped' then
    raceRun=RaceSession.stopped(raceRun,mission.id)
    if rejectMission and rejectMission.id==mission.id then rejectMission=nil end
  end
  if status=='started' and M.isActive() then
    if gameplay_missions_missionManager.getForegroundMissionId()~=mission.id or mission._isOngoing~=true then return end
    if rejectMission and rejectMission.id==mission.id then return end
    local event=content.eventsByMission[mission.id]
    if not event then
      rejectMission=mission;message('Stock challenges are disabled in BNG Underground. Choose a campaign race.','info');return
    end
    local allowed,reason=M.canEnter(event.id)
    local id=Bridge.campaignVehicleId(content,state)
    if not allowed or not id or not WorkshopBridge.ready(content,state,id) then
      rejectMission=mission;message(reason or 'Race in your initialized active owned car. Return to the city and try again.','error');return
    end
    local ok,run=RaceSession.started(content,state,raceRun,mission.id,commit)
    if not ok then rejectMission=mission;message(run,'error');return end
    raceRun=run;modal=false;M.requestState();return
  end
  if not content.eventsByMission[mission.id] then
    if status=='stopped' and M.isActive() then Bridge.spawnCar(content,state,false);notifyClock=1 end
    return
  end
  if status=='stopped' then
    if M.isActive() then notifyClock=1 end
  end
end

function M.onClientStartMission(levelPath)
  if pendingJoin and Bridge.isCity(content) then cityLoaded=true end
end

function M.onUpdate(dtReal)
  UiSession.update()
  showroom.update(dtReal)
  transactions.update(dtReal)
  street.update(dtReal,Bridge.busy())
  if modal and not Bridge.busy() then dismissActivity() end
  if not content then return end
  if not M.isActive() then rejectMission=nil end
  if rejectMission and not gameplay_missions_missionManager.isCurrentlyProcessingStep() then
    if gameplay_missions_missionManager.getForegroundMissionId()==rejectMission.id then
      gameplay_missions_missionManager.stop(rejectMission,{abandoned=true})
    end
    rejectMission=nil
  end
  if pendingJoin and cityLoaded and Bridge.isCity(content) and not Bridge.busy() then
    joinClock=joinClock+dtReal
    if joinCarRequested then joinVehicleClock=joinVehicleClock+dtReal end
    if joinClock>2 then joinCity() end
  end
  if not M.isActive() then return end
  if notifyClock>0 then
    notifyClock=notifyClock-dtReal
    if notifyClock<=0 then
      if Bridge.busy() then notifyClock=0.5
      else Bridge.ensureApp(state,content.settings.features.minimap);Atmosphere.apply(content,state);M.requestState() end
    end
  end
  updateClock=updateClock+dtReal
  if updateClock<1 then return end
  updateClock=0
  if not Bridge.busy() and not pendingJoin and not street.busy() and not transactions.active() then
    if MissionIsolation.apply(content) then Bridge.refreshMap() end
    Bridge.ensureApp(state,content.settings.features.minimap)
    if not Onboarding.pending(state) and not modal then
      local access=Workshop.context(content,state,Bridge.distance,Bridge.isStopped(),false)
      if Workshop.shouldPrompt(access) then message('Workshop ready · choose Enter workshop at the parking bay, or Start → Garage → Enter workshop.','info') end
    end
    if Onboarding.pending(state) then
      local dealer=content.locationsById[content.settings.introduction.dealership]
      if not dealerPrompted and not modal and Bridge.distance(dealer.pos)<=20 and Bridge.isStopped() then
        dealerPrompted=true;M.showBoard('garage')
      end
    elseif content.settings.features.discovery then
      for _,site in ipairs(content.locations) do
        if site.chapter<=state.chapter and not state.discovered[site.id] and Bridge.distance(site.pos)<=content.settings.shopRadius then
          local nextState=U.copy(state)
          if Campaign.discover(content,nextState,site.id) and commit(nextState) then message('Discovered '..site.name..' / +'..content.settings.discoveryRep..' REP') end
        end
      end
    end
  end
  if modal then M.requestState() end
end

function M.onVehicleGroupSpawned(vehList,groupId,groupName) street.groupSpawned(vehList,groupName) end
function M.onVehicleMapmgrUpdate(id) street.mapReady(id) end

function M.onGetRawPoiListForLevel(level,elements)
  if not M.isActive() or level~=content.settings.level then return end
  for _,site in ipairs(content.locations) do
    if site.chapter<=state.chapter then
      local markers={bigmapMarker={pos=vec3(site.pos),icon=site.type=='meet' and 'camera' or 'garage',
        name='BNG Underground | '..site.name,description=site.description,cluster=false}}
      if site.parkingScale then
        markers.parkingMarker={path='bngUnderground/'..site.id,pos=vec3(site.pos),rot=quat(site.rot),
          scl=vec3(site.parkingScale),icon='poi_garage_2_round',mode='overlap'}
      end
      table.insert(elements,{id='bngu_'..site.id,clusterType='walkingMarker',
        data={id='bngu_'..site.id,type='bnguLocation',locationId=site.id},
        markerInfo=markers})
    end
  end
end

function M.onActivityAcceptGatherData(elements,activities)
  if not M.isActive() or Bridge.busy() then return end
  for _,entry in ipairs(elements) do
    if entry.type=='bnguLocation' then
      local site=content.locationsById[entry.locationId]
      if site and (site.type=='garage' or site.type=='shop' or (site.type=='dealership' and Onboarding.pending(state))) then
        table.insert(activities,{icon='garage',heading=site.name,preheadings={'BNG Underground'},
          buttonLabel=site.type=='dealership' and 'Choose your starter' or 'Enter workshop',
          sorting={type='bnguLocation',id=entry.id},buttonFun=function()
            dismissActivity()
            if site.type=='dealership' or not content.settings.features.liveWorkshop then M.showBoard('garage') else M.enterWorkshop() end
          end})
      end
    end
  end
end

function M.onBeforeRadialOpened()
  if radialAdded then return end
  radialAdded=true
  core_quickAccess.addEntry({level='/root/',title='BNG Underground',icon='AIRace',priority=85,
    uniqueID='bnguCampaign',onSelect=function() M.open();return {'hide'} end})
end

function M.onClientEndMission()
  endingLevel=false
  cityLoaded=false
  transactions.cancel()
  showroom.abandon(true)
  street.endLevel();joinCarReady=false;joinCarRequested=false;joinVehicleId=nil;joinVehicleClock=0
  MissionIsolation.restore();clearMapCaches()
  if not travelling then Bridge.restoreLayout() end
  UiSession.leave()
  if not travelling then finishLoading() end
  if state and store then store.save(state) end
  if not travelling then active=false;pendingJoin=false end
  raceRun=nil;rejectMission=nil;modal=false
  Atmosphere.clear();Bridge.clearVehicleSnapshot();Bridge.clearLayoutSnapshot()
end
function M.onCareerActive(careerActive)
  if careerActive then
    endingLevel=false
    transactions.cancel()
    showroom.abandon(false)
    street.stop()
    MissionIsolation.restore();clearMapCaches()
    UiSession.leave()
    finishLoading()
    active=false;pendingJoin=false;travelling=false;raceRun=nil;rejectMission=nil;modal=false
    Atmosphere.restore();Bridge.restoreLayout();Bridge.clearVehicleSnapshot();Bridge.refreshMap()
  end
end
function M.onExtensionLoaded()
  setExtensionUnloadMode(M,'manual')
  -- Register integrations now; catalogs and profile load on the launch screen.
  -- Mods mount after some core extensions; rescan additive condition files once.
  gameplay_missions_unlocks.onExtensionLoaded()
  Bridge.refreshMap()
end
function M.onExtensionUnloaded()
  raceRun=nil;rejectMission=nil
  local interrupted=transactions.snapshot()
  if interrupted and content and state then GarageBridge.spawn(content,state,interrupted.context.restore) end
  transactions.cancel()
  showroom.abandon(false)
  street.stop()
  MissionIsolation.restore();clearMapCaches()
  UiSession.leave()
  finishLoading()
  if state and store then store.save(state) end
  if active then Atmosphere.restore();Bridge.restoreLayout();Bridge.refreshMap() end
end
function M.onSerialize()
  return {active=active,modal=modal,bridge=Bridge.snapshot(),atmosphere=Atmosphere.snapshot(),uiSession=UiSession.snapshot(),
    raceRun=U.copy(raceRun),isolation=MissionIsolation.snapshot(),streetTraffic=street.snapshot(),
    pendingJoin=pendingJoin,joinCarReady=joinCarReady,joinCarRequested=joinCarRequested,joinVehicleId=joinVehicleId,joinVehicleClock=joinVehicleClock,joinClock=joinClock,cityLoaded=cityLoaded,
    workshop=showroom.snapshot(),carTransaction=transactions.snapshot()}
end
function M.onDeserialized(data)
  if data and data.active and load() and state and not Bridge.isCareer() then
    Bridge.restoreSnapshot(data.bridge);Atmosphere.restoreSnapshot(data.atmosphere)
    UiSession.restore(data.uiSession)
    active=true;modal=data.modal;notifyClock=1
    raceRun=RaceSession.restore(content,state,data.raceRun or {event=data.activeEvent,serial=data.sessionSerial},gameplay_missions_missionManager.getForegroundMissionId())
    rejectMission=nil
    pendingJoin=data.pendingJoin==true;joinCarReady=data.joinCarReady==true;joinClock=data.joinClock or 0;cityLoaded=data.cityLoaded==true
    joinVehicleId=data.joinVehicleId or (joinCarReady and Bridge.campaignVehicleId(content,state) or nil)
    joinCarRequested=data.joinCarRequested==true or joinVehicleId~=nil;joinVehicleClock=data.joinVehicleClock or 0
    if pendingJoin and joinCarReady and not joinVehicleId then joinCarReady=false;joinCarRequested=false end
    street.restore(data.streetTraffic)
    if not StreetTraffic.enabled(content,state) then street.stop() end
    if pendingJoin then core_gamestate.requestEnterLoadingScreen(loadingTag);loadingHeld=true end
    MissionIsolation.restoreSnapshot(data.isolation);MissionIsolation.apply(content);Bridge.refreshMap()
    if data.workshop and content.settings.features.liveWorkshop and not pendingJoin and content.locationsById[data.workshop.site] then
      UiSession.enter();modal=true
      openWorkshopScreen(data.workshop.site,data.workshop.presentation)
    elseif data.carTransaction and not pendingJoin then
      UiSession.enter();modal=true;boardPage='garage'
      transactions.recover(content,data.carTransaction.context)
      ui_router.navigate('bngUnderground.board')
    end
  end
end
-- Read-only inspection for in-engine validation and support.
function M.getDiagnostics()
  return {active=active,chapter=state and state.chapter,event=raceRun and raceRun.event,raceRun=U.copy(raceRun),saveError=loadError,
    version=content and content.settings.version,events=content and #content.events,
    level=getCurrentLevelIdentifier(),profileValid=state and Campaign.validate(content,state) or false,
    streetTraffic=street.view(state and StreetTraffic.enabled(content,state) or false,Bridge.busy()),
    join={pending=pendingJoin,requested=joinCarRequested,ready=joinCarReady,vehicleId=joinVehicleId,waitSeconds=joinVehicleClock},
    workshop=showroom.projection(),carTransaction=transactions.projection()}
end
return M
