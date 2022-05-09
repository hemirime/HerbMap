local isDebugEnabled = true

function Log(message)
  if not isDebugEnabled then return end

  common.LogInfo(common.GetAddonName(), message)
  LogToChat(message)
end

function GetMiniMapWidget(parent, name)
  local widget = parent:GetChildChecked(name, false)
  return {
    Name = name,
    Widget = widget,
    Engine = widget:GetChildChecked("Map", false):GetChildChecked("MapEngine", false),
    Controls = widget:GetChildChecked("Controls", false)
  }
end

local MainMap = stateMainForm:GetChildChecked("Map", false):GetChildChecked("MainPanel", false):GetChildChecked("LayoutMain", false):GetChildChecked("MapEnginePanel", true)
local MainMapLabel = MainMap:GetChildChecked("Texts", false):GetChildChecked("MapLabel", false)

local MiniMap = stateMainForm:GetChildChecked("Minimap", false)
local SquareMiniMap = GetMiniMapWidget(MiniMap, "Square")
local CircleMiniMap = GetMiniMapWidget(MiniMap, "Circle")
--------------------------------------------------------------------------------
local wtMainPanel = mainForm:GetChildChecked("HM:MapPanel", false)
local wtMiniMapPanel = mainForm:GetChildChecked("HM:MiniMapPanel", false)

local pinDesc = mainForm:GetChildChecked("PinTemplate", false):GetWidgetDesc()

local wtTooltip
local wtTooltipText

local wtPopup
local wtPopupText
local PopupMinWidth
local PopupPointIndex

local TextColors = {
  GORN = "tip_blue",
  HERB = "tip_green"
}

local wtPoint = {}
local wtPointMini = {}
--------------------------------------------------------------------------------
local points = {}

local miniMapInfo = {
  Name = nil,
  MapSize = nil,
}

local IsTimerEventRegistered = false

local ShowMap = true
local mapSystemNames = {}
--------------------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------------------

function GetActiveMiniMap()
  if SquareMiniMap.Widget:IsVisible() then
    return SquareMiniMap
  elseif CircleMiniMap.Widget:IsVisible() then
    return CircleMiniMap
  else
    return nil
  end
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
        container[i] = mainForm:CreateWidgetByDesc(pinDesc)
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
    return
  end

  wtMainPanel:Show(ShowMap)

  local placement = MainMap:GetPlacementPlain()
  wtMainPanel:SetPlacementPlain(placement)
  MainMap:AddChild(wtMainPanel)

  RenderMapPoints()
end

