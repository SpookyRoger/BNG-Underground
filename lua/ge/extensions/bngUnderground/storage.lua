-- Injectable persistence keeps the domain independent of the game's filesystem.
local U = require('/lua/ge/extensions/bngUnderground/util')
local Campaign = require('/lua/ge/extensions/bngUnderground/campaign')
local M = {}
function M.new(content, io)
  local dir='/settings/bngUnderground/'
  local path=dir..'profile.json'
  local backup=dir..'profile.backup.json'
  local lastGood
  io=io or {
    read=jsonReadFile,
    exists=function(p) return FS:fileExists(p) end,
    mkdir=function(p) FS:directoryCreate(p) end,
    write=function(p,data) return jsonWriteFile(p,data,true,nil,true) end
  }
  local store={}
  local function valid(value)
    local ok,result=pcall(Campaign.validate,content,value)
    return ok and result==true
  end
  local function read(p)
    local ok,value=pcall(io.read,p)
    return ok and value or nil
  end
  local function write(p,value)
    local ok,result=pcall(io.write,p,value)
    return ok and result==true
  end
  function store.load()
    local primary=io.exists(path) and read(path) or nil
    if type(primary)=='table' and type(primary.schema)=='number' and primary.schema>content.settings.saveSchema then
      return nil,'This save belongs to a newer BNG Underground release. It has been preserved. Use a compatible release to continue.',true
    end
    if valid(primary) then lastGood=U.copy(primary);return primary end
    local fallback=io.exists(backup) and read(backup) or nil
    if valid(fallback) then
      lastGood=U.copy(fallback)
      return fallback,'The previous good save was recovered. Your most recent transaction may need repeating.'
    end
    if io.exists(path) or io.exists(backup) then return nil,'The campaign save could not be read. It has been preserved; restore a valid backup before continuing.',true end
    return nil
  end
  function store.save(state)
    if not valid(state) then return false,'The campaign state failed validation. Your last good save is preserved.' end
    if not pcall(io.mkdir,dir) then return false,'Could not create the campaign save folder.' end
    if lastGood and not write(backup,lastGood) then return false,'Could not write the backup. Progress has not been committed.' end
    if not write(path,state) then return false,'Could not save campaign progress. Check free disk space and folder access.' end
    lastGood=U.copy(state)
    return true
  end
  return store
end
return M
