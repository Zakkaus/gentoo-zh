#!/usr/bin/env python3

"""Bump the packages nvchecker reported, one issue at a time.

    autobump-sweep.py [issue#...] [--limit N] [--pr] [--comment]
"""

import datetime
from dataclasses import dataclass
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import time


STATUS_MARKER = "<!-- autobump-status -->"
# One hidden marker gives each issue an editable status instead of an unbounded
# stream of "bumping / opened PR / deferred" comments.
SPACE = " \t\r\n\v\f"


@dataclass
class Settings:
    repo: str
    upstream_repo: str
    judge: str
    done: Path
    attempts_ledger: Path
    pr: str
    comment: bool
    limit: str
    issues: list[str]
    engine: str | None


def output(command, *, stderr=None):
    """Run a command and return its status and command-substitution-style stdout."""
    try:
        result = subprocess.run(command, stdout=subprocess.PIPE, stderr=stderr, text=True)
    except FileNotFoundError:
        return 127, ""
    return result.returncode, result.stdout.rstrip("\n")


def combined_output(command):
    """Run a command and return its status and command-substitution-style combined output."""
    try:
        result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    except FileNotFoundError:
        return 127, f"{command[0]}: command not found"
    return result.returncode, result.stdout.rstrip("\n")


def today():
    return datetime.date.today().isoformat()


# Terminal results are never retried for the same package and target; a new upstream
# version has a distinct ledger key and starts fresh.
def append_ledger(path, package, version, result=None):
    fields = (package, version, result, today()) if result else (package, version, today())
    with path.open("a") as f:
        f.write(" ".join(fields) + "\n")


def matching_line(path, package, version):
    needle = f"{package} {version} "
    with path.open() as f:
        for line in f:
            if needle in line:
                return line.rstrip("\n")
    return None


def matching_count(path, package, version):
    needle = f"{package} {version} "
    with path.open() as f:
        return sum(needle in line for line in f)


def parse_args(argv):
    pr = ""
    comment = False
    limit = "5"
    issues = []
    previous = ""

    for arg in argv:
        if arg == "--pr":
            pr = "--pr"
            previous = ""
        elif arg == "--comment":
            comment = True
            previous = ""
        elif arg == "--limit":
            previous = "limit"
        elif re.match(r"[0-9]", arg):
            if not re.fullmatch(r"[0-9]+", arg):
                print(f"not a number: {arg}", file=sys.stderr)
                raise SystemExit(2)
            if previous == "limit":
                limit = arg
                previous = ""
            else:
                issues.append(arg)
        else:
            print(f"unknown arg: {arg}", file=sys.stderr)
            raise SystemExit(2)

    return pr, comment, limit, issues


# Autobump is an explicit maintainer opt-in. Its value carries retention policy, which
# autobump-args.py turns into engine flags.
#
# TOML permits a trailing comment after a table header. Strip it before the exact match,
# or an opted-in package with an annotated header is silently skipped.
def autobump_enabled(path, package):
    wanted_header = f'["{package}"]'
    in_package = False
    found = False

    try:
        with path.open() as f:
            for original in f:
                original = original.rstrip("\n")
                header = re.sub(r"[ \t\r\v\f]*#.*", "", original).rstrip(SPACE)
                if header == wanted_header:
                    in_package = True
                    continue
                if original.startswith("["):
                    in_package = False
                if (in_package
                        and re.match(r"^[ \t\r\v\f]*autobump[ \t\r\v\f]*=", header)
                        and not re.search(r"=[ \t\r\v\f]*false", header)):
                    found = True
                    break
    except OSError as error:
        print(error, file=sys.stderr)

    return found


def package_and_version(title):
    packages = []
    versions = []
    for line in title.split("\n"):
        package = re.match(
            r"^\[nvchecker\] ([a-z0-9-]+/[A-Za-z0-9_.+-]+) can be bump to .*",
            line,
        )
        if package:
            packages.append(package.group(1))
        version = re.search(r".* can be bump to ([A-Za-z0-9._+-]+)$", line)
        if version:
            versions.append(version.group(1))
    return "\n".join(packages), "\n".join(versions)


