"""Hi-fi hub, light (Field Journal) and dark (Midnight Grimoire), assembled from the Gemini kit.
Writes ux/hifi/hub-<theme>.svg on the 960 x 540 design grid, with the fonts embedded, plus a no-text
version and a list of text boxes so art/tools/check_contrast.py can measure every line.
Usage: python3 art/tools/hifi_hub.py

Art rules applied here (Art review, 2026-11-18):
- Icons come in fixed boxes: 16 units inline with body text, 14 in the title purse, 18 on buttons.
  Each icon is trimmed to its own outline and fitted inside its box, so nothing is bigger or smaller by accident.
- Nothing crosses a border: panel ornaments sit inside the panel, icons sit inside their row or pill.
- Text never sits on a frame's rim, only on its flat middle."""
import os, io, base64, json, glob
import numpy as np
from PIL import Image
ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
UI = os.path.join(ROOT, "art/kit/ui")
PORTRAITS = json.load(open(os.path.join(ROOT, "playtest/portraits.json")))
FONT_DIR = os.environ.get("FPR_FONTS", "/tmp/claude-0/-home-claude/9afd4abb-3b1e-518e-b6c5-95385ef3302c/scratchpad/fonts/node_modules/@fontsource")

def b64(im, fmt="WEBP", q=86):
    b = io.BytesIO(); im.save(b, fmt, quality=q)
    return f"data:image/{fmt.lower()};base64," + base64.b64encode(b.getvalue()).decode()
def piece(name, w=None, h=None):
    im = Image.open(os.path.join(UI, name)).convert("RGBA")
    if w or h:
        W, H = im.size
        if w and not h: h = round(H * w / W)
        if h and not w: w = round(W * h / H)
        im = im.resize((int(w), int(h)), Image.LANCZOS)
    return im
def trimmed(name):
    im = Image.open(os.path.join(UI, name)).convert("RGBA")
    bb = im.getchannel("A").point(lambda v: 255 if v > 60 else 0).getbbox()
    return im.crop(bb)
def gradmap(im, stops):
    """Recolour a greyscale piece: luminance picks a colour along the stops. Alpha kept."""
    a = np.asarray(im).astype(np.float32)
    lum = (0.3 * a[..., 0] + 0.59 * a[..., 1] + 0.11 * a[..., 2]) / 255
    xs = np.linspace(0, 1, len(stops)); cols = np.array([[int(c[i:i + 2], 16) for i in (1, 3, 5)] for c in stops], np.float32)
    out = np.stack([np.interp(lum, xs, cols[:, k]) for k in range(3)], -1)
    return Image.fromarray(np.dstack([out, a[..., 3]]).astype(np.uint8), "RGBA")
def font_css():
    faces = [("Kalam", "kalam/files/kalam-latin-400-normal.woff2", 400, "normal"), ("Kalam", "kalam/files/kalam-latin-700-normal.woff2", 700, "normal"),
             ("IBM Plex Sans", "ibm-plex-sans/files/ibm-plex-sans-latin-400-normal.woff2", 400, "normal"),
             ("IBM Plex Sans", "ibm-plex-sans/files/ibm-plex-sans-latin-400-italic.woff2", 400, "italic"),
             ("IBM Plex Sans", "ibm-plex-sans/files/ibm-plex-sans-latin-600-normal.woff2", 600, "normal"),
             ("IBM Plex Sans", "ibm-plex-sans/files/ibm-plex-sans-latin-700-normal.woff2", 700, "normal")]
    css = []
    for fam, f, w, st in faces:
        p = os.path.join(FONT_DIR, f)
        if os.path.exists(p):
            css.append(f"@font-face{{font-family:'{fam}';font-weight:{w};font-style:{st};src:url(data:font/woff2;base64,{base64.b64encode(open(p, 'rb').read()).decode()}) format('woff2')}}")
    return "".join(css)

