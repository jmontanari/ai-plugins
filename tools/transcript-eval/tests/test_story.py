"""
Tests for transcript_eval.story — FR-016 per-seat evidence rendering (AC-3).

TST-fr016: rendered story contains literal "## FR-016 per-seat evidence" header and a row per seat
TST-label:  rendered story contains "(precision-from-usage)" and NOT "catch rate" / "recall" as metric labels
TST-health: aggregates with activity + rubber-stamp data → story contains pipeline-health/trends section
"""
from __future__ import annotations

import re
import pytest

from transcript_eval.story import render_story


# ---------------------------------------------------------------------------
# Fixture: aggregates with two seats
# ---------------------------------------------------------------------------

@pytest.fixture
def two_seat_aggregates() -> dict:
    return {
        "spec-flow:qa-phase": {
            "precision": 0.75,
            "raised": 8,
            "accepted": 6,
            "activity": 4,
            "overlap": {"some finding": ["spec-flow:review-board-blind"]},
            "unique_catch": ["Only qa-phase raised this one"],
            "leave_one_out_delta": 1,
            "rubber_stamp_candidates": [],
            "metric_kind": "precision-from-usage",
        },
        "spec-flow:review-board-security": {
            "precision": 0.5,
            "raised": 4,
            "accepted": 2,
            "activity": 2,
            "overlap": {},
            "unique_catch": [],
            "leave_one_out_delta": 2,
            "rubber_stamp_candidates": [
                {
                    "seat": "spec-flow:review-board-security",
                    "tool_use_id": "toolu_001",
                    "reviewer_notes": "",
                    "dispatch_ts": 1000.0,
                    "result_ts": 1030.0,
                    "reason": "zero-notes",
                }
            ],
            "metric_kind": "precision-from-usage",
        },
    }


# ---------------------------------------------------------------------------
# TST-fr016
# ---------------------------------------------------------------------------

def test_fr016_section_header_present(two_seat_aggregates):
    """TST-fr016: story must contain the literal '## FR-016 per-seat evidence' header."""
    story = render_story(two_seat_aggregates)
    assert "## FR-016 per-seat evidence" in story, (
        "Required FR-016 section header '## FR-016 per-seat evidence' not found in story output"
    )


def test_fr016_row_per_seat(two_seat_aggregates):
    """TST-fr016: per-seat table has a row for every seat in aggregates."""
    story = render_story(two_seat_aggregates)
    for seat in two_seat_aggregates:
        assert seat in story, f"Seat '{seat}' not found in story output"


def test_fr016_h1_header(two_seat_aggregates):
    """Story must open with the H1 header '# spec-flow Pipeline Health Report'."""
    story = render_story(two_seat_aggregates)
    assert story.startswith("# spec-flow Pipeline Health Report"), (
        "Story must start with '# spec-flow Pipeline Health Report'"
    )


def test_fr016_empty_aggregates():
    """render_story with empty aggregates does not crash and still has the FR-016 header."""
    story = render_story({})
    assert "## FR-016 per-seat evidence" in story
    assert "# spec-flow Pipeline Health Report" in story


# ---------------------------------------------------------------------------
# TST-label: precision-from-usage present; "catch rate" and "recall" absent
# ---------------------------------------------------------------------------

def test_label_precision_from_usage_present(two_seat_aggregates):
    """TST-label: story must contain '(precision-from-usage)' somewhere."""
    story = render_story(two_seat_aggregates)
    assert "precision-from-usage" in story, (
        "Story must label effectiveness numbers with 'precision-from-usage'"
    )


def test_label_no_catch_rate(two_seat_aggregates):
    """TST-label: 'catch rate' must not appear as a metric label."""
    story = render_story(two_seat_aggregates)
    # Case-insensitive; look for "catch rate" as a standalone label (not in a note saying it's absent)
    # The only allowed mention is in the disclaimer that says "not recall"/"not catch rate".
    # We check that "catch rate" doesn't appear as a column header or metric label.
    # We grep for occurrences that are NOT inside the disclaimer note.
    lines_with_catch_rate = [
        line for line in story.splitlines()
        if re.search(r"catch rate", line, re.IGNORECASE)
        and "not" not in line.lower()  # allow "not catch rate" in disclaimers
        and "never" not in line.lower()
        and "no" not in line.lower()
    ]
    assert not lines_with_catch_rate, (
        f"'catch rate' found as a metric label in story lines: {lines_with_catch_rate}"
    )


def test_label_no_recall_metric(two_seat_aggregates):
    """TST-label: 'recall' must not appear as a column header or row label (SF-8).

    The word 'recall' may appear in disclaimer/negation contexts
    ('not recall', 'no recall', 'no ... recall', 'recall figures are absent').
    It must NOT appear as a standalone column header like '| Recall |' or
    a metric label like 'Recall: X%'.
    """
    story = render_story(two_seat_aggregates)
    # Check for "recall" appearing as a standalone metric label (column header or row prefix)
    # Table headers look like "| Recall |" and metric rows look like "- **Recall:** X"
    forbidden_patterns = [
        r"\|\s*Recall\s*\|",          # table column header
        r"\*\*Recall\*\*",            # bold metric label in prose
        r"^Recall:",                  # line starting with "Recall:"
        r"^- Recall\b",              # bullet point metric
    ]
    for pattern in forbidden_patterns:
        matches = re.findall(pattern, story, re.IGNORECASE | re.MULTILINE)
        assert not matches, (
            f"'recall' found as a metric label (pattern {pattern!r}): {matches}"
        )


def test_label_sf8_note_present(two_seat_aggregates):
    """TST-label: the SF-8 disclaimer note is present."""
    story = render_story(two_seat_aggregates)
    assert "precision/overlap/activity, not recall" in story, (
        "SF-8 note must be present: 'mining measures precision/overlap/activity, not recall (SF-8)'"
    )


# ---------------------------------------------------------------------------
# TST-health: pipeline health and trends sections present
# ---------------------------------------------------------------------------

def test_health_section_present(two_seat_aggregates):
    """TST-health: story contains a '## Pipeline Health' section."""
    story = render_story(two_seat_aggregates)
    assert "## Pipeline Health" in story, (
        "Story must contain a '## Pipeline Health' section"
    )


def test_health_activity_summary(two_seat_aggregates):
    """TST-health: Activity Summary subsection present with totals."""
    story = render_story(two_seat_aggregates)
    assert "Activity Summary" in story
    # total dispatches = 4 + 2 = 6
    assert "6" in story


def test_health_rubber_stamp_summary(two_seat_aggregates):
    """TST-health: rubber-stamp candidates surface in the pipeline-health section."""
    story = render_story(two_seat_aggregates)
    assert "Rubber-stamp" in story or "rubber-stamp" in story, (
        "Pipeline health must surface rubber-stamp candidate summary"
    )


def test_health_trends_present(two_seat_aggregates):
    """TST-health: Trends subsection is present."""
    story = render_story(two_seat_aggregates)
    assert "Trends" in story, "Story must include a Trends section"
