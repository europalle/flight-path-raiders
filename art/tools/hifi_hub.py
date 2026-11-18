"""Hi-fi hub, light (Field Journal) and dark (Midnight Grimoire), assembled from the Gemini kit.
Writes ux/hifi/hub-light.svg and hub-dark.svg on the 960 x 540 design grid. Usage: python3 art/tools/hifi_hub.py"""
import os, io, base64, json
import numpy as np
from PIL import Image
ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
UI = os.path.join(ROOT, "art/kit/ui")
PORTRAITS = json.load(open(os.path.join(ROOT, "playtest/portraits.json")))

def b64(im, fmt="WEBP", q=86):
    b = io.BytesIO(); im.save(b, fmt, quality=q) if fmt != "PNG" else im.save(b, "PNG", optimize=True)
    return f"data:image/{fmt.lower()};base64," + base64.b64encode(b.getvalue()).decode()
def piece(name, w=None, h=None):
    im = Image.open(os.path.join(UI, name)).convert("RGBA")
    if w or h:
        W, H = im.size
        if w and not h: h = round(H * w / W)
        if h and not w: w = round(W * h / H)
        im = im.resize((int(w), int(h)), Image.LANCZOS)
    return im
def gradmap(im, stops):
    """Recolour a greyscale piece: luminance -> colour along the stops (dark to light). Alpha kept."""
    a = np.asarray(im).astype(np.float32)
    lum = (0.3 * a[..., 0] + 0.59 * a[..., 1] + 0.11 * a[..., 2]) / 255
    xs = np.linspace(0, 1, len(stops)); cols = np.array([[int(c[i:i + 2], 16) for i in (1, 3, 5)] for c in stops], np.float32)
    out = np.stack([np.interp(lum, xs, cols[:, k]) for k in range(3)], -1)
    return Image.fromarray(np.dstack([out, a[..., 3]]).astype(np.uint8), "RGBA")

THEMES = {
  "light": dict(name="Field Journal", tex="A1.jpeg", ink="#2a2119", muted="#5f5243", rule="#b9a582", panel="rgba(251,246,234,.78)", row="rgba(255,252,244,.82)",
                accent="#c44a1a", frost="#2f63c4", good="#2e7d32", warn="#9a5f00",
                metal=["#2b1c0c", "#7a5420", "#c99a45", "#f6e3a8"], btn=["#3a2a16", "#8a6a3a", "#e8dcc0", "#fffaf0"],
                primary=["#120c07", "#2a2119", "#4a3a2a", "#6b5640"], ptext="#fbf6ea", slot=["#2b1c0c", "#7a5420", "#c99a45", "#f3ecdc"]),
  "dark": dict(name="Midnight Grimoire", tex="A2b.png", ink="#e6e1d3", muted="#b3ad9e", rule="#4a515e", panel="rgba(30,34,42,.80)", row="rgba(37,42,51,.86)",
               accent="#ff8a3d", frost="#8cc8ff", good="#7ccf83", warn="#f0b44c",
               metal=["#0d0f13", "#3c424d", "#8b93a1", "#dfe4ec"], btn=["#0d0f13", "#5a616e", "#8b93a1", "#343a45"],
               primary=["#3a1204", "#9a3a10", "#ff8a3d", "#ffc08a"], ptext="#1c1f26", slot=["#0d0f13", "#3c424d", "#8b93a1", "#252a33"]),
}
HAND = "Kalam, 'Patrick Hand', 'Comic Sans MS', cursive"
BODY = "'IBM Plex Sans', Arial, sans-serif"

