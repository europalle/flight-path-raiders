"""Measures text contrast on a hi-fi screen against its real background (texture, frames, buttons).
Renders the screen without text, then for each text box compares the text colour with the background
pixels under it. Pass: 4.5:1 for body text, 3:1 for large text (18+ units, or 14+ bold), at the
10th-percentile background pixel (so a few stray texture specks don't decide it).
Usage: python3 art/tools/check_contrast.py ux/hifi/hub-light.svg [...]"""
import sys, os, json, io
import numpy as np
from PIL import Image
from playwright.sync_api import sync_playwright
def lum(rgb):
    c = np.asarray(rgb, np.float64) / 255
    c = np.where(c <= 0.03928, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
    return 0.2126 * c[..., 0] + 0.7152 * c[..., 1] + 0.0722 * c[..., 2]
def hexrgb(h): return [int(h[i:i + 2], 16) for i in (1, 3, 5)]
def render(page, path):
    page.goto("file://" + os.path.abspath(path)); page.wait_for_timeout(300)
    return np.asarray(Image.open(io.BytesIO(page.screenshot())).convert("RGB"))
fails = 0
with sync_playwright() as p:
    b = p.chromium.launch(); page = b.new_page(viewport={"width": 1920, "height": 1080})
    for svg in sys.argv[1:]:
        bg = render(page, svg.replace(".svg", "-notext.svg")); S = bg.shape[1] / 960
        texts = json.load(open(svg.replace(".svg", ".texts.json")))
        print(svg)
        for t in texts:
            if t.get("behind"): continue  # dimmed under a scrim on purpose
            x0, y0 = int(t["x"] * S), int(t["y"] * S); x1, y1 = int((t["x"] + t["w"]) * S), int((t["y"] + t["h"]) * S)
            px = bg[max(0, y0):y1, max(0, x0):x1].reshape(-1, 3)
            if not len(px): continue
            lt = lum(np.array(hexrgb(t["col"]))); lb = lum(px)
            ratio = (np.maximum(lt, lb) + 0.05) / (np.minimum(lt, lb) + 0.05)
            worst = float(np.percentile(ratio, 10))
            need = 3.0 if t["size"] >= 18 or (t["size"] >= 14 and t["bold"]) else 4.5
            small = t["size"] < 11
            ok = worst >= need and not small
            fails += not ok
            print(f'  {"ok  " if ok else "FAIL"} {worst:5.1f}:1 (needs {need})  {t["size"]:>4}u  {t["text"][:48]}' + ("  [below 11 units]" if small else ""))
    b.close()
print("All text passes." if not fails else f"{fails} text item(s) fail.")
sys.exit(1 if fails else 0)
