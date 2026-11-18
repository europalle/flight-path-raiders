"""Shared kit for hi-fi screens: the two themes, the Gemini pieces, the board chrome and the building blocks.
Every screen is drawn on the 960 x 540 board grid. Screens record every text box so
art/tools/check_contrast.py can measure it, and save a no-text twin for that check.

Art rules (Art review, 2026-11-18), enforced here so every screen follows them:
- Icons come in fixed boxes: 16 inline with body text, 14 in the title purse, 18 on buttons.
- Nothing crosses a border: ornaments sit inside panels, icons sit inside their row or pill.
- Text never sits on a frame's rim, only on its flat middle.
- Nothing below 11 units."""
import os, io, base64, json, functools
import numpy as np
from PIL import Image
ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
UI = os.path.join(ROOT, "art/kit/ui")
PORTRAITS = json.load(open(os.path.join(ROOT, "playtest/portraits.json")))
FONT_DIR = os.environ.get("FPR_FONTS", "/tmp/claude-0/-home-claude/9afd4abb-3b1e-518e-b6c5-95385ef3302c/scratchpad/fonts/node_modules/@fontsource")
OUT = os.path.join(ROOT, "ux/hifi")
HAND = "Kalam, 'Comic Sans MS', cursive"
BODY = "'IBM Plex Sans', Arial, sans-serif"
ICON_INLINE, ICON_PURSE, ICON_BTN = 16, 14, 18

# Tokens follow the art direction doc.
THEMES = {
  "light": dict(name="Field Journal", tex="A1.jpeg", ink="#2a2119", muted="#6b5d4c", rule="#b9a582", panel="rgba(251,246,234,.84)", row="rgba(255,252,244,.9)",
                accent="#a8401a", good="#256b29", warn="#8c5a00", bad="#b3261e", badtext="#ffffff", bar="#7a5420", barbg="#e6dcc6", hp="#2e7d32",
                scrim="rgba(42,33,25,.72)",
                metal=["#2b1c0c", "#7a5420", "#c99a45", "#f6e3a8"], btn=["#3a2a16", "#8a6a3a", "#e8dcc0", "#fffaf0"],
                sel=["#3a1204", "#c44a1a", "#f2c9a8", "#fff4ea"], seltext="#2a2119",
                primary=["#120c07", "#4a3a2a", "#2a2119", "#241a12"], ptext="#fbf6ea", slot=["#2b1c0c", "#7a5420", "#c99a45", "#f3ecdc"],
                gem=["#2a0606", "#7a1414", "#d84a3a", "#ffd0c0"],
                rarity={"common": "#5d564c", "rare": "#1f5fae", "epic": "#7b2fa8", "legendary": "#b05a00"}),
  "dark": dict(name="Midnight Grimoire", tex="A2b.png", ink="#e6e1d3", muted="#b3ad9e", rule="#4a515e", panel="rgba(30,34,42,.86)", row="rgba(37,42,51,.92)",
               accent="#ff8a3d", good="#7ccf83", warn="#f0b44c", bad="#ff7b6e", badtext="#1c1f26", bar="#c9a05a", barbg="#2a2f38", hp="#5fbf68",
               scrim="rgba(8,10,14,.74)",
               metal=["#0d0f13", "#3c424d", "#8b93a1", "#dfe4ec"], btn=["#0d0f13", "#5a616e", "#8b93a1", "#2a2f38"],
               sel=["#1a0a04", "#ff8a3d", "#c45a1c", "#3a1a0c"], seltext="#ffe9d6",
               primary=["#1a0a04", "#ff8a3d", "#c45a1c", "#3a1206"], ptext="#ffe9d6", slot=["#0d0f13", "#3c424d", "#8b93a1", "#252a33"],
               gem=["#2a0606", "#7a1414", "#ff6a5a", "#ffd0c0"],
               rarity={"common": "#c7c1b3", "rare": "#7fb2ff", "epic": "#d39bff", "legendary": "#ffb35c"}),
}
CLASS_ICON = {"warrior": "C1-05.png", "paladin": "C1-03.png", "hunter": "C1-06.png", "rogue": "C1-07.png", "priest": "C1-09.png",
              "shaman": "C1-10.png", "mage": "C1-11.png", "warlock": "C1-08.png", "druid": "C1-12.png"}
