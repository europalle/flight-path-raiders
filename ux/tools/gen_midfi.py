import os, html, json
OUT = "/home/claude/flight-path-raiders/ux/wireframes/mid-fi"
os.makedirs(OUT, exist_ok=True)
INK="#222a33"; MUTED="#5d6773"; LINE="#9aa3ad"; FILL="#eef1f4"; FILL2="#dde2e7"; PAPER="#ffffff"
NOTE="#2f6fd6"; ACC="#3a4654"; STAGE="#e6e9ed"
FONT="Inter, Arial, Helvetica, sans-serif"

class S:
    def __init__(s,w,h,title): s.w,s.h,s.title=w,h,title; s.p=[]
    def rect(s,x,y,w,h,fill=PAPER,stroke=LINE,r=4,dash=False,sw=1):
        d=' stroke-dasharray="5 4"' if dash else ''
        s.p.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"{d}/>')
    def line(s,x1,y1,x2,y2,stroke=LINE,sw=1,dash=False):
        d=' stroke-dasharray="5 4"' if dash else ''
        s.p.append(f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{stroke}" stroke-width="{sw}"{d}/>')
    def text(s,x,y,t,size=13,weight=400,fill=INK,anchor="start",italic=False):
        it=' font-style="italic"' if italic else ''
        s.p.append(f'<text x="{x}" y="{y}" font-family="{FONT}" font-size="{size}" font-weight="{weight}" fill="{fill}" text-anchor="{anchor}"{it}>{html.escape(t)}</text>')
    def img(s,x,y,w,h,label=None):
        s.rect(x,y,w,h,fill=FILL2,stroke=LINE,r=4)
        s.line(x,y,x+w,y+h); s.line(x+w,y,x,y+h)
        if label: s.text(x+w/2,y+h+14,label,11,500,MUTED,"middle")
    def btn(s,x,y,w,h,label,primary=False,size=13):
        s.rect(x,y,w,h,fill=INK if primary else PAPER,stroke=INK,r=5,sw=1.5)
        s.text(x+w/2,y+h/2+size*0.36,label,size,600,PAPER if primary else INK,"middle")
    def bar(s,x,y,w,h,frac,fill=ACC):
        s.rect(x,y,w,h,fill=PAPER,stroke=LINE,r=2)
        if frac>0: s.rect(x,y,w*frac,h,fill=fill,stroke="none",r=2)
    def pips(s,x,y,n,total=5):
        for i in range(total):
            s.p.append(f'<circle cx="{x+i*9}" cy="{y}" r="3.2" fill="{INK if i<n else PAPER}" stroke="{INK}" stroke-width="1"/>')
    def note(s,n,x,y):
        s.p.append(f'<circle cx="{x}" cy="{y}" r="11" fill="{NOTE}"/>')
        s.text(x,y+4.5,str(n),12,700,PAPER,"middle")
    def frame(s,crumb):
        s.rect(0.75,0.75,s.w-1.5,s.h-1.5,fill=PAPER,stroke=INK,r=8,sw=1.5)
        s.p.append(f'<path d="M0.75 40 V8.75 a8 8 0 0 1 8 -8 H{s.w-8.75} a8 8 0 0 1 8 8 V40 Z" fill="{FILL}" stroke="{INK}" stroke-width="1.5"/>')
        s.text(16,26,"Flight Path Raiders",15,700); s.text(178,26,"/  "+crumb,15,400,MUTED)
        # title-bar controls: scale, settings, close
        for i,(lab) in enumerate(["-","+","gear","x"]):
            x=s.w-132+i*30
            s.rect(x,9,24,22,fill=PAPER,stroke=INK,r=4)
            s.text(x+12,25,{"gear":"⚙","x":"✕"}.get(lab,lab),13,600,INK,"middle")
        s.text(s.w-142,26,"100%",11,500,MUTED,"end")
    def svg(s):
        return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {s.w} {s.h}" width="{s.w}" height="{s.h}" role="img" aria-label="{html.escape(s.title)}">\n'
                f'<title>{html.escape(s.title)}</title>\n<rect width="{s.w}" height="{s.h}" fill="{PAPER}"/>\n'+"\n".join(s.p)+"\n</svg>\n")

