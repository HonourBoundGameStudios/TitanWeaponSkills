# Design/ — UI handoffs and mockups

Drop UI design handoffs here (mockups, layout sketches, icon choices, format
proposals) — e.g. exports from the Claude Design Tool or annotated screenshots.

**Check this folder before starting any UI work.**

Conventions for designs in this project:

- The addon must look **native to WoW** — Titan Panel templates, WoW escape
  sequences for color/icons, `Interface\Icons\…` textures (see
  `Process/WorkingWithClaude.md` §4).
- The plugin's surfaces are: the **bar button text**, the **tooltip**, and the
  **right-click menu**. A design handoff should specify, per surface: icon
  size, label format, separator, and the rank-color thresholds if they change.
- Screenshots of the current in-game state belong here too, named
  `current-<surface>-<date>.png`, so before/after is reviewable.
- The repo's `screenshots/` folder holds the **published marketing images**
  (CurseForge); working/baseline captures live here in `Design/`.
