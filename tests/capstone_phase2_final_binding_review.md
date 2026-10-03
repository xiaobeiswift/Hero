# Independent final binding review

Reviewed 2026-10-03, after full-01. This review read source and evidence, computed hashes, inspected code consumers, and independently reproduced the UID algorithm in Python. It did not invoke Godot, edit source, modify historical evidence, export, or publish anything.

## Recommendation

**A bounded acceptance is technically justified:** the 1,101 pre-existing aggregate-inventoried files have identical bytes; the only additions are two exact QA reports and one deterministic Godot-generated UID sidecar for an already-existing, unchanged fixture-producer script. All 381 package-rehearsal inputs and all 440 native bindings also match current bytes.

**The strict raw guard did not pass.** The suite subprocess returned 0, but its wrapper's zero-delta condition evaluates to exit 1. Preserve that result and its complete three-path delta. The UID is metadata consumed by Godot, so it must be described as an explicit generated-metadata exception, not a third human-readable report or something no code can consume.

The root lead decides acceptance. This review neither changes the existing two-report acceptance scope nor applies retention records. During completion, the parent reported that the root had explicitly accepted the scoped exception, with the raw failure retained. That decision belongs in a separate acceptance record; it does not change any finding below.

## Aggregate result and exact delta

Independent recomputation from the raw log confirms:

- Suite subprocess exit 0, 1,041.493 seconds recorded
- 172 Godot command banners, 77 Python tests, 53 Node/mocked-DOM checks, zero `SCRIPT ERROR:`/`ERROR:` lines
- 48,348 real capstone scene checks across 12 routes
- 1,916 real-scene interruption checks across two boundaries
- Both old Web25 and old Web28 gates enabled in the raw record
- All 1,101 original files still match; no modified or missing original path
- No original file currently has an mtime at or after the before-snapshot
- Exactly 1,104 files in the same current inventory, with precisely these additions:

| Addition under source/ | Bytes | SHA-256 |
|---|---:|---|
| tests/capstone_package_audit_preparation.json | 5,286 | 82a6f128891edb4d7ad75a3ee44a8866cfaf43f3380c2d1d026cd0962b996c4b |
| tests/capstone_package_audit_report.md | 6,222 | e397bc4a615ac162e89b667983b476b9b7f9965655ff3efeda52a2fa24f959e2 |
| tests/capstone_package_fixture_producer.gd.uid | 18 | 96cfb722920f3d1935a6c3a7bbe354f545a442196e14f7932e930ddc82b06311 |

All three are regular nonsymlink files, mode 0644. The JSON and Markdown reports are byte-identical to package-audit/PACKAGE-AUDIT-REPORT.json and .md respectively. Both were written at approximately 08:49:22 UTC, after the 08:48:41.009920 before-snapshot. This corroborates the supplied report-writing provenance; filesystem timestamps alone do not identify their writer.

Raw record bindings:

| Artifact | SHA-256 |
|---|---|
| aggregate/full-01-before.json | d5e30d1b58dc5454902bbe8b30e5c83cf0d46a24f349f91879b7ec7abf49d516 |
| aggregate/full-01-result.json | 51135de1bdc0059726b4953a31e17f152be28f28e84ce8cdf21754190f3caf0a |
| aggregate/full-01.log | 58bb4c98fd059996efa667af9189ffdc056f61da4b9764c97f56655a2f287238 |
| source/run-tests.sh | b535329126530a8c5749aa6c27802685fd169691014b79e5813007292e616574 |

The wrapper inventories project.godot, export_presets.cfg, run-tests.sh, and files under assets/scripts/scenes/tests/tools/web/licenses, excluding Python cache files. Even its intended zero-delta result is an inventory-scoped claim, not an invariant over every file in the checkout or environment.

## UID provenance: independent deterministic reproduction

The sidecar contains exactly `uid://qctvsylf10j\n`. Its mtime and ctime are 08:48:43.888405 UTC, approximately 2.879 seconds after the before-snapshot. The suite's first command is the editor/import bootstrap, and the raw log begins with that scan. The engine filesystem and UID caches were written at 08:48:43.976 UTC.

The corresponding producer .gd already existed in the before-manifest, is unchanged, and has SHA-256 `ab5fb90361cccdce12ac8c968d6786fa83b235d412d9454db611745080a8b35a`. It is a non-tool SceneTree script without a global class declaration. It generates authentic historical fixture bytes only when explicitly executed with its required output argument.

Godot 4.6.3's [editor filesystem implementation](https://github.com/godotengine/godot/blob/4.6.3-stable/editor/file_system/editor_file_system.cpp#L1273-L1299) writes a missing UID sidecar during scanning and registers its identity. Its [ResourceUID implementation](https://github.com/godotengine/godot/blob/4.6.3-stable/core/io/resource_uid.cpp#L122-L140) computes the candidate from the project name, lowercase resource path and source-file MD5. The independent Python verifier reproduces that computation, using [String::hash64](https://github.com/godotengine/godot/blob/4.6.3-stable/core/string/ustring.cpp#L2623-L2636), [RandomPCG initialization](https://github.com/godotengine/godot/blob/4.6.3-stable/core/math/random_pcg.h#L54-L69), the [default increment](https://github.com/godotengine/godot/blob/4.6.3-stable/thirdparty/misc/pcg.h#L7), and [PCG operations](https://github.com/godotengine/godot/blob/4.6.3-stable/thirdparty/misc/pcg.cpp#L4-L22).

