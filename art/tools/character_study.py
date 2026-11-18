"""Art: ink-and-wash character study. Sets the quality bar before style tiles."""
import html, os, random
random.seed(11)
OUT="/home/claude/flight-path-raiders/art/sketches/character-study-v1.svg"
W,H=1240,736
INK="#2a2119"; PAPER="#f3ecdc"; BLUE="#2f5fb8"
P=[]; HATCH=[]
def shape(d,fill,ink=2.2,op=0.9,hatch=False,inkcol=INK):
    if fill:
        P.append(f'<path d="{d}" fill="{fill}" opacity="{op}" filter="url(#wash)" transform="translate(2 1.5)"/>')
    if hatch: HATCH.append(d)
    if ink:
        P.append(f'<path d="{d}" fill="none" stroke="{inkcol}" stroke-width="{ink}" stroke-linejoin="round" stroke-linecap="round" filter="url(#ink)"/>')
        P.append(f'<path d="{d}" fill="none" stroke="{inkcol}" stroke-width="{ink*0.45}" opacity="0.35" transform="translate(0.8 -0.6)" filter="url(#ink)"/>')
def stroke(d,w=1.6,col=INK,op=1):
    P.append(f'<path d="{d}" fill="none" stroke="{col}" stroke-width="{w}" stroke-linecap="round" stroke-linejoin="round" opacity="{op}" filter="url(#ink)"/>')
def text(x,y,t,size=16,col=BLUE,anchor="start",weight=400,font="Patrick Hand, Comic Sans MS, cursive"):
    P.append(f'<text x="{x}" y="{y}" font-family="{font}" font-size="{size}" font-weight="{weight}" fill="{col}" text-anchor="{anchor}">{html.escape(t)}</text>')
def flush_hatch(clip_id):
    if HATCH:
        P.append(f'<g clip-path="url(#{clip_id})" opacity="0.55">'+"".join(f'<path d="{d}" fill="url(#hatch)"/>' for d in HATCH)+'</g>')
        HATCH.clear()

defs=f'''<defs>
<filter id="ink" x="-5%" y="-5%" width="110%" height="110%"><feTurbulence type="fractalNoise" baseFrequency="0.04" numOctaves="2" seed="4"/><feDisplacementMap in="SourceGraphic" scale="1.8"/></filter>
<filter id="wash" x="-10%" y="-10%" width="120%" height="120%"><feTurbulence type="fractalNoise" baseFrequency="0.018" numOctaves="3" seed="8" result="n"/><feDisplacementMap in="SourceGraphic" in2="n" scale="7" result="d"/><feGaussianBlur in="d" stdDeviation="0.8"/></filter>
<filter id="grain"><feTurbulence type="fractalNoise" baseFrequency="0.85" numOctaves="2" seed="2"/><feColorMatrix values="0 0 0 0 0.35  0 0 0 0 0.3  0 0 0 0 0.22  0 0 0 0.10 0"/></filter>
<filter id="glow"><feGaussianBlur stdDeviation="6"/></filter>
<pattern id="hatch" width="5" height="5" patternUnits="userSpaceOnUse" patternTransform="rotate(38)"><line x1="0" y1="0" x2="0" y2="5" stroke="{INK}" stroke-width="0.9"/></pattern>
<clipPath id="leftWar"><rect x="100" y="230" width="112" height="420"/></clipPath>
<clipPath id="leftMage"><rect x="470" y="230" width="84" height="420"/></clipPath>
<clipPath id="leftBoss"><rect x="830" y="150" width="120" height="520"/></clipPath>
<radialGradient id="lavaGlow" cx="0.5" cy="0.9" r="0.7"><stop offset="0" stop-color="#ff8a2a" stop-opacity="0.55"/><stop offset="1" stop-color="#ff8a2a" stop-opacity="0"/></radialGradient>
</defs>'''

# paper
P.append(f'<rect width="{W}" height="{H}" fill="{PAPER}"/>')
for y in range(40,H,28): P.append(f'<line x1="0" y1="{y}" x2="{W}" y2="{y}" stroke="#a9bcd6" stroke-width="0.6" opacity="0.45"/>')
P.append(f'<line x1="70" y1="0" x2="70" y2="{H}" stroke="#d69a9a" stroke-width="1" opacity="0.6"/>')
P.append(f'<rect width="{W}" height="{H}" filter="url(#grain)"/>')
# coffee ring, top right empty space
P.append(f'<circle cx="1150" cy="86" r="46" fill="none" stroke="#a87a4a" stroke-width="5" opacity="0.18" filter="url(#wash)"/>')
text(90,58,"Character study  ·  style bar for hi-fi",26,INK,weight=700)
text(90,86,"ink line + loose watercolour wash + crosshatch on the shadow side. Light comes from the lava (right).",15)

