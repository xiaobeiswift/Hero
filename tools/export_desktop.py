#!/usr/bin/env python3
"""Snapshot, export and verify Hero with pinned official Godot 4.6.3 templates.

The build tree is ignored by git. This script never downloads tools, uploads
anything, accesses accounts, or touches normal player saves.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import platform
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tarfile
import zipfile

ROOT = Path(__file__).resolve().parent.parent
VERSION = "4.6.3.stable.official.7d41c59c4"
PACK_SMOKE_CHECKS = 412
SOURCE_DIRS = ("assets", "scripts", "scenes", "licenses")
SOURCE_FILES = ("project.godot", "export_presets.cfg")
TARGETS = {
    "linux": ("Linux x86_64", "linux_release.x86_64", "Hero.x86_64"),
    "windows": ("Windows x86_64", "windows_release_x86_64.exe", "Hero.exe"),
    "macos": ("macOS Universal", "macos.zip", "Hero.zip"),
}


def digest(path: Path) -> str:
    with path.open("rb") as f:
        return hashlib.file_digest(f, "sha256").hexdigest()


def source_manifest(root: Path) -> dict[str, str]:
    paths = [root / name for name in SOURCE_FILES]
    for name in SOURCE_DIRS:
        paths.extend(p for p in (root / name).rglob("*") if p.is_file())
    return {p.relative_to(root).as_posix(): digest(p) for p in sorted(paths)}


def git_provenance() -> dict:
    """Record local revision without using remotes, accounts or credentials."""
    git = shutil.which("git")
    if not git:
        return {"source_git_commit": None, "source_git_clean": None}
    revision = subprocess.run([git, "rev-parse", "HEAD"], cwd=ROOT, text=True,
                              stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    if revision.returncode:
        return {"source_git_commit": None, "source_git_clean": None}
    status = subprocess.run([git, "status", "--porcelain", "--untracked-files=all", "--",
                             *SOURCE_DIRS, *SOURCE_FILES, "tools"], cwd=ROOT, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
    return {"source_git_commit": revision.stdout.strip(),
            "source_git_clean": not bool(status.stdout.strip()),
            "source_git_changes": status.stdout.splitlines()}


def run(command: list[str], log: Path, env: dict[str, str], *, cwd: Path) -> str:
    print("Running:", " ".join(command), flush=True)
    result = subprocess.run(command, cwd=cwd, env=env, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=240)
    log.write_text(result.stdout, encoding="utf-8")
    # Godot can print script errors while returning exit code zero.
    errors = re.search(r"^(?:SCRIPT ERROR|ERROR):", result.stdout, re.MULTILINE)
    if result.returncode or errors:
        raise RuntimeError(f"Command failed ({result.returncode}); inspect {log}\n{result.stdout[-5000:]}")
    return result.stdout


def add_notices(directory: Path, snapshot: Path, source_text: str, platform: str) -> None:
    shutil.copytree(snapshot / "licenses", directory / "licenses", dirs_exist_ok=True)
    shutil.copyfile(snapshot / "assets/fonts/LICENSE.txt", directory / "licenses/FONT-LICENSE.txt")
    shutil.copyfile(snapshot / "assets/generated/ART_PROVENANCE.md", directory / "ART_PROVENANCE.md")
    shutil.copyfile(snapshot / "assets/generated/characters/ART_PROVENANCE.md",
                    directory / "CHARACTER-ART-PROVENANCE.md")
    (directory / "SOURCE-SHA256SUMS.txt").write_text(source_text, encoding="utf-8")
    launch = {"linux": "Keep Hero.x86_64 and Hero.pck together. Run ./Hero.x86_64.",
              "windows": "Extract the complete ZIP. Keep Hero.exe and Hero.pck together. Run Hero.exe.",
              "macos": "Extract the ZIP, then open the Hero application. This prototype is ad-hoc signed, not notarized."}[platform]
    native_status = "Linux release executable passed headless startup in the build environment; graphical playtesting is separate." if platform == "linux" else "This artifact is cross-exported only; native platform execution has NOT been tested."
    (directory / "READ-ME.txt").write_text(
        "Hero · 渡灯录 — offline single-player desktop prototype\n\n" + launch + "\n\n" + native_status +
        "\nThis is a work-in-progress prototype, not a finished commercial game.\n"
        "No Godot editor, account, network connection or credentials are required at runtime.\n"
        "WASD / arrows: walk; E / Enter: interact; I: inventory; J: journal;\n"
        "M: map; K: martial arts; B: workshop;\n"
        "F5/F9: quick save/load; F6/F10: manual save/load slots; Esc: close dialogue.\n"
        "The included engine and font license notices must remain with redistributions.\n",
        encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target", choices=["all", *TARGETS], default="linux")
    parser.add_argument("--label", default=dt.datetime.now(dt.timezone.utc).strftime("build-%Y%m%d-%H%M%S"))
    parser.add_argument("--allow-dirty-source", action="store_true", help="Development exports only: allow uncommitted game resources; report remains marked dirty")
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    args = parser.parse_args()
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*", args.label):
        parser.error("label must contain only letters, numbers, dot, dash and underscore")
    godot = shutil.which(args.godot)
    if not godot:
        parser.error(f"Godot executable not found: {args.godot}")
    build = ROOT / "builds" / args.label
    if build.exists():
        parser.error(f"Build already exists; choose another label to preserve its evidence: {build}")
    export_data = Path(os.environ.get("HERO_EXPORT_DATA", str(ROOT / "builds/export-data"))).resolve()
    templates = export_data / "godot/export_templates/4.6.3.stable"
    targets = list(TARGETS) if args.target == "all" else [args.target]
    for target in targets:
        required = templates / TARGETS[target][1]
        if not required.is_file():
            parser.error(f"Missing {required}; run bash tools/install-export-templates.sh first")
    if not (ROOT / "licenses/GODOT-LICENSE.txt").is_file():
        parser.error("Missing engine license notices; see EXPORTS.md for generation command")
    provenance = git_provenance()
    if provenance["source_git_clean"] is False and not args.allow_dirty_source:
        parser.error("Game resources have uncommitted changes. Commit them first, or use --allow-dirty-source for a development-only export.")
    build.mkdir(parents=True)
    logs = build / "logs"
    logs.mkdir()
    env = os.environ.copy()
    env.update(XDG_DATA_HOME=str(export_data), XDG_CONFIG_HOME=str(build / "editor-config"),
               XDG_CACHE_HOME=str(build / "cache"))
    for key in ("XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"):
        Path(env[key]).mkdir(parents=True, exist_ok=True)
    version = run([godot, "--headless", "--version"], logs / "version.log", env, cwd=build).strip()
    if version != VERSION:
        raise RuntimeError(f"Exact Godot version required: {VERSION}; got {version}")
    before = source_manifest(ROOT)
    snapshot = build / "source"
    snapshot.mkdir()
    for name in SOURCE_DIRS:
        shutil.copytree(ROOT / name, snapshot / name)
    for name in SOURCE_FILES:
        shutil.copyfile(ROOT / name, snapshot / name)
    manifest = source_manifest(snapshot)
    if before != manifest or manifest != source_manifest(ROOT):
        raise RuntimeError("Source changed while snapshotting. Choose a new label and rerun after edits settle.")
    source_text = "".join(f"{sha}  {name}\n" for name, sha in manifest.items())
    (build / "SOURCE-SHA256SUMS.txt").write_text(source_text, encoding="utf-8")
    # Preserve the exact external test driver used for every platform. It stays
    # outside the source snapshot/PCK so no development tools ship to players.
    smoke_driver = build / "smoke_export.gd"
    shutil.copyfile(ROOT / "tools/smoke_export.gd", smoke_driver)
    if digest(smoke_driver) != digest(ROOT / "tools/smoke_export.gd"):
        raise RuntimeError("Smoke driver changed while snapshotting. Choose a new label and rerun.")
    run([godot, "--headless", "--path", str(snapshot), "--editor", "--import", "--quit"],
        logs / "import.log", env, cwd=build)
    report = {"created_utc": dt.datetime.now(dt.timezone.utc).isoformat(), "engine": version,
              "build_status": "incomplete", "build_host": platform.platform(), **provenance,
              "source_manifest_sha256": hashlib.sha256(source_text.encode()).hexdigest(),
              "build_script_sha256": digest(Path(__file__)),
              "smoke_script_sha256": digest(smoke_driver),
              "expected_pack_checks": PACK_SMOKE_CHECKS,
              "template_sha256": {}, "platforms": {}, "archives": {}}
    for target in targets:
        preset, template, filename = TARGETS[target]
        directory = build / target
        directory.mkdir()
        output = directory / filename
        run([godot, "--headless", "--path", str(snapshot), "--export-release", preset, str(output)],
            logs / f"export-{target}.log", env, cwd=build)
        if not output.is_file() or output.stat().st_size < 1024:
            raise RuntimeError(f"Missing/empty export: {output}")
        report["template_sha256"][template] = digest(templates / template)
        status = {"export": "passed", "native_runtime": "not tested", "binary": str(output.relative_to(build))}
        smoke_env = env.copy()
        smoke_env.update(XDG_DATA_HOME=str(build / (target + "-smoke-data")),
                         XDG_CONFIG_HOME=str(build / (target + "-smoke-config")),
                         XDG_CACHE_HOME=str(build / (target + "-smoke-cache")))
        for key in ("XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"):
            Path(smoke_env[key]).mkdir()
        if target == "linux":
            output.chmod(0o755)
            # The cwd has no project.godot; the executable must load its adjacent PCK.
            run([str(output), "--headless", "--audio-driver", "Dummy", "--quit-after", "60"],
                logs / "linux-launch.log", smoke_env, cwd=directory)
            status["native_runtime"] = "Linux release executable headless startup and 60 iterations passed"
            status["graphical_runtime"] = "not tested by this script"
        # Release templates do not implement --script. Audit each exact PCK via the
        # Linux editor separately; never describe these assertions as native OS runs.
        pack = directory / "Hero.pck"
        if target == "macos":
            with zipfile.ZipFile(output) as z:
                packs = [n for n in z.namelist() if n.endswith(".pck")]
                if len(packs) != 1:
                    raise RuntimeError(f"Expected one macOS PCK; got {packs}")
                pack = build / "macos-audit.pck"
                with z.open(packs[0]) as src, pack.open("wb") as dst:
                    shutil.copyfileobj(src, dst)
        text = run([godot, "--headless", "--audio-driver", "Dummy", "--main-pack", str(pack),
                    "--script", str(smoke_driver)], logs / f"{target}-smoke.log", smoke_env, cwd=directory)
        if f"PASS: {PACK_SMOKE_CHECKS} exported-pack checks; 0 failures" not in text:
            raise RuntimeError(f"Expected smoke assertion summary missing: {logs / f'{target}-smoke.log'}")
        status["pack_audit"] = f"Exact exported PCK loaded by Linux editor: {PACK_SMOKE_CHECKS} checks passed"
        add_notices(directory, snapshot, source_text, target)
        if target == "macos":
            # Notices are adjacent to the signed .app, so signing is not invalidated.
            archive = build / f"Hero-{args.label}-macos-universal.zip"
            shutil.copyfile(output, archive)
            with zipfile.ZipFile(archive, "a", compression=zipfile.ZIP_DEFLATED) as z:
                for path in sorted(directory.rglob("*")):
                    if path.is_file() and path != output:
                        z.write(path, path.relative_to(directory))
                bad = z.testzip()
                if bad:
                    raise RuntimeError(f"ZIP integrity failure: {bad}")
                if not any(n.endswith(".app/Contents/Info.plist") for n in z.namelist()):
                    raise RuntimeError("macOS archive has no application bundle")
            status["signing"] = "Godot built-in ad-hoc signing; not notarized; no Developer ID"
        elif target == "linux":
            archive = build / f"Hero-{args.label}-linux-x86_64.tar.gz"
            with tarfile.open(archive, "w:gz") as tar:
                tar.add(directory, arcname="Hero")
        else:
            archive = build / f"Hero-{args.label}-windows-x86_64.zip"
            with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED) as z:
                for path in sorted(directory.rglob("*")):
                    if path.is_file():
                        z.write(path, "Hero/" + path.relative_to(directory).as_posix())
                bad = z.testzip()
                if bad:
                    raise RuntimeError(f"ZIP integrity failure: {bad}")
            status["signing"] = "Unsigned prototype; no Authenticode certificate"
        report["platforms"][target] = status
        report["archives"][archive.name] = {"sha256": digest(archive), "bytes": archive.stat().st_size}
        (build / "BUILD-REPORT.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        print(f"PASS: {target} export at {output}", flush=True)
    sums = "".join(f"{item['sha256']}  {name}\n" for name, item in report["archives"].items())
    report["build_status"] = "complete"
    (build / "BUILD-REPORT.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (build / "SHA256SUMS.txt").write_text(sums, encoding="utf-8")
    print(f"Build complete: {build}\n{sums}", flush=True)


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, subprocess.TimeoutExpired) as error:
        sys.exit(f"EXPORT FAILED: {error}")
