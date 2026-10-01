# Shen Qing travelling animation

Created 2026-10-01 for Hero · 渡灯录. The unchanged original Shen four-direction image-generation source is the selected v2 described in [PAINTED_VILLAGE_PROVENANCE.md](PAINTED_VILLAGE_PROVENANCE.md). Its prompts, project-only references and rights limitations continue to apply. No new external artwork, stock asset, model or service was introduced.

The existing painted robe/satchel and separately sampled boots are mapped to transparent Blender mesh cards. A deterministic eight-frame contact cycle independently moves the two boots, with a small torso bob. Four authored directional views are preserved without whole-character mirroring; the medicine satchel remains on the anatomical left side.

Runtime atlas: 2048×1024 RGBA, eight columns and four rows (front/right/back/left), 256px cells and foot anchor (128,241). One cached atlas crop is drawn per follower frame. The artwork does not move the character, change collision, formation, saves or combat outcomes.

All 32 rendered cells match their source frames exactly, retain transparent four-pixel borders and have distinct opposed contact poses. This is a painted cutout walk pass, with restrained upper-body motion, not a full skeletal cloth/arm animation. Tang Qi and battle actors retain their previous renderer. The village Shen idle sheet remains a separate idle-only asset.

Authoring inputs, polygon UV definitions, renderer, editable Blender scene and pixel measurements are retained in the project authoring workspace. The runtime helper and atlas are the files required by the game.

Runtime atlas SHA-256: `fa27d48204fc883ad702595e2f273a6c694cca8203561c22472a1697aa4d3605`