# ground wash
P.append(f'<path d="M80 650 Q400 636 760 648 T1220 646 L1220 668 Q700 676 80 668 Z" fill="#b9a98c" opacity="0.45" filter="url(#wash)"/>')
stroke("M80 650 Q400 638 760 648 T1220 646",2.4)
for i in range(40):
    x=90+i*28+random.uniform(-4,4); stroke(f"M{x} {652+random.uniform(0,4)} l-10 12",0.8,INK,0.5)

# ================= Warrior (Protection) =================
CAPE="#7d2f26"; STEEL="#8e9aa8"; STEEL_D="#6c7886"; RED="#9c3b2e"; GOLD="#c79a3b"; LEATHER="#6b4a2f"
shape("M172 352 Q118 440 126 640 L176 628 Q164 500 196 364 Z",CAPE,hatch=True)                       # cape
shape("M178 468 L198 470 L196 548 L192 622 L200 642 L148 642 L156 624 L166 548 Z",STEEL_D,hatch=True)   # back leg
shape("M206 468 L230 468 L240 548 L242 620 L268 642 L214 642 L220 622 L214 548 Z",STEEL)               # front leg
shape("M168 538 Q180 528 194 538 Q182 556 168 538 Z",GOLD,1.6)
shape("M216 538 Q230 526 244 538 Q230 558 216 538 Z",GOLD,1.6)
shape("M166 452 L242 452 L256 524 L224 514 L204 530 L184 514 L152 524 Z",RED,hatch=True)              # tabard skirt
shape("M164 358 Q158 420 170 456 L238 456 Q250 420 246 358 Q206 340 164 358 Z",STEEL,hatch=True)       # breastplate
stroke("M206 352 L206 452",1.2); stroke("M176 400 Q206 412 238 400",1.2); stroke("M172 428 Q206 438 240 428",1.0)
shape("M166 446 L244 446 L244 462 L166 462 Z",LEATHER,1.8); shape("M198 444 L214 444 L214 464 L198 464 Z",GOLD,1.6)
# tabard front panel with emblem
shape("M188 362 L224 362 L222 446 L190 446 Z",RED,1.6)
stroke("M206 380 L206 420 M194 398 L218 398",2.2,GOLD)
# sword arm (back) & sword
shape("M150 372 L130 424 L148 432 L170 384 Z",STEEL_D,hatch=True)
shape("M127 420 Q124 440 140 444 Q154 440 152 424 Z",LEATHER,1.8)
shape("M132 446 L146 448 L116 566 L106 560 Z","#c9d1d9",1.8)
stroke("M118 438 L162 448",3.2); P.append(f'<circle cx="150" cy="430" r="4" fill="{GOLD}" stroke="{INK}" stroke-width="1.5"/>')
# pauldrons
shape("M138 374 Q134 326 176 322 Q204 328 198 364 Q170 382 138 374 Z",STEEL,hatch=True)
stroke("M146 364 Q168 352 194 356",1.2); stroke("M150 348 Q170 336 192 340",1.0)
shape("M152 330 L146 304 L162 326 Z",STEEL_D,1.4); shape("M172 324 L172 296 L182 324 Z",STEEL_D,1.4)
# helmet
shape("M180 334 Q174 282 206 274 Q238 280 234 334 Q206 346 180 334 Z",STEEL)
shape("M186 302 L230 300 L230 312 L186 314 Z","#3b4049",1.4)
stroke("M208 276 L208 334",1.2)
shape("M206 276 Q214 244 246 236 Q226 258 224 282 Z",RED,1.8)
# shield (front) over the front arm
shape("M246 380 Q300 368 324 390 Q324 474 282 548 Q244 474 244 402 Z",STEEL)
shape("M256 390 Q298 380 314 398 Q312 466 282 528 Q254 466 254 404 Z",RED,1.4)
stroke("M284 410 L284 486 M262 438 L306 438",3,GOLD)
shape("M212 360 Q208 318 250 316 Q284 322 282 366 Q248 382 212 360 Z",STEEL)
stroke("M220 352 Q248 340 276 346",1.2); shape("M262 318 L276 290 L274 322 Z",STEEL_D,1.4)
flush_hatch("leftWar")
text(206,690,"Brannoc  ·  Protection Warrior",17,INK,"middle",700)
text(206,710,"big pauldron + kite shield = readable at 34 units",13,BLUE,"middle")

