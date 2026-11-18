# Hi-fi screens (vertical slice)

Every slice screen in both themes, Field Journal (light) and Midnight Grimoire (dark), on the 960 x 540 board grid.
Built from the Gemini kit by `art/tools/hifi_hub.py` (hub) and `art/tools/hifi_screens.py` (the rest), with the
shared pieces in `art/tools/hifi_kit.py`. Each screen has an SVG with fonts embedded, a no-text twin and a list of
text boxes; `art/tools/check_contrast.py` measures every line against its real background. All 18 pass.

Rebuild: `python3 art/tools/hifi_hub.py && python3 art/tools/hifi_screens.py --png`
Check: `python3 art/tools/check_contrast.py ux/hifi/*-light.svg ux/hifi/*-dark.svg` (skip the `-notext` files)

## Changes from mid-fi (sign-off list)

The mid-fi was drawn before the slice scope was settled. Hi-fi follows the slice rules in `engine/game.lua`.

| Screen | What changed from mid-fi, and why |
|---|---|
| All | Tabs are Hub, Roster, Tavern, Journal. Guild Hall and Bank are not in the slice. The purse shows week, gold and DKP. |
| Hub | Same layout as the approved hub; only the tabs changed. |
| Prep | Cards show role icon, GL and morale (power is not a number players see). A potion icon marks who gets a Fire Protection Potion. Tactic cards carry the slice's real effects; the chosen one has a tick as well as colour. Cauldrons are chips with prices; "Same as last pull" is the default, not a button. The banner names the journal's answer once the raid has worked it out. |
| Playback | Portraits stand in zones until the stage sprites exist. "Sinks at round 10" replaces score pace (no score pace in the slice). Log lines are coloured and weighted: deaths bold red, heals green, mechanics amber. Pause has no icon (none in the kit). |
| Results (wipe) | New in the slice: the learning recap (what happened, raid leader's clue, the answer), the boss's line, journal finds, repairs waived on the first wipe, growth and morale, and Replay with the other cards. Loot Council drama moved to the loot window as a chance, not a choice. |
| Results (kill) | The loot window from the #31 wireframe opens over the result. Candidates are the raiders in the pull who can use the item, best upgrade first and picked; the number is the gear level gained. Traits that can override the choice are written under the item. |
| Roster | Same table plus detail. Detail shows traits with their full text, morale with last week's changes, gear by slot, Fire Whelp gear, respec 60 g and dismiss with the refund. Level and set bonuses are gone (not in the slice). |
| Tavern | Full-body art instead of portraits. Five recruits, rarity in pips and words, traits listed. The weekly reset replaces the daily one. Unaffordable Hire buttons are not greyed in this mock; the addon greys them. |
| Journal | New (wireframe in #31). Boss list with kill state per mode and abilities found; abilities fill in as seen, unseen ones are a dashed "?" row; "Worked out" shows answers and the current clue. |
| Settings | Four tabs (Notifications folded into Display). Theme names match the art doc. Self-test is a button with the last result. |
