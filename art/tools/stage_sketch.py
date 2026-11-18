"""Art: pencil stage sketch for the playback screen (620 x 330 stage units, drawn at 2x)."""
import math, random, html
random.seed(7)
OUT="/home/claude/flight-path-raiders/art/sketches/stage-pencil-v1.svg"
import os; os.makedirs(os.path.dirname(OUT),exist_ok=True)
PAPER="#f5f0e4"; LEAD="#3a3835"; SOFT="#8d877c"; BLUE="#2f63c4"; RED="#b8452e"
W,H=620,330
FRONT=300; BACK=272   # ground lines
P=[]
def path(d,sw=1.6,col=LEAD,fill="none",op=1):
    P.append(f'<path d="{d}" fill="{fill}" stroke="{col}" stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round" opacity="{op}" filter="url(#rough)"/>')
    if fill=="none":
        P.append(f'<path d="{d}" fill="none" stroke="{col}" stroke-width="{sw*0.6}" opacity="{0.35*op}" transform="translate(0.7 0.5)" filter="url(#rough)"/>')
def line(x1,y1,x2,y2,sw=1.6,col=LEAD,op=1): path(f"M{x1:.1f} {y1:.1f} L{x2:.1f} {y2:.1f}",sw,col,op=op)
def circ(cx,cy,r,sw=1.6,col=LEAD,fill="none"):
    k=0.5523*r
    d=f"M{cx-r} {cy} C{cx-r} {cy-k} {cx-k} {cy-r} {cx} {cy-r} C{cx+k} {cy-r} {cx+r} {cy-k} {cx+r} {cy} C{cx+r} {cy+k} {cx+k} {cy+r} {cx} {cy+r} C{cx-k} {cy+r} {cx-r} {cy+k} {cx-r} {cy}"
    path(d,sw,col,fill)
def note(x,y,t,size=9,col=BLUE,anchor="start",rot=0):
    tr=f' transform="rotate({rot} {x} {y})"' if rot else ''
    P.append(f'<text x="{x}" y="{y}" font-family="Patrick Hand, Comic Sans MS, cursive" font-size="{size}" fill="{col}" text-anchor="{anchor}"{tr}>{html.escape(t)}</text>')
def hatch(x1,x2,y,n,len_=6,col=SOFT):
    for i in range(n):
        x=x1+(x2-x1)*i/n+random.uniform(-2,2)
        line(x,y+2+random.uniform(0,3),x-len_,y+2+len_+random.uniform(0,3),0.8,col,0.7)

def figure(x,g,s=1.0,kind="melee",face=1,walk=False,label=None):
    """Side-view figure standing with feet on ground g. face=1 looks right."""
    h=46*s; hr=6.5*s
    hip=g-18*s; sh=g-33*s; head=g-h+hr
    # legs
    if walk:
        line(x,hip,x-7*s,g,1.6); line(x,hip,x+6*s,g-1,1.6)
    else:
        line(x-1*s,hip,x-4*s,g,1.6); line(x+1*s,hip,x+4*s,g,1.6)
        line(x-4*s,g,x-4*s+4*face*s,g,1.4); line(x+4*s,g,x+4*s+4*face*s,g,1.4)
    # torso (slightly tapered)
    path(f"M{x-5*s} {sh} Q{x-6*s} {hip-4*s} {x-4*s} {hip} L{x+4*s} {hip} Q{x+6*s} {hip-4*s} {x+5*s} {sh} Z",1.6)
    circ(x,head,hr)
    # eye
    circ(x+2.5*face*s,head-0.5*s,0.6*s,1.2,LEAD,LEAD)
    ax=x+5*face*s
    if kind=="tank":
        path(f"M{ax+4*face*s} {sh-2*s} Q{ax+11*face*s} {sh+8*s} {ax+4*face*s} {hip+4*s} Q{ax+1*face*s} {sh+8*s} {ax+4*face*s} {sh-2*s} Z",1.6)
        line(x-5*face*s,sh+2*s,x-12*face*s,sh-10*s,1.6); line(x-12*face*s,sh-10*s,x-14*face*s,sh-20*s,2)
    elif kind=="melee":
        line(ax,sh+3*s,ax+8*face*s,sh+10*s,1.6); line(ax+8*face*s,sh+10*s,ax+20*face*s,sh-4*s,2)
        line(ax+6*face*s,sh+12*s,ax+10*face*s,sh+7*s,1.4)
    elif kind=="rogue":
        line(ax,sh+3*s,ax+7*face*s,sh+12*s,1.6); line(ax+7*face*s,sh+12*s,ax+14*face*s,sh+8*s,1.8)
        path(f"M{x-6*s} {head-4*s} Q{x} {head-12*s} {x+6*s} {head-4*s}",1.4)  # hood
    elif kind=="hunter":
        path(f"M{ax+8*face*s} {sh-10*s} Q{ax+18*face*s} {sh+4*s} {ax+8*face*s} {hip+6*s}",1.6)
        line(ax+8*face*s,sh-10*s,ax+8*face*s,hip+6*s,0.8); line(ax,sh+2*s,ax+8*face*s,sh+2*s,1.4)
    elif kind=="caster":
        line(ax+3*face*s,g,ax+3*face*s,head-8*s,1.6); circ(ax+3*face*s,head-11*s,3*s)
        path(f"M{x-6*s} {head-5*s} L{x} {head-17*s} L{x+6*s} {head-5*s}",1.4)  # pointy hat
    elif kind=="healer":
        line(ax+3*face*s,g,ax+3*face*s,head-6*s,1.6); path(f"M{ax+3*face*s-4*s} {head-9*s} L{ax+3*face*s+4*s} {head-9*s} M{ax+3*face*s} {head-13*s} L{ax+3*face*s} {head-5*s}",1.4)
        for i in range(3):
            a=i*2.1; circ(x+math.cos(a)*14*s,head+math.sin(a)*6*s-2*s,1.2*s,1,SOFT)
    # shadow on ground
    path(f"M{x-10*s} {g+1.5} Q{x} {g+4.5} {x+10*s} {g+1.5}",1,SOFT,op=0.8)
    if label: note(x,g+14*s if s>0.95 else g+12,label,8,LEAD,"middle")