# Tokens follow the art direction doc exactly.
THEMES = {
  "light": dict(name="Field Journal", tex="A1.jpeg", ink="#2a2119", muted="#6b5d4c", rule="#b9a582", panel="rgba(251,246,234,.84)", row="rgba(255,252,244,.9)",
                accent="#c44a1a", good="#2e7d32", warn="#a86a00", bad="#b3261e", badtext="#ffffff",
                metal=["#2b1c0c", "#7a5420", "#c99a45", "#f6e3a8"], btn=["#3a2a16", "#8a6a3a", "#e8dcc0", "#fffaf0"],
                sel=["#3a1204", "#c44a1a", "#f2c9a8", "#fff4ea"], seltext="#2a2119",
                primary=["#120c07", "#4a3a2a", "#2a2119", "#241a12"], ptext="#fbf6ea", slot=["#2b1c0c", "#7a5420", "#c99a45", "#f3ecdc"],
                gem=["#2a0606", "#7a1414", "#d84a3a", "#ffd0c0"]),
  "dark": dict(name="Midnight Grimoire", tex="A2b.png", ink="#e6e1d3", muted="#b3ad9e", rule="#4a515e", panel="rgba(30,34,42,.86)", row="rgba(37,42,51,.92)",
               accent="#ff8a3d", good="#7ccf83", warn="#f0b44c", bad="#ff7b6e", badtext="#1c1f26",
               metal=["#0d0f13", "#3c424d", "#8b93a1", "#dfe4ec"], btn=["#0d0f13", "#5a616e", "#8b93a1", "#2a2f38"],
               sel=["#1a0a04", "#ff8a3d", "#c45a1c", "#3a1a0c"], seltext="#ffe9d6",
               primary=["#1a0a04", "#ff8a3d", "#c45a1c", "#3a1206"], ptext="#ffe9d6", slot=["#0d0f13", "#3c424d", "#8b93a1", "#252a33"],
               gem=["#2a0606", "#7a1414", "#ff6a5a", "#ffd0c0"]),
}
HAND = "Kalam, 'Comic Sans MS', cursive"
BODY = "'IBM Plex Sans', Arial, sans-serif"
ICON_INLINE, ICON_PURSE, ICON_BTN = 16, 14, 18

