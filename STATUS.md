# Status

Last updated: 2026-11-18. Read this first at the start of every session.

## Where we are

**Phase 2, Pre-production.** Art is ahead of plan; Engineering is starting.

| Deliverable | Status |
| --- | --- |
| Design document | Done, signed off |
| UX wireframes and art direction | Mid-fi wireframes done (12 screens). Style chosen. Asset kit generated and cut out. First hi-fi stage test done. Art direction write-up and hi-fi hub to do |
| Technical design | Done, signed off |
| Browser prototype | Engine v5 published: https://claude.ai/artifact/YHGsBUgA2y1DGDVTaisGpy (fire resistance, preparation, raid experience, raid moments, 10-week season). QA suite passes; Tuning pass 4 done |
| Milestone plan | Not started |
| Gate review (separate agents) | After the above |

## Where things live

| What | Where |
| --- | --- |
| Task board | [GitHub Issues](https://github.com/europalle/flight-path-raiders/issues), by milestone. Status is a label: `status:next`, `status:in-progress`, `status:review`, `status:blocked`. Closed means done |
| Every decision the Director made | `design/decisions.md` |
| Design document | https://claude.ai/artifact/SALKe92QNhpz1sRA7YA2Dk |
| Browser prototype | https://claude.ai/artifact/YHGsBUgA2y1DGDVTaisGpy (built from `prototype/build.py`) |
| Combat engine and tests | `engine/` (sim, progress), `tests/check.sh` (Lua 5.1 vs Fengari), `tools/qa.py`, `tools/tune*.py`, results in `tools/results-pass*.txt` |
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

## Next

1. Director plays the prototype (engine v5). Next: more bosses in the prototype so Tuning can test per-boss cards.
2. QA's first solo playtest script (#15); more bosses in the prototype.
3. Art direction write-up (#4), frame kit (#5) and the hi-fi hub (#7) alongside.
4. Milestone plan (#16), then the Phase 2 gate review (#17).

## Working rules

- Solo development: all guild interaction is simulated in tests.
- Commits end with the attribution lines; decisions go in `design/decisions.md`.
- No em dashes in anything drafted.
