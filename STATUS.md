# Status

Last updated: 2026-11-19. Read this first at the start of every session.

## Where we are

**Phase 3, vertical slice: closed (2026-11-19).** Phase 4 (production) starts. The addon plays the Molten Bore end to end (hub, prep, playback, results, loot window, roster, tavern, journal, settings), tested headless on every push. The Director installs it when the game is in production; everything that needs the real client is marked **verify at install** (`qa/test-plan-addon.md`).

| Deliverable | Status |
| --- | --- |
| Game rules | One source in Lua (`engine/game.lua`), used by the addon, the playtest page and the bots |
| Engine | Engine 10; boss mechanics as hooks (`engine/bosses.lua`); replay records (`engine/replay.lua`) |
| Addon | Every slice screen as real frames (`addon/src`), art exported at build (`tools/addon_media.py`), keyboard reach, sound cues. Build: `python3 tools/build_addon.py` into `addon/dist/FlightPathRaiders` |
| Hi-fi | Every slice screen, both themes (`ux/hifi/`, sign-off list in its README); board preview https://claude.ai/artifact/9QSA6W3cuxP2tgejH3FU6P |
| Playtest build | https://claude.ai/artifact/NfN3hjmbfZ7Hvhf7pncJxM (runs the Lua rules) |
| Audio, Legal, Marketing, QA | `audio/cues.md`, `legal/checklist.md`, `marketing/positioning.md` and `marketing/clip-pull.mp4`, `qa/test-plan-addon.md` |
| Phase 3 gate | See below |

## Phase 3 gate (milestone plan)

First gate review (separate agent, 2026-11-19): **fail**, six must-fix items, all fixed. Second review (separate agent, 2026-11-19): all six confirmed fixed; **fail on 6a only**. Its CI item is fixed (the learning gate runs in its own job and can't turn the checks red); its can-wait items are fixed except armour icons by slot (#36, Phase 4).

| Check | Result |
| --- | --- |
| 1. Fun, scored | Survey written (`qa/survey-phase3.md`); the Director fills it in after a full in-game week at install (#34) |
| 2. Same fights everywhere | Pass in Lua 5.1, LuaJIT and Fengari; `/fpr selftest` passes inside the built addon headless and now runs a few dozen fights per frame. In the client: verify at install (#27) |
| 3. Stable and fast | Pass headless: 10 weeks through the addon with no Lua errors; slowest pull under 6 ms; hub redraw under 1 ms. Taint and first open: verify at install |
| 4. Looks like the hi-fi | Pass headless: 204 of 204 fixed labels within 2 units of the hi-fi (`tools/layout_compare.py`); every screen, both themes, at 70% and 120% of a 2560 x 1440 screen, passes contrast (`tools/addon_shot.py`; smallest text 14.4 px at 70%). In-client screenshots: verify at install |
| 5. Keyboard reach | Pass: a whole pull and every tab with the keyboard alone; combat hands every key back; can be turned off |
| 6. Learning path | 6b pass: no recap answer before two wipes on that lesson (QA checks every pull). **6a accepted by the Director** at 61-69% of 100 guilds against 70% (`tools/results-gate6.txt`, decisions.md) |
| 7. Separate-agent gate review | Done twice; second review passes everything except 6a |

## Where things live

| What | Where |
| --- | --- |
| Task board | [GitHub Issues](https://github.com/europalle/flight-path-raiders/issues), by milestone. Status is a label: `status:next`, `status:in-progress`, `status:review`, `status:blocked`. Closed means done |
| Every decision the Director made | `design/decisions.md` |
| Design document | https://claude.ai/artifact/SALKe92QNhpz1sRA7YA2Dk |
| Browser prototype | https://claude.ai/artifact/YHGsBUgA2y1DGDVTaisGpy (built from `prototype/build.py`) |
| Combat engine and tests | `engine/` (sim, validate, progress), `tests/check.sh` (standard Lua 5.1, LuaJIT and Fengari; CI in `.github/workflows`), `tools/qa.py`, `tools/tune*.py`, results in `tools/results-pass*.txt`, `tools/results-bosses.txt` |
| Technical design | Claude Doc: https://claude.ai/artifact/8fVgrn6YoRb2ATCBdEQSfm |
| Wireframe review page | https://claude.ai/artifact/8b9wnYtUHvZ5BFR1tbkuNa |
| Mid-fi wireframes and Art handoff | `ux/wireframes/mid-fi/`, `ux/art-handoff/` |
| Gemini prompts and to-do sheet | `art/gemini-prompt-pack.md`, `art/gemini-todo.xlsx` |
| Raw Gemini images | `art/source/gemini/` (named by prompt code) |
| Cut-out kit pieces | `art/kit/` (characters, bosses, textures) |

## Recent

- 2026-11-19: Phase 3 closed (gate 6a accepted by the Director); Phase 4 board set up.
- 2026-11-19: Director: no install until production, so finish the slice without it.
- 2026-11-19: Rules in Lua; boss hooks; replay records; every slice screen in hi-fi and in the addon; keyboard reach; sound cues; art in the addon (3-slice buttons, stage, rim light); Legal, Marketing and QA deliverables; Phase 3 gate checks measured.
- 2026-11-18: Phase 3 started: addon skeleton, every trait and morale (engine 10).
- 2026-11-18: Phase 2 gate passed with conditions; art direction, hi-fi hub, milestone plan.
- 2026-11-18: Learning path approved; playtest build published.

## Next

1. Director, at install: follow `qa/test-plan-addon.md` (self-test, taint, screenshots, a week of play, the survey).
2. Director, when convenient: the six Gemini prompts on https://claude.ai/artifact/8uH9F6h2DJ4XQG8jhHWtpx (F3-F6 bosses, F1b Ragnaroast in parts, C3b armour by slot); Legal's two open decisions.
3. Phase 4 (production), milestone "Phase 4: Production (alpha)". Build order: plan and fixed gate (#37), design-doc open questions (#38), levelling and bench training (#39), economy (#40), activities (#41), guild layer (#42), ranked and sync (#43), season and economy bots (#44), with narrative, audio and art alongside (#45, #36, #9).

## Working rules

- Solo development: all guild interaction is simulated in tests.
- Commits end with the attribution lines; decisions go in `design/decisions.md`.
- No em dashes in anything drafted.
