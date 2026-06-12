"""
Tests for transcript_eval.store — InsightStore foundation + loud-fail behavior.

Test Data (from plan Phase 1):
  TS-store-ok:          writable temp dir → append_run → file exists with correct content
  TS-store-unwritable:  non-writable parent path → StoreUnwritableError raised, nothing written in-repo
  TS-store-norepo:      store_path under repo root → construction rejects it (SF-6 guard)
"""
import json
import os
import stat
import pytest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

from transcript_eval.config import Config, Thresholds, _REPO_ROOT
from transcript_eval.store import InsightStore, StoreUnwritableError


# ---------------------------------------------------------------------------
# TS-store-ok
# ---------------------------------------------------------------------------
def test_store_ok_append_run(tmp_path):
    """TS-store-ok: writable temp dir → append_run creates run-index.jsonl with correct content."""
    store_path = tmp_path / "store"
    config = Config(project_dirs=[], store_path=store_path)
    store = InsightStore(config)

    store.append_run({"kind": "test", "run_id": "r001"})

    index = store_path / "run-index.jsonl"
    assert index.exists(), "run-index.jsonl should be created"
    lines = [json.loads(l) for l in index.read_text().splitlines() if l.strip()]
    assert len(lines) == 1
    assert lines[0]["kind"] == "test"
    assert lines[0]["run_id"] == "r001"


def test_store_ok_write_aggregates(tmp_path):
    """write_aggregates creates aggregates.json under store_path."""
    store_path = tmp_path / "store"
    config = Config(project_dirs=[], store_path=store_path)
    store = InsightStore(config)

    store.write_aggregates({"total_sessions": 3, "seats": {}})

    agg = store_path / "aggregates.json"
    assert agg.exists()
    data = json.loads(agg.read_text())
    assert data["total_sessions"] == 3


def test_store_ok_write_story(tmp_path):
    """write_story creates story-latest.md and stories/<run_id>.md."""
    store_path = tmp_path / "store"
    config = Config(project_dirs=[], store_path=store_path)
    store = InsightStore(config)

    store.write_story("run-20260612", "# Pipeline Health Story\n\nAll good.\n")

    latest = store_path / "story-latest.md"
    archive = store_path / "stories" / "run-20260612.md"
    assert latest.exists(), "story-latest.md should exist"
    assert archive.exists(), "stories/<run_id>.md should exist"
    assert "Pipeline Health Story" in latest.read_text()
    assert latest.read_text() == archive.read_text()


def test_store_ok_append_run_multiple(tmp_path):
    """Multiple append_run calls accumulate lines."""
    store_path = tmp_path / "store"
    config = Config(project_dirs=[], store_path=store_path)
    store = InsightStore(config)

    store.append_run({"kind": "run", "n": 1})
    store.append_run({"kind": "run", "n": 2})

    lines = [
        json.loads(l)
        for l in (store_path / "run-index.jsonl").read_text().splitlines()
        if l.strip()
    ]
    assert len(lines) == 2
    assert lines[0]["n"] == 1
    assert lines[1]["n"] == 2


# ---------------------------------------------------------------------------
# TS-store-unwritable
# ---------------------------------------------------------------------------
def test_store_unwritable_raises(tmp_path):
    """TS-store-unwritable: non-writable parent → StoreUnwritableError raised."""
    # Create a directory and remove write permission from it.
    unwritable_parent = tmp_path / "locked"
    unwritable_parent.mkdir()
    os.chmod(unwritable_parent, stat.S_IREAD | stat.S_IEXEC)

    store_path = unwritable_parent / "store"
    config = Config(project_dirs=[], store_path=store_path)

    try:
        with pytest.raises(StoreUnwritableError):
            InsightStore(config)
    finally:
        # Restore permissions so tmp_path cleanup works.
        os.chmod(unwritable_parent, stat.S_IRWXU)


def test_store_unwritable_no_repo_write(tmp_path):
    """TS-store-unwritable: nothing written under the repo root when store is unwritable."""
    import subprocess
    unwritable_parent = tmp_path / "locked2"
    unwritable_parent.mkdir()
    os.chmod(unwritable_parent, stat.S_IREAD | stat.S_IEXEC)

    store_path = unwritable_parent / "store"
    config = Config(project_dirs=[], store_path=store_path)

    try:
        with pytest.raises(StoreUnwritableError):
            InsightStore(config)

        # Assert nothing was written under the repo root.
        result = subprocess.run(
            ["git", "status", "--porcelain"],
            cwd=str(_REPO_ROOT),
            capture_output=True,
            text=True,
        )
        # No new mined content should appear.
        new_files = [
            line for line in result.stdout.splitlines()
            if "run-index" in line or "aggregates" in line or "story" in line
        ]
        assert not new_files, f"Unexpected in-repo writes after unwritable store: {new_files}"
    finally:
        os.chmod(unwritable_parent, stat.S_IRWXU)


# ---------------------------------------------------------------------------
# TS-store-norepo
# ---------------------------------------------------------------------------
def test_store_norepo_rejected():
    """TS-store-norepo: store_path under repo root is rejected (SF-6 guard)."""
    in_repo_path = _REPO_ROOT / "tools" / "transcript-eval" / ".store-would-be-wrong"

    with pytest.raises((ValueError, StoreUnwritableError)):
        Config(project_dirs=[], store_path=in_repo_path)
