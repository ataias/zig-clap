#!/usr/bin/env python3
"""Parse Cobertura XML coverage reports and print a summary with uncovered lines.

Usage:
    coverage_report.py [<cobertura.xml>]

If no path is given, searches zig-out/coverage/ for the most recent cobertura.xml.

Output format:
    Coverage: <pct>%
    <filename>:<line_number>
    <filename>:<line_number>
    ...

Exits 0 on success, 2 on usage/parse errors.
"""

import glob
import os
import sys
import xml.etree.ElementTree as ET


def find_cobertura_xml() -> str | None:
    candidates = glob.glob("zig-out/coverage/**/cobertura.xml", recursive=True)
    if not candidates:
        return None
    return max(candidates, key=os.path.getmtime)


def report(xml_path: str) -> int:
    try:
        tree = ET.parse(xml_path)
    except (ET.ParseError, FileNotFoundError) as e:
        print(f"Error: cannot parse {xml_path}: {e}", file=sys.stderr)
        return 2

    root = tree.getroot()
    rate_str = root.get("line-rate")
    if rate_str is None:
        print(f"Error: no line-rate attribute in {xml_path}", file=sys.stderr)
        return 2

    try:
        coverage = float(rate_str) * 100
    except ValueError:
        print(f"Error: line-rate is not a number: {rate_str!r}", file=sys.stderr)
        return 2

    print(f"Coverage: {coverage:.1f}%")

    uncovered: list[str] = []
    for cls in root.findall(".//class"):
        filename = cls.get("filename", "")
        for line in cls.findall(".//line"):
            if line.get("hits") == "0":
                uncovered.append(f"{filename}:{line.get('number')}")

    if uncovered:
        print(f"Uncovered lines ({len(uncovered)}):")
        for loc in uncovered:
            print(f"  {loc}")
    else:
        print("All lines covered.")

    return 0


def main() -> int:
    if len(sys.argv) > 2:
        print(f"Usage: {sys.argv[0]} [<cobertura.xml>]", file=sys.stderr)
        return 2

    if len(sys.argv) == 2:
        xml_path = sys.argv[1]
    else:
        xml_path = find_cobertura_xml()
        if xml_path is None:
            print(
                "Error: no cobertura.xml found in zig-out/coverage/. "
                "Run ./scripts/coverage.sh first.",
                file=sys.stderr,
            )
            return 2
        print(f"Using: {xml_path}")

    return report(xml_path)


if __name__ == "__main__":
    sys.exit(main())
