"""
Metric-layer tests (Phase 3 — AC-2).

All 8 test-data cases verified against hand-derived oracles on the
synthetic-records.json fixture.

TM-precision       — per-seat precision = accepted/raised
TM-activity        — dispatch count per seat
TM-overlap         — co-finding seats per issue
TM-unique          — unique_catch for accepted-only findings
TM-loo             — leave-one-out delta (FR-016 ablation)
TM-rubberstamp-zeronotes — zero reviewer notes → rubber_stamp_candidates
TM-rubberstamp-fast      — fast interval → rubber_stamp_candidates
TM-nocatchrate     — no "catch rate" / "recall" labels anywhere
"""
from __future__ import annotations

import json
import re
from dataclasses import fields as dataclass_fields
from pathlib import Path

import pytest

from transcript_eval.metrics import compute_metrics, SeatMetrics

# ---------------------------------------------------------------------------
# Fixture loading
# ---------------------------------------------------------------------------

FIXTURES_DIR = Path(__file__).parent / "fixtures"


@pytest.fixture(scope="module")
def synthetic_records() -> list[dict]:
    path = FIXTURES_DIR / "synthetic-records.json"
    return json.loads(path.read_text())


@pytest.fixture(scope="module")
def metrics(synthetic_records) -> dict[str, SeatMetrics]:
    return compute_metrics(synthetic_records)


# ---------------------------------------------------------------------------
# TM-precision: review-board-security raised 4, accepted 3 → precision == 0.75
# ---------------------------------------------------------------------------

def test_precision_review_board_security(metrics):
    """TM-precision: 3 accepted / 4 raised = 0.75, labeled precision-from-usage."""
    seat = "spec-flow:review-board-security"
    m = metrics[seat]
    assert m.precision == pytest.approx(0.75), f"Expected 0.75, got {m.precision}"
    assert m.raised == 4
    assert m.accepted == 3
    assert m.metric_kind == "precision-from-usage"


# ---------------------------------------------------------------------------
# TM-activity: qa-phase dispatched 7 times
# ---------------------------------------------------------------------------

def test_activity_qa_phase(metrics):
    """TM-activity: 7 dispatches → activity == 7."""
    seat = "spec-flow:qa-phase"
    m = metrics[seat]
    assert m.activity == 7, f"Expected activity=7, got {m.activity}"


# ---------------------------------------------------------------------------
# TM-overlap: issue-SHARED co-found by review-board-security + review-board-edge-case
# ---------------------------------------------------------------------------

def test_overlap_shared_issue(metrics):
    """TM-overlap: issue-SHARED found by both seats — each appears in the other's overlap."""
    security_seat = "spec-flow:review-board-security"
    edge_case_seat = "spec-flow:review-board-edge-case"

    shared_text = "FINDING: issue-SHARED SQL injection risk"

    # review-board-security's overlap for the shared issue includes review-board-edge-case
    rbs_overlap = metrics[security_seat].overlap
    assert shared_text in rbs_overlap, f"Expected {shared_text!r} in security overlap, got keys: {list(rbs_overlap.keys())}"
    assert edge_case_seat in rbs_overlap[shared_text], (
        f"Expected {edge_case_seat!r} in security's overlap for the shared finding"
    )

    # review-board-edge-case's overlap for the shared issue includes review-board-security
    rbec_overlap = metrics[edge_case_seat].overlap
    assert shared_text in rbec_overlap, f"Expected {shared_text!r} in edge-case overlap"
    assert security_seat in rbec_overlap[shared_text], (
        f"Expected {security_seat!r} in edge-case's overlap for the shared finding"
    )


# ---------------------------------------------------------------------------
# TM-unique: finding-UNIQUE-GT only raised by review-board-ground-truth
# ---------------------------------------------------------------------------

def test_unique_catch_ground_truth(metrics):
    """TM-unique: finding-UNIQUE-GT accepted and unique → in unique_catch for gt, not others."""
    gt_seat = "spec-flow:review-board-ground-truth"
    unique_text = "FINDING: finding-UNIQUE-GT incorrect formula result"

    # Must appear in ground-truth's unique_catch
    assert unique_text in metrics[gt_seat].unique_catch, (
        f"Expected {unique_text!r} in ground-truth unique_catch, got: {metrics[gt_seat].unique_catch}"
    )

    # Must NOT appear in any other seat's unique_catch
    for seat, m in metrics.items():
        if seat == gt_seat:
            continue
        assert unique_text not in m.unique_catch, (
            f"Did not expect {unique_text!r} in {seat}'s unique_catch"
        )


