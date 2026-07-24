-- WeaponJourneyDB -- thin accessor over the WeaponJourneyDB saved variable.
--
-- Until [WJ-4] the settings lived inside Titan's own store (TitanGetVar, backed
-- by Titan's registry `savedVariables`). Dropping the Titan dependency means
-- owning them: this module is that store, plus a one-time migration so players
-- who already configured the addon under Titan keep their toggles.
--
-- Kept free of frame/event code so it can be exercised offline (see Tests/);
-- the only WoW coupling is the saved-variable global itself, which the client
-- populates around login.

local DB = {}
WeaponJourney_DB = DB

-- The settings the player actually chose. ShowIcon / DisplayOnRightSide are
-- deliberately NOT here: those were Titan bar-layout concerns, and every
-- LibDataBroker display owns its own icon/placement handling.
DB.DEFAULTS = {
    ShowSkillLabels       = true,
    ShowSkillIcons        = true,
    ShowLargeSkillIcons   = true,
    PlayAudioNotification = true,
    HideMaxedSkills       = false,
}

-- Ensure the saved table exists and has the expected shape (merge, never
-- clobber -- a new default must back-fill without resetting existing choices).
function DB.Init()
    WeaponJourneyDB = WeaponJourneyDB or {}
    local d = WeaponJourneyDB
    d.settings = d.settings or {}
    for key, value in pairs(DB.DEFAULTS) do
        if d.settings[key] == nil then d.settings[key] = value end
    end
    return d
end

function DB.Get() return WeaponJourneyDB or DB.Init() end

-- ── Settings ─────────────────────────────────────────────────────────────────

---@param key string one of DB.DEFAULTS
function DB.Setting(key)
    local value = DB.Get().settings[key]
    if value == nil then return DB.DEFAULTS[key] end
    return value
end

-- Flip a boolean setting and return the new value.
---@param key string
function DB.Toggle(key)
    local d = DB.Get()
    d.settings[key] = not DB.Setting(key)
    return d.settings[key]
end

-- Is Titan Panel around to host the bar? Two independent signals so the answer
-- holds whatever the addon load order was. Only meaningful at/after login.
function DB.TitanPresent()
    if TITAN_ID ~= nil then return true end
    local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    return (loaded and loaded("Titan")) and true or false
end

-- Minimap launcher state. LibDBIcon's contract: hand it a table it mutates in
-- place (`.hide`, drag angle), so this must always return the SAME table.
-- First-run default: hidden when Titan is hosting us (every existing player of
-- this addon is a Titan user, and a second launcher would be redundant), shown
-- otherwise so the addon is never invisible. The menu toggles it after that.
function DB.Minimap()
    local d = DB.Get()
    if d.minimap == nil then d.minimap = { hide = DB.TitanPresent() } end
    return d.minimap
end

-- ── One-time migration off Titan's store ─────────────────────────────────────

-- Titan keeps plugin settings at TitanSettings.Players[<player>].Plugins[<id>].
-- The player key format is Titan's business and has changed across its versions,
-- so rather than guess it we take the first player entry that carries our
-- plugin's table. Titan's settings are per-character while ours are per-account,
-- so on a multi-character account the first match wins -- an acceptable trade
-- for a one-time convenience import.
--
-- `titanSettings` is passed in rather than read from the global so this is
-- testable offline. Returns the number of settings imported.
---@param titanSettings table|nil the TitanSettings global
---@param pluginID string Titan plugin id ("WeaponSkills")
---@return number imported
function DB.MigrateFromTitan(titanSettings, pluginID)
    local d = DB.Init()
    if d.migratedFromTitan then return 0 end

    local players = titanSettings and titanSettings.Players
    if type(players) ~= "table" then return 0 end

    local saved = nil
    for _, player in pairs(players) do
        local plugins = type(player) == "table" and player.Plugins
        local mine = type(plugins) == "table" and plugins[pluginID]
        if type(mine) == "table" then saved = mine; break end
    end
    if not saved then return 0 end

    -- Only the settings we still have a meaning for, and only when Titan
    -- actually held a value -- never overwrite a choice already made here.
    local imported = 0
    for key in pairs(DB.DEFAULTS) do
        local value = saved[key]
        if value ~= nil and d.settings[key] == DB.DEFAULTS[key] then
            -- Titan stored these as booleans, but older builds used 1/nil.
            d.settings[key] = (value == true or value == 1) and true or false
            imported = imported + 1
        end
    end

    d.migratedFromTitan = true
    return imported
end

return DB