ROLE_ICON = {"tank": "C1-00.png", "healer": "C1-01.png", "damage": "C1-02.png"}
SLOT_ICON = {"weapon": "C2-06.png", "plate": "C3-10.png", "mail": "C3-13.png", "leather": "C3-14.png", "cloth": "C3-15.png", "trinket": "C3-16.png"}
FULL_BODY = {("warrior", "Human"): "E1.png", ("paladin", "Human"): "E2.png", ("rogue", "Human"): "E4.png", ("priest", "Human"): "E5.png",
             ("mage", "Human"): "E7-human-mage.png", ("warlock", "Human"): "E8.png", ("warrior", "Dwarf"): "R1-dwarf-warrior.png",
             ("druid", "Night Elf"): "R10-nightelf-druid.png", ("shaman", "Dwarf"): "R11-dwarf-shaman.png", ("paladin", "Dwarf"): "R2-dwarf-paladin.png",
             ("hunter", "Dwarf"): "R3-dwarf-hunter.png", ("hunter", "Night Elf"): "R4-nightelf-hunter.png", ("rogue", "Gnome"): "R5-gnome-rogue.png",
             ("priest", "Night Elf"): "R6-nightelf-priest.png", ("mage", "Gnome"): "R7-gnome-mage.png", ("warlock", "Gnome"): "R8-gnome-warlock.png"}
LOOK = {"warrior": ["Human", "Dwarf"], "paladin": ["Human", "Dwarf"], "hunter": ["Night Elf", "Dwarf"], "rogue": ["Human", "Gnome"], "priest": ["Human", "Night Elf"],
        "shaman": ["Dwarf", "Dwarf"], "mage": ["Human", "Gnome"], "warlock": ["Human", "Gnome"], "druid": ["Night Elf", "Night Elf"]}

def b64(im, fmt="WEBP", q=86):
    b = io.BytesIO(); im.save(b, fmt, quality=q)
    return f"data:image/{fmt.lower()};base64," + base64.b64encode(b.getvalue()).decode()
@functools.lru_cache(None)
def _open(path): return Image.open(path).convert("RGBA")
def piece(name, w=None, h=None):
    im = _open(os.path.join(UI, name))
    if w or h:
        W, H = im.size
        if w and not h: h = round(H * w / W)
        if h and not w: w = round(W * h / H)
        im = im.resize((int(w), int(h)), Image.LANCZOS)
    return im
@functools.lru_cache(None)
def trimmed(name):
    im = _open(os.path.join(UI, name))
    return im.crop(im.getchannel("A").point(lambda v: 255 if v > 60 else 0).getbbox())
def gradmap(im, stops):
    a = np.asarray(im).astype(np.float32)
    lum = (0.3 * a[..., 0] + 0.59 * a[..., 1] + 0.11 * a[..., 2]) / 255
    xs = np.linspace(0, 1, len(stops)); cols = np.array([[int(c[i:i + 2], 16) for i in (1, 3, 5)] for c in stops], np.float32)
    out = np.stack([np.interp(lum, xs, cols[:, k]) for k in range(3)], -1)
    return Image.fromarray(np.dstack([out, a[..., 3]]).astype(np.uint8), "RGBA")
def grey(im):
    a = np.asarray(im.convert("RGBA")); g = np.asarray(im.convert("L"))
    return Image.fromarray(np.dstack([g, g, g, a[..., 3]]).astype(np.uint8), "RGBA")
@functools.lru_cache(None)
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
    if not css: raise SystemExit("Fonts missing: npm install @fontsource/kalam @fontsource/ibm-plex-sans and set FPR_FONTS")
    return "".join(css)
def portrait_img(cls, look):
    return Image.open(io.BytesIO(base64.b64decode(PORTRAITS[cls][look]["img"].split(",")[1]))).convert("RGBA")
def esc(s): return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")