W,H=960,540
frames=[]

# ---------- Toast ----------
t=S(480,112,"Takeoff toast")
t.rect(0.75,0.75,478.5,110.5,fill=PAPER,stroke=INK,r=10,sw=1.5)
t.img(14,16,52,52)
t.text(80,36,"Ragnaroast is up (Heroic)",16,700)
t.text(80,56,"3 quests open  ·  Frequent Flyer +25% while you fly",12,400,MUTED)
t.btn(80,70,120,30,"Open board",True); t.btn(210,70,80,30,"Later")
t.text(466,100,"hides in 8 s",11,400,MUTED,"end")
t.note(1,462,18)
frames.append(("toast",t,["Same two actions as low-fi, now at real text sizes (16 title, 12 body). Opens nothing by itself; /fpr and the minimap button also work."]))

# ---------- Hub ----------
h=S(W,H,"Hub")
h.frame("Hub")
h.text(20,68,"LFR",14,700); h.text(60,68,"·  Gold 2,340  ·  DKP 86  ·  Raider rank 12th in guild",13,400,MUTED)
h.rect(560,50,384,28,fill=FILL,stroke=LINE,r=14)
h.text(576,69,"This week:",12,700); h.text(652,69,"◆ Fortified Trash   +   ▲ Floor Is Lava",12,500)
h.note(1,944,48)
h.rect(20,90,920,96,fill=FILL,stroke=INK,r=8,sw=1.5)
h.img(32,102,72,72)
h.text(122,124,"Continue: Ragnaroast, The Molten Bore",18,700)
h.text(122,146,"Heroic  ·  Boss 5 of 5  ·  8 ready, 2 benched until reset",13,400,MUTED)
h.text(122,168,"Last pull: wipe in round 18. Tip from the officers: fewer melee.",13,400,INK,italic=True)
h.btn(780,116,144,44,"Prep pull",True,15)
h.note(2,930,94)
cols=[("Raids",[("The Molten Bore","N 5/5   H 4/5   M 0/5"),("Onyxiety's Lair","N 1/1   H 0/1   M locked"),("Attunement: Blackwing Lair","2 of 3 steps")]),
      ("Dungeons & keystone",[("Quick dungeon","fits one flight (~3 min)"),("Your key: Gnomeregret +7","Season best +9  ·  2nd in guild"),("Weekly chest","1 of 1 ready")]),
      ("Daily quests",[("☐  Clear any dungeon","12 gold  ·  2 DKP"),("☑  Kill a raid boss","done"),("☐  Survive a Loot Council","12 gold  ·  2 DKP")])]
x=20
for title,items in cols:
    h.text(x,214,title,15,700)
    y=226
    for a,b in items:
        h.rect(x,y,296,56,fill=PAPER,stroke=LINE,r=6)
        h.text(x+14,y+24,a,13,600); h.text(x+14,y+44,b,12,400,MUTED)
        y+=64
    x+=312
h.note(3,96,208)
h.rect(20,428,920,92,fill=PAPER,stroke=LINE,r=8)
h.text(36,452,"Roster 15 / 15",14,700); h.text(152,452,"10 ready  ·  3 bench  ·  2 benched until reset",12,400,MUTED)
for i in range(10):
    h.img(36+i*50,464,40,40)
h.rect(560,462,230,42,fill=FILL,stroke=INK,r=6)
h.text(574,480,"⚠ 2 characters low morale",12,700); h.text(574,497,"Rook 22, Fen 35: quit risk",12,400,MUTED)
h.btn(806,462,118,42,"Roster")
h.note(4,792,458)
frames.append(("hub",h,[
 "Affixes keep a shape icon plus the name, so they read in any colour mode.",
 "Primary action now carries context: last pull result and one officer tip, so a returning player knows what to change.",
 "Three columns of 296 units each; text is 13 / 12, the floor for body text at the smallest scale.",
 "Problems (low morale, quit risk) say who and why, not just a count."]))

