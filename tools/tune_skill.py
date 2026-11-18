"""Tuning: player skill, familiarity, chemistry and raid moments.
Usage: python3 tools/tune_skill.py [sections] [n] ["lua overrides"]
Sections: 1 profiles x prep, 2 moments on/off, 3 ten-week campaign, 4 bench and quit cost, 5 moment mix"""
import os, sys, random, collections
sys.path.insert(0, os.path.dirname(__file__))
from tune import load, sensible
from tune_prep import PREP

PROFILES = {  # skill, familiarity, chemistry per pair
    "baseline": (0, 0, 0),     # pass 3 numbers (no experience at all)
    "fresh": (30, 0, 0),       # brand new guild of mixed recruits
    "typical": (50, 5, 8),     # about week 5
    "veteran": (75, 10, 16),   # a raid that has been together for months
}
MODES = {"normal": 60, "heroic": 65, "mythic": 74}

def prepped(rr, prep):
    cons, buffs, pz, fg, aura = PREP[prep]
    raid = sensible(rr)
    if aura and not any(c["class"] in ("paladin", "shaman") for c in raid):
        for c in raid:
            if c["zone"] == "back": c.update({"class": "paladin", "spec": "holy"}); break
    for c in raid:
        c["potion"] = c["zone"] in pz; c["firegear"] = fg.get(c["zone"], 0)
    return raid, cons, buffs

def fight(L, sim, raid, mode, seed, tac, cons, buffs, pairs=(), moments=True):
    t = L.table_from({"boss": "ragnaroast", "mode": mode, "seed": seed, "tactic": tac, "gl": MODES[mode],
                      "consumables": L.table_from(cons), "buffs": L.table_from(buffs), "moments": moments,
                      "pairs": L.table_from([L.table_from(p) for p in pairs]),
                      "raid": L.table_from([L.table_from(c) for c in raid])})
    return sim(t)

def uniform_pairs(chem, n=10):
    return [{"a": i, "b": j, "v": chem} for i in range(1, n + 1) for j in range(i + 1, n + 1)] if chem else []

def rate(L, n, mode, prep, tac, prof, moments=True, seed=7):
    sim = L.eval("FPR_ENGINE.Simulate"); sk, fam, ch = PROFILES[prof] if isinstance(prof, str) else prof
    rr = random.Random(seed); k = 0
    for i in range(n):
        raid, cons, buffs = prepped(rr, prep)
        for c in raid: c["skill"] = sk; c["fam"] = fam
        k += fight(L, sim, raid, mode, rr.randrange(1, 2**31 - 2), tac, cons, buffs, uniform_pairs(ch), moments)["result"] == "kill"
    return 100 * k / n

def s1(L, n):
    print("1. Kill % by experience profile (Spread/Burn)")
    for mode in MODES:
        for prof in PROFILES:
            print(f"  {mode:7s} {prof:9s} " + "  ".join(f"{p}: {rate(L,n,mode,p,'spread',prof):3.0f}/{rate(L,n,mode,p,'burn',prof):3.0f}" for p in PREP))

def s2(L, n):
    print("2. Raid moments on vs off (fresh and veteran, Spread)")
    for mode, prep in (("normal", "unprepared"), ("heroic", "full"), ("mythic", "min-maxed")):
        for prof in ("fresh", "veteran"):
            on, off = rate(L, n, mode, prep, "spread", prof, True), rate(L, n, mode, prep, "spread", prof, False)
            print(f"  {mode:7s} {prep:10s} {prof:8s} on {on:5.1f}  off {off:5.1f}  net {on-off:+5.1f}")

def campaign(L, weeks, pulls, mode, prep, tac, seed, bench_week=None, quit_week=None, roster=12):
    """One guild raiding weekly. Returns kill % per week. Bench: from bench_week two veterans sit and two
    fresh recruits play. Quit: at quit_week the two most bonded veterans leave and two recruits join."""
    sim = L.eval("FPR_ENGINE.Simulate"); P = L.eval("FPR_ENGINE.Progress")
    rr = random.Random(seed); g = P.NewGuild(L.table())  # NewGuild ignores args
    rar = ["common", "uncommon", "uncommon", "rare", "rare", "epic"]
    for i in range(roster): P.Recruit(g, rr.choice(rar))
    raid, cons, buffs = prepped(rr, prep)
    out = []
    core = [g.members[i]["id"] for i in range(1, 11)]
    bench = [g.members[11]["id"], g.members[12]["id"]]
    for w in range(1, weeks + 1):
        ids = core
        if quit_week and w == quit_week:  # slots 3 and 4 leave the guild; two new recruits take their places
            for x in core[2:4]: P.Quit(g, x)
            core = core[:2] + [P.Recruit(g, "uncommon")["id"], P.Recruit(g, "uncommon")["id"]] + core[4:]
            ids = core
        if bench_week and w >= bench_week:  # slots 3 and 4 sit out; the two bench players fill in
            ids = core[:2] + bench + core[4:]
        k = 0
        for p in range(pulls):
            f, pl = P.RaidFields(g, L.table_from(ids), "ragnaroast")
            for i, c in enumerate(raid):
                c["skill"] = f[i + 1]["skill"]; c["fam"] = f[i + 1]["fam"]
            pairs = [{"a": pl[j]["a"], "b": pl[j]["b"], "v": pl[j]["v"]} for j in range(1, len(pl) + 1)]
            r = fight(L, sim, raid, mode, rr.randrange(1, 2**31 - 2), tac, cons, buffs, pairs)
            kill = r["result"] == "kill"; k += kill
            P.AfterPull(g, L.table_from(ids), "ragnaroast", kill)
        P.NewWeek(g)
        out.append(k / pulls)
    m = [g.by_id[i] for i in ids]
    sk = sum(x["skill10"] for x in m) / 100; fam = sum((x["fam10"]["ragnaroast"] or 0) for x in m) / 100
    return out, (sk, fam)

