#!/usr/bin/env python3
"""Extract plain text from a .docx file using only the Python standard library.

A .docx is a ZIP archive; the body text lives in word/document.xml.
We pull paragraph (<w:p>) and tab/break runs and emit one line per paragraph,
which preserves speaker turns in an interview transcript.

Usage: python3 extract_docx.py <path-to-docx>
"""
import sys
import zipfile
import xml.etree.ElementTree as ET

W = "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}"


def extract(path: str) -> str:
    try:
        with zipfile.ZipFile(path) as z:
            if "word/document.xml" not in z.namelist():
                raise ValueError(
                    "Not a Word .docx (word/document.xml missing). "
                    "If this is .doc or RTF, convert it to .docx first."
                )
            xml = z.read("word/document.xml")
    except zipfile.BadZipFile:
        raise ValueError(
            "File is not a valid .docx (not a ZIP archive). "
            "It may be a legacy .doc, RTF, or corrupt."
        )

    root = ET.fromstring(xml)
    lines = []
    for para in root.iter(f"{W}p"):
        parts = []
        for node in para.iter():
            tag = node.tag
            if tag == f"{W}t":
                parts.append(node.text or "")
            elif tag == f"{W}tab":
                parts.append("\t")
            elif tag in (f"{W}br", f"{W}cr"):
                parts.append("\n")
        line = "".join(parts).strip()
        if line:
            lines.append(line)
    return "\n".join(lines)


def main():
    if len(sys.argv) != 2:
        print("Usage: python3 extract_docx.py <path-to-docx>", file=sys.stderr)
        sys.exit(2)
    path = sys.argv[1]
    try:
        text = extract(path)
    except FileNotFoundError:
        print(f"Error: file not found: {path}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:  # surface a clean message to the caller
        print(f"Error extracting docx: {e}", file=sys.stderr)
        sys.exit(1)
    if not text.strip():
        print("Error: no text extracted (empty document?)", file=sys.stderr)
        sys.exit(1)
    print(text)


if __name__ == "__main__":
    main()
