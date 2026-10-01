#!/usr/bin/env bash
# Download only from Godot's official release service; verify the pinned vendor digest.
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION=4.6.3
ARCHIVE="Godot_v${VERSION}-stable_export_templates.tpz"
CACHE="${HERO_TEMPLATE_CACHE:-$ROOT/builds/template-cache}"
DATA="${HERO_EXPORT_DATA:-$ROOT/builds/export-data}"
TARGET="$DATA/godot/export_templates/$VERSION.stable"
EXPECTED=da606b61c10157844f8300172df374472665f95015495cb1a7cd132c40ede404faa96cc1016a4b9662db9909ddea69632c4948b2cd11163438dad4808881fb68
# Pinned from https://github.com/godotengine/godot-builds/releases/download/4.6.3-stable/SHA512-SUMS.txt
mkdir -p "$CACHE" "$TARGET"
if [[ ! -f "$CACHE/$ARCHIVE" ]]; then
  curl --fail --location --retry 2 --output "$CACHE/$ARCHIVE.part" \
    "https://downloads.godotengine.org/?flavor=stable&platform=templates&slug=export_templates.tpz&version=$VERSION"
  mv "$CACHE/$ARCHIVE.part" "$CACHE/$ARCHIVE"
fi
python3 - "$CACHE/$ARCHIVE" "$TARGET" "$EXPECTED" <<'PY'
import hashlib, pathlib, shutil, sys, zipfile
archive, target, expected = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]), sys.argv[3]
with archive.open('rb') as f:
    actual = hashlib.file_digest(f, 'sha512').hexdigest()
if actual != expected:
    raise SystemExit(f'Export template SHA-512 mismatch: {actual}; refusing to extract')
names = ['version.txt', 'linux_debug.x86_64', 'linux_release.x86_64',
         'windows_debug_x86_64.exe', 'windows_debug_x86_64_console.exe',
         'windows_release_x86_64.exe', 'windows_release_x86_64_console.exe', 'macos.zip']
with zipfile.ZipFile(archive) as z:
    if z.read('templates/version.txt').decode().strip() != '4.6.3.stable':
        raise SystemExit('Unexpected template version; refusing to install')
    for name in names:
        # A fixed allowlist prevents traversal and avoids extracting mobile/web templates.
        out = target / name
        with z.open('templates/' + name) as source, out.open('wb') as dest:
            shutil.copyfileobj(source, dest)
        if name.startswith('linux_'):
            out.chmod(0o755)
print(f'Verified official Godot 4.6.3 templates installed at {target}')
PY
