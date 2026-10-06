# Companion folio validation

This is a Linux-only bounded fork of the preserved recovery validation helper. The historical helper and16-frame driver remain unchanged. The companion contract is ten actual frames (five prepared legal states at physical1280×800 and960×600), scripted input, exact helper/runtime/source hashes and fresh owned userdata. It is not a browser or Windows helper acceptance claim.

Copy this entire directory to a new external owned staging directory before execution. The runtime manifest must remain outside the source checkout; running the launcher directly from this tracked directory intentionally refuses. Copy `native_capture.gd.txt` to a new external `.gd` file and pass its absolute path for native mode. This small tooling copy is not another source checkout. Both source and existing import caches are reused in place and inventoried; all original bytes must remain unchanged through each run.

The manifest pins the382 runtime inputs of candidate0378635; later evidence/tooling-only source commits may share that exact runtime. The launcher records the actual tested HEAD/tree and hashes every tracked original. Changing any runtime file requires a separately reviewed external binding to its new exact digest. Do not alter historical reports or substitute earlier passes.

Example, after copying these files outside the checkout, using fresh absolute directories:

```sh
python3 /owned/staging/isolated_godot.py test --source /owned/Hero \
  --qa-root /owned/new-companion-behavior --script tests/companion_folio_behavior_test.gd --timeout 180
```

For native use mode `native`, a fresh QA root, `--script /owned/staging/native_capture.gd`, and `--timeout 210`. The native launcher requires an already authorized X11 display; it neither creates a display nor reconfigures graphics. It uses the original official Godot4.6.3 Linux binary pin, Dummy audio and fixed30FPS. No user desktop automation is involved.

The ownership guard runs before any game load. It checks an entirely empty exact user directory, HOME/XDG containment and a fresh ownership token. Paths/inputs/PNG outputs must not use symlinks. Source, engine, manifest, copied driver and helper hashes are checked. Errors and timeouts fail closed, retain raw output and stop only children created by this launcher. Existing4GiB admission/2GiB running free-space floors remain.

Python-only tests can run from the external staging copy with `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest -v test_companion_launcher test_isolated_godot`. They use mocks/artificial PNGs and owned Python children; they do not start Godot and cannot prove game rendering. Independent review passed45 checks before execution. Actual results belong to the separately bound companion checkpoint records.

This focused suite complements the retained183-script regression, recovery folio suite, exact source/PCK audit and historical-reader processes. Those remain separate gates. Full regression/new package/Windows historical branches were pending at this tooling checkpoint.
