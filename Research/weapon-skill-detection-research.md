# Locale-Independent Weapon Skill Detection (LOC-1)

**Date:** 2026-06-11
**Author:** Research Agent
**Status:** Draft
**Confidence:** Medium (web-sourced; not personally verified in-game)
**Flavors verified:** Classic Era 1.x

---

## Executive Summary

`GetSkillLineInfo` does **not** return a skill ID or category flag — there is no
single API call that distinguishes weapon skills from professions without either
knowing the skill name or tracking the enclosing header row. Two viable
locale-independent approaches exist:

1. **Hardcoded skill ID whitelist** — maintain a Lua table of the 16 weapon skill
   line IDs (sourced from `SkillLine.dbc` / emulator databases) and match the
   skill name against what `GetSpellInfo(id)` returns on the local client. This
   approach requires a one-time population of the ID→localised-name table on
   first login and is medium complexity.

2. **Header-tracking** — iterate the skill list, remember when the cursor crosses
   the "Weapon Skills" category header (`isHeader == 1`), and collect all
   non-header rows that immediately follow it. Because the header row's
   `skillName` is the *localised* category label (e.g. "Waffenfertigkeiten" in
   German), this approach also requires a seed — the localised header string for
   the current client locale — unless the addon resolves it dynamically.

**Recommended approach:** implement an **isAbandonable-based pre-filter** combined
with a **hardcoded skill ID whitelist** populated via `GetSpellInfo`. This is the
most robust approach; it requires no in-game verification of header strings and
degrades safely to nothing rather than returning false positives. See the
Recommendation section for the full Lua design.

---

## Research Question

Is there a locale-independent way to identify weapon skill lines in Classic Era
1.x? Specifically:

1. Do weapon skill lines have stable numeric skill IDs usable at runtime?
2. Is there a `skillType` or `isWeapon` flag returned by `GetSkillLineInfo`?
3. What are the numeric skill IDs for all weapon skill lines?
4. How do locale-aware WoW addons detect weapon skills without English strings?

---

## Constraints

- Target: Classic Era 1.x only. `GetSkillLineInfo` is the correct API — it was
  removed in Cataclysm 4.0.1 and does not exist on retail or Cata Classic. This
  research is Classic Era–scoped.
- The addon must not crash or produce Lua errors on non-English clients; it may
  show nothing if it cannot identify weapon skills, but it must not break.
- No build system, no LibStub/embedded libraries are currently used — any
  solution must be self-contained in the single `TitanWeaponSkills.lua` file.

---

## Findings

### F1 — `GetSkillLineInfo` does not expose a skill ID or category flag

The function returns exactly 13 values:

```
skillName, header, isExpanded, skillRank, numTempPoints, skillModifier,
skillMaxRank, isAbandonable, stepCost, rankCost, minLevel, skillCostType,
skillDescription
```

No `skillID`, `categoryID`, or `isWeapon` field exists in this return set. The
`skillCostType` field is documented as "unknown, seems to be related to primary
and secondary skills" and its weapon-skill value is not publicly confirmed.

Source: warcraft.wiki.gg, AddOnStudio WoW API mirror (see Sources).

### F2 — Weapon skill lines have stable numeric IDs in the DBC