def run_link(upstream_repo, label="run"):
    run_id = os.environ.get("GITHUB_RUN_ID", "")
    if not run_id:
        return ""
    server = os.environ.get("GITHUB_SERVER_URL") or "https://github.com"
    repository = os.environ.get("GITHUB_REPOSITORY") or upstream_repo
    return f" · [{label}]({server}/{repository}/actions/runs/{run_id})"


# A status comment must remain short; detailed evidence belongs in the Actions log or
# the escalation's collapsed evidence block.
def fold(reason):
    reason = re.sub(r"[ \t\r\n\v\f]+", " ", reason).strip(SPACE)
    if len(reason) > 200:
        return f"{reason[:199]}…"
    return reason


def find_status_comment(issue, upstream_repo):
    # A failed FIND must not fall through to CREATE: a transient API error would create
    # a duplicate status comment instead of updating the existing one.
    lookup = (
        "map(select(.body|contains(\"<!-- autobump-status -->\")))|.[0].id // empty"
    )
    for _ in range(3):
        status, comment_id = output(
            [
                "gh",
                "api",
                f"repos/{upstream_repo}/issues/{issue}/comments",
                "--paginate",
                "--jq",
                lookup,
            ],
            stderr=subprocess.DEVNULL,
        )
        if status == 0:
            return comment_id
        time.sleep(3)
    return None


def status_comment(issue, body, *, comment, footer, upstream_repo, status_comment_failed):
    if not comment:
        return

    if footer:
        body = f"{body}\n{footer}"
    body = f"{body}\n\n{STATUS_MARKER}"
    comment_id = find_status_comment(issue, upstream_repo)
    if comment_id is None:
        # Keep a failed update visible in the final summary rather than claiming the issue
        # has current status.
        status_comment_failed.add(issue)
        return

    if comment_id:
        command = [
            "gh",
            "api",
            "-X",
            "PATCH",
            f"repos/{upstream_repo}/issues/comments/{comment_id}",
            "-f",
            f"body={body}",
        ]
    else:
        command = [
            "gh",
            "issue",
            "comment",
            issue,
            "--repo",
            upstream_repo,
            "--body",
            body,
        ]

    for _ in range(3):
        try:
            status = subprocess.run(
                command,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            ).returncode
        except FileNotFoundError:
            status = 127
        if status == 0:
            return
        time.sleep(3)
    # Keep a failed update visible in the final summary rather than claiming the issue
    # has current status.
    status_comment_failed.add(issue)


def tail_lines(text, count):
    print("\n".join(text.split("\n")[-count:]))


# The engine prints this anchor and its temporary directory follows TMPDIR. Do not
# hard-code /tmp: that loses evidence or parses the wrong path on Gentoo systems.
def evidence_directory(text):
    found = []
    for line in text.split("\n"):
        match = re.search(r".*evidence: ([^ ]+) ==.*", line)
        if match:
            found.append(match.group(1))
    return found[-1] if found else ""


def current_version(text):
    for line in text.split("\n"):
        match = re.match(r"^>> current: ([^ ]+) +-> +target:.*", line)
        if match:
            return match.group(1)
    return ""


def evidence_reasons(evidence):
    try:
        with (evidence / "escalations.txt").open() as f:
            reasons = ";".join(line.rstrip("\n") for line in f)
    except OSError:
        reasons = ""
    return reasons.replace(";", "; ") or f"see evidence in {evidence}"


def human_verdict(evidence):
    reason = evidence_reasons(evidence)
    return {
        "verdict": "human",
        "reasons": [reason],
        "use_flags_needed": [],
        "deps_changed": [],
        "issue_comment": f"not mechanically safe: {reason}",
    }


def verdict_value(verdict_json):
    try:
        return json.loads(verdict_json)
    except json.JSONDecodeError:
        return {}


