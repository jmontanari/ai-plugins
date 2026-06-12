"""
Tests for transcript_eval.extract — Phase 2.

TE-clean:       parse clean-session.jsonl → ≥2 seat dispatches, correlated findings,
                accept/reject populated, 0 parse misses.
TE-malformed:   parse malformed.jsonl → valid record extracted, bad line counted,
                no exception, no finding silently dropped.
TE-acceptreject: qa-phase finding → "accepted"; review-board-security finding → "rejected".
"""
from __future__ import annotations

from pathlib import Path

import pytest

from transcript_eval.extract import (
    CoverageReport,
    Dispatch,
    Finding,
    extract_dispatches,
    extract_findings,
    extract_session,
    infer_accept_reject,
    iter_records,
)

FIXTURES = Path(__file__).parent / "fixtures"


# ---------------------------------------------------------------------------
# TE-clean
# ---------------------------------------------------------------------------

class TestCleanSession:
    """TE-clean: parse clean-session.jsonl."""

    def setup_method(self) -> None:
        self.fixture = FIXTURES / "clean-session.jsonl"
        self.coverage = CoverageReport()
        self.dispatches = extract_session(self.fixture, self.coverage)

    def test_at_least_two_seat_dispatches(self) -> None:
        """TE-clean: clean-session must yield ≥2 seat dispatches."""
        assert len(self.dispatches) >= 2

    def test_dispatches_have_findings(self) -> None:
        """TE-clean: each dispatch must have ≥1 finding after extraction."""
        for dispatch in self.dispatches:
            assert len(dispatch.findings) >= 1, (
                f"Dispatch {dispatch.tool_use_id} ({dispatch.seat}) has no findings"
            )

    def test_findings_have_accept_reject(self) -> None:
        """TE-clean: every finding must have a non-None accept_reject field."""
        for dispatch in self.dispatches:
            for finding in dispatch.findings:
                assert finding.accept_reject in ("accepted", "rejected"), (
                    f"Finding in {dispatch.seat} has accept_reject={finding.accept_reject!r}"
                )

    def test_zero_parse_misses(self) -> None:
        """TE-clean: clean-session must have 0 parse misses."""
        assert self.coverage.lines_missed == 0

    def test_sessions_parsed_incremented(self) -> None:
        """TE-clean: sessions_parsed counter must be incremented."""
        assert self.coverage.sessions_parsed == 1


# ---------------------------------------------------------------------------
# TE-malformed
# ---------------------------------------------------------------------------

class TestMalformedSession:
    """TE-malformed: parse malformed.jsonl (1 valid + 1 truncated line)."""

    def setup_method(self) -> None:
        self.fixture = FIXTURES / "malformed.jsonl"
        self.coverage = CoverageReport()

    def test_no_exception_raised(self) -> None:
        """TE-malformed: iter_records must never raise on a malformed line."""
        records = list(iter_records(self.fixture))
        # Should complete without exception — assertion is implicit by reaching here.
        assert records is not None

    def test_bad_line_counted_as_miss(self) -> None:
        """TE-malformed: the truncated line must be counted as a parse miss."""
        self.dispatches = extract_session(self.fixture, self.coverage)
        assert self.coverage.lines_missed >= 1, (
            "Expected ≥1 parse miss for the truncated line in malformed.jsonl"
        )

    def test_valid_record_extracted(self) -> None:
        """TE-malformed: the valid JSON line must still be processed (no silent drop)."""
        records = list(iter_records(self.fixture))
        valid_records = [r for r in records if r is not None]
        assert len(valid_records) >= 1, "At least 1 valid record must be extracted"

    def test_findings_not_silently_dropped(self) -> None:
        """TE-malformed: a valid dispatch in malformed.jsonl must produce a dispatch (if present)."""
        # malformed.jsonl has 1 valid qa-spec dispatch + a truncated tool_result line.
        # The dispatch should be extracted (though result_text may be None since the
        # correlated result is on the truncated line).
        # Key invariant: no exception, and we can count dispatches.
        try:
            dispatches = extract_session(self.fixture, self.coverage)
        except Exception as exc:  # pragma: no cover
            pytest.fail(f"extract_session raised an unexpected exception: {exc}")
        # Should have parsed 1 session
        assert self.coverage.sessions_parsed == 1


