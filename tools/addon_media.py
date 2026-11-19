"""Exports the art the addon needs into <dist>/Media as TGA (power-of-two sizes, which every WoW client
accepts) and writes Media.lua with the theme tokens from art/tools/hifi_kit.py, so the addon and the hi-fi
use the same colours. Called by tools/build_addon.py.
Fonts: the addon uses the client's own fonts for now (Friz Quadrata, Arial Narrow). Shipping Kalam and
IBM Plex (both OFL) needs their TTF files; tracked for production."""
import os, sys, io
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "art", "tools"))
from hifi_kit import THEMES, piece, trimmed, gradmap, portrait_img, rim, ROOT, CLASS_ICON, ROLE_ICON, FULL_BODY, LOOK

ICONS = {"coin": "C3-05.png", "gem": "B2-07.png", "warn": "C2-11.png", "check": "C2-16.png", "book": "C3-04.png", "chest": "C3-08.png",
         "firepot": "C3-03.png", "food": "C3-00.png", "elixir": "C3-02.png", "flask": "C3-01.png", "lock": "C2-15.png", "gear": "C2-23.png",
         "weapon": "C2-06.png", "plate": "C3-10.png", "mail": "C3-13.png", "leather": "C3-14.png", "cloth": "C3-15.png", "trinket": "C3-16.png",
         "lava": "C2-04.png", "scroll": "C3-09.png",
         # armour by slot (C3b, issue #36): picked by item name in UI.itemIcon
         "sandals": "C3b-00.png", "boots": "C3b-01.png", "trousers": "C3b-02.png", "legplates": "C3b-04.png", "helm": "C3b-06.png",
         "hood": "C3b-07.png", "cardigan": "C3b-09.png", "lanyard": "C3b-10.png", "mitts": "C3b-mitts.png", "gauntlets": "C3b-gauntlets.png"}
for c, f in CLASS_ICON.items(): ICONS["class-" + c] = f
for r, f in ROLE_ICON.items(): ICONS["role-" + r] = f

def tga(im, path):
    im.save(path, "TGA")  # uncompressed; RLE support varies by client

def fit(im, size):
    """Fit inside a size x size transparent square, centred."""
    im = im.copy(); im.thumbnail((size, size), Image.LANCZOS)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0)); out.alpha_composite(im, ((size - im.size[0]) // 2, (size - im.size[1]) // 2))
    return out

def fit_tall(im):
    """Fit inside 128 x 256 (a full-body figure), bottom-aligned, transparent around it."""
    im = im.copy(); im.thumbnail((128, 256), Image.LANCZOS)
    out = Image.new("RGBA", (128, 256), (0, 0, 0, 0)); out.alpha_composite(im, ((128 - im.size[0]) // 2, 256 - im.size[1]))
    return out

def rgb(h):
    if h.startswith("rgba"):
        v = h[5:-1].split(","); return [round(int(v[0]) / 255, 3), round(int(v[1]) / 255, 3), round(int(v[2]) / 255, 3), float(v[3])]
    return [round(int(h[i:i + 2], 16) / 255, 3) for i in (1, 3, 5)]

def export(out_dir):
    M = os.path.join(out_dir, "Media"); os.makedirs(M, exist_ok=True)
    files = []
    def save(im, name): tga(im, os.path.join(M, name + ".tga")); files.append(name)
    for name, f in ICONS.items():
        im = trimmed(f)
        if name == "gem": im = gradmap(im, THEMES["light"]["gem"])
        save(fit(im, 32), "icon-" + name)
    for theme, T in THEMES.items():
        tex = Image.open(os.path.join(ROOT, "art/source/gemini", T["tex"])).convert("RGB").resize((256, 256), Image.LANCZOS)
        save(tex.convert("RGBA"), f"bg-{theme}")
        # Buttons as 3-slice (frame kit, issue #5): two end caps that keep their shape and a middle that
        # stretches, so short and long buttons both look drawn rather than squashed.
        for kind, stops in (("normal", T["btn"]), ("selected", T["sel"]), ("primary", T["primary"])):
            src = "B3-10.png" if (kind == "primary" and theme == "light") else "B3-00.png"
            b = gradmap(trimmed(src), stops); W, H = b.size; cap = int(H * 0.5)
            save(b.crop((0, 0, cap, H)).resize((64, 128), Image.LANCZOS), f"btn-{kind}-{theme}-l")
            save(b.crop((cap, 0, W - cap, H)).resize((128, 128), Image.LANCZOS), f"btn-{kind}-{theme}-m")
            save(b.crop((W - cap, 0, W, H)).resize((64, 128), Image.LANCZOS), f"btn-{kind}-{theme}-r")
        # Panel corner ornaments, inside the panel (art rule: nothing crosses a border).
        for i, f in enumerate(("B1-05.png", "B1-06.png", "B1-10.png", "B1-11.png")):
            save(gradmap(piece(f, w=32, h=32), T["metal"]), f"orn-{i + 1}-{theme}")
        # The playback stage (issue #8): the Molten Bore, toned down on the left where the raid stands,
        # on the cave's own floor.
        cave = Image.open(os.path.join(ROOT, "art/source/gemini/G1.jpeg")).convert("RGB")
        # Crop to the stage's shape (610 x 340) inside the image, never past its edge (a crop past the
        # bottom left a black band: gate review M3).
        W, H = cave.size; ch = min(H, int(W * 340 / 610)); cw = int(ch * 610 / 340); x0 = (W - cw) // 2; y0 = H - ch
        cave = cave.crop((x0, y0, x0 + cw, y0 + ch)).resize((512, 256), Image.LANCZOS).convert("RGBA")
        # The G3 ground strip does not blend with this cave crop (it shows a pale band), so the stage uses
        # the cave's own floor. G3 waits for the animated stage in Phase 4.
        panel = rgb(T["panel"])
        shade = Image.new("RGBA", (512, 256))
        px = shade.load()
        for x in range(512):
            a = int(255 * 0.62 * max(0.0, 1 - x / 300))
            for y in range(256): px[x, y] = tuple(int(c * 255) for c in panel[:3]) + (a,)
        cave.alpha_composite(shade)
        save(cave, f"stage-{theme}")
        m = T["metal"]
        save(gradmap(piece("B1-13.png", w=256, h=16), m), f"edge-h-{theme}")
        save(gradmap(piece("B1-03.png", w=16, h=256), m), f"edge-v-{theme}")
        for i, f in enumerate(("B1-00.png", "B1-01.png", "B1-08.png", "B1-09.png")):
            save(gradmap(piece(f, w=64, h=64), m), f"corner-{i + 1}-{theme}")
        # Full-body art for the Tavern cards (64 x 128 board units, as the hi-fi), with rim light in dark mode.
        for cls, races in LOOK.items():
            for look, race in enumerate(races):
                im = Image.open(os.path.join(ROOT, "art/kit/characters", FULL_BODY[(cls, race)])).convert("RGBA"); im = im.crop(im.getbbox())
                if theme == "dark": im = rim(im, width=5)
                save(fit_tall(im), f"body-{cls}-{look}-{theme}")
        slot = gradmap(piece("B4-01.png", w=64, h=64), T["slot"])
        for cls in CLASS_ICON:
            for look in (0, 1):
                p = portrait_img(cls, look)
                if theme == "dark": p = rim(p)
                im = slot.copy(); p = p.resize((46, 46), Image.LANCZOS); im.alpha_composite(p, (9, 9))
                save(im, f"portrait-{cls}-{look}-{theme}")
    # Boss scenes: the cave with the boss in it, for every boss Art has drawn (art/kit/bosses/F<n>-<id>.png).
    # Bosses without a drawing yet show their initial; the scene appears as soon as the PNG is added.
    import glob
    bosses = []
    for bid in ("magmadad", "baron", "lucifrown", "majordomo", "ragnaroast"):
        found = sorted(glob.glob(os.path.join(ROOT, "art/kit/bosses", f"F*-{bid}.png")))
        if not found: continue
        cave = Image.open(os.path.join(ROOT, "art/source/gemini/G1.jpeg")).convert("RGB")
        W, H = cave.size; cave = cave.crop((W // 2 - int(H * 0.8), int(H * 0.1), W // 2 + int(H * 0.8), int(H * 0.9))).resize((256, 128), Image.LANCZOS).convert("RGBA")
        art = Image.open(found[0]).convert("RGBA"); art = art.crop(art.getbbox())
        art = art.resize((int(art.size[0] * 120 / art.size[1]), 120), Image.LANCZOS)
        if art.size[0] > 240: art = art.resize((240, int(art.size[1] * 240 / art.size[0])), Image.LANCZOS)
        cave.alpha_composite(art, (256 - art.size[0] - 16, 128 - art.size[1] - 4))
        save(cave, "boss-" + bid); bosses.append(bid)
        cut = Image.open(found[0]).convert("RGBA"); cut = cut.crop(cut.getbbox())
        save(fit(cut, 256), "bossart-" + bid)
    lua = ["-- Generated by tools/addon_media.py from art/tools/hifi_kit.py. Do not edit.", "local _, ns = ...",
           'ns.MEDIA = { path = "Interface\\\\AddOns\\\\FlightPathRaiders\\\\Media\\\\", themes = {}, rarity = {} }']
    lua.append("ns.MEDIA.bosses = { " + ", ".join(f"{b} = true" for b in bosses) + " }")
    keys = ("ink", "muted", "rule", "panel", "row", "accent", "good", "warn", "bad", "badtext", "bar", "barbg", "hp", "scrim", "ptext", "seltext")
    for theme, T in THEMES.items():
        lua.append(f"ns.MEDIA.themes.{theme} = {{ " + ", ".join(f"{k} = {{ {', '.join(str(v) for v in rgb(T[k]))} }}" for k in keys) +
                   ", rarity = { " + ", ".join(f"{k} = {{ {', '.join(str(v) for v in rgb(c))} }}" for k, c in T["rarity"].items()) + " } }")
    open(os.path.join(out_dir, "Media.lua"), "w").write("\n".join(lua) + "\n")
    return files

if __name__ == "__main__":
    print(len(export(sys.argv[1])), "textures")
