"""Hi-fi for every vertical-slice screen, light and dark: prep, playback, results (a wipe with the recap),
results with the loot window (a kill), roster, tavern, journal and settings. The hub stays in hifi_hub.py.
Content uses the slice's real rules and words (engine/game.lua): cards, traits, morale, prices.
Writes ux/hifi/<screen>-<theme>.svg (+ -notext.svg, .texts.json); with --png also a 1920 x 1080 PNG.
Usage: python3 art/tools/hifi_screens.py [--png] [screen ...]"""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
from hifi_kit import Board, THEMES, ROOT, OUT, CLASS_ICON, ROLE_ICON, SLOT_ICON, LOOK, ICON_INLINE, HAND

# One guild, used on every screen so they agree with each other.
RAID = [  # name, class, spec, role, zone, look, GL, morale, traits
    ("Brannoc", "warrior", "Protection", "tank", "Front", 1, 66, 82, ["Pulls on Cooldown"]),
    ("Mira", "paladin", "Protection", "tank", "Front", 0, 64, 77, ["Raid Leader's Favourite"]),
    ("Kess", "rogue", "Combat", "damage", "Melee", 1, 67, 71, ["Needs on Everything"]),
    ("Tor", "warrior", "Fury", "damage", "Melee", 0, 63, 58, ["Stands in Fire", "Rage Quitter"]),
    ("Ash", "shaman", "Enhancement", "damage", "Melee", 0, 62, 74, ["Parse Goblin"]),
    ("Lumi", "mage", "Frost", "damage", "Ranged", 1, 65, 80, ["Keyboard Turner"]),
    ("Orrin", "hunter", "Marksmanship", "damage", "Ranged", 0, 63, 66, ["Pet on Aggressive", "Needs on Everything"]),
    ("Sela", "priest", "Holy", "healer", "Back", 1, 64, 85, ["Hardcore Andy"]),
    ("Bram", "druid", "Restoration", "healer", "Back", 0, 61, 69, ["Backseat Raid Leader"]),
    ("Thessa", "paladin", "Holy", "healer", "Back", 0, 62, 73, ["Main-Spec Loot Only"]),
]
BENCH = [("Rook", "mage", "Fire", "damage", 0, 58, 18, ["Alt-Tabbed"], "Benched until reset"),
         ("Fen", "rogue", "Subtlety", "damage", 0, 57, 35, ["AFK on Trash"], "Bench"),
         ("Dax", "hunter", "Beast Mastery", "damage", 1, 56, 62, ["Discord Lawyer"], "Bench")]
CARDS = [("Spread", "Splash hits one character", "healing -10%"), ("Stack", "Healing +15%", "area hits land on everyone"),
         ("Burn", "Damage +10%, threat +25%", "heals cost 20% more mana"), ("Play Safe", "Damage -5%", "everyone takes 15% less")]

def morale_col(T, m): return T["bad"] if m < 20 else T["warn"] if m < 40 else T["good"] if m >= 80 else T["ink"]

