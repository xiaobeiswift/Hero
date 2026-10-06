# Recovered-source validation launcher

This new Linux helper has passed 15 Python-only checks and an independent execution-safety review. Its GDScript guard and actual Godot import have not yet executed at this checkpoint. It is not a gameplay, full regression, package, Windows or browser acceptance result.

The launcher runs the current checkout in place with a fresh exclusively created private QA directory. It pins the official Godot 4.6.3 Linux binary and all 382 recovered runtime inputs; records source commit/tree and tool hashes; verifies an empty exact user:// before any game script; separates logs/results from userdata; and rejects changed original source bytes or engine errors. Generated .godot files and new UIDs are recorded separately. Existing self-contained engine markers are preserved and cause refusal in this Linux flow.

It requires 4 GiB available at entry and keeps a 2 GiB running floor. Timeout/interruption/floor failure terminates only a still-running process group created by the launcher. Failed evidence stays in place. This is a profile and integrity guard, not an OS sandbox.

From the repository root, with a new absolute QA directory outside the checkout:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 tools/recovery_validation/isolated_godot.py import \
  --source "$PWD" --qa-root "$(dirname "$PWD")/qa-import-01" \
  --guard-timeout 30 --timeout 120
```

For a tracked test, choose a different fresh QA root and use test mode with --script. Script arguments follow repeated --test-arg options; {results} expands to that QA root's external results directory. Do not run concurrent source edits or engine checks while binding input bytes.

The shared environment contract is HERO_FOLIO_QA_OWNED_ROOT, HERO_FOLIO_QA_USER_DIR, HERO_FOLIO_QA_TOKEN and HERO_FOLIO_QA_REPORT. The marker .hero-folio-qa-owner contains the exact token. Each test still needs its own reviewed behavior and output contract.

The Python unit suite creates retained small fixtures beside its own file. Run it from a separate external copy of these three helper files so the fixtures stay outside the source checkout. It starts Python fixture children only; it never starts Godot. The original staged tests and independent rerun each passed 15 checks before this byte-identical code integration.

## Native capture mode

The native extension passed the same 15 Python safety checks and 17 additional mocked native checks, including command parity, profile guards and rejected invalid PNG outputs. Actual native execution is still pending at this tooling checkpoint.

The exact reviewed driver is retained as native_capture.gd.txt. Copy those bytes to an external owned .gd path, then select native mode with --script pointing to that absolute path. The launcher copies and binds that driver into its newly owned QA root. This small script copy is not a source-worktree copy. Native mode uses the already available authorized cloud X11 display; it does not configure a display or connect to a user desktop. Coordinate foreground use before running.

The unchanged headless profile guard executes first. The second process uses x11, gl_compatibility, Dummy audio and fixed30FPS. It captures16 actual viewport PNGs across1280×800 and960×600, using validated prepared fixtures and scripted input. Journal, fitting, Shen dialogue, inventory, martial arts, workshop and cultivation are included; this is a bounded matrix rather than every branch/size combination. Each final PNG path, hash and physical dimension is checked. Both reports must pass, and actual pixels still require review. No native, contrast, browser or full-regression acceptance follows from mocked tests.
