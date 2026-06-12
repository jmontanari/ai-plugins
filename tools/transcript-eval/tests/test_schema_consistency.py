"""
Tests for transcript_eval.schema_check — schema consistency verification.

TSC-consistent: call assert_schema_consistency() → expect empty list
TSC-drift:      inject a structural mismatch (e.g. rename a dataclass field or
                mutate the reads-set) → expect a named mismatch reported
"""
from __future__ import annotations

import dataclasses
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any
from unittest.mock import patch

import pytest

from transcript_eval.schema_check import (
    assert_schema_consistency,
    _METRICS_READS_FROM_RECORD,
    _METRICS_READS_FROM_FINDING,
    _STORY_READS_FROM_SEAT_METRICS,
)


# ---------------------------------------------------------------------------
# TSC-consistent: baseline check — current codebase is consistent
# ---------------------------------------------------------------------------

def test_schema_consistent_no_args():
    """TSC-consistent: assert_schema_consistency() with no args returns empty list."""
    mismatches = assert_schema_consistency()
    assert mismatches == [], (
        f"Schema inconsistency detected: {mismatches}"
    )


def test_schema_consistent_with_valid_record():
    """TSC-consistent: a well-formed sample record passes validation."""
    sample = {
        "seat": "spec-flow:qa-phase",
        "session_id": None,
        "tool_use_id": "toolu_001",
        "findings": [
            {"text": "Some finding", "accept_reject": "accepted"}
        ],
        "dispatch_ts": None,
        "result_ts": None,
        "reviewer_notes": "",
    }
    mismatches = assert_schema_consistency(sample_record=sample)
    assert mismatches == [], f"Valid record should pass: {mismatches}"


def test_schema_consistent_with_valid_store(tmp_path):
    """TSC-consistent: store with all required files passes layout check."""
    store = tmp_path / "store"
    store.mkdir()
    (store / "run-index.jsonl").write_text('{"kind":"run"}\n')
    (store / "aggregates.json").write_text("{}")
    (store / "story-latest.md").write_text("# Report\n")

    mismatches = assert_schema_consistency(store_path=store)
    assert mismatches == [], f"Valid store layout should pass: {mismatches}"


# ---------------------------------------------------------------------------
# TSC-drift: mutated field name → mismatch detected
# ---------------------------------------------------------------------------

def test_schema_drift_missing_record_key():
    """TSC-drift: record missing 'seat' key → mismatch reported."""
    sample = {
        # 'seat' is missing — drift from the expected schema
        "session_id": None,
        "tool_use_id": "toolu_001",
        "findings": [],
        "dispatch_ts": None,
        "result_ts": None,
        "reviewer_notes": "",
    }
    mismatches = assert_schema_consistency(sample_record=sample)
    assert len(mismatches) > 0, "Missing 'seat' key should be reported as a mismatch"
    assert any("seat" in m for m in mismatches), (
        f"Expected 'seat' in mismatch descriptions, got: {mismatches}"
    )


def test_schema_drift_missing_finding_key():
    """TSC-drift: finding missing 'accept_reject' key → mismatch reported."""
    sample = {
        "seat": "spec-flow:qa-phase",
        "session_id": None,
        "tool_use_id": "toolu_002",
        "findings": [
            {"text": "Some finding"}  # missing 'accept_reject'
        ],
        "dispatch_ts": None,
        "result_ts": None,
        "reviewer_notes": "",
    }
    mismatches = assert_schema_consistency(sample_record=sample)
    assert len(mismatches) > 0, "Missing 'accept_reject' in finding should be reported"
    assert any("accept_reject" in m for m in mismatches), (
        f"Expected 'accept_reject' in mismatch descriptions, got: {mismatches}"
    )


def test_schema_drift_missing_finding_text():
    """TSC-drift: finding missing 'text' key → mismatch reported."""
    sample = {
        "seat": "spec-flow:qa-phase",
        "session_id": None,
        "tool_use_id": "toolu_003",
        "findings": [
            {"accept_reject": "accepted"}  # missing 'text'
        ],
        "dispatch_ts": None,
        "result_ts": None,
        "reviewer_notes": "",
    }
    mismatches = assert_schema_consistency(sample_record=sample)
    assert len(mismatches) > 0, "Missing 'text' in finding should be reported"
    assert any("text" in m for m in mismatches), (
        f"Expected 'text' in mismatch descriptions, got: {mismatches}"
    )


def test_schema_drift_store_missing_file(tmp_path):
    """TSC-drift: store missing 'aggregates.json' → mismatch reported."""
    store = tmp_path / "store2"
    store.mkdir()
    (store / "run-index.jsonl").write_text("")
    # aggregates.json intentionally absent
    (store / "story-latest.md").write_text("")

    mismatches = assert_schema_consistency(store_path=store)
    assert len(mismatches) > 0, "Missing aggregates.json should be reported"
    assert any("aggregates.json" in m for m in mismatches), (
        f"Expected 'aggregates.json' in mismatch descriptions, got: {mismatches}"
    )


def test_schema_drift_metrics_reads_record_contract():
    """TSC-drift: simulate metrics.py reading a key not in Dispatch dataclass → mismatch."""
    # Patch _METRICS_READS_FROM_RECORD to include a key not in Dispatch dataclass fields
    with patch(
        "transcript_eval.schema_check._METRICS_READS_FROM_RECORD",
        _METRICS_READS_FROM_RECORD | {"nonexistent_dispatch_key"},
    ):
        mismatches = assert_schema_consistency()
    assert len(mismatches) > 0, (
        "A key in METRICS_READS_FROM_RECORD not in Dispatch fields should be reported"
    )
    assert any("nonexistent_dispatch_key" in m for m in mismatches), (
        f"Expected 'nonexistent_dispatch_key' in mismatch descriptions, got: {mismatches}"
    )


def test_schema_drift_seat_metrics_renamed_field():
    """TSC-drift: SeatMetrics with a renamed field causes story-reads mismatch.

    This test exercises real introspection by replacing the SeatMetrics class
    with a version that renames 'precision' to 'precision_renamed'.  The checker
    must detect that story.py still reads 'precision' but the dataclass no longer
    has that field.
    """
    # Build a fake SeatMetrics dataclass that is missing 'precision'
    @dataclass
    class FakeSeatMetrics:
        precision_renamed: float | None  # renamed — 'precision' is gone
        raised: int
        accepted: int
        activity: int
        overlap: dict
        unique_catch: list
        leave_one_out_delta: int
        rubber_stamp_candidates: list
        metric_kind: str = "precision-from-usage"

    # Patch _get_seat_metrics_field_names so the checker sees the fake class fields
    fake_fields = frozenset(f.name for f in dataclasses.fields(FakeSeatMetrics))

    with patch(
        "transcript_eval.schema_check._get_seat_metrics_field_names",
        return_value=fake_fields,
    ):
        mismatches = assert_schema_consistency()

    assert len(mismatches) > 0, (
        "A renamed SeatMetrics field should be detected as a story-reads mismatch"
    )
    assert any("precision" in m for m in mismatches), (
        f"Expected 'precision' in mismatch descriptions, got: {mismatches}"
    )
    assert any("story.py" in m for m in mismatches), (
        f"Expected 'story.py' in mismatch descriptions, got: {mismatches}"
    )
