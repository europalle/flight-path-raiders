# Flight Path Raiders

A World of Warcraft: Forever addon that turns flight paths into raid nights. Recruit a 10-player raid, gear up in dungeons, and clear parody bosses one flight at a time. Weekly lockouts, Normal, Heroic and Mythic modes, and a guild leaderboard synced entirely in-game.

> Status: **Phase 3, vertical slice, is next.** A playable browser build of the raid runs on the real engine (see STATUS.md).

**Current status and next steps:** see [STATUS.md](STATUS.md). Tasks live in [Issues](https://github.com/europalle/flight-path-raiders/issues).

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
| `ux/` | Screen flows, wireframes and accessibility standards |
| `data/` | Balance data (all game numbers), read by both the prototype and the addon |

## Studio

| Department | Owns |
| --- | --- |
| Game Director | Vision and every final call |
| Production | Phase plan, scope, risks, sign-offs |
| Game Design | Rules, systems and what each mechanic does |
| Game Tuning & Balancing | Every number: combat, bosses, XP, loot, traits, economy |
| UX/UI & Accessibility | Screen flows, wireframes, readability, onboarding, settings, accessibility standards; can block on readability |
| Narrative & Writing | Jokes, flavour text, events, the game's voice |
| Art | Art direction, sketches, cards, visual styling over approved wireframes |
| Engineering | Addon architecture, combat engine, sync, prototype |
| QA | Test plans, bug lists, in-game checks |
| QA: Player Research | Solo playtest scripts and short surveys for the Director; guild interaction is simulated |
| Audio | Sound cues, stings and their accessibility role |
| Marketing & Community | Addon pages, screenshots and GIFs, Discord, release notes, launch plan, player feedback |
| Legal & Compliance | Blizzard addon and fan-content rules, parody names, trademarks, licences (a checklist, not legal advice) |

At milestone gates, reviews run as separate agents that start fresh and read only the repo and design doc, so the work is checked by eyes that didn't make it.

## Project phases

| Phase | Name | Status |
| --- | --- | --- |
| 1 | Concept | Done (2026-11-17) |
| 2 | Pre-production | Done (2026-11-18), gate passed with conditions |
| 3 | Vertical slice | Next |
| 4 | Production (alpha) | Not started |
| 5 | Beta | Not started |
| 6 | Launch and live | Not started |

Phases and gates are defined in the [milestone plan](https://claude.ai/artifact/MiJAJ6iKh2Dkcn8aYSeBU9).

## Target client

WoW: Forever, interface `16001`, client folder `_forever_`.

## Installing

Not yet available. When it is, the addon installs as a single folder with its libraries bundled.

## Licence

- **Code** (everything outside `art/`): [GPL-3.0](LICENSE). You may copy and change it, but your versions must stay open under the same licence.
- **Art** (`art/`): [CC BY-NC-SA 4.0](art/LICENSE). Credit us, no commercial use, share alike.
- Bundled third-party libraries keep their own licences, included next to them.
- World of Warcraft is a trademark of Blizzard Entertainment. This is an unofficial fan project; it contains no Blizzard art or assets.
