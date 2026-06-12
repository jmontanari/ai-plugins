"""
Extraction-validation spike for transcript-eval.

Runs against real (or synthetic) session samples to validate extraction
coverage and accept/reject inference agreement before the downstream
metrics/story pipeline proceeds.

NN-P-004: operator-gated — CLI exits non-zero on HALT.
"""
from __future__ import annotations

import json
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from .config import Config
from .extract import CoverageReport, extract_session


# ---------------------------------------------------------------------------
# Data classes
# ---------------------------------------------------------------------------

@dataclass
class SpikeReport:
    coverage: float | None          # fraction of extractable dispatches found (0.0–1.0)
    agreement: float | None         # fraction of findings where inferred a/r matches hand-check
    verdict: str                    # "PROCEED" | "HALT"
    notes: str = ""                 # human-readable explanation, required on HALT


# ---------------------------------------------------------------------------
# Spike runner
# ---------------------------------------------------------------------------

def run_spike(
    config: Config,
    project_dirs: list[Path],
    hand_check_path: Path | None = None,
) -> SpikeReport:
    """
    Run the extraction-validation spike.

    Parameters
    ----------
    config:
        Config object with thresholds.coverage and thresholds.agreement.
    project_dirs:
        One or more directories each containing .jsonl session files.
        Satisfying AC-6 requires ≥2 repos (≥3 sessions total).
    hand_check_path:
        Optional path to a JSON file with hand-checked accept/reject labels.
        Format: {"<tool_use_id>/<finding_index>": "accepted"|"rejected", ...}
        If None or the file is empty, agreement cannot be computed.

    Returns
    -------
    SpikeReport with coverage, agreement (possibly None), verdict, and notes.
    """
    # -----------------------------------------------------------------------
    # Step 1: collect .jsonl session files from all project dirs
    # -----------------------------------------------------------------------
    session_files: list[Path] = []
    for project_dir in project_dirs:
        if project_dir.is_dir():
            session_files.extend(sorted(project_dir.glob("*.jsonl")))
        elif project_dir.is_file():
            session_files.append(project_dir)

    if not session_files:
        return SpikeReport(
            coverage=None,
            agreement=None,
            verdict="HALT",
            notes=f"no .jsonl session files found in: {[str(d) for d in project_dirs]}",
        )

    # -----------------------------------------------------------------------
    # Step 2: extract all dispatches, counting coverage
    # -----------------------------------------------------------------------
    coverage = CoverageReport()
    all_dispatches = []

    for session_file in session_files:
        dispatches = extract_session(session_file, coverage)
        all_dispatches.extend(dispatches)

    # Coverage = dispatches with a correlated result / total dispatches found.
    # If no dispatches were found at all, coverage is 0.0.
    total_dispatches = len(all_dispatches)
    correlated = sum(1 for d in all_dispatches if d.result_text is not None)

    if total_dispatches == 0:
        coverage_pct: float | None = None
    else:
        coverage_pct = correlated / total_dispatches

    # -----------------------------------------------------------------------
    # Step 3: agreement computation (optional, only when hand_check_path given)
    # -----------------------------------------------------------------------
    agreement_pct: float | None = None
    agreement_notes = ""

    if hand_check_path is not None and hand_check_path.is_file():
        try:
            hand_check: dict[str, str] = json.loads(
                hand_check_path.read_text(encoding="utf-8")
            )
        except (json.JSONDecodeError, OSError):
            hand_check = {}

        if hand_check:
            matches = 0
            total_checked = 0
            for dispatch in all_dispatches:
                for idx, finding in enumerate(dispatch.findings):
                    key = f"{dispatch.tool_use_id}/{idx}"
                    if key in hand_check:
                        total_checked += 1
                        if finding.accept_reject == hand_check[key]:
                            matches += 1
            if total_checked > 0:
                agreement_pct = matches / total_checked
            else:
                agreement_notes = "hand_check file provided but no matching finding keys found"
        else:
            agreement_notes = "hand_check file is empty or could not be parsed"

    # -----------------------------------------------------------------------
    # Step 4: verdict
    # -----------------------------------------------------------------------
    thresholds = config.thresholds
    failures: list[str] = []

    if coverage_pct is None:
        failures.append("coverage: no dispatches found in sample — cannot evaluate")
    elif coverage_pct < thresholds.coverage:
        failures.append(
            f"coverage: {coverage_pct:.1%} < required {thresholds.coverage:.1%}"
        )

    if agreement_pct is not None and agreement_pct < thresholds.agreement:
        failures.append(
            f"agreement: {agreement_pct:.1%} < required {thresholds.agreement:.1%}"
        )

    if failures:
        verdict = "HALT"
        notes = "; ".join(failures)
        if agreement_notes:
            notes += f"; {agreement_notes}"
    else:
        verdict = "PROCEED"
        notes = agreement_notes or ""

    return SpikeReport(
        coverage=coverage_pct,
        agreement=agreement_pct,
        verdict=verdict,
        notes=notes,
    )
