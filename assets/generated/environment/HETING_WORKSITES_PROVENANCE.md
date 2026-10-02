# Art provenance — Heting worksite props

Created 2026-10-02 UTC for Hero · 渡灯录 using the built-in `image_gen.imagegen` tool in transparent-background mode. The runtime exposed no model version, seed, or reproducible generation identifier beyond its saved filenames. No external stock, downloaded third-party art, API/CLI fallback, Blender, or Godot was used.

## Original generations

Four independent generation calls produced the weighing scale, hot cooking pot/hearth, folded tarpaulin stack, and rope coil. No reference files were submitted to these original generations. Their prompts were informed by visual inspection of the actual existing gameplay screenshots:

- `Hero/screenshots/243-heting-machinery-loaded-east-pontoon.png`
- `Hero/screenshots/246-heting-machinery-short-ferries-aftermath.png`

The full exact prompt set is preserved in `source/generation_prompts.json`. `source/generated_source_paths.json` maps each output to its tool-returned original filename in `generated_images/`. Canonical copies are preserved unchanged under `source/heting_*_source.png`; their dimensions, SHA-256 checksums, and alpha measurements are recorded in `qa/alpha_validation.json`.

## Cold cooking-state variant

Read-only inspection of `_relief` in `Hero/scripts/heting_region.gd` showed that the scene distinguishes the pre-delivery cold pot from the cooked state. A fifth built-in edit call used `source/heting_pot_source.png` as its sole reference and preserved the composition while changing soup to dark water and embers to cold charcoal. The exact edit prompt is `source/cold_pot_prompt.txt`; its unchanged output is `source/heting_pot_cold_source.png`.

The cold output is 1355×1160 versus 1355×1161 for the original hot output. Both use the same absolute crop and foot anchor, and were inspected at 70×60. Their silhouettes align visually; the generated cold variant has minor texture differences outside the requested edit areas, so no claim of pixel-identical overlays is made.

## Deterministic runtime preparation

`prepare_pack.py` performs only crop, Lanczos resample, atlas packing, review labels, and QA compositing. It does not repaint the art, remove a background, mask image regions, or threshold alpha. Source alpha is retained inside each declared crop. Faint peripheral alpha outside the intentionally padded crop is not part of the runtime rectangle.

All props are resampled into exactly twice their requested runtime draw envelopes, then packed into a 512×320 RGBA PNG. The tarpaulin source was wider/flatter than its requested envelope; its deterministic resize produces a slightly taller folded stack at 96×38, which was visually checked and accepted. All other requested envelopes closely match their source proportions.

The five runtime regions have transparent gutters. No ground, scenery, text, people, or steam is baked into them. Hot soup and a small ember glow are baked into the hot-pot variant, while the separate cold variant has no cooking glow. World steam remains procedural.

## QA-only sources

`prepare_pack.py` reads both supplied screenshots for review-only scene composites and reads the previous `heting-machinery-art` runtime atlas/manifest to test existing sealed cargo on the two empty weighing pans. Those pre-existing screenshot and cargo pixels appear only in `qa/`, never in the new runtime atlas. QA scene composites preserve the existing procedural props and add new artwork into nearby clear space; these files are labeled mock composites and are not Godot captures.

## Project integration

The runtime atlas and its measured manifest are distributed here. Original generation sources, deterministic packing script and mock-composite QA remain retained in the project art workpack. Live rendering uses the measured ground feet, pan cargo sockets and procedural steam origin; model/collision state is unchanged.
