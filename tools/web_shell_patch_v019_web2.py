#!/usr/bin/env python3
"""Patch an exact existing Hero Web1 index.html into a NEW staged Web2 file.

No network, archive extraction, deletion, or in-place edit. The original 13
non-HTML assets remain unchanged. Verify the deployment manifest before switch.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path

ORIGINAL_SHA256 = 'a4b1a6c642d0ac1d8ee448a12039dc7cf400acc986b613273d2c74bb32797d14'
RESULT_SHA256 = 'dc43baa0bc3a6b870f50b5a288d45501cd5ec4b24764cfa729b2772abcf1e48f'
ORIGINAL_BYTES = 8121
RESULT_BYTES = 9095
VISIBLE_VERSION = "0.0.19 · Web 2"
EDITS = [
  [
    44,
    45,
    "\tpadding: 0 8px;\n",
    "\tpadding: 0 156px 0 8px;\n"
  ],
  [
    61,
    61,
    "",
    "}\n\n#build-notice {\n\tposition: fixed;\n\ttop: 0;\n\tright: 8px;\n\theight: 20px;\n\tpadding-left: 8px;\n\tborder-left: 1px solid #58715e;\n\tcolor: #dcc58d;\n\tbackground: #091c1d;\n\tfont-size: 11px;\n\tline-height: 20px;\n\twhite-space: nowrap;\n\tpointer-events: none;\n\tz-index: 4;\n"
  ],
  [
    191,
    191,
    "",
    "\t\t<span id=\"build-notice\" data-game-version=\"0.0.19\" data-web-revision=\"2\">0.0.19 · Web 2</span>\n"
  ],
  [
    213,
    213,
    "",
    "\tconst buildNotice = document.getElementById('build-notice');\n"
  ],
  [
    224,
    224,
    "",
    "\t\tgetBuildInfo: function () {\n\t\t\treturn JSON.stringify({ game_version: buildNotice.dataset.gameVersion, web_revision: buildNotice.dataset.webRevision });\n\t\t},\n"
  ],
  [
    265,
    266,
    "\tfunction displayFailureNotice(err) {\n",
    "\tfunction displayFailureNotice(err, caption = '游戏未能启动，请查看下方原因后重试。') {\n"
  ],
  [
    267,
    268,
    "\t\tstatusCaption.textContent = '加载未能完成。请确认已完整上传导出文件，并通过网站地址打开。';\n",
    "\t\tstatusCaption.textContent = caption;\n"
  ],
  [
    314,
    316,
    "\t\t\tconst missingMsg = '当前浏览器缺少运行游戏所需的功能：\\n';\n\t\t\tdisplayFailureNotice(missingMsg + missing.join('\\n'));\n",
    "\t\t\tconst lacksGraphics = missing.some((feature) => feature.startsWith('WebGL2'));\n\t\t\tconst caption = lacksGraphics\n\t\t\t\t? '当前浏览器无法提供 WebGL 2 图形功能，游戏尚未启动。'\n\t\t\t\t: '当前浏览器缺少运行游戏所需的功能，游戏尚未启动。';\n\t\t\tconst guidance = lacksGraphics\n\t\t\t\t? '请在支持 WebGL 2 的桌面浏览器中打开此页。'\n\t\t\t\t: '请使用较新的桌面浏览器重新打开此页。';\n\t\t\tdisplayFailureNotice(guidance + '\\n\\n功能检查结果：\\n' + missing.join('\\n'), caption);\n"
  ]
]


def transform(original):
    if len(original) != ORIGINAL_BYTES or hashlib.sha256(original).hexdigest() != ORIGINAL_SHA256:
        raise ValueError("Input is not the verified existing Web1 HTML")
    lines = original.decode("utf-8").splitlines(keepends=True)
    for start, end, expected, replacement in reversed(EDITS):
        if "".join(lines[start:end]) != expected:
            raise ValueError("Source patch context differs")
        lines[start:end] = replacement.splitlines(keepends=True)
    result = "".join(lines).encode("utf-8")
    if len(result) != RESULT_BYTES or hashlib.sha256(result).hexdigest() != RESULT_SHA256:
        raise ValueError("Output differs from the reviewed Web2 HTML")
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.input.name != "index.html":
        parser.error("Input must be the existing index.html")
    if args.input.resolve() == args.output.resolve() or args.output.exists():
        parser.error("Output must be a separate new staged file")
    if args.input.stat().st_size != ORIGINAL_BYTES:
        parser.error("Input size differs; nothing written")
    result = transform(args.input.read_bytes())
    with args.output.open("xb") as output:
        output.write(result)
        output.flush()
        os.fsync(output.fileno())
    print(json.dumps({"input_sha256": ORIGINAL_SHA256, "output_sha256": RESULT_SHA256,
                      "bytes": len(result), "version": VISIBLE_VERSION, "output": str(args.output)}))


if __name__ == "__main__":
    main()
