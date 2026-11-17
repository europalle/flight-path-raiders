# Flight Path Raiders

A World of Warcraft: Forever addon that turns flight paths into raid nights. Recruit a 10-player raid, gear up in dungeons, and clear parody bosses one flight at a time. Weekly lockouts, Normal, Heroic and Mythic modes, and a guild leaderboard synced entirely in-game.

> Status: **Phase 2, pre-production.** Nothing is playable yet.

## Design pillars

1. **Fits a flight.** One prep phase plus one pull fits a 2-8 minute flight. Landing never punishes you.
2. **Raid culture is the content.** The jokes are mechanics: wipes on trash, loot drama, the tank who never waits for mana.
3. **Same raid, fair race.** Everyone gets the same weekly lockout, and scores are verified by replay.

## Repository layout

| Folder | Contents |
| --- | --- |
| `addon/FlightPathRaiders/` | The WoW addon: TOC, Lua, bundled libraries |
| `prototype/` | Browser prototype used to tune combat and balance before the Lua build |
| `art/` | SVG sketches, card frames, board layouts, icons |
| `design/` | Decision log and links to the design documents |

## Project phases

| Phase | Name | Status |
| --- | --- | --- |
| 1 | Concept | Done (2026-11-17) |
| 2 | Pre-production | In progress |
| 3 | Vertical slice | Not started |
| 4 | Production | Not started |
| 5 | Alpha | Not started |
| 6 | Beta | Not started |
| 7 | Launch | Not started |
| 8 | Live ops | Not started |

## Target client

WoW: Forever, interface `16001`, client folder `_forever_`.

## Installing

Not yet available. When it is, the addon installs as a single folder with its libraries bundled.

## Licence

- **Code** (everything outside `art/`): [GPL-3.0](LICENSE). You may copy and change it, but your versions must stay open under the same licence.
- **Art** (`art/`): [CC BY-NC-SA 4.0](art/LICENSE). Credit us, no commercial use, share alike.
- Bundled third-party libraries keep their own licences, included next to them.
- World of Warcraft is a trademark of Blizzard Entertainment. This is an unofficial fan project; it contains no Blizzard art or assets.
