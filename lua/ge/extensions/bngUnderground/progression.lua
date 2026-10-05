local U = require('/lua/ge/extensions/bngUnderground/util')
local M = {}
function M.wins(content, state, chapterId)
  local count = 0
  for _, event in ipairs(content.events) do
    if event.chapter == chapterId and not event.boss and state.events[event.id] and state.events[event.id].cleared then count = count + 1 end
  end
  return count
end
function M.canEnter(content, state, eventId)
  if state.intro and state.intro.stage=='dealership' then return false,'Buy your own starter at Quarryside Auto Sales first.' end
  local event = content.eventsById[eventId]
  if not event then return false, 'Unknown event.' end
  if event.chapter > state.chapter then return false, 'Defeat the previous district rival first.' end
  if event.boss and not (state.events[event.id] and state.events[event.id].cleared) then
    local chapter = content.chaptersById[event.chapter]
    local wins = M.wins(content, state, event.chapter)
    if wins < chapter.requiredWins then return false, ('Clear %d more different events in this chapter.'):format(chapter.requiredWins-wins) end
    if state.rep < chapter.requiredRep then return false, ('Earn %d more reputation.'):format(chapter.requiredRep-state.rep) end
  end
  return true
end
function M.view(content,state)
  local chapters={}
  for _,chapter in ipairs(content.chapters) do
    local row=U.copy(chapter)
    row.clears=M.wins(content,state,chapter.id)
    row.current=chapter.id==state.chapter and not state.completed
    row.unlocked=chapter.id<=state.chapter
    row.regularCount=0;row.unlocks={}
    for _,event in ipairs(content.events) do
      if event.chapter==chapter.id then
        if event.boss then
          row.rivalEventId=event.id;row.rivalName=event.name
          row.rivalCleared=state.events[event.id]~=nil and state.events[event.id].cleared==true
          row.rivalOpen,row.rivalReason=M.canEnter(content,state,event.id)
        else row.regularCount=row.regularCount+1 end
      end
    end
    for _,car in ipairs(content.vehicles) do
      if car.chapter==chapter.id then table.insert(row.unlocks,{name=car.name,cost=car.price,type='Car'}) end
    end
    for _,tier in ipairs(content.settings.upgradeTiers) do
      if tier.chapter==chapter.id then table.insert(row.unlocks,{name=tier.name,cost=tier.cost,type='Build'}) end
    end
    if chapter.id==2 then table.insert(row.unlocks,{name='Specialist drag builds',type='Build'}) end
    if content.settings.features.parts~=false then
      for _,category in ipairs(content.partsShop.categories) do
        if not category.feature or content.settings.features[category.feature]~=false then
          local total,minimum,maximum=0,nil,nil
          for _,car in ipairs(content.vehicles) do
            if car.chapter<=chapter.id then
              for _,option in ipairs(car.partsCatalog.options) do
                if option.category==category.id and option.chapter==chapter.id then
                  total=total+1;minimum=math.min(minimum or option.cost,option.cost);maximum=math.max(maximum or option.cost,option.cost)
                end
              end
            end
          end
          if total>0 then table.insert(row.unlocks,{name=category.name,type='Parts',count=total,costMin=minimum,costMax=maximum}) end
        end
      end
    end
    if content.settings.features.showcases then
      for _,site in ipairs(content.locations) do
        if site.chapter==chapter.id and site.showcaseStyle then
          table.insert(row.unlocks,{name=site.name,type='Cover',reward=site.showcaseReward,style=site.showcaseStyle})
        end
      end
    end
    table.insert(chapters,row)
  end
  return chapters
end
function M.advance(content, state, event)
  if not event.boss or event.chapter ~= state.chapter then return nil end
  if state.chapter == #content.chapters then
    if state.completed then return nil end
    state.completed = true
    return {sender='Mara', title='The city knows your name',
      text='Nocturne is beaten. You built this from a first set of keys. Every meet stays open: chase gold, finish your garage, and keep the Underground alive.'}
  end
  state.chapter = state.chapter + 1
  local nextChapter = content.chaptersById[state.chapter]
  return {sender=nextChapter.sender,title=nextChapter.name,text=nextChapter.intro}
end
return M
