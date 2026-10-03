# Hero: capture the already imported native folio

This is a **capture-only, unexecuted helper** for the exact runtime below. It does not import again, change `_sc_`, copy/install an engine, change settings, or run a full test gate. The earlier first-render handoff and its records remain preserved separately.

- Runtime published commit: `87c4c3f3f9a5c39c39118e0202177b46f35ebae1`
- Local source reference: `e6bd39027c9a4d86d82bc385024e3a7b28d945e8`
- Exact runtime tree: `84d995012e92e20bac1db1abe28e78eef5c67904`
- Original files: 1,639; bundled `source-sha256.json` SHA-256 `b02494ed1bd254e6ad022421659eac67638ece8518fb2bcb29178233dd045a66`

The Windows owner has already reported a successful zero-error import with all original bytes unchanged and a separate, guard-proved empty capture user directory. This helper revalidates those supplied receipts and actual files. It does not pretend the already created empty directory never existed.

## Separate helper retrieval and runtime

Retrieve these reviewed tooling files through the separate published tooling Git objects, into an external helper directory. Keep the runtime checkout at the original runtime commit above. Do not check out the tooling commit in the runtime or copy the helper into it. The helper has no network or transfer code. No Library/manual blob transfer is needed or implied.

The consumer must verify the tooling commit and helper-manifest hashes. Cloud staging paths do not establish that the helper files exist on Windows. Do not embed private Windows paths, usernames, actual receipts or local log files in the published tooling source.

## Required input contract

All paths below are explicit caller inputs, not guessed filenames. Each receipt/inventory has a mandatory SHA-256 argument obtained from its prior reviewed result. The helper reads the actual existing Windows files and fails if any caller pin differs. Paths shown in examples are placeholders only; preserve the caller's actual receipt names and locations.

### Existing capture-profile receipt

`--profile-receipt` JSON supplies:

- `source`, `source_commit`, `source_tree`, `profile`
- `engine`: absolute existing GUI engine path; `engine_sha256`: that file's reviewed hash
- `process_local_environment`: `APPDATA`, `LOCALAPPDATA`, `HOME`, `USERPROFILE`, `XDG_DATA_HOME`, `XDG_CONFIG_HOME`, `XDG_CACHE_HOME`, `TEMP`, `TMP`; optional pre-existing `HERO_OWNED_DATA_ROOT` and `HERO_CHECK_TIMEOUT_SECONDS`
- `isolation`: `actual_user_root`, `cache_dir`, `config_dir`, `data_dir`, `expected_owned_data`, `main_loaded: false`, `passed: true`, `user_files: []`, `user_folders: []`
- `guard_exit_code: 0`, `main_loaded: false`, `capture_run: false`
- Other retained observation fields, such as `guard_stdout_sha256` or `awaiting`, are preserved in the receipt identity; they do not authorize unrelated actions

The existing guard must have been run and reviewed by the Windows owner. The helper checks all referenced scope and environment paths again. On Windows, the observed user root must exactly equal `<APPDATA>/Godot/app_userdata/Hero · 渡灯录` and lie under the explicitly owned profile. A development or temporary workspace inside the user home or LOCALAPPDATA/Temp is allowed; the actual default `<real APPDATA>/Godot` and `<real LOCALAPPDATA>/Godot` data/config/cache trees remain excluded.

The user directory may already exist empty after its isolation guard. Immediately before launch, application files and unexpected subdirectories must still be absent. A known engine-owned `shader_cache` is separately inventoried and permitted. The helper exclusively creates `.hero-first-capture-started` in that owned profile; prior use is rejected. No actual save/profile is removed, cleaned, reset or reused.

### Existing import result

`--import-receipt` JSON supplies:

- `passed: true`
- `import.exit_code: 0`
- `import.error_lines: []`, `original_file_changes: []`
- `generated_file_count`: count matching the supplied generated inventory
- `original_engine_and_marker_unchanged: true`

Other original receipt observations remain available through its byte pin. The existing import logs remain at their original receipt locations; this helper does not claim to have rerun their process or to have independently reconstructed historical exit status from a file scan.

### Original file inventory

`--original-inventory` JSON maps every original relative POSIX path to an object containing `git_blob`, `git_mode`, `bytes`, and `sha256`. Its path/SHA set must exactly equal the bundled 1,639-file manifest. Every current size and SHA is rechecked, and Git HEAD/tree must match the original runtime pins.

### Generated file inventory

`--generated-inventory` JSON maps each generated relative POSIX path to `{ "bytes": ..., "sha256": ... }`. Every listed file is revalidated before launch. The observed import currently has 101 generated entries; that count is checked against its import receipt, not assumed to mean 101 source sidecars.

- New paired `.gd.uid` and resource `.import` files become explicit effective-source additions
- `.godot/` entries are existing engine-generated cache inputs and are inventoried separately
- A generated entry cannot replace any original source path
- Unexpected non-cache/non-sidecar files are rejected
- Original bytes and generated source sidecars must remain unchanged after capture
- Project cache input bytes are rechecked immediately before launch; actual project cache hashes at pre-Main and after capture are separately retained. Engine cache changes do not become a false clean-source identity

