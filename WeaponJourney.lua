---@diagnostic disable: duplicate-set-field

-- **************************************************************************
-- * WeaponJourney.lua
-- *
-- * Weapon Journey (formerly TitanWeaponSkills)
-- * @Description: Tracks the player's weapon skills on any LibDataBroker display
-- * @Author: Honour Bound Game Studios Inc.
-- **************************************************************************
--
-- Hosting (WJ-4): no Titan Panel dependency. This file publishes a
-- LibDataBroker data object ("WeaponJourney"); any LDB display hosts it --
-- Titan Panel through its own LDB bridge, Bazooka, ElvUI DataTexts -- with a
-- LibDBIcon minimap button as the fallback for players running no bar at all.
-- Nothing here may branch on which display is hosting us.
--
-- Layering: WeaponJourneyEngine owns the formatting (pure, tested offline),
-- WeaponJourneyDB owns the settings, and this file is the client wiring --
-- scanning skill lines, events, the menu, and the data object.

-- ******************************** Constants *******************************
local Engine = WeaponJourney_Engine
local DB = WeaponJourney_DB
local Colors = Engine.COLORS

-- The Titan plugin id these settings used to live under; kept only so the
-- one-time migration in DB.MigrateFromTitan can find them.
local TITAN_PLUGIN_ID = "WeaponSkills"

-- Single source of truth: read the version straight from the .toc so the About
-- dialog can never drift from the packaged version.
local GetMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
local VERSION = (GetMeta and GetMeta("WeaponJourney", "Version")) or "dev"

local LDB_NAME = "WeaponJourney"
local ADDON_ICON = "Interface\\Icons\\INV_Sword_27"

-- ******************************** Sound Effects *******************************
local sfkIndex = 6518 -- WISP sound

-- ******************************** Debugging *******************************
-- Titan_Debug is gone with the dependency. Same shape, ours: flip a topic to
-- true and /reload to get output.
local Debug = { Events = false, Flow = false }
local function DebugOut(topic, msg)
    if Debug[topic] then
        print("|cff33ff99WeaponJourney|r [" .. topic .. "] " .. tostring(msg))
    end
end

-- ******************************** Locale-independent detection (LOC-1) *******************************
-- weaponSkillNameCache is nil until CacheWeaponSkillNames() runs on PLAYER_ENTERING_WORLD.
-- Falls back to the engine's English seed until then (covers enUS/enGB out of the box).
local weaponSkillNameCache = nil

