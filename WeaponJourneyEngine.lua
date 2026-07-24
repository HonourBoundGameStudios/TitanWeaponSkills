-- WeaponJourneyEngine -- the pure-Lua display engine for Weapon Journey.
--
-- No WoW API, frame, event or saved-variable dependency lives here: everything
-- is plain tables and functions, so the formatting rules can be exercised with
-- a standalone Lua interpreter (see Tests/) instead of only by eye in-game.
-- The caller scans the skill lines and owns the settings; this file decides
-- what the resulting string looks like.
--
-- Dual-load contract:
--   * In WoW (Lua 5.1) the file is loaded by WeaponJourney.toc; it publishes
--     the module as the global `WeaponJourney_Engine`.
--   * In tests it is loaded with `dofile`, which returns the module table.
-- Keep this file inside the Lua 5.1 .. 5.4 common subset.

local Engine = {}

-- ── Palette ──────────────────────────────────────────────────────────────────
Engine.COLORS = {
    White     = "|cffffffff",
    Yellow    = "|cffffff00",
    Orange    = "|cffffa500",
    Red       = "|cffff0000",
    Green     = "|cff00ff00",
    LightGray = "|cffbbbbbb",
    Reset     = "|r",
}
local C = Engine.COLORS

-- Blizzard's standard tooltip divider texture. A line of ASCII/box glyphs
-- renders as TOFU in the tooltip font, so a texture is the native fix.
Engine.TOOLTIP_RULE = "|TInterface\\Common\\UI-TooltipDivider-Transparent:8:160|t"

-- ── Icons ────────────────────────────────────────────────────────────────────
-- Keyed by the English skill name with spaces and hyphens folded to underscores
-- (see IconPath). A locale whose names miss the table falls back to the sword.
Engine.DEFAULT_ICON = "Interface\\Icons\\INV_Sword_27"
Engine.ICONS = {
    Axes              = "Interface\\Icons\\inv_axe_06",
    Bows              = "Interface\\Icons\\inv_weapon_bow_04",
    Crossbows         = "Interface\\Icons\\inv_weapon_crossbow_01",
    Daggers           = "Interface\\Icons\\inv_sword_31",
    Fist_Weapons      = "Interface\\Icons\\inv_gauntlets_28",
    Guns              = "Interface\\Icons\\inv_weapon_rifle_05",
    Maces             = "Interface\\Icons\\inv_mace_36",
    Polearms          = "Interface\\Icons\\inv_axe_30",
    Staves            = "Interface\\Icons\\inv_staff_14",
    Swords            = "Interface\\Icons\\inv_sword_28",
    Thrown            = "Interface\\Icons\\inv_throwingknife_05",
    Two_Handed_Axes   = "Interface\\Icons\\inv_axe_10",
    Two_Handed_Maces  = "Interface\\Icons\\inv_mace_47",
    Two_Handed_Swords = "Interface\\Icons\\inv_sword_21",
    Unarmed           = "Interface\\Icons\\inv_gauntlets_30",
    Wands             = "Interface\\Icons\\inv_wand_06",
}

-- English signal used to identify the weapon-skill category header in any
-- locale (see PickWeaponHeader) and as the fallback name set.
Engine.WEAPON_SKILL_SEED = {
    ["Axes"] = true, ["Bows"] = true, ["Crossbows"] = true, ["Daggers"] = true,
    ["Fist Weapons"] = true, ["Guns"] = true, ["Maces"] = true, ["Polearms"] = true,
    ["Staves"] = true, ["Swords"] = true, ["Thrown"] = true, ["Two-Handed Axes"] = true,
    ["Two-Handed Maces"] = true, ["Two-Handed Swords"] = true, ["Unarmed"] = true,
    ["Wands"] = true,
}

-- ── Formatting ───────────────────────────────────────────────────────────────

-- "245/300" with the current rank coloured by how close it is to the cap:
-- maxed green, >=90% yellow, >=80% orange, below that red. The "/max" half is
-- grey unless the skill is maxed, so a finished skill reads as entirely green.
---@param rank number
---@param maxRank number
function Engine.FormatRank(rank, maxRank)
    local text = "" .. rank
    -- Guard the division: a skill line with no cap would otherwise blow up here.
    local ratio = (maxRank and maxRank > 0) and (rank / maxRank) or 0

    if rank == maxRank then
        text = C.Green .. text .. C.Reset
    elseif ratio >= 0.90 then
        text = C.Yellow .. text .. C.Reset
    elseif ratio >= 0.80 then
        text = C.Orange .. text .. C.Reset
    else
        text = C.Red .. text .. C.Reset
    end

    if rank == maxRank then
        return text .. C.Green .. "/" .. maxRank .. C.Reset
    end
    return text .. C.LightGray .. "/" .. maxRank .. C.Reset
