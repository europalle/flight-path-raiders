# Status

Last updated: 2026-11-18. Read this first at the start of every session.

## Where we are

**Phase 3, vertical slice, in progress.** Addon skeleton built; traits and morale in the engine and the playtest build.

| Deliverable | Status |
| --- | --- |
| Design document | Done, signed off |
| UX wireframes and art direction | Done: mid-fi wireframes (12 screens), art direction doc https://claude.ai/artifact/QmgH2PCEzUQ7htB5fSzQpZ, hi-fi hub in light and dark (`ux/hifi/`), kit cut into `art/kit/ui/` |
| Technical design | Done, signed off |
| Browser prototype | Engine 10 published: https://claude.ai/artifact/YHGsBUgA2y1DGDVTaisGpy (all five Molten Bore bosses, preparation, raid experience, raid moments, 10-week season). QA suite passes; boss tuning done |
| Addon | `addon/src` (Core, SelfTest, Board); build with `python3 tools/build_addon.py` into `addon/dist/FlightPathRaiders`; `tests/addon_test.py` runs it headless |
| Board preview | https://claude.ai/artifact/9QSA6W3cuxP2tgejH3FU6P (`ux/preview/`): the board on the Director's 1440p screen, clickable, scale and theme |
| Playtest build | Published: https://claude.ai/artifact/NfN3hjmbfZ7Hvhf7pncJxM (`playtest/`, built by `playtest/build.py`). Script: `qa/playtest-1.md`. Rules QA `tools/playtest_qa.js`, bot `tools/playtest_bot.js` |
| Milestone plan | Done: https://claude.ai/artifact/MiJAJ6iKh2Dkcn8aYSeBU9 |
| Gate review (separate agents) | Passed with conditions; conditions fixed or filed as Phase 3 issues (#26-#35) |

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

- 2026-11-18: Style set: A Field Journal is light mode, C Midnight Grimoire is dark mode, characters in Gemini's polished-but-janky WoW Classic look.
- 2026-11-18: Alliance only (human, dwarf, night elf, gnome), Classic class rules; dwarves can be shamans (WoW: Forever). 18 characters cut out.
- 2026-11-18: All Gemini prompts done; Ragnaroast and the Molten Bore stage in; first hi-fi stage test.
- 2026-11-18: Task board set up as GitHub Issues.
- 2026-11-18: Technical design signed off.
- 2026-11-18: Browser prototype v1 and Tuning pass 1.
- 2026-11-18: QA and Tuning sweeps; department meeting changed the lava throw, zones and two tactic cards (engine v3).
- 2026-11-18: Tuning pass 3: fire resistance and preparation-first targets (engine v4).
- 2026-11-18: Skill, familiarity, chemistry and raid moments (engine v5, Tuning pass 4); design doc 4.6.
- 2026-11-18: The other four Molten Bore bosses in the engine and prototype (engine v6); design doc 6.1.
- 2026-11-18: Learning path approved (design doc 3.1); playtest build published (engine v7).
- 2026-11-18: Phase 3 started: addon skeleton (`addon/`, `tools/build_addon.py`, `/fpr selftest`), every trait and morale (engine 10).
- 2026-11-18: Art direction, hi-fi hub and milestone plan. Phase 2 gate review: pass with conditions; engine v9 with input checks, CI, Normal retuned, softer card checks, Heroic keep-pulling rule.

## Next

1. Director: copy `addon/dist/FlightPathRaiders` into the game and run `/fpr selftest` (first in-game check).
2. Journal and loot window wireframes (#31), then hi-fi for the slice screens (#32); replay records (#28); Legal checklist (#14).
3. Then the Phase 3 list in the milestone plan.

## Working rules

- Solo development: all guild interaction is simulated in tests.
- Commits end with the attribution lines; decisions go in `design/decisions.md`.
- No em dashes in anything drafted.
