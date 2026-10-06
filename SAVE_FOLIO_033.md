# 旅途手记 · 0.0.33 development checkpoint

The existing three manual-save slots, autosave load entry, current/backup details and explicit overwrite/load confirmations now use the original cloth-and-paper folio family. Slot metadata stays adjacent to its actual action. Existing save-result and failed-load text is also shown inside the active folio, while the original toast and autosave-warning behavior remain.

The earlier native32 baseline reproduced all three hidden-feedback cases in137 checks: successful manual save, real write failure and failed title load. The new focused suite passed449 checks across ten cases with real production I/O, actual key/pointer dispatch, isolated prepared faults, state/file evidence and terminal integrity. See `tests/save_folio_baseline.json` and `tests/save_folio_checkpoint.json`. This is not yet a native visual, full-regression or packaged acceptance. Live remains0.0.32 Web1.

Native focus does not automatically select or invoke an action. Tab enters the choices; a focused native button handles Enter/Space once, while the existing unfocused first-choice shortcut remains. Title choices gain generation guards, and local folio callbacks reject quit-pending, including Back. These narrow input protections are explicitly recorded rather than described as unchanged behavior.

LocalSaveSlots, HeroState, schema16, slot paths/count, resources and save/backup behavior are unchanged. Normal exploration dismissal still autosaves; title cancellation, fitting read-only browsing and dormant transfer-return browsing retain their distinct suppression. Successful load followed by failed autosave keeps the loaded branch and warning. A valid primary may already have rotated into backup before a later primary-write failure; this scope adds no backup journal. Transfer remains default-off.

Remaining gates: twelve actual native frames across six states and two physical sizes, direct compact geometry and sampled contrast/focus, retained regression plus focused supplement, exact source/Web PCK and independent Windows boundaries. No new illustration or gameplay content is added.