# ------------------------------------------------------------------ prep
def prep(b):
    T = b.T
    b.chrome("Prep · Ragnaroast (Heroic)", nav="Hub")
    b.panel(24, 100, 912, 62, corners=False)
    b.boss_scene(32, 106, 78, 50, boss_h=48)
    b.text(122, 125, "Throws the lowest-health melee into the lava every 4 rounds. Sinks at round 10 and sends fire adds.", 13, weight=600)
    b.icon("C3-04.png", 130, 145, ICON_INLINE)
    b.text(142, 150, "Journal: fire resistance is the answer here. Gear and potions for melee and tanks.", 12, T["muted"])
    b.rect(774, 116, 150, 30, T["row"], T["warn"], 1.4, r=15)
    b.icon("C2-11.png", 792, 131, ICON_INLINE); b.text(806, 136, "3 melee: risky", 12.5, weight=700)
    # Zones.
    zones = ["Front", "Melee", "Ranged", "Back"]
    for zi, z in enumerate(zones):
        y = 174 + zi * 54
        b.hand(30, y + 30, z, 16)
        members = [r for r in RAID if r[4] == z]
        for k, (n, cl, sp, role, _, lk, gl, mo, tr) in enumerate(members):
            x = 96 + k * 160
            b.rect(x, y, 152, 48, T["row"], T["rule"], 1)
            b.portrait(cl, lk, x + 4, y + 4, 40)
            b.text(x + 50, y + 18, n, 13, weight=700)
            b.icon(ROLE_ICON[role], x + 140, y + 12, 14)
            b.text(x + 50, y + 32, f"{sp} {cl.title()}" if len(sp) + len(cl) < 15 else sp, 11, T["muted"])
            b.text(x + 50, y + 44, f"GL {gl}", 11, weight=600)
            b.text(x + 92, y + 44, f"Mor {mo}", 11, morale_col(T, mo), weight=600)
            if role == "tank" or z == "Melee":
                b.icon("C3-03.png", x + 141, y + 38, 13)
    # Bench.
    b.panel(744, 172, 192, 210, corners=False, dash=True)
    b.hand(758, 196, "Bench (2)", 16)
    for i, (n, cl, sp, role, lk, gl, mo, tr, st) in enumerate(BENCH[1:]):
        y = 206 + i * 44
        b.rect(756, y, 168, 38, T["row"], T["rule"], 1)
        b.portrait(cl, lk, 760, y + 3, 32)
        b.text(798, y + 17, n, 12.5, weight=700); b.text(798, y + 31, f"{cl.title()} · GL {gl}", 11, T["muted"])
    b.text(758, 308, "Benched until reset", 12, weight=700)
    n, cl, sp, role, lk, gl, mo, tr, st = BENCH[0]
    b.rect(756, 316, 168, 38, T["row"], T["bad"], 1, dash=True)
    b.portrait(cl, lk, 760, 319, 32, dim=True)
    b.text(798, 333, n, 12.5, T["muted"], weight=700); b.text(798, 347, "Died to lava, H 3", 11, T["muted"])
    b.text(758, 374, "Click a raider to swap", 11, T["muted"])
    # Tactic cards.
    b.hand(30, 418, "Tactic", 16)
    for i, (nm, a, c) in enumerate(CARDS):
        x = 96 + i * 160; sel = nm == "Burn"
        b.button(x, 392, 152, 48, nm, "selected" if sel else "normal", 14)
        if sel: b.icon("C2-16.png", x + 30, 416, 14)
        b.text(x + 76, 452, a, 11, T["ink"] if sel else T["muted"], weight=600 if sel else 400, anchor="middle")
    # Cauldrons and cost.
    b.hand(30, 494, "Prep", 16)
    x = 96
    for label, ic, on in [("Food: free (Lumi)", "C3-00.png", True), ("Elixirs 30 g", "C3-02.png", True), ("Flasks 75 g", "C3-01.png", True), ("Fire potions ×3  45 g", "C3-03.png", True)]:
        x += b.chip(x, 478, label, icon=ic, stroke=T["accent"] if on else None) + 8
    b.text(744, 470, "This pull costs", 12, T["muted"]); b.text(744, 488, "150 gold of 312", 13, weight=700)
    b.text(744, 506, "Same as last pull", 11.5, T["accent"], weight=600)
    b.button(840, 462, 96, 52, "Pull", "primary", 22)