-- ******************************** About dialog *******************************
-- StaticPopup with a focused, pre-selected editbox so the player can Ctrl-C the
-- studio link (WoW can't open an external browser). preferredIndex = 3 avoids taint.
local HBGS_URL = "https://store.steampowered.com/curator/44062210-Honour-Bound-Game-Studios/"
StaticPopupDialogs["WEAPONJOURNEY_ABOUT"] = {
    text = "Honour Bound Game Studios\nWeapon Journey v" .. VERSION
        .. "\n\nSelect and copy the link below (Ctrl-C):",
    button1 = OKAY,
    hasEditBox = true,
    editBoxWidth = 350,
    OnShow = function(self)
        local editBox = self.editBox or (self.GetEditBox and self:GetEditBox())
        editBox:SetText(HBGS_URL)
        editBox:HighlightText()
        editBox:SetFocus()
    end,
    EditBoxOnEnterPressed = function(self) self:GetParent():Hide() end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- ******************************** ScanSkillLines *******************************
---local Read every skill line out of the client into a plain array the engine
---can work on: { name, rank, maxRank, isAbandonable } plus the header grouping.
---This is the only place that touches GetNumSkillLines/GetSkillLineInfo.
---@return table headers, table skills
local function ScanSkillLines()
    local headers, skills = {}, {}
    local current = nil
    for i = 1, GetNumSkillLines() do
        local name, isHdr, _, rank, _, _, maxRank, isAband = GetSkillLineInfo(i)
        if isHdr then
            current = { name = name, children = {} }
            tinsert(headers, current)
        else
            local skill = { name = name, rank = rank, maxRank = maxRank, isAbandonable = isAband }
            tinsert(skills, skill)
            if current then tinsert(current.children, skill) end
        end
    end
    return headers, skills
end

-- ******************************** CacheWeaponSkillNames *******************************
-- Stores the names of every skill under the weapon-skills category header into
-- weaponSkillNameCache. Works in any client locale -- the header-scoring logic
-- lives in the engine (Engine.WeaponSkillNames) and is covered by Tests/.
local function CacheWeaponSkillNames()
    local headers = ScanSkillLines()
    weaponSkillNameCache = Engine.WeaponSkillNames(headers)
    DebugOut("Flow", "CacheWeaponSkillNames: cached the weapon-skill names")
end

-- ******************************** isWeaponSkill *******************************
---local Check if the skill is a weapon skill (locale-independent via cache)
---@param skillName string
local function isWeaponSkill(skillName)
    if weaponSkillNameCache then
        return weaponSkillNameCache[skillName]
    end
    return Engine.WEAPON_SKILL_SEED[skillName]
end

-- ******************************** GetWeaponSkillsList *******************************
---local Get the list of weapon skills and their current levels.
---Thin: scan, tag which lines are weapon skills, read the settings, and let the
---engine assemble the string (both the bar text and the tooltip body).
local function GetWeaponSkillsList(verticalAlignment)
    if not weaponSkillNameCache then CacheWeaponSkillNames() end

    local _, skills = ScanSkillLines()
    for i = 1, #skills do
        skills[i].isWeapon = isWeaponSkill(skills[i].name) and true or false
    end

    -- Vertical tooltip only (never the bar): the Honour Bound Game Studios
    -- branding footer under the closing rule.
    local footer = nil
    if verticalAlignment then
        local logo = "|TInterface\\AddOns\\WeaponJourney\\Media\\HBGS-Logo:14:14|t "
        footer = logo .. Colors.LightGray .. "Honour Bound Game Studios" .. Colors.Reset
    end

    return Engine.BuildList(skills, {
        vertical   = verticalAlignment,
        labels     = DB.Setting("ShowSkillLabels"),
        icons      = DB.Setting("ShowSkillIcons"),
        largeIcons = DB.Setting("ShowLargeSkillIcons"),
        hideMaxed  = DB.Setting("HideMaxedSkills"),
        footer     = footer,
        empty      = Colors.LightGray .. "No weapon skills" .. Colors.Reset,
    })
end

-- ******************************** WeaponJourney_GetButtonText *******************************
---Get the text to display on the bar. Global by contract: prefixed to avoid
---collisions on the shared namespace -- see the Global Name Registry in CLAUDE.md.
function WeaponJourney_GetButtonText()
    return GetWeaponSkillsList()
end

-- ******************************** WeaponJourney_GetTooltipText *******************************
-- The vertical tooltip body shown on hover.
-- Global by contract: prefixed to avoid collisions on the shared namespace.
function WeaponJourney_GetTooltipText()
    return GetWeaponSkillsList(true)
end

-- ******************************** Right-click menu *******************************
-- Ours regardless of host: Blizzard's MenuUtil, the post-UIDropDownMenu API.
-- Titan used to contribute the icon/right-side/hide entries; those are the
-- host's business now, so the menu carries only our own settings.
local function ToggleSetting(key)
    DB.Toggle(key)
    WeaponJourney_RefreshButton()
end

local function OpenContextMenu(frame)
    if not MenuUtil then return end
    MenuUtil.CreateContextMenu(frame, function(_, root)
        root:CreateTitle("Weapon Journey")
        root:CreateCheckbox("Skill Labels",
            function() return DB.Setting("ShowSkillLabels") end,
            function() ToggleSetting("ShowSkillLabels") end)
        root:CreateCheckbox("Skill Icons",
            function() return DB.Setting("ShowSkillIcons") end,
            function() ToggleSetting("ShowSkillIcons") end)
        root:CreateCheckbox("Large Skill Icons",
            function() return DB.Setting("ShowLargeSkillIcons") end,
            function() ToggleSetting("ShowLargeSkillIcons") end)
        root:CreateDivider()
        root:CreateCheckbox("Audio Notification",
            function() return DB.Setting("PlayAudioNotification") end,
            function() ToggleSetting("PlayAudioNotification") end)
        root:CreateCheckbox("Hide Maxed Skills",
            function() return DB.Setting("HideMaxedSkills") end,
            function() ToggleSetting("HideMaxedSkills") end)
        root:CreateDivider()
        root:CreateCheckbox("Show minimap button",
            function() return not DB.Minimap().hide end,
            function()
                local mm = DB.Minimap()
                mm.hide = not mm.hide
                local dbicon = LibStub and LibStub("LibDBIcon-1.0", true)
                if dbicon then
                    if mm.hide then dbicon:Hide(LDB_NAME) else dbicon:Show(LDB_NAME) end
                end
            end)
        root:CreateDivider()
        root:CreateButton("About Honour Bound Game Studios",
            function() StaticPopup_Show("WEAPONJOURNEY_ABOUT") end)
    end)
end

-- ******************************** The LibDataBroker data object *******************************
-- The one thing every display addon hosts. Displays call the scripts; we own
-- the text and icon and update them through WeaponJourney_RefreshButton.
local ldb = LibStub and LibStub("LibDataBroker-1.1", true)
local dataObj
if ldb then
    dataObj = ldb:NewDataObject(LDB_NAME, {
        type = "data source",
        label = "Weapon Skills",
        text = "\226\128\148",              -- em dash placeholder until the first refresh
        icon = ADDON_ICON,
        OnClick = function(frame, button)
            if button == "RightButton" then
                OpenContextMenu(frame)
            end
        end,
        OnTooltipShow = function(tooltip)
            -- Displays hand us their tooltip frame. AddLine does not split on
            -- embedded newlines, so feed it one line at a time.
            tooltip:AddLine("Weapon Journey")
            for line in (WeaponJourney_GetTooltipText() .. "\n"):gmatch("(.-)\n") do
                tooltip:AddLine(line)
            end
        end,
    })
end

-- ******************************** WeaponJourney_RefreshButton *******************************
-- Repaint = write the data object; every hosting display reacts via the LDB
-- attribute-changed callback (Titan's bridge included). The single seam:
-- everything that needs the bar repainted calls this and knows nothing more.
-- Global by contract.
function WeaponJourney_RefreshButton()
    if dataObj == nil then return end
    dataObj.text = WeaponJourney_GetButtonText()
end

-- ******************************** Events *******************************
-- Registered permanently on our own frame. Under Titan these were tied to the
-- button's OnShow/OnHide; with no button of our own to hang them on, and the
-- data object always live for whichever display is hosting, permanent is both
-- simpler and correct.
local minimapRegistered = false
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
watcher:RegisterEvent("SKILL_LINES_CHANGED")
watcher:RegisterEvent("CHAT_MSG_SKILL")
watcher:RegisterEvent("PLAYER_LEVEL_UP")

watcher:SetScript("OnEvent", function(_, event)
    DebugOut("Events", "OnEvent " .. tostring(event))

    if event == "PLAYER_ENTERING_WORLD" then
        -- SavedVariables are only populated by the client around login, so the
        -- DB (and the settings import off Titan) can only be touched from here.
        DB.Init()
        local imported = DB.MigrateFromTitan(TitanSettings, TITAN_PLUGIN_ID)
        if imported > 0 then
            DebugOut("Flow", "imported " .. imported .. " settings from Titan")
        end

        if not minimapRegistered then
            minimapRegistered = true
            local dbicon = LibStub and LibStub("LibDBIcon-1.0", true)
            if dbicon and dataObj then
                dbicon:Register(LDB_NAME, dataObj, DB.Minimap())
            end
        end

        CacheWeaponSkillNames()
    elseif event == "SKILL_LINES_CHANGED" then
        CacheWeaponSkillNames()
    elseif event == "CHAT_MSG_SKILL" or event == "PLAYER_LEVEL_UP" then
        if DB.Setting("PlayAudioNotification") then
            PlaySound(sfkIndex)
        end
    end

    WeaponJourney_RefreshButton()
end)
