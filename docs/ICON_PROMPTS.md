# Game pass icon prompts

Image-generation prompts for the eight game pass icons, written to match the GUI
already in the game: chunky cartoon shapes, a heavy near-black outline, saturated
two-stop gradients, nothing fussy.

How to use this file: paste the **Style block** first, then one **Subject** line
after it. That is the whole prompt. The style block is what keeps the eight icons
looking like a set instead of eight unrelated pictures, so do not paraphrase it
between generations — change only the subject line.

Every prompt bakes in that pass's accent colour, because the icon sits in a well
tinted with the same gradient on its shop card. An icon in the wrong hue reads as
a mistake even when the drawing is good.

---

## Style block

> Cartoon game icon for a mobile game, single centred object on a fully
> transparent background. Chunky simplified shapes with a thick uniform dark
> outline in near-black (#10131A). Flat colour fills with one soft top-to-bottom
> gradient per shape and a single soft highlight; no textures, no noise, no
> gritty detail. Bold and readable at small size: one clear silhouette, big
> forms, no thin lines and no small text. Friendly, glossy, slightly toy-like,
> like a Roblox shop icon. Three-quarter front view, straight-on, object filling
> most of the frame with a small even margin. Vector-clean edges, no drop
> shadow, no ground shadow, no background panel, no frame, no border.

**Negative prompt** (use if the tool takes one):

> photorealistic, realistic, 3D render, ray tracing, gritty, rusty texture,
> noise, grain, sketch, painterly brush strokes, thin outlines, fine detail,
> text, letters, numbers, watermark, logo, drop shadow, background, panel,
> border, frame, multiple objects, cluttered composition, dull desaturated
> colours

**Output settings:** 1024×1024, square, transparent PNG. Upscale later if you
need it — do not generate non-square, the icon boxes are square and a wide image
gets letterboxed.

---

## The eight passes

Order matches `MonetizationConfig.PassOrder`, which is the order they appear in
the shop.

### 1. DoubleCash — "2x Cash Forever"

Accent: **Gold**, gradient `#FFE97A` → `#FFB300`

> Subject: a fat stack of three gold coins with a big glossy "×2" style sparkle
> star bursting off the top right, coins in warm yellow-gold gradient from
> #FFE97A down to #FFB300, one white highlight arc on the top coin.

### 2. StoragePlus — "Mega Storage"

Accent: **Cyan**, gradient `#21E5F5` → `#159ED9`

> Subject: a chunky open-topped storage crate seen from the front three-quarter,
> overflowing with rounded scrap chunks, crate body in bright cyan gradient from
> #21E5F5 down to #159ED9 with darker cyan slats, contents in light grey-blue.

### 3. FastCollector — "Turbo Collector"

Accent: **Blue**, gradient `#25B9FF` → `#167BE8`

> Subject: a bold rounded lightning bolt with two short curved speed streaks
> trailing behind it, bolt in vivid blue gradient from #25B9FF down to #167BE8
> with a white highlight along the leading edge, streaks in pale blue.

### 4. QuantumMagnet — "Quantum Magnet"

Accent: **Pink**, gradient `#FF5CC8` → `#E6237F`

> Subject: a classic horseshoe magnet standing upright, thick rounded arms,
> body in hot pink gradient from #FF5CC8 down to #E6237F with pale grey-white
> pole tips, two small four-point sparkles floating near the poles.

This is the shop's featured card, so it gets the most attention — generate a few
and pick the cleanest silhouette.

### 5. ExtraPetSlots — "+2 Pet Slots"

Accent: **Yellow**, gradient `#FFE539` → `#FFB600`

> Subject: a rounded cartoon paw print with a bold plus sign badge overlapping
> its lower right, paw in bright yellow gradient from #FFE539 down to #FFB600,
> plus badge in white with the same dark outline.

### 6. SingularityPet — "Singularity Pet"

Accent: **Cyan**, gradient `#49E0FF` → `#159ED9`

> Subject: a small round friendly blob creature made of swirling energy with two
> big simple eyes, a bright ring orbiting it at a tilt, body in electric cyan
> gradient from #49E0FF down to #159ED9, ring in white-cyan.

### 7. DemonicGhostPet — "Demonic Ghost Pet"

Accent: **Red**, gradient `#FF5757` → `#E62C37`

> Subject: a cute rounded cartoon ghost with a wavy bottom edge, two small
> curved horns and two big simple eyes, body in red gradient from #FF5757 down
> to #E62C37, faint lighter red glow inside the outline, friendly not scary.

### 8. SinisterLordPet — "Sinister Lord Pet"

Accent: **Purple**, gradient `#B530FF` → `#711CE8`

> Subject: a rounded cartoon creature head with a chunky simple crown, two big
> simple glowing eyes, body in purple gradient from #B530FF down to #711CE8,
> crown in gold #FFD21C, one soft violet highlight on the forehead. Regal and
> imposing but still cute and toy-like.

This is the most expensive pass in the game, so it should read as the loudest of
the eight — busier crown, stronger glow.

---

## Where the ids go

Pass art is looked up as `Assets.Art["pass:<PassId>"]` in
`src/shared/UI/Assets.luau`, using the exact ids above:

```lua
Assets.Art["pass:DoubleCash"] = "rbxassetid://0000000000"
Assets.Art["pass:StoragePlus"] = "rbxassetid://0000000000"
Assets.Art["pass:FastCollector"] = "rbxassetid://0000000000"
Assets.Art["pass:QuantumMagnet"] = "rbxassetid://0000000000"
Assets.Art["pass:ExtraPetSlots"] = "rbxassetid://0000000000"
Assets.Art["pass:SingularityPet"] = "rbxassetid://0000000000"
Assets.Art["pass:DemonicGhostPet"] = "rbxassetid://0000000000"
Assets.Art["pass:SinisterLordPet"] = "rbxassetid://0000000000"
```

The eight keys are already in `Assets.Art` as empty strings, and the path from
there to the card is wired: `GameData.passes()` reads
`Assets.imageId("pass", passId)` and `ShopScreen` forwards it as the card's
`image`. So pasting an id is the only step. An id you leave blank keeps the
procedural glyph, which means these can ship one at a time.

`PASS_STYLE` in `src/shared/UI/GameData.luau` now covers all eight. It used to
stop after the first five, so `SingularityPet`, `DemonicGhostPet` and
`SinisterLordPet` fell back to `{ glyph = "star", accent = "Blue", tier = 1 }`
and rendered as three identical blue star cards. They now carry the accents above
at tier 3, which is also what gives them the glow and sparkle treatment their
prices deserve.

## Notes for regenerating

- Keep the silhouettes distinct from each other. Coins, crate, bolt, magnet,
  paw are already unambiguous; the three pet passes are the risk, since blob,
  ghost and lord can converge on "round thing with eyes". If two look alike,
  push the shape language apart (wavy hem, orbiting ring, crown) rather than
  relying on colour to tell them apart.
- Reject anything with baked-in text. The card already renders the name, and a
  "2X" inside the art fights `Shop.Title`, which draws its own oversized lead
  token.
- Reject anything with a background panel or shadow. Cards supply their own
  well, gradient and outline; art that brings its own box looks pasted on.
- Check each one at 128 px before uploading. That is roughly the size the well
  renders at on desktop, and smaller on phone.
