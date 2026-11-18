"""Gate check 4, the layout half: how close the addon's screens are to the hi-fi. For every line of text
that appears on both (same words, so labels and headings rather than data like names and numbers), it
compares position and size. The hi-fi records a text box from its baseline and the addon from the top of
the line, so one fixed offset per text size, measured across every screen, is taken out first.
Pass: a line is "on the hi-fi" when it is within 2 units on both axes and the same size within 1 unit.
Usage: python3 tools/addon_shot.py && python3 tools/layout_compare.py [--strict]"""
import json, os, sys, statistics
ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
SCREENS = ["hub", "prep", "playback", "results", "loot", "roster", "tavern", "journal", "settings"]
# Only fixed labels count (words written into the addon's code, like "Tactic" or "Pull"): names, numbers
# and other data differ between the hi-fi's sample guild and the addon's, so they can't be compared.
import glob, re
SRC = "".join(open(f).read() for f in glob.glob(os.path.join(ROOT, "addon/src/*.lua")))
def fixed(txt): return ('"' + txt + '"') in SRC
pairs = {}
for s in SCREENS:
    for t in ("light", "dark"):
        hp, ap = os.path.join(ROOT, f"ux/hifi/{s}-{t}.texts.json"), os.path.join(ROOT, f"addon/shots/{s}-{t}.texts.json")
        if not (os.path.exists(hp) and os.path.exists(ap)): continue
        hi = {}
        for x in json.load(open(hp)): hi.setdefault(x["text"].strip(), x)
        ad = {}
        for x in json.load(open(ap)):
            if not x.get("behind"): ad.setdefault(x["text"].strip(), x)
        pairs[(s, t)] = [(k, hi[k], ad[k]) for k in hi if k in ad and len(k) > 1 and fixed(k)]
# The convention offset: addon top minus hi-fi box top, as a share of the text size, the median of every match.
ratios = [(a["y"] - h["y"]) / h["size"] for v in pairs.values() for _, h, a in v if h["size"]]
k = statistics.median(ratios) if ratios else 0
total = good = 0
worst = []
print(f"Convention offset: addon y = hi-fi y {k:+.2f} x size")
for (s, t), v in pairs.items():
    ok = 0
    for txt, h, a in v:
        # Centred and right-aligned text is compared by its centre or right edge.
        dx = min(abs(a["x"] - h["x"]), abs((a["x"] + a["w"]) - (h["x"] + h["w"])), abs((a["x"] + a["w"] / 2) - (h["x"] + h["w"] / 2)))
        dy = abs(a["y"] - (h["y"] + k * h["size"]))
        ds = abs(a["size"] - h["size"])
        if dx <= 2 and dy <= 2 and ds <= 1: ok += 1
        else: worst.append((max(dx, dy), s, t, txt, round(dx, 1), round(dy, 1), ds))
    total += len(v); good += ok
    print(f"  {s:9} {t:5}: {ok:3}/{len(v):3} shared lines on the hi-fi")
share = 100 * good / max(1, total)
print(f"On the hi-fi: {good}/{total} shared lines ({share:.0f}%)")
worst.sort(reverse=True)
for w in worst[:int(os.environ.get("N", 15))]: print(f"  off by {w[0]:5.1f}: {w[1]}-{w[2]} '{w[3][:40]}' dx {w[4]} dy {w[5]} size {w[6]}")
if "--strict" in sys.argv: sys.exit(0 if share >= 90 else 1)