# ------------------------------------------------------------------ playback
def playback(b):
    T = b.T
    b.chrome("Pull · Ragnaroast (Heroic)")
    b.boss_scene(24, 70, 610, 340, crop=0.1, boss_h=300)
    # Raiders on stage, by zone, in portrait slots (the stage art pass replaces these with sprites).
    pos = {"Front": [(300, 250), (300, 320)], "Melee": [(230, 205), (230, 275), (230, 345)], "Ranged": [(140, 230), (140, 310)], "Back": [(60, 200), (60, 270), (60, 340)]}
    used = {k: 0 for k in pos}
    for (n, cl, sp, role, z, lk, gl, mo, tr) in RAID:
        x, y = pos[z][used[z]]; used[z] += 1
        dead = n == "Tor"
        b.portrait(cl, lk, x, y, 46, dim=dead)
        if dead: b.icon("C2-04.png", x + 40, y + 8, 14)
    b.rect(330, 148, 166, 32, T["row"], T["rule"], 1.2, r=8)
    b.text(413, 169, "Tor: “bye o/”", 13, weight=600, anchor="middle")
    b.rect(36, 80, 262, 22, T["row"], T["rule"], 1, r=11)
    b.text(48, 95, "Zones: tanks front, healers at the back", 11.5)
    # Round and boss.
    b.panel(648, 70, 288, 118, corners=False)
    b.text(662, 92, "Round", 12, T["muted"], weight=600)
    b.hand(662, 132, "7", 40); b.text(690, 132, "/ 20", 16, T["muted"])
    b.text(922, 92, "Sinks at round 10", 11.5, T["muted"], anchor="end")
    b.text(662, 160, "Ragnaroast", 13, weight=700); b.text(922, 160, "58%", 13, weight=700, anchor="end")
    b.bar(662, 168, 260, 12, 0.58, T["accent"])
    # Log.
    b.panel(648, 198, 288, 212, corners=False)
    b.hand(662, 222, "What happened", 16)
    log = [("R4", "Tor goes into the lava. No potion.", T["bad"], 700), ("R5", "Brannoc pulls aggro off Mira.", T["ink"], 400),
           ("R6", "Sela heals Mira for 240.", T["good"], 400), ("R6", "Magma Splash on Melee.", T["warn"], 600),
           ("R7", "Burn: Ragnaroast takes 1,120.", T["ink"], 600), ("R7", "Kess lands a crit.", T["ink"], 400)]
    for i, (r, t, c, w) in enumerate(log):
        y = 248 + i * 26
        b.text(662, y, r, 11.5, T["muted"], weight=700); b.text(692, y, t, 12, c, weight=w)
    # Raid health.
    for i, (n, cl, sp, role, z, lk, gl, mo, tr) in enumerate(RAID):
        x = 24 + i * 91.5
        b.rect(x, 420, 86, 40, T["row"], T["rule"], 1)
        b.text(x + 6, 436, n, 11.5, T["muted"] if n == "Tor" else T["ink"], weight=700)
        if n == "Tor": b.text(x + 80, 436, "Dead", 11, T["bad"], weight=700, anchor="end")
        hp = {"Brannoc": .62, "Mira": .48, "Tor": 0, "Kess": .9, "Ash": .35, "Bram": .88}.get(n, .8)
        b.bar(x + 6, 444, 74, 6, hp, T["hp"] if hp > .4 else T["bad"])
        if role == "healer": b.bar(x + 6, 452, 74, 4, .55, "#4a7fd0")
    b.button(24, 474, 120, 44, "Pause")
    b.button(152, 474, 110, 44, "Speed ×2")
    b.button(270, 474, 190, 44, "Skip to result", "primary", 19)
    b.button(468, 474, 150, 44, "Summary only")
    b.text(936, 492, "The result was decided at Pull.", 11.5, T["muted"], anchor="end")
    b.text(936, 508, "Skipping loses nothing.", 11.5, T["muted"], anchor="end")