def last_clear_reason(text):
    found = []
    for line in text.split("\n"):
        match = re.search(r".*not mechanically safe \(([^)]+)\).*", line)
        if match:
            found.append(match.group(1))
    return found[-1] if found else ""


def evidence_excerpt(evidence):
    try:
        with (evidence / "escalations.txt").open() as f:
            lines = [line.rstrip("\n").replace("```", "") for line in f]
    except OSError:
        return ""
    filtered = [line for line in lines if not re.fullmatch(r"[ \t\r\v\f]*", line)]
    return "\n".join(filtered[:25])


def read_settings(argv):
    repo = os.environ.get("AUTOBUMP_REPO")
    if not repo:
        _, repo = output(["git", "rev-parse", "--show-toplevel"], stderr=subprocess.DEVNULL)
    upstream_repo = os.environ.get("AUTOBUMP_UPSTREAM_REPO") or "gentoo-zh/overlay"
    # An unset judge deliberately sends every escalation to a human with its evidence.
    # Configure a model only when that semantic judgment is worth the extra call.
    judge = os.environ.get("AUTOBUMP_JUDGE", "")
    state_home = os.environ.get("XDG_STATE_HOME") or f"{os.environ.get('HOME', '')}/.local/state"
    state_dir = Path(state_home) / "autobump"
    done = state_dir / "done.list"
    # ATTEMPTS records only retryable outcomes, so the cap reaches a human without
    # prematurely making a transient failure terminal.
    attempts_ledger = state_dir / "attempts"
    state_dir.mkdir(parents=True, exist_ok=True)
    done.touch(exist_ok=True)
    attempts_ledger.touch(exist_ok=True)

    try:
        os.chdir(repo)
    except OSError:
        return None

    pr, comment, limit, issues = parse_args(argv[1:])
    return Settings(
        repo=repo,
        upstream_repo=upstream_repo,
        judge=judge,
        done=done,
        attempts_ledger=attempts_ledger,
        pr=pr,
        comment=comment,
        limit=limit,
        issues=issues,
        engine=os.environ.get("AUTOBUMP_ENGINE"),
    )


def select_issues(settings):
    # LIMIT caps engine attempts, not fetched issues. Fetch a larger window so free
    # skips below a busy queue do not starve opted-in packages.
    if settings.issues:
        return settings.issues, False

    # Keep a failed gh request distinct from an empty issue list; auth, rate-limit, and
    # network failures must surface as an error instead of silently skipping a sweep.
    status, raw = output(
        [
            "gh",
            "issue",
            "list",
            "--repo",
            settings.upstream_repo,
            "--search",
            "[nvchecker] in:title",
            "--state",
            "open",
            "--limit",
            str(int(settings.limit) * 10),
            "--json",
            "number",
            "--jq",
            ".[].number",
        ]
    )
    if status != 0:
        print("gh issue list failed (auth/rate-limit/network?)", file=sys.stderr)
        return None, True
    return raw.split("\n") if raw else [], True


def copy_tools():
    # Copy helpers before the engine starts switching branches; otherwise a helper that
    # exists only on the starting branch can disappear in the middle of the sweep.
    _, original_branch = output(["git", "branch", "--show-current"])
    tools = Path(tempfile.mkdtemp(prefix="autobump-tools-", dir="/tmp"))
    shutil.copy2("scripts/autobump-judge.sh", tools / "autobump-judge.sh")
    shutil.copy2("scripts/autobump-args.py", tools / "autobump-args.py")
    return tools, original_branch


def engine_words(settings):
    # autobump-rb is the single engine. There is no in-tree fallback to silently use.
    if not settings.engine:
        print("AUTOBUMP_ENGINE: set AUTOBUMP_ENGINE, e.g. ruby autobump-rb/bin/autobump", file=sys.stderr)
        return None
    return shlex.split(settings.engine)