def build(theme, notext=False):
    T = THEMES[theme]; out = []; defs = []; texts = []
    add = out.append
    def img(im, x, y, w, h, extra=""):
        add(f'<image href="{b64(im)}" x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" preserveAspectRatio="none" {extra}/>')
    def icon(name, cx, cy, box, recolour=None):
        """Fits a trimmed icon inside a square box centred on (cx, cy)."""
        im = trimmed(name)
        if recolour: im = gradmap(im, recolour)
        w, h = im.size; s = box / max(w, h); w, h = w * s, h * s
        im = im.resize((max(1, round(w * 3)), max(1, round(h * 3))), Image.LANCZOS)
        img(im, cx - w / 2, cy - h / 2, w, h)
    def text(x, y, s, size=13, col=None, font=BODY, weight=400, anchor="start", italic=False):
        col = col or T["ink"]
        w = len(s) * size * (0.47 if font == BODY else 0.5)
        x0 = x - w if anchor == "end" else x - w / 2 if anchor == "middle" else x
        texts.append({"text": s, "x": x0, "y": y - size * 0.78, "w": w, "h": size * 0.98, "size": size, "bold": weight >= 700, "col": col})
        if notext: return
        add(f'<text x="{x}" y="{y}" font-family="{font}" font-size="{size}" font-weight="{weight}" fill="{col}" text-anchor="{anchor}"'
            f'{" font-style=\"italic\"" if italic else ""}>{s.replace("&", "&amp;").replace("<", "&lt;")}</text>')
    # Texture.
    tex = Image.open(os.path.join(ROOT, "art/source/gemini", T["tex"])).convert("RGB").resize((360, 360), Image.LANCZOS)
    defs.append(f'<pattern id="tex" patternUnits="userSpaceOnUse" width="240" height="240"><image href="{b64(tex, q=80)}" width="240" height="240"/></pattern>')
    add('<rect width="960" height="540" fill="url(#tex)"/>')
    # Heavy window border (9-slice).
    m = T["metal"]; c = 34; e = 14
    edge_v = gradmap(piece("B1-03.png", w=40), m); edge_h = gradmap(piece("B1-13.png", h=40), m)
    img(edge_h, c - 6, 0, 960 - 2 * c + 12, e); img(edge_h, c - 6, 540 - e, 960 - 2 * c + 12, e)
    img(edge_v, 0, c - 6, e, 540 - 2 * c + 12); img(edge_v, 960 - e, c - 6, e, 540 - 2 * c + 12)
    for f, (x, y) in {"B1-00.png": (0, 0), "B1-01.png": (960 - c, 0), "B1-08.png": (0, 540 - c), "B1-09.png": (960 - c, 540 - c)}.items():
        img(gradmap(piece(f, w=c * 3), m), x, y, c, c)
    # Title bar: name, page, purse, scale and window buttons.
    text(30, 44, "Flight Path Raiders", 22, font=HAND, weight=700)
    text(232, 44, "/ Hub", 17, T["muted"], font=HAND)
    text(752, 42, "100%", 12, T["muted"], anchor="end")
    rb = gradmap(piece("B3-01.png", w=96), T["btn"])
    for i, g in enumerate(["B3-07.png", "B3-08.png", "C2-23.png", "B3-06.png"]):
        x = 764 + i * 40
        img(rb, x, 20, 32, 32)
        if g.startswith("B3"): icon(g, x + 16, 36, 13, [T["ink"], T["ink"], T["ink"], T["ink"]])
        else: icon(g, x + 16, 36, 15)
    # Navigation tabs.
    tab = gradmap(piece("B3-00.png", w=300), T["btn"]); sel = gradmap(piece("B3-00.png", w=300), T["sel"])
    x = 24
    for i, name in enumerate(["Hub", "Roster", "Tavern", "Guild Hall", "Bank"]):
        w = 66 + len(name) * 7
        img(sel if i == 0 else tab, x, 58, w, 34)
        text(x + w / 2, 80, name, 13.5, T["seltext"] if i == 0 else T["ink"], weight=700 if i == 0 else 600, anchor="middle")
        x += w + 8
    # Purse: guild name, gold, DKP, rank. Each value has its icon in the same 14-unit box.
    px = 934
    for label, ic, rec in reversed([("LFR", None, None), ("2,340", "C3-05.png", None), ("86 DKP", "B2-07.png", T["gem"]), ("12th in guild", "C2-19.png", None)]):
        tw = len(label) * 12.5 * (0.6 if label[0].isdigit() and "guild" not in label else 0.49)
        text(px, 80, label, 12.5, T["ink"] if ic else T["muted"], weight=600 if ic else 400, anchor="end")
        px -= tw + 4
        if ic: icon(ic, px - 2 - ICON_PURSE / 2, 75.5, ICON_PURSE, rec); px -= ICON_PURSE + 16
        else: px -= 10
    # Panels: light frame, ornaments inside the edge.
    lc = [gradmap(piece(f, w=60), m) for f in ("B1-05.png", "B1-06.png", "B1-10.png", "B1-11.png")]
    def panel(x, y, w, h, corners=True, fill=None, stroke=None):
        add(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="6" fill="{fill or T["panel"]}" stroke="{stroke or T["rule"]}" stroke-width="1.2"/>')
        if corners:
            s = 18; i = 2
            img(lc[0], x + i, y + i, s, s); img(lc[1], x + w - s - i, y + i, s, s); img(lc[2], x + i, y + h - s - i, s, s); img(lc[3], x + w - s - i, y + h - s - i, s, s)
    # Continue card.
    panel(24, 102, 912, 150)
    cave = Image.open(os.path.join(ROOT, "art/source/gemini/G1.jpeg")).convert("RGB")
    W, H = cave.size; cw = int(H * 210 / 128 * 0.7); cave = cave.crop((W // 2 - cw // 2, int(H * 0.15), W // 2 + cw // 2, int(H * 0.15) + int(cw * 128 / 210))).resize((420, 256), Image.LANCZOS)
    rag = Image.open(os.path.join(ROOT, "art/kit/bosses/F1-ragnaroast.png")).convert("RGBA"); rag = rag.crop(rag.getbbox()); rag.thumbnail((240, 240), Image.LANCZOS)
    comp = cave.convert("RGBA"); comp.alpha_composite(rag, (420 - rag.size[0] - 30, 256 - rag.size[1] + 10))
    defs.append('<clipPath id="bossclip"><rect x="42" y="116" width="210" height="122" rx="4"/></clipPath>')
    add(f'<image href="{b64(comp.convert("RGB"), q=84)}" x="42" y="116" width="210" height="128" clip-path="url(#bossclip)" preserveAspectRatio="xMidYMid slice"/>')
    add(f'<rect x="42" y="116" width="210" height="122" rx="4" fill="none" stroke="{m[1]}" stroke-width="3"/>')
    text(270, 142, "Continue: Ragnaroast, The Molten Bore", 21, font=HAND, weight=700)
    text(270, 164, "Heroic · Boss 5 of 5 · 13 ready, 2 benched until reset", 12.5, T["muted"])
    text(270, 186, "Last pull: wipe in round 18. Raid leader: “We’re melting. Literally.”", 12.5, italic=True)
    add(f'<rect x="270" y="200" width="372" height="30" rx="15" fill="{T["row"]}" stroke="{T["rule"]}"/>')
    text(286, 220, "This week:", 12.5, weight=700)
    icon("C2-04.png", 368, 215, ICON_INLINE); text(380, 220, "Floor Is Lava", 12.5)
    icon("C2-00.png", 482, 215, ICON_INLINE); text(494, 220, "Fortified Trash", 12.5)
    pb = gradmap(piece("B3-10.png" if theme == "light" else "B3-00.png", w=420), T["primary"])
    img(pb, 756, 146, 162, 62); text(837, 184, "Prep pull", 20, T["ptext"], font=HAND, weight=700, anchor="middle")
    # Three columns of rows. Every row has a 16-unit icon slot, so text lines up whether or not there's an icon.
    cols = [("Raids", [("The Molten Bore", "N 5/5 · H 4/5 · M 0/5", "C2-04.png"), ("Onyxiety’s Lair", "N 1/1 · H 0/1 · M locked", "C2-15.png"), ("Blackwing attunement", "2 of 3 steps", "C3-09.png")]),
            ("Dungeons & keystone", [("Quick dungeon", "one flight (~3 min)", "C2-08.png"), ("Key: Gnomeregret +7", "best +9 · 2nd in guild", "C2-10.png"), ("Weekly chest", "1 of 1 ready", "C3-08.png")]),
            ("Daily quests", [("Clear any dungeon", "12 g · 2 DKP", "C2-17.png"), ("Kill a raid boss", "done", "C2-18.png"), ("Survive a Loot Council", "12 g · 2 DKP", "C2-17.png")])]
    for ci, (title, rows) in enumerate(cols):
        x = 24 + ci * 312
        text(x + 2, 278, title, 17, font=HAND, weight=700)
        for ri, (a, b, ic) in enumerate(rows):
            y = 288 + ri * 42
            panel(x, y, 288, 34, corners=False, fill=T["row"])
            icon(ic, x + 18, y + 17, ICON_INLINE)
            text(x + 34, y + 22, a, 13, weight=600)
            text(x + 278, y + 22, b, 11.5, T["good"] if b == "done" else T["muted"], anchor="end")
    # Roster strip: portrait slots with the benched tag underneath, inside the panel.
    panel(24, 420, 912, 104)
    text(42, 446, "Roster 15 / 15", 17, font=HAND, weight=700)
    text(172, 445, "13 ready · 2 benched until reset", 12, T["muted"])
    slot = gradmap(piece("B4-01.png", w=140), T["slot"])
    order = ["warrior", "paladin", "priest", "shaman", "druid", "rogue", "mage", "hunter", "warlock", "priest"]
    looks = [0, 1, 1, 0, 1, 1, 0, 0, 1, 0]
    for i, (cl, lk) in enumerate(zip(order, looks)):
        x = 42 + i * 50; y = 454
        img(slot, x, y, 42, 42)
        im = Image.open(io.BytesIO(base64.b64decode(PORTRAITS[cl][lk]["img"].split(",")[1]))).convert("RGBA")
        bench = i in (6, 9)
        if bench: im = Image.fromarray(np.dstack([np.repeat(np.asarray(im.convert("L"))[..., None], 3, -1), np.asarray(im)[..., 3]]).astype(np.uint8), "RGBA")
        img(im, x + 6, y + 6, 30, 30, 'opacity=".5"' if bench else "")
        if bench:
            add(f'<rect x="{x - 3}" y="{y + 44}" width="48" height="15" rx="3" fill="{T["bad"]}"/>')
            text(x + 21, y + 55.5, "Benched", 11, T["badtext"], weight=700, anchor="middle")
    add(f'<rect x="560" y="452" width="232" height="54" rx="6" fill="{T["row"]}" stroke="{T["warn"]}" stroke-width="1.4"/>')
    icon("C2-11.png", 579, 469, ICON_INLINE); text(594, 474, "2 characters low morale", 12.5, weight=700)
    text(574, 494, "Rook 22, Fen 35: quit risk", 11.5, T["muted"])
    mb = gradmap(piece("B3-00.png", w=300), T["btn"])
    img(mb, 806, 454, 118, 46); text(865, 482, "Manage", 15, weight=700, anchor="middle")
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 960 540" width="1920" height="1080">'
           f'<title>Flight Path Raiders hub, {T["name"]}</title><style>{font_css()}</style>'
           f'<defs>{"".join(defs)}</defs>{"".join(out)}</svg>')
    suffix = "-notext" if notext else ""
    path = os.path.join(ROOT, f"ux/hifi/hub-{theme}{suffix}.svg"); open(path, "w").write(svg)
    if not notext:
        json.dump(texts, open(os.path.join(ROOT, f"ux/hifi/hub-{theme}.texts.json"), "w"), indent=0)
        print(os.path.relpath(path, ROOT), len(svg) // 1024, "KB")

if __name__ == "__main__":
    for t in THEMES:
        build(t); build(t, notext=True)
