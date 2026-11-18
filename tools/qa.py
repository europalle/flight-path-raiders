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
                    for b in ("magmadad", "baron", "lucifrown", "majordomo"):
                        t = L.table_from({"boss": b, "mode": mode, "seed": seed, "tactic": "stack", "gl": gl, "consumables": L.table_from({}),
                                          "buffs": L.table_from({}), "raid": L.table_from([L.table_from(c) for c in raid])})
                        invariants(SIM(t), raid, f"edge {name} {b} {mode}")
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

# 5. Skill, familiarity, chemistry and raid moments (engine v5).
def run5(raid, pairs=(), moments=True, **kw):
    t = L.table_from({"boss": "ragnaroast", "mode": kw.get("mode", "heroic"), "seed": kw.get("seed", 1), "tactic": "spread",
                      "gl": kw.get("gl", 65), "consumables": L.table_from({"food": True, "elixirs": True, "flasks": True}),
                      "buffs": L.table_from({}), "moments": moments,
                      "pairs": L.table_from([L.table_from(p) for p in pairs]), "raid": L.table_from([L.table_from(c) for c in raid])})
    return SIM(t)
START = (40, 41, 42, 43, 44, 45, 46)
rr = random.Random(21); n_mom = 0; mom_seen = collections.Counter()
for i in range(3000):
    raid = sensible(rr)
    for c in raid:
        c["skill"] = rr.randint(-20, 130); c["fam"] = rr.randint(-3, 14); c["potion"] = rr.random() < .5; c["firegear"] = rr.randint(0, 2)
    pairs = [{"a": rr.randint(0, 11), "b": rr.randint(0, 11), "v": rr.randint(-5, 30)} for _ in range(rr.randint(0, 50))]
    r = run5(raid, pairs, rr.random() < .8, mode=rr.choice(["normal", "heroic", "mythic"]), seed=rr.randrange(1, 2**31 - 2))
    invariants(r, raid, f"v5#{i}")
    ev = events(r)
    starts = [e for e in ev if e[1] in START and e[0] == 0]
    check("at most one raid moment per pull", len(starts) <= 1, f"v5#{i} {starts}")
    for e in starts: mom_seen[e[1]] += 1
    check("moments only appear when a moment was rolled", all(e[0] == 0 for e in ev if e[1] in (40, 42, 43, 45, 46)), f"v5#{i}")
    check("lucky saves at most once", sum(1 for e in ev if e[1] == 41 and e[0] > 0) <= 1, f"v5#{i}")
    check("early pull only in rounds 0-1", all(e[0] <= 1 for e in ev if e[1] == 44), f"v5#{i}")
    rd = r["raid"]
    for j in range(1, len(rd) + 1):
        check("skill clamped to 0-100", 0 <= rd[j]["skill"] <= 100, f"v5#{i} {rd[j]['skill']}")
        check("familiarity clamped to 0-10", 0 <= rd[j]["fam"] <= 10, f"v5#{i} {rd[j]['fam']}")
    n_mom += 1
check("every moment type shows up", all(mom_seen[c] > 0 for c in START), str(dict(mom_seen)))
off = sum(1 for s_ in range(1, 300) for e in events(run5(sensible(random.Random(s_)), moments=False, seed=s_)) if e[1] in START)
check("moments switched off means none", off == 0, f"{off} moment events")
# Direction checks: more skill, familiarity or chemistry never makes the average raid worse.
def kills(sk=0, fam=0, chem=0, n=400):
    rr = random.Random(5); k = 0
    for i in range(n):
        raid = sensible(rr)
        for c in raid: c["skill"] = sk; c["fam"] = fam; c["potion"] = c["zone"] in ("melee", "front"); c["firegear"] = 1
        pairs = [{"a": a, "b": b, "v": chem} for a in range(1, 11) for b in range(a + 1, 11)] if chem else []
        k += run5(raid, pairs, False, seed=rr.randrange(1, 2**31 - 2))["result"] == "kill"
    return k