# ---------- Prep ----------
p=S(W,H,"Prep")
p.frame("Prep  ·  Ragnaroast (Heroic)")
p.rect(20,52,920,52,fill=FILL,stroke=LINE,r=8)
p.img(30,58,40,40)
p.text(82,74,"Throws the lowest-health melee into lava every 4 rounds. Adds join from round 10.",14,600)
p.text(82,93,"Tests: melee count, fire resistance.   Affix: Floor Is Lava (everyone takes 2% per round standing still).",12,400,MUTED)
p.rect(774,64,154,28,fill=PAPER,stroke=INK,r=14,sw=1.5); p.text(851,83,"⚠ 4 melee: risky",12,700,INK,"middle")
p.note(1,936,56)
zones=[("Front",["Brannoc|Warrior · tank|64|45|72|4","Mira|Paladin · tank|63|43|80|3"]),
       ("Melee",["Kess|Rogue|66|101|55|4","Tor|Warrior|62|97|61|3","Ash|Shaman|61|94|70|3","Vey|Druid|60|92|74|2"]),
       ("Ranged",["Lumi|Mage|65|103|68|4","Orrin|Hunter|62|99|66|3"]),
       ("Back",["Sela|Priest|63|120|71|4","Bram|Druid|61|116|77|3"])]
def card(s,x,y,n,cl,gl,pw,mo,q,w=156,h=58):
    s.rect(x,y,w,h,fill=PAPER,stroke=LINE,r=6)
    s.img(x+6,y+6,34,34)
    s.text(x+48,y+20,n,13,700); s.text(x+48,y+36,cl,11,400,MUTED)
    s.pips(x+w-44,y+14,int(q))
    s.text(x+8,y+52,f"GL {gl}   Pow {pw}   Mor {mo}",11,600)
y=116
for zname,chars in zones:
    p.text(20,y+34,zname,13,700)
    x=84
    for c in chars:
        card(p,x,y,*c.split("|")); x+=164
    y+=66
p.note(2,82,112)
p.rect(752,116,188,256,fill=PAPER,stroke=LINE,r=8,dash=True)
p.text(766,138,"Bench (3)",13,700)
for i,nm in enumerate(["Dax  ·  Hunter","Ilo  ·  Priest","Fen  ·  Rogue"]):
    p.rect(764,148+i*38,164,32,fill=FILL,stroke=LINE,r=5); p.text(776,169+i*38,nm,12,500)
p.text(766,282,"Benched until reset",13,700)
p.rect(764,292,164,32,fill=PAPER,stroke=LINE,r=5,dash=True); p.text(776,313,"Rook  ·  Mage  (died)",12,500,MUTED)
p.text(766,352,"Drag or click to swap",11,400,MUTED)
p.note(3,940,120)
p.text(20,404,"Tactic",13,700)
for i,(nm,ef) in enumerate([("Spread","Lava hits 1, not the zone"),("Stack","Healing +15%"),("Burn","Damage +15%, risky"),("Play Safe","Damage taken -10%")]):
    sel=(i==0)
    p.rect(84+i*166,384,158,48,fill=INK if sel else PAPER,stroke=INK,r=6,sw=1.5)
    p.text(163+i*166,404,("✓ " if sel else "")+nm,13,700,PAPER if sel else INK,"middle")
    p.text(163+i*166,422,ef,11,400,PAPER if sel else MUTED,"middle")
p.note(4,752,388)
p.text(20,462,"Cauldrons",13,700)
for i,nm in enumerate(["☑ Food (Lumi)  free","☑ Elixirs  12 g","☐ Flasks  30 g","☐ Fire Res ×4  24 g"]):
    p.text(104+i*166,462,nm,12,500)
p.btn(20,484,190,40,"Same as last pull")
p.text(222,509,"This pull costs 12 gold",12,500,MUTED)
p.btn(760,478,180,50,"Pull",True,17)
p.note(5,756,476)
frames.append(("prep",p,[
 "Boss brief now names what the fight tests and how this week's affix touches it.",
 "Cards are 156 x 58 with quality pips; four zones in fight order, never more than four cards per row.",
 "Bench column is fixed width so drag targets stay big at 70% scale.",
 "Selected tactic gets a tick as well as the dark fill, so it reads without colour.",
 "Pull is the largest target (180 x 50). Prices match the tuned economy."]))

