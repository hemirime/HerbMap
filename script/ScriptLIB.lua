---- update 2011.09.26
function AT_Vers()
	return {
		lib = 8, --- 4.0.02 --itemInfi.name = name + quality+level+mets+... [[[ScriptLIB + itemLib + wtGetSizeY
		tools = 3, --- AddonsTools - LibDnD - use standard
		menu = 8, --- + childObj-destroy()
		addons = 4, --- AddonsMenu + PlanTime + +skin+terxtures
		version = "r81d", -- item.temporaryInfo
	}
end

local ADDONname = common.GetAddonName()

local valuedText = common.CreateValuedText()
local formatVT = "<html fontname='AllodsSystem' shadow='1'><rs class='color'><r name='addon'/><r name='text'/></rs></html>"
valuedText:SetFormat(userMods.ToWString(formatVT))

--------------------------------------------------------------------------------
-- FUNCTIONS
--------------------------------------------------------------------------------
local ScreenSize
local wtToResizeOnResolutionChanged = {}
local function OnResolutionChanged()
	local newScreenSize = widgetsSystem:GetPosConverterParams()
	---exObj("ScreenSize",ScreenSize)
	for i, wt in pairs(wtToResizeOnResolutionChanged) do
		local plc = wt:GetPlacementPlain()
		for _, v in pairs({ "size", "pos", "highPos" }) do
			for _, xy in pairs({ "X", "Y" }) do
				local k = v .. xy
				plc[k] = plc[k] / ScreenSize["fullVirtualSize" .. xy] * newScreenSize["fullVirtualSize" .. xy]
			end
		end
		wt:SetPlacementPlain(plc)

	end
	ScreenSize = newScreenSize
end

function wtAddForResolutionChanged(wt)
	table.insert(wtToResizeOnResolutionChanged, wt)
end

function getScreenSizeCenter()
	---return ScreenSize.fullVirtualSizeX/2, ScreenSize.fullVirtualSizeY/2
	return ScreenSize.realSizeX / 2, ScreenSize.realSizeY / 2
end

OnResolutionChanged()
common.RegisterEventHandler(OnResolutionChanged, "EVENT_POS_CONVERTER_CHANGED")


local ToDo = {}
function ToDo_Add1(time, func, arg)
	table.insert(ToDo, { time = time, func = func, arg = arg })
end

local function sTimer(pars)
	for i, item in pairs(ToDo) do
		if item.time <= 0 then
			item.func(item.arg)
			table.remove(ToDo, i)
		else
			item.time = item.time - 1
		end
	end
end

common.RegisterEventHandler(sTimer, "EVENT_SECOND_TIMER")



--- ������������ ��������� - ��� ����������� � ������� ���������
--- ����� user.cfg �� ���������, ��������� PS �� config.txt ��������� �� ����� � ���������� ����
--- ����� ������� ��������� ���������� ����� ������ ������ � ������������ ���������
--- ������ setPS(i)=... === PSD.i=...
local PSD = {}
--- ������ ���� ����������� �������� ���� ����������� (�� config.txt) - � ������������ ���������� ��������
--- getPS(key) -- ����� ��������������� �� ���������� ���������� ��������
local PSnames = {}
function getPS(key, name)
	local index = name and key .. name or key
	--- ��� �� � ������������� ���� ���������� ���� ��������� ("tbSIZE"), �� ����� ���������� ("SIZE")
	local val = PSD[index]
	if val then
		--[[if val == "-" and name then
			--- ���� ��� ������� � �������� �������� ����������� �� ������� ��� ���������� ��������
			val = getPS(name)
		end
		]]
	elseif PS[index] ~= nil then
		val = PS[index]
	elseif name and PSD[name] ~= nil then
		val = PSD[name]
	elseif name and PS[name] ~= nil then
		val = PS[name]
	else
		val = nil
	end
	--- ���� ������ ��������� ��� �������� - �������� ��� ��������� ����� ��� ������ � ����������
	if val == nil then
		PSnames[index] = PSnames[index] or "-"
	else
		PSnames[index] = ListParsRef[val] or type(val)
	end
	--- ���� ��� ������� - �� ���� ������� ����������� ������� - ��������� + ������� ���������
	if type(val) == "table" then
		local tab = {}
		for k, v in pairs(name and PS[name] or {}) do
			tab[k] = v
		end
		for k, v in pairs(PS[index] or {}) do
			tab[k] = v
		end
		for k, v in pairs(name and PSD[name] or {}) do
			tab[k] = v
		end
		for k, v in pairs(PSD[index] or {}) do
			tab[k] = v
		end
		return tab
	else
		return val
	end
end

function getPSnames(key)
	return PSnames
end

--- ������������ � ��������
function setPS(index, val)
	PSD[index] = val
end

--- ��������� �������� � �������
function addPS(index, tab)
	if not PSD[index] then PSD[index] = {} end
	for k, v in pairs(tab) do
		PSD[index][k] = v
	end
end

--- ������� �������� �� �������
function remPS(index, tab)
	if PSD[index] then
		for _, k in pairs(tab) do
			PSD[index][k] = nil
		end
	end
end

--- ��� ������ ������������ ���������� ����
function getPSD()
	return PSD
end

function setPSD(val)
	PSD = val
end

function GetErrMessages()
	if IsEmptyTable(errMess) then
		return _
	end
	return errMess
end

------------------------------------------------------------------
------ Loging To Chat
------------------------------------------------------------------
---- output in Chat. created by icreator(EDS) 2011/01/23
--- initial ref
--- Chat...Chat
local wtChat = nil
local chatRows = 0 --- for clear buffer after show messages

--- ����� ���� ���������� ����
--- ������ ��������� ���� � ������� ��� ����
function GetSysChatContainer()
	--- ������ ���� ����
	--- Chat..Chat
	---local w = getNamedChild(stateMainForm, "Chat", false)
	local parents = 2
	local w = stateMainForm:GetChildUnchecked("Chat", false)
	if not w then
		--- ������ ����� �� ������� - ������ �� �������
		w = stateMainForm:GetChildUnchecked("Chat", true)
	else
		w = w:GetChildUnchecked("Chat", true)
	end
	if not w then ---- 2.0.06.13 [26.05.2011]
		w = stateMainForm:GetChildUnchecked("ChatLog", false)
		---getAllChildrensOfWidget("ChatLog",w, "PushBack")
		w = w:GetChildUnchecked("Container", true)
		if w then parents = 3 end
	end

	return w, wtGetNumParents(w, parents)
end

function LogToChatVT(valuedText, name, toWW)
	--- ����� � ��� ValuedText
	name = name or ADDONname
	--- ������� � WhisperWindow
	if toWW then LogToChatWWVT(valuedText, name) end
	--- � ��������� ������� � ��������� ���
	if not wtChat then wtChat = GetSysChatContainer() end
	if wtChat and wtChat.PushFrontValuedText then
		--- �������� ��� 1 ������� � ��������� ��� ��������
		chatRows = chatRows + 1
		valuedText:SetVal("addon", userMods.ToWString(name .. ": "))
		wtChat:PushFrontValuedText(valuedText)
	end
end

function LogToChatWWVT(valuedText, name)

	local sender = name or ADDONname --- object.GetName(avatar.GetId())
	if not common.IsWString(sender) then sender = userMods.ToWString(sender) end
	local senderId = avatar.IsExist() and avatar.GetId()
	local chatType = CHAT_TYPE_NOTICE --- -1 ---CHAT_TYPE_NOTICE ---CHAT_TYPE_WHISPER --- = -1 --- �� �������
	local recipient = sender
	userMods.SendEvent("EVENT_CHAT_MESSAGE_WITH_OBJECTS", { msg = valuedText, chatType = chatType, sender = sender, isEcho = true, isAlive = true, recipient = recipient, senderId = senderId })

end

--[[ semd message to chat and WishperWindow chat
 message , color,
 toWW = true|false|nil
]]
function LogToChat(message, color, toWW)

	valuedText:ClearValues() --- ����������� �������
	valuedText:SetClassVal("color", color or "LogColorYellow")
	if not common.IsWString(message) then message = userMods.ToWString(message) end
	valuedText:SetVal("text", message)
	LogToChatVT(valuedText, ADDONname, toWW)

end

--- call by "EVENT_SECOND_TIMER" - for clear messages from chat
function ClearChat(size)
	--- ������� ���������� �� ���������� ���� ����� - ����� �� �� ������������
	-- � �� �������� �����
	if chatRows < 1 then return end
	if wtChat then
		for i = 1, size or math.ceil(chatRows / 30) + 1 do
			if chatRows < 1 then return end
			chatRows = chatRows - 1
			wtChat:PopBack()
		end
	else
		wtChat = GetSysChatContainer()
	end
end

------------------------------------------------------------------------------------

--- Log error mess to Chat
function ErrToChat(mess)
	LogToChat("ERROR: " .. mess, "LogColorRed")
end

function getAllChildrensOfWidget(tab, widget, metod)
	local childrens = widget:GetNamedChildren()
	for _, w in pairs(childrens) do
		local tab1 = tab .. ":" .. w:GetName()
		if metod and w[metod] then tab1 = tab1 .. " proc." .. metod end
		LogInfo(tab1)
		getAllChildrensOfWidget(tab1, w)
	end
end

function testAllMainForms()
	local childrens = stateMainForm:GetNamedChildren()
	for _, w in pairs(childrens) do
		if string.lower(w:GetName()) == "mainform" then getAllChildrensOfWidget("+", w) end
	end
end

--- ������ ������� �������, ����� ������ ��� ���
function getNamedChild(w, name, recursive)
	local ch = w:GetChildUnchecked(name, recursive)
	if ch then
		return ch
	else
		LogInfo(" ERROR: can't find widget \"", name, "\" in parent \"", w:GetName(), "\"")
		LogInfo(w:GetName(), " childs:")
		for _, ww in pairs(w:GetNamedChildren()) do
			LogInfo(ww:GetName())
		end
	end
end

wtGetAllParents = function(w)
	if w.GetParent then
		local pr = w:GetParent()
		if pr then
			return wtGetAllParents(pr) .. ":" .. w:GetName()
		end
	end
	if w.GetName then return w:GetName() end
	return ""

end

--- ���������� �������� ���� �� �����
wtGetNumParents = function(w, parents)
	if parents > 0 and w.GetParent then
		local pr = w:GetParent()
		---LogInfo( pr:GetName() )
		if pr then
			return wtGetNumParents(pr, parents - 1)
		end
	end
	return w
end


function alt_Z()
	---AO 2.0:
	---:ContextPinMenu2:MainPanel:PinPanelLeft:PinButtonItemMall
	---:ContextItemMall
	---:WidgetsManagerForm
	---:ContextItemMall:ItemMall:Stand:Plate03:Favorites
	---old
	---:ItemMall:Stand:Plate03:Favorites

	local w, n
	if true then
		n = "ContextDamageVisualization" --- ��� ��������� ����� �������
		n = "ContextItemMall" --- 7900 priority
		n = "ContextOverlayMap" --- 3200
		w = stateMainForm:GetChildUnchecked(n, false)
		if w then
			----n = mainForm:GetPriority()
			w:AddChild(mainForm)
			----mainForm:SetPriority( n-w:GetPriority() )
			----LogToChat(""..mainForm:GetPriority())
		else
		end
	else
		w = stateMainForm:GetChildUnchecked("PinButtonItemMall", true)
		if w then
			w = w:GetParent():GetParent():GetParent()
			w:AddChild(mainForm)
		end
	end
end

function wtResize(w, dX, dY)
	local place = w:GetPlacementPlain()
	place.sizeX = place.sizeX + dX
	place.sizeY = place.sizeY + dY
	w:SetPlacementPlain(place)
end

function wtSize(w, sizeX, sizeY)
	local place = w:GetPlacementPlain()
	place.sizeX = sizeX or place.sizeX
	place.sizeY = sizeY or place.sizeY
	w:SetPlacementPlain(place)
end

function wtScale(w, scaleX, scaleY, andChildrens)

	if not w or (scaleX == 1 and scaleY == 1) then return end
	local place = w:GetPlacementPlain()
	---LogInfo(w:GetName())
	place.posX = math.ceil(place.posX * scaleX)
	place.highPosX = math.ceil(place.highPosX * scaleX)
	place.posY = math.ceil(place.posY * scaleY)
	place.highPosY = math.ceil(place.highPosY * scaleY)
	if not w.SetVal and not w.GetText then
		----LogInfo("scaled....")
		---- ���� ��� �� ������� ValuedText � �� EditLine  �� ����� �������� ��� �������
		place.sizeX = math.ceil(place.sizeX * scaleX)
		place.sizeY = math.ceil(place.sizeY * scaleY)
	end
	if w.SetTextScale then
		w:SetTextScale(scaleX)
	end
	w:SetPlacementPlain(place)

	if andChildrens then
		--- ���� ������� ����
		for _, wCh in pairs(w:GetNamedChildren()) do
			wtScale(wCh, scaleX, scaleY, andChildrens)
		end
	end
end

function wtMove(w, shiftX, shiftY, highShiftX, highShiftY)
	local place = w:GetPlacementPlain()
	place.posX = place.posX + shiftX
	place.posY = place.posY + shiftY
	if highShiftX then place.highPosX = place.highPosX + highShiftX end
	if highShiftY then place.highPosY = place.highPosY + highShiftY end
	w:SetPlacementPlain(place)
end

function wtPlace(w, posX, posY, alignX, alignY)
	local place = w:GetPlacementPlain()
	place.posX = posX or place.posX
	place.posY = posY or place.posY
	place.alignX = alignX or place.alignX
	place.alignY = alignY or place.alignY
	w:SetPlacementPlain(place)
end

--- �������� ��������� ��������
function wtSetPlace(w, place)
	local p = w:GetPlacementPlain()
	for k, v in pairs(place) do
		p[k] = place[k] or v
	end
	w:SetPlacementPlain(p)
end

--- ����� ���������� ���������� � ������ ����
function wtGetAbsPos(w)
	--[[	local p = w:GetPlacementPlain()
	if p.alignX == 0 then
	elseif p.alignX == 1 then p.posX = p.posX + ScreenSize.realSizeX
	elseif p.alignX == 2 then p.posX = p.posX + ScreenSize.realSizeX
	end
	return p.posX, p.posY
--]]
	local rect = w:GetRealRect()

	local place = w:GetPlacementPlain()
	place.alignX = WIDGET_ALIGN_LOW_ABS
	place.alignY = WIDGET_ALIGN_LOW_ABS
	place.posX = rect.x1
	place.posY = rect.y1
	place.highPosX = rect.x2
	place.highPosY = rect.y2
	place.sizeX = place.sizeX or rect.x2 - rect.x1
	place.sizeY = place.sizeY or rect.y2 - rect.y1
	return place
end

--- ���������� ������ �������
function wtGetSizeX(w, p)
	--[[ ��� ������������ �� �������� �����	local rr = w:GetRealRect()
	return rr.x2-rr.x1, rr.y2-rr.y1
--]]
	if not w then return ScreenSize.fullVirtualSizeX end
	if not p then p = w:GetPlacementPlain() end
	--LogIndo(w:GetName(),": sX=", p.sizeX,"  sY=",p.sizeY )

	if p.alignX == 3 then
		local parent = w.GetParent and w:GetParent()
		return wtGetSizeX(parent) - p.posX - p.highPosX

	elseif p.alignX == WIDGET_ALIGN_LOW_ABS then
		--exObj2("abs",p)
		return p.sizeX * ScreenSize.fullVirtualSizeX / ScreenSize.realSizeX
	else
		return p.sizeX
	end

end

--- ���������� ������ �������
function wtGetSizeY(w, p)
	--[[ ��� ������������ �� �������� �����	local rr = w:GetRealRect()
	return rr.x2-rr.x1, rr.y2-rr.y1
--]]
	if not w then return ScreenSize.fullVirtualSizeY end
	if not p then p = w:GetPlacementPlain() end
	if p.alignY == 3 then
		local parent = w.GetParent and w:GetParent()
		return wtGetSizeY(parent) - p.posY - p.highPosY

	elseif p.alignX == WIDGET_ALIGN_LOW_ABS then
		return p.sizeY * ScreenSize.fullVirtualSizeY / ScreenSize.realSizeY
	else
		return p.sizeY
	end

end

--- ������� �� �������� ������� ������ ������������� �������
function wtAttach(w, wtBase, dx, dy)
	local p = w:GetPlacementPlain()
	local base = wtBase:GetRealRect()
	--[[ ������� ��� ��� ����� ���������� ����� ������ � � ��� ������� ��� ���� ����
	p.alignX = WIDGET_ALIGN_LOW_ABS
	p.alignY = WIDGET_ALIGN_LOW_ABS
	p.posX = base.x1 + dx
	p.posY = base.y1 + dy
--]]
	local pBase = wtBase:GetPlacementPlain()
	local parentSizeX = wtGetSizeX(wtBase:GetParent())
	local parentSizeY = wtGetSizeY(wtBase:GetParent())
	if pBase.alignX == 1 then
		--- ���� ������� �� ������� ��������������� �� �� ������� ��������
		p.posX = parentSizeX - pBase.highPosX - pBase.sizeX + dx
		p.alignX = 0
		p.highPosX = 0
	else
		p.alignX = pBase.alignX
		p.highPosX = pBase.highPosX + dx
		p.posX = pBase.posX + dx
	end
	if pBase.alignY == 1 then
		p.posY = parentSizeY - pBase.highPosY - pBase.sizeY + dy
		p.alignY = 0
		p.highPosY = 0
	else
		p.alignY = pBase.alignY
		p.highPosY = pBase.highPosY + dy
		p.posY = pBase.posY + dy
	end

	w:SetPlacementPlain(p)
end

--- ��������� � �������� � ����
function wtAttLeft(w, wtBase, dx)
	local p = w:GetPlacementPlain()
	--[[	local base = wtBase:GetRealRect()
	p.alignX = WIDGET_ALIGN_LOW_ABS
	p.posX = base.x1 - p.sizeX - dx
	LogToChat(base.x1..":"..p.posX)
--]]
	local pBase = wtBase:GetPlacementPlain()
	local parentSizeX = wtGetSizeX(wtBase:GetParent())
	--- ��� ���� ����������� ������ ������� ���� ������ ���������������
	p.alignX = 1
	if pBase.alignX == 1 then
		p.posX = 0
		p.highPosX = pBase.highPosX + pBase.sizeX + dx
	else
		p.posX = 0
		p.highPosX = parentSizeX - pBase.posX + dx
	end
	p.posY = pBase.posY
	p.highPosY = pBase.highPosY
	p.alignY = pBase.alignY
	w:SetPlacementPlain(p)
end

--- ��������� � �������� ������
function wtAttRight(w, wtBase, dx)
	local p = w:GetPlacementPlain()
	--[[	local base = wtBase:GetRealRect()
	p.alignX = WIDGET_ALIGN_LOW_ABS
	p.posX = base.x2 + dx
--]]
	local pBase = wtBase:GetPlacementPlain()
	local parentSizeX = wtGetSizeX(wtBase:GetParent())
	--- ��� ���� ����������� ������ ������ ���� ������ ���������������
	p.alignX = 0
	if pBase.alignX == 1 then
		p.posX = parentSizeX - pBase.highPosX + dx
		p.highPosX = 0
	else
		p.posX = pBase.posX + pBase.sizeX + dx
		p.highPosX = 0
	end
	p.posY = pBase.posY
	p.highPosY = pBase.highPosY
	p.alignY = pBase.alignY
	w:SetPlacementPlain(p)
end

--- ��������������� � ������������ �������
function wtChain(w, wBase, dx, dy)
	--LogToChat(dx..":".. dy)
	local p, r = w:GetPlacementPlain(), wBase:GetRealRect()
	local xx, yy = getScreenSizeCenter()
	p.alignX = WIDGET_ALIGN_LOW_ABS
	p.alignY = WIDGET_ALIGN_LOW_ABS
	local x, y = (r.x1 + r.x2) * 0.5, 0.5 * (r.y1 + r.y2) --- ����� ����� � ����
	---LogInfo(x,":",y, "   xx:y",xx, ":", yy)
	if xx > x then
		p.posX = x + dx
	else
		p.posX = x - dx - p.sizeX
	end
	if yy > y then
		p.posY = y + dy
	else
		p.posY = y - dy - p.sizeY
	end
	w:SetPlacementPlain(p)
end

--- �������� �����
function wtSetBColor(w, color)
	local clr = w:GetBackgroundColor()
	for k, v in pairs(color) do
		clr[k] = color[k] or v
	end
	w:SetBackgroundColor(clr)
end

function wtSetFColor(w, color)
	local clr = w:GetForegroundColor()
	for k, v in pairs(color) do
		clr[k] = color[k] or v
	end
	w:SetForegroundColor(clr)
end

function wtSetVal(w, v)
	local n = w:GetName()
	if string.sub(n, -4) == "_clr" and w.SetBackgroundColor then w:SetBackgroundColor(v) return end

	if type(v) == "number" then v = "" .. v
	elseif type(v) == "table" then v = "{table}"
	end
	if false then
	elseif string.find(n, "_btn") then w:SetVal("button_label", ToWS(v)) ---LogToChat(n)
	elseif string.find(n, "_mnu") then w:SetVal("button_label", ToWS(v))
	elseif string.find(n, "_edl") or string.find(n, "_edn") then w:SetText(ToWS(v))
	elseif string.find(n, "_chk") then w:SetVariant(v and 1 or 0)
	elseif string.find(n, "_cch") then w:SetVariant(v and 1 or 0) --- ������� CheckCmplx
	elseif w.SetVal then w:SetVal("value", ToWS(v))
	else LogInfo("wtSetVal: unknown widgets type:" .. n) errr()
	end
end

function wtGetVal(w)
	local n = w:GetName()
	if string.find(n, "_chk") then return w:GetVariant() == 1
	elseif string.find(n, "_edl") then return ToWS(w:GetText())
	end
end

local function wtReSkin(wt, nameIn)
	local name = nameIn or wt:GetName()
	if string.sub(name, -4) == "_frm" then
		if skin.texture then wt:SetBackgroundTexture(skin.texture) end
		if skin.color then wt:SetBackgroundColor(skin.color) end
	elseif string.sub(name, -4) == "_btn" then
		if skin.item_texture then wt:SetBackgroundTexture(skin.item_texture) end
		if skin.item_color then wt:SetBackgroundColor(skin.item_color) end
		--	if skin.item_font then wt:Set----BackgroundColor(skin.color ) end
	end
end

local skinnedWidgets = {}
--- ������� ������ �� �������� (descr), � ������ ( name), ��� �������� (parent), �� ����� (place � �������� (show)
--- skinOn = true -->
--          _frm +skin.texture  +skin.color
--          _btn +skin.item_texture  +skin.item_color
-- � ����� ������� ������ ��������� ����� �������� wtDestroy( w )
function WCD(descr, name, parent, place, show, skinOn)
	if not descr then LogInfo("ScriptLIB.lua/function WCD(): - Descriptor is nil...") return end
	local n
	n = mainForm:CreateWidgetByDesc(descr)
	if name then n:SetName(name) else n:SetName("") end
	if parent then parent:AddChild(n) end
	if place then wtSetPlace(n, place) end
	n:Show(show == true)
	if skinOn then
		--- ����� ��� ������ �� ������
		wtReSkin(n, name)
		--- � �������� ���� �� � ����������� �� �� �������
		--- � �� ������� ��� ����������
		skinnedWidgets[GetInstanceId(n)] = n
	end

	return n
end

function repaint_all_GUI()
	local name
	for ids, wt in pairs(skinnedWidgets) do
		wtReSkin(wt)
	end
end

function W(s, wt) return getNamedChild(wt or mainForm, s, true) end

--- ������ unchecked ������� �b����� ������ �� ��� ������
function Wun0(s, wt) return (wt or mainForm):GetChildUnchecked(s, false) end

function FromWS(str)
	if str then return userMods.FromWString(str) end
end

function ToWS(str)
	if str then return userMods.ToWString(str) end
end

---- ������� ������ �� �������
function delRows(tab, rows)
	for k in pairs(rows) do
		tab[k] = nil
	end
end

--- ������� ������� ������
function subTable(tab1, tab2)
	local subTab = {}
	for k, v in pairs(tab1) do
		if tab2[k] ~= v then
			subTab[k] = v
		end
	end
	return subTab
end

--- ��� ������ �������?
function IsEmptyTable(tab)
	for _ in pairs(tab) do
		return false
	end
	return true
end

function addTable(tab, add)
	for _, v in pairs(add) do
		table.insert(tab, v)
	end
end

---������ ��� ���� � �������� � ��� �� ������� �������
--- meta=true  - ������ ���������� �������
--- exclude = "filter string" or { filter_1 = 1, filter_2 = 1, ... }
function exObj(tab, obj, meta, exclude) --- explore an object

	if not tab then tab = "nil" end
	---��������� ��������
	if string.len(tab) > 100 then
		LogInfo(" �������� ����������!")
		return
	end

	if meta then
		local metaTable = getmetatable(obj)
		if metaTable then
			exObj(tab .. " meta", metaTable, nil, exclude)
		end
	end
	----LogInfo(tab, "{",type(obj),"}")
	if type(obj) == "table" then
		---- ������� ���� (����������) �������
		---if obj == {} then
		---	LogInfo ( tab, "{}")
		---	return
		---	end
		LogInfo(tab, "{")
		for k, v in pairs(obj) do
			if k == true then k = "[TRUE]" end
			if k == false then k = "[FALSE]" end
			---LogInfo ( tab, k,":=",v,  "{", type (v), "}")
			if k == "__index" then
				--- "__index" - �� ����� �� ����� ������� ��������� ����� ��� �������� � ������������
				--- ������� ������ ������� ������
				---LogInfo(tab, k)
				---for k1,v1 in pairs(v) do
				---	LogInfo ( tab, k, " - ",k1," = ",v1,"{", type (v1), "}")
				---end
			elseif k == "__gc" then
			elseif k == "_G" then
			elseif k == "parent" or exclude and (type(exclude) == "table" and exclude[k] or exclude == k) then
				LogInfo(tab .. "." .. k .. " -> excluded...")
			else
				if "userdata" ~= type(k) then exObj(tab .. "." .. k, v, nil, exclude)
				else exObj(tab .. ".userdata", v, nil, exclude)
				end
			end
		end
		LogInfo(tab, "}")
	elseif type(obj) == "string" then
		LogInfo(tab, "=\"", obj, "\"")
	elseif common.IsWString(obj) then
		LogInfo(tab, "=\"", obj, "{WString}")
	elseif type(obj) == "number" then
		LogInfo(tab, "=", obj)
	else
		LogInfo(tab, "=", obj, "{", type(obj), "}")
	end
end

---������ ��� ���� � �������� � ��� �� ������� �������
--- meta=true  - ������ ���������� �������
--- exclude = "filter string" or { filter_1 = 1, filter_2 = 1, ... }
function exObj2(val, obj, meta, exclude, level) --- explore an object

	local tabStr, tab = "   ", ""

	if not level then
		level = 0
	else
		level = level + 1
		tab = string.rep(tabStr, level) ---
	end

	--if not val then val="nil" end
	---��������� ��������
	if string.len(tab) > 100 then
		LogInfo(" �������� ����������!")
		return
	end

	if meta then
		local metaTable = getmetatable(obj)
		if metaTable then
			exObj2("[{meta}]", metaTable, nil, exclude, level)
		end
	end

	local comma = level == 0 and "" or ","

	----LogInfo(tab, "{",type(obj),"}")
	if type(obj) == "table" then
		---- ������� ���� (����������) �������
		---if obj == {} then
		---	LogInfo ( tab, "{}")
		---	return
		---	end

		LogInfo(tab, val, " = {")
		local key
		for k, v in pairs(obj) do
			key = k
			if key == true then key = "[TRUE]" end
			if key == false then key = "[FALSE]" end

			if key == "__index" then
				--- "__index" - �� ����� �� ����� ������� ��������� ����� ��� �������� � ������������
				--- ������� ������ ������� ������
				---LogInfo(tab, k)
				---for k1,v1 in pairs(v) do
				---	LogInfo ( tab, k, " - ",k1," = ",v1,"{", type (v1), "}")
				---end
			elseif key == "__gc" then
			elseif key == "_G" then
			elseif key == "parent" or exclude and (type(exclude) == "table" and exclude[key] or exclude == key) then
				LogInfo(tab .. tabStr, "[\"" .. key .. "\"]" .. " -> excluded...")
			else
				if "userdata" ~= type(k) then exObj2("[\"" .. key .. "\"]", v, nil, exclude, level)
				else exObj2("[{userdata}]", v, nil, exclude, level)
				end
			end
		end
		LogInfo(tab, "}" .. (level > 0 and "," or ""))
	elseif type(obj) == "boolean" then
		LogInfo(tab, val, " = ", obj, comma, " ---{boolean}")
	elseif type(obj) == "string" then
		LogInfo(tab, val, " = \"", obj, "\"", comma, " ---{string}")
	elseif common.IsWString(obj) then
		LogInfo(tab, val, " = \"", obj, "\"", comma, " ---{WString}")
	elseif type(obj) == "number" then
		LogInfo(tab, val, " = ", obj, comma)
	else
		LogInfo(tab, val, " = ", obj, comma, " --- {", type(obj), "}")
	end
end

function vers_corrupt()
	if true then
		return false
	else return true
	end
end

----------------------------
function IsWs(text)
	return common.IsWString(text)
end

--------------------------------------------------------------------------------
function IsEWs(text)
	return common.IsEmptyWString(text)
end

function GetIndexFromName(name)
	return tonumber(string.sub(name, -2)), string.sub(name, 1, string.len(name) - 2)
end

function IsEqual(value01, value02)
	if type(value01) == "table" and type(value02) == "table" then
		local match = true

		for id, value in pairs(value01) do
			match = IsEqual(value, value02[id])
			if match == false then break end
		end
		return match

	elseif IsWs(value01) and IsWs(value02) then
		return common.CompareWString(value01, value02) == 0

	else
		return value01 == value02
	end
end

--------------------------------------------------------------------------------
function IsTable(tab)
	return type(tab) == "table"
end

--------------------------------------------------------------------------------
function CloneNotUserData(value)
	if type(value) == "table" then
		local new = {}
		for id, val in pairs(value) do
			new[id] = CloneNotUserData(val)
		end
		return new
	else
		if type(value) == "string" then
			return "" .. value .. "" --- ��������� �������
		elseif type(value) == "userdata" then
			--- ���� ���� ����� - ������� ������ � ������
			return nil
		end
		--LogInfo(type(value))
		return value
	end
end

function Clone(value)
	if type(value) == "table" then
		local new = {}
		for id, val in pairs(value) do
			new[id] = Clone(val)
		end
		return new
	else
		if type(value) == "string" then
			return "" .. value .. "" --- ��������� �������
		end
		return value
	end
end

function SearchInTable(tab, entry)
	if not (IsTable(entry) and IsEmptyTable(entry)) then
		for id, value in pairs(tab) do
			if IsEqual(entry, value) then
				return id, value
			end
		end
	end
	return nil
end

--- ����� ������ ������ � ��� �������
function SearchInSubTable(tab, key, entry)
	if not (IsTable(entry) and IsEmptyTable(entry)) then
		for id, subTab in pairs(tab) do
			if IsEqual(subTab[key], entry) then
				return id, subTab
			end
		end
	end
	return nil
end

-------------------------------------------------------------------------------
function RegisterEventHandlers(handlers)

	for event, handler in pairs(handlers) do
		common.RegisterEventHandler(handler, event)
	end

end

function UnRegisterEventHandlers(handlers)

	for event, handler in pairs(handlers) do
		common.UnRegisterEventHandler(handler, event)
	end

end

-------------------------------------------------------------------------------
function RegisterReactionHandlers(handlers)

	for reaction, handler in pairs(handlers) do
		---LogToChat(reaction)
		common.RegisterReactionHandler(handler, reaction)
	end
end

function UnRegisterReactionHandlers(handlers)

	for reaction, handler in pairs(handlers) do
		---LogToChat("UN:"..reaction)
		common.UnRegisterReactionHandler(handler, reaction)
	end
end

--- �������� ValuedTex
--- ��������� - ���� ��������� - �� ��� ���� ��� class
--- valuedObject - ��� ��� ����� � r name
--- ��� �������� - ��������� � ������� ��������
function makeValuedText(format, params)
	local vt = common.CreateValuedText()
	vt:SetFormat(userMods.ToWString(format))
	for k, v in pairs(params) do
		if type(v) == "string" then vt:SetClassVal(k, v)
		else vt:SetVal(k, v)
		end
	end
	return vt
end

function GetGlobalConfig(name)
	local cfg = userMods.GetGlobalConfigSection(common.GetAddonName()) or {}
	return name == nil and cfg or cfg[name]
end

function SetGlobalConfig(name, value)
	local cfg = userMods.GetGlobalConfigSection(common.GetAddonName()) or {}
	if type(name) == "table" then
		for i, v in pairs(name) do cfg[name][i] = v end
	elseif name ~= nil then
		cfg[name] = value
	end
	userMods.SetGlobalConfigSection(common.GetAddonName(), cfg)
end

--- ������������� �������� � ������� �� ������� �� ��������� ������� �����:
--- local key, tab = unpackToTab("����� ����:0|123455|3|2|1|5|", {"MinBid", "Buyout", "StackCount", "TimeSel", "Spread", "RandomCh"} )
--- (�������� ��� ��� � ��������� ��������� ":", ������ ������ ��� "|"
--- unpackToTab("����� ����|0|123455|3|2|1|5|", {"MinBid", "Buyout", "StackCount", "TimeSel", "Spread", "RandomCh"} )
function unpackToTab(str, pars)
	local _, val, pos, key, sEnd, val2
	_, pos = string.find(str, "|")
	if not pos then return end
	key = strFromNormalize(string.sub(str, 1, pos - 1))
	local tab = {}
	sEnd = string.sub(str, pos + 1)
	for i, par in ipairs(pars) do
		_, pos = string.find(sEnd, "|")
		if not pos then break end
		val = strFromNormalize(string.sub(sEnd, 1, pos - 1))
		sEnd = string.sub(sEnd, pos + 1)
		tab[par] = val
	end
	---LogToChat("from norm:"..key, nil, true)
	return key, tab
end

--- ������������ ������� �� ������� ����� ��� ���������� � ������
function packFromTab(key, tab, template)
	local str = strToNormalize(key) .. "|"
	for i, v in pairs(template) do
		str = tab[v] and str .. strToNormalize("" .. (tab[v] or "")) .. "|"
	end
	---LogToChat("to norm:"..str, nil, true)
	return str
end

strToNormalize = function(str)
	local res = ""
	local char
	for i = 1, string.len(str) do
		char = string.sub(str, i, i)
		if char == '"' then char = "'" end
		res = res .. char
	end
	return res
end
strFromNormalize = function(str)
	local res = ""
	local char
	for i = 1, string.len(str) do
		char = string.sub(str, i, i)
		if char == "'" then char = '"' end
		res = res .. char
	end
	return res
end


--- ���������� ��������� ��������� ������
getStateAddon = function(name)
	local nn = "UserAddon/" .. name
	for i, addon in pairs(common.GetStateManagedAddons()) do
		if addon.name == nn then
			return addon.isLoaded
		end
	end
end
--- ���������� ��������� ��������� ���������� ������
getStateSysAddon = function(name)
	local nn = name
	for i, addon in pairs(common.GetStateManagedAddons()) do
		if addon.name == nn then
			return addon.isLoaded
		end
	end
end

--- ���������� ��� �����, ����� ���� x � ������� ����� x.
--- 123.45 = 123, 45
function modf100(x)
	local f = math.floor(x)
	return f, math.floor((x - f) * 100) / 100
end

--- ������ ��� ��� ������ � ������ � ����� �����
function modf100string(x)
	local f, m = modf100(x)
	return f .. ".", string.format("%02d", m * 100) ---string.sub( string.format("%02d",m),3)
end

----------------------------------------------------------------------------- CLASS CONSTRUCTOR
function addmetatable(tab, mt)
	local _mt = getmetatable(tab)
	_mt = type(_mt) == "table" and _mt or {}

	for k, v in pairs(mt) do
		_mt[k] = v
	end

	setmetatable(tab, _mt)
end

-- ScriptClassesImplementation.lua
-- from Interface.1.0.03.26.2\Common\Script
-- REQUIRES: ScriptStandardExtension.lua
--------------------------------------------------------------------------------
do
	local constructor = function(cl, object)
		local object = object or {}
		addmetatable(object, { __index = cl })
		return object
	end
	------------------------------------------------------------------------------
	function class(proto)
		addmetatable(proto, { __call = constructor })
		return proto
	end

	------------------------------------------------------------------------------
	function Class(name, object)
		Global(name, class(object))
	end
end
--------------------------------------------------------------------------------


local function getVersionAO1()
	if false then
	elseif avatar.GetInventoryOverflowSize then return 3 --- 2.0.08.12 [3.08.2011]  �����
	elseif stateMainForm:GetChildUnchecked("ChatLog", false) then ---- 2.0.06.13 [26.05.2011]
		local w = stateMainForm:GetChildUnchecked("RollGreedNeed", false)
		if w and w:GetChildUnchecked("ItemSlot", true) then --- --- 2.0.08.12 [3.08.2011]  �����
			return 3
		elseif w and w:GetChildUnchecked("Icon", true) then
			return 2
		end
	elseif stateMainForm:GetChildUnchecked("Chat", false) then
		return 1 -- ��� ��� ���.��� ���
	elseif stateMainForm:GetChildUnchecked("Chat", true) then
		return 0 --- ��� ��� mainForm � ���� ���
	end
	return -1
end

local versAO = getVersionAO1()
function getVersionAO()
	return versAO
end

local sysItemQualityStyle = {
	[ITEM_QUALITY_JUNK] = "Junk", ---1
	[ITEM_QUALITY_GOODS] = "Goods", ---2
	[ITEM_QUALITY_COMMON] = "Common", ---3
	[ITEM_QUALITY_UNCOMMON] = "Uncommon", ---4 - �����
	[ITEM_QUALITY_RARE] = "Rare", --- 5 - �����
	[ITEM_QUALITY_EPIC] = "Epic", --- 6 - �����
	[ITEM_QUALITY_LEGENDARY] = "Legendary", --- 7 - �� ��
	[ITEM_QUALITY_RELIC] = "Relic" --- 8
}
function getSysItemQualityStyle(quality, isCursed)
	return sysItemQualityStyle[quality] .. (isCursed and "Cursed" or "")
end

------------------------------------------------
------------------------------------------------
--- itemLib -----------
-- ���� 4.0.01.14++

function NameFromHTML(strIn)
	--Info: addon AucEDSman:    ["name"] = "<html><t href="/Mechanics/Ships/TextFragments/Names/Crystals/Crystal_Common_Cap.txt"/> <t href="/Mechanics/Ships/TextFragments/Names/BeamCannon_Par.txt"/> <t href="/Mechanics/Ships/TextFragments/Names/BeamCannons/3.txt"/>/<t href="/Mechanics/Ships/TextFragments/Names/BeamCannons/4.txt"/> <t href="/Mechanics/Ships/TextFragments/Names/Generations/1.txt"/></html>", ---{WString}

	--LogInfo("<html>...")
	local str = FromWS(strIn) ---  ������ ������ FromWS ������� ������ � ������ ����� �������
	if "<html>" == string.sub(str, 1, 6) then
		local nameVT
		nameVT = common.CreateValuedText()
		nameVT:SetFormat(str)
		return common.ExtractWStringFromValuedText(nameVT), nameVT
	else
		return ToWS(str)
	end

end

local _avaItem, _itemLib
if avatar.GetItemInfo then _avaItem = true end
if not _avaItem and itemLib.GetItemInfo then _itemLib = true end

--old vers info: level, name, quality, dressSlot, source, itemMallType
--[[
avatar.GetItemMetaInfo( itemId ).hasMetaState - true ���� ��� ������.
avatar.GetItemMetaInfo( itemId ).isMetaEnchancer - true ���� ��� ����������, ��� ������� ��� ��� �� ������.
improvement = 0...99

ENUM_ItemSource_Quest
ENUM_ItemSource_FixedDrop
ENUM_ItemSource_WorldDrop
ENUM_ItemSource_Crafted
ENUM_ItemSource_Conjured
ENUM_ItemSource_Vendor
ENUM_ItemSource_QuestItem
]]
-- new vers itemLib.info: level, name, (quality), dressSlot, (source), (itemMallType)
--[[
itemLib.GetSource( itemId )
itemMall.GetItemType( itemId )
]]
function GetItemInfo(itemId)
	local itemInfo
	if false then
	elseif _avaItem then
		itemInfo = avatar.GetItemInfo(itemId)
	elseif _itemLib then
		--[[
  id: ObjectId (not nil) - ������������� ��������
  name: WString - �������� ��������
  description: ValuedText or nil - �������� � �������������� �������� ���������� ����������
  dressSlot: number (enum) - ���� ������ ��� ������, ���� ������� ����������: DRESS_SLOT_XXXX
  sysName: string - ����������� ������������ ����������� ��������.
  level: number (integer) - ������� ��������
  requiredLevel: number (integer) - ������� ���������, ����������� ��� ������� ��������
  requiredReputationLevel: number (enum REPUTATION_LEVEL_...) - ������ ���������, ����������� ��� ������� ��������
  isRitual: boolean - �������� �� ������� ���������� (����������, ���� ����� ������ ������ � ����� � ���������� ITEM_CONT_EQUIPMENT_RITUAL)
  debugName: string - ���� � ����� �������� �������� (���������� ����������)
  icon: TextureId - �������� � ������� �������� (�������� ������ � UI)
]]
		itemInfo = itemLib.GetItemInfo(itemId)
	end

	--exObj2("itemInfo", itemInfo)
	--- �������� ����� ������ �������� ���� ��� - ���� ������ ��� ��������
	local name, nameVT = NameFromHTML(itemInfo.name)
	--LogInfo(name, ":",nameVT)
	itemInfo.name = name
	itemInfo.nameVT = nameVT

	--- ��� � ������ �������� � ����. - ����� ������ ��������� ������� � ��������� ������ � ������ ���������
	local metaInfo = avatar.GetItemMetaInfo(itemId)
	itemInfo.nameOrig = itemInfo.name
	itemInfo.name = string.format("%02d ", itemInfo.level or 0)
		.. FromWS(itemInfo.name)
		.. " " .. (itemLibGetQuality(itemId, itemInfo) or "X")
		.. "-" .. (metaInfo and ((metaInfo.hasMetaState and "1" or "0")
			.. (metaInfo.isMetaEnchancer and "1" or "0")
			--..(metaInfo.improvement)
			)
			or "")
	-- ���� ��� ������ ���	.. "-".. (itemLibGetSource( itemId, itemInfo) or "??")

	itemInfo.name = ToWS(itemInfo.name)
	--LogInfo(itemInfo.name)

	return itemInfo
end

function itemLibGetSource(itemId, itemInfo)
	local info
	if false then
	elseif _avaItem then
		info = itemInfo or avatar.GetItemInfo(itemId)
		return info.sourse --- before 4.0.01
	elseif _itemLib then
		return itemLib.GetSource(itemId)
	end

end

function itemLibGetStackInfo(itemId, itemInfo)

	local info
	if false then
	elseif _avaItem then
		info = itemInfo or avatar.GetItemInfo(itemId)
		return { count = info.stackCount, limit = info.stackLimit } --- before 4.0.01
	elseif _itemLib then
		return itemLib.GetStackInfo(itemId)
	end

end

function itemMallGetItemType(itemId, itemInfo)
	local info
	if false then
	elseif _avaItem then
		info = itemInfo or avatar.GetItemInfo(itemId)
		return info.itemMallType --- before 4.0.01
	elseif itemMall.GetItemType then
		return itemMall.GetItemType(itemId)
	end

end

function itemLibGetQuality(itemId, itemInfo)
	local info
	if false then
	elseif _avaItem then
		info = itemInfo or avatar.GetItemInfo(itemId)
		return info.quality --- before 4.0.01
	elseif _itemLib then
		return itemLib.GetQuality(itemId).quality
	end

end

function itemLibIsCursed(itemId, itemInfo)
	local info
	if false then
	elseif _avaItem then
		info = itemInfo or avatar.GetItemInfo(itemId)
		return info.isCursed --- before 4.0.01
	elseif _itemLib then
		return itemLib.IsCursed(itemId)
	end

end

function itemLibGetPriceInfo(itemId, itemInfo)
	local info
	if false then
	elseif _avaItem then
		info = itemInfo or avatar.GetItemInfo(itemId)
		return info --- before 4.0.01
	elseif _itemLib then
		return itemLib.GetPriceInfo(itemId)
	end

end

function itemLibGetBindingInfo(itemId, itemInfo)

	local info
	if false then
	elseif _avaItem then
		info = itemInfo or avatar.GetItemInfo(itemId)
		return info --- before 4.0.01
	elseif _itemLib then
		return itemLib.GetBindingInfo(itemId)
	end

end

function itemLibGetOverallStackCount(itemId, itemInfo)

	local info
	if false then
	elseif _avaItem then
		info = itemInfo or avatar.GetItemInfo(itemId)
		return info.overallStackCount --- before 4.0.01
	elseif _itemLib then
		return itemLib.GetOverallStackCount(itemId)
	end

end

function itemLibIsQuestOperator(itemId, itemInfo)

	local info
	if false then
	elseif _avaItem then
		info = itemInfo or avatar.GetItemInfo(itemId)
		return info.isQuestOperator --- before 4.0.01
	elseif _itemLib then
		return itemLib.IsQuestOperator(itemId)
	end

end

function itemLibIsQuestRelated(itemId, itemInfo)

	local info
	if false then
	elseif _avaItem then
		info = itemInfo or avatar.GetItemInfo(itemId)
		return info.isQuestRelated --- before 4.0.01
	elseif _itemLib then
		return itemLib.IsQuestRelated(itemId)
	end

end

function itemLibGetTemporaryInfo(itemId, itemInfo)

	local info
	if false then
	elseif _avaItem then
		info = itemInfo or avatar.GetItemInfo(itemId)
		return info.temporaryInfo --- before 4.0.01
	elseif _itemLib then
		return itemLib.GetTemporaryInfo(itemId)
	end

end

--ItemId - id ������� �������� (ResourceId); ����� ���������� � ������� ItemId (��. :IsEqual) � �������� ���������� � ��� (��. avatar.GetItemResourceInfo( itemResourceId ))
--avatar.GetItemResourceId( itemId )
function GetItemResourceId(itemId)
	return avatar.GetItemResourceId(itemId)
end

----------------------- ��������� �������� ���� ����� ��� ��� �������� ������ ����
-------------------------------------------------------------------------------------
--- ������ ��� ���� � ������� ���� ��������� � ��� ������ ������� ����� �� ���� ������� ������
local wtEFFS = {} ---funcs = {}, deals = {} --- ������ ���� ������ � �������� ��� �������� - � � ����� ����� � �����
--[[
ET_MOVE - ������ ��������� Placement �������
ET_FADE - ������ ��������� ������������ �������/������
ET_RESIZE - ������ ��������� �������� �������
ET_TEXTURE_ROTATION - ������ ��������� ���� �������� FrontLayer �������
ET_TEXT_SCALE - ������ ��������� ������� ������, ������ ��� TextView
]]
function wtEFFSfuncAdd(wt, func)
	local ID = GetInstanceId(wt)
	if not wtEFFS[ID] then wtEFFS[ID] = { wt = wt, effs = {}, funcs = {} } end
	table.insert(wtEFFS[ID].funcs, func)
end

function wtEFFSfuncClear(wt)
	local ID = GetInstanceId(wt)
	if not wtEFFS[ID] then return end
	wtEFFS[ID].funcs = {}
end

--local registeregIntegers = {} --- ����� �� ����� 0 -
local function wtDoEffect(wt, type)
	local ID = GetInstanceId(wt)
	--	--- �������� ��� ���������� ������� - ����� ����� �� ������ �������� ������� ���������
	--	--- � �� ������ �� ������?
	--	registeregIntegers[ common.RequestIntegerByInstanceId( ID ) ] = 1
	if not wtEFFS[ID] then wtEFFS[ID] = { wt = wt, effs = {}, funcs = {} } end
	wtEFFS[ID].effs[type] = 1
	--exObj2( "wtEFFS", wtEFFS )
end

function wtIsInEffect(wt, type)
	local ID = GetInstanceId(wt)
	local wtTab = wtEFFS[ID]
	return wtTab and wtTab.effs[type]
end

local function wtFinishEffect(wt, type)
	if false then
	elseif type == ET_FADE then wt:FinishFadeEffect()
	elseif type == ET_MOVE then wt:FinishMoveEffect()
	elseif type == ET_RESIZE then wt:FinishResizeEffect()
	elseif type == ET_TEXTURE_ROTATION then wt:FinishRotationEffect()
	elseif type == ET_TEXT_SCALE then wt:FinishTextScaleEffect()
	end
end

function wtPlayFadeEffect(wt, fromP, toP, time1, algor)
	wtDoEffect(wt, ET_FADE)
	wt:PlayFadeEffect(fromP, toP, time1, algor)
end

function wtPlayMoveEffect(wt, fromP, toP, time1, algor)
	wtDoEffect(wt, ET_MOVE)
	wt:PlayMoveEffect(fromP, toP, time1, algor)
end

function wtPlayResizeEffect(wt, fromP, toP, time1, algor)
	wtDoEffect(wt, ET_RESIZE)
	wt:PlayResizeEffect(fromP, toP, time1, algor)
end

function wtPlayRotationEffect(wt, fromP, toP, time1, algor)
	wtDoEffect(wt, ET_TEXTURE_ROTATION)
	wt:PlayRotationEffect(fromP, toP, time1, algor)
end

function wtPlayTextScaleEffect(wt, fromP, toP, time1, algor)
	wtDoEffect(wt, ET_TEXT_SCALE)
	wt:PlayTextScaleEffect(fromP, toP, time1, algor)
end

--- ���� ������ 1 ������ � �����
local function getChildsEFFs(wt)
	local ID = GetInstanceId(wt)
	local wtTab = wtEFFS[ID]
	if wtTab and GetTableSize(wtTab.effs) ~= 0 then
		return ID, wtTab
	end

	for i, wCh in pairs(wt:GetNamedChildren()) do
		ID, wtTab = getChildsEFFs(wCh)
		if wtTab then
			--- ���� ���� ������ � �����
			return ID, wtTab
		end
	end
end

local resumeDestroy = {}
local function DestroyWidget0(wt)
	--- ������ ��� � ������ ���� �� � ����������� �� �������
	skinnedWidgets[GetInstanceId(wt)] = nil
	wt:DestroyWidget()
end

function wtDestroy(wt)
	--- ��� ���� ��������� - ��� �� ��� ����� ������� �������� �������� ��� ������� �� �������
	--- � ������� ������ ���� ��� �����

	---� ��� �� ���� �� ���� ����� ���������!!!!!!!!!!!!!
	--- � ������� �� ���� ���������
	local childID, childTab = getChildsEFFs(wt)
	if childID then
		--- ����� ������� ������� � ��������
		--- ������������� ������� ��� � ����
		childTab.funcs = {}
		for type in pairs(childTab.effs) do
			wtFinishEffect(childTab.wt, type)
			childTab.effs[type] = nil
		end
		--- ��������� ����� ����� � ���������
		wtDestroy(wt)
		return
	end

	--- ��� �������� �� � ���� �� � ����� - ������� �����
	if not childID then
		--LogInfo("DestroyWidget  "..wt:GetName())
		--LogToChat("DestroyWidget  "..wt:GetName())

		--- � ��� ����� ����� � ��������� ��������� �� ������� ��� �����
		--- ������ �������
		ToDo_Add1(2, DestroyWidget0, wt)
	else
		--- ����� ������ ������� � ����� ������� � ����� �������
		--LogInfo("DestroyWidget --- resume  "..wt:GetName())
		--LogToChat("DestroyWidget --- resume  "..wt:GetName())
		--wt:Show( false )
		LogToChat("���� �� ����� ��������� ����")

		resumeDestroy[childID] = wt

	end
end

onEVENT_EFFECT_FINISHED_lib = function(pars)
	local wId = GetInstanceId(pars.wtOwner)
	if not wId then return end

	--LogInfo("onEVENT_EFFECT_FINISHED_lib")
	local type = pars.effectType
	local wtTab = wtEFFS[wId]

	if not wtTab then return end
	--- �������� �� ������ ����������
	wtTab.effs[type] = nil

	--- ���� ���� ������� ����� �������� �� ��������� ��� ��� �������
	local wtResume = resumeDestroy[wId]
	if wtResume then
		resumeDestroy[wId] = nil
		wtDestroy(wtResume)
		return
	end

	--- ��� ��������������� ������ ����� ������������������ ������� �����������
	local func = table.remove(wtTab.funcs, 1)
	if func then func(pars.wtOwner)
	else
	end

end
----------------------------------------------------------

function GetInstanceId(wt)
	return wt:IsValid() and wt:GetInstanceId() or wt:Show(false) and nil
end

function makeFontFormatFromVal(vN, val)
	if not val then return ""
	elseif type(val) == "table" then
		return vN .. "='0x"
			.. string.format("%02X", (val.a or 1) * 255) --- color="0xFFFF771F"
			.. string.format("%02X", (val.r or 1) * 255)
			.. string.format("%02X", (val.g or 1) * 255)
			.. string.format("%02X", (val.b or 1) * 255)
			.. "' "
	end
	return vN .. "='" .. val .. "' "
end

--"fontsize", "fontname", "outline", "shadow", "alignx", "aligny", "color", "shadowcolor", "outlinecolor"
function makeFontFormatFromTab(tab, rName)
	if not tab then return end

	local str, v, vN = "<html "

	for key, val in pairs(tab) do
		str = str .. makeFontFormatFromVal(key, val)
	end
	str = str .. " ><r name='" .. (rName or "value") .. "'/></html>"
	return str
end

function SizeInside(w, wt, dxy)
	local p = wt:GetPlacementPlain()
	local pp = w:GetPlacementPlain()
	pp.sizeX = p.sizeX + 2 * dxy
	pp.sizeY = p.sizeY + 2 * dxy
	wtSetPlace(w, pp)
end

function PlaceInside(w, wt, dxy)
	local p = wt:GetPlacementPlain()
	local pp = Clone(p)
	pp.sizeX = p.sizeX + 2 * dxy
	pp.sizeY = p.sizeY + 2 * dxy
	pp.posX = p.posX - dxy
	pp.posY = p.posY - dxy
	w:SetPlacementPlain(pp)
	w:AddChild(wt)
	--wtSetPlace(wt, { posX = dxy, posY = dxy, highPosX = dxy, highPosY = dxy, alignX = 3, slignY = 3})
	wtSetPlace(wt, { posX = 0, posY = 0, highPosX = 0, highPosY = 0, alignX = 2, slignY = 2 })
end

function NormalizePlacement(wt, PlaceIn)
	local Place = PlaceIn or wt:GetPlacementPlain()
	local wtParent = wt:GetParent()
	--exObj2("Place", Place )
	local sizeXparent, sizeYparent = wtGetSizeX(wtParent), wtGetSizeY(wtParent)
	--LogInfo("sizeXparent, sizeYparent", sizeXparent,", ", sizeYparent)
	local sizeX = wtGetSizeX(wt)
	local sizeY = wtGetSizeY(wt)
	--LogInfo("sizeX, sizeY", sizeX,", ", sizeY)

	if Place.posX + sizeX > sizeXparent then
		Place.posX = sizeXparent - sizeX
	end
	if Place.posY + sizeY > sizeYparent then
		Place.posY = sizeYparent - sizeY
	end
	if Place.posX < 0 then Place.posX = 0 end
	if Place.posY < 0 then Place.posY = 0 end

	wt:SetPlacementPlain(Place)
	return Place
end
