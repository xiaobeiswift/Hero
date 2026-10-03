# Folio heading font · Noto Serif CJK SC 2.003

Runtime file: `NotoSerifSC-Regular.woff2`, 16,708,712 bytes, SHA-256 `4411e803d26015b09bd2141d102892a426842aaef1622a99d641e45e378b2b2c`. Internal family/name tables remain Noto Serif CJK SC / NotoSerifCJKsc-Regular. The shorter project filename does not rename the font.

The full Simplified Chinese Regular face was extracted from already installed `NotoSerifCJK-Regular.ttc`, face index2. Its 26,411,360 bytes match official Noto Serif CJK Serif2.003: SHA-256 `5d9c31a059600193c9d7968a998bde886ccdc77e934006ad243b41794c496a7d`, Git blob `e72653a3a41fc9a8930e0cb40af310c4472a753b`, fixed upstream commit `9b0f1436e455d902de067a2501422e5dc71ad16b`. No binary was downloaded.

Official source: https://github.com/notofonts/noto-cjk/blob/9b0f1436e455d902de067a2501422e5dc71ad16b/Serif/OTC/NotoSerifCJK-Regular.ttc
Official license: https://github.com/notofonts/noto-cjk/blob/9b0f1436e455d902de067a2501422e5dc71ad16b/Serif/LICENSE

## License
Distribute `NotoSerifSC-OFL.txt` (complete SIL OFL1.1) and `NotoSerifSC-NOTICE.txt` (actual embedded Adobe2017–2024 copyright and author credits). No Reserved Font Name is declared. Font data remains OFL; no upstream endorsement is implied. Do not sell the font alone. The installed Debian packaging has separate licensing from font data.

## Extraction and compression audit
All16 SFNT tables,65,535 glyphs and44,777 best-cmap Unicode entries remain present; no subset or outline/metric/layout/name/cmap edits. Standalone OTF extraction changes only container offsets and head.checkSumAdjustment. Lossless WOFF2 uses existing fontTools4.57.0/Brotli1.1.0. Decompression preserves every original table byte except regenerated checksum and the WOFF2-mandated head.flags bit11. Original shared CFF data carries a JP label internally; SC regional name/cmap/layout selection is retained and Fontconfig identifies SC Regular.

Exact extraction, official blob comparisons, whole-file/table hashes and WOFF2 round-trip checks are retained in `tests/folio_font_extraction_audit.json`; license provenance in `tests/folio_font_license_audit.json`. Those records use preparation-relative runtime/reference/optional paths: only runtime/NotoSerifCJKsc-Regular.woff2 was copied, byte-identically, to this project's NotoSerifSC-Regular.woff2. The 24,543,056-byte reference OTF and25,521,436-byte optional Bold are not shipped.

## Integration and limits
Use serif only for native folio headings, keeping existing Noto Sans SC body font. Godot4.6 FontFile officially supports WOFF2: https://docs.godotengine.org/en/4.6/classes/class_fontfile.html . Full glyph coverage is preserved rather than guessed from current titles; future unsupported symbols/localizations still need proper fallback.

Source-asset compression saves7,834,344 bytes (31.9%) against the extracted full OTF. No exact package size, startup/memory improvement, native import/render, legibility or release acceptance is implied; those checks remain pending. The existing1/1.25/1.6 setting scales the world, not journal fonts.

The project-specific NOTICE updates only the license filename reference from the preparation name LICENSE.txt to NotoSerifSC-OFL.txt. Original author/copyright text remains. No trademark notice is claimed as part of that NOTICE.
