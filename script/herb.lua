local isDebugEnabled = true

function Log(message)
  if not isDebugEnabled then return end

  common.LogInfo(common.GetAddonName(), message)
  LogToChat(message)
end

function GetMiniMapWidget(parent, name)
  return {
    Name = name,
    Engine = parent:GetChildChecked(name, false):GetChildChecked("Map", false):GetChildChecked("MapEngine", false)
  }
end

local MainMap = stateMainForm:GetChildChecked("Map", false):GetChildChecked("MainPanel", false):GetChildChecked("LayoutMain", false):GetChildChecked("MapEnginePanel", true)
local MainMapLabel = MainMap:GetChildChecked("Texts", false):GetChildChecked("MapLabel", false)

local MiniMap = stateMainForm:GetChildChecked("Minimap", false)
local SquareMiniMap = GetMiniMapWidget(MiniMap, "Square")
local CircleMiniMap = GetMiniMapWidget(MiniMap, "Circle")

local miniMapInfo = {
  Name = nil,
  MapSize = nil,
  Engine = nil,
}

local wtMainPanel = mainForm:GetChildChecked("MainPanel", false)
local wtMiniMapPanel = mainForm:GetChildChecked("MiniMapPanel", false)

local wtTooltip = mainForm:GetChildChecked("Tooltip", false)
local wtTooltipText = wtTooltip:GetChildChecked("TooltipText", false)

local wtBtn = mainForm:GetChildChecked("btn", false)

local points = {}

local wtPoint = {}
local wtPointMini = {}

local ShowMap = true
local mapSystemNames = {}

-- чекКнопки для отображения информации
local wtListPanel = mainForm:GetChildChecked("listpanel", false)
local cB = wtListPanel:GetChildChecked("cbtn", false)
cB:Show(false)
local cBt = wtListPanel:GetChildChecked("cfgtxt", false)
cBt:Show(false)
local cBtn = {} -- с галочкой
local sB = wtListPanel:GetChildChecked("bottom", false)
sB:Show(false)
local sBtn = {} -- просто кнопки

--------------------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------------------

function GetActiveMiniMap()
  if SquareMiniMap.Engine:IsVisibleEx() then
    return SquareMiniMap
  elseif CircleMiniMap.Engine:IsVisibleEx() then
    return CircleMiniMap
  else
    return nil
  end
end

function PosXY(wt, posX, sizeX, posY, sizeY, alignX, alignY)
  local Placement = wt:GetPlacementPlain()
  if posX then Placement.posX = posX end
  if sizeX then Placement.sizeX = sizeX end
  if posY then Placement.posY = posY end
  if sizeY then Placement.sizeY = sizeY end
  if alignX then Placement.alignX = alignX end
  if alignY then Placement.alignY = alignY end
  wt:SetPlacementPlain(Placement)
end

function IsPointInCircle(point, center, radius)
  local dx = math.abs(point.posX - center.posX)
  local dy = math.abs(point.posY - center.posY)
  if dx + dy <= radius then return true end
  if dx > radius or dy > radius then return false end
  return dx^2 + dy^2 <= radius^2
end

