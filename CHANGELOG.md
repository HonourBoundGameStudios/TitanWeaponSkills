# Changelog

## [1.3.0] - 2026-09-07

### Changed
- **Titan Panel is no longer required.** The addon publishes a LibDataBroker feed, so any LDB display can host it — Titan Panel (through its own LDB bridge), Bazooka, ElvUI DataTexts — and it ships a minimap button for players running no bar at all.
- **Renamed to Weapon Journey** (addon folder `WeaponJourney`): the old name implied a Titan prerequisite that no longer exists.
- Settings moved out of Titan's store into the addon's own saved variables. Existing toggles are imported automatically on first login; nothing to reconfigure.
- The right-click menu is now the addon's own (Blizzard's Menu API) and gained a "Show minimap button" toggle. The Titan-specific entries (Show Icon, Display on Right Side, Hide) are gone — those belong to the host display now.

### Added
- An offline test suite for the display logic (`Tests/`, run with a standalone Lua interpreter): rank colour thresholds, icon name-folding, list assembly, locale-independent skill detection, and the settings store.
- Empty-state text on the bar, so a character with no weapon skills shows a label instead of a blank gap.

### Fixed
- A skill line with no cap can no longer divide by zero while colouring its rank.
- Tooltip lines no longer show a stray box (missing-glyph) character between the skill name and its rank.

## [1.2.0] - 2026-07-22

### Added
- Locale-independent weapon skill detection — skill lines are now identified by stable SkillLine IDs, so the addon works on non-English clients
- Honour Bound Game Studios branding: an About popup and a tooltip footer

### Fixed
- Right-click menu migrated to the January 2026 `Titan_Menu` scheme (the old menu API had stopped opening)

### Changed
- Bumped Classic Era interface version to 11509

## [1.1.0] - 2026-05-24

### Added
- Right-click menu with plugin-specific toggles: Skill Labels, Skill Icons, Large Skill Icons, Audio Notification
- Audio notification toggle — play a sound when a weapon skill increases or on level up
- All toggle settings now persist across sessions via Titan Panel's saved variable system

### Fixed
- Right-click menu was not opening due to an undefined `OnClick` call in the button handler
- Toggle states now correctly read from and write to saved variables instead of being reset on every reload

## [1.0.1] - 2024-09-27

### Fixed
- Compatibility fix for the latest version of WoW Classic Era

## [1.0.0] - 2024-09-01

### Added
- Initial release
- Displays current weapon skill ranks on the Titan Panel bar
- Tooltip with full skill list on hover
- Color-coded ranks: green (maxed), yellow (≥90%), orange (≥80%), red (<80%)
- Per-skill icons on the bar and tooltip
- Toggle for large vs small skill icons
- Toggle for skill labels
- Sound notification on skill increase or level up