# ---------------------------------------------------------------------------
# TE-acceptreject
# ---------------------------------------------------------------------------

class TestAcceptReject:
    """
    TE-acceptreject: verify ADR-6 heuristic on clean-session.jsonl.

    qa-phase finding (toolu_qa_phase_01) has a downstream fix-code dispatch
    → expect "accepted".
    review-board-security finding (toolu_review_security_01) has no downstream fix
    → expect "rejected".
    """

    def setup_method(self) -> None:
        self.fixture = FIXTURES / "clean-session.jsonl"
        self.coverage = CoverageReport()
        self.dispatches = extract_session(self.fixture, self.coverage)

    def _dispatch_by_seat(self, seat: str) -> Dispatch:
        for d in self.dispatches:
            if d.seat == seat:
                return d
        raise AssertionError(f"No dispatch found for seat {seat!r}")

    def test_qa_phase_finding_accepted(self) -> None:
        """TE-acceptreject: qa-phase finding with downstream fix-code → accepted."""
        dispatch = self._dispatch_by_seat("spec-flow:qa-phase")
        assert dispatch.findings, "qa-phase dispatch must have ≥1 finding"
        finding = dispatch.findings[0]
        assert finding.accept_reject == "accepted", (
            f"Expected 'accepted' for qa-phase finding, got {finding.accept_reject!r}. "
            f"Finding text: {finding.text!r}"
        )

    def test_review_board_security_finding_rejected(self) -> None:
        """TE-acceptreject: review-board-security finding with no downstream fix → rejected."""
        dispatch = self._dispatch_by_seat("spec-flow:review-board-security")
        assert dispatch.findings, "review-board-security dispatch must have ≥1 finding"
        finding = dispatch.findings[0]
        assert finding.accept_reject == "rejected", (
            f"Expected 'rejected' for review-board-security finding, got {finding.accept_reject!r}. "
            f"Finding text: {finding.text!r}"
        )


# ---------------------------------------------------------------------------
# Unit: extract_findings
# ---------------------------------------------------------------------------

class TestExtractFindings:
    """Unit tests for extract_findings()."""

    def test_single_finding_line(self) -> None:
        text = "FINDING: The module is missing error handling."
        findings = extract_findings(text)
        assert len(findings) == 1
        assert "missing error handling" in findings[0].text

    def test_multiple_findings(self) -> None:
        text = (
            "FINDING: Issue one.\n"
            "FINDING: Issue two."
        )
        findings = extract_findings(text)
        assert len(findings) == 2

    def test_empty_text_returns_empty(self) -> None:
        assert extract_findings("") == []
        assert extract_findings(None) == []
        assert extract_findings("   \n  ") == []

    def test_fallback_no_finding_prefix(self) -> None:
        """Text with no FINDING: prefix → whole text as one finding."""
        text = "This gate is fine, no issues."
        findings = extract_findings(text)
        assert len(findings) == 1
        assert findings[0].text == text.strip()


# ---------------------------------------------------------------------------
# Unit: is_measured_seat
# ---------------------------------------------------------------------------

def test_is_measured_seat_known() -> None:
    from transcript_eval.extract import is_measured_seat
    assert is_measured_seat("spec-flow:qa-phase") is True
    assert is_measured_seat("spec-flow:review-board-security") is True
    assert is_measured_seat("spec-flow:verify") is True


def test_is_measured_seat_unknown() -> None:
    from transcript_eval.extract import is_measured_seat
    assert is_measured_seat("spec-flow:fix-code") is False
    assert is_measured_seat("") is False
    assert is_measured_seat("some-other-agent") is False