Independent inputs and results:

- Project: Hero · 渡灯录; hash64: 8244915197213009487
- Resource path: res://tests/capstone_package_fixture_producer.gd; hash64: 4389898403036789107
- Producer MD5: 7d308becd0cebbf08cea6bcde0220c8e; MD5-string hash64: 8087585082469399652
- PCG seed: 13590357120504638676
- First two output words: 2050565659 and 2155210491
- First generated candidate after the sign-bit mask: 33186540036892187
- Godot base-34 encoding: uid://qctvsylf10j, an exact byte match to the sidecar

The current engine UID cache was parsed according to [Godot's binary cache layout](https://github.com/godotengine/godot/blob/4.6.3-stable/core/io/resource_uid.cpp#L237-L298). All 423 entries and 21,620 bytes parse fully. Exactly one matching UID/path entry exists, mapping 33186540036892187 to this producer. The engine filesystem cache agrees. No other inventoried .uid sidecar has this value. UID cache SHA-256: `332f79e70c372f93c94d4ccc13d24fcb549fda268277b7a84f3a36995ee26759`.

This establishes that the observed metadata bytes are precisely what this engine's first deterministic candidate generates from the unchanged inputs. The writer attribution is a strongly corroborated editor-import inference, not an OS process-write trace. The reviewed .uid does not contain executable source and does not remap another resource or collide with another recorded UID.

## Consumers and exclusions

- The verifier scanned all 405 inventoried executable/runtime/config-text files for the report stem, sidecar filename, and UID value. No reference exists
- The only executable mention of the producer .gd path is tools/audit_web_export.py's explicit input-hash list; it names the .gd, not its .uid
- The two QA report filenames are not referenced by project runtime, test drivers, tool code, configuration or scene sources
- Python test discovery in run-tests.sh selects named .py files and test_web*.py; it cannot discover either report or the UID
- Reviewed project directory enumeration concerns isolated save fixtures, synthetic test trees, build/site validation, or source manifests. The export/source manifests enumerate assets/scripts/scenes/licenses/web, and the package audit adds explicit test fixtures and the producer .gd. They do not glob the three added files into executed checks
- All four export presets exclude tests/*; neither these reports nor the fixture producer is part of the intended shipped resource set. Actual final-PCK exclusion remains a separate future assertion
- Godot itself **does** consume the sidecar for resource identity, as its [generic resource loader](https://github.com/godotengine/godot/blob/4.6.3-stable/core/io/resource_loader.cpp#L106-L119) demonstrates. Bootstrap metadata therefore changed, even though pre-existing executable, fixture, asset and configuration bytes did not

## Native and package bindings

- Native final-stills-source.json: all 440 entries match, comprising 356 source/QA files and 84 imported resource-cache files. Manifest SHA-256: `f3166be177c1152f49dfaf9d1833d4fe44e615e2d0a4c615ab3d228d76c13ca0`
- Package rehearsal03 SOURCE-BEFORE.json and SOURCE-AFTER.json: both 381 entries match current files. Both manifest SHA-256 values: `35c33b4999ed10e94926f8766f5b3143ae3319d91ab7dcbfeadb19d063b97b88`
- The package rehearsal's recorded 6,369 source checks remain source-only evidence; the exact final exported PCK's 6,374 target remains unexecuted by this review

## Retention guard and required next steps

The retention worker's rejection was correct. Its exact allowlist covered two reports, and the actual delta contains a third path. Both default mode and its two-report acceptance flag rejected it. This review does not reinterpret those attempts as passes or modify that allowlist.

If the lead uses bounded acceptance, create an explicit, separately pinned generated-UID exception and preserve the existing raw full-01 and rejected-retention records. Keep the language scoped to unchanged pre-existing inventoried inputs and disclosed metadata/report additions. Do not say all execution state or the whole tree stayed unchanged. Do not delete the UID, manufacture a before-snapshot, change a test, or edit the raw delta to make a pass.

If strict zero-delta acceptance is required instead, retain these three files, freeze the current 1,104-file inventory, and rerun the unchanged full suite into fresh full-02 evidence, with both historical PCK gates enabled. Require subprocess exit 0, zero engine errors and zero before/after source delta. A source-script/asset/fixture/config mutation, a different new path, a different UID/hash, or an unexplained mapping would invalidate this exception and require review/rerun.

The endpoint hashes and mtimes do not prove the absence of hypothetical transient edits restored between observations. Unbound engine state, external executable/environment inputs and old build files are outside this review's invariant. No Windows, browser, final new PCK, publication or export approval follows from this report.

## Reproducible evidence

- verify_binding.py: independent read-only checker and UID reproduction; no project-code import or engine call
- FINDINGS.json: machine-readable result, exact pins, timestamps, provenance intermediates and scope limits
- CURRENT-INVENTORY.json: the independently observed 1,104-file inventory, kept separately from the original snapshot
- SHA256SUMS.txt: hashes of the review artifacts

The verifier completed successfully and checked that its source inventory was identical at the beginning and end of this review. It refuses to overwrite its findings files.
