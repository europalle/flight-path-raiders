# Decision log

Decisions made by the Game Director. Newest first.

| Date | Area | Decision |
| --- | --- | --- |
| 2026-11-18 | Production | Task tracking in GitHub Issues (labels for department and status, milestones per phase); STATUS.md is the session handoff file |
| 2026-11-18 | Design / Art | Shamans stay: dwarves can be shamans in WoW: Forever (Director). Two dwarf shaman looks, R11 and R12 |
| 2026-11-18 | Design / Art | Alliance only: human, dwarf, night elf, gnome with Classic class rules (replaces the all-races entry). Two looks per class; 10 R prompts. Shaman open: Classic Alliance had none |
| 2026-11-18 | Design / Art | Races with Classic's class restrictions, no factions, cosmetic for now; minotaur and undead as parody-safe names. Art covers 21 race and class looks (6 human + 15 new R prompts, men and women mixed). E3, E6, E9 retired (not Classic-legal) |
| 2026-11-18 | Art | Director likes Gemini's polished-but-janky WoW look (better than doodles); it is the character style. A2 slate and E7 mage rerun with v2 prompts; warlock flipped to face right |
| 2026-11-18 | Art / Design | Gear on characters: quality shimmer only (trim glow tinted by average quality, in code). Equipped weapon props later; no tier set looks for now |
| 2026-11-18 | Art | Reusable kit: neutral pieces tinted in code (SetVertexColor), 9-slice frames, frame plus glyph icons, state overlays, shared character template with separate props, generic tinted effects, layered stages. Prompt pack v2 replaces v1 |
| 2026-11-18 | Art | Style: A Field Journal is light mode, C Midnight Grimoire is dark mode. Direction: a hand-drawn parody of the WoW Classic UI (parchment quest log, dark slate frames), never copying Blizzard art. Assets come from Gemini via art/gemini-prompt-pack.md, on a magenta background; Art cleans, slices, recolours and edits every piece |
| 2026-11-18 | QA / Production | Solo development: playtests are solo; all guild interaction (sync, leaderboard, guildies) is simulated |
| 2026-11-18 | Tuning | Guild Bank unlock costs 150 DKP like other guild hall buildings; only Tab 2 costs gold |
| 2026-11-18 | UX / Art | Roster, Tavern and Guild Hall mid-fi wireframes; character study accepted as the style bar; three style tiles for the Director to choose from |
| 2026-11-18 | Studio | New departments: Audio, Marketing & Community, Legal & Compliance; Player Research is a QA subdivision writing playtests for the Director. Milestone reviews run as separate, fresh agents |
| 2026-11-18 | Art | Director: stage sketch v1 too simple ("3rd grader"). Composition (ground plane, rows, walk-off) kept; Art raises the bar with an ink-and-wash character study before style tiles |
| 2026-11-18 | Production | No launch date and no cuts: the game launches when the Director is happy. The milestone plan uses quality gates, not dates |
| 2026-11-18 | Design / Tuning | Specs: three Classic specs per class (27), each sets role, one signature passive and stat priorities; no talent trees. Within ±5% of role average; meme specs viable. Respec cost rises (10 min to 4 h of play at 60), drops a step per week. Tome of Respec: rare drop (dungeon final bosses ~2%, weekly chest ~10%), one free respec |
| 2026-11-18 | All departments | Pre-Art review: hub gets a navigation row (Hub, Roster, Tavern, Guild Hall, Bank); "starter" label dropped for upgrade markers; mailbox timers count play-days scaled by quality (Common 3, Uncommon 5, Rare 7, Epic 10; 30 calendar-day cap); bank tabs renamable (local only); hub boss illustration 210 x 128; all symbols become icon textures |
| 2026-11-18 | Tuning | Ranked gear band replaces fixed scaling: Heroic 60-70, Mythic 68-80. Only base stat budget is clamped; set bonuses, stat allocation, suffixes, perks and legendary effects carry. Target gap: full set at cap beats fresh roster at floor by about 25-30% power |
| 2026-11-18 | Art / UX | Mid-fi wireframes approved as the hi-fi base; Art handoff brief in ux/art-handoff (stage ground plane first) |
| 2026-11-18 | Loot | Trash loot: Poor junk auto-sells; Common starter gear is BoE, about 10 GL below current content, labelled "starter" |
| 2026-11-18 | Tuning | Guild Bank revised: end-game unlock (avg level 60 + first Normal raid kill, about 2 h of play); 16 + 16 slots, cap 32; consumables stack 5 per slot; BoE 1 in 8, never from raid bosses; required levels; 20% sell value, no buyback; mailbox max 5 |
| 2026-11-18 | Loot / Tuning | BoP boss drops, about 1 in 5 other drops BoE (one step below current raid BoP). Guild Bank: own roster only, no player trading; tabs of 28 slots, Tab 1 free, Tabs 2-4 at 3 / 8 / 20 hours of play at 60; quest items use no slots. Full bank: overflow mailbox, auto-sell after 7 days (Director chose A). New mid-fi Guild Bank screen |
| 2026-11-18 | UX | Director's UI scale measured at 0.64 (about 1.2 px per UI unit at 1440p). 960 x 540 becomes the design grid; in-game default size is about 70% of screen width at 16:9, so it matches the approved map-sized frame on any UI scale. Mid-fi wireframes drawn, low-fi moved to ux/wireframes/low-fi |
| 2026-11-18 | UX | Board goes wide: 960 x 540 UI units (16:9) by default, about the size of the world map; scale slider 70-120%, movable, position saved per character. Extra width goes to the playback stage for Art |
| 2026-11-18 | Loot | Armor types by class (plate, mail, leather, cloth); tier sets per class (nine per raid); drops not tailored to the roster, all types and sets equally likely; unusable items sell for gold; results pre-fill the best eligible recipient |
| 2026-11-18 | Playback | Animated by default; speed, skip and summary-only live on a settings page |
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
