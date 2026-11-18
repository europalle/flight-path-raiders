"""Tuning pass 5: what one trait on one raider is worth, averaged over all five bosses on each boss's
right card. Also morale above 80 (Normal only) and the raid leader's favourite.
Usage: python3 tools/tune_traits.py [n]"""
import os, sys, random
sys.path.insert(0, os.path.dirname(__file__))
from tune import load
from tune_skill import prepped, uniform_pairs, PROFILES, MODES
BOSSES = [("magmadad", "burn"), ("baron", "spread"), ("lucifrown", "playsafe"), ("majordomo", "stack"), ("ragnaroast", "burn")]
FIRE = {"ragnaroast"}
TRAITS = ["pulls_on_cooldown", "stands_in_fire", "never_stands_in_fire", "parse_goblin", "alt_tabbed", "partner_aggro", "hardcore_andy",
          "backseat_raid_leader", "keyboard_turner", "main_character", "pug_hero", "pet_on_aggressive", "raid_leaders_favourite"]

def who(raid, trait):
    """Which raider carries the trait: tanks pull, hunters bring pets, otherwise the first damage dealer."""
    role = lambda c: c["zone"]
    if trait == "pulls_on_cooldown": return next(i for i, c in enumerate(raid) if c["zone"] == "front")
    if trait == "pet_on_aggressive":
        for i, c in enumerate(raid):
            if c["class"] == "hunter": return i
        return None
    return next(i for i, c in enumerate(raid) if c["zone"] in ("melee", "ranged"))

def rate(L, n, mode, prep, prof, trait=None, morale=70, extra=None):
    sim = L.eval("FPR_ENGINE.Simulate"); sk, fam, ch = PROFILES[prof]; tot = 0; cnt = 0
    for boss, card in BOSSES:
        rr = random.Random(11); k = 0; m = 0
        for i in range(n):
            raid, cons, buffs = prepped(rr, prep)
            for c in raid:
                c["skill"] = sk; c["fam"] = fam; c["morale"] = morale
                if boss not in FIRE: c["potion"] = False; c["firegear"] = 0
            seed = rr.randrange(1, 2**31 - 2)
            if trait:
                j = who(raid, trait)
                if j is None: continue
                raid[j]["traits"] = L.table_from([trait])
                if trait == "main_character": raid[j]["looted"] = True
                if trait == "pug_hero":
                    for c in raid[-2:]: c["new"] = True
            if extra: extra(raid)
            t = L.table_from({"boss": boss, "mode": mode, "seed": seed, "tactic": card, "gl": MODES[mode],
                              "consumables": L.table_from(cons), "buffs": L.table_from(buffs),
                              "pairs": L.table_from([L.table_from(p) for p in uniform_pairs(ch)]),
                              "raid": L.table_from([L.table_from(c) for c in raid])})
            k += sim(t)["result"] == "kill"; m += 1
        if m: tot += k / m; cnt += 1
    return 100 * tot / cnt

if __name__ == "__main__":
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 200
    L = load()
    for mode, prep, prof in (("normal", "unprepared", "fresh"), ("heroic", "full", "typical")):
        base = rate(L, n, mode, prep, prof)
        print(f"{mode} ({prep}, {prof}), average over the five bosses on their right card: baseline {base:.1f}%")
        for tr in TRAITS:
            v = rate(L, n, mode, prep, prof, tr)
            print(f"  {tr:24s} {v:5.1f}%  {v - base:+5.1f}")
        if mode == "normal":
            v = rate(L, n, mode, prep, prof, morale=90); print(f"  {'morale 90 (everyone)':24s} {v:5.1f}%  {v - base:+5.1f}")
            v = rate(L, n, mode, prep, prof, morale=30); print(f"  {'morale 30 (everyone)':24s} {v:5.1f}%  {v - base:+5.1f}")
