--- UI module
-- @module UI

local UI = {}

local stackDesc = mainForm:GetChildChecked("StackTemplate", false):GetWidgetDesc()
local frameDesc = mainForm:GetChildChecked("FrameTemplate", false):GetWidgetDesc()
local checkBoxDesc = mainForm:GetChildChecked("CheckboxTemplate", false):GetWidgetDesc()
local buttonDesc = mainForm:GetChildChecked("bottom", false):GetWidgetDesc()

function PosXY(wt, posX, sizeX, posY, sizeY, alignX, alignY)
  local placement = wt:GetPlacementPlain()
  if posX then placement.posX = posX end
  if sizeX then placement.sizeX = sizeX end
  if posY then placement.posY = posY end
  if sizeY then placement.sizeY = sizeY end
  if alignX then placement.alignX = alignX end
  if alignY then placement.alignY = alignY end
  wt:SetPlacementPlain(placement)
end

function SetPos(wt, posX, posY, alignX, alignY)
  local placement = wt:GetPlacementPlain()
  if posX then placement.posX = posX end
  if posY then placement.posY = posY end
  if alignX then placement.alignX = alignX end
  if alignY then placement.alignY = alignY end
  wt:SetPlacementPlain(placement)
end

function SetSize(wt, sizeX, sizeY)
  local placement = wt:GetPlacementPlain()
  placement.sizeX = sizeX
  placement.sizeY = sizeY
  wt:SetPlacementPlain(placement)
end

function Repeat(count, block)
  local items = {}
  for index = 1, count do
    items[index] = block(index)
  end
  return items
end

function Frame(name, content)
  local frame = mainForm:CreateWidgetByDesc(frameDesc)
  frame:SetName(name)
  frame:AddChild(content)
  local placement = content:GetPlacementPlain()
  SetSize(frame, placement.sizeX, placement.sizeY)
  frame:Show(true)
  return frame, content
end

function Checkbox(name, isChecked)
  local checkbox = mainForm:CreateWidgetByDesc(checkBoxDesc)
  checkbox:SetName(name)
  checkbox:SetVariant(isChecked and 1 or 0)
  checkbox:Show(true)
  return checkbox
end

function Button(name, title)
  local button = mainForm:CreateWidgetByDesc(buttonDesc)
  button:SetName(name)
  button:SetVal("Name", title)
  button:Show(true)
  return button
end

function HStack(spacing, edges, gravity)
  return function(children)
    local left, top, right, bottom = UI.Edges(edges)

    local stack, maxSize, x = UI.Stack(
        UI.Flatten(children),
        left, top,
        function(index, placement)
          return { before = index > 1 and spacing or 0, after = placement.sizeX }, { before = 0, after = 0 }, WIDGET_ALIGN_LOW, gravity, placement.sizeY
        end
    )
    SetSize(stack, x + right, top + maxSize + bottom)
    return stack
  end
end

function VStack(spacing, edges, gravity)
  return function(children)
    local left, top, right, bottom = UI.Edges(edges)

    local stack, maxSize, _, y = UI.Stack(
        UI.Flatten(children),
        left, top,
        function(index, placement)
          return { before = 0, after = 0 }, { before = index > 1 and spacing or 0, after = placement.sizeY }, gravity, WIDGET_ALIGN_LOW, placement.sizeX
        end
    )
    SetSize(stack, left + maxSize + right, y + bottom)
    return stack
  end
end

function UI.Edges(edges)
  if not edges then
    return 0, 0, 0, 0
  end
  if edges.all then
    local edge = edges.all
    return edge, edge, edge, edge
  end
  return edges.left, edges.top, edges.right, edges.bottom
end

function UI.Stack(children, startX, startY, axisProperties)
  local stack = mainForm:CreateWidgetByDesc(stackDesc)

  local x = startX
  local y = startY

  local maxSize = 0
  for i = 1, #children do
    local child = children[i]
    stack:AddChild(child)

    local stepX, stepY, alignX, alignY, sideSize = axisProperties(i, child:GetPlacementPlain())
    maxSize = sideSize > maxSize and sideSize or maxSize

    x = x + stepX.before
    y = y + stepY.before
    SetPos(child, x, y, alignX, alignY)
    x = x + stepX.after
    y = y + stepY.after
  end
  stack:Show(true)
  return stack, maxSize, x, y
end

function UI.Flatten(item, result)
  local arr = result or {}
  if type(item) == 'table' then
    for _, v in pairs(item) do
      UI.Flatten(v, arr)
    end
  elseif type(item) == 'function' then
    arr[#arr + 1] = item()
  else
    arr[#arr + 1] = item
  end
  return arr
end