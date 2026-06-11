# Skill-Line API Reference: GetNumSkillLines / GetSkillLineInfo — Flavor Availability

**Date:** 2026-06-11
**Author:** Research Agent
**Status:** Draft
**Confidence:** Medium (wiki-sourced and source-corroborated; not personally verified in-game on Cataclysm Classic or retail — maximum confidence without live `/dump` runs is Medium per the research process)
**Flavors verified:** Classic Era 1.x (present), Cataclysm Classic 4.x (absent — removed in 4.0.1), Retail 11.x (absent — removed in 4.0.1)

---

## Executive Summary

`GetNumSkillLines` and `GetSkillLineInfo` exist **only on Classic Era 1.x** (and Mists of Pandaria Classic, which is not a target of this addon). Both functions were removed in Patch 4.0.1 (the Cataclysm launch patch). They do not exist on Cataclysm Classic 4.x or retail 11.x. Calling either function on those flavors would attempt to call `nil`, which in Lua produces a runtime error that will silently kill the button's display pipeline.

The lightest-weight guard is a single module-level constant computed once at load time using `WOW_PROJECT_ID`. If the constant is not `WOW_PROJECT_CLASSIC`, `GetWeaponSkillsList` returns `""` immediately, producing a silent empty button on non-Era clients. No API calls are made on flavors where the API does not exist.

---

## Research Question

Do `GetNumSkillLines` and `GetSkillLineInfo` exist on retail 11.x and Cataclysm Classic 4.x? What do they return there? What is the minimum guard needed so the addon degrades to an empty/silent button on non-Era flavors instead of erroring?

This unblocks backlog item **[FLAV-1]** (multi-flavor graceful degradation).

---

## Constraints

- The addon ships a single `.toc` with `## Interface: 110105, 40402, 11508` — the same Lua file loads on all three flavors.
- Weapon skills as a game mechanic were removed in Patch 4.0.1, so Cataclysm Classic 4.x and retail 11.x will never have weapon skill data to show. The desired UX on those flavors is a silent empty button (no text, no Lua errors).
- The guard must not introduce a new global, must not break the Titan Panel plugin registration lifecycle, and must add minimal code.
- No build system; the WoW client is the test runner.

---

## Findings

1. **`GetNumSkillLines` is absent on Cataclysm Classic and retail.** The function was added in patch 1.0.0/1.13.2 and removed in Patch 4.0.1. It does not exist in any 4.x or 11.x client. Calling it on those flavors produces `attempt to call a nil value`.

2. **`GetSkillLineInfo` is absent on Cataclysm Classic and retail.** Same removal point: Patch 4.0.1. It does not exist in any 4.x or 11.x client.

3. **Both functions do exist on Classic Era 1.x** and on Mists Classic (which is not a target of this addon). Their behavior is well-defined and is what the current addon code already relies on.

4. **`WOW_PROJECT_ID` is the canonical flavor-detection constant.** It is defined in Blizzard's `BNet.lua` across all clients. The relevant constants and numeric values are:

   | Constant | Value | Flavor |
   |---|---|---|
   | `WOW_PROJECT_MAINLINE` | 1 | Retail 11.x |
   | `WOW_PROJECT_CLASSIC` | 2 | Classic Era 1.x |
   | `WOW_PROJECT_BURNING_CRUSADE_CLASSIC` | 5 | TBC Classic |
   | `WOW_PROJECT_WRATH_CLASSIC` | 11 | Wrath Classic |
   | `WOW_PROJECT_CATACLYSM_CLASSIC` | 14 | Cataclysm Classic 4.x |
   | `WOW_PROJECT_MISTS_CLASSIC` | 19 | Mists Classic |

5. **`WOW_PROJECT_CLASSIC` (value 2) is the only constant that identifies Classic Era 1.x.** The 20th Anniversary re-release of Classic also maps to this constant.

6. **Alternative flavor-detection via `select(4, GetBuildInfo())`** returns the integer interface version (e.g. `11508` for Classic Era, `40402` for Cata Classic, `110105` for retail). This approach works but is version-number fragile — ranges need updating as patches land. `WOW_PROJECT_ID` is the community-recommended approach for flavor gating, not version ranges.

7. **`GetProfessions` / `GetProfessionInfo`** are the Cataclysm replacements (added in Patch 4.0.1) for the old skill-line APIs, but they cover only professions — not weapon skills, which were removed from the game entirely in that same patch. There is no equivalent weapon-skill API on Cata or retail.

---

## Evidence

