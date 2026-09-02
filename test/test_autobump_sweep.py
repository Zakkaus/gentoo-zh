#!/usr/bin/env python3
"""End-to-end checks for scripts/autobump-sweep.py without GitHub or git."""

import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import textwrap
import unittest


ROOT = Path(__file__).resolve().parents[1]
SWEEP = ROOT / "scripts" / "autobump-sweep.py"


GIT = """#!/usr/bin/env python3
import sys
if sys.argv[1:] == ["branch", "--show-current"]:
    print("test-branch")
"""


GH = """#!/usr/bin/env python3
import json
import os
from pathlib import Path
import sys

args = sys.argv[1:]
with Path(os.environ["GH_LOG"]).open("a") as log:
    log.write(json.dumps(args) + "\\n")

if args[:2] == ["issue", "list"]:
    print("1\\n2\\n3\\n4\\n5\\n6\\n7")
elif args[:2] == ["issue", "view"]:
    titles = {
        "1": "[nvchecker] cat/skip can be bump to 1.0",
        "2": "[nvchecker] cat/done can be bump to 1.0",
        "3": "[nvchecker] cat/bump can be bump to 2.0",
        "4": "[nvchecker] cat/escalate can be bump to 3.0",
        "5": "[nvchecker] cat/transient can be bump to 4.0",
        "6": "[nvchecker] cat/comment-fail can be bump to 5.0",
        "7": "[nvchecker] cat/regex can be bump to 6.0",
    }
    print(titles[args[2]])
elif args[0] == "api":
    pass
elif args[:2] == ["issue", "comment"]:
    issue = args[2]
    state = Path(os.environ["GH_STATE"])
    counts = json.loads(state.read_text()) if state.exists() else {}
    count = counts.get(issue, 0)
    counts[issue] = count + 1
    state.write_text(json.dumps(counts))
    if issue == "6" and count >= 1:
        raise SystemExit(1)
else:
    raise SystemExit(f"unexpected gh command: {args!r}")
"""


ENGINE = """#!/usr/bin/env python3
import json
import os
from pathlib import Path
import sys

args = sys.argv[1:]
with Path(os.environ["ENGINE_LOG"]).open("a") as log:
    log.write(json.dumps(args) + "\\n")

issue = args[0]
if issue == "3":
    print("stage one")
    print("https://github.com/test/overlay/pull/123")
elif issue == "4":
    print(">> current: 2.0 -> target: 3.0")
    print(f"== evidence: {os.environ['EVIDENCE_DIR']} ==")
    raise SystemExit(3)
elif issue == "5":
    print("! build host timed out")
    raise SystemExit(2)
elif issue in {"6", "7"}:
    print("bumped")
else:
    raise SystemExit(f"unexpected engine issue: {issue}")
"""