# ------------------------------------------------------------------ results: wipe and the recap
def results_body(b, kill):
    T = b.T
    b.panel(24, 100, 912, 66, corners=False, fill=T["row"], stroke=T["good"] if kill else T["bad"], sw=2)
    if kill:
        b.hand(44, 140, "Kill in round 16", 26)
        b.text(916, 132, "+60 gold · +15 DKP", 13, weight=700, anchor="end")
        b.text(916, 150, "Heroic score this week 3,240", 12, T["muted"], anchor="end")
    else:
        b.hand(44, 140, "Wipe in round 15", 26)
        b.text(916, 132, "Ragnaroast at 31%", 13, weight=700, anchor="end")
        b.text(916, 150, "Every tank and healer is down", 12, T["muted"], anchor="end")
    b.text(44, 192, "“Is that your healer or a decorative candle?”" if not kill else "“Too soon... you have roasted me... too soon!”", 13, italic=True)
    # Recap: what happened, the raid leader's clue, the answer (tier 2 shown).
    b.panel(24, 204, 560, 132, corners=False)
    b.rect(24, 204, 5, 132, T["warn"], r=2)
    if kill:
        b.text(42, 226, "YOU WON, BUT", 11, T["warn"], weight=700)
        b.text(42, 248, "2 died to fire on the way: the lava and Magma Splash.", 13.5, weight=600)
        b.text(42, 274, "Raid leader: \u201cPotions on every melee next week.\u201d", 13, italic=True)
        b.text(42, 300, "Your raid has this fight worked out.", 12, T["muted"])
    else:
        b.text(42, 226, "WHAT HAPPENED", 11, T["warn"], weight=700)
        b.text(42, 248, "3 died to fire: the lava, Magma Splash and the fire adds.", 13.5, weight=600)
        b.text(42, 274, "Raid leader: “We’re melting. Literally.”", 13, italic=True)
        b.text(42, 300, "Your raid is close to working it out.", 12, T["muted"])
    b.icon("C3-04.png", 50, 320, ICON_INLINE); b.text(64, 325, "New in the journal: Magma Splash, Sinks and sends adds", 12, weight=600)
    # Money, growth, morale.
    b.hand(24, 364, "Gold", 15)
    b.text(24, 384, "Prep -150 · Repairs waived: first wipe this week (62 gold)", 12)
    b.hand(24, 412, "Getting better", 15)
    b.text(24, 432, "Skill +0.6 · knows Ragnaroast +0.3 · chemistry +0.4", 12)
    b.hand(24, 460, "Morale", 15)
    b.text(24, 480, "Wipe: 10 raiders -3 · Backseat raid leading: 9 raiders -2", 12)
    b.icon("C2-11.png", 32, 500, ICON_INLINE); b.text(46, 505, "Rook 18: may quit at the end of the week", 12, T["bad"], weight=700)
    # Replay.
    b.panel(600, 204, 336, 132)
    b.hand(618, 232, "Replay that pull", 16)
    b.text(618, 254, "The exact same pull with another card.", 12, T["muted"])
    b.text(618, 270, "Nothing is won or lost. Once per boss a week.", 12, T["muted"])
    for i, c in enumerate(["Spread", "Stack", "Play Safe"]):
        b.button(618 + i * 104, 284, 96, 36, c, size=13)
    b.button(600, 466, 150, 50, "Pull again", "primary", 20)
    b.button(758, 466, 110, 50, "Change plan", size=13)
    b.button(876, 466, 60, 50, "Hub", size=13)

def results(b):
    b.chrome("Result · Ragnaroast (Heroic)")
    results_body(b, kill=False)

