--- UI module
-- @module UI

Global("UI", {})

local stackDesc = mainForm:GetChildChecked("StackTemplate", false):GetWidgetDesc()
local frameDesc = mainForm:GetChildChecked("FrameTemplate", false):GetWidgetDesc()
local checkBoxDesc = mainForm:GetChildChecked("CheckboxTemplate", false):GetWidgetDesc()
local buttonDesc = mainForm:GetChildChecked("ButtonTemplate", false):GetWidgetDesc()
local popupButtonDesc = mainForm:GetChildChecked("PopupButtonTemplate", false):GetWidgetDesc()
local labelDesc = mainForm:GetChildChecked("LabelTemplate", false):GetWidgetDesc()

local CheckboxCallbacks = {}
local ButtonCallbacks = {}

function UI:Init()
  common.RegisterReactionHandler(UI.OnCheckboxClicked, "on_checkbox_clicked")
  common.RegisterReactionHandler(UI.OnButtonClicked, "on_button_clicked")
end

function WidgetID(widget)
  return common.RequestIntegerByInstanceId(widget:GetInstanceId())
end

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
  if sizeX then placement.sizeX = sizeX end
  if sizeY then placement.sizeY = sizeY end
  wt:SetPlacementPlain(placement)
end

function Repeat(count, block)
  local items = {}
  for index = 1, count do
    items[index] = block(index)
  end
  return items
end

local FrameContents = {}

---@param name string @widget name
---@param args table @with fields { edges, content }
function Frame(name)
  return function(args)
    local content = UI.Unwrap(args.content)
    local left, top, _, _ = UI.Edges(args.edges)

    local frame = mainForm:CreateWidgetByDesc(frameDesc)
    frame:SetName(name)
    frame:AddChild(content)
    SetPos(content, left, top, WIDGET_ALIGN_LOW, WIDGET_ALIGN_LOW)

    FrameContents[WidgetID(frame)] = {
      content = content,
      edges = args.edges
    }
    RegisterShowListener(frame)
    frame:Show(true)
    return frame, content
  end
end

function RegisterShowListener(frame)
  local mt = getmetatable(frame)
  if mt._HM_Show then
    return
  end
  mt._HM_Show = mt.Show
  mt.Show = function(self, show)
    self:_HM_Show(show)
    local frameData = FrameContents[WidgetID(self)]
    if show and frameData then
      local placement = frameData.content:GetPlacementPlain()
      local left, top, right, bottom = UI.Edges(frameData.edges)
      SetSize(self, left + placement.sizeX + right, top + placement.sizeY + bottom)
    end
  end
end

---@param args table @with fields { isChecked, onChecked }
function Checkbox(args)
  local checkbox = mainForm:CreateWidgetByDesc(checkBoxDesc)
  checkbox:SetVariant(args.isChecked and 1 or 0)
  checkbox:Show(true)
  CheckboxCallbacks[WidgetID(checkbox)] = args.onChecked
  return checkbox
end

---@param args table @with fields { title, isInstantClick, onClicked, style, fontSize, sizeX, sizeY }
function Button(args)
  local desc = args.isInstantClick and popupButtonDesc or buttonDesc
  local button = mainForm:CreateWidgetByDesc(desc)
  button:SetVal("Text", args.title)
  button:SetClassVal("Style", args.style or "tip_golden")
  button:SetClassVal("FontSize", "Size" .. (args.fontSize or 12))
  button:Show(true)
  ButtonCallbacks[WidgetID(button)] = args.onClicked
  SetSize(button, args.sizeX, args.sizeY)
  return button
end

---@param args table @with fields { text, style, fontSize }
function Label(args)
  local label = mainForm:CreateWidgetByDesc(labelDesc)
  label:SetVal("Text", args.text)
  label:SetClassVal("Style", args.style or "tip_white")
  label:SetClassVal("FontSize", "Size" .. (args.fontSize or 14))
  label:Show(true)
  return label
end

---@param args table @with fields { edges, spacing, gravity, children }
function HStack(args)
  local left, top, right, bottom = UI.Edges(args.edges)

  local stack, maxSize, x = UI.Stack(
      UI.Unwrap(args.children),
      left, top,
      function(index, placement)
        return { before = index > 1 and args.spacing or 0, after = placement.sizeX }, { before = 0, after = 0 }, WIDGET_ALIGN_LOW, args.gravity, placement.sizeY
      end
  )
  SetSize(stack, x + right, top + maxSize + bottom)
  return stack
end

---@param args table @with fields { edges, spacing, gravity, children }
function VStack(args)
  local left, top, right, bottom = UI.Edges(args.edges)

  local stack, maxSize, _, y = UI.Stack(
      UI.Unwrap(args.children),
      left, top,
      function(index, placement)
        return { before = 0, after = 0 }, { before = index > 1 and args.spacing or 0, after = placement.sizeY }, args.gravity, WIDGET_ALIGN_LOW, placement.sizeX
      end
  )
  SetSize(stack, left + maxSize + right, y + bottom)
  return stack
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

function UI.Unwrap(item)
  if type(item) == 'function' then
    return item()
  elseif type(item) == 'table' then
    return UI.Flatten(item)
  else
    return item
  end
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

--------------------------------------------------------------------------------
-- REACTION HANDLERS
--------------------------------------------------------------------------------

-- on_checkbox_clicked
function UI.OnCheckboxClicked(params)
  if DnD:IsDragging() then return end

  local sender = params.widget
  local wasChecked = sender:GetVariant() == 1
  sender:SetVariant(wasChecked and 0 or 1)

  local callback = CheckboxCallbacks[WidgetID(sender)]
  if callback then
    callback(not wasChecked)
  end
end

-- on_button_clicked
function UI.OnButtonClicked(params)
  if DnD:IsDragging() then return end

  local callback = ButtonCallbacks[WidgetID(params.widget)]
  if callback then
    callback()
  end
end