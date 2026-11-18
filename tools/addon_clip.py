"""Marketing's 30-second clip of a pull, made from the addon itself drawn headless (tools/addon_shot.py):
hub, prep, the pull round by round, the result and the loot window. 1920 x 1080, H.264.
Fonts are stand-ins for the client's, so the in-game capture replaces this at install.
Usage: python3 tools/build_addon.py && python3 tools/addon_clip.py [out.mp4]"""
import os, sys, subprocess, tempfile, shutil
sys.argv = sys.argv[:1] + [tempfile.mkdtemp()] + sys.argv[1:]
import addon_shot as A
OUT_MP4 = sys.argv[2] if len(sys.argv) > 2 else os.path.join(A.ROOT, "marketing/clip-pull.mp4")
frames = []
def hold(name, seconds):
    A.shot(name); frames.append((os.path.join(A.OUT, name + ".png"), seconds))
click = A.L.eval("WOW_CLICK"); tick = A.L.eval("WOW_TICK")
A.L.execute("WOW_FIRE('ADDON_LOADED', 'FlightPathRaiders')")
slash = A.L.eval("SlashCmdList.FLIGHTPATHRAIDERS")
slash("theme dark"); slash("")
# A guild that has reached Ragnaroast on Normal (the boss with finished art), on a seed where the pull is
# a kill, so the clip ends on the loot window.
setup = """(function(seed) local G = FPR_NS.Game local st = G.NewGame(seed)
  for _, b in ipairs({ "magmadad", "baron", "lucifrown", "majordomo" }) do st.progress[b].normalKills = 1; st.progress[b].normalWeek = true end
  for _, c in ipairs(st.roster) do c.skill10 = 600; c.fam10.ragnaroast = 60 end
  st.gold = 2000 return st end)"""
for seed in range(1, 300):
    A.L.execute(f"FlightPathRaidersDB.guild = {setup}({seed * 7919})")
    out = A.L.eval("""(function() local G = FPR_NS.Game local st = G.copy(FlightPathRaidersDB.guild)
      local p = G.DefaultPrep(st, "ragnaroast", "normal") p.tactic = "burn" p.cons = { food = false, elixirs = true, flasks = false }
      for _, id in ipairs(p.ids) do local z = p.zones[tostring(id)] if z == "melee" or z == "front" then p.potions[tostring(id)] = true end end
      local o = G.Pull(st, p) return o.result == "kill" and #o.run.events > 0 and o.run.rounds >= 12 end)()""")
    if out: break
click("Hub"); hold("c00-hub", 3)
click("Prep pull"); hold("c01-prep", 2); click("Burn"); click("Elixirs 30 g"); click("Fire potions: melee + tanks"); hold("c02-prep-burn", 3)
click("Pull")
rounds = A.L.eval("FPR_NS.Board.args.out.run.rounds")
per = min(1.0, 16 / max(1, rounds))
for r in range(1, rounds + 1):
    hold(f"c1{r:02d}-round", per)
    if A.L.eval("FPR_NS.Board.page") != "Playback": break
    tick(0.95)
if A.L.eval("FPR_NS.Board.page") == "Playback": click("Skip to result")
hold("c30-result", 3)
hold("c31-loot", 3)
click("Hand out"); hold("c32-handed", 2)
lst = os.path.join(A.OUT, "frames.txt")
with open(lst, "w") as f:
    for p, s in frames: f.write(f"file '{p}'\nduration {s}\n")
    f.write(f"file '{frames[-1][0]}'\n")
os.makedirs(os.path.dirname(OUT_MP4), exist_ok=True)
subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", lst, "-vf", "fps=30,format=yuv420p",
                "-c:v", "libx264", "-preset", "veryfast", "-crf", "20", OUT_MP4], check=True)
print("clip:", os.path.relpath(OUT_MP4, A.ROOT), f"{sum(s for _, s in frames):.0f} s")
