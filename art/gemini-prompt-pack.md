# Gemini prompt pack v2: a reusable kit

Art department, 2026-11-18. Replaces v1. The whole game is assembled from a small kit of reusable pieces instead of one drawing per screen element.

## The reuse rules

1. **Draw once, tint in code.** WoW can recolour a texture at runtime (`SetVertexColor`). So borders, ornaments, buttons, rings, quality marks and effects are drawn **in neutral greys and white**, then tinted: sepia and gold for light mode, silver and iron for dark mode, green, blue or purple for item quality, orange for fire, ice-blue for frost. One border serves dozens of uses.
2. **Colour lives in the textures.** The paper and slate textures carry the watercolour richness; everything drawn on top stays neutral and gets tinted.
3. **Stretch, don't redraw.** Every frame is a 9-slice set (4 corners, 4 edges, centre texture), so one set covers every window, panel, card and tooltip at any size.
4. **Frame plus glyph.** Icons are a shared frame (square slot or round ring) with a separate glyph on top. Thirty icons cost one frame and thirty small glyphs.
5. **States are overlays.** Hover, pressed, disabled and selected are a glow, an inner shadow or a desaturation on the same base, not four drawings.
6. **Characters share a body template.** All nine classes stand on the same template: same height, same stance, empty hands. Weapons and shields are separate props, reused across classes (a sword for warrior, paladin and rogue). The stage animates the props and body parts separately.
7. **Effects are generic.** One glow, one sparkle, one hit spark, one smoke puff, one swirl, all neutral, tinted per school of magic.

## How to run

