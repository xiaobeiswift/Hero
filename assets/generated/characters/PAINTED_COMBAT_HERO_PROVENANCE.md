# Hero combat key-pose artwork

Created 2026-10-01 for Hero · 渡灯录 using the built-in OpenAI image-generation tool. Input was the project-original painted exploration traveller sheet; no external game, artist, stock texture or model was referenced. The unchanged generated 1536×1024 RGBA source contains six distinct poses.

Blender orthographic transparent UV cards normalize all poses at one shared source scale, preserving shorter kneeling posture rather than stretching every pose to equal height. Measured polygon crops exclude neighboring sword/foot fragments where the source gutters are tight. The normalized atlas is 1536×1024, six 512px cells, shared foot anchor (224,470).

Poses: idle, anticipation, extended strike, guard, hurt recoil and nonfatal kneel. They are key poses rather than a fully articulated skeletal animation. Existing choreography must supply motion and timings; helper validation alone does not establish native battle integration. At this asset checkpoint, live combat still uses its prior renderer.

Every normalized cell matches its standalone Blender render; meaningful alpha stays inside four-pixel borders. Images and code define appearance only, never game damage or saves. Originality is project-directed generation, not a claim of exclusive rights or absence of all resemblance. Applicable service terms and distribution-platform disclosure requirements still apply.

Source SHA-256: `784f4b9234e703de5b475f77a1781b1c1a45f2117cbdf64e2d81a9ca05b3867c`

Runtime SHA-256: `a658ddb8ffd62dc110482b553241450481b7df38dbf58ab91f792eb04cf4290c`

## Exact generation prompt

Use case: stylized-concept
Asset type: original 2D battle-character sprite sheet for the offline Chinese wuxia RPG Hero / 渡灯录.
Input image role: character identity and costume reference only. It is the project's own exploration hero sheet; create NEW combat poses, not more walking frames.
Subject: the same adult young male swordsman, lean natural adult proportions, dark tied-back hair, teal scarf and layered weathered teal-grey robe, cream cuffs, leather belt and boots. Preserve his face, clothing colors and costume construction. His sword is now drawn, so the back scabbard must be empty rather than showing a second sword hilt.
Composition: one transparent 3-column by 2-row sprite sheet, six SEPARATE full-body cutouts. All six face SCREEN RIGHT in readable three-quarter side view. Wide transparent gutters between cells, full weapons and boots comfortably inside each cell. No text, grid lines, ground patches, shadows, borders or effects.
Pose order left to right:
TOP LEFT: poised idle, balanced bent-knee stance, sword held low ahead in right hand, left hand loosely raised.
TOP CENTER: clear attack anticipation, weight on rear left foot, right arm draws sword back above shoulder, torso coils, scarf trailing left.
TOP RIGHT: fully extended forward lunge and horizontal sword cut, right arm reaches screen right, front knee bent and rear leg extended. Sword blade continuous and straight.
BOTTOM LEFT: defensive guard, sword held diagonally upright in front of chest, composed stance, both arms anatomically clear.
BOTTOM CENTER: hit reaction, torso leans backward, one hand to ribs, sword lowered, no blood and no injury detail.
BOTTOM RIGHT: nonfatal defeated kneel, one knee down, head bowed, sword tip resting near ground at right.
Style: finely painted game character materials with crisp readable silhouettes, restrained warm edge light and soft ink outlines, matching the original reference. Practical fabric folds and leather details, not a glossy 3D mannequin, not chibi.
Constraints: same character identity in all six cells; six different action silhouettes; exactly two arms and two legs each; clean single sword per pose; genuine transparent background; no cropped swords, feet or hair. This is gameplay sprite art, not a poster.