def issue_target(settings, issue):
    _, title = output(
        ["gh", "issue", "view", issue, "--repo", settings.upstream_repo, "--json", "title", "--jq", ".title"],
        stderr=subprocess.DEVNULL,
    )
    package, version = package_and_version(title)
    if not package or not version:
        return None, None, "unparseable title"
    if not autobump_enabled(Path(".github/workflows/overlay.toml"), package):
        return None, None, "skip (not opted in: no autobump key)"
    return package, version, None


def engine_arguments(tools, package):
    # stderr is the refusal reason. A rewrite regex may contain anything except a
    # newline, so retain each output line as one engine argument.
    status, arguments = combined_output(["python3", str(tools / "autobump-args.py"), package])
    if status != 0:
        return None, None, f"skip ({arguments.replace(chr(10), ' ')})"
    args = arguments.split("\n") if arguments else []
    _, footer = output(["python3", str(tools / "autobump-args.py"), "--describe", package])
    return args, f"— `autobump` enabled{footer}", None


def run_engine(engine, issue, args, pr):
    # Successful runs need only a tail. Failures print all evidence because the CI
    # container and its evidence directory disappear when the run ends.
    status, engine_output = combined_output(engine + [issue, *args] + ([pr] if pr else []))
    if status == 0:
        tail_lines(engine_output, 4)
    else:
        print(engine_output)
    return status, engine_output


def record_bumped(settings, issue, package, version, engine_output, footer, status_comment_failed):
    append_ledger(settings.done, package, version, "bumped")
    result = f"bumped{' + PR' if settings.pr else ''}"
    urls = re.findall(r"https://github\.com/[^ \n]+/pull/[0-9]+", engine_output)
    opened_pr = f" — opened {urls[-1]}" if urls else ""
    status_comment(
        issue,
        f"**autobump** bumped `{package}` → `{version}`{opened_pr}{run_link(settings.upstream_repo)}",
        comment=settings.comment,
        footer=footer,
        upstream_repo=settings.upstream_repo,
        status_comment_failed=status_comment_failed,
    )
    return result


def defer_unparseable_evidence(settings, package, version):
    # Output-format drift must not turn every escalation into a permanent empty-reason
    # defer. Treat it as a capped transient so it reaches a human.
    tries = matching_count(settings.attempts_ledger, package, version)
    append_ledger(settings.attempts_ledger, package, version)
    if tries >= 2:
        append_ledger(settings.done, package, version, "deferred")
        return f"deferred (exit 3, evidence dir unparseable after {tries + 1} tries)"
    return f"exit 3 but evidence dir not found (try {tries + 1}), retrying"


def escalation_verdict(settings, tools, evidence, package, old, version):
    if settings.judge:
        _, verdict_json = output(
            ["bash", str(tools / "autobump-judge.sh"), str(evidence), package, old or "?", version]
        )
        print(f"judge: {verdict_json}")
        return verdict_value(verdict_json)

    # Without a model, preserve the evidence and hand the escalation to a human.
    return human_verdict(evidence)


def retry_accepted_escalation(
    settings, engine, issue, package, version, args, footer, status_comment_failed
):
    retry_status, retry_output = combined_output(
        engine + [issue, "--accept-surface", "--accept-payload", *args] + ([settings.pr] if settings.pr else [])
    )
    tail_lines(retry_output, 3)
    if retry_status == 0:
        append_ledger(settings.done, package, version, "bumped-after-judge")
        return "bumped (judge accepted surface delta)"
    if retry_status != 2:
        append_ledger(settings.done, package, version, "deferred")
        return f"deferred (retry failed, exit {retry_status})"

    # The judge-accepted retry shares ATTEMPTS so an escalation -> judge -> timeout loop
    # terminates instead of paying for a judge every sweep.
    tries = matching_count(settings.attempts_ledger, package, version)
    append_ledger(settings.attempts_ledger, package, version)
    if tries < 2:
        return f"judge-retry deferred transiently (try {tries + 1})"

    append_ledger(settings.done, package, version, "deferred-transient")
    status_comment(
        issue,
        (
            f"**autobump** accepted the surface delta for `{package}` → `{version}` "
            f"but the retry hit transient failures {tries + 1} times. "
            f"A maintainer may need to bump it by hand.{run_link(settings.upstream_repo)}"
        ),
        comment=settings.comment,
        footer=footer,
        upstream_repo=settings.upstream_repo,
        status_comment_failed=status_comment_failed,
    )
    return f"deferred after {tries + 1} judge-retry transients"


