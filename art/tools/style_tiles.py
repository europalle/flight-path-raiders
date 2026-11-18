"""Art: three style tiles, variations on the ink-and-wash study."""
import html, os
OUTD="/home/claude/flight-path-raiders/art/style-tiles"; os.makedirs(OUTD,exist_ok=True)
TW,TH=400,640
TILES=[
 dict(slug="a-field-journal",name="A · Field Journal",line="Warm sketchbook: sepia ink, loose watercolour, notebook lines.",
      paper="#f3ecdc",ink="#2a2119",muted="#6b5d4c",rule="#a9bcd6",accent="#d9541e",accent2="#2f63c4",card="#fbf6ea",
      btn="#2a2119",btnText="#f3ecdc",wash=7,grain=0.10,lines=True,head="Patrick Hand",body="IBM Plex Sans",glow="#ff8a2a"),
 dict(slug="b-clean-ink",name="B · Clean Ink",line="Crisp black line, flat colour, almost no texture. Best at small sizes.",
      paper="#fbfaf6",ink="#16181c",muted="#555b64",rule="#dfe3e8",accent="#e0622a",accent2="#1f5fc8",card="#ffffff",
      btn="#16181c",btnText="#ffffff",wash=0,grain=0.03,lines=False,head="Kalam",body="IBM Plex Sans",glow="#ff9a4a"),
 dict(slug="c-midnight-grimoire",name="C · Midnight Grimoire",line="Dark pages, silver ink, glowing accents. Matches WoW's frames.",
      paper="#1c1f26",ink="#e6e1d3",muted="#a8a293",rule="#2f3540",accent="#ff8a3d",accent2="#8cc8ff",card="#252a33",
      btn="#e6e1d3",btnText="#1c1f26",wash=5,grain=0.06,lines=True,head="Kalam",body="IBM Plex Sans",glow="#ff8a2a"),
]
def tile(t):
    P=[]; e=html.escape
    def tx(x,y,s,size=14,col=None,font=None,weight=400,anchor="start"):
        P.append(f'<text x="{x}" y="{y}" font-family="{font or t["body"]}, sans-serif" font-size="{size}" font-weight="{weight}" fill="{col or t["ink"]}" text-anchor="{anchor}">{e(s)}</text>')
    flt='filter="url(#ink-'+t["slug"]+')"' if t["wash"] else ''
    wfl='filter="url(#wash-'+t["slug"]+')"' if t["wash"] else ''
    defs=f'''<defs>
<filter id="ink-{t["slug"]}" x="-5%" y="-5%" width="110%" height="110%"><feTurbulence type="fractalNoise" baseFrequency="0.04" numOctaves="2" seed="4"/><feDisplacementMap in="SourceGraphic" scale="1.6"/></filter>
<filter id="wash-{t["slug"]}" x="-10%" y="-10%" width="120%" height="120%"><feTurbulence type="fractalNoise" baseFrequency="0.02" numOctaves="3" seed="8"/><feDisplacementMap in="SourceGraphic" scale="{t["wash"]}"/></filter>
<filter id="grain-{t["slug"]}"><feTurbulence type="fractalNoise" baseFrequency="0.85" numOctaves="2" seed="2"/><feColorMatrix values="0 0 0 0 0.4  0 0 0 0 0.35  0 0 0 0 0.3  0 0 0 {t["grain"]} 0"/></filter>
<filter id="glow-{t["slug"]}"><feGaussianBlur stdDeviation="4"/></filter>
<pattern id="hatch-{t["slug"]}" width="4" height="4" patternUnits="userSpaceOnUse" patternTransform="rotate(38)"><line x1="0" y1="0" x2="0" y2="4" stroke="{t["ink"]}" stroke-width="0.8"/></pattern>
</defs>'''
    P.append(f'<rect width="{TW}" height="{TH}" fill="{t["paper"]}"/>')
    if t["lines"]:
        for y in range(36,TH,24): P.append(f'<line x1="0" y1="{y}" x2="{TW}" y2="{y}" stroke="{t["rule"]}" stroke-width="0.6" opacity="0.5"/>')
    P.append(f'<rect width="{TW}" height="{TH}" filter="url(#grain-{t["slug"]})"/>')
    tx(24,46,t["name"],26,font=t["head"],weight=700)
    tx(24,70,t["line"],11.5,t["muted"])
    # palette
    sw=[("paper",t["paper"]),("ink",t["ink"]),("lava",t["accent"]),("frost",t["accent2"]),("panel",t["card"])]
    for i,(n,c) in enumerate(sw):
        x=24+i*72
        P.append(f'<rect x="{x}" y="88" width="60" height="40" rx="6" fill="{c}" stroke="{t["ink"]}" stroke-width="1.2" {flt}/>')
        tx(x+30,144,n,10,t["muted"],anchor="middle")
    # type
    tx(24,184,"Ragnaroast is up (Heroic)",24,font=t["head"],weight=700)
    tx(24,206,"Body text stays clean: 13 units minimum, high contrast.",12.5)
    tx(24,224,"R7  Spread holds: lava hits only Kess.",12.5,weight=600)
    # character card
    cx,cy=24,246
    P.append(f'<rect x="{cx}" y="{cy}" width="230" height="86" rx="10" fill="{t["card"]}" stroke="{t["ink"]}" stroke-width="1.8" {flt}/>')
    # portrait: hooded frost mage
    px,py=cx+12,cy+12
    P.append(f'<rect x="{px}" y="{py}" width="62" height="62" rx="8" fill="{t["paper"]}" stroke="{t["ink"]}" stroke-width="1.4" {flt}/>')
    P.append(f'<path d="M{px+12} {py+62} Q{px+10} {py+30} {px+31} {py+12} Q{px+52} {py+30} {px+50} {py+62} Z" fill="#2f4f7a" opacity="0.92" {wfl}/>')
    P.append(f'<path d="M{px+12} {py+62} Q{px+10} {py+30} {px+31} {py+12} Q{px+52} {py+30} {px+50} {py+62}" fill="none" stroke="{t["ink"]}" stroke-width="1.6" {flt}/>')
    P.append(f'<path d="M{px+21} {py+46} Q{px+23} {py+30} {px+31} {py+26} Q{px+39} {py+30} {px+41} {py+46} Z" fill="#141a24"/>')
    for ex in (27,35): P.append(f'<circle cx="{px+ex}" cy="{py+36}" r="3.5" fill="{t["accent2"]}" filter="url(#glow-{t["slug"]})"/><circle cx="{px+ex}" cy="{py+36}" r="1.3" fill="#eef8ff"/>')
    tx(cx+86,cy+30,"Lumi",17,font=t["head"],weight=700)
    tx(cx+86,cy+48,"Mage · Frost",12,t["muted"])
    for i in range(5):
        P.append(f'<circle cx="{cx+90+i*12}" cy="{cy+64}" r="4" fill="{t["ink"] if i<4 else "none"}" stroke="{t["ink"]}" stroke-width="1.2"/>')
    tx(cx+156,cy+68,"Epic",11,t["muted"])
    # buttons
    by=352
    P.append(f'<rect x="24" y="{by}" width="150" height="44" rx="8" fill="{t["btn"]}" {flt}/>')
    tx(99,by+28,"Pull",17,t["btnText"],font=t["head"],weight=700,anchor="middle")
    P.append(f'<rect x="186" y="{by}" width="150" height="44" rx="8" fill="none" stroke="{t["ink"]}" stroke-width="1.8" {flt}/>')
    tx(261,by+28,"Same as last",15,font=t["head"],weight=700,anchor="middle")
    # icons: affix diamond, BoE mark, warning, potion
    iy=420
    def icon(x,kind):
        P.append(f'<rect x="{x}" y="{iy}" width="56" height="56" rx="10" fill="{t["card"]}" stroke="{t["ink"]}" stroke-width="1.4" {flt}/>')
        c=x+28; m=iy+28
        if kind=="affix": P.append(f'<path d="M{c} {m-16} L{c+14} {m} L{c} {m+16} L{c-14} {m} Z" fill="{t["accent"]}" stroke="{t["ink"]}" stroke-width="1.6" {flt}/>')
        if kind=="boe": P.append(f'<path d="M{c} {m-16} L{c+14} {m} L{c} {m+16} L{c-14} {m} Z" fill="none" stroke="{t["accent2"]}" stroke-width="2.4" {flt}/><circle cx="{c}" cy="{m}" r="4" fill="{t["accent2"]}"/>')
        if kind=="warn": P.append(f'<path d="M{c} {m-17} L{c+17} {m+14} L{c-17} {m+14} Z" fill="{t["accent"]}" stroke="{t["ink"]}" stroke-width="1.6" {flt}/><path d="M{c} {m-6} L{c} {m+4}" stroke="{t["ink"]}" stroke-width="2.6"/><circle cx="{c}" cy="{m+9}" r="1.8" fill="{t["ink"]}"/>')
        if kind=="potion": P.append(f'<path d="M{c-5} {m-18} L{c+5} {m-18} L{c+5} {m-8} Q{c+16} {m} {c+14} {m+10} Q{c} {m+20} {c-14} {m+10} Q{c-16} {m} {c-5} {m-8} Z" fill="{t["accent"]}" stroke="{t["ink"]}" stroke-width="1.6" {flt}/>')
    for i,k in enumerate(("affix","boe","warn","potion")): icon(24+i*68,k)
    tx(24,iy+76,"icons: affix · BoE · warning · Fire Resistance",10.5,t["muted"])
    # mini scene strip: boss pot glow
    sy=520
    P.append(f'<rect x="24" y="{sy}" width="352" height="96" rx="10" fill="{t["card"]}" stroke="{t["ink"]}" stroke-width="1.4" {flt}/>')
    P.append(f'<ellipse cx="300" cy="{sy+92}" rx="90" ry="40" fill="{t["glow"]}" opacity="0.35" filter="url(#glow-{t["slug"]})"/>')
    P.append(f'<path d="M244 {sy+70} Q240 {sy+92} 260 {sy+92} L340 {sy+92} Q360 {sy+92} 356 {sy+70} Z" fill="#3a3d42" stroke="{t["ink"]}" stroke-width="1.6" {flt}/>')
    P.append(f'<path d="M262 {sy+70} Q258 {sy+30} 300 {sy+22} Q342 {sy+30} 338 {sy+70} Z" fill="#4a3a34" opacity="0.95" {wfl}/>')
    P.append(f'<path d="M262 {sy+70} Q258 {sy+30} 300 {sy+22} Q342 {sy+30} 338 {sy+70}" fill="none" stroke="{t["ink"]}" stroke-width="1.6" {flt}/>')
    P.append(f'<path d="M282 {sy+44} L296 {sy+40} M304 {sy+40} L318 {sy+44}" stroke="#ffd27a" stroke-width="3" filter="url(#glow-{t["slug"]})"/><path d="M282 {sy+44} L296 {sy+40} M304 {sy+40} L318 {sy+44}" stroke="#ffd27a" stroke-width="1.6"/>')
    P.append(f'<path d="M286 {sy+22} L284 {sy+4} Q276 {sy-6} 290 {sy-8} Q300 {sy-16} 310 {sy-8} Q324 {sy-6} 316 {sy+4} L314 {sy+22} Z" fill="#f8f4ea" stroke="{t["ink"]}" stroke-width="1.4" {flt}/>')
    tx(40,sy+40,"Stage mood",14,font=t["head"],weight=700)
    tx(40,sy+60,"lava light from the right,",11.5,t["muted"]); tx(40,sy+76,"shadow side hatched",11.5,t["muted"])
    P.append(f'<rect x="40" y="{sy+82}" width="120" height="8" fill="url(#hatch-{t["slug"]})" opacity="0.6"/>')
    tx(24,TH-10,f'Fonts: {t["head"]} (headings) · {t["body"]} (body). Both free to ship (OFL).',9.5,t["muted"])
    svg=f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {TW} {TH}" width="{TW}" height="{TH}" role="img" aria-label="Style tile {e(t["name"])}">\n<title>{e(t["name"])}</title>\n{defs}\n'+"\n".join(P)+"\n</svg>\n"
    open(f'{OUTD}/{t["slug"]}.svg',"w").write(svg)
for t in TILES: tile(t)
print(sorted(os.listdir(OUTD)))
