"""Integration test for the full parse → scrub → aggregate → store pipeline (INT-2).

Registered: Phase 1. Completes: Phase 4.

Exercises the full story pipeline:
  extract_session → scrub → compute_metrics → aggregate → store.write_aggregates
  → render_story → store.write_story

AC-3: story-latest.md contains '## FR-016 per-seat evidence'
AC-4: run-index.jsonl, aggregates.json, story-latest.md appear under tmp_path; nothing mined in repo
AC-5: secret token 'sk-ABCD1234EFGHabcd5678IJ' is absent from every file in tmp_path
"""
from __future__ import annotations

import json
import shutil
import subprocess
from pathlib import Path

import pytest

from transcript_eval.config import Config, _REPO_ROOT
from transcript_eval.store import InsightStore
from transcript_eval.cli import _run_full_pipeline
from transcript_eval.story import render_story


# Fixture files used as "project dirs"
_FIXTURES_DIR = Path(__file__).parent / "fixtures"
_SECRET_TOKEN = "sk-ABCD1234EFGHabcd5678IJ"


@pytest.mark.integration
def test_full_pipeline_integration(tmp_path):
    """INT-2: Full parse → scrub → aggregate → store pipeline end-to-end."""

    # --- Setup: copy both fixture jsonl files into a tmp project dir ---
    project_dir = tmp_path / "project"
    project_dir.mkdir()
    for fixture_name in ("clean-session.jsonl", "secret-bearing.jsonl"):
        src = _FIXTURES_DIR / fixture_name
        shutil.copy(src, project_dir / fixture_name)

    store_dir = tmp_path / "store"

    # --- Build config pointing at tmp project dir and tmp store ---
    config = Config(
        project_dirs=[project_dir],
        store_path=store_dir,
    )

    # --- Snapshot (b): capture repo git status BEFORE the pipeline ---
    before_snapshot = subprocess.run(
        ["git", "-C", str(_REPO_ROOT), "status", "--porcelain"],
        capture_output=True,
        text=True,
    )
    before_lines = set(before_snapshot.stdout.splitlines())

    # --- Run the full pipeline ---
    aggregates, run_id = _run_full_pipeline(config)

    store = InsightStore(config)
    store.append_run({"kind": "story", "run_id": run_id})
    store.write_aggregates(aggregates)
    story_content = render_story(aggregates)
    store.write_story(run_id, story_content)

    # --- Assert (a): required store files exist ---
    assert (store_dir / "run-index.jsonl").exists(), "run-index.jsonl must exist"
    assert (store_dir / "aggregates.json").exists(), "aggregates.json must exist"
    assert (store_dir / "story-latest.md").exists(), "story-latest.md must exist"

    # --- Assert (b): git status shows no new files in the repo after the pipeline ---
    after_snapshot = subprocess.run(
        ["git", "-C", str(_REPO_ROOT), "status", "--porcelain"],
        capture_output=True,
        text=True,
    )
    after_lines = set(after_snapshot.stdout.splitlines())
    new_repo_changes = after_lines - before_lines
    assert not new_repo_changes, (
        f"Pipeline wrote unexpected files to the repo (set difference after−before): "
        f"{sorted(new_repo_changes)}"
    )

    # --- Assert (c): secret token absent from every file in store_dir ---
    for store_file in store_dir.rglob("*"):
        if not store_file.is_file():
            continue
        content = store_file.read_text(encoding="utf-8", errors="replace")
        assert _SECRET_TOKEN not in content, (
            f"Secret token '{_SECRET_TOKEN}' found in store file: {store_file}"
        )

    # --- Assert (d): story-latest.md contains the FR-016 section header ---
    story_md = (store_dir / "story-latest.md").read_text(encoding="utf-8")
    assert "## FR-016 per-seat evidence" in story_md, (
        "story-latest.md must contain '## FR-016 per-seat evidence' (AC-3)"
    )
