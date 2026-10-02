# Art provenance — Heting harbor machinery

Created 2026-10-02 UTC for the ongoing Hero · 渡灯录 project, using the built-in `image_gen.imagegen` tool. The runtime did not expose a model version, seed, or reproducible generation identifier beyond its saved filenames. No API/CLI fallback, third-party stock, downloaded copyrighted assets, Blender rendering, or external publication was used.

## Original source 1

- File: `source/heting_machinery_source.png`
- Tool-returned source: `generated_images/exec-57bd29ed-7cb1-427a-b78d-4e21b6257c66.png`
- Dimensions / mode: 1536 × 1024 RGBA
- Tool parameter: `transparent_background=true`
- Exact complete prompt: `source/generation_prompt.txt`
- Generation intent: one original separated six-prop painted atlas with rope winch, timber crane, loaded grain handcart, sack stack, full grain basket, and closed cargo hampers
- No reference files were passed to this first generation. Style was described after inspecting the three existing project references listed below.

## Original source 2

- File: `source/heting_empty_basket_source.png`
- Tool-returned source: `generated_images/exec-5bf17f18-ea0e-4b04-8d03-bc141abfd2e1.png`
- Actual returned dimensions / mode: 1254 × 1254 RGBA (the requested 1024 square size was advisory)
- Tool parameter: `transparent_background=true`
- Exact complete prompt: `source/empty_basket_prompt.txt`
- Reference / edit target: original source 1 above
- Generation intent: an isolated empty version of the original sheet's full grain basket, preserving woven material, camera, and lighting while removing grain and scoop

Both generated source files are preserved unchanged. Their checksums and alpha ranges are recorded in `qa/alpha_validation.json`.

## Existing project references inspected

- `Hero/screenshots/224-heting-working-harbor.png`
- `Hero/screenshots/227-heting-loaded-east-pontoon.png`
- `Hero/assets/generated/environment/qingwei_environment_atlas.png`

Only for QA compositing, `prepare_pack.py` samples sage ground from the first screenshot and reads `Hero/assets/generated/environment/qingwei_deck_wood.png`. Neither ground image is baked into the runtime atlas.

## Deterministic runtime processing

`prepare_pack.py` crops exact isolated source regions with padding, proportionally downsamples each to a maximum dimension of 244 pixels using Pillow Lanczos filtering, and packs seven crops into a 1024 × 512 RGBA atlas. No semantic image editing, background removal, or alpha thresholding is applied. Hidden RGB remains hidden by its original alpha.

The manifest records every packed rectangle, source-original rectangle, source-local and packed-local foot anchor, suggested draw size, and drawing offset. It also records the runtime file's SHA-256 checksum. No text or labels are rendered into the sprite artwork; labels appear only on QA previews.

## Preparation handoff

The original source images, packing script and QA remain retained in the project art workpack. Asset preparation itself was separate from live-game integration. The runtime copy and its use are described below.

## Project integration

This directory distributes the compact runtime atlas and measured manifest. Unmodified generated originals, deterministic packing script and image-level QA are retained in the separate project art workpack. Runtime rendering preserves each source crop aspect ratio and anchors it to the authored ground foot; collision and cargo rules stay in the map/model.