function LoadPoints()
  local loaded = userMods.GetGlobalConfigSection("HerbMap")
  if not loaded then
    return
  end
  points = loaded
  Log(#points .. " точек загружено")
end

function SavePoints()
  if points then
    userMods.SetGlobalConfigSection("HerbMap", points)
    Log(#points .." точек записано")
  end
end

function LoadMapsDictionary()
  local zones = rules.GetZonesMaps()
  for _, zoneId in pairs(zones) do
    local mapInfo = cartographer.GetZonesMapInfo(zoneId)
    mapSystemNames[userMods.FromWString(mapInfo.name)] = mapInfo.sysName
  end
end

function MigrateData()
  Migration_1_2()
  SavePoints()
end

function Migration_1_2()
  function MapNameToSystemName(mapName)
    local normalizedMapName = userMods.FromWString(mapName)
    for name, sysName in pairs(mapSystemNames) do
      if name == normalizedMapName then
        return sysName
      end
    end
    return mapName
  end

  for i = 1, #points do
    local mapName = points[i].MAP
    if common.GetApiType(mapName) == "WString" then
      points[i].MAP = MapNameToSystemName(mapName)
    end
  end
end

function SelectedMapName()
  return userMods.FromWString(common.ExtractWStringFromValuedText(MainMapLabel:GetValuedText()))
end

function SelectedMapID()
  local sysName = mapSystemNames[SelectedMapName()]
  return cartographer.GetZonesMapId(sysName)
end

function RenderMapPoints()
  function FindGeodata(mapId)
    local markers = cartographer.GetMapMarkers(mapId)
    for _, markerId in pairs(markers) do
      local markerObjects = cartographer.GetMapMarkerObjects(mapId, markerId)
      for _, data in pairs(markerObjects) do
        if data.geodata then
          return data.geodata
        end
      end
    end
  end

  local geodata = FindGeodata(SelectedMapID())
  if not geodata then
    Log("Не удалось получить геодату для выбранной зоны: " .. SelectedMapName())
    for _, wt in pairs(wtPoint) do
      wt:Show(false)
    end
    return
  end

  RenderPoints(wtMainPanel:GetPlacementPlain(), geodata, mapSystemNames[SelectedMapName()], wtPoint, wtMainPanel)
end

function RenderMiniMapPoints()
  Log("Render " .. #points .. " points")
  local geodata = cartographer.GetObjectGeodata(avatar.GetId())
  if not geodata then
    Log("Не удалось получить геодату для текущей зоны")
    for _, wt in pairs(wtPointMini) do
      wt:Show(false)
    end
    return
  end

  local currentMapName = cartographer.GetZonesMapInfo(unit.GetZonesMapId(avatar.GetId())).sysName
  RenderPoints(wtMiniMapPanel:GetPlacementPlain(), geodata, currentMapName, wtPointMini, wtMiniMapPanel)
end

function RenderPoints(mapSize, geodata, mapSysName, container, parent)
  local pixelsPerMeterX = mapSize.sizeX / geodata.width
  local pixelsPerMeterY = mapSize.sizeY / geodata.height

  for i = 1, #points do
    if mapSysName == points[i].MAP then
      local isPinVisible = (Settings.ShowPoints.HERB and points[i].ICON == "HERB") or (Settings.ShowPoints.ORE and points[i].ICON == "GORN")
      if container[i] then
        container[i]:Show(isPinVisible)
      else
        container[i] = mainForm:CreateWidgetByDesc(wtBtn:GetWidgetDesc())
        container[i]:SetName("wtPoint" .. i)
        container[i]:Show(isPinVisible)
        parent:AddChild(container[i])
        if points[i].ICON then
          local textureId = common.GetAddonRelatedTexture(points[i].ICON)
          container[i]:SetBackgroundTexture(textureId)
        end
      end
      local sizeX = 15
      local sizeY = 20
      local posX = (points[i].posX - geodata.x) * pixelsPerMeterX
      local posY = ((geodata.y + geodata.height) - points[i].posY) * pixelsPerMeterY
      PosXY(container[i], posX - sizeX / 2, sizeX, posY - sizeY, sizeY)
    else
      if container[i] then
        container[i]:Show(false)
      end
    end
  end
end

function RefreshMapOverlay()
  if not MainMap:IsVisibleEx() then
    wtMainPanel:Show(false)
    wtListPanel:Show(false)
    return
  end

  wtMainPanel:Show(ShowMap)
  wtListPanel:Show(true)

  local placement = MainMap:GetPlacementPlain()
  wtMainPanel:SetPlacementPlain(placement)
  MainMap:AddChild(wtMainPanel)

  RenderMapPoints()
end

function RefreshMiniMapOverlay()
  local activeMiniMap = GetActiveMiniMap()
  if not activeMiniMap then
    wtMiniMapPanel:Show(false)
    return
  end

  wtMiniMapPanel:Show(true)

  local placement = activeMiniMap.Engine:GetPlacementPlain()
  PosXY(wtMiniMapPanel, nil, placement.sizeX, nil, placement.sizeY)
  activeMiniMap.Engine:AddChild(wtMiniMapPanel)

  RenderMiniMapPoints()
end

function CheckMiniMapScale()
  local activeMiniMap = GetActiveMiniMap()
  if not activeMiniMap then
    return
  end

  local name = activeMiniMap.Name
  local pl = activeMiniMap.Engine:GetPlacementPlain()
  local mapSize = pl.sizeX .. "x" .. pl.sizeY

  if name ~= miniMapInfo.Name or mapSize ~= miniMapInfo.MapSize then
    Log("Изменился масштаб миникарты: " .. mapSize .. " и/или форма: " .. name)
    miniMapInfo.Name = name
    miniMapInfo.MapSize = mapSize
    miniMapInfo.Engine = activeMiniMap.Engine
    RefreshMiniMapOverlay()
  end
end

--------------------------------------------------------------------------------
-- EVENT HANDLERS
--------------------------------------------------------------------------------

-- EVENT_AVATAR_CREATED
function OnCreate()
  LoadMapsDictionary()
  LoadPoints()
  MigrateData()

  MainMap:AddChild(wtListPanel)

  local txt = {}
  PosXY(wtListPanel, 100, 200, 50, 20 * 5 + 55)
  for i = 1, 2 do -- с галочкой
    cBtn[i] = mainForm:CreateWidgetByDesc(cB:GetWidgetDesc())
    cBtn[i]:SetName("cBtn" .. i)
    wtListPanel:AddChild(cBtn[i])
    PosXY(cBtn[i], 15, 20, 20 * i, 20)
    cBtn[i]:Show(true)
    txt[i] = mainForm:CreateWidgetByDesc(cBt:GetWidgetDesc())
    txt[i]:SetName("cTxt" .. i)
    wtListPanel:AddChild(txt[i])
    PosXY(txt[i], 15 + 20, 150, 20 * i, 20)
    txt[i]:Show(true)
    txt[i]:SetVal("Name", userMods.ToWString(NameCBtn[i]))
  end
  for i = 1, 3 do -- просто кнопки
    sBtn[i] = mainForm:CreateWidgetByDesc(sB:GetWidgetDesc())
    sBtn[i]:SetName("sBtn" .. i)
    wtListPanel:AddChild(sBtn[i])
    PosXY(sBtn[i], 15, 150, 20 * i + 40, 20)
    sBtn[i]:SetVal("Name", userMods.ToWString(NameBtn[i]))
    sBtn[i]:Show(true)
  end
  if Settings.ShowPoints.HERB then
    cBtn[1]:SetVariant(1)
  else
    cBtn[1]:SetVariant(0)
  end
  if Settings.ShowPoints.ORE then
    cBtn[2]:SetVariant(1)
  else
    cBtn[2]:SetVariant(0)
  end

  common.RegisterEventHandler(OnTimer, "EVENT_SECOND_TIMER")
  common.RegisterEventHandler(OnEventAvatarClientZoneChanged, "EVENT_AVATAR_CLIENT_ZONE_CHANGED")
  common.RegisterEventHandler(OnEventItemTaken, "EVENT_AVATAR_ITEM_TAKEN", { actionType = "ENUM_TakeItemActionType_Craft" })
end

-- EVENT_SECOND_TIMER
function OnTimer()
  RefreshMapOverlay()
  CheckMiniMapScale()
  --  OnMiniMap()
end

-- EVENT_AVATAR_CLIENT_ZONE_CHANGED
function OnEventAvatarClientZoneChanged()
  RefreshMiniMapOverlay()
end

-- EVENT_AVATAR_ITEM_TAKEN
function OnEventItemTaken(params)
  local itemId = params.itemObject:GetId()

  local itemSource = itemLib.GetSource(itemId)
  if not itemSource or itemSource ~= "ENUM_ItemSource_FixedDrop" then
    return
  end

  local craftInfo = itemLib.GetCraftInfo(itemId)
  if not craftInfo then
    return
  end

  local item = itemLib.GetItemInfo(itemId)
  Log("Взят предмет: " .. userMods.FromWString(item.name))

  local icon
  for _, skill in pairs(craftInfo.craftingSkillsInfo) do
    local skillId = skill.skillId
    local skillInfo = skillId and skillId:GetInfo()
    local sysName = skillInfo and skillInfo.sysName
    if sysName == "Blacksmithing" or sysName == "Weaponsmithing" then
      Log("Это руда")
      icon = "GORN"
      break
    elseif sysName == "Alchemy" then
      Log("Это трава")
      icon = "HERB"
      break
    else
      Log("Не определен тип ресурса")
      return
    end
  end

  local currentMapName = cartographer.GetZonesMapInfo(unit.GetZonesMapId(avatar.GetId())).sysName
  local pos = avatar.GetPos()
  for i = 1, #points do
    if points[i].MAP == currentMapName and points[i].ICON == icon and IsPointInCircle(pos, points[i], Settings.IgnoreNewResourcesRadius) then
      Log("Такая точка уже есть")
      return
    end
  end

  points[#points + 1] = {
    NAME = item.name,
    ICON = icon,
    MAP  = currentMapName,
    posX = pos.posX,
    posY = pos.posY,
    posZ = pos.posZ
  }
  Log("Точка записана, всего: " .. #points)
  SavePoints()
  RefreshMiniMapOverlay()
end

--------------------------------------------------------------------------------
-- REACTION HANDLERS
--------------------------------------------------------------------------------

-- ReactionBottom
function ReactionBottom(param)
  if DnD:IsDragging() then return end
  local widgetName = param.widget:GetName()
  if widgetName == "sBtn1" then -- скрыть
    ToggleMapOverlayVisibility()
  elseif widgetName == "sBtn2" then
    DeleteAllPointsOnMap(mapSystemNames[SelectedMapName()])
  elseif widgetName == "sBtn3" then
    DeleteAllPoints()
  end
end

function ToggleMapOverlayVisibility()
  Log("Скрыть/Показать точки на карте")
  ShowMap = not ShowMap
  wtMainPanel:Show(ShowMap)
end

function DeleteAllPoints()
  for i = 1, #points do
    if wtPoint[i] then
      wtPoint[i]:DestroyWidget()
    end
    if wtPointMini[i] then
      wtPointMini[i]:DestroyWidget()
    end
  end
  points = {}
  Log("Все точки удалены")
  SavePoints()
end

function DeleteAllPointsOnMap(sysMapName)
  Log("Сброс точек на карте: " .. sysMapName)
  local j, size = 1, #points
  for i = 1, size do
      if sysMapName == points[i].MAP then
        if wtPoint[i] then
          wtPoint[i]:DestroyWidget()
        end
        if wtPointMini[i] then
          wtPointMini[i]:DestroyWidget()
        end
        points[i] = nil
      else
        if i ~= j then
          points[j] = points[i]
          points[i] = nil
        end
        j = j + 1
      end
  end
  Log("Удалено точек: " .. (size - #points) .. ", всего: " .. #points)
  SavePoints()
end

-- click_cbtn
function click_cbtn(params)
  if DnD:IsDragging() then return end
  local widgetName = params.widget:GetName()
  if widgetName == "cBtn1" then -- Травничество
    if cBtn[1]:GetVariant() == 1 then
      -- скрыть
      cBtn[1]:SetVariant(0)
      Settings.ShowPoints.HERB = false
    else -- отобразить
      cBtn[1]:SetVariant(1)
      Settings.ShowPoints.HERB = true
    end
  elseif widgetName == "cBtn2" then -- Горное
    if cBtn[2]:GetVariant() == 1 then
      -- скрыть
      cBtn[2]:SetVariant(0)
      Settings.ShowPoints.ORE = false
    else -- отобразить
      cBtn[2]:SetVariant(1)
      Settings.ShowPoints.ORE = true
    end
  end
end

-- mouse_over
function ShowTooltip(params)
  if params.active then
    local index = tonumber(string.sub(params.sender, 8))
    local pointName = points[index].NAME
    wtTooltipText:SetClassVal("style", "tip_white")
    wtTooltipText:SetVal("Name", pointName)
    PosTooltip(wtTooltip, params.widget)
    wtTooltip:Show(true)
  else
    wtTooltip:Show(false)
  end
end

function PosTooltip(tooltip, anchorWidget)
  local rect = tooltip:GetRealRect()
  local tooltipWidth = rect.x2 - rect.x1

  local anchorRect = anchorWidget:GetRealRect()
  local posX = anchorRect.x1 - tooltipWidth - 2
  local posY = anchorRect.y1
  PosXY(tooltip, posX, nil, posY)
end

--------------------------------------------------------------------------------
-- INITIALIZATION
--------------------------------------------------------------------------------
function Init()
  DnD:Init(357, wtListPanel, wtListPanel, true, true, { -8, -8, -8, -8 })

  wtMainPanel:Show(false)
  wtMiniMapPanel:Show(false)

  if avatar.IsExist() then
    OnCreate()
  else
    common.RegisterEventHandler(OnCreate, "EVENT_AVATAR_CREATED")
  end

  common.RegisterReactionHandler(ReactionBottom, "ReactionBottom")
  common.RegisterReactionHandler(click_cbtn, "click_cbtn")
  common.RegisterReactionHandler(ShowTooltip, "mouse_over")
end

--------------------------------------------------------------------------------
Init()
--------------------------------------------------------------------------------
