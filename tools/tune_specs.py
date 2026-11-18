"""Tuning sweeps: per-spec output, melee count, consumables, gear level, tactic cards."""
import os, sys, random, collections, statistics
sys.path.insert(0, os.path.dirname(__file__))
import tune
from tune import load, run, sensible
L = load(); SIM = L.eval("FPR_ENGINE.Simulate")
BASE = [("T1","warrior","protection","front"),("T2","paladin","protection","front"),("M1","rogue","combat","melee"),
        ("M2","warrior","fury","melee"),("X","mage","frost","ranged"),("R1","hunter","marksmanship","ranged"),
        ("R2","warlock","affliction","ranged"),("R3","mage","arcane","ranged"),("H1","priest","holy","back"),("H2","druid","restoration","back")]
def fight(raid, seed, mode="normal", tactic="spread", gl=60, cons=None, buffs=None):
    t = L.table_from({"boss":"ragnaroast","mode":mode,"seed":seed,"tactic":tactic,"gl":gl,
        "consumables":L.table_from(cons or {"food":True}),"buffs":L.table_from(buffs or {}),
        "raid":L.table_from([L.table_from({"name":n,"class":c,"spec":s,"zone":z,"fireres":fr}) for n,c,s,z,fr in raid])})
    return SIM(t)
DMG = [("warrior","arms","melee"),("warrior","fury","melee"),("paladin","retribution","melee"),("rogue","assassination","melee"),
       ("rogue","combat","melee"),("rogue","subtlety","melee"),("shaman","enhancement","melee"),("druid","feralcat","melee"),
       ("hunter","beastmastery","ranged"),("hunter","marksmanship","ranged"),("hunter","survival","ranged"),("mage","arcane","ranged"),
       ("mage","fire","ranged"),("mage","frost","ranged"),("warlock","affliction","ranged"),("warlock","demonology","ranged"),
       ("warlock","destruction","ranged"),("priest","shadow","ranged"),("shaman","elemental","ranged"),("druid","balance","ranged")]
HEAL = [("priest","holy"),("priest","discipline"),("paladin","holy"),("shaman","restoration"),("druid","restoration")]
TANK = [("warrior","protection"),("paladin","protection"),("druid","feral")]
N = 200

def s1():
    print("1. Damage per round alive, each damage spec in the X slot (Normal, fire res on everyone so throws don't decide it)")
    rows = []
    for c, s, z in DMG:
        raid = [(n, cc, ss, zz, True) for n, cc, ss, zz in BASE]; raid[4] = ("X", c, s, z, True)
        vals = []; kills = 0
        for seed in range(1, N + 1):
            r = fight(raid, seed); p = r["raid"][5]
            vals.append(p["dealt"] / max(1, p["alive_rounds"])); kills += r["result"] == "kill"
        rows.append((f"{c} {s}", statistics.mean(vals), kills / N))
    avg = statistics.mean(v for _, v, _ in rows)
    for name, v, k in sorted(rows, key=lambda x: -x[1]):
        print(f"   {name:24s} {v:6.1f}  {100*(v/avg-1):+6.1f}% vs average   raid kill {k*100:5.1f}%")

def s2():
    print("2. Healing per round, each healer spec in the H1 slot")
    hrows = []
    for c, s in HEAL:
        raid = [(n, cc, ss, zz, True) for n, cc, ss, zz in BASE]; raid[8] = ("H1", c, s, "back", True)
        vals = []
        for seed in range(1, N + 1):
            r = fight(raid, seed, mode="heroic", gl=65); p = r["raid"][9]
            vals.append(p["healed"] / max(1, p["alive_rounds"]))
        hrows.append((f"{c} {s}", statistics.mean(vals)))
    havg = statistics.mean(v for _, v in hrows)
    for name, v in sorted(hrows, key=lambda x: -x[1]):
        print(f"   {name:24s} {v:6.1f}  {100*(v/havg-1):+6.1f}% vs average")

def s3():
    print("3. Tanks: kill rate and tank deaths with each tank spec in T1 (Heroic, GL 65)")
    for c, s in TANK:
        raid = [(n, cc, ss, zz, True) for n, cc, ss, zz in BASE]; raid[0] = ("T1", c, s, "front", True)
        kills = 0; tdeaths = 0
        for seed in range(1, N + 1):
            r = fight(raid, seed, mode="heroic", gl=65); kills += r["result"] == "kill"; tdeaths += not r["raid"][1]["alive"]
        print(f"   {c+' '+s:24s} kill {100*kills/N:5.1f}%   T1 dead at end {100*tdeaths/N:5.1f}%")

def s4():
    print("4. Melee count (rest ranged), Normal and Heroic, with and without Fire Resistance on melee")
    for nm in range(0, 7):
        for fr in (False, True):
            out = []
            for mode, gl in (("normal", 60), ("heroic", 65)):
                kills = 0
                for seed in range(1, N + 1):
                    raid = [("T1","warrior","protection","front",fr),("T2","paladin","protection","front",fr)]
                    for i in range(nm): raid.append((f"M{i}", ("rogue","warrior")[i%2], ("combat","fury")[i%2], "melee", fr))
                    for i in range(6 - nm): raid.append((f"R{i}", ("mage","hunter","warlock")[i%3], ("frost","marksmanship","affliction")[i%3], "ranged", fr))
                    raid += [("H1","priest","holy","back",fr),("H2","druid","restoration","back",fr)]
                    kills += fight(raid, seed, mode=mode, gl=gl)["result"] == "kill"
                out.append(f"{mode} {100*kills/N:5.1f}%")
            print(f"   {nm} melee, fire res {'on ' if fr else 'off'}: " + "  ".join(out))

def s5():
    print("5. Value of each consumable and buff (Heroic, GL 65, base raid, fire res on melee): kill rate")
    opts = {"nothing": ({}, {}), "food": ({"food":True}, {}), "elixirs": ({"elixirs":True}, {}), "flasks": ({"flasks":True}, {}),
            "dragonslayer": ({}, {"dragonslayer":True}), "songbloom": ({}, {"songbloom":True}), "warchief": ({}, {"warchief":True})}
    for name, (cons, buffs) in opts.items():
        raid = [(n, c, s, z, z == "melee") for n, c, s, z in BASE]
        k = sum(fight(raid, seed, mode="heroic", gl=65, cons=cons, buffs=buffs)["result"] == "kill" for seed in range(1, N + 1))
        print(f"   {name:13s} {100*k/N:5.1f}%")

def s6():
    print("6. Gear level curve (base raid, fire res on melee, food, Spread)")
    for mode in ("normal", "heroic", "mythic"):
        line = []
        for gl in (55, 60, 65, 70, 75, 80):
            raid = [(n, c, s, z, z == "melee") for n, c, s, z in BASE]
            k = sum(fight(raid, seed, mode=mode, gl=gl)["result"] == "kill" for seed in range(1, 121))
            line.append(f"GL{gl} {100*k/120:4.0f}%")
        print(f"   {mode:7s} " + "  ".join(line))

def s7():
    print("7. Tactic cards after the aggro fix (sensible raids, setups from tune.py)")
    tune.report(run(load(), 300))

SECTIONS = sys.argv[1].split(",") if len(sys.argv) > 1 else list("1234567")
for k in SECTIONS:
    globals()["s" + k]()