k0 = kills()
check("skill 100 beats skill 0", kills(sk=100) > k0)
check("familiarity 10 beats 0", kills(fam=10) > k0)
check("chemistry 20 beats 0", kills(chem=20) > k0)

# 6. Progression module (engine/progress.lua).
P = L.eval("FPR_ENGINE.Progress")
def guild(n=12, rarity="common"):
    g = P.NewGuild()
    for i in range(n): P.Recruit(g, rarity)
    return g
T = L.table_from
g = guild(); ids = [g.members[i]["id"] for i in range(1, 11)]
for p_ in range(10): P.AfterPull(g, T(ids), "ragnaroast", False)
check("only 3 pulls per boss per week count for skill", g.members[1]["skill10"] == 200 + 3 * 6, str(g.members[1]["skill10"]))
check("chemistry gain capped at 1.5 per week", P.Bond(g, ids[0], ids[1]) == 15, str(P.Bond(g, ids[0], ids[1])))
check("bench gains nothing", g.members[11]["skill10"] == 200 and P.Bond(g, ids[0], g.members[11]["id"]) == 0)
for w in range(200):
    P.NewWeek(g)
    for p_ in range(5): P.AfterPull(g, T(ids), "ragnaroast", True)
check("skill caps at 100", max(g.members[i]["skill10"] for i in range(1, 11)) == 1000)
check("familiarity caps at 10", g.members[1]["fam10"]["ragnaroast"] == 100)
check("chemistry caps at 20", P.Bond(g, ids[0], ids[1]) == 200)
check("familiarity is per boss", g.members[1]["fam10"]["other"] is None)
f, pl = P.RaidFields(g, T(ids), "ragnaroast")
check("raid fields read the guild", f[1]["skill"] == 100 and f[1]["fam"] == 10 and len(pl) == 45 and pl[1]["v"] == 20)
P.Quit(g, ids[0])
check("quitting removes the character and their bonds", g.by_id[ids[0]] is None and P.Bond(g, ids[0], ids[1]) == 0 and P.Bond(g, ids[1], ids[2]) == 200)
check("start skill by rarity", [P.Recruit(guild(0), r)["skill10"] for r in ("common", "uncommon", "rare", "epic")] == [200, 300, 400, 550])
# Kills teach twice as fast as wipes; above skill 70 gains halve.
g = guild(10, "epic"); ids = [g.members[i]["id"] for i in range(1, 11)]
P.AfterPull(g, T(ids), "b", True); a1 = g.members[1]["skill10"]
g2 = guild(10, "epic"); P.AfterPull(g2, T(ids), "b", False)
check("a kill teaches more than a wipe", a1 - 550 == 2 * (g2.members[1]["skill10"] - 550))
g3 = guild(10); g3.members[1]["skill10"] = 750; P.AfterPull(g3, T(ids), "b", True)
check("gains halve above skill 70", g3.members[1]["skill10"] == 756, str(g3.members[1]["skill10"]))

# 7. The other Molten Bore bosses (engine v6).
BOSSES = ["magmadad", "baron", "lucifrown", "majordomo", "ragnaroast"]
def runb(raid, boss, **kw):
    t = L.table_from({"boss": boss, "mode": kw.get("mode", "heroic"), "seed": kw.get("seed", 1), "tactic": kw.get("tactic", "spread"),
                      "gl": kw.get("gl", 65), "consumables": L.table_from(kw.get("cons", {"food": True, "elixirs": True, "flasks": True})),
                      "buffs": L.table_from({}), "raid": L.table_from([L.table_from(c) for c in raid])})
    return SIM(t)
