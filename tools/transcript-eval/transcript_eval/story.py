"""
Story renderer for transcript-eval.

Renders a markdown pipeline-health report from aggregated per-seat metrics.

SF-8: No effectiveness number is labeled "catch rate" or "recall".
      All effectiveness numbers carry the "(precision-from-usage)" label.
AC-3: Required section header is "## FR-016 per-seat evidence".
"""
from __future__ import annotations

import datetime


def _pct(value: float | None) -> str:
    """Format a fraction as a percentage string, or 'N/A' if None."""
    if value is None:
        return "N/A"
    return f"{value:.1%}"


def render_story(aggregates: dict) -> str:
    """
    Render a markdown pipeline-health story from aggregated per-seat metrics.

    Parameters
    ----------
    aggregates:
        dict mapping seat name → metric dict with keys:
          precision, raised, accepted, activity, overlap, unique_catch,
          leave_one_out_delta, rubber_stamp_candidates, metric_kind

    Returns
    -------
    A markdown string suitable for writing to story-latest.md.
    """
    now = datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")

    lines: list[str] = []

    # H1 header
    lines.append("# spec-flow Pipeline Health Report")
    lines.append("")
    lines.append(f"_Generated: {now}_")
    lines.append("")
    lines.append(
        "> mining measures precision/overlap/activity, not recall (SF-8)"
    )
    lines.append("")

    # -----------------------------------------------------------------------
    # FR-016 per-seat evidence section (required literal header — AC-3)
    # -----------------------------------------------------------------------
    lines.append("## FR-016 per-seat evidence")
    lines.append("")
    lines.append(
        "All effectiveness numbers are **precision-from-usage** — "
        "derived from observed accept/reject ratios across real sessions. "
        "They measure the fraction of raised findings that were acted on, "
        "not any form of recall or catch rate."
    )
    lines.append("")

    if not aggregates:
        lines.append("_No seats with data in this run._")
        lines.append("")
    else:
        # Per-seat table
        headers = [
            "Seat",
            "Precision (precision-from-usage)",
            "Raised",
            "Accepted",
            "LOO delta (precision-from-usage)",
            "Overlap count",
            "Unique catch",
            "Activity",
            "Rubber-stamp candidates",
        ]
        lines.append("| " + " | ".join(headers) + " |")
        lines.append("| " + " | ".join(["---"] * len(headers)) + " |")

        for seat, m in sorted(aggregates.items()):
            precision = m.get("precision") if isinstance(m, dict) else getattr(m, "precision", None)
            raised = m.get("raised", 0) if isinstance(m, dict) else getattr(m, "raised", 0)
            accepted = m.get("accepted", 0) if isinstance(m, dict) else getattr(m, "accepted", 0)
            loo = m.get("leave_one_out_delta", 0) if isinstance(m, dict) else getattr(m, "leave_one_out_delta", 0)
            overlap = m.get("overlap", {}) if isinstance(m, dict) else getattr(m, "overlap", {})
            unique_catch = m.get("unique_catch", []) if isinstance(m, dict) else getattr(m, "unique_catch", [])
            activity = m.get("activity", 0) if isinstance(m, dict) else getattr(m, "activity", 0)
            rubber = m.get("rubber_stamp_candidates", []) if isinstance(m, dict) else getattr(m, "rubber_stamp_candidates", [])

            row = [
                f"`{seat}`",
                _pct(precision),
                str(raised),
                str(accepted),
                str(loo),
                str(len(overlap)),
                str(len(unique_catch)),
                str(activity),
                str(len(rubber)),
            ]
            lines.append("| " + " | ".join(row) + " |")

        lines.append("")

        # Per-seat detail blocks
        for seat, m in sorted(aggregates.items()):
            precision = m.get("precision") if isinstance(m, dict) else getattr(m, "precision", None)
            unique_catch = m.get("unique_catch", []) if isinstance(m, dict) else getattr(m, "unique_catch", [])
            rubber = m.get("rubber_stamp_candidates", []) if isinstance(m, dict) else getattr(m, "rubber_stamp_candidates", [])

            lines.append(f"### {seat}")
            lines.append("")
            lines.append(
                f"- **Precision (precision-from-usage):** {_pct(precision)}"
            )

            if unique_catch:
                lines.append(f"- **Unique-catch findings ({len(unique_catch)}):**")
                for uc in unique_catch[:5]:
                    snippet = uc[:120].replace("\n", " ")
                    lines.append(f"  - {snippet}")
                if len(unique_catch) > 5:
                    lines.append(f"  - _(+{len(unique_catch) - 5} more)_")
            else:
                lines.append("- **Unique-catch findings:** none")

            if rubber:
                lines.append(f"- **Rubber-stamp candidates:** {len(rubber)}")
                for rc in rubber[:3]:
                    reason = rc.get("reason", "unknown")
                    tuid = rc.get("tool_use_id", "?")
                    lines.append(f"  - `{tuid}`: {reason}")
                if len(rubber) > 3:
                    lines.append(f"  - _(+{len(rubber) - 3} more)_")

            lines.append("")

    # -----------------------------------------------------------------------
    # Pipeline health section
    # -----------------------------------------------------------------------
    lines.append("## Pipeline Health")
    lines.append("")

    if not aggregates:
        lines.append("_No data available for this run._")
        lines.append("")
    else:
        total_activity = sum(
            (m.get("activity", 0) if isinstance(m, dict) else getattr(m, "activity", 0))
            for m in aggregates.values()
        )
        total_raised = sum(
            (m.get("raised", 0) if isinstance(m, dict) else getattr(m, "raised", 0))
            for m in aggregates.values()
        )
        total_accepted = sum(
            (m.get("accepted", 0) if isinstance(m, dict) else getattr(m, "accepted", 0))
            for m in aggregates.values()
        )
        total_rubber = sum(
            len(m.get("rubber_stamp_candidates", []) if isinstance(m, dict) else getattr(m, "rubber_stamp_candidates", []))
            for m in aggregates.values()
        )

        overall_precision = total_accepted / total_raised if total_raised else None

        lines.append("### Activity Summary")
        lines.append("")
        lines.append(f"- **Seats observed:** {len(aggregates)}")
        lines.append(f"- **Total dispatches:** {total_activity}")
        lines.append(f"- **Total findings raised:** {total_raised}")
        lines.append(f"- **Total findings accepted:** {total_accepted}")
        lines.append(
            f"- **Overall precision (precision-from-usage):** {_pct(overall_precision)}"
        )
        lines.append("")

        # Rubber-stamp candidates summary
        lines.append("### Rubber-stamp Candidates")
        lines.append("")
        if total_rubber == 0:
            lines.append("No rubber-stamp candidates detected in this run.")
        else:
            lines.append(
                f"{total_rubber} approval(s) flagged as rubber-stamp candidates "
                "(zero reviewer notes or fast-approval interval < threshold)."
            )
            lines.append("")
            lines.append("**Seats with rubber-stamp candidates:**")
            for seat, m in sorted(aggregates.items()):
                rubber = m.get("rubber_stamp_candidates", []) if isinstance(m, dict) else getattr(m, "rubber_stamp_candidates", [])
                if rubber:
                    lines.append(f"- `{seat}`: {len(rubber)} candidate(s)")
        lines.append("")

        # Trends note
        lines.append("### Trends")
        lines.append("")
        lines.append(
            "Cross-run trend analysis requires multiple stored runs. "
            "Once run-history accumulates, compare `precision (precision-from-usage)` "
            "across runs to detect degradation or improvement."
        )
        lines.append("")

    # Footer
    lines.append("---")
    lines.append("")
    lines.append(
        "_This report is generated by transcript-eval (internal tooling, NN-C-002). "
        "All metrics are precision-from-usage. "
        "No catch-rate or recall figures are present — "
        "the mining harness does not have ground truth._"
    )
    lines.append("")

    return "\n".join(lines)
