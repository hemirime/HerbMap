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

local wtMainPanel = mainForm:GetChildChecked("MainPanel", false)
local wtMiniMapPanel = mainForm:GetChildChecked("MiniMapPanel", false)
local wtBtn = mainForm:GetChildChecked("btn", false)

local MainMap = stateMainForm:GetChildChecked("Map", false):GetChildChecked("MainPanel", false)
local wtName = MainMap:GetChildChecked("LayoutMain", false):GetChildChecked("LayoutFrameLeft", false):GetChildChecked("LayoutFrameLeftHor", false):GetChildChecked("LayoutFrameLeftVert", false):GetChildChecked("MapEnginePanel", false):GetChildChecked("Markers", false):GetChildChecked("MapTextPanel", false)

local MiniMap = stateMainForm:GetChildChecked("Minimap", false)
local SquareMiniMap = GetMiniMapWidget(MiniMap, "Square")
local CircleMiniMap = GetMiniMapWidget(MiniMap, "Circle")

local miniMapInfo = {
  Name = nil,
  MapSize = nil,
  Engine = nil,
}

local points = {}

local wtPoint = {}
local wtPointMini = {}

local ShowMap = true
local geodata

local vid = 0
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

function CurrentMap()
  local children = wtName:GetNamedChildren()
  for i = 0, GetTableSize(children) - 1 do
    local wtChild = children[i]
    local name = wtChild:GetName()
    if wtChild:IsVisible() then
      return name
    end
  end
end

function ConvertedMapName(mapname) -- fix to update user.cfg
  local mapBlocks = cartographer.GetMapBlocks()
  for i = 0, GetTableSize(mapBlocks) - 1 do
    local mapBlockInfo = cartographer.GetMapBlockInfo(mapBlocks[i])
    if mapBlockInfo then
      local zones = mapBlockInfo.zonesMaps
      for _, id in pairs(zones) do
        local name = cartographer.GetZonesMapInfo(id).name
        if common.GetApiType(mapname) == "WString" then
          if common.CompareWStringEx(name, mapname) == 0 then
            local sys = cartographer.GetZonesMapInfo(id).sysName
            return sys
          end
        else return mapname
        end
      end
    end
  end
end

function Extract() -- fix to update user.cfg
  for i = 1, GetTableSize(points) do
    points[i].MAP = ConvertedMapName(points[i].MAP)
  end
  SavePoints()
end

function CurrentMapID()
  local children = wtName:GetNamedChildren()
  for i = 0, GetTableSize(children) - 1 do
    local wtChild = children[i]
    local name = wtChild:GetName()
    if wtChild:IsVisible() then
      local id = cartographer.GetZonesMapId(name)
      return id
    end
  end
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


function OnPoint()
  local markers = cartographer.GetMapMarkers(CurrentMapID())
  for i, markerId in pairs(markers) do
    local markedobjects = cartographer.GetMapMarkerObjects(CurrentMapID(), markerId)
    for _, v in pairs(markedobjects) do
      geodata = v.geodata
    end
  end
  local pl = wtMainPanel:GetPlacementPlain()
  local R = false
  for i = 1, #points do
    if points[i] then
      -- сравнение названий карт
      if CurrentMap() == points[i].MAP then
        if ShowMetki.HERB and points[i].ICON == "HERB" then
          R = true
        elseif ShowMetki.GORN and points[i].ICON == "GORN" then
          R = true
        else
          R = false
        end
        if wtPoint[i] then --если точка существует - отобразить
          wtPoint[i]:Show(R)
          PosXY(wtPoint[i], (points[i].posX - geodata.x) * pl.sizeX / geodata.width - 12, 15, ((geodata.y + geodata.height) - points[i].posY) * pl.sizeY / geodata.height - 20, 20)
        else -- Если не существует - создать
          wtPoint[i] = mainForm:CreateWidgetByDesc(wtBtn:GetWidgetDesc())
          wtPoint[i]:SetName("wtPoint" .. i)
          wtPoint[i]:SetTransparentInput(false)
          wtMainPanel:AddChild(wtPoint[i])
          MainMap:AddChild(wtMainPanel)
          PosXY(wtPoint[i], (points[i].posX - geodata.x) * pl.sizeX / geodata.width - 12, 15, ((geodata.y + geodata.height) - points[i].posY) * pl.sizeY / geodata.height - 20, 20)
          if points[i].ICON then -- присвоить вид метки
            local bt = common.GetAddonRelatedTexture(points[i].ICON)
            wtPoint[i]:SetBackgroundTexture(bt)
          end
        end
      else
        if wtPoint[i] then
          wtPoint[i]:Show(false)
        end
      end
    end
  end
end