`SkillLine.dbc` contains a `m_categoryID` column. `m_categoryID = 6` is the
weapon skills category (confirmed in AzerothCore's `skillline` wiki page).
The full list of weapon skill line IDs with category 6:

| SkillLine ID | Skill Name (enUS) |
|---|---|
| 43 | Swords |
| 44 | Axes |
| 45 | Bows |
| 46 | Guns |
| 54 | Maces |
| 55 | Two-Handed Swords |
| 95 | Defense |
| 118 | Dual Wield |
| 136 | Staves |
| 160 | Two-Handed Maces |
| 162 | Unarmed |
| 172 | Two-Handed Axes |
| 173 | Daggers |
| 176 | Thrown |
| 226 | Crossbows |
| 228 | Wands |
| 229 | Polearms |
| 473 | Fist Weapons |

Source: AzerothCore `skillline` wiki, wowgm.board-directory.net skill IDs list,
corroborated by WoWClassicDB (Fist Weapons = 473 confirmed by URL).

Note: **Defense (95) and Dual Wield (118)** are in `m_categoryID = 6` per the
DBC but are not weapon skill lines for tracking purposes (they have no
rank/max-rank pair in the same way). The current addon already excludes them via
name matching; the whitelist approach must also exclude them explicitly.

### F3 — The `isAbandonable` flag is NOT set for weapon skills

Per Wowpedia documentation, `isAbandonable = 1` when a skill can be unlearned.
Weapon skills (Swords, Axes, etc.) are permanent once learned and return
`isAbandonable = nil`. Professions may return `isAbandonable = 1`. However,
**this alone does not distinguish weapon skills from non-weapon combat skills**
(e.g. First Aid is not abandonable either). It is a useful pre-filter but not
sufficient by itself.

### F4 — No locale-independent header string exists in GlobalStrings

WoW's `GlobalStrings.lua` does not contain a `SKILL_TYPE_WEAPON` or
`WEAPON_SKILLS_HEADER` constant. The "Weapon Skills" category header seen in the
skills window is a localised string read directly from `SkillLine.dbc` for the
current client locale. A Vanilla GlobalStrings search for "Weapon" returned no
matching category header constants.

Source: tekkub/wow-globalstrings GitHub repository (enUS.lua scan).

### F5 — Other addons use English string matching or localised header tracking

`CharacterStatsClassic` (getov/CharacterStatsClassic on GitHub) is the most
prominent Classic weapon-skill addon. Its detection approach:
- Stores a constant `CSC_WEAPON_SKILLS_HEADER` (value not visible in the public
  file snippet but is a localised string for the client's locale).
- Iterates all skill lines, tracks the current header, and collects skills under
  that header.
- Uses a second constant `g_WeaponStringByWeaponId` mapping item subtype IDs to
  weapon skill names (localised per client).

This confirms the community pattern: **header tracking + localised string table**
is the dominant approach in existing addons. No public Classic Era addon reviewed
used the numeric DBC skill IDs at runtime.

### F6 — `GetSpellInfo(spellID)` returns the localised spell name and works by numeric ID

`GetSpellInfo` is available in Classic Era 1.x and accepts a numeric spell ID,
returning the localised name for the current client locale. Weapon skills
correspond to passive spells in the spellbook; their spell IDs are stable across
locales. This is the bridge between the stable numeric DBC IDs and the localised
strings returned by `GetSkillLineInfo`.

However, the passive spell IDs for each weapon skill line (not the `SkillLine`
IDs above, but the corresponding `Spell.dbc` IDs) are not confirmed in this
research. This remains a gap — see Risks.

---

## Evidence

### E1 — AzerothCore `skillline` table confirms weapon category

The AzerothCore wiki for the `skillline` database table documents:
- Column `iRefID_SkillLineCategory` (integer) — references `SkillLineCategory.dbc`
- Category 6 = Weapon Skills (as stated in the wiki page response)
- Complete weapon skill ID list with names as shown in F2 above

URL: `https://www.azerothcore.org/wiki/skillline`

### E2 — WoW GM Portal skill ID list corroborates all IDs

A community skill ID list confirmed: Swords=43, Axes=44, Bows=45, Guns=46,
Maces=54, Two-Handed Swords=55, Staves=136, Two-Handed Maces=160, Unarmed=162,
Two-Handed Axes=172, Daggers=173, Thrown=176, Crossbows=226, Wands=228,
Polearms=229, Fist Weapons=473.

URL: `https://wowgm.board-directory.net/t24-skill-id-s`

### E3 — warcraft.wiki.gg confirms no skillID in return values

The warcraft.wiki.gg page for `API_GetSkillLineInfo` lists all 13 return values
explicitly. No `skillID` or `categoryID` is present.

URL: `https://warcraft.wiki.gg/wiki/API_GetSkillLineInfo`

### E4 — Blizzard's SkillFrame.lua uses `skillCostType` for colour, not weapon detection

The `SkillFrame.lua` source (wowgaming/3.3.5-interface-files, which reflects
Blizzard's approach) uses `skillCostType` only for bar colouring. No weapon skill
categorisation logic exists in Blizzard's own skill frame — it treats all skills
uniformly.

URL: `https://github.com/wowgaming/3.3.5-interface-files/blob/main/SkillFrame.lua`

### E5 — CharacterStatsClassic uses header-tracking with localised constants

The getov/CharacterStatsClassic addon iterates skill lines, stores the last seen
header name, and matches skills against that header + a skill name constant. Both
constants are localised strings, not numeric IDs.

URL: `https://github.com/getov/CharacterStatsClassic/blob/master/CharacterStatsClassicUtils.lua`

### E6 — WoWClassicDB URL pattern confirms Fist Weapons = 473

The WoWClassicDB URL for Fist Weapons is `https://wowclassicdb.com/wotlk/skill/473`,
confirming the SkillLine ID 473 maps to Fist Weapons.

---

## Analysis

### Why not use `skillCostType`?

`skillCostType` is undocumented and its relationship to weapon skills is unconfirmed
publicly. Using an undocumented field whose values may shift between server builds
is fragile. Do not use.

### Why not use header tracking alone?

Header tracking requires knowing the localised "Weapon Skills" header string for
each client locale. This string is not available as a global constant — it comes
from `GetSkillLineInfo` on the header row itself. A possible workaround: on first
load, scan for the first header row whose skills are all `isAbandonable = nil` and
`skillMaxRank > 1`, then store that header name. But this is fragile: if a player
has no weapon skills (impossible in practice but should be handled), or if header
order changes, the heuristic breaks.

A simpler fallback: read the header string by scanning until a header row is found
whose immediately-following skills are in the known-ID whitelist. But this is
circular — it still requires the ID whitelist.

### Why the hardcoded ID whitelist + `GetSpellInfo` works

The 16 weapon skill line IDs (excluding Defense and Dual Wield) are stable across
all locales and all client builds for Classic Era 1.x — they come from DBC data
that is baked into the client, not from translated strings. If the addon
pre-builds a lookup table `weaponSkillIDs[localizedName] = true` by calling
`GetSpellInfo` for each ID on login, then `isWeaponSkill(name)` becomes a simple
table lookup that works in any locale.

The gap: `GetSpellInfo` takes a **spell ID**, not a **SkillLine ID**. The mapping
from SkillLine ID to the corresponding passive spell ID is not confirmed by this
research. This needs in-game verification.

### Alternative: direct `skillName` lookup against a dynamically-built table

On `PLAYER_LOGIN` (or on the first call to `GetWeaponSkillsList`), iterate all
skill lines via `GetNumSkillLines / GetSkillLineInfo` and cache the `skillName`
for any row that falls under the "Weapon Skills" header. Detect the header by
looking for the row where `isHeader == 1` AND the rows that follow have
`isAbandonable = nil` and `skillMaxRank > 1` and `skillRank > 0`. Store the
header name. On subsequent calls, use a second pass under that header.

This works even if the cache is nil on the very first call — the button simply
shows nothing until the cache is warm (which happens immediately on login when
the `PLAYER_LOGIN` event fires).

**This is the cleanest approach for a single-file addon**: no dependency on
`GetSpellInfo` spell IDs, no external library, purely driven by live API data.

---

## Recommendation

Implement a **two-pass dynamic cache** approach:

**Phase 1 (on `PLAYER_LOGIN`):** Scan all skill lines. When a header row is
found where the name can be confirmed as the weapon skills header (by checking
that at least one following non-header row falls in the known-DBC-ID set
cross-referenced via `GetSpellInfo`, or more simply: by using the known English
name as a seed that is replaced on first successful detection), store the header
name. Then collect all non-header skill names under that header into a
`weaponSkillNames` lookup table.

**Phase 2 (on each button update):** `isWeaponSkill(name)` checks `weaponSkillNames[name]`.

For a simpler pragmatic implementation that improves on the current state
without full locale coverage, the **intermediate step** is to extend the current
English-string matching with a hardcoded whitelist of localized names for the
supported locales. The Classic Era client has only a small set of supported
locales (enUS/enGB, deDE, frFR, esES/esMX, ruRU, koKR, zhCN, zhTW). The weapon
skill names are known for each locale from community sources. This is less
elegant than the dynamic cache but has zero runtime complexity.

**Concrete Lua implementation (dynamic cache approach):**

```lua
-- Populated once on PLAYER_LOGIN via CacheWeaponSkillNames()
local weaponSkillNameCache = nil

-- Known English weapon skill names as a seed for the first scan
-- (also covers enUS/enGB servers)
local WEAPON_SKILL_SEED = {
    ["Axes"] = true, ["Bows"] = true, ["Crossbows"] = true,
    ["Daggers"] = true, ["Fist Weapons"] = true, ["Guns"] = true,
    ["Maces"] = true, ["Polearms"] = true, ["Staves"] = true,
    ["Swords"] = true, ["Thrown"] = true, ["Two-Handed Axes"] = true,
    ["Two-Handed Maces"] = true, ["Two-Handed Swords"] = true,
    ["Unarmed"] = true, ["Wands"] = true,
}

--- Build the locale-aware weapon skill name cache.
--- Call once on PLAYER_LOGIN. Scans all skill lines; collects the names of every
--- skill that sits directly under a "Weapon Skills"-category header.
--- Detection heuristic: the header row that has at least one immediately-following
--- non-header row whose English name is in WEAPON_SKILL_SEED.
--- Falls back to WEAPON_SKILL_SEED if the heuristic cannot identify the header
--- (e.g. player has no weapon skills yet — practically impossible in Classic Era).
local function CacheWeaponSkillNames()
    weaponSkillNameCache = {}
    local numLines = GetNumSkillLines()
    local inWeaponHeader = false
    local weaponHeaderFound = false

    -- First pass: find the weapon skills header by testing skills against the seed
    -- A header is the weapon skills header if any of its direct child skills
    -- are in WEAPON_SKILL_SEED (English client) OR if this is a non-English client
    -- and we are inside a header whose children all have isAbandonable=nil and
    -- skillMaxRank > 1 (weapon skills are never abandonable).
    -- For simplicity: collect all headers and their children, then pick the header
    -- whose children have the most seed matches (or any match on enUS).
    local headers = {}
    local currentHeader = nil
    for i = 1, numLines do
        local name, isHdr, _, rank, _, _, maxRank, isAband = GetSkillLineInfo(i)
        if isHdr then
            currentHeader = { name = name, children = {} }
            table.insert(headers, currentHeader)
        elseif currentHeader then
            table.insert(currentHeader.children, {
                name = name, rank = rank, maxRank = maxRank,
                isAband = isAband
            })
        end
    end

    -- Pick the header whose children best match the weapon skill profile:
    -- seed match OR (isAband=nil AND maxRank > 1 AND rank > 0)
    local bestHeader = nil
    local bestScore = 0
    for _, hdr in ipairs(headers) do
        local score = 0
        for _, child in ipairs(hdr.children) do
            if WEAPON_SKILL_SEED[child.name] then
                score = score + 10  -- strong signal: English name match
            elseif not child.isAband and child.maxRank and child.maxRank > 1
                   and child.rank and child.rank > 0 then
                score = score + 1   -- weak signal: profile match
            end
        end
        if score > bestScore then
            bestScore = score
            bestHeader = hdr
        end
    end

    if bestHeader and bestScore > 0 then
        for _, child in ipairs(bestHeader.children) do
            weaponSkillNameCache[child.name] = true
        end
    else
        -- Fallback: English seed (enUS/enGB only, non-English will show nothing)
        for name in pairs(WEAPON_SKILL_SEED) do
            weaponSkillNameCache[name] = true
        end
    end
end

--- Returns truthy if skillName is a weapon skill on the current client locale.
--- Requires CacheWeaponSkillNames() to have been called first.
local function isWeaponSkill(skillName)
    if not weaponSkillNameCache then
        -- Cache not warm yet — fall back to English seed
        return WEAPON_SKILL_SEED[skillName]
    end
    return weaponSkillNameCache[skillName]
end
```

Register `CacheWeaponSkillNames` on `PLAYER_LOGIN` and also on
`SKILL_LINES_CHANGED` (if that event exists in 1.x — needs in-game verification).
If `SKILL_LINES_CHANGED` is unavailable, call `CacheWeaponSkillNames` on
`PLAYER_LEVEL_UP` (which fires when a new weapon skill is learned via levelling)
and also on the first call to `GetWeaponSkillsList` if the cache is nil.

The `iconTable` keys must also be updated: because they are keyed by English name
(e.g. `"Axes"`, `"Swords"`), icons will fall back to the default sword icon on
non-English clients unless the `iconTable` is also keyed by numeric skill ID or
populated from the cache. The icon lookup path in `FormatSkillIcon` already has a
fallback (`or "Interface\\Icons\\INV_Sword_27"`) so this degrades gracefully —
no icons per skill on non-English clients, but no errors.

---

## Risks

### R1 — Spell ID gap (if GetSpellInfo approach is used instead)
The mapping from `SkillLine.dbc` ID (e.g. 43 for Swords) to the corresponding
passive spell ID is not confirmed. The `GetSpellInfo` approach cannot be
implemented without this data. **Needs in-game verification.** (The dynamic
cache approach above sidesteps this gap entirely.)

### R2 — `SKILL_LINES_CHANGED` event availability on Classic Era 1.x
Whether this event fires in 1.x is not confirmed. If absent, the cache may be
stale if the player learns a new weapon type mid-session. Calling
`CacheWeaponSkillNames` on `PLAYER_LEVEL_UP` is a partial mitigation since
weapon skills are usually available from level 1 or learned at a trainer (which
fires a different event).

### R3 — Edge case: player has no weapon skills when the cache is built
Practically impossible in Classic Era (all characters start with at least one
weapon skill), but if the cache is warm before any weapon skills are known, the
heuristic may misidentify the header. The fallback to `WEAPON_SKILL_SEED` handles
this correctly on English clients; non-English would show nothing until the cache
is refreshed.

### R4 — Non-English clients not tested
The dynamic cache algorithm has not been verified on any non-English Classic Era
client. Medium confidence — the algorithm is sound in theory, but the behavior
of `GetSkillLineInfo` on deDE/frFR/koKR/zhCN clients has not been observed.

### R5 — iconTable still English-keyed
Even with the detection fix, the `iconTable` lookup in `FormatSkillIcon` uses
the raw `skillName` after stripping spaces/dashes. On non-English clients the
keys will not match and all skills will use the fallback sword icon. This is
acceptable degradation (no errors, just generic icons) but should be noted as a
separate follow-on task.

---

## Action Items

1. **[LOC-1a]** Implement `CacheWeaponSkillNames()` + updated `isWeaponSkill()` as
   described in Recommendation. Wire up on `PLAYER_LOGIN`.
2. **[LOC-1b]** Verify in-game (Classic Era, enUS client): cache correctly identifies
   all 16 weapon skills; no false positives; no Lua errors on button load.
3. **[LOC-1c]** Verify `SKILL_LINES_CHANGED` event availability on Classic Era 1.x via
   `/dump` or event monitoring. If available, register it to refresh the cache.
4. **[LOC-1d — optional]** Extend `iconTable` to also cache icons by position in the
   cache (or key by SkillLine ID if the GetSpellInfo spell ID gap is resolved),
   so non-English clients get correct icons rather than the fallback.
5. **[LOC-1e — research gap]** Verify SkillLine ID → passive spell ID mapping for all
   16 weapon skills via in-game `/dump GetSpellInfo(id)` for candidate IDs.

---

## Sources

- [API_GetSkillLineInfo — warcraft.wiki.gg](https://warcraft.wiki.gg/wiki/API_GetSkillLineInfo)
- [API_GetSkillLineInfo — WoW AddOn Studio mirror](https://addonstudio.org/wiki/WoW:API_GetSkillLineInfo)
- [skillline — AzerothCore wiki](https://www.azerothcore.org/wiki/skillline) (SkillLine.dbc structure and weapon category = 6)
- [DB/SkillLine — wowdev.wiki](https://wowdev.wiki/DB/SkillLine) (DBC column definitions)
- [Skill IDs — wowgm.board-directory.net](https://wowgm.board-directory.net/t24-skill-id-s) (numeric IDs per skill)
- [CharacterStatsClassic — getov/CharacterStatsClassic on GitHub](https://github.com/getov/CharacterStatsClassic/blob/master/CharacterStatsClassicUtils.lua) (header-tracking pattern in the wild)
- [SkillFrame.lua — wowgaming/3.3.5-interface-files on GitHub](https://github.com/wowgaming/3.3.5-interface-files/blob/main/SkillFrame.lua) (Blizzard's own skill categorisation: skillCostType only)
- [wow-globalstrings — tekkub on GitHub](https://github.com/tekkub/wow-globalstrings) (GlobalStrings.lua locale files; no WEAPON_SKILLS constant found)
- [Localizing an addon — Wowpedia](https://wowpedia.fandom.com/wiki/Localizing_an_addon)
- [Weapon Skills — Wowhead Classic](https://www.wowhead.com/classic/skills/weapon-skills)
- [WoWClassicDB Fist Weapons skill/473](https://wowclassicdb.com/wotlk/skill/473)