| Finding | Source | Flavor | Notes |
|---|---|---|---|
| `GetNumSkillLines` removed in 4.0.1 | warcraft.wiki.gg/wiki/API_GetNumSkillLines | All | "Removed in Patch 4.0.1"; availability listed as "Mists Classic and Classic Era" only |
| `GetSkillLineInfo` removed in 4.0.1 | warcraft.wiki.gg/wiki/API_GetSkillLineInfo | All | "This API only exists in Mists Classic and Classic Era"; removed in 4.0.1 |
| `GetSkillLineInfo` returns 13 values | warcraft.wiki.gg/wiki/API_GetSkillLineInfo | Classic Era | skillName, header, isExpanded, skillRank, numTempPoints, skillModifier, skillMaxRank, isAbandonable, stepCost, rankCost, minLevel, skillCostType, skillDescription |
| `WOW_PROJECT_ID` constants and values | warcraft.wiki.gg/wiki/WOW_PROJECT_ID | All | `WOW_PROJECT_CLASSIC = 2`, `WOW_PROJECT_CATACLYSM_CLASSIC = 14`, `WOW_PROJECT_MAINLINE = 1` |
| `WOW_PROJECT_ID` recommended for flavor detection | warcraft.wiki.gg/wiki/Porting_addons_to_Classic | All | "local isClassic = (WOW_PROJECT_ID == WOW_PROJECT_CLASSIC)" |
| `GetProfessions`/`GetProfessionInfo` are the 4.0.1 replacements | warcraft.wiki.gg/wiki/API_GetProfessionInfo | Cata/Retail | Cover only professions; no weapon-skill equivalent exists |
| `.toc` interface versions for this addon | `TitanWeaponSkills.toc` line 1 | All | `110105` (retail), `40402` (Cata Classic), `11508` (Classic Era) |

**Confidence note:** The warcraft.wiki.gg API pages carry explicit flavor-availability banners ("only exists in Mists Classic and Classic Era") that are editorially maintained and generally reliable. The removal in 4.0.1 is also consistent across both Wowpedia and warcraft.wiki.gg. However, this has not been personally verified via in-game `/dump GetNumSkillLines` on a live Cata Classic or retail client; confidence is therefore capped at Medium per the project's research process.

---

## Analysis

### Why calling the API on non-Era clients would error

In Lua, calling `nil` as a function produces a fatal runtime error: `attempt to call a nil value (global 'GetNumSkillLines')`. The WoW client catches this and prints a Lua error to the chat frame, and the function that triggered it returns nothing. In the display pipeline this means `GetWeaponSkillsList` throws before returning, `TitanWeaponSkills_GetButtonText` propagates the error, and Titan Panel's button-update cycle may produce repeated error spam.

### Why a module-level constant is preferable to a per-call nil-check

Two guard shapes are possible:

**Option A — nil-check inside `GetWeaponSkillsList`:**
```lua
local numSkills = GetNumSkillLines and GetNumSkillLines() or 0
```
This works but performs the nil-check on every button redraw (every `CHAT_MSG_SKILL`, `PLAYER_LEVEL_UP`, and tooltip hover). It also leaves the question unanswered at module load time, which is the right place for a load-time invariant.

**Option B — module-level constant (preferred):**
```lua
local IS_CLASSIC_ERA = (WOW_PROJECT_ID == WOW_PROJECT_CLASSIC)
```
Set once at module load. `GetWeaponSkillsList` returns `""` immediately if `not IS_CLASSIC_ERA`. The check cost is negligible and the intent is explicit. The constant name is readable and matches the idiom used across the WoW addon ecosystem.

Option B is preferred: it communicates intent at the top of the file (readers immediately understand the addon is Era-only for data), it is evaluated once, and it matches the pattern the warcraft.wiki.gg porting guide explicitly recommends.

### Why `WOW_PROJECT_ID` over interface-version ranges

`select(4, GetBuildInfo())` returns a version integer that must be compared against ranges (e.g. `>= 11000` for retail). Ranges are fragile: each patch bumps the number, and the addon's `.toc` `## Interface:` line already lists specific version integers that would need updating in two places. `WOW_PROJECT_ID` is a named constant that is stable across patches within a flavor and is the explicitly recommended approach for per-flavor feature gating.

---

## Recommendation

Add a single module-level constant near the top of `TitanWeaponSkills.lua`, after the existing constants block, and add an early-return guard in `GetWeaponSkillsList`:

```lua
-- Weapon skills exist only on Classic Era. Guard against calling the
-- skill-line API on Cata Classic (4.x) or retail (11.x), where
-- GetNumSkillLines and GetSkillLineInfo were removed in patch 4.0.1.
local IS_CLASSIC_ERA = (WOW_PROJECT_ID == WOW_PROJECT_CLASSIC)
```