# ------------------------------------------------------------------ loot window (a kill)
def loot(b):
    T = b.T
    b.chrome("Result · Ragnaroast (Heroic)")
    results_body(b, kill=True)
    for t in b.texts: t["behind"] = True  # under the scrim on purpose: not measured
    b.scrim()
    b.panel(150, 92, 660, 412, fill=T["panel"].replace(".84", ".97").replace(".86", ".98"), stroke=T["metal"][2], sw=2)
    b.icon("C3-08.png", 190, 130, 40)
    b.hand(222, 130, "Loot", 24)
    b.text(222, 150, "2 items · Bind on Pickup: only the 10 in this pull can have them · numbers are gear level gained", 12, T["muted"])
    b.text(790, 128, "2 left", 12.5, weight=700, anchor="end")
    items = [("Roasting Spit of the Firelord", "Epic · Weapon · gear level 68", "spit",
              [("Kess", "rogue", 1, "+12", True), ("Orrin", "hunter", 0, "+9", False), ("Tor", "warrior", 0, "+5", False)],
              ("C2-11.png", "Orrin has Needs on Everything: 15% chance he takes it anyway.")),
             ("Crispy Chainmail", "Epic · Mail armor · gear level 66", "C3-13.png",
              [("Ash", "shaman", 0, "+8", True), ("Orrin", "hunter", 0, "+5", False)], (None, "Only mail wearers are offered mail."))]
    for i, (nm, meta, art, cands, (wic, warn)) in enumerate(items):
        y = 168 + i * 134
        b.rect(168, y, 624, 122, T["row"], T["rule"], 1)
        b.img(__import__("hifi_kit").gradmap(__import__("hifi_kit").piece("B4-01.png", w=140), T["slot"]), 180, y + 12, 56, 56)
        if art == "spit":
            from PIL import Image
            im = Image.open(os.path.join(ROOT, "art/kit/bosses/F1-roasting-spit.png")).convert("RGBA"); im = im.crop(im.getbbox())
            im = im.rotate(38, expand=True, resample=Image.BICUBIC); im = im.crop(im.getbbox())
            w, h = im.size; s = 46 / max(w, h); im = im.resize((int(w * s * 3), int(h * s * 3)), Image.LANCZOS)
            b.img(im, 208 - w * s / 2, y + 40 - h * s / 2, w * s, h * s)
        else: b.icon(art, 208, y + 40, 36)
        b.text(248, y + 32, nm, 15, T["rarity"]["epic"], weight=700)
        b.text(248, y + 50, meta, 12, T["muted"])
        for k, (n, cl, lk, g, best) in enumerate(cands):
            x = 248 + k * 150
            b.button(x, y + 58, 144, 40, "", "selected" if best else "normal")
            b.portrait(cl, lk, x + 16, y + 64, 28, frame=False)
            b.text(x + 48, y + 83, n, 12.5, T["seltext"] if best else T["ink"], weight=700)
            b.text(x + 124, y + 83, g, 12.5, T["seltext"] if best else T["ink"], weight=700, anchor="end")
        b.button(700, y + 58, 84, 40, "Sell 17 g", size=12)
        if wic: b.icon(wic, 256, y + 110, 14)
        b.text(268 if wic else 248, y + 114, warn, 11.5, T["ink"] if wic else T["muted"], weight=600 if wic else 400)
    b.text(170, 470, "Loot drama can happen: 10% per item.", 11.5, T["muted"])
    b.button(486, 446, 120, 44, "Decide later", size=13)
    b.button(614, 444, 178, 48, "Hand out", "primary", 20)

