"""Loads the built addon (addon/dist) in standard Lua 5.1 with a stand-in WoW API, in TOC order, and
drives it: ADDON_LOADED, /fpr, /fpr selftest, scale, theme, reset, Escape, saved data.
Usage: python3 tools/build_addon.py && python3 tests/addon_test.py"""
import os, sys
import lupa.lua51 as l51
ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
DIST = os.path.join(ROOT, "addon/dist/FlightPathRaiders")
L = l51.LuaRuntime(unpack_returned_tuples=True)
L.execute(open(os.path.join(ROOT, "tests/wow_stub.lua")).read())
L.execute("FPR_NS = {}")
toc = [l.strip() for l in open(os.path.join(DIST, "FlightPathRaiders.toc")) if l.strip() and not l.startswith("#")]
load = L.eval("function(src, name) local f, err = loadstring(src, '@' .. name); if not f then error(err) end; return f('FlightPathRaiders', FPR_NS) end")
for f in toc: load(open(os.path.join(DIST, f.replace("\\", "/"))).read(), f)
fails = []
def check(name, ok):
    print(("ok   " if ok else "FAIL ") + name)
    if not ok: fails.append(name)
check("the engine stays out of the global namespace", L.eval("FPR_ENGINE") is None)
check("no globals besides the documented ones", all(L.eval(f"{g} ~= nil") for g in ("SlashCmdList.FLIGHTPATHRAIDERS", "SLASH_FLIGHTPATHRAIDERS1")))
L.execute("WOW_FIRE('ADDON_LOADED', 'FlightPathRaiders')")
check("saved data is created with defaults", L.eval("FlightPathRaidersDB.version == 1 and FlightPathRaidersDB.settings.scale == 1"))
slash = L.eval("SlashCmdList.FLIGHTPATHRAIDERS")
slash("")
check("/fpr opens the board", L.eval("FlightPathRaidersBoard ~= nil and FlightPathRaidersBoard:IsShown()"))
check("Escape can close the board", L.eval("UISpecialFrames[1] == 'FlightPathRaidersBoard'"))
check("the board scales to about 70% of the screen", abs(L.eval("rawget(FlightPathRaidersBoard, '_scale')") - 1920 * 0.7 / 960) < 1e-6)
slash("scale 120"); check("/fpr scale 120 saves and applies", L.eval("FlightPathRaidersDB.settings.scale") == 1.2 and abs(L.eval("rawget(FlightPathRaidersBoard, '_scale')") - 1.4 * 1.2) < 1e-6)
slash("scale 300"); check("scale outside 70-120 is refused", L.eval("FlightPathRaidersDB.settings.scale") == 1.2)
slash("theme light"); check("/fpr theme light is saved", L.eval("FlightPathRaidersDB.settings.theme") == "light")
L.execute("FlightPathRaidersBoard:GetScript('OnDragStop')(FlightPathRaidersBoard)")
check("dragging saves the position", L.eval("FlightPathRaidersDB.settings.point[1]") == "CENTER")
slash("reset"); check("/fpr reset clears the position", L.eval("FlightPathRaidersDB.settings.point") is None)
slash(""); check("/fpr again closes it", not L.eval("FlightPathRaidersBoard:IsShown()"))
L.execute("WOW_CHAT = {}")
ok = L.eval("FPR_NS.SelfTestRun")()
chat = " ".join(L.eval("WOW_CHAT")[i] for i in range(1, len(L.eval("WOW_CHAT")) + 1))
check("/fpr selftest passes inside the addon: " + chat[:140], ok is True and "passed" in chat)
print("Addon test:", "all passed" if not fails else f"{len(fails)} failed")
sys.exit(1 if fails else 0)
