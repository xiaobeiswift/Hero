# Qingwei moss and earth ground material

- File: `qingwei_moss_earth.png`
- Created: 2026-10-01 with OpenAI built-in image generation, text-only input
- Actual dimensions: 1254 × 1254 pixels; RGB PNG
- SHA-256: `4527c951ae405bfbff2e2ec8867f073ba80dee71ae205a3b54cfb20a82793278`
- Original project art; no third-party reference image or existing game's assets were used. No additional stock license was introduced. Use is governed by applicable OpenAI service terms; this note does not claim exclusive copyright.
- Source PNG remains byte-for-byte unchanged. Tile transforms and tint/opacity, if any, belong in runtime rendering.

## Important integration note

The prompt requested a seamless tile. Pixel inspection shows the generated material is low-contrast but **not mathematically seamless**: average opposite-edge RGB difference is approximately 14/255, versus 8–9/255 for neighboring interior pixels. Do not rely on ordinary repeat as a perfect seam match. Use mirrored-repeat tiles or a single aspect-filled ground patch. This retains the original source and avoids visible color jumps. Suggested first integration: 512–640 world-pixel mirrored tiles at 0.35–0.45 opacity over the existing pale sage ground, below paths, water and structures. Retain road boundaries and geometry; this is not a whole map.

Mean RGB is approximately (152,149,110); channel standard deviations are approximately (17.5,16.9,16.6). The intended role is subtle material detail beneath readable gameplay silhouettes. Reduce opacity if the soil competes with grass, paths or characters.

## Complete generation prompt

Use case: stylized-concept. Asset type: SEAMLESS TILEABLE overhead terrain texture for the ground of an original Chinese riverside wuxia 2D game. Produce a square 1024x1024 image. Paint only a continuous subtle mixture of softly compacted warm grey-ochre earth, pale muted sage moss and tiny scattered weathered grey pebbles. Straight top-down orthographic overhead view, no horizon, no perspective, no directional cast shadows, no lighting gradients, no vignette. The TOP and BOTTOM edges, and LEFT and RIGHT edges, must match naturally for invisible repeated tiling. The overall ground is a restrained mid-light muted sage/ochre, near color #a6b292; low saturation, low contrast, no black or white. Moss appears as delicate irregular low clusters mixed into earth, not large separate round islands. Very fine painterly gouache and subtle stone/earth microtexture, aesthetically compatible with hand-painted old Chinese timber buildings and dark teal roof tiles. Texture scale: tiny pebbles no larger than 5–12 pixels across, sparse tiny dry grass blades under 15px. Keep the central and edge areas all equally neutral; no focal points or recognizable repeated landmarks, no large rocks, bushes, plants, flowers, roots, logs, leaves, water, buildings, paths, paving, cracks, borders, symbols, grids, lettering, UI, people or objects. Make it a production terrain material swatch, not an illustration of a landscape, photograph of a landscape, or map. Original project artwork.