defs='''<defs>
<filter id="rough" x="-5%" y="-5%" width="110%" height="110%"><feTurbulence type="fractalNoise" baseFrequency="0.035" numOctaves="2" seed="3"/><feDisplacementMap in="SourceGraphic" scale="1.6"/></filter>
<filter id="grain"><feTurbulence type="fractalNoise" baseFrequency="0.9" numOctaves="2" seed="9"/><feColorMatrix values="0 0 0 0 0.4  0 0 0 0 0.37  0 0 0 0 0.3  0 0 0 0.08 0"/></filter>
</defs>'''
# paper + grain + faint squares
P.append(f'<rect width="{W}" height="{H}" fill="{PAPER}"/>')
P.append(f'<rect width="{W}" height="{H}" filter="url(#grain)"/>')
for gx in range(0,W,20): P.append(f'<line x1="{gx}" y1="0" x2="{gx}" y2="{H}" stroke="#9fb6d6" stroke-width="0.3" opacity="0.35"/>')
for gy in range(0,H,20): P.append(f'<line x1="0" y1="{gy}" x2="{W}" y2="{gy}" stroke="#9fb6d6" stroke-width="0.3" opacity="0.35"/>')

# --- back wall / cave silhouette (very soft)

# --- ground: back line, front line, hatching between
path(f"M0 {BACK} Q150 {BACK-2} 300 {BACK} T620 {BACK-1}",1.2,SOFT)
path(f"M0 {FRONT} Q160 {FRONT+2} 320 {FRONT} T620 {FRONT+1}",2.2)
hatch(10,600,FRONT,48,7)
for i in range(16):  # pebbles
    x=random.uniform(20,420); y=random.uniform(BACK+6,FRONT-6); circ(x,y,random.uniform(1,2.2),0.8,SOFT)

# --- lava pool & boss (right third): Ragnaroast, a lava chef rising from his stew pot
bx=536
_b0=len(P)
path(f"M440 {FRONT} Q470 {FRONT-6} 500 {FRONT-3} Q540 {FRONT-8} 600 {FRONT-2}",1.2,RED)   # lava lip
for i in range(6):
    x=448+i*26; path(f"M{x} {FRONT-2} q4 -6 8 0",1,RED,op=0.8)
# pot
path(f"M{bx-62} {FRONT-46} Q{bx-66} {FRONT} {bx-44} {FRONT} L{bx+44} {FRONT} Q{bx+66} {FRONT} {bx+62} {FRONT-46} Z",2.2)
path(f"M{bx-70} {FRONT-50} Q{bx} {FRONT-60} {bx+70} {FRONT-50} Q{bx} {FRONT-40} {bx-70} {FRONT-50} Z",1.8)
line(bx-66,FRONT-30,bx-78,FRONT-34,2); line(bx+66,FRONT-30,bx+78,FRONT-34,2)  # handles
# torso rising
path(f"M{bx-40} {FRONT-54} Q{bx-48} {FRONT-120} {bx-30} {FRONT-170} Q{bx} {FRONT-186} {bx+30} {FRONT-170} Q{bx+48} {FRONT-120} {bx+40} {FRONT-54}",2.2)
# head
circ(bx-4,FRONT-196,20,2.2)
circ(bx-12,FRONT-200,2,1.4,LEAD,LEAD)
path(f"M{bx-20} {FRONT-188} Q{bx-12} {FRONT-182} {bx-4} {FRONT-188}",1.6)
# flame hair & chef hat
for i in range(5):
    x=bx-22+i*9; path(f"M{x} {FRONT-210} q-3 -10 2 -16 q1 8 6 6",1.4,RED)
