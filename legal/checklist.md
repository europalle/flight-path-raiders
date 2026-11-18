# Rules checklist (Legal and Compliance)

Issue #14, 2026-11-19. A checklist for us to work through, **not legal advice**. Before a public release, someone qualified should read the current versions of Blizzard's terms, since they change.

Status key: **Done** (checked in the repo), **Before beta**, **Before launch**, **Verify at install** (needs the real client).

## 1. Blizzard's addon rules (UI Add-On Development Policy)

| Rule | Where we stand | Status |
|---|---|---|
| Addons must be free; no charging for the addon or for features | Free, no paid features, no donations gate | Done |
| No obfuscated code | All Lua is plain and readable; the build only copies files | Done |
| No advertising, no requests for donations inside the game | None in the addon | Done |
| No harm to the game or other players' experience (performance) | No work while the board is closed; a pull takes about 6 ms in standard Lua 5.1 | Done, verify at install |
| No automation of gameplay | The game lives entirely inside our board; nothing touches combat, movement or the real UI's protected functions; keyboard handling is left alone in combat | Done, verify at install (taint check) |
| Addon messages within limits | Replay records are chunked to 250 bytes or less, as addon messages require. Sending is not built yet (Phase 4) | Done for the format |
| No in-game purchases for real money | None | Done |
| Don't use Blizzard's trademarks to suggest we're official | Name and page avoid "World of Warcraft" in the title; "for WoW: Forever" only as a compatibility note | Before launch: page text review |

## 2. Our parody names and the IP line

| Check | Where we stand | Status |
|---|---|---|
| Boss names are our own puns, not real boss names | Magmadad, Baron Get-Down, Lucifrown, Majordomo Exhaustus, Ragnaroast, Onyxiety | Done |
| No real character, logo or crest in the art | Art's look-alike rule (prompt pack v4): anything two of us read as a real character gets redrawn | Done for current art |
| Item names are our own | All loot names and flavour text are ours (engine/game.lua) | Done |
| Dungeon item names that echo real dungeons ("Deadmines Pickaxe", "Gnomeregan Hand-me-downs") | Place names are used as in-game references, which is common in fan works, but they are Blizzard's names | **Before launch: decide.** Safest is renaming them to our own places |
| Class and race names (warrior, night elf...) | Generic fantasy words, needed to describe the player's own game | Done |
| Use of the game's sound kit | We play the client's own sounds through its API; we ship no audio files | Done |
| Use of the client's fonts | We use the fonts already in the client; we ship none | Done |

## 3. Licences

| Item | Licence | Duty | Status |
|---|---|---|---|
| Our code | MIT (LICENSE in the repo) | Keep the notice | Done |
| Fengari (browser Lua, playtest page only) | MIT | Credit in the playtest page | Before beta: add credit line |
| Kalam, IBM Plex Sans (hi-fi mockups only; not in the addon) | SIL Open Font License 1.1 | If we ever ship them in the addon: include the OFL text | Done for now |
| lupa, Pillow, numpy, Playwright (tools only, never shipped) | BSD/MIT/Apache-type | None for users | Done |
| Any library added later (LibStub, Ace3, LibDBIcon) | Varies | Add to this table before adding the code | Ongoing |

## 4. AI-made art

| Check | Where we stand | Status |
|---|---|---|
| Art is generated with Gemini from our own prompts and our own character study, then cleaned by Art | Prompt pack v4 in art/ | Done |
| Disclose AI-assisted art on the addon page | CurseForge and Wago both have content rules; we say it plainly on the page | Before launch |
| Check the image tool's current terms allow use in a free public project | Read Google's current Gemini terms for generated images | Before launch |
| Keep prompts and source images in the repo so we can show how each piece was made | art/gemini-prompt-pack.md and art/source | Done |

## 5. Players' data

| Check | Where we stand | Status |
|---|---|---|
| Saved data stays on the player's PC (SavedVariables) | Only game state and settings | Done |
| Guild sync and leaderboards share names of their fictional raiders, scores and replay records, nothing about the player | Design for Phase 4 | Before beta: review the sync messages |
| Crash reporting respects privacy (beta) | Not built yet | Before beta |

## Open decisions for the Director

1. Rename the two dungeon items that use real place names (Deadmines, Gnomeregan)? Legal's advice: yes, before launch.
2. AI disclosure wording on the addon page: Marketing drafts it, Legal checks it.
