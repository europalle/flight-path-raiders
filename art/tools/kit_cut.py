"""Cuts a Gemini sheet on magenta into separate transparent pieces.
Usage: python3 art/tools/kit_cut.py B1 [B3 ...]  -> art/kit/ui/<code>-NN.png and a numbered index sheet."""
import sys, os, json, numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage
ROOT = os.path.join(os.path.dirname(__file__), "..")
def key(im):
    a = np.asarray(im.convert("RGB")).astype(np.float32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    m = np.minimum(r, b) - g
    alpha = np.clip(1 - (m - 60) / 90, 0, 1)
    spill = np.clip(np.minimum(r, b) - g - 20, 0, None) * (alpha < 1)
    out = a.copy(); out[..., 0] -= spill * 0.6; out[..., 2] -= spill * 0.6
    return Image.fromarray(np.dstack([np.clip(out, 0, 255), alpha * 255]).astype(np.uint8), "RGBA")
def cut(code):
    src = [f for f in os.listdir(os.path.join(ROOT, "source/gemini")) if f.split(".")[0] == code][0]
    im = key(Image.open(os.path.join(ROOT, "source/gemini", src)))
    al = np.asarray(im)[..., 3] > 40
    lab, n = ndimage.label(ndimage.binary_dilation(al, iterations=6))
    boxes = ndimage.find_objects(lab)
    pieces = []
    for i, sl in enumerate(boxes):
        h, w = sl[0].stop - sl[0].start, sl[1].stop - sl[1].start
        if h * w < 1500: continue
        mask = (lab[sl] == i + 1)
        p = np.asarray(im)[sl].copy(); p[..., 3] = p[..., 3] * mask
        pieces.append((sl[0].start, sl[1].start, Image.fromarray(p, "RGBA")))
    # reading order: rows of similar top, then left to right
    pieces.sort(key=lambda t: (t[0] // 180, t[1]))
    os.makedirs(os.path.join(ROOT, "kit/ui"), exist_ok=True)
    idx = im.copy().convert("RGBA"); d = ImageDraw.Draw(idx)
    for k, (y, x, p) in enumerate(pieces):
        p.save(os.path.join(ROOT, "kit/ui", f"{code}-{k:02d}.png"))
        d.rectangle([x, y, x + p.size[0], y + p.size[1]], outline=(0, 160, 255, 255), width=4)
        d.text((x + 6, y + 6), str(k), fill=(0, 0, 0, 255))
    idx.convert("RGB").resize((idx.size[0] // 3, idx.size[1] // 3)).save(os.path.join(ROOT, "kit/ui", f"_index-{code}.jpg"), quality=80)
    man = [{"file": f"{code}-{k:02d}.png", "x": x, "y": y, "w": p.size[0], "h": p.size[1]} for k, (y, x, p) in enumerate(pieces)]
    json.dump(man, open(os.path.join(ROOT, "kit/ui", f"_manifest-{code}.json"), "w"), indent=0)
    for m in man: print(code, m)
for c in sys.argv[1:]: cut(c)
