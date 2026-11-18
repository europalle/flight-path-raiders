"""Screenshots of the addon without the game: loads the built addon in Lua 5.1 with the WoW stand-in
(tests/wow_stub.lua), drives it to each screen and draws what it laid out (textures, colours, text) to a
PNG. Fonts are stand-ins for the client's (DejaVu Condensed for Arial Narrow, DejaVu Serif for Friz
Quadrata), so text widths are close, not exact. Use it to catch overlaps and missing art before install.
Usage: python3 tools/build_addon.py && python3 tools/addon_shot.py [out_dir]"""
import os, sys
import lupa.lua51 as l51
from PIL import Image, ImageDraw, ImageFont
import numpy as np
ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
DIST = os.path.join(ROOT, "addon/dist/FlightPathRaiders")
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "addon/shots")
S = 2  # pixels per board unit
FONTS = {"body": "/usr/share/fonts/truetype/dejavu/DejaVuSansCondensed.ttf", "head": "/usr/share/fonts/truetype/dejavu/DejaVuSerifCondensed-Bold.ttf"}
LAYERS = {"BACKGROUND": 0, "BORDER": 1, "ARTWORK": 2, "OVERLAY": 3}

L = l51.LuaRuntime(unpack_returned_tuples=True)
L.execute(open(os.path.join(ROOT, "tests/wow_stub.lua")).read())
L.execute("FPR_NS = {}")
toc = [l.strip() for l in open(os.path.join(DIST, "FlightPathRaiders.toc")) if l.strip() and not l.startswith("#")]
load = L.eval("function(src, name) local f, err = loadstring(src, '@' .. name); if not f then error(err) end; return f('FlightPathRaiders', FPR_NS) end")
for f in toc: load(open(os.path.join(DIST, f.replace("\\", "/"))).read(), f)
raw = L.eval("rawget"); req = L.eval("rawequal")
def g(o, k): return raw(o, k)
def lst(t): return [t[i] for i in range(1, len(t) + 1)] if t is not None else []

_cache = {}
def tex(name):
    if name not in _cache:
        p = os.path.join(DIST, "Media", name.split("\\")[-1] + ".tga")
        _cache[name] = Image.open(p).convert("RGBA") if os.path.exists(p) else None
    return _cache[name]
def font(kind, size):
    return ImageFont.truetype(FONTS[kind], max(6, round(size * S)))

def rect(o, board):
    if req(o, board): return (0, 0, 960, 540)
    allp = g(o, "_all")
    if allp is not None: return rect(allp, board)
    pts = lst(g(o, "_points"))
    w, h = g(o, "_w"), g(o, "_h")
    if not pts:
        par = g(o, "_parent"); return rect(par, board) if par is not None else (0, 0, 960, 540)
    p = lst(pts[0]); anchor = p[0]; rel = p[1] if len(p) > 1 and not isinstance(p[1], (str, int, float)) else g(o, "_parent")
    x = p[3] if len(p) > 3 else 0; y = p[4] if len(p) > 4 else 0
    rx, ry, rw, rh = rect(rel, board) if rel is not None else (0, 0, 960, 540)
    if anchor == "CENTER":
        w = w or 0; h = h or 0
        return (rx + rw / 2 + x - w / 2, ry + rh / 2 - y - h / 2, w, h)
    return (rx + x, ry - y, w or 0, h or 0)

