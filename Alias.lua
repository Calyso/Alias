-- ==========================================
-- Alias Add-on Core Logic
-- ==========================================

local addonName = "Alias"
AliasDB = AliasDB or {}

-- Forward declarations
local RegisterAlias
local UnregisterAlias
local UpdateMinimapPosition

-- Initialize database and load existing aliases natively
local EventFrame = CreateFrame("Frame")
EventFrame:RegisterEvent("ADDON_LOADED")
EventFrame:SetScript("OnEvent", function(self, event, loadedAddon)
    if loadedAddon == addonName then
        AliasDB = AliasDB or {}
        
        -- Set default minimap position if it doesn't exist
        AliasDB.minimapPos = AliasDB.minimapPos or (math.pi / 4) -- Default to ~45 degrees (top right)
        UpdateMinimapPosition(AliasDB.minimapPos)

        local tempDB = {}
        for alias, cmd in pairs(AliasDB) do
            if alias ~= "minimapPos" then -- Ignore the minimap variable
                local lowerAlias = string.lower(alias)
                tempDB[lowerAlias] = cmd
                RegisterAlias(lowerAlias, cmd) 
            end
        end
        
        -- Restore the minimap setting to the DB before saving
        tempDB.minimapPos = AliasDB.minimapPos
        AliasDB = tempDB
        
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

function RegisterAlias(alias, targetCommand)
    local cleanAlias = string.upper(string.sub(alias, 2))
    local cmdID = "CUSTOM_ALIAS_" .. cleanAlias
    
    _G["SLASH_" .. cmdID .. "1"] = alias
    
    SlashCmdList[cmdID] = function(msg)
        local executeString = targetCommand
        if msg and msg ~= "" then
            executeString = executeString .. " " .. msg
        end
        local editBox = ChatEdit_ChooseBoxForSend()
        editBox:SetText(executeString)
        ChatEdit_SendText(editBox)
    end
    
    hash_SlashCmdList[string.upper(alias)] = cmdID
end

function UnregisterAlias(alias)
    local cleanAlias = string.upper(string.sub(alias, 2))
    local cmdID = "CUSTOM_ALIAS_" .. cleanAlias
    
    _G["SLASH_" .. cmdID .. "1"] = nil
    SlashCmdList[cmdID] = nil
    hash_SlashCmdList[string.upper(alias)] = nil
end

-- ==========================================
-- User Interface (Alias Manager)
-- ==========================================

local UI = CreateFrame("Frame", "AliasManagerFrame", UIParent, "BasicFrameTemplateWithInset")
UI:SetSize(480, 450) 
UI:SetPoint("CENTER")
UI:Hide()
tinsert(UISpecialFrames, "AliasManagerFrame")

UI.title = UI:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
UI.title:SetPoint("CENTER", UI.TitleBg, "CENTER", 0, 0)
UI.title:SetText("Alias Manager")

-- Window Dragging Functionality
UI:SetMovable(true)
UI:SetClampedToScreen(true) 
local dragFrame = CreateFrame("Frame", nil, UI)
dragFrame:SetPoint("TOPLEFT", UI, "TOPLEFT", 0, 0)
dragFrame:SetPoint("BOTTOMRIGHT", UI, "TOPRIGHT", 0, -30)
dragFrame:EnableMouse(true)
dragFrame:RegisterForDrag("LeftButton")
dragFrame:SetScript("OnDragStart", function() UI:StartMoving() end)
dragFrame:SetScript("OnDragStop", function() UI:StopMovingOrSizing() end)

-- Inputs
local aliasInput = CreateFrame("EditBox", nil, UI, "InputBoxTemplate")
aliasInput:SetSize(120, 30)
aliasInput:SetPoint("TOPLEFT", UI, "TOPLEFT", 20, -40)
aliasInput:SetAutoFocus(false)
local aliasLabel = UI:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
aliasLabel:SetPoint("BOTTOMLEFT", aliasInput, "TOPLEFT", 0, 0)
aliasLabel:SetText("Alias (e.g., /hi)")

local cmdInput = CreateFrame("EditBox", nil, UI, "InputBoxTemplate")
cmdInput:SetSize(220, 30) 
cmdInput:SetPoint("LEFT", aliasInput, "RIGHT", 15, 0)
cmdInput:SetAutoFocus(false)
local cmdLabel = UI:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
cmdLabel:SetPoint("BOTTOMLEFT", cmdInput, "TOPLEFT", 0, 0)
cmdLabel:SetText("Command (e.g., /hello)")

local scrollFrame = CreateFrame("ScrollFrame", nil, UI, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", UI, "TOPLEFT", 15, -100)
scrollFrame:SetPoint("BOTTOMRIGHT", UI, "BOTTOMRIGHT", -35, 15)

local contentFrame = CreateFrame("Frame", nil, scrollFrame)
contentFrame:SetSize(430, 400) 
scrollFrame:SetScrollChild(contentFrame)

local aliasRows = {}

local function UpdateAliasList()
    for _, row in ipairs(aliasRows) do row:Hide() end

    local yOffset = 0
    local rowIndex = 1

    for alias, command in pairs(AliasDB) do
        if alias ~= "minimapPos" then
            local row = aliasRows[rowIndex]
            if not row then
                row = CreateFrame("Frame", nil, contentFrame)
                row:SetSize(430, 40) 
                
                row.aliasText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                row.aliasText:SetPoint("LEFT", row, "LEFT", 5, 0)
                row.aliasText:SetWidth(80) 
                row.aliasText:SetJustifyH("LEFT")
                
                row.deleteBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                row.deleteBtn:SetSize(60, 22)
                row.deleteBtn:SetPoint("RIGHT", row, "RIGHT", -5, 0)
                row.deleteBtn:SetText("Remove")

                row.cmdText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                row.cmdText:SetPoint("LEFT", row.aliasText, "RIGHT", 10, 0)
                row.cmdText:SetPoint("RIGHT", row.deleteBtn, "LEFT", -15, 0)
                row.cmdText:SetJustifyH("LEFT")
                row.cmdText:SetJustifyV("MIDDLE")
                row.cmdText:SetWordWrap(true) 
                row.cmdText:SetMaxLines(2) 
                
                aliasRows[rowIndex] = row
            end

            row.aliasText:SetText("|cFFFFFF00" .. alias .. "|r")
            row.cmdText:SetText(command)
            
            row.deleteBtn:SetScript("OnClick", function()
                UnregisterAlias(alias)
                AliasDB[alias] = nil
                print("|cFF00FF00Alias removed:|r", alias)
                UpdateAliasList()
            end)

            row:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, yOffset)
            row:Show()

            yOffset = yOffset - 45 
            rowIndex = rowIndex + 1
        end
    end
end

local addBtn = CreateFrame("Button", nil, UI, "UIPanelButtonTemplate")
addBtn:SetSize(60, 25)
addBtn:SetPoint("LEFT", cmdInput, "RIGHT", 10, 0)
addBtn:SetText("Add")
addBtn:SetScript("OnClick", function()
    local a = aliasInput:GetText()
    local c = cmdInput:GetText()
    
    if a ~= "" and c ~= "" then
        if string.sub(a, 1, 1) ~= "/" then a = "/" .. a end
        if string.sub(c, 1, 1) ~= "/" then c = "/" .. c end
        a = string.lower(a)
        
        AliasDB[a] = c
        RegisterAlias(a, c) 
        
        aliasInput:SetText("")
        cmdInput:SetText("")
        aliasInput:ClearFocus()
        cmdInput:ClearFocus()
        print("|cFF00FF00Alias added:|r", a, "->", c)
        UpdateAliasList()
    else
        print("|cFFFF0000Error:|r Both fields must be filled.")
    end
end)

UI:SetScript("OnShow", UpdateAliasList)

-- ==========================================
-- Minimap Button
-- ==========================================

local minimapBtn = CreateFrame("Button", "AliasMinimapButton", Minimap)
minimapBtn:SetSize(32, 32)
minimapBtn:SetFrameLevel(8)
minimapBtn:RegisterForDrag("RightButton", "LeftButton")

local bg = minimapBtn:CreateTexture(nil, "BACKGROUND")
bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
bg:SetSize(25, 25)
bg:SetPoint("CENTER")

-- Use a standard scroll icon to represent code/text
local icon = minimapBtn:CreateTexture(nil, "ARTWORK")
icon:SetTexture("Interface\\Icons\\INV_Scroll_03") 
icon:SetSize(21, 21)
icon:SetPoint("CENTER")

local border = minimapBtn:CreateTexture(nil, "OVERLAY")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
border:SetSize(54, 54)
border:SetPoint("TOPLEFT", 11, -11)

minimapBtn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-Button-Highlight")

-- Math to place the button on the minimap ring
function UpdateMinimapPosition(angle)
    local radius = 80
    local x = math.cos(angle) * radius
    local y = math.sin(angle) * radius
    minimapBtn:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

-- Drag to move around the minimap
minimapBtn:SetScript("OnDragStart", function()
    minimapBtn:LockHighlight()
    minimapBtn:SetScript("OnUpdate", function()
        local mx, my = Minimap:GetCenter()
        local px, py = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        px, py = px / scale, py / scale
        
        local angle = math.atan2(py - my, px - mx)
        AliasDB.minimapPos = angle
        UpdateMinimapPosition(angle)
    end)
end)

minimapBtn:SetScript("OnDragStop", function()
    minimapBtn:SetScript("OnUpdate", nil)
    minimapBtn:UnlockHighlight()
end)

-- Click to toggle UI
minimapBtn:SetScript("OnClick", function(self, button)
    if button == "LeftButton" then
        if UI:IsShown() then
            UI:Hide()
        else
            UI:Show()
        end
    end
end)

-- Tooltip text
minimapBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Alias")
    GameTooltip:AddLine("Left-click to open Alias Manager.", 1, 1, 1)
    GameTooltip:AddLine("Drag to move this button.", 1, 1, 1)
    GameTooltip:Show()
end)

minimapBtn:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

-- ==========================================
-- Core Menu Command
-- ==========================================

SLASH_ALIASMANAGER1 = "/alias"
SlashCmdList["ALIASMANAGER"] = function()
    if UI:IsShown() then
        UI:Hide()
    else
        UI:Show()
    end
end