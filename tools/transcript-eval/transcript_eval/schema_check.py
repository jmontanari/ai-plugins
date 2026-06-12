"""
Schema consistency checker for transcript-eval.

Verifies that:
  1. The extracted record structure (from extract.py) matches what metrics.py reads.
  2. The metrics structure (SeatMetrics from metrics.py) matches what story.py reads.
  3. The store layout (from store.py ADR-4) matches what story.py writes.

Uses real module introspection (dataclasses.fields()) so that a field rename in
extract.py, metrics.py, or story.py will be detected immediately — not buried
under a constant that was never updated.

Returns an empty list on consistency, or a list of mismatch descriptions.
"""
from __future__ import annotations

import dataclasses
from pathlib import Path


# ---------------------------------------------------------------------------
# Store files that must be present / written (ADR-4)
# ---------------------------------------------------------------------------

_EXPECTED_STORE_FILES: list[str] = [
    "run-index.jsonl",
    "aggregates.json",
    "story-latest.md",
]

# ---------------------------------------------------------------------------
# Keys that metrics.py reads from the dataclass-backed portion of each dispatch
# dict record.  Only fields that are present in the Dispatch dataclass itself
# are listed here; the extra keys added by cli.py serialisation (dispatch_ts,
# result_ts, reviewer_notes, session_id) are deliberately excluded — those are
# pipeline glue, not part of the Dispatch contract.
# ---------------------------------------------------------------------------

_METRICS_READS_FROM_RECORD: frozenset[str] = frozenset(
    [
        "seat",
        "findings",
    ]
)

# Keys that compute_metrics reads from each finding dict (= Finding fields)
_METRICS_READS_FROM_FINDING: frozenset[str] = frozenset(
    [
        "text",
        "accept_reject",
    ]
)

# Required keys in each serialised dispatch record dict (as produced by cli.py).
# This is the dict schema that metrics.py and sample_record validation check against.
# Note: 'result_text' from Dispatch is NOT here — cli.py maps it to 'reviewer_notes'
# after scrubbing.
_EXPECTED_RECORD_KEYS: frozenset[str] = frozenset(
    [
        "seat",
        "session_id",
        "tool_use_id",
        "findings",
        "dispatch_ts",
        "result_ts",
        "reviewer_notes",
    ]
)

# Keys that story.py reads from the aggregates dict per seat
# (matched against SeatMetrics dataclass fields)
_STORY_READS_FROM_SEAT_METRICS: frozenset[str] = frozenset(
    [
        "precision",
        "raised",
        "accepted",
        "activity",
        "overlap",
        "unique_catch",
        "leave_one_out_delta",
        "rubber_stamp_candidates",
    ]
)


def _get_dispatch_field_names() -> frozenset[str]:
    """Return the actual field names of the Dispatch dataclass from extract.py."""
    from .extract import Dispatch  # noqa: PLC0415
    return frozenset(f.name for f in dataclasses.fields(Dispatch))


def _get_finding_field_names() -> frozenset[str]:
    """Return the actual field names of the Finding dataclass from extract.py."""
    from .extract import Finding  # noqa: PLC0415
    return frozenset(f.name for f in dataclasses.fields(Finding))


def _get_seat_metrics_field_names() -> frozenset[str]:
    """Return the actual field names of the SeatMetrics dataclass from metrics.py."""
    from .metrics import SeatMetrics  # noqa: PLC0415
    return frozenset(f.name for f in dataclasses.fields(SeatMetrics))


def assert_schema_consistency(
    *,
    sample_record: dict | None = None,
    store_path: Path | None = None,
) -> list[str]:
    """
    Check that the extract record schema and store layout are internally consistent.

    Uses real module introspection (dataclasses.fields()) to detect field renames
    in extract.py, metrics.py, or story.py at test time.

    Parameters
    ----------
    sample_record:
        An optional sample extracted record dict to validate against the schema.
        If None, only structural/static checks are run.
    store_path:
        An optional Path to an existing store directory to verify its layout.
        If None, the store-layout check is skipped.

    Returns
    -------
    An empty list if everything is consistent; a list of mismatch descriptions
    otherwise.
    """
    mismatches: list[str] = []

    # ------------------------------------------------------------------
    # 1. Extract record schema (Dispatch fields) → metrics reads
    # ------------------------------------------------------------------
    dispatch_fields = _get_dispatch_field_names()
    missing_for_metrics = _METRICS_READS_FROM_RECORD - dispatch_fields
    if missing_for_metrics:
        mismatches.append(
            f"metrics.py reads keys not in Dispatch dataclass fields: {sorted(missing_for_metrics)}"
        )

    # ------------------------------------------------------------------
    # 2. Extract finding schema (Finding fields) → metrics reads
    # ------------------------------------------------------------------
    finding_fields = _get_finding_field_names()
    missing_finding_keys = _METRICS_READS_FROM_FINDING - finding_fields
    if missing_finding_keys:
        mismatches.append(
            f"metrics.py reads finding keys not in Finding dataclass fields: {sorted(missing_finding_keys)}"
        )

    # ------------------------------------------------------------------
    # 3. SeatMetrics fields → story.py reads
    # ------------------------------------------------------------------
    seat_metrics_fields = _get_seat_metrics_field_names()
    missing_for_story = _STORY_READS_FROM_SEAT_METRICS - seat_metrics_fields
    if missing_for_story:
        mismatches.append(
            f"story.py reads keys not in SeatMetrics dataclass fields: {sorted(missing_for_story)}"
        )

    # ------------------------------------------------------------------
    # 4. Validate a sample record if provided
    # ------------------------------------------------------------------
    if sample_record is not None:
        record_keys = frozenset(sample_record.keys())

        # Check that the record has the required keys from the serialised dict schema.
        # _EXPECTED_RECORD_KEYS matches what cli.py actually writes (not the raw Dispatch
        # fields, since result_text is scrubbed and renamed to reviewer_notes).
        missing_required = _EXPECTED_RECORD_KEYS - record_keys
        if missing_required:
            mismatches.append(
                f"sample record missing required keys: {sorted(missing_required)}"
            )

        # Validate findings list
        findings = sample_record.get("findings", [])
        if not isinstance(findings, list):
            mismatches.append(
                f"sample record 'findings' field is not a list: {type(findings).__name__}"
            )
        else:
            for i, f in enumerate(findings):
                if not isinstance(f, dict):
                    mismatches.append(
                        f"sample record findings[{i}] is not a dict: {type(f).__name__}"
                    )
                    continue
                fkeys = frozenset(f.keys())
                missing_f_keys = finding_fields - fkeys
                if missing_f_keys:
                    mismatches.append(
                        f"sample record findings[{i}] missing keys: {sorted(missing_f_keys)}"
                    )

    # ------------------------------------------------------------------
    # 5. Store layout check if store_path provided
    # ------------------------------------------------------------------
    if store_path is not None:
        store_path = Path(store_path)
        if not store_path.exists():
            mismatches.append(
                f"store_path does not exist: {store_path}"
            )
        else:
            for expected_file in _EXPECTED_STORE_FILES:
                target = store_path / expected_file
                if not target.exists():
                    mismatches.append(
                        f"expected store file missing: {expected_file} under {store_path}"
                    )

    return mismatches
