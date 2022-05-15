
function MigrateDataFromOriginalAddon(mapSystemNames)
  local points = userMods.GetGlobalConfigSection("HerbMap")
  points = FilterPoints(points)
  if not points or #points == 0 then
    Log("Нет данных для миграции с HerbMap")
    return nil
  end
  points = NormalizeMapNames(points, mapSystemNames)
  points = RemoveDuplicates(points)
  points = GroupByMap(points)
  userMods.SetGlobalConfigSection("HerbMap", nil)
  Log("Миграция данных завершена")
  return points
end

function FilterPoints(points)
  if not points then
    return nil
  end
  local result = {}
  for _, point in pairs(points) do
    if point.NAME then
      result[#result + 1] = point
    end
  end
  Log("Отфильтровано точек: " .. #result)
  return result
end

function NormalizeMapNames(points, mapSystemNames)
  function MapNameToSystemName(mapName)
    local normalizedMapName = userMods.FromWString(mapName)
    for name, sysName in pairs(mapSystemNames) do
      if name == normalizedMapName then
        return sysName
      end
    end
    return mapName
  end

  for key, point in pairs(points) do
    local mapName = point.MAP
    if common.GetApiType(mapName) == "WString" then
      points[key].MAP = MapNameToSystemName(mapName)
    end
  end
  return points
end

function RemoveDuplicates(points)
  local result = {}
  local filtered = {}
  for _, point in pairs(points) do
    local hash = point.posX .. "x" .. point.posY
    if not filtered[hash] then
      result[#result + 1] = point
      filtered[hash] = true
    end
  end
  Log("Удалено точек-дубликатов: " .. (#points - #result) .. ", всего точек: " .. #result)
  return result
end

function GroupByMap(points)
  local result = {}
  for _, point in pairs(points) do
    local mapPoints = result[point.MAP] or {}
    mapPoints[#mapPoints + 1] = {
      name = point.NAME,
      icon = point.ICON == "GORN" and "ORE" or point.ICON,
      posX = point.posX,
      posY = point.posY,
    }
    result[point.MAP] = mapPoints
  end
  return result
end
