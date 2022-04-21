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
local wtBtn = mainForm:GetChildChecked("btn", false)

local points = {}

local wtPoint = {}
local wtPointMini = {}

local ShowMap = true
local mapSystemNames = {}

-- ��������� ��� ����������� ����������
local wtListPanel = mainForm:GetChildChecked("listpanel", false)
local cB = wtListPanel:GetChildChecked("cbtn", false)
cB:Show(false)
local cBt = wtListPanel:GetChildChecked("cfgtxt", false)
cBt:Show(false)
local cBtn = {} -- � ��������
local sB = wtListPanel:GetChildChecked("bottom", false)
sB:Show(false)
local sBtn = {} -- ������ ������
local wtInfoPanel = mainForm:GetChildChecked("Tooltip", false)
local wtInfoPaneltxt = wtInfoPanel:GetChildChecked("TooltipText", false)

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
  Log(#points .. " ����� ���������")
end

function SavePoints()
  if points then
    userMods.SetGlobalConfigSection("HerbMap", points)
    Log(#points .." ����� ��������")
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
  local mapId = SelectedMapID()
  local markers = cartographer.GetMapMarkers(mapId)
  local markerObjects = cartographer.GetMapMarkerObjects(mapId, markers[0])
  local geodata = markerObjects[0].geodata
  if not geodata then
    Log("�� ������� �������� ������� ��� ��������� ����: " .. SelectedMapName())
    return
  end

  RenderPoints(wtMainPanel:GetPlacementPlain(), geodata, mapSystemNames[SelectedMapName()], wtPoint, wtMainPanel)
end

function RenderMiniMapPoints()
  Log("Render " .. #points .. " points")
  local geodata = cartographer.GetObjectGeodata(avatar.GetId())
  if not geodata then
    Log("�� ������� �������� ������� ��� ������� ����")
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
      if container[i] then
        local isPinVisible = (Settings.ShowPoints.HERB and points[i].ICON == "HERB") or (Settings.ShowPoints.ORE and points[i].ICON == "GORN")
        container[i]:Show(isPinVisible)
      else
        container[i] = mainForm:CreateWidgetByDesc(wtBtn:GetWidgetDesc())
        container[i]:SetName("wtPoint" .. i)
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
    Log("��������� ������� ���������: " .. mapSize .. " �/��� �����: " .. name)
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
  wtMiniMapPanel:Show(false)
  MainMap:AddChild(wtListPanel)
  LoadPoints()
  MigrateData()
  local txt = {}
  PosXY(wtListPanel, 100, 200, 50, 20 * 5 + 55)
  for i = 1, 2 do -- � ��������
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
  for i = 1, 3 do -- ������ ������
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
  Log("���� �������: " .. userMods.FromWString(item.name))

  local icon
  for _, skill in pairs(craftInfo.craftingSkillsInfo) do
    local skillId = skill.skillId
    local skillInfo = skillId and skillId:GetInfo()
    local sysName = skillInfo and skillInfo.sysName
    if sysName == "Blacksmithing" or sysName == "Weaponsmithing" then
      Log("��� ����")
      icon = "GORN"
      break
    elseif sysName == "Alchemy" then
      Log("��� �����")
      icon = "HERB"
      break
    else
      Log("�� ��������� ��� �������")
      return
    end
  end

  local currentMapName = cartographer.GetZonesMapInfo(unit.GetZonesMapId(avatar.GetId())).sysName
  local pos = avatar.GetPos()
  for i = 1, #points do
    if points[i].MAP == currentMapName and IsPointInCircle(pos, points[i], Settings.Radius) then
      Log("����� ����� ��� ����")
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
  Log("����� ��������, �����: " .. #points)
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
  if widgetName == "sBtn1" then -- ������
    Log("������...")
    if wtMainPanel:IsVisible() then
      wtMainPanel:Show(false)
      ShowMap = false
    else
      wtMainPanel:Show(true)
      ShowMap = true
    end
  elseif widgetName == "sBtn2" then -- ����� ����� �� �����
    Log("����� ����� �� �����")
    -------------------------------------------
    -- ��������� �������� ����
    local sizeKol = #points
    for i = 1, #points do
      if points[i] then
        if CurrentMapSysName() == points[i].MAP then
          Log("����� �� ������ ����� ������� "..i.." ����� ����� "..#points)
          for i = 1, #points do
            if wtPoint[i] then
              wtPoint[i]:DestroyWidget()
            end
          end
          for ii = i, sizeKol - 1 do
            points[ii] = points[ii + 1]
          end
          points[sizeKol] = nil
          sizeKol = sizeKol - 1
        else
          Log("����� �� ������ ����� �� ������� ����� �� "..#points)
        end
      end
    end
    SavePoints()
    -------------------------------------------
  elseif widgetName == "sBtn3" then -- ����� ���� �����
    for i = 1, #points do
      if wtPoint[i] then
        wtPoint[i]:DestroyWidget()
      end
      if wtPointMini[i] then
        wtPointMini[i]:DestroyWidget()
      end
    end
    points = {}
    SavePoints()
  end
end

-- click_cbtn
function click_cbtn(params)
  if DnD:IsDragging() then return end
  local widgetName = params.widget:GetName()
  if widgetName == "cBtn1" then -- ������������
    if cBtn[1]:GetVariant() == 1 then
      -- ������
      cBtn[1]:SetVariant(0)
      Settings.ShowPoints.HERB = false
    else -- ����������
      cBtn[1]:SetVariant(1)
      Settings.ShowPoints.HERB = true
    end
  elseif widgetName == "cBtn2" then -- ������
    if cBtn[2]:GetVariant() == 1 then
      -- ������
      cBtn[2]:SetVariant(0)
      Settings.ShowPoints.ORE = false
    else -- ����������
      cBtn[2]:SetVariant(1)
      Settings.ShowPoints.ORE = true
    end
  end
end

-- mouse_over
function ReactionOnPointing(params)
  if params.active then
    local name = string.sub(params.sender, 8)
    local d = points[tonumber(name)].NAME
    wtInfoPanel:Show(true)
    wtInfoPaneltxt:SetVal("Name", d)
    wtInfoPaneltxt:SetClassVal("style", "tip_golden")
    local m = params.widget:GetRealRect()
    if params.widget:GetParent():GetName() == "MainPanel" then
      params.widget:GetParent():GetParent():AddChild(wtInfoPanel)
      SetPosTT(params.widget, wtInfoPanel)
    else
      stateMainForm:GetChildChecked("HerbMap", false):AddChild(wtInfoPanel)
      SetPosTT(params.widget, wtInfoPanel)
    end
  else
    wtInfoPanel:Show(false)
  end
end

function SetPosTT(wt, wtt)
  local Placement = wt:GetRealRect()
  local posX = Placement.x1 + 20
  local posY = Placement.y1 - 40
  PosXY(wtt, posX, nil, posY)
end

--------------------------------------------------------------------------------
-- INITIALIZATION
--------------------------------------------------------------------------------
function Init()
  LoadMapsDictionary()

  wtMainPanel:Show(false)
  wtMiniMapPanel:Show(false)
  if avatar.IsExist() then
    OnCreate()
  end
  DnD:Init(357, wtListPanel, wtListPanel, true, true, { -8, -8, -8, -8 })

  common.RegisterReactionHandler(ReactionBottom, "ReactionBottom")
  common.RegisterReactionHandler(click_cbtn, "click_cbtn")
  common.RegisterReactionHandler(ReactionOnPointing, "mouse_over")

  common.RegisterEventHandler(OnCreate, "EVENT_AVATAR_CREATED")
  common.RegisterEventHandler(OnTimer, "EVENT_SECOND_TIMER")
  common.RegisterEventHandler(OnEventAvatarClientZoneChanged, "EVENT_AVATAR_CLIENT_ZONE_CHANGED")
  common.RegisterEventHandler(OnEventItemTaken, "EVENT_AVATAR_ITEM_TAKEN", { actionType = "ENUM_TakeItemActionType_Craft" })
end

--------------------------------------------------------------------------------
Init()
--------------------------------------------------------------------------------
