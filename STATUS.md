# Status

Last updated: 2026-11-18. Read this first at the start of every session.

## Where we are

**Phase 2, Pre-production.** Art is ahead of plan; Engineering is starting.

| Deliverable | Status |
| --- | --- |
| Design document | Done, signed off |
| UX wireframes and art direction | Mid-fi wireframes done (12 screens). Style chosen. Asset kit generated and cut out. First hi-fi stage test done. Art direction write-up and hi-fi hub to do |
| Technical design | Draft complete, waiting for Director review (3 open questions in section 12) |
| Browser prototype | Not started |
| Milestone plan | Not started |
| Gate review (separate agents) | After the above |

## Where things live

| What | Where |
| --- | --- |
| Task board | [GitHub Issues](https://github.com/europalle/flight-path-raiders/issues), by milestone. Status is a label: `status:next`, `status:in-progress`, `status:review`, `status:blocked`. Closed means done |
| Every decision the Director made | `design/decisions.md` |
| Design document | Claude Doc in the Director's Claude Docs, doc id `cbc21151-ea09-48bd-9b01-bd12cf9a945f` |
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
- 2026-11-18: Technical design drafted (12 sections, architecture diagram).

## Next

1. Director reviews the technical design and answers its open questions (#1).
2. Browser prototype with the shared Lua engine (#2), then Tuning's simulations (#3).
3. Art direction write-up (#4), frame kit (#5) and the hi-fi hub (#7) alongside.
4. Milestone plan (#16), then the Phase 2 gate review (#17).

## Working rules

- Solo development: all guild interaction is simulated in tests.
- Commits end with the attribution lines; decisions go in `design/decisions.md`.
- No em dashes in anything drafted.
