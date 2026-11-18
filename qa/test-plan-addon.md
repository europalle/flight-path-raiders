# Addon test plan (QA and Player Research)

Phase 3, 2026-11-19. What is tested headless on every push, and what is checked in the client at install.

## On every push (CI, .github/workflows/check.yml)

| Check | Tool | What it proves |
|---|---|---|
| Same fights everywhere | tests/check.sh | 18 golden fights, 2,000 fuzz fights, 3 scripted seasons and the replay record tests give the same results in Lua 5.1, LuaJIT and Fengari |
| Engine rules | tools/qa.py | Bosses, cards, validation, gear band, traits and morale behave as the design doc says |
| Game rules | tools/playtest_qa.js | 25 guilds for 8 weeks through the real rules: no broken states, saves load back, records rebuild, no recap answer before two wipes |
| Addon plays | tests/addon_test.py | The built addon in Lua 5.1 with a WoW stand-in: every page, a pull to the loot window, keyboard only, 10 weeks with no Lua errors, timings, sounds, self-test, slash commands, every texture present |
| Addon looks right | tools/addon_shot.py | Every screen in both themes drawn from the addon's own layout; every line of text passes contrast; nothing under 11 units |
| Learning path | tools/gate_learning.py | The learner bot keeps up with the smart bot in 70%+ of guilds |

## At install (verify at install)

The Director installs the addon when the game is in production. Then, in this order:

1. **Loads clean:** log in, check for Lua errors (BugSack if available). Type /fpr.
2. **Self-test:** /fpr selftest says passed, engine 10. If it fails, copy the chat line into an issue.
3. **Speed:** /fpr opens the board with no visible hitch; a pull starts playback at once. If in doubt: /run local t=debugprofilestop() FlightPathRaidersBoard:Show() print(debugprofilestop()-t)
4. **Taint:** /console taintLog 1, play a pull, enter combat, leave combat, open the board; check Logs/taint.log for FlightPathRaiders.
5. **Looks:** screenshot every slice screen in both themes at 70% and 120% (/fpr scale 70, /fpr scale 120); run art/tools/check_contrast.py on them (needs text boxes: QA compares by eye against ux/hifi for now).
6. **Sounds:** each cue in audio/cues.md plays or is silent; none errors.
7. **Keyboard:** Tab through a whole pull. Escape closes the loot window, then the board.
8. **Fonts and art:** textures show (no green squares), text fits its boxes with the real fonts.
9. **A week:** play a full in-game week, then fill in the fun survey (qa/, gate check 1).
10. **10 weeks:** over time, ten weeks with no Lua errors or taint (gate check 3).

## Known gaps

- Text widths are measured with stand-in fonts headless; the real fonts may be wider. Step 8 checks it.
- Taint and real frame-open time can only be measured in the client.
