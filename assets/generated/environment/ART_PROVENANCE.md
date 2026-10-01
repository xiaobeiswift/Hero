# Original Qingwei gameplay environment art

## Deliverable

- File: `qingwei_environment_atlas.png`
- Created: 2026-10-01 using OpenAI built-in image generation; not API/CLI fallback
- Dimensions: 1536 × 1024 pixels, RGBA PNG, 8 bits per channel
- Purpose: actual in-world buildings and foliage in the playable Qingwei Ferry map
- Contents: apothecary, tea house, inn, training hall, wayside shrine, gnarled willow
- Inputs: the initial generation used text only. One subsequent layout-refinement edit used only that original generated image. No existing game's image, stock texture, outside reference, or third-party character was used.
- SHA-256: `61ee9b4894ae503b14ed175ab9bc252025b1dda32e0635b60e52f9b285aae3d9`
- The selected PNG is unchanged from the generation tool. Cropping/scaling is done at runtime by Godot's `AtlasTexture`; no destructive raster edits were made.
- Provenance: AI-generated original project art. No separate third-party stock/asset license was introduced. Applicable OpenAI service terms govern use. This record does not claim exclusive copyright or grant additional legal rights.

## Important integration facts

The generator did not precisely honor the requested equal-cell packing. Use the measured rectangles in `qingwei_environment_art.gd` or `atlas_manifest.json`, **not** an assumed equal 3 × 2 split. These rectangles keep complete silhouettes separate; source regions have at least a few transparent edge pixels. The source has real transparency despite some image viewers showing the RGB data of transparent pixels as a blurred backdrop. Sample corner alpha is 0 and foreground alpha reaches 254/255.

Building collision remains the existing base rectangle, including any existing collision margin. The art helper aligns the existing bottom-center door threshold with the source doorway; decorative roofs extend farther upward. Keep the current building y-sort key `pos.y + size.y`. Do not use sprite dimensions to change collisions or walkable geometry. Render Chinese names separately with the shipped font; the source plaques are intentionally blank. Existing animated water, lantern light, particles, player movement, interactables and map logic stay procedural.

The willow root anchor is the existing tree foot. Use the tree inside the existing sorted tree layer. A 132 px wide draw produces roughly 126 px height at scale 1. The helper is optional and has a clean fallback: unrecognized building types return false.

## Full initial generation prompt

Use case: stylized-concept. Asset type: production-ready TRANSPARENT 2D gameplay environment sprite atlas for an original Chinese wuxia RPG set in Qingwei Ferry (青苇渡). Create one 1536 by 1024 PNG, exactly three equal columns and two equal rows, six 512x512 cells. Each subject is entirely isolated within its own cell with generous 30px transparent margins; no visible grid, labels, typography, background, ground terrain, scenery, UI, watermark or characters. Every building faces directly toward the bottom of the image, horizontally aligned front facade, a modest elevated orthographic 2.5D game camera so broad roof surfaces are visible, zero vanishing point perspective, consistent lighting from upper left, no isometric rotation. Harmonious premium hand-painted Chinese ink-and-gouache style, subtly textured individual ceramic roof tiles, weathered ivory plaster, dark warm timber, sage moss, petrol-teal roofs, small amber paper lanterns, intricate but readable silhouettes and confident sculptural light. Crisp clean external alpha edges, no hazy wash outside shapes. Five DISTINCT humble late-imperial riverside-village buildings, similar width and not palaces. Each building width about 450px, front doorstep baseline around y=440 in its cell, topmost roof ridge around y=110, with a subtle short contact shadow beneath. Top-left: small single-storey apothecary, low hipped dark tile roof, medicinal herb baskets, lattice windows, double wooden central door, a plain BLANK wooden plaque above door. Top-middle: inviting tea house with curved layered roof, asymmetrical small front awning and teaware on one side, central double door, plain blank plaque. Top-right: village inn, slightly taller broad single-storey hall, handsome curved roof, worn timber posts and broad three-step doorstep, plain blank plaque. Bottom-left: martial training hall, simple sturdy open central entrance with dark interior, spare weapon rack beside it, roof and wall silhouette clearly readable, blank plaque. Bottom-middle: small old wayside shrine, compact pavilion-like shrine facade with stone plinth, mossed dark tiles, incense vessel and plain blank plaque, no deities or people. Bottom-right: one beautiful mature gnarled willow tree, entire crown, trunk, roots and a subtle short contact shadow within its cell, drooping clusters of elegant narrow sage-green leaves, dense sculptural foliage lit by warm diffuse afternoon light; trunk foot around cell y=450 and crown top y=55. The tree is in the same painterly game-art style. These are game objects to be drawn over a walkable level, not an illustrated poster or concept scene. Objects must remain disjoint with transparent gutters. Original designs only, no existing game's artwork or recognizable borrowed designs.

## Full selected refinement prompt

Use case: precise-object-edit. This image is a production game sprite atlas. Keep the SAME six original subjects, style, materials, colors, lighting, details, front-facing perspective and overall design. Change ONLY their size and placement to make six perfectly separated usable game sprites on true alpha transparency. Output EXACTLY 1536x1024. Layout is 3 columns × 2 rows of 512x512 cells. Every subject must fit STRICTLY inside its cell, including shadow, cloth and roof tips, with AT LEAST 40 transparent pixels on all four sides. Shrink each full subject uniformly as needed without cropping or distortion. First row clinic, tea house, inn. Second row martial hall, shrine, willow. No object crosses x=512, x=1024 or y=512; those gutters must be entirely transparent. Building front doorstep at local cell y=438; willow root at local cell y=448. Maintain alpha transparency; DO NOT paint a colored, blurred, black, checkerboard or neutral background, and remove all ambient backdrop haze. Preserve every subject's existing identity and blank signs. No text, grid, frames, UI or labels.

## Verification completed

- Inspected the source pixels through the image viewer
- Verified PNG dimensions, RGBA mode, alpha extrema and source region boundary pixels
- Verified unchanged SHA-256 after staging
- Godot 4.6.3 headless editor import and GDScript parsing completed without errors using isolated writable QA directories
- Runtime-size HTML preview and Godot preview source are included for integration review. Native screenshot capture in the staging environment was blocked because the executor had no display server; installed Chromium also could not create sockets. Capture the actual game through its existing graphical route before marking integration visually approved.

- Focused Godot asset test passed: six textures load, all five doorway anchors remain fixed, all five plaques remain within their visual rectangles, and aspect ratios are preserved. Test source: `preview/environment_asset_test.gd`.
