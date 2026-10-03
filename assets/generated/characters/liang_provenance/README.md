# Liang Zhen / 梁缜·签令主事: original accepted art

Integrated for `liang_zhen` in `capstone_authorizer`. Original RGBA PNG bytes are copied exactly from accepted imagegen outputs. No resampling, mirror, alpha cleanup, recolor, composite, pixel edits or replacement old-boss images were used.

- Combat v4: `../painted_liang_combat_v4.png`, SHA256 `4812052ca14b016e43818713eaefe3a15ba3baa79fc421a8d40fc1e6774b5f33`
- Portrait v1: `../painted_liang_portrait_v1.png`, SHA256 `ce56fcca4b2bfaa5af6511df62b65e1463fc21437d5d452d8cb75ede00e081d3`
- Both1254×1254 RGBA. The portrait is a separately authored imagegen portrait, not a combat-atlas crop
- Exact generation prompts, generator source paths, accepted independent-artboard review notes and source geometry accompany this file. Historical review JSON reports its original staging-only state

Six separately authored left-facing keys: idle, windup, strike, guard, hurt, kneel. There is no walking cycle. The helper uses independent runtime regions with one uniform anatomical scale204/512 for battle. Visible heights are181.3,178.9,141.4,141.4,151.4,128.3px. Naturally bent/crouched poses are never enlarged to standing height. Stationary exploration idle has72px measured visible height.

The kneel region excludes44 detached pixels at the extreme bottom-right corner with max alpha12/255; the untouched PNG retains them. All intended silhouettes and documented three-or-greater source-pixel gutters remain. Foot anchors are stance baseline midpoints; chest/weapon anchors land on visible painted pixels.

V1/V2 failed direction/geometry. V3 corrected facing but mirrored windup arms/pouch. V4 restored right-hand saber and consistent pouch side. Rejected originals are retained in the separate staging art package; only accepted bytes are production assets. Original pixels and independent native-size dark/light/anchor artboard reviews passed before integration.

Helper/pixel/renderer tests establish region, scale, cache, targeting, current accepted battle-event playback and parity. They do not establish earned scene play, audible audio, performance or release acceptance. Real native game-scene acceptance is a separate gate.
