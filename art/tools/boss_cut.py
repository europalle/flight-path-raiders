"""Cuts a Gemini boss sheet into the boss and its separate props, transparent, into art/kit/bosses.
The boss is the biggest piece plus everything that floats over it (a storm cloud, smoke, sparks);
pieces off to the side are props, named left to right. Bosses face left (the raid stands on the left),
so a sheet drawn facing right is mirrored. The ink ground line under the feet is removed.
Usage: python3 art/tools/boss_cut.py            (every sheet in SHEETS)
       python3 art/tools/boss_cut.py F3 F4      (only these)"""
import os, sys, numpy as np
from PIL import Image
from scipy import ndimage
sys.path.insert(0, os.path.dirname(__file__))
from kit_cut import key
ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "kit/bosses")
# code: (boss id, prop names left to right, mirror so the boss faces left)
SHEETS = {
    "F3": ("magmadad", ["pup-1", "pup-2", "pup-3"], True),
    "F4": ("baron", ["bomb"], True),
    "F5": ("lucifrown", ["staff"], False),
    "F6": ("majordomo", ["intern-1", "intern-2"], False),
}
# F1b is Ragnaroast as puppet parts (issue #9): every piece is a part, named by where it sits on the sheet.
PARTS = {"F1b": ("ragnaroast", {"head": (0, 0), "arm-low": (0, 1), "body": (1, 0), "arm-raised": (2, 0), "pot": (2, 1)})}

def drop_ground_line(a, share=0.8):
    """Clears thin horizontal strokes (under 14 px tall) below share of the height: the ground line."""
    al = a[..., 3] > 40
    H = al.shape[0]; y0 = int(H * share)
    band = al[y0:]
    thick = ndimage.binary_opening(band, structure=np.ones((14, 1)))
    keep = ndimage.binary_dilation(thick, structure=np.ones((5, 5))) & band
    a[y0:, ..., 3] = np.where(keep, a[y0:, ..., 3], 0)
    return a

def components(a, grow=18):
    al = a[..., 3] > 40
    lab, n = ndimage.label(ndimage.binary_dilation(al, iterations=grow))
    out = []
    for i, sl in enumerate(ndimage.find_objects(lab)):
        mask = (lab == i + 1) & al
        if mask.sum() < 400: continue
        out.append((mask, sl))
    return out

def save(a, mask, name, line=False):
    p = a.copy(); p[..., 3] = p[..., 3] * mask
    im = Image.fromarray(p, "RGBA"); im = im.crop(im.getbbox())
    if line:  # a part drawn standing in its own ground line (Ragnaroast's body)
        im = Image.fromarray(drop_ground_line(np.asarray(im).copy(), 0.85), "RGBA"); im = im.crop(im.getbbox())
    im.save(os.path.join(OUT, name)); return im.size

def sheet(code):
    src = [f for f in os.listdir(os.path.join(ROOT, "source/gemini")) if f.split(".")[0] == code][0]
    return np.asarray(key(Image.open(os.path.join(ROOT, "source/gemini", src)))).copy()

def cut_boss(code):
    bid, props, mirror = SHEETS[code]
    a = drop_ground_line(sheet(code))
    comps = components(a)
    comps.sort(key=lambda c: -c[0].sum())
    boss_mask, bsl = comps[0]
    x0, x1 = bsl[1].start, bsl[1].stop
    rest = []
    for mask, sl in comps[1:]:
        cx = (sl[1].start + sl[1].stop) / 2
        if x0 - 40 <= cx <= x1 + 40: boss_mask = boss_mask | mask   # floats over the boss: part of it
        else: rest.append((sl[1].start, mask))
    rest.sort(key=lambda t: t[0])
    if len(rest) != len(props): raise SystemExit(f"{code}: expected {len(props)} props, found {len(rest)}")
    if mirror: a = a[:, ::-1].copy(); boss_mask = boss_mask[:, ::-1]; rest = [(x, m[:, ::-1]) for x, m in rest]
    print(code, f"{code}-{bid}.png", save(a, boss_mask, f"{code}-{bid}.png"))
    for (x, m), name in zip(rest, props): print(code, f"{code}-{bid}-{name}.png", save(a, m, f"{code}-{bid}-{name}.png"))

def cut_parts(code):
    bid, names = PARTS[code]
    a = drop_ground_line(sheet(code))
    comps = components(a, grow=8)
    comps = [c for c in comps if c[0].sum() > 20000]
    if len(comps) != len(names): raise SystemExit(f"{code}: expected {len(names)} parts, found {len(comps)}")
    W, H = a.shape[1], a.shape[0]
    for name, (col, row) in names.items():
        # the part whose centre is nearest this spot on a 3 x 2 grid
        tx, ty = (col + 0.5) * W / 3, (row + 0.5) * H / 2
        best = min(comps, key=lambda c: ((c[1][1].start + c[1][1].stop) / 2 - tx) ** 2 + ((c[1][0].start + c[1][0].stop) / 2 - ty) ** 2)
        print(code, f"{code}-{bid}-{name}.png", save(a, best[0], f"{code}-{bid}-{name}.png", line=True))

if __name__ == "__main__":
    for c in (sys.argv[1:] or list(SHEETS) + list(PARTS)):
        cut_parts(c) if c in PARTS else cut_boss(c)