function CheckMiniMapScale()
  local activeMiniMap = GetActiveMiniMap()
  if not activeMiniMap then
    Log("Миникарта скрыта")
    return
  end

  local name = activeMiniMap.Name
  local pl = activeMiniMap.Engine:GetPlacementPlain()
  local mapSize = pl.sizeX .. "x" .. pl.sizeY

  if name ~= miniMapInfo.Name or mapSize ~= miniMapInfo.MapSize then
    Log("Изменился масштаб миникарты: " .. mapSize .. " и/или форма: " .. name)
    miniMapInfo.Name = name
    miniMapInfo.MapSize = mapSize

    PosXY(wtMiniMapPanel, nil, pl.sizeX, nil, pl.sizeY)
    activeMiniMap.Engine:AddChild(wtMiniMapPanel)

    for i = 1, #points do
      if wtPointMini[i] then
        wtPointMini[i]:DestroyWidget()
        wtPointMini[i] = nil
      end
    end
    RenderMiniMapPoints()
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

  CheckMiniMapScale()

  local wtSettings = Frame "HM:Settings" {
    edges = { all = 12 },
    content = VStack {
      spacing = 2,
      gravity = WIDGET_ALIGN_LOW,
      children = {
        Label { text = "HerbMap", fontSize = 11 },
        HStack {
          spacing = 2,
          gravity = WIDGET_ALIGN_CENTER,
          children = {
            Checkbox "cBtn1" { isChecked = Settings.ShowPoints.HERB },
            Label { text = userMods.ToWString(NameCBtn[1]), style = TextColors['HERB'], fontSize = 12 }
          }
        },
        HStack {
          spacing = 2,
          gravity = WIDGET_ALIGN_CENTER,
          children = {
            Checkbox "cBtn2" { isChecked = Settings.ShowPoints.ORE },
            Label { text = userMods.ToWString(NameCBtn[2]), style = TextColors['GORN'], fontSize = 12 }
          }
        },
        Repeat(3, function(index)
          local btn = Button("sBtn" .. index) { title = userMods.ToWString(NameBtn[index]) }
          SetSize(btn, 150, 20)
          return btn
        end)
      }
    }
  }
  wtSettings:SetPriority(3)
  MainMap:AddChild(wtSettings)
  DnD:Init(wtSettings, wtSettings, true, true)

  wtTooltip = Frame "Tooltip" {
    edges = { all = 12 },
    content = function()
      wtTooltipText = Label { text = "" }
      return wtTooltipText
    end
  }
  wtTooltip:SetPriority(11240)
  wtTooltip:Show(false)

  wtPopup = Frame "Popup" {
    edges = { all = 12 },
    content = function()
      local stack = VStack {
        spacing = 2,
        gravity = WIDGET_ALIGN_LOW,
        children = {
          function()
            wtPopupText = Label { text = "", fontSize = 13 }
            return wtPopupText
          end,
          Repeat(2, function(index)
            local btn = Button("PopupBtn" .. index) { title = userMods.ToWString(NameTT[index]) }
            SetSize(btn, 100, 20)
            return btn
          end)
        }
      }
      PopupMinWidth = stack:GetPlacementPlain().sizeX
      return stack
    end
  }
  wtPopup:Show(false)

  local mapRoot = stateMainForm:GetChildChecked("Map", false)
  mapRoot:GetChildChecked("MainPanel", false):SetOnShowNotification(true)
  mapRoot:GetChildChecked("DropdownBarL1Menu", false):SetOnShowNotification(true)
  mapRoot:GetChildChecked("DropdownBarL2Menu", false):SetOnShowNotification(true)

  SquareMiniMap.Widget:SetOnShowNotification(true)
  SquareMiniMap.Controls:SetOnShowNotification(true)

  CircleMiniMap.Widget:SetOnShowNotification(true)
  CircleMiniMap.Controls:SetOnShowNotification(true)

  common.RegisterEventHandler(OnEventAvatarClientZoneChanged, "EVENT_AVATAR_CLIENT_ZONE_CHANGED")
  common.RegisterEventHandler(OnEventItemTaken, "EVENT_AVATAR_ITEM_TAKEN", { actionType = "ENUM_TakeItemActionType_Craft" })
  common.RegisterEventHandler(OnWidgetShow, "EVENT_WIDGET_SHOW_CHANGED")
end

-- EVENT_WIDGET_SHOW_CHANGED
function OnWidgetShow(params)
  local sender = params.widget
  local senderName = sender:GetName()
  local parentName = sender:GetParent():GetName()

  function IsMainMap()
    return senderName == "MainPanel" and parentName == "Map"
  end
  function IsSelectMapMenuClosed()
    return (senderName == "DropdownBarL1Menu" or senderName == "DropdownBarL2Menu") and parentName == "Map" and not sender:IsVisible()
  end
  function IsMiniMap()
    return (senderName == "Square" or senderName == "Circle") and parentName == "Minimap"
  end
  function IsMiniMapControls()
    return senderName == "Controls" and (parentName == "Square" or parentName == "Circle")
  end

  if IsMainMap() or IsSelectMapMenuClosed() then
    RefreshMapOverlay()
    wtTooltip:Show(false)
    wtPopup:Show(false)
  end
  if IsMiniMap() then
    CheckMiniMapScale()
  end
  if IsMiniMapControls() then
    ToggleMiniMapScaleTracking()
  end
end

function ToggleMiniMapScaleTracking()
  if IsTimerEventRegistered then
    if not (SquareMiniMap.Controls:IsVisible() or CircleMiniMap.Controls:IsVisible()) then
      common.UnRegisterEventHandler(OnTimer, "EVENT_SECOND_TIMER")
      IsTimerEventRegistered = false
    end
  else
    if SquareMiniMap.Controls:IsVisible() or CircleMiniMap.Controls:IsVisible() then
      common.RegisterEventHandler(OnTimer, "EVENT_SECOND_TIMER")
      IsTimerEventRegistered = true
    end
  end
end

-- EVENT_SECOND_TIMER
function OnTimer()
  CheckMiniMapScale()
end

-- EVENT_AVATAR_CLIENT_ZONE_CHANGED
function OnEventAvatarClientZoneChanged()
  RenderMiniMapPoints()
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
  RenderMiniMapPoints()