path(f"M{bx-18} {FRONT-214} L{bx-16} {FRONT-232} Q{bx-26} {FRONT-252} {bx-8} {FRONT-252} Q{bx-2} {FRONT-266} {bx+10} {FRONT-252} Q{bx+28} {FRONT-250} {bx+14} {FRONT-232} L{bx+12} {FRONT-214} Z",1.8)
# arm raised with giant roasting spit (wind-up)
line(bx-34,FRONT-150,bx-62,FRONT-190,2.2); line(bx-62,FRONT-190,bx-58,FRONT-232,2.2)
line(bx-90,FRONT-246,bx-24,FRONT-222,3)          # the spit
for i in range(3): line(bx-88+i*4,FRONT-248+i*1.5,bx-96+i*4,FRONT-256+i*1.5,1.2)  # prongs
# motion arcs
for r_ in (14,22):
    path(f"M{bx-80} {FRONT-260-r_/3} q-{r_} {r_/2} -{r_/2} {r_*1.4}",0.9,SOFT)
# other arm on pot rim
line(bx+34,FRONT-140,bx+56,FRONT-96,2.2); line(bx+56,FRONT-96,bx+52,FRONT-58,2.2)
_body=P[_b0:]; del P[_b0:]; P.append(f'<g transform="translate({bx} {FRONT}) scale(0.8) translate({-bx} {-FRONT})">'+"".join(_body)+"</g>")
note(bx,FRONT+18,"Ragnaroast",10,LEAD,"middle")
# wind-up marker
circ(bx-96,FRONT-206,9,1.8,BLUE); note(bx-96,FRONT-202,"!",12,BLUE,"middle")
note(bx-108,FRONT-222,"wind-up marker + text label (not just animation)",8,BLUE,"end")

# --- raid: left = healers, then ranged, melee, tanks nearest the boss
back=[(84,"healer","Sela"),(152,"caster","Lumi"),(236,"rogue","Kess"),(310,"melee","Ash"),(376,"tank","Mira")]
front=[(60,"healer","Bram"),(128,"hunter","Orrin"),(206,"melee","Vey"),(282,"melee",None),(354,"tank","Brannoc")]
for x,k,n in back:
    figure(x,BACK,0.9,k)
    note(x,BACK-50,n,8,LEAD,"middle")
for x,k,n in front:
    if n is None:
        # Tor's empty spot
        path(f"M{x-10} {FRONT+1.5} Q{x} {FRONT+4.5} {x+10} {FRONT+1.5}",1,SOFT,op=0.8)
        P.append(f'<ellipse cx="{x}" cy="{FRONT-22}" rx="12" ry="25" fill="none" stroke="{SOFT}" stroke-width="1" stroke-dasharray="3 3"/>')
        note(x,FRONT+14,"Tor's spot",8,SOFT,"middle")
    else: figure(x,FRONT,1.0,k,label=n)
# Tor walking off, left edge, back turned (faces left)
figure(14,FRONT,1.0,"melee",face=-1,walk=True)
path(f"M2 {FRONT-74} L62 {FRONT-74} L62 {FRONT-58} L22 {FRONT-58} L14 {FRONT-50} L16 {FRONT-58} L2 {FRONT-58} Z",1.2)
note(32,FRONT-62,'Tor: "bye o/"',8,LEAD,"middle")
# heal sparkle line Sela -> Brannoc
path(f"M90 {BACK-58} Q220 {BACK-120} 354 {FRONT-56}",0.9,SOFT,op=0.9)
note(220,BACK-100,"heal arc",8,SOFT,"middle")

# --- annotations (blue pencil)
line(4,FRONT+6,4,FRONT+20,1,BLUE); note(8,FRONT+27,"FRONT ground: every foot touches this line",9)
note(250,FRONT+27,"back row: 28 units up, 90% size",9,BLUE)
note(366,BACK-66,"tanks nearest the boss",8,BLUE,"middle")
note(72,BACK-70,"healers back left",8,BLUE,"middle")
note(4,FRONT-84,"benched = walks off left",8,BLUE)

svg=f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W*2}" height="{H*2}" role="img" aria-label="Pencil sketch of the playback stage">\n<title>Stage pencil sketch v1</title>\n{defs}\n'+"\n".join(P)+"\n</svg>\n"
open(OUT,"w").write(svg); print(OUT)
