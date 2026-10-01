# Original painted traveler provenance

Created 2026-10-01 for Hero · 渡灯录.

The runtime sheet `painted_traveler_walk.png` is a deterministic Blender render of an original painted 2D cutout rig. Its source texture `source/painted_pose_reference.png` was generated using OpenAI's built-in image generation tool. It has not been modified destructively. The mesh-card render/animation source is retained in the authoring workspace as Python and an editable Blender scene. This initial runtime package includes the rendered sprite sheet and its Godot helper; it does not yet include all authoring intermediates.

Source lineage:
1. Existing project-original teal traveler portrait in `Hero/assets/generated/characters/hero-character-portraits-atlas.png`, top-left only, provided visual identity.
2. A text-and-identity-referenced four-direction sheet and one corrective pass established costume and direction views, but did not produce reliable alternating gait. These are candidate/reference art only.
3. An original geometric Blender model and inverse-kinematic walk produced the pose-control reference. The model was authored locally from primitives, custom cloth meshes, curves and procedural materials; no downloaded model, texture or rig was used.
4. The following imagegen pass produced the final source texture using only the project's own pose-control and candidate images.
5. Blender textured-card rendering uses selected body and boot UV regions. Independent boot transforms create alternating contact/passing poses; source pixels remain intact. The sprite atlas contains those rendered frames.

No existing game's artwork, external character reference, stock imagery or outside model was introduced. Original generated source art is governed by applicable OpenAI service terms. This note does not claim exclusive copyright or grant additional legal rights. The project-authored Blender scripts and models introduce no external asset license.

## Complete final source-image prompt

Use case: style-transfer with strict pose preservation. IMAGE1 is the EDIT TARGET and authoritative animation pose/layout guide: an original 1024×1024 4x4 sprite sheet from a rig. IMAGE2 is STYLE AND COSTUME REFERENCE ONLY; DO NOT COPY ITS POSES. Transform only the stiff simplified model appearance in IMAGE1 into the rich painterly young adult Chinese wuxia traveler from IMAGE2, with teal woven cloak/scarf, charcoal layered robe and trousers, flax waist ties, weathered wrapped boots, tied loose dark hair, warm skin, sword sheathed diagonally behind and small pack. Paint convincing cloth folds, natural face, hands and loose hair; remove the plastic tube/ball/jointed mannequin appearance. Preserve IMAGE1's EXACT 4x4 grid, positions, body size, head positions, shin and foot placements, arm poses, camera angle, row directions and transparent gutters. Keep all sixteen silhouettes fully isolated. The images in columns1 and3 MUST retain the OPPOSITE leading foot from IMAGE1; columns2 and4 retain its lifted passing feet. Do not revert to a repeated same-foot pose. Keep the lower legs visible enough to distinguish these phases, matching the pose guide. Row1 faces front, row2 faces right, row3 faces back, row4 faces left. Thin adult proportions around6.5heads tall, no chibi. Hand-painted ink-and-gouache game sprites with crisp readable contours, subtly worn teal cloth and soft warm light, premium 2D wuxia art matching painted Chinese village buildings. No photorealism or smooth plastic 3D. Output exactly1024x1024 with genuine transparent alpha, no floor, cast shadows, background, text, outlines of boxes, labels or UI. This pass changes visual finish and cloth richness only; the pose guide's grounded walking contacts and fixed locations are mandatory invariants.

## Actual source-output caveat

The tool returned 1254 × 1254 RGBA and again failed the strict front/back gait invariants. Therefore, the generated grid is NOT used as an animation sheet. It serves solely as painted texture input to the supplied deterministic cutout rig. The final runtime animation dimensions and anchors are established by Blender, not inferred from the generated grid.


## Runtime integration limits

The exploration protagonist uses the painted four-direction walk. Other NPCs, companions and battle figures retain the articulated vector style at this checkpoint. Upper-body motion is restrained and side-view robe/calf joins still need polish. No new story, collision, save field or combat rule is introduced by this art integration.