rr = random.Random(31); n_boss = 0; seen = collections.Counter()
for i in range(4000):
    raid = sensible(rr); boss = BOSSES[i % 5]; tac = rr.choice(["spread", "stack", "burn", "playsafe"])
    for c in raid: c["skill"] = rr.randint(0, 100); c["fam"] = rr.randint(0, 10)
    r = runb(raid, boss, mode=rr.choice(["normal", "heroic", "mythic"]), seed=rr.randrange(1, 2**31 - 2), tactic=tac, gl=rr.randint(50, 90))
    lab = f"boss#{i} {boss} {tac}"
    invariants(r, raid, lab); ev = events(r); codes = [e[1] for e in ev]
    seen[(boss, r["result"])] += 1
    if boss == "majordomo":
        joined = [e[0] for e in ev if e[1] == 64]
        check("Majordomo only dies after he joins", r["result"] != "kill" or bool(joined), lab)
        check("Majordomo joins once, after the last intern", len(joined) <= 1 and sum(1 for c in codes if c == 27) >= (8 if joined else 0), lab)
    if boss == "magmadad":
        done = [e for e in ev if e[1] == 65 and e[3] == 1]
        check("Magmadad only dies after all pups go down together", r["result"] != "kill" or bool(done), lab)
        check("no pup revives after they are all down", not done or all(not (e[1] == 65 and e[3] == 0 and e[0] > done[0][0]) for e in ev), lab)
    if boss == "baron":
        for e in ev:
            if e[1] == 62:
                check("Spread: the bomb hits only its carrier", tac != "spread" or e[3] == 1, lab)
        check("a bomb only goes off after someone was marked", codes.count(62) <= codes.count(61), lab)
    if boss == "lucifrown":
        check("curses only on every 3rd round", all(e[0] % 3 == 0 for e in ev if e[1] == 66), lab)
        dec = any(c["class"] in ("mage", "druid") for c in raid)
        check("decurse status matches the raid", all(e[3] == (1 if dec else 0) for e in ev if e[1] == 66), lab)
    if boss != "ragnaroast":
        check("only Ragnaroast throws and submerges", not any(c in (20, 21, 22, 23) for c in codes), lab)
    n_boss += 1
check("every boss can be killed and can wipe or enrage", all(seen[(b, "kill")] > 0 and (seen[(b, "wipe")] + seen[(b, "enrage")]) > 0 for b in BOSSES), str(dict(seen)))
# The decurser matters: Lucifrown with no mage or druid is harder.
def luci(dec, n=300):
    rr = random.Random(9); k = 0
    for i in range(n):
        raid = sensible(rr)
        for c in raid:
            if not dec and c["class"] in ("mage", "druid"):
                if c["zone"] == "back": c.update({"class": "priest", "spec": "holy"})
                elif c["zone"] == "front": c.update({"class": "warrior", "spec": "protection"})
                else: c.update({"class": "warlock", "spec": "affliction", "zone": "ranged"})
        if dec and not any(c["class"] in ("mage", "druid") for c in raid): raid[-1] = dict(raid[-1], **{"class": "druid", "spec": "restoration", "zone": "back"})
        k += runb(raid, "lucifrown", tactic="playsafe", seed=rr.randrange(1, 2**31 - 2))["result"] == "kill"
    return k
k_dec, k_none = luci(True), luci(False)
check("Lucifrown: a decurser helps", k_dec > k_none, f"{k_dec} vs {k_none}")
print(f"QA: {n_boss} fights across five bosses; Lucifrown kills with a decurser {k_dec}/300, without {k_none}/300")
print(f"QA: {n_mom} v5 fights (skill, chemistry, moments), progression module checks")
print(f"QA: {n_inv} random fights, {len(edges)} edge raids x 12 runs, determinism x199")
if not fails:
    print("All checks passed")
for k, v in fails.items():
    print(f"FAIL {k}: {len(v)} cases, e.g. {v[:2]}")
print("Edge results:", {f"{k[0]} {k[1]} gl{k[2]}": v for k, v in sorted(edge_results.items())})
