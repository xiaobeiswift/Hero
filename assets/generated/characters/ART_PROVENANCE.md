# Hero character portrait atlas: art provenance

## Deliverable

- File: `hero-character-portraits-atlas.png`
- Created: 2026-10-01
- Intended use: Hero offline Chinese wuxia RPG character UI
- Method: OpenAI built-in image-generation tool, with a composition-only generated revision
- Canvas: 1254 × 1254 pixels, PNG RGBA
- Runtime cells: four equal 627 × 627 pixel AtlasTexture regions, no image transformation required
- Cell order:
  - Top-left, Rect2(0, 0, 627, 627): 无名客
  - Top-right, Rect2(627, 0, 627, 627): 沈青
  - Bottom-left, Rect2(0, 627, 627, 627): 唐栖
  - Bottom-right, Rect2(627, 627, 627, 627): 秦禾

## Originality and source record

The initial image was generated from the written brief below without an external reference image. No artwork from another game, specific copyrighted character, celebrity, or named artist was supplied or requested. The second tool call used only that first original generated image to improve quadrant spacing. No purchased assets, accounts, or outside uploads were used. The selected PNG was copied without raster edits; its original alpha is preserved.

This records how the image was made, rather than guaranteeing exclusive rights or that every generated feature is unlike all existing art. Before commercial publication, review the target storefront's then-current AI-content disclosure rules and applicable terms, as well as the final artwork for unwanted similarities. This prototype artifact does not itself establish legal clearance.

## Visual and pixel QA

Inspected the actual selected PNG, its channels, and its mathematical quadrant boundaries.

- All four requested characters are present in the requested order with their clothing colors and readable facial expressions
- Transparent background: 60.12% of all pixels have exactly zero alpha; the file has a genuine alpha channel, not an opaque checkerboard
- No text, borders, logos, grid lines, or ornamental background
- All meaningful painted silhouettes remain within their quadrant
- At alpha > 8/255, empty margins in each cell (left, top, right, bottom pixels):
  - 无名客: 106, 93, 96, 49
  - 沈青: 93, 99, 92, 45
  - 唐栖: 79, 45, 39, 80
  - 秦禾: 91, 72, 61, 81
- No meaningful-alpha figure pixels touch either center cut. The four-pixel-wide horizontal center band is completely zero-alpha
- The vertical four-pixel-wide center band contains three extremely faint generated pixels; these are outside the meaningful silhouette and do not clip a character
- Generated output retains a small amount of alpha 1–2/255 color noise around some edges. Some raw-image viewers exaggerate these near-transparent red/yellow specks; normal alpha compositing makes them effectively invisible. No raster cleanup was applied
- Parent project should inspect at actual 100px UI scale and desired background as part of runtime QA. Faces are deliberately high contrast; individual accessory details will be subtle at that scale

## Initial generation prompt

Use case: stylized-concept.
Asset type: original four-character portrait atlas for Hero, an offline Chinese wuxia RPG, to be divided at runtime into four equal square AtlasTexture cells.
Create one square 2-by-2 atlas on a genuinely transparent alpha background. No text, labels, letters, borders, grid lines, logos, or watermarks. No ornamental background and no painted paper rectangle. Only four isolated bust-and-shoulder figures, one fully inside each quadrant, with comfortable transparent margins on all four sides of each cell. Equal figure scale and visual weight. Each face must read clearly when its individual cell is displayed at 100px. No figure or accessory may touch or cross a cell boundary. Position figure centers at 25%/25%, 75%/25%, 25%/75%, 75%/75% of canvas. Keep each portrait inside the middle 82% of its quadrant; silhouettes gently end within the cell.
Top left: 无名客, an adult androgynous traveller around age 30, tied dark hair, teal travelling robe, alert and quietly determined, practical unadorned travelling clothing.
Top right: 沈青, adult woman healer around age 30, ivory and sage robe, calm alert expression, a subtle medicine satchel strap or jade scarf.
Bottom left: 唐栖, adult man craftsman around age 30, slate and sage practical clothes, short wooden measuring ruler and subtle tool pouch, thoughtful face.
Bottom right: 秦禾, adult woman former water recorder around age 40, muted olive robe, holding a folded oil-paper umbrella or bamboo tally, composed expression.
Visual language: refined hand-painted ink-and-gouache Chinese adventure character art. Warm rice-paper tones in the figures themselves, restrained teal and ochre, delicate but decisive brush lines, expressive clear faces and natural adult proportions. Consistent bust/shoulders framing and medium-detail readable clothing. Original designs, no reference-game artwork, no copied characters, no named-artist imitation. Not chibi, not photorealistic. Strong clean character silhouettes on actual transparency.

## Composition revision prompt

Edit target: the supplied original Hero portrait atlas. Use case: compositing.
Change only composition, spacing, and technical cutout cleanliness. Keep the exact four original character identities, clothing, props, expressions, ink-and-gouache illustration style, and order: androgynous teal traveller upper left; ivory/sage woman healer upper right; slate/sage man craftsman lower left; muted olive mature woman recorder lower right.
Create a square canvas with four equal invisible square quadrants. Reduce EACH complete figure uniformly to 72% of its current size and center it in its respective quadrant. All four bust silhouettes must be FULLY contained within their own quadrant, with at least 10% of cell width of completely transparent empty margin on every side. The middle horizontal and vertical gaps must be wide, completely empty and transparent; no stray brush strokes or colored specks in those gaps. The bottom-left portrait's hair must not enter top-left cell; the bottom-left shoulder must not enter bottom-right cell. No cut-off shoulders or accessories. This is an atlas for four exact mathematical 50% cuts, so spacing is essential. Do not draw visible quadrants or grid lines.
Genuinely transparent alpha background, opaque painted figures with only delicate antialiasing at their outer edges. No colored fringe, no ornamental background, no paper rectangle, no text, labels, borders, frames, watermark, logos, or added content. Preserve natural adult proportions.

## Generation source files

- Initial, not selected: `generated_images/exec-424d07c2-ca9b-44c9-b64d-780ef34debac.png`
- Selected composition revision: `generated_images/exec-23e0a974-8746-4c6e-b326-642b06aa949e.png`
- Both calls requested `transparent_background: true`