class Board:
    def __init__(self, theme, notext=False):
        self.theme = theme; self.T = THEMES[theme]; self.notext = notext
        self.out = []; self.defs = []; self.texts = []; self._id = 0
    # ---- primitives
    def add(self, s): self.out.append(s)
    def uid(self, p="c"): self._id += 1; return f"{p}{self._id}"
    def img(self, im, x, y, w, h, extra=""):
        self.add(f'<image href="{b64(im)}" x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" preserveAspectRatio="none" {extra}/>')
    def icon(self, name, cx, cy, box, recolour=None, dim=False):
        im = trimmed(name)
        if recolour: im = gradmap(im, recolour)
        if dim: im = grey(im)
        w, h = im.size; s = box / max(w, h); w, h = w * s, h * s
        im = im.resize((max(1, round(w * 3)), max(1, round(h * 3))), Image.LANCZOS)
        self.img(im, cx - w / 2, cy - h / 2, w, h, 'opacity=".55"' if dim else "")
    def text(self, x, y, s, size=13, col=None, font=BODY, weight=400, anchor="start", italic=False):
        col = col or self.T["ink"]
        w = len(s) * size * (0.47 if font == BODY else 0.5) * (1.06 if weight >= 600 else 1)
        x0 = x - w if anchor == "end" else x - w / 2 if anchor == "middle" else x
        self.texts.append({"text": s, "x": x0, "y": y - size * 0.78, "w": w, "h": size * 0.98, "size": size, "bold": weight >= 700, "col": col})
        if self.notext: return
        self.add(f'<text x="{x:.1f}" y="{y:.1f}" font-family="{font}" font-size="{size}" font-weight="{weight}" fill="{col}" text-anchor="{anchor}"'
                 f'{" font-style=\"italic\"" if italic else ""}>{esc(s)}</text>')
    def rect(self, x, y, w, h, fill, stroke="none", sw=1.2, r=6, dash=False):
        d = ' stroke-dasharray="5 4"' if dash else ""
        self.add(f'<rect x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" rx="{r}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"{d}/>')
    def hand(self, x, y, s, size=17, col=None, anchor="start"): self.text(x, y, s, size, col, font=HAND, weight=700, anchor=anchor)
    # ---- blocks
    def background(self):
        T = self.T
        tex = Image.open(os.path.join(ROOT, "art/source/gemini", T["tex"])).convert("RGB").resize((360, 360), Image.LANCZOS)
        self.defs.append(f'<pattern id="tex" patternUnits="userSpaceOnUse" width="240" height="240"><image href="{b64(tex, q=80)}" width="240" height="240"/></pattern>')
        self.add('<rect width="960" height="540" fill="url(#tex)"/>')
    def border(self):
        m = self.T["metal"]; c = 34; e = 14
        ev = gradmap(piece("B1-03.png", w=40), m); eh = gradmap(piece("B1-13.png", h=40), m)
        self.img(eh, c - 6, 0, 960 - 2 * c + 12, e); self.img(eh, c - 6, 540 - e, 960 - 2 * c + 12, e)
        self.img(ev, 0, c - 6, e, 540 - 2 * c + 12); self.img(ev, 960 - e, c - 6, e, 540 - 2 * c + 12)
        for f, (x, y) in {"B1-00.png": (0, 0), "B1-01.png": (960 - c, 0), "B1-08.png": (0, 540 - c), "B1-09.png": (960 - c, 540 - c)}.items():
            self.img(gradmap(piece(f, w=c * 3), m), x, y, c, c)
    def chrome(self, crumb, nav=None, purse=("Week 4", "312", "85 DKP")):
        """Background, heavy border, title bar with crumb, scale and window buttons, tabs and purse."""
        T = self.T
        self.background(); self.border()
        self.hand(30, 44, "Flight Path Raiders", 22)
        self.text(232, 44, "/ " + crumb, 17, T["muted"], font=HAND)
        self.text(752, 42, "100%", 12, T["muted"], anchor="end")
        rb = gradmap(piece("B3-01.png", w=96), T["btn"])
        for i, g in enumerate(["B3-07.png", "B3-08.png", "C2-23.png", "B3-06.png"]):
            x = 764 + i * 40
            self.img(rb, x, 20, 32, 32)
            if g.startswith("B3"): self.icon(g, x + 16, 36, 13, [T["ink"]] * 4)
            else: self.icon(g, x + 16, 36, 15)
        if nav is None: return
        tab = gradmap(piece("B3-00.png", w=300), T["btn"]); sel = gradmap(piece("B3-00.png", w=300), T["sel"])
        x = 24
        for name in ["Hub", "Roster", "Tavern", "Journal"]:
            w = 66 + len(name) * 7
            self.img(sel if name == nav else tab, x, 58, w, 34)
            self.text(x + w / 2, 80, name, 13.5, T["seltext"] if name == nav else T["ink"], weight=700 if name == nav else 600, anchor="middle")
            x += w + 8
        px = 934
        for label, ic, rec in reversed([(purse[0], None, None), (purse[1], "C3-05.png", None), (purse[2], "B2-07.png", T["gem"])]):
            tw = len(label) * 12.5 * (0.6 if label[0].isdigit() else 0.5)
            self.text(px, 80, label, 12.5, T["ink"] if ic else T["muted"], weight=600 if ic else 400, anchor="end")
            px -= tw + 4
            if ic: self.icon(ic, px - 2 - ICON_PURSE / 2, 75.5, ICON_PURSE, rec); px -= ICON_PURSE + 16
            else: px -= 10
    def panel(self, x, y, w, h, corners=True, fill=None, stroke=None, sw=1.2, dash=False):
        T = self.T
        self.rect(x, y, w, h, fill or T["panel"], stroke or T["rule"], sw, dash=dash)
        if corners:
            lc = [gradmap(piece(f, w=60), T["metal"]) for f in ("B1-05.png", "B1-06.png", "B1-10.png", "B1-11.png")]
            s = 18; i = 2
            self.img(lc[0], x + i, y + i, s, s); self.img(lc[1], x + w - s - i, y + i, s, s)
            self.img(lc[2], x + i, y + h - s - i, s, s); self.img(lc[3], x + w - s - i, y + h - s - i, s, s)
    def button(self, x, y, w, h, label, kind="normal", size=14, icon=None, sub=None, sub_col=None):
        """kind: normal, selected, primary. Primary uses the hand font, like the hub's Prep pull."""
        T = self.T
        stops = {"normal": T["btn"], "selected": T["sel"], "primary": T["primary"]}[kind]
        src = "B3-10.png" if (kind == "primary" and self.theme == "light") else "B3-00.png"
        self.img(gradmap(piece(src, w=420 if kind == "primary" else 300), stops), x, y, w, h)
        col = T["ptext"] if kind == "primary" else T["seltext"] if kind == "selected" else T["ink"]
        cy = y + h / 2 + size * 0.36 - (6 if sub else 0)
        tx = x + w / 2
        if icon:
            tw = len(label) * size * 0.5
            self.icon(icon, tx - tw / 2 - 4, cy - size * 0.36, ICON_BTN); tx += ICON_BTN / 2 + 2
        if kind == "primary": self.hand(tx, cy + 1, label, size, col, anchor="middle")
        else: self.text(tx, cy, label, size, col, weight=700, anchor="middle")
        if sub: self.text(x + w / 2, cy + 15, sub, 11, sub_col or col, anchor="middle")
    def portrait(self, cls, look, x, y, s, dim=False, frame=True):
        if frame: self.img(gradmap(piece("B4-01.png", w=140), self.T["slot"]), x, y, s, s)
        im = portrait_img(cls, look)
        if dim: im = grey(im)
        p = s * 0.14
        self.img(im, x + p, y + p, s - 2 * p, s - 2 * p, 'opacity=".5"' if dim else "")
    def full_body(self, cls, race, x, y, h):
        im = Image.open(os.path.join(ROOT, "art/kit/characters", FULL_BODY[(cls, race)])).convert("RGBA")
        im = im.crop(im.getbbox()); W, H = im.size; w = W * h / H
        im = im.resize((int(w * 2), int(h * 2)), Image.LANCZOS)
        self.img(im, x - w / 2, y, w, h)
        return w
    def bar(self, x, y, w, h, frac, col=None, bg=None):
        T = self.T
        self.rect(x, y, w, h, bg or T["barbg"], T["rule"], 0.8, r=h / 2)
        if frac > 0: self.rect(x, y, max(h, w * frac), h, col or T["bar"], "none", r=h / 2)
    def pips(self, x, y, n, total, col):
        for i in range(total):
            self.add(f'<circle cx="{x + i * 9:.1f}" cy="{y:.1f}" r="3.3" fill="{col if i < n else "none"}" stroke="{col}" stroke-width="1.2"/>')
    def tag(self, x, y, label, col, text_col=None, size=11, anchor="start"):
        """A small filled tag. Text colour defaults to the theme's badge text."""
        w = len(label) * size * 0.56 + 12
        x0 = x - w if anchor == "end" else x
        self.rect(x0, y, w, size + 5, col, "none", r=3)
        self.text(x0 + w / 2, y + size + 0.5, label, size, text_col or self.T["badtext"], weight=700, anchor="middle")
        return w
    def chip(self, x, y, label, size=11.5, icon=None, col=None, stroke=None):
        T = self.T
        w = len(label) * size * 0.5 + 18 + (ICON_INLINE + 4 if icon else 0)
        self.rect(x, y, w, size + 11, T["row"], stroke or T["rule"], 1, r=(size + 11) / 2)
        tx = x + 9
        if icon: self.icon(icon, tx + ICON_INLINE / 2, y + (size + 11) / 2, ICON_INLINE - 2); tx += ICON_INLINE + 4
        self.text(tx, y + size + 4.5, label, size, col or T["ink"], weight=600)
        return w
    def scrim(self): self.rect(0, 0, 960, 540, self.T["scrim"], r=0)
    def boss_scene(self, x, y, w, h, crop=0.15, boss_h=None):
        """The Molten Bore cave with Ragnaroast standing in it, clipped to the box."""
        cave = Image.open(os.path.join(ROOT, "art/source/gemini/G1.jpeg" if os.path.exists(os.path.join(ROOT, "art/source/gemini/G1.jpeg")) else "art/source/gemini/F2.jpeg")).convert("RGB")
        W, H = cave.size; tw = int(W * 0.9); th = int(tw * h / w)
        if th > H: th = H; tw = int(th * w / h)
        cave = cave.crop(((W - tw) // 2, max(0, int(H * crop) if int(H * crop) + th <= H else H - th), (W - tw) // 2 + tw, max(0, int(H * crop) if int(H * crop) + th <= H else H - th) + th))
        cave = cave.resize((int(w * 2), int(h * 2)), Image.LANCZOS).convert("RGBA")
        rag = Image.open(os.path.join(ROOT, "art/kit/bosses/F1-ragnaroast.png")).convert("RGBA"); rag = rag.crop(rag.getbbox())
        bh = int((boss_h or h * 0.9) * 2); rag = rag.resize((int(rag.size[0] * bh / rag.size[1]), bh), Image.LANCZOS)
        cave.alpha_composite(rag, (cave.size[0] - rag.size[0] - int(w * 0.06), cave.size[1] - rag.size[1] + int(h * 0.05)))
        cid = self.uid("clip")
        self.defs.append(f'<clipPath id="{cid}"><rect x="{x}" y="{y}" width="{w}" height="{h}" rx="5"/></clipPath>')
        self.add(f'<image href="{b64(cave.convert("RGB"), q=82)}" x="{x}" y="{y}" width="{w}" height="{h}" clip-path="url(#{cid})" preserveAspectRatio="none"/>')
        self.rect(x, y, w, h, "none", self.T["metal"][1], 3, r=5)
    def save(self, name, title):
        svg = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 960 540" width="1920" height="1080">'
               f'<title>Flight Path Raiders {esc(title)}, {self.T["name"]}</title><style>{font_css()}</style>'
               f'<defs>{"".join(self.defs)}</defs>{"".join(self.out)}</svg>')
        path = os.path.join(OUT, f"{name}-{self.theme}{'-notext' if self.notext else ''}.svg")
        open(path, "w").write(svg)
        if not self.notext: json.dump(self.texts, open(os.path.join(OUT, f"{name}-{self.theme}.texts.json"), "w"), indent=0)
        return path
