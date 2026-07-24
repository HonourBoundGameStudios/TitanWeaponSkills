-- PickWeaponHeader / WeaponSkillNames -- locale-independent detection of the
-- weapon-skills category among the client's skill-line headers.
-- Run from project root: lua Tests/header_test.lua

local H = dofile("Tests/harness.lua")
local Engine = dofile("WeaponJourneyEngine.lua")

H.start("Weapon-skill header detection")

local function hdr(name, children) return { name = name, children = children } end

-- ── English client: the seed names carry it outright. ────────────────────────

local enUS = {
    hdr("Professions", {
        { name = "Cooking",     rank = 225, maxRank = 300, isAbandonable = 1 },
        { name = "First Aid",   rank = 300, maxRank = 300, isAbandonable = 1 },
    }),
    hdr("Weapon Skills", {
        { name = "Swords",      rank = 300, maxRank = 300 },
        { name = "Daggers",     rank = 150, maxRank = 300 },
        { name = "Unarmed",     rank = 1,   maxRank = 300 },
    }),
}

local best, score = Engine.PickWeaponHeader(enUS)
H.eq(best and best.name, "Weapon Skills", "English: the weapon header wins")
H.eq(score, 30, "three seed matches at 10 points each")

local names = Engine.WeaponSkillNames(enUS)
H.ok(names["Swords"] and names["Daggers"] and names["Unarmed"], "all three names cached")
H.ok(names["Cooking"] == nil, "profession names are not cached as weapon skills")

-- ── Non-English client: no name matches, so the profile signal decides. ──────
-- Weapon skills are not abandonable, have a cap above 1, and are trained;
-- professions are abandonable, languages cap at 1.

local frFR = {
    hdr("Metiers", {
        { name = "Cuisine",   rank = 225, maxRank = 300, isAbandonable = 1 },
        { name = "Secourisme", rank = 300, maxRank = 300, isAbandonable = 1 },
    }),
    hdr("Langues", {
        { name = "Commun",    rank = 1, maxRank = 1 },
        { name = "Nain",      rank = 1, maxRank = 1 },
    }),
    hdr("Competences d'arme", {
        { name = "Epees",     rank = 300, maxRank = 300 },
        { name = "Dagues",    rank = 150, maxRank = 300 },
        { name = "Haches",    rank = 90,  maxRank = 300 },
    }),
}

local frBest, frScore = Engine.PickWeaponHeader(frFR)
H.eq(frBest and frBest.name, "Competences d'arme", "French: profile signal picks the weapon header")
H.eq(frScore, 3, "three profile matches at 1 point each")
H.ok(Engine.WeaponSkillNames(frFR)["Epees"], "localised names are cached")
H.ok(Engine.WeaponSkillNames(frFR)["Cuisine"] == nil, "localised profession is not")

-- The strong signal outranks the weak one: a header with one English weapon
-- name beats a bigger header that only matches the profile.
local mixed = {
    hdr("Decoys", {
        { name = "A", rank = 1, maxRank = 300 }, { name = "B", rank = 1, maxRank = 300 },
        { name = "C", rank = 1, maxRank = 300 }, { name = "D", rank = 1, maxRank = 300 },
    }),
    hdr("Real", { { name = "Maces", rank = 5, maxRank = 300 } }),
}
H.eq(select(1, Engine.PickWeaponHeader(mixed)).name, "Real", "one seed match (10) beats four profile matches (4)")

-- ── Degenerate input falls back to the English seed. ─────────────────────────

H.eq(select(2, Engine.PickWeaponHeader({})), 0, "no headers -> score 0")
H.eq(select(1, Engine.PickWeaponHeader({})), nil, "no headers -> no winner")

local fallback = Engine.WeaponSkillNames({})
H.ok(fallback["Swords"] and fallback["Two-Handed Maces"], "fallback is the English seed")

-- A header whose children are all abandonable professions scores nothing, so
-- we must not latch onto it.
local nothing = { hdr("Professions", {
    { name = "Cooking", rank = 225, maxRank = 300, isAbandonable = 1 },
}) }
H.eq(select(2, Engine.PickWeaponHeader(nothing)), 0, "abandonable children score nothing")
H.ok(Engine.WeaponSkillNames(nothing)["Cooking"] == nil, "and do not poison the cache")

-- Untrained (rank 0) children give no profile signal either.
local untrained = { hdr("Empty", { { name = "Zzz", rank = 0, maxRank = 300 } }) }
H.eq(select(2, Engine.PickWeaponHeader(untrained)), 0, "rank 0 gives no profile signal")

H.done()
