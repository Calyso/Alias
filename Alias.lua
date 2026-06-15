-- ==========================================
-- Alias Add-on Core Logic
-- ==========================================

local addonName = "Alias"
AliasDB = AliasDB or {}

-- Forward declarations
local RegisterAlias
local UnregisterAlias

-- Initialize database and load existing aliases natively
local EventFrame = CreateFrame("Frame")
EventFrame:RegisterEvent("ADDON_LOADED")
EventFrame:SetScript("OnEvent", function(self, event, loadedAddon)
    if loadedAddon == addonName then
        AliasDB = AliasDB or {}
        
        local tempDB = {}
        for alias, cmd in pairs(AliasDB) do
            local lowerAlias = string.lower(alias)
            tempDB[lowerAlias] = cmd
            RegisterAlias(lowerAlias, cmd) -- Load into WoW's native system
        end
        AliasDB = tempDB
        
        self:UnregisterEvent("ADDON_LOADED")
    end
end)

-- The "Blizzard Way" of registering a command dynamically
function RegisterAlias(alias, targetCommand)
    -- Strip the slash and create a unique ID for the game engine
    local cleanAlias = string.upper(string.sub(alias, 2))
    local cmdID = "CUSTOM_ALIAS_" .. cleanAlias
    
    -- 1. Create the global slash variable 
    _G["SLASH_" .. cmdID .. "1"] = alias
    
    -- 2. Define what happens when the command is triggered
    SlashCmdList[cmdID] = function(msg)
        local executeString = targetCommand
        
        -- If the user typed extra words (e.g., "/ty everyone"), pass them through
        if msg and msg ~= "" then
            executeString = executeString .. " " .. msg
        end
        
        -- 3. Execute securely by feeding it back to the hidden chat system
        local editBox = ChatEdit_ChooseBoxForSend()
        editBox:SetText(executeString)
        ChatEdit_SendText(editBox)
    end
    
    -- 4. Inject directly into WoW's runtime dictionary
    -- This is the secret sauce that makes it work immediately without a /reload
    hash_SlashCmdList[string.upper(alias)] = cmdID
end

function UnregisterAlias(alias)
    local cleanAlias = string.upper(string.sub(alias, 2))
    local cmdID = "CUSTOM_ALIAS_" .. cleanAlias
    
    -- Wipe it from WoW's memory
    _G["SLASH_" .. cmdID .. "1"] = nil
    SlashCmdList[cmdID] = nil
    hash_SlashCmdList[string.upper(alias)] = nil
end

-- ==========================================
-- User Interface (Alias Manager)
-- ==========================================

local UI = CreateFrame("Frame", "AliasManagerFrame", UIParent, "BasicFrameTemplateWithInset")
UI:SetSize(400, 450)
UI:SetPoint("CENTER")
UI:Hide()
tinsert(UISpecialFrames, "AliasManagerFrame")

UI.title = UI:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
UI.title:SetPoint("CENTER", UI.TitleBg, "CENTER", 0, 0)
UI.title:SetText("Alias Manager")

local aliasInput = CreateFrame("EditBox", nil, UI, "InputBoxTemplate")
aliasInput:SetSize(120, 30)
aliasInput:SetPoint("TOPLEFT", UI, "TOPLEFT", 20, -40)
aliasInput:SetAutoFocus(false)
local aliasLabel = UI:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
aliasLabel:SetPoint("BOTTOMLEFT", aliasInput, "TOPLEFT", 0, 0)
aliasLabel:SetText("Alias (e.g., /hi)")

local cmdInput = CreateFrame("EditBox", nil, UI, "InputBoxTemplate")
cmdInput:SetSize(160, 30)
cmdInput:SetPoint("LEFT", aliasInput, "RIGHT", 15, 0)
cmdInput:SetAutoFocus(false)
local cmdLabel = UI:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
cmdLabel:SetPoint("BOTTOMLEFT", cmdInput, "TOPLEFT", 0, 0)
cmdLabel:SetText("Command (e.g., /hello)")

local scrollFrame = CreateFrame("ScrollFrame", nil, UI, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", UI, "TOPLEFT", 15, -100)
scrollFrame:SetPoint("BOTTOMRIGHT", UI, "BOTTOMRIGHT", -35, 15)

local contentFrame = CreateFrame("Frame", nil, scrollFrame)
contentFrame:SetSize(350, 400)
scrollFrame:SetScrollChild(contentFrame)

local aliasRows = {}

local function UpdateAliasList()
    for _, row in ipairs(aliasRows) do row:Hide() end

    local yOffset = 0
    local rowIndex = 1

    for alias, command in pairs(AliasDB) do
        local row = aliasRows[rowIndex]
        if not row then
            row = CreateFrame("Frame", nil, contentFrame)
            row:SetSize(350, 30)
            
            row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            row.text:SetPoint("LEFT", row, "LEFT", 5, 0)
            
            row.deleteBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            row.deleteBtn:SetSize(60, 22)
            row.deleteBtn:SetPoint("RIGHT", row, "RIGHT", -5, 0)
            row.deleteBtn:SetText("Remove")
            
            aliasRows[rowIndex] = row
        end

        row.text:SetText("|cFFFFFF00" .. alias .. "|r  ->  " .. command)
        row.deleteBtn:SetScript("OnClick", function()
            UnregisterAlias(alias) -- Dynamically unregister from the game
            AliasDB[alias] = nil
            print("|cFF00FF00Alias removed:|r", alias)
            UpdateAliasList()
        end)

        row:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, yOffset)
        row:Show()

        yOffset = yOffset - 35
        rowIndex = rowIndex + 1
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
        RegisterAlias(a, c) -- Dynamically register to the game
        
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