Then at the top of `GetWeaponSkillsList`:

```lua
local function GetWeaponSkillsList(verticalAlignment)
    if not IS_CLASSIC_ERA then
        return ""
    end

    local allSkillsTable = {}
    local numSkills = GetNumSkillLines()
    -- ... rest unchanged ...
end
```

This is the complete guard. No other changes are needed. On Classic Era the behavior is identical to today. On Cataclysm Classic and retail the button text and tooltip text functions return `""` without calling any missing APIs — Titan Panel renders this as an empty or icon-only button.

---

## Risks

| Risk | Likelihood | Severity | Mitigation |
|---|---|---|---|
| `WOW_PROJECT_CLASSIC` constant not defined on some client build | Low | High | The constant is set in Blizzard's `BNet.lua`, which ships with every client. If somehow absent, `WOW_PROJECT_ID == WOW_PROJECT_CLASSIC` evaluates to `false` (nil == nil is true, but `WOW_PROJECT_ID == nil` is not `WOW_PROJECT_CLASSIC` — actually both would be nil and equal). Add a belt-and-suspenders nil check if paranoid: `local IS_CLASSIC_ERA = WOW_PROJECT_CLASSIC and (WOW_PROJECT_ID == WOW_PROJECT_CLASSIC) or false` |
| Classic Era 20th Anniversary maps to a different `WOW_PROJECT_ID` | Low | Medium | Wiki confirms Anniversary Classic maps to `WOW_PROJECT_CLASSIC = 2`, same as original Classic Era. Verify with `/dump WOW_PROJECT_ID` if 20th Anniversary support is needed. |
| Mists Classic also passes the guard | None for now | Low | Mists Classic maps to `WOW_PROJECT_MISTS_CLASSIC = 19`, not `WOW_PROJECT_CLASSIC = 2`, so it will correctly get `IS_CLASSIC_ERA = false`. Weapon skills do exist in the Mists Classic client — if the addon ever targets MoP Classic, a separate constant and `.toc` entry would be needed. |
| Wiki page is stale / incorrect | Low | High | Both warcraft.wiki.gg pages carry explicit flavor-availability banners, are internally consistent, and agree with the known game history (weapon skills removed in 4.0.1). Verify in-game before the FLAV-1 item is closed. |

---

## Action Items

- [ ] **[FLAV-1 implementation]** Add `IS_CLASSIC_ERA` constant and `GetWeaponSkillsList` early-return guard as shown in Recommendation.
- [ ] **[FLAV-1 verify]** Deploy to Classic Era client, confirm button still shows correctly (`/reload` + smoke test).
- [ ] **[FLAV-1 verify]** Verify GREEN on Cataclysm Classic 4.x client: button loads without Lua errors, shows empty/icon-only. Use `/dump WOW_PROJECT_ID` to confirm constant is `14` (`WOW_PROJECT_CATACLYSM_CLASSIC`).
- [ ] **[FLAV-1 verify]** Verify GREEN on retail 11.x client: same — no Lua errors, empty button. `/dump WOW_PROJECT_ID` should return `1` (`WOW_PROJECT_MAINLINE`).
- [ ] **[Confidence upgrade]** Once verified in-game on all three flavors, promote Status to Final and Confidence to High.
- [ ] **[CLAUDE.md]** Add research table row (see note at end of this document).

---

## Sources

1. [warcraft.wiki.gg — API GetNumSkillLines](https://warcraft.wiki.gg/wiki/API_GetNumSkillLines) — primary; flavor availability banner, return value, removal patch.
2. [warcraft.wiki.gg — API GetSkillLineInfo](https://warcraft.wiki.gg/wiki/API_GetSkillLineInfo) — primary; flavor availability banner, 13 return values, removal patch.
3. [warcraft.wiki.gg — WOW_PROJECT_ID](https://warcraft.wiki.gg/wiki/WOW_PROJECT_ID) — constant table with numeric values for all flavors.
4. [warcraft.wiki.gg — Porting addons to Classic](https://warcraft.wiki.gg/wiki/Porting_addons_to_Classic) — recommended `WOW_PROJECT_ID` detection idiom.
5. [warcraft.wiki.gg — API GetProfessionInfo](https://warcraft.wiki.gg/wiki/API_GetProfessionInfo) — confirms Cata-era profession replacement APIs; confirms no weapon-skill equivalent.
6. [warcraft.wiki.gg — Getting the current interface number](https://warcraft.wiki.gg/wiki/Getting_the_current_interface_number) — `GetBuildInfo` approach documentation.
