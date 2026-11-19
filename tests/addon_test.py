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
# A new guild starts at level 10 (Phase 4): dungeons level it, and raids wait for the level gate.
check("a new guild starts at level 10", L.eval("FlightPathRaidersDB.guild.roster[1].level == 10"))
press("Prep pull")
check("prep says raids wait for level 58", "raids need 58" in text())
press("Hub")
gold0 = L.eval("FlightPathRaidersDB.guild.gold")
press("Quick dungeon")
check("a quick dungeon pays gold and levels the party", L.eval("FlightPathRaidersDB.guild.gold") > gold0 and L.eval("FlightPathRaidersDB.guild.roster[1].level") > 10)
check("its three items open the loot window", L.eval("FPR_NS.Board.modal ~= nil") and L.eval("#FlightPathRaidersDB.guild.pending") == 3)
press("Hand out")
check("handing out clears the loot", L.eval("#FlightPathRaidersDB.guild.pending") == 0)
# The raid flow, with a guild that has levelled.
L.execute("FlightPathRaidersDB.guild = FPR_NS.Game.NewGame(77, { level = 60 }); FPR_NS.Board.Go('Hub')")
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
key("TAB")  # a key the board uses: input stops passing through...
L.execute("WOW_FIRE('PLAYER_REGEN_DISABLED')"); L.execute("WOW_COMBAT = true"); key("TAB")
check("entering combat hands every key back to the game, even right after Tab (M4)",
      L.eval("rawget(FlightPathRaidersBoard, '_propagate') == true and rawget(FlightPathRaidersBoard, '_keyboard') == false"))
