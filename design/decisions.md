# Decision log

Decisions made by the Game Director. Newest first.

| Date | Area | Decision |
| --- | --- | --- |
| 2026-11-18 | Levels | Max level 60, Classic style; levelling 1-60 in about 20-25 flights; keystones need level 60, Raid Normal average level 58; dungeons scale to group level; seasons never raise the cap |
| 2026-11-18 | Licence | All rights reserved during development; final licence decided before beta (Production leans GPL-3.0 code, CC BY-NC-SA 4.0 art) - pending Director confirmation |
| 2026-11-17 | Workspace | Code, art and prototype live in this repository; design documents stay as Claude docs, linked from `design/README.md` |
| 2026-11-17 | Libraries | Use community libraries only where unavoidable; bundle them in the addon folder for a one-folder install |
| 2026-11-17 | Art | Direction: a battered raid-leader's notebook (sketched portraits, ink, coffee stains, tactical scribbles). Deliverables as SVG |
| 2026-11-17 | Language | English only at launch; all player-facing text kept in one file for later translation |
| 2026-11-17 | Tone | Wide and memey for a public audience, nice but not distasteful. No real people, no slurs, nothing sexual, no real-world tragedies |
| 2026-11-17 | Writing seeds | Rogues are the class everyone loves to hate; warlocks are rare; the tank who pulls before the healer has mana is an archetype (public name invented; guild easter egg only with consent) |
| 2026-11-17 | Clock | No thinking clock in PvE; ranked runs reward fast decisions instead |
| 2026-11-17 | Classes | All nine Classic classes at launch; expansion classes later |
| 2026-11-17 | Raid size | 10 raiders per pull; roster larger than the raid (working figure 15) |
| 2026-11-17 | Benching | Raiders who die are benched for poor performance for the rest of the lockout; the run continues with the bench |
| 2026-11-17 | Progression | Option B: ranked modes scale gear to a fixed level; content has entry gates (raider level, gear level); levelling and gearing are fast |
| 2026-11-17 | Content | Dungeons, keystone dungeons with weekly affixes, daily bounties, Normal raid unlimited, Heroic and Mythic one ranked run per lockout, persistent roster, guild hall, seasons |
| 2026-11-17 | Modes | Normal, Heroic, Mythic; kills saved per boss across the weekly lockout, one boss per flight |
| 2026-11-17 | Bosses | Original parodies, as close to WoW as is safe: no Blizzard names, art, logos, voice lines or exact ability names |
| 2026-11-17 | Audience | Public release; leaderboards per guild |
| 2026-11-17 | Title | Working title: Flight Path Raiders |

## Verified on the live client (2026-11-17)

- `C_ChatInfo`, `C_ChatInfo.SendAddonMessage` and `C_Timer` exist
- `UnitOnTaxi("player")` returns true in flight
- Interface number is `16001`

Still to verify: addon message throttle limits and size cap on Forever.
