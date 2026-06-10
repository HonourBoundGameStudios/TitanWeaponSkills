# Smoke Checklist — manual in-game verification

> The WoW client is the test runner. After any change, run the rows touching the
> changed surface; before any CurseForge release, run **all** rows on Classic Era
> (and ideally confirm a clean load on retail). Enable error display first:
> `/console scriptErrors 1`.
>
> Every new feature adds a row here before it ships. Every bug fix adds its
> reproduction step here so it can't regress silently.

## Load & lifecycle

| # | Step | Expected |
|---|---|---|
| L1 | Fresh login with addon enabled | No Lua errors; Titan bar shows the Weapon Skills button with the character's learned weapon skills |
| L2 | `/reload` | No Lua errors; button still present with the same text |
| L3 | Hover the Titan button | Tooltip lists each weapon skill vertically: icon, name, colored `rank/max` |
| L4 | Character with unlearned/rank-0 skills | Those skills do not appear on the button or tooltip |

## Display & rank colors

| # | Step | Expected |
|---|---|---|
| D1 | Bar entry format | `[icon] [Name:] rank/max` per skill, separated by spaces; tooltip uses one line per skill with tab indent |
| D2 | A maxed skill (rank == max, i.e. level×5) | Rank **and** the `/max` part render green |
| D3 | A skill ≥ 90% of max | Rank renders yellow, `/max` light grey |
| D4 | A skill ≥ 80% of max | Rank renders orange, `/max` light grey |
| D5 | A skill < 80% of max | Rank renders red, `/max` light grey |
| D6 | Tooltip with Skill Labels / Skill Icons toggled **off** | Tooltip still shows labels and icons (vertical mode forces them); only the bar respects the toggles |

## Right-click menu & settings

| # | Step | Expected |
|---|---|---|
| M1 | Right-click the Titan button | Menu shows: Skill Labels, Skill Icons, Large Skill Icons, Audio Notification, then Toggle Icon, Toggle Right Side, Hide |
| M2 | Toggle **Skill Labels** | Names disappear/reappear on the bar immediately; menu stays open |
| M3 | Toggle **Skill Icons** | Icons disappear/reappear on the bar immediately |
| M4 | Toggle **Large Skill Icons** | Icons switch between 24px and 16px |
| M5 | Toggle any setting, `/reload` | The setting persists (Titan savedVariables) |
| M6 | Hide via the menu, re-enable from Titan's plugin list | Plugin returns without error, settings intact |

## Events

| # | Step | Expected |
|---|---|---|
| E1 | Level a weapon skill (hit a training dummy/mob with an unlevelled weapon) | Button text updates with the new rank; notification sound plays |
| E2 | Same, with **Audio Notification** off | Button still updates; no sound |
| E3 | Level up the character | Button updates — every skill's `/max` increases by 5 and colors re-evaluate |