def draw_text(img, d, o, board):
    t = g(o, "_text")
    if not isinstance(t, str) or not t: return
    t = t.replace("|r", "")
    while "|c" in t: i = t.index("|c"); t = t[:i] + t[i + 10:]
    kind = "head" if "FRIZ" in str(g(o, "_font")) else "body"
    f = font(kind, g(o, "_size") or 13)
    c = lst(g(o, "_textcol")) or [1, 1, 1, 1]
    fill = tuple(int(v * 255) for v in c[:3]) + (int(c[3] * 255) if len(c) > 3 else 255,)
    x, y, w, h = rect(o, board)
    lines = [t]
    if g(o, "_wrap") and w:
        words, lines, cur = t.split(" "), [], ""
        for wd in words:
            test = (cur + " " + wd).strip()
            if d.textlength(test, font=f) / S > w and cur: lines.append(cur); cur = wd
            else: cur = test
        lines.append(cur)
    j = g(o, "_justify") or "LEFT"
    for i, line in enumerate(lines):
        tw = d.textlength(line, font=f) / S
        if pts_center(o): xx = x + w / 2 - tw / 2 if w else x - tw / 2
        elif j == "RIGHT" and w: xx = x + w - tw
        elif j == "CENTER" and w: xx = x + w / 2 - tw / 2
        else: xx = x
        yy = y + i * (g(o, "_size") or 13) * 1.2
        if pts_center(o): yy = y - (g(o, "_size") or 13) * 0.6
        d.text((xx * S, yy * S), line, font=f, fill=fill)
        TEXTS.append({"text": line, "x": xx, "y": yy, "w": tw, "h": (g(o, "_size") or 13), "size": g(o, "_size") or 13, "bold": kind == "head",
                      "col": c[:3], "dim": (g(o, "_alpha") or 1) < 1})
TEXTS = []
def pts_center(o):
    pts = lst(g(o, "_points"))
    return bool(pts) and lst(pts[0])[0] == "CENTER"

def draw_tex(img, o, board):
    x, y, w, h = rect(o, board)
    if w <= 0 or h <= 0: return
    box = (int(x * S), int(y * S), int((x + w) * S), int((y + h) * S))
    col = g(o, "_color")
    alpha = g(o, "_alpha"); alpha = 1 if alpha is None else alpha
    if col is not None:
        c = lst(col); a = (c[3] if len(c) > 3 else 1) * alpha
        if a <= 0: return
        layer = Image.new("RGBA", (box[2] - box[0], box[3] - box[1]), tuple(int(v * 255) for v in c[:3]) + (int(a * 255),))
        img.alpha_composite(layer, (box[0], box[1])); return
    path = g(o, "_path")
    if not isinstance(path, str): return
    im = tex(path)
    if im is None: return
    if "\\bg-" in path:  # tiled background
        tile = im.resize((240 * S, 240 * S))
        for tx in range(box[0], box[2], tile.size[0]):
            for ty in range(box[1], box[3], tile.size[1]): img.alpha_composite(tile.crop((0, 0, min(tile.size[0], box[2] - tx), min(tile.size[1], box[3] - ty))), (tx, ty))
        return
    im = im.resize((box[2] - box[0], box[3] - box[1]), Image.LANCZOS)
    if g(o, "_desat"): im = Image.merge("RGBA", (*[im.convert("L")] * 3, im.getchannel("A")))
    if alpha < 1: im.putalpha(im.getchannel("A").point(lambda v: int(v * alpha)))
    img.alpha_composite(im, (box[0], box[1]))

def visible(o):
    while o is not None:
        if not g(o, "_shown"): return False
        o = g(o, "_parent")
    return True

def lum(a):
    a = np.asarray(a, np.float64) / 255
    a = np.where(a <= 0.03928, a / 12.92, ((a + 0.055) / 1.055) ** 2.4)
    return 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]
