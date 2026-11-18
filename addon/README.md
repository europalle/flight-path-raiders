# The addon

`src/` holds the addon's own files; `tools/build_addon.py` assembles `dist/FlightPathRaiders/` with the
engine copied in unchanged and the golden results baked in for `/fpr selftest`.

To try it: run `python3 tools/build_addon.py`, then copy `addon/dist/FlightPathRaiders` into
`World of Warcraft/_forever_/Interface/AddOns/`. In game:

- `/fpr` opens and closes the board (Escape closes it too; drag to move)
- `/fpr selftest` runs 15 golden fights and 2,000 fuzz fights and checks every checksum against the other runtimes
- `/fpr scale 70-120`, `/fpr theme light|dark|auto`, `/fpr reset`

`tests/addon_test.py` loads the built addon in standard Lua 5.1 with a stand-in for the WoW API
(`tests/wow_stub.lua`) and drives it headless; CI runs it on every push.
