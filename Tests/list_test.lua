-- BuildList -- the one pipeline behind both the bar text and the tooltip body.
-- Run from project root: lua Tests/list_test.lua

local H = dofile("Tests/harness.lua")
local Engine = dofile("WeaponJourneyEngine.lua")
local C = Engine.COLORS

H.start("BuildList")

local function skills()
    return {
        { name = "Swords",  rank = 300, maxRank = 300, isWeapon = true },  -- maxed
        { name = "Daggers", rank = 150, maxRank = 300, isWeapon = true },
        { name = "Bows",    rank = 0,   maxRank = 300, isWeapon = true },  -- untrained
        { name = "Cooking", rank = 225, maxRank = 300, isWeapon = false }, -- not a weapon
    }
end

-- ── Bar text ─────────────────────────────────────────────────────────────────

local bare = Engine.BuildList(skills(), {})
H.eq(bare, Engine.FormatRank(300, 300) .. "   " .. Engine.FormatRank(150, 300),
    "everything off: just the ranks, three-space separated")
H.ok(bare:find("Cooking", 1, true) == nil, "non-weapon skill lines are excluded")
H.ok(bare:find("|T", 1, true) == nil, "no icon markup when icons are off")

-- An untrained skill (rank 0) never appears -- Classic Era lists every weapon
-- skill line, trained or not, and a wall of 0/300 is pure noise.
H.ok(bare:find("/300", 1, true) ~= nil, "trained skills are present")
H.eq(select(2, bare:gsub("   ", "")), 1, "two entries -> exactly one separator")

local labelled = Engine.BuildList(skills(), { labels = true })
H.eq(labelled,
    C.White .. "Swords: " .. C.Reset .. Engine.FormatRank(300, 300) .. "   "
        .. C.White .. "Daggers: " .. C.Reset .. Engine.FormatRank(150, 300),
    "labels on: white 'Name: ' before each rank")

local iconed = Engine.BuildList(skills(), { icons = true, largeIcons = true })
H.ok(iconed:find("|TInterface\\Icons\\inv_sword_28:24:24", 1, true) ~= nil,
    "icons on + large: 24px sword icon leads the entry")
H.ok(Engine.BuildList(skills(), { icons = true })
    :find("|TInterface\\Icons\\inv_sword_28:16:16", 1, true) ~= nil,
    "icons on, large off: 16px")

-- Hide-maxed drops the finished skill from the bar only.
local hidden = Engine.BuildList(skills(), { labels = true, hideMaxed = true })
H.ok(hidden:find("Swords", 1, true) == nil, "hideMaxed: the maxed skill is gone")
H.ok(hidden:find("Daggers", 1, true) ~= nil, "hideMaxed: unmaxed skills stay")
H.ok(hidden:find("   ", 1, true) == nil, "one entry left -> no dangling separator")

H.eq(Engine.BuildList({}, {}), "", "no skills -> empty string, not an error")
H.eq(Engine.BuildList(skills()), bare, "nil opts behaves like all-off")

-- ── Tooltip body ─────────────────────────────────────────────────────────────

local tip = Engine.BuildList(skills(), { vertical = true, footer = "HBGS" })
local lines = {}
for line in (tip .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = line end

H.eq(#lines, 5, "rule, two skills, rule, footer")
H.eq(lines[1], Engine.TOOLTIP_RULE, "opens with a divider")
H.eq(lines[4], Engine.TOOLTIP_RULE, "closes the list with a divider")
H.eq(lines[5], "HBGS", "caller's footer goes last")
H.ok(lines[2]:find("\t", 1, true) ~= nil, "vertical entries tab between label and rank")

-- Vertical is the detail view: it overrides the bar's compaction toggles.
H.ok(tip:find("Swords", 1, true) ~= nil, "vertical forces labels on")
H.ok(tip:find("|T", 1, true) ~= nil, "vertical forces icons on")
local tipMaxed = Engine.BuildList(skills(), { vertical = true, hideMaxed = true })
H.ok(tipMaxed:find("Swords", 1, true) ~= nil, "vertical ignores hideMaxed")

-- Footer is optional; without one the body still closes with its rule.
local noFooter = Engine.BuildList(skills(), { vertical = true })
H.ok(noFooter:sub(-#Engine.TOOLTIP_RULE) == Engine.TOOLTIP_RULE,
    "no footer -> body ends on the closing rule")

H.done()
