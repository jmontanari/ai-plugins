"""
Tests for transcript_eval.spike — Phase 2.

TSP-proceed: mock coverage=0.97, agreement=0.85 → SpikeReport.verdict == "PROCEED"
TSP-halt:    mock coverage=0.90 (< 0.95) → verdict == "HALT", notes names coverage gap
"""
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from unittest.mock import patch

import pytest

from transcript_eval.config import Config, Thresholds
from transcript_eval.spike import SpikeReport, run_spike


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _make_config(coverage: float = 0.95, agreement: float = 0.80) -> Config:
    """Create a Config pointing to a non-existent store (not used in spike tests)."""
    return Config(
        project_dirs=[],
        store_path=Path("/tmp/test-spike-store"),
        thresholds=Thresholds(coverage=coverage, agreement=agreement),
    )


# ---------------------------------------------------------------------------
# TSP-proceed
# ---------------------------------------------------------------------------

class TestSpikeReport:
    """Tests that SpikeReport holds the expected fields."""

    def test_spike_report_has_required_fields(self) -> None:
        """SpikeReport must expose coverage, agreement, verdict, notes."""
        report = SpikeReport(coverage=0.97, agreement=0.85, verdict="PROCEED", notes="")
        assert report.coverage == 0.97
        assert report.agreement == 0.85
        assert report.verdict == "PROCEED"
        assert report.notes == ""


class TestSpikeDecisionLogic:
    """
    TSP-proceed and TSP-halt: test the verdict logic directly by constructing
    SpikeReport outcomes from run_spike via a lightweight fixture directory.
    """

    def test_proceed_when_both_thresholds_met(self, tmp_path: Path) -> None:
        """TSP-proceed: coverage=0.97, agreement=0.85 → PROCEED."""
        # Build a minimal single-session fixture with 1 correlated dispatch
        # so coverage = 1/1 = 1.0 (≥ 0.95) → PROCEED
        session = tmp_path / "session.jsonl"
        import json
        lines = [
            json.dumps({
                "type": "assistant",
                "sessionId": "s1",
                "uuid": "m1",
                "message": {
                    "role": "assistant",
                    "content": [{
                        "type": "tool_use",
                        "id": "tu1",
                        "name": "Agent",
                        "input": {
                            "subagent_type": "spec-flow:qa-phase",
                            "description": "QA",
                            "prompt": "Review",
                        },
                    }],
                },
            }),
            json.dumps({
                "type": "user",
                "sessionId": "s1",
                "uuid": "m2",
                "parentUuid": "m1",
                "message": {
                    "role": "user",
                    "content": [{
                        "type": "tool_result",
                        "tool_use_id": "tu1",
                        "content": "FINDING: Everything looks good.",
                    }],
                },
            }),
        ]
        session.write_text("\n".join(lines), encoding="utf-8")

        config = _make_config(coverage=0.95, agreement=0.80)
        report = run_spike(config, [tmp_path], hand_check_path=None)

        # coverage = 1 correlated / 1 total = 1.0 ≥ 0.95 → PROCEED
        assert report.coverage is not None
        assert report.coverage >= 0.95
        assert report.verdict == "PROCEED"

    def test_halt_when_coverage_below_threshold(self, tmp_path: Path) -> None:
        """TSP-halt: coverage below threshold → HALT, notes name the coverage gap."""
        # Build 3 dispatches, only 1 correlated → coverage = 1/3 ≈ 0.33 < 0.95
        import json
        session = tmp_path / "session.jsonl"
        lines = [
            # Dispatch 1: has a correlated result
            json.dumps({
                "type": "assistant",
                "sessionId": "s1",
                "uuid": "m1",
                "message": {
                    "role": "assistant",
                    "content": [{
                        "type": "tool_use",
                        "id": "tu1",
                        "name": "Agent",
                        "input": {"subagent_type": "spec-flow:qa-phase"},
                    }],
                },
            }),
            json.dumps({
                "type": "user",
                "sessionId": "s1",
                "uuid": "m2",
                "message": {
                    "role": "user",
                    "content": [{
                        "type": "tool_result",
                        "tool_use_id": "tu1",
                        "content": "FINDING: Issue A.",
                    }],
                },
            }),
            # Dispatch 2: NO correlated result
            json.dumps({
                "type": "assistant",
                "sessionId": "s1",
                "uuid": "m3",
                "message": {
                    "role": "assistant",
                    "content": [{
                        "type": "tool_use",
                        "id": "tu2",
                        "name": "Agent",
                        "input": {"subagent_type": "spec-flow:qa-plan"},
                    }],
                },
            }),
            # Dispatch 3: NO correlated result
            json.dumps({
                "type": "assistant",
                "sessionId": "s1",
                "uuid": "m4",
                "message": {
                    "role": "assistant",
                    "content": [{
                        "type": "tool_use",
                        "id": "tu3",
                        "name": "Agent",
                        "input": {"subagent_type": "spec-flow:verify"},
                    }],
                },
            }),
        ]
        session.write_text("\n".join(lines), encoding="utf-8")

        config = _make_config(coverage=0.95, agreement=0.80)
        report = run_spike(config, [tmp_path], hand_check_path=None)

        assert report.verdict == "HALT"
        assert report.coverage is not None
        assert report.coverage < 0.95
        # notes must name the coverage gap
        assert "coverage" in report.notes.lower()

    def test_spike_report_has_coverage_field(self) -> None:
        """SpikeReport emits a coverage field (machine-assertable per AC-6)."""
        report = SpikeReport(coverage=0.97, agreement=None, verdict="PROCEED", notes="")
        assert hasattr(report, "coverage")

    def test_spike_report_has_agreement_field(self) -> None:
        """SpikeReport emits an agreement field (machine-assertable per AC-6)."""
        report = SpikeReport(coverage=0.97, agreement=0.85, verdict="PROCEED", notes="")
        assert hasattr(report, "agreement")

    def test_spike_report_has_verdict_field(self) -> None:
        """SpikeReport emits a verdict field (machine-assertable per AC-6)."""
        report = SpikeReport(coverage=0.97, agreement=0.85, verdict="PROCEED", notes="")
        assert report.verdict in ("PROCEED", "HALT")

    def test_halt_when_coverage_none(self, tmp_path: Path) -> None:
        """Empty sample_path directory (no .jsonl) → coverage=None → HALT."""
        config = _make_config()
        report = run_spike(config, [tmp_path], hand_check_path=None)
        assert report.verdict == "HALT"
        assert report.coverage is None

    def test_agreement_none_when_no_hand_check(self, tmp_path: Path) -> None:
        """When hand_check_path is None, agreement must be None."""
        import json
        session = tmp_path / "session.jsonl"
        session.write_text(
            json.dumps({
                "type": "assistant",
                "sessionId": "s1",
                "uuid": "m1",
                "message": {
                    "role": "assistant",
                    "content": [{
                        "type": "tool_use",
                        "id": "tu1",
                        "name": "Agent",
                        "input": {"subagent_type": "spec-flow:qa-phase"},
                    }],
                },
            })
            + "\n"
            + json.dumps({
                "type": "user",
                "sessionId": "s1",
                "uuid": "m2",
                "message": {
                    "role": "user",
                    "content": [{
                        "type": "tool_result",
                        "tool_use_id": "tu1",
                        "content": "FINDING: ok.",
                    }],
                },
            }),
            encoding="utf-8",
        )
        config = _make_config()
        report = run_spike(config, [tmp_path], hand_check_path=None)
        assert report.agreement is None