# ---------------------------------------------------------------------------
# TM-loo: leave-one-out delta
# ---------------------------------------------------------------------------

def test_loo_blind_drops_two(metrics):
    """TM-loo: removing review-board-blind drops accepted-defect coverage by 2."""
    blind_seat = "spec-flow:review-board-blind"
    assert metrics[blind_seat].leave_one_out_delta == 2, (
        f"Expected leave_one_out_delta=2 for blind, got {metrics[blind_seat].leave_one_out_delta}"
    )


def test_loo_duplicated_seat_zero(metrics):
    """TM-loo: seat with all findings duplicated elsewhere → leave_one_out_delta == 0."""
    integration_seat = "spec-flow:review-board-integration"
    assert metrics[integration_seat].leave_one_out_delta == 0, (
        f"Expected leave_one_out_delta=0 for integration, got {metrics[integration_seat].leave_one_out_delta}"
    )


# ---------------------------------------------------------------------------
# TM-rubberstamp-zeronotes: zero reviewer notes → in rubber_stamp_candidates
# ---------------------------------------------------------------------------

def test_rubberstamp_zero_notes(metrics):
    """TM-rubberstamp-zeronotes: review-board-spec-compliance has empty notes → flagged."""
    seat = "spec-flow:review-board-spec-compliance"
    candidates = metrics[seat].rubber_stamp_candidates
    assert len(candidates) >= 1, f"Expected ≥1 rubber-stamp candidate for {seat}, got {candidates}"
    # Verify at least one is flagged for zero-notes reason
    reasons = [c.get("reason", "") for c in candidates]
    assert any("zero-notes" in r for r in reasons), (
        f"Expected 'zero-notes' in rubber-stamp reason, got: {reasons}"
    )


# ---------------------------------------------------------------------------
# TM-rubberstamp-fast: 30s → flagged; 120s → NOT flagged
# ---------------------------------------------------------------------------

def test_rubberstamp_fast_approval(metrics):
    """TM-rubberstamp-fast: review-board-prd-alignment (30s) flagged; review-board-architecture (120s) not."""
    prd_seat = "spec-flow:review-board-prd-alignment"
    arch_seat = "spec-flow:review-board-architecture"

    # 30s interval — should be in rubber_stamp_candidates
    prd_candidates = metrics[prd_seat].rubber_stamp_candidates
    assert len(prd_candidates) >= 1, (
        f"Expected ≥1 rubber-stamp candidate for {prd_seat} (30s interval), got none"
    )

    # 120s interval — should NOT be in rubber_stamp_candidates
    # (architecture seat has reviewer_notes and 120s > 60s threshold)
    arch_candidates = metrics[arch_seat].rubber_stamp_candidates
    # The architecture seat has reviewer_notes="one finding" (non-empty) and 120s > 60s
    # So it must not be flagged
    assert len(arch_candidates) == 0, (
        f"Expected 0 rubber-stamp candidates for {arch_seat} (120s, non-empty notes), got: {arch_candidates}"
    )


# ---------------------------------------------------------------------------
# TM-nocatchrate: no "catch rate" or "recall" label anywhere in the metrics
# ---------------------------------------------------------------------------

def test_no_catch_rate_label(metrics):
    """TM-nocatchrate: no field name or metric_kind value contains 'catch rate' or 'recall'."""
    forbidden_pattern = re.compile(r"catch.?rate|recall", re.IGNORECASE)

    for seat, m in metrics.items():
        # Check metric_kind value
        assert not forbidden_pattern.search(m.metric_kind), (
            f"Seat {seat}: metric_kind {m.metric_kind!r} contains forbidden label"
        )
        # Check all dataclass field names
        for f in dataclass_fields(m):
            assert not forbidden_pattern.search(f.name), (
                f"Seat {seat}: field name {f.name!r} contains forbidden label"
            )
        # Check overlap keys
        for key in m.overlap:
            assert not forbidden_pattern.search(key), (
                f"Seat {seat}: overlap key {key!r} contains forbidden label"
            )
