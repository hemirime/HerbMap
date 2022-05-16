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

local isDnDRegistered = false
local wtSettings

local wtTooltip
local wtTooltipText

local wtPopup
local wtPopupText
local PopupMinWidth
local PopupPinName

local TextColors = {
  ORE = "tip_blue",
  HERB = "tip_green"
}

local wtPoint = {}
local wtPointMini = {}
--------------------------------------------------------------------------------
local CURRENT_DATA_VERSION = 1
local data = {
  Points = {
  },
  Version = 0
}

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

function LoadMapsDictionary()
  local zones = rules.GetZonesMaps()
  for _, zoneId in pairs(zones) do
    local mapInfo = cartographer.GetZonesMapInfo(zoneId)
    mapSystemNames[userMods.FromWString(mapInfo.name)] = mapInfo.sysName
  end
end

function LoadData()
  local loaded = userMods.GetGlobalConfigSection("Data")
  if not loaded then
    return
  end
  data = loaded
  Log("Данные загружены, версия: " .. data.Version)
end

function SaveData()
  data.Version = CURRENT_DATA_VERSION
  userMods.SetGlobalConfigSection("Data", data)
  Log("Данные сохранены, версия: " .. data.Version)
end

function GetCurrentMapSysName(avatarId)
  return cartographer.GetZonesMapInfo(unit.GetZonesMapId(avatarId or avatar.GetId())).sysName
end

function GetSelectedMapSysName()
  local localizedName = userMods.FromWString(common.ExtractWStringFromValuedText(MainMapLabel:GetValuedText()))
  return mapSystemNames[localizedName]
end

function RenderMapPoints()
  function FindGeodata(mapId)
    local markers = cartographer.GetMapMarkers(mapId)
    for _, markerId in pairs(markers) do
      local markerObjects = cartographer.GetMapMarkerObjects(mapId, markerId)
      for _, d in pairs(markerObjects) do
        if d.geodata then
          return d.geodata
        end
      end
    end
  end

  local mapSysName = GetSelectedMapSysName()
  local geodata = FindGeodata(cartographer.GetZonesMapId(mapSysName))

  DestroyPins(wtPoint)
  RenderPoints(wtMainPanel:GetPlacementPlain(), geodata, mapSysName, wtPoint, wtMainPanel, 1)
end

function RenderMiniMapPoints()
  local avatarId = avatar.GetId()
  local mapSysName = GetCurrentMapSysName(avatarId)
  local geodata = cartographer.GetObjectGeodata(avatarId)

  DestroyPins(wtPointMini)
  RenderPoints(wtMiniMapPanel:GetPlacementPlain(), geodata, mapSysName, wtPointMini, wtMiniMapPanel, Settings.MiniMapPinSizeModifier)
end

function GetPointIndexFromPin(pinName)
  local name, index = string.match(pinName, "(.+):(%d+)")
  return name, tonumber(index)
end

