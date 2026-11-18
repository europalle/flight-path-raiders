"""Tuning: every Molten Bore boss by preparation and tactic card (typical raid, moments on).
Usage: python3 tools/tune_bosses.py [bosses] [n] ["lua overrides"] [modes]"""
import os, sys, random
sys.path.insert(0, os.path.dirname(__file__))
from tune import load
from tune_skill import prepped, fight, uniform_pairs, PROFILES, MODES
FIRE = {"ragnaroast"}  # the only boss where fire gear is the right preparation
CARDS = ("spread", "stack", "burn", "playsafe")
PREPS = ("unprepared", "partial", "full", "min-maxed")

def rate(L, n, boss, mode, prep, tac, prof="typical", firegear=None, seed=7):
    sim = L.eval("FPR_ENGINE.Simulate"); sk, fam, ch = PROFILES[prof]
    rr = random.Random(seed); k = 0
    for i in range(n):
        raid, cons, buffs = prepped(rr, prep)
        for c in raid:
            c["skill"] = sk; c["fam"] = fam
            if firegear is False or (firegear is None and boss not in FIRE): c["potion"] = False; c["firegear"] = 0
        t = L.table_from({"boss": boss, "mode": mode, "seed": rr.randrange(1, 2**31 - 2), "tactic": tac, "gl": MODES[mode],
                          "consumables": L.table_from(cons), "buffs": L.table_from(buffs),
                          "pairs": L.table_from([L.table_from(p) for p in uniform_pairs(ch)]),
                          "raid": L.table_from([L.table_from(c) for c in raid])})
        k += sim(t)["result"] == "kill"
    return 100 * k / n

def table(L, n, bosses, modes=("normal", "heroic", "mythic")):
    for boss in bosses:
        print(boss)
        for mode in modes:
            for prep in PREPS:
                r = [rate(L, n, boss, mode, prep, t) for t in CARDS]
                best = CARDS[r.index(max(r))]
                print(f"  {mode:7s} {prep:10s} " + "  ".join(f"{t[:5]} {v:3.0f}" for t, v in zip(CARDS, r)) + f"   best {best}")

if __name__ == "__main__":
    bosses = (sys.argv[1] if len(sys.argv) > 1 else "magmadad,baron,lucifrown,majordomo,ragnaroast").split(",")
    n = int(sys.argv[2]) if len(sys.argv) > 2 else 200
    L = load(sys.argv[3] if len(sys.argv) > 3 and sys.argv[3] else None)
    modes = tuple(sys.argv[4].split(",")) if len(sys.argv) > 4 else ("normal", "heroic", "mythic")
    table(L, n, bosses, modes)
