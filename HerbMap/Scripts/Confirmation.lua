local wtConfirmation
local wtConfirmationTitle

local wtButtons
local wtRemoveButton

local AlertMinWidth
local callback

function CreateConfirmationAlert()
    wtConfirmationTitle = Label { text = "", fontSize = 13 }

    wtRemoveButton = Button {
        title = userMods.ToWString("-"),
        align = "Center", fontSize = 13, style = "ReputationHostility",
        sizeY = 20,
        onClicked = function()
            if callback then
                callback()
                callback = nil
            end
            wtConfirmation:Show(false)
        end
    }

    wtButtons = HStack {
        spacing = 2,
        gravity = WIDGET_ALIGN_LOW,
        children = {
            Button {
                title = userMods.ToWString(L10N.Action.Cancel),
                align = "Center", fontSize = 13,
                sizeY = 20,
                onClicked = function()
                    wtConfirmation:Show(false)
                end
            },
            wtRemoveButton
        }
    }
    AlertMinWidth = wtButtons:GetPlacementPlain().sizeX

    wtConfirmation = Frame "HM:Confirmation" {
        edges = { all = 12 },
        content = VStack {
            spacing = 2,
            gravity = WIDGET_ALIGN_CENTER,
            children = {
                wtConfirmationTitle,
                wtButtons
            }
        }
    }
    wtConfirmation:Show(false)
    return wtConfirmation
end

function ShowConfirmation(title, removeButtonTitle, removeCallback)
    wtConfirmationTitle:SetVal("Text", title)
    wtRemoveButton:SetVal("Text", userMods.ToWString(removeButtonTitle))
    callback = removeCallback

    -- update buttons size
    local labelWidth = wtConfirmationTitle:GetPlacementPlain().sizeX
    local width = labelWidth > AlertMinWidth and labelWidth or AlertMinWidth
    local buttonWidth = (width - 2) / 2
    SetSize(wtButtons, width)
    SetSize(wtButtons:GetParent(), width)
    local x = 0
    for _, btn in pairs(wtButtons:GetNamedChildren()) do
        PosXY(btn, x, buttonWidth)
        x = x + buttonWidth + 2
    end

    wtConfirmation:Show(true)
end