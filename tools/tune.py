"""Tuning harness: runs the real Lua engine (Lua 5.1 via LuaJIT) over many sensible raids.
Usage: python3 tools/tune.py [fights_per_cell]"""
import random, sys, collections, os
import lupa.luajit21 as lj
ROOT = os.path.join(os.path.dirname(__file__), "..")
def load(overrides=None):
    L = lj.LuaRuntime()
    for f in ("engine/rng.lua", "engine/data.lua", "engine/sim.lua", "engine/validate.lua", "engine/progress.lua"):
        L.execute(open(os.path.join(ROOT, f)).read())
    if overrides:
        L.execute(overrides)
    return L
TANKS = [("warrior","protection"),("paladin","protection"),("druid","feral")]
HEALS = [("priest","holy"),("priest","discipline"),("paladin","holy"),("shaman","restoration"),("druid","restoration")]
MELEE = [("warrior","arms"),("warrior","fury"),("rogue","assassination"),("rogue","combat"),("rogue","subtlety"),
         ("shaman","enhancement"),("paladin","retribution"),("druid","feralcat")]
RANGED = [("mage","arcane"),("mage","fire"),("mage","frost"),("hunter","beastmastery"),("hunter","marksmanship"),
          ("hunter","survival"),("warlock","affliction"),("warlock","demonology"),("warlock","destruction"),
          ("priest","shadow"),("shaman","elemental"),("druid","balance")]
def sensible(r):
    raid = []
    for c,s in r.sample(TANKS, 2) if False else [r.choice(TANKS) for _ in range(2)]:
        raid.append(dict(name="T", **{"class":c}, spec=s, zone="front"))
    nh = r.choice([2,3])
    for c,s in [r.choice(HEALS) for _ in range(nh)]:
        raid.append(dict(name="H", **{"class":c}, spec=s, zone="back"))
    nd = 10 - len(raid); nm = r.randint(1, nd - 1)
    for c,s in [r.choice(MELEE) for _ in range(nm)]:
        raid.append(dict(name="M", **{"class":c}, spec=s, zone="melee"))
    for c,s in [r.choice(RANGED) for _ in range(nd - nm)]:
        raid.append(dict(name="R", **{"class":c}, spec=s, zone="ranged"))
    return raid
SETUPS = {  # mode: (gear level, consumables, buffs, fire resistance on melee)
    "normal": (60, {"food": True}, {}, False),
    "heroic": (65, {"food": True, "elixirs": True}, {}, True),
    "mythic": (74, {"food": True, "elixirs": True, "flasks": True}, {"dragonslayer": True}, True),
}
def run(L, n=600, seed=1):
    r = random.Random(seed)
    sim = L.eval("FPR_ENGINE.Simulate")
    out = {}
    for mode,(gl,cons,buffs,fr) in SETUPS.items():
        per = {}
        for tactic in ("spread","stack","burn","playsafe"):
            rr = random.Random(seed)
            kills=0; rounds=[]; causes=collections.Counter()
            for i in range(n):
                raid = sensible(rr)
                for c in raid:
                    c["fireres"] = fr and c["zone"] == "melee"
                lt = L.table_from({"boss":"ragnaroast","mode":mode,"seed":rr.randrange(1,2**31-1),"tactic":tactic,"gl":gl,
                    "consumables":L.table_from(cons),"buffs":L.table_from(buffs),
                    "raid":L.table_from([L.table_from(c) for c in raid])})
                res = sim(lt)
                if res["result"] == "kill": kills+=1; rounds.append(res["rounds"])
                causes[res["result"]] += 1
            per[tactic] = (kills/n, sum(rounds)/max(1,len(rounds)), dict(causes))
        out[mode] = per
    return out
def report(out):
    for mode, per in out.items():
        best = max(per.items(), key=lambda kv: kv[1][0])
        print(f"{mode:7s} " + "  ".join(f"{t}:{v[0]*100:5.1f}% (r{v[1]:4.1f})" for t,v in per.items()) + f"   best={best[0]}")
if __name__ == "__main__":
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 400
    report(run(load(), n))