function RenderPoints(mapSize, geodata, mapSysName, container, parent, sizeModifier)
  if not geodata then
    Log("Не удалось получить геодату для выбранной зоны: " .. mapSysName)
    return
  end

  local points = data.Points[mapSysName]
  if not points then
    Log("Нет точек для отображения на: " .. mapSysName)
    return
  end

  local pixelsPerMeterX = mapSize.sizeX / geodata.width
  local pixelsPerMeterY = mapSize.sizeY / geodata.height

  for i = 1, #points do
    local point = points[i]
    local isPinVisible = (Settings.ShowPoints.HERB and point.icon == "HERB") or (Settings.ShowPoints.ORE and point.icon == "ORE")

    local pin = mainForm:CreateWidgetByDesc(pinDesc)
    pin:SetName(mapSysName.. ":" .. i)
    pin:Show(isPinVisible)
    pin:SetBackgroundTexture(common.GetAddonRelatedTexture(point.icon))

    parent:AddChild(pin)
    container[#container + 1] = pin

    local sizeX = 15 * sizeModifier
    local sizeY = 20 * sizeModifier
    local posX = (point.posX - geodata.x) * pixelsPerMeterX
    local posY = ((geodata.y + geodata.height) - point.posY) * pixelsPerMeterY
    PosXY(pin, posX - sizeX / 2, sizeX, posY - sizeY, sizeY)
  end
end

function RefreshMapOverlay()
  if not MainMap:IsVisibleEx() then
    wtMainPanel:Show(false)
    return
  end
  if not isDnDRegistered then
    DnD:Init(wtSettings, wtSettings, true, true)
    isDnDRegistered = true
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

    DestroyPins(wtPointMini)
    RenderMiniMapPoints()
  end
end

function DestroyPins(parent)
  for i = 1, #parent do
    parent[i]:DestroyWidget()
    parent[i] = nil
  end
end
--------------------------------------------------------------------------------
-- EVENT HANDLERS
--------------------------------------------------------------------------------

-- EVENT_AVATAR_CREATED
function OnCreate()
  UI:Init()
  LoadMapsDictionary()

  local migrated = MigrateDataFromOriginalAddon(mapSystemNames)
  if migrated then
    data.Points = migrated
    SaveData()
  else
    LoadData()
  end

  CheckMiniMapScale()

  wtSettings = Frame "HM:Settings" {
    edges = { all = 12 },
    content = VStack {
      spacing = 2,
      gravity = WIDGET_ALIGN_LOW,
      children = {
        HStack {
          spacing = 2,
          gravity = WIDGET_ALIGN_CENTER,
          children = {
            Checkbox {
              isChecked = Settings.ShowPoints.HERB,
              onChecked = function(isChecked)
                Settings.ShowPoints.HERB = isChecked
                wtPopup:Show(false)
                RenderMapPoints()
              end
            },
            Label { text = userMods.ToWString(NameCBtn[1]), style = TextColors.HERB, fontSize = 12 }
          }
        },
        HStack {
          spacing = 2,
          gravity = WIDGET_ALIGN_CENTER,
          children = {
            Checkbox {
              isChecked = Settings.ShowPoints.ORE,
              onChecked = function(isChecked)
                Settings.ShowPoints.ORE = isChecked
                wtPopup:Show(false)
                RenderMapPoints()
              end
            },
            Label { text = userMods.ToWString(NameCBtn[2]), style = TextColors.ORE, fontSize = 12 }
          }
        },
        Button {
          title = userMods.ToWString(NameBtn[1]),
          sizeX = 150, sizeY = 20,
          onClicked = function()
            wtPopup:Show(false)
            ToggleMapOverlayVisibility()
          end
        },
        Button {
          title = userMods.ToWString(NameBtn[2]),
          sizeX = 150, sizeY = 20,
          onClicked = function()
            wtPopup:Show(false)
            DeleteAllPointsOnMap(GetSelectedMapSysName())
          end
        },
        Button {
          title = userMods.ToWString(NameBtn[3]),
          sizeX = 150, sizeY = 20,
          onClicked = function()
            wtPopup:Show(false)
            DeleteAllPoints()
          end
        }
      }
    }
  }
  wtSettings:SetPriority(3)
  MainMap:AddChild(wtSettings)

  wtTooltip = Frame "Tooltip" {
    edges = { all = 12 },
    content = function()
      wtTooltipText = Label { text = "" }
      return wtTooltipText
    end
  }
  wtTooltip:SetPriority(11240)
  wtTooltip:Show(false)

  wtPopupText = Label { text = "", fontSize = 13 }
  wtPopup = Frame "Popup" {
    edges = { all = 12 },
    content = function()
      local stack = VStack {
        spacing = 2,
        gravity = WIDGET_ALIGN_LOW,
        children = {
          wtPopupText,
          Button {
            title = userMods.ToWString(NameTT[1]),
            sizeX = 100, sizeY = 20,
            isInstantClick = true,
            onClicked = function()
              DeletePoint(PopupPinName)
              PopupPinName = nil
              wtPopup:Show(false)
            end
          },
          Button {
            title = userMods.ToWString(NameTT[2]),
            sizeX = 100, sizeY = 20,
            isInstantClick = true,
            onClicked = function()
              wtPopup:Show(false)
            end
          }
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
      icon = "ORE"
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

  local currentMapName = GetCurrentMapSysName()
  local pos = avatar.GetPos()
  local points = data.Points[currentMapName] or {}
  for i = 1, #points do
    if points[i].icon == icon and IsPointInCircle(pos, points[i], Settings.IgnoreNewResourcesRadius) then
      Log("Такая точка уже есть")
      return
    end
  end

  points[#points + 1] = {
    name = item.name,
    icon = icon,
    posX = pos.posX,
    posY = pos.posY,
  }
  data.Points[currentMapName] = points
  Log("Точка записана, всего " .. #points .. " на " .. currentMapName)
  SaveData()
  RenderMiniMapPoints()
end

--------------------------------------------------------------------------------
-- REACTION HANDLERS
--------------------------------------------------------------------------------

function ToggleMapOverlayVisibility()
  Log("Скрыть/Показать точки на карте")
  ShowMap = not ShowMap
  wtMainPanel:Show(ShowMap)
end

function DeleteAllPoints()
  DestroyPins(wtPoint)
  DestroyPins(wtPointMini)
  data.Points = {}
  Log("Все точки удалены")
  SaveData()
end

function DeleteAllPointsOnMap(sysMapName)
  data.Points[sysMapName] = nil
  DestroyPins(wtPoint)
  if GetCurrentMapSysName() == sysMapName then
    DestroyPins(wtPointMini)
  end
  Log("Удалены все точки на карте " .. sysMapName)
  SaveData()
end

function DeletePoint(pinName)
  local mapSysName, index = GetPointIndexFromPin(pinName)
  local points = data.Points[mapSysName]
  local point = points[index]
  Log("Удаляем точку: " .. userMods.FromWString(point.name) .. " " .. point.posX .. "x" .. point.posY)

  local lastIndex = #points
  points[index] = points[lastIndex]
  points[lastIndex] = nil

  function DeletePin(parent)
    if parent[index] and parent[index]:GetName() == pinName then
      parent[index]:DestroyWidget()
      local last = #parent
      parent[index] = parent[last]
      parent[index]:SetName(mapSysName .. ":" .. index)
      parent[last] = nil
    end
  end
  DeletePin(wtPoint)
  DeletePin(wtPointMini)

  SaveData()
end

-- pin_mouse_over
function ShowTooltip(params)
  if params.active then
    local mapSysName, index = GetPointIndexFromPin(params.sender)
    local point = data.Points[mapSysName][index]
    wtTooltipText:SetVal("Text", point.name)
    wtTooltipText:SetClassVal("Style", TextColors[point.icon] or "tip_white")
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
  PopupPinName = params.sender
  local mapSysName, index = GetPointIndexFromPin(params.sender)
  local point = data.Points[mapSysName][index]
  wtPopupText:SetVal("Text", point.name)
  wtPopupText:SetClassVal("Style", TextColors[point.icon] or "tip_white")

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

  common.RegisterReactionHandler(ShowTooltip, "pin_mouse_over")
  common.RegisterReactionHandler(ShowPopup, "pin_right_click")
end

--------------------------------------------------------------------------------
Init()
--------------------------------------------------------------------------------
