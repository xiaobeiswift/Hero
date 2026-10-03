# Du Hui original combat art — staged handoff

Status: **v4 accepted at native runtime scale for phase-2 integration** after actual Godot dark/light/anchor pixel review, 2026-10-03 03:42 UTC. This package remains staging-only; no source integration was performed by its author.

## Character and scope

杜晦, 平川粮栈收货管事, is an original middle-aged, clean-shaven receiving clerk. The fitted navy work cap, round face, river-blue coat, rust-umber sleeveless vest, cream cuffs, rectangular ledger pouch, and short wood baton distinguish him from Pu Heng. He is a compromised local agent, not the whole-conspiracy boss.

Stable future consumer ID: `du_hui`; encounter `heting_consignee`. This package does not change any model, encounter, UI, main script, combat cap, attack values, source repository, or publication state. The generic `consignee_guard` is not covered by this art package.

Six original authored keys, left-to-right in the 3×2 atlas: idle, windup, strike, guard, hurt, kneel. Every pose faces left. The idle can be used for a stationary exploration actor. There is no walking cycle and no implied walking support.

## Authorship and untouched pixels

Created with the built-in image generation tool, using one fresh generation and three targeted edits of that newly generated art. No external art was fetched. No raster cut/paste, Python raster editing, fake pose transforms, code-drawn replacement sprites, recolored existing boss, or payment/API-key route was used.

The existing owned Hero, Pu Heng, and Qin atlases were opened with `view_image` and their renderers read before authoring. They informed the painted cutout style, view, scale and atlas contract. They were **not** supplied as an edit target and no existing named character pixels were reused.

Selected file: `assets/generated/characters/painted_duhui_combat.png`, copied byte-for-byte from imagegen v4. Exact output paths and all four original-versus-copy SHA-256 checks are in `atlas-measurements.json`. All failed/intermediate variants are preserved in `variants/`. Exact prompts are in `generation-prompt-v1.txt` through `generation-prompt-v4.txt`.

Variant sequence:
- v1: new identity and six authored actions; windup/guard faced the wrong direction and strike crossed the cell line
- v2: corrected windup and guard; hurt still looked right and the strike gutter was too small
- v3: corrected hurt facing and reduced scale; strike left gutter remained approximately 10px
- v4: targeted strike re-layout only, resulting in at least 28px significant-alpha gutters in every cell

The PNG retains all original RGBA pixels, including source RGB under alpha zero and tiny alpha 1/255 or 2/255 remnants. These faint remnants were not erased. The apparent gradient when some viewers ignore alpha is not a painted opaque backdrop. The accepted native dark/light boards confirm clean transparent edges at runtime scale.

## Renderer contract

`scripts/painted_battle_duhui.gd` exposes full 512×512 `AtlasTexture` regions with `filter_clip`, per-pose foot/chest/weapon anchors in absolute atlas coordinates, `opaque_rect`, `pose_for`, and drawing helpers. Pose selection priority matches current opponent renderers. No battle state or damage lives in this helper.

Recommended drawing cell: **236px**. Do not pass the generic rival's 300px cell without intentionally changing scale. The conservative visible heights at 236px are approximately 183.5 / 188.1 / 150.3 / 173.8 / 168.7 / 153.5px. Foot positions are deliberately pose-specific so the newly authored silhouettes are grounded without modifying source pixels. Bounds are measured at alpha >2/255; all such pixels are at least 28 source pixels from cell edges. The strike baton tip points toward the player's side, over 100 screen pixels left of the chest at default scale.

## Focused validation already run

- Godot 4.6.3 staging import: passed
- `tests/painted_duhui_test.gd`: passed six unique images; source regions; cache; invalid names; no walk alias; alpha-present chest/weapon points; ground/chest/weapon transforms at multiple scales; pose priority; significant gutters; 150–190px height
- `tests/measure_duhui_atlas.py`: read-only raster QA, writes measurements JSON only; byte-identical original and four preserved variants

Numeric passes alone did not establish visual acceptance. The lead subsequently ran the native board via the supported Terminal and inspected all three 1280×720 captures. The author then independently opened those exact captures with `view_image`. Both reviews found consistent left-facing identity, six distinct readable poses, full shoes/baton, and clean alpha edges at native 150–188px scale. The anchor overlay showed ground/chest/tip registration on the intended points. Accepted evidence hashes and observations are in `native-visual-acceptance.json`.

The accepted capture run logged an ALSA device-open error before falling back to dummy audio. These are **visual-only** tests, not audio validation. The future launcher explicitly passes `--audio-driver Dummy`; future captures go into a unique review directory so the accepted PNGs are never overwritten. Copies of the exact pre-adjustment capture board and launcher are retained beside this file for provenance. No art, dimensions, anchors or drawing scale changed after acceptance.

## Native pixel review plan

1. Open the isolated staging directory using the supported native Terminal route. Run `./run_native_review.sh`. No server, source integration, install, or publication is required. The shell used for staging has no DISPLAY or Xvfb, so do not claim a headless run is visual evidence.
2. The launcher imports the staging project, re-runs the focused test, and runs the native Godot board using the GL compatibility renderer with explicit dummy audio. Future captures are written into a unique `evidence/review-<timestamp>-<pid>/` directory. The original accepted files `evidence/duhui-native-dark.png`, `duhui-native-light.png`, and `duhui-native-anchors.png` remain intact.
3. Inspect each board at native 1280×720 resolution, not enlarged-only. Check each of the six poses: left-facing intent; same face/cap/vest/pouch/shoes/baton; separate readable windup/strike/guard/hurt silhouettes; full hands, shoes and baton; transparent edges without halos or neighboring-cell fragments; good foot grounding.
4. Check anchors on the overlay: yellow ground origin, red chest, green weapon tip, blue conservative painted bounds. The two-foot poses intentionally have slightly different sole y-coordinates from three-quarter perspective; the kneel origin uses its support plane.
5. Have the lead/reviewer record accept/reject with filenames, actual pixel observations, and any specific issue. If a real visual defect exists, fix only that defect through a new preserved imagegen version and remeasure. Do not integrate merely because this package's numeric tests pass.
6. After source phase 1 and explicit phase-2 authorization, the lead can integrate the selected PNG/helper and attach the new renderer to `du_hui`. Integration is outside this package's authoring scope.