# ------------------------------------------------------------------ roster
def roster(b):
    T = b.T
    b.chrome("Roster", nav="Roster")
    x = 24
    for i, f in enumerate(["All 13", "Tanks 2", "Healers 3", "Damage 8"]):
        w = len(f) * 7 + 30
        b.button(x, 100, w, 28, f, "selected" if i == 0 else "normal", 12); x += w + 6
    b.text(544, 119, "Sort: status", 12, weight=600, anchor="end")
    for xx, c in [(70, "Name"), (178, "Class · spec"), (342, "GL"), (374, "Morale"), (456, "Status")]:
        b.text(xx, 148, c, 11, T["muted"], weight=700)
    rows = [(n, cl, sp, lk, gl, mo, "Ready") for (n, cl, sp, role, z, lk, gl, mo, tr) in RAID[:7]] + [(n, cl, sp, lk, gl, mo, st) for (n, cl, sp, role, lk, gl, mo, tr, st) in BENCH]
    for i, (n, cl, sp, lk, gl, mo, st) in enumerate(rows):
        y = 156 + i * 34; sel = n == "Kess"; bench = st.startswith("Benched")
        b.rect(24, y, 520, 30, T["row"], T["accent"] if sel else T["rule"], 2 if sel else 1, dash=bench)
        b.portrait(cl, lk, 28, y + 1, 28, dim=bench, frame=False)
        b.text(70, y + 20, n, 12.5, T["muted"] if bench else T["ink"], weight=700)
        b.icon(CLASS_ICON[cl], 186, y + 15, 14); b.text(198, y + 20, f"{cl.title()} · {sp}", 12)
        b.text(342, y + 20, str(gl), 12, weight=600)
        b.bar(374, y + 11, 36, 8, mo / 100, morale_col(T, mo)); b.text(416, y + 20, str(mo), 11.5, morale_col(T, mo), weight=700)
        if mo < 40: b.icon("C2-11.png", 443, y + 15, 13)
        if bench: b.tag(456, y + 7, "Benched", T["bad"])
        else: b.text(456, y + 20, st, 12, T["muted"] if st == "Bench" else T["ink"])
    b.text(24, 508, "Roster 13 / 15 · 3 more below", 12, T["muted"])
    # Detail.
    b.panel(560, 100, 376, 424)
    b.portrait("rogue", 1, 578, 118, 72)
    b.hand(662, 142, "Kess", 22)
    b.text(662, 162, "Gnome Rogue · Combat · Rare", 12, T["muted"])
    b.pips(666, 178, 2, 4, T["rarity"]["rare"]); b.text(704, 182, "GL 67 · skill 46", 12, weight=600)
    b.text(578, 214, "Traits", 12, T["muted"], weight=700)
    b.rect(578, 222, 340, 40, T["row"], T["rule"], 1)
    b.text(588, 238, "Needs on Everything", 12.5, weight=700)
    b.text(588, 254, "15% chance to grab loot you gave someone else.", 11.5, T["muted"])
    b.text(578, 284, "Morale", 12, T["muted"], weight=700)
    b.bar(640, 276, 220, 10, .71, T["ink"]); b.text(918, 285, "71", 13, weight=700, anchor="end")
    b.text(578, 302, "Last week: kill +3 · loot +6 · wipe -3. Under 20 risks quitting.", 11.5, T["muted"])
    b.text(578, 328, "Gear", 12, T["muted"], weight=700)
    for i, (sl, it, gl, ic) in enumerate([("Weapon", "Dad's Grill Spatula", 68, "C2-06.png"), ("Armor", "Singed Dancing Shoes", 66, "C3-14.png"), ("Trinket", "Pup Treat Pouch", 66, "C3-16.png")]):
        y = 336 + i * 30
        b.rect(578, y, 340, 26, T["row"], T["rule"], 1)
        b.icon(ic, 592, y + 13, ICON_INLINE); b.text(608, y + 18, it, 12, T["rarity"]["epic"], weight=600)
        b.text(908, y + 18, f"GL {gl}", 12, weight=700, anchor="end")
    b.text(578, 446, "Fire Whelp gear 1 of 2", 12, weight=600); b.icon("C3-03.png", 728, 442, 14)
    b.button(578, 460, 112, 40, "Respec 60 g", size=12.5)
    b.button(698, 460, 132, 40, "Fire gear 120 g", size=12.5)
    b.button(838, 460, 80, 40, "Dismiss", size=12.5)
    b.text(578, 514, "Dismiss gives back 75 gold and ends every friendship.", 11, T["muted"])

# ------------------------------------------------------------------ tavern
def tavern(b):
    T = b.T
    b.chrome("Tavern", nav="Tavern")
    b.hand(24, 124, "The Bench & Barrel", 20)
    b.text(214, 123, "5 recruits this week · new faces at the weekly reset", 12, T["muted"])
    b.button(790, 100, 146, 36, "Reroll 25 g", size=13, icon="C3-05.png")
    recs = [("Grimli", "warrior", "Arms", "Dwarf", "common", 54, ["Pulls on Cooldown"], 50),
            ("Saffi", "priest", "Holy", "Night Elf", "rare", 55, ["Never Stands in Fire", "Alt-Tabbed"], 300),
            ("Mortis", "warlock", "Destruction", "Gnome", "epic", 56, ["Parse Goblin"], 1500),
            ("Fizzwick", "mage", "Fire", "Gnome", "common", 53, ["Partner Aggro"], 50),
            ("Valen", "hunter", "Survival", "Night Elf", "common", 54, ["Pet on Aggressive"], 50)]
    for i, (n, cl, sp, race, rar, gl, tr, price) in enumerate(recs):
        x = 24 + i * 184; y = 144
        b.panel(x, y, 176, 346, corners=False, stroke=T["rarity"][rar] if rar != "common" else None, sw=2 if rar != "common" else 1.2)
        b.rect(x + 8, y + 8, 160, 132, T["barbg"], "none", r=4)
        b.full_body(cl, race, x + 88, y + 12, 124)
        if cl == "warlock": b.tag(x + 168, y + 12, "Rare find", T["accent"], T["badtext"], anchor="end")
        b.hand(x + 10, y + 166, n, 18)
        b.icon(CLASS_ICON[cl], x + 18, y + 182, 14); b.text(x + 30, y + 187, f"{race} {cl.title()}", 12)
        b.text(x + 10, y + 205, sp, 12, T["muted"])
        b.pips(x + 14, y + 222, {"common": 1, "rare": 2, "epic": 3}[rar], 4, T["rarity"][rar])
        b.text(x + 54, y + 226, rar.title(), 12, T["rarity"][rar], weight=700)
        b.text(x + 166, y + 226, f"GL {gl}", 12, weight=600, anchor="end")
        b.text(x + 10, y + 248, "Traits", 11, T["muted"], weight=700)
        for k, t in enumerate(tr):
            b.text(x + 10, y + 266 + k * 18, t, 12, weight=600)
        b.button(x + 8, 442, 160, 40, f"Hire {price:,} g", "normal", 13)
    b.icon("C2-11.png", 34, 506, ICON_INLINE)
    b.text(48, 510, "Roster 13 / 15. Hired raiders start at morale 70 and count as new for 2 weeks (Pug Hero likes that).", 11.5, T["muted"])

