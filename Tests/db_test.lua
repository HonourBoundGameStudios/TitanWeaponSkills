-- WeaponJourneyDB -- saved-variable shape, defaults, and the one-time import
-- of settings from Titan's store.
-- Run from project root: lua Tests/db_test.lua

local H = dofile("Tests/harness.lua")
local DB = dofile("WeaponJourneyDB.lua")

H.start("WeaponJourneyDB")

local function fresh()
    WeaponJourneyDB = nil
    return DB.Init()
end

-- ── Shape and defaults ───────────────────────────────────────────────────────

local d = fresh()
H.eq(type(d.settings), "table", "Init creates the settings table")
H.eq(DB.Setting("ShowSkillLabels"), true, "labels default on")
H.eq(DB.Setting("ShowSkillIcons"), true, "icons default on")
H.eq(DB.Setting("ShowLargeSkillIcons"), true, "large icons default on")
H.eq(DB.Setting("PlayAudioNotification"), true, "audio default on")
H.eq(DB.Setting("HideMaxedSkills"), false, "hide-maxed defaults off")

-- Titan bar-layout settings are gone: the LDB host owns icon and placement.
H.eq(DB.DEFAULTS.ShowIcon, nil, "ShowIcon is not ours to store")
H.eq(DB.DEFAULTS.DisplayOnRightSide, nil, "DisplayOnRightSide is not ours to store")

-- Init merges: an existing choice survives, a newly added default back-fills.
WeaponJourneyDB = { settings = { HideMaxedSkills = true } }
DB.Init()
H.eq(DB.Setting("HideMaxedSkills"), true, "existing choice is not clobbered")
H.eq(DB.Setting("ShowSkillLabels"), true, "missing key back-fills from defaults")

-- Init is idempotent.
local before = DB.Setting("HideMaxedSkills")
DB.Init(); DB.Init()
H.eq(DB.Setting("HideMaxedSkills"), before, "re-running Init changes nothing")

-- Get lazily initialises rather than returning nil.
WeaponJourneyDB = nil
H.eq(type(DB.Get().settings), "table", "Get initialises on first use")

-- ── Toggle ───────────────────────────────────────────────────────────────────

fresh()
H.eq(DB.Toggle("HideMaxedSkills"), true, "toggle off -> on returns the new value")
H.eq(DB.Setting("HideMaxedSkills"), true, "and the new value persists")
H.eq(DB.Toggle("HideMaxedSkills"), false, "toggle back")
H.eq(DB.Toggle("ShowSkillIcons"), false, "toggling a default-on setting turns it off")

-- ── Minimap ──────────────────────────────────────────────────────────────────

-- TitanPresent reads two client globals; stub them the way the client would.
TITAN_ID = nil
IsAddOnLoaded = function() return false end
H.eq(DB.TitanPresent(), false, "no Titan: neither signal set")
TITAN_ID = "Titan"
H.eq(DB.TitanPresent(), true, "Titan loaded ahead of us sets TITAN_ID")
TITAN_ID = nil
IsAddOnLoaded = function(name) return name == "Titan" end
H.eq(DB.TitanPresent(), true, "Titan loaded after us is still detected")
IsAddOnLoaded = function() return false end

fresh()
local mm = DB.Minimap()
H.eq(mm.hide, false, "no Titan: minimap button shown, so the addon is never invisible")
H.ok(DB.Minimap() == mm, "same table every call (LibDBIcon mutates it in place)")
mm.minimapPos = 123
H.eq(DB.Minimap().minimapPos, 123, "LibDBIcon's own keys survive")

TITAN_ID = "Titan"
fresh()
H.eq(DB.Minimap().hide, true, "Titan hosting: minimap button hidden as redundant")
TITAN_ID = nil

-- The first-run default is a default only -- a stored choice always wins.
WeaponJourneyDB = { minimap = { hide = false } }
TITAN_ID = "Titan"
H.eq(DB.Minimap().hide, false, "stored choice beats the Titan-present default")
TITAN_ID = nil

-- ── Migration off Titan ──────────────────────────────────────────────────────

local titan = {
    Players = {
        ["Thrall@Nethergarde"] = {
            Plugins = {
                WeaponSkills = {
                    ShowSkillLabels = false,
                    HideMaxedSkills = true,
                    ShowIcon = true,           -- no longer ours; must be ignored
                },
            },
        },
    },
}

fresh()
local imported = DB.MigrateFromTitan(titan, "WeaponSkills")
H.eq(imported, 2, "two recognised settings imported")
H.eq(DB.Setting("ShowSkillLabels"), false, "the player's Titan choice carried over")
H.eq(DB.Setting("HideMaxedSkills"), true, "and so did hide-maxed")
H.eq(DB.Setting("ShowSkillIcons"), true, "settings Titan did not hold keep our default")
H.eq(DB.Get().settings.ShowIcon, nil, "retired Titan setting is not imported")

-- Exactly once: a later call must not re-import over newer choices.
DB.Toggle("ShowSkillLabels")
H.eq(DB.MigrateFromTitan(titan, "WeaponSkills"), 0, "second run imports nothing")
H.eq(DB.Setting("ShowSkillLabels"), true, "post-migration choice survives")

-- Older Titan builds stored 1/nil rather than true/false.
fresh()
DB.MigrateFromTitan({ Players = { P = { Plugins = { WeaponSkills = { HideMaxedSkills = 1 } } } } },
    "WeaponSkills")
H.eq(DB.Setting("HideMaxedSkills"), true, "numeric 1 imports as true")

-- ── Migration: degenerate input must never error ─────────────────────────────

fresh()
H.eq(DB.MigrateFromTitan(nil, "WeaponSkills"), 0, "no Titan settings at all")
fresh()
H.eq(DB.MigrateFromTitan({}, "WeaponSkills"), 0, "TitanSettings with no Players")
fresh()
H.eq(DB.MigrateFromTitan({ Players = "nonsense" }, "WeaponSkills"), 0, "Players is not a table")
fresh()
H.eq(DB.MigrateFromTitan({ Players = { X = "nonsense" } }, "WeaponSkills"), 0, "player is not a table")
fresh()
H.eq(DB.MigrateFromTitan({ Players = { X = { Plugins = { Other = {} } } } }, "WeaponSkills"), 0,
    "Titan is installed but never hosted this plugin")
fresh()
H.eq(DB.MigrateFromTitan({ Players = { X = { Plugins = { WeaponSkills = "nonsense" } } } }, "WeaponSkills"),
    0, "our plugin entry is not a table")

H.done()