function RenderMiniMapPoints()
  Log("Render " .. #points .. " points")
  local geodata = cartographer.GetObjectGeodata(avatar.GetId())
  if not geodata then
    Log("Не удалось получить геодату для текущей зоны")
    return
  end

  local miniMapPlacement = wtMiniMapPanel:GetPlacementPlain()
  local pixelsPerMeterX = miniMapPlacement.sizeX / geodata.width
  local pixelsPerMeterY = miniMapPlacement.sizeY / geodata.height

  local currentMapName = cartographer.GetZonesMapInfo(unit.GetZonesMapId(avatar.GetId())).sysName
  for i = 1, #points do
    if currentMapName == points[i].MAP then
      if wtPointMini[i] then
        local isPinVisible = (ShowMetki.HERB and points[i].ICON == "HERB") or (ShowMetki.GORN and points[i].ICON == "GORN")
        wtPointMini[i]:Show(isPinVisible)
      else
        wtPointMini[i] = mainForm:CreateWidgetByDesc(wtBtn:GetWidgetDesc())
        wtPointMini[i]:SetName("wtPoint" .. i)
        wtMiniMapPanel:AddChild(wtPointMini[i])
        if points[i].ICON then
          local textureId = common.GetAddonRelatedTexture(points[i].ICON)
          wtPointMini[i]:SetBackgroundTexture(textureId)
        end
      end
      local sizeX = 15
      local sizeY = 20
      local posX = (points[i].posX - geodata.x) * pixelsPerMeterX
      local posY = ((geodata.y + geodata.height) - points[i].posY) * pixelsPerMeterY
      PosXY(wtPointMini[i], posX - sizeX / 2, sizeX, posY - sizeY, sizeY)
    else
      if wtPointMini[i] then
        wtPointMini[i]:Show(false)
      end
    end
  end
end

function OnMap()
  if MainMap:IsVisible() then -- отображается ли карта вданный момент
    local lm = MainMap:GetChildChecked("LayoutFrameLeftVert", true) --карта
    local pl = lm:GetPlacementPlain()
    local lfr = MainMap:GetChildChecked("LayoutFrameRight", true)
    local plr = lfr:GetPlacementPlain()
    local Placement = wtMainPanel:GetPlacementPlain()
    wtMainPanel:Show(ShowMap)
    wtListPanel:Show(true)
    local QuestShow = MainMap:GetChildChecked("ButtonQuestsHide", true)
    if QuestShow:IsVisible() then --Со списком квестов
      Placement.posX = pl.posX - (plr.sizeX / 2)
      Placement.sizeX = pl.sizeX
      Placement.posY = pl.posY
      Placement.sizeY = pl.sizeY
      wtMainPanel:SetPlacementPlain(Placement)
      vid = 1
      OnPoint()
    else -- Без списка квестов
      Placement.posX = pl.posX
      Placement.sizeX = pl.sizeX
      Placement.posY = pl.posY
      Placement.sizeY = pl.sizeY
      wtMainPanel:SetPlacementPlain(Placement)
      vid = 0
      OnPoint()
    end
  else
    wtMainPanel:Show(false)
    wtListPanel:Show(false)
  end
end

function RefreshMiniMapOverlay()
  local markers = cartographer.GetMapMarkers(cartographer.GetCurrentZoneInfo().zonesMapId)
  for i, markerId in pairs(markers) do
    local markedobjects = cartographer.GetMapMarkerObjects(cartographer.GetCurrentZoneInfo().zonesMapId, markerId)
    for _, v in pairs(markedobjects) do
      geodata = v.geodata
    end
  end
  --
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
  wtMiniMapPanel:Show(false)
  MainMap:AddChild(wtListPanel)
  LoadPoints()
  Extract()
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
  if ShowMetki.HERB then
    cBtn[1]:SetVariant(1)
  else
    cBtn[1]:SetVariant(0)
  end
  if ShowMetki.GORN then
    cBtn[2]:SetVariant(1)
  else
    cBtn[2]:SetVariant(0)
  end
end

-- EVENT_SECOND_TIMER
function OnTimer()
  OnMap()
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
    if points[i].MAP == currentMapName and IsPointInCircle(pos, points[i], Radius) then
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
    Log("Скрыть...")
    if wtMainPanel:IsVisible() then
      wtMainPanel:Show(false)
      ShowMap = false
    else
      wtMainPanel:Show(true)
      ShowMap = true
    end
  elseif widgetName == "sBtn2" then -- Сброс точек на карте
    Log("Сброс точек на карте")
    -------------------------------------------
    -- сравнение названий карт
    local sizeKol = #points
    for i = 1, #points do
      if points[i] then
        if CurrentMap() == points[i].MAP then
          Log("Точки на данной карте найдены "..i.." всего точек "..#points)
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
          Log("Точки на данной карте не найдены всего их "..#points)
        end
      end
    end
    SavePoints()
    -------------------------------------------
  elseif widgetName == "sBtn3" then -- сброс всех точек
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
  if widgetName == "cBtn1" then -- Травничество
    if cBtn[1]:GetVariant() == 1 then
      -- скрыть
      cBtn[1]:SetVariant(0)
      ShowMetki.HERB = false
    else -- отобразить
      cBtn[1]:SetVariant(1)
      ShowMetki.HERB = true
    end
  elseif widgetName == "cBtn2" then -- Горное
    if cBtn[2]:GetVariant() == 1 then
      -- скрыть
      cBtn[2]:SetVariant(0)
      ShowMetki.GORN = false
    else -- отобразить
      cBtn[2]:SetVariant(1)
      ShowMetki.GORN = true
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