# ---------- Playback ----------
b=S(W,H,"Combat playback")
b.frame("Pull  ·  Ragnaroast (Heroic)")
# stage
b.rect(20,52,620,330,fill=STAGE,stroke=INK,r=8,sw=1.5)
b.text(34,74,"STAGE  ·  animated scene (Art)",12,700,MUTED)
b.line(20,320,640,320,LINE,1,True); b.text(300,314,"floor line",11,400,MUTED)
# boss right
b.rect(452,96,168,216,fill=FILL2,stroke=LINE,r=8)
b.line(452,96,620,312); b.line(620,96,452,312)
b.text(536,330+18,"Ragnaroast",12,700,INK,"middle")
b.rect(420,140,22,22,fill=PAPER,stroke=INK,r=11); b.text(431,156,"!",13,700,INK,"middle")
b.text(410,132,"winding up",11,600,INK,"end")
# raid formation left
pos=[(150,220),(150,268),(230,200),(230,248),(230,296),(260,150),(90,170),(90,250),(40,210),(40,290)]
for i,(x,y) in enumerate(pos):
    b.rect(x,y,34,44,fill=PAPER,stroke=LINE,r=5)
    if i==3: b.text(x+17,y+27,"✕",14,700,INK,"middle")
b.text(34,372,"10 characters in zones: tanks front, healers back",11,400,MUTED)
b.rect(306,118,110,30,fill=PAPER,stroke=INK,r=5); b.text(361,138,"Tor: \"bye o/\"",12,600,INK,"middle")
b.note(1,636,56)
# side column
b.text(656,78,"Round",13,600,MUTED); b.text(656,112,"7",36,800); b.text(690,112,"/ 20",16,500,MUTED)
b.text(920,78,"Score pace",12,500,MUTED,"end"); b.text(920,100,"+30 if kill by 14",12,700,INK,"end")
b.text(656,138,"Ragnaroast",13,700); b.text(940,138,"58%",13,700,INK,"end")
b.bar(656,146,284,16,0.58,INK)
b.note(2,944,62)
b.rect(656,176,284,206,fill=FILL,stroke=LINE,r=8)
b.text(670,198,"What happened",13,700)
log=[("R4","Tor into the lava. No Fire Res potion."),("R5","Brannoc pulled the next pack."),("","Healers were still drinking."),("R6","Sela heals Mira for 120."),("R7","Spread holds: lava hits only Kess.")]
for i,(r_,l) in enumerate(log):
    b.text(670,224+i*30,r_,12,700,MUTED); b.text(700,224+i*30,l,12,500 if i<4 else 700)
b.note(3,944,180)
# raid frames strip
for i,nm in enumerate(["Brannoc","Mira","Kess","Tor","Ash","Vey","Lumi","Orrin","Sela","Bram"]):
    x=20+i*92; y=394
    b.rect(x,y,86,48,fill=PAPER,stroke=LINE,r=5)
    b.text(x+8,y+17,nm,12,600)
    hp=[0.9,0.7,0.4,0,0.8,0.6,0.9,0.75,1,0.85][i]
    if i==3: b.text(x+78,y+17,"DEAD",11,800,INK,"end")
    b.bar(x+8,y+24,70,9,hp,INK)
    if i>=8: b.bar(x+8,y+37,70,5,[0.55,0.62][i-8],MUTED)
b.note(4,20,392)
b.btn(20,462,104,36,"❚❚ Pause"); b.btn(134,462,104,36,"Speed ×2"); b.btn(248,462,150,36,"Skip to result",True)
b.btn(408,462,140,36,"Summary only")
b.text(20,524,"Result is decided at Pull. Skipping loses nothing.",12,400,MUTED)
b.text(940,488,"Motion: Full  (change in ⚙)",12,500,MUTED,"end")
b.note(5,554,466)
frames.append(("playback",b,[
 "The wide board buys a 620 x 330 stage: raid formation left, boss right, floor line for Art to animate on. Boss wind-ups get a '!' marker plus a text label, not just an animation.",
 "Side column keeps the round counter as the biggest number, with the Efficient Kill target beside it.",
 "Log stays in plain sentences, five lines visible, newest in bold.",
 "Raid frames move to a bottom strip of 10, so names never truncate. Death is written as DEAD; healers show mana.",
 "Motion setting is visible here and lives in Settings. Reduced motion keeps the stage still and only updates bars."]))