class AutobumpSweepTest(unittest.TestCase):
    def write_executable(self, path, contents):
        path.write_text(contents)
        path.chmod(0o755)

    def setUp(self):
        self.tempdir = tempfile.TemporaryDirectory()
        self.addCleanup(self.tempdir.cleanup)
        self.repo = Path(self.tempdir.name) / "overlay"
        self.bin = self.repo / "bin"
        self.state_home = Path(self.tempdir.name) / "state"
        self.evidence = Path(self.tempdir.name) / "evidence"
        self.repo.joinpath(".github", "workflows").mkdir(parents=True)
        self.repo.joinpath("scripts").mkdir()
        self.bin.mkdir()
        self.evidence.mkdir()
        (self.evidence / "escalations.txt").write_text("payload layout changed\n")
        self.repo.joinpath(".github", "workflows", "overlay.toml").write_text(
            textwrap.dedent(
                """\
                ["cat/skip"]
                source = "github"

                ["cat/done"]
                autobump = true

                ["cat/bump"]
                autobump = true

                ["cat/escalate"]
                autobump = true

                ["cat/transient"]
                autobump = true

                ["cat/comment-fail"]
                autobump = true

                ["cat/regex"]
                autobump = true
                url = "https://example.invalid/releases/${PV}"
                autobump_my_pv_regex = '"release":"([0-9]+)"'
                """
            )
        )
        shutil.copy2(ROOT / "scripts" / "autobump-args.py", self.repo / "scripts")
        shutil.copy2(ROOT / "scripts" / "autobump-judge.sh", self.repo / "scripts")
        self.write_executable(self.bin / "git", GIT)
        self.write_executable(self.bin / "gh", GH)
        self.write_executable(self.bin / "engine", ENGINE)
        self.done = self.state_home / "autobump" / "done.list"
        self.done.parent.mkdir(parents=True)
        self.done.write_text("cat/done 1.0 bumped 2026-09-01\n")
        self.engine_log = Path(self.tempdir.name) / "engine.log"
        self.gh_log = Path(self.tempdir.name) / "gh.log"
        self.gh_state = Path(self.tempdir.name) / "gh.state"

    def run_sweep(self, *args):
        environment = os.environ | {
            "AUTOBUMP_ENGINE": str(self.bin / "engine"),
            "AUTOBUMP_REPO": str(self.repo),
            "AUTOBUMP_UPSTREAM_REPO": "test/overlay",
            "XDG_STATE_HOME": str(self.state_home),
            "GH_TOKEN": "test-token",
            "EVIDENCE_DIR": str(self.evidence),
            "ENGINE_LOG": str(self.engine_log),
            "GH_LOG": str(self.gh_log),
            "GH_STATE": str(self.gh_state),
            "PATH": f"{self.bin}:{os.environ['PATH']}",
        }
        environment.pop("AUTOBUMP_JUDGE", None)
        return subprocess.run(
            [sys.executable, str(SWEEP), *args],
            cwd=self.repo,
            env=environment,
            capture_output=True,
            text=True,
            check=False,
        )

    def engine_calls(self):
        if not self.engine_log.exists():
            return []
        return [json.loads(line) for line in self.engine_log.read_text().splitlines()]

    def gh_calls(self):
        if not self.gh_log.exists():
            return []
        return [json.loads(line) for line in self.gh_log.read_text().splitlines()]
    def run_worker(self, items, delta, *args):
        return self.run_sweep(
            "--worker",
            json.dumps({"items": items}),
            "--delta",
            str(delta),
            *args,
        )

    def run_collect(self, plan, *deltas):
        return self.run_sweep("--collect", json.dumps(plan), *(str(delta) for delta in deltas))


    def attempt_lines(self):
        attempts = self.state_home / "autobump" / "attempts"
        return attempts.read_text().splitlines() if attempts.exists() else []

    def test_one_broken_issue_does_not_stop_the_sweep(self):
        # the shell this replaced ran without `set -e`; losing that would cost every
        # remaining package its turn and the run its only record.
        self.done.chmod(0o444)
        try:
            run = self.run_sweep("3", "4")
        finally:
            self.done.chmod(0o644)
        self.assertEqual(run.returncode, 0, run.stderr)
        self.assertIn("==== sweep summary ====", run.stdout)
        self.assertIn("#3  error (", run.stdout)
        self.assertIn("#4  ", run.stdout)

    def test_not_opted_in(self):
        result = self.run_sweep("1")

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("#1  skip (not opted in: no autobump key)", result.stdout)
        self.assertEqual(self.engine_calls(), [])

    def test_already_done(self):
        result = self.run_sweep("2")

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("#2  skip (cat/done 1.0 bumped 2026-09-01)", result.stdout)
        self.assertEqual(self.engine_calls(), [])

    def test_per_run_limit(self):
        result = self.run_sweep("--limit", "1")

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("#1  skip (not opted in: no autobump key)", result.stdout)
        self.assertIn("#2  skip (cat/done 1.0 bumped 2026-09-01)", result.stdout)
        self.assertIn("#4  skip (per-run attempt limit 1 reached)", result.stdout)
        self.assertEqual([call[0] for call in self.engine_calls()], ["3"])

    def test_exit_0_records_bump_and_posts_comment(self):
        result = self.run_sweep("3", "--comment")

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("#3  bumped", result.stdout)
        self.assertIn("cat/bump 2.0 bumped", self.done.read_text())
        self.assertTrue(
            any(
                call[:3] == ["issue", "comment", "3"]
                and "**autobump** bumped `cat/bump` → `2.0`" in call[-1]
                for call in self.gh_calls()
            )
        )

    def test_exit_3_escalates_with_evidence_reason(self):
        result = self.run_sweep("4", "--comment")

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("#4  escalated: payload layout changed", result.stdout)
        self.assertIn("cat/escalate 3.0 deferred", self.done.read_text())
        self.assertTrue(
            any(
                call[:3] == ["issue", "comment", "4"]
                and "payload layout changed" in call[-1]
                for call in self.gh_calls()
            )
        )

    def test_exit_2_retries(self):
        result = self.run_sweep("5")

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("#5  not attempted (transient, try 1): build host timed out", result.stdout)
        self.assertEqual(len(self.attempt_lines()), 1)
        self.assertNotIn("cat/transient 4.0 deferred-transient", self.done.read_text())

    def test_exit_2_past_cap_becomes_terminal_defer(self):
        self.assertEqual(self.run_sweep("5").returncode, 0)
        self.assertEqual(self.run_sweep("5").returncode, 0)
        result = self.run_sweep("5")

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("#5  deferred after 3 transient attempts: build host timed out", result.stdout)
        self.assertIn("cat/transient 4.0 deferred-transient", self.done.read_text())
        self.assertEqual(len(self.attempt_lines()), 3)
        self.assertTrue(
            all(
                re.fullmatch(r"cat/transient 4\.0 \d{4}-\d{2}-\d{2}", line)
                for line in self.attempt_lines()
            )
        )

    def test_status_comment_failure_marks_summary(self):
        result = self.run_sweep("6", "--comment")

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("#6  bumped (status comment not posted)", result.stdout)

    def test_autobump_args_reach_engine_unchanged(self):
        result = self.run_sweep("7")

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(
            [
                "7",
                "--rewrite-var",
                "MY_PV",
                "--rewrite-url",
                "https://example.invalid/releases/${PV}",
                "--rewrite-regex",
                '"release":"([0-9]+)"',
            ],
            self.engine_calls(),
        )


    def test_planning_output_is_disjoint_and_covers_eligible_issues(self):
        result = self.run_sweep("--plan", "3")

        self.assertEqual(result.returncode, 0, result.stderr)
        plan = json.loads(result.stdout)
        items = [
            item
            for shard in plan["matrix"]["include"]
            for item in json.loads(shard["items"])["items"]
        ]
        self.assertEqual({item["issue"] for item in items}, {"3", "4", "5", "6", "7"})
        self.assertEqual(len(items), len({item["issue"] for item in items}))
        self.assertEqual(self.engine_calls(), [])

    def test_planning_keeps_existing_terminal_skip_wording(self):
        result = self.run_sweep("--plan", "3")

        self.assertEqual(result.returncode, 0, result.stderr)
        plan = json.loads(result.stdout)
        self.assertEqual(plan["results"]["1"], "skip (not opted in: no autobump key)")
        self.assertEqual(plan["results"]["2"], "skip (cat/done 1.0 bumped 2026-09-01)")

    def test_worker_only_processes_its_shard_and_delta(self):
        plan = json.loads(self.run_sweep("--plan", "1").stdout)
        item = json.loads(plan["matrix"]["include"][0]["items"])["items"][0]
        delta = Path(self.tempdir.name) / "worker-0.json"
        done_before = self.done.read_text()

        result = self.run_worker([item], delta)

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([call[0] for call in self.engine_calls()], ["3"])
        self.assertEqual(self.done.read_text(), done_before)
        worker_delta = json.loads(delta.read_text())
        self.assertEqual(set(worker_delta["results"]), {"3"})
        self.assertEqual(len(worker_delta["done"]), 1)
        self.assertEqual(self.attempt_lines(), [])

    def test_collect_merges_worker_deltas_without_duplicates(self):
        plan = json.loads(self.run_sweep("--plan", "2").stdout)
        items = {
            item["issue"]: item
            for shard in plan["matrix"]["include"]
            for item in json.loads(shard["items"])["items"]
        }
        first = Path(self.tempdir.name) / "worker-0.json"
        second = Path(self.tempdir.name) / "worker-1.json"
        self.assertEqual(self.run_worker([items["3"]], first).returncode, 0)
        self.assertEqual(self.run_worker([items["6"]], second).returncode, 0)
        second_delta = json.loads(second.read_text())
        second_delta["done"].append(json.loads(first.read_text())["done"][0])
        second.write_text(json.dumps(second_delta))

        result = self.run_collect({"issues": ["3", "6"], "results": {}}, first, second)

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.done.read_text().count("cat/bump 2.0 bumped"), 1)
        self.assertIn("#3  bumped", result.stdout)
        self.assertIn("#6  bumped", result.stdout)

    def test_planning_enforces_the_run_limit_across_shards(self):
        result = self.run_sweep("--limit", "2", "--plan", "3")

        self.assertEqual(result.returncode, 0, result.stderr)
        plan = json.loads(result.stdout)
        deltas = []
        for shard in plan["matrix"]["include"]:
            delta = Path(self.tempdir.name) / f"worker-{shard['shard']}.json"
            worker = self.run_worker(json.loads(shard["items"])["items"], delta, "--limit", "2")
            self.assertEqual(worker.returncode, 0, worker.stderr)
            deltas.append(delta)
        collected = self.run_collect(plan, *deltas)

        self.assertEqual(collected.returncode, 0, collected.stderr)
        self.assertEqual([call[0] for call in self.engine_calls()], ["3", "4"])
        self.assertIn("#5  skip (per-run attempt limit 2 reached)", collected.stdout)
        self.assertIn("#7  skip (per-run attempt limit 2 reached)", collected.stdout)

    def test_single_job_invocation_keeps_existing_output(self):
        result = self.run_sweep("3")

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            result.stdout,
            "==== #3 cat/bump -> 2.0 (1/5) ====\n"
            "stage one\nhttps://github.com/test/overlay/pull/123\n\n"
            "==== sweep summary ====\n#3  bumped\n",
        )

if __name__ == "__main__":
    unittest.main()
