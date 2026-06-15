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

-- Made the window wider (480 instead of 400)
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
cmdInput:SetSize(220, 30) -- Made the input slightly wider to match the new UI
cmdInput:SetPoint("LEFT", aliasInput, "RIGHT", 15, 0)
cmdInput:SetAutoFocus(false)
local cmdLabel = UI:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
cmdLabel:SetPoint("BOTTOMLEFT", cmdInput, "TOPLEFT", 0, 0)
cmdLabel:SetText("Command (e.g., /hello)")

local scrollFrame = CreateFrame("ScrollFrame", nil, UI, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", UI, "TOPLEFT", 15, -100)
scrollFrame:SetPoint("BOTTOMRIGHT", UI, "BOTTOMRIGHT", -35, 15)

local contentFrame = CreateFrame("Frame", nil, scrollFrame)
contentFrame:SetSize(430, 400) -- Expanded to fit the new scroll frame width
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
            -- Made rows slightly taller (40) to accommodate wrapped text
            row:SetSize(430, 40) 
            
            -- COLUMN 1: Alias (Fixed Width)
            row.aliasText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            row.aliasText:SetPoint("LEFT", row, "LEFT", 5, 0)
            row.aliasText:SetWidth(80) 
            row.aliasText:SetJustifyH("LEFT")
            
            -- COLUMN 3: Remove Button (Fixed Width)
            row.deleteBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            row.deleteBtn:SetSize(60, 22)
            row.deleteBtn:SetPoint("RIGHT", row, "RIGHT", -5, 0)
            row.deleteBtn:SetText("Remove")

            -- COLUMN 2: Command (Dynamic Width, Fills middle space)
            row.cmdText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            -- Anchor LEFT to the Alias text, Anchor RIGHT to the Delete button
            row.cmdText:SetPoint("LEFT", row.aliasText, "RIGHT", 10, 0)
            row.cmdText:SetPoint("RIGHT", row.deleteBtn, "LEFT", -15, 0)
            row.cmdText:SetJustifyH("LEFT")
            row.cmdText:SetJustifyV("MIDDLE")
            row.cmdText:SetWordWrap(true) -- Enables text wrapping
            row.cmdText:SetMaxLines(2) -- Prevents massive commands from breaking the UI height
            
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

        yOffset = yOffset - 45 -- Increased spacing between rows for the taller text limits
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