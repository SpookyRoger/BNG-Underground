-- Persistent, optional invitations. They never lock the player into a race.
local U = require('/lua/ge/extensions/bngUnderground/util')
local P = require('/lua/ge/extensions/bngUnderground/progression')
local Onboarding = require('/lua/ge/extensions/bngUnderground/onboarding')
local M = {}
function M.prepare(state)
  state.messageFlags=state.messageFlags or {}
  state.messageSerial=state.messageSerial or 0
  local used,seen={},{}
  -- Reserve every existing ID before assigning new ones, including legacy saves.
  for _,entry in ipairs(state.inbox) do if entry.id then used[entry.id]=true end end
  for _,entry in ipairs(state.inbox) do
    if not entry.id or seen[entry.id] then
      local id
      repeat
        state.messageSerial=state.messageSerial+1
        id='message-'..state.messageSerial
      until not used[id]
      entry.id=id;used[id]=true
    end
    seen[entry.id]=true
    if entry.read==nil then entry.read=false end
  end
end
function M.add(state,entry,limit)
  U.push(state.inbox,entry,limit or 80)
  M.prepare(state)
end
function M.sync(content,state)
  M.prepare(state)
  if Onboarding.pending(state) or not content.settings.features.messaging then return 0 end
  local count=0
  for _,invite in ipairs(content.invitations) do
    if not state.messageFlags[invite.id] and state.chapter>=invite.chapter and
      P.wins(content,state,invite.chapter)>=(invite.wins or 0) and P.canEnter(content,state,invite.eventId) then
      local record=state.events[invite.eventId]
      if not (invite.rival and record and record.cleared) then
        state.messageFlags[invite.id]=true
        U.push(state.inbox,{id=invite.id,sender=invite.sender,title=invite.title,text=invite.text,
          eventId=invite.eventId,read=false},80)
        count=count+1
      else state.messageFlags[invite.id]=true end
    end
  end
  if content.settings.features.tuning~=false then
    local highestTier=0
    for _,car in pairs(state.garage) do highestTier=math.max(highestTier,car.tier) end
    for _,note in ipairs(content.workshopNotes or {}) do
      if not state.messageFlags[note.id] and state.chapter>=note.chapter and highestTier>=note.tier then
        state.messageFlags[note.id]=true
        M.add(state,{id=note.id,sender=note.sender,title=note.title,text=note.text,locationId=note.locationId,read=false})
        count=count+1
      end
    end
  end
  return count
end
function M.read(state,id)
  M.prepare(state)
  for _,entry in ipairs(state.inbox) do if entry.id==id then entry.read=true;return true end end
  return false,'Message not found.'
end
function M.unread(state)
  local count=0
  for _,entry in ipairs(state.inbox) do if not entry.read then count=count+1 end end
  return count
end
function M.readMany(state,ids)
  if type(ids)~='table' or #ids<1 or #ids>80 then return false,'Choose between one and eighty messages.' end
  local size,entries,seen,count=#ids,{}, {},0
  for key,id in pairs(ids) do
    if type(key)~='number' or key%1~=0 or key<1 or key>size or type(id)~='string' or id=='' or seen[id] then
      return false,'Invalid message selection.'
    end
    seen[id]=true;count=count+1
  end
  if count~=size then return false,'Invalid message selection.' end
  M.prepare(state)
  local indexed=U.index(state.inbox)
  for _,id in ipairs(ids) do
    if not indexed[id] then return false,'Messages changed. Review the conversation and try again.' end
    entries[#entries+1]=indexed[id]
  end
  -- Validate the whole selection before changing any read state.
  for _,entry in ipairs(entries) do entry.read=true end
  return true
end
return M