# ---------- Results ----------
r=S(W,H,"Results")
r.frame("Result")
r.rect(20,52,920,72,fill=INK,stroke=INK,r=8)
r.text(40,84,"KILL  ·  Ragnaroast (Heroic)",22,800,PAPER)
r.text(40,108,"Round 14  ·  Efficient Kill +30  ·  Score +1,030  ·  Guild rank 3rd → 2nd",14,500,PAPER)
r.note(1,934,58)
r.text(20,154,"Loot",15,700)
items=[("Roasting Spit of the Tryhard","Epic · Weapon · Agility",4,"Kess (+6 GL)"),
       ("Molten Bulwark Pauldrons","Rare · Plate · Warrior set 1/3",3,"Brannoc (+4 GL)"),
       ("Robe of Questionable Pulls","Rare · Cloth · nobody can use",3,"Sell  (9 g)")]
for i,(nm,meta,q,who) in enumerate(items):
    y=166+i*62
    r.rect(20,y,520,54,fill=PAPER,stroke=LINE,r=6)
    r.img(30,y+8,38,38); r.text(80,y+23,nm,13,700); r.text(80,y+42,meta,11,400,MUTED); r.pips(260,y+38,q)
    r.rect(356,y+12,172,30,fill=FILL,stroke=INK,r=5); r.text(368,y+32,who,12,600); r.text(518,y+32,"▾",12,600,INK,"end")
r.note(2,536,160)
r.text(560,154,"Raid changes",15,700)
r.rect(560,166,380,178,fill=PAPER,stroke=LINE,r=6)
for i,(l,st) in enumerate([("+5 morale for everyone present",600),("Tor: benched until reset (died to lava)",600),("“We need to talk about the fire.” - RL",400),("Kess: +10 morale (loot)",600),("Rook: morale 22, may quit after next wipe",700)]):
    r.text(576,192+i*30,l,13,st,INK if st!=400 else MUTED,italic=(st==400))
r.note(3,934,160)
r.rect(20,360,920,100,fill=FILL,stroke=INK,r=8,sw=1.5)
r.text(40,386,"Loot Council Drama",15,700)
r.text(40,408,"Kess and Orrin both want Roasting Spit of the Tryhard.",13,500)
r.btn(40,420,250,32,"Give it to Kess  (Orrin -15)"); r.btn(302,420,230,32,"Roll for it  (both -5)")
r.text(920,442,"This choice waits if you land.",12,400,MUTED,"end")
r.note(4,934,366)
r.btn(640,478,140,44,"Back to hub",False,14); r.btn(792,478,148,44,"Next boss",True,15)
frames.append(("results",r,[
 "Outcome banner adds the guild rank change, since that is what people talk about in guild chat.",
 "Loot now shows armor type and set piece. Unusable drops pre-fill 'Sell' with the price; every row is a dropdown.",
 "Raid changes include the quit warning, so it never comes as a surprise.",
 "Drama card unchanged in logic: two choices, costs written on the buttons."]))

# ---------- Settings ----------
st=S(W,H,"Settings")
st.frame("Settings")
tabs=["Display","Playback","Accessibility","Notifications","Data"]
for i,tb in enumerate(tabs):
    sel=(i<3 and False)
st.rect(20,52,180,468,fill=FILL,stroke=LINE,r=8)
for i,tb in enumerate(tabs):
    y=64+i*44; sel=(i==0)
    st.rect(30,y,160,36,fill=INK if sel else PAPER,stroke=INK if sel else LINE,r=5)
    st.text(44,y+23,tb,13,700 if sel else 500,PAPER if sel else INK)
