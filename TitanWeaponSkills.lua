---@diagnostic disable: duplicate-set-field

-- **************************************************************************
-- * TitanWeaponSkills.lua
-- *
-- * Titan Panel - Weapon Skills Addon
-- * @Description: Displays the player's current weapon skills on Titan Panel
-- * @Version: 1.0.0
-- * @Date: Jul 19, 2025
-- * @Author: Honour Bound Game Studios Inc.
-- **************************************************************************

-- ******************************** Constants *******************************
local _G = getfenv(0);
local ADDON_ID = "WeaponSkills" -- Short ID for the plugin
local TITAN_BUTTON_NAME = "TitanPanel" .. ADDON_ID .. "Button" -- Full name of the Titan Panel button frame
local VERSION = "1.0.0" -- Version of the addon

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

-- ******************************** Variables *******************************
TitanWeaponSkillsSaved = {}

-- ******************************** Debugging *******************************
local dbg = Titan_Debug:New(ADDON_ID)
dbg:EnableDebug(false)
dbg:EnableTopic("Events", true) 
dbg:EnableTopic("Flow", true)



-- ******************************** RegEvent *******************************
---local Register event if not already registered
---@param plugin 
---@param event
local function RegEvent(plugin, event)
	if not plugin:IsEventRegistered(event) then
		plugin:RegisterEvent(event)
	end
end

-- ******************************** Events *******************************
---@param action string
---@param reason string
local function Events(action, reason)
	local plugin = _G[TITAN_BUTTON_NAME]

	if action == "register" then
        RegEvent(plugin, "CHAT_MSG_SKILL")
	elseif action == "unregister" then
        plugin:UnregisterEvent("CHAT_MSG_SKILL")
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
        version = "1.0",
        menuText = "Weapon Skills", -- Text displayed in the Titan Panel menu
        tooltipTitle = "Weapon Skills", -- Title for the tooltip
        buttonTextFunction = "GetButtonText", -- Function to get the text displayed on the button
        tooltipTextFunction = "GetTooltipText", -- Function to generate the tooltip text
        icon = "Interface\\Icons\\INV_Sword_27", -- Default icon for the button
        iconWidth = 16, -- Width of the icon
        notes = notes, -- Short description in the config
        controlVariables = {
            ShowIcon = true,
            ShowLabelText = true,
            DisplayOnRightSide = false
        },
        savedVariables = {
            ShowIcon = 1,
            ShowLabelText = 1,
            DisplayOnRightSide = 0
        }
    }
end

-- ******************************** OnEvent *******************************
---local Handle events registered to plugin
---@param self Button
---@param event string
---@param ... any
local function OnEvent(self, event, ...)
	local msg = "_OnEvent" .. " " .. tostring(event) .. ""
	dbg:Out("Events", msg)
    TitanPanelButton_UpdateButton(ADDON_ID)
end

-- ******************************** GetWeaponSkillsList *******************************
---local Get the list of weapon skills and their current levels
function GetWeaponSkillsList(verticalAlignment)
    local allSkillsText = {}
    local numSkills = GetNumSkillLines()

    for skillIndex = 1, numSkills do
        local skillName, isHeader, isExpanded, skillRank, numTempPoints, skillModifier, skillMaxRank, isAbandonable, stepCost, rankCost, minLevel, skillCostType, skillDescription = GetSkillLineInfo(skillIndex)

        local isWeaponSkill = 
        skillName:find("Axe") or 
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

        if isWeaponSkill then
            local currentSkill = skillRank
            local maxSkill = skillMaxRank
            local currentSkillText = "" .. currentSkill

            -- Color the currentSkillText based on its value
            if currentSkill == maxSkill then
                currentSkillText = "|cff00ff00" .. currentSkillText .. "|r" -- Green for maxed skill
            elseif currentSkill / maxSkill >= 0.90 then
                currentSkillText = "|cffffff00" .. currentSkillText .. "|r" -- Yellow for medium skill
            elseif currentSkill / maxSkill >= 0.80 then
                currentSkillText = "|cffffa500" .. currentSkillText .. "|r" -- Orange for high skill
            else
                currentSkillText = "|cffff0000" .. currentSkillText .. "|r" -- Red for low skill
            end

            -- Light grey for maxSkill
            if currentSkill == maxSkill then
                currentSkillText = currentSkillText .. "|cff00ff00" .. "/" .. maxSkill .. "|r"
            else
                currentSkillText = currentSkillText .. "|cbbbbbbbb" .. "/" .. maxSkill .. "|r"
            end

            local skillNameWithoutDashOrSpaces = skillName:gsub("-", "_")
            skillNameWithoutDashOrSpaces = skillNameWithoutDashOrSpaces:gsub(" ", "_")
            local iconPath = iconTable[skillNameWithoutDashOrSpaces] or "Interface\\Icons\\INV_Sword_27" -- Default to sword icon if not found
            local skillIcon = "|T" .. iconPath .. ":24:24|t  "
            local skillName = skillIcon .. skillName -- Prepend the icon to the skill name
            skillName = "|cffffffff" .. skillName .. "|r" -- Default white for other skills

            if currentSkill and maxSkill and currentSkill > 0 then
                if verticalAlignment then
                    tinsert(allSkillsText, skillName .. ": \t" .. currentSkillText)
                else
                    tinsert(allSkillsText, skillName .. ": " ..  currentSkillText)
                end
            end
        end
    end

    local combinedText = ""
    
    combinedText = allSkillsText
    if #allSkillsText == 0 then
        combinedText = "No weapon skills found."
    else
        -- If vertical alignment is requested, join with newline characters
        if verticalAlignment then
            combinedText = table.concat(allSkillsText, "\n")
        else
            -- Otherwise, join with commas for horizontal alignment
            combinedText = table.concat(allSkillsText, "   ")
        end
    end

    -- If vertical alignment is requested, prepend a newline character
    if verticalAlignment then
        combinedText = "\n" .. combinedText
    end

    return combinedText
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
local function CreateTitanWeaponSkillsButton()
    if _G[TITAN_BUTTON_NAME] then
        return -- If already created, do nothing
    end

    local f = CreateFrame("Frame", nil, UIParent)
    local window = CreateFrame("Button", TITAN_BUTTON_NAME, f, "TitanPanelComboTemplate")
    window:SetFrameStrata("FULLSCREEN")
    OnLoad(window)

    window:SetScript("OnShow", function(self) 
		OnShow(self);
        TitanPanelButton_OnShow(self) 
    end)

    window:SetScript("OnHide", function(self) 
		OnHide(self)
    end)

    window:SetScript("OnEvent", function(self, event, ...) 
        OnEvent(self, event, ...) 
    end)

	window:SetScript("OnClick", function(self, button) 
        OnClick(self, button);
		TitanPanelButton_OnClick(self, button);
	end)
end

-- ******************************** Initialization *******************************
-- Check if Titan Panel's global ID exists before attempting to create frames
-- This ensures Titan Panel is loaded before we try to interact with it.
if TITAN_ID then
    dbg:Out("Flow", "TitanWeaponSkills: TITAN_ID found. Attempting to create button frame.")
    CreateTitanWeaponSkillsButton()
else
    -- If TITAN_ID is not immediately available, we might still be too early.
    -- This scenario is less likely with ##Dependencies, but good to be aware.
    dbg:Out("Flow", "TitanWeaponSkills: TITAN_ID not found at initial load. This addon might load before Titan Panel.")
    -- For robustness, you could add an ADDON_LOADED listener for "Titan" here
    -- if you consistently find TITAN_ID missing at this point.
    -- However, ##Dependencies: Titan in .toc should generally handle this.
end