def record_escalation(settings, issue, package, version, evidence, verdict, engine_output, footer, status_comment_failed):
    # Prefer the engine's clear one-line reason over a bare evidence path.
    append_ledger(settings.done, package, version, "deferred")
    clear = last_clear_reason(engine_output)
    if clear in ("", f"see evidence in {evidence}"):
        reasons = verdict.get("reasons", [])
        clear = "; ".join(reasons) if isinstance(reasons, list) else ""
    if clear in ("", f"see evidence in {evidence}"):
        clear = "needs a manual bump"

    body = (
        f"**autobump** can't bump `{package}` → `{version}` mechanically: "
        f"**{fold(clear)}**. Needs a manual bump.{run_link(settings.upstream_repo, 'log')}"
    )
    # Keep the issue comment scannable while retaining raw evidence one click away.
    excerpt = evidence_excerpt(evidence)
    if excerpt:
        body += f"\n\n<details><summary>evidence</summary>\n\n```\n{excerpt}\n```\n</details>"
    status_comment(
        issue,
        body,
        comment=settings.comment,
        footer=footer,
        upstream_repo=settings.upstream_repo,
        status_comment_failed=status_comment_failed,
    )
    return f"escalated: {clear}"


def handle_escalation(
    settings, tools, engine, issue, package, version, args, footer, engine_output, status_comment_failed
):
    # Engine output is the only portable evidence-directory source: its temporary root follows
    # TMPDIR and is not necessarily /tmp.
    evidence_path = evidence_directory(engine_output)
    evidence = Path(evidence_path)
    if not evidence_path or not evidence.is_dir():
        return defer_unparseable_evidence(settings, package, version)

    verdict = escalation_verdict(
        settings, tools, evidence, package, current_version(engine_output), version
    )
    if verdict.get("verdict") == "proceed":
        return retry_accepted_escalation(
            settings, engine, issue, package, version, args, footer, status_comment_failed
        )
    return record_escalation(
        settings, issue, package, version, evidence, verdict, engine_output, footer, status_comment_failed
    )


def record_precondition(settings, issue, package, version, footer, status_comment_failed):
    # Already-at-target, existing ebuild, and downgrade guards are permanent preconditions,
    # not build failures to retry.
    append_ledger(settings.done, package, version, "done-precondition")
    # Replace "bumping" for stale nvchecker issues so the status does not look stuck.
    status_comment(
        issue,
        f"**autobump**: `{package}` is already at (or ahead of) `{version}` in the overlay — nothing to bump.{run_link(settings.upstream_repo)}",
        comment=settings.comment,
        footer=footer,
        upstream_repo=settings.upstream_repo,
        status_comment_failed=status_comment_failed,
    )
    return f"done (precondition: overlay already at/ahead of {version})"


def defer_transient(settings, issue, package, version, engine_output, footer, status_comment_failed):
    # Dirty trees, fetch flakes, timeouts, and dependency gaps are retryable, but the ATTEMPTS
    # cap eventually hands a persistent failure to a maintainer.
    tries = matching_count(settings.attempts_ledger, package, version)
    append_ledger(settings.attempts_ledger, package, version)
    reason = re.sub(r"^[ \t\r\v\f]*!+[ \t\r\v\f]*", "", engine_output.split("\n")[-1])
    if tries < 2:
        status_comment(
            issue,
            (
                f"**autobump** deferred `{package}` → `{version}` (transient: {fold(reason)}). "
                f"Will retry automatically.{run_link(settings.upstream_repo)}"
            ),
            comment=settings.comment,
            footer=footer,
            upstream_repo=settings.upstream_repo,
            status_comment_failed=status_comment_failed,
        )
        return f"not attempted (transient, try {tries + 1}): {reason}"

    append_ledger(settings.done, package, version, "deferred-transient")
    status_comment(
        issue,
        (
            f"**autobump** gave up on `{package}` → `{version}` after {tries + 1} tries: "
            f"{fold(reason)}. A maintainer may need to bump it by hand.{run_link(settings.upstream_repo, 'log')}"
        ),
        comment=settings.comment,
        footer=footer,
        upstream_repo=settings.upstream_repo,
        status_comment_failed=status_comment_failed,
    )
    return f"deferred after {tries + 1} transient attempts: {reason}"


