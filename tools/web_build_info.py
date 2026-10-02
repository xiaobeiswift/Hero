"""Bind visible Web identity to the exact runtime project version and revision."""
from html.parser import HTMLParser
from pathlib import Path
import re

BADGE = '<span id="build-notice" data-game-version="" data-web-revision="">构建信息待生成</span>'
VERSION = re.compile(r"\d+\.\d+\.\d+(?:[-+][A-Za-z0-9.-]+)?")


def project_version(project_text):
    section = re.search(r"(?ms)^\[application\]\s*\n(.*?)(?=^\[|\Z)", project_text)
    values = re.findall(r'^config/version="([^"\n]+)"$', section.group(1), re.M) if section else []
    if len(values) != 1 or VERSION.fullmatch(values[0]) is None:
        raise ValueError("Require one explicit application/config/version")
    return values[0]


def caption(version, revision):
    if not isinstance(version, str) or VERSION.fullmatch(version) is None:
        raise ValueError("Invalid game version")
    if type(revision) is not int or revision < 1:
        raise ValueError("Web revision must be a positive integer")
    return f"{version} · Web {revision}"


def stamp(html, version, revision):
    label = caption(version, revision)
    if html.count(BADGE) != 1:
        raise ValueError("Require exactly one unstamped build badge")
    result = html.replace(BADGE, f'<span id="build-notice" data-game-version="{version}" data-web-revision="{revision}">{label}</span>', 1)
    validate(result, version, revision)
    return result


def validate(html, version, revision):
    expected = caption(version, revision)
    class Parser(HTMLParser):
        def __init__(self):
            super().__init__(); self.matches = []; self.active = False
        def handle_starttag(self, tag, attrs):
            values = dict(attrs)
            if values.get("id") == "build-notice":
                self.matches.append({"tag": tag, "attrs": values, "text": ""}); self.active = True
        def handle_data(self, text):
            if self.active: self.matches[-1]["text"] += text
        def handle_endtag(self, tag):
            if tag == "span": self.active = False
    parsed = Parser(); parsed.feed(html)
    if len(parsed.matches) != 1:
        raise ValueError("Missing or duplicated build identity")
    found = parsed.matches[0]
    if found["tag"] != "span" or found["attrs"].get("data-game-version") != version or found["attrs"].get("data-web-revision") != str(revision) or found["text"] != expected:
        raise ValueError("Visible version and deployment identity differ")
    return {"game_version": version, "web_revision": revision, "caption": expected}


def read_project_version(path):
    return project_version(Path(path).read_text(encoding="utf-8"))
