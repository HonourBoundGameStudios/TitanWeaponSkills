-- IconPath / IconMarkup -- name-to-texture folding and the inline escape.
-- Run from project root: lua Tests/icon_test.lua

local H = dofile("Tests/harness.lua")
local Engine = dofile("WeaponJourneyEngine.lua")

H.start("Skill icons")

-- Single-word names key the table directly.
H.eq(Engine.IconPath("Swords"), "Interface\\Icons\\inv_sword_28", "Swords")
H.eq(Engine.IconPath("Wands"), "Interface\\Icons\\inv_wand_06", "Wands")

-- Spaces and hyphens both fold to underscores -- the reason the table is keyed
-- that way rather than by the display name.
H.eq(Engine.IconPath("Fist Weapons"), "Interface\\Icons\\inv_gauntlets_28",
    "space folds to underscore")
H.eq(Engine.IconPath("Two-Handed Axes"), "Interface\\Icons\\inv_axe_10",
    "hyphen and space both fold")
H.eq(Engine.IconPath("Two-Handed Swords"), "Interface\\Icons\\inv_sword_21",
    "Two-Handed Swords")

-- Anything unmapped (a non-English locale, a skill we do not have art for)
-- falls back rather than producing a broken texture path.
H.eq(Engine.IconPath("Haches"), Engine.DEFAULT_ICON, "unknown name -> default sword")
H.eq(Engine.IconPath(""), Engine.DEFAULT_ICON, "empty name -> default sword")

-- Every mapped icon is a real Interface path (guards typos in the table).
local count = 0
for key, path in pairs(Engine.ICONS) do
    count = count + 1
    H.ok(path:match("^Interface\\Icons\\") ~= nil, "ICONS." .. key .. " is an Interface\\Icons path")
end
H.eq(count, 16, "all 16 Classic Era weapon skills have an icon")

-- Markup: size follows the large-icons toggle, trailing space always present.
H.eq(Engine.IconMarkup("Swords", false),
    "|TInterface\\Icons\\inv_sword_28:16:16:0:0|t ", "small icon is 16px")
H.eq(Engine.IconMarkup("Swords", true),
    "|TInterface\\Icons\\inv_sword_28:24:24:0:0|t ", "large icon is 24px")
H.eq(Engine.IconMarkup("Swords", nil),
    "|TInterface\\Icons\\inv_sword_28:16:16:0:0|t ", "nil large -> small")

H.done()