def run_package(settings, tools, engine, issue, package, version, args, footer, attempt, status_comment_failed):
    print(f"==== #{issue} {package} -> {version} ({attempt}/{settings.limit}) ====")
    status_comment(
        issue,
        f"**autobump** is bumping `{package}` → `{version}`…{run_link(settings.upstream_repo)}",
        comment=settings.comment,
        footer=footer,
        upstream_repo=settings.upstream_repo,
        status_comment_failed=status_comment_failed,
    )
    status, engine_output = run_engine(engine, issue, args, settings.pr)
    if status == 0:
        return record_bumped(settings, issue, package, version, engine_output, footer, status_comment_failed)
    if status == 3:
        return handle_escalation(
            settings, tools, engine, issue, package, version, args, footer, engine_output, status_comment_failed
        )
    if re.search(r"already at|already exists|would downgrade|newer than target", engine_output):
        return record_precondition(settings, issue, package, version, footer, status_comment_failed)
    return defer_transient(settings, issue, package, version, engine_output, footer, status_comment_failed)


def run_issues(settings, issues, fetched, tools, engine):
    results = {}
    status_comment_failed = set()
    attempts = 0
    for issue in issues:
        if fetched and attempts >= int(settings.limit):
            results[issue] = f"skip (per-run attempt limit {settings.limit} reached)"
            continue

        package, version, result = issue_target(settings, issue)
        if result:
            results[issue] = result
            continue
        args, footer, result = engine_arguments(tools, package)
        if result:
            results[issue] = result
            continue
        prior = matching_line(settings.done, package, version)
        if prior is not None:
            results[issue] = f"skip ({prior})"
            continue

        attempts += 1
        # the shell this replaced ran without `set -e`, so one broken issue never took the
        # rest of the sweep with it. Keep that: record the failure and move on, or a single
        # unexpected error would cost every remaining package its turn and the summary.
        try:
            results[issue] = run_package(
                settings, tools, engine, issue, package, version, args, footer, attempts, status_comment_failed
            )
        except Exception as error:  # noqa: BLE001 - the sweep must outlive one bad issue
            results[issue] = f"error ({type(error).__name__}: {error})"
    return results, status_comment_failed


def restore_branch(original_branch):
    if not original_branch:
        return
    try:
        subprocess.run(
            ["git", "checkout", "-q", original_branch],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except FileNotFoundError:
        pass


def print_summary(issues, results, status_comment_failed):
    # A failed status update must be visible in the run record as well as the issue log.
    print()
    print("==== sweep summary ====")
    for issue in issues:
        suffix = " (status comment not posted)" if issue in status_comment_failed else ""
        print(f"#{issue}  {results.get(issue, '?')}{suffix}")


def main(argv):
    settings = read_settings(argv)
    if settings is None:
        return 2
    issues, fetched = select_issues(settings)
    if issues is None:
        return 2
    if not issues:
        print("no open nvchecker issues")
        return 0

    tools, original_branch = copy_tools()
    engine = engine_words(settings)
    if engine is None:
        return 1
    results, status_comment_failed = {}, set()
    try:
        results, status_comment_failed = run_issues(settings, issues, fetched, tools, engine)
    finally:
        # the branch and the tools copy are restored even when the sweep dies, and the
        # summary is the only record of what a run did once its container is gone.
        restore_branch(original_branch)
        shutil.rmtree(tools, ignore_errors=True)
        print_summary(issues, results, status_comment_failed)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
