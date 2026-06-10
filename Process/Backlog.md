# TitanWeaponSkills — Backlog

> Source of truth for what gets built and in what order. Rules (from
> `Process/WorkingWithClaude.md`): only work the next unchecked item, one item =
> one commit, mark `[x]` the moment it's committed — not before. Items that
> depend on unverified WoW APIs get a research spike first.

**The vision:** the cleanest weapon-skill tracker on the Titan bar — glanceable
proficiency at all times, zero noise once a skill is maxed, correct on every
client the `.toc` claims to support.

---

## Epic 0 — Process Bootstrap (2026-06-10)

Import the battle-tested collaboration process from TitanBgGeneral, flavored
for this project.

- [x] **[PROC-1] Process docs** — `Process/WorkingWithClaude.md`, `SmokeChecklist.md`, this backlog, `Research/RESEARCH-PROCESS.md`, `Design/` folder, CLAUDE.md wiring (2026-06-10)
- [ ] **[PROC-2] Baseline smoke pass** — full `SmokeChecklist.md` run in-game on Classic Era, all rows pass; capture `Design/current-bar-<date>.png` as the baseline screenshot

## Epic 1 — Hygiene & Robustness

Make the existing behaviour solid before adding new behaviour.
*(Items below are proposals — confirm before working them.)*

- [ ] **[HYG-1] SavedVariables clobber** — `TitanWeaponSkillsSaved = {}` overwrites any restored copy and the `.toc` `## SavedVariables:` line is empty, so the global is dead weight; either remove it or wire it properly (`or {}` + `.toc` declaration). Titan's registry `savedVariables` is the real persistence today.
- [ ] **[HYG-2] Global namespace cleanup** — `GetButtonText`/`GetTooltipText` are dangerously generic globals on a shared namespace; `FormatSkillRank`/`FormatSkillIcon`/`FormatSkillName`/`GetWeaponSkillsList`/`isWeaponSkill` don't need to be global at all (the registry takes function references). Localize/prefix, update the Global Name Registry in CLAUDE.md.
- [ ] **[FLAV-1] Research: skill-line APIs per flavor** — do `GetNumSkillLines`/`GetSkillLineInfo` exist on retail 11.x and Cata Classic 4.x, and what do they return there (weapon skills were removed in 4.0.1)? Guard accordingly so non-Era flavors degrade to an empty button instead of erroring. (`Research/skill-line-api-reference.md`)
- [ ] **[LOC-1] Research: locale-independent skill detection** — `isWeaponSkill()` matches English substrings and `iconTable` is keyed by English names; non-English clients show nothing. Find a locale-independent key (skill IDs? spell IDs?) before any matching rework. (`Research/weapon-skill-detection-research.md`)

## Epic 2 — Display Quality of Life

*(Ideas — promote and confirm before working.)*

- [ ] **[QOL-1] Hide maxed skills option** — menu toggle: once a skill is at `level×5`, drop it from the bar (tooltip keeps everything)
- [ ] **[QOL-2] Equipped-weapons-only option** — show only the skills for currently equipped weapon types
- [ ] **[QOL-3] Per-skill visibility** — submenu to hide individual skills
- [ ] **[QOL-4] Sound selection** — choose the skill-up notification sound instead of hardcoded WISP (6518)

## Epic 3 — Release Quality

- [ ] **[REL-1] Multi-flavor verification pass** — clean load on retail and Cata Classic with flavor guards from [FLAV-1]; full smoke checklist on Classic Era
- [ ] **[REL-2] CurseForge release** — CHANGELOG entry, `.toc` version bump, tag-driven release via the existing GitHub workflow

## Parked / Ideas

- Skill-up progress estimation ("~40 hits to next point" — needs research on skill-up chance formulas)
- Character-specific settings (Titan supports per-character saved vars)
