#!/usr/bin/env python3
"""Fail when a role or shared module imports a path under hosts/.

Layering runs host -> role -> module. A role or module that imports a host
inverts that order, so any such import is a violation. Matches inside comments
and string literals are ignored: a path in prose or data is not an import.

Run with --self-test to prove the checker still detects violations and still
ignores prose.
"""

import re
import sys
import tempfile
from pathlib import Path

SEARCH_DIRS = ("roles", "modules")
# Any code reference counts, not only one inside an `imports` list. A role or
# module has no reason to name a hosts/ path in code at all, and matching every
# reference also catches the indirect spellings (a `let` binding, an attribute
# set passed down) that an imports-only match would miss.
HOSTS_REF = re.compile(r"(?<![\w.-])hosts/")


def code_only(text):
    """Blank out comments and string bodies, keeping offsets and newlines."""
    out = list(text)
    i, n = 0, len(text)

    def blank(start, end):
        for k in range(start, min(end, n)):
            if out[k] != "\n":
                out[k] = " "

    while i < n:
        if text.startswith("/*", i):
            end = text.find("*/", i + 2)
            end = n if end == -1 else end + 2
            blank(i, end)
            i = end
        elif text[i] == "#":
            end = text.find("\n", i)
            end = n if end == -1 else end
            blank(i, end)
            i = end
        elif text[i] == '"':
            j = i + 1
            while j < n:
                if text[j] == "\\":
                    j += 2
                    continue
                if text[j] == '"':
                    j += 1
                    break
                j += 1
            blank(i, j)
            i = j
        elif text.startswith("''", i):
            j = i + 2
            while j < n:
                if text.startswith("''", j):
                    nxt = text[j + 2 : j + 3]
                    if nxt and nxt in "'$\\":
                        j += 3
                        continue
                    j += 2
                    break
                j += 1
            blank(i, j)
            i = j
        else:
            i += 1
    return "".join(out)


def find_violations(paths):
    violations = []
    for path in paths:
        text = Path(path).read_text(encoding="utf-8", errors="replace")
        for lineno, line in enumerate(code_only(text).splitlines(), start=1):
            if HOSTS_REF.search(line):
                violations.append(f"{path}:{lineno}: imports a path under hosts/")
    return violations


def collect(root="."):
    paths = []
    for name in SEARCH_DIRS:
        base = Path(root) / name
        if base.is_dir():
            paths.extend(sorted(str(p) for p in base.rglob("*.nix")))
    return paths


def self_test():
    cases = {
        "good.nix": """{ ... }: {
  # hosts/tower/default.nix would be wrong here
  imports = [ ../modules/base.nix ];
  text = "hosts/tower/default.nix is prose";
  note = ''
    hosts/tower/default.nix is prose too
  '';
}
""",
        "bad.nix": """{ ... }: {
  imports = [ ../hosts/tower/default.nix ];
}
""",
        "escape.nix": """{ ... }: {
  note = ''
    it'''s fine, hosts/ is prose
  '';
  imports = [ ../hosts/work-laptop/default.nix ];
}
""",
        "block.nix": """{ ... }: {
  /* hosts/tower/default.nix in a block comment */
  imports = [ ../modules/base.nix ];
}
""",
    }

    with tempfile.TemporaryDirectory() as tmp:
        base = Path(tmp) / "roles"
        base.mkdir()
        for name, body in cases.items():
            (base / name).write_text(body, encoding="utf-8")
        prefix = f"{base}/"
        got = [line.replace(prefix, "") for line in find_violations(collect(tmp))]

    expected = [
        "bad.nix:2: imports a path under hosts/",
        "escape.nix:5: imports a path under hosts/",
    ]

    if got != expected:
        print("self-test FAILED", file=sys.stderr)
        print(f"  expected: {expected}", file=sys.stderr)
        print(f"  actual:   {got}", file=sys.stderr)
        return 1
    print("self-test passed: 2 violations found, 2 prose cases ignored")
    return 0


def main(argv):
    if "--self-test" in argv:
        return self_test()

    violations = find_violations(collect())
    if violations:
        for line in violations:
            print(line, file=sys.stderr)
        return 1
    print("Layering OK: no role or module imports hosts/.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