end

--------------------------------------------------------------------------------
-- REACTION HANDLERS
--------------------------------------------------------------------------------

-- ReactionBottom
function OnButtonClicked(param)
  if DnD:IsDragging() then return end

  local widgetName = param.widget:GetName()
  if widgetName == "sBtn1" then
    ToggleMapOverlayVisibility()
  elseif widgetName == "sBtn2" then
    DeleteAllPointsOnMap(mapSystemNames[SelectedMapName()])
  elseif widgetName == "sBtn3" then
    DeleteAllPoints()
  elseif widgetName == "PopupBtn1" then
    DeletePoint(PopupPointIndex)
    PopupPointIndex = nil
    wtPopup:Show(false)
  elseif widgetName == "PopupBtn2" then
    wtPopup:Show(false)
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

function DeletePoint(index)
  if not index then return end

  local point = points[index]
  Log("Удаляем точку: " .. userMods.FromWString(point.NAME) .. ", x: " .. point.posX .. ", y: " .. point.posY)

  if wtPoint[index] then
    wtPoint[index]:DestroyWidget()
  end
  if wtPointMini[index] then
    wtPointMini[index]:DestroyWidget()
  end

  local lastIndex = #points
  points[index] = points[lastIndex]
  points[lastIndex] = nil

  function MoveWidget(parent)
    parent[index] = parent[lastIndex]
    if parent[index] then
      parent[index]:SetName("wtPoint" .. index)
    end
    parent[lastIndex] = nil
  end
  MoveWidget(wtPoint)
  MoveWidget(wtPointMini)

  SavePoints()
end

-- on_checkbox_clicked
function OnCheckboxClicked(params)
  if DnD:IsDragging() then return end

  local sender = params.widget
  sender:SetVariant(sender:GetVariant() == 1 and 0 or 1)

  local senderName = sender:GetName()
  if senderName == "cBtn1" then
    Settings.ShowPoints.HERB = sender:GetVariant() == 1
    RenderMapPoints()
  elseif senderName == "cBtn2" then
    Settings.ShowPoints.ORE = sender:GetVariant() == 1
    RenderMapPoints()
  end
end

-- pin_mouse_over
function ShowTooltip(params)
  if params.active then
    local index = tonumber(string.sub(params.sender, 8))
    local point = points[index]
    wtTooltipText:SetVal("Text", point.NAME)
    wtTooltipText:SetClassVal("Style", TextColors[point.ICON] or "tip_white")
    wtTooltip:Show(true)
    PosTooltip(wtTooltip, params.widget)
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
  PosXY(tooltip, posX, nil, posY, nil, WIDGET_ALIGN_LOW_ABS, WIDGET_ALIGN_LOW_ABS)
end

-- pin_right_click
function ShowPopup(params)
  PopupPointIndex = tonumber(string.sub(params.sender, 8))
  local point = points[PopupPointIndex]
  wtPopupText:SetVal("Text", point.NAME)
  wtPopupText:SetClassVal("Style", TextColors[point.ICON] or "tip_white")

  -- update popup size
  local labelWidth = wtPopupText:GetPlacementPlain().sizeX
  local width = labelWidth > PopupMinWidth and labelWidth or PopupMinWidth
  for _, w in pairs(wtPopupText:GetParent():GetNamedChildren()) do
    SetSize(w, width)
  end
  SetSize(wtPopupText:GetParent(), width)

  wtPopup:Show(true)
  PosXY(wtPopup, params.x, nil, params.y, nil, WIDGET_ALIGN_LOW_ABS, WIDGET_ALIGN_LOW_ABS)
end

--------------------------------------------------------------------------------
-- INITIALIZATION
--------------------------------------------------------------------------------
function Init()
  if avatar.IsExist() then
    OnCreate()
  else
    common.RegisterEventHandler(OnCreate, "EVENT_AVATAR_CREATED")
  end

  common.RegisterReactionHandler(OnButtonClicked, "ReactionBottom")
  common.RegisterReactionHandler(OnCheckboxClicked, "on_checkbox_clicked")
  common.RegisterReactionHandler(ShowTooltip, "pin_mouse_over")
  common.RegisterReactionHandler(ShowPopup, "pin_right_click")
end

--------------------------------------------------------------------------------
Init()
--------------------------------------------------------------------------------
