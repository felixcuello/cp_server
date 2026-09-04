#!/bin/sh
# Convert installed man 2/3/7/2p/3p pages to HTML under /usr/share/sandbox-man.
# Must run at image build. Request handling must never call man or a shell.

set -eu

OUT_ROOT="${SANDBOX_MAN_ROOT:-/usr/share/sandbox-man}"

if ! command -v mandoc >/dev/null 2>&1; then
  echo "mandoc is not installed" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is not installed" >&2
  exit 1
fi

python3 - "$OUT_ROOT" <<'PY'
import gzip
import html as htmlmod
import json
import os
import re
import subprocess
import sys
from pathlib import Path

OUT_ROOT = Path(sys.argv[1])
SECTIONS = {"2", "3", "7", "2p", "3p"}
SOURCE_SECTIONS = {
    "2": "2",
    "3": "3",
    "7": "7",
    "2p": "2p",
    "3p": "3p",
    "2posix": "2p",
    "3posix": "3p",
}
SECTION_DIRS = ("man2", "man3", "man7", "man2p", "man3p")
LOCALES = (("en", Path("/usr/share/man")), ("es", Path("/usr/share/man/es")))
FILENAME_RE = re.compile(r"^(.+)\.(\d+[a-z]*)(?:\.gz)?$")
XR_HREF_RE = re.compile(
    r'href="[^"]*?([A-Za-z0-9._+-]+)\.(\d+[a-z]*)(?:\.html)?"',
    re.IGNORECASE,
)
XR_MAN_HREF_RE = re.compile(
    r'href="man:([A-Za-z0-9._+-]+)\((\d+[a-z]*)\)"',
    re.IGNORECASE,
)
XR_TEXT_RE = re.compile(
    r'<(?:a|span)\b[^>]*class="Xr"[^>]*>\s*([A-Za-z0-9._+-]+)\((\d+[a-z]*)\)\s*</(?:a|span)>',
    re.IGNORECASE,
)
ND_RE = re.compile(r"^\.Nd\s+(.+)$", re.MULTILINE)
NAME_SH_RE = re.compile(
    r'^\.SH\s+"?NAME"?\s*$\n(.+?)(?=\n\.SH|\Z)',
    re.MULTILINE | re.IGNORECASE | re.DOTALL,
)
HTML_ND_RE = re.compile(r'class="Nd"[^>]*>([^<]+)')
BODY_RE = re.compile(r"<body[^>]*>(.*)</body>", re.IGNORECASE | re.DOTALL)


def parse_filename(path):
    match = FILENAME_RE.match(path.name)
    if not match:
        return None
    name, source_section = match.group(1), match.group(2)
    section = SOURCE_SECTIONS.get(source_section)
    if not section:
        return None
    return name, section


def read_man_bytes(path, depth=0):
    if depth > 8:
        raise OSError("man page alias chain is too deep")

    data = path.read_bytes()
    if path.name.endswith(".gz") or data[:2] == b"\x1f\x8b":
        try:
            data = gzip.decompress(data)
        except OSError:
            pass

    alias = re.fullmatch(rb"\s*\.so\s+(\S+)\s*", data)
    if not alias:
        return data

    target = path.parent.parent / alias.group(1).decode("utf-8", "replace")
    candidates = (target, Path(str(target) + ".gz"))
    for candidate in candidates:
        if candidate.is_file():
            return read_man_bytes(candidate, depth + 1)

    return data


def clean_roff(text):
    text = text.replace("\\-", "-")
    text = re.sub(r"\\f(?:[A-Z]|\\(.*?\\))", "", text)
    text = re.sub(r"\\[.&]", "", text)
    text = re.sub(r"\s+", " ", text)
    return text.strip().strip('"')


def title_from_source(raw):
    text = raw.decode("utf-8", "replace")
    match = ND_RE.search(text)
    if match:
        return clean_roff(match.group(1))
    match = NAME_SH_RE.search(text)
    if not match:
        return ""
    line = match.group(1).split("\n")[0]
    line = clean_roff(line)
    parts = re.split(r"\s+-\s+", line, maxsplit=1)
    if len(parts) == 2:
        return parts[1].strip()
    return ""


def title_from_html(html):
    match = HTML_ND_RE.search(html)
    if match:
        return re.sub(r"\s+", " ", match.group(1)).strip()
    return ""


def man_anchor(name, source_section, inner=None):
    section = SOURCE_SECTIONS.get(source_section, source_section)
    safe_name = htmlmod.escape(name, quote=True)
    safe_section = htmlmod.escape(section, quote=True)
    label = inner if inner is not None else "%s(%s)" % (htmlmod.escape(name), htmlmod.escape(section))
    return (
        f'<a href="#" data-man-name="{safe_name}" '
        f'data-man-section="{safe_section}">{label}</a>'
    )


