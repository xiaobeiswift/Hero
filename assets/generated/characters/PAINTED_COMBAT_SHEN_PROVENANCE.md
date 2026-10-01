# Shen Qing combat-support art · 2026-10-01

Project-original painted support sheet for Hero · 渡灯录, generated using only the existing project-owned `painted_shen_directions.png` as a costume/direction reference. No third-party character, screenshot or stock artwork was used. Generated material does not imply guaranteed exclusive copyright.

Selected original PNG:1254×1254 RGBA, SHA256 `2b15acc90c8b1861dbaa42f42ca96e035ab737dd42406a15aa5a901602938144`. Selected output was left unchanged. Four full-body right-facing poses are idle, needle assist, protective cover and healing. A follow-up image-generation edge-cleanup experiment was not selected: pixel analysis showed the saturated edge pixels in the original were only alpha1–2/255, and actual Godot compositing confirmed they did not create the bright fringe shown by the inspection preview. No chroma-key or repaint was applied.

Blender transparent UV cards project measured quadrants at common source scale0.70, with foot anchor(224,470) inside each512px cell. The normalized1024×1024 runtime atlas is2×2, row-major in the order above. Default game cell156px keeps the supporting figure proportional to the protagonist. The source figure and pose remain painted; there is no claim of a skeletal animation or full combat cycle. Game timing chooses the relevant pose, with procedural needle travel/cover/healing feedback.

Runtime SHA256 `4b1eaa49b76f656c3ba1645eb7f0c6d2f28f8c437e00fafd44eab523f3b6ce2b`. All four atlas cells are pixel-identical to their corresponding Blender renders, and alpha16+ foreground pixels stay at least4px inside cell boundaries. Separate frame caches and fixed-foot transforms are regression-tested. Authoring scene, exact crop/foot manifest, source and rendering script are retained with the project authoring files; the repository ships only runtime resources and this provenance.

## Exact generation prompt

Use case: stylized-concept
Asset type: original transparent combat character key-pose sheet for the Chinese single-player RPG Hero / 渡灯录.
Input image: project-owned character reference only. It shows Shen Qing in four exploration directions; use the SECOND, right-facing view as the direction and costume reference. Do not copy its four-direction layout.
Create a square 2×2 sprite sheet, four full-body poses of THIS SAME adult female traveling physician Shen Qing. All four face screen RIGHT in the same restrained side-three-quarter camera used for a side-view duel. Preserve her ivory robe with sage edging, dark brown waist belt and medicine satchel on her anatomical left hip, dark tied hair with pale-green trailing ribbon, brown boots and calm determined adult face. Same slim proportions and painterly material style throughout.
Top left: relaxed but alert supporting stance, slightly bent knees, one hand at medicine pouch, other hand open forward.
Top right: short controlled forward cast of three tiny silver acupuncture needles toward screen right, clear extended right arm, grounded feet. Only the needles close to the fingers, no long effect trail.
Bottom left: protective brace, leading forearm raised across chest and the other palm extended forward; a supportive martial posture, NO shield or sword.
Bottom right: focused healing gesture, one small medicine vial held near chest, other open hand raised gently toward the ally to the right; subtle cloth movement, NO painted glow or particle effects.
Composition: exactly four isolated complete figures, one inside each equal square quadrant, wide transparent gutters of at least8% of each cell. Keep hair, cloth, hands, feet and tiny needles entirely inside each quadrant. Figures all use the same scale and foot baseline within each cell. Boots and fingertips must not touch image or cell borders. No cropped anatomy and no overlap between cells.
Style: detailed hand-painted wuxia game sprite, crisp readable cloth layers and natural anatomy, muted ivory/sage/umber matching reference, delicate dark contour and gentle directional highlights. Not a geometric doll, not glossy3D, not anime chibi.
True transparent background. No ground, shadows, frames, checkerboard, text, pose names, logos, scenery, other characters, swords, large weapons or UI.
