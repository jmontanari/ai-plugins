"""
CLI entry point for transcript-eval.

Subcommands:
  extract  — Phase 2: extract gate dispatches and findings
  spike    — Phase 2: extraction-validation spike
  metrics  — implemented in Phase 3
  story    — implemented in Phase 4
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path


def _not_yet(name: str) -> None:
    """Stub handler — printed when a subcommand is not yet implemented."""
    print(f"[transcript-eval] '{name}' subcommand is implemented in a later phase.", file=sys.stderr)
    sys.exit(1)


def _run_full_pipeline(config: "Config") -> tuple[dict, str]:
    """
    Run the full extract → scrub → metrics → aggregate pipeline.

    Returns (aggregates, run_id) where aggregates maps seat → metrics dict
    and run_id is a timestamp string for store archiving.
    """
    import datetime
    from pathlib import Path

    from .extract import CoverageReport, extract_session
    from .scrub import scrub
    from .metrics import compute_metrics

    coverage = CoverageReport()
    all_records: list[dict] = []

    for project_dir in config.project_dirs:
        project_dir = Path(project_dir)
        if not project_dir.is_dir():
            continue
        for jsonl_file in sorted(project_dir.glob("*.jsonl")):
            dispatches = extract_session(jsonl_file, coverage)
            for d in dispatches:
                all_records.append({
                    "seat": d.seat,
                    "session_id": None,
                    "tool_use_id": d.tool_use_id,
                    "findings": [
                        {"text": scrub(f.text), "accept_reject": f.accept_reject}
                        for f in d.findings
                    ],
                    "dispatch_ts": None,
                    "result_ts": None,
                    "reviewer_notes": scrub(d.result_text or "") if d.result_text else "",
                })

    seat_metrics = compute_metrics(all_records)
    aggregates = {seat: vars(m) for seat, m in seat_metrics.items()}

    run_id = datetime.datetime.utcnow().strftime("run-%Y%m%dT%H%M%SZ")
    return aggregates, run_id


def _cmd_extract(args: argparse.Namespace) -> int:
    """Handler for the 'extract' subcommand."""
    from .config import load_config
    from .extract import CoverageReport, extract_session
    from .scrub import scrub

    config = load_config(args)
    coverage = CoverageReport()
    total_dispatches = 0
    total_findings = 0

    for project_dir in config.project_dirs:
        project_dir = Path(project_dir)
        if not project_dir.is_dir():
            continue
        for jsonl_path in sorted(project_dir.glob("*.jsonl")):
            dispatches = extract_session(jsonl_path, coverage)
            for dispatch in dispatches:
                total_dispatches += 1
                # Scrub result text before any display/storage
                if dispatch.result_text is not None:
                    dispatch.result_text = scrub(dispatch.result_text)
                for finding in dispatch.findings:
                    finding.text = scrub(finding.text)
                    total_findings += 1
                    status = finding.accept_reject or "unknown"
                    print(
                        f"  [{dispatch.seat}] {finding.text[:80]!r}… → {status}"
                        if len(finding.text) > 80
                        else f"  [{dispatch.seat}] {finding.text!r} → {status}"
                    )

    print(
        f"\nSummary: {coverage.sessions_parsed} sessions, "
        f"{total_dispatches} dispatches, {total_findings} findings, "
        f"{coverage.lines_missed} parse misses, {coverage.fields_missed} field misses."
    )
    return 0


def _cmd_spike(args: argparse.Namespace) -> int:
    """Handler for the 'spike' subcommand (NN-P-004 operator gate)."""
    from .config import load_config
    from .spike import run_spike

    config = load_config(args)
    # --project-dir (repeatable) sources; fall back to config's project_dirs
    spike_dirs = [Path(d) for d in args.spike_project_dir] if getattr(args, "spike_project_dir", None) else config.project_dirs
    hand_check_path = Path(args.hand_check) if getattr(args, "hand_check", None) else None

    report = run_spike(config, spike_dirs, hand_check_path)

    cov_str = f"{report.coverage:.1%}" if report.coverage is not None else "N/A"
    agr_str = f"{report.agreement:.1%}" if report.agreement is not None else "N/A"

    print(f"coverage:  {cov_str}")
    print(f"agreement: {agr_str}")
    print(f"verdict:   {report.verdict}")
    if report.notes:
        print(f"notes:     {report.notes}")

    # NN-P-004: exit non-zero on HALT
    return 0 if report.verdict == "PROCEED" else 1


def _cmd_story(args: argparse.Namespace) -> int:
    """Handler for the 'story' subcommand.

    Runs the full pipeline over configured project dirs:
      extract → scrub → compute_metrics → aggregate → store.write_aggregates
      → render_story → store.write_story

    Writes ONLY to the external store (SF-6).
    """
    from .config import load_config
    from .store import InsightStore
    from .story import render_story

    config = load_config(args)
    aggregates, run_id = _run_full_pipeline(config)

    store = InsightStore(config)

    # Write run-index entry
    store.append_run({"kind": "story", "run_id": run_id})

    # Write aggregates
    store.write_aggregates(aggregates)

    # Render and write story
    story_content = render_story(aggregates)
    store.write_story(run_id, story_content)

    print(f"[transcript-eval] story written: {config.store_path}/story-latest.md  (run_id={run_id})")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="transcript_eval",
        description=(
            "transcript-eval — internal spec-flow transcript mining tool "
            "(not shipped, NN-C-002 by location, ADR-3)."
        ),
    )
    parser.add_argument(
        "--store",
        metavar="PATH",
        default=None,
        help=(
            "External insight store path "
            "(default: /Volumes/joeData/spec-flow-insights/ or SPEC_FLOW_INSIGHTS_STORE env var)."
        ),
    )
    parser.add_argument(
        "--project-dir",
        dest="project_dir",
        action="append",
        metavar="PATH",
        default=None,
        help=(
            "Source project directory to mine (repeatable). "
            "Default: all ~/.claude/projects/*/ or SPEC_FLOW_PROJECT_DIRS env var."
        ),
    )

    subparsers = parser.add_subparsers(dest="subcommand", title="subcommands")

    # extract — Phase 2
    sub_extract = subparsers.add_parser(
        "extract",
        help="Extract per-seat gate dispatches and findings from transcripts.",
    )
    sub_extract.set_defaults(func=_cmd_extract)

    # spike — Phase 2
    sub_spike = subparsers.add_parser(
        "spike",
        help=(
            "Extraction-validation spike: validate coverage + agreement "
            "before downstream metrics/story pipeline proceeds (NN-P-004)."
        ),
    )
    sub_spike.add_argument(
        "--project-dir",
        dest="spike_project_dir",
        action="append",
        metavar="PATH",
        default=None,
        help=(
            "Project dir to extract from (repeatable, ≥2 required for the gate). "
            "Defaults to the global --project-dir list if not set."
        ),
    )
    sub_spike.add_argument(
        "--hand-check",
        dest="hand_check",
        metavar="PATH",
        default=None,
        help=(
            "Optional JSON file with hand-checked accept/reject labels. "
            'Format: {"<tool_use_id>/<finding_index>": "accepted"|"rejected", ...}'
        ),
    )
    sub_spike.set_defaults(func=_cmd_spike)

    # metrics — Phase 3
    sub_metrics = subparsers.add_parser(
        "metrics",
        help="Compute gate-effectiveness metrics over extracted records (implemented in Phase 3).",
    )
    sub_metrics.set_defaults(func=lambda _args: _not_yet("metrics"))

    # story — Phase 4
    sub_story = subparsers.add_parser(
        "story",
        help="Render a cross-repo pipeline-health story with FR-016 per-seat evidence (implemented in Phase 4).",
    )
    sub_story.set_defaults(func=_cmd_story)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    if args.subcommand is None:
        parser.print_help()
        return 0

    return args.func(args) or 0


if __name__ == "__main__":
    sys.exit(main())
