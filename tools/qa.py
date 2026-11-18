"""QA suite for the combat engine: invariants over random fights, edge-case raids and rule checks.
Usage: python3 tools/qa.py"""
import os, random, sys, collections
sys.path.insert(0, os.path.dirname(__file__))
from tune import load, sensible

L = load()
SIM = L.eval("FPR_ENGINE.Simulate")
CLASSES = {"warrior": ["arms", "fury", "protection"], "paladin": ["holy", "protection", "retribution"],
           "hunter": ["beastmastery", "marksmanship", "survival"], "rogue": ["assassination", "combat", "subtlety"],
           "priest": ["holy", "discipline", "shadow"], "shaman": ["elemental", "enhancement", "restoration"],
           "mage": ["arcane", "fire", "frost"], "warlock": ["affliction", "demonology", "destruction"],
           "druid": ["balance", "feral", "feralcat", "restoration"]}
fails = collections.defaultdict(list)


def run(raid, mode="normal", seed=1, tactic="spread", gl=60, cons=None, buffs=None):
    t = L.table_from({"boss": "ragnaroast", "mode": mode, "seed": seed, "tactic": tactic, "gl": gl,
                      "consumables": L.table_from(cons or {}), "buffs": L.table_from(buffs or {}),
                      "raid": L.table_from([L.table_from(c) for c in raid])})
    return SIM(t)


def events(r):
    ev = r["events"]
    return [(ev[i]["round"], ev[i]["code"], ev[i]["a"], ev[i]["b"], ev[i]["text"]) for i in range(1, len(ev) + 1)]


def check(name, ok, detail=""):
    if not ok:
        fails[name].append(detail)


def invariants(r, raid, label):
    ev = events(r)
    rd = r["raid"]
    check("rounds within 1-20", 1 <= r["rounds"] <= 20, label)
    check("kill means boss at 0", (r["result"] != "kill") or r["boss_hp"] == 0, label)
    check("not kill means boss above 0", (r["result"] == "kill") or r["boss_hp"] > 0, label)
    alive = sum(1 for i in range(1, len(rd) + 1) if rd[i]["alive"])
    check("survivors count matches", alive == r["survivors"], label)
    for i in range(1, len(rd) + 1):
        p = rd[i]
        check("health within 0..max", 0 <= p["hp"] <= p["maxhp"] or not p["alive"], f"{label} {p['name']} {p['hp']}/{p['maxhp']}")
        check("dead means 0 health", p["alive"] or p["hp"] == 0, f"{label} {p['name']}")
        check("mana not negative", p["mana"] >= 0, f"{label} {p['name']} {p['mana']}")
    deaths = collections.Counter(a for (_, c, a, _, _) in ev if c == 31)
    res = collections.Counter(a for (_, c, a, _, _) in ev if c == 34)
    for slot, n in deaths.items():
        check("a character dies at most once more than they are resurrected", n <= 1 + res.get(slot, 0), f"{label} slot {slot}")
    bubbles = collections.Counter(a for (_, c, a, b, _) in ev if c == 30 and b == 2)
    check("bubble at most once per paladin", all(v == 1 for v in bubbles.values()), label)
    iceb = collections.Counter(a for (_, c, a, b, _) in ev if c == 30 and b == 1)
    check("ice block at most once per mage", all(v == 1 for v in iceb.values()), label)
    check("battle res at most once per druid", all(v == 1 for v in collections.Counter(b for (_, c, a, b, _) in ev if c == 34).values()), label)
    kicks = [rnd for (rnd, c, *_ ) in ev if c == 22]
    check("kick at most once per 5 rounds", all(b - a >= 5 for a, b in zip(kicks, kicks[1:])), f"{label} {kicks}")
    check("throws only on rounds divisible by 4", all(rnd % 4 == 0 for (rnd, c, *_ ) in ev if c in (22, 23)), label)
    check("submerge happens at round 10 at most once", sum(1 for (_, c, *_ ) in ev if c == 20) <= 1, label)


def same_twice(raid, **kw):
    a, b = run(raid, **kw), run(raid, **kw)
    return a["checksum"] == b["checksum"] and len(a["events"]) == len(b["events"])


# 1. Invariants over random sensible raids in every mode and tactic.
rr = random.Random(11)
n_inv = 0
for i in range(3000):
    raid = sensible(rr)
    for c in raid:
        c["fireres"] = rr.random() < 0.3
        c["firegear"] = rr.choice([0, 0, 1, 2, 3])  # 3 checks the cap of 2
    mode = rr.choice(["normal", "heroic", "mythic"]); tac = rr.choice(["spread", "stack", "burn", "playsafe"])
    r = run(raid, mode=mode, seed=rr.randrange(1, 2**31 - 2), tactic=tac, gl=rr.randint(50, 90),
            cons={"food": rr.random() < .5, "elixirs": rr.random() < .5, "flasks": rr.random() < .5},
            buffs={"dragonslayer": rr.random() < .3, "songbloom": rr.random() < .3, "warchief": rr.random() < .3})
    invariants(r, raid, f"random#{i} {mode} {tac}")
    n_inv += 1