FAILS = []
def shot(name):
    """Draws the board twice (with and without text) and measures every text line against the pixels
    behind it, like art/tools/check_contrast.py does for the hi-fi: 4.5:1, or 3:1 for large text, at the
    10th-percentile background pixel; nothing below 11 units. Greyed-out (disabled) labels are exempt,
    and so is anything under a window's scrim."""
    board = L.eval("FlightPathRaidersBoard")
    frames = [f for f in lst(L.eval("WOW_FRAMES")) if visible(f) and (req(f, board) or is_child(f, board))]
    frames.sort(key=lambda f: g(f, "_level") or 0)
    modal_on = L.eval("FPR_NS.Board.modal ~= nil")
    top = max(g(f, "_level") or 0 for f in frames)
    imgs = []
    for with_text in (False, True):
        TEXTS.clear()
        img = Image.new("RGBA", (960 * S, 540 * S), (0, 0, 0, 255)); d = ImageDraw.Draw(img)
        for f in frames:
            regs = [r for r in lst(g(f, "_regions")) if g(r, "_shown") and g(r, "_layer") != "HIGHLIGHT"]
            regs.sort(key=lambda r: (LAYERS.get(g(r, "_layer") or "ARTWORK", 2), g(r, "_sub") or 0))
            for r in regs:
                if g(r, "_name") == "fontstring":
                    if with_text: draw_text(img, d, r, board)
                else: draw_tex(img, r, board)
        if not with_text:
            # the text-free pass still needs the text boxes: draw them to a scratch image
            scratch = Image.new("RGBA", img.size); sd = ImageDraw.Draw(scratch); TEXTS.clear()
            for f in frames:
                for r in lst(g(f, "_regions")):
                    if g(r, "_shown") and g(r, "_name") == "fontstring":
                        n = len(TEXTS); draw_text(scratch, sd, r, board)
                        for t in TEXTS[n:]: t["behind"] = modal_on and (g(f, "_level") or 0) < top - 5
            boxes = list(TEXTS)
        imgs.append(img)
    bg = np.asarray(imgs[0].convert("RGB"))
    os.makedirs(OUT, exist_ok=True)
    imgs[1].convert("RGB").save(os.path.join(OUT, name + ".png"))
    bad = 0
    for t in boxes:
        if t["behind"] or t["dim"]: continue
        x0, y0, x1, y1 = int(t["x"] * S), int(t["y"] * S), int((t["x"] + t["w"]) * S), int((t["y"] + t["h"]) * S)
        px = bg[max(0, y0):max(0, y1), max(0, x0):max(0, x1)].reshape(-1, 3)
        if not len(px): continue
        lt = lum(np.array([v * 255 for v in t["col"]])); lb = lum(px)
        ratio = (np.maximum(lt, lb) + 0.05) / (np.minimum(lt, lb) + 0.05)
        worst = float(np.percentile(ratio, 10))
        need = 3.0 if t["size"] >= 18 or (t["size"] >= 14 and t["bold"]) else 4.5
        if worst < need or t["size"] < 11:
            bad += 1; FAILS.append(f"{name}: {worst:.1f}:1 needs {need}, {t['size']}u: {t['text'][:50]}")
    print(f"{name}: {len(boxes)} text lines, {bad} fail")

def is_child(f, board):
    p = g(f, "_parent")
    while p is not None:
        if req(p, board): return True
        p = g(p, "_parent")
    return False

if __name__ == "__main__":
    click = L.eval("WOW_CLICK")
    L.execute("WOW_FIRE('ADDON_LOADED', 'FlightPathRaiders')")
    slash = L.eval("SlashCmdList.FLIGHTPATHRAIDERS")
    for theme in ("light", "dark"):
        L.execute("FlightPathRaidersDB.guild = nil")
        slash("theme " + theme)
        if not L.eval("FlightPathRaidersBoard and FlightPathRaidersBoard:IsShown()"): slash("")
        click("Hub"); shot(f"hub-{theme}")
        click("Prep pull"); click("Burn"); shot(f"prep-{theme}")
        click("Pull")
        for _ in range(8): L.eval("WOW_TICK(1)")
        shot(f"playback-{theme}")
        click("Skip to result")
        for _ in range(8):
            if L.eval("FPR_NS.Board.args.out.result") == "kill": break
            shot(f"results-{theme}"); click("Pull again"); click("Skip to result")
        shot(f"loot-{theme}")
        click("Hand out"); click("Hub")
        for page in ("Roster", "Tavern", "Journal"): click(page); shot(f"{page.lower()}-{theme}")
        click("Settings"); shot(f"settings-{theme}"); click("Done")
    print("shots in", os.path.relpath(OUT, ROOT))
    for f in FAILS: print("  FAIL", f)
    sys.exit(1 if FAILS else 0)
