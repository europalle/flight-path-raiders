# Decision log

Decisions made by the Game Director. Newest first.

| Date | Area | Decision |
| --- | --- | --- |
| 2026-11-18 | Phase 2 | Design document signed off by the Director; deliverable 2 starts with UX wireframes |
| 2026-11-18 | Tuning audit | Appendix A approved and applied: ~40 gold per activity (~625/h in the air), Lockout Loot on Normal, keystone DKP capped at 50/week, repairs 1 gold per 5 gear levels per death (x1.5 wipe), Efficient Kill rounds bonus replaces the speed bonus, Ragnaroast every 4 rounds, raid-wide cauldrons, new gear ladder (gates 50/58/66), morale gains and drift, softer trait drains, bench XP 50% |
| 2026-11-18 | Normal re-clears | XP plus 5 gold per boss (Tuning and Design) |
| 2026-11-18 | Ranked morale | Morale power bonus off in Heroic and Mythic; ranked records carry trait snapshots (team decision, delegated) |
| 2026-11-18 | Affixes | One base affix (Fortified Trash or Tyrannical Raid Leader) plus one weekly affix; affixes never depend on the characters brought |
| 2026-11-18 | Legendary | Bad-luck protection kept small: 2% base, +0.5 points per miss, cap 10% |
| 2026-11-18 | Studio | New department, UX/UI & Accessibility: owns flows, wireframes, readability and accessibility; wireframes come before art; can block on readability, Director breaks ties with Art |
| 2026-11-18 | Studio | New department, Game Tuning & Balancing: owns every number; balance data lives in `data/` and is read by both prototype and addon |
| 2026-11-18 | Bosses | Names are close puns on the originals: The Molten Bore (Magmadad, Baron Get-Down, Lucifrown, Majordomo Exhaustus, Ragnaroast), Onyxiety's Lair; dungeons The Deadlines, Gnomeregret, Scarlet Monotony |
| 2026-11-18 | Loot | WoW-style items with seeded random stats: quality tiers, random suffixes, named epics, 3-piece tier sets, one legendary per raid with a quest chain |
| 2026-11-18 | Attunements | Classic-style attunement chains gate Heroic and Mythic; the guild is attuned once, each character needs one catch-up run |
| 2026-11-18 | Traits | Edgier traits approved (Parse Goblin, Alt-Tabbed, Partner Aggro, Rage Quitter and more); morale and quitting kept |
| 2026-11-18 | Economy | Priced in hours of play at level 60 (about 550-650 gold per hour); legendary recruit 8,000 gold and 1% of tavern offers |
| 2026-11-18 | Ground play | Allowed, with the Frequent Flyer bonus for activities started in the air |
| 2026-11-18 | Easter egg | In a guild named LFR the always-pulling tank appears as Happy Aggroholic |
| 2026-11-18 | Hall of shame | On for everyone, no opt-out |
| 2026-11-18 | Expansions | The level cap rises only with expansions; each expansion ships with a pre-release event, like the real game; expansion classes arrive with expansions |
| 2026-11-18 | Naming | The recruitable units are called "characters" (not raiders); daily tasks are called "quests" (not bounties) |
| 2026-11-18 | Levels | Max level 60, Classic style; levelling 1-60 in about 20-25 flights; keystones need level 60, Raid Normal average character level 58; dungeons scale to group level; seasons never raise the cap |
| 2026-11-18 | Licence | Code GPL-3.0, art CC BY-NC-SA 4.0 (Production, on the Director's delegation). Purely AI-generated art may not be copyrightable in some countries; human edits strengthen the art licence |
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
| 2026-11-17 | Content | Dungeons, keystone dungeons with weekly affixes, daily quests, Normal raid unlimited, Heroic and Mythic one ranked run per lockout, persistent roster, guild hall, seasons |
| 2026-11-17 | Modes | Normal, Heroic, Mythic; kills saved per boss across the weekly lockout, one boss per flight |
| 2026-11-17 | Bosses | Original parodies, as close to WoW as is safe: no Blizzard names, art, logos, voice lines or exact ability names |
| 2026-11-17 | Audience | Public release; leaderboards per guild |
| 2026-11-17 | Title | Working title: Flight Path Raiders |

## Verified on the live client (2026-11-17)

- `C_ChatInfo`, `C_ChatInfo.SendAddonMessage` and `C_Timer` exist
- `UnitOnTaxi("player")` returns true in flight
- Interface number is `16001`

Still to verify: addon message throttle limits and size cap on Forever.
