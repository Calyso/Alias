-- ==========================================
-- Alias
-- Linux-style chat command aliases.
-- ==========================================

local ADDON_NAME = "Alias"
local MANAGER_COMMAND = "/alias"

-- Saved variable (declared in Alias.toc). Window settings live alongside
-- the aliases; IsAliasKey keeps them out of the alias list.
AliasDB = AliasDB or {}
local DB = AliasDB

local ROW_HEIGHT = 40

local UI
local minimapToggle
local aliasInput
local cmdInput
local contentFrame
local aliasRows = {}
local skin

-- Forward declarations
local RefreshList, RegisterAlias, UnregisterAlias, UpdateMinimapPosition

-- ==========================================
-- Minimap Button
-- ==========================================

local minimapBtn = CreateFrame("Button", "AliasMinimapButton", Minimap)
minimapBtn:SetSize(31, 31)
minimapBtn:SetFrameLevel(8)
minimapBtn:RegisterForDrag("LeftButton", "RightButton")

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
    minimapBtn:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

minimapBtn:SetScript("OnDragStart", function(self)
    self:LockHighlight()
    self:SetScript("OnUpdate", function()
        local mx, my = Minimap:GetCenter()
        local px, py = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        local angle = math.atan((py / scale) - my, (px / scale) - mx)

        DB.minimapPos = angle
        UpdateMinimapPosition(angle)
    end)
end)

minimapBtn:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
    self:UnlockHighlight()
end)

minimapBtn:SetScript("OnClick", function(self, button)
    if button == "LeftButton" then
        if UI:IsShown() then
            UI:Hide()
        else
            UI:Show()
        end
    end
end)

minimapBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText("Alias")
    GameTooltip:AddLine("Left-click to open Alias Window.", 1, 1, 1)
    GameTooltip:AddLine("Drag to move this button.", 1, 1, 1)
    GameTooltip:Show()
end)

minimapBtn:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

-- ==========================================
-- Window
-- ==========================================

UI = CreateFrame("Frame", "AliasFrame", UIParent, "BasicFrameTemplateWithInset")
UI:SetSize(480, 450)
UI:SetPoint("CENTER")
UI:Hide()
tinsert(UISpecialFrames, "AliasFrame")

UI.title = UI:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
UI.title:SetPoint("CENTER", UI.TitleBg, "CENTER", 0, 0)
UI.title:SetText("Alias")

UI:SetMovable(true)
UI:SetClampedToScreen(true)
local dragArea = CreateFrame("Frame", nil, UI)
dragArea:SetPoint("TOPLEFT", UI, "TOPLEFT", 0, 0)
dragArea:SetPoint("BOTTOMRIGHT", UI, "TOPRIGHT", 0, -30)
dragArea:EnableMouse(true)
dragArea:RegisterForDrag("LeftButton")
dragArea:SetScript("OnDragStart", function() UI:StartMoving() end)
dragArea:SetScript("OnDragStop", function() UI:StopMovingOrSizing() end)

-- ==========================================
-- Input Row
-- ==========================================

local aliasLabel = UI:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
aliasLabel:SetText("Alias (ie, /ghi)")

aliasInput = CreateFrame("EditBox", nil, UI, "InputBoxTemplate")
aliasInput:SetSize(120, 30)
aliasInput:SetPoint("TOPLEFT", UI, "TOPLEFT", 20, -40)
aliasInput:SetAutoFocus(false)
aliasLabel:SetPoint("BOTTOMLEFT", aliasInput, "TOPLEFT", 0, 0)

local cmdLabel = UI:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
cmdLabel:SetText("Command (ie, /g hello guild!)")

cmdInput = CreateFrame("EditBox", nil, UI, "InputBoxTemplate")
cmdInput:SetSize(180, 30)
cmdInput:SetPoint("LEFT", aliasInput, "RIGHT", 15, 0)
cmdInput:SetAutoFocus(false)
cmdLabel:SetPoint("BOTTOMLEFT", cmdInput, "TOPLEFT", 0, 0)

local addBtn = CreateFrame("Button", nil, UI, "UIPanelButtonTemplate")
addBtn:SetSize(60, 25)
addBtn:SetPoint("LEFT", cmdInput, "RIGHT", 10, 0)
addBtn:SetText("Add")

local toggleLabel = UI:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
toggleLabel:SetText("Minimap")

minimapToggle = CreateFrame("CheckButton", nil, UI, "UICheckButtonTemplate")
minimapToggle:SetSize(26, 26)
minimapToggle:SetPoint("LEFT", addBtn, "RIGHT", 10, 0)
toggleLabel:SetPoint("BOTTOMLEFT", minimapToggle, "TOPLEFT", 0, 0)
minimapToggle:SetScript("OnClick", function(self)
    DB.showMinimap = self:GetChecked()
    if DB.showMinimap then
        minimapBtn:Show()
    else
        minimapBtn:Hide()
    end
end)

