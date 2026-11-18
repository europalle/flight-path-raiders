"""Tuning pass 3: kill rates by preparation level (random sensible raids).
Usage: python3 tools/tune_prep.py [n] ["lua overrides"]"""
import os, sys, random
sys.path.insert(0, os.path.dirname(__file__))
from tune import load, sensible
PREP = {
    # name: consumables, buffs, potion zones, fire gear by zone, force aura
    "unprepared": ({}, {}, (), {}, False),
    "partial":    ({"food": True, "elixirs": True}, {}, ("melee",), {"front": 1, "melee": 1}, False),
    "full":       ({"food": True, "elixirs": True, "flasks": True}, {}, ("melee", "front"), {"front": 2, "melee": 2, "ranged": 1, "back": 1}, False),
    "min-maxed":  ({"food": True, "elixirs": True, "flasks": True}, {"dragonslayer": True, "songbloom": True, "warchief": True},
                   ("melee", "front", "ranged", "back"), {"front": 2, "melee": 2, "ranged": 2, "back": 2}, True),
}
def run(L, n=300, modes=(("normal", 60), ("heroic", 65), ("mythic", 74)), tactics=("spread", "burn"), preps=PREP):
    sim = L.eval("FPR_ENGINE.Simulate"); out = {}
    for mode, gl in modes:
        for prep, (cons, buffs, pz, fg, aura) in preps.items():
            for tac in tactics:
                rr = random.Random(7); kills = 0
                for i in range(n):
                    raid = sensible(rr)
                    if aura and not any(c["class"] in ("paladin", "shaman") for c in raid):
                        raid[-1] = dict(raid[-1], **{"class": "paladin", "spec": "holy", "zone": "back"}) if raid[-1]["zone"] == "back" else raid[-1]
                        if not any(c["class"] in ("paladin", "shaman") for c in raid):
                            for c in raid:
                                if c["zone"] == "back": c.update({"class": "paladin", "spec": "holy"}); break
                    for c in raid:
                        c["potion"] = c["zone"] in pz; c["firegear"] = fg.get(c["zone"], 0)
                    t = L.table_from({"boss": "ragnaroast", "mode": mode, "seed": rr.randrange(1, 2**31 - 2), "tactic": tac, "gl": gl,
                                      "consumables": L.table_from(cons), "buffs": L.table_from(buffs),
                                      "raid": L.table_from([L.table_from(c) for c in raid])})
                    kills += sim(t)["result"] == "kill"
                out[(mode, prep, tac)] = kills / n
    return out
def report(out):
    modes = sorted({k[0] for k in out}, key=["normal", "heroic", "mythic"].index)
    for mode in modes:
        print(f"{mode:7s} " + "   ".join(f"{p}: " + "/".join(f"{100*out[(mode,p,t)]:3.0f}" for t in ("spread", "burn")) for p in PREP))
if __name__ == "__main__":
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 300
    report(run(load(sys.argv[2] if len(sys.argv) > 2 else None), n))
    print("(each cell: Spread/Burn kill %)")