# ================= Mage (Frost) =================
ROBE="#2f4f7a"; ROBE_L="#45699a"; TRIM="#b8c4cf"; FROST="#9fd3e8"
shape("M534 360 Q506 470 488 642 L640 642 Q622 470 594 360 Q562 346 534 360 Z",ROBE,hatch=True)
shape("M556 400 L572 400 L586 642 L548 642 Z",ROBE_L,1.4)
stroke("M490 630 Q562 618 638 630",2.6,TRIM)
shape("M542 446 L590 446 L592 458 L540 458 Z","#6a4a8a",1.6)
shape("M574 456 L590 456 L594 494 L578 494 Z","#5c3b2a",1.4)   # book on the sash
# arms
shape("M592 382 Q626 398 640 432 L622 444 Q600 424 588 404 Z",ROBE,hatch=False)
P.append(f'<circle cx="636" cy="440" r="7" fill="#e3c9a8" stroke="{INK}" stroke-width="1.6"/>')
shape("M536 384 Q512 416 504 462 L520 470 Q530 430 548 402 Z",ROBE,hatch=True)
P.append(f'<circle cx="510" cy="472" r="7" fill="#e3c9a8" stroke="{INK}" stroke-width="1.6"/>')
# frost swirl from off-hand
for r,o in ((16,0.9),(26,0.6),(36,0.35)):
    stroke(f"M{510-r} 476 a{r} {r*0.6} 0 1 1 {r*0.4} {r*0.5}",1.4,"#4f9fc4",o)
for i in range(7):
    x=470+random.uniform(0,60); y=440+random.uniform(0,70); stroke(f"M{x} {y} l4 -6 l4 6 l-4 6 Z",1,"#4f9fc4",0.8)
# mantle
shape("M522 372 Q530 340 564 336 Q600 340 610 372 Q566 392 522 372 Z",ROBE_L,hatch=True)
stroke("M528 372 Q566 386 606 372",2.2,TRIM)
# hood + shadowed face + glowing eyes
shape("M536 344 Q526 288 566 268 Q606 288 596 344 Q566 356 536 344 Z",ROBE)
shape("M548 334 Q552 302 566 296 Q580 302 584 334 Q566 340 548 334 Z","#1b2433",1.2)
P.append(f'<circle cx="560" cy="314" r="6" fill="{FROST}" filter="url(#glow)" opacity="0.9"/><circle cx="574" cy="314" r="6" fill="{FROST}" filter="url(#glow)" opacity="0.9"/>')
P.append(f'<circle cx="560" cy="314" r="2" fill="#e8f7ff"/><circle cx="574" cy="314" r="2" fill="#e8f7ff"/>')
stroke("M566 268 Q584 254 606 262",1.6)
# staff + crystal
stroke("M640 642 L646 290",4.2,"#5c3b2a"); stroke("M640 642 L646 290",1.2,INK)
P.append(f'<circle cx="648" cy="262" r="26" fill="{FROST}" filter="url(#glow)" opacity="0.7"/>')
shape("M648 228 L666 262 L648 300 L630 262 Z",FROST,2)
stroke("M648 228 L648 300 M630 262 L666 262",0.9,"#4f9fc4")
for a,b,c,d in ((618,240,626,232),(676,248,684,240),(674,290,682,298)):
    shape(f"M{a} {b} L{c} {d} L{c+4} {d+8} Z",FROST,1.2)
flush_hatch("leftMage")
text(566,690,"Lumi  ·  Frost Mage",17,INK,"middle",700)
text(566,710,"glow is the only light on her face",13,BLUE,"middle")

# ================= Ragnaroast =================
ROCK="#4a3a34"; ROCK_L="#6b5246"; LAVA="#ff8a2a"; LAVA_D="#d9541e"; IRON="#3a3d42"
P.append(f'<ellipse cx="1000" cy="560" rx="240" ry="160" fill="url(#lavaGlow)"/>')
# body rising from pot
shape("M872 600 Q858 500 888 432 Q912 378 970 362 Q1044 352 1084 404 Q1120 462 1112 600 Z",ROCK,hatch=True)
for d in ("M900 470 L926 500 L918 540 L940 572","M1010 420 L1030 452 L1022 486","M1072 470 L1060 510 L1080 548 L1074 584","M960 500 L984 520 L1000 560"):
    stroke(d,3.2,LAVA_D,0.9); stroke(d,1.4,"#ffd27a",0.9)
