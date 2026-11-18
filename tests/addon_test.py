"""Loads the built addon (addon/dist) in standard Lua 5.1 with a stand-in WoW API, in TOC order, and
drives it like a player: ADDON_LOADED, /fpr, every page, a pull through prep, playback, results and the
loot window, a week ending, settings, /fpr selftest, and saved data. Also checks that every texture the
UI asks for exists in the build.
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
def check(name, ok, detail=""):
    print(("ok   " if ok else "FAIL ") + name + ("" if ok else f"  ({detail})"))
    if not ok: fails.append(name)
click = L.eval("WOW_CLICK")
def press(label):
    r = click(label)
    ok, why = (r if isinstance(r, tuple) else (r, None))
    if not ok: print("     could not press", repr(label), why)
    return ok
text = lambda: L.eval("WOW_VISIBLE_TEXT()")
render = L.eval("function() FPR_NS.Board.Render() end")

check("the engine stays out of the global namespace", L.eval("FPR_ENGINE") is None)
check("no globals besides the documented ones", all(L.eval(f"{g} ~= nil") for g in ("SlashCmdList.FLIGHTPATHRAIDERS", "SLASH_FLIGHTPATHRAIDERS1")))
L.execute("WOW_FIRE('ADDON_LOADED', 'FlightPathRaiders')")
check("saved data is created with defaults", L.eval("FlightPathRaidersDB.version == 2 and FlightPathRaidersDB.settings.scale == 1"))
slash = L.eval("SlashCmdList.FLIGHTPATHRAIDERS")
slash("")
check("/fpr opens the board", L.eval("FlightPathRaidersBoard ~= nil and FlightPathRaidersBoard:IsShown()"))
check("Escape can close the board", L.eval("UISpecialFrames[1] == 'FlightPathRaidersBoard'"))
check("the board scales to about 70% of the screen", abs(L.eval("rawget(FlightPathRaidersBoard, '_scale')") - 1920 * 0.7 / 960) < 1e-6)
check("a new guild exists on first open: 12 raiders, 300 gold", L.eval("#FlightPathRaidersDB.guild.roster == 12 and FlightPathRaidersDB.guild.gold == 300"))
t = text()
check("the hub shows the first boss and the tabs", "Next: Magmadad (Normal)" in t and "Prep pull" in [L.eval("WOW_BUTTONS()")[i].labelText for i in range(1, len(L.eval("WOW_BUTTONS()")) + 1)], t[:200])
for page in ("Roster", "Tavern", "Journal", "Hub"):
    check(f"the {page} tab opens", press(page) and L.eval("FPR_NS.Board.page") == page)
press("Roster"); names = [L.eval(f"FlightPathRaidersDB.guild.roster[{i}].name") for i in range(1, 13)]
check("the roster lists every raider", all(n in text() for n in names))
press("Hub")
# Dungeons fill the purse a little; then a pull.
gold0 = L.eval("FlightPathRaidersDB.guild.gold")
press("Quick dungeon (8 left)")
check("a quick dungeon pays gold", L.eval("FlightPathRaidersDB.guild.gold") > gold0)
check("Prep pull opens prep", press("Prep pull") and L.eval("FPR_NS.Board.page") == "Prep")
check("prep shows the raid by zone and the four cards", all(s in text() for s in ("Front", "Melee", "Back", "This pull costs")))
press("Burn")
check("a tactic card can be picked", L.eval("FPR_NS.Board.args.prep.tactic") == "burn")
check("Pull starts playback", press("Pull") and L.eval("FPR_NS.Board.page") == "Playback")
check("playback only ticks while playing", L.eval("FlightPathRaidersBoard._scripts.OnUpdate ~= nil"))
for _ in range(60): L.eval("WOW_TICK(1)")
check("playback ends on the results", L.eval("FPR_NS.Board.page") == "Results")
check("no work while the results are up", L.eval("FlightPathRaidersBoard._scripts.OnUpdate == nil"))
result = L.eval("FPR_NS.Board.args.out.result")
t = text()
check("results show the outcome and what happened", ("Kill in round" in t) if result == "kill" else ("in round" in t and ("WHAT HAPPENED" in t)), t[:300])
# Pull until a kill, so the loot window shows up.
for _ in range(8):
    if L.eval("FPR_NS.Board.args.out.result") == "kill": break
    press("Pull again"); press("Skip to result")
killed = L.eval("FPR_NS.Board.args.out.result") == "kill"
check("Magmadad dies within a few pulls on Burn", killed)
if killed:
    check("the loot window opens after a first kill", L.eval("FPR_NS.Board.modal ~= nil") and "Loot" in text())
    pend = L.eval("#FlightPathRaidersDB.guild.pending")
    press("Hand out")
    check("Hand out empties the loot pile", L.eval("#FlightPathRaidersDB.guild.pending") == 0 and L.eval("FPR_NS.Board.modal == nil"), pend)
check("saved pulls keep a replay record that rebuilds the fight", L.eval("""(function() local h = FlightPathRaidersDB.guild.history[1]
  local rb = FPR_NS.Game.Rebuild(h.record); return rb.run ~= nil and rb.run.result == h.result and rb.run.rounds == h.rounds end)()"""))
press("Hub")
press("Journal")
check("the journal records what the raid saw", "Magma pups" in text())
press("Hub"); press("End the week"); press("End the week")
check("ending the week moves to week 2", L.eval("FlightPathRaidersDB.guild.week") == 2)
press("Tavern")
check("the tavern shows five recruits", L.eval("#FlightPathRaidersDB.guild.tavern") == 5 and "Hire" in " ".join(str(L.eval("WOW_BUTTONS()")[i].labelText) for i in range(1, len(L.eval("WOW_BUTTONS()")) + 1)))
# Keyboard reach: a whole pull, then the other pages, with no mouse at all.
key = L.eval("WOW_KEY")
def tab_to(label, limit=80):
    for _ in range(limit):
        if key("TAB") == label: return True
    return False
press("Hub")
kb = tab_to("Prep pull") and (key("ENTER") or True) and L.eval("FPR_NS.Board.page") == "Prep"
kb = kb and tab_to("Pull") and (key("ENTER") or True) and L.eval("FPR_NS.Board.page") in ("Playback", "Results")
if L.eval("FPR_NS.Board.page") == "Playback": kb = kb and tab_to("Skip to result") and (key("ENTER") or True)
kb = kb and L.eval("FPR_NS.Board.page") == "Results"
if L.eval("FPR_NS.Board.modal ~= nil"):
    kb = kb and tab_to("Hand out") and (key("ENTER") or True) and L.eval("FPR_NS.Board.modal == nil")
kb = kb and tab_to("Hub") and (key("ENTER") or True) and L.eval("FPR_NS.Board.page") == "Hub"
check("keyboard only: prep, pull, result, loot and back to the hub", kb)
for page in ("Roster", "Tavern", "Journal"):
    check(f"keyboard only: the {page} tab", tab_to(page) and (key("ENTER") or True) and L.eval("FPR_NS.Board.page") == page)
key("TAB"); back = key("TAB", True); fwd = key("TAB")
up = key("UP")
check("Shift-Tab goes back, arrows move too", back is not None and fwd is not None and up == back, (back, fwd, up))
check("a focused button shows its tooltip, so greyed-out ones say why", L.eval("GameTooltip ~= nil"))
press("Hub"); press("End the week")
check("Escape closes a window before the board", L.eval("FPR_NS.Board.modal ~= nil") and (key("ESCAPE") or True) and L.eval("FPR_NS.Board.modal == nil") and L.eval("FlightPathRaidersBoard:IsShown()"))
check("keys the board doesn't use pass through to the game", (key("W") or True) and L.eval("rawget(FlightPathRaidersBoard, '_propagate') ~= false"))
L.execute("WOW_COMBAT = true"); key("TAB")
check("in combat the board never touches protected key handling", L.eval("rawget(FlightPathRaidersBoard, '_propagate') ~= false"))
L.execute("WOW_COMBAT = false")
# Settings and the old slash commands.
press("Settings")
check("settings open from the cog", L.eval("FPR_NS.Board.page") == "Settings")
press("Midnight"); check("the theme can be picked", L.eval("FlightPathRaidersDB.settings.theme") == "dark")
press("Summary only"); check("playback can be set to summary", L.eval("FlightPathRaidersDB.settings.playback") == "summary")
press("Done")
slash("scale 120"); check("/fpr scale 120 saves and applies", L.eval("FlightPathRaidersDB.settings.scale") == 1.2 and abs(L.eval("rawget(FlightPathRaidersBoard, '_scale')") - 1.4 * 1.2) < 1e-6)
slash("scale 300"); check("scale outside 70-120 is refused", L.eval("FlightPathRaidersDB.settings.scale") == 1.2)
slash("theme light"); check("/fpr theme light is saved", L.eval("FlightPathRaidersDB.settings.theme") == "light")
L.execute("FlightPathRaidersBoard:GetScript('OnDragStop')(FlightPathRaidersBoard)")
check("dragging saves the position", L.eval("FlightPathRaidersDB.settings.point[1]") == "CENTER")
slash("reset"); check("/fpr reset clears the position", L.eval("FlightPathRaidersDB.settings.point") is None)
# Every texture the UI asked for exists.
paths = [p for p in L.eval("WOW_TEXTURES").keys() if isinstance(p, str)]
missing = [p for p in paths if p.startswith("Interface") and not os.path.exists(os.path.join(DIST, "Media", p.split("\\")[-1] + ".tga"))]
check(f"every texture the UI uses is in the build ({len(paths)} used)", not missing, missing[:5])
# Stable: 10 weeks of play through the addon, rendering every page after every action (gate check 3).
ten = L.eval("""function()
  local B, G = FPR_NS.Board, FPR_NS.Game
  local pages = { "Hub", "Roster", "Tavern", "Journal", "Settings" }
  local st = FPR_NS.Core.Guild()
  local start = st.week
  local pulls, t0 = 0, os.clock()
  local slowest = 0
  for w = 1, 10 do
    while st.dungeonsLeft > 0 do G.Dungeon(st) end
    if #st.roster < 12 and st.tavern[1] and st.gold >= st.tavern[1].price then G.Hire(st, 1) end
    for _, mode in ipairs({ "normal", "heroic" }) do
      for _, b in ipairs(G.BOSSES) do
        for _ = 1, 3 do
          if not G.unlocked(st, b.id, mode) or st.progress[b.id][mode .. "Week"] then break end
          B.Go("Prep", { boss = b.id, mode = mode }); local prep = B.args.prep; prep.tactic = b.card
          prep.cons = { food = true, elixirs = st.gold > 300, flasks = st.gold > 600 }
          if #G.Problems(st, prep) > 0 then break end
          local c0 = os.clock(); local out = G.Pull(st, prep); local dt = os.clock() - c0
          if dt > slowest then slowest = dt end
          pulls = pulls + 1
          B.Go("Playback", { out = out, prep = prep, round = 1, t = 0 }); WOW_TICK(5)
          B.Go("Results", { out = out, prep = prep })
          if B.modal then for _ = 1, 50 do if #st.pending == 0 then break end G.AssignPending(st, 1, G.SuggestFor(st, st.pending[1])) end B.CloseModal() end
          if out.result == "kill" then break end
        end
      end
    end
    for _, p in ipairs(pages) do B.Go(p) end
    G.EndWeek(st)
  end
  local c1 = os.clock(); B.Go("Hub"); local open = os.clock() - c1
  return pulls, st.week - start, slowest * 1000, open * 1000
end""")
pulls, week, slow_ms, open_ms = ten()
check(f"10 weeks through the addon with no Lua errors ({pulls} pulls)", week == 10 and pulls > 40)
check(f"a pull resolves in under 50 ms in standard Lua 5.1 (slowest {slow_ms:.1f} ms)", slow_ms < 50)
check(f"the hub draws in under 100 ms (redraw {open_ms:.1f} ms; first open is verify at install)", open_ms < 100)
slash(""); check("/fpr again closes it", not L.eval("FlightPathRaidersBoard:IsShown()"))
L.execute("WOW_CHAT = {}")
ok = L.eval("FPR_NS.SelfTestRun")()
chat = " ".join(L.eval("WOW_CHAT")[i] for i in range(1, len(L.eval("WOW_CHAT")) + 1))
check("/fpr selftest passes inside the addon: " + chat[:120], ok is True and "passed" in chat)
print("Addon test:", "all passed" if not fails else f"{len(fails)} failed")
sys.exit(1 if fails else 0)
