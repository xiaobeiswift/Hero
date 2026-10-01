#!/usr/bin/env python3
"""Compare final archive members with their exact unpacked build files; never delete."""
from __future__ import annotations
import argparse
import datetime as dt
import hashlib
import json
from pathlib import Path, PurePosixPath
import tarfile
import zipfile


def digest_stream(stream) -> str:
    return hashlib.file_digest(stream, "sha256").hexdigest()


def digest(path: Path) -> str:
    with path.open("rb") as stream:
        return digest_stream(stream)


def contained_file(base: Path, relative: str) -> Path:
    name = PurePosixPath(relative)
    if name.is_absolute() or ".." in name.parts:
        raise RuntimeError(f"Unsafe build path: {relative}")
    path = base / relative
    if not path.resolve().is_relative_to(base.resolve()) or path.is_symlink() or not path.is_file():
        raise RuntimeError(f"Expected regular build-owned file: {relative}")
    return path


def verify_build(base: Path) -> dict:
    base = base.resolve()
    report = json.loads((base / "BUILD-REPORT.json").read_text())
    if report.get("build_status") != "complete":
        raise RuntimeError("Build is not complete")
    suffixes = {"linux": "-linux-x86_64.tar.gz", "windows": "-windows-x86_64.zip", "macos": "-macos-universal.zip"}
    rows = []
    for target, status in report["platforms"].items():
        if target not in suffixes or status.get("export") != "passed":
            raise RuntimeError("Unknown or incomplete platform")
        names = [name for name in report["archives"] if name.endswith(suffixes[target])]
        if len(names) != 1:
            raise RuntimeError(f"Expected exactly one final {target} archive")
        name = names[0]
        archive = contained_file(base, name)
        expected = report["archives"][name]
        if digest(archive) != expected["sha256"] or archive.stat().st_size != expected["bytes"]:
            raise RuntimeError(f"Final archive differs from build report: {name}")
        binary = contained_file(base, status["binary"])
        directory = binary.parent
        if target != "macos":
            contained_file(base, (directory / "Hero.pck").relative_to(base).as_posix())
        files = sorted(p for p in directory.rglob("*") if p.is_file())
        for path in files:
            contained_file(base, path.relative_to(base).as_posix())
        checked = 0
        if target == "linux":
            with tarfile.open(archive, "r:gz") as packed:
                for path in files:
                    member = packed.getmember("Hero/" + path.relative_to(directory).as_posix())
                    if not member.isfile():
                        raise RuntimeError("Expected ordinary Linux archive member")
                    with packed.extractfile(member) as stream:
                        if digest_stream(stream) != digest(path):
                            raise RuntimeError(f"Archive member differs: {member.name}")
                    checked += 1
        else:
            with zipfile.ZipFile(archive) as packed:
                if packed.testzip() is not None:
                    raise RuntimeError("Final ZIP failed integrity check")
                if target == "macos":
                    with zipfile.ZipFile(binary) as original:
                        for member in original.infolist():
                            if member.is_dir():
                                continue
                            with original.open(member) as left, packed.open(member.filename) as right:
                                if digest_stream(left) != digest_stream(right):
                                    raise RuntimeError(f"macOS bundle member differs: {member.filename}")
                            checked += 1
                    files = [p for p in files if p != binary]
                for path in files:
                    member = path.relative_to(directory).as_posix()
                    if target == "windows":
                        member = "Hero/" + member
                    with packed.open(member) as stream:
                        if digest_stream(stream) != digest(path):
                            raise RuntimeError(f"Archive member differs: {member}")
                    checked += 1
                if target == "macos":
                    work = PurePosixPath(report.get("platform_work_directory", "."))
                    if work.is_absolute() or ".." in work.parts:
                        raise RuntimeError("Unsafe platform work directory")
                    audit = contained_file(base, (work / "macos-audit.pck").as_posix())
                    if audit.is_file():
                        packs = [n for n in packed.namelist() if n.endswith(".pck")]
                        if len(packs) != 1:
                            raise RuntimeError("Expected exactly one macOS PCK")
                        with packed.open(packs[0]) as stream:
                            if digest_stream(stream) != digest(audit):
                                raise RuntimeError("macOS audit PCK differs from shipped PCK")
                        checked += 1
        rows.append({"platform": target, "archive": name, "sha256": expected["sha256"], "members_compared": checked})
    if not rows:
        raise RuntimeError("No verified platform archives")
    return {"verified_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
            "source_git_commit": report.get("source_git_commit"),
            "source_manifest_sha256": report["source_manifest_sha256"],
            "platform_work_directory": report.get("platform_work_directory", "."),
            "archives": rows,
            "scope": "Read-only member-byte verification. This does not prove native processes have closed and does not authorize or perform cleanup."}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("build", type=Path)
    args = parser.parse_args()
    try:
        print(json.dumps(verify_build(args.build), ensure_ascii=False, indent=2))
    except (OSError, ValueError, RuntimeError, KeyError, tarfile.TarError, zipfile.BadZipFile) as error:
        parser.exit(1, f"ARCHIVE VERIFICATION FAILED: {error}\n")
