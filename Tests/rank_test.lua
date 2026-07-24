-- FormatRank -- the rank/max string and its colour thresholds.
-- Run from project root: lua Tests/rank_test.lua

local H = dofile("Tests/harness.lua")
local Engine = dofile("WeaponJourneyEngine.lua")
local C = Engine.COLORS

H.start("FormatRank colour thresholds")

-- Maxed: both halves green, so a finished skill reads as one solid colour.
H.eq(Engine.FormatRank(300, 300),
    C.Green .. "300" .. C.Reset .. C.Green .. "/300" .. C.Reset,
    "maxed: rank and /max both green")

-- Everything below the cap keeps a grey "/max".
local function rankHalf(rank, maxRank)
    local s = Engine.FormatRank(rank, maxRank)
    return (s:gsub("%" .. "|cffbbbbbb/%d+|r$", ""))
end

H.eq(rankHalf(285, 300), C.Yellow .. "285" .. C.Reset, "90% exactly -> yellow")
H.eq(rankHalf(299, 300), C.Yellow .. "299" .. C.Reset, "just under the cap -> yellow")
H.eq(rankHalf(240, 300), C.Orange .. "240" .. C.Reset, "80% exactly -> orange")
H.eq(rankHalf(269, 300), C.Orange .. "269" .. C.Reset, "just under 90% -> orange")
H.eq(Engine.FormatRank(239, 300),
    C.Red .. "239" .. C.Reset .. C.LightGray .. "/300" .. C.Reset,
    "just under 80% -> red, grey /max")
H.eq(rankHalf(1, 300), C.Red .. "1" .. C.Reset, "barely trained -> red")

-- A zero or missing cap must not divide by zero; treat it as the lowest tier.
H.eq(Engine.FormatRank(5, 0),
    C.Red .. "5" .. C.Reset .. C.LightGray .. "/0" .. C.Reset,
    "zero cap: no division blow-up, red")

-- Level-scaled caps (Classic Era: cap = level x 5) colour on the same ratio.
H.eq(Engine.FormatRank(50, 50),
    C.Green .. "50" .. C.Reset .. C.Green .. "/50" .. C.Reset,
    "maxed at level 10 cap")

H.done()
