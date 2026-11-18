# Art handoff: mid-fi to hi-fi

From UX/UI & Accessibility to Art, 2026-11-18. The mid-fi wireframes are approved as the base for hi-fi.

## What you get

| File | Use |
| --- | --- |
| `../wireframes/mid-fi/*.svg` | Editable source, one per screen, on the 960 x 540 design grid |
| `png/*@2x.png` | 2x renders to paint over (1920 x 1080 for full screens) |
| `../tools/gen_midfi.py` | The script that draws the wireframes, if a layout needs regenerating |
| `../overlays/midfi-playback-on-1440p.png` | The board at default size on the Director's real screen |

Screens: toast, hub, prep, playback, results, guild bank, guild bank (locked), landing popup, settings.

## Size and scale

- Design grid: 960 x 540 UI units, 16:9. The in-game default is about 70% of screen width, and the player scales it from 70 to 120%.
- On the Director's 1440p screen (UI scale 0.64) one unit is about 1.9 px at default size. On small screens at 70% it can drop to about 1 px.
- Deliver art as SVG (vector) where possible. Raster textures are made at 2x the grid size, so they stay sharp at 120% on a 4K screen.
- In-game texture format (TGA or BLP, power-of-two sizes) is Engineering's call in the technical design. Keep the source files layered.

## Locked: please don't change

- Layout, the order of the regions and their relative sizes.
- Click target sizes. The smallest is 24 units; the primary buttons (Prep pull, Pull, Next boss) stay the largest on their screens.
- Text sizes: 11 units minimum, 12 to 13 for body text. Headings may grow; nothing shrinks.
- Every state is shape plus text, never colour alone: quality pips plus the word, BoP and BoE as text tags, DEAD written out, affix shape icons, the selected tactic's tick.
- Contrast: body text at least 4.5:1 against its background, including on paper texture. Check the paper at its darkest point, not its average.

## Open to Art

- The notebook style: the raid leader's notebook. Lined or squared paper, ink and pencil sketches, highlighter accents, sticky notes, tape, coffee rings in empty space only.
- Frames, panels, buttons, dividers and the title bar (built as 9-slice so they stretch).
- Typography: a handwritten face is fine for headings and the boss name; body text, numbers and the combat log stay in a clean, readable sans.
- Illustration, icons and animation, within the rules below.

## The stage (playback): first deliverable

The Director flagged that the mid-fi stage reads as floating characters. The stage needs a ground before anything else is painted.

- Side-on view. One ground plane across the whole stage; every character's feet touch it.
- Two depth rows: the back row sits about 24 units higher and at 90% size, the front row lower and full size. Tanks stand closest to the boss, healers at the back left.
- The boss fills the right third (about 168 x 216 units), standing on the same ground.
- Speech bubbles sit above heads and never cover the boss's wind-up marker.
- A benched character walks off to the left and leaves an empty spot, so the gap in the raid is visible.

Deliver a pencil sketch of the stage first, for the Director to check, before any painting.

## Icons are textures, not characters

WoW's in-game fonts can't draw symbols such as a lock, envelope, tick, checkbox, arrow or warning sign; they show up as empty boxes. In the wireframes every such symbol is drawn in ochre. Each one needs an icon texture, shown inline in text at the text's height. The set so far: affix shapes, warning, tick, checkbox (empty and ticked), envelope (mailbox), lock, potion (consumable), Bind on Equip mark, dropdown arrow, upgrade arrow, rename pencil, pause, settings, close, and the rank arrow on the results banner.

## Hub boss illustration

After the department review the hub's Continue card has a 210 x 128 unit boss illustration. It changes with the next boss, so it comes from the same drawings as the stage bosses (a cropped, framed version).

## Asset list (first pass)

| Group | Count | Notes |
| --- | --- | --- |
| Class figures, full body | 9 | Warrior, paladin, hunter, rogue, priest, shaman, mage, warlock, druid. States: idle, attack, hit, dead, walk-off |
| Portrait crops | 9 | From the same drawings, for cards (34 units) and the roster strip (40 units) |
| Bosses | 6 | The Molten Bore (5) and Onyxiety. States: idle, wind-up, hit, defeated |
| Stage backgrounds | 2 | One per raid, with the floor as part of the drawing |
| Effects | about 6 | Lava, heal glow, hit spark, shield, buff, "!" wind-up marker |
| Item icons | about 24 | 4 armor types, weapons, wand, shield, trinket, ring, plus consumables (food, elixir, flask, Fire Resistance, tome) |
| UI icons | about 20 | 9 affix shapes (2 base, 7 weekly), BoP and BoE marks, 4 tactics, mailbox, lock, warning, settings, scale +/- |
| Quality marks | 6 | Poor, Common, Uncommon, Rare, Epic, Legendary. Each must work in all four colour palettes and in greyscale |

## Motion rules

- One playback lasts 20 to 40 seconds. A key moment gets 1 to 2 seconds.
- Nothing flashes more than 3 times per second (photosensitivity).
- Reduced motion: the stage holds still and only bars and the log update. Every animation needs a still frame that tells the same story.
- Summary only skips playback entirely, so no information may exist only in an animation.

## Order of delivery

1. Stage sketch (pencil) for the Director.
2. Three style tiles: paper, ink, accent colour, one button, one card, one icon.
3. Hub and playback in hi-fi.
4. The remaining screens, then the asset list.

Licence reminder: art is CC BY-NC-SA 4.0. Human edits on top of any generated base strengthen the licence; keep the layered sources.
