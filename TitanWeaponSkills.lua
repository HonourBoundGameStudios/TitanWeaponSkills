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

-- ******************************** Variables *******************************
TitanWeaponSkillsSaved = {}

-- ******************************** Debugging *******************************
local dbg = Titan_Debug:New(ADDON_ID)
dbg:EnableDebug(false)
dbg:EnableTopic("Events", true) 
dbg:EnableTopic("Flow", true)

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
	dbg:Out("Events", msg)
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
        menuTextFunction = PrepareWeaponSkillsMenu,
        tooltipTitle = "Weapon Skills", -- Title for the tooltip
        buttonTextFunction = GetButtonText, -- Function to get the text displayed on the button
        tooltipTextFunction = GetTooltipText, -- Function to generate the tooltip text
        icon = "Interface\\Icons\\INV_Sword_27", -- Default icon for the button
        iconWidth = 16, -- Width of the icon
        notes = notes, -- Short description in the config
        controlVariables = {
            ShowIcon = true,
            DisplayOnRightSide = false,
            SkillIncreaseSoundNotification = true, -- Enable sound notification for skill increases
            ShowSkillLabels = true, -- Show skill labels in the tooltip
            ShowSkillIcons = true, -- Show skill icons in the tooltip
            ShowSmallSkillIcons = true, -- Show small skill icons in the tooltip
        },
        savedVariables = {
            ShowIcon = 1,
            DisplayOnRightSide = 0,
            SkillIncreaseSoundNotification = 1,
            ShowSkillLabels = 1, -- Default to showing skill labels
            ShowSkillIcons = 1, -- Default to showing skill icons
            ShowSmallSkillIcons = 1, -- Default to showing small skill icons
        }
    }
end

-- ******************************** OnEvent *******************************
---local Handle events registered to plugin
---@param self Button
---@param event string
---@param ... any
local function OnEvent(self, event, ...)
	dbg:Out("Events", "_OnEvent" .. " " .. tostring(event) .. "")

    if event == "CHAT_MSG_SKILL" or "PLAYER_LEVEL_UP" then
        PlaySound(sfkIndex)
        TitanPanelButton_UpdateButton(ADDON_ID)
    end
end

-- ******************************** isWeaponSkill *******************************
---local Check if the skill is a weapon skill
---@param skillName string
function isWeaponSkill(skillName)  
    return skillName:find("Axe") or 
           skillName:find("Bow") or
           skillName:find("Crossbow") or
           skillName:find("Dagger") or
           skillName:find("Fist Weapons") or
           skillName:find("Guns") or
           skillName:find("Mace") or 
           skillName:find("Polearm") or 
           skillName:find("Staves") or 
           skillName:find("Sword") or 
           skillName:find("Thrown") or
           skillName:find("Unarmed") or 
           skillName:find("Wand")
end

-- ******************************** FormatSkillLevel *******************************
---local Format the skill level text for display
function FormatSkillRank(skillRank, skillMaxRank, verticalAlignment)
    local currentSkillRankText = ""

    currentSkillRankText = "" .. skillRank

    -- Color the currentSkillText based on its value
    if skillRank == skillMaxRank then
        currentSkillRankText = "|cff00ff00" .. currentSkillRankText .. "|r" -- Green for maxed skill
    elseif skillRank / skillMaxRank >= 0.90 then
        currentSkillRankText = "|cffffff00" .. currentSkillRankText .. "|r" -- Yellow for medium skill
    elseif skillRank / skillMaxRank >= 0.80 then
        currentSkillRankText = "|cffffa500" .. currentSkillRankText .. "|r" -- Orange for high skill
    else
        currentSkillRankText = "|cffff0000" .. currentSkillRankText .. "|r" -- Red for low skill
    end

    -- Light grey for maxSkill
    if skillRank == skillMaxRank then
        currentSkillRankText = currentSkillRankText .. "|cff00ff00" .. "/" .. skillMaxRank .. "|r"
    else
        currentSkillRankText = currentSkillRankText .. "|cbbbbbbbb" .. "/" .. skillMaxRank .. "|r"
    end

    return currentSkillRankText
end

-- ******************************** FormatSkillIcon *******************************
---local Format the skill icon for display
function FormatSkillIcon(skillName, verticalAlignment)
    local plugin = TitanUtils_GetPlugin(ADDON_ID)
    local skillIcon = ""

    -- Check if the plugin is configured to show skill icons
    if plugin.controlVariables.ShowSkillIcons or verticalAlignment then

        -- Check if the skill is a weapon skill and get the icon path
        local skillNameWithoutDashOrSpaces = skillName:gsub("-", "_")
        skillNameWithoutDashOrSpaces = skillNameWithoutDashOrSpaces:gsub(" ", "_")
        local iconPath = iconTable[skillNameWithoutDashOrSpaces] or "Interface\\Icons\\INV_Sword_27" -- Default to sword icon if not found

        -- If the skill is a weapon skill, prepend the icon to the skill name
        if isWeaponSkill(skillName) then
            if plugin.controlVariables.ShowLargeSkillIcons then
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
function FormatSkillName(skillName, verticalAlignment)
    local plugin = TitanUtils_GetPlugin(ADDON_ID)
    local skillNameText = ""

    if plugin.controlVariables.ShowSkillLabels or verticalAlignment then
        skillNameText = "|cffffffff" .. skillName .. ": |r"
    else
        skillNameText = ""
    end

    return skillNameText
end

