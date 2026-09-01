#!/usr/bin/env python3
"""Print a package's autobump engine flags, one per line.

Shared by autobump-sweep, autobump-probe, autobump-trial.yml and autobump-recommend.yml:
the two workflows call the engine directly, so without this a trial ran with different
flags than the sweep it is meant to predict.

    mapfile -t args < <(python3 scripts/autobump-args.py <category/package>)
    python3 scripts/autobump-args.py --describe <category/package>   # one phrase for the issue comment

Exit 2 with a reason when the table asks for something the engine cannot honour.
"""
import sys
import tomllib

DEFAULT_TOML = ".github/workflows/overlay.toml"


def die(reason):
    print(reason, file=sys.stderr)
    raise SystemExit(2)


def keep_old_flag(pkg, value):
    """`autobump` carries the retention: true replaces, N keeps N, "all" keeps every one."""
    if value in (None, True, False, 0):
        return []
    if value == "all":
        return ["--keep-old"]
    if isinstance(value, int) and value > 0:
        return [f"--keep-old={value}"]
    die(f"{pkg}: unsupported autobump value {value!r}")


def rewrite_flags(pkg, table):
    """`autobump_<variable>_regex` names the ebuild variable to rewrite in its own key."""
    names = sorted(k[len("autobump_"):-len("_regex")]
                   for k in table if k.startswith("autobump_") and k.endswith("_regex"))
    if not names:
        return []
    if len(names) > 1:
        die(f"{pkg}: {len(names)} rewrite specs but the engine takes one")
    name = names[0]
    url = table.get(f"autobump_{name}_url") or table.get("url")
    if not url:
        die(f"{pkg}: rewrite of {name.upper()} has no url, and the entry has none to fall back on")
    return ["--rewrite-var", name.upper(),
            "--rewrite-url", url,
            "--rewrite-regex", table[f"autobump_{name}_regex"]]


def describe(flags):
    """The same settings in words, for the status comment autobump leaves on the issue."""
    said = []
    for flag in flags:
        if flag == "--keep-old":
            said.append("keeps every old version")
        elif flag.startswith("--keep-old="):
            said.append(f"keeps {flag.removeprefix('--keep-old=')} old versions")
        elif flag == "--rewrite-var":
            said.append("rewrites a pinned variable")
    return "".join(f" · {s}" for s in said)


def main(argv):
    argv = argv[1:]
    as_words = argv and argv[0] == "--describe"
    if as_words:
        argv = argv[1:]
    pkg = argv[0]
    path = argv[1] if len(argv) > 1 else DEFAULT_TOML
    with open(path, "rb") as f:
        table = tomllib.load(f).get(pkg, {})
    flags = keep_old_flag(pkg, table.get("autobump")) + rewrite_flags(pkg, table)
    print(describe(flags) if as_words else "\n".join(flags))


if __name__ == "__main__":
    main(sys.argv)
