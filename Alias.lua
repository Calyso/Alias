-- ==========================================
-- Alias Add-on 
-- Version: 1.3
-- ==========================================

local addonName = "Alias"
AliasDB = AliasDB or {}

-- Forward declarations
local RegisterAlias, UnregisterAlias, UpdateMinimapPosition

-- ==========================================
-- Minimap Button (Optimized)
-- ==========================================

local minimapBtn = CreateFrame("Button", "AliasMinimapButton", Minimap)
minimapBtn:SetSize(31, 31)
minimapBtn:SetFrameLevel(8)
minimapBtn:RegisterForDrag("RightButton", "LeftButton")

local bg = minimapBtn:CreateTexture(nil, "BACKGROUND")
bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
bg:SetSize(25, 25)
bg:SetPoint("TOPLEFT", 2, -4)

local icon = minimapBtn:CreateTexture(nil, "ARTWORK")
icon:SetTexture("Interface\\Icons\\ability_rogue_disguise") 
icon:SetSize(20, 20)
icon:SetPoint("TOPLEFT", 7, -6)
icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)

local border = minimapBtn:CreateTexture(nil, "OVERLAY")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
border:SetSize(54, 54)
border:SetPoint("TOPLEFT", 0, 0)

minimapBtn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-Button-Highlight")

function UpdateMinimapPosition(angle)
    local radius = 80
    local x = math.cos(angle) * radius
    local y = math.sin(angle) * radius
    minimapBtn:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

minimapBtn:SetScript("OnDragStart", function(self)
    self:LockHighlight()
    self:SetScript("OnUpdate", function()
        local mx, my = Minimap:GetCenter()
        local px, py = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        local angle = math.atan2((py / scale) - my, (px / scale) - mx)
        
        AliasDB.minimapPos = angle
        UpdateMinimapPosition(angle)
    end)
end)

minimapBtn:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
    self:UnlockHighlight()
end)

-- ==========================================
-- User Interface (Alias)
-- ==========================================

local UI = CreateFrame("Frame", "AliasFrame", UIParent, "BasicFrameTemplateWithInset")
UI:SetSize(480, 450) 
UI:SetPoint("CENTER")
UI:Hide()
tinsert(UISpecialFrames, "AliasFrame")

UI.title = UI:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
UI.title:SetPoint("CENTER", UI.TitleBg, "CENTER", 0, 0)
UI.title:SetText("Alias")

UI:SetMovable(true)
UI:SetClampedToScreen(true) 
local dragFrame = CreateFrame("Frame", nil, UI)
dragFrame:SetPoint("TOPLEFT", UI, "TOPLEFT", 0, 0)
dragFrame:SetPoint("BOTTOMRIGHT", UI, "TOPRIGHT", 0, -30)
dragFrame:EnableMouse(true)
dragFrame:RegisterForDrag("LeftButton")
dragFrame:SetScript("OnDragStart", function() UI:StartMoving() end)
dragFrame:SetScript("OnDragStop", function() UI:StopMovingOrSizing() end)

local aliasInput = CreateFrame("EditBox", nil, UI, "InputBoxTemplate")
aliasInput:SetSize(120, 30)
aliasInput:SetPoint("TOPLEFT", UI, "TOPLEFT", 20, -40)
aliasInput:SetAutoFocus(false)
local aliasLabel = UI:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
aliasLabel:SetPoint("BOTTOMLEFT", aliasInput, "TOPLEFT", 0, 0)
aliasLabel:SetText("Alias (ie, /ghi)")

local cmdInput = CreateFrame("EditBox", nil, UI, "InputBoxTemplate")
cmdInput:SetSize(180, 30) 
cmdInput:SetPoint("LEFT", aliasInput, "RIGHT", 15, 0)
cmdInput:SetAutoFocus(false)
local cmdLabel = UI:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
cmdLabel:SetPoint("BOTTOMLEFT", cmdInput, "TOPLEFT", 0, 0)
cmdLabel:SetText("Command (ie, /g hello guild!)")