def build(theme):
    T = THEMES[theme]; out = []
    defs = []
    add = out.append
    def img(im, x, y, w, h, extra=""):
        add(f'<image href="{b64(im)}" x="{x}" y="{y}" width="{w}" height="{h}" preserveAspectRatio="none" {extra}/>')
    def text(x, y, s, size=13, col=None, font=BODY, weight=400, anchor="start", italic=False):
        add(f'<text x="{x}" y="{y}" font-family="{font}" font-size="{size}" font-weight="{weight}" fill="{col or T["ink"]}" text-anchor="{anchor}"{" font-style=\"italic\"" if italic else ""}>{s.replace("&", "&amp;").replace("<", "&lt;")}</text>')
    # Texture background (tiled).
    tex = Image.open(os.path.join(ROOT, "art/source/gemini", T["tex"])).convert("RGB").resize((360, 360), Image.LANCZOS)
    defs.append(f'<pattern id="tex" patternUnits="userSpaceOnUse" width="240" height="240"><image href="{b64(tex, q=80)}" width="240" height="240"/></pattern>')
    add(f'<rect width="960" height="540" fill="url(#tex)"/>')
    # Heavy 9-slice window border, tinted.
    m = T["metal"]; c = 34; e = 14
    corners = {"tl": "B1-00.png", "tr": "B1-01.png", "bl": "B1-08.png", "br": "B1-09.png"}
    edge_v = gradmap(piece("B1-03.png", w=40), m); edge_h = gradmap(piece("B1-13.png", h=40), m)
    img(edge_h, c - 6, 0, 960 - 2 * c + 12, e); img(edge_h, c - 6, 540 - e, 960 - 2 * c + 12, e)
    img(edge_v, 0, c - 6, e, 540 - 2 * c + 12); img(edge_v, 960 - e, c - 6, e, 540 - 2 * c + 12)
    for k, (x, y) in {"tl": (0, 0), "tr": (960 - c, 0), "bl": (0, 540 - c), "br": (960 - c, 540 - c)}.items():
        img(gradmap(piece(corners[k], w=c * 3), m), x, y, c, c)
    # Title bar.
    text(30, 42, "Flight Path Raiders", 22, font=HAND, weight=700)
    text(232, 42, "/ Hub", 17, T["muted"], font=HAND)
    text(760, 41, "100%", 12, T["muted"], anchor="end")
    rb = gradmap(piece("B3-01.png", w=72), T["btn"])
    glyphs = [("B3-07.png", "Smaller"), ("B3-08.png", "Bigger"), ("C2-23.png", "Settings"), ("B3-06.png", "Close")]
    for i, (g, _) in enumerate(glyphs):
        x = 772 + i * 38
        img(rb, x, 20, 30, 30)
        gl = piece(g, w=48); gl = gradmap(gl, [T["ink"], T["ink"], T["muted"], T["muted"]]) if g.startswith("B3") else gl
        gw = 16 if g != "B3-07.png" else 14; gh = round(gl.size[1] * gw / gl.size[0])
        img(gl, x + 15 - gw / 2, 35 - gh / 2, gw, gh)
    # Navigation tabs (wide button base, the current one with the selected outline).
    tab = gradmap(piece("B3-00.png", w=240), T["btn"]); sel = gradmap(piece("B3-00.png", w=240), ["#1a0a04", "#ff8a3d", "#c45a1c", "#3a1a0c"]) if theme == "dark" else gradmap(piece("B3-11.png", w=240), ["#5a1d08", T["accent"], "#f6e3a8", "#fffaf0"])
    x = 24
    for i, name in enumerate(["Hub", "Roster", "Tavern", "Guild Hall", "Bank"]):
        w = 62 + len(name) * 7
        img(sel if i == 0 else tab, x, 56, w, 34)
        text(x + w / 2, 78, name, 13.5, T["ink"] if theme == "light" or i else T["ink"], weight=700 if i == 0 else 600, anchor="middle")
        x += w + 8
    text(934, 78, "Gold 2,340 · DKP 86 · 12th in guild", 12.5, T["muted"], anchor="end")
    # Light frame helper for panels (vector ink line plus light kit corners).
    lc = {"tl": gradmap(piece("B1-05.png", w=60), m), "tr": gradmap(piece("B1-06.png", w=60), m), "bl": gradmap(piece("B1-10.png", w=60), m), "br": gradmap(piece("B1-11.png", w=60), m)}
    def panel(x, y, w, h, corners=True, fill=None, stroke=None):
        add(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="6" fill="{fill or T["panel"]}" stroke="{stroke or T["rule"]}" stroke-width="1.2"/>')
        if corners:
            s = 20
            img(lc["tl"], x - 3, y - 3, s, s); img(lc["tr"], x + w - s + 3, y - 3, s, s); img(lc["bl"], x - 3, y + h - s + 3, s, s); img(lc["br"], x + w - s + 3, y + h - s + 3, s, s)
    # Continue card.
    panel(24, 100, 912, 150)
    # Boss illustration: Molten Bore far layer with Ragnaroast standing in it.
    cave = Image.open(os.path.join(ROOT, "art/source/gemini/G1.jpeg")).convert("RGB")
    W, H = cave.size; cw = int(H * 210 / 128 * 0.7); cave = cave.crop((W // 2 - cw // 2, int(H * 0.15), W // 2 + cw // 2, int(H * 0.15) + int(cw * 128 / 210))).resize((420, 256), Image.LANCZOS)
    rag = Image.open(os.path.join(ROOT, "art/kit/bosses/F1-ragnaroast.png")).convert("RGBA"); rag = rag.crop(rag.getbbox()); rag.thumbnail((240, 240), Image.LANCZOS)
    comp = cave.convert("RGBA"); comp.alpha_composite(rag, (420 - rag.size[0] - 30, 256 - rag.size[1] + 10))
    defs.append('<clipPath id="bossclip"><rect x="40" y="114" width="210" height="122" rx="4"/></clipPath>')
    add(f'<image href="{b64(comp.convert("RGB"), q=84)}" x="40" y="114" width="210" height="128" clip-path="url(#bossclip)" preserveAspectRatio="xMidYMid slice"/>')
    add(f'<rect x="40" y="114" width="210" height="122" rx="4" fill="none" stroke="{m[1]}" stroke-width="3"/>')
    text(268, 140, "Continue: Ragnaroast, The Molten Bore", 21, font=HAND, weight=700)
    text(268, 162, "Heroic · Boss 5 of 5 · 8 ready, 2 benched until reset", 12.5, T["muted"])
    text(268, 184, "Last pull: wipe in round 18. Raid leader: “We’re melting. Literally.”", 12.5, T["ink"], italic=True)
    add(f'<rect x="268" y="198" width="380" height="28" rx="14" fill="{T["row"]}" stroke="{T["rule"]}"/>')
    text(282, 217, "This week:", 12.5, weight=700)
    img(piece("C2-04.png", w=60), 352, 203, 24, 16); text(380, 217, "Floor Is Lava", 12.5)
    img(piece("C2-00.png", w=40), 470, 202, 15, 18); text(490, 217, "Fortified Trash", 12.5)
    pb = gradmap(piece("B3-10.png", w=360), T["primary"])
    img(pb, 762, 146, 154, 58); text(839, 182, "Prep pull", 20, T["ptext"], font=HAND, weight=700, anchor="middle")
    # Three columns.
    cols = [("Raids", [("The Molten Bore", "N 5/5 · H 4/5 · M 0/5", None), ("Onyxiety’s Lair", "N 1/1 · H 0/1", "C2-15.png"), ("Blackwing attunement", "2 of 3 steps", "C3-09.png")]),
            ("Dungeons & keystone", [("Quick dungeon", "fits one flight", "C2-08.png"), ("Key: Gnomeregret +7", "best +9 · 2nd", None), ("Weekly chest", "1 of 1 ready", "C3-08.png")]),
            ("Daily quests", [("Clear any dungeon", "12 g · 2 DKP", "C2-17.png"), ("Kill a raid boss", "done", "C2-18.png"), ("Survive a Loot Council", "12 g · 2 DKP", "C2-17.png")])]
    for ci, (title, rows) in enumerate(cols):
        x = 24 + ci * 312
        text(x + 2, 276, title, 17, font=HAND, weight=700)
        for ri, (a, b, ic) in enumerate(rows):
            y = 286 + ri * 42
            panel(x, y, 288, 34, corners=False, fill=T["row"])
            tx = x + 12
            if ic: img(piece(ic, w=60), x + 9, y + 8, 18, 18 * piece(ic).size[1] / piece(ic).size[0]); tx = x + 34
            text(tx, y + 22, a, 13, weight=600)
            text(x + 278, y + 22, b, 11.5, T["good"] if b == "done" else T["muted"], anchor="end")
    # Roster strip.
    panel(24, 420, 912, 100)
    text(40, 444, "Roster 15 / 15", 17, font=HAND, weight=700)
    text(170, 443, "10 ready · 3 bench · 2 benched until reset", 12, T["muted"])
    slot = gradmap(piece("B4-01.png", w=140), T["slot"])
    order = ["warrior", "paladin", "priest", "shaman", "druid", "rogue", "mage", "hunter", "warlock", "priest"]
    looks = [0, 1, 1, 0, 1, 1, 0, 0, 1, 0]
    for i, (cl, lk) in enumerate(zip(order, looks)):
        x = 38 + i * 50; y = 452
        img(slot, x, y, 44, 44)
        im = Image.open(io.BytesIO(base64.b64decode(PORTRAITS[cl][lk]["img"].split(",")[1]))).convert("RGBA")
        bench = i in (6, 9)
        if bench: im = Image.fromarray(np.dstack([np.repeat(np.asarray(im.convert("L"))[..., None], 3, -1), np.asarray(im)[..., 3]]).astype(np.uint8), "RGBA")
        img(im, x + 6, y + 6, 32, 32, 'opacity=".55"' if bench else "")
        if bench: add(f'<rect x="{x + 2}" y="{y + 30}" width="40" height="11" rx="2" fill="{T["accent"]}"/>'); text(x + 22, y + 39, "BENCHED", 7.5, T["ptext"], weight=700, anchor="middle")
    add(f'<rect x="560" y="448" width="232" height="52" rx="6" fill="{T["row"]}" stroke="{T["warn"]}" stroke-width="1.4"/>')
    img(piece("C2-11.png", w=60), 570, 456, 18, 16); text(594, 469, "2 characters low morale", 12.5, weight=700)
    text(572, 489, "Rook 22, Fen 35: quit risk", 11.5, T["muted"])
    img(tab, 804, 450, 120, 48); text(864, 479, "Manage", 15, weight=700, anchor="middle")
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 960 540" width="1920" height="1080">'
           f'<title>Flight Path Raiders hub, {T["name"]}</title>'
           '<style>@import url("https://fonts.googleapis.com/css2?family=Kalam:wght@400;700&amp;family=IBM+Plex+Sans:wght@400;600;700&amp;display=swap");</style>'
           f'<defs>{"".join(defs)}</defs>{"".join(out)}</svg>')
    path = os.path.join(ROOT, f"ux/hifi/hub-{theme}.svg"); open(path, "w").write(svg)
    print(path, len(svg) // 1024, "KB")
for t in THEMES: build(t)
