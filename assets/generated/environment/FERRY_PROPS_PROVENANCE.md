# Qingwei deck and moored skiff · 2026-10-01

Two original text-to-image assets made for Hero · 渡灯录 using the built-in image-generation tool. No reference images, third-party game art, stock textures or photographs were supplied. Generated material is not a guarantee of exclusive copyright. Both generated PNG files are copied unchanged.

- qingwei_deck_wood.png: 1254×1254, RGB, SHA256 `b92b3410e9597c741c1afe85990b3a980598306f49961eaaa65bf24e7c6304c0`
- qingwei_moored_skiff.png: 1774×887, RGBA, SHA256 `b39001516e12031cc6e7f785cd9994a7d6442c24ed0d178c7f50d401ddffa837`

The wood material samples an aspect-preserved central region onto the original fishing-pier117×34 and ferry184×65 deck rectangles. It does not change their collision or traversal. Existing posts, mooring rope and fishing rod remain their original geometry. The skiff uses a measured alpha crop(51,205,1693,498), with a small transparent gutter and preserved aspect at110world-pixel width, centered at(1540,831). It is decorative and remains in non-walkable river. Texture and deck geometry are cached; source pixels are not repainted. This pass replaces the two deck surfaces and skiff only, not every village prop.

## Exact wood prompt

Use case: stylized-concept
Asset type: original opaque overhead wooden decking material texture for Hero / 渡灯录, a hand-painted Chinese wuxia RPG.
Create a square image filled edge to edge with about16 parallel narrow timber planks running vertically from top to bottom. Weathered river-jetty wood in muted warm umber, aged ochre and grey-brown, with delicate grain, worn corners, fine cracks and a few understated dark iron nail heads. All boards lie on the SAME flat horizontal plane, viewed directly from above.
Detailed painterly game texture with slightly ink-like dark seams, coherent with painted old Chinese village buildings, not a photo or glossy3D rendering. Moderate-low contrast, even soft daylight, no strong spotlight, no cast shadows from outside objects.
Only continuous timber boards. No railings, posts, rope, boats, water, people, plants, labels, text, border or UI. Do not paint the outer edge of a platform: this is a material that the game clips to exact pier shapes. Opaque background.

## Exact skiff prompt

Use case: stylized-concept
Asset type: isolated transparent original small wooden ferry SKIFF sprite for Hero / 渡灯录.
A single modest traditional wooden river skiff, empty, viewed from the same elevated oblique three-quarter angle as a2D top-down Chinese wuxia village. Long axis almost horizontal, bow pointing screen RIGHT and slightly upward. Slim pointed bow, curved weathered timber hull, visible interior ribs and two crosswise bench seats, one plain wooden oar laid inside, small coil of rope near the stern. No sail, cabin, canopy, people, animals or cargo.
Detailed hand-painted game illustration with natural timber grain and dark ink-like edge definition, muted warm ochre/umber and grey-brown, softly lit in daylight. Match old painted village architecture. Full complete boat including bow/stern with generous transparent padding. The boat should occupy about80% of image width and45% of image height, with a wide shallow silhouette.
True transparent background. No water, land, reflection, ground shadow, text, numbers, logos, frames, checkerboard or UI. Original generic fictional village craft, no reference to any existing game.
