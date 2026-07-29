#!/usr/bin/env python3
"""Print the pkgcheck findings a pull request adds, dropping the ones already there.

pkgcheck plain output puts a package on its own line and indents its findings under
it. Findings are matched by package, keyword and version rather than by the whole
message, so one that merely moved to another line does not count as new.

Usage: pkgcheck-new-findings.py BASE_REPORT HEAD_REPORT
"""

import sys


def parse(path):
    """Map (package, keyword, version) to the finding as pkgcheck printed it."""
    findings = {}
    package = None
    with open(path) as report:
        for line in report:
            line = line.rstrip("\n")
            if not line:
                continue
            if not line.startswith(" "):
                package = line
                continue
            keyword, _, rest = line.strip().partition(": ")
            version = rest.split(":")[0] if rest.startswith("version ") else ""
            findings[(package, keyword, version)] = line
    return findings


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    existing = parse(sys.argv[1])
    added = {key: line for key, line in parse(sys.argv[2]).items() if key not in existing}

    package = None
    for (pkg, _, _), line in added.items():
        if pkg != package:
            if package is not None:
                print()
            print(pkg)
            package = pkg
        print(line)


if __name__ == "__main__":
    main()