- Attach `art/sketches/character-study-v1.png` to every prompt as the style reference.
- One prompt per message, in order. Send results back as PNG at full resolution.
- Everything except the textures and backgrounds is on flat magenta (#FF00FF). Art keys it out.
- If something copies Blizzard's real art, logos or characters, rerun it. Art edits on top of everything, for the licence.

## Style block (included below as [Style])

> Hand-drawn parody of the World of Warcraft Classic interface, as if a raid leader sketched it in a paper notebook with a dip pen and watercolour. Wobbly confident ink outlines, light crosshatching on shadow sides. Charming and a bit clumsy, never sloppy. Original designs only: no Blizzard logos, no real WoW icons, no text. Flat solid magenta (#FF00FF) background with nothing else on it. Each piece separate, with clear magenta space between pieces.

[Neutral] means: **draw only in black ink, greys and white, no colour at all, so it can be tinted later.**

---

## A. Textures (colour, full canvas, no magenta)

**A1. Parchment (light mode)**
> A seamless tileable square texture of aged cream notebook parchment with faint watercolour stains, very subtle paper grain and faint blue ruled lines. Even lighting, no shadows, no objects, no vignette. The left edge must continue into the right edge and the top into the bottom.

**A2. Slate (dark mode)**
> A seamless tileable square texture of dark charcoal slate, like a dark spellbook page, with very subtle chalky grain and faint lighter streaks. Even lighting, no objects, no vignette. Edges must tile seamlessly.

**A3. Paper wear stickers**
> [Style] A sheet of small decorative stickers to scatter on a page: a coffee ring stain, an ink blot, a smudged thumbprint, a strip of torn masking tape, a folded dog-ear corner, a small doodled star, a doodled skull, a doodled arrow. Watercolour colour allowed on these.

## B. Frame kit [Neutral]

**B1. Borders**
> [Style] [Neutral] A 9-slice border kit for game windows, in two weights. Heavy weight: 4 ornate corner pieces (top-left, top-right, bottom-left, bottom-right) and 4 straight edge strips (top, bottom, left, right) that can repeat seamlessly. Light weight: the same 8 pieces, thinner and plainer. Edges must be perfectly straight strips so they can be stretched.

**B2. Ornaments**
> [Style] [Neutral] A sheet of small ornaments to decorate frames: a title ribbon banner with no text, a short horizontal divider with a flourish in the middle, a round rivet, a small cut gem, a wax seal with no symbol, a hanging tassel, a scroll curl end.

**B3. Controls**
> [Style] [Neutral] A sheet of interface controls: one wide rounded button base, a round button base, a square tab base, a checkbox box, a slider track and a slider knob, a dropdown arrow, a close X, a minus and a plus. Then three overlays the same size as the wide button: a soft outer glow, an inner pressed shadow, and a thin selected outline.

**B4. Rings, slots and bars**
> [Style] [Neutral] A sheet of empty frames: a round portrait ring, a square item slot, a small round badge, a long thin bar frame, and a cartoonish parody dragon that wraps around the round ring as an elite overlay (not the real WoW elite dragon). Also a plain bar fill texture with brush-stroke edges.

**B5. Quality marks**
> [Style] [Neutral] Six tiny corner marks to place in the corner of an item slot, so quality reads without colour: nothing (empty circle), one dot, two dots, a small diamond, a small star, a small flame.

## C. Glyphs (ink plus at most one accent colour, no frame)

Each glyph sits on the shared slot or ring from B4.

**C1. Roles and classes**
> [Style] Small icon glyphs, dark ink with one watercolour accent each, no frames or circles around them: tank (dented kite shield), healer (glowing hand with a plus), damage (crossed swords); warrior (notched axe), paladin (hammer with a halo), hunter (bow with a paw print), rogue (dagger and mask), priest (candle), shaman (small totem), mage (pointed hat with a star), warlock (skull candle with green flame), druid (oak leaf and paw).

**C2. Affixes and status**
> [Style] Small icon glyphs, dark ink with one accent each, no frames: stone shield, goblin wearing a crown, feet pushing each other, tilted sad face, floor with lava cracks, glowing orb, dripping blade, snail with an hourglass, cracked summoning stone, warning triangle, envelope, padlock, tick, empty checkbox, ticked checkbox, upward arrow, pencil, pause symbol, cog.

**C3. Items**
> [Style] Small item glyphs, ink and watercolour, no frames: plate of food, round elixir bottle, tall flask, red potion with a flame mark, thick book with a swirl, coin stack, small chest, scroll, plate chestpiece, mail chestpiece, leather vest, cloth robe, ring, trinket charm.

## D. Effects [Neutral, tinted per school]

**D1. Effects**
> [Style] [Neutral] A sheet of simple 2D effect sprites drawn in white and grey ink so they can be tinted: a soft round glow, a four-point sparkle, a jagged hit spark, a smoke puff, a swirl of magic, a rising heal plus, a small flame shape, a crescent slash arc, a shockwave ring.

## E. Characters on a shared template

**E0. Template (run first)**
> [Style] One plain mannequin figure for a 2D game, side view facing right, standing idle, feet on an invisible flat line at the bottom, about two-thirds of the image height tall, hands open and empty. Simple clothing. This is a proportion template that all characters will match.

**E1 to E9. Classes (attach the template result as well as the style reference)**
> [Style] One full-body character drawn on exactly the same proportions, height and pose as the attached template, side view facing right, hands empty (weapons are added separately). Original character, not a known WoW character. **Class line.**

1. Warrior: red tabard over dented plate, heavy pauldrons, crested helmet.
2. Paladin: polished plate, gold-trimmed blue tabard, small halo glow.
3. Hunter: mail and leather, quiver on the back, a fat loyal boar beside them (the boar as a separate drawing).
4. Rogue: dark leather hood and scarf, slightly hunched, sneaky grin.
5. Priest: white and gold robes, calm and slightly smug.
6. Shaman: mail and furs, bone charms.
7. Mage: deep blue hooded robe, face in shadow with glowing eyes.
8. Warlock: purple robes, horned cowl, a small imp on the shoulder (imp as a separate drawing).
9. Druid: leather and leaves, antler headdress.

**E10. Props**
> [Style] A sheet of separate weapons and held items, each drawn at the scale of the attached template's hands, angled as if held: sword, axe, two-handed hammer, longbow, dagger, staff with an ice crystal, wooden staff with a moon charm, wand, kite shield, round shield, small totem, candle, spellbook.

## F. Bosses

> [Style] One large boss character, side view facing left, standing on an invisible flat line at the bottom, filling most of the image, limbs and held items clearly separated so they can be animated. Original parody. **Boss line.**

1. Ragnaroast: a giant lava chef of cracked molten rock rising out of an iron stew pot, chef's hat, flame moustache. The roasting spit as a separate drawing. Match the attached Ragnaroast.
2. Onyxiety: a nervous black dragon, wings half folded, chewing a claw, anxious eyes. Cartoonish and sympathetic.

The other Molten Bore bosses follow once their designs are written up.

## G. Stage backgrounds in layers (full canvas, no magenta)

Each raid is three layers so the ground and middle can be reused and recoloured.

> [Style, but fill the whole image instead of magenta] A wide side-view 2D game background, aspect ratio 2:1, no characters. **Layer line.**

1. Far layer, Molten Bore: distant volcanic cave walls and lava rivers, soft and low contrast.
2. Middle layer, Molten Bore: rock pillars and stalactites at the sides only, empty centre.
3. Ground strip (shared): a flat rocky ground strip filling the bottom fifth, horizontally tileable, the rest of the image magenta.
4. Far layer, Onyxiety's Lair: a dark cave with piles of gold coins and eggs, soft and low contrast.

---

## What Art builds from the kit

| Kit piece | Becomes |
| --- | --- |
| A1 / A2 + B1 + B2 | Every window, panel, card, tooltip and popup in both modes |
| B3 + overlays | Every button, tab, checkbox, slider and dropdown, in every state |
| B4 + C glyphs | Every icon, portrait, item slot and boss frame |
| B4 + B5 + tint | Every item quality, readable without colour |
| B4 bar + fill + tint | Health, mana, morale, XP, progress and countdown bars |
| D1 + tint | Every spell, heal, hit and buff effect |
| E0 to E10 | All characters on the stage, cards and roster, with any weapon |
| G layers | Every raid stage; new raids reuse the ground strip |