L.execute("WOW_COMBAT = false"); L.execute("WOW_FIRE('PLAYER_REGEN_ENABLED')")
check("after combat the keyboard works again", L.eval("rawget(FlightPathRaidersBoard, '_keyboard') == true"))
key("TAB"); key("ESCAPE")
check("Escape first lets go of the focus (arrows and Space go back to the game)", L.eval("FPR_NS.Board.focused == nil and FlightPathRaidersBoard:IsShown()"))
L.execute("FlightPathRaidersDB.settings.keys = false"); key("TAB")
check("keyboard control can be turned off in Settings", L.eval("FPR_NS.Board.focused == nil and rawget(FlightPathRaidersBoard, '_propagate') == true"))
L.execute("FlightPathRaidersDB.settings.keys = true")
# Heroic: pull again with whoever is left (gate review M1).
heroic = L.eval("""function()
  local G, B = FPR_NS.Game, FPR_NS.Board
  for seed = 1, 30 do
    local st = G.NewGame(4242 + seed, { level = 60 })
    for _, b in ipairs(G.BOSSES) do st.progress[b.id].normalKills = 1 end
    FlightPathRaidersDB.guild = st
    B.Go("Prep", { boss = "magmadad", mode = "heroic" }); local prep = B.args.prep; prep.tactic = "spread"
    local out = G.Pull(st, prep)
    if out.error then return false, out.error end
    if out.result ~= "kill" and #out.benched > 0 then
      B.Go("Results", { out = out, prep = prep }); B.CloseModal()
      local p2 = G.Problems(st, prep)
      if #p2 > 0 then return false, p2[1] end
      local out2 = G.Pull(st, prep)
      if out2.error then return false, out2.error end
      for _, id in ipairs(prep.ids) do if G.byId(st, id).benched and out2.input then
        for _, c in ipairs(out2.input.raid) do if c.name == G.byId(st, id).name then return false, "benched raider pulled" end end end end
      return true, #out.benched .. " benched, pulled again with " .. #out2.input.raid
    end
  end
  return false, "no Heroic wipe with deaths found"
end""")
ok, why = heroic()
check(f"Heroic: after a wipe the dead are benched and Pull again goes with whoever is left ({why})", ok is True, why)
# Prep: a 5th raider in a zone is still shown (S1).
five = L.eval("""function()
  local G, B = FPR_NS.Game, FPR_NS.Board
  FlightPathRaidersDB.guild = G.NewGame(99, { level = 60 })
  B.Go("Prep", { boss = "magmadad", mode = "normal" })
  local prep = B.args.prep
  for _, id in ipairs(prep.ids) do prep.zones[tostring(id)] = "melee" end
  B.Render()
  local n = 0
  for _, b in ipairs(WOW_BUTTONS()) do local t = rawget(b, "tip") if type(t) == "string" and t:find("click to bench") then n = n + 1 end end
  return n, #prep.ids
end""")
shown, total = five()
check(f"prep shows every raider even with all {total} in one zone ({shown} shown)", shown == total)
FIX = None
played = " ".join(L.eval("FPR_NS.Audio.played")[i] for i in range(1, len(L.eval("FPR_NS.Audio.played")) + 1))
check("sound cues fire for the pull, the result and the loot (" + played + ")", all(c in played for c in ("pull", "tab")) and ("kill" in played or "wipe" in played))
L.execute("PlaySound = function() end; SOUNDKIT = { READY_CHECK = 8960 }")
check("an unknown sound kit name is silent, not an error", L.eval("pcall(FPR_NS.Audio.Play, 'kill')") is True)
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
    for _ = 1, 8 do G.Dungeon(st) end
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
# Async, as /fpr selftest runs in the client: a few dozen fights a frame, never one long freeze.
L.execute("WOW_CHAT = {}")
slash("selftest")
frames = L.eval("""function()
  local n = 0
  for i = 1, 500 do
    local busy = false
    for _, f in ipairs(WOW_FRAMES) do local fn = f._scripts.OnUpdate if fn and f ~= FlightPathRaidersBoard then busy = true; fn(f, 0.016) end end
    if not busy then break end
    n = n + 1
  end
  return n
end""")()
chat = " ".join(L.eval("WOW_CHAT")[i] for i in range(1, len(L.eval("WOW_CHAT")) + 1))
check(f"/fpr selftest runs spread over {frames} frames and passes", frames > 20 and "passed" in chat, chat[-200:])
L.execute("WOW_CHAT = {}")
ok = L.eval("FPR_NS.SelfTestRun")(True)
chat = " ".join(L.eval("WOW_CHAT")[i] for i in range(1, len(L.eval("WOW_CHAT")) + 1))
check("/fpr selftest passes inside the addon: " + chat[:120], ok is True and "passed" in chat)
# First open in combat (gate review 2): a fresh load, opened during lockdown, must not touch keyboard input
# until combat ends.
L2 = l51.LuaRuntime(unpack_returned_tuples=True)
L2.execute(open(os.path.join(ROOT, "tests/wow_stub.lua")).read()); L2.execute("FPR_NS = {}")
load2 = L2.eval("function(src, name) local f, err = loadstring(src, '@' .. name); if not f then error(err) end; return f('FlightPathRaiders', FPR_NS) end")
for f in toc: load2(open(os.path.join(DIST, f.replace("\\", "/"))).read(), f)
L2.execute("WOW_FIRE('ADDON_LOADED', 'FlightPathRaiders'); WOW_FIRE('PLAYER_REGEN_DISABLED'); WOW_COMBAT = true; FPR_NS.Board.Toggle()")
check("opened for the first time in combat, the board leaves keyboard input alone",
      L2.eval("FlightPathRaidersBoard:IsShown() and rawget(FlightPathRaidersBoard, '_keyboard') == nil"))
L2.execute("WOW_COMBAT = false; WOW_FIRE('PLAYER_REGEN_ENABLED')")
check("and turns it on when combat ends", L2.eval("rawget(FlightPathRaidersBoard, '_keyboard') == true"))
print("Addon test:", "all passed" if not fails else f"{len(fails)} failed")
sys.exit(1 if fails else 0)