# arm with the roasting spit, raised (wind-up)
shape("M1076 410 Q1128 380 1146 318 L1172 326 Q1158 400 1100 446 Z",ROCK_L,1.8)
stroke("M1146 560 L1172 110",5,IRON); stroke("M1146 560 L1172 110",1.2,INK)
for dx in (-14,0,14): stroke(f"M{1172+dx} 112 L{1174+dx*1.2} 84",3,IRON)
stroke("M1158 112 L1188 112",3,IRON)
shape("M1144 312 Q1160 296 1176 314 Q1178 334 1160 338 Q1142 334 1144 312 Z",ROCK_L,1.8)
stroke("M1150 90 q-30 20 -26 60",1.2,INK,0.5)
# other arm gripping the pot rim
shape("M884 430 Q846 470 842 548 L870 556 Q874 496 904 462 Z",ROCK,hatch=True)
# head
shape("M928 366 Q916 296 978 276 Q1042 286 1042 346 Q1034 384 980 390 Q936 386 928 366 Z",ROCK_L,hatch=True)
P.append(f'<path d="M948 326 L972 320 L970 330 Z" fill="#ffd27a" filter="url(#glow)"/><path d="M996 320 L1020 326 L998 330 Z" fill="#ffd27a" filter="url(#glow)"/>')
shape("M948 326 L972 320 L970 330 Z","#ffd27a",1.4); shape("M996 320 L1020 326 L998 330 Z","#ffd27a",1.4)
shape("M948 352 Q984 380 1022 352 Q1010 368 984 370 Q958 368 948 352 Z","#1c1210",1.6)
for x in (962,976,990,1004): stroke(f"M{x} 356 l3 7 l3 -7",1.2,"#f3ecdc")
# flame moustache
shape("M984 344 Q960 330 932 346 Q954 336 966 352 Q976 346 984 344 Q992 346 1002 352 Q1014 336 1036 346 Q1008 330 984 344 Z",LAVA,1.4)
# flame hair & chef hat
for i in range(6):
    x=936+i*18; shape(f"M{x} 292 q-8 -22 4 -36 q2 18 12 14 q-2 12 -16 22 Z",LAVA,1.2)
shape("M946 286 L942 236 Q914 204 946 192 Q956 160 990 172 Q1022 156 1036 186 Q1066 196 1042 236 L1034 288 Q990 296 946 286 Z","#f8f4ea",2.2)
stroke("M944 262 Q990 270 1038 262",1.6); stroke("M968 196 Q974 226 966 250 M1008 192 Q1004 226 1012 250",1,INK,0.6)
# pot in front
shape("M852 586 Q840 662 900 670 L1100 670 Q1160 662 1148 586 Z",IRON,hatch=True)
shape("M836 586 Q1000 560 1164 586 Q1000 612 836 586 Z","#2c2e32",2.4)
P.append(f'<path d="M860 588 Q1000 570 1140 588 Q1000 604 860 588 Z" fill="{LAVA}" opacity="0.85" filter="url(#wash)"/>')
for x in (880,940,1010,1080,1120):
    shape(f"M{x} 586 q-6 -18 4 -30 q4 14 10 10 q0 14 -14 20 Z",LAVA,1.2)
stroke("M836 600 L812 592 M1164 600 L1188 592",4,IRON)
flush_hatch("leftBoss")
text(1000,700,"Ragnaroast  ·  boss",17,INK,"middle",700)
text(1000,718,"original parody: a lava chef in his own stew pot",13,BLUE,"middle")

# margin notes
text(330,250,"plate reads as plate:",14); text(330,268,"layered rims, rivet lines",14)
stroke("M326 262 Q300 270 282 300",1.2,BLUE)
text(700,180,"crystal = the only cold",14); text(700,198,"colour on the page",14)
stroke("M696 196 Q676 214 664 240",1.2,BLUE)
text(760,300,"cracks glow from inside",14); stroke("M850 300 Q890 320 908 360",1.2,BLUE)

svg=f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}" role="img" aria-label="Ink and wash character study: Protection Warrior, Frost Mage and Ragnaroast">\n<title>Character study v1</title>\n{defs}\n'+"\n".join(P)+"\n</svg>\n"
open(OUT,"w").write(svg); print(OUT)
