# Qin He original exploration animation

Generated 2026-10-02, with review corrections on 2026-10-03, using the built-in image-generation tool. Identity inputs were this project's original Qin combat sheet and only the bottom-right Qin portrait in the original portrait atlas. No third-party game, photograph, franchise character or licensed stock art was used. The existing portrait and combat provenance and generated-art rights limitations remain applicable; do not assert copyright exclusivity or a separate third-party license.

## Runtime scope

Four separately authored RGBA direction sheets contain four distinct walking keys each, 16 authored keys total. These are not eight-frame sheets, mirrored left/right art, rigged cutouts, copies moved up/down, or code-repainted feet. Front/back runtime order is source 0,3,2,1; side order is 0,1,2,3. The two opposite contact poses and two passing poses were reviewed anatomically as well as in a native Godot fixture. A separate neutral idle source is used when stopped; a wide contact walking key is not a standing animation.

The runtime PNGs are byte-for-byte copies of the selected generated originals. The renderer crops with individually measured rectangles, preserves alpha, applies fixed uniform scale, and uses transparent logical-canvas margins to register a fixed foot anchor. It neither warps nor repaints the artwork. A naïve 2x2 grid would clip some wide side strides. No gameplay position, collision, formation or save state lives in the renderer.

- Logical canvas: 672x672, foot anchor (336,633)
- Existing party convention: 72px logical cell, approximately 62–65px visible character height, not a claim of 72 opaque pixels
- Body-height/cloth differences are preserved rather than per-frame scale-fitted
- Frame/crop/alpha bounds and original SHA256 values: accompanying QA measurement record
- Every visible source crop edge has alpha at most 16/255, with 8 source pixels of antialias padding

## Selected unchanged generated sources

- Front: `generated_images/exec-700e8659-20f0-4904-bc29-13671857c889.png`; runtime `painted_qin_walk_front.png`; SHA256 `fae899d2b07d0835fa82fdba3b4e57be32af01a14d5c7a3cfed43fc5ce868a10`
- Right: `generated_images/exec-b6868dfd-af52-4417-9e55-d3fa830a222d.png`; runtime `painted_qin_walk_right.png`; SHA256 `c169430ad445e64e91cbf91ce270ecd3261d93218c08ead04c7de6bcce7bfa34`
- Back: `generated_images/exec-e661271f-b7d7-4541-be83-72ab3d737e07.png`; runtime `painted_qin_walk_back.png`; SHA256 `b91246dcd0a0a25e0243266d0c295d28410b62b4bc5dd577ed8c3f7744aafe75`
- Left: `generated_images/exec-42e3ede9-8089-497f-9dc1-d7cd8e041be3.png`; runtime `painted_qin_walk_left.png`; SHA256 `71c682709adc546bd3a87aefc0b04f958073d0909af4151dc56ac269b41b9479`

Each sheet is 1254x1254 RGBA. The four originals and exact retained prompts should accompany source delivery. Earlier 32-frame attempts are retained as rejected evidence, not runtime assets. Review-specific rejected generations include ambiguous right leg overlap/cream-trouser drift and an excessive rear-foot running kick. The accepted final side cycle fixes the right backward near-thigh overlap and low rear passing lift. Left frame1's shortened staff was extended by imagegen; the left PNG was never extended programmatically.

## Exact prompts and provenance chain

Retain `QIN_WALK_GENERATION_PROMPTS.json` with this record. Its named sections preserve verbatim four-phase, review, passing-refinement, opposite-contact and idle generation/edit prompts. `evidence/source-original-matches.json` links generated originals to runtime SHA256. Initial rejected 32-cell prompt history remains in `generation-prompts.json` for audit; it is not an accepted walk cycle.

## Visual limits

This is a four-key painted cycle with deliberate visible leg changes. Four keys are more abrupt than an eight-key or full skeletal animation; no interpolation is claimed. Front passing knees are high, close to a marching walk. Hair/robe/face detail can drift slightly between authored keys, and the left opposite-contact torso turns somewhat more toward camera. Staff hand and anatomical equipment sides are preserved. Very faint generated alpha/color flecks remain at outlines; native 72px tests on dark green are required, and in-world background review remains separate. These limits must remain visible in test/release notes rather than described as a fully rigged gait.

## Neutral standing poses

The separate standing sheet is `painted_qin_idle.png` (1254x1254 RGBA), SHA256 `749e88b29f79d0ba485b74fb2748af8a7f53dc9c5b922b52448d982d7a76bc3d`. It is an unchanged copy of `generated_images/exec-3d64447e-0204-4146-a18d-7a5fa835f2e2.png`. Exact generation and accessory-correction prompts are in the `idle` section of `QIN_WALK_GENERATION_PROMPTS.json` (the separate `generation-record-idle.json` is also retained). Actual source quadrants are front0, left1, back2, right3, regardless of initial prompt order. Both boots are planted near one another in all views, with staff in anatomical right hand and tool pouch on anatomical left hip.

Idle uses the same672 logical cell/foot anchor and a fixed1.125 optical-size normalization, because its generated body is526–537 source pixels versus approximately600 in the walking sources. This is one uniform idle-only draw scale, not a per-frame size fit, raster rewrite, bob or walking substitute. Independent alpha/bounds metadata is in `evidence/idle-measurements.json`. Idle back backpack remains more rectangular and rope-framed than the walking satchel. This is a documented detail-continuity limit, not a gait or ownership claim; no extra cosmetic generation is required for current acceptance.

## Final native acceptance

Accepted 2026-10-03 after independent lead review of all four72px/216px keys and stopped transition frame10. Native fixture produced28PNG captures, including24walk/stop/restart samples; no engine ERROR. Both four-frame idle holds have exactly identical character pixels, excluding changing header text. Headless renderer assertions passed. This validates staged artwork/renderer only; final in-world integration and packaged export checks remain required.

Numeric/crop/alpha measurements and the final native QA manifest are retained under `tests/art_authoring/qin_exploration/` in the source repository. Rejected image attempts remain development evidence and are not shipped.