-- ******************************** GetWeaponSkillsList *******************************
---local Get the list of weapon skills and their current levels
function GetWeaponSkillsList(verticalAlignment)
    local allSkillsTable = {}
    local numSkills = GetNumSkillLines()

    for skillIndex = 1, numSkills do
        local skillName, _, _, skillRank, _, _, skillMaxRank, _, _, _, _, _, _ = GetSkillLineInfo(skillIndex)

        -- Check if the skill is a weapon skill and has a valid rank
        if isWeaponSkill(skillName) and skillRank and skillRank > 0 then
        
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
    
    return table.concat(allSkillsTable, separator)
end


-- ******************************** GetButtonText *******************************
---local Get the text to display on the button
function GetButtonText()
    return GetWeaponSkillsList()
end

-- ******************************** OnClick *******************************
---local Handle events registered to plugin. Copies coordinates to chat line for shift-LeftClick
---@param self Button
---@param button string
local function OnClick(self, button)
	if (button == "LeftButton") then
        PlaySound(sfkIndex)

        if (IsShiftKeyDown()) then
			local activeWindow = ChatEdit_GetActiveWindow();
			if (activeWindow) then
				local message = GetWeaponSkillsList(false)
				activeWindow:Insert(message);
			end
		end
	end
end

-- ******************************** GetTooltipText *******************************
-- Function to generate the tooltip text when hovering over the button
-- This function will be called by Titan Panel to display detailed information.
function GetTooltipText()
    return GetWeaponSkillsList(true)
end

-- ******************************** OnShow *******************************
---local Handle the OnShow event for the Titan Panel button
local function OnShow(self)
	local msg = "_OnShow"
	dbg:Out("Flow", msg)
	Events("register", "_OnShow")
	TitanPanelButton_UpdateButton(ADDON_ID);
end

-- ******************************** OnHide *******************************
---local Handle the OnHide event for the Titan Panel button
local function OnHide(self)
    local msg = "_OnHide"
    dbg:Out("Flow", msg)
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
            OnClick(self, button);
		    TitanPanelButton_OnClick(self, button);
	    end)
end

--- Function to prepare the right-click menu for the addon.
-- This function is referenced by the plugin's registry (menuTextFunction).
function PrepareWeaponSkillsMenu()
    local plugin = TitanUtils_GetPlugin(ADDON_ID);
    TitanPanelRightClickMenu_AddTitle(TitanPlugins[ADDON_ID].menuText);
    
    --local debugToggleButton = {};
    --debugToggleButton.text = "Toggle Debug Output";
    --debugToggleButton.func = function()
    --    dbg:EnableDebug(not dbg.enabled);
    --    TitanPanelButton_UpdateButton(ADDON_ID);
    --end
    --
    --debugToggleButton.checked = dbg.enabled; -- Checkmark if debugging is enabled
    --TitanPanelRightClickMenu_AddButton(debugToggleButton);

    -- ************************************** --
    -- Skill Label Toggle
    local displaySkillLabelsButton = {};
    displaySkillLabelsButton.text = "Skill Labels";
    displaySkillLabelsButton.func = function()
        plugin.controlVariables.ShowSkillLabels = not plugin.controlVariables.ShowSkillLabels;
        TitanPanelButton_UpdateButton(ADDON_ID);
    end
    
    displaySkillLabelsButton.checked = plugin.controlVariables.ShowSkillLabels;
    TitanPanelRightClickMenu_AddButton(displaySkillLabelsButton);

    -- ************************************** --
    -- Skill Icons Toggle
    local displaySkillIconsButton = {};
    displaySkillIconsButton.text = "Skill Icons";
    displaySkillIconsButton.func = function()
        plugin.controlVariables.ShowSkillIcons = not plugin.controlVariables.ShowSkillIcons;
        TitanPanelButton_UpdateButton(ADDON_ID);
    end

    displaySkillIconsButton.checked = plugin.controlVariables.ShowSkillIcons;
    TitanPanelRightClickMenu_AddButton(displaySkillIconsButton);
    
    -- ************************************** --
    -- Large Skill Icons Toggle
    local displayLargeSkillIcons = {};
    displayLargeSkillIcons.text = "Large Skill Icons";
    displayLargeSkillIcons.func = function()
        plugin.controlVariables.ShowLargeSkillIcons = not plugin.controlVariables.ShowLargeSkillIcons;
        TitanPanelButton_UpdateButton(ADDON_ID);
    end
    displayLargeSkillIcons.checked = plugin.controlVariables.ShowLargeSkillIcons;
    TitanPanelRightClickMenu_AddButton(displayLargeSkillIcons);

    -- ************************************** --
    TitanPanelRightClickMenu_AddSpacer();
    
    -- ************************************** --
    -- Default Titan Panel Options
    TitanPanelRightClickMenu_AddControlVars(ADDON_ID);
end

-- ******************************** Initialization *******************************
-- Check if Titan Panel's global ID exists before attempting to create frames
-- This ensures Titan Panel is loaded before we try to interact with it.
if TITAN_ID then
    dbg:Out("Flow", "TitanWeaponSkills: TITAN_ID found. Attempting to create button frame.")
    CreateTitanButton()
else
    -- If TITAN_ID is not immediately available, we might still be too early.
    -- This scenario is less likely with ##Dependencies, but good to be aware.
    dbg:Out("Flow", "TitanWeaponSkills: TITAN_ID not found at initial load. This addon might load before Titan Panel.")
    -- For robustness, you could add an ADDON_LOADED listener for "Titan" here
    -- if you consistently find TITAN_ID missing at this point.
    -- However, ##Dependencies: Titan in .toc should generally handle this.
end

