# Changelog

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