addBtn:SetScript("OnClick", function()
    local alias = aliasInput:GetText()
    local command = cmdInput:GetText()
    if alias == "" or command == "" then
        print("|cFFFF0000Error:|r Both fields must be filled.")
        return
    end

    if string.sub(alias, 1, 1) ~= "/" then alias = "/" .. alias end
    if string.sub(command, 1, 1) ~= "/" then command = "/" .. command end
    alias = string.lower(alias)

    -- Refreshing an alias we own needs the old registration cleared first.
    -- Never touch a name we don't own.
    if alias ~= MANAGER_COMMAND and DB[alias] ~= nil then
        UnregisterAlias(alias)
    end

    -- Register first: a taken name must never be saved.
    if not RegisterAlias(alias, command) then
        print("|cFFFF0000Error:|r " .. alias .. " is already taken by another command.")
        return
    end

    DB[alias] = command

    aliasInput:SetText("")
    cmdInput:SetText("")
    aliasInput:ClearFocus()
    cmdInput:ClearFocus()

    print("|cFF00FF00Alias added:|r", alias, "->", command)
    RefreshList()
end)

-- ==========================================
-- Alias List
-- ==========================================

local scrollFrame = CreateFrame("ScrollFrame", nil, UI, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", UI, "TOPLEFT", 15, -100)
scrollFrame:SetPoint("BOTTOMRIGHT", UI, "BOTTOMRIGHT", -35, 15)

contentFrame = CreateFrame("Frame", nil, scrollFrame)
contentFrame:SetSize(430, 400)
scrollFrame:SetScrollChild(contentFrame)

local function IsAliasKey(key)
    return type(key) == "string" and key ~= "minimapPos" and key ~= "showMinimap"
end

local function CreateRow(index)
    local row = CreateFrame("Frame", nil, contentFrame)
    row:SetSize(430, ROW_HEIGHT)

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

    if skin then
        skin.Font(row.aliasText)
        skin.Font(row.cmdText)
        skin.Button(row.deleteBtn)
    end

    aliasRows[index] = row
    return row
end

function RefreshList()
    for _, row in ipairs(aliasRows) do
        row:Hide()
    end

    local keys = {}
    for alias in pairs(DB) do
        if IsAliasKey(alias) then
            keys[#keys + 1] = alias
        end
    end
    table.sort(keys)

    contentFrame:SetHeight(#keys * ROW_HEIGHT)

    local yOffset = 0
    for index = 1, #keys do
        local alias = keys[index]
        local row = aliasRows[index] or CreateRow(index)

        row.aliasText:SetText("|cFFFFFF00" .. alias .. "|r")
        row.cmdText:SetText(DB[alias])
        row.deleteBtn:SetScript("OnClick", function()
            UnregisterAlias(alias)
            DB[alias] = nil
            print("|cFF00FF00Alias removed:|r", alias)
            RefreshList()
        end)

        row:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, yOffset)
        row:Show()
        yOffset = yOffset - ROW_HEIGHT
    end
end

UI:SetScript("OnShow", function()
    RefreshList()
end)

-- ==========================================
-- Slash Commands
-- ==========================================
-- Uses the client's standard SlashCmdList mechanism: a handler in
-- SlashCmdList, a SLASH_* global for tab completion, and a hash_SlashCmdList
-- entry so the client dispatches the name case-insensitively. This is the
-- same mechanism the other addons on this client use, and it worked in game
-- in 2.0.1.
--
-- RegisterAlias returns true on success and nil if the name is already
-- taken (a built-in command or another addon), so a taken name is rejected
-- and never saved.

-- True if the name is owned by a built-in command or another addon.
-- The authoritative list of claimed names is in the SLASH_<key>1,
-- SLASH_<key>2 ... globals each SlashCmdList entry publishes, so we
-- compare those names. Key names are not reliable: the client stores
-- its built-ins under keys that do not match the command (its /g is not
-- under "G"), and one key can serve several names. The hash lookup is
-- kept as a fast path, but the scan below is the real check, because
-- the client builds the hash lazily.
local function CommandNameTaken(alias)
    local upper = string.upper(alias)
    local owner = hash_SlashCmdList[upper]
    if owner ~= nil and owner ~= ("CUSTOM_ALIAS_" .. string.upper(string.sub(alias, 2))) then
        return true
    end
    local target = string.lower(alias)
    for key in pairs(SlashCmdList) do
        local i = 1
        while true do
            local s = _G["SLASH_" .. key .. i]
            if type(s) ~= "string" then
                break
            end
            if string.lower(s) == target then
                return true
            end
            i = i + 1
        end
    end
    return false
end

-- Registers an alias as a chat command.
-- Returns true on success, nil if the name is already taken.
function RegisterAlias(alias, command)
    if CommandNameTaken(alias) then
        return nil
    end

    local cmdID = "CUSTOM_ALIAS_" .. string.upper(string.sub(alias, 2))
    SlashCmdList[cmdID] = function(msg)
        local executeString = command
        if msg and msg ~= "" then
            executeString = executeString .. " " .. msg
        end
        print("|cFF00CCFFAlias Used:|r " .. alias .. " > " .. command)
        local editBox = ChatEdit_ChooseBoxForSend()
        editBox:SetText(executeString)
        ChatEdit_SendText(editBox)
    end
    _G["SLASH_" .. cmdID .. "1"] = alias
    hash_SlashCmdList[string.upper(alias)] = cmdID

    return true
end

-- Unregisters a command this addon registered. Entries we do not own are
-- left untouched.
function UnregisterAlias(alias)
    local cmdID = "CUSTOM_ALIAS_" .. string.upper(string.sub(alias, 2))
    if SlashCmdList[cmdID] ~= nil then
        SlashCmdList[cmdID] = nil
    end
    local slashGlobal = "SLASH_" .. cmdID .. "1"
    if _G[slashGlobal] == alias then
        _G[slashGlobal] = nil
    end
    if hash_SlashCmdList[string.upper(alias)] == cmdID then
        hash_SlashCmdList[string.upper(alias)] = nil
    end
end

-- /alias opens or closes the window. If the name is taken, the minimap
-- button still works, so we just say so. This block is wrapped so that even
-- an unexpected error here can never stop the rest of the addon (skinning,
-- startup) from loading.
pcall(function()
    if CommandNameTaken(MANAGER_COMMAND) then
        print("|cFFFF0000Alias:|r Could not register " .. MANAGER_COMMAND ..
            " (that command name is already in use). Use the minimap button to open the window.")
        return
    end

    SlashCmdList["ALIASMANAGER"] = function()
        if UI:IsShown() then
            UI:Hide()
        else
            UI:Show()
        end
    end
    _G["SLASH_ALIASMANAGER1"] = MANAGER_COMMAND
    hash_SlashCmdList[string.upper(MANAGER_COMMAND)] = "ALIASMANAGER"
end)

-- ==========================================
-- EllesmereUI Skinning
-- ==========================================

if EllesmereUI and EllesmereUI.RegisterSkin then
    EllesmereUI.RegisterSkin(ADDON_NAME, function(S)
        skin = S

        S.Shell(UI)
        if UI.Inset then
            S.Inset(UI.Inset)
        end

        S.Font(UI.title)
        S.Font(aliasLabel)
        S.Font(cmdLabel)
        S.Font(toggleLabel)

        S.EditBox(aliasInput, { padInput = true })
        S.EditBox(cmdInput, { padInput = true })

        S.Button(addBtn)
        S.Checkbox(minimapToggle)
        S.ScrollBar(scrollFrame.ScrollBar)
    end)
end

-- ==========================================
-- Startup
-- ==========================================

local EventFrame = CreateFrame("Frame")
EventFrame:RegisterEvent("ADDON_LOADED")
EventFrame:SetScript("OnEvent", function(self, event, loadedAddon)
    if string.upper(loadedAddon) ~= string.upper(ADDON_NAME) then
        return
    end

    DB = AliasDB or {}
    AliasDB = DB

    if type(DB.minimapPos) ~= "number" then
        DB.minimapPos = math.pi / 4
    end
    if DB.showMinimap == nil then
        DB.showMinimap = true
    end

    UpdateMinimapPosition(DB.minimapPos)

    if DB.showMinimap then
        minimapBtn:Show()
    else
        minimapBtn:Hide()
    end
    minimapToggle:SetChecked(DB.showMinimap)

    -- Lowercase alias keys in place, then register each alias.
    local aliases = {}
    for alias in pairs(DB) do
        if IsAliasKey(alias) then
            aliases[#aliases + 1] = alias
        end
    end
    for _, alias in ipairs(aliases) do
        local lowerAlias = string.lower(alias)
        if lowerAlias ~= alias then
            DB[lowerAlias] = DB[alias]
            DB[alias] = nil
        end
        -- A saved name may have been taken since (a game update or another
        -- addon). Keep the entry so it shows in the list; warn once.
        if not RegisterAlias(lowerAlias, DB[lowerAlias]) then
            print("|cFFFF0000Alias:|r Could not register " .. lowerAlias ..
                " (that command name is already in use).")
        end
    end

    self:UnregisterEvent("ADDON_LOADED")
end)
