local isDebugEnabled = false

function Log(message)
  if not isDebugEnabled then return end

  common.LogInfo(common.GetAddonName(), message)
  LogToChat(message)
end

function LogTable(table, level)
  if not isDebugEnabled then return end

  local indent = level or 1
  for k, v in pairs(table) do
    if (type(v) == "table") then
      Log(string.rep(" ", indent) .. tostring(k) .. " = {")
      LogTable(v, indent + 2)
      Log(string.rep(" ", indent) .. "}")
    else
      Log(string.rep(" ", indent) .. tostring(k) .. " = " .. tostring(v))
    end
  end
end

--------------------------------------------------------------------------------
--- Texture caches
--------------------------------------------------------------------------------
local _textureGroups = {}
local _textureCache = {}

--- Получить текстуру sysName из текстурной группы аддона sysGroup (группа должна существовать)
function GetAddonTexture(sysGroup, sysName)
  local group = _textureGroups[sysGroup]
  if not group then
    group = common.GetAddonRelatedTextureGroup(sysGroup)
    _textureGroups[sysGroup] = group
    _textureCache[sysGroup] = {}
  end
  local result = _textureCache[sysGroup][sysName]
  if result == nil then
    result = group:HasTexture(sysName) and group:GetTexture(sysName)
    _textureCache[sysGroup][sysName] = result
  end
  if result == false then
    assert(false, "Non-existent texture requested: " .. tostring(sysName))
  end
  return result
end