# ------------------------------------------------------------------ journal
def journal(b):
    T = b.T
    b.chrome("Journal", nav="Journal")
    b.hand(24, 124, "The Molten Bore", 20)
    bosses = [("Magmadad", "Normal ✓ Heroic ✓", "3/3"), ("Baron Get-Down", "Normal ✓ Heroic ✓", "2/2"), ("Lucifrown", "Normal ✓ Heroic: 2 wipes", "3/3"),
              ("Majordomo Exhaustus", "Normal ✓", "2/2"), ("Ragnaroast", "Normal ✓ Heroic: 4 wipes", "2/3")]
    for i, (n, s, f) in enumerate(bosses):
        y = 136 + i * 76; sel = n == "Ragnaroast"
        b.rect(24, y, 250, 68, T["row"], T["accent"] if sel else T["rule"], 2 if sel else 1)
        if sel: b.boss_scene(32, y + 8, 52, 52, boss_h=50)
        else:
            b.rect(32, y + 8, 52, 52, T["barbg"], T["rule"], 1, r=5)
            b.hand(58, y + 44, n[0], 24, T["muted"], anchor="middle")
        b.text(94, y + 24, n, 13, weight=700)
        b.text(94, y + 41, s, 11.5, T["muted"])
        b.text(94, y + 58, f + " abilities found", 11.5, weight=600)
    b.panel(288, 100, 648, 424)
    b.boss_scene(306, 118, 170, 120, crop=0.05)
    b.hand(492, 146, "Ragnaroast", 24)
    b.text(492, 168, "Boss 5 of 5 · pulled 6 times · best: 31% left", 12, T["muted"])
    b.text(492, 192, "“The trash is still out there. I can hear it.”", 12.5, italic=True)
    b.rect(492, 206, 236, 26, T["row"], T["rule"], 1, r=13)
    b.text(504, 224, "Your raid knows this fight:", 11.5, weight=600); b.bar(668, 215, 50, 8, .4, T["accent"])
    b.hand(306, 266, "Abilities", 17)
    abil = [(True, "Into the lava", "Every 4 rounds he throws the lowest-health melee in. Potions cancel one throw each.", "week 3"),
            (True, "Magma Splash", "Fire on one zone every 2nd round.", "week 3"),
            (False, "Not seen yet", "Pull again: it shows up later in the fight.", "")]
    for i, (seen, n, d, w) in enumerate(abil):
        y = 276 + i * 52
        b.rect(306, y, 612, 46, T["row"] if seen else "none", T["rule"], 1, dash=not seen)
        if seen: b.icon("C2-16.png", 324, y + 23, ICON_INLINE)
        else: b.hand(324, y + 31, "?", 20, T["muted"], anchor="middle")
        b.text(342, y + 19, n, 13, T["ink"] if seen else T["muted"], weight=700)
        b.text(342, y + 37, d, 11.5, T["muted"])
        if w: b.text(908, y + 19, "found " + w, 11, T["muted"], anchor="end")
    b.hand(306, 452, "Worked out", 17)
    b.rect(306, 462, 612, 26, T["row"], T["good"], 1.2)
    b.icon("C2-16.png", 320, 475, 14); b.text(334, 480, "Fire resistance: Fire Whelp gear and potions for melee and tanks.", 12, weight=600)
    b.rect(306, 492, 612, 24, "none", T["rule"], 1, dash=True)
    b.text(320, 508, "Clue: “He sinks at round 10. We need him low before he does.”", 11.5, T["muted"], italic=True)