local addBtn = CreateFrame("Button", nil, UI, "UIPanelButtonTemplate")
addBtn:SetSize(60, 25)
addBtn:SetPoint("LEFT", cmdInput, "RIGHT", 10, 0)
addBtn:SetText("Add")

local minimapToggle = CreateFrame("CheckButton", nil, UI, "UICheckButtonTemplate")
minimapToggle:SetSize(26, 26)
minimapToggle:SetPoint("LEFT", addBtn, "RIGHT", 10, 0)
local toggleLabel = UI:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
toggleLabel:SetPoint("BOTTOMLEFT", minimapToggle, "TOPLEFT", 0, 0)
toggleLabel:SetText("Minimap")

minimapToggle:SetScript("OnClick", function(self)
    AliasDB.showMinimap = self:GetChecked()
    if AliasDB.showMinimap then minimapBtn:Show() else minimapBtn:Hide() end
end)

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
        UI:GetScript("OnShow")(UI) 
    else
        print("|cFFFF0000Error:|r Both fields must be filled.")
    end
end)

local scrollFrame = CreateFrame("ScrollFrame", nil, UI, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", UI, "TOPLEFT", 15, -100)
scrollFrame:SetPoint("BOTTOMRIGHT", UI, "BOTTOMRIGHT", -35, 15)

local contentFrame = CreateFrame("Frame", nil, scrollFrame)
contentFrame:SetSize(430, 400) 
scrollFrame:SetScrollChild(contentFrame)

local aliasRows = {}

UI:SetScript("OnShow", function()
    for _, row in ipairs(aliasRows) do row:Hide() end
    local yOffset = 0
    local rowIndex = 1
    for alias, command in pairs(AliasDB) do
        if alias ~= "minimapPos" and alias ~= "showMinimap" then
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
                UI:GetScript("OnShow")(UI) 
            end)
            row:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, yOffset)
            row:Show()
            yOffset = yOffset - 45 
            rowIndex = rowIndex + 1
        end
    end
end)

minimapBtn:SetScript("OnClick", function(self, button)
    if button == "LeftButton" then if UI:IsShown() then UI:Hide() else UI:Show() end end
end)

minimapBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Alias")
    GameTooltip:AddLine("Left-click to open Alias Window.", 1, 1, 1)
    GameTooltip:AddLine("Drag to move this button.", 1, 1, 1)
    GameTooltip:Show()
end)

minimapBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

local EventFrame = CreateFrame("Frame")
EventFrame:RegisterEvent("ADDON_LOADED")
EventFrame:SetScript("OnEvent", function(self, event, loadedAddon)
    if loadedAddon == addonName then
        AliasDB = AliasDB or {}
        AliasDB.minimapPos = AliasDB.minimapPos or (math.pi / 4) 
        if AliasDB.showMinimap == nil then AliasDB.showMinimap = true end
        UpdateMinimapPosition(AliasDB.minimapPos)
        if AliasDB.showMinimap then minimapBtn:Show() else minimapBtn:Hide() end
        minimapToggle:SetChecked(AliasDB.showMinimap)
        local tempDB = {}
        for alias, cmd in pairs(AliasDB) do
            if alias ~= "minimapPos" and alias ~= "showMinimap" then 
                local lowerAlias = string.lower(alias)
                tempDB[lowerAlias] = cmd
                RegisterAlias(lowerAlias, cmd) 
            end
        end
        tempDB.minimapPos = AliasDB.minimapPos
        tempDB.showMinimap = AliasDB.showMinimap
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
        print("|cFF00CCFFAlias Used:|r " .. alias .. " > " .. targetCommand)
        if msg and msg ~= "" then executeString = executeString .. " " .. msg end
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

SLASH_ALIASMANAGER1 = "/alias"
SlashCmdList["ALIASMANAGER"] = function()
    if UI:IsShown() then UI:Hide() else UI:Show() end
end