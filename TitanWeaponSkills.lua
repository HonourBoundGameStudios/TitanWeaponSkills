---@diagnostic disable: duplicate-set-field

-- **************************************************************************
-- * TitanWeaponSkills.lua
-- *
-- * Titan Panel - Weapon Skills Addon
-- * @Description: Displays the player's current weapon skills on Titan Panel
-- * @Version: 1.1.0
-- * @Date: Jul 19, 2025
-- * @Author: Honour Bound Game Studios Inc.
-- **************************************************************************

-- ******************************** Constants *******************************
local _G = getfenv(0);
local ADDON_ID = "WeaponSkills" -- Short ID for the plugin
local TITAN_BUTTON_NAME = "TitanPanel" .. ADDON_ID .. "Button" -- Full name of the Titan Panel button frame
local VERSION = "1.1.0" -- Version of the addon
local Colors = {
                White = "|cffffffff",
                Yellow = "|cffffff00",
                Orange = "|cffffa500",
                Red = "|cffff0000",
                Green = "|cff00ff00",
                LightGray = "|cffbbbbbb",
                Reset = "|r" -- Reset color
            }

-- Thin horizontal rule for the vertical tooltip: Blizzard's standard tooltip
-- divider texture (the same one Atlas's dropdown lib uses on Classic Era). A line
-- of glyphs renders as TOFU here, so a texture is the native fix. |Ttex:height:width|t
local TOOLTIP_RULE = "|TInterface\\Common\\UI-TooltipDivider-Transparent:8:160|t"

-- ****************************** Weapon Skill Types: ******************************
-- Axes:                Used by classes like warriors, paladins, and rogues for melee combat.
-- Bows:                Used by ranged classes like hunters. 
-- Crossbows:           Another ranged weapon type for hunters. 
-- Daggers:             Primarily used by rogues and some other classes for stealth and quick attacks. 
-- Fist Weapons:        Used by various classes, often with a focus on speed. 
-- Guns:                Ranged weapons for hunters, often with a slower rate of fire but high damage. 
-- Maces:               Used by classes like warriors and paladins, effective against armored targets. 
-- Polearms:            Two-handed melee weapons with reach, favored by some classes. 
-- Staves:              Primarily used by casters like mages and priests, but also used by some melee classes. 
-- Swords:              Used by a variety of classes for melee combat. 
-- Thrown Weapons:      Short-range weapons for ranged attacks. 
-- Two-Handed Axes:     Powerful two-handed weapons for melee classes, especially warriors. 
-- Two-Handed Maces:    Heavy two-handed weapons, effective for dealing with heavily armored foes. 
-- Two-Handed Swords:   Versatile two-handed weapons, favored by many melee classes.
-- Unarmed:             Represents the skill of fighting without weapons, used by monks and in certain situations by other classes.
-- Wands:               Ranged weapons for casters, often used for leveling. 

-- ************************* Icon Paths *******************************
local iconTable = {
                    Axes = "Interface\\Icons\\inv_axe_06",
                    Bows = "Interface\\Icons\\inv_weapon_bow_04",
                    Crossbows = "Interface\\Icons\\inv_weapon_crossbow_01",
                    Daggers = "Interface\\Icons\\inv_sword_31",
                    Fist_Weapons = "Interface\\Icons\\inv_gauntlets_28",
                    Guns = "Interface\\Icons\\inv_weapon_rifle_05",
                    Maces = "Interface\\Icons\\inv_mace_36",
                    Polearms = "Interface\\Icons\\inv_axe_30",
                    Staves = "Interface\\Icons\\inv_staff_14",
                    Swords = "Interface\\Icons\\inv_sword_28",
                    Thrown = "Interface\\Icons\\inv_throwingknife_05",
                    Two_Handed_Axes = "Interface\\Icons\\inv_axe_10",
                    Two_Handed_Maces = "Interface\\Icons\\inv_mace_47",
                    Two_Handed_Swords = "Interface\\Icons\\inv_sword_21",
                    Unarmed = "Interface\\Icons\\inv_gauntlets_30",
                    Wands = "Interface\\Icons\\inv_wand_06",
                }
                
-- ******************************** Sound Effects *******************************
local sfkIndex = 6518 -- WISP sound

-- ******************************** Locale-independent detection (LOC-1) *******************************
-- weaponSkillNameCache is nil until CacheWeaponSkillNames() runs on PLAYER_ENTERING_WORLD.
-- Falls back to the English seed until then (covers enUS/enGB out of the box).
local weaponSkillNameCache = nil
local WEAPON_SKILL_SEED = {
    ["Axes"]=true, ["Bows"]=true, ["Crossbows"]=true, ["Daggers"]=true,
    ["Fist Weapons"]=true, ["Guns"]=true, ["Maces"]=true, ["Polearms"]=true,
    ["Staves"]=true, ["Swords"]=true, ["Thrown"]=true, ["Two-Handed Axes"]=true,
    ["Two-Handed Maces"]=true, ["Two-Handed Swords"]=true, ["Unarmed"]=true,
    ["Wands"]=true,
}

-- ******************************** Debugging *******************************
-- Titan_Debug is a plain table; register topics by adding keys under ADDON_ID.
-- Set a topic to true to enable output for that topic.
Titan_Debug[ADDON_ID] = {}
Titan_Debug[ADDON_ID].Events = false
Titan_Debug[ADDON_ID].Flow   = false

-- ******************************** RegisterEvent *******************************
---local Register event if not already registered
---@param plugin 
---@param event
local function RegisterEvent(plugin, event)
	if not plugin:IsEventRegistered(event) then
		plugin:RegisterEvent(event)
	end
end

-- ******************************** Events *******************************
---@param action string
---@param reason string
local function Events(action, reason)
	local frame = _G[TITAN_BUTTON_NAME]

	if action == "register" then
        RegisterEvent(frame, "CHAT_MSG_SKILL")
        RegisterEvent(frame, "PLAYER_LEVEL_UP")
	elseif action == "unregister" then
        frame:UnregisterEvent("CHAT_MSG_SKILL")
        frame:UnregisterEvent("PLAYER_LEVEL_UP")
	else
		-- action unknown ???
	end

	local msg = ""
		.. " " .. tostring(action) .. ""
		.. " " .. tostring(reason) .. ""
	Titan_Debug.Out(ADDON_ID, "Events", msg)
end

-- ******************************** About dialog *******************************
-- StaticPopup with a focused, pre-selected editbox so the player can Ctrl-C the
-- studio link (WoW can't open an external browser). preferredIndex = 3 avoids taint.
local HBGS_URL = "https://store.steampowered.com/curator/44062210-Honour-Bound-Game-Studios/"
StaticPopupDialogs["TITANWEAPONSKILLS_ABOUT"] = {
    text = "Honour Bound Game Studios\nTitanWeaponSkills v" .. VERSION
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

-- ******************************** PrepareWeaponSkillsMenu *******************************
---local Build the right-click dropdown menu -- OLD UIDropDownMenu scheme.
--- Kept only as a fallback for Titan builds predating the Jan 2026 menu rewrite;
--- on current Titan the menuContextFunction below (GeneratorFunction) wins.
local function PrepareWeaponSkillsMenu()
    TitanPanelRightClickMenu_AddTitle(TitanPlugins[ADDON_ID].menuText)

    local level = TitanPanelRightClickMenu_GetDropdownLevel()

    -- ************************************** --
    -- Skill Label Toggle
    local info = {}
    info.text = "Skill Labels"
    info.func = function()
        TitanPanelRightClickMenu_ToggleVar({ADDON_ID, "ShowSkillLabels"})
        TitanPanelButton_UpdateButton(ADDON_ID)
    end
    info.checked = TitanUtils_Ternary(TitanGetVar(ADDON_ID, "ShowSkillLabels"), 1, nil)
    info.keepShownOnClick = 1
    TitanPanelRightClickMenu_AddButton(info, level)

    -- ************************************** --
    -- Skill Icons Toggle
    info = {}
    info.text = "Skill Icons"
    info.func = function()
        TitanPanelRightClickMenu_ToggleVar({ADDON_ID, "ShowSkillIcons"})
        TitanPanelButton_UpdateButton(ADDON_ID)
    end
    info.checked = TitanUtils_Ternary(TitanGetVar(ADDON_ID, "ShowSkillIcons"), 1, nil)
    info.keepShownOnClick = 1
    TitanPanelRightClickMenu_AddButton(info, level)

    -- ************************************** --
    -- Large Skill Icons Toggle
    info = {}
    info.text = "Large Skill Icons"
    info.func = function()
        TitanPanelRightClickMenu_ToggleVar({ADDON_ID, "ShowLargeSkillIcons"})
        TitanPanelButton_UpdateButton(ADDON_ID)
    end
    info.checked = TitanUtils_Ternary(TitanGetVar(ADDON_ID, "ShowLargeSkillIcons"), 1, nil)
    info.keepShownOnClick = 1
    TitanPanelRightClickMenu_AddButton(info, level)

    TitanPanelRightClickMenu_AddSpacer()

    -- ************************************** --
    -- Audio Notification Toggle
    info = {}
    info.text = "Audio Notification"
    info.func = function()
        TitanPanelRightClickMenu_ToggleVar({ADDON_ID, "PlayAudioNotification"})
    end
    info.checked = TitanUtils_Ternary(TitanGetVar(ADDON_ID, "PlayAudioNotification"), 1, nil)
    info.keepShownOnClick = 1
    TitanPanelRightClickMenu_AddButton(info, level)

    -- ************************************** --
    -- Hide Maxed Skills Toggle
    info = {}
    info.text = "Hide Maxed Skills"
    info.func = function()
        TitanPanelRightClickMenu_ToggleVar({ADDON_ID, "HideMaxedSkills"})
        TitanPanelButton_UpdateButton(ADDON_ID)
    end
    info.checked = TitanUtils_Ternary(TitanGetVar(ADDON_ID, "HideMaxedSkills"), 1, nil)
    info.keepShownOnClick = 1
    TitanPanelRightClickMenu_AddButton(info, level)

    TitanPanelRightClickMenu_AddSpacer()

    -- ************************************** --
    -- About Honour Bound Game Studios
    info = {}
    info.text = "About Honour Bound Game Studios"
    info.func = function()
        StaticPopup_Show("TITANWEAPONSKILLS_ABOUT")
    end
    info.notCheckable = 1
    TitanPanelRightClickMenu_AddButton(info, level)

    TitanPanelRightClickMenu_AddSpacer()

    -- ************************************** --
    -- Default Titan Panel Options
    TitanPanelRightClickMenu_AddToggleIcon(ADDON_ID)
    TitanPanelRightClickMenu_AddToggleRightSide(ADDON_ID)
    TitanPanelRightClickMenu_AddSpacer()
    TitanPanelRightClickMenu_AddHide(ADDON_ID)
end

-- ******************************** GeneratorFunction *******************************
-- Right-click menu -- NEW scheme (Jan 2026). Blizzard rewrote the Menu API and
-- is removing the old UIDropDownMenu code, so Titan wraps Blizzard_Menu behind
-- Titan_Menu and calls this generator on right-click. Titan itself adds the menu
-- title (top) plus the ShowIcon / DisplayOnRightSide toggles and Hide (bottom)
-- from the registry's controlVariables, so we only supply our own entries.
-- AddSelector toggles the saved variable and refreshes the button text for us.
---@param owner table Plugin frame
---@param root table Menu context root
local function GeneratorFunction(owner, root)
    Titan_Menu.AddSelector(root, ADDON_ID, "Skill Labels", "ShowSkillLabels")
    Titan_Menu.AddSelector(root, ADDON_ID, "Skill Icons", "ShowSkillIcons")
    Titan_Menu.AddSelector(root, ADDON_ID, "Large Skill Icons", "ShowLargeSkillIcons")
    Titan_Menu.AddSpacer(root)
    Titan_Menu.AddSelector(root, ADDON_ID, "Audio Notification", "PlayAudioNotification")
    Titan_Menu.AddSelector(root, ADDON_ID, "Hide Maxed Skills", "HideMaxedSkills")
    Titan_Menu.AddSpacer(root)
    Titan_Menu.AddCommand(root, ADDON_ID, "About Honour Bound Game Studios",
        function() StaticPopup_Show("TITANWEAPONSKILLS_ABOUT") end)
end

-- ******************************** OnLoad *******************************
---local Initialize the addon when loaded
local function OnLoad(self)
    	local notes = "\n"
        .. "Titan Weapon Skills Addon\n\n"
        .. "Version: " .. VERSION .. "\n\n"
        .. "Description: Displays your current weapon skills on Titan Panel\n"
        .. "allows you to quickly see your weapon proficiency and skill levels to assist maxing them out.\n\n"
        .. "Author: Honour Bound Game Studios Inc.\n\n"
        .. "Website: https://www.honourboundgames.com/\n"

    self.registry = {
        id = ADDON_ID,
        category = "Combat",
        version = VERSION,
        menuText = "Weapon Skills", -- Text displayed in the Titan Panel menu
        menuContextFunction = GeneratorFunction,   -- NEW scheme (1st priority, Jan 2026)
        menuTextFunction = PrepareWeaponSkillsMenu, -- OLD scheme fallback (pre-2026 Titan)
        tooltipTitle = "Weapon Skills", -- Title for the tooltip
        buttonTextFunction = TitanWeaponSkills_GetButtonText, -- Function to get the text displayed on the button
        tooltipTextFunction = TitanWeaponSkills_GetTooltipText, -- Function to generate the tooltip text
        icon = "Interface\\Icons\\INV_Sword_27", -- Default icon for the button
        iconWidth = 16, -- Width of the icon
        notes = notes, -- Short description in the config
        controlVariables = {
            ShowIcon = true,
            DisplayOnRightSide = false,
            ShowSkillLabels = true,
            ShowSkillIcons = true,
            ShowLargeSkillIcons = true,
            PlayAudioNotification = true,
            HideMaxedSkills = false,
        },
        savedVariables = {
            ShowIcon = true,
            DisplayOnRightSide = false,
            ShowSkillLabels = true,
            ShowSkillIcons = true,
            ShowLargeSkillIcons = true,
            PlayAudioNotification = true,
            HideMaxedSkills = false,
        }
    }
end

-- Forward declaration: defined below after isWeaponSkill; OnEvent captures the upvalue.
local CacheWeaponSkillNames

-- ******************************** OnEvent *******************************
---local Handle events registered to plugin
---@param self Button
---@param event string
---@param ... any
local function OnEvent(self, event, ...)
	Titan_Debug.Out(ADDON_ID, "Events", "_OnEvent" .. " " .. tostring(event) .. "")

    if event == "PLAYER_ENTERING_WORLD" then
        CacheWeaponSkillNames()
    elseif event == "SKILL_LINES_CHANGED" then
        CacheWeaponSkillNames()
        TitanPanelButton_UpdateButton(ADDON_ID)
    elseif event == "CHAT_MSG_SKILL" or event == "PLAYER_LEVEL_UP" then
        if TitanGetVar(ADDON_ID, "PlayAudioNotification") then
            PlaySound(sfkIndex)
        end
        TitanPanelButton_UpdateButton(ADDON_ID)
    end
end

-- ******************************** CacheWeaponSkillNames *******************************
-- Scans all skill lines and stores the names of every skill under the weapon-skills
-- category header into weaponSkillNameCache. Works in any client locale: the header
-- is identified by scoring its children against WEAPON_SKILL_SEED (English signal)
-- and the weapon-skill profile (isAbandonable=nil, maxRank>1, rank>0).
CacheWeaponSkillNames = function()
    weaponSkillNameCache = {}
    local headers = {}
    local current = nil
    for i = 1, GetNumSkillLines() do
        local name, isHdr, _, rank, _, _, maxRank, isAband = GetSkillLineInfo(i)
        if isHdr then
            current = { name = name, children = {} }
            tinsert(headers, current)
        elseif current then
            tinsert(current.children, { name = name, rank = rank, maxRank = maxRank, isAband = isAband })
        end
    end
    local best, bestScore = nil, 0
    for _, hdr in ipairs(headers) do
        local score = 0
        for _, child in ipairs(hdr.children) do
            if WEAPON_SKILL_SEED[child.name] then
                score = score + 10  -- strong: English name match
            elseif not child.isAband and child.maxRank and child.maxRank > 1
                   and child.rank and child.rank > 0 then
                score = score + 1   -- weak: weapon-skill profile
            end
        end
        if score > bestScore then bestScore = score; best = hdr end
    end
    if best and bestScore > 0 then
        for _, child in ipairs(best.children) do
            weaponSkillNameCache[child.name] = true
        end
    else
        for name in pairs(WEAPON_SKILL_SEED) do weaponSkillNameCache[name] = true end
    end
    Titan_Debug.Out(ADDON_ID, "Flow", "CacheWeaponSkillNames: cached " .. tostring(bestScore) .. " score")
end

-- ******************************** isWeaponSkill *******************************
---local Check if the skill is a weapon skill (locale-independent via cache)
---@param skillName string
local function isWeaponSkill(skillName)
    if weaponSkillNameCache then
        return weaponSkillNameCache[skillName]
    end
    return WEAPON_SKILL_SEED[skillName]
end

-- ******************************** FormatSkillLevel *******************************
---local Format the skill level text for display
local function FormatSkillRank(skillRank, skillMaxRank, verticalAlignment)
    local currentSkillRankText = ""

    currentSkillRankText = "" .. skillRank

    -- Color the currentSkillText based on its value
    if skillRank == skillMaxRank then
        currentSkillRankText = Colors.Green .. currentSkillRankText .. Colors.Reset -- Green for maxed skill
    elseif skillRank / skillMaxRank >= 0.90 then
        currentSkillRankText = Colors.Yellow .. currentSkillRankText .. Colors.Reset -- Yellow for medium skill
    elseif skillRank / skillMaxRank >= 0.80 then
        currentSkillRankText = Colors.Orange .. currentSkillRankText .. Colors.Reset -- Orange for high skill
    else
        currentSkillRankText = Colors.Red .. currentSkillRankText .. Colors.Reset -- Red for low skill
    end

    -- Light grey for maxSkill unless it is maxed
    if skillRank == skillMaxRank then
        currentSkillRankText = currentSkillRankText .. Colors.Green .. "/" .. skillMaxRank .. Colors.Reset
    else
        currentSkillRankText = currentSkillRankText .. Colors.LightGray .. "/" .. skillMaxRank .. Colors.Reset
    end

    return currentSkillRankText
end

-- ******************************** FormatSkillIcon *******************************
---local Format the skill icon for display
local function FormatSkillIcon(skillName, verticalAlignment)
    local skillIcon = ""

    -- Check if the plugin is configured to show skill icons
    if TitanGetVar(ADDON_ID, "ShowSkillIcons") or verticalAlignment then

        -- Check if the skill is a weapon skill and get the icon path
        local skillNameWithoutDashOrSpaces = skillName:gsub("-", "_")
        skillNameWithoutDashOrSpaces = skillNameWithoutDashOrSpaces:gsub(" ", "_")
        local iconPath = iconTable[skillNameWithoutDashOrSpaces] or "Interface\\Icons\\INV_Sword_27" -- Default to sword icon if not found

        -- If the skill is a weapon skill, prepend the icon to the skill name
        if isWeaponSkill(skillName) then
            if TitanGetVar(ADDON_ID, "ShowLargeSkillIcons") then
                -- Use standard icon size
                skillIcon = "|T" .. iconPath .. ":24:24:0:0|t "
            else
                -- Use small icon size if configured
                skillIcon = "|T" .. iconPath .. ":16:16:0:0|t "
            end
        end
    end

    return skillIcon
end

-- ******************************** FormatSkillName *******************************
---local Format the skill name for display
local function FormatSkillName(skillName, verticalAlignment)
    local skillNameText = ""

    if TitanGetVar(ADDON_ID, "ShowSkillLabels") or verticalAlignment then
        skillNameText = Colors.White .. skillName .. ": " .. Colors.Reset
    else
        skillNameText = ""
    end

    return skillNameText
end

-- ******************************** GetWeaponSkillsList *******************************
---local Get the list of weapon skills and their current levels
local function GetWeaponSkillsList(verticalAlignment)
    if not weaponSkillNameCache then CacheWeaponSkillNames() end

    local allSkillsTable = {}
    local numSkills = GetNumSkillLines()

    for skillIndex = 1, numSkills do
        local skillName, _, _, skillRank, _, _, skillMaxRank, _, _, _, _, _, _ = GetSkillLineInfo(skillIndex)

        -- Check if the skill is a weapon skill and has a valid rank
        local isMaxed = skillRank and skillMaxRank and (skillRank == skillMaxRank)
        local hideMaxed = not verticalAlignment and TitanGetVar(ADDON_ID, "HideMaxedSkills")
        if isWeaponSkill(skillName) and skillRank and skillRank > 0
           and not (isMaxed and hideMaxed) then
        
            -- [Skill Icon] + [Skill Name] + ": " + [Skill Rank / Max Rank]
            local skillIcon = FormatSkillIcon(skillName, verticalAlignment)
            local skillNameText = FormatSkillName(skillName, verticalAlignment)
            local skillRankText = FormatSkillRank(skillRank, skillMaxRank, verticalAlignment)
            local separatorText = ""
            
            if verticalAlignment then
                separatorText = "\t"
            end
            
            tinsert(allSkillsTable, skillIcon .. skillNameText .. separatorText .. skillRankText)
        end
    end

    local separator = verticalAlignment and "\n" or "   "
    local list = table.concat(allSkillsTable, separator)

    -- Vertical tooltip only (never the bar): a rule under the Titan title, then
    -- the skill list, a rule, and the Honour Bound Game Studios branding footer.
    if verticalAlignment then
        local logo = "|TInterface\\AddOns\\TitanWeaponSkills\\Media\\HBGS-Logo:14:14|t "
        local footer = logo .. Colors.LightGray .. "Honour Bound Game Studios" .. Colors.Reset
        list = TOOLTIP_RULE .. "\n" .. list .. "\n" .. TOOLTIP_RULE .. "\n" .. footer
    end

    return list
end


-- ******************************** TitanWeaponSkills_GetButtonText *******************************
---Get the text to display on the button (global by contract: prefixed to avoid
---collisions on the shared namespace — see Global Name Registry in CLAUDE.md)
function TitanWeaponSkills_GetButtonText()
    return GetWeaponSkillsList()
end

-- ******************************** TitanWeaponSkills_GetTooltipText *******************************
-- Function to generate the tooltip text when hovering over the button
-- This function will be called by Titan Panel to display detailed information.
-- Global by contract: prefixed to avoid collisions on the shared namespace.
function TitanWeaponSkills_GetTooltipText()
    return GetWeaponSkillsList(true)
end

-- ******************************** OnShow *******************************
---local Handle the OnShow event for the Titan Panel button
local function OnShow(self)
	local msg = "_OnShow"
	Titan_Debug.Out(ADDON_ID, "Flow", msg)
	Events("register", "_OnShow")
	TitanPanelButton_UpdateButton(ADDON_ID);
end

-- ******************************** OnHide *******************************
---local Handle the OnHide event for the Titan Panel button
local function OnHide(self)
    local msg = "_OnHide"
    Titan_Debug.Out(ADDON_ID, "Flow", msg)
    Events("unregister", "_OnHide")    
end
    
-- ******************************** CreateTitanWeaponSkillsButton *******************************
---local Create the Titan Panel button for the Weapon Skills addon
local function CreateTitanButton()
    if _G[TITAN_BUTTON_NAME] then
        return -- If already created, do nothing
    end

    local frame = CreateFrame("Frame", nil, UIParent)
    local window = CreateFrame("Button", TITAN_BUTTON_NAME, frame, "TitanPanelComboTemplate")
    window:SetFrameStrata("FULLSCREEN")
    OnLoad(window)

    -- Permanently registered (not tied to OnShow/OnHide): build/refresh the
    -- locale-aware weapon skill name cache on world enter and when skills change.
    window:RegisterEvent("PLAYER_ENTERING_WORLD")
    window:RegisterEvent("SKILL_LINES_CHANGED")

    window:SetScript("OnShow", 
        function(self) 
		    OnShow(self);
            TitanPanelButton_OnShow(self) 
        end)

    window:SetScript("OnHide", 
        function(self) 
		    OnHide(self)
        end)
    
    window:SetScript("OnEvent", 
        function(self, event, ...) 
            OnEvent(self, event, ...) 
        end)

	window:SetScript("OnClick",
	    function(self, button)
		    TitanPanelButton_OnClick(self, button);
	    end)
end


-- ******************************** Initialization *******************************
-- Check if Titan Panel's global ID exists before attempting to create frames
-- This ensures Titan Panel is loaded before we try to interact with it.
if TITAN_ID then
    Titan_Debug.Out(ADDON_ID, "Flow", "TitanWeaponSkills: TITAN_ID found. Attempting to create button frame.")
    CreateTitanButton()
else
    -- If TITAN_ID is not immediately available, we might still be too early.
    -- This scenario is less likely with ##Dependencies, but good to be aware.
    Titan_Debug.Out(ADDON_ID, "Flow", "TitanWeaponSkills: TITAN_ID not found at initial load. This addon might load before Titan Panel.")
    -- For robustness, you could add an ADDON_LOADED listener for "Titan" here
    -- if you consistently find TITAN_ID missing at this point.
    -- However, ##Dependencies: Titan in .toc should generally handle this.
end