def rewrite_links(html):
    def href_repl(match):
        return 'href="#" data-man-name="%s" data-man-section="%s"' % (
            htmlmod.escape(match.group(1), quote=True),
            htmlmod.escape(SOURCE_SECTIONS.get(match.group(2), match.group(2)), quote=True),
        )

    html = XR_HREF_RE.sub(href_repl, html)
    html = XR_MAN_HREF_RE.sub(href_repl, html)

    def text_repl(match):
        if "data-man-name" in match.group(0):
            return match.group(0)
        return man_anchor(match.group(1), match.group(2))

    return XR_TEXT_RE.sub(text_repl, html)


def mandoc_html(raw):
    proc = subprocess.run(
        ["mandoc", "-T", "html", "-O", "fragment,man=%N.%S.html"],
        input=raw,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if proc.returncode != 0 or not proc.stdout.strip():
        proc = subprocess.run(
            ["mandoc", "-T", "html", "-O", "man=%N.%S.html"],
            input=raw,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
    html = proc.stdout.decode("utf-8", "replace")
    if proc.returncode != 0 and not html.strip():
        return None
    body = BODY_RE.search(html)
    if body:
        html = body.group(1)
    return rewrite_links(html)


def convert_one(src):
    parsed = parse_filename(src)
    if not parsed:
        return None
    name, section = parsed
    try:
        raw = read_man_bytes(src)
    except OSError:
        return None
    html = mandoc_html(raw)
    if not html or not html.strip():
        return None
    title = title_from_source(raw) or title_from_html(html)
    return name, section, html, title


def copy_licenses(out_root):
    parts = []
    for doc in (
        "/usr/share/doc/manpages/copyright",
        "/usr/share/doc/manpages-dev/copyright",
        "/usr/share/doc/manpages-posix/copyright",
        "/usr/share/doc/manpages-posix-dev/copyright",
        "/usr/share/doc/manpages-es/copyright",
        "/usr/share/doc/manpages-es-dev/copyright",
    ):
        path = Path(doc)
        if path.is_file():
            parts.append("---- %s ----\n%s\n" % (path, path.read_text(errors="replace")))
    if parts:
        (out_root / "COPYING").write_text("\n".join(parts), encoding="utf-8")


NESTED_LOCALES = {
    "es", "de", "fr", "it", "pt", "nl", "pl", "ru", "ja", "zh_CN", "zh_TW",
}


def locale_files(locale, base):
    if not base.is_dir():
        print("missing man root: %s" % base, file=sys.stderr)
        return []

    files = []
    for path in sorted(base.rglob("*")):
        if not path.is_file():
            continue
        if locale == "en":
            rel = path.relative_to(base)
            if rel.parts and rel.parts[0] in NESTED_LOCALES:
                continue
        if parse_filename(path):
            files.append(path)
    print("found %s source pages in %s" % (len(files), base), file=sys.stderr)
    return files


def dump_man_tree():
    root = Path("/usr/share/man")
    print("listing %s" % root, file=sys.stderr)
    if not root.exists():
        print("  (missing)", file=sys.stderr)
        return
    for child in sorted(root.iterdir()):
        extra = ""
        if child.is_dir():
            extra = " dir"
        print("  %s%s" % (child, extra), file=sys.stderr)


def main():
    out_root = OUT_ROOT
    if out_root.exists():
        for child in out_root.iterdir():
            if child.is_dir():
                for p in child.rglob("*"):
                    if p.is_file():
                        p.unlink()
            elif child.is_file():
                child.unlink()
    out_root.mkdir(parents=True, exist_ok=True)

    indexes = {"en": [], "es": []}
    seen = {"en": set(), "es": set()}
    converted = 0
    skipped = 0

    for locale, base in LOCALES:
        files = locale_files(locale, base)
        for src in files:
            result = convert_one(src)
            if not result:
                skipped += 1
                continue
            name, section, html, title = result
            key = (name, section)
            if key in seen[locale]:
                continue
            dest_dir = out_root / locale / section
            dest_dir.mkdir(parents=True, exist_ok=True)
            (dest_dir / ("%s.html" % name)).write_text(html, encoding="utf-8")
            indexes[locale].append({"name": name, "section": section, "title": title})
            seen[locale].add(key)
            converted += 1

    for locale, pages in indexes.items():
        locale_dir = out_root / locale
        locale_dir.mkdir(parents=True, exist_ok=True)
        pages.sort(key=lambda p: (p["name"], p["section"]))
        (locale_dir / "index.json").write_text(
            json.dumps(pages, ensure_ascii=False, indent=0) + "\n",
            encoding="utf-8",
        )

    copy_licenses(out_root)
    print("Converted %s man pages (%s skipped) -> %s" % (converted, skipped, out_root))
    if converted == 0:
        dump_man_tree()
        sys.exit("No man pages converted")


if __name__ == "__main__":
    main()
PY
