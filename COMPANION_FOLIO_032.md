# Companion folio 0.0.32 development checkpoint

This local candidate changes the 同行册 presentation to the existing original cloth-and-paper folio family. It reuses licensed fonts and original portraits/materials, preserves the four actor identities, and keeps story, roster, formation, resource and save callbacks unchanged. The version32 metadata identifies the next candidate; live Web31 remains unchanged.

Current checkpoint:1738 genuine Main/HeroState checks and690 checks across10 actual native frames passed on0378635. Independent review inspected all10PNG and sampled text contrast4.763–14.968:1. Full retained source regression and exact new package audit are pending. Earlier import/legacy results and preserved failed candidates are bound separately in `tests/companion_folio_checkpoint.json`. No deployment or browser gameplay acceptance is implied.

The old roster geometry test is retained byte-for-byte in `tests/fixtures/companion_folio_20261006/`; its live successor preserves the behavior assertions. Newly authored genuine Main/HeroState and external10-frame native contracts are described in `tests/companion_folio_behavior_contract.md`. Prepared test states are not earned player journeys.

Scope is presentation, plus required version assertions. Save schema16, automatic combat, recruitment, roster capacity/order, costs and HP/Qi behavior retain their existing rules. Normal inventory-close autosave remains a separate host behavior; this checkpoint does not claim universally write-free navigation.

Validation will use fresh owned userdata profiles with the existing official Godot4.6.3 engine and reused imported asset caches, recording source/runtime hashes and generated-file changes. Previous Web31 passes apply only to their frozen bytes. Failed candidate evidence will be preserved.
