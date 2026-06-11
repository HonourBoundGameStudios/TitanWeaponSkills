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
- [x] **[PROC-2] Baseline smoke pass** — full `SmokeChecklist.md` run in-game on Classic Era, all rows pass; baseline confirmed 2026-06-11

## Epic 1 — Hygiene & Robustness

Make the existing behaviour solid before adding new behaviour.
*(Items below are proposals — confirm before working them.)*

- [x] **[HYG-1] SavedVariables clobber** — removed the dead `TitanWeaponSkillsSaved = {}` global: never declared in the `.toc`, never read, so Blizzard never persisted it; Titan's registry `savedVariables` is the real persistence. GREEN in-game on Classic Era (L1–L3, M5) 2026-06-10.
- [x] **[HYG-2] Global namespace cleanup** — all formatters and display pipeline functions were already `local`; callbacks correctly prefixed `TitanWeaponSkills_*`; Global Name Registry in CLAUDE.md already reflects this. Confirmed pre-process, closed 2026-06-11.
- ~~**[FLAV-1] Research: skill-line APIs per flavor**~~ — *Jettisoned 2026-06-11: addon is Classic Era only; `.toc` declares only `11508`. Research doc preserved at `Research/skill-line-api-reference.md`.*
- [ ] **[LOC-1] Research: locale-independent skill detection** — `isWeaponSkill()` matches English substrings and `iconTable` is keyed by English names; non-English clients show nothing. Find a locale-independent key (skill IDs? spell IDs?) before any matching rework. (`Research/weapon-skill-detection-research.md`)

## Epic 2 — Display Quality of Life

*(Ideas — promote and confirm before working.)*

- [ ] **[QOL-1] Hide maxed skills option** — menu toggle: once a skill is at `level×5`, drop it from the bar (tooltip keeps everything)
- [ ] **[QOL-2] Equipped-weapons-only option** — show only the skills for currently equipped weapon types
- [ ] **[QOL-3] Per-skill visibility** — submenu to hide individual skills
- [ ] **[QOL-4] Sound selection** — choose the skill-up notification sound instead of hardcoded WISP (6518)

## Epic 3 — Release Quality

- ~~**[REL-1] Multi-flavor verification pass**~~ — *Jettisoned 2026-06-11: Classic Era only; no other flavors to verify.*
- [ ] **[REL-2] CurseForge release** — CHANGELOG entry, `.toc` version bump, tag-driven release via the existing GitHub workflow

## Parked / Ideas

- Skill-up progress estimation ("~40 hits to next point" — needs research on skill-up chance formulas)
- Character-specific settings (Titan supports per-character saved vars)
