# Pu Heng combat artwork provenance

Created 2026-10-01 for Hero · 渡灯录 with the built-in OpenAI image-generation tool. References were only the project-original Pu Heng village artwork and the project's painted hero combat sheet, the latter used for camera and rendering style.

Three outputs were retained in the authoring workspace: the first faced the wrong direction; the second corrected direction but clipped a rear boot; the third corrected full-body containment and removed the duplicate sheathed hilt. Only the final left-facing sheet is selected. No horizontal mirroring is used in its gameplay rendering.

The generator did not honor perfectly separated equal cells. Blender transparent UV cards use measured, padded alpha-connected row outlines to prevent neighboring blade fragments from entering a crop. The source PNG remains unchanged. All six poses share one projection scale; kneeling posture stays shorter. The normalized atlas is 1536×1024 RGBA with six 512px cells and foot anchor (300,470). Each cell matches its standalone Blender render and retains transparent outer margins.

This sprite is selected only for Pu Heng's named story and sparring encounters. It is not a generic replacement for other characters. These are painted key poses driven by the existing choreography, not a complete skeletal animation. No new damage rules or saves are introduced.

Original project-directed generation does not promise exclusive rights or absence of every resemblance. No external game artwork, stock model, additional account or paid service was used. Existing service terms and future distribution requirements still apply.

## Exact prompts

### Pass 1

Use case: stylized-concept
Asset type: six-pose transparent 2D combat sprite sheet for the original offline RPG Hero / 渡灯录.
Input reference 1 defines ONLY Pu Heng's identity and clothes: adult river-ferry swordsman, weathered straw hat, short moustache and goatee, russet-brown layered robe with ochre trim, cream cuffs, rope waist and worn boots.
Input reference 2 defines the painted combat rendering, camera and six action silhouettes. Do not copy that reference character's face or teal clothing.
Create NEW Pu Heng combat poses, facing SCREEN LEFT in all six cells. Keep the same mature face, straw hat and russet/ochre costume throughout. Draw one practical single-edged sword held in the right hand; his belt scabbard is EMPTY, no second hilt or duplicated weapon.
Layout: 3 columns by 2 rows, six independent full-body cutouts. Each entire character and sword must fit within its own cell with wide transparent gutters and at least32pixels margin. No overlapping neighboring poses, no cropped sword tips or boots, no labels, grid, background, floor, shadow or painted glow.
Order:
TOP LEFT idle: balanced broad stance, right hand holds blade low toward the left, free hand ready.
TOP CENTER anticipation: weight shifts back to the screen-right leg; sword raised behind the shoulder for a cut to the left; full blade visible.
TOP RIGHT strike: fully extended leftward lunging cut, leftmost blade continuous and clear, front knee bent, rear leg stretched to the right.
BOTTOM LEFT guard: sword diagonally upright before the chest, clear hands and stable stance.
BOTTOM CENTER hurt: recoil leaning back toward screen right, free hand to ribs, blade lowered; no blood or wound detail.
BOTTOM RIGHT nonfatal defeat: kneeling on one knee, head bowed, sword tip resting low at screen left.
Style: detailed painterly material surfaces, natural adult proportions, soft ink contours and restrained edge highlights matching reference2. Readable at about160px character height. NOT chibi, not a geometric puppet, not glossy3D.
Genuine transparent RGBA background. Exactly two arms and two legs per pose; preserve the straw hat rather than changing to a hero topknot.

### Pass 2

Edit the supplied Pu Heng six-pose combat sheet. Preserve the same adult face, straw hat, russet/ochre clothing, painting detail and six distinct poses, but FIX DIRECTION: every man must face and attack toward SCREEN LEFT, with his face and nose pointing LEFT. Current sheet wrongly faces right. Keep the 3-column by2-row layout in the same pose order: idle, windup, lunge; guard, hurt, kneeling defeat. Re-pose each man as a proper left-facing anatomical view, not a horizontal flip of the whole sheet. Keep right-handed sword use, empty belt scabbard, clear full weapons/feet, wide gaps between separate poses. No text, effects, vignette, ground or background; genuine transparent RGBA. The main functional requirement is LEFT-FACING enemies for the right side of the combat stage.

### Pass 3

Fix sprite-sheet packing only. Keep these same six LEFT-FACING Pu Heng poses, exact face/straw hat/russet costume, anatomy and paint style. Each pose must sit fully INSIDE its own cell in a3-column by2-row grid, with at least40pixels of totally transparent gutter on every cell edge. Shrink the cutouts inside the cells enough that every sword tip, hair and especially the far-right rear boot of the TOP-RIGHT lunge is completely visible with empty margin. Nothing may cross into a neighboring cell. Preserve pose order and LEFT-facing direction. Remove the extra small sword hilt protruding from the belt scabbard; the sheath is empty because his single sword is in his hand. No text, lines, floor or backdrop, genuine alpha transparency. Do not crop or cut away body parts to make margins.


Source SHA-256: `403569f57898a8d5bdefe243039dd2e8c0741b37dbb39154a8abb63439fcf3fd`

Runtime SHA-256: `aa837f09eb48aa356c0f329614423dff1be69626c4d6b559b912d5f43cfb1bfb`