end

-- Skill name -> icon texture. "Two-Handed Axes" and "Fist Weapons" both fold to
-- the underscore form the ICONS table is keyed by.
---@param skillName string
function Engine.IconPath(skillName)
    local key = skillName:gsub("-", "_"):gsub(" ", "_")
    return Engine.ICONS[key] or Engine.DEFAULT_ICON
end

-- Inline texture escape, trailing space included so it butts up against the label.
---@param skillName string
---@param large boolean|nil 24px when set, 16px otherwise
function Engine.IconMarkup(skillName, large)
    local size = large and 24 or 16
    return "|T" .. Engine.IconPath(skillName) .. ":" .. size .. ":" .. size .. ":0:0|t "
end

---@param skillName string
function Engine.FormatName(skillName)
    return C.White .. skillName .. ": " .. C.Reset
end

-- ── Locale-independent weapon-skill detection ────────────────────────────────

-- Score each skill-line header by how much its children look like weapon skills
-- and return the winner. A header scores 10 per English weapon-skill name (the
-- strong signal) and 1 per child merely matching the weapon-skill profile
-- (not abandonable, a cap above 1, trained at all) -- which is what carries a
-- non-English client, where no name matches the seed.
---@param headers table array of { name = string, children = { {name, rank, maxRank, isAbandonable} } }
---@return table|nil header, number score
function Engine.PickWeaponHeader(headers)
    local best, bestScore = nil, 0
    for _, hdr in ipairs(headers) do
        local score = 0
        for _, child in ipairs(hdr.children) do
            if Engine.WEAPON_SKILL_SEED[child.name] then
                score = score + 10
            elseif not child.isAbandonable and child.maxRank and child.maxRank > 1
                and child.rank and child.rank > 0 then
                score = score + 1
            end
        end
        if score > bestScore then
            best, bestScore = hdr, score
        end
    end
    return best, bestScore
end

-- The set of names to treat as weapon skills: the winning header's children, or
-- the English seed when no header scored (skills not loaded yet, odd client).
---@param headers table see PickWeaponHeader
---@return table set of name -> true
function Engine.WeaponSkillNames(headers)
    local best, score = Engine.PickWeaponHeader(headers)
    local names = {}
    if best and score > 0 then
        for _, child in ipairs(best.children) do
            names[child.name] = true
        end
    else
        for name in pairs(Engine.WEAPON_SKILL_SEED) do
            names[name] = true
        end
    end
    return names
end

-- ── The display pipeline ─────────────────────────────────────────────────────

-- Build the display string from scanned skill lines.
--
-- The one function behind both surfaces: the horizontal bar text (entries joined
-- by spaces, honouring every toggle) and the vertical tooltip body (one entry per
-- line, labels and icons forced on, maxed skills always kept, wrapped in rules).
--
---@param skills table array of { name, rank, maxRank, isWeapon }
---@param opts table|nil { labels, icons, largeIcons, hideMaxed, vertical, footer }
---@return string
function Engine.BuildList(skills, opts)
    opts = opts or {}
    local vertical = opts.vertical
    -- Vertical is the detail view: it overrides the bar's compaction toggles.
    local showLabels = opts.labels or vertical
    local showIcons = opts.icons or vertical

    local entries = {}
    for i = 1, #skills do
        local s = skills[i]
        local maxed = s.rank and s.maxRank and s.rank == s.maxRank
        local hidden = (not vertical) and opts.hideMaxed and maxed
        if s.isWeapon and s.rank and s.rank > 0 and not hidden then
            local icon = showIcons and Engine.IconMarkup(s.name, opts.largeIcons) or ""
            local label = showLabels and Engine.FormatName(s.name) or ""
            local gap = vertical and "\t" or ""
            entries[#entries + 1] = icon .. label .. gap .. Engine.FormatRank(s.rank, s.maxRank)
        end
    end

    local list = table.concat(entries, vertical and "\n" or "   ")
    if not vertical then
        return list
    end

    -- Tooltip only: a rule above and below the list, then the caller's footer
    -- (branding lives with the addon, not in the engine).
    local rule = Engine.TOOLTIP_RULE
    list = rule .. "\n" .. list .. "\n" .. rule
    if opts.footer then
        list = list .. "\n" .. opts.footer
    end
    return list
end

-- Publish for the WoW client (global by contract); return for standalone use.
WeaponJourney_Engine = Engine
return Engine
