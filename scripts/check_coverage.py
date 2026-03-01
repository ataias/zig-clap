#!/usr/bin/env python3
"""Parse a Cobertura XML report and check line coverage against a threshold."""

import sys
import xml.etree.ElementTree as ET


def main() -> int:
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <cobertura.xml> <threshold>", file=sys.stderr)
        return 2

    xml_path = sys.argv[1]
    try:
        threshold = float(sys.argv[2])
    except ValueError:
        print(f"Error: threshold must be a number, got {sys.argv[2]!r}", file=sys.stderr)
        return 2

    try:
        tree = ET.parse(xml_path)
    except (ET.ParseError, FileNotFoundError) as e:
        print(f"Error: cannot parse {xml_path}: {e}", file=sys.stderr)
        return 2

    rate_str = tree.getroot().get("line-rate")
    if rate_str is None:
        print(f"Error: no line-rate attribute in {xml_path}", file=sys.stderr)
        return 2

    try:
        coverage = float(rate_str) * 100
    except ValueError:
        print(f"Error: line-rate is not a number: {rate_str!r}", file=sys.stderr)
        return 2

    print(f"Coverage: {coverage:.1f}%  (threshold: {threshold:.0f}%)")
    if coverage < threshold:
        print(f"FAIL: {coverage:.1f}% < {threshold:.0f}%")
        return 1

    print(f"OK: {coverage:.1f}% >= {threshold:.0f}%")
    return 0


if __name__ == "__main__":
    sys.exit(main())