## Direct GUI engine; optional wrapper

The default launches the exact existing GUI engine and SHA from the reviewed capture-profile receipt. `_sc_` and `._sc_` are recorded and left unchanged. Their presence alone is not a reason to copy the engine, delete a marker, import again, or block this already proved capture path. The pre-Main GDScript independently confirms the live user-data path and environment before loading production State or Main.

This direct-GUI mode captures its actual exit, stdout, stderr and explicit Godot log. On a timeout it kills only the process it launched and records whether that process exited. It **does not claim a console wrapper's Job Object, verified descendant cleanup, or a full process-tree gate**. No global/name-based process termination is used.

A caller may optionally choose a verified official console wrapper with `--console-wrapper` and `--console-wrapper-sha256`. The wrapper must use the canonical `.console.exe` or `_console.exe` suffix and map to the same-directory receipt-bound GUI binary. The wrapper is optional; the existing direct-GUI path does not depend on it.

## Native PowerShell invocation

Populate these variables from the already reviewed Windows task records. No value requires a new engine discovery/import, credentials, installation, setting or marker change. The helper directory is materialized from the separately reviewed tooling Git objects.

```powershell
python "$Helper\test_capture_static.py"
python "$Helper\test_receipt_schema.py"
python "$Helper\capture_imported_windows.py" `
  --source "$Runtime" `
  --profile-receipt "$CaptureProfileReceipt" `
  --profile-receipt-sha256 "$CaptureProfileReceiptSha256" `
  --import-receipt "$ImportReceipt" `
  --import-receipt-sha256 "$ImportReceiptSha256" `
  --original-inventory "$OriginalInventory" `
  --original-inventory-sha256 "$OriginalInventorySha256" `
  --generated-inventory "$GeneratedInventory" `
  --generated-inventory-sha256 "$GeneratedInventorySha256" `
  --run-root "$FreshOutputRoot"
```

`$FreshOutputRoot` must not exist, must have an existing authorized parent, and must be separate from runtime and capture profile. It can be inside an authorized development/temporary workspace. All input paths must be absolute without `..` or reparse/junction traversal. The helper preserves all existing receipts, generated metadata, engine bytes, markers and prior failed outputs.

There is one engine launch, using the actual production Main scene via external GDScript:

`--rendering-method gl_compatibility --resolution 1280x800 --max-fps 30 --quit-after 300 --script <external first_render.gd>`

It additionally selects Dummy audio and a fresh explicit log path. No editor/import or separate parse invocation occurs. Any script parse/runtime failure is retained as a failure, with no screenshot success claim.

## First-image evidence and limits

The GDScript retains the reviewed path/token/known-cache checks before loading State/Main. It accepts the prepared canonical oracle `bounded_qin_tang_fix_1_1` through the genuine production reader. A genuine save is created only as isolated test setup before the browsing baseline, never as a player's save or a claim about normal journal behavior.

It queues J through Godot input, clicks the actual Tang row, verifies Tang selection/focus before Enter, and requires automatic Qin with `mist_rain_gauge` plus exact Main/World/HUD/J snapshot agreement. Canonical State, all application/save-file bytes and world position must remain unchanged through browsing. Engine shader caches are separately inventoried. Required directory open/enumeration and file-digest failures fail closed; an absent optional shader-cache root is distinguished through successful parent-directory enumeration. Hidden files are included.

The output is an actual 1280×800 native framebuffer or an explicit failure. `capture.json` records engine/OS/display identity, resolved font resource paths, BBCode, prepared/scripted qualifiers, actual input, source binding, cache observations and before/after state/files. `first-native.png` is labeled `captured_pending_visual_review`; inspect its actual pixels before reporting what works.

Do not treat default RichText color as the whole contrast inventory. The new body has `#5d251e`/24 px and `#3d3428`/19 px spans, a default `#101f22` body, and a 42 px long-title fallback. A first image does not establish all span/background contrasts, selected/disabled/focus states, full regression, earned gameplay, browser behavior, PCK, release, audio or performance gates.

## Preparation validation

This helper and GDScript are unexecuted on Windows and uncompiled by Godot during preparation. Portable Python/static tests validate receipt classifications, direct-engine byte binding, optional wrapper mapping, existing-empty versus player-data rejection, cache separation and retained guards. This is preparation evidence only.

## Observed Windows receipt-schema correction

The initial published helper stopped before starting Godot because it incorrectly looked for top-level `error_lines`. The actual import result stores this field at `import.error_lines`. The correction changes exactly that one subscript; source runtime, profile rules and all other guards remain unchanged. Original published helper bytes and the failure are preserved.

`actual_receipt_schema.json` is a privacy-redacted projection of the fields this guard actually reads, tied to the observed original receipt SHA. It is not a reconstructed full receipt or a fabricated successful execution. `test_receipt_schema.py` evaluates the exact production-guard AST: it reproduces the original KeyError, accepts the real nested shape, and rejects nested errors even if a top-level empty list is supplied, absent nested data, nonzero exit, original changes and false status/marker claims. Seven new checks and the existing fourteen pass; this is not an engine or native-visual result. Exact adaptation identities are in ADAPTATION.json.