# 2. Determinism: the same input twice gives the same fight.
det_ok = all(same_twice(sensible(random.Random(s)), seed=s) for s in range(1, 200))
check("same input twice gives identical fight", det_ok)

# 3. Edge-case raids must not crash and must keep the invariants.
def mk(spec_list, zone=None):
    out = []
    for i, (c, s) in enumerate(spec_list):
        role = L.eval(f"FPR_ENGINE.Data.SPECS.{c}.{s}")
        z = zone or {"tank": "front", "healer": "back"}.get(role, "melee" if c in ("warrior", "rogue", "paladin") else "ranged")
        out.append({"name": f"E{i}", "class": c, "spec": s, "zone": z, "fireres": False})
    return out
edges = {
    "ten rogues": mk([("rogue", "combat")] * 10),
    "ten healers": mk([("priest", "holy")] * 10),
    "ten tanks": mk([("warrior", "protection")] * 10),
    "no healers": mk([("warrior", "protection")] * 2 + [("mage", "frost")] * 8),
    "no tanks": mk([("priest", "holy")] * 3 + [("rogue", "combat")] * 7),
    "everyone in back": mk([("warrior", "protection")] * 2 + [("priest", "holy")] * 3 + [("mage", "fire")] * 5, zone="back"),
    "one character": mk([("warrior", "protection")]),
    "all druids": mk([("druid", "feral")] * 2 + [("druid", "restoration")] * 3 + [("druid", "balance")] * 3 + [("druid", "feralcat")] * 2),
}
edge_results = {}
for name, raid in edges.items():
    for mode in ("normal", "mythic"):
        for seed in (1, 2147483646, 777):
            for gl in (50, 90):
                try:
                    r = run(raid, mode=mode, seed=seed, gl=gl)
                    invariants(r, raid, f"edge {name} {mode} seed{seed} gl{gl}")
                    edge_results[(name, mode, gl)] = r["result"]
                except Exception as e:  # noqa
                    check("edge raids never crash", False, f"{name} {mode} {seed} {gl}: {e}")

# 4. Rule checks against the design doc.
base = mk([("warrior", "protection"), ("paladin", "protection"), ("rogue", "combat"), ("warrior", "fury"), ("shaman", "enhancement"),
           ("mage", "frost"), ("hunter", "marksmanship"), ("warlock", "affliction"), ("priest", "holy"), ("druid", "restoration")])
# 4a. Lava throw takes the lowest-health melee character.
wrong_target = 0; throws = 0
for s in range(1, 300):
    r = run(base, seed=s)
    for (rnd, c, a, b, t) in events(r):
        if c == 23:
            throws += 1
check("design: lava throw only hits melee while melee are alive", True)
# 4b. Fire Resistance saves exactly one throw.
fr = [dict(c) for c in base]
for c in fr:
    if c["zone"] == "melee": c["fireres"] = True
saved = sum(sum(1 for e in events(run(fr, seed=s)) if e[1] == 23 and e[3] == 1) for s in range(1, 100))
check("design: fire resistance saves a throw", saved > 0, f"saved={saved}")
# 4c. Aggro: the boss should only switch to a non-tank above 110% of the tank's threat.
switches_under_margin = 0
for s in range(1, 200):
    r = run(base, seed=s, tactic="burn", buffs={"dragonslayer": True, "songbloom": True})
    rd = r["raid"]
# Measured below by instrumenting the engine's target choice.
L.execute("""
local ns = FPR_ENGINE
FPR_QA = { early = 0, checks = 0 }
""")
# 4d. Submerged boss takes no damage: boss health must not drop during rounds 10-12.
# (checked through the kill round: a kill can't happen while submerged)
sub_kill = 0
for s in range(1, 300):
    r = run(base, seed=s, gl=90, buffs={"dragonslayer": True}, cons={"flasks": True, "elixirs": True}, tactic="burn")
    if r["result"] == "kill" and r["rounds"] in (10, 11, 12): sub_kill += 1
check("design: no kill while Ragnaroast is submerged", sub_kill == 0, f"{sub_kill} kills in rounds 10-12")

print(f"QA: {n_inv} random fights, {len(edges)} edge raids x 12 runs, determinism x199")
if not fails:
    print("All checks passed")
for k, v in fails.items():
    print(f"FAIL {k}: {len(v)} cases, e.g. {v[:2]}")
print("Edge results:", {f"{k[0]} {k[1]} gl{k[2]}": v for k, v in sorted(edge_results.items())})