# ------------------------------------------------------------------ settings
def settings(b):
    T = b.T
    b.chrome("Settings")
    b.panel(24, 70, 200, 454, corners=False)
    for i, t in enumerate(["Display", "Playback", "Accessibility", "Guild data"]):
        b.button(36, 84 + i * 48, 176, 40, t, "selected" if i == 0 else "normal", 13.5)
    b.panel(238, 70, 698, 454)
    def seg(x, y, opts, sel, w):
        for i, o in enumerate(opts): b.button(x + i * (w + 6), y, w, 34, o, "selected" if i == sel else "normal", 12.5)
    def label(y, s, sub=None):
        b.text(262, y, s, 13.5, weight=700)
        if sub: b.text(262, y + 18, sub, 11.5, T["muted"])
    b.hand(262, 104, "Board", 18)
    label(140, "Theme", "Auto follows the time of day")
    seg(440, 120, ["Field Journal", "Midnight", "Auto"], 2 if False else (0 if b.theme == "light" else 1), 136)
    label(196, "Size", "Same as /fpr scale")
    b.rect(440, 186, 300, 4, T["rule"], r=2); b.rect(440, 186, 180, 4, T["accent"], r=2)
    b.add(f'<circle cx="620" cy="188" r="10" fill="{T["row"]}" stroke="{T["accent"]}" stroke-width="2.5"/>')
    b.text(440, 214, "70%", 11, T["muted"]); b.text(740, 214, "120%", 11, T["muted"], anchor="end"); b.text(760, 193, "100%", 14, weight=700)
    label(250, "Position", "Lost it? /fpr reset")
    b.button(440, 232, 150, 36, "Unlock and drag", size=12.5); b.button(598, 232, 140, 36, "Reset to centre", size=12.5)
    b.hand(262, 306, "Playback", 18)
    label(342, "Motion", "Reduced holds the stage still")
    seg(440, 322, ["Full", "Reduced", "Summary only"], 0, 120)
    label(398, "Speed")
    seg(440, 380, ["×1", "×2", "×4"], 1, 64)
    b.hand(262, 452, "Checks", 18)
    label(486, "Self-test", "18 golden fights, here")
    b.button(440, 466, 150, 38, "Run self-test", size=13)
    b.text(602, 486, "Last run: passed, engine 10", 12, T["good"], weight=700)
    b.button(820, 466, 96, 40, "Done", "primary", 19)

SCREENS = {"prep": prep, "playback": playback, "results": results, "loot": loot, "roster": roster, "tavern": tavern, "journal": journal, "settings": settings}
TITLES = {"prep": "prep", "playback": "playback", "results": "results, wipe", "loot": "results, loot window", "roster": "roster", "tavern": "tavern", "journal": "journal", "settings": "settings"}

def png(paths):
    from playwright.sync_api import sync_playwright
    with sync_playwright() as p:
        br = p.chromium.launch(); pg = br.new_page(viewport={"width": 1920, "height": 1080})
        for path in paths:
            pg.goto("file://" + path); pg.wait_for_timeout(250); pg.screenshot(path=path.replace(".svg", ".png"))
        br.close()

if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    built = []
    for name in (args or SCREENS):
        for theme in THEMES:
            for nt in (False, True):
                b = Board(theme, notext=nt); SCREENS[name](b); path = b.save(name, TITLES[name])
                if not nt: built.append(path); print(os.path.relpath(path, ROOT), os.path.getsize(path) // 1024, "KB")
    if "--png" in sys.argv: png(built)