def s3(L, n, mode="heroic", prep="full"):
    print(f"3. Ten-week campaign, {mode} {prep} prep, Spread, 5 pulls a week ({n} guilds)")
    tot = [0] * 10; end = [0, 0]
    for s in range(n):
        o, e = campaign(L, 10, 5, mode, prep, "spread", 1000 + s)
        tot = [a + b for a, b in zip(tot, o)]; end = [end[0] + e[0], end[1] + e[1]]
    print("  week " + " ".join(f"{w+1:4d}" for w in range(10)))
    print("  kill " + " ".join(f"{100*t/n:4.0f}" for t in tot))
    print(f"  after week 10: average skill {end[0]/n:.0f}, familiarity {end[1]/n:.1f}")

def s4(L, n):
    print("4. Week 8-10 kill %: same ten vs bench two vs two quit at week 7 (heroic full, Spread)")
    res = {}
    for label, kw in (("same ten", {}), ("bench two", {"bench_week": 8}), ("two quit", {"quit_week": 7})):
        t = 0
        for s in range(n):
            o, _ = campaign(L, 10, 5, "heroic", "full", "spread", 1000 + s, **kw); t += sum(o[7:]) / 3
        res[label] = 100 * t / n
        print(f"  {label:10s} {res[label]:5.1f}")

def s5(L, n):
    print("5. Which moments fire (veteran vs fresh, heroic full)")
    sim = L.eval("FPR_ENGINE.Simulate")
    for prof in ("fresh", "veteran"):
        sk, fam, ch = PROFILES[prof]; rr = random.Random(3); c = collections.Counter()
        for i in range(n):
            raid, cons, buffs = prepped(rr, "full")
            for x in raid: x["skill"] = sk; x["fam"] = fam
            r = fight(L, sim, raid, "heroic", rr.randrange(1, 2**31 - 2), "spread", cons, buffs, uniform_pairs(ch))
            ev = r["events"]; codes = {ev[j]["code"] for j in range(1, len(ev) + 1)}
            hit = [x for x in (40, 41, 42, 43, 44, 45, 46) if x in codes]
            c[hit[0] if hit else 0] += 1
        names = {0: "none", 40: "pep talk", 41: "lucky", 42: "in the zone", 43: "disconnect", 44: "early pull", 45: "no repair", 46: "coffee"}
        print(f"  {prof:8s} " + "  ".join(f"{names[k]} {100*v/n:.0f}%" for k, v in sorted(c.items())))

if __name__ == "__main__":
    secs = sys.argv[1] if len(sys.argv) > 1 else "1,2,3,4,5"
    n = int(sys.argv[2]) if len(sys.argv) > 2 else 300
    L = load(sys.argv[3] if len(sys.argv) > 3 else None)
    for s in secs.split(","):
        {"1": s1, "2": s2, "3": lambda L, n: s3(L, max(20, n // 10)), "4": lambda L, n: s4(L, max(20, n // 10)), "5": s5, "6": lambda L, n: None}[s](L, n)

def s6(L, n):
    print("6. Kill % when each moment fires vs no moment (typical raid, heroic full, Spread)")
    sim = L.eval("FPR_ENGINE.Simulate"); sk, fam, ch = PROFILES["typical"]
    rr = random.Random(5); k = collections.Counter(); c = collections.Counter()
    for i in range(n):
        raid, cons, buffs = prepped(rr, "full")
        for x in raid: x["skill"] = sk; x["fam"] = fam
        r = fight(L, sim, raid, "heroic", rr.randrange(1, 2**31 - 2), "spread", cons, buffs, uniform_pairs(ch))
        ev = r["events"]; codes = {ev[j]["code"] for j in range(1, len(ev) + 1)}
        hit = [x for x in (40, 41, 42, 43, 44, 45, 46) if x in codes]; key = hit[0] if hit else 0
        c[key] += 1; k[key] += r["result"] == "kill"
    names = {0: "none", 40: "pep talk", 41: "lucky", 42: "in the zone", 43: "disconnect", 44: "early pull", 45: "no repair", 46: "coffee"}
    for key in sorted(c): print(f"  {names[key]:12s} {100*k[key]/c[key]:5.1f}%  ({c[key]} pulls)")
if __name__ == "__main__" and "6" in (sys.argv[1] if len(sys.argv) > 1 else ""):
    s6(L, n)