st.note(1,200,56)
def section(y,title): st.text(224,y,title,15,700); st.line(224,y+8,940,y+8,FILL2)
def slider(x,y,w,frac,lo,hi,val):
    st.line(x,y,x+w,y,INK,3); st.p.append(f'<circle cx="{x+w*frac}" cy="{y}" r="9" fill="{PAPER}" stroke="{INK}" stroke-width="2"/>')
    st.text(x,y+24,lo,11,400,MUTED); st.text(x+w,y+24,hi,11,400,MUTED,"end"); st.text(x+w+20,y+5,val,13,700)
def toggle(x,y,on):
    st.rect(x,y,44,24,fill=INK if on else PAPER,stroke=INK,r=12)
    st.p.append(f'<circle cx="{x+(32 if on else 12)}" cy="{y+12}" r="8" fill="{PAPER if on else INK}"/>')
    st.text(x+54,y+17,"On" if on else "Off",12,600)
def seg(x,y,opts,sel,w=110):
    for i,o in enumerate(opts):
        st.rect(x+i*w,y,w,32,fill=INK if i==sel else PAPER,stroke=INK,r=5)
        st.text(x+i*w+w/2,y+21,o,12,600,PAPER if i==sel else INK,"middle")
# Display
section(72,"Board size and position")
st.text(224,108,"Scale",13,600); slider(380,104,300,0.6,"70%","120%","100%"); st.text(740,128,"about 70% of screen width",11,400,MUTED)
st.note(2,930,96)
st.text(224,156,"Position",13,600); st.btn(380,138,150,32,"Unlock and drag"); st.btn(540,138,130,32,"Reset to centre")
st.text(224,196,"Saved per character. /fpr reset puts it back if it ever goes off-screen.",12,400,MUTED)
section(236,"Playback  (preview of the Playback tab)")
st.text(224,274,"Motion",13,600); seg(380,254,["Full","Reduced","Summary only"],0,130)
st.note(3,940,262)
st.text(224,318,"Default speed",13,600); seg(380,298,["×1","×2","×4"],0,70)
st.text(224,354,"Auto-skip on landing",13,600); toggle(380,338,False)
section(394,"Accessibility  (preview)")
st.text(224,430,"Colour palette",13,600); seg(380,410,["Standard","Deuteranopia","Protanopia","Tritanopia"],0,130)
st.text(224,474,"Text size",13,600); seg(380,454,["Normal","Large +15%"],0,130)
st.note(4,940,418)
st.btn(800,484,140,36,"Done",True,14)
frames.append(("settings",st,[
 "Five tabs on the left; the mock shows Display with previews of Playback and Accessibility so you can judge the full set in one view.",
 "Scale slider 70 to 120%. Default is about 70% of screen width at 16:9, matching the world map size you approved. Position unlocks for dragging and is saved per character; /fpr reset is the escape hatch.",
 "Motion: Full (default), Reduced (stage holds still, bars and log update) or Summary only (straight to results).",
 "Colour-blind palettes and a text size bump. Every state is already shape plus text, so palettes are a comfort, not a crutch."]))

# ---------- Landing ----------
l=S(480,240,"Landing popup")
l.rect(0.75,0.75,478.5,238.5,fill=PAPER,stroke=INK,r=10,sw=1.5)
l.text(24,42,"You landed in Booty Bay",18,700)
l.text(24,66,"You're mid-prep on Ragnaroast (Heroic). Nothing is lost either way.",12,400,MUTED)
l.btn(24,88,200,46,"Finish now",True,14); l.btn(236,88,220,46,"Pause until next flight",False,14)
l.text(24,166,"Pausing automatically in 10 s",13,600)
l.bar(24,176,432,10,0.6,INK)
l.text(24,214,"Finished pulls are always saved. Ground play earns no Frequent Flyer bonus.",11,400,MUTED)
l.note(1,462,110)
frames.append(("landing",l,["Same logic as low-fi at real sizes. Countdown defaults to Pause, so an alt-tabbed player never returns to a frozen screen."]))

for slug,s,notes in frames:
    open(f"{OUT}/{slug}.svg","w").write(s.svg())
json.dump([(slug,s.title,s.w,s.h,notes) for slug,s,notes in frames],open(os.path.dirname(__file__)+"/notes_mid.json","w"))
print(sorted(os.listdir(OUT)))
