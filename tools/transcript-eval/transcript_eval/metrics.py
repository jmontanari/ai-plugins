"""
Gate-effectiveness metrics for transcript-eval.

Computes per-seat effectiveness metrics over extracted dispatch records.

All effectiveness numbers are labeled `metric_kind = "precision-from-usage"` (SF-8).
No field is named or labeled "catch rate" or "recall".

NN-P-005: pure deterministic computation — no model invoked.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


# ---------------------------------------------------------------------------
# Data model
# ---------------------------------------------------------------------------

@dataclass
class SeatMetrics:
    """Per-seat effectiveness metrics derived from extracted dispatch records."""

    # Core counts
    precision: float | None  # accepted / raised; None when raised == 0
    raised: int              # total findings raised by this seat
    accepted: int            # findings accepted (downstream fix dispatched)
    activity: int            # dispatch count for this seat

    # Overlap / unique-catch
    overlap: dict[str, list[str]]  # issue_key -> list of OTHER seat names that co-found it
    unique_catch: list[str]        # accepted finding texts only THIS seat raised

    # Leave-one-out ablation (FR-016)
    leave_one_out_delta: int  # covered_defects(all) - covered_defects(all - {seat})

    # Rubber-stamp signals
    rubber_stamp_candidates: list[dict[str, Any]]  # approvals with zero notes OR fast interval

    # Label (SF-8) — every effectiveness field carries this tag
    metric_kind: str = "precision-from-usage"


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

def _normalise_seat(seat: str) -> str:
    """Strip 'spec-flow:' prefix if present so seat names match fixture keys."""
    return seat


def _accepted_defect_keys(dispatches: list[dict], seat_subset: set[str]) -> set[str]:
    """
    Return the set of accepted finding keys covered by any seat in seat_subset.

    A finding key is `(seat, finding_text)` normalised — but for coverage we
    want UNIQUE *defects*, not findings.  Two findings from different seats
    that share the same text are treated as the same defect (de-duplicated).

    For leave-one-out: we identify defects by their finding text (normalised).
    A defect is "covered" if at least one seat in `seat_subset` accepted a
    finding with that text.
    """
    covered: set[str] = set()
    for d in dispatches:
        if d["seat"] not in seat_subset:
            continue
        for f in d.get("findings", []):
            if f.get("accept_reject") == "accepted":
                covered.add(f["text"].strip())
    return covered


def _finding_text_to_seats(dispatches: list[dict]) -> dict[str, set[str]]:
    """
    Map each accepted finding text to the set of seats that raised it.
    Used for overlap and unique-catch detection.
    """
    text_to_seats: dict[str, set[str]] = {}
    for d in dispatches:
        seat = d["seat"]
        for f in d.get("findings", []):
            txt = f["text"].strip()
            if txt not in text_to_seats:
                text_to_seats[txt] = set()
            text_to_seats[txt].add(seat)
    return text_to_seats


def _accepted_finding_text_to_seats(dispatches: list[dict]) -> dict[str, set[str]]:
    """
    Same as _finding_text_to_seats but restricted to accepted findings only.
    Used for unique_catch.
    """
    text_to_seats: dict[str, set[str]] = {}
    for d in dispatches:
        seat = d["seat"]
        for f in d.get("findings", []):
            if f.get("accept_reject") != "accepted":
                continue
            txt = f["text"].strip()
            if txt not in text_to_seats:
                text_to_seats[txt] = set()
            text_to_seats[txt].add(seat)
    return text_to_seats


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def compute_metrics(
    records: list[dict],
    *,
    rubber_stamp_secs: float = 60.0,
) -> dict[str, SeatMetrics]:
    """
    Compute per-seat effectiveness metrics from extracted dispatch records.

    Parameters
    ----------
    records:
        List of dispatch dicts, each containing:
        - "seat": str — subagent_type / seat name
        - "findings": list of {"text": str, "accept_reject": "accepted"|"rejected"|None}
        - "dispatch_ts": float | None — Unix timestamp when dispatch was issued
        - "result_ts": float | None — Unix timestamp when result arrived
        - "reviewer_notes": str | None — notes accompanying an approval
    rubber_stamp_secs:
        Approvals whose (result_ts - dispatch_ts) < this threshold are flagged
        as rubber-stamp candidates (default 60 s).

    Returns
    -------
    dict[seat, SeatMetrics] — one entry per unique seat seen in records.
    """
    # Group dispatches by seat
    seat_dispatches: dict[str, list[dict]] = {}
    all_seats: list[str] = []

    for d in records:
        seat = d["seat"]
        if seat not in seat_dispatches:
            seat_dispatches[seat] = []
            all_seats.append(seat)
        seat_dispatches[seat].append(d)

    all_seats_set = set(all_seats)

    # Pre-compute shared lookup tables
    # All findings (accepted or not) per text → seats (for overlap)
    all_text_to_seats = _finding_text_to_seats(records)
    # Accepted findings per text → seats (for unique_catch)
    accepted_text_to_seats = _accepted_finding_text_to_seats(records)

    # Total covered defects across ALL seats (for leave-one-out baseline)
    baseline_covered = _accepted_defect_keys(records, all_seats_set)

    result: dict[str, SeatMetrics] = {}

    for seat in all_seats:
        dispatches = seat_dispatches[seat]

        # --- Activity: number of dispatches ---
        activity = len(dispatches)

        # --- Raised / Accepted counts ---
        raised = 0
        accepted = 0
        for d in dispatches:
            for f in d.get("findings", []):
                raised += 1
                if f.get("accept_reject") == "accepted":
                    accepted += 1

        # --- Precision ---
        precision: float | None = accepted / raised if raised else None

        # --- Overlap: per accepted finding, which OTHER seats also found it ---
        # We include ALL findings (accepted or not) in the overlap map, keyed
        # by finding text.  overlap[finding_text] = [other seats].
        overlap: dict[str, list[str]] = {}
        for d in dispatches:
            for f in d.get("findings", []):
                txt = f["text"].strip()
                other_seats = sorted(all_text_to_seats.get(txt, set()) - {seat})
                if other_seats:
                    overlap[txt] = other_seats

        # --- Unique catch: accepted findings ONLY this seat raised ---
        unique_catch: list[str] = []
        for d in dispatches:
            for f in d.get("findings", []):
                if f.get("accept_reject") != "accepted":
                    continue
                txt = f["text"].strip()
                if accepted_text_to_seats.get(txt) == {seat}:
                    # Only this seat raised this accepted finding
                    if txt not in unique_catch:
                        unique_catch.append(txt)

        # --- Leave-one-out delta (FR-016 ablation) ---
        # Computed as: |covered_defects(all_seats)| - |covered_defects(all_seats - {this_seat})|
        # Under the current single-finding-per-defect model, this equals len(unique_catch) because
        # a finding only drops from coverage when this seat is the SOLE acceptor (= unique_catch).
        # The two metrics diverge when a coverage model deduplicates findings by issue identity
        # (e.g. N findings about the same underlying bug count as 1 defect) — then a finding shared
        # by multiple seats reduces LOO delta below unique_catch. That deduplication is a deferred
        # future enhancement (the current model is one finding = one defect).
        without_seat = all_seats_set - {seat}
        covered_without = _accepted_defect_keys(records, without_seat)
        leave_one_out_delta = len(baseline_covered) - len(covered_without)

        # --- Rubber-stamp candidates ---
        rubber_stamp_candidates: list[dict[str, Any]] = []
        for d in dispatches:
            notes = d.get("reviewer_notes")
            dispatch_ts = d.get("dispatch_ts")
            result_ts = d.get("result_ts")

            is_zero_notes = isinstance(notes, str) and notes.strip() == ""
            is_fast = (
                dispatch_ts is not None
                and result_ts is not None
                and (result_ts - dispatch_ts) < rubber_stamp_secs
            )

            if is_zero_notes or is_fast:
                rubber_stamp_candidates.append({
                    "seat": seat,
                    "tool_use_id": d.get("tool_use_id"),
                    "reviewer_notes": notes,
                    "dispatch_ts": dispatch_ts,
                    "result_ts": result_ts,
                    "reason": (
                        "zero-notes" if is_zero_notes
                        else f"fast-approval ({result_ts - dispatch_ts:.1f}s < {rubber_stamp_secs}s)"
                    ),
                })

        result[seat] = SeatMetrics(
            precision=precision,
            raised=raised,
            accepted=accepted,
            activity=activity,
            overlap=overlap,
            unique_catch=unique_catch,
            leave_one_out_delta=leave_one_out_delta,
            rubber_stamp_candidates=rubber_stamp_candidates,
            metric_kind="precision-from-usage",
        )

    return